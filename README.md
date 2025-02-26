# OpenNFT
This is a fork of OpenNFT that allows feedback based on dynamic functional connectivity with auditory feedback.

> OpenNFT is a GUI-based multi-processing open-source software package for real-time fMRI neurofeedback training and quality assessment.
This package is based on best practices of the platform-independent interpreted programming languages Python and Matlab to facilitate
concurrent functionality, high modularity, and the ability to extend the software in Python or Matlab depending on end-user preferences.
OpenNFT includes, but is not limited to, the functionality of SPM, PsychoPy and Psychtoolbox software suits. The OpenNFT’s GUI,
synchronization module and multi-processing core are implemented in Python, whilst computational modules for real-time data processing
and neurofeedback are implemented in Matlab.

## Installation and Documentation
First install all the necessary toolboxes for Matlab. (please see below on how to install psychotoolbox on linux)
https://opennft.readthedocs.io/en/latest
And setup the `$MATLABROOT` environment variable.

### Linux
- Use distrobox to create an Ubuntu 24.04 container.

- Before installing psychotoolbox using their neurodebian package, install libglx from the following link
https://github.com/PetrusNoleto/Error-in-install-cisco-packet-tracer-in-ubuntu-23.10-unmet-dependencies/releases/tag/CiscoPacketTracerFixUnmetDependenciesUbuntu23.10 and then go through with psytoolbox installation.

- Clone this repository
```
git clone --recurse-submodules https://github.com/OpenNFT/OpenNFT.git
```

- Install pyqt5 from the Ubuntu repositories to get all the necessary third-party libraries.
```
sudo apt install python3-pyqt5
```

- Make sure you have `uv` installed. Then run the following:
```
uv add $MATLABROOT/extern/engines/python
```
or
change the path to the matlabengine for python in `pyproject.toml`.

Then launch the matlab instances

```
uv run run_matlab
```

and then in a separate terminal run:

```
uv run python -m opennft
```

## MacOS
Everything should be simiilar to the Linux verison except you would have to install pyqt5 using brew to get all the dependencies:
https://stackoverflow.com/questions/65901162/how-can-i-run-pyqt5-on-my-mac-with-m1chip-ppc64el-architecture
- 

## Windows
Should technically work by following the instructions of each toolbox and package, but I never tested it.


## Docs
# Entry Point `__main__.py`
- Entry point is at `__main__.py` where QT context and an instance of OpenNFT class is created.
- OpenNFT object is an instance of QTWidget and has a [`show()`](https://doc.qt.io/qt-6/qwidget.html#show) method.

## OpenNFT.__init__() `opennft.py`
- In the init function of OpenNFT object, the handle for matlab processes are created using `runmatlab.get_matlab_helpers()` and their handles are assigned to appropriate variables.
- The objects for PsychoToolBox interface are created depending on the modality of feedback.
- `initializeUi()` connects the UI elements defined in `opennft.ui` to their python bindings.
- `readAppSettings()` reads the contents of QT specific application settings and `initialize(start=False)` tries to connect to an existing matlab process and spits out an error telling you to press initialize if it fails.
- Two main variables are used for inter process communication (i.e., communication between matlab and python).
  - `P`: is shared between matlab and python and is mainly used for static variables (e.g., the sliding window length)
  - `mainLoopData`: is also shared and is used for variables that change across iterations (e.g., the signal across time series)

## Initialize Button `opennft.py`
- Associated with `initialize()` function of OpenNFT.
- Starts the matlab processes if not already started.
- Prepares them for use and sets up necessary components for Matlab engine - Python communication.

## Parameters
- After selecting the parameters in the experiment, a bunch of options are set in the python side that are later then synced with matlab side using `self.eng`.
- `self.P['MCTempl']` is set to the path of the EPI template specified in the `.ini` file.


## Setup Button `opennft.py`
- The setup button is connected with the `setup()` function.
- Makes sure opennft is initialized.
- Resets all the variables.
- Calls `actualize()` which read the parameters of the experiment and assigns them to variables such as `self.P`.
- Sets up memory mapped files for fast communication between python and matlab.
- Passes the change to `self.P` to matlab using the handle to engine (`self.eng`).
- Loads the experiment protocol using the json whos filename was read from the parameters and assigned to an entry in `self.P`. It calls the `self.loadJsonProcotol()` function which in turn calls a function with the same name in matlab using the handle to engine `self.eng`. This function is located in `loadJsonProtocol.m`. The comments should clearly explain how the json file is parsed. The parsed conditions and protocls are stored in `P` in matlab side.
  ### `loadJsonProtocol.m`
  - It creates an array called `P.vectEncCond` that assigns each volume to a condition.
  - Note that all the OnOffsets in the JSON protocol file are set without taking into account the skip volumes. So an index of 1 is the first volume after skiping the skip volumes. 
- Calls `selectROI.m` and give it the path of the folder containing the ROIs. `selectROI.m` then goes through all the ROI masks and loads them one by one into `ROIs` array that is then assigned into the global `base` workspace. It also makes sure the ROIs are infact binary by simple thresholding.
- Updates the value `P` in python with the new changes that were made in Matlab side.
- It then calls `self.initMainLoopData()` which sets the selected data type (e.g. Nifti or Dicom) and `self.mainLoopData` in the Matlab side. It calls into the Matlab side with `eng.setUpProcParams()`.
  ### `setUpProcParams.m`
  - This sets up data processing parameters and options that are used throughout the pipeline to make decisions on which type of processing to use. Notable settings are:
  - SPM realign and reslice parameters.
  - Kalman filter parameters for spike filtering.
  - Initializes the min and max values for all the ROIs.
  - Initializes a bunch of arrays used later for time-series processing.
  - Options whether to use Autoregressive filtering for removing autocorrelations. (prewhitening)
  - Whether to add nuissance regressors like motion correction parameters, highpass filtering, linear regressors to iGLM.
  - It then reads the EPI template specified in the `P.MCTempl` and loads the volume. It assigns the different components of the volume to  `mainLoopData.dimTemplMotCorr`, `mainLoopData.matTemplMotCorr`, `mainLoopData.imgVolTempl`.
  - It calls `setupSPM()` which sets up a parameters related to iGLM and cGLM as well as the HRF signal.
  - Reads the explicit contrasts set in the protocol if any.
  - Sets up different the number of regressors depending on which type of regressor we want to use such as motion (e.g., nrRegrToCorrect = 8), highpass, linear, and ...
  - Sets the values for realign and reslice parameters in `mainLoopData`.
  - It creates an array called `R` and assigns to its first element (`R(1, 1)`, which is the mean value of EPI or EPI template) the values of `matTemplMotCorr` `dimTemplMotCorr` `imgVolTempl`.
  - Sets up necessary output folders.
  - Initializes `shared` and `statVol` memory mapped files.
- Creates the threads for PsychoToolBox so that feedback can be presented in a concurrent manner. 
- It also calls the `inisialize()` method of `ptbSound` or `ptbScreen`.

## Start Button `opennft.py`
- Calls the `start()` function.
- Calls `startFilesystemWatching()` which starts the trigger hook that watches the filesystem `workfolder` for new volumes. It also starts the `self.cell_timer` which is a `QTimer` that is connected to the`self.call_main_loop()` function as executes it every `MAIN_LOOP_CALL_PERIOD` which is by default 30ms. `self.call_main_loop` In turn calls `self.main_loop_iteration()` which is where the main logic of processing resides.

## `main_loop_iteration()` `opennft.py`
- Before acquiring a new volume from file system, it first calls `eng.mainLoopEntry()` in the matlab side. 
  ### `mainLoopEntry.m`
    - `mainLoopData.indVolNorm` is the actual index of the volume after ignoring the skip volumes. This is the index that is used to interface with the protocol define in the JSON files.
    - It sets up some variables that may be useful later for displaying and calculating the feedback.
    - It then shows instructions if visual feedback modality was chosen.
    - Then, gets the filename of the next volume, makes sure the skip volumes are passed and, sees if we have reached the end of experiment (the current volumes is equal to the last volume specified in the initial parameters)
  - `eng.preprVol` is then called on the matlab side passing in the filepath of the volume and the index of the iteration.
    #### `preprVol.m`
    - Reads the values for reslice and realign from `mainLoopData`.
    - Reads the volume using `getVolData()` and the file path of the volume. It then stores the contents in the second array element of `R` (remember that the first element of it was the EPI template, set in `setupProcParams.m`) so now `R(2, 1)` is our current volume.
    - It then calls `spm_realign_rt` to estimate the motion parameters using `R(1,1)` as reference and `R(2,1)` is the current volume whose motion parameters are estimated.
    - The 6 motion corretion params are then stored in `P.motCorrParam` at the index of the current volume.
    - It then does reslicing using `spm_reslice_rt` which nudges the current volume using the motion parameters so that it is aligned with the EPI template.
    - The volumes is then smoother using a gaussian kernel with `spm_smooth`.
    - Sets `mainLoopData.procVol` with the smoothed resulting volume.
    - It sends the volume to python using the memory mapped file.
    - It then tries to run iGLM with the regressors specified in `setupProcParams.m`. iGLM is mainly used for brain activation map and dynamic ROI estimation which you may not be interested in depending on the type of research.
  - It then calls `eng.preprSig` for spatio-temporal time-series processing.
    #### `preprSig.m`
    - First loads the masks for `ROIs` from `mainLoopData`.
    - Gets the `rawTimeSeries` data from `mainLoopData` (the first time it's just an empty array).
    - For each ROI:
      - Gets the current volume from `mainLoopData.procVol`
      - Masks the voxels of the current volume with the ROI.
      - Takes the mean of their intensities.
      - And stores it in `rawTimeSeries[index_of_ROI, index_of_volume]`
      - `mainLoopData.initLim` is an array the size of the number of ROIs and stores for each ROI the limits for scaling which is just 0.005 times the mean of the `rawTimeSeries` for that ROI so far.
      - `displRawTimeSeries` is just the signal for each ROI at each time point minus the first signal of that ROI.
      - Next, cumulative GLM is performed. First, a simple AR(1) filtering is applied to the signal. Since it's of order one then we just substract the previous value from the current value of `rawTimeSeries` with the defined `aAR1` constant in `setupProcParams`.
      - The result is stored in `mainLoopData.glmProcTimeSeries` for each ROI.
      - Kalman filtering is done using `glmProcTimeSeries` as input using `modifKalman.m` function to perform Kalman low-pass filtering and despiking. The result is stored in `kalmanProcTimeSeries`.
      - The `kalmanProcTimeSeries` time series is then scaled using `scaleTimeSeries.m`.

## The plots
- `Raw ROI` plot is just `mainLoopData.rawTimeSeries` 
- `Proc ROI` is `mainLoopData.kalmanProcTimeSeries`
- `Norm ROI` is `mainLoopData.scalProcTimeSeries`


PSC = Percentage Signal Change
SVM = Support Vector Machine for classification task
DCM = Dynamic Causal Modelling


