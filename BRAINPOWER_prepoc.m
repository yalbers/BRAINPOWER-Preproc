% --------------------------------------------------------------------- %
%   EEG PREPROCESSING
% --------------------------------------------------------------------- %
%
% Description:  Matlab-script to pre-process Biosemi EEG data
%             - Study name: PITA (UU lab-study)
%             - Measure/instrument: Biosemi 32-EEG-channel recordings
%             - Data type: EEG time series with trigger events (time stamps)
%             - Design: within-subjects cross-over, 2 timepoints (sham vs. real 5Hz-tACS)
%
% Required toolbox:
% EEGLAB (used: version 2024.2)
%
% Notes: 
% * Besluit > Excludeer ppn bij wie stimulatie niet is uitgevoerd tijdens real tACS sessie.
%   Dat zijn ppn: 297, 334, 396, 602, 626, 913.
%   Behoud ppn bij wie stimulatie niet is uitgevoerd in sham sessie.
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
%% Trim the data


%% ICA


%% Epoch the data


%% Artifact rejection