classdef ClusterConfig
%CLUSTERCONFIG Resolve the cluster-mode configuration for v4.0.
%
%   Determines whether this MATLAB session is operating in cluster mode
%   (shared filesystem) or single-user mode, and validates the configured
%   shared root path.
%
%   ClusterConfig.resolve()             -> struct (SharedRoot='', IsClusterMode=false)
%   ClusterConfig.resolve(struct('SharedRoot', '/mnt/share')) -> struct (validated)
%
%   Precedence: opts.SharedRoot > getenv('FASTSENSE_SHARED_ROOT') > '' (single-user).
%
%   Config struct fields:
%     .SharedRoot    — char; path to shared filesystem root ('' in single-user mode)
%     .IsClusterMode — logical; true iff SharedRoot is non-empty and exists
%
%   Errors:
%     Concurrency:sharedRootUnreachable — SharedRoot non-empty but not an existing folder
%
%   Warnings (one-time per session):
%     Concurrency:smbOplockDetected — checkSharedConfig canary mismatch (Pitfall 14)
%
%   See also SharedPaths, ClusterIdentity.

    methods (Static)

        function cfg = resolve(opts)
            %RESOLVE Resolve and validate the cluster-mode configuration.
            %
            %   cfg = ClusterConfig.resolve() — single-user mode (SharedRoot='').
            %   cfg = ClusterConfig.resolve(opts) — validates opts.SharedRoot if set.
            %
            %   Input:
            %     opts — (optional) struct; may have .SharedRoot field
            %   Output:
            %     cfg — struct with .SharedRoot (char) and .IsClusterMode (logical)
            if nargin < 1 || isempty(opts)
                opts = struct();
            end
            root = SharedPaths.resolveRoot(opts);
            cfg = struct();
            cfg.SharedRoot    = root;
            cfg.IsClusterMode = ~isempty(root);
            if cfg.IsClusterMode && ~isfolder(root)
                error('Concurrency:sharedRootUnreachable', ...
                    'SharedRoot ''%s'' is not an existing folder.', root);
            end
        end

        function result = checkSharedConfig(sharedRoot)
            %CHECKSHAREDCONFIG Best-effort SMB-oplock smoke test (Pitfall 14 detection).
            %
            %   result = ClusterConfig.checkSharedConfig(sharedRoot)
            %
            %   Performs a canary write-and-immediate-read against a small probe file in
            %   <sharedRoot>/.oplock_canary/ to detect gross filesystem incoherency that
            %   suggests SMB oplocks (or similar client-side caching) are corrupting
            %   reads.  This is BEST-EFFORT — false negatives are expected (oplocks
            %   typically misbehave only under multi-process pressure, which a single-
            %   process smoke test cannot reproduce).
            %
            %   Returns:
            %     result.ok        — logical; true if all canary bytes round-tripped
            %     result.evidence  — struct with diagnostic fields:
            %                          .bytesWritten, .bytesRead, .matches (logical),
            %                          .sharedRoot, .canaryPath, .elapsedSec
            %     result.warnings  — cell of warning strings (operator-readable)
            %
            %   On mismatch, emits a one-time warning('Concurrency:smbOplockDetected', ...)
            %   per MATLAB session (guarded by a persistent flag).  NEVER throws — this is
            %   advisory and must not block pipeline startup.
            %
            %   Phase 1033 will wire this method into FastSenseCompanion startup; Phase
            %   1032 only ships the method itself.

            persistent warningEmitted_     %#ok<USENS>

            result = struct('ok', false, 'warnings', {{}}, 'evidence', struct());
            result.evidence.sharedRoot   = '';
            result.evidence.canaryPath   = '';
            result.evidence.bytesWritten = -1;
            result.evidence.bytesRead    = -1;
            result.evidence.matches      = false;
            result.evidence.elapsedSec   = 0;

            if nargin < 1 || isempty(sharedRoot) || ~ischar(sharedRoot)
                result.warnings{end+1} = 'sharedRoot is empty or not a char';
                return;
            end

            result.evidence.sharedRoot = sharedRoot;

            if ~isfolder(sharedRoot)
                result.warnings{end+1} = sprintf('sharedRoot ''%s'' is not a folder', sharedRoot);
                return;
            end

            try
                canaryDir = fullfile(sharedRoot, '.oplock_canary');
                if ~isfolder(canaryDir), mkdir(canaryDir); end
                canaryPath = fullfile(canaryDir, sprintf('canary_%d_%d.bin', ...
                    feature('getpid'), round(rand() * 1e6)));
                result.evidence.canaryPath = canaryPath;

                tStart = tic;

                % Write a deterministic 1024-byte pattern.
                payload = uint8(mod(1:1024, 256));
                fid = fopen(canaryPath, 'wb');
                if fid < 0
                    result.warnings{end+1} = sprintf('fopen wb failed on canary path: %s', canaryPath);
                    return;
                end
                fwrite(fid, payload, 'uint8');
                fclose(fid);
                result.evidence.bytesWritten = numel(payload);

                % Immediate read-back (no sleep — any oplock-induced cache incoherency
                % would surface here on the oplock-break boundary).
                fid = fopen(canaryPath, 'rb');
                if fid < 0
                    result.warnings{end+1} = sprintf('fopen rb failed on canary path: %s', canaryPath);
                    return;
                end
                readback = fread(fid, [1, Inf], 'uint8=>uint8');
                fclose(fid);
                result.evidence.bytesRead    = numel(readback);
                result.evidence.elapsedSec   = toc(tStart);

                % Verify the canary bytes round-tripped correctly.
                if numel(readback) ~= numel(payload)
                    result.warnings{end+1} = sprintf( ...
                        'TORN READ: wrote %d bytes, read %d — possible SMB oplock caching', ...
                        numel(payload), numel(readback));
                elseif ~isequal(readback, payload)
                    result.warnings{end+1} = ...
                        'TORN READ: byte pattern mismatch — possible SMB oplock caching';
                else
                    result.evidence.matches = true;
                    result.ok = true;
                end

                % Cleanup canary file (always, even on mismatch).
                try
                    delete(canaryPath);
                catch
                    % non-fatal
                end

            catch ME
                result.warnings{end+1} = sprintf('checkSharedConfig probe caught: %s', ME.message);
                % best-effort: probe failure does not mean oplocks are present
                result.ok = false;
            end

            % One-time warning per MATLAB session on torn-read detection.
            if ~result.ok && isempty(warningEmitted_)
                warningEmitted_ = true;
                warning('Concurrency:smbOplockDetected', ...
                    ['SMB oplock canary smoke test FAILED on ''%s''.\n', ...
                     'This may indicate filesystem caching corruption (SMB oplocks, NFS attribute cache).\n', ...
                     'Operational fix: disable oplocks on the EventStore directory.\n', ...
                     'Windows Server: Set-SmbServerConfiguration -EnableLeasing $false\n', ...
                     'Samba: oplocks = no in smb.conf per-share section.\n', ...
                     'See PITFALLS.md Pitfall 14 and Phase 1033 cluster-setup README for details.'], ...
                    sharedRoot);
            end
        end

    end
end
