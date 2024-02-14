function ptbSoundPlay(displayData)
    % Function to display feedbacks using PTB functions
    %
    % input:
    % displayData - input data structure

    tDispl = tic;

    P = evalin('base', 'P');

    % Note, don't split cell structure in 2 lines with '...'.
    fieldNames = {'feedbackType', 'condition', 'dispValue', 'Reward', 'displayStage','displayBlankScreen', 'iteration'};
    defaultFields = {'', 0, 0, '', '', '', 0};
    eval(varsFromStruct(displayData, fieldNames, defaultFields))

    dispValue = round(dispValue);
    fprintf('dispValue: %d\n', dispValue);
    
    % If the playback is not active or is finished or has not started yet, create a new schedule
    % http://psychtoolbox.org/docs/PsychPortAudio-GetStatus
    % status = PsychPortAudio(‘GetStatus’, pahandle);
    audio_status = PsychPortAudio('GetStatus', P.nf_sound.pahandle);
    if audio_status.Active == 0
        % http://psychtoolbox.org/docs/PsychPortAudio-UseSchedule
        % PsychPortAudio(‘UseSchedule’, pahandle, enableSchedule [, maxSize = 128]);
        PsychPortAudio('UseSchedule', P.nf_sound.pahandle, 1);
        fprintf('Playback stopped. Recreating the schedule.\n');
        fprintf('state: %d, pos: %d\n', audio_status.State, audio_status.SchedulePosition);
    end

    switch feedbackType
        %% Continuous PSC
        case 'bar_count'
            switch condition
                case 1 % Baseline
                    % http://psychtoolbox.org/docs/PsychPortAudio-AddToSchedule
                    % [success, freeslots] = PsychPortAudio(‘AddToSchedule’, pahandle [, bufferHandle=0][, repetitions=1][, startSample=0][, endSample=max][, UnitIsSeconds=0][, specialFlags=0]);
                    PsychPortAudio('AddToSchedule', P.nf_sound.pahandle, P.nf_sound.baseline, 1);
                    fprintf('Added baseline sound.\n')
                case 2 % Regualtion
                    fprintf('Added regulation sound at %d.\n', dispValue)
                    PsychPortAudio('AddToSchedule', P.nf_sound.pahandle, P.nf_sound.feedback_buffers(dispValue), 1);
                case 3 % Cue Regulation
                    PsychPortAudio('AddToSchedule', P.nf_sound.pahandle, P.nf_sound.cue_nf_start, 1);
                    fprintf('Added cue sound.\n');
            end
        
        %% Continuous PSC with task block
        case 'bar_count_task'
            switch condition
                case 1 % Baseline
                case 2 % Regualtion
                case 3
                    % ptbTask sequence called seperetaly in python 
            end
            
        %% Intermittent PSC
        case 'value_fixation'
            switch condition
                case 1  % Baseline
                case 2  % Regualtion
                case 3 % NF
            end
            
        %% Trial-based DCM
        case 'DCM'
            switch condition
                case 1 % Neutral textures
                case 2 % Positive textures
                case 3 % Rest epoch
                    % Black screen case is called seaprately in Python to allow
                    % using PTB Matlab Helper process for DCM model estimations
                case 4 % NF display   
            end
    end


    % In case the playback is not active, we previously created the schedule and hopefully added a buffer to 
    % the schedule in one of the case conditions. Now we start the playback:
    if audio_status.Active == 0
        % http://psychtoolbox.org/docs/PsychPortAudio-Start
        % startTime = PsychPortAudio(‘Start’, pahandle [, repetitions=1] [, when=0] [, waitForStart=0] [, stopTime=inf] [, resume=0]);
        PsychPortAudio('Start', P.nf_sound.pahandle);
        fprintf('Playback was stopped. Starting it again.\n');
        fprintf('state: %d, pos: %d\n', audio_status.State, audio_status.SchedulePosition);
    end

    % EventRecords for PTB
    % Each event row for PTB is formatted as
    % [t9, t10, displayTimeInstruction, displayTimeFeedback]
    t = posixtime(datetime('now','TimeZone','local'));
    tAbs = toc(tDispl);
    if strcmp(displayStage, 'instruction')
        P.eventRecords(1, :) = repmat(iteration,1,4);
        P.eventRecords(iteration + 1, :) = zeros(1,4);
        P.eventRecords(iteration + 1, 1) = t;
        P.eventRecords(iteration + 1, 3) = tAbs;
    elseif strcmp(displayStage, 'feedback')
        P.eventRecords(1, :) = repmat(iteration,1,4);
        P.eventRecords(iteration + 1, :) = zeros(1,4);
        P.eventRecords(iteration + 1, 2) = t;
        P.eventRecords(iteration + 1, 4) = tAbs;
    end
    recs = P.eventRecords;
    save(P.eventRecordsPath, 'recs', '-ascii', '-double');

    assignin('base', 'P', P);
end
