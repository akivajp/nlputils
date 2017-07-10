# 3-rd party library
cimport numpy as np
# local library
from nlputils.common.config cimport Config
from nlputils.common.vocab  cimport StringEnumerator

cdef class Vocab:
    cdef StringEnumerator src
    cdef StringEnumerator trg

    cdef inline void init(self):
        self.src = StringEnumerator()
        self.trg = StringEnumerator()

    cpdef tuple ids_pair_to_str_pair(self, src_ids, trg_ids)
    cpdef list load_sent_pairs(self, str src_path, str trg_path)

cdef class Model:
    cdef Vocab vocab
    cdef np.ndarray trans_dist

    cdef inline void init(self):
        self.vocab = Vocab()

    cpdef double calc_pair_entropy(self, list src_sent, list trg_sent)
    cpdef double calc_entropy(self, list sent_pairs)
    cpdef void calc_and_save_scores(self, out_path, list sent_pairs)
    cpdef void save_align(self, out_path, threshold)

cdef class Trainer:
    cdef Model model
    cdef str src_path
    cdef str trg_path
    cdef list sent_pairs
    cdef np.ndarray cooc_src_trg

    cdef inline void init(self):
        self.model = Model()

    cpdef np.ndarray calc_uniform_dist(self)
    cpdef np.ndarray count_cooccurrence(self, sent_pairs)
    cpdef void train(self, int iteration_limit)
    cpdef void train_first(self)
    cpdef void train_step(self)

