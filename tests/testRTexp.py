# -*- coding: utf-8 -*-

"""
Real time export simulation

__________________________________________________________________________
Copyright (C) 2016-2021 OpenNFT.org

Written by Artem Nikonorov, Yury Koush
"""


import shutil
from time import sleep
from pathlib import Path
import sys
import os

delete_files = False

mask = "001_000008_000"
# fns = [1, 2, 3, 4, 6, 5, 7, 8]
fns = None

testCase = 'SVM'

pause_in_sec = 1.5

if len(sys.argv) != 3:
    print("Usage: python script.py <srcpath> <dstpath>")
    exit()

srcpath = sys.argv[1]
dstpath = sys.argv[2]

# Check if provided paths are valid directories
if not os.path.isdir(srcpath):
    print(f"The path '{srcpath}' is not a valid directory.")
    exit()

if not os.path.isdir(dstpath):
    print(f"The path '{dstpath}' is not a valid directory.")
    exit()

if delete_files:
    files = Path(dstpath)
    for f in files.glob('*'):
        f.unlink()


if fns is None:
    filelist = Path(srcpath).iterdir()
else:
    filelist = []
    for fn in fns:
        fname = "{0}{1:03d}.dcm".format(mask, fn)
        filelist.append(fname)

for filename in sorted(filelist):
    src = filename
    if Path.is_file(src) and (not str(filename).startswith(".")):
        dst = Path(dstpath, filename.name)
        shutil.copy(src, dst)
        print(filename)
        sleep(pause_in_sec)  # seconds
