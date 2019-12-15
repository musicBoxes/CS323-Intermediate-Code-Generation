import sys
import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--r', type=int, default=0, help='irsim')
parser.add_argument('--n', type=int, default=1, help='index number')
parser.add_argument('--i', type=str, default="", help='input')
args = parser.parse_args()

if not args.r:
    cmd = "cat -n ./test/test_3_r%02d.out"%(args.n)
    os.system(cmd)
else:
    if (len(args.i) == 0): # no input
        print("No input")
        cmd = "irsim ./test/test_3_r%02d.out"%(args.n)
        os.system(cmd)
    else:
        cmd = "irsim ./test/test_3_r%02d.out -i %s"%(args.n, args.i)
        os.system(cmd)