#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Standard libraries
import argparse
import math
import multiprocessing
import os
import subprocess
import sys
import time

# Cython set-up
from common import pyximportcpp ; pyximportcpp.install()
# Local libraries
from common import files
from common import progress
from common.config import Config
from common import log
from wait_files import waitFile

numCPUs = multiprocessing.cpu_count()
SLEEP_DURATION = 1.0

#def getHostProcID():
def getCurrentWorkerID():
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
    #elif type(f) == file:
    elif files.isFileType(f):
        log.log('Removing file: %s' % f.name)
        f.close()
        os.remove(f.name)

def checkFile(filepath):
    if os.path.exists(filepath):
        log.log('File already exists: %s' % filepath)
        return True
    else:
        return False

#def checkStage(tmpdir, basename, stage):
#def checkPhase(tmpdir, phase):
def checkPhase(conf, phase):
    tmpdir = conf.data.tmpdir
#    if checkFile('%s/__INIT__.%s.%s' % (tmpdir,stage,basename)):
    if checkFile('%s/report.%s.begin' % (tmpdir,phase)):
        return 'started'
#    elif checkFile('%s/__DONE__.%s.%s' % (tmpdir,stage,basename)):
    elif checkFile('%s/report.%s.done' % (tmpdir,phase)):
        return 'finished'
    else:
        return 'none'

def getPhaseCharge(conf, phase):
    tmpdir = conf.data.tmpdir
    #basename = conf.data.basename
    #path = '%(tmpdir)s/__INIT__.%(stage)s.%(basename)s' % locals()
    path = '%(tmpdir)s/report.%(phase)s.begin' % locals()
    #return open(path, 'r').read()
    chargeID = open(path, 'r').read()
    return chargeID

def checkPhaseCharge(conf, phase):
    if getPhaseCharge(conf,phase) != getCurrentWorkerID():
        log.alert('Failed to confirm the responsible process of the phase: "%s"' % phase)

def reportInit(conf, phase):
    tmpdir = conf.data.tmpdir
    #basename = conf.data.basename
    #path = '%(tmpdir)s/__INIT__.%(stage)s.%(basename)s' % locals()
    path = '%(tmpdir)s/report.%(phase)s.begin' % locals()
    #if not report(path, conf.data.hostproc):
    if not report(path, getCurrentWorkerID()):
        return False
    log.log('Waiting %s second to confirm the responsible process of the phase' % conf.data.interval)
    time.sleep(conf.data.interval)
    checkPhaseCharge(conf, phase)
    return True

def reportDone(conf, phase):
    tmpdir = conf.data.tmpdir
    #basename = conf.data.basename
    #return report('%(tmpdir)s/__DONE__.%(stage)s.%(basename)s'%locals(), conf.data.hostproc)
    return report('%(tmpdir)s/report.%(phase)s.done'%locals(), getCurrentWorkerID())

def waitPhaseDone(conf, phase):
    tmpdir = conf.data.tmpdir
    #basename = conf.data.basename
    #return waitFile('%(tmpdir)s/__DONE__.%(stage)s.%(basename)s'%locals())
    return waitFile('%(tmpdir)s/report.%(phase)s.done'%locals())

def getInBuffer(conf):
    #bufname = '%s/__BUFFER__%s' % (tmpdir,hostproc)
    #bufname = '%(tmpdir)s/__BUFFER__%(hostproc)s' % conf
    bufname = '%(tmpdir)s/tmp.buffer' % conf
    progCounter = progress.ProgressCounter(1, "buffering", force=True)
    with open(conf.data.inPath, 'r') as inFile:
        inbuf = open(bufname, 'w+')
        log.log("Buffering into file: \"%s\"" % inbuf.name)
        lineCount = 0
        for line in inFile:
            lineCount += 1
            inbuf.write(line)
            progCounter.add(1, view=True)
            progCounter.view()
    conf.data.lineCount = lineCount
    progCounter.flush()
    log.log("Lines: %s" % lineCount)
    inbuf.seek(0)
    return inbuf

def int2str(number, digits, suppress='0'):
    strNumber = str(number)
    lenNumber = len(strNumber)
    return suppress*(digits-lenNumber) + strNumber

def getSplitPrefix(conf):
    #return "%(tmpdir)s/%(basename)s" % conf
    return "%(tmpdir)s/split" % conf

def splitFile(conf):
    #threads = conf.require('threads')
    splitSize = conf.get('splitSize', None)
    numChunks = conf.data.numChunks
    configFile = "%s/config.json" % conf.data.tmpdir
    if not reportInit(conf, 'split'):
        waitPhaseDone(conf, 'split')
        log.debug(conf)
        log.log("Updating the configuration with: %s" % configFile)
        conf.loadJSON(open(configFile).read())
        log.debug(conf)
        return True
    inbuf = getInBuffer(conf)
    lineCount = conf.data.lineCount
    if lineCount == 0:
        log.log('Nothing to do')
        remove(inbuf)
        return
    #prefix = getPrefix(conf)
    #strSplitPrefix = conf.data.tmpdir + "/split"
    prefix = getSplitPrefix(conf)
    if not splitSize:
        #splitSize = int( math.ceil(float(lineCount) / threads) )
        splitSize = conf.data.splitSize = int( math.ceil(float(lineCount) / numChunks) )
        log.log('Split size: %s' % splitSize)
    #splitCount = conf.data.splitCount = int(math.ceil(float(lineCount) / splitSize))
    #splitCount = int(math.ceil(float(lineCount) / splitSize))
    numChunks = conf.data.numChunks = int(math.ceil(float(lineCount) / splitSize))
    #digits = conf.data.digits = len(str(splitCount))
    digits = conf.data.digits = len(str(numChunks))
    log.log('Splitting into: "%s.*"' % prefix)
    progCounter = progress.ProgressCounter(1, "splitting", force=True, maxCount=lineCount)
    with inbuf:
        for fileNumber in range(1, numChunks+1):
            path = "%s.%s.in" % (prefix, int2str(fileNumber,digits,'0'))
            with open(path,'w') as outFile:
                for _ in range(0, splitSize):
                    line = inbuf.readline()
                    if line:
                        outFile.write(line)
                        progCounter.add(1, view=True)
                    else:
                        break
    progCounter.flush()
    log.log('Finished to split')
    remove(inbuf)
    log.log('Saving configuration into: %s' % configFile)
    with open(configFile, 'w') as fobj:
        fobj.write(conf.toJSON(indent=4))
    reportDone(conf, 'split')
    return True

#def getFileNumberDigits(conf):
#    MAX_DIGITS=20
#    #prefix = getPrefix(conf)
#    prefix = getSplitPrefix(conf)
#    for digits in range(1, MAX_DIGITS+1):
#        path = "%s.%s.in" % (prefix,int2str(1, digits, '0'))
#        if os.path.exists(path):
#            return digits
#    log.alert("Failed to get file number digits")

def waitAvailableWorker(conf, workers, flush = False):
    threads = min(conf.data.threads, numCPUs)
    if flush:
        threads = 1
    if len(workers) == 0:
        return
    while True:
        for i, (proc,phase) in enumerate(workers):
            if proc.poll() != None:
                conf.data.processed += 1
                reportDone(conf,phase)
                workers.pop(i)
                break
        else:
            time.sleep(conf.data.interval)
        if len(workers) < threads:
            break
    processed = conf.data.processed
    numChunks = conf.data.numChunks
    ratio = float(processed) / numChunks
    strTemplate = "Processed files: %s / %s (%2.2f%%), Active processes: %s / %s"
    strMessage = strTemplate % (processed,numChunks,ratio*100,len(workers),threads)
    log.log(strMessage)

def runWorkers(conf):
    #fileNumber = 1
    #prefix = getPrefix(conf)
    prefix = getSplitPrefix(conf)
    #digits = getFileNumberDigits(conf)
    numChunks = conf.data.numChunks
    digits = conf.data.digits = len(str(numChunks))
    #threads = min(conf.data.threads,numCPUs)
    workers = []
    conf.data.processed = 0
    for fileNumber in range(1, numChunks+1):
        strFileNumber = int2str(fileNumber, digits, '0')
        strPhase = 'cmd.%s' % strFileNumber
        inPath = "%s.%s.in" % (prefix, strFileNumber)
        outPath = "%s.%s.out" % (prefix, strFileNumber)
        cmdline = "%s < %s > %s" % (conf.data.command, inPath, outPath)
        waitAvailableWorker(conf, workers)
        if not reportInit(conf, strPhase):
            log.log("Skipping processing: %s" % inPath)
            #if checkPhase(conf.data.tmpdir, strPhase) == 'finished':
            if checkPhase(conf, strPhase) == 'finished':
                conf.data.processed += 1
            continue
        proc = subprocess.Popen(cmdline, shell=True)
        workers.append([proc,strPhase])
        log.log("Executing: %s" % cmdline)
        #log.debug(p)
        #reportInit(conf, 'cmd.%s' % strFileNumber)
        fileNumber += 1
    waitAvailableWorker(conf, workers, flush=True)

def concatFiles(conf):
    if not reportInit(conf, 'concat'):
        waitPhaseDone(conf, 'concat')
        chargeID = getPhaseCharge(conf, 'concat')
        log.log("Finalizing (concatenation) process is running: %s" % chargeID)
        return True
    prefix = getSplitPrefix(conf)
    numChunks = conf.data.numChunks
    lineCount = conf.data.lineCount
    digits = conf.data.digits = len(str(numChunks))
    #outPath = "%s.out" % (prefix)
    outPath = conf.data.outPath
    conf.data.processed = 0
    progCounter = progress.ProgressCounter(1, "concat", force=True, maxCount=lineCount)
    for fileNumber in range(1, numChunks+1):
        strFileNumber = int2str(fileNumber, digits, '0')
        inPath = "%s.%s.out" % (prefix, strFileNumber)
        waitFile(inPath)
        conf.data.processed += 1
    log.log('Concatenating: "%s.*" -> "%s"' % (prefix,outPath))
    with open(outPath, 'w') as outFile:
        for fileNumber in range(1, numChunks+1):
            strFileNumber = int2str(fileNumber, digits, '0')
            inPath = "%s.%s.out" % (prefix, strFileNumber)
            with open(inPath, 'r') as inFile:
                for line in inFile:
                    outFile.write(line)
                    progCounter.add(1, view=True)
    progCounter.flush()
    reportDone(conf, 'concat')

def checkConfig(conf):
    conf.setdefault('inPath',  '/dev/stdin')
    conf.data.inPath = os.path.abspath(conf.data.inPath)
    conf.setdefault('outPath', '/dev/stdout')
    conf.data.outPath = os.path.abspath(conf.data.outPath)
    #conf.setdefault('splitSize', None)
    conf.setdefault('interval', SLEEP_DURATION)
    conf.setdefault('threads', numCPUs)
    conf.setdefault('numChunks', conf.data.threads)
    if conf.data.numChunks <= 0:
        strTemplate = "--chunks (number of splitted files) should be positive integer: %s"
        strMessage = strTemplate % (conf.data.numChunks)
        log.alert(strMessage)
    conf.setdefault('basename', os.path.basename(conf.data.inPath))
    conf.setdefault('tmpdir', './tmp-%s' % conf.data.basename)
    conf.data.tmpdir = os.path.abspath(conf.data.tmpdir)
    #if conf.data.threads > numCPUs:
    #    strTemplate = "Number of worker processes is limited to number of available threads: %s -> %s"
    #    strMessage = strTemplate % (conf.data.threads, numCPUs)
    #    log.warn(strMessage)
    #    conf.data.threads = numCPUs

def execParallel(conf = None, **others):
    conf = Config(conf, **others)
    checkConfig(conf)
    log.debug(conf)
    #hostproc = conf.data.hostproc = getHostProcID()
    workerID = getCurrentWorkerID()
    files.safeMakeDirs(conf.data.tmpdir)
    log.log("Worker ID (Host+Proc): \"%s\"" % workerID)
    splitFile(conf)
    runWorkers(conf)
    concatFiles(conf)

def cmdExecParallel(args):
    parser = argparse.ArgumentParser(description='Execute command in multiple processes by splitting the target file')
    #parser.add_argument('inFile', type=str, help='input file name for execution')
    #parser.add_argument('outFile', type=str, help='output file name for execution')
    parser.add_argument('command', type=str, help='command line string for execution, replacing %%1 and %%2 with input and output files respectively')
    parser.add_argument('--input',  '-I', dest='inPath', type=str, default='/dev/stdin',  help='path to input file for execution (default: /dev/stdin)')
    parser.add_argument('--output', '-O', dest='outPath', type=str, default='/dev/stdout', help='path to output file for execution (default: /dev/stdout)')
    #parser.add_argument('--digitsize', '-d', type=int, default=6, help='assign the number of digits in suffix of splitted files')
    parser.add_argument('--splitsize', '-s', dest='splitSize', type=int, default=None, help='assign the size (number of lines) of each splitted file')
    parser.add_argument('--chunks', '-c', dest='numChunks', type=int, default=None, help='assign the number of splitted files (default: same as --threads parameter)')
    parser.add_argument('--threads', '-n', type=int, default=None, help='assign the maximum number of worker processes (default: %s in your computer' % numCPUs)
    #parser.add_argument('--tmpdir', '-t', type=str, default='./tmp', help='assign the path of working directory')
    parser.add_argument('--tmpdir', '-t', type=str, default=None, help='assign the path of working directory (default: "./tmp-[basename]"')
    parser.add_argument('--verbose', '-v', action='store_true', help='verbosely print progressive messages')
    parser.add_argument('--interval', '-i', type=float, default=SLEEP_DURATION, help='sleep time duration for each confirmation (default: %(default)s)')
    parsed = parser.parse_args(args)
    conf = Config(vars(parsed))
    print(conf)
    #execParallel(**vars(parsed))
    execParallel(conf)

if __name__ == '__main__':
    cmdExecParallel(sys.argv[1:])

