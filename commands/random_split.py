#!/usr/bin/env python
# -*- coding: utf-8 -*-


# Common Initialization
import nlputils.init

# Standard libraries
import argparse
import os
import random
import sys

# Local libraries
from nlputils.common import compat
from nlputils.common import files
from nlputils.common import logging
from nlputils.common import numbers
from nlputils.common import progress
from nlputils.common.config import Config

def getValidIndices(conf):
    #indices = set()
    indices = []
    inFiles = [files.open(path) for path in conf.data.inputFiles]
    genLines = compat.zip(*inFiles)
    if conf.data.progress:
        genLines = progress.view(genLines, 'reading input files')
    for i, lines in enumerate(genLines):
        if conf.data.ignoreEmpty:
            if all([line.rstrip("\n") for line in lines]):
                    indices.append(i)
        else:
            indices.append(i)
    return indices

def randomSplit(conf, **others):
    conf = Config(conf, **others)
    checkConfig(conf)

    inputFiles = conf.data.inputFiles
    prefixes = conf.data.prefixes
    suffixes = conf.data.suffixes
    tags = conf.data.tags
    splitSizes = conf.data.splitSizes
    verbose = conf.data.verbose

    for path in inputFiles:
        files.testFile(path)
    if verbose:
        logging.log('Building sequence')
    indices = getValidIndices(conf)
    if verbose:
        logging.debug(len(indices))
    if conf.data.seed:
        random.seed(conf.data.seed)
    if verbose:
        logging.log("Randomizing sequence")
    random.shuffle(indices)
    start = 0
    splitIndices = []
    for size in splitSizes:
        if size == '*':
            size = len(indices)
        elif size < 1:
            size = int(len(indices) * size)
        else:
            size = int(size)
        splitIndices.append( set(indices[start:start+size]) )
        start += size
    splitSizes = list( map(len, splitIndices) )
    for inPath, prefix, suffix in zip(inputFiles, prefixes, suffixes):
        if progress:
            inFile = progress.open(inPath, "processing file '%s'" % inPath)
        else:
            inFile = files.open(inPath)
        outPaths = []
        for tag in tags:
            if suffix:
                outPath = "%s%s.%s" % (prefix, tag, suffix)
            else:
                outPath = "%s%s" % (prefix, tag)
            outPaths.append(outPath)
        if verbose:
            logging.log("Writing lines into splitted files: %s" % outPaths)
            logging.log("Split sizes: %s" % splitSizes)
        outFiles = [files.open(outPath,'wt') for outPath in outPaths]
        for lineIndex, line in enumerate(inFile):
            for fileIndex, outFile in enumerate(outFiles):
                if lineIndex in splitIndices[fileIndex]:
                    outFile.write(line)
    if conf.data.ids:
        for fileIndex, tag in enumerate(tags):
            outPath = "%s.%s" % (tag, conf.data.ids)
            genIDs = iter(sorted(splitIndices[fileIndex]))
            if progress:
                genIDs = progress.view(genIDs, "Writing IDs into '%s'" % outPath)
            outFile = files.open(outPath, 'wt')
            for lineIndex in genIDs:
                # line index is zero origin, line id should be +1
                outFile.write("%d\n" % (lineIndex+1))

def checkConfig(conf):
    numInput = len(conf.data.input)
    numTags  = len(conf.data.tags)
    conf.data.ignoreEmpty = conf.data.ignore_empty
    conf.data.inputFiles  = conf.data.input
    conf.data.seed        = conf.data.random_seed
    conf.data.splitSizes  = conf.data.split_sizes
    if not conf.data.prefixes:
        conf.data.prefixes = [''] * numInput
    elif len(conf.data.prefixes) != numInput:
        msg="Number of prefixes should be same with input files (expected %d, but given %d)"
        logging.alert(msg % (numInput, len(conf.data.prefixes)))
        return False
    if not conf.data.suffixes:
        conf.data.suffixes = [''] * numInput
    elif len(conf.data.suffixes) != numInput:
        msg="Number of suffixes should be same with input files (expected %d, but given %d)"
        logging.alert(msg % (numInput, len(conf.data.suffixes)))
        return False
    if len(conf.data.splitSizes) != numTags:
        msg="Number of split sizes should be same with input files (expected %d, but given %d)"
        logging.alert(msg % (numTags, len(conf.data.splitSizes)))
        return False
    for i, size in enumerate(conf.data.splitSizes):
        if size == '*':
            pass
        else:
            try:
                n = float(size)
                conf.data.splitSizes[i] = n
            except Exception as e:
                msg = "string '%s' cannnot be converted to number (given invalid split sizes: %s)"
                logging.alert(msg % (size, conf.data.splitSizes))
            if n <= 0:
                msg = "split size should be positive, but given negative: %s (given invalid split sizes: %s)"
                logging.alert(msg % (n, conf.data.splitSizes))
    if conf.data.verbose:
        logging.debug(conf)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', '-I', help='input files', type=str, required=True, nargs='+')
    parser.add_argument('--prefixes', '-P', help='prefixes of splitted files (should be same number with INPUT)', type=str, default=[], nargs='+')
    parser.add_argument('--suffixes', '-S', help='suffixes of splittted files (should be same number with INPUT)', type=str, default=[], nargs='+')
    parser.add_argument('--tags', help='base names of splitted files (comma separated list)', type=str, required=True, nargs='+')
    parser.add_argument('--split-sizes', '-s', help='number of lines in splitted files (should be same number with TAGS)', type=str, required=True, nargs='+')
    parser.add_argument('--progress', '-p', help='show progress', action='store_true')
    parser.add_argument('--ignore-empty', '-E', help='preventing empty lines to output', action='store_true')
    parser.add_argument('--verbose', '-v', help='verbose mode', action='store_true')
    parser.add_argument('--random-seed', '-R', help='random seed', type=int)
    parser.add_argument('--ids', metavar='SUFFIX', help='write original line numbers for each tags', nargs='?', const='ids')
    args = parser.parse_args()
    conf = Config()
    conf.update(vars(args))
    if args.verbose:
        logging.debug(args)
    randomSplit(conf)

if __name__ == '__main__':
    main()

