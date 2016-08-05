#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import math
import multiprocessing
import os
import subprocess
import sys
import time

import progress
from common.config import Config
from common import log
from wait_files import waitFile

numCPUs = multiprocessing.cpu_count()

def forceMakeDirs(dirpath):
    if not os.path.isdir(dirpath):
        log.log('Making directory: "%s"' % dirpath)
        try:
            os.makedirs(dirpath)
        except:
            log.alert('Cannot make directory: "%s"' % dirpath)

def getHostProcID():
    return "%s:%s" % (os.uname()[1],os.getpid())

def report(filepath, message):
    if os.path.exists(filepath):
        log.log('Exists file or directory: %s' % filepath)
        return False
    else:
        log.log('Reporting into file: %s' % filepath)
        fobj = open(filepath, 'w')
        fobj.write(message)
        fobj.close()
        return True

def remove(f):
    if type(f) == str:
        log.log('Removing file: %s' % filepath)
        os.remove(filepath)
    elif type(f) == file:
        log.log('Removing file: %s' % f.name)
        f.close()
        os.remove(f.name)

def checkFile(filepath):
    if os.path.exists(filepath):
        log.log('File already exists: %s' % filepath)
        return True
    else:
        return False

def checkStage(tmpdir, basename, stage):
    if checkFile('%s/__INIT__.%s.%s' % (tmpdir,stage,basename)):
        return 'started'
    elif checkFile('%s/__DONE__.%s.%s' % (tmpdir,stage,basename)):
        return 'finished'
    else:
        return 'none'

def checkStageOwner(conf, stage):
    tmpdir = conf.data.tmpdir
    basename = conf.data.basename
    path = '%(tmpdir)s/__INIT__.%(stage)s.%(basename)s' % locals()
    return open(path, 'r').read()

def reportInit(conf, stage):
    tmpdir = conf.data.tmpdir
    basename = conf.data.basename
    path = '%(tmpdir)s/__INIT__.%(stage)s.%(basename)s' % locals()
    if not report(path, conf.data.hostproc):
        return False
    log.log('Waiting 1 second to confirm the stage file ownership')
    time.sleep(1)
    owner = checkStageOwner(conf, stage)
    #log.debug(owner)
    #log.debug(conf.data.hostproc)
    if owner != conf.data.hostproc:
        log.alert('Failed to obtain ownership of stage file: %s' % path)
    return True

def reportDone(conf, stage):
    tmpdir = conf.data.tmpdir
    basename = conf.data.basename
    return report('%(tmpdir)s/__DONE__.%(stage)s.%(basename)s'%locals(), conf.data.hostproc)

def waitReportDone(conf, stage):
    tmpdir = conf.data.tmpdir
    basename = conf.data.basename
    return waitFile('%(tmpdir)s/__DONE__.%(stage)s.%(basename)s'%locals())

def getInBuffer(conf):
    #bufname = '%s/__BUFFER__%s' % (tmpdir,hostproc)
    bufname = '%(tmpdir)s/__BUFFER__%(hostproc)s' % conf
    progCounter = progress.ProgressCounter(1, "buffering", force=True)
    with open(conf.data.inpath, 'r') as infile:
        inbuf = open(bufname, 'w+')
        log.log("Buffering into file: \"%s\"" % inbuf.name)
        lineCount = 0
        for line in infile:
            lineCount += 1
            inbuf.write(line)
            progCounter.add(1, view=True)
            progCounter.view()
    progCounter.flush()
    log.log("Lines: %s" % lineCount)
    inbuf.seek(0)
    return inbuf, lineCount

def int2str(number, digits, suppress='0'):
    strNumber = str(number)
    lenNumber = len(strNumber)
    return suppress*(digits-lenNumber) + strNumber

def getPrefix(conf):
    return "%(tmpdir)s/%(basename)s" % conf

def splitFile(conf):
    threads = conf.require('threads')
    splitSize = conf.get('splitSize', None)
    if not reportInit(conf, 'split'):
        waitReportDone(conf, 'split')
        return True
    inbuf, lineCount = getInBuffer(conf)
    if lineCount == 0:
        log.log('Nothing to do')
        remove(inbuf)
        return
    prefix = getPrefix(conf)
    if not splitSize:
        splitSize = int( math.ceil(float(lineCount) / threads) )
        log.log('Split size: %s' % splitSize)
    #splitCount = conf.data.splitCount = int(math.ceil(float(lineCount) / splitSize))
    splitCount = int(math.ceil(float(lineCount) / splitSize))
    #digits = conf.data.digits = len(str(splitCount))
    digits = len(str(splitCount))
    log.log('Splitting into: "%s.*"' % prefix)
    progCounter = progress.ProgressCounter(1, "splitting", force=True)
    with inbuf:
        for fileNumber in range(1, splitCount+1):
            path = "%s.%s" % (prefix, int2str(fileNumber,digits,'0'))
            with open(path,'w') as outfile:
                for _ in range(0, splitSize):
                    line = inbuf.readline()
                    if line:
                        outfile.write(line)
                        progCounter.add(1, view=True)
                    else:
                        break
    progCounter.flush()
    log.log('Finished to split')
    remove(inbuf)
    reportDone(conf, 'split')
    return True

def getFileNumberDigits(conf):
    MAX_DIGITS=20
    prefix = getPrefix(conf)
    for digits in range(1, MAX_DIGITS+1):
        path = "%s.%s" % (prefix,int2str(1, digits, '0'))
        if os.path.exists(path):
            return digits
    log.alert("Failed to get file number digits")

def runWorkers(conf):
    fileNumber = 1
    prefix = getPrefix(conf)
    digits = getFileNumberDigits(conf)
    workers = []
    while True:
        strFileNumber = int2str(fileNumber, digits, '0')
        inpath = "%s.%s" % (prefix, strFileNumber)
        #log.debug(path)
        #log.debug(os.path.exists(path))
        if not os.path.exists(inpath):
            break
        outpath = "%s.%s.out" % (prefix, strFileNumber)
        cmdline = "%s < %s > %s" % (conf.data.command, inpath, outpath)
        #if len(workers) < conf.data.threads:
        p = subprocess.Popen(cmdline, shell=True)
        log.log("Executing: %s" % cmdline)
        log.debug(p)
        while True:
            if p.poll() != None:
                break
            time.sleep(1)
        #reportInit(conf, 'cmd.%s' % strFileNumber)
        fileNumber += 1

def execParallel(conf = None, **others):
    conf = Config(conf, **others)
    conf.setdefault('inpath',  '/dev/stdin')
    conf.setdefault('outpath', '/dev/stdout')
    conf.setdefault('splitSize', None)
    conf.setdefault('threads', numCPUs)
    conf.setdefault('tmpdir', './tmp')
    log.debug(conf)
    hostproc = conf.data.hostproc = getHostProcID()
    forceMakeDirs(conf.data.tmpdir)
    log.log("Host+Proc ID: \"%s\"" % hostproc)
    basename = conf.data.basename = os.path.basename(conf.data.inpath)
    splitFile(conf)
    runWorkers(conf)

def cmdExecParallel(args):
    parser = argparse.ArgumentParser(description='Execute command in multiple processes by splitting the target file')
    #parser.add_argument('infile', type=str, help='input file name for execution')
    #parser.add_argument('outfile', type=str, help='output file name for execution')
    parser.add_argument('command', type=str, help='command line string for execution, replacing %%1 and %%2 with input and output files respectively')
    parser.add_argument('--input',  '-I', dest='inpath', type=str, default='/dev/stdin',  help='path to input file for execution (default: /dev/stdin)')
    parser.add_argument('--output', '-O', dest='outpath', type=str, default='/dev/stdout', help='path to output file for execution (default: /dev/stdout)')
    #parser.add_argument('--digitsize', '-d', type=int, default=6, help='assign the number of digits in suffix of splitted files')
    parser.add_argument('--splitsize', '-s', dest='splitSize', type=int, default=None, help='assign the size (number of lines) of each splitted file')
    parser.add_argument('--threads', '-n', type=int, default=numCPUs, help='assign the number of processes (default: %s in your computer' % numCPUs)
    parser.add_argument('--tmpdir', '-t', type=str, default='./tmp', help='assign the path of working directory')
    parser.add_argument('--verbose', '-v', action='store_true', help='verbosely print progressive messages')
    parsed = parser.parse_args(args)
    conf = Config(vars(parsed))
    print(conf)
    #execParallel(**vars(parsed))
    execParallel(conf)

if __name__ == '__main__':
    cmdExecParallel(sys.argv[1:])

