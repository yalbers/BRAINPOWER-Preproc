% --------------------------------------------------------------------- %
%   EEG PREPROCESSING
% --------------------------------------------------------------------- %
%
% Description:  Matlab-script to pre-process Biosemi EEG data
%             - Study name: BRAINPOWER (UU lab-study)
%             - Measure/instrument: Biosemi 32-EEG-channel recordings
%             - Data type: EEG time series with trigger events (time stamps)
%             - Design: within-subjects cross-over, 2 timepoints (sham vs. real 5Hz-tACS)
%
% Required toolbox:
% EEGLAB (used: version 2024.2)
%
% Notes: 
% * Alleen sham stimulatie gebruiken + pp 213 niet gebruiken --> 2x actieve stimulatie 
%
% Date:             April 2026
% Matlab version:   2024b
%
% --------------------------------------------------------------------- %

%% Clear workspace

clear
close all


%% Initialize

% initialize eeglab 
addpath('/Users/yalbers/Documents/MATLAB/eeglab2025.1.0') % AANPASSEN NAAR LOKALE PAD NAAR EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab; 



%% Set paths and subject IDs

% find path name to research folder structure (RFS)
path2RFS = 'L:/onderzoeksarchief/22-000_PITA_BS/E_ResearchData/2023_BRAINPOWER/3_raw_data/2_Research data/'; % ENTER YOUR PATH TO RFS. End with slash ('/' on Mac, '\' on Windows)

% set other paths 
path2data    = [path2RFS '4_EEG data/'];
path2EEGsets = [path2RFS '5_EEG sets/'];
path2save    = [path2RFS '6_Preproc EEG data/'];

% enter subject names
subj_list =[135	192 203	218	252	298	315	316	323	353	362	372 ...
            385 404	455	468	505	537	547 576	583	637	674	705	758	...
            763 775	847	867	922	968 996	];
sessions  = [1 2];

% enter filenames
rec1 = 'restingstate-pretACS-';
rec2 = 'eFRT_encoding_';
rec3 = 'restingstate_posttACS-';
rec4 = 'eFRT_retrieval-';
file_type = {rec1, rec2, rec3, rec4};

% % --- EEG trigger codebook: ---
% % Original trigger codes
% StartRec        = 254;
% StopRec         = 255;
% 
% % resting-state EEG
% EyesOpenOnset    = 1;
% EyesOpenOffset   = 2;
% EyesClosedOnset  = 3;
% EyesClosedOffset = 4;
% 
% % tACS-EEG
% start_tACS      = 5; %(2:20) identical to stop_EEG minus(1:19)
% stop_tACS       = 6; %(1:20) identical to start_EEG (1:20)
% start_EEG       = 7;
% stop_EEG        = 8;
% post_tACS_EEG   = 9;
% 
% % Memory task encoding:
% Resume              = 253;
% ITIOnset            = 20; % Fixation onset
% ITIOffset           = 21;
% StimContextOnset    = 22; % Onset context stimulus
% StimFaceOnset       = 23; % Onset face stimulus
% StimOffset          = 24; % Offset context + face stimulus
% 
% % Memory task retrieval:
% con_StimOnset       = 25; % Onset context + face stimulus; congruent trail
% incon_StimOnset     = 26; % Onset context + face stimulus; incongruent trail
% new_StimOnset       = 27; % Onset context + face stimulus; new trial
% StimOffset          = 28; % Offset context + face stimulus
% StimOld             = 29; % this combinations has been presented before
% StimNew             = 30; % this combinations has not been presented before
% Hit_EEG             = 31; % Correctly recognizing something as 'old'
% FA_EEG              = 32; % Incorrectly recognizing something as 'new'
% miss_EEG            = 33; % incorrectly recognizing old as new
% corej_EEG           = 34; % correctly recognizing new as new

%% Preprocessing step 1: re-reference, downsample, filter, VEOG/HEOG

% Which task (file type) you want to analyze?
fileno = 2;

% ~~~~ VOOR 1 DATASET (voorbeeld): ~~~~~ 
subjectID_n1 = 775;
session_n1   = 2;
name_of_set  = sprintf('%s%i-%i.bdf', file_type{fileno}, subjectID_n1, session_n1);
fileName     = fullfile(path2data, name_of_set);

% -- Load raw bdf data file via EEGlab
EEG = pop_biosig( fileName ); % REQUIRES BIOSIG EXTENSION

% -- Enter data to the EEG structure
EEG.filename = fileName;
EEG.setname  = name_of_set;
EEG.subject  = subjectID_n1;
EEG.session  = session_n1;

% % -- Remove non-recorded channels: F3 F4 (tACS electrode locations) and EXG7 EXG8
% EEG = pop_select(EEG, 'nochannel', {'F3', 'F4', 'EXG7', 'EXG8'});
% 
% % -- Re-code events [Why? BioSemi/Computer settings resulted in changes in the recorded trigger codes relative to the originally programmed triggers codes. These changes are unfortunately not exactly the same across subjects.]
% % remove added trigger text like 'condition' and 'artifact'
% for fi = 1:length(EEG.event)
%     EEG.event(fi).type = string(EEG.event(fi).type);
% end
% 
% for ev_i = 1:length({EEG.event.type})
%     EEG.event(ev_i).type = strrep( EEG.event(ev_i).type, 'condition ', '' );
%     EEG.event(ev_i).type = strrep( EEG.event(ev_i).type, 'artifact', '' );
% end
% 
% % remove trigger 64769
% types = {EEG.event.type};
% 
% trig_64768 = find(cellfun(@(x) contains(strtrim(x), '64768'), types));
% 
% EEG = pop_editeventvals(EEG, 'delete', trig_64768);
% EEG = eeg_checkset(EEG);
% 
% % Re-reference to avg mastoids
% mastoid1 = find(strcmpi( {EEG.chanlocs.labels}, 'EXG5' ));
% mastoid2 = find(strcmpi( {EEG.chanlocs.labels}, 'EXG6' ));
% EEG      = pop_reref( EEG, [mastoid1 mastoid2]); %re-references to the average of 2 channels
% 
% % Downsample & Filter
% EEG      = pop_resample( EEG, 256); % Downsample the data from 2048 to 256 Hz
% 
% % Filter
% % Output:'EEG' contains the filtered EEGLAB structure, 'com' contains the history string (the matlab command), 'b' contains the filter coefficients (plot to see the filter) 
% [EEG, com, b] = pop_eegfiltnew(EEG,'locutoff',0.5); 
% [EEG, com, b] = pop_eegfiltnew(EEG,'hicutoff',34);
% 
% %EEG      = pop_basicfilter( EEG, 1:32 , 'Cutoff',  0.5, 'Design', 'butter', 'Filter', 'highpass', 'Order',  4 ); % Format: pop_basicfilter( EEG, chanArray, parameters )
% %EEG      = pop_basicfilter( EEG, 1:32 , 'Cutoff',   35, 'Design', 'butter', 'Filter',  'lowpass', 'Order',  4 ); % IIR Butterworth filters highpass 0.5 Hz, lowpass 35 Hz, filter order 4 (-24 dB rolloff).
% 
% % Create eye channel bipolar signals
% EOG_ch   = find(strcmpi({EEG.chanlocs.labels},'EXG1')):find(strcmpi({EEG.chanlocs.labels},'EXG4')); % Find indices EOG electrodes (EXG1, EXG2, EXG3, EXG4) & EEG scalp electrodes
% EEG_ch   = 1:EOG_ch(1)-1;
% EEG      = pop_reref(EEG, EOG_ch(2),'exclude',[EEG_ch, EOG_ch(3:4)] ); % For vertical eye movements: re-reference channel below left eye (EXG1) to channel above left eye (EXG2):
% EOG_ch   = find(strcmpi( {EEG.chanlocs.labels},'EXG1')):find(strcmpi( {EEG.chanlocs.labels},'EXG4')); % Find indices EOG electrodes (EXG1, EXG2, EXG3, EXG4) & EEG scalp electrodes
% EEG      = pop_reref(EEG, EOG_ch(2),'exclude',[EEG_ch, EOG_ch(1)] ); % For horizontal eye movements: re-reference channel next to left eye. (EXG3) to channel next to right eye (EXG4):
% EEG.chanlocs( EOG_ch(1) ).labels = 'VEOG'; % EXG1 is now the bipolar VEOG channel. Change channel name.
% EEG.chanlocs( EOG_ch(2) ).labels = 'HEOG'; % EXG3 is now the bipolar HEOG channel. Change channel name.
% 
% % Save
% fprintf('\n****\nSave pre-processed subject %i session %i\n****\n\n', subjectID_n1, session_n1);
% SaveName = [file_type{fileno} num2str(subjectID_n1) '-' num2str(session_n1) '_PreprocEEG.set'];
% EEG = pop_saveset( EEG, 'filename',SaveName,'filepath', path2EEGsets );




% ~~~~~ HERHALING IN LOOP: ~~~~~

error_count = 0;
error_files = {};

% Which task (file type) you want to analyze?
fileno = 2;

% Loop over files
for subj_i = 1:length(subj_list)
    for sess_i = 1:length(sessions)

        fprintf('\n****\nStart processing subject %i session %i\n****\n\n', subj_list(subj_i), sessions(sess_i));
        fileName = fullfile(path2data, [file_type{fileno} num2str(subj_list(subj_i)) '-' num2str(sess_i) '.bdf']);
        
        try

            % -- Load raw bdf data file via EEGlab
            EEG = pop_biosig( fileName );

             % -- Enter data to the EEG structure
            EEG.filename = fileName;
            EEG.setname  = name_of_set;
            EEG.subject  = subj_list(subj_i);
            EEG.session  = sess_i;

            % -- Remove non-recorded channels: F3 F4 (tACS electrode locations) and EXG7 EXG8
            EEG = pop_select(EEG, 'nochannel', {'F3', 'F4', 'EXG7', 'EXG8'});

            % -- Re-code events [Why? BioSemi/Computer settings resulted in changes in the recorded trigger codes relative to the originally programmed triggers codes. These changes are unfortunately not exactly the same across subjects.]
            % remove added trigger text like 'condition' and 'artifact'
            for fi = 1:length(EEG.event)
                EEG.event(fi).type = string(EEG.event(fi).type);
            end

            for ev_i = 1:length({EEG.event.type})
                EEG.event(ev_i).type = strrep( EEG.event(ev_i).type, 'condition ', '' );
                EEG.event(ev_i).type = strrep( EEG.event(ev_i).type, 'artifact', '' );
            end

            % remove trigger 64768
            types = {EEG.event.type};

            trig_64768 = find(cellfun(@(x) contains(strtrim(x), '64768'), types));

            EEG = pop_editeventvals(EEG, 'delete', trig_64768);
            EEG = eeg_checkset(EEG);

            % Re-reference to avg mastoids
            mastoid1 = find(strcmpi( {EEG.chanlocs.labels}, 'EXG5' ));
            mastoid2 = find(strcmpi( {EEG.chanlocs.labels}, 'EXG6' ));
            EEG      = pop_reref( EEG, [mastoid1 mastoid2]); %re-references to the average of 2 channels

            % Downsample & Filter
            EEG      = pop_resample( EEG, 256); % Downsample the data from 2048 to 256 Hz
            [EEG, com, b] = pop_eegfiltnew(EEG,'locutoff',0.5); 
            [EEG, com, b] = pop_eegfiltnew(EEG,'hicutoff',34);
            %EEG      = pop_basicfilter( EEG, 1:32 , 'Cutoff',  0.5, 'Design', 'butter', 'Filter', 'highpass', 'Order',  4 ); % Format: pop_basicfilter( EEG, chanArray, parameters )
            %EEG      = pop_basicfilter( EEG, 1:32 , 'Cutoff',   35, 'Design', 'butter', 'Filter',  'lowpass', 'Order',  4 ); % IIR Butterworth filters highpass 0.5 Hz, lowpass 35 Hz, filter order 4 (-24 dB rolloff).

            % Create eye channel bipolar signals
            EOG_ch   = find(strcmpi({EEG.chanlocs.labels},'EXG1')):find(strcmpi({EEG.chanlocs.labels},'EXG4')); % Find indices EOG electrodes (EXG1, EXG2, EXG3, EXG4) & EEG scalp electrodes
            EEG_ch   = 1:EOG_ch(1)-1;
            EEG      = pop_reref(EEG, EOG_ch(2),'exclude',[EEG_ch, EOG_ch(3:4)] ); % For vertical eye movements: re-reference channel below left eye (EXG1) to channel above left eye (EXG2):
            EOG_ch   = find(strcmpi( {EEG.chanlocs.labels},'EXG1')):find(strcmpi( {EEG.chanlocs.labels},'EXG4')); % Find indices EOG electrodes (EXG1, EXG2, EXG3, EXG4) & EEG scalp electrodes
            EEG      = pop_reref(EEG, EOG_ch(2),'exclude',[EEG_ch, EOG_ch(1)] ); % For horizontal eye movements: re-reference channel next to left eye. (EXG3) to channel next to right eye (EXG4):
            EEG.chanlocs( EOG_ch(1) ).labels = 'VEOG'; % EXG1 is now the bipolar VEOG channel. Change channel name.
            EEG.chanlocs( EOG_ch(2) ).labels = 'HEOG'; % EXG3 is now the bipolar HEOG channel. Change channel name.

            % Save
            fprintf('\n****\nSave pre-processed subject %i session %i\n****\n\n', subj_list(subj_i), sessions(sess_i));
            SaveName = [file_type{fileno} num2str(subj_list(subj_i)) '-' num2str(sess_i) '_PreprocEEG.set'];
            EEG = pop_saveset( EEG, 'filename',SaveName,'filepath', path2EEGsets );

            clear EEG
            ALLEEG(1:end) = [];

        catch ME
            error_count = error_count + 1;
            error_files{end+1} = fileName;

            fprintf('\n!!!!!!!! ERROR !!!!!!!!\n');
            fprintf('Bestand: %s\n', fileName);
            fprintf('Subject: %i | Session: %i\n', subj_list(subj_i), sess_i);
            fprintf('Error message: %s\n', ME.message);
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!\n\n');

            % Zorg dat EEG leeg is zodat volgende iteratie niet crasht
            if exist('EEG','var')
                clear EEG
            end

            ALLEEG(1:end) = [];

            continue; % ga door met volgende file
        end
    end
end

%% PIPELINE: recode → clean → fix 64535 → fix 64537 → split emo/neu + QC

% Which task (file type) you want to analyze?
fileno = 2;

files = dir(fullfile(path2EEGsets, '*sham*.set'));

trialinfo_all = readtable('Opgeschoonde BP data.xlsx');

qc_issues = {};

for fi = 1:length(files)

    try
        fileName = files(fi).name;
        fprintf('\nProcessing: %s\n', fileName);

        EEG = pop_loadset('filename', fileName, 'filepath', files(fi).folder);

        % STEP 0: RECODE EVENTS (jouw originele code)

        for i = 1:length(EEG.event)

            type = strtrim(string(EEG.event(i).type));

            if type == "64792"
                EEG.event(i).type = "64536";
            elseif type == "64794"
                EEG.event(i).type = "64538";
            elseif type == "64791"
                EEG.event(i).type = "64535";
            elseif type == "64793"
                EEG.event(i).type = "64537";
            end

        end

        EEG = eeg_checkset(EEG);

        % STEP 1: REMOVE DUPLICATES

        tol = 5;
        targetCodes = {'64538','64535','64537'};

        for c = 1:length(targetCodes)

            code = targetCodes{c};
            idx = find(strcmp({EEG.event.type}, code));

            if length(idx) <= 1
                continue
            end

            lat = [EEG.event(idx).latency];
            [lat, sortIdx] = sort(lat);
            idx = idx(sortIdx);

            keep = true(size(idx));

            for i = 2:length(idx)
                if abs(lat(i) - lat(i-1)) <= tol
                    keep(i) = false;
                end
            end

            EEG.event(idx(~keep)) = [];
        end

        EEG = eeg_checkset(EEG, 'eventconsistency');

        % STEP 2: FIX 64535

        srate = EEG.srate;
        offset_samples = round(0.600 * srate);
        tol = 5;

        eventTypes = {EEG.event.type};
        eventLatencies = [EEG.event.latency];

        idx_64538 = find(strcmp(eventTypes, '64538'));
        idx_64535 = find(strcmp(eventTypes, '64535'));

        added_count = 0;

        for i = 1:length(idx_64538)

            lat_38 = eventLatencies(idx_64538(i));
            target_lat = lat_38 + offset_samples;

            existing_64535_lats = eventLatencies(idx_64535);

            if isempty(existing_64535_lats) || all(abs(existing_64535_lats - target_lat) > tol)

                newEvent = EEG.event(1);
                newEvent.type = '64535';
                newEvent.latency = target_lat;

                if isfield(newEvent,'urevent')
                    newEvent.urevent = [];
                end

                EEG.event(end+1) = newEvent;
                added_count = added_count + 1;
            end
        end

        [~, sortIdx] = sort([EEG.event.latency]);
        EEG.event = EEG.event(sortIdx);

        EEG = eeg_checkset(EEG, 'eventconsistency');

        eventTypes = {EEG.event.type};
        fprintf('64535 count: %d (+%d added)\n', ...
            sum(strcmp(eventTypes,'64535')), added_count);

        % STEP 3: FIX 64537

        srate = EEG.srate;
        offset_samples = round(0.800 * srate);
        tol = 5;

        eventTypes = {EEG.event.type};
        eventLatencies = [EEG.event.latency];

        idx_64535 = find(strcmp(eventTypes, '64535'));

        added_count_37 = 0;

        for i = 1:length(idx_64535)

            lat_35 = eventLatencies(idx_64535(i));
            target_lat = lat_35 + offset_samples;

            eventTypes = {EEG.event.type};
            eventLatencies = [EEG.event.latency];

            existing_64537_lats = eventLatencies(strcmp(eventTypes,'64537'));

            if isempty(existing_64537_lats) || all(abs(existing_64537_lats - target_lat) > tol)

                newEvent = EEG.event(1);
                newEvent.type = '64537';
                newEvent.latency = target_lat;

                if isfield(newEvent,'urevent')
                    newEvent.urevent = [];
                end

                EEG.event(end+1) = newEvent;
                added_count_37 = added_count_37 + 1;
            end
        end

        [~, sortIdx] = sort([EEG.event.latency]);
        EEG.event = EEG.event(sortIdx);

        EEG = eeg_checkset(EEG, 'eventconsistency');

        eventTypes = {EEG.event.type};
        fprintf('64537 count: %d (+%d added)\n', ...
            sum(strcmp(eventTypes,'64537')), added_count_37);

        % STEP 4: SPLIT 64535 → EMO / NEU

        tokens = regexp(fileName, '_(\d+)-', 'tokens');
        subID = str2double(tokens{1}{1});

        trialinfo = trialinfo_all(trialinfo_all.SubjectID == subID, :);

        idx = find(strcmp({EEG.event.type}, '64535'));

        if length(idx) ~= height(trialinfo)
            error('Mismatch in aantal trials voor subject %d', subID);
        end

        for k = 1:length(idx)

            cond = trialinfo.Trialtype_Emotion{k};

            if strcmpi(cond, 'Emo')
                EEG.event(idx(k)).type = "64535_emo";
            elseif strcmpi(cond, 'Neu')
                EEG.event(idx(k)).type = "64535_neu";
            end
        end

        EEG = eeg_checkset(EEG);

        % FINAL QC CHECK

        eventTypes = {EEG.event.type};

        count_64535 = sum(strcmp(eventTypes,'64535_emo')) + ...
                      sum(strcmp(eventTypes,'64535_neu'));

        count_64537 = sum(strcmp(eventTypes,'64537'));

        issues = {};

        if count_64535 ~= 20
            issues{end+1} = sprintf('64535 count = %d (expected 20)', count_64535);
        end

        if count_64537 ~= 20
            issues{end+1} = sprintf('64537 count = %d (expected 20)', count_64537);
        end

        if count_64535 ~= height(trialinfo)
            issues{end+1} = sprintf('Trialinfo mismatch (%d vs %d)', ...
                count_64535, height(trialinfo));
        end

        if ~isempty(issues)
            qc_issues{end+1} = sprintf('%s --> %s', ...
                fileName, strjoin(issues, ' | '));
        end

        % Save

        SaveName = strrep(fileName, '.set', '_FINAL.set');

        EEG = pop_saveset(EEG, ...
            'filename', SaveName, ...
            'filepath', files(fi).folder);

        fprintf('Saved: %s\n', SaveName);

        clear EEG

    catch ME
        fprintf('\nERROR in %s:\n%s\n', fileName, ME.message);
        qc_issues{end+1} = sprintf('%s --> ERROR: %s', fileName, ME.message);

        if exist('EEG','var'); clear EEG; end
        continue;
    end
end

% Final summary

fprintf('\n===== FINAL QC SUMMARY =====\n');

if isempty(qc_issues)
    fprintf('All files OK\n');
else
    fprintf('Problems found in %d files:\n\n', length(qc_issues));

    for i = 1:length(qc_issues)
        fprintf('%s\n', qc_issues{i});
    end
end
%% Trim the data

% Which task (file type) you want to analyze?
fileno = 2;

files = dir(fullfile(path2EEGsets, '*_FINAL.set'));

for fi = 1:length(files)

    try
        fileName = files(fi).name;
        fprintf('\nTrimming: %s\n', fileName);

        EEG = pop_loadset('filename', fileName, 'filepath', files(fi).folder);

        EEG = eeg_checkset(EEG, 'eventconsistency');

        eventTypes = {EEG.event.type};

        % START: eerste 64538
        start_idx = find(strcmp(eventTypes, '64538'), 1, 'first');

        if isempty(start_idx)
            error('Geen 64538 start events gevonden');
        end

        start_time = EEG.event(start_idx).latency / EEG.srate;

        % END: laatste 64537
        end_idx = find(strcmp(eventTypes, '64537'), 1, 'last');

        if isempty(end_idx)
            error('Geen 64537 events gevonden');
        end

        end_time = EEG.event(end_idx).latency / EEG.srate;

        % buffers
        pre_buffer  = 1.5;
        post_buffer = 2;

        % trim
        EEG = pop_select(EEG, 'time', ...
            [start_time - pre_buffer, end_time + post_buffer]);

        EEG = eeg_checkset(EEG);

        fprintf('Trim window: %.2f → %.2f sec\n', ...
            start_time - pre_buffer, end_time + post_buffer);

        % Save
        SaveName = strrep(fileName, '_FINAL.set', '_TRIM.set');

        EEG = pop_saveset(EEG, ...
            'filename', SaveName, ...
            'filepath', files(fi).folder);

        fprintf('Saved: %s\n', SaveName);

        clear EEG

    catch ME
        fprintf('\nERROR in %s:\n%s\n', fileName, ME.message);

        if exist('EEG','var')
            clear EEG
        end

        continue;
    end
end

%% ICA

% Which task (file type) you want to analyze?
fileno = 2;

files = dir(fullfile(path2EEGsets, '*_TRIM.set'));

error_files = {};
error_messages = {};

for fi = 1:length(files)

    try
        fprintf('\n****\nLoad file %s\n****\n\n', files(fi).name);

        fileName = files(fi).name;

        % Load EEG set
        EEG = pop_loadset('filename', fileName, 'filepath', path2EEGsets);

        % Find Eyeblink components with ICA (runica):
        EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1,'interrupt','on');

        % Save
        fprintf('\n****\nSave ICA data %s\n****\n\n', fileName);

        SaveName = strrep(fileName, '_TRIM.set', '_ICA.set');

        EEG = pop_saveset(EEG, 'filename', SaveName, 'filepath', path2EEGsets);

        clear EEG
        ALLEEG(1:end) = [];

    catch ME

        fprintf('\nERROR in %s:\n%s\n', files(fi).name, ME.message);

        error_files{end+1} = files(fi).name;
        error_messages{end+1} = ME.message;

        if exist('EEG','var')
            clear EEG
        end

        continue;
    end

end

% Error summary

fprintf('\n===== ICA ERROR SUMMARY =====\n');

if isempty(error_files)
    fprintf('No errors encountered ✅\n');
else
    fprintf('Errors in %d files:\n\n', length(error_files));

    for i = 1:length(error_files)
        fprintf('%s --> %s\n', error_files{i}, error_messages{i});
    end
end

%% Epoch the data

% Which task (file type) you want to analyze?
fileno = 2;

files = dir(fullfile(path2EEGsets, '*_ICA_eyeblink.set'));

error_files = {};
error_messages = {};

for fi = 1:length(files)

    try
        fileName = files(fi).name;

        fprintf('\n****\nEpoching: %s\n****\n', fileName);

        % load
        EEG = pop_loadset('filename', fileName, 'filepath', path2EEGsets);

        % epoch rond 64535 
        EEG = pop_epoch(EEG, {'64535_emo','64535_neu'}, [-0.5 2], 'epochinfo', 'yes');

        % baseline correctie 
        EEG = pop_rmbase(EEG, [-200 0]);

        EEG = eeg_checkset(EEG);

        % Save 
        SaveName = regexprep(fileName, '_ICA.*\.set$', '_EPOCH.set');

        EEG = pop_saveset(EEG, 'filename', SaveName, 'filepath', path2EEGsets);

        fprintf('Saved: %s\n', SaveName);

        clear EEG
        ALLEEG(1:end) = [];

    catch ME

        fprintf('\nERROR in %s:\n%s\n', fileName, ME.message);

        error_files{end+1} = fileName;
        error_messages{end+1} = ME.message;

        if exist('EEG','var'); clear EEG; end

        continue;
    end
end

% Error summary

fprintf('\n===== EPOCH ERROR SUMMARY =====\n');

if isempty(error_files)
    fprintf('No errors encountered ✅\n');
else
    fprintf('Errors in %d files:\n\n', length(error_files));

    for i = 1:length(error_files)
        fprintf('%s --> %s\n', error_files{i}, error_messages{i});
    end
end

%% Split 64535_emo / 64535_neu into remembered / forgotten

files = dir(fullfile(path2EEGsets, '*_EPOCH.set'));

trialinfo_all = readtable('Opgeschoonde BP data.xlsx');

for fi = 1:length(files)

    try

        fileName = files(fi).name;

        fprintf('\nProcessing: %s\n', fileName);

        EEG = pop_loadset('filename', fileName, 'filepath', files(fi).folder);

        % --- subject ID uit bestandsnaam halen ---
        tokens = regexp(fileName, '_(\d+)-', 'tokens');
        subID = str2double(tokens{1}{1});

        % --- filter trialinfo voor deze participant ---
        trialinfo = trialinfo_all(trialinfo_all.SubjectID == subID, :);

        % --- vind alle 64535 events ---
        idx = find(strcmp({EEG.event.type}, '64535_emo') | ...
                   strcmp({EEG.event.type}, '64535_neu'));

        % --- check ---
        if length(idx) ~= height(trialinfo)
            error('Mismatch in aantal trials voor subject %d', subID);
        end

        % --- recode ---
        for k = 1:length(idx)

            retrieved = trialinfo.retrieved(k);

            if strcmpi(EEG.event(idx(k)).type, '64535_emo')

                if retrieved == 1
                    EEG.event(idx(k)).type = "64535_emo_rem";
                elseif retrieved == 0
                    EEG.event(idx(k)).type = "64535_emo_for";
                end

            elseif strcmpi(EEG.event(idx(k)).type, '64535_neu')

                if retrieved == 1
                    EEG.event(idx(k)).type = "64535_neu_rem";
                elseif retrieved == 0
                    EEG.event(idx(k)).type = "64535_neu_for";
                end

            end

        end

        EEG = eeg_checkset(EEG);

        % --- save ---
        SaveName = strrep(fileName, '_EPOCH.set', '_remFor.set');

        EEG = pop_saveset(EEG, ...
            'filename', SaveName, ...
            'filepath', files(fi).folder);

        fprintf('Saved: %s\n', SaveName);

        clear EEG

    catch ME

        fprintf('\nERROR in %s:\n%s\n', fileName, ME.message);

        if exist('EEG','var')
            clear EEG
        end

        continue;

    end

end
%% Artifact rejection 

fileno = 2;

files = dir(fullfile(path2EEGsets, '*_remFor.set'));

% logging
log_file   = {};
log_total  = [];
log_reject = [];
log_percent = [];

log_emo = [];
log_neu = [];
log_amp = [];
log_chan_rej = [];

for fi = 1:length(files)

    fileName = files(fi).name;
    fprintf('\nProcessing: %s\n', fileName);

    EEG = pop_loadset('filename', fileName, 'filepath', path2EEGsets);

    % Noisy channel detection

    pop_eegplot(EEG, 1, 1, 1);

    data_2d = reshape(EEG.data, EEG.nbchan, []);

    n_use = min(30, EEG.nbchan-2);

    chansd = std(data_2d(1:n_use, :)');
    sortsd = sort(chansd);

    badsd = find(chansd > 4 * mean(sortsd(1:15)));
    badsdchans = {EEG.chanlocs(badsd).labels};

    if isempty(badsdchans)
        fprintf('No channels >4SD deviation\n');
        badchannels = {'0'};
        noisychannels = [];
    else
        fprintf('Channel(s) >4SD deviation: %s\n', strjoin(badsdchans, ', '));
    end

    % manual confirmation
    m3a = "no";
    while m3a ~= "yes"
        m3a = input('Ready to input channels to leave out? Type [yes] ','s');
    end

    m3 = -1;
    while m3 == -1
        m3 = str2double(input('How many channels to leave out? ','s'));
    end

    badchannels = {};
    noisychannels = [];

    if m3 > 0
        for bchni = 1:m3
            badchannels{bchni} = input(['Which channel to leave out nr ' num2str(bchni) ': '],'s');
            noisychannels(bchni) = find(strcmpi(badchannels{bchni}, {EEG.chanlocs.labels}));
        end
    else
        badchannels = {'0'};
    end

    EEG.eventdescription = {{'Too much noise in channels:'}, badchannels};

    % Artifact parameters

    grad_thresh = 50; % Maximaal verschil tussen twee opeenvolgende datapunten
    amp_thresh  = 100; % Absolute amplitude grens (+/- microV)
    diff_thresh = 150; % Maximaal verloop binnen een schuiven venster van 200 ms
    win_ms      = 200;

    winpnts = round(win_ms/(1000/EEG.srate));

    EEG.reject.rejmanual  = zeros(1, EEG.trials);
    EEG.reject.rejmanualE = zeros(EEG.nbchan, EEG.trials);

    % Exclude noisy channels
    chanarray = 1:EEG.nbchan-2;

    if ~any(strcmpi(badchannels, '0'))
        for i = 1:length(badchannels)
            idx = find(strcmpi(badchannels{i}, {EEG.chanlocs.labels}));
            chanarray(chanarray == idx) = [];
        end
    end

    % Trial artifact rejection

    for ci = 1:length(chanarray)
        ch = chanarray(ci);

        for tr = 1:EEG.trials

            data = EEG.data(ch,:,tr);

            gradient = max(abs(diff(data)));
            ampliMax = max(data);
            ampliMin = min(data);

            win_diff = [];
            for w = 1:winpnts:length(data)-winpnts
                seg = data(w:w+winpnts-1);
                win_diff(end+1) = max(seg) - min(seg);
            end
            diffV = max(win_diff);

            if gradient > grad_thresh || ...
               ampliMax > amp_thresh || ...
               ampliMin < -amp_thresh || ...
               diffV > diff_thresh

                EEG.reject.rejmanual(tr) = 1;
                EEG.reject.rejmanualE(ch,tr) = 1;
            end
        end
    end

    % Visual check
    fprintf('Marked trials: %d\n', sum(EEG.reject.rejmanual));
    pop_eegplot(EEG, 1, 1, 0);
    input('Press enter to continue...','s');

    bad_trials = find(EEG.reject.rejmanual);

    % Logging
    total_trials = EEG.trials;
    rejected     = length(bad_trials);
    percent      = (rejected / total_trials) * 100;

    log_file{end+1}    = fileName;
    log_total(end+1)   = total_trials;
    log_reject(end+1)  = rejected;
    log_percent(end+1) = percent;

    event_types = {EEG.event.type};

    log_emo(end+1) = sum(strcmp(event_types, '64535_emo'));
    log_neu(end+1) = sum(strcmp(event_types, '64535_neu'));

    log_amp(end+1) = mean(abs(EEG.data(:)));

    chan_rej_rate = sum(EEG.reject.rejmanualE,2) / EEG.trials;
    log_chan_rej = [log_chan_rej; chan_rej_rate'];

    % Reject epochs
    EEG = pop_rejepoch(EEG, bad_trials, 1);
    EEG = eeg_checkset(EEG);

    % Save file
    SaveName = regexprep(fileName, '_EPOCH\.set$', '_CLEAN.set');

    EEG = pop_saveset(EEG, ...
        'filename', SaveName, ...
        'filepath', path2EEGsets);

    fprintf('Saved: %s\n', SaveName);

    clear EEG
    close all
end

% Save overview


T = table(log_file', log_total', log_reject', log_percent', ...
          log_emo', log_neu', log_amp', ...
    'VariableNames', {'File','TotalTrials','RejectedTrials','PercentRejected','EmoTrials','NeuTrials','MeanAmplitude'});

writetable(T, fullfile(path2EEGsets, 'ArtifactRejection_Overview.csv'), ...
    'Delimiter',';');

writematrix(log_chan_rej, fullfile(path2EEGsets, 'Channel_Rejection_Rates.csv'), ...
    'Delimiter', ',');

fprintf('\nOverview saved:\n');
fprintf('- ArtifactRejection_Overview.csv\n');
fprintf('- Channel_Rejection_Rates.csv\n');

%% Artifact rejection 2.0

fileno = 2;

files = dir(fullfile(path2EEGsets, '*_remFor.set'));

% ===== logging =====

log_file = {};

log_total = [];
log_reject = [];
log_percent = [];

log_emo_rem = [];
log_emo_for = [];

log_neu_rem = [];
log_neu_for = [];

log_amp = [];

log_chan_rej = [];

for fi = 1:length(files)

    fileName = files(fi).name;

    fprintf('\nProcessing: %s\n', fileName);

    EEG = pop_loadset('filename', fileName,'filepath', path2EEGsets);

    % NOISY CHANNEL DETECTION

    pop_eegplot(EEG,1,1,1);

    data_2d = reshape(EEG.data, EEG.nbchan, []);

    n_use = min(30, EEG.nbchan-2);

    chansd = std(data_2d(1:n_use,:)');
    sortsd = sort(chansd);

    badsd = find(chansd > 4 * mean(sortsd(1:15)));

    badsdchans = {EEG.chanlocs(badsd).labels};

    if isempty(badsdchans)

        fprintf('No channels >4SD deviation\n');

        badchannels = {'0'};
        noisychannels = [];

    else

        fprintf('Channel(s) >4SD deviation: %s\n', strjoin(badsdchans, ', '));

    end

    % Manual confirmation

    m3a = "no";

    while m3a ~= "yes"
        m3a = input( ...
            'Ready to input channels to leave out? Type [yes] ','s');
    end

    m3 = -1;

    while m3 == -1
        m3 = str2double( ...
            input('How many channels to leave out? ','s'));
    end

    badchannels = {};
    noisychannels = [];

    if m3 > 0

        for bchni = 1:m3

            badchannels{bchni} = ...
                input(['Which channel to leave out nr ' num2str(bchni) ': '],'s');

            noisychannels(bchni) = ...
                find(strcmpi(badchannels{bchni}, {EEG.chanlocs.labels}));

        end

    else

        badchannels = {'0'};

    end

    EEG.eventdescription = {{'Too much noise in channels:'}, badchannels};

    % ARTIFACT PARAMETERS

    grad_thresh = 50;
    amp_thresh  = 100;
    diff_thresh = 150;
    win_ms      = 200;

    winpnts = round(win_ms/(1000/EEG.srate));

    EEG.reject.rejmanual = zeros(1, EEG.trials);
    EEG.reject.rejmanualE = zeros(EEG.nbchan, EEG.trials);

    % Exclude noisy channels

    chanarray = 1:(EEG.nbchan-2);

    if ~any(strcmpi(badchannels,'0'))

        for i = 1:length(badchannels)

            idx = find(strcmpi(badchannels{i}, {EEG.chanlocs.labels}));

            chanarray(chanarray == idx) = [];

        end

    end

    % TRIAL ARTIFACT REJECTION

    for ci = 1:length(chanarray)

        ch = chanarray(ci);

        for tr = 1:EEG.trials

            data = EEG.data(ch,:,tr);

            gradient = max(abs(diff(data)));

            ampliMax = max(data);
            ampliMin = min(data);

            win_diff = [];

            for w = 1:winpnts:length(data)-winpnts

                seg = data(w:w+winpnts-1);

                win_diff(end+1) = max(seg) - min(seg);

            end

            diffV = max(win_diff);

            if gradient > grad_thresh || ampliMax > amp_thresh || ampliMin < -amp_thresh || diffV > diff_thresh

                EEG.reject.rejmanual(tr) = 1;
                EEG.reject.rejmanualE(ch,tr) = 1;

            end

        end

    end

    % VISUAL CHECK

    fprintf('Marked trials: %d\n', sum(EEG.reject.rejmanual));

    pop_eegplot(EEG,1,1,0);

    input('Press enter to continue...','s');

    bad_trials = find(EEG.reject.rejmanual);

    % LOGGING BEFORE REJECTION

    total_trials = EEG.trials;

    rejected = length(bad_trials);

    percent = (rejected / total_trials) * 100;

    log_file{end+1} = fileName;

    log_total(end+1) = total_trials;

    log_reject(end+1) = rejected;

    log_percent(end+1) = percent;

    log_amp(end+1) = mean(abs(EEG.data(:)));

    chan_rej_rate = sum(EEG.reject.rejmanualE,2) / EEG.trials;

    log_chan_rej = [log_chan_rej ; chan_rej_rate'];

    % REJECT EPOCHS

    EEG = pop_rejepoch(EEG, bad_trials, 1);

    EEG = eeg_checkset(EEG);

    % COUNTS AFTER REJECTION

    event_types_after = {EEG.event.type};

    log_emo_rem(end+1) = sum(strcmp(event_types_after,'64535_emo_rem'));

    log_emo_for(end+1) = sum(strcmp(event_types_after,'64535_emo_for'));

    log_neu_rem(end+1) = sum(strcmp(event_types_after,'64535_neu_rem'));

    log_neu_for(end+1) = sum(strcmp(event_types_after,'64535_neu_for'));

    % SAVE FILE

    SaveName = regexprep(fileName, '_remFor\.set$','_CLEAN.set');

    EEG = pop_saveset(EEG,'filename', SaveName,'filepath', path2EEGsets);

    fprintf('Saved: %s\n', SaveName);

    clear EEG
    close all

end

% SAVE OVERVIEW

T = table(log_file', log_total', log_reject', log_percent', log_emo_rem', log_emo_for', log_neu_rem', log_neu_for', log_amp', 'VariableNames', ...
    {'File', 'TotalTrials', 'RejectedTrials', 'PercentRejected', 'Emo_Rem', 'Emo_For', 'Neu_Rem', 'Neu_For', 'MeanAmplitude'});

writetable(T, fullfile(path2EEGsets, 'ArtifactRejection_Overview.csv'), 'Delimiter',';');

writematrix( log_chan_rej, fullfile(path2EEGsets, 'Channel_Rejection_Rates.csv'), 'Delimiter', ',');

fprintf('\nOverview saved:\n');
fprintf('- ArtifactRejection_Overview.csv\n');
fprintf('- Channel_Rejection_Rates.csv\n');