# distutils: language=c++
# -*- coding: utf-8 -*-
# cython: profile=True

# Standard libraries
import argparse
import itertools
import math
import sys
from collections import defaultdict

# 3-rd party library
import cython
import numpy as np
cimport numpy as np
import scipy.sparse as sp

# Local libraries
from nlputils.common import environ
from nlputils.common import files
from nlputils.common import progress
from nlputils.common import logging
#from nlputils.common import vocab

from nlputils.common.config cimport Config
from nlputils.common.vocab cimport StringEnumerator

ITERATION_LIMIT = 10

NULL_SYMBOL = '__NULL__'

cdef class Vocab:
    cdef StringEnumerator src
    cdef StringEnumerator trg

    def __cinit__(self):
        self.src = StringEnumerator()
        self.trg = StringEnumerator()

cdef tuple grid_indices(list x_indices, list y_indices):
    cdef np.ndarray indices1, indices2
    indices1, indices2 = np.meshgrid(x_indices, y_indices, sparse=True)
    return indices1.T, indices2.T

cdef np.ndarray sub_matrix(np.ndarray matrix, list x_indices, list y_indices):
    return matrix[grid_indices(x_indices, y_indices)]

cdef void add_sub_matrix(np.ndarray target_matrix, list x_indices, list y_indices, np.ndarray source_matrix):
    cdef np.ndarray indices1, indices2
    indices1, indices2 = grid_indices(x_indices, y_indices)
    np.add.at(target_matrix, (indices1,indices2), source_matrix[indices1,indices2])

cdef class Model:
    cdef np.ndarray trans_dist
    cdef Vocab vocab
    #cdef StringEnumerator src_vocab
    #cdef StringEnumerator trg_vocab

    def __cinit__(self):
        self.vocab = Vocab()

    cpdef double calc_pair_entropy(self, list src_sent, list trg_sent):
        cdef np.ndarray trans_matrix
        trans_matrix = sub_matrix(self.trans_dist, src_sent, trg_sent)
        return -np.log(trans_matrix.sum(axis=0) / len(src_sent)).sum()

    cpdef double calc_entropy(self, list sent_pairs):
        cdef float total_entropy = 0
        logging.log('calculating entropy')
        for i, (src_sent, trg_sent) in enumerate(progress.view(sent_pairs, 'progress')):
            total_entropy += self.calc_pair_entropy(src_sent, trg_sent)
        return total_entropy / len(sent_pairs)

    cpdef tuple ids_pair_to_str_pair(self, src_ids, trg_ids):
        cdef StringEnumerator src_vocab = self.vocab.src
        cdef StringEnumerator trg_vocab = self.vocab.trg
        cdef src_str = str.join(' ', [src_vocab.id2str(i) for i in src_ids[:-1]])
        cdef trg_str = str.join(' ', [trg_vocab.id2str(i) for i in trg_ids])
        return src_str, trg_str

cdef class Trainer:
    cdef Config conf
    #cdef np.ndarray trans_dist_src2trg
    cdef object env
    cdef list sent_pairs
    cdef float last_entropy
    #cdef Vocab vocab
    cdef np.ndarray cooc_src_trg
    cdef list cooc_id_src_trg
    cdef Model model

    def __cinit__(self, conf, **others):
        self.conf = Config(conf)
        self.conf.update(**others)
        self.env = environ.push()
        if conf.data.verbose:
            self.env.set('DEBUG', '1')
        if conf.data.quiet:
            self.env.set('QUIET', '1')
        #self.model = Model()
        check_config(conf)

    def __dealloc__(self):
        self.clear()

    cpdef np.ndarray count_cooccurrence(self, sent_pairs):
        cdef StringEnumerator vocab_src = self.model.vocab.src
        cdef StringEnumerator vocab_trg = self.model.vocab.trg
        cdef np.ndarray cooc_src_trg
        cdef int src, trg
        cdef np.ndarray src_indices, trg_indices
        cooc_src_trg = np.zeros([len(vocab_src),len(vocab_trg)], np.int)
        logging.log('counting co-occurrences of source word and target word')
        for i, (src_sent, trg_sent) in enumerate(progress.view(sent_pairs, 'processing')):
            #np.add.at(cooc_src_trg, np.meshgrid(src_sent,trg_sent), 1)
            np.add.at(cooc_src_trg, grid_indices(src_sent, trg_sent), 1)
        logging.log("co-occurrence matrix size: %s [src words] x %s [trg words] x %s [bytes]= %s [bytes]"
            % (cooc_src_trg.shape[0],cooc_src_trg.shape[1],cooc_src_trg.itemsize,cooc_src_trg.size*cooc_src_trg.itemsize))
        return cooc_src_trg

    cpdef calc_uniform_dist(self):
        cdef StringEnumerator vocab_src = self.model.vocab.src
        cdef StringEnumerator vocab_trg = self.model.vocab.trg
        cdef np.ndarray uniform_dist
        cdef int src, trg
        logging.log("calculating uniform distribution for word translation probability")
        uniform_dist = np.ones([len(vocab_src), len(vocab_trg)], np.float64) / len(vocab_trg)
        logging.log("word trans. distribution matrix size: %s [src words] x %s [trg words] x %s [bytes] = %s [bytes]"
            % (uniform_dist.shape[0],uniform_dist.shape[1],uniform_dist.itemsize,len(uniform_dist.data)))
        return uniform_dist

    cpdef clear(self):
        self.env.clear()

    cpdef init(self):
        self.model = Model()
        self.model.vocab = Vocab()
        self.model.vocab.src.append(NULL_SYMBOL)
        #self.vocab.trg.append(NULL_SYMBOL)
        self.sent_pairs = self.load_sent_pairs()
        logging.log("source vocabulary size: %s" % len(self.model.vocab.src))
        logging.log("target vocabulary size: %s" % len(self.model.vocab.trg))
        self.cooc_src_trg = self.count_cooccurrence(self.sent_pairs)
        self.model.trans_dist = self.calc_uniform_dist()

    cpdef list load_sent_pairs(self):
        cdef str word
        cdef str src_path = self.conf.data.src_path
        cdef str trg_path = self.conf.data.trg_path
        logging.log("loading files: %s %s" % (src_path,trg_path))
        src_file = progress.view(files.open(src_path), 'loading')
        trg_file = files.open(trg_path)
        sent_pairs = []
        for src_line, trg_line in zip(src_file, trg_file):
            if self.conf.data.character:
                src_words = list( src_line.rstrip("\n") )
                trg_words = list( trg_line.rstrip("\n") )
            else:
                src_words = src_line.rstrip("\n").split(' ')
                trg_words = trg_line.rstrip("\n").split(' ')
            src_words.append(NULL_SYMBOL)
            #src_words = map(self.vocab.src.str2id, src_words)
            #trg_words = map(self.vocab.trg.str2id, trg_words)
            src_words = [self.model.vocab.src.str2id(word) for word in src_words]
            trg_words = [self.model.vocab.trg.str2id(word) for word in trg_words]
            sent_pairs.append( (src_words, trg_words) )
        return sent_pairs
        #self.sent_pairs = sent_pairs

    cpdef save_align(self, out_path, threshold = 0.01):
        cdef StringEnumerator vocab_src = self.model.vocab.src
        cdef StringEnumerator vocab_trg = self.model.vocab.trg
        cdef tuple indices
        cdef int src, trg
        cdef float prob
        cdef str record
        with files.open(out_path, 'wt') as fobj:
            logging.log("storing translation probabilities into file (threshold=%s): %s" % (threshold,out_path))
            indices = np.where(self.model.trans_dist>= threshold)
            for src, trg in progress.view(zip(*indices), 'storing', max_count=len(indices[0])):
                prob = self.model.trans_dist[src,trg]
                record = "%s\t%s\t%s\n" % (vocab_src.id2str(src), vocab_trg.id2str(trg), prob)
                fobj.write(record)

    cpdef save_scores(self, out_path):
        cdef double entropy = 0
        cdef str src_string, trg_string
        cdef list src_ids, trg_ids
        cdef str record
        logging.log("calculating and storing into file: %s"  % (self.conf.data.save_scores))
        with files.open(self.conf.data.save_scores, 'wt') as fobj:
            for i, (src_ids, trg_ids) in enumerate(progress.view(self.sent_pairs, 'progress')):
                entropy = self.model.calc_pair_entropy(src_ids, trg_ids)
                src_string, trg_string = self.model.ids_pair_to_str_pair(src_ids, trg_ids)
                record = "%s\t%s\t%s\n" % (entropy, src_string, trg_string)
                fobj.write(record)

    cpdef train(self):
        cdef long i
        logging.log("start training IBM Model 1")
        self.init()
        self.last_entropy = self.model.calc_entropy(self.sent_pairs)
        logging.log("initial entropy: %s" % self.last_entropy)
        for step in range(self.conf.data.iteration_limit):
            logging.log("--")
            logging.log("step: %s" % (step + 1))
            # train 1 step
            self.train_step()
            # calculate entropy
            entropy = self.model.calc_entropy(self.sent_pairs)
            logging.log("entropy: %s" % entropy)
            if entropy == self.last_entropy:
                break
            else:
                self.last_entropy = entropy

    cpdef train_step(self):
        cdef long i
        cdef list src_sent, trg_sent
        cdef np.ndarray count_src2trg, total_src
        cdef np.ndarray trg_factor
        cdef StringEnumerator vocab_src = self.model.vocab.src
        cdef StringEnumerator vocab_trg = self.model.vocab.trg
        cdef tuple grid

        if len(self.model.trans_dist) == 0:
            self.init()
        else:
            count_src2trg = np.zeros([len(vocab_src),len(vocab_trg),], np.float64)
            total_src = np.zeros(len(vocab_src), np.float64)
            logging.log("estimating co-occurrence counts")
            for i, (src_sent, trg_sent) in enumerate(progress.view(self.sent_pairs, 'processing')):
                grid = grid_indices(src_sent, trg_sent)
                # compute normalization
                trg_factor = np.zeros(len(vocab_trg), np.float64)
                np.add.at(trg_factor, trg_sent, sub_matrix(self.model.trans_dist,src_sent,trg_sent).sum(axis=0))
                # collect counts
                np.add.at(count_src2trg, grid,     self.model.trans_dist[grid] / trg_factor[trg_sent])
                np.add.at(total_src, src_sent, (self.model.trans_dist[grid] / trg_factor[trg_sent]).sum(axis=1))
            # estimate probabilities
            logging.log("estimating word translation probabilities")
            self.model.trans_dist = count_src2trg / total_src.reshape([-1,1])

def check_config(conf):
    if conf.data.verbose:
        logging.debug(conf)

def train_ibm_model1(conf, **others):
    conf = Config(conf)
    conf.update(others)
    trainer = Trainer(conf, **others)
    trainer.train()
    trainer.save_align(conf.data.save_align_path, conf.data.threshold)
    if conf.data.save_scores:
        trainer.save_scores(conf.data.save_scores)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('src_path', metavar='src_path (in)', help='file containing source-side lines of parallel text', type=str)
    parser.add_argument('trg_path', help='file containing target-side lines of parallel text', type=str)
    parser.add_argument('save_align_path', help='output file to save alignment', type=str)
    parser.add_argument('--save-scores', '-S', help='output file to save entropy of each each alignment', type=str, default=None)
    parser.add_argument('--iteration-limit', '-I', help='maximum iteration number of EM algorithm (default: %(default)s)', type=int, default=ITERATION_LIMIT)
    parser.add_argument('--threshold', '-t', help='threshold of translation probabilities to save', type=float, default=0.01)
    parser.add_argument('--character', '-c', help='chacacter based alignment mode', action='store_true')
    parser.add_argument('--verbose', '-v', help='verbose mode (including debug info)', action='store_true')
    parser.add_argument('--quiet', '-q', help='not showing staging log', action='store_true')
    args = parser.parse_args()
    conf = Config(vars(args))
    if args.verbose:
        with environ.push(DEBUG=1) as e:
            logging.debug(args)
    train_ibm_model1(conf)

if __name__ == '__main__':
    main()

