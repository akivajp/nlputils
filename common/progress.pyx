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
from common import environ
from common import files
from common import logging

cdef long BUFFER_SIZE = 4096
cdef str BACK_WHITE = '  \b\b'

#cdef double REFRESH = 1
cdef double REFRESH = 0.5

#cdef class ProgressCounter(object):
cdef class SpeedCounter(object):
    cdef readonly bool force
    cdef readonly str header
    cdef readonly double refresh
    cdef readonly double strat_time, last_time
    cdef readonly long count, pos, last_count, max_count
    cdef readonly str color

    def __cinit__(self, str header="", long max_count=-1, double refresh=REFRESH, bool force=False, str color='green'):
        #logging.log("__CINIT__", color="cyan")
        self.refresh = refresh
        self.header = header 
        self.reset()
        self.force = force
        self.max_count = max_count
        self.color = color

    def add(self, unsigned long count=1, bool view=False):
        self.count += count
        if view:
            self.view()

    def flush(self):
        self.view(flush=True)

    def reset(self, refresh=None, header=None, force=None, color=None):
        cdef double now
        now = time.time()
        self.strat_time = now
        self.last_time  = now
        self.count = 0
        self.last_count = 0
        self.pos = 0
        if refresh != None:
            self.refresh = refresh
        if header != None:
            self.header = header
        if force != None:
            self.force = force
        if color != None:
            self.color = color

    def set_count(self, unsigned long count, bool view=False):
        self.count = count
        if view:
            self.view()

    def set_position(self, unsigned long position, bool view=False):
        self.pos = position
        if view:
            self.view()

    def view(self, bool flush=False):
        cdef double now, delta_time, delta_count
        cdef str str_elapsed, str_rate, str_ratio
        cdef str str_timestamp, str_header, str_about
        cdef str str_print
        cdef bool show_bytes
        now = time.time()
        delta_time  = now - self.last_time
        if not flush:
            if delta_time < self.refresh:
                return False
        fobj = None
        if not self.force:
            if sys.stderr.isatty():
                fobj = sys.stderr
        else:
            fobj = sys.stderr
        if fobj:
            delta_count = self.count - self.last_count
            show_bytes = False
            if self.count == self.pos:
                # bytes mode
                show_bytes = True
            str_rate = about(delta_count / delta_time, show_bytes)
            if self.header:
                str_header = "%s: " % self.header
            else:
                str_header = ""
            if self.max_count > 0:
                if self.pos > 0:
                    str_ratio = "(%.2f%%) " % (self.pos * 100.0 / self.max_count)
                else:
                    str_ratio = "(%.2f%%) " % (self.count * 100.0 / self.max_count)
            else:
                str_ratio = ""
            try:
                #strTimeStamp = datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")
                #str_timestamp = datetime.now().strftime("%Y/%m/%d %H:%M:%S")
                str_timestamp = datetime.now().strftime("%Y/%m/%d %H:%M:%S")
                fobj.write("\r")
                str_elapsed = format_time(now - self.strat_time)
                #logging.debug(elapsed)
                #fobj.write("%s%s %s%s [%s/s] [%s]" % (showName, about(self.count,show_bytes), strRatio, strElapsed, strRate, strTimeStamp))
                #fobj.write("[%s] %s%s %s%s [%s/s]" % (strTimeStamp, showName, about(self.count,show_bytes), strRatio, strElapsed, strRate))
                #fobj.write("  \b\b")
                str_about = about(self.count, show_bytes)
                str_print = "[%s] %s%s %s%s [%s/s]%s" % (str_timestamp, str_header, str_about, str_ratio, str_elapsed, str_rate, BACK_WHITE)
                logging.put_color(str_print, self.color, newline=False)
            except Exception as e:
                print(e)
                pass
        if fobj and flush:
            fobj.write("\n")
        self.last_time  = now
        self.last_count = self.count
        return True

    def __del__(self):
        if self.last_count != self.count:
            self.flush()

#cdef class ProgressReader(object):
cdef class FileReader(object):
    #cdef ProgressCounter counter
    cdef SpeedCounter counter
    cdef object source

    def __cinit__(self, source, str header="", double refresh=REFRESH, bool force=False):
        if isinstance(source, str):
            #self.source = files.open(source, 'r')
            #self.source = files.open(source, 'rb')
            if not header:
                header = "reading file '%s'" % source
            self.source = files.open(source, 'rt')
        elif isinstance(source, io.IOBase):
            self.source = source
        else:
            raise TypeError("FileReader() expected iterable str or file type, but given %s found" % type(source).__name__)
        size = files.rawsize(self.source)
        #self.counter = ProgressCounter(header=header, refresh=refresh, force=force, max_count=size)
        self.counter = SpeedCounter(header=header, max_count=size, refresh=refresh, force=force)

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

    #cpdef str readline(self):
    cpdef readline(self):
        #cdef str line
        #cdef string line
        if self.source:
            line = self.source.readline()
            self.counter.add(1)
            self.counter.set_position(files.rawtell(self.source))
            self.counter.view()
            return line
            #return compat.to_str( line )

    def __iter__(self):
        #cdef str line
        #cdef string line
        if self.source:
            for line in self.source:
                #yield self.readline()
                #self.counter.set(files.rawtell(self.source),view=True)
                #yield(line)
                #yield compat.to_str(line)
                self.counter.add(1)
                self.counter.set_position(files.rawtell(self.source))
                self.counter.view()
                yield line
        self.close()

cdef class Iterator(object):
    cdef SpeedCounter counter
    cdef object source

    def __cinit__(self, source, str header="", double refresh=REFRESH, bool force=False, long max_count=-1):
        if isinstance(source, Iterable):
            self.source = source
        else:
            raise TypeError("Iterator() expected iterable type, but %s found" % type(source).__name__)
        self.counter = SpeedCounter(header=header, max_count=max_count, refresh=refresh, force=force)

    def __dealloc__(self):
        self.close()

    cdef close(self):
        if self.source is not None:
            self.counter.flush()
            self.counter = None
            self.source = None

    def __iter__(self):
        cdef object obj
        if self.source is not None:
            for obj in self.source:
                self.counter.add(1, view=True)
                yield obj
        self.close()

cdef format_time(seconds):
    cdef unsigned char show_seconds, show_minutes
    cdef unsigned long show_hours
    seconds = int(seconds)
    show_seconds = seconds % 60
    show_minutes = (seconds / 60) % 60
    show_hours = seconds / (60*60)
    return "%02d:%02d:%02d" % (show_hours,show_minutes,show_seconds)

def about(num, bool show_bytes = False):
    if show_bytes:
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

cpdef open(path, header=""):
    return FileReader(path, header)

cpdef pipe_view(filepaths, mode='bytes', header=None, refresh=REFRESH, outfunc=None):
    #cdef str strBuf
    cdef bytes buf
    cdef long max_count = -1
    cdef long delta = 1
    cdef SpeedCounter counter
    if refresh < 0:
        refresh = REFRESH
    infiles = [files.open(fpath, 'rb') for fpath in filepaths]
    if infiles:
        #if mode == 'bytes':
        max_count = sum(map(files.rawsize, infiles))
    else:
        infiles = [files.bin_stdin]
    counter = SpeedCounter(header=header, refresh=refresh, max_count=max_count)
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
            counter.set_position(counter.pos + len(buf))
            counter.view()
    counter.flush()

cpdef view(source, header = None, long max_count = -1, env = True):
    if logging.get_quiet_mode():
        # as-is (without progress view)
        return source
    elif isinstance(source, (FileReader,Iterator)):
        return source
    elif isinstance(source, (str,io.IOBase)):
        if not header:
            header = "reading file"
        return FileReader(source, header)
    elif isinstance(source, Iterable):
        if not header:
            header = "iterating"
        if max_count < 0:
            if hasattr(source, '__len__'):
                max_count = len(source)
        return Iterator(source, header, max_count=max_count)
    else:
        raise TypeError("view() expected file or iterable type, but %s found" % type(source).__name__)

