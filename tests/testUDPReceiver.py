# -*- coding: utf-8 -*-

# testing UDP
"""

__________________________________________________________________________
Copyright (C) 2016-2017 OpenNFT.org

Written by Tibor Auer
"""

from pyniexp.connection import Udp

UDP_IP = "127.0.0.1"
UDP_PORT = 1234
UDP_CONTROL_CHAR = '#'

receiver = Udp(IP=UDP_IP,port=UDP_PORT,controlChar=UDP_CONTROL_CHAR)

receiver.ConnectForReceiving()
receiver.sendTimeStamp = True

n = 0
while receiver.isOpen:
    data = receiver.ReceiveData(n=1)#,dtype='float')
    n += 1
    # if n == 1: receiver.ResetClock()
    if len(data) > 1: receiver.Log('volume #{:3d} feedback: {} - {}'.format(n,data[0],data[1]))
    else: receiver.Log('volume #{:3d} no data!'.format(n))

receiver.Close()