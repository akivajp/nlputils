# distutils: language=c++
# -*- coding: utf-8 -*-
# cython: profile=True

'''Utility functions for Python 2/3 compatibility'''

import collections

if str == bytes:
    # Python2
    def toUnicode(s):
        '''
        convert to unicode string
        '''
        return unicode(s, 'utf-8')

    def toBytes(s):
        '''
        convert to byte string
        '''
        if isinstance(s, unicode):
            return s.encode('utf-8')
        else:
            return bytes(s)

    def toStr(data):
        '''
        convert to object based on standard strings
        '''
        if isinstance(data, basestring):
            if isinstance(data, unicode):
                return data.encode('utf-8')
            else:
                return data
        elif isinstance(data, collections.Mapping):
            return type(data)(map(toStr, data.iteritems()))
        elif isinstance(data, collections.Iterable):
            return type(data)(map(toStr, data))
        else:
            return data

else:
    # Python3
    def toUnicode(s):
        '''
        convert to unicode string
        '''
        if isinstance(s, bytes):
            return str(s, 'utf-8')
        else:
            return str(s)

    def toBytes(s):
        '''
        convert to byte string
        '''
        return bytes(s, 'utf-8')

    def toStr(data):
        '''
        convert to object based on standard strings
        '''
        if isinstance(data, bytes):
            return str(data, 'utf-8')
        elif isinstance(data, collections.Mapping):
            return type(data)(map(toStr, data.iteritems()))
        elif isinstance(data, collections.Iterable):
            return type(data)(map(toStr, data))
        else:
            return data

