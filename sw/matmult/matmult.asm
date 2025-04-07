
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
  28:	02f706b3          	mul	a3,a4,a5
  2c:	fec42783          	lw	a5,-20(s0)
  30:	00279713          	slli	a4,a5,0x2
  34:	fe842783          	lw	a5,-24(s0)
  38:	00f707b3          	add	a5,a4,a5
  3c:	00005737          	lui	a4,0x5
  40:	00070713          	mv	a4,a4
  44:	00279793          	slli	a5,a5,0x2
  48:	00f707b3          	add	a5,a4,a5
  4c:	00d7a023          	sw	a3,0(a5)
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
  98:	02f706b3          	mul	a3,a4,a5
  9c:	fe442783          	lw	a5,-28(s0)
  a0:	00279713          	slli	a4,a5,0x2
  a4:	fe042783          	lw	a5,-32(s0)
  a8:	00f707b3          	add	a5,a4,a5
  ac:	00005737          	lui	a4,0x5
  b0:	04070713          	addi	a4,a4,64 # 5040 <b>
  b4:	00279793          	slli	a5,a5,0x2
  b8:	00f707b3          	add	a5,a4,a5
  bc:	00d7a023          	sw	a3,0(a5)
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
  f4:	0540006f          	j	148 <main+0x148>
  f8:	fc042c23          	sw	zero,-40(s0)
  fc:	0340006f          	j	130 <main+0x130>
 100:	fdc42783          	lw	a5,-36(s0)
 104:	00279713          	slli	a4,a5,0x2
 108:	fd842783          	lw	a5,-40(s0)
 10c:	00f707b3          	add	a5,a4,a5
 110:	00005737          	lui	a4,0x5
 114:	08070713          	addi	a4,a4,128 # 5080 <c>
 118:	00279793          	slli	a5,a5,0x2
 11c:	00f707b3          	add	a5,a4,a5
 120:	0007a023          	sw	zero,0(a5)
 124:	fd842783          	lw	a5,-40(s0)
 128:	00178793          	addi	a5,a5,1
 12c:	fcf42c23          	sw	a5,-40(s0)
 130:	fd842703          	lw	a4,-40(s0)
 134:	00300793          	li	a5,3
 138:	fce7f4e3          	bgeu	a5,a4,100 <main+0x100>
 13c:	fdc42783          	lw	a5,-36(s0)
 140:	00178793          	addi	a5,a5,1
 144:	fcf42e23          	sw	a5,-36(s0)
 148:	fdc42703          	lw	a4,-36(s0)
 14c:	00300793          	li	a5,3
 150:	fae7f4e3          	bgeu	a5,a4,f8 <main+0xf8>
 154:	fc042a23          	sw	zero,-44(s0)
 158:	0e80006f          	j	240 <main+0x240>
 15c:	fc042823          	sw	zero,-48(s0)
 160:	0c80006f          	j	228 <main+0x228>
 164:	fc042623          	sw	zero,-52(s0)
 168:	0a80006f          	j	210 <main+0x210>
 16c:	fd442783          	lw	a5,-44(s0)
 170:	00279713          	slli	a4,a5,0x2
 174:	fd042783          	lw	a5,-48(s0)
 178:	00f707b3          	add	a5,a4,a5
 17c:	00005737          	lui	a4,0x5
 180:	08070713          	addi	a4,a4,128 # 5080 <c>
 184:	00279793          	slli	a5,a5,0x2
 188:	00f707b3          	add	a5,a4,a5
 18c:	0007a683          	lw	a3,0(a5)
 190:	fd442783          	lw	a5,-44(s0)
 194:	00279713          	slli	a4,a5,0x2
 198:	fcc42783          	lw	a5,-52(s0)
 19c:	00f707b3          	add	a5,a4,a5
 1a0:	00005737          	lui	a4,0x5
 1a4:	00070713          	mv	a4,a4
 1a8:	00279793          	slli	a5,a5,0x2
 1ac:	00f707b3          	add	a5,a4,a5
 1b0:	0007a703          	lw	a4,0(a5)
 1b4:	fd442783          	lw	a5,-44(s0)
 1b8:	00279613          	slli	a2,a5,0x2
 1bc:	fd042783          	lw	a5,-48(s0)
 1c0:	00f607b3          	add	a5,a2,a5
 1c4:	00005637          	lui	a2,0x5
 1c8:	04060613          	addi	a2,a2,64 # 5040 <b>
 1cc:	00279793          	slli	a5,a5,0x2
 1d0:	00f607b3          	add	a5,a2,a5
 1d4:	0007a783          	lw	a5,0(a5)
 1d8:	02f70733          	mul	a4,a4,a5
 1dc:	fd442783          	lw	a5,-44(s0)
 1e0:	00279613          	slli	a2,a5,0x2
 1e4:	fd042783          	lw	a5,-48(s0)
 1e8:	00f607b3          	add	a5,a2,a5
 1ec:	00e68733          	add	a4,a3,a4
 1f0:	000056b7          	lui	a3,0x5
 1f4:	08068693          	addi	a3,a3,128 # 5080 <c>
 1f8:	00279793          	slli	a5,a5,0x2
 1fc:	00f687b3          	add	a5,a3,a5
 200:	00e7a023          	sw	a4,0(a5)
 204:	fcc42783          	lw	a5,-52(s0)
 208:	00178793          	addi	a5,a5,1
 20c:	fcf42623          	sw	a5,-52(s0)
 210:	fcc42703          	lw	a4,-52(s0)
 214:	00300793          	li	a5,3
 218:	f4e7fae3          	bgeu	a5,a4,16c <main+0x16c>
 21c:	fd042783          	lw	a5,-48(s0)
 220:	00178793          	addi	a5,a5,1
 224:	fcf42823          	sw	a5,-48(s0)
 228:	fd042703          	lw	a4,-48(s0)
 22c:	00300793          	li	a5,3
 230:	f2e7fae3          	bgeu	a5,a4,164 <main+0x164>
 234:	fd442783          	lw	a5,-44(s0)
 238:	00178793          	addi	a5,a5,1
 23c:	fcf42a23          	sw	a5,-44(s0)
 240:	fd442703          	lw	a4,-44(s0)
 244:	00300793          	li	a5,3
 248:	f0e7fae3          	bgeu	a5,a4,15c <main+0x15c>
 24c:	0000006f          	j	24c <main+0x24c>
