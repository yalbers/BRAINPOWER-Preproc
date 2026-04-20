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

% remove trigger 64769
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

% Filter
% Output:'EEG' contains the filtered EEGLAB structure, 'com' contains the history string (the matlab command), 'b' contains the filter coefficients (plot to see the filter) 
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
fprintf('\n****\nSave pre-processed subject %i session %i\n****\n\n', subjectID_n1, session_n1);
SaveName = [file_type{fileno} num2str(subjectID_n1) '-' num2str(session_n1) '_PreprocEEG.set'];
EEG = pop_saveset( EEG, 'filename',SaveName,'filepath', path2EEGsets );




% ~~~~~ HERHALING IN LOOP: ~~~~~

error_count = 0;
error_files = {};

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

%% Event codes aanpassen

files = dir(fullfile(path2EEGsets, '*sham*.set'));

error_count = 0;
error_files = {};

for fi = 1:length(files)

    try
        fileName = files(fi).name;

        fprintf('\nProcessing: %s\n', fileName);

        EEG = pop_loadset('filename', fileName, 'filepath', files(fi).folder);

        % --- recode events ---
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

        % --- save ---
        SaveName = strrep(fileName, '.set', '_recoded.set');

        fprintf('Saving: %s\n', SaveName);

        EEG = pop_saveset(EEG, ...
            'filename', SaveName, ...
            'filepath', files(fi).folder);

        clear EEG

    catch ME
        error_count = error_count + 1;
        error_files{end+1} = fileName;

        fprintf('\nERROR in %s:\n%s\n', fileName, ME.message);

        if exist('EEG','var')
            clear EEG
        end

        continue;
    end
end

% % Voor 1 bestand
% fileName = 'eFRT_encoding_135-sham_PreprocEEG.set';
% 
% fullFile = fullfile(path2EEGsets, fileName);
% 
% fprintf('Loading: %s\n', fullFile);
% 
% % === LOAD ===
% EEG = pop_loadset('filename', fileName, 'filepath', path2EEGsets);
% 
% % === RECODE EVENTS ===
% for i = 1:length(EEG.event)
% 
%     type = strtrim(string(EEG.event(i).type));
% 
%     if type == "64792"
%         EEG.event(i).type = "64536";
% 
%     elseif type == "64794"
%         EEG.event(i).type = "64538";
% 
%     elseif type == "64791"
%         EEG.event(i).type = "64535";
% 
%     elseif type == "64793"
%         EEG.event(i).type = "64537";
%     end
% 
% end
% 
% EEG = eeg_checkset(EEG);
% 
% fprintf('Recode done\n');
% 
% % === SAVE ===
% SaveName = strrep(fileName, '.set', '_recoded.set');
% 
% fprintf('Saving to: %s\n', fullfile(path2EEGsets, SaveName));
% 
% EEG = pop_saveset(EEG, ...
%     'filename', SaveName, ...
%     'filepath', path2EEGsets);
% 
% fprintf('Save complete\n');

%% Tellen en aanpassen van 64538, 64535, 64537 en het splitsen van 64535 in neu en emo

files = dir(fullfile(path2EEGsets, '*recoded.set'));

trialinfo_all = readtable('Opgeschoonde BP data.xlsx');

error_count = 0;
report = {};

for fi = 1:length(files)

    try
        fileName = files(fi).name;
        fprintf('\nProcessing: %s\n', fileName);

        EEG = pop_loadset('filename', fileName, 'filepath', files(fi).folder);
        srate = EEG.srate;

        % --- subject ID ---
        tokens = regexp(fileName, '_(\d+)-', 'tokens');
        subID = str2double(tokens{1}{1});

        trialinfo = trialinfo_all(trialinfo_all.SubjectID == subID, :);

        %  DEDUPLICATIE (ALLE TRIGGERS)

        tol_dup = 2;

        for trig = ["64538","64535","64537"]

            types = {EEG.event.type};
            latencies = [EEG.event.latency];

            isTrig = strcmp(types, trig);
            idx_all = find(isTrig);
            lat_trig = latencies(idx_all);

            keep = true(size(lat_trig));

            for i = 2:length(lat_trig)
                if abs(lat_trig(i) - lat_trig(i-1)) <= tol_dup
                    keep(i) = false;
                end
            end

            EEG.event(idx_all(~keep)) = [];
        end

        % INITIËLE TELLING

        types = string({EEG.event.type});
        latencies = [EEG.event.latency];

        n38 = sum(types == "64538");
        n35 = sum(types == "64535");
        n37 = sum(types == "64537");

        fprintf('Na dedup: 38=%d | 35=%d | 37=%d\n', n38, n35, n37);

        % EVENTS AANVULLEN

        idx38 = find(types == "64538");
        tol = 20;

        for i = 1:length(idx38)

            lat38 = latencies(idx38(i));
            lat35 = lat38 + 0.5 * srate;
            lat37 = lat35 + 0.8 * srate;

            % --- 64535 ---
            if n35 < 20
                if ~any(abs(latencies - lat35) < tol)

                    EEG.event(end+1).type = '64535';
                    EEG.event(end).latency = lat35;

                    latencies(end+1) = lat35;
                    n35 = n35 + 1;
                end
            end

            % --- 64537 ---
            if n37 < 20
                if ~any(abs(latencies - lat37) < tol)

                    EEG.event(end+1).type = '64537';
                    EEG.event(end).latency = lat37;

                    latencies(end+1) = lat37;
                    n37 = n37 + 1;
                end
            end

        end

        % --- sorteer events ---
        [~, order] = sort([EEG.event.latency]);
        EEG.event = EEG.event(order);

        % EMO / NEU SPLIT

        idx = find(strcmp({EEG.event.type}, '64535'));

        if length(idx) ~= height(trialinfo)
            error('Mismatch bij subject %d', subID);
        end

        for k = 1:length(idx)

            cond = trialinfo.Trialtype_Emotion{k};

            if strcmpi(cond, 'Emo')
                EEG.event(idx(k)).type = "64535_emo";
            else
                EEG.event(idx(k)).type = "64535_neu";
            end

        end

        EEG = eeg_checkset(EEG);

        % EINDCHECK

        types = string({EEG.event.type});

        n38 = sum(types == "64538");
        n35 = sum(contains(types, "64535"));
        n37 = sum(types == "64537");

        fprintf('Na alles: 38=%d | 35=%d | 37=%d\n', n38, n35, n37);

        report{end+1,1} = fileName;
        report{end,2} = n38;
        report{end,3} = n35;
        report{end,4} = n37;

        % OPSLAAN

        SaveName = strrep(fileName, '.set', '_final.set');

        EEG = pop_saveset(EEG, ...
            'filename', SaveName, ...
            'filepath', files(fi).folder);

        fprintf('Saved: %s\n', SaveName);

        clear EEG

    catch ME
        error_count = error_count + 1;
        fprintf('\nERROR in %s:\n%s\n', fileName, ME.message);
        continue;
    end
end

% RAPPORT

fprintf('\n=== EINDRAPPORT ===\n');

for i = 1:size(report,1)

    f = report{i,1};
    n38 = report{i,2};
    n35 = report{i,3};
    n37 = report{i,4};

    if n38==20 && n35==20 && n37==20
        fprintf('%s ✅ OK\n', f);
    else
        fprintf('%s ❌ 38=%d | 35=%d | 37=%d\n', f, n38, n35, n37);
    end

end

fprintf('\nKlaar! %d errors.\n', error_count);

% TEST voor 1 bestand – volledige pipeline
% 
% fileName = 'eFRT_encoding_316-sham_PreprocEEG_recoded.set';
% filePath = path2EEGsets;
% 
% % --- laad EEG ---
% EEG = pop_loadset('filename', fileName, 'filepath', filePath);
% srate = EEG.srate;
% 
% % --- laad Excel ---
% trialinfo_all = readtable('Opgeschoonde BP data.xlsx');
% 
% % --- subject ID ---
% tokens = regexp(fileName, '_(\d+)-', 'tokens');
% subID = str2double(tokens{1}{1});
% fprintf('Subject ID: %d\n', subID);
% 
% trialinfo = trialinfo_all(trialinfo_all.SubjectID == subID, :);
% 
% % INITIËLE TELLING
% 
% types = string({EEG.event.type});
% latencies = [EEG.event.latency];
% 
% n38 = sum(types == "64538");
% n35 = sum(types == "64535");
% n37 = sum(types == "64537");
% 
% fprintf('Voor: 38=%d | 35=%d | 37=%d\n', n38, n35, n37);
% 
% % EVENTS AANVULLEN (ROBUST)
% 
% idx38 = find(types == "64538");
% 
% tol = 20; % tolerantie in samples
% 
% for i = 1:length(idx38)
% 
%     lat38 = latencies(idx38(i));
%     lat35 = lat38 + 0.5 * srate;
%     lat37 = lat35 + 0.8 * srate;
% 
%     % --- voeg 64535 toe indien nodig ---
%     if n35 < 20
%         if ~any(abs(latencies - lat35) < tol)
%             EEG.event(end+1).type = '64535';
%             EEG.event(end).latency = lat35;
% 
%             latencies(end+1) = lat35;
%             n35 = n35 + 1;
% 
%             fprintf('Toegevoegd 64535 (nu %d)\n', n35);
%         end
%     end
% 
%     % --- voeg 64537 toe indien nodig ---
%     if n37 < 20
%         if ~any(abs(latencies - lat37) < tol)
%             EEG.event(end+1).type = '64537';
%             EEG.event(end).latency = lat37;
% 
%             latencies(end+1) = lat37;
%             n37 = n37 + 1;
% 
%             fprintf('Toegevoegd 64537 (nu %d)\n', n37);
%         end
%     end
% 
% end
% 
% % --- sorteer events ---
% [~, order] = sort([EEG.event.latency]);
% EEG.event = EEG.event(order);
% 
% % DUPLICATEN VERWIJDEREN (64535)
% 
% types = {EEG.event.type};
% latencies = [EEG.event.latency];
% 
% is64535 = strcmp(types, '64535');
% idx_all = find(is64535);
% lat_64535 = latencies(idx_all);
% 
% tol_dup = 2;
% keep = true(size(lat_64535));
% 
% for i = 2:length(lat_64535)
%     if abs(lat_64535(i) - lat_64535(i-1)) <= tol_dup
%         keep(i) = false;
%     end
% end
% 
% EEG.event(idx_all(~keep)) = [];
% 
% % EMO / NEU SPLIT
% 
% idx = find(strcmp({EEG.event.type}, '64535'));
% 
% fprintf('Na fix: 64535 events = %d | trials = %d\n', length(idx), height(trialinfo));
% 
% if length(idx) ~= height(trialinfo)
%     error('Mismatch na aanvullen!');
% end
% 
% for k = 1:length(idx)
% 
%     cond = trialinfo.Trialtype_Emotion{k};
% 
%     if strcmpi(cond, 'Emo')
%         EEG.event(idx(k)).type = "64535_emo";
%     else
%         EEG.event(idx(k)).type = "64535_neu";
%     end
% 
%     if k <= 10
%         fprintf('Trial %d → %s\n', k, EEG.event(idx(k)).type);
%     end
% end
% 
% EEG = eeg_checkset(EEG);
% 
% % EINDCHECK
% 
% types = string({EEG.event.type});
% 
% n38 = sum(types == "64538");
% n35 = sum(contains(types, "64535"));
% n37 = sum(types == "64537");
% 
% fprintf('\nNa alles: 38=%d | 35=%d | 37=%d\n', n38, n35, n37);
% 
% if n38==20 && n35==20 && n37==20
%     fprintf('✅ Alles correct!\n');
% else
%     fprintf('❌ NIET correct!\n');
% end
% 
% %  OPSLAAN
% 
% SaveName = strrep(fileName, '.set', '_TEST_final.set');
% 
% EEG = pop_saveset(EEG, ...
%     'filename', SaveName, ...
%     'filepath', filePath);
% 
% fprintf('\nTestbestand opgeslagen: %s\n', SaveName);
%% Trim the data


%% ICA


%% Epoch the data


%% Artifact rejection