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
    
    % http://psychtoolbox.org/docs/PsychPortAudio-GetStatus
    % status = PsychPortAudio(‘GetStatus’, pahandle);
    audio_status = PsychPortAudio('GetStatus', P.nf_sound.pahandle); fprintf("indx: %d\n", audio_status.ElapsedOutSamples);
    % This condition is only used for the start of playback.
    if audio_status.ElapsedOutSamples ~= 0
        fill_sample_index = audio_status.ElapsedOutSamples + (P.nf_sound.sampling_frequency * P.nf_sound.inter_signal_distance);
    else
        fill_sample_index = 1;
    end
    
    % Check if we have gone past the end of the buffer and circled around. If yes then the calculation for the
    % end phase of the previous wave that is playing, is different.
    if fill_sample_index > P.nf_sound.prev_signal_start_sample_index
        end_phase_index = fill_sample_index - P.nf_sound.prev_signal_start_sample_index;
    else
        end_phase_index = (P.nf_sound.buffer_size - P.nf_sound.prev_signal_start_sample_index) + fill_sample_index;
    end

    % Find the phase of beep and modulation signals of the previous wave that IS currently playing
    prev_beep_wave_end_phase       = P.nf_sound.prev_beep_wave_phase(end_phase_index);
    prev_modulation_wave_end_phase = P.nf_sound.prev_modulation_wave_phase(end_phase_index);
    % The calculated fill_sample_index is where the next wave is going to be placed. Here we save this index
    % and will use it in the next iteration again.
    P.nf_sound.prev_signal_start_sample_index = fill_sample_index;

    % Set diffault frequencies in case none of the conditions were meet (this is just a safe gaurd)
    beep_frequency = P.nf_sound.baseline_beep_frequency;
    modulation_frequency = P.nf_sound.baseline_modulation_frequency;

    switch feedbackType
        %% Continuous PSC
        case 'bar_count'
            switch condition
                case 1 % Baseline
                    beep_frequency = P.nf_sound.baseline_beep_frequency;
                    modulation_frequency = P.nf_sound.baseline_modulation_frequency;
                case 2 % Regualtion
                    beep_frequency = P.nf_sound.nfreg_beep_frequency;
                    modulation_frequency = dispValue;
                case 3 % Cue Regulation
                    beep_frequency = P.nf_sound.cue_beep_frequency;
                    modulation_frequency = P.nf_sound.cue_modulation_frequency;
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

    % These are the increments used for phase accumulation
    beep_phase_increment = 2*pi*beep_frequency/P.nf_sound.sampling_frequency;
    modulation_phase_increment = 2*pi*modulation_frequency/P.nf_sound.sampling_frequency;

    % Create the beep signal
    t_beep = P.nf_sound.time_vector;
    t_beep(:) = beep_phase_increment;

    if P.nf_sound.prev_beep_phase_increment > beep_phase_increment
        t_beep(1:round(P.nf_sound.sampling_frequency*P.nf_sound.smoothing_range)) = linspace(beep_phase_increment, P.nf_sound.prev_beep_phase_increment, round(P.nf_sound.sampling_frequency*P.nf_sound.smoothing_range));
    else
        t_beep(1:round(P.nf_sound.sampling_frequency*P.nf_sound.smoothing_range)) = linspace(P.nf_sound.prev_beep_phase_increment, beep_phase_increment, round(P.nf_sound.sampling_frequency*P.nf_sound.smoothing_range));
    end
    
    t_beep(1) = prev_beep_wave_end_phase;
    t_beep_cum = cumsum(t_beep);
    beep_signal = sin(t_beep_cum);
    % Save the whole phase vector and the phase increment for the next iteration
    P.nf_sound.prev_beep_wave_phase = t_beep_cum;
    P.nf_sound.prev_beep_phase_increment = beep_phase_increment;

    % Create the modulation signal
    t_mod = P.nf_sound.time_vector;
    t_mod(:) = modulation_phase_increment;

    % This condition makes sure that the transition happens in the correct order. If we go from a low frequency
    % to high frequency or the other way around.
    if P.nf_sound.prev_beep_phase_increment > beep_phase_increment
        t_mod(1:round(P.nf_sound.sampling_frequency*P.nf_sound.smoothing_range)) = linspace(modulation_phase_increment, P.nf_sound.prev_modulation_phase_increment, round(P.nf_sound.sampling_frequency*P.nf_sound.smoothing_range));
    else
        t_mod(1:round(P.nf_sound.sampling_frequency*P.nf_sound.smoothing_range)) = linspace(P.nf_sound.prev_modulation_phase_increment, modulation_phase_increment, round(P.nf_sound.sampling_frequency*P.nf_sound.smoothing_range));
    end

    t_mod(1) = prev_modulation_wave_end_phase;
    t_mod_cum = cumsum(t_mod);
    modulation_signal = sin(t_mod_cum);
    % Save the whole phase vector and the phase increment for the next iteration
    P.nf_sound.prev_modulation_wave_phase = t_mod_cum;
    P.nf_sound.prev_modulation_phase_increment = modulation_phase_increment;
    % Create the final signal
    feedback_signal = beep_signal .* modulation_signal;
    snddata = feedback_signal / max(abs(feedback_signal));

    % In case playback was stopped for some reason, try to start it again
    if audio_status.Active == 0
        % http://psychtoolbox.org/docs/PsychPortAudio-Start
        % startTime = PsychPortAudio(‘Start’, pahandle [, repetitions=1] [, when=0] [, waitForStart=0] [, stopTime=inf] [, resume=0]);
        PsychPortAudio('Start', P.nf_sound.pahandle, 1);
    end

    [underflow, nextSampleStartIndex, nextSampleETASecs] = PsychPortAudio('FillBuffer',  P.nf_sound.pahandle, snddata, 2, fill_sample_index);
    if underflow > 1
        fprinft('Underflow! Increase the inter_wave_distance.');
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
