
matmult.elf:     file format elf32-littleriscv


Disassembly of section .text:

00000000 <main>:
   0:	fc010113          	addi	sp,sp,-64
   4:	02112e23          	sw	ra,60(sp)
   8:	02812c23          	sw	s0,56(sp)
   c:	04010413          	addi	s0,sp,64
  10:	fe042623          	sw	zero,-20(s0)
  14:	0600006f          	j	74 <main+0x74>
  18:	fe042423          	sw	zero,-24(s0)
  1c:	0400006f          	j	5c <main+0x5c>
  20:	fec42703          	lw	a4,-20(s0)
  24:	fe842783          	lw	a5,-24(s0)
  28:	02f707b3          	mul	a5,a4,a5
  2c:	00078613          	mv	a2,a5
  30:	23c00713          	li	a4,572
  34:	fec42783          	lw	a5,-20(s0)
  38:	00279693          	slli	a3,a5,0x2
  3c:	fe842783          	lw	a5,-24(s0)
  40:	00f687b3          	add	a5,a3,a5
  44:	00279793          	slli	a5,a5,0x2
  48:	00f707b3          	add	a5,a4,a5
  4c:	00c7a023          	sw	a2,0(a5)
  50:	fe842783          	lw	a5,-24(s0)
  54:	00178793          	addi	a5,a5,1
  58:	fef42423          	sw	a5,-24(s0)
  5c:	fe842703          	lw	a4,-24(s0)
  60:	00300793          	li	a5,3
  64:	fae7fee3          	bgeu	a5,a4,20 <main+0x20>
  68:	fec42783          	lw	a5,-20(s0)
  6c:	00178793          	addi	a5,a5,1
  70:	fef42623          	sw	a5,-20(s0)
  74:	fec42703          	lw	a4,-20(s0)
  78:	00300793          	li	a5,3
  7c:	f8e7fee3          	bgeu	a5,a4,18 <main+0x18>
  80:	fe042223          	sw	zero,-28(s0)
  84:	0600006f          	j	e4 <main+0xe4>
  88:	fe042023          	sw	zero,-32(s0)
  8c:	0400006f          	j	cc <main+0xcc>
  90:	fe442703          	lw	a4,-28(s0)
  94:	fe042783          	lw	a5,-32(s0)
  98:	02f707b3          	mul	a5,a4,a5
  9c:	00078613          	mv	a2,a5
  a0:	27c00713          	li	a4,636
  a4:	fe442783          	lw	a5,-28(s0)
  a8:	00279693          	slli	a3,a5,0x2
  ac:	fe042783          	lw	a5,-32(s0)
  b0:	00f687b3          	add	a5,a3,a5
  b4:	00279793          	slli	a5,a5,0x2
  b8:	00f707b3          	add	a5,a4,a5
  bc:	00c7a023          	sw	a2,0(a5)
  c0:	fe042783          	lw	a5,-32(s0)
  c4:	00178793          	addi	a5,a5,1
  c8:	fef42023          	sw	a5,-32(s0)
  cc:	fe042703          	lw	a4,-32(s0)
  d0:	00300793          	li	a5,3
  d4:	fae7fee3          	bgeu	a5,a4,90 <main+0x90>
  d8:	fe442783          	lw	a5,-28(s0)
  dc:	00178793          	addi	a5,a5,1
  e0:	fef42223          	sw	a5,-28(s0)
  e4:	fe442703          	lw	a4,-28(s0)
  e8:	00300793          	li	a5,3
  ec:	f8e7fee3          	bgeu	a5,a4,88 <main+0x88>
  f0:	fc042e23          	sw	zero,-36(s0)
  f4:	0500006f          	j	144 <main+0x144>
  f8:	fc042c23          	sw	zero,-40(s0)
  fc:	0300006f          	j	12c <main+0x12c>
 100:	2bc00713          	li	a4,700
 104:	fdc42783          	lw	a5,-36(s0)
 108:	00279693          	slli	a3,a5,0x2
 10c:	fd842783          	lw	a5,-40(s0)
 110:	00f687b3          	add	a5,a3,a5
 114:	00279793          	slli	a5,a5,0x2
 118:	00f707b3          	add	a5,a4,a5
 11c:	0007a023          	sw	zero,0(a5)
 120:	fd842783          	lw	a5,-40(s0)
 124:	00178793          	addi	a5,a5,1
 128:	fcf42c23          	sw	a5,-40(s0)
 12c:	fd842703          	lw	a4,-40(s0)
 130:	00300793          	li	a5,3
 134:	fce7f6e3          	bgeu	a5,a4,100 <main+0x100>
 138:	fdc42783          	lw	a5,-36(s0)
 13c:	00178793          	addi	a5,a5,1
 140:	fcf42e23          	sw	a5,-36(s0)
 144:	fdc42703          	lw	a4,-36(s0)
 148:	00300793          	li	a5,3
 14c:	fae7f6e3          	bgeu	a5,a4,f8 <main+0xf8>
 150:	fc042a23          	sw	zero,-44(s0)
 154:	0d80006f          	j	22c <main+0x22c>
 158:	fc042823          	sw	zero,-48(s0)
 15c:	0b80006f          	j	214 <main+0x214>
 160:	fc042623          	sw	zero,-52(s0)
 164:	0980006f          	j	1fc <main+0x1fc>
 168:	2bc00713          	li	a4,700
 16c:	fd442783          	lw	a5,-44(s0)
 170:	00279693          	slli	a3,a5,0x2
 174:	fd042783          	lw	a5,-48(s0)
 178:	00f687b3          	add	a5,a3,a5
 17c:	00279793          	slli	a5,a5,0x2
 180:	00f707b3          	add	a5,a4,a5
 184:	0007a703          	lw	a4,0(a5)
 188:	23c00693          	li	a3,572
 18c:	fd442783          	lw	a5,-44(s0)
 190:	00279613          	slli	a2,a5,0x2
 194:	fcc42783          	lw	a5,-52(s0)
 198:	00f607b3          	add	a5,a2,a5
 19c:	00279793          	slli	a5,a5,0x2
 1a0:	00f687b3          	add	a5,a3,a5
 1a4:	0007a683          	lw	a3,0(a5)
 1a8:	27c00613          	li	a2,636
 1ac:	fcc42783          	lw	a5,-52(s0)
 1b0:	00279593          	slli	a1,a5,0x2
 1b4:	fd042783          	lw	a5,-48(s0)
 1b8:	00f587b3          	add	a5,a1,a5
 1bc:	00279793          	slli	a5,a5,0x2
 1c0:	00f607b3          	add	a5,a2,a5
 1c4:	0007a783          	lw	a5,0(a5)
 1c8:	02f687b3          	mul	a5,a3,a5
 1cc:	00f70733          	add	a4,a4,a5
 1d0:	2bc00693          	li	a3,700
 1d4:	fd442783          	lw	a5,-44(s0)
 1d8:	00279613          	slli	a2,a5,0x2
 1dc:	fd042783          	lw	a5,-48(s0)
 1e0:	00f607b3          	add	a5,a2,a5
 1e4:	00279793          	slli	a5,a5,0x2
 1e8:	00f687b3          	add	a5,a3,a5
 1ec:	00e7a023          	sw	a4,0(a5)
 1f0:	fcc42783          	lw	a5,-52(s0)
 1f4:	00178793          	addi	a5,a5,1
 1f8:	fcf42623          	sw	a5,-52(s0)
 1fc:	fcc42703          	lw	a4,-52(s0)
 200:	00300793          	li	a5,3
 204:	f6e7f2e3          	bgeu	a5,a4,168 <main+0x168>
 208:	fd042783          	lw	a5,-48(s0)
 20c:	00178793          	addi	a5,a5,1
 210:	fcf42823          	sw	a5,-48(s0)
 214:	fd042703          	lw	a4,-48(s0)
 218:	00300793          	li	a5,3
 21c:	f4e7f2e3          	bgeu	a5,a4,160 <main+0x160>
 220:	fd442783          	lw	a5,-44(s0)
 224:	00178793          	addi	a5,a5,1
 228:	fcf42a23          	sw	a5,-44(s0)
 22c:	fd442703          	lw	a4,-44(s0)
 230:	00300793          	li	a5,3
 234:	f2e7f2e3          	bgeu	a5,a4,158 <main+0x158>
 238:	0000006f          	j	238 <main+0x238>
