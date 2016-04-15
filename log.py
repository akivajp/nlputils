#!/usr/bin/env python
# -*- coding: utf-8 -*-

import datetime
import sys

colors = {
    'clear': '\033[0m',
    'black': '\033[30m',
    'red': '\033[31m',
    'green': '\033[32m',
    'yellow': '\033[33m',
    'blue': '\033[34m',
    'purple': '\033[35m',
    'cyan': '\033[36m',
    'white': '\033[37m'
}

def timestamp():
    return datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")

def log(msg, color=None):
    strPrint = "[%s] %s" % (timestamp(), msg)
    if color in colors:
        code = colors[color]
        sys.stderr.write("%s%s\033[m\n" % (code,strPrint))
    else:
        sys.stdout.write(strPrint+"\n")

def warn(msg):
    strPrint = "[Warning %s] %s" % (timestamp(), msg)
    code = colors['yellow']
    sys.stderr.write("%s%s\033[m\n" % (code,strPrint))
    if quit:
        sys.exit(1)

def alert(msg, quit=True):
    strPrint = "[Error %s] %s" % (timestamp(), msg)
    code = colors['red']
    sys.stderr.write("%s%s\033[m\n" % (code,strPrint))
    if quit:
        sys.exit(1)

