#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''Pipe-view script for I/O progress'''

# Common Initialization
import nlputils.init
# Standard libraries
import argparse
import sys
# Local libraries
from common.progress import pipe_view

def cmdPipeView(args):
    REFRESH_INTERVAL = 1
    parser = argparse.ArgumentParser(description='Show the progress of pipe I/O')
    parser.add_argument('filepaths', metavar="filepath", nargs="*", type=str, help='path of file to load')
    parser.add_argument('--lines', '-l', action='store_true', help='line count mode (default: byte count mode)')
    parser.add_argument('--refresh', '-r', type=float, default=1.0, help='refresh interval (default: %(default)s')
    parser.add_argument('--head', '-H', type=str, help='header of the progress information')
    parsed = parser.parse_args(args)
    mode = 'bytes'
    if parsed.lines:
        mode = 'lines'
    pipe_view(parsed.filepaths, mode=mode, head=parsed.name, refresh=parsed.refresh)

def main():
    cmdPipeView(sys.argv[1:])

if __name__ == '__main__':
    main()

