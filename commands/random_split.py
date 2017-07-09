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
from nlputils.common import environ
from nlputils.common import logging
from nlputils.common import numbers
from nlputils.common import progress
from nlputils.common.config import Config

def get_valid_indices(conf):
    #indices = set()
    indices = []
    infiles = [files.open(path,'rb') for path in conf.data.inpaths]
    for i, lines in enumerate(progress.view(compat.zip(*infiles), 'loading')):
        try:
            lines = map(compat.to_unicode, lines)
            if conf.data.ignore_empty:
                if all([line.rstrip("\n") for line in lines]):
                        indices.append(i)
            else:
                indices.append(i)
        except Exception as e:
            #sys.stdout.write("\n")
            logging.warn("%s (Line %s)" % (e, i))
    return indices

def random_split(conf, **others):
    conf = Config(conf, **others)
    check_config(conf)

    inpaths = conf.data.inpaths
    prefixes = conf.data.prefixes
    suffixes = conf.data.suffixes
    tags = conf.data.tags
    split_sizes = conf.data.split_sizes
    verbose = conf.data.verbose

    for path in inpaths:
        files.testFile(path)
    if verbose:
        logging.log('Building sequence')
    indices = get_valid_indices(conf)
    if verbose:
        logging.debug(len(indices))
    if conf.data.seed:
        random.seed(conf.data.seed)
    if verbose:
        logging.log("Randomizing sequence")
    random.shuffle(indices)
    start = 0
    split_indices = []
    for size in split_sizes:
        if size == '*':
            size = len(indices)
        elif size < 1:
            size = int(len(indices) * size)
        else:
            size = int(size)
        split_indices.append( set(indices[start:start+size]) )
        start += size
    split_sizes = list( map(len, split_indices) )
    for inpath, prefix, suffix in zip(inpaths, prefixes, suffixes):
        infile = files.open(inpath, 'rb')
        outpaths = []
        for tag in tags:
            if suffix:
                outpath = "%s%s.%s" % (prefix, tag, suffix)
            else:
                outpath = "%s%s" % (prefix, tag)
            outpaths.append(outpath)
        logging.log("Writing lines into splitted files: %s" % outpaths)
        logging.log("Split sizes: %s" % split_sizes)
        outfiles = [files.open(outpath,'wb') for outpath in outpaths]
        for line_index, line in enumerate(progress.view(infile, 'processing')):
            for file_index, outfile in enumerate(outfiles):
                if line_index in split_indices[file_index]:
                    outfile.write(line)
    if conf.data.ids:
        for file_index, tag in enumerate(tags):
            outpath = "%s.%s" % (tag, conf.data.ids)
            genIDs = iter(sorted(split_indices[file_index]))
            if progress:
                genIDs = progress.view(genIDs, "Writing IDs into '%s'" % outpath)
            outfile = files.open(outpath, 'wt')
            for line_index in genIDs:
                # line index is zero origin, line id should be +1
                outfile.write("%d\n" % (line_index+1))

def check_config(conf):
    numInput = len(conf.data.input)
    numTags  = len(conf.data.tags)
    conf.data.inpaths = conf.data.input
    conf.data.seed        = conf.data.random_seed
    conf.data.split_sizes  = conf.data.split_sizes
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
    if len(conf.data.split_sizes) != numTags:
        msg="Number of split sizes should be same with input files (expected %d, but given %d)"
        logging.alert(msg % (numTags, len(conf.data.split_sizes)))
        return False
    for i, size in enumerate(conf.data.split_sizes):
        if size == '*':
            pass
        else:
            try:
                n = float(size)
                conf.data.split_sizes[i] = n
            except Exception as e:
                msg = "string '%s' cannnot be converted to number (given invalid split sizes: %s)"
                logging.alert(msg % (size, conf.data.split_sizes))
            if n <= 0:
                msg = "split size should be positive, but given negative: %s (given invalid split sizes: %s)"
                logging.alert(msg % (n, conf.data.split_sizes))
    if conf.data.verbose:
        logging.debug(conf)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', '-I', help='input files', type=str, required=True, nargs='+')
    parser.add_argument('--prefixes', '-P', help='prefixes of splitted files (should be same number with INPUT)', type=str, default=[], nargs='+')
    parser.add_argument('--suffixes', '-S', help='suffixes of splittted files (should be same number with INPUT)', type=str, default=[], nargs='+')
    parser.add_argument('--tags', help='base names of splitted files (comma separated list)', type=str, required=True, nargs='+')
    parser.add_argument('--split-sizes', '-s', help='number of lines in splitted files (should be same number with TAGS)', type=str, required=True, nargs='+')
    parser.add_argument('--ignore-empty', '-E', help='preventing empty lines to output', action='store_true')
    parser.add_argument('--quiet', '-q', help='not showing staging log', action='store_true')
    parser.add_argument('--verbose', '-v', help='verbose mode (including debug info)', action='store_true')
    parser.add_argument('--random-seed', '-R', help='random seed', type=int)
    parser.add_argument('--ids', metavar='SUFFIX', help='write original line numbers for each tags', nargs='?', const='ids')
    args = parser.parse_args()
    logging.log('test')
    conf = Config()
    conf.update(vars(args))
    with environ.push() as e:
        if conf.data.verbose:
            e.set('DEBUG', '1')
        logging.debug(args)
        random_split(conf)

if __name__ == '__main__':
    main()

