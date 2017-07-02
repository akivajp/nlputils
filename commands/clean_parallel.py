#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Common Initialization
import nlputils.init
# Standard libraries
import argparse
import os
import re
import sys
import unicodedata
from functools import reduce
# Local libraries
from nlputils.common import progress
from nlputils.common import compat
from nlputils.common import logging

REPLACE_MAP = {
    compat.toUnicode('<'): compat.toUnicode('-LT-'),
    compat.toUnicode('>'): compat.toUnicode('-GT-'),
    compat.toUnicode('('): compat.toUnicode('-LRB-'),
    compat.toUnicode(')'): compat.toUnicode('-RRB-'),
    compat.toUnicode('{'): compat.toUnicode('-LCB-'),
    compat.toUnicode('}'): compat.toUnicode('-RCB-'),
    compat.toUnicode('['): compat.toUnicode('-LSB-'),
    compat.toUnicode(']'): compat.toUnicode('-RSB-'),
    compat.toUnicode('|'): compat.toUnicode('-BAR-'),
    compat.toUnicode('&'): compat.toUnicode('-AMP-'),
    compat.toUnicode('\t'): compat.toUnicode(' '),
    unicodedata.lookup('ZERO WIDTH SPACE'): compat.toUnicode(' '),
    unicodedata.lookup('ZERO WIDTH NO-BREAK SPACE'): compat.toUnicode(' '),
}

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

def replaceChar(c):
    if c in REPLACE_MAP:
        #logging.log("Replacing '%s' -> '%s'" % (c, REPLACE_MAP[c]))
        return REPLACE_MAP[c]
    else:
        return c

def normalize(line):
    line = compat.toUnicode( line.strip() )
    line = unicodedata.normalize('NFKD', line)
    line = compat.toUnicode('').join(map(replaceChar, line))
    line = unicodedata.normalize('NFC', line)
    line = compat.toStr(line)
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
    srcBaseNames = list( map(os.path.basename, srcFilePaths) )
    commonPrefix = reduce(getLongestCommonPrefix, srcBaseNames)
    commonSuffix = reduce(getLongestCommonSuffix, srcBaseNames)
    #print(commonPrefix)
    #print(commonSuffix)
    outPaths = []
    for path in srcFilePaths:
        if outTag[0:1] != '.':
            outTag = '.' + outTag
        if commonSuffix:
            outPath = path + outTag
        else:
            diff = getDiff(path, commonPrefix, commonSuffix)
            #print(diff)
            outPath = commonPrefix + outTag + diff
        outPaths.append(outPath)
    logging.log("Writing cleaned corpora into: %s" % str.join(' ',outPaths))
    if sys.version_info.major >= 3:
        infiles  = [open(path,'rb') for path in srcFilePaths]
    else:
        infiles  = [open(path,'r') for path in srcFilePaths]
    outfiles = [open(path,'w') for path in outPaths]
    counter = progress.SpeedCounter(name='Processed')
    for i, lines in enumerate(zip(*infiles)):
        counter.add()
        counter.view()
        try:
            lines = list( map(normalize, lines) )
            if checkLength(lines, minLength, maxLength):
                for i, line in enumerate(lines):
                    outfiles[i].write(line)
                    outfiles[i].write("\n")
        except Exception as e:
            #sys.stdout.write("\n")
            logging.warn("%s (Line %s)" % (e, i))
    counter.flush()

def cmdCleanParallel(args):
    DEFAULT_MIN_LENGTH = 1
    DEFAULT_MAX_LENGTH = 80
    DEFAULT_RATIO = 9.0
    parser = argparse.ArgumentParser(description='Clean parallel corpus by length and normalize Unicode chars')
    parser.add_argument('srcFilePaths', metavar="filepath", nargs="+", type=str, help='path of file to clean')
    parser.add_argument('outTag', metavar="output_tag", type=str, help='tag added in name of file to save')
    parser.add_argument('--min', default=DEFAULT_MIN_LENGTH, type=int, help='minimum #words per line (default: %(default)s)')
    parser.add_argument('--max', default=DEFAULT_MAX_LENGTH, type=int, help='maximum #words per line (default: %(default)s)')
    parser.add_argument('--ratio', default=DEFAULT_RATIO, type=float, help='upper bound of maximal ratio of #words between each 2 lines (default: %(default)s)')
    parsed = parser.parse_args(args)
    cleanParallel(**vars(parsed))

if __name__ == '__main__':
    cmdCleanParallel(sys.argv[1:])

