# distutils: language=c++
# -*- coding: utf-8 -*-

'''this module provides globally shared stack of environment'''

# C++ setting
from libcpp cimport bool

# Standard libraries
import os

# Local libraries
#from nlputils.common import logging

env_stack = []

def get_env(key, default=None, system=True):
    for env_dict in env_stack[::-1]:
        if key in env_dict:
            return env_dict[key]
    if system:
        if key in os.environ:
            return os.environ[key]
    else:
        return default

cdef class StackHolder:
    cdef readonly bool affect_system
    cdef readonly int level
    cdef dict env_layer
    cdef list back_log

    def __cinit__(self, affect_system=True):
        self.env_layer = {}
        env_stack.append(self.env_layer)
        self.back_log = []
        self.affect_system = affect_system
        self.level = len(env_stack)

    cpdef set(self, str key, str value):
        cdef bool prev_exist = False
        cdef str prev_value = ''
        if self.affect_system:
            #logging.log("appending %s='%s' to env" % (key, value) )
            if key in os.environ:
                prev_exist = True
                prev_value = os.environ[key]
            self.back_log.append( (key,prev_exist,prev_value) )
            os.environ[key] = value
        self.env_layer[key] = value

    cpdef clear(self):
        cdef str key
        cdef bool prev_exist
        cdef str prev_value
        if self.back_log:
            for key, prev_exist, prev_value in self.back_log[::-1]:
                if prev_exist:
                    #logging.log("record back %s='%s' to env" % (key, prev_value))
                    os.environ[key] = prev_value
                else:
                    #logging.log("unset key from env: %s" % (key,))
                    os.environ.pop(key)
        self.env_layer.clear()
        self.back_log.clear()

    def __enter__(self):
        #logging.log("__enter__")
        return self

    def __exit__(self, exception_type, exception_value, traceback):
        #logging.log("__exit__")
        #logging.debug(exception_type)
        #logging.debug(exception_value)
        #logging.debug(traceback)
        self.clear()

    def __dealloc__(self):
        #logging.log("__dealloc__")
        self.clear()

cpdef push():
    return StackHolder()

