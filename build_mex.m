function build_mex()
%BUILD_MEX Compile FastPlot MEX files with platform-appropriate SIMD flags.
%   build_mex()
%
%   Detects CPU architecture, sets compiler flags for AVX2/SSE2/NEON,
%   and compiles all MEX source files from private/mex_src/ into private/.
%
%   Safe to re-run — overwrites existing MEX binaries.

    rootDir = fileparts(mfilename('fullpath'));
    srcDir  = fullfile(rootDir, 'private', 'mex_src');
    outDir  = fullfile(rootDir, 'private');

    % Detect architecture
    arch = computer('arch');
    fprintf('Architecture: %s\n', arch);

    % Set SIMD compiler flags
    switch arch
        case {'maci64', 'glnxa64', 'win64'}
            % x86_64: try AVX2 first
            simd_flags = {'-mavx2', '-mfma', '-O3'};
            fprintf('SIMD target: AVX2 + FMA\n');
        case 'maca64'
            % Apple Silicon ARM64: NEON is default
            simd_flags = {'-O3'};
            fprintf('SIMD target: ARM NEON (default on aarch64)\n');
        otherwise
            simd_flags = {'-O3'};
            fprintf('SIMD target: scalar fallback\n');
    end

    % Common flags
    include_flag = ['-I' srcDir];

    % Files to compile: {source_name, output_name}
    mex_files = {
        'binary_search_mex.c',  'binary_search_mex'
        'minmax_core_mex.c',    'minmax_core_mex'
        'lttb_core_mex.c',      'lttb_core_mex'
    };

    fprintf('\n');

    n_success = 0;
    n_fail = 0;

    for i = 1:size(mex_files, 1)
        src_file = fullfile(srcDir, mex_files{i, 1});
        out_name = mex_files{i, 2};

        fprintf('Compiling %s ... ', mex_files{i, 1});

        try
            % Build CFLAGS string
            cflags = ['CFLAGS="$CFLAGS ' strjoin(simd_flags, ' ') '"'];

            mex(cflags, include_flag, ...
                '-outdir', outDir, ...
                '-output', out_name, ...
                src_file);

            fprintf('OK\n');
            n_success = n_success + 1;
        catch e
            fprintf('FAILED\n');
            fprintf('  Error: %s\n', e.message);

            % If AVX2 failed on x86_64, retry with SSE2
            if any(strcmp(arch, {'maci64', 'glnxa64', 'win64'})) && ...
               any(contains(simd_flags, 'mavx2'))
                fprintf('  Retrying with SSE2 fallback ... ');
                try
                    cflags_sse = 'CFLAGS="$CFLAGS -msse2 -O3"';
                    mex(cflags_sse, include_flag, ...
                        '-outdir', outDir, ...
                        '-output', out_name, ...
                        src_file);
                    fprintf('OK (SSE2)\n');
                    n_success = n_success + 1;
                catch e2
                    fprintf('FAILED\n');
                    fprintf('  Error: %s\n', e2.message);
                    n_fail = n_fail + 1;
                end
            else
                n_fail = n_fail + 1;
            end
        end
    end

    fprintf('\n%d/%d MEX files compiled successfully.\n', ...
        n_success, size(mex_files, 1));

    if n_fail > 0
        fprintf('(%d failed — MATLAB fallback will be used for those.)\n', n_fail);
    end
end
