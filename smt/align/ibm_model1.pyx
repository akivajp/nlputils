# distutils: language=c++
# -*- coding: utf-8 -*-
# cython: profile=True

# Standard libraries
import argparse
import math
import sys
from collections import defaultdict

# Local libraries
from nlputils.common import environ
from nlputils.common import files
from nlputils.common import progress
from nlputils.common import logging
from nlputils.common.config import Config

ITERATION_LIMIT = 10

src_word2id = {}
src_id2word = []
trg_word2id = {}
trg_id2word = []

vocab = {
    'src': {
        'word2id': src_word2id,
        'id2word': src_id2word,
    },
    'trg': {
        'word2id': trg_word2id,
        'id2word': trg_id2word,
    },
}

def calc_entropy(sent_pairs, trans_probs, conf):
    entropy = 0
    #for i, (src_sent, trg_sent) in enumerate(progress.view(sent_pairs)):
    #for i, (src_sent, trg_sent) in enumerate(sent_pairs):
    logging.log('calculating entropy')
    for i, (src_sent, trg_sent) in enumerate(progress.view(sent_pairs, 'progress')):
        prob = 1.0
        for trg in trg_sent:
            sum_for_align = 0
            for src in src_sent:
                sum_for_align += trans_probs[src,trg]
            prob = prob * sum_for_align / len(src_sent)
        entropy -= math.log(prob)
    return entropy / len(sent_pairs)

def train_ibm_model1(conf, **others):
    cdef long i
    cdef list src_sent
    cdef list trg_sent
    cdef str src, trg

    conf = Config(conf, **others)
    check_config(conf)

    sent_pairs = load_pairs(conf)
    logging.log("start training IBM Model 1")
    trans_prob_src2trg = calc_uniform_dist(sent_pairs)
    last_entropy = calc_entropy(sent_pairs, trans_prob_src2trg, conf)
    logging.log("initial entropy: %s" % last_entropy)
    for epoch in range(conf.data.iteration_limit):
        entropy = 0
        logging.log("--")
        logging.log("epoch: %s" % (epoch + 1))
        # initialize
        count_src2trg = defaultdict(lambda: 0.0)
        total_src = defaultdict(lambda: 0.0)
        logging.log("estimating co-occurences")
        for i, (src_sent, trg_sent) in enumerate(progress.view(sent_pairs, 'processing')):
            #print("processing sent: %s" % i)
            # compute normalization
            #print("calc normalization factor")
            trg_factor = defaultdict()
            #for trg in trg_id2word:
            for trg in trg_sent:
                trg_factor[trg] = 0
                #for src in src_id2word:
                for src in src_sent:
                    trg_factor[trg] += trans_prob_src2trg[src,trg]
            # collect counts
            #print("collect counts")
            #for trg in trg_id2word:
            #    for src in src_id2word:
            for trg in trg_sent:
                for src in src_sent:
                    count_src2trg[src,trg] += trans_prob_src2trg[src,trg] / trg_factor[trg]
                    total_src[src] += trans_prob_src2trg[src,trg] / trg_factor[trg]
        # estimate probabilities
        logging.log("estimating probs")
        #for src in src_id2word:
        for src in progress.view(src_id2word, 'processing'):
            for trg in trg_id2word:
                if total_src[src]:
                    trans_prob_src2trg[src,trg] = count_src2trg[src,trg] / total_src[src]
        entropy = calc_entropy(sent_pairs, trans_prob_src2trg, conf)
        logging.log("entropy: %s" % entropy)
        if entropy == last_entropy:
            break
        else:
            last_entropy = entropy
    return trans_prob_src2trg

def calc_uniform_dist(sent_pairs):
    cdef str src_word, trg_word

    trans_prob_src2trg = {}
    # calculating uniform distribution
    logging.log("calculating uniform distribution for word translation probability")
    for src_word in progress.view(src_id2word, 'processing'):
        for trg_word in trg_id2word:
            trans_prob_src2trg[src_word,trg_word] = float(1) / len(trg_id2word)
    return trans_prob_src2trg

def get_word_id(side, word):
    word2id = vocab[side]['word2id']
    if word in word2id:
        return word2id[word]
    else:
        id2word = vocab[side]['id2word']
        id2word.append(word)
        return word2id.setdefault(word, len(word2id))

def get_src_word_id(word):
    return get_word_id('src', word)

def get_trg_word_id(word):
    return get_word_id('trg', word)

def init_vocab():
    for side in ('src','trg'):
        vocab[side]['word2id'].clear()
        vocab[side]['id2word'].clear()
    get_src_word_id('-NULL-')
    get_trg_word_id('-NULL-')

#def load_files(src_path, trg_path, quiet=False, progress=False):
def load_pairs(conf):
    src_path = conf.data.src_path
    trg_path = conf.data.trg_path
    if not conf.data.quiet:
        logging.log("loading files: %s %s" % (src_path,trg_path))
    src_file = progress.view(files.open(src_path), 'loading')
    trg_file = files.open(trg_path)
    sent_pairs = []
    init_vocab()
    for src_line, trg_line in zip(src_file, trg_file):
        src_words = src_line.rstrip("\n").split(' ')
        trg_words = trg_line.rstrip("\n").split(' ')
        #src_words = ['-NULL-'] + src_line.rstrip("\n").split(' ')
        #trg_words = ['-NULL-'] + trg_line.rstrip("\n").split(' ')
        src_words.append('-NULL-')
        #trg_words.append('-NULL-')
        tuple( map(get_src_word_id, src_words) )
        tuple( map(get_trg_word_id, trg_words) )
        sent_pairs.append( (src_words, trg_words) )
    return sent_pairs

def write_trans_probs(out_path, trans_probs, threshold = 0.01):
    with files.open(out_path, 'wt') as fobj:
        for (src, trg), prob in progress.view(sorted(trans_probs.items())):
            if prob > threshold:
                fobj.write("%s\t%s\t%s\n" % (src, trg, prob))

def check_config(conf):
    if conf.data.verbose:
        logging.debug(conf)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('src_path', metavar='src_path (in)', help='file containing source-side lines of parallel text', type=str)
    parser.add_argument('trg_path', help='file containing target-side lines of parallel text', type=str)
    parser.add_argument('save_align_path', help='output file to save alignment', type=str)
    parser.add_argument('--iteration_limit', '-I', help='maximum iteration number of EM algorithm (default: %(default)s)', type=int, default=ITERATION_LIMIT)
    parser.add_argument('--threshold', '-t', help='threshold of translation probabilities to save', type=float, default=0.01)
    parser.add_argument('--verbose', '-v', help='verbose mode (including debug info)', action='store_true')
    parser.add_argument('--quiet', '-q', help='not showing staging log', action='store_true')
    args = parser.parse_args()
    conf = Config(vars(args))
    if args.verbose:
        logging.debug(args)
    with environ.push() as env:
        if conf.data.verbose:
            env.set('DEBUG', '1')
        if conf.data.quiet:
            env.set('QUIET', '1')
        trans_probs = train_ibm_model1(conf)
        write_trans_probs(args.save_align_path, trans_probs, args.threshold)

if __name__ == '__main__':
    main()

