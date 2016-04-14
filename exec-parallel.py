#!/usr/bin/env python

import argparse
import os
import sys

def execParallel(**args):
    #stub
    print(args)

def cmdExecParallel(args):
    parser = argparse.ArgumentParser(description='Execute command in multiple processes by splitting the target file')
    parser.add_argument('infile', type=str, help='input file name for execution')
    parser.add_argument('outfile', type=str, help='output file name for execution')
    parser.add_argument('command', type=str, help='command line string for execution, replacing %1 and %2 with input and output files respectively')
    parsed = parser.parse_args(args)
    execParallel(**vars(parsed))

if __name__ == '__main__':
    cmdExecParallel(sys.argv[1:])

