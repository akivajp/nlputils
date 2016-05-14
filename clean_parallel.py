#!/usr/bin/env python

import argparse
import os
import re
import sys
import unicodedata

import progress
from common import compat

def getLongestCommonPrefix(s1, s2):
    index = 0
    f1 = s1.split('.')
    f2 = s2.split('.')
    while True:
        if len(f1) <= index or len(f2) <= index:
            break
        if f1[index] != f2[index]:
            break
        index += 1
    return str.join('.', f1[0:index])

def getLongestCommonSuffix(s1, s2):
    return getLongestCommonPrefix(s1[::-1],s2[::-1])[::-1]

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

def getDiff(s, prefix, suffix):
    if len(suffix) == 0:
        return s[len(prefix):None]
    else:
        return s[len(prefix):-len(suffix)]

def cleanParallel(**args):
    srcFilePaths = args.get('srcFilePaths')
    #outPrefix = args.get('outfileprefix')
    outTag = args.get('outTag')
    minLength = args.get('min')
    maxLength = args.get('max')

    #print(args)
    srcBaseNames = map(os.path.basename, srcFilePaths)
    commonPrefix = reduce(getLongestCommonPrefix, srcBaseNames)
    commonSuffix = reduce(getLongestCommonSuffix, srcBaseNames)
    print(commonPrefix)
    print(commonSuffix)
    outpaths = []
    for path in srcFilePaths:
        if outTag[0:1] != '.':
            outTag = '.' + outTag
        if commonSuffix:
            outpath = path + outTag
        else:
            diff = getDiff(path, commonPrefix, commonSuffix)
            #print(diff)
            outpath = commonPrefix + outTag + diff
        outpaths.append(outpath)
    #print(outpaths)
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
    DEFAULT_MIN_LENGTH = 1
    DEFAULT_MAX_LENGTH = 80
    DEFAULT_RATIO = 9.0
    parser = argparse.ArgumentParser(description='Clean parallel corpus by length and normalize Unicode chars')
    parser.add_argument('srcFilePaths', metavar="filepath", nargs="+", type=str, help='path of file to clean')
    parser.add_argument('outTag', metavar="output_tag", type=str, help='tag added in name of file to save')
    parser.add_argument('--min', default=DEFAULT_MIN_LENGTH, type=int, help='minimum #words per line')
    parser.add_argument('--max', default=DEFAULT_MAX_LENGTH, type=int, help='maximum #words per line')
    parser.add_argument('--ratio', default=DEFAULT_RATIO, type=float, help='upper bound of maximal ratio of #words between each 2 lines')
    parsed = parser.parse_args(args)
    cleanParallel(**vars(parsed))

if __name__ == '__main__':
    cmdCleanParallel(sys.argv[1:])

