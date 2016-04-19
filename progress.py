#!/usr/bin/env python

import argparse
import datetime
import os
import sys
import time

class ProgressCounter(object):
    def __init__(self, refresh=1, name=""):
        self.refresh = refresh
        self.name = name
        self.reset()

    def add(self, count=1):
        self.count += count

    def flush(self, force=False):
        self.view(flush=True, force=force)

    def reset(self, refresh=None, name=None):
        now = time.time()
        self.firstTime = now
        self.lastTime  = now
        self.count = 0
        self.lastCount = 0
        if refresh != None:
            self.refresh = refresh
        if name != None:
            self.name = name

    def view(self, force=False, flush=False):
        now = time.time()
        deltaTime  = now - self.lastTime
        deltaCount = self.count - self.lastCount
        elapsed = formatTime(now - self.firstTime)
        if not flush:
            if deltaTime < self.refresh:
                return
        fobj = None
        if not force:
            if not sys.stdout.isatty():
                if sys.stderr.isatty():
                    fobj = sys.stderr
        else:
            fobj = sys.stderr
        if fobj:
            rate = about(deltaCount / deltaTime)
            if self.name:
                name = "%s: " % self.name
            else:
                name = ""
            timestamp = datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")
            fobj.write("\r")
            fobj.write("%s%s %s [%s/s] [%s]" % (name, about(self.count), elapsed, rate, timestamp))
            fobj.write("  \b\b")
        if fobj and flush:
            fobj.write("\n")
        self.lastTime  = now
        self.lastCount = self.count

def formatTime(seconds):
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

def pipeView(filepaths, mode='bytes', name=None):
    counter = ProgressCounter(name=name)
    if mode == 'bytes':
        infiles = [open(fpath, 'rb') for fpath in filepaths]
    else:
        infiles = [open(fpath, 'r') for fpath in filepaths]
    if not infiles:
        infiles = [sys.stdin]
    for infile in infiles:
        while True:
            if mode == 'bytes':
                buf = infile.read(1)
            elif mode == 'lines':
                buf = infile.readline()
            if buf == '':
                break
            counter.add()
            counter.view()
            sys.stdout.write(buf)
    counter.flush()

def cmdPipeView(args):
    parser = argparse.ArgumentParser(description='Show the progress of pipe I/O')
    parser.add_argument('filepaths', metavar="filepath", nargs="*", type=str, help='path of file to load')
    parser.add_argument('--lines', '-l', action='store_true', help='line count mode (default: byte count mode)')
    parser.add_argument('--name', '-N', type=str, help='prefix the output information')
    parsed = parser.parse_args(args)
    mode = 'bytes'
    if parsed.lines:
        mode = 'lines'
    pipeView(parsed.filepaths, mode=mode, name=parsed.name)

def main():
    cmdPipeView(sys.argv[1:])

if __name__ == '__main__':
    main()

