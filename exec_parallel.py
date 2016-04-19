#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import multiprocessing
import os
import sys

numCPUs = multiprocessing.cpu_count()

def forceMakeDirs(dirpath):
    if not os.path.isdir(dirpath):
        sys.stderr.write('Making directory: "%s"\n' % dirpath)
    try:
        os.makedirs(dirpath)
    except:
        sys.stderr.write('[Error] Cannot make directory: "%s"\n' % dirpath)
        sys.exit(1)

def execParallel(infile, outfile, command, **args):
    dsize = args.get('digitsize', 6)
    ssize = args.get('splitsize', 1000)
    threads = args.get('threads', numCPUs)
    tmpdir = args.get('tmpdir', './tmp')
    print(args)
    forceMakeDirs(tmpdir)

def cmdExecParallel(args):
    parser = argparse.ArgumentParser(description='Execute command in multiple processes by splitting the target file')
    parser.add_argument('infile', type=str, help='input file name for execution')
    parser.add_argument('outfile', type=str, help='output file name for execution')
    parser.add_argument('command', type=str, help='command line string for execution, replacing %%1 and %%2 with input and output files respectively')
    parser.add_argument('--digitsize', '-d', type=int, default=6, help='assign the number of digits in suffix of splitted files')
    parser.add_argument('--splitsize', '-s', type=int, default=1000, help='assign the size (number of lines) of each splitted file')
    parser.add_argument('--threads', '-n', type=int, default=numCPUs, help='assign the number of processes (default: %s in your computer' % numCPUs)
    parser.add_argument('--tmpdir', '-t', type=str, default='./tmp', help='assign the path of working directory')
    parsed = parser.parse_args(args)
    execParallel(**vars(parsed))

if __name__ == '__main__':
    cmdExecParallel(sys.argv[1:])

