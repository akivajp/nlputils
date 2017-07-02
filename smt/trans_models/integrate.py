#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''function integrating 2 rule tables having the same language pairs into 1 table'''

import argparse

# my exp libs
import exp.phrasetable.integrate as base
from exp.ruletable.record import TravatarRecord

# limit number of records for the same source phrase
NBEST = 20

# methods to estiamte translation probs (count/interpolate)
methods = ['count', 'interpolate', 'fillup', 'flexible']
METHOD = 'count'

lexMethods = ['count', 'interpolate']
LEX_METHOD = 'interpolate'

FACTOR_DIRECT = 0.9

def main():
    parser = argparse.ArgumentParser(description = 'load 2 phrase tables and pivot into one moses phrase table')
    parser.add_argument('table1', help = 'phrase table 1')
    parser.add_argument('table2', help = 'phrase table 2')
    parser.add_argument('savefile', help = 'path for saving moses phrase table file')
    parser.add_argument('--nbest', help = 'best n scores for phrase pair filtering (default = 20)', type=int, default=NBEST)
    parser.add_argument('--workdir', help = 'working directory', default='.')
    parser.add_argument('--lexfile', help = 'word pair counts file', default=None)
    parser.add_argument('--method', help = 'triangulation method', choices=methods, default=METHOD)
    parser.add_argument('--lexmethod', help = 'lexical triangulation method', choices=lexMethods, default=LEX_METHOD)
    args = vars(parser.parse_args())

    args['RecordClass'] = TravatarRecord
    args['prefix'] = 'rule'
    base.integrate(**args)

if __name__ == '__main__':
    main()

