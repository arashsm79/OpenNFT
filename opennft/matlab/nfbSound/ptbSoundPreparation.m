function [] = ptbSoundPreparation()
    %ptbSoundPreparation Initializes PTB sound and buffers
    %   This function initializes PTB sound and the audio buffers required to
    %   play the feedback sounds. This function exists in the context of the
    %   ptbsound python object, and is called whenever the initialize function
    %   of that object is called. It follows basically the same logic that
    %   ptbScreenPreparation follows for screen

    % recover P (parameter) structure
    P = evalin('base', 'P');
    P.TR = 1500;
        
    InitializePsychSound(0); % Initializes the sound driver, 1 pushes for low latency

    P.nf_sound = struct();
    P.nf_sound.sampling_frequency = 44100; % Sampling frequency of the device

    % http://psychtoolbox.org/docs/PsychPortAudio-Open
    % pahandle = PsychPortAudio(‘Open’ [, deviceid][, mode][, reqlatencyclass][, freq][, channels][, buffersize][, suggestedLatency][, selectchannels][, specialFlags=0]);
    P.nf_sound.pahandle = PsychPortAudio('Open', [], [], 0, P.nf_sound.sampling_frequency, 1);

    % Start schedule mode
    % http://psychtoolbox.org/docs/PsychPortAudio-UseSchedule
    % PsychPortAudio(%UseSchedule , pahandle, enableSchedule [, maxSize = 128]);
    PsychPortAudio('UseSchedule', P.nf_sound.pahandle, 1);

    P.nf_sound.feedback_buffers = [];
    P.nf_sound.levels = 8;
    P.nf_sound.duration = P.TR / 1000; % TODO: this should be P.TR but P.TR is initialized after this
    P.nf_sound.modulation_amplitude = 30;
    P.nf_sound.beep_frequency= 100;

    waves_per_tr = 1;
    % each sample is 1/sampling_frequency seconds
    t = 0:1/P.nf_sound.sampling_frequency:P.nf_sound.duration;

    % Generate buffers for different levels of feedback value
    % The number of waves heard per TR gradually increases by two
    for i = 1:P.nf_sound.levels
        modulation_frequency = waves_per_tr / (P.TR/1000);
        waves_per_tr = waves_per_tr + 1;
        % Generate modulating signal
        modulating_signal = P.nf_sound.modulation_amplitude * sin(2*pi*modulation_frequency*t);
        % Generate beep signal modulated by the modulating signal
        beep_signal = sin(2*pi*P.nf_sound.beep_frequency*t) .* modulating_signal;
        % Normalize the signal to be between -1 and 1
        snddata = beep_signal / max(abs(beep_signal));
        
        % Add it to the buffers list
        % http://psychtoolbox.org/docs/PsychPortAudio-CreateBuffer
        % bufferhandle = PsychPortAudio(‘CreateBuffer’ [, pahandle], bufferdata);
        P.nf_sound.feedback_buffers(end+1) = PsychPortAudio('CreateBuffer', P.nf_sound.pahandle, snddata);
    end

    % Baseline sound. Two waves per TR.
    modulation_frequency = 1 / (P.TR/1000);
    modulating_signal = P.nf_sound.modulation_amplitude * sin(2*pi*modulation_frequency*t);
    beep_signal = sin(2*pi*2*P.nf_sound.beep_frequency*t) .* modulating_signal;
    snddata = beep_signal / max(abs(beep_signal));
    P.nf_sound.baseline = PsychPortAudio('CreateBuffer', P.nf_sound.pahandle, snddata);

    % Generate specific sounds
    snddata = MakeBeep(400, P.nf_sound.duration);
    P.nf_sound.cue_nf_start = PsychPortAudio('CreateBuffer', P.nf_sound.pahandle, snddata);
    snddata = MakeBeep(500, P.nf_sound.duration);
    P.nf_sound.cue_nf_stop = PsychPortAudio('CreateBuffer', P.nf_sound.pahandle, snddata);
    snddata = MakeBeep(300, P.nf_sound.duration);
    P.nf_sound.cue_baseline_start = PsychPortAudio('CreateBuffer', P.nf_sound.pahandle, snddata);

    % reassign the parameter structure
    assignin('base', 'P', P);

end
    
    
