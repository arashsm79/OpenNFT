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
