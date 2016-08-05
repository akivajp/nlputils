# distutils: language=c++
# -*- coding: utf-8 -*-

'''Utilities for viewing I/O progress'''

# C++ setting
from libcpp cimport bool
#from libcpp.string cimport string
# Standard libraries
import datetime
import os
import sys
import time
# Local libraries
from common import log

cdef class ProgressCounter(object):
    cdef readonly bool force
    cdef readonly str name
    cdef readonly double refresh
    cdef readonly double firstTime, lastTime
    cdef readonly long count, lastCount

    def __cinit__(self, double refresh=1, str name="", bool force=False):
        #log.log("__CINIT__", color="cyan")
        self.refresh = refresh
        self.name = name
        self.reset()
        self.force = force

    def add(self, unsigned long count=1, bool view=False):
        self.count += count
        if view:
            self.view()

    def flush(self):
        self.view(flush=True)

    def reset(self, refresh=None, name=None, force=None):
        cdef double now
        now = time.time()
        self.firstTime = now
        self.lastTime  = now
        self.count = 0
        self.lastCount = 0
        if refresh != None:
            self.refresh = refresh
        if name != None:
            self.name = name
        if force != None:
            self.force = force

    def view(self, bool flush=False):
        cdef double now, deltaTime, deltaCount
        cdef str strElapsed, strRate, strTimeStamp, showName
        now = time.time()
        #log.debug(now)
        #log.debug(self.lastTime)
        deltaTime  = now - self.lastTime
        #log.debug(deltaTime)
        if not flush:
            #log.debug(deltaTime)
            #log.debug(self.refresh)
            if deltaTime < self.refresh:
                return False
        #log.debug(deltaTime)
        fobj = None
        if not self.force:
            if not sys.stdout.isatty():
                if sys.stderr.isatty():
                    fobj = sys.stderr
        else:
            fobj = sys.stderr
        #log.debug(fobj)
        if fobj:
            deltaCount = self.count - self.lastCount
            strRate = about(deltaCount / deltaTime)
            if self.name:
                showName = "%s: " % self.name
            else:
                showName = ""
            strTimeStamp = datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")
            fobj.write("\r")
            strElapsed = formatTime(now - self.firstTime)
            #log.debug(elapsed)
            fobj.write("%s%s %s [%s/s] [%s]" % (showName, about(self.count), strElapsed, strRate, strTimeStamp))
            fobj.write("  \b\b")
        if fobj and flush:
            fobj.write("\n")
        self.lastTime  = now
        self.lastCount = self.count
        return True

    def __del__(self):
        if self.lastCount != self.count:
            self.flush()

cdef class ProgressReader(object):
    cdef ProgressCounter counter
    cdef object source

    def __cinit__(self, source, str name="", double refresh=1, bool force=False):
        self.counter = ProgressCounter(name=name, refresh=refresh, force=force)
        if type(source) == str:
            self.source = open(source)
        elif type(source) == file:
            self.source = source

    def read(self, unsigned long size):
        cdef str buf
        buf = self.source.read(size)
        if len(buf) > 0:
            self.counter.add(len(buf), view=True)

    def readline(self, long size=-1):
        cdef str buf
        buf = self.source.readline(size)
        if len(buf) > 0:
            if buf[-1] in ('\r', '\n'):
                self.counter.add(view=True)

    def __iter__(self):
        cdef str line
        for line in self.source:
            yield(line)

cdef formatTime(seconds):
    cdef unsigned char showSeconds, showMinutes
    cdef unsigned long showHours
    seconds = int(seconds)
    showSeconds = seconds % 60
    showMinutes = (seconds / 60) % 60
    showHours = seconds / (60*60)
    return "%02d:%02d:%02d" % (showHours,showMinutes,showSeconds)

def about(num):
    if num >= 10 ** 9:
        show = num / float(10 ** 9)
        return "%.3fG" % show
    elif num >= 10 ** 6:
        show = num / float(10 ** 6)
        return "%.3fM" % show
    elif num >= 10 ** 3:
        show = num / float(10 ** 3)
        return "%.3fk" % show
    else:
        return "%.3f" % num

def pipeView(filepaths, mode='bytes', name=None, refresh=1, outfunc=None):
    cdef str strBuf
    if refresh < 0:
        refresh = 1
    counter = ProgressCounter(name=name, refresh=refresh)
    if mode == 'bytes':
        infiles = [open(fpath, 'rb') for fpath in filepaths]
    else:
        infiles = [open(fpath, 'r') for fpath in filepaths]
    if not infiles:
        infiles = [sys.stdin]
    for infile in infiles:
        while True:
            if mode == 'bytes':
                strBuf = infile.read(1)
            elif mode == 'lines':
                strBuf = infile.readline()
            if strBuf == '':
                break
            counter.add(view=True)
            if not outfunc:
                sys.stdout.write(strBuf)
    counter.flush()

