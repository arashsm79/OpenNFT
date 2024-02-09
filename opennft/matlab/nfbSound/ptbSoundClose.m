function [] = ptbSoundClose()
    %ptbCloseAudioPorts Attempts to close any opened audio ports
    %   This function assess if there are any open audio devices, and tries to
    %   close the opened ones. This function exists inthe context of the
    %   ptbsound object in python, and is called whenever deinitialize is
    %   called

    % if this is the case, then no need to close anything
    if PsychPortAudio('GetOpenDeviceCount') == 0
        return
    end
    % Delete all buffers
    PsychPortAudio('DeleteBuffer')
    try 
        PsychPortAudio('Close'); % try to close first audio device
    end
    
end
    
    