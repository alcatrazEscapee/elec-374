# This is *ridiculously* primitive
# It does not support all instructions (mostly because branches are hard)
# It is super brittle and will not report errors in any reasonable sense
# Usage: assembler/main.py <input file> [-o <output file>]

import re

from argparse import ArgumentParser, Namespace
from typing import List, Tuple, Dict

MEMORY_SIZE = 512

MIF_PREFIX = """
DEPTH = {memory_size}; -- Memory Size (words)
WIDTH = 32; -- Data Width (bits)

ADDRESS_RADIX = UNS;
DATA_RADIX = HEX;

CONTENT
BEGIN
""".strip().format(memory_size=MEMORY_SIZE)


def parse_command_line_args() -> Namespace:
    parser = ArgumentParser('Primitive Assembler')
    parser.add_argument('input_file', type=str, help='Input Assembly')
    parser.add_argument('-o', type=str, default=None, dest='output_file', help='Output .mem')
    parser.add_argument('-m', type=str, default=None, dest='output_mif', help='Output .mif')

    return parser.parse_args()

def main(args: Namespace):
    input_file = args.input_file
    output_file = args.output_file if args.output_file is not None else input_file.replace('.s', '.mem')
    output_mif = args.output_mif

    with open(input_file, 'r', encoding='utf-8') as f:
        text = f.read()
    
    lines, mif = assemble(text)

    with open(output_file, 'w', encoding='utf-8') as f:
        for line in lines:
            f.write(line + '\n')
    
    if output_mif is not None:
        with open(output_mif, 'w', encoding='utf-8') as f:
            f.write(MIF_PREFIX + '\n')
            i = j = -1
            for i in range(MEMORY_SIZE):
                if i in mif:
                    # Pad previous addresses
                    if j != -1 and j < i - 1:
                        f.write('[%3d..%3d] : 00000000;\n' % (j + 1, i - 1))
                    f.write('%3d : %s\n' % (i, mif[i]))
                    j = i
            if j != -1 and j < i - 1:
                f.write('[%3d..%3d] : 00000000;\n' % (j + 1, i))
            f.write('\nEND\n')


def assemble(text: str):
    return Assembler(text).try_assemble()

class Assembler:

    def __init__(self, text: str):
        self.text: str = text
        self.lines: List[str] = text.split('\n')
        self.output: Dict[int, Tuple[int, str, str]] = {}  # code point -> (instruction, comment, label)
        self.labels: Dict[str, int] = {}  # label -> code point
        self.line_no: int = 0
        self.line: str = ''
        self.code_point: int = 0

    def try_assemble(self) -> Tuple[List[str], Dict[int, str]]:
        try:
            self.assemble()
        except Exception as e:
            raise RuntimeError('%s\nAt line %d:\n%s' % (e, 1 + self.line_no, self.line))
        
        for _, _, label in self.output.values():
            if label is not None and label not in self.labels:
                raise RuntimeError('Undefined label: %s' % label)
        
        lines = []
        mif = {}
        reverse_labels = {i: label for label, i in self.labels.items()}
        for i in range(1 + max(self.output.keys())):
            if i in self.output:
                code, comment, label = self.output[i]
                if label is not None:
                    code |= (self.labels[label] - i - 1) & ((1 << 19) - 1)
                if i in reverse_labels:
                    comment = '%s: %s' % (reverse_labels[i], comment.strip())
                
                instruction = hex(code)[2:].zfill(8)
                comment = comment.strip()
                
                lines.append('%s // %03d : %s' % (instruction, i, comment))
                mif[i] = instruction + ';' + ('' if comment == '' else ' -- ' + comment)
            else:
                lines.append('00000000 // %03d' % i)
        
        return lines, mif

    def assemble(self):
        for line_no, line in enumerate(self.lines):
            self.line_no = line_no
            self.line = line
            
            tokens = line.replace(',', '').split(' ')
            while tokens:
                token = tokens.pop(0)
                if token == '':
                    pass
                elif token == '//':
                    break  # comment
                elif match := re.match('([A-Za-z0-9-_]+):', token):
                    self.labels[match.group(1)] = self.code_point
                elif token == '.org':
                    point, *_ = tokens
                    self.code_point = eval(point)
                    break
                elif token == '.mem':
                    first = True
                    for word in tokens:
                        self.append(eval(word), '.mem [%d words]' % len(tokens) if first else '')
                        first = False
                    break
                elif token in INSTRUCTIONS or token in FPU_INSTRUCTIONS:
                    self.instruction(token, tokens)
                    break
                else:
                    self.error('Unknown token: %s' % token)
    
    def instruction(self, token: str, tokens: List[str]) -> str:
        label = None
        if token in ('add', 'sub', 'shr', 'shl', 'ror', 'rol', 'and', 'or'):
            ra, rb, rc, *_ = tokens
            inst = register(ra, 23) | register(rb, 19) | register(rc, 15)
        elif token in ('neg', 'not', 'mul', 'div'):
            ra, rb, *_ = tokens
            inst = register(ra, 23) | register(rb, 19)
        elif token in ('addi', 'andi', 'ori'):
            ra, rb, c, *_ = tokens
            inst = register(ra, 23) | register(rb, 19) | constant(c)
        elif token in ('ld', 'ldi'):
            ra, other, *_ = tokens
            if "(" in other:
                c, rb = other.replace(")", "").split("(")
            else:
                rb, c = ("r0", other)
            inst = register(ra, 23) | register(rb, 19) | constant(c)
        elif token == 'st':
            other, ra, *_ = tokens
            if "(" in other:
                c, rb = other.replace(")", "").split("(")
            else:
                rb, c = ("r0", other)
            inst = register(ra, 23) | register(rb, 19) | constant(c)
        elif token in ('brzr', 'brnz', 'brpl', 'brmi'):
            ra, label, *_ = tokens
            c2 = ['zr', 'nz', 'pl', 'mi'].index(token[2:])
            inst = register(ra, 23) | condition(c2)
            if re.match('-?0?x?b?[0-9]+', label):  # label is actually a constant
                inst |= constant(label)
                label = None
        elif token in ('mfhi', 'mflo', 'in', 'out', 'jal', 'jr'):
            ra, *_ = tokens
            inst = register(ra, 23)
        elif token in ('nop', 'halt'):
            inst = 0
        elif token in ('fadd', 'fsub', 'fmul', 'fgt', 'feq'):
            ra, rb, rc, *_ = tokens
            inst = register(ra, 23) | register(rb, 19) | register(rc, 15)
        elif token in ('frc', 'crf', 'cfr', 'curf', 'cufr'):
            ra, rb, *_ = tokens
            inst = register(ra, 23) | register(rb, 19)
        else:
            raise NotImplementedError

        self.append(inst | opcode(token), self.line, label)

    def append(self, code: int, comment: str, label: str = None):
        if self.code_point in self.output:
            self.error('Overwriting existing memory at %d' % self.code_point)
        self.output[self.code_point] = (code, comment, label)
        self.code_point += 1

    def error(self, message: str):
        raise RuntimeError(message)

def opcode(x: str) -> int:
    if x in INSTRUCTIONS:
        return INSTRUCTIONS[x] << 27
    if x in FPU_INSTRUCTIONS:
        return (FPU_OPCODE << 27) | FPU_INSTRUCTIONS.index(x)

def register(x: str, offset: int = 0) -> int:
    return int(re.search('[rf]([0-9]{1,2})', x).group(1)) << offset

def constant(x: str) -> int:
    return eval(x) & ((1 << 19) - 1)

def condition(x: int) -> int:
    return x << 19


INSTRUCTIONS = {'ld': 0, 'ldi': 1, 'st': 2, 'add': 3, 'sub': 4, 'shr': 5, 'shl': 6, 'ror': 7, 'rol': 8, 'and': 9, 'or': 10, 'addi': 11, 'andi': 12, 'ori': 13, 'mul': 14, 'div': 15, 'neg': 16, 'not': 17, 'brzr': 18, 'brnz': 18, 'brpl': 18, 'brmi': 18, 'jr': 19, 'jal': 20, 'in': 21, 'out': 22, 'mfhi': 23, 'mflo': 24, 'nop': 25, 'halt': 26}
FPU_INSTRUCTIONS = ['crf', 'cfr', 'curf', 'cufr', 'fadd', 'fsub', 'fmul', 'frc', 'fgt', 'feq']
FPU_OPCODE = 27

if __name__ == '__main__':
    main(parse_command_line_args())
