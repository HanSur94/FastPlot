/*
 * to_step_function_mex.c — Convert segment boundaries to step-function arrays.
 *
 * [stepX, stepY] = to_step_function_mex(segBounds, values, dataEnd)
 *
 *   segBounds — 1xS double, segment boundary timestamps
 *   values    — 1xS double, threshold value at each boundary (NaN = inactive)
 *   dataEnd   — scalar double, end-of-data timestamp (right edge of last seg)
 *
 *   Returns:
 *     stepX — 1xP double, X coordinates for step-function plotting
 *     stepY — 1xP double, Y coordinates for step-function plotting
 *
 * Algorithm:
 *   Single pass over segments.  Active (non-NaN) segments emit two points
 *   (segStart, segEnd).  Contiguous active segments share a duplicated
 *   boundary X for a vertical step.  Non-contiguous active segments are
 *   separated by NaN so the plot line breaks.
 *
 *   Pre-allocates output to worst-case size (3*nActive) and trims once.
 *   No dynamic allocation or reallocation inside the loop.
 */

#include "mex.h"
#include <math.h>
#include <stddef.h>

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    const double *segBounds, *values;
    double dataEnd;
    size_t nB, i;
    size_t nActive;
    size_t *activeIdx;
    double *segEnds;
    double *stepX, *stepY;
    size_t pos, a, k;
    int *isGap;

    if (nrhs != 3) {
        mexErrMsgIdAndTxt("FastSense:to_step_function_mex:nrhs",
            "Three inputs required: segBounds, values, dataEnd.");
    }

    segBounds = mxGetPr(prhs[0]);
    values    = mxGetPr(prhs[1]);
    dataEnd   = mxGetScalar(prhs[2]);
    nB        = mxGetNumberOfElements(prhs[0]);

    /* Count active (non-NaN) segments */
    nActive = 0;
    for (i = 0; i < nB; i++) {
        if (!mxIsNaN(values[i])) {
            nActive++;
        }
    }

    /* No active segments */
    if (nActive == 0) {
        plhs[0] = mxCreateDoubleMatrix(1, 0, mxREAL);
        if (nlhs > 1) plhs[1] = mxCreateDoubleMatrix(1, 0, mxREAL);
        return;
    }

    /* Collect active indices */
    activeIdx = (size_t *)mxMalloc(nActive * sizeof(size_t));
    nActive = 0;
    for (i = 0; i < nB; i++) {
        if (!mxIsNaN(values[i])) {
            activeIdx[nActive++] = i;
        }
    }

    /* Compute right edges: segEnds[i] = segBounds[i+1], last = dataEnd */
    segEnds = (double *)mxMalloc(nB * sizeof(double));
    for (i = 0; i + 1 < nB; i++) {
        segEnds[i] = segBounds[i + 1];
    }
    segEnds[nB - 1] = dataEnd;

    /* Single active segment — fast path */
    if (nActive == 1) {
        k = activeIdx[0];
        plhs[0] = mxCreateDoubleMatrix(1, 2, mxREAL);
        stepX = mxGetPr(plhs[0]);
        stepX[0] = segBounds[k];
        stepX[1] = segEnds[k];
        if (nlhs > 1) {
            plhs[1] = mxCreateDoubleMatrix(1, 2, mxREAL);
            stepY = mxGetPr(plhs[1]);
            stepY[0] = values[k];
            stepY[1] = values[k];
        }
        mxFree(activeIdx);
        mxFree(segEnds);
        return;
    }

    /* Detect gaps between consecutive active segments */
    isGap = (int *)mxMalloc((nActive - 1) * sizeof(int));
    for (a = 0; a + 1 < nActive; a++) {
        isGap[a] = (segEnds[activeIdx[a]] != segBounds[activeIdx[a + 1]]);
    }

    /* Worst case output: 2*nActive (contiguous points) + nActive (NaN seps)
     * = 3*nActive.  Always sufficient. */
    {
        size_t maxLen = 3 * nActive;
        double *outX = (double *)mxMalloc(maxLen * sizeof(double));
        double *outY = (double *)mxMalloc(maxLen * sizeof(double));

        /* First active segment */
        pos = 0;
        k = activeIdx[0];
        outX[pos] = segBounds[k]; outY[pos] = values[k]; pos++;
        outX[pos] = segEnds[k];   outY[pos] = values[k]; pos++;

        for (a = 1; a < nActive; a++) {
            k = activeIdx[a];
            if (isGap[a - 1]) {
                /* Non-contiguous: NaN separator, then new segment */
                outX[pos] = mxGetNaN(); outY[pos] = mxGetNaN(); pos++;
                outX[pos] = segBounds[k]; outY[pos] = values[k]; pos++;
                outX[pos] = segEnds[k];   outY[pos] = values[k]; pos++;
            } else {
                /* Contiguous: duplicate boundary for vertical step */
                outX[pos] = segBounds[k]; outY[pos] = values[k]; pos++;
                outX[pos] = segEnds[k];   outY[pos] = values[k]; pos++;
            }
        }

        /* Create output arrays with exact size and copy */
        plhs[0] = mxCreateDoubleMatrix(1, pos, mxREAL);
        stepX = mxGetPr(plhs[0]);
        for (i = 0; i < pos; i++) stepX[i] = outX[i];

        if (nlhs > 1) {
            plhs[1] = mxCreateDoubleMatrix(1, pos, mxREAL);
            stepY = mxGetPr(plhs[1]);
            for (i = 0; i < pos; i++) stepY[i] = outY[i];
        }

        mxFree(outX);
        mxFree(outY);
    }

    mxFree(isGap);
    mxFree(activeIdx);
    mxFree(segEnds);
}
