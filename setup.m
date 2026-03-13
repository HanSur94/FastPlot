function setup()
%SETUP Add libraries to path and compile MEX files (including mksqlite/SQLite).
%   SETUP() locates the project root (the directory containing this
%   file), then adds the FastPlot, SensorThreshold, and EventDetection
%   library folders to the MATLAB search path using addpath. It then
%   compiles all MEX files, including mksqlite for SQLite-backed
%   DataStore support.
%
%   Run this once per MATLAB session, or add a call to your startup.m
%   for automatic initialization.
%
%   The following directories are added:
%     <project_root>/libs/FastPlot
%     <project_root>/libs/SensorThreshold
%     <project_root>/libs/EventDetection
%     <project_root>/libs/Dashboard
%
%   MEX compilation includes:
%     - SIMD-optimized downsampling kernels (AVX2/NEON)
%     - mksqlite (SQLite3 MEX interface for large-dataset disk storage)
%
%   If libsqlite3-dev is not installed, mksqlite is skipped and
%   FastPlotDataStore falls back to binary file storage.
%
%   Prerequisites for SQLite support:
%     Ubuntu/Debian: sudo apt install libsqlite3-dev
%     macOS:         brew install sqlite3
%     Windows:       download from https://sqlite.org/download.html
%
%   Example:
%     setup();   % adds libraries to path, compiles MEX; prints status
%
%   See also addpath, FastPlotDefaults, build_mex, FastPlotDataStore.

    % Determine the project root from this file's location
    root = fileparts(mfilename('fullpath'));

    % Add library directories to the MATLAB search path
    addpath(fullfile(root, 'libs', 'FastPlot'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    addpath(fullfile(root, 'libs', 'EventDetection'));
    addpath(fullfile(root, 'libs', 'Dashboard'));
    fprintf('FastPlot + SensorThreshold + EventDetection + Dashboard libraries added to path.\n');

    % Ensure SQLite3 dev libraries are installed before compiling MEX
    ensure_sqlite3();

    % Compile all MEX files (SIMD kernels + mksqlite)
    fprintf('\n--- Compiling MEX files ---\n');
    build_mex();
end


function ensure_sqlite3()
%ENSURE_SQLITE3 Attempt to install libsqlite3-dev if not already present.
%   Detects the platform and package manager, then installs the SQLite3
%   development headers/libraries so that mksqlite and the SQLite-backed
%   MEX files can compile successfully. Requires appropriate permissions
%   (e.g. sudo access on Linux). If installation fails or the platform
%   is not recognized, a warning is printed and build_mex will fall back
%   to binary file storage.

    % Quick check: if sqlite3.h is already usable, nothing to do
    test_c = fullfile(tempdir(), 'sqlite3_setup_check.c');
    fid = fopen(test_c, 'w');
    if fid ~= -1
        fprintf(fid, '#include <sqlite3.h>\nint main(){sqlite3_libversion();return 0;}\n');
        fclose(fid);
        [status, ~] = system(sprintf('cc -o /dev/null %s -lsqlite3 2>/dev/null', test_c));
        delete(test_c);
        if status == 0
            fprintf('SQLite3 dev libraries: found.\n');
            return;
        end
    end

    fprintf('SQLite3 dev libraries: not found. Attempting to install...\n');

    installed = false;

    if isunix && ~ismac
        % Linux — try apt (Debian/Ubuntu), then dnf (Fedora/RHEL), then pacman (Arch)
        [has_apt, ~] = system('which apt-get 2>/dev/null');
        [has_dnf, ~] = system('which dnf 2>/dev/null');
        [has_pacman, ~] = system('which pacman 2>/dev/null');

        if has_apt == 0
            fprintf('  Detected apt package manager.\n');
            [s, out] = system('sudo apt-get install -y libsqlite3-dev 2>&1');
            if s == 0
                installed = true;
            else
                fprintf('  apt install failed:\n  %s\n', out);
            end
        elseif has_dnf == 0
            fprintf('  Detected dnf package manager.\n');
            [s, out] = system('sudo dnf install -y sqlite-devel 2>&1');
            if s == 0
                installed = true;
            else
                fprintf('  dnf install failed:\n  %s\n', out);
            end
        elseif has_pacman == 0
            fprintf('  Detected pacman package manager.\n');
            [s, out] = system('sudo pacman -S --noconfirm sqlite 2>&1');
            if s == 0
                installed = true;
            else
                fprintf('  pacman install failed:\n  %s\n', out);
            end
        else
            fprintf('  No supported package manager found (apt, dnf, pacman).\n');
        end
    elseif ismac
        % macOS — try Homebrew
        [has_brew, ~] = system('which brew 2>/dev/null');
        if has_brew == 0
            fprintf('  Detected Homebrew.\n');
            [s, out] = system('brew install sqlite3 2>&1');
            if s == 0
                installed = true;
            else
                fprintf('  brew install failed:\n  %s\n', out);
            end
        else
            fprintf('  Homebrew not found. Install Homebrew first or manually install sqlite3.\n');
        end
    elseif ispc
        fprintf('  Automatic installation is not supported on Windows.\n');
        fprintf('  Please download SQLite from: https://sqlite.org/download.html\n');
    end

    if installed
        fprintf('  SQLite3 dev libraries installed successfully.\n');
    else
        fprintf('  Could not install SQLite3 automatically.\n');
        fprintf('  Manual installation:\n');
        fprintf('    Ubuntu/Debian: sudo apt install libsqlite3-dev\n');
        fprintf('    Fedora/RHEL:   sudo dnf install sqlite-devel\n');
        fprintf('    Arch Linux:    sudo pacman -S sqlite\n');
        fprintf('    macOS:         brew install sqlite3\n');
        fprintf('    Windows:       https://sqlite.org/download.html\n');
        fprintf('  (build_mex will skip SQLite MEX files and use binary fallback)\n');
    end
end
