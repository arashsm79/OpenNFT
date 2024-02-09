function loadJsonProtocol()
% Function to load experimental protocol stored in json format.
% Note, to work with json files, use jsonlab toolbox.
%
% input:
% Workspace variables.
%
% output:
% Output is assigned to workspace variables.
%__________________________________________________________________________
% Copyright (C) 2016-2017 OpenNFT.org
%
% Written by Yury Koush, Artem Nikonorov

P = evalin('base', 'P');

flags = getFlagsType(P);

if ~P.isAutoRTQA
    jsonFile = P.ProtocolFile;
    NrOfVolumes = P.NrOfVolumes;
    nrSkipVol = P.nrSkipVol;

    prt = loadjson(jsonFile);

    % -- remove dcmdef field -- %
    if flags.isDCM
        prt = rmfield(prt, 'dcmdef');
    end

    % ConditionIndex is an array of all the conditions (baseline, regulation, task1, rest, ...)
    % lCond would then be the number of conditions we have specified in our protocol.
    lCond = length(prt.ConditionIndex);
    % For each condition in the COnditionIndex array, get the name of the condition
    for x=1:lCond
        protNames{x} = prt.ConditionIndex{x}.ConditionName;
    end

    % An encoding vector for all the volumes. We assign a condition to each volume.
    % 1 is for baseline, by default we set everything as baseline and later reassign them to 
    % their correct condition.
    P.vectEncCond = ones(1,NrOfVolumes-nrSkipVol);

    % check if baseline field already exists in protocol
    % and protocol reading presets
    % 1 is for Baseline
    indexBAS = strcmp(protNames,'BAS');
    if any(indexBAS)
        P.basBlockLength = prt.ConditionIndex{ 1 }.OnOffsets(1,2);
        inc = 0;
    else
        inc = 1;
    end

    tmpSignalPreprocessingBasis = textscan(prt.SignalPreprocessingBasis,'%s','Delimiter',';');
    P.SignalPreprocessingBasis = tmpSignalPreprocessingBasis{:};
    P.CondIndexNames = protNames;
    % Find the OnOffest of each condition and assign its corresponding encoding
    % to the volumes in that condition in vectEncCond.
    % ProtCond simply contains the sequence of volumes for each OnOffset pair for each condition.
    for x=1:lCond
        P.ProtCond{x} = {};
        for k = 1:length(prt.ConditionIndex{x}.OnOffsets(:,1))
            % unitBlock is a mask on all the volumes where the current condition and OnOffset are present.
            unitBlock = prt.ConditionIndex{x}.OnOffsets(k,1) : prt.ConditionIndex{x}.OnOffsets(k,2);
            P.vectEncCond(unitBlock) = x+inc;
            P.ProtCond{x}(k,:) = {unitBlock};
        end
    end

    %% Implicit baseline
    % If there is no definition of baseline condition in the protocol json
    % we just assume everything else is the baseline.
    BasInd = find(P.vectEncCond == 1);
    ProtCondBas = accumarray( cumsum([1, diff(BasInd) ~= 1]).', BasInd, [], @(x){x'} );
    if ~any(strcmp(P.CondIndexNames,'BAS')) % If there is no definition of baseline in the json protocol\
        P.ProtCond = [ {ProtCondBas} P.ProtCond ];
        P.CondIndexNames = [ {''} P.CondIndexNames ];
        P.basBlockLength = ProtCondBas{1}(end);
    end


    %% Contrast and Conditions For Contrast encoding from .json Contrast specification
    if isfield(prt,'ContrastActivation')
        if ~P.isAutoRTQA
            conditionNames = cellfun(@(x) x.ConditionName, prt.ConditionIndex, 'UniformOutput',false);
            contrastString = textscan(prt.ContrastActivation,'%d*%s','Delimiter',';');
            P.ConditionForContrast = contrastString{2}';
            if length(conditionNames)>length(contrastString{1})
                conditionNames = intersect(contrastString{2},conditionNames)';
            end
            contrastVect = [];
            for contrastIndex = cellfun(@(x) find(strcmp(x,contrastString{2})),conditionNames,'UniformOutput',false)
                if ~isempty(contrastIndex{1})
                    contrastVect(end+1) = contrastString{1}(contrastIndex{1});
                else
                    contrastVect(end+1) = 0;
                end
            end
        else
            contrastVect = double(cell2mat(textscan(prt.ContrastActivation,'%d','Delimiter',';'))');
        end
        P.ContrastActivation = contrastVect';
    end

    %% Save
    P.Protocol = prt;
else

    P.ContrastActivation = [1; 1; 1; 1; 1; 1];

end

assignin('base', 'P', P);
end