# -*- coding: utf-8 -*-

"""
Wrapper class for asynchronous display
using Psychtoolbox Matlab helper process

__________________________________________________________________________
Copyright (C) 2016-2021 OpenNFT.org

Written by Evgeny Prilepin, Artem Nikonorov, Yury Koush

"""

from loguru import logger

from opennft import eventrecorder as erd, mlproc
from opennft.eventrecorder import Times as Times
import multiprocessing as mp
import threading


# ==============================================================================
class PtbScreen(object):
    """Asynchronous PTB display
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
    def initialize(self, screen_id, work_folder, feedback_protocol, ptbP):
        """
        """
        self.deinitialize()

        if self.ml_helper.engine is None:
            raise ValueError(
                'Matlab helper is not connected to Matlab session.')

        self.eng = self.ml_helper.engine

        self.eng.workspace['P'] = ptbP
        self.eng.ptbPreparation(screen_id, work_folder, feedback_protocol, nargout=0)
        self.eng.nfbInitReward(nargout=0)

    # --------------------------------------------------------------------------
    def deinitialize(self):
        if not self.eng:
            return

        try:
            self.eng.Screen('CloseAll', nargout=0)
        except Exception:
            pass

    # --------------------------------------------------------------------------
    def display(self, displayQueue):
        """
        """
        if displayQueue.empty():
            self.displayLock.release()
            return

        displayData = displayQueue.get()
        self.endEvent.clear()
        if not displayData:
            self.displayLock.release()
            return

        logger.info('stage: {}', displayData['displayStage'])

        # if display_blank:
        if displayData['displayBlankScreen'] > 0:
            self.eng.ptbBlankScreen(nargout=0, background=True)
            displayData['displayBlankScreen'] = 0
        else:
            if displayData['displayStage'] == 'instruction':
                # t7
                self.recorder.recordEvent(Times.t7, int(displayData['iteration']))
            elif displayData['displayStage'] == 'feedback':
                # t8
                self.recorder.recordEvent(Times.t8, int(displayData['iteration']))

            if displayData['taskseq'] > 0:
                self.eng.ptbTask(nargout=0, background=True)
                displayData['taskseq'] = 0
            else:
                self.eng.displayFeedback(displayData, nargout=0, background=True)

        # logger.info('ptbDisplay 3-{}', displayData['iteration'])

        self.endEvent.set()
        self.displayLock.release()
