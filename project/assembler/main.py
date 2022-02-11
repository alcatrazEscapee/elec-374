# This is *ridiculously* primitive
# It does not support all instructions (mostly because branches are hard)
# It is super brittle and will not report errors in any reasonable sense
# Usage: assembler/main.py <input file> [-o <output file>]

import re
import argparse


def main():
    parser = argparse.ArgumentParser('Primitive Assembler')
    parser.add_argument('input_file', type=str, help='Input Assembly')
    parser.add_argument('-o', type=str, default=None, dest='output_file', help='Output file')

    args = parser.parse_args()

    input_file = args.input_file
    output_file = args.output_file if args.output_file is not None else input_file.replace('.s', '.mem')

    with open(input_file, 'r', encoding='utf-8') as f:
        text = f.read()
    
    # Did I mention this was insanely primitive yet?
    lines = []
    for line_no, line in enumerate(text.split('\n')):
        tokens = line.replace(',', '').split(' ')
        while tokens:
            inst = None
            token = tokens.pop(0)
            if token == '':
                pass
            elif token == '//':
                break  # comment
            elif token in INSTRUCTIONS:
                try:
                    if token in ('add', 'sub', 'shr', 'shl', 'ror', 'rol', 'and', 'or'):
                        ra, rb, rc, *_ = tokens
                        inst = register(ra, 23) | register(rb, 19) | register(rc, 15)
                    elif token in ('mul', 'div'):
                        rb, rc, *_ = tokens
                        inst = register(rb, 19) | register(rc, 15)
                    elif token in ('neg', 'not'):
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
                    elif token in ('brzr', 'brnx', 'brpl', 'brmi'):
                        # only supports literal constants (no labels)
                        ra, c, *_ = tokens
                        if 'zr' in token:
                            c2 = 0
                        elif 'nx' in token:
                            c2 = 1
                        elif 'pl' in token:
                            c2 = 2
                        else:
                            c2 = 3
                        inst = register(ra, 23) | condition(c2) | constant(c)
                    elif token in ('mfhi', 'mflo', 'in', 'out', 'jal', 'jr'):
                        ra, *_ = tokens
                        inst = register(ra, 23)
                    elif token in ('noop', 'halt'):
                        inst = 0
                    else:
                        raise NotImplementedError('Fixme, line %d:\n%s' % (1 + line_no, line))
                except Exception as err:
                    raise RuntimeError('Broken Line %d:\n%s' % (1 + line_no, line)) from err
                
                inst |= opcode(token)
                inst_str = hex(inst)[2:].zfill(8)
                bin_str = "0b" + bin(inst)[2:].zfill(32)
                lines.append(inst_str + ' // ' + line + ' // ' + bin_str)
                break
            else:
                raise RuntimeError('Broken Line %d:\n%s\n\nToken=%s' % (1 + line_no, line, token))
            
        if inst is None:
            lines.append(line)

    with open(output_file, 'w', encoding='utf-8') as f:
        for line in lines:
            f.write(line + '\n')


def constant(x: str) -> int:
    return int(x) & ((1 << 19) - 1)

def opcode(x: str) -> int:
    # default to nop
    return INSTRUCTIONS.get(x, 25) << 27

def register(x: str, offset: int = 0) -> int:
    return int(re.search('r([0-9]{1,2})', x).group(1)) << offset

def condition(x: int) -> int:
    return x << 19

INSTRUCTIONS = {
    'ld': 0,
    'ldi': 1,
    'st': 2,
    'add': 3,
    'sub': 4,
    'shr': 5,
    'shl': 6,
    'ror': 7,
    'rol': 8,
    'and': 9,
    'or': 10,
    'addi': 11,
    'andi': 12,
    'ori': 13,
    'mul': 14,
    'div': 15,
    'neg': 16,
    'not': 17,
    'brzr': 18,
    'brnx': 18,
    'brpl': 18,
    'brmi': 18,
    'jr': 19,
    'jal': 20,
    'in': 21,
    'out': 22,
    'mfhi': 23,
    'mflo': 24,
    'nop': 25,
    'halt': 26,
}

if __name__ == '__main__':
    main()
