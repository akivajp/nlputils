#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Cython set-up
import pyximport
#from pyximport import install
#from Cython.Compiler.Options import directive_defaults
# Standard libraries
import os.path
import sys
from distutils import sysconfig
# Local libraries
#from common import logging

get_distutils_extension = None

have_numpy = False
try:
    import numpy
    have_numpy = True
except Exception as e:
    pass

#if True:
def install():
    global get_distutils_extension
    if not get_distutils_extension:
        old_get_distutils_extension = pyximport.pyximport.get_distutils_extension
        def get_distutils_extension(modname, pyxfilename, language_level=None):
            #logging.log("modname: %s" % modname, color="cyan")
            #logging.log("pyxfilename: %s" % pyxfilename, color="cyan")
            #logging.log("language_level: %s" % language_level, color="cyan")
            global extension_mod, setup_args
            extension_mod, setup_args = old_get_distutils_extension(modname, pyxfilename, language_level)
            #logging.log("extension_mod: %s" % extension_mod, color="cyan")
            #logging.log("setup_args: %s" % setup_args, color="cyan")
            #logging.log("extension_mod.language: %s" % extension_mod.language, color="cyan")
            #logging.log("extension_mod.extra_compile_args: %s" % extension_mod.extra_compile_args, color="cyan")
            #logging.log("extension_mod.include_dirs: %s" % extension_mod.include_dirs, color="cyan")
            extension_mod.language='c++'
            extension_mod.extra_compile_args.append('-std=c++11')
            extension_mod.include_dirs.append(os.path.dirname(pyxfilename))
            if have_numpy:
                extension_mod.include_dirs.append(numpy.get_include())
                extension_mod.extra_compile_args.append('-w')
                #extension_mod.extra_compile_args.append('-DNPY_NO_DEPRECATED_API=DNPY_1_7_API_VERSION')
                #extension_mod.extra_compile_args.append('-DNPY_NO_DEPRECATED_API')
                #extension_mod.extra_compile_args.append('-DNPY_1_7_API_VERSION')
            #extension_mod.extra_compile_args.append('-DCYTHON_TRACE=1')
            #extension_mod.define_macros.append( ('CYTHON_TRACE', '1') )
            return extension_mod,setup_args
        pyximport.pyximport.get_distutils_extension = get_distutils_extension
    if sys.platform == 'linux2':
        # Omitting 'strict-prototypes' warning For Python 2.x
        opt = sysconfig.get_config_vars().get('OPT', '')
        opt = opt.replace('-Wstrict-prototypes', '')
        sysconfig.get_config_vars()['OPT'] = opt
        # Omitting 'strict-prototypes' warning For Python 3.x
        cflags = sysconfig.get_config_vars().get('CFLAGS', '')
        cflags = cflags.replace('-Wstrict-prototypes', '')
        sysconfig.get_config_vars()['CFLAGS'] = cflags
    #directive_defaults['binding'] = True
    #directive_defaults['linetrace'] = True
    pyximport.install()

