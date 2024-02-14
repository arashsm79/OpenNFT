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
    P.nf_sound.n_channels = 1; % Sampling frequency of the device
    % The buffer size. Since memory is cheap we can set it to an hour or two.
    % the codde however, can handle small buffer size just fine.
    P.nf_sound.buffer_size = 3600*P.nf_sound.sampling_frequency;

    % http://psychtoolbox.org/docs/PsychPortAudio-Open
    % pahandle = PsychPortAudio(‘Open’ [, deviceid][, mode][, reqlatencyclass][, freq][, channels][, buffersize][, suggestedLatency][, selectchannels][, specialFlags=0]);
    P.nf_sound.pahandle = PsychPortAudio('Open', [], [], 0, P.nf_sound.sampling_frequency, P.nf_sound.n_channels);
    % Create a buffer with the given size.
    PsychPortAudio('FillBuffer',  P.nf_sound.pahandle, zeros(1, 3600*P.nf_sound.sampling_frequency));

    P.nf_sound.duration = P.TR / 1000 + 1; % TODO: this should be P.TR but P.TR is initialized after this
    P.nf_sound.modulation_amplitude = 30;
    P.nf_sound.beep_frequency= 100;
    % each sample is 1/sampling_frequency seconds
    P.nf_sound.time_vector = 0:1/P.nf_sound.sampling_frequency:P.nf_sound.duration;
    % How many seconds of smoothing should be applied on frequency transition
    P.nf_sound.smoothing_range = 0.3;
    % The distance between two sound signals in the buffer. When we receive a new feedback
    % we put its corresponding sound wave this many seconds later at the current playback position
    P.nf_sound.inter_signal_distance = 0.2;
    % Frequencies 
    P.nf_sound.baseline_beep_frequency = 200;
    P.nf_sound.nfreg_beep_frequency = 150;
    P.nf_sound.cue_beep_frequency = 400;
    P.nf_sound.baseline_modulation_frequency = 1;
    P.nf_sound.cue_modulation_frequency = 20;

    P.nf_sound.prev_modulation_wave_phase = [0];
    P.nf_sound.prev_beep_wave_phase = [0];
    P.nf_sound.beep_phase_increment = 2*pi*P.nf_sound.beep_frequency/P.nf_sound.sampling_frequency;
    P.nf_sound.modulation_phase_increment = 2*pi*1/P.nf_sound.sampling_frequency;
    P.nf_sound.prev_signal_start_sample_index = 0;

    P.nf_sound.prev_beep_phase_increment = 0;
    P.nf_sound.prev_modulation_phase_increment = 0;

    % reassign the parameter structure
    assignin('base', 'P', P);
end
    
    
