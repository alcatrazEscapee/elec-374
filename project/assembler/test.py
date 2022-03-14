import main
import unittest


class AssemblerTest(unittest.TestCase):

    # Phase 1

    def test_and(self): self.asm('and r5, r2, r4', '01001 0101 0010 0100 000000000000000')
    def test_or(self): self.asm('or r5, r2, r4', '01010 0101 0010 0100 000000000000000')
    def test_add(self): self.asm('add r5, r2, r4', '00011 0101 0010 0100 000000000000000')
    def test_sub(self): self.asm('sub r5, r2, r4', '00100 0101 0010 0100 000000000000000')
    def test_shr(self): self.asm('shr r5, r2, r4', '00101 0101 0010 0100 000000000000000')
    def test_shl(self): self.asm('shl r5, r2, r4', '00110 0101 0010 0100 000000000000000')
    def test_ror(self): self.asm('ror r5, r2, r4', '00111 0101 0010 0100 000000000000000')
    def test_rol(self): self.asm('rol r5, r2, r4', '01000 0101 0010 0100 000000000000000')
    def test_mul(self): self.asm('mul r2, r5', '01110 0010 0101 0000000000000000000')
    def test_div(self): self.asm('div r2, r5', '01111 0010 0101 0000000000000000000')
    def test_neg(self): self.asm('neg r5, r2', '10000 0101 0010 0000000000000000000')
    def test_not(self): self.asm('not r5, r2', '10001 0101 0010 0000000000000000000')

    # Phase 2

    def test_ld_r0(self): self.asm('ld r1, 85', '00000 0001 0000 0000000000001010101')
    def test_ld_rx(self): self.asm('ld r0, 35(r1)', '00000 0000 0001 0000000000000100011')
    def test_ldi_r0(self): self.asm('ldi r1, 85', '00001 0001 0000 0000000000001010101')
    def test_ldi_rx(self): self.asm('ldi r0, 35(r1)', '00001 0000 0001 0000000000000100011')
    def test_st_r0(self): self.asm('st 90, r1', '00010 0001 0000 0000000000001011010')
    def test_st_rx(self): self.asm('st 90(r1), r1', '00010 0001 0001 0000000000001011010')
    def test_addi(self): self.asm('addi r2, r1, -5', '01011 0010 0001 1111111111111111011')
    def test_andi(self): self.asm('andi r2, r1, 26', '01100 0010 0001 0000000000000011010')
    def test_ori(self): self.asm('ori r2, r1, 26', '01101 0010 0001 0000000000000011010')
    def test_brzr(self): self.asm('brzr r2, 35', '10010 0010 0000 0000000000000100011')
    def test_brnz(self): self.asm('brnz r2, 35', '10010 0010 0001 0000000000000100011')
    def test_brpl(self): self.asm('brpl r2, 35', '10010 0010 0010 0000000000000100011')
    def test_brmi(self): self.asm('brmi r2, 35', '10010 0010 0011 0000000000000100011')
    def test_jr(self): self.asm('jr r1', '10011 0001 00000000000000000000000')
    def test_jal(self): self.asm('jal r1', '10100 0001 00000000000000000000000')
    def test_mfhi(self): self.asm('mfhi r2', '10111 0010 00000000000000000000000')
    def test_mflo(self): self.asm('mflo r2', '11000 0010 00000000000000000000000')
    def test_out(self): self.asm('out r1', '10110 0001 00000000000000000000000')
    def test_in(self): self.asm('in r1', '10101 0001 00000000000000000000000')

    # Misc
    
    def test_nop(self): self.asm('nop', '11001 000000000000000000000000000')
    def test_halt(self): self.asm('halt', '11010 000000000000000000000000000')

    # FPU

    def test_crf(self): self.asm('crf f2 r1', '11011 0010 0001 0000 00000000000 0000')
    def test_cfr(self): self.asm('cfr r2 f1', '11011 0010 0001 0000 00000000000 0001')
    def test_curf(self): self.asm('curf f2 r1', '11011 0010 0001 0000 00000000000 0010')
    def test_cufr(self): self.asm('cufr r2 f1', '11011 0010 0001 0000 00000000000 0011')
    def test_fadd(self): self.asm('fadd f1 f2 f3', '11011 0001 0010 0011 00000000000 0100')
    def test_fsub(self): self.asm('fsub f1 f2 f3', '11011 0001 0010 0011 00000000000 0101')
    def test_fmul(self): self.asm('fmul f1 f2 f3', '11011 0001 0010 0011 00000000000 0110')
    def test_frc(self): self.asm('frc f1 f2', '11011 0001 0010 0000 00000000000 0111')
    def test_fgt(self): self.asm('fgt r1 f2 f3', '11011 0001 0010 0011 00000000000 1000')
    def test_feq(self): self.asm('feq r1 f2 f3', '11011 0001 0010 0011 00000000000 1001')

    def asm(self, asm: str, binary: str):
        expected = hex(int('0b' + binary.replace(' ', '_'), 2))[2:].zfill(8) + ' // 000 : ' + asm
        (actual, *_), *_ = main.assemble(asm)
        self.assertEqual(actual, expected, 'Assembly:\n%s\nBinary:\n%s\nExpected:\n%s\nActual:\n%s' % (asm, binary, expected, actual))


if __name__ == '__main__':
    unittest.main()