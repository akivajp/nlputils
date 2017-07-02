# distutils: language=c++
# -*- coding: utf-8 -*-

'''classes handling phrase/rule table'''

from libcpp cimport bool

# Standard libraries
import sys
import time

# 3rd party library
import cedar

# Local libraries
from nlputils.common import compat
from nlputils.common import files
from nlputils.common import logging
from nlputils.common import numbers
from nlputils.common import progress
from nlputils.common import vocab
from nlputils.smt.trans_models import records

keyTypes = ['src', 'srcHiero', 'srcSymbols', 'srcTree']

cdef class Table(object):
    cdef bool showProgress
    cdef object RecordClass
    cdef str tablePath
    cdef object tableFile
    cdef object records
    cdef str keyType

    def __init__(self, tablePath, RecordClass, **options):
        showProgress = options.get('showProgress', False)
        self.keyType = options.get('keyType', 'src')
        self.RecordClass = RecordClass
        self.tablePath = tablePath
        if showProgress:
            self.tableFile = progress.FileReader(tablePath, 'Loading')
        else:
            #self.tableFile = files.open(tablePath, 'r')
            self.tableFile = files.open(tablePath, 'rt')
        self.records = cedar.trie()
        self.__load()

    cdef __load(self):
        cdef long i
        cdef str line
        #cdef object rec
        cdef str src
        cdef str srcKey
        #print(self.tableFile)
        for i, line in enumerate(self.tableFile):
            #if i > 5:
            #    break
            #print(repr(line))
            #rec = self.RecordClass(line)
            src = line.split('|||',1)[0].strip()
            #srcKey = str.join(' ', self.RecordClass.getSymbols(src)) + ' ||| '
            if self.keyType == 'src':
                srcKey = src + ' ||| '
            elif self.keyType == 'srcHiero':
                srcKey = str.join(' ', self.RecordClass.getSymbols(src,hiero=True)) + ' ||| '
            elif self.keyType == 'srcSymbols':
                srcKey = str.join(' ', self.RecordClass.getSymbols(src,hiero=False)) + ' ||| '
            try:
                #self.records.insert(srcKey + line)
                self.records.insert(vocab.phrase2idvec(srcKey + line))
            except Exception as e:
                self.tableFile.close()
                logging.debug(e)
        self.tableFile.close()

    def find(self, str key):
        cdef str line
        if key and key.find('|||') < 0:
            key = key + ' ||| '
        keyvec = vocab.phrase2idvec(key)
        #for r in self.records.predict(key):
        #for r in self.records.predict(vocab.phrase2idvec(key)):
        for r in self.records.predict(keyvec):
            #line = key + r.key()
            idvec = keyvec + r.key()
            line = vocab.idvec2phrase(idvec)
            yield self.RecordClass(line.split('|||',1)[1])
            #yield src + r.key()

    def __iter__(self):
        return self.find('')
    def __len__(self):
        return self.records.num_keys()

class MosesTable(Table):
    def __init__(self, tablePath, **options):
        Table.__init__(self, tablePath, records.MosesRecord, **options)

class TravatarTable(Table):
    def __init__(self, tablePath, **options):
        Table.__init__(self, tablePath, records.TravatarRecord, **options)

