/*
 * mksqlite.c - Minimal mksqlite-compatible MEX for GNU Octave
 *
 * Supports:
 *   dbId = mksqlite('open', filepath)
 *   mksqlite(dbId, 'close')
 *   mksqlite(dbId, 'typedBLOBs', 2)
 *   mksqlite(dbId, 'SQL statement')
 *   mksqlite(dbId, 'SQL with ? placeholders', val1, val2, ...)
 *
 * Typed BLOBs: MATLAB/Octave arrays are serialized with a header containing
 * magic bytes, class ID, dimensions, then raw double data. On SELECT, typed
 * BLOBs are automatically deserialized back to mxArray.
 *
 * Compile:
 *   mkoctfile --mex -o mksqlite.mex -lsqlite3 mksqlite.c
 */

#include "mex.h"
#include <sqlite3.h>
#include <string.h>
#include <stdlib.h>

/* ---- Constants ---- */
#define MAX_DBS 16

/* Typed BLOB header magic: "mksqlite typed BLOB" signature */
#define TYPED_BLOB_MAGIC  0x4D4B5351  /* "MKSQ" */
#define TYPED_BLOB_VER    2

/* ---- Typed BLOB header structure ---- */
typedef struct {
    uint32_t magic;       /* TYPED_BLOB_MAGIC */
    uint32_t version;     /* TYPED_BLOB_VER */
    uint32_t class_id;    /* mxClassID (mxDOUBLE_CLASS=6, mxINT32_CLASS=12, etc.) */
    uint32_t ndims;       /* number of dimensions */
    uint32_t rows;        /* first dimension size */
    uint32_t cols;        /* second dimension size */
    /* raw data follows immediately after this header */
} TypedBlobHeader;

#define TYPED_BLOB_HEADER_SIZE sizeof(TypedBlobHeader)

/* ---- Module state ---- */
static sqlite3 *g_dbs[MAX_DBS] = {NULL};
static int g_typed_blobs[MAX_DBS] = {0};  /* per-db typedBLOBs flag */

/* ---- Helpers ---- */

static int find_free_slot(void) {
    int i;
    for (i = 0; i < MAX_DBS; i++) {
        if (g_dbs[i] == NULL) return i;
    }
    return -1;
}

static void check_db_id(int dbId) {
    if (dbId < 1 || dbId > MAX_DBS || g_dbs[dbId - 1] == NULL) {
        mexErrMsgIdAndTxt("mksqlite:badHandle",
                          "Invalid database handle: %d", dbId);
    }
}

/* Get size in bytes for an mxClassID */
static size_t class_element_size(mxClassID cid) {
    switch (cid) {
        case mxDOUBLE_CLASS:  return 8;
        case mxSINGLE_CLASS:  return 4;
        case mxINT8_CLASS:    return 1;
        case mxUINT8_CLASS:   return 1;
        case mxINT16_CLASS:   return 2;
        case mxUINT16_CLASS:  return 2;
        case mxINT32_CLASS:   return 4;
        case mxUINT32_CLASS:  return 4;
        case mxINT64_CLASS:   return 8;
        case mxUINT64_CLASS:  return 8;
        default:              return 0;
    }
}

/* Serialize an mxArray to a typed BLOB (malloc'd buffer, caller frees) */
static void *serialize_array(const mxArray *arr, size_t *out_size) {
    mxClassID cid = mxGetClassID(arr);
    size_t elem_sz = class_element_size(cid);
    size_t rows = mxGetM(arr);
    size_t cols = mxGetN(arr);
    size_t numel = rows * cols;
    size_t data_bytes = numel * elem_sz;
    size_t total = TYPED_BLOB_HEADER_SIZE + data_bytes;
    unsigned char *buf;
    TypedBlobHeader hdr;

    if (elem_sz == 0) {
        mexErrMsgIdAndTxt("mksqlite:unsupportedClass",
                          "Cannot serialize arrays of this class.");
    }

    buf = (unsigned char *)mxMalloc(total);
    hdr.magic    = TYPED_BLOB_MAGIC;
    hdr.version  = TYPED_BLOB_VER;
    hdr.class_id = (uint32_t)cid;
    hdr.ndims    = 2;
    hdr.rows     = (uint32_t)rows;
    hdr.cols     = (uint32_t)cols;

    memcpy(buf, &hdr, TYPED_BLOB_HEADER_SIZE);
    memcpy(buf + TYPED_BLOB_HEADER_SIZE, mxGetData(arr), data_bytes);

    *out_size = total;
    return buf;
}

/* Deserialize a typed BLOB back to an mxArray (returns NULL if not typed) */
static mxArray *deserialize_blob(const void *data, int nbytes) {
    const TypedBlobHeader *hdr;
    mxClassID cid;
    size_t elem_sz, expected;
    mxArray *arr;

    if (nbytes < (int)TYPED_BLOB_HEADER_SIZE) return NULL;

    hdr = (const TypedBlobHeader *)data;
    if (hdr->magic != TYPED_BLOB_MAGIC) return NULL;
    if (hdr->version != TYPED_BLOB_VER) return NULL;

    cid = (mxClassID)hdr->class_id;
    elem_sz = class_element_size(cid);
    if (elem_sz == 0) return NULL;

    expected = TYPED_BLOB_HEADER_SIZE + (size_t)hdr->rows * hdr->cols * elem_sz;
    if ((size_t)nbytes < expected) return NULL;

    if (cid == mxDOUBLE_CLASS) {
        arr = mxCreateDoubleMatrix(hdr->rows, hdr->cols, mxREAL);
    } else {
        arr = mxCreateNumericMatrix(hdr->rows, hdr->cols, cid, mxREAL);
    }
    memcpy(mxGetData(arr), (const unsigned char *)data + TYPED_BLOB_HEADER_SIZE,
           (size_t)hdr->rows * hdr->cols * elem_sz);
    return arr;
}

/* Bind one mxArray parameter to a sqlite3_stmt at position idx (1-based) */
static void bind_param(sqlite3_stmt *stmt, int idx, const mxArray *param,
                       int typed_blobs) {
    if (mxIsChar(param)) {
        char *str = mxArrayToString(param);
        sqlite3_bind_text(stmt, idx, str, -1, SQLITE_TRANSIENT);
        mxFree(str);
    } else if (mxIsEmpty(param)) {
        sqlite3_bind_null(stmt, idx);
    } else if (mxIsNumeric(param) && mxGetNumberOfElements(param) == 1 &&
               !typed_blobs) {
        /* Scalar numeric — bind as double */
        sqlite3_bind_double(stmt, idx, mxGetScalar(param));
    } else if (mxIsNumeric(param)) {
        if (typed_blobs && mxGetNumberOfElements(param) > 1) {
            /* Array with typedBLOBs enabled — serialize */
            size_t blob_sz;
            void *blob = serialize_array(param, &blob_sz);
            sqlite3_bind_blob(stmt, idx, blob, (int)blob_sz, SQLITE_TRANSIENT);
            mxFree(blob);
        } else {
            /* Scalar or typedBLOBs disabled — bind as double */
            sqlite3_bind_double(stmt, idx, mxGetScalar(param));
        }
    } else {
        mexErrMsgIdAndTxt("mksqlite:unsupportedParam",
                          "Unsupported parameter type at position %d.", idx);
    }
}

/* Build struct array result from a stepped SELECT statement */
static mxArray *build_result(sqlite3_stmt *stmt, int typed_blobs) {
    int ncols = sqlite3_column_count(stmt);
    int capacity = 64;
    int nrows = 0;
    int i, j, rc;
    const char **col_names;
    mxArray ***cell_data;  /* cell_data[col][row] */
    mxArray *result;

    if (ncols == 0) return mxCreateDoubleMatrix(0, 0, mxREAL);

    /* Collect column names */
    col_names = (const char **)mxMalloc(ncols * sizeof(char *));
    for (i = 0; i < ncols; i++) {
        col_names[i] = sqlite3_column_name(stmt, i);
    }

    /* Allocate column arrays */
    cell_data = (mxArray ***)mxMalloc(ncols * sizeof(mxArray **));
    for (i = 0; i < ncols; i++) {
        cell_data[i] = (mxArray **)mxCalloc(capacity, sizeof(mxArray *));
    }

    /* Step through rows */
    /* The first row was already stepped before calling this function.
     * Actually, let's restructure: caller will pass first step result. */
    do {
        if (nrows >= capacity) {
            capacity *= 2;
            for (i = 0; i < ncols; i++) {
                cell_data[i] = (mxArray **)mxRealloc(cell_data[i],
                                capacity * sizeof(mxArray *));
            }
        }
        for (i = 0; i < ncols; i++) {
            int ctype = sqlite3_column_type(stmt, i);
            switch (ctype) {
                case SQLITE_INTEGER:
                    cell_data[i][nrows] = mxCreateDoubleScalar(
                        (double)sqlite3_column_int64(stmt, i));
                    break;
                case SQLITE_FLOAT:
                    cell_data[i][nrows] = mxCreateDoubleScalar(
                        sqlite3_column_double(stmt, i));
                    break;
                case SQLITE_TEXT:
                    cell_data[i][nrows] = mxCreateString(
                        (const char *)sqlite3_column_text(stmt, i));
                    break;
                case SQLITE_BLOB: {
                    const void *bdata = sqlite3_column_blob(stmt, i);
                    int bsize = sqlite3_column_bytes(stmt, i);
                    mxArray *deserialized = NULL;
                    if (typed_blobs) {
                        deserialized = deserialize_blob(bdata, bsize);
                    }
                    if (deserialized) {
                        cell_data[i][nrows] = deserialized;
                    } else {
                        /* Return raw bytes as uint8 array */
                        mxArray *u8 = mxCreateNumericMatrix(1, bsize,
                                                            mxUINT8_CLASS, mxREAL);
                        memcpy(mxGetData(u8), bdata, bsize);
                        cell_data[i][nrows] = u8;
                    }
                    break;
                }
                case SQLITE_NULL:
                default:
                    cell_data[i][nrows] = mxCreateDoubleMatrix(0, 0, mxREAL);
                    break;
            }
        }
        nrows++;
        rc = sqlite3_step(stmt);
    } while (rc == SQLITE_ROW);

    if (nrows == 0) {
        mxFree(col_names);
        for (i = 0; i < ncols; i++) mxFree(cell_data[i]);
        mxFree(cell_data);
        return mxCreateDoubleMatrix(0, 0, mxREAL);
    }

    /* Build struct array (1 x nrows) with field per column */
    result = mxCreateStructMatrix(1, nrows, ncols, col_names);
    for (i = 0; i < ncols; i++) {
        for (j = 0; j < nrows; j++) {
            mxSetFieldByNumber(result, j, i, cell_data[i][j]);
        }
    }

    mxFree(col_names);
    for (i = 0; i < ncols; i++) mxFree(cell_data[i]);
    mxFree(cell_data);
    return result;
}

/* ---- MEX entry point ---- */
void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[]) {
    char *cmd;
    int dbId, slot, rc, i;
    sqlite3 *db;
    sqlite3_stmt *stmt;
    const char *tail;
    char *errmsg;

    if (nrhs < 1) {
        mexErrMsgIdAndTxt("mksqlite:nargs", "Not enough input arguments.");
    }

    /* ------ Case 1: mksqlite('open', filepath) ------ */
    if (mxIsChar(prhs[0])) {
        cmd = mxArrayToString(prhs[0]);

        if (strcmp(cmd, "open") == 0) {
            char *filepath;
            if (nrhs < 2 || !mxIsChar(prhs[1])) {
                mxFree(cmd);
                mexErrMsgIdAndTxt("mksqlite:args",
                                  "'open' requires a file path argument.");
            }
            filepath = mxArrayToString(prhs[1]);
            slot = find_free_slot();
            if (slot < 0) {
                mxFree(cmd);
                mxFree(filepath);
                mexErrMsgIdAndTxt("mksqlite:tooMany",
                                  "Maximum %d databases already open.", MAX_DBS);
            }
            rc = sqlite3_open(filepath, &g_dbs[slot]);
            if (rc != SQLITE_OK) {
                const char *msg = sqlite3_errmsg(g_dbs[slot]);
                sqlite3_close(g_dbs[slot]);
                g_dbs[slot] = NULL;
                mxFree(cmd);
                mxFree(filepath);
                mexErrMsgIdAndTxt("mksqlite:openFailed",
                                  "Cannot open database: %s", msg);
            }
            g_typed_blobs[slot] = 0;
            mxFree(filepath);
            mxFree(cmd);
            plhs[0] = mxCreateDoubleScalar((double)(slot + 1));
            return;
        }

        /* Unknown string-first command */
        mxFree(cmd);
        mexErrMsgIdAndTxt("mksqlite:unknownCmd",
                          "Unknown command. First arg must be 'open' or a db handle.");
        return;
    }

    /* ------ Cases with dbId as first argument ------ */
    if (!mxIsNumeric(prhs[0]) || mxGetNumberOfElements(prhs[0]) != 1) {
        mexErrMsgIdAndTxt("mksqlite:badArg",
                          "First argument must be 'open' or a numeric db handle.");
    }

    dbId = (int)mxGetScalar(prhs[0]);
    check_db_id(dbId);
    slot = dbId - 1;
    db = g_dbs[slot];

    if (nrhs < 2 || !mxIsChar(prhs[1])) {
        mexErrMsgIdAndTxt("mksqlite:args",
                          "Second argument must be a command string.");
    }

    cmd = mxArrayToString(prhs[1]);

    /* ------ Case 2: mksqlite(dbId, 'close') ------ */
    if (strcmp(cmd, "close") == 0) {
        sqlite3_close(g_dbs[slot]);
        g_dbs[slot] = NULL;
        g_typed_blobs[slot] = 0;
        mxFree(cmd);
        if (nlhs > 0) plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
        return;
    }

    /* ------ Case 3: mksqlite(dbId, 'typedBLOBs', mode) ------ */
    if (strcmp(cmd, "typedBLOBs") == 0) {
        if (nrhs >= 3 && mxIsNumeric(prhs[2])) {
            g_typed_blobs[slot] = (int)mxGetScalar(prhs[2]);
        }
        mxFree(cmd);
        if (nlhs > 0) plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
        return;
    }

    /* ------ Cases 4 & 5: SQL execution ------ */
    rc = sqlite3_prepare_v2(db, cmd, -1, &stmt, &tail);
    if (rc != SQLITE_OK) {
        const char *msg = sqlite3_errmsg(db);
        mxFree(cmd);
        mexErrMsgIdAndTxt("mksqlite:sqlError", "SQL prepare error: %s", msg);
    }

    /* Bind parameters (prhs[2], prhs[3], ...) */
    for (i = 2; i < nrhs; i++) {
        bind_param(stmt, i - 1, prhs[i], g_typed_blobs[slot]);
    }

    /* Execute */
    rc = sqlite3_step(stmt);

    if (rc == SQLITE_ROW) {
        /* SELECT query — build struct array result */
        mxArray *result = build_result(stmt, g_typed_blobs[slot]);
        sqlite3_finalize(stmt);
        mxFree(cmd);
        if (nlhs > 0) plhs[0] = result;
        else mxDestroyArray(result);
        return;
    }

    if (rc != SQLITE_DONE && rc != SQLITE_OK) {
        const char *msg = sqlite3_errmsg(db);
        sqlite3_finalize(stmt);
        mxFree(cmd);
        mexErrMsgIdAndTxt("mksqlite:sqlError", "SQL execution error: %s", msg);
    }

    sqlite3_finalize(stmt);
    mxFree(cmd);

    /* Non-SELECT: return empty */
    if (nlhs > 0) plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
}
