# distutils: language=c++
# -*- coding: utf-8 -*-

'''functions mapping from words/phrases to IDs and vice versa'''

from nlputils.data_structs.trie import TwoWayIDMap

wordMap   = TwoWayIDMap()
phraseMap = TwoWayIDMap()

cpdef long word2id(str word):
    return wordMap[word]

cpdef str id2word(long number):
    return wordMap.id2str(number)

cpdef str phrase2idvec(str phrase):
    if not phrase:
        return ''
    #return str.join(',', map(str, map(word2id, phrase.split(' '))))
    #return str.join(',', map(str, map(word2id, phrase.split())))
    return str.join(',', map(str, map(word2id, phrase.strip().split(' '))))

cpdef str idvec2phrase(str idvec):
    if not idvec:
        return ''
    return str.join(' ', map(id2word, map(int, idvec.split(','))))

cpdef long phrase2id(str phrase):
    cdef str idvec = str.join(',', map(str, map(word2id, phrase.split(' '))))
    return phraseMap[idvec]

cpdef str id2phrase(long number):
    cdef str idvec = phraseMap.id2str(number)
    return str.join(' ', map(id2word, map(int, idvec.split(','))))

