# distutils: language=c++
# -*- coding: utf-8 -*-

'''Utility functions for Python 2/3 compatibility'''

import sys
import collections
import itertools

cdef bytes __py2__toBytes(s):
    '''
    convert to byte string
    '''
    if isinstance(s, unicode):
        return s.encode('utf-8')
    else:
        return bytes(s)
cdef bytes __py3__toBytes(s):
    '''
    convert to byte string
    '''
    if isinstance(s, str):
        return bytes(s, 'utf-8')
    elif isinstance(s, bytes):
        return s
    else:
        return bytes(str(s), 'utf-8')


cdef str __py2__toStr(data):
#cdef __py2__toStr(data):
    '''
    convert to object based on standard strings
    '''
    if isinstance(data, basestring):
        if isinstance(data, unicode):
            return data.encode('utf-8')
        else:
            return data
    #elif isinstance(data, collections.Mapping):
    #    return type(data)(map(toStr, data.iteritems()))
    #elif isinstance(data, collections.Iterable):
    #    return type(data)(map(toStr, data))
    else:
        return str(data)
cdef str __py3__toStr(data):
#cdef __py3__toStr(data):
    '''
    convert to object based on standard strings
    '''
    if isinstance(data, str):
        return data
    elif isinstance(data, bytes):
        return str(data, 'utf-8')
    #elif isinstance(data, collections.Mapping):
    #    return type(data)(map(toStr, data.items()))
    #elif isinstance(data, collections.Iterable):
    #    return type(data)(map(toStr, data))
    else:
        return str(data)

cdef unicode __py2__toUnicode(s):
    '''
    convert to unicode string
    '''
    return unicode(s, 'utf-8')
cdef unicode __py3__toUnicode(s):
    '''
    convert to unicode string
    '''
    if isinstance(s, bytes):
        return str(s, 'utf-8')
    else:
        return str(s)

if sys.version_info.major == 2:
    # Python2
    toBytes   = __py2__toBytes
    toStr     = __py2__toStr
    toUnicode = __py2__toUnicode
    range = xrange
    zip   = itertools.izip
elif sys.version_info.major == 3:
    # Python3
    toBytes   = __py3__toBytes
    toStr     = __py3__toStr
    toUnicode = __py3__toUnicode
    range = range
    zip   = zip
else:
    raise SystemError("Unsupported python version: %s" % sys.version)

