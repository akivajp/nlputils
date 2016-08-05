#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Cython set-up
import pyximport
#from pyximport import install
from Cython.Compiler.Options import directive_defaults
# Standard libraries
import sys
from distutils import sysconfig
# Local libraries
from common import log

get_distutils_extension = None

#if True:
def install():
    global get_distutils_extension
    if not get_distutils_extension:
        old_get_distutils_extension = pyximport.pyximport.get_distutils_extension
        def get_distutils_extension(modname, pyxfilename, language_level=None):
            #log.log("modname: %s" % modname, color="cyan")
            #log.log("pyxfilename: %s" % pyxfilename, color="cyan")
            #log.log("language_level: %s" % language_level, color="cyan")
            global extension_mod, setup_args
            extension_mod, setup_args = old_get_distutils_extension(modname, pyxfilename, language_level)
            #log.log("extension_mod: %s" % extension_mod, color="cyan")
            #log.log("setup_args: %s" % setup_args, color="cyan")
            extension_mod.language='c++'
            extension_mod.extra_compile_args.append('-std=c++11')
            #extension_mod.extra_compile_args.append('-DCYTHON_TRACE=1')
            #extension_mod.define_macros.append( ('CYTHON_TRACE', '1') )
            return extension_mod,setup_args
        pyximport.pyximport.get_distutils_extension = get_distutils_extension
    if sys.platform == 'linux2':
        #cflags = sysconfig.get_config_vars().get('CFLAGS', '')
        #cflags = cflags.replace('-Wstrict-prototypes', '')
        #sysconfig.get_config_vars()['CFLAGS'] = cflags
        #print("CFLAGS: %s" % cflags)
        opt = sysconfig.get_config_vars().get('OPT', '')
        opt = opt.replace('-Wstrict-prototypes', '')
        #opt += ' -DCYTHON_TRACE=1'
        sysconfig.get_config_vars()['OPT'] = opt
        #corecflags = sysconfig.get_config_vars().get('PY_CORE_CFLAGS', '')
        #corecflags = corecflags.replace('-Wstrict-prototypes', '')
        #sysconfig.get_config_vars()['PY_CORE_CFLAGS'] = corecflags
        #shared = sysconfig.get_config_vars().get('BLDSHARED', '')
        #shared = shared.replace('-Wstrict-prototypes', '')
        #sysconfig.get_config_vars()['BLDSHARED'] = shared
        #pycflags = sysconfig.get_config_vars().get('PY_CFLAGS', '')
        #pycflags = pycflags.replace('-Wstrict-prototypes', '')
        #sysconfig.get_config_vars()['PY_CFLAGS'] = pycflags
    #directive_defaults['binding'] = True
    #directive_defaults['linetrace'] = True
    pyximport.install()

