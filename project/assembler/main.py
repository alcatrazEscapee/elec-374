# This is *ridiculously* primitive
# It does not support all instructions (mostly because branches are hard)
# It is super brittle and will not report errors in any reasonable sense
# Usage: assembler/main.py <input file> [-o <output file>]

import re
import argparse
from typing import List


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
    word_count = 0
    lines = []
    directives = []
    for line_no, line in enumerate(text.split('\n')):
        tokens = line.replace(',', '').split(' ')
        while tokens:
            inst = None
            token = tokens.pop(0)
            if token == '':
                pass
            elif token == '//':
                break  # comment
            elif token in DIRECTIVES:
                directive = handle_directive(token, tokens, line, line_no)
                directives.append(directive)
                # e.g. /// .mem 1234 (42 values)
                lines.append("/// .mem {} ({} values)".format(directive["address"], len(directive["values"])))
                break
            elif token in INSTRUCTIONS or token in FPU_INSTRUCTIONS:
                inst = handle_instruction(token, tokens, line, line_no)
                lines.append(inst)
                word_count += 1
                break
            else:
                raise RuntimeError('Broken Line %d:\n%s\n\nToken=%s' % (1 + line_no, line, token))

        if token in ("", "//"):
            # preserve whitespace
            lines.append(line)

    # after parsing and appending instructions, handle directives
    directives.sort(key=lambda x: x.get("address", 0xFF000000))
    for directive in directives:
        address = directive.get("address", 0xFF000000)
        values = directive.get("values", [])

        # calculate padding
        diff = address - word_count
        assert diff >= 0, 'Overlapping memory values and assembly!'
        lines.extend(["00000000"] * diff)

        # write values
        str_values = [hex(x)[2:].zfill(8) for x in values]
        lines.extend(str_values)

        # update word count
        word_count += len(values) + diff


    with open(output_file, 'w', encoding='utf-8') as f:
        for line in lines:
            f.write(line + '\n')


def handle_instruction(token: str, tokens: List[str], line: str, line_no: int) -> str:
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
            c2 = ['zr', 'nx', 'pl', 'mi'].index(token[2:])
            inst = register(ra, 23) | condition(c2) | constant(c)
        elif token in ('mfhi', 'mflo', 'in', 'out', 'jal', 'jr'):
            ra, *_ = tokens
            inst = register(ra, 23)
        elif token in ('noop', 'halt'):
            inst = 0
        elif token in ('fadd', 'fsub', 'fmul', 'fgt', 'feq'):
            ra, rb, rc, *_ = tokens
            inst = register(ra, 23) | register(rb, 19) | register(rc, 15)
        elif token in ('frc', 'mvrf', 'mvfr', 'crf', 'cfr', 'curf', 'cufr'):
            ra, rb, *_ = tokens
            inst = register(ra, 23) | register(rb, 19)
        else:
            raise NotImplementedError('Fixme, line %d:\n%s' % (1 + line_no, line))
    except Exception as err:
        raise RuntimeError('Broken Line %d:\n%s' % (1 + line_no, line)) from err

    inst |= opcode(token)
    inst_str = hex(inst)[2:].zfill(8)
    bin_str = "0b" + bin(inst)[2:].zfill(32)

    instr_line = inst_str + ' // ' + line + ' // ' + bin_str

    return instr_line

def handle_directive(token: str, tokens: List[str], line: str, line_no: int):
    try:
        if token == '.mem':
            # remove extra whitespace
            tokens = [x for x in tokens if x != '']
            addr, *values = tokens

            addr = eval(addr) & ((1 << 32) - 1)
            values = [eval(x) & ((1 << 32) - 1) for x in values]

            return { 'address': addr, 'values': values }
        else:
            raise NotImplementedError('Fixme, line %d:\n%s' % (1 + line_no, line))
    except Exception as err:
        raise RuntimeError('Broken Line %d:\n%s' % (1 + line_no, line)) from err


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

FPU_INSTRUCTIONS = ['mvrf', 'mvfr', 'crf', 'cfr', 'curf', 'cufr', 'fadd', 'fsub', 'fmul', 'frc', 'fgt', 'feq']
FPU_OPCODE = 27

DIRECTIVES = {
    '.mem'
}

if __name__ == '__main__':
    main()
