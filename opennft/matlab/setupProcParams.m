function setupProcParams()
% Function to set up data processing parameters.
%
% input:
% Workspace variables.
%
% output:
% Output is assigned to workspace variables.
%
% The iGLM estimations are used for visualizations, however, note that
% negligible variations are possible in dynamic ROI update schemes or
% feedback estimations based on iGLM.
%
% Note, the iGLM/cGLM contrasts are hard-coded and user-/study- defined,
% which is linked to the prepared SPM.mat structure.
% An end-user needs to set and justify their own parameter
% files and contrasts.
%__________________________________________________________________________
% Copyright (C) 2016-2021 OpenNFT.org
%
% Written by Yury Koush

P = evalin('base', 'P');
mainLoopData = evalin('base', 'mainLoopData');
if P.isRTQA
    rtQA_matlab = evalin('base', 'rtQA_matlab');
end

evalin('base', 'clear mmImgVolTempl;');
evalin('base', 'clear mmStatVol;');
evalin('base', 'clear mmOrthView;');

if ~exist(fullfile(P.WorkFolder,'Settings')), mkdir(fullfile(P.WorkFolder,'Settings')); end

flags = getFlagsType(P);

% Experiment specific settings.
% TODO: move them out to a better place
P.dfc_sliding_window_length = 10;
P.isDFC = false;
P.isNFPSC = true;

if strcmp(P.DataType, 'DICOM')
    fDICOM = true;
    fIMAPH = false;
elseif strcmp(P.DataType, 'IMAPH')
    fDICOM = false;
    fIMAPH = true;
else
    fDICOM = false;
    fIMAPH = false;
end

% TCP Data
if P.UseTCPData
    data.watch = P.WatchFolder;
    data.LastName = '';
    data.ID = '';
    data.FirstFileName = P.FirstFileName;
    
    try tcp = evalin('base','tcp'); catch E
        if strcmp(E.identifier,'MATLAB:UndefinedFunction'), tcp = ImageTCPClass(P.TCPDataPort);
        else, throw(E); end
    end

    tcp.setHeaderFromDICOM(data);
    if ~tcp.Open
        try tcp.WaitForConnection; catch E
            if strcmp(E.message,'No valid handler! already closed?')
                
            else
                throw(E);
            end
        end
    end
    tcp.ReceiveInitial;
    % tcp.Quiet = true;
end

%% SPM Settings
% It is recommended to use the same interpolation values for both real-time
% realign and reslice functions. See spm_realign_rt() for further comments.
% 'interp' 4 is B-Spline 4th order in SPM12
mainLoopData.flagsSpmRealign = struct('quality',.9,'fwhm',5,'sep',4,...
    'interp',4,'wrap',[0 0 0],'rtm',0,'PW','','lkp',1:6);
mainLoopData.flagsSpmReslice = struct('quality',.9,'fwhm',5,'sep',4,...
    'interp',4,'wrap',[0 0 0],'mask',1,'mean',0,'which', 2);

%% Signal Processing Settings
P.VolumesNumber = P.NrOfVolumes - P.nrSkipVol;
% sliding window length in blocks, large value is used to ignore it.
P.nrBlocksInSlidingWindow = 100; % i.e disabled

% Kalman preset
S.Q = 0;
S.P = S.Q;
S.x = 0;
fPositDerivSpike = 0;
fNegatDerivSpike = 0;
S(1:P.NrROIs) = S;
fPositDerivSpike(1:P.NrROIs) = fPositDerivSpike;
fNegatDerivSpike(1:P.NrROIs) = fNegatDerivSpike;
mainLoopData.S = S;
mainLoopData.fPositDerivSpike(1:P.NrROIs) = fPositDerivSpike;
mainLoopData.fNegatDerivSpike(1:P.NrROIs) = fNegatDerivSpike;


% Scaling Init
tmp_posMin(1:P.NrROIs) = 0;
tmp_posMax(1:P.NrROIs) = 0;

mainLoopData.tmp_posMin = tmp_posMin;
mainLoopData.tmp_posMax = tmp_posMax;

P.rawTimeSeries = [];
mainLoopData.rawTimeSeries = [];
mainLoopData.kalmanProcTimeSeries = [];
mainLoopData.displRawTimeSeries = [];
mainLoopData.scalProcTimeSeries = [];
mainLoopData.emaProcTimeSeries = [];

mainLoopData.posMin = [];
mainLoopData.posMax = [];
mainLoopData.mposMax = [];
mainLoopData.mposMin = [];

mainLoopData.blockNF = 0;
mainLoopData.firstNF = 0;

%% DCM Settings
if flags.isDCM
    % This is to simplify the P.Protocol parameter listings for DCM,
    
    % -- read timing parameters from JSON file ----------------------------
    tim = loadTimings(P.ProtocolFile);
    
    % in scans
    P.indNFTrial        = 0;
    P.lengthDCMTrial    = tim.trialLength;
    P.nrNFtrials        = tim.numberOfTrials;
    P.nrDisplayScans    = tim.feedbackDisplayDurationInScans;
    P.nrBlankScans      = tim.feedbackEstimationDurationInScans;
    P.dcmRemoveInterval = P.nrBlankScans + P.nrDisplayScans;
    P.lengthDCMPeriod   = P.lengthDCMTrial + P.nrDisplayScans + P.nrBlankScans;
    P.beginDCMblock     = double([1:P.lengthDCMPeriod:P.lengthDCMPeriod*P.nrNFtrials]);
    P.endDCMblock       = double([P.lengthDCMTrial:P.lengthDCMPeriod:P.lengthDCMPeriod*P.nrNFtrials]);

    % used adaptive DCM ROIs per trial: 1-Group, 2-New, 3-Advanced
    mainLoopData.adaptROIs = [];
    % DCM block counter
    mainLoopData.NrDCMblocks = -1;
    % Reard per DCM trial
    mainLoopData.tReward = 0;
    % adding regressors on the level of DCM computing
    P.fRegrDcm = true;
end

%% AR(1)
if ~flags.isDCM
    % AR(1) for cGLM, i.e. nfb signal processing
    P.cglmAR1 = true;
    % AR(1) for iGLM
    P.iglmAR1 = true;
else
    % For DCM:
    % use smoothing for DCM (optional, to explore the differences)
    P.smForDCM = true;
    % not implemented for cGLM
    P.cglmAR1 = false;
    % AR(1) for iGLM (optional, to explore the differences)
    P.iglmAR1 = true;
end
P.aAR1 = 0.2; % default SPM value

%% adding nuisance regressors to iGLM
P.isRegrIGLM = true;

%% adding nuisance regressors to iGLM
% Note, less efficient regressing out of the motion-related regressors than
% offline GLM given the whole motion regressors at once.
if ~P.isAutoRTQA
    P.isMotionRegr = true;
else
    P.isMotionRegr = false;
end

%% adding high-pass filter to iGLM
% Note, different data processing iGLM approach as compared to SPM
P.isHighPass = true;

%% adding linear regressor
P.isLinRegr = true;
P.linRegr = zscore((1:double(P.NrOfVolumes-P.nrSkipVol))');

%% Get motion realignment template data and volume
if ~P.isAutoRTQA || (P.isAutoRTQA && P.useEPITemplate)
    [tmp_imgVolTempl, matTemplMotCorr, dimTemplMotCorr] = getVolData('NII', P.MCTempl, 0, false, false);
else
    [tmp_imgVolTempl, matTemplMotCorr, dimTemplMotCorr] = getVolData('DICOM', P.MCTempl, 0, true, false);
end

if P.isZeroPadding
    nrZeroPadVol = 3;
    zeroPadVol = zeros(dimTemplMotCorr(1),dimTemplMotCorr(2),nrZeroPadVol);
    dimTemplMotCorr(3) = dimTemplMotCorr(3)+nrZeroPadVol*2;
    imgVolTempl = cat(3, cat(3, zeroPadVol, tmp_imgVolTempl), zeroPadVol);
else
    imgVolTempl = tmp_imgVolTempl;
end

mainLoopData.dimTemplMotCorr = dimTemplMotCorr;
mainLoopData.matTemplMotCorr = matTemplMotCorr;
mainLoopData.imgVolTempl  = imgVolTempl;

P.meanVolTemplate = mean2(mean(tmp_imgVolTempl,1));

SPM = setupSPM(P);
% TODO: To check
% High-pass filter
mainLoopData.K.X0 = SPM.xX.K.X0;

%% Explicit contrasts (optional)
if isfield(P,'ContrastActivation')
    mainLoopData.tContr.pos = P.ContrastActivation;
    mainLoopData.tContr.neg = -P.ContrastActivation;
end

if ~P.isAutoRTQA
    
    if ~P.iglmAR1
        % exclude constant regressor
        mainLoopData.basFct = SPM.xX.X(:,1:end-1);
    else
        % exclude constant regressor
        mainLoopData.basFct = arRegr(P.aAR1, SPM.xX.X(:,1:end-1));
    end
    [mainLoopData.numscan, P.nrBasFct] = size(mainLoopData.basFct);
    % see notes above definition of spmMaskTh value
    mainLoopData.spmMaskTh = mean(SPM.xM.TH)*ones(size(SPM.xM.TH)); % SPM.xM.TH;
    mainLoopData.pVal = .01;
    mainLoopData.statMap3D_iGLM = [];

    mainLoopData.signalPreprocGlmDesign = mainLoopData.basFct(:,contains(SPM.xX.name, P.SignalPreprocessingBasis));
    mainLoopData.nrSignalPreprocGlmDesign = size(mainLoopData.signalPreprocGlmDesign,2);

    % DCM
    if flags.isDCM && strcmp(P.Prot, 'InterBlock')
        [mainLoopData.DCM_EN, mainLoopData.dcmParTag, ...
            mainLoopData.dcmParOpp] = dcmPrep(SPM);
    end

    %% High-pass filter for iGLM given by SPM
    mainLoopData.K = SPM.xX.K;

else
    mainLoopData.basFct = [];
    P.nrBasFct = 6; % size of motion regressors, P.motCorrParam
    mainLoopData.numscan = 0;
    [mainLoopData.numscan, mainLoopData.nrHighPassFct] = size(mainLoopData.K.X0);
    P.spmDesign = [];
    mainLoopData.spmMaskTh = mean(SPM.xM.TH)*ones(size(SPM.xM.TH));
    mainLoopData.pVal = .1;
    mainLoopData.statMap3D_iGLM = [];
end

mainLoopData.mf = [];
mainLoopData.npv = 0;
mainLoopData.statMapCreated = 0;

% number of regressors of no interest to correct with cGLM
if ~P.isAutoRTQA
    % 6 MC regressors, linear trend, constant
    nrRegrToCorrect = 8;
else
    % 2 linear trend, constant, because 6 MC regressors are nrBasFct
    nrRegrToCorrect = 2;
end
if ~P.isRegrIGLM
    if ~P.isAutoRTQA
        nrBasFctRegr = 1;
    else
        nrBasFctRegr = 6;
    end
else
    nrHighPassRegr = size(mainLoopData.K.X0,2);
    if ~P.isAutoRTQA
        nrMotRegr = 6;
        if P.isHighPass && P.isMotionRegr && P.isLinRegr
            nrBasFctRegr = nrMotRegr+nrHighPassRegr+2;
            % adding 6 head motion, linear, high-pass filter, and
            % constant regressors
        elseif ~P.isHighPass && P.isMotionRegr && P.isLinRegr
            nrBasFctRegr = nrMotRegr+2;
            % adding 6 head motion, linear, and constant regressors
        elseif P.isHighPass && ~P.isMotionRegr && P.isLinRegr
            nrBasFctRegr = nrHighPassRegr+2;
            % adding high-pass filter, linear, and constant regressors
        elseif P.isHighPass && ~P.isMotionRegr && ~P.isLinRegr
            nrBasFctRegr = nrHighPassRegr+1;
            % adding high-pass filter, and constant regressors
        elseif ~P.isHighPass && ~P.isMotionRegr && P.isLinRegr
            nrBasFctRegr = 2; % adding linear, and constant regressors
        end
    else
        if P.isHighPass && P.isLinRegr
            nrBasFctRegr = nrHighPassRegr+2;
            % adding 6 head motion, linear, high-pass filter, and
            % constant regressors
        elseif ~P.isHighPass && P.isLinRegr
            nrBasFctRegr = 2;
            % adding 6 head motion, linear, and constant regressors
        elseif P.isHighPass && ~P.isLinRegr
            nrBasFctRegr = nrHighPassRegr+1;
            % adding high-pass filter, and constant regressors
        end
    end
end

P.nrRegrToCorrect = nrRegrToCorrect;
P.nrBasFctRegr = nrBasFctRegr;

%% rtQA init
rtQA_matlab.snrMapCreated = 0;
if P.isRTQA
    % rtQA python saving preparation
    rtQA_python.meanSNR = [];
    rtQA_python.m2SNR = [];
    rtQA_python.rSNR = [];
    rtQA_python.meanBas = [];
    rtQA_python.varBas = [];
    rtQA_python.meanCond = [];
    rtQA_python.varCond = [];
    rtQA_python.rCNR = [];
    rtQA_python.excFDIndexes_1 = [];
    rtQA_python.excFDIndexes_2 = [];
    rtQA_python.excMDIndexes = [];
    rtQA_python.FD = [];
    rtQA_python.MD = [];
    rtQA_python.rMSE = [];

    % rtQA matlab part structure preparation
    if flags.isDCM
        duration = P.lengthDCMTrial*P.nrNFtrials;
    else
        duration = P.VolumesNumber;
    end

    rtQA_matlab.kalmanSpikesPos = zeros(P.NrROIs,duration);
    rtQA_matlab.kalmanSpikesNeg = zeros(P.NrROIs,duration);
    rtQA_matlab.varErGlmProcTimeSeries = zeros(P.NrROIs,duration);
    rtQA_matlab.tGlmProcTimeSeries.pos = zeros(P.NrROIs,duration);
    rtQA_matlab.tGlmProcTimeSeries.neg = zeros(P.NrROIs,duration);

    ROI.betaRegr = zeros(duration, P.nrBasFct+nrRegrToCorrect);
    ROI.Bn = zeros(duration, P.nrBasFct+nrBasFctRegr);
    ROI.tn.pos = zeros(duration, 1);
    ROI.tn.neg = zeros(duration, 1);

    if ~P.isAutoRTQA
        % indexes of baseline and condition for CNR calculation
        tmpindexesCond = find(SPM.xX.X(:,contains(SPM.xX.name, P.CondIndexNames( 2 )))>0.6); % Index for Regulation block == 2
        tmpindexesBas = find(SPM.xX.X(:,contains(SPM.xX.name, P.CondIndexNames( 2 )))<0.1); % Index for Regulation block == 2
        if flags.isDCM
            tmpindexesBas = tmpindexesBas(1:end-1)+1;
            tmpindexesCond = tmpindexesCond-1;
            indexesBas = [];
            indexesCond = [];
            for i=0:P.nrNFtrials-1
                indexesBas = [ indexesBas; tmpindexesBas+i*(P.lengthDCMPeriod-P.dcmRemoveInterval) ];
                indexesCond = [ indexesCond; tmpindexesCond+i*(P.lengthDCMPeriod-P.dcmRemoveInterval) ];
            end
        else
            indexesBas = tmpindexesBas(1:end-1)+1;
            indexesCond = tmpindexesCond-1;
        end
        P.inds = { indexesBas, indexesCond };
    end

end

clear SPM

% Realign preset
A0=[];x1=[];x2=[];x3=[];wt=[];deg=[];b=[];
R(1,1).mat = matTemplMotCorr;
R(1,1).dim = dimTemplMotCorr;
R(1,1).Vol = imgVolTempl;

mainLoopData.R = R;
mainLoopData.A0 = A0;
mainLoopData.x1 = x1;
mainLoopData.x2 = x2;
mainLoopData.x3 = x3;
mainLoopData.wt = wt;
mainLoopData.deg = deg;
mainLoopData.b = b;

% make output data folder
if ~P.isAutoRTQA
    P.nfbDataFolder = [P.WorkFolder filesep 'NF_Data_' num2str(P.NFRunNr)];
else
    watchFolderPath = strsplit(P.WatchFolder,'\');
    watchFolderName = watchFolderPath{end};
    P.nfbDataFolder = [P.WorkFolder filesep watchFolderName '_rtQA_Data_' num2str(P.NFRunNr)];
end

if ~exist(P.nfbDataFolder, 'dir')
    mkdir(P.nfbDataFolder);
end

nrVoxInVol = prod(dimTemplMotCorr);

%% Init memmapfile transport
% volume from root matlab to python GUI
initMemmap(P.memMapFile, 'shared', zeros(nrVoxInVol,1), 'double', 'mmTransferVol', {'double', dimTemplMotCorr, 'transferVol'});

% statVol from root matlab to helper matlab
initMemmap(P.memMapFile, 'statVol', zeros(nrVoxInVol,2), 'double', ...
    'mmStatVol', {'double', dimTemplMotCorr, 'posStatVol'; 'double', dimTemplMotCorr, 'negStatVol'});


if P.isRTQA
    assignin('base', 'rtQA_matlab', rtQA_matlab);
    assignin('base', 'rtQA_python', rtQA_python);
end

assignin('base', 'mainLoopData', mainLoopData);
assignin('base', 'P', P);
if P.UseTCPData, assignin('base', 'tcp', tcp); end

end

function tim = loadTimings(protocoFilePath)
% Loads the DCM timings from the protocol JSON file. To be specified
% as follows: Within the key "dcmdef", insert a key "timings"
%
% "timings": {
%     "trialLength": 108,
%     "numberOfTrials": 7,
%     "feedbackDisplayDurationInScans": 4,
%     "feedbackEstimationDurationInScans": 38
% }
%
% This function will read those values and return an error if they are
% misspecified.
% --------------------------------------------------------------------------

% -- Read the file ---------------------------------------------------------

try
    prt = loadjson(protocoFilePath);
catch
    error('Invalid path to protocol file.')
end

% -- Extract timings and check for completeness and type -------------------

tim            = prt.dcmdef.timings;
requiredFields = {'trialLength','numberOfTrials',...
                  'feedbackDisplayDurationInScans',...
                  'feedbackEstimationDurationInScans'};

for fn = requiredFields
    if ~strcmp(fn{:},fieldnames(tim))
        error('protocol JSON file missing field: %s',fn{:})
    end
end

for fn = fieldnames(tim)'
    if ~isnumeric(tim.(fn{:}))
        error('Timings.%s is invalid. Make sure its a number.',fn{:})
    end
end

end
