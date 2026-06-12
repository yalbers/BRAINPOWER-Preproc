% %% Welch FFT - Theta Power Analysis
% % BRAINPOWER Study
% % Computes theta power (4-8 Hz) per trial per condition with dB baseline normalization.
% % Conditions: emo_rem, emo_for, neu_rem, neu_for
% % Main effects: emotional (emo_rem + emo_for), neutral (neu_rem + neu_for),
% %               remembered (emo_rem + neu_rem), forgotten (emo_for + neu_for)
% 
% clear
% close all
% 
% %% ===== PATHS =====
% path2EEGsets = 'L:/onderzoeksarchief/22-000_PITA_BS/E_ResearchData/2023_BRAINPOWER/4_analysis/4_EEG data (anl)/BP_(pre)proc_ya2026/1_Preproc_EEG/';
% path2save    = 'L:/onderzoeksarchief/22-000_PITA_BS/E_ResearchData/2023_BRAINPOWER/4_analysis/4_EEG data (anl)/BP_(pre)proc_ya2026/2_EEG_power/';
% if ~exist(path2save, 'dir'), mkdir(path2save); end
% 
% addpath('/Users/yalbers/Documents/MATLAB/eeglab2025.1.0');   % <-- update if needed
% [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
% 
% %% ===== SETTINGS =====
% channels     = {'Fz','FC1','FC2','Cz'};
% theta_band   = [4 8];
% baseline_win = [-500 0];    % ms
% encoding_win = [0 800];     % ms
% 
% % Trigger value for word onset
% word_onset_trig = 64535;
% 
% % Condition labels stored in EEG.event(i).condition (adjust field name if needed)
% cond_labels = {'emo_rem', 'emo_for', 'neu_rem', 'neu_for'};
% 
% %% ===== FIND FILES =====
% files = dir(fullfile(path2EEGsets, '*_2CLEAN.set'));
% nSubj = length(files);
% 
% if nSubj == 0
%     error('No *_2CLEAN.set files found in %s', path2EEGsets);
% end
% 
% fprintf('\nFound %d participant files.\n', nSubj);
% 
% %% ===== PRE-ALLOCATE RESULTS TABLE =====
% % Columns: SubjectID, then theta power per condition and main effects
% varNames = {'SubjectID', ...
%     'theta_emo_rem', 'theta_emo_for', 'theta_neu_rem', 'theta_neu_for', ...
%     'theta_emotional', 'theta_neutral', 'theta_remembered', 'theta_forgotten', ...
%     'n_emo_rem', 'n_emo_for', 'n_neu_rem', 'n_neu_for'};
% 
% % Initialize table
% resultsTable = array2table(nan(nSubj, length(varNames)-1), 'VariableNames', varNames(2:end));
% resultsTable = [cell2table(cell(nSubj,1), 'VariableNames', {'SubjectID'}), resultsTable];

% %% ===== MAIN LOOP =====
% for subj_i = 1:nSubj
% 
%     fname = files(subj_i).name;
%     fprintf('\n=== Processing: %s (%d/%d) ===\n', fname, subj_i, nSubj);
% 
%     % Extract subject ID from filename (everything before _2CLEAN.set)
%     subjID = strrep(fname, '_2CLEAN.set', '');
%     resultsTable.SubjectID{subj_i} = subjID;
% 
%     % Load EEG set
%     EEG = pop_loadset('filename', fname, 'filepath', path2EEGsets);
% 
%     % Convert to double for numerical precision
%     EEG.data = double(EEG.data);
% 
%     % --- Identify channel indices ---
%     chanIdx = zeros(1, length(channels));
%     for c = 1:length(channels)
%         idx = find(strcmpi({EEG.chanlocs.labels}, channels{c}));
%         if isempty(idx)
%             warning('Channel %s not found in subject %s. Skipping.', channels{c}, subjID);
%             chanIdx(c) = NaN;
%         else
%             chanIdx(c) = idx;
%         end
%     end
%     chanIdx = chanIdx(~isnan(chanIdx)); % remove missing channels
% 
%     if isempty(chanIdx)
%         warning('No valid channels for subject %s. Skipping.\n', subjID);
%         continue
%     end
% 
%     % --- Time vector & window indices ---
%     % EEG.times is in ms relative to epoch onset
%     % Epochs should be cut around word onset (trigger 64535)
%     % Expected: epoch from -500 to ~2000 ms (adjust if your epochs differ)
% 
%     times    = EEG.times; % ms
%     bsl_idx  = find(times >= baseline_win(1) & times <= baseline_win(2));
%     enc_idx  = find(times >= encoding_win(1) & times <= encoding_win(2));
% 
%     if isempty(bsl_idx) || isempty(enc_idx)
%         error('Baseline or encoding window not found in epoch times for subject %s.\nCheck that epochs span [-500 2000] ms.', subjID);
%     end
% 
%     % --- FFT settings ---
%     nfft     = EEG.srate * 4;                   % zero-padding for frequency resolution
%     hannw    = hann(length(enc_idx));            % Hann window over encoding window length
%     nOverlap = 0;                                % no overlap for single-window epochs
% 
%     % Frequency vector from pwelch
%     [~, hz_enc] = pwelch(zeros(length(enc_idx),1), hannw, nOverlap, nfft, EEG.srate);
%     theta_hz_idx = find(hz_enc >= theta_band(1) & hz_enc <= theta_band(2));
% 
%     % Baseline: use periodogram (single window, no overlap)
%     hannw_bsl   = hann(length(bsl_idx));
%     [~, hz_bsl] = pwelch(zeros(length(bsl_idx),1), hannw_bsl, 0, nfft, EEG.srate);
%     theta_hz_bsl_idx = find(hz_bsl >= theta_band(1) & hz_bsl <= theta_band(2));
% 
%     % --- Identify word-onset trials and their conditions ---
%     % Event types are formatted as '64535_emo_rem', '64535_emo_for', etc.
%     % We match any type string that starts with '64535_'
%     evtypes      = {EEG.event.type};
%     trig_prefix  = [num2str(word_onset_trig) '_'];
%     isWordOnset  = cellfun(@(x) strncmp(x, trig_prefix, length(trig_prefix)), evtypes);
% 
%     wordOnsetIdx = find(isWordOnset);
%     nTrials      = length(wordOnsetIdx);
% 
%     if nTrials == 0
%         warning('No trigger %d_* found for subject %s. Skipping.\n', word_onset_trig, subjID);
%         continue
%     end
% 
%     fprintf('  Found %d word-onset trials.\n', nTrials);
% 
%     % --- Per-trial theta power ---
%     trial_theta  = nan(nTrials, length(chanIdx)); % encoding window theta power
%     trial_bsl    = nan(nTrials, length(chanIdx)); % baseline theta power
%     trial_cond   = cell(nTrials, 1);              % condition label per trial
% 
%     for tri = 1:nTrials
%         evIdx = wordOnsetIdx(tri);
% 
%         % Parse condition from type string: '64535_emo_rem' -> 'emo_rem'
%         type_str        = EEG.event(evIdx).type;
%         parts           = strsplit(type_str, '_');
%         % Condition is everything after the first token (the trigger number)
%         trial_cond{tri} = strjoin(parts(2:end), '_');  % e.g. 'emo_rem'
% 
%         % Get epoch number for this event
%         epocNum = EEG.event(evIdx).epoch;
% 
%         % Per-channel FFT
%         for ci = 1:length(chanIdx)
%             ch = chanIdx(ci);
% 
%             % --- Encoding window ---
%             sig_enc = EEG.data(ch, enc_idx, epocNum);
%             sig_enc = sig_enc(:); % ensure column vector
% 
%             [pxx_enc, ~] = pwelch(sig_enc, hannw, nOverlap, nfft, EEG.srate);
%             trial_theta(tri, ci) = mean(pxx_enc(theta_hz_idx)); % mean theta power
% 
%             % --- Baseline window ---
%             sig_bsl = EEG.data(ch, bsl_idx, epocNum);
%             sig_bsl = sig_bsl(:);
% 
%             [pxx_bsl, ~] = pwelch(sig_bsl, hannw_bsl, 0, nfft, EEG.srate);
%             trial_bsl(tri, ci) = mean(pxx_bsl(theta_hz_bsl_idx)); % mean baseline theta
%         end
%     end
% 
%     % --- Baseline normalization (dB) ---
%     % dB = 10 * log10(encoding_power / baseline_power)
%     % Average across the channels of interest first, then normalize
%     trial_theta_mean = mean(trial_theta, 2); % average across channels
%     trial_bsl_mean   = mean(trial_bsl, 2);
% 
%     trial_theta_dB   = 10 * log10(trial_theta_mean ./ trial_bsl_mean);
% 
%     % --- Aggregate by condition ---
%     theta_by_cond = struct();
%     n_by_cond     = struct();
%     for c = 1:length(cond_labels)
%         cname = cond_labels{c};
%         cidx  = strcmpi(trial_cond, cname);
%         if any(cidx)
%             theta_by_cond.(cname) = nanmean(trial_theta_dB(cidx));
%             n_by_cond.(cname)     = sum(cidx);
%         else
%             theta_by_cond.(cname) = NaN;
%             n_by_cond.(cname)     = 0;
%             fprintf('  Warning: no trials found for condition %s.\n', cname);
%         end
%     end
% 
%     % --- Main effects (average of sub-conditions) ---
%     % Emotional: emo_rem + emo_for (weighted by trial count)
%     n_emo  = n_by_cond.emo_rem + n_by_cond.emo_for;
%     n_neu  = n_by_cond.neu_rem + n_by_cond.neu_for;
%     n_rem  = n_by_cond.emo_rem + n_by_cond.neu_rem;
%     n_for  = n_by_cond.emo_for + n_by_cond.neu_for;
% 
%     % Weighted mean across sub-conditions (handles unequal trial counts)
%     theta_emotional  = (theta_by_cond.emo_rem * n_by_cond.emo_rem + ...
%                         theta_by_cond.emo_for * n_by_cond.emo_for) / max(n_emo, 1);
%     theta_neutral    = (theta_by_cond.neu_rem * n_by_cond.neu_rem + ...
%                         theta_by_cond.neu_for * n_by_cond.neu_for) / max(n_neu, 1);
%     theta_remembered = (theta_by_cond.emo_rem * n_by_cond.emo_rem + ...
%                         theta_by_cond.neu_rem * n_by_cond.neu_rem) / max(n_rem, 1);
%     theta_forgotten  = (theta_by_cond.emo_for * n_by_cond.emo_for + ...
%                         theta_by_cond.neu_for * n_by_cond.neu_for) / max(n_for, 1);
% 
%     % --- Store in results table ---
%     resultsTable.theta_emo_rem(subj_i)    = theta_by_cond.emo_rem;
%     resultsTable.theta_emo_for(subj_i)    = theta_by_cond.emo_for;
%     resultsTable.theta_neu_rem(subj_i)    = theta_by_cond.neu_rem;
%     resultsTable.theta_neu_for(subj_i)    = theta_by_cond.neu_for;
%     resultsTable.theta_emotional(subj_i)  = theta_emotional;
%     resultsTable.theta_neutral(subj_i)    = theta_neutral;
%     resultsTable.theta_remembered(subj_i) = theta_remembered;
%     resultsTable.theta_forgotten(subj_i)  = theta_forgotten;
%     resultsTable.n_emo_rem(subj_i)        = n_by_cond.emo_rem;
%     resultsTable.n_emo_for(subj_i)        = n_by_cond.emo_for;
%     resultsTable.n_neu_rem(subj_i)        = n_by_cond.neu_rem;
%     resultsTable.n_neu_for(subj_i)        = n_by_cond.neu_for;
% 
%     fprintf('  Theta power (dB): emo_rem=%.3f, emo_for=%.3f, neu_rem=%.3f, neu_for=%.3f\n', ...
%         theta_by_cond.emo_rem, theta_by_cond.emo_for, ...
%         theta_by_cond.neu_rem, theta_by_cond.neu_for);
% 
%     clear EEG
%     ALLEEG(1:end) = [];
% 
% end % subject loop
% 
% %% ===== SAVE RESULTS =====
% fprintf('\n=== Saving results ===\n');
% 
% % Save MATLAB table
% save(fullfile(path2save, 'BP_ThetaPower_results.mat'), 'resultsTable');
% 
% % Save as CSV for easy inspection in Excel/R/Python
% writetable(resultsTable, fullfile(path2save, 'BP_ThetaPower_results.csv'));
% 
% fprintf('Results saved to:\n  %s\n', path2save);
% disp(resultsTable)
% 
% fprintf('\nDone!\n');

%% Power analysis BRAINPOWER - Welch FFT
%  BP_encoding_spectral_power.m
%  Spectral power during encoding (0–800 ms), baseline-normalised
%  (-500 to 0 ms), per condition and per participant.
%
%  Conditions of interest
%    Main effects : emo vs. neu  |  rem vs. for
%    Interactions : emo_rem, emo_for, neu_rem, neu_for
%
%  Trigger format: 64535_emo_rem  (word-onset trigger = 64535)
%  Epochs already span –500 ms to +2000 ms.
%
%  Output saved to path2save:
%    BP_encoding_power.mat  –  struct with all results
% ============================================================

clear; close all;

%% ===== PATHS =====
path2EEGsets = 'L:/onderzoeksarchief/22-000_PITA_BS/E_ResearchData/2023_BRAINPOWER/4_analysis/4_EEG data (anl)/BP_(pre)proc_ya2026/1_Preproc_EEG/';
path2save    = 'L:/onderzoeksarchief/22-000_PITA_BS/E_ResearchData/2023_BRAINPOWER/4_analysis/4_EEG data (anl)/BP_(pre)proc_ya2026/2_EEG_power/';
if ~exist(path2save, 'dir'), mkdir(path2save); end

% Make sure EEGlab is on the path (update as needed)
% initialize eeglab 
addpath('/Users/yalbers/Documents/MATLAB/eeglab2025.1.0') % AANPASSEN NAAR LOKALE PAD NAAR EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab; 

%% ===== SETTINGS =====
baseline_win     = [-500  0  ];   % ms, relative to word onset
encoding_win     = [0     800];   % ms, relative to word onset
word_onset_trig  = 64535;         % numeric part of the trigger

% Condition labels (must match the suffix in EEG.event(i).type)
cond_labels = {'emo_rem', 'emo_for', 'neu_rem', 'neu_for'};

% Welch / FFT settings
%   We compute power per trial (one epoch), so we use a single Hann window
%   the length of the analysis segment and no overlap.
%   nfft is set to the next power of 2 >= segment length for efficiency.

%% ===== FIND FILES =====
files = dir(fullfile(path2EEGsets, '*_2CLEAN.set'));
nSubj = length(files);
if nSubj == 0
    error('No *_2CLEAN.set files found in:\n  %s', path2EEGsets);
end
fprintf('\nFound %d participant file(s).\n', nSubj);

%% ===== PRE-ALLOCATE OUTPUT STRUCTURE =====
% We fill these after reading the first file (to know nFreqs, nChans)
results = struct();

%% ===== MAIN LOOP =====
for subj_i = 1:nSubj

    % ---- Load dataset ----
    fname = files(subj_i).name;
    fprintf('\n[%d/%d] Loading: %s\n', subj_i, nSubj, fname);
    EEG = pop_loadset('filename', fname, 'filepath', path2EEGsets);

    % Cast data to double for numerical precision
    EEG.data = double(EEG.data);

    % Derive subject ID from filename (everything before _2CLEAN)
    subj_id = strrep(fname, '_2CLEAN.set', '');
    results.subj_ids{subj_i} = subj_id;

    % ---- Convert time windows to sample indices ----
    % EEG.times is in ms; find closest samples
    [~, base_start] = min(abs(EEG.times - baseline_win(1)));
    [~, base_end  ] = min(abs(EEG.times - baseline_win(2)));
    [~, enc_start ] = min(abs(EEG.times - encoding_win(1)));
    [~, enc_end   ] = min(abs(EEG.times - encoding_win(2)));

    nBase = base_end - base_start + 1;   % samples in baseline
    nEnc  = enc_end  - enc_start  + 1;   % samples in encoding

    % ---- FFT parameters ----
    srate   = EEG.srate;
    nfft_b  = 2^nextpow2(nBase);         % for baseline segment
    nfft_e  = 2^nextpow2(nEnc);          % for encoding segment
    hannw_b = hann(nBase);
    hannw_e = hann(nEnc);

    % Frequency vectors (pwelch returns 0:srate/nfft:srate/2)
    hz_base = linspace(0, srate/2, nfft_b/2 + 1);
    hz_enc  = linspace(0, srate/2, nfft_e/2 + 1);

    % On first subject: store frequency axis and allocate result arrays
    if subj_i == 1
        results.hz      = hz_enc;
        nFreqs          = length(hz_enc);
        nChans          = EEG.nbchan;
        results.chanlab = {EEG.chanlocs.labels};

        nC = length(cond_labels);
        % Arrays: nSubj x nChans x nFreqs, one per condition
        for ci = 1:nC
            results.(cond_labels{ci}) = nan(nSubj, nChans, nFreqs);
        end
        % Main-effect arrays (averages across paired conditions)
        results.emo = nan(nSubj, nChans, nFreqs);
        results.neu = nan(nSubj, nChans, nFreqs);
        results.rem = nan(nSubj, nChans, nFreqs);
        results.for = nan(nSubj, nChans, nFreqs);
    end

    % ---- Sort trials by condition ----
    % Trigger types are stored as strings like '64535_emo_rem'
    % (adjust the field name below if your events use a different field)
    nTrials = EEG.trials;
    trial_cond = cell(1, nTrials);   % condition label per trial

    for tri = 1:nTrials
        % Find the event in this epoch that carries the word-onset trigger
        epoch_events = EEG.epoch(tri).eventtype;   % cell array of type strings
        if ~iscell(epoch_events)
            epoch_events = {epoch_events};
        end
        for ei = 1:length(epoch_events)
            ev_str = epoch_events{ei};
            % Parse trigger: check that numeric part matches word_onset_trig
            parts = strsplit(num2str(ev_str), '_');
            if str2double(parts{1}) == word_onset_trig && length(parts) >= 3
                trial_cond{tri} = strjoin(parts(2:end), '_');
                break
            end
        end
    end

    % ---- Compute baseline-normalised power per trial per channel ----
    % Power [nChans x nFreqs x nTrials] during encoding,
    % expressed relative to baseline (dB: 10*log10(enc/base))

    enc_pow  = nan(nChans, nFreqs, nTrials);

    fprintf('  Computing power spectra (%d trials) ...\n', nTrials);

    for chani = 1:nChans
        for tri = 1:nTrials
            % Extract segments
            base_seg = EEG.data(chani, base_start:base_end, tri);
            enc_seg  = EEG.data(chani, enc_start:enc_end,   tri);

            % Compute power with pwelch (single window = no overlap)
            [P_base, ~] = pwelch(base_seg(:), hannw_b, 0, nfft_b, srate);
            [P_enc,  ~] = pwelch(enc_seg(:),  hannw_e, 0, nfft_e, srate);

            % Interpolate baseline to encoding frequency resolution if needed
            if nfft_b ~= nfft_e
                P_base_interp = interp1(hz_base, P_base, hz_enc, 'linear', 'extrap');
            else
                P_base_interp = P_base;
            end

            % Baseline-normalise: dB conversion
            enc_pow(chani, :, tri) = 10 * log10( P_enc ./ P_base_interp );
        end
    end

    % ---- Average per condition ----
    for ci = 1:length(cond_labels)
        cl   = cond_labels{ci};
        tidx = strcmp(trial_cond, cl);
        if any(tidx)
            results.(cl)(subj_i, :, :) = mean(enc_pow(:, :, tidx), 3);
        else
            warning('Subject %s: no trials found for condition "%s".', subj_id, cl);
        end
    end

    % ---- Main effects (collapse across the other factor) ----
    % Emotional context
    emo_idx = strcmp(trial_cond, 'emo_rem') | strcmp(trial_cond, 'emo_for');
    neu_idx = strcmp(trial_cond, 'neu_rem') | strcmp(trial_cond, 'neu_for');
    rem_idx = strcmp(trial_cond, 'emo_rem') | strcmp(trial_cond, 'neu_rem');
    for_idx = strcmp(trial_cond, 'emo_for') | strcmp(trial_cond, 'neu_for');

    if any(emo_idx), results.emo(subj_i,:,:) = mean(enc_pow(:,:,emo_idx),3); end
    if any(neu_idx), results.neu(subj_i,:,:) = mean(enc_pow(:,:,neu_idx),3); end
    if any(rem_idx), results.rem(subj_i,:,:) = mean(enc_pow(:,:,rem_idx),3); end
    if any(for_idx), results.for(subj_i,:,:) = mean(enc_pow(:,:,for_idx),3); end

    % ---- Tidy up for next subject ----
    clear EEG enc_pow trial_cond
    ALLEEG(1:end) = [];
end

%% ===== SAVE =====
outfile = fullfile(path2save, 'BP_encoding_power.mat');
fprintf('\nSaving results to:\n  %s\n', outfile);
save(outfile, 'results', '-v7.3');
fprintf('Done.\n');

%% ===== EXPORT TO CSV FOR R =====
% Produces a long-format CSV:
%   subject | condition | channel | frequency_hz | power_db
%
% This is the tidiest format for R (works directly with lme4, ez, afex, etc.)
% One row = one subject x condition x channel x frequency bin combination.
%
% For typical analyses you will want to further average over frequency bands
% (e.g. theta: 4–8 Hz) or electrode clusters in R, so all frequencies and
% channels are kept here and you can filter/summarise in R as needed.

fprintf('\nExporting data to CSV for R...\n');

all_conds = [cond_labels, {'emo','neu','rem','for'}];   % all condition arrays

% Open file and write header
csv_file = fullfile(path2save, 'BP_encoding_power.csv');
fid = fopen(csv_file, 'w');
fprintf(fid, 'subject,condition,channel,frequency_hz,power_db\n');

nSubj_out = length(results.subj_ids);
hz_out    = results.hz;
chans_out = results.chanlab;
nF        = length(hz_out);
nCh       = length(chans_out);

for subj_i = 1:nSubj_out
    subj_str = results.subj_ids{subj_i};

    for ci = 1:length(all_conds)
        cond_str = all_conds{ci};
        pow_mat  = squeeze( results.(cond_str)(subj_i, :, :) ); % nChans x nFreqs

        for chani = 1:nCh
            chan_str = chans_out{chani};

            for fi = 1:nF
                val = pow_mat(chani, fi);
                if ~isnan(val)
                    fprintf(fid, '%s,%s,%s,%.4f,%.6f\n', ...
                        subj_str, cond_str, chan_str, hz_out(fi), val);
                end
            end
        end
    end
    fprintf('  Written subject %d/%d\n', subj_i, nSubj_out);
end

fclose(fid);
fprintf('CSV saved to:\n  %s\n', csv_file);

%% ===== QUICK SANITY PLOT (grand average, all channels, emo vs neu) =====
% Comment out if you do not want this at runtime.
figure('Name', 'Grand average – Emotional context main effect');
hz = results.hz;
GA_emo = squeeze( nanmean(results.emo, 1) );  % nChans x nFreqs
GA_neu = squeeze( nanmean(results.neu, 1) );

% Average over all channels for a single summary curve
plot(hz, mean(GA_emo,1), 'r', 'LineWidth', 1.5); hold on;
plot(hz, mean(GA_neu,1), 'b', 'LineWidth', 1.5);
xlim([1 40]);
xlabel('Frequency (Hz)'); ylabel('Power (dB re baseline)');
legend('Emotional', 'Neutral');
title('Grand-average encoding power: Emo vs Neu (all channels)');
grid on;

%% Figure to check all interaction condition averages
figure;
hz = results.hz;
conds     = {'emo_rem','emo_for','neu_rem','neu_for'};
colors    = {'r','r','b','b'};
linestyle = {'-','--','-','--'};

for ci = 1:4
    GA = squeeze(nanmean(results.(conds{ci}), 1));  % nChans x nFreqs
    plot(hz, mean(GA,1), 'Color', colors{ci}, ...
        'LineStyle', linestyle{ci}, 'LineWidth', 1.5); 
    hold on;
end

xlim([1 40]);
xlabel('Frequency (Hz)'); ylabel('Power (dB re baseline)');
legend(conds); grid on;
title('Grand average encoding power – all conditions');

