# -*- coding: utf-8 -*-

"""
Wrapper class for asynchronous sound presentation
using Psychtoolbox Matlab helper process

__________________________________________________________________________
Copyright (C) 2016-2017 OpenNFT.org

Written by Herberto Dhanis

"""

from loguru import logger

from opennft import eventrecorder as erd, mlproc
from opennft.eventrecorder import Times as Times
import multiprocessing as mp
import threading

# ==============================================================================

class PtbSound(object):
    """Asynchronous PTB sound
    """
    # --------------------------------------------------------------------------
    def __init__(self, matlab_helper: mlproc.MatlabSharedEngineHelper, recorder: erd.EventRecorder, endEvent: mp.Event):
        self.eng = None
        self.ml_helper = matlab_helper
        self.recorder = recorder
        self.endEvent = endEvent

        self.displayLock = threading.Lock()

    # --------------------------------------------------------------------------
    def __del__(self):
        self.deinitialize()

    # --------------------------------------------------------------------------
    def initialize(self, work_folder, feedback_protocol, ptbP):
        """
        """
        self.deinitialize()

        if self.ml_helper.engine is None:
            raise ValueError(
                'Matlab helper is not connected to Matlab session.')

        self.eng = self.ml_helper.engine

        self.eng.workspace['P'] = ptbP
        self.eng.ptbSoundPreparation(nargout=0)

    # --------------------------------------------------------------------------
    def deinitialize(self):
        if not self.eng:
            return
        try:
            self.eng.ptbSoundClose(nargout=0)
        except Exception as error:
            logger.error('Failed to close the sound system: {}', error)


# --------------------------------------------------------------------------
    def playSound(self, soundQueue):
        """
        """
        if soundQueue.empty():
            self.displayLock.release()
            return

        feedbackData = soundQueue.get()
        self.endEvent.clear()
        if not feedbackData:
            self.displayLock.release()
            return

        logger.info('stage: {}', feedbackData['displayStage'])

        if feedbackData['displayStage'] == 'instruction':
            # t7
            self.recorder.recordEvent(Times.t7, int(feedbackData['iteration']))
        elif feedbackData['displayStage'] == 'feedback':
            # t8
            self.recorder.recordEvent(Times.t8, int(feedbackData['iteration']))

        self.eng.ptbSoundPlay(feedbackData, nargout=0, background=True)


        self.endEvent.set()
        self.displayLock.release()
