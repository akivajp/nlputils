#!/usr/bin/env python

import argparse
import sys

def guessLangCodeFromFileName(filepath):
    fields = filepath.split('.')
    fields.reverse()
    for field in fields:
        if len(field) == 2:
            return field.lower()
    return "UNK"

def printGuessLangCodeFromFileNameList(filenames):
    print(str.join(' ', map(guessLangCodeFromFileName, filenames)))

def cmdGuessLangCode(args):
    parser = argparse.ArgumentParser(description='Guess the language codes from given files')
    parser.add_argument('filenames', nargs="+", type=str, help='list of file names to guess the language codes')
    #parser.add_argument('--from-filename', '-n', action='store_true', help='guess from the file name (default)')
    parsed = parser.parse_args(args)
    printGuessLangCodeFromFileNameList(parsed.filenames)

if __name__ == '__main__':
    cmdGuessLangCode(sys.argv[1:])

