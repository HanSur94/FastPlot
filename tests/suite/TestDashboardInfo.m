classdef TestDashboardInfo < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Test)
        function testInfoFileDefaultEmpty(testCase)
            d = DashboardEngine('Test');
            testCase.verifyEqual(d.InfoFile, '');
        end

        function testInfoFileAtConstruction(testCase)
            d = DashboardEngine('Test', 'InfoFile', 'info.md');
            testCase.verifyEqual(d.InfoFile, 'info.md');
        end

        function testInfoFileSetAfterConstruction(testCase)
            d = DashboardEngine('Test');
            d.InfoFile = 'docs/readme.md';
            testCase.verifyEqual(d.InfoFile, 'docs/readme.md');
        end

        function testShowInfoMissingFileWarns(testCase)
            d = DashboardEngine('Test');
            d.InfoFile = 'nonexistent_file_xyz.md';
            % showInfo should warn, not error
            testCase.verifyWarning(@() d.showInfo(), ...
                'DashboardEngine:infoFileNotFound');
        end

        function testShowInfoReadsFile(testCase)
            mdPath = fullfile(testCase.TempDir, 'info.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Test Info\n\nHello world.');
            fclose(fid);

            d = DashboardEngine('Test');
            d.InfoFile = mdPath;
            d.showInfo();
            testCase.addTeardown(@() d.cleanupInfoTempFile());
            testCase.verifyTrue(~isempty(d.InfoTempFile));
            testCase.verifyTrue(exist(d.InfoTempFile, 'file') == 2);
        end

        function testRelativePathResolvesAgainstFilePath(testCase)
            % Create a subdirectory with an md file
            subDir = fullfile(testCase.TempDir, 'sub');
            mkdir(subDir);
            mdPath = fullfile(subDir, 'info.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Info');
            fclose(fid);

            d = DashboardEngine('Test');
            d.InfoFile = 'info.md';
            % Simulate having been loaded from sub/dashboard.json
            % FilePath is SetAccess=private, so we save+load to set it
            dashPath = fullfile(subDir, 'dash.json');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], 'Content', 'x');
            d.save(dashPath);

            d2 = DashboardEngine.load(dashPath);
            d2.InfoFile = 'info.md';
            % Should resolve info.md relative to sub/
            d2.showInfo();
            testCase.addTeardown(@() d2.cleanupInfoTempFile());
            testCase.verifyTrue(exist(d2.InfoTempFile, 'file') == 2);
        end

        function testRelativePathUnsavedResolvesAgainstPwd(testCase)
            mdPath = fullfile(pwd, 'test_info_unsaved_xyz.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Unsaved test');
            fclose(fid);
            testCase.addTeardown(@() delete(mdPath));

            d = DashboardEngine('Test');
            d.InfoFile = 'test_info_unsaved_xyz.md';
            % FilePath is empty (unsaved), should resolve against pwd
            d.showInfo();
            testCase.addTeardown(@() d.cleanupInfoTempFile());
            testCase.verifyTrue(exist(d.InfoTempFile, 'file') == 2);
        end
    end
end
