#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Common Initialization
import nlputils.init
# Standard libraries
import argparse
import os
import sys
import time
# Local libraries
from nlputils.common import logging

def waitFile(filepath, quiet=False, interval=1, timeout=0):
    if interval < 0:
        interval = 1
    if not os.path.exists(filepath):
        logging.log("Waiting for file: %s" % filepath, quiet=quiet)
        firstTime = time.time()
    while not os.path.exists(filepath):
        time.sleep(interval)
        elapsed = time.time() - firstTime
        if timeout > 0 and elapsed > timeout:
                logging.alert("Waiting file (%s) was timed out (%s seconds)" % (filepath, timeout))
    logging.log("File exists: %s" % filepath, quiet=quiet)
    return True

def waitFiles(filepaths, quiet=False, interval=1, timeout=0):
    if type(filepaths) == str:
        filepaths = [filepaths]
    for path in filepaths:
        waitFile(path, quiet, interval, timeout)

def cmdWaitFiles(args):
    parser = argparse.ArgumentParser(description='Wait until file will be found')
    parser.add_argument('filepaths', metavar='filepath', nargs='+', help='file path for waiting')
    parser.add_argument('--quiet', '-q', action='store_true', help='quiet mode')
    parser.add_argument('--interval', '-i', default=1, type=float, help='interval for next trial (default: %(default)s seconds)')
    parser.add_argument('--timeout', '-t', default=0, type=float, help='time limit in waiting file')
    parsed = parser.parse_args(args)
    logging.debug(parsed)
    waitFiles(**vars(parsed))

if __name__ == '__main__':
    cmdWaitFiles(sys.argv[1:])

