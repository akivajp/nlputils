# distutils: language=c++
# -*- coding: utf-8 -*-

'''Utilities for viewing I/O progress'''

# C++ setting
from libcpp cimport bool
from libcpp.string cimport string
# Standard libraries
from collections import Iterable
from datetime import datetime
import io
import sys
import time
# Local libraries
from common import compat
from common import files
from common import logging

cdef long BUFFER_SIZE = 4096

#cdef class ProgressCounter(object):
cdef class SpeedCounter(object):
    cdef readonly bool force
    cdef readonly str name
    cdef readonly double refresh
    cdef readonly double firstTime, lastTime
    cdef readonly long count, pos, lastCount, maxCount

    def __cinit__(self, str name="", long maxCount=-1, double refresh=1, bool force=False):
        #logging.log("__CINIT__", color="cyan")
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
        self.pos = 0
        if refresh != None:
            self.refresh = refresh
        if name != None:
            self.name = name
        if force != None:
            self.force = force

    def setCount(self, unsigned long count, bool view=False):
        self.count = count
        if view:
            self.view()

    def setPosition(self, unsigned long position, bool view=False):
        self.pos = position
        if view:
            self.view()

    def view(self, bool flush=False):
        cdef double now, deltaTime, deltaCount
        cdef str strElapsed, strRate, strRatio, strTimeStamp, showName
        now = time.time()
        #logging.debug(now)
        #logging.debug(self.lastTime)
        deltaTime  = now - self.lastTime
        #logging.debug(deltaTime)
        if not flush:
            #logging.debug(deltaTime)
            #logging.debug(self.refresh)
            if deltaTime < self.refresh:
                return False
        #logging.debug(deltaTime)
        fobj = None
        if not self.force:
            if sys.stderr.isatty():
                fobj = sys.stderr
            #if not sys.stdout.isatty():
            #    if sys.stderr.isatty():
            #        fobj = sys.stderr
        else:
            fobj = sys.stderr
        #logging.debug(fobj)
        if fobj:
            deltaCount = self.count - self.lastCount
            showBytes = False
            if self.count == self.pos:
                # bytes mode
                showBytes = True
            strRate = about(deltaCount / deltaTime, showBytes)
            if self.name:
                showName = "%s: " % self.name
            else:
                showName = ""
            if self.maxCount > 0:
                if self.pos > 0:
                    strRatio = "(%.2f%%) " % (self.pos * 100.0 / self.maxCount)
                else:
                    strRatio = "(%.2f%%) " % (self.count * 100.0 / self.maxCount)
            else:
                strRatio = ""
            try:
                #strTimeStamp = datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")
                strTimeStamp = datetime.now().strftime("%Y/%m/%d %H:%M:%S")
                fobj.write("\r")
                strElapsed = formatTime(now - self.firstTime)
                #logging.debug(elapsed)
                fobj.write("%s%s %s%s [%s/s] [%s]" % (showName, about(self.count,showBytes), strRatio, strElapsed, strRate, strTimeStamp))
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
            #self.source = files.open(source, 'rb')
            if not name:
                name = "reading file '%s'" % source
            self.source = files.open(source, 'rt')
        elif isinstance(source, io.IOBase):
            self.source = source
        else:
            raise TypeError("FileReader() expected iterable str or file type, but given %s found" % type(source).__name__)
        size = files.rawsize(self.source)
        #self.counter = ProgressCounter(name=name, refresh=refresh, force=force, maxCount=size)
        self.counter = SpeedCounter(name=name, maxCount=size, refresh=refresh, force=force)

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

    cpdef str readline(self):
        cdef str line
        #cdef string line
        if self.source:
            line = self.source.readline()
            self.counter.add(1)
            self.counter.setPosition(files.rawtell(self.source))
            self.counter.view()
            return line
            #return compat.toStr( line )

    def __iter__(self):
        cdef str line
        #cdef string line
        if self.source:
            for line in self.source:
                #yield self.readline()
                #self.counter.set(files.rawtell(self.source),view=True)
                #yield(line)
                #yield compat.toStr(line)
                self.counter.add(1)
                self.counter.setPosition(files.rawtell(self.source))
                self.counter.view()
                yield line
        self.close()

cdef class Iterator(object):
    cdef SpeedCounter counter
    cdef object source

    def __cinit__(self, source, str name="", double refresh=1, bool force=False, long maxCount=-1):
        if isinstance(source, Iterable):
            self.source = source
        else:
            raise TypeError("Iterator() expected iterable type, but %s found" % type(source).__name__)
        self.counter = SpeedCounter(name=name, maxCount=maxCount, refresh=refresh, force=force)

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

def about(num, bool showBytes = False):
    if showBytes:
        if num >= 2 ** 30:
            show = num / float(2 ** 30)
            return "%.3fGiB" % show
        elif num >= 2 ** 20:
            show = num / float(2 ** 20)
            return "%.3fMiB" % show
        elif num >= 2 ** 10:
            show = num / float(2 ** 10)
            return "%.3fKiB" % show
        else:
            return "%.3f" % num
    else:
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

cpdef open(path, name=""):
    return FileReader(path, name)

cpdef pipeView(filepaths, mode='bytes', name=None, refresh=1, outfunc=None):
    #cdef str strBuf
    cdef bytes buf
    cdef long maxCount = -1
    cdef long delta = 1
    cdef SpeedCounter counter
    if refresh < 0:
        refresh = 1
    infiles = [files.open(fpath, 'rb') for fpath in filepaths]
    if infiles:
        #if mode == 'bytes':
        maxCount = sum(map(files.rawsize, infiles))
    else:
        infiles = [files.bin_stdin]
    counter = SpeedCounter(name=name, refresh=refresh, maxCount=maxCount)
    for infile in infiles:
        while True:
            buf = infile.read(BUFFER_SIZE)
            if mode == 'bytes':
                delta = len(buf)
            elif mode == 'lines':
                delta = buf.count(b"\n")
            if not buf:
                break
            #counter.add(view=True)
            if not outfunc:
                files.bin_stdout.write(buf)
            counter.add(delta)
            counter.setPosition(counter.pos + len(buf))
            counter.view()
    counter.flush()

cpdef view(source, name = None, long maxCount = -1):
    if isinstance(source, (FileReader,Iterator)):
        return source
    elif isinstance(source, (str,io.IOBase)):
        if not name:
            name = "reading file"
        return FileReader(source, name)
    elif isinstance(source, Iterable):
        if not name:
            name = "iterating"
        return Iterator(source, name, maxCount=maxCount)
    else:
        raise TypeError("view() expected file or iterable type, but %s found" % type(source).__name__)

