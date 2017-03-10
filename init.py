#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Standard libraries
import os.path
import sys

def log(msg):
    if sys.stderr.isatty():
        # stderr is opened for terminal, showing message in cyan color
        sys.stderr.write("\033[36m%s\033[m\n" % str(msg))
    else:
        # stderr is redirected, showing message in default color
        sys.stderr.write("%s\n" % str(msg))

strHead = '[message on %s] ' % __name__
log(strHead+"Initializing NLPUtils...")
log(strHead+"Python version: %s" % sys.version.split('\n')[0].strip())

scriptDir = os.path.abspath(os.path.dirname(__file__))
log(strHead+"Script dir: %s" % scriptDir)
if scriptDir not in sys.path:
    sys.path.append(scriptDir)
parentDir = os.path.dirname(scriptDir)
log(strHead+"Parent dir: %s" % parentDir)
if parentDir not in sys.path:
    sys.path.append(parentDir)

# Cython set-up
log(strHead+"Setting up to use Cython")
from nlputils.common import pyximportcpp ; pyximportcpp.install()

log(strHead+"Initialization was done")

