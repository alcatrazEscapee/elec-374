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
            elif token in INSTRUCTIONS or token in FPU_INSTRUCTIONS:
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
                    elif token in ('addi', 'andi', 'ori', 'ld', 'ldi'):
                        ra, rb, c, *_ = tokens
                        inst = register(ra, 23) | register(rb, 19) | constant(c)
                    elif token == 'st':
                        ra, c, *_ = tokens
                        inst = register(ra, 23) | constant(c)
                    elif token in ('mfhi', 'mflo', 'in', 'out'):
                        ra, *_ = tokens
                        inst = register(ra, 23)
                    elif token in ('noop', 'halt'):
                        inst = 0
                    elif token in ('fadd', 'fsub', 'fmul', 'frc', 'fgt', 'feq'):
                        ra, rb, rc, *_ = tokens
                        inst = register(ra, 23) | register(rb, 19) | register(rc, 15)
                    elif token in ('mvrf', 'mvfr', 'crf', 'cfr', 'curf', 'cufr'):
                        ra, rb, *_ = tokens
                        inst = register(ra, 23) | register(rb, 19)
                    else:
                        raise NotImplementedError('Fixme, line %d:\n%s' % (1 + line_no, line))
                except Exception as err:
                    raise RuntimeError('Broken Line %d:\n%s' % (1 + line_no, line)) from err
                
                inst |= opcode(token)
                lines.append(hex(inst)[2:] + ' // ' + line)
                break
            else:
                raise RuntimeError('Broken Line %d:\n%s\n\nToken=%s' % (1 + line_no, line, token))
            
        if inst is None:
            lines.append(line)

    with open(output_file, 'w', encoding='utf-8') as f:
        for line in lines:
            f.write(line + '\n')


def constant(x: str) -> int:
    return eval(x) & ((1 << 19) - 1)

def opcode(x: str) -> int:
    if x in INSTRUCTIONS:
        return INSTRUCTIONS.index(x) << 27
    if x in FPU_INSTRUCTIONS:
        return (FPU_OPCODE << 27) | FPU_INSTRUCTIONS.index(x)

def register(x: str, offset: int = 0) -> int:
        return int(re.search('[rf]([0-9]{1,2})', x).group(1)) << offset

INSTRUCTIONS = ['ld', 'ldi', 'st', 'add', 'sub', 'shr', 'shl', 'ror', 'rol', 'and', 'or', 'addi', 'andi', 'ori', 'mul', 'div', 'neg', 'not']
FPU_INSTRUCTIONS = ['mvrf', 'mvfr', 'crf', 'cfr', 'curf', 'cufr', 'fadd', 'fsub', 'fmul', 'frc', 'fgt', 'feq']
FPU_OPCODE = 27

if __name__ == '__main__':
    main()
