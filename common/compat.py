#!/usr/bin/env python
# -*- coding: utf-8 -*-

def toUnicode(s):
    '''
    convert to unicode string
    '''
    if str == bytes:
        # Python2
        return unicode(s, 'utf-8')
    else:
        # Python3
        if type(s) == bytes:
            return str(s, 'utf-8')
        else:
            return str(s)

def toBytes(s):
    '''
    convert to byte string
    '''
    if str == bytes:
        # Python2
        if type(s) == unicode:
            return s.encode('utf-8')
        else:
            return bytes(s)
    else:
        # Python3
        return bytes(s, 'utf-8')

def toStr(s):
    '''
    convert to standard string
    '''
    if str == bytes:
        # Python2
        if type(s) == unicode:
            return s.encode('utf-8')
        else:
            return str(s)
    else:
        # Python3
        if type(s) == bytes:
            return str(s, 'utf-8')
        else:
            return str(s)

