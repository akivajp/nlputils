# distutils: language=c++
# -*- coding: utf-8 -*-
# cython: profile=True

'''Configuration utility class for function settings'''

# Standard libraries
import json

# Local libraries
from nlputils.common import compat
from nlputils.common import logging

class ConfigData(object):
    '''Configuration data holder'''
    def __init__(self, _base=None, **args):
        if type(_base) == Config:
            self.__base = _base.data
        elif type(_base) == ConfigData:
            self.__base = _base
        elif type(_base) == dict:
            self.__base = _base
        else:
            self.__base = None
        if args:
            self.__dict__.update(args)

    def __contains__(self, key):
        if key in self.__dict__:
            return True
        base = self.__base
        if base and key in base:
            return True
        return False

    def __getattr__(self, key):
        base = self.__base
        if base and key in base:
                return base[key]
        className = self.__class__.__name__
        raise AttributeError("'%s' object has no attribute '%s'" % (className, key))

    def __getitem__(self, key):
        d = self.__dict__
        if key in d:
            return d[key]
        base = self.__base
        if base and key in base:
            return base[key]
        raise KeyError(key)

    def __iter__(self):
        s = set(self.__dict__)
        base = self.__base
        if base:
            s.update(base)
        for key in s:
            if not key.startswith('_'):
                yield(key)

    def __len__(self):
        return len(set(self))

    def __repr__(self):
        c = self.__class__
        name = c.__name__
        strParams = getKeyValStr(vars(self), False)
        if strParams:
            return "%s(%r, %s)" % (name,self.__base,strParams)
        else:
            return "%s(%s)" % (name,self.__base)

    def __setattr__(self, key, val):
        if len(self.__dict__) == 0:
            # first assignment (should be '__base')
            self.__dict__.__setitem__(key, val)
        elif key.startswith('_'):
            raise KeyError('Key should not start with "_": %s' % key)
        else:
            self.__dict__.__setitem__(key, val)

    def __setitem__(self, key, val):
        if type(key) != str:
            raise TypeError('Key value should be type of string, given: %s' % type(key))
        elif key.startswith('_'):
            raise KeyError('Key should not start with "_": %s' % key)
        else:
            return self.__dict__.__setitem__(key, val)

class Config(object):
    '''Configuration maintenance class'''
    #cdef object __data
    __slots__ = {'__data'}

    def __init__(self, _base = None, **args):
        self.__data = ConfigData(_base)
        if args:
            #self.__data.__dict__.update(args)
            self.update(args)

    def cast(self, name, typeOf):
        val = self.requireAny(name)
        if type(val) == typeOf:
            return val
        else:
            newVal = typeOf(val)
            self.data.__dict__[name] = newVal
            return newVal

    @property
    def data(self):
        return self.__data

    def get(self, key, default = None):
        if key in self:
            return self[key]
        else:
            return default

    def items(self):
        for key in self:
            yield key, self[key]

    def loadJSON(self, strJSON, override=True):
        #self.update(json.loads(compat.toStr(strJSON)))
        uniDict = json.loads(strJSON)
        #self.update(compat.toStr(uniDict))
        self.update(uniDict, override)

    def require(self, name, desc = None, typeOf = None):
        val = self.requireAny(name, desc)
        if typeOf:
            self.requireType(name, typeOf)
        return val

    def requireAny(self, name, desc = None):
        if name not in self.data:
            if desc:
                raise KeyError('Configuration "%s" (%s) is not defined' % (name, desc))
            else:
                raise KeyError('Configuration "%s" is not defined' % (name))
        return self.data.__getitem__(name)

    def requireType(self, name, typeOf):
        val = self.requireAny(name)
        if type(val) != typeOf:
            msg = 'Configuration "%s" should be type of %s, but given %s'
            logging.alert(msg % (name, typeOf, type(val)))
        return val

    def setdefault(self, key, val):
        if key not in self:
            self[key] = val
            return val
        elif self[key] == None:
            self[key] = val
            return val
        else:
            return self[key]

    def toJSON(self, **options):
        return json.dumps(dict(self.items()), **options)

    def update(self, _conf = None, _override=True, **args):
        if _conf:
            if _override:
                for key, val in _conf.items():
                    if val != None:
                        self[key] = val
            else:
                for key in _conf:
                    if key not in self:
                        self[key] = _conf[key]
        if args:
            self.update(args, _override)

    def __getitem__(self, key):
        return self.data.__getitem__(key)

    def __iter__(self):
        return self.data.__iter__()

    def __len__(self):
        return self.data.__len__()

    def __repr__(self):
        c = self.__class__
        name = c.__name__
        strParams = getKeyValStr(vars(self.data), False)
        return "%s(%r)" % (name,self.data)

    def __setitem__(self, key, val):
        return self.data.__setitem__(key, val)

def getKeyValStr(d, verbose=True):
    if verbose:
        items = ["%s=%r" % (t[0],t[1]) for t in d.items()]
    else:
        items = ["%s=%r" % (t[0],t[1]) for t in d.items() if not t[0].startswith('_')]
    return str.join(', ', items)

