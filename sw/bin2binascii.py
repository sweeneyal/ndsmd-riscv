import sys
import numpy as np
import os

if len(sys.argv) > 1:
    path = sys.argv[1]
else:
    path = "./sw/matmult/matmult.bin"

with open(path, 'rb') as f:
    binary = f.read()
    words = np.frombuffer(binary, np.uint32)
    new_path = os.path.splitext(path)[0] + ".data"
    fw = open(new_path, 'w')
    for i in range(0, len(words)):
        fw.write(bin(words[i])[2:].zfill(32) + "\n")
