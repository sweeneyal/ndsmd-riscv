![alt text](header.png)

#

NDSMD is a RISC-V soft core processor IP designed to be an extensible demonstration platform for advanced architecture techniques, including, but not limited to, multilevel cache hierarchy, branch prediction, support for M, A, and F extensions, and out-of-order execution. This is a redesign of a previous project I worked on, with more rigorous verification and an emphasis on robustness to change.

The current development plan is as follows:
- [ ] Develop basic version of RV32I for use with BRAM ROM and RAM.
- [ ] Develop multilevel cache heirarchy with AXI-based L1iCache, L1dCache, L2uCache, with a master controller for testing.
- [ ] Develop branch prediction mechanism in basic BRAM ROM/RAM RV32I demonstration.
- [ ] Develop FPU with master controller and BRAM RAM interface to demonstrate processing of floating point instructions.
- [ ] Develop Tomasulo-based OOO architecture leveraging developed RV32I demo and new FPU.