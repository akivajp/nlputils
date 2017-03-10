# distutils: language=c++
# -*- coding: utf-8 -*-

'''Utilities for viewing I/O progress'''

# C++ setting
from libcpp cimport bool
from libcpp.string cimport string
# Standard libraries
#import datetime
from collections import Iterable
from datetime import datetime
import os
import sys
import time
# Local libraries
from common import compat
from common import files
from common import log

#cdef class ProgressCounter(object):
cdef class SpeedCounter(object):
    cdef readonly bool force
    cdef readonly str name
    cdef readonly double refresh
    cdef readonly double firstTime, lastTime
    cdef readonly long count, lastCount, maxCount

    def __cinit__(self, double refresh=1, str name="", bool force=False, long maxCount=-1):
        #log.log("__CINIT__", color="cyan")
        self.refresh = refresh
        self.name = name
        self.reset()
        self.force = force
        self.maxCount = maxCount

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

    def set(self, unsigned long count, bool view=False):
        self.count = count
        if view:
            self.view()

    def view(self, bool flush=False):
        cdef double now, deltaTime, deltaCount
        cdef str strElapsed, strRate, strRatio, strTimeStamp, showName
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
            if sys.stderr.isatty():
                fobj = sys.stderr
            #if not sys.stdout.isatty():
            #    if sys.stderr.isatty():
            #        fobj = sys.stderr
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
            if self.maxCount > 0:
                strRatio = "(%.2f%%) " % (self.count * 100.0 / self.maxCount)
            else:
                strRatio = ""
            try:
                #strTimeStamp = datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")
                strTimeStamp = datetime.now().strftime("%Y/%m/%d %H:%M:%S")
                fobj.write("\r")
                strElapsed = formatTime(now - self.firstTime)
                #log.debug(elapsed)
                fobj.write("%s%s %s%s [%s/s] [%s]" % (showName, about(self.count), strRatio, strElapsed, strRate, strTimeStamp))
                fobj.write("  \b\b")
            except Exception as e:
                print(e)
                pass
        if fobj and flush:
            fobj.write("\n")
        self.lastTime  = now
        self.lastCount = self.count
        return True

    def __del__(self):
        if self.lastCount != self.count:
            self.flush()

#cdef class ProgressReader(object):
cdef class FileReader(object):
    #cdef ProgressCounter counter
    cdef SpeedCounter counter
    cdef object source

    def __cinit__(self, source, str name="", double refresh=1, bool force=False):
        if isinstance(source, str):
            #self.source = files.open(source, 'r')
            self.source = files.open(source, 'rb')
        elif isinstance(source, files.FileType):
            self.source = source
        else:
            raise TypeError("FileReader() expected iterable str or file type, but given %s found" % type(source).__name__)
        size = files.rawsize(self.source)
        #self.counter = ProgressCounter(name=name, refresh=refresh, force=force, maxCount=size)
        self.counter = SpeedCounter(name=name, refresh=refresh, force=force, maxCount=size)

    #def __del__(self):
    #    print("DEL")
    #    self.close()

    def __dealloc__(self):
        self.close()

    cpdef close(self):
        if self.source:
            self.counter.flush()
            self.counter = None
            self.source.close()
            self.source = None

    def __iter__(self):
        #cdef str line
        cdef string line
        if self.source:
            for line in self.source:
                self.counter.set(files.rawtell(self.source),view=True)
                #yield(line)
                yield compat.toStr(line)
        self.close()

cdef class Iterator(object):
    cdef SpeedCounter counter
    cdef object source

    def __cinit__(self, source, str name="", double refresh=1, bool force=False):
        if isinstance(source, Iterable):
            self.source = source
        else:
            raise TypeError("Iterator() expected iterable type, but %s found" % type(source).__name__)
        self.counter = SpeedCounter(name=name, refresh=refresh, force=force)

    def __dealloc__(self):
        self.close()

    cdef close(self):
        if self.source:
            self.counter.flush()
            self.counter = None
            self.source = None

    def __iter__(self):
        cdef object obj
        if self.source:
            for obj in self.source:
                self.counter.add(1, view=True)
                yield obj
        self.close()

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
    #cdef str strBuf
    cdef bytes buf
    cdef long maxCount = -1
    if refresh < 0:
        refresh = 1
    #if mode == 'bytes':
    #    infiles = [open(fpath, 'rb') for fpath in filepaths]
    #else:
    #    infiles = [open(fpath, 'r') for fpath in filepaths]
    #infiles = [open(fpath, 'rb') for fpath in filepaths]
    infiles = [files.open(fpath, 'rb') for fpath in filepaths]
    if infiles:
        if mode == 'bytes':
            maxCount = max(map(files.rawsize, infiles))
    else:
        #infiles = [sys.stdin]
        infiles = [files.bin_stdin]
    #counter = ProgressCounter(name=name, refresh=refresh)
    #counter = SpeedCounter(name=name, refresh=refresh)
    counter = SpeedCounter(name=name, refresh=refresh, maxCount=maxCount)
    for infile in infiles:
        while True:
            #if mode == 'bytes':
            #    strBuf = infile.read(1)
            #elif mode == 'lines':
            #    strBuf = infile.readline()
            if mode == 'bytes':
                buf = infile.read(1)
            elif mode == 'lines':
                buf = infile.readline()
            #if strBuf == '':
            if not buf:
                break
            counter.add(view=True)
            if not outfunc:
                #sys.stdout.write(strBuf)
                #sys.stdout.write(compat.toStr(strBuf))
                files.bin_stdout.write(buf)
    counter.flush()

cpdef view(source):
    if isinstance(source, (str,files.FileType)):
        return FileReader(source, "loading")
    elif isinstance(source, Iterable):
        return Iterator(source, "iterating")
    else:
        raise TypeError("view() expected file or iterable type, but %s found" % type(source).__name__)

