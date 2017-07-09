# distutils: language=c++
# -*- coding: utf-8 -*-

'''Log/Debug print functions'''

import datetime
import inspect
import os
import sys

from nlputils.common import compat
from nlputils.common import environ

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

#debugLevel = None
#debugLevel = 1

env_layer = environ.push()

#def enableDebug(level = 1):
def enable_debug(level = 1):
    env_layer.set('DEBUG', str(level))

#def disableDebug():
def disable_debug():
    env_layer.set('DEBUG', '0')

#def getDebugLevel():
def get_debug_level():
    mode = environ.get_env('DEBUG')
    if not mode:
        return 0
    else:
        if mode.lower() in ('', 'false', 'off'):
            return 0
        elif mode.lower() in ('true', 'on'):
            return 1
        else:
            try:
                return int(mode)
            except Exception as e:
                return -1

def get_color_mode():
    mode = environ.get_env('COLOR')
    auto = False
    if not mode:
        auto = True
    else:
        if mode.lower() in ('false', 'off'):
            return False
        elif mode.lower() in ('true', 'on', 'force'):
            return True
        elif mode.lower() in ('', 'auto',):
            auto = True
    if auto:
        return sys.stderr.isatty()
    else:
        return False

def enable_quiet():
    env_layer.set('QUIET', '1')

def disable_quiet():
    env_layer.set('QUIET', '0')

def get_quiet_mode():
    mode = environ.get_env('QUIET')
    if not mode:
        return False
    else:
        if mode.lower() in ('', 'false', '0'):
            return False
        elif mode.lower() in ('true', '1'):
            return True
    return False

def timestamp():
    return datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")

def put_color(content, color=None, force=False, newline=True):
    if color in colors:
        if force:
            fallback = False
        elif get_color_mode():
            fallback = False
        else:
            fallback = True
    else:
        fallback = True
    if fallback:
        sys.stderr.write(content+"\n")
    else:
        code = colors[color]
        #sys.stderr.write("%s%s\033[m\n" % (code,content))
        if newline:
            sys.stderr.write("%s%s%s\n" % (code,content,colors['clear']))
        else:
            sys.stderr.write("%s%s%s" % (code,content,colors['clear']))

#def log(msg, color=None, quiet=False):
#def log(msg, color='cyan', quiet=False):
def log(msg, color='cyan'):
    #if not quiet:
    if not get_quiet_mode():
        str_print = "[%s] %s" % (timestamp(), compat.to_str(msg))
        put_color(str_print, color)

#def test_inspect(index, s):
#    frame    = s[0]
#    filename = s[1]
#    line     = s[2]
#    name     = s[3]
#    code     = s[4]
#    if code:
#        str_print = "<%s> [%s:%s %s] %s: " % (index, filename, line, timestamp(), code[0].strip())
#    else:
#        str_print = "<%s> [%s:%s %s] : " % (index, filename, line, timestamp())
#    put_color(str_print, 'yellow')

import traceback

def debug(msg, color='yellow', level = 1):
    if get_debug_level() >= level:
        #print("color: %s" % get_color_mode())
        #print(inspect.stack()[0])
        #try:
        #    test_inspect(0, inspect.stack()[0])
        #    test_inspect(1, inspect.stack()[1])
        #    test_inspect(2, inspect.stack()[2])
        #except Exception as e:
        #    print(e)
        #frames = inspect.stack()
        #s = inspect.stack()[1]
        f = inspect.stack()[0]
        frame    = f[0]
        filename = f[1]
        line     = f[2]
        name     = f[3]
        code     = f[4]
        if code:
            #str_print = "[%s:%s %s] in function '%s': " % (filename, line, timestamp(), code[0].strip())
            str_print = "[%s:%s %s] '%s': " % (filename, line, timestamp(), code[0].strip())
        else:
            str_print = "[%s:%s %s] : " % (filename, line, timestamp())
        str_print += repr(msg)
        put_color(str_print, color)

def warn(msg, quiet=False):
    if not quiet:
        str_print = "[Warning %s] %s" % (timestamp(), str(msg))
        if sys.stderr.isatty():
            put_color(str_print, color='yellow')
        else:
            put_color(str_print)

def alert(msg, quit=True, quiet=False):
    if not quiet:
        str_print = "[Error %s] %s" % (timestamp(), str(msg))
        if sys.stderr.isatty():
            put_color(str_print, 'red')
        else:
            put_color(str_print)
    if quit:
        sys.exit(1)

