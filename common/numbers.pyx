# distutils: language=c++
# -*- coding: utf-8 -*-

'''functions for numbers'''

# Standard libraries
import math

cpdef toNumber(anyNum, float margin = 0):
    cdef float floatNum
    cdef int intNum
    floatNum = float(anyNum)
    intNum   = int(round(floatNum))
    if abs(floatNum - intNum) <= margin:
        return intNum
    else:
        return floatNum

cpdef __py2__intToBytes(n, int length, str byteorder='big'):
    assert n >= 0
    strHex = '%x' % n
    if len(strHex) >= length*2:
        raise OverflowError('int too big to convert')
    strDecoded = strHex.zfill(length*2).decode('hex')
    return strDecoded if byteorder == 'big' else strDecoded[::-1]
cpdef __py3__intToBytes(n, int length, str byteorder='big'):
    return int.to_bytes(n, length, byteorder)

cpdef __py2__intFromBytes(bytes b, str byteorder='big'):
    if byteorder == 'big':
        return int(b.encode('hex'), 16)
    else:
        return int(b[::-1].encode('hex'), 16)
cpdef __py3__intFromBytes(bytes b, str byteorder='big'):
    return int.from_bytes(b, byteorder)

if hasattr(int, 'to_bytes'):
    intToBytes = __py3__intToBytes
    intFromBytes = __py3__intFromBytes
else:
    intToBytes = __py2__intToBytes
    intFromBytes = __py2__intFromBytes

