import numpy as np

a = np.zeros(shape=(4,4), dtype=np.uint32)
b = np.zeros(shape=(4,4), dtype=np.uint32)
c = np.zeros(shape=(4,4), dtype=np.uint32)

for i in range(4):
    for j in range(4):
        a[i,j] = i * j
        b[i,j] = i * j

print(a)
print(b)

c = a@b
print(c)

from zlib import crc32

x  = crc32(a)
x ^= crc32(b)
x ^= crc32(c)

print(hex(x))