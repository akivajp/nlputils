# distutils: language=c++
# -*- coding: utf-8 -*-

# C++ setting
from libcpp cimport bool
from libcpp.string cimport string
ctypedef unsigned char byte

# Local libraries
from common import compat
from common import log

'''Dictionary implemented by Patricia trie'''

cdef long getCommonPrefixLength(string str1, string str2):
    cdef long index
    index = 0
    while True:
        if str1.length() <= index:
            break
        elif str2.length() <= index:
            break
        elif str1[index] != str2[index]:
            break
        index += 1
    return index

cdef class PatriciaNode(object):
    cdef string label
    cdef bool isValid
    cdef object obj
    cdef unsigned long size
    cdef list subNodes

    def __cinit__(self, string label='', object valid=False, object obj=None):
        #print('Ctor: %s' % label)
        self.label = label
        self.obj = obj
        self.isValid = valid
        if valid:
            self.size = 1
        else:
            self.size = 0
        self.subNodes = [None] * 256

    def __dealloc__(self):
        #print('Dtor: %s' % self.label)
        self.subNodes = None
        self.obj = None

    cdef void dump(self, indent=0):
        cdef PatriciaNode node
        cdef strIndent, strLabel
        strIndent = '  ' * indent
        strLabel = compat.toStr(self.label)
        #print(type(self.label))
        if self.isValid:
            print("%s- %r (valid)" % (strIndent,strLabel))
        else:
            print("%s- %r" % (strIndent,strLabel))
        for node in self.subNodes:
            if node:
                node.dump(indent+1)

    def genItems(self, string prefix=''):
        cdef tuple item
        cdef PatriciaNode node
        if self.isValid:
            yield (prefix+self.label, self.obj)
        for node in self.subNodes:
            if node:
                for item in node.genItems(prefix+self.label):
                    yield item

    def genKeys(self, string prefix=''):
        cdef string key
        cdef PatriciaNode node
        if self.isValid:
            yield prefix+self.label
        for node in self.subNodes:
            if node:
                for key in node.genKeys(prefix+self.label):
                    yield key

    def genValues(self):
        cdef object val
        cdef PatriciaNode node
        if self.isValid:
            yield self.obj
        for node in self.subNodes:
            if node:
                for val in node.genValues():
                    yield val

    cdef object get(self, string key, object default):
        cdef PatriciaNode node
        node = self.getNode(key)
        if node and node.isValid:
            return node.obj
        else:
            return default

    cdef PatriciaNode getNode(self, string key):
        cdef byte firstChar
        cdef PatriciaNode tmpNode
        cdef long lenPrefix
        #print('KEY: %s' % key)
        if key == '':
            return self
        else:
            firstChar = key[0]
            # check the existency
            tmpNode = self.subNodes[firstChar]
            if tmpNode:
                lenPrefix = getCommonPrefixLength(key, tmpNode.label)
                if lenPrefix == tmpNode.label.length():
                    if lenPrefix == key.length():
                        # exact match
                        return tmpNode
                    else:
                        # tmpNode.label is prefix of key
                        return tmpNode.getNode(key.substr(lenPrefix))
                else:
                    # key not found
                    return None
            else:
                # key not found
                return None

    cdef void remove(self, string key, string prefix=''):
        cdef byte firstChar
        cdef PatriciaNode tmpNode
        cdef long lenPrefix
        #print("KEY: %s" % key)
        if key == '':
            self.obj = None
            if self.isValid:
                self.size -= 1
                self.isValid = False
            else:
                # key not found
                raise KeyError(compat.toStr(prefix+key))
        else:
            firstChar = key[0]
            #print("FIRST: %s" % firstChar)
            # check the existency
            tmpNode = self.subNodes[firstChar]
            if tmpNode:
                lenPrefix = getCommonPrefixLength(key, tmpNode.label)
                if lenPrefix == tmpNode.label.length():
                    if lenPrefix == key.length():
                        # exact match
                        tmpNode.obj = None
                        if tmpNode.isValid:
                            # invalidating the node
                            tmpNode.size -= 1
                            tmpNode.isValid = False
                            self.size -= 1
                            if tmpNode.size == 0:
                                # deleting the node
                                self.subNodes[firstChar] = None
                        else:
                            # key not found
                            raise KeyError(compat.toStr(prefix+key))
                    else:
                        # tmpNode.label is prefix of key
                        tmpNode.remove(key.substr(lenPrefix), prefix+key.substr(0,lenPrefix))
                        self.size -= 1
                        if tmpNode.size == 0:
                            # deleting the node
                            self.subNodes[firstChar] = None
                else:
                    # key not found
                    raise KeyError(compat.toStr(prefix+key))
            else:
                # key not found
                raise KeyError(compat.toStr(prefix+key))

    cdef void set(self, string key, object val):
        cdef byte firstChar
        cdef PatriciaNode tmpNode, newNode
        cdef long lenPrefix
        #print("KEY: %s" % key)
        if key == '':
            self.obj = val
            if not self.isValid:
                self.size += 1
                self.isValid = True
        else:
            firstChar = key[0]
            #print("FIRST: %s" % firstChar)
            # check the existency
            tmpNode = self.subNodes[firstChar]
            if tmpNode:
                lenPrefix = getCommonPrefixLength(key, tmpNode.label)
                if lenPrefix == tmpNode.label.length():
                    if lenPrefix == key.length():
                        # exact match, just setting the new value
                        tmpNode.obj = val
                        if not tmpNode.isValid:
                            tmpNode.size += 1
                            tmpNode.isValid = True
                            self.size += 1
                    else:
                        # tmpNode.label is prefix of key
                        tmpNode.set(key.substr(lenPrefix), val)
                        self.size += 1
                else:
                    if lenPrefix == key.length():
                        # key is prefix of tmpNode.label
                        newNode = PatriciaNode(key, True, val)
                        newNode.subNodes[<byte>tmpNode.label[lenPrefix]] = tmpNode
                        newNode.size = tmpNode.size + 1
                        tmpNode.label = tmpNode.label.substr(lenPrefix)
                        self.subNodes[firstChar] = newNode
                        self.size += 1
                    else:
                        # partial match, splitting into two nodes
                        newNode = PatriciaNode(key.substr(0,lenPrefix), False, None)
                        newNode.subNodes[<byte>tmpNode.label[lenPrefix]] = tmpNode
                        tmpNode.label = tmpNode.label.substr(lenPrefix)
                        newNode.size = tmpNode.size + 1
                        newNode.subNodes[<byte>key[lenPrefix]] = PatriciaNode(key.substr(lenPrefix), True, val)
                        self.subNodes[firstChar] = newNode
                        self.size += 1
            else:
                # setting new sub-node
                newNode = PatriciaNode(key, True, val)
                self.subNodes[firstChar] = newNode
                self.size += 1

cdef class PatriciaDict(object):
    cdef PatriciaNode root

    def __cinit__(self):
        self.root = PatriciaNode()

    def __dealloc__(self):
        self.root = None

    cpdef void dump(self):
        self.root.dump()

    cpdef bool exist(self, key):
        cdef PatriciaNode node
        node = self.root.getNode(compat.toBytes(key))
        if node and node.isValid:
            return True
        else:
            return False

    cpdef object get(self, key, default=None):
        return self.root.get(compat.toBytes(key), default)

    cpdef unsigned long getSize(self):
        return self.root.size

    def items(self):
        for key, val in self.root.genItems():
            yield (compat.toStr(key), val)

    def keys(self):
        for key in self.root.genKeys():
            yield compat.toStr(key)

    def values(self):
        for val in self.root.genValues():
            yield val

    cpdef void remove(self, key):
        self.root.remove(compat.toBytes(key))

    cpdef void set(self, key, val):
        self.root.set(compat.toBytes(key), val)

    def __contains__(self, key):
        return self.exist(key)

    def __delitem__(self, key):
        self.remove(key)

    def __getitem__(self, key):
        cdef PatriciaNode node
        node = self.root.getNode(compat.toBytes(key))
        if node and node.isValid:
            return node.obj
        else:
            raise KeyError(key)

    def __iter__(self):
        for key in self.keys():
            yield key

    def __len__(self):
        return self.getSize()

    def __setitem__(self, key, val):
        self.set(key, val)

