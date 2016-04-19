#!/usr/bin/env python

import argparse
import os
import re
import sys
import unicodedata

import progress
from common import compat

DEFAULT_MIN_LENGTH = 1
DEFAULT_MAX_LENGTH = 80
DEFAULT_RATIO = 9.0

def getLongestCommonPrefix(s1, s2):
    index = 0
    while True:
        if len(s1) <= index or len(s2) <= index:
            break
        if s1[index] != s2[index]:
            break
        index += 1
    return s1[0:index]

def normalize(line):
    line = line.strip()
    line = unicodedata.normalize('NFKC', compat.toUnicode(line))
    line = re.sub(r'\s+', ' ', line)
    return line

def checkLength(lines, minLength, maxLength):
    for line in lines:
        words = line.split()
        if len(words) < minLength: return False
        if len(words) > maxLength: return False
    return True

def cleanParallel(**args):
    srcFilePaths = args.get('srcfilepaths')
    outPrefix = args.get('outfileprefix')
    minLength = args.get('min')
    maxLength = args.get('max')

    #print(args)
    prefix = reduce(getLongestCommonPrefix, srcFilePaths)
    suffixes = [path[len(prefix):None] for path in srcFilePaths]
    outpaths = []
    for suffix in suffixes:
        filepath = outPrefix + suffix
        if outPrefix[-1:None] == '.' and suffix[0:1] == '.':
            filepath = outPrefix + suffix[1:None]
        outpaths.append(filepath)
    infiles  = [open(path,'r') for path in srcFilePaths]
    outfiles = [open(path,'w') for path in outpaths]
    counter = progress.ProgressCounter(name='Processed')
    for lines in zip(*infiles):
        lines = map(normalize, lines)
        if checkLength(lines, minLength, maxLength):
            for i, line in enumerate(lines):
                outfiles[i].write(compat.toStr(line))
                outfiles[i].write("\n")
        counter.add()
        counter.view(force=True)
    counter.flush(force=True)

def cmdCleanParallel(args):
    parser = argparse.ArgumentParser(description='Clean parallel corpus by length and normalize Unicode chars')
    parser.add_argument('srcfilepaths', metavar="filepath", nargs="+", type=str, help='path of file to clean')
    parser.add_argument('outfileprefix', metavar="filepath_prefix", type=str, help='path of file to save')
    parser.add_argument('--min', default=DEFAULT_MIN_LENGTH, type=int, help='minimum #words per line')
    parser.add_argument('--max', default=DEFAULT_MAX_LENGTH, type=int, help='maximum #words per line')
    parser.add_argument('--ratio', default=DEFAULT_RATIO, type=float, help='upper bound of maximal ratio of #words between each 2 lines')
    parsed = parser.parse_args(args)
    cleanParallel(**vars(parsed))

if __name__ == '__main__':
    cmdCleanParallel(sys.argv[1:])

