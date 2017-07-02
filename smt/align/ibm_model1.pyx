# distutils: language=c++
# -*- coding: utf-8 -*-

# Standard libraries
import argparse
import math
import sys
from collections import defaultdict

# Local libraries
from nlputils.common import logging

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

def calc_entropy(sent_pairs, trans_probs):
    entropy = 0
    for i, (src_sent, trg_sent) in enumerate(sent_pairs):
        prob = 1.0
        #prob = float(1) / ((len(src_sent)+1) ** len(trg_sent))
        #for src in src_sent:
        #    for trg in trg_sent:
        for trg in trg_sent:
            sum_align = 0
            for src in src_sent:
                sum_align += trans_probs[src,trg]
            #prob = prob * sum_align / (len(src_sent)+1)
            prob = prob * sum_align / len(src_sent)
        #print("prob: %s" % prob)
        entropy -= math.log(prob)
    return entropy / len(sent_pairs)

def train_ibm_model1(sent_pairs, iteration_limit = ITERATION_LIMIT):
    logging.log("start training")
    trans_prob_src2trg = calc_uniform_dist(sent_pairs)
    last_entropy = calc_entropy(sent_pairs, trans_prob_src2trg)
    logging.log("initial entropy: %s" % last_entropy)
    for epoch in range(iteration_limit):
        entropy = 0
        logging.log("epoch: %s\n" % (epoch + 1))
        # initialize
        count_src2trg = defaultdict(lambda: 0.0)
        total_src = defaultdict(lambda: 0.0)
        for i, (src_sent, trg_sent) in enumerate(sent_pairs):
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
        logging.log("estimate probs")
        for src in src_id2word:
            for trg in trg_id2word:
                if total_src[src]:
                    trans_prob_src2trg[src,trg] = count_src2trg[src,trg] / total_src[src]
        entropy = calc_entropy(sent_pairs, trans_prob_src2trg)
        logging.log("entropy: %s" % entropy)
        if entropy == last_entropy:
            break
        else:
            last_entropy = entropy
    return trans_prob_src2trg

def calc_uniform_dist(sent_pairs):
    trans_prob_src2trg = {}
    #trg_vocab = set()
    #for pair in sent_pairs:
    #    for word in pair[1]:
    #        trg_vocab.add(word)
    #for pair in sent_pairs:
    #    for src_word in pair[0]:
    #        for trg_word in pair[1]:
    #            trans_prob_src2trg[src_word,trg_word] = 1 / float(len(trg_vocab)+1)
    for src_word in src_id2word:
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

def load_files(src_path, trg_path):
    logging.log("file loading")
    src_file = open(src_path)
    trg_file = open(trg_path)
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
    with open(out_path, 'w') as fobj:
        for (src, trg), prob in sorted(trans_probs.items()):
            if prob > threshold:
                fobj.write("%s\t%s\t%s\n" % (src, trg, prob))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('src_file', help='file containing source-side lines of parallel text', type=str)
    parser.add_argument('trg_file', help='file containing target-side lines of parallel text', type=str)
    parser.add_argument('save_align_file', help='output file to save alignment', type=str)
    parser.add_argument('--iteration', '-I', help='maximum iteration number of EM algorithm (default: %(default)s)', type=int, default=ITERATION_LIMIT)
    parser.add_argument('--verbose', '-v', help='verbose mode', action='store_true')
    parser.add_argument('--progress', '-p', help='show progress', action='store_true')
    parser.add_argument('--threshold', '-t', help='threshold of translation probabilities to save', type=float, default=0.01)
    args = parser.parse_args()
    if args.verbose:
        logging.debug(args)
    sent_pairs = load_files(args.src_file, args.trg_file)
    trans_probs = train_ibm_model1(sent_pairs, args.iteration)
    write_trans_probs(args.save_align_file, trans_probs, args.threshold)

if __name__ == '__main__':
    main()

