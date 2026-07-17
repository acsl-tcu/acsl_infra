#! /usr/bin/python3
# thanks to http://my-web-site.iobb.net/~yuki/2017-10/raspberry-pi/cpustat/
# -*- coding: utf-8 -*-
import time 
import subprocess
import sys

def GetCpuFreq():
    Cmd = 'vcgencmd measure_clock arm'
    result = subprocess.Popen(Cmd, shell=True,  stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    Rstdout ,Rstderr = result.communicate()
    CpuFreq = Rstdout.split('=')
    return int(CpuFreq[1])

def GetCpuTemp():
    Cmd = 'vcgencmd measure_temp'
    result = subprocess.Popen(Cmd, shell=True,  stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    Rstdout ,Rstderr = result.communicate()
    CpuTemp = Rstdout.split()
    return CpuTemp[0]


def GetCpuStat():
    Cmd = 'cat /proc/stat | grep cpu'
    result = subprocess.Popen(Cmd, shell=True,  stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    Rstdout ,Rstderr = result.communicate()
    LineList = Rstdout.splitlines()
    #
    TckList = []
    for Line in LineList:
        ItemList = Line.split()
        TckIdle = int(ItemList[4])
        TckBusy = int(ItemList[1])+int(ItemList[2])+int(ItemList[3])
        TckAll  = TckBusy + TckIdle
        TckList.append( [ TckBusy ,TckAll ] )
    return  TckList


class CpuUsage:
    def __init__(self):
        self._TckList    = GetCpuStat()

    def get(self):
        TckListPre       = self._TckList
        TckListNow       = GetCpuStat()
        self._TckList    = TckListNow
        CpuRateList = []
        for (TckNow, TckPre) in zip(TckListNow, TckListPre):
            TckDiff = [ Now - Pre for (Now , Pre) in zip(TckNow, TckPre) ]
            TckBusy = TckDiff[0]
            TckAll  = TckDiff[1]
            CpuRate = int(TckBusy*100/TckAll)
            CpuRateList.append( CpuRate )
        return CpuRateList

#
if __name__=='__main__':
    
    gCpuUsage = CpuUsage()       # 初期化
    for ix in range(10000):
        time.sleep(1)
        CpuRateList = gCpuUsage.get()
        CpuRate     = CpuRateList[0]
        CpuRate_str = "  CPU:%3d" % CpuRate
        del CpuRateList[0]
        CpuTemp     = GetCpuTemp()
        CpuFreq     = int(GetCpuFreq()/1000000)
        CpuFreq_str = "ARM %4dMHz  " % CpuFreq
        Info_str = CpuFreq_str + CpuTemp + CpuRate_str + "%"
        print(Info_str ,CpuRateList)