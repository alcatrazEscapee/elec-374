import os
import sys
import unittest
import subprocess
import collections

class Lazy:
    value: str

    def __str__(self) -> str:
        return self.value

class ModelSim(unittest.TestCase):
    pass


def mock(expected: str, actual: str, name: str):
    def apply(self):
        self.assertEqual(expected, actual, '%s\nExpected %s\nActual   %s' % (name, expected, actual))
    return apply

def mock_fail(message):
    def apply(self):
        self.fail(message)
    return apply

def mock_ea(name: str):
    expected, actual = Lazy(), Lazy()
    def load(parts):
        expected.value, actual.value = parts
    def apply(self):
        self.assertEqual(expected.value, actual.value, '%s\nExpected %s\nActual   %s' % (name, expected, actual))
    return load, apply

def mock_xea(name: str, prefix: str):
    line1, expected, actual = Lazy(), Lazy(), Lazy()
    def load(parts):
        line1.value, expected.value, actual.value = parts
    def apply(self):
        self.assertEqual(expected.value, actual.value, '%s\n%s%s\nExpected %s\nActual   %s' % (name, prefix, line1, expected, actual))
    return load, apply

def mock_xxea(name: str, prefix):
    line1, line2, expected, actual = Lazy(), Lazy(), Lazy(), Lazy()
    def load(parts):
        line1.value, line2.value, expected.value, actual.value = parts
    def apply(self):
        self.assertEqual(expected.value, actual.value, '%s\nExpected\n%s%s\n%s%s\n%s%s\nActual\n%s%s\n%s%s\n%s%s' % (name,
            prefix[0], line1,
            prefix[1], line2,
            prefix[2], expected,
            prefix[0], line1,
            prefix[1], line2,
            prefix[2], actual
        ))
    return load, apply

def mock_xxxxa(name: str, prefix):
    line1, line2, line3, line4, actual = Lazy(), Lazy(), Lazy(), Lazy(), Lazy()
    def load(parts):
        line1.value, line2.value, line3.value, line4.value, actual.value = parts
    def apply(self):
        self.assertEqual('true', actual.value, '%s\n%s%s\n%s%s\n%s%s\n%s%s' % (name,
            prefix[0], line1,
            prefix[1], line2,
            prefix[2], line3,
            prefix[3], line4
        ))
    return load, apply

def main():
    print('Analyzing Test Results')
    log = sys.argv[1]
    target = '???'
    i = 0
    fpu_tests = collections.defaultdict(list)
    cmd_replacements = {'>': 'G', '<': 'L', '=': 'E', '+': 'a', '-': 's', '*': 'x', '/': 'd'}

    with open(log, 'r', encoding='utf-8') as f:
        lines = f.read().split('\n')

    for output in lines:
        if output.startswith('vsim -voptargs=+acc work.'):
            *_, target = output.split('.')
            i = 0
        elif output.startswith('# ** Error:'):
            test = mock_fail('External error in module %s:\n  %s\n  check out/vsim.log for more info' % (target, output))
            test.__name__ = 'test %07d : %s compile' % (i, target)
            setattr (ModelSim, test.__name__, test)
            i += 1
        elif output.startswith('# Test'):
            special, name, *parts = map(lambda x: ' '.join(x.split()), output.split('|'))
            if special.startswith('# Test fpu'):
                op = special[-1]
                if op in 'fg':
                    load, test = mock_ea(name)
                elif op in 'ij':
                    load, test = mock_xea(name, '= (int) ' if op == 'i' else '= (unsigned int) ')
                elif op in 'r':
                    load, test = mock_xxxxa(name, ('Input    ', 'Expected ', 'Actual   ', 'Error    '))
                elif op in '+-*/':
                    load, test = mock_xxea(name, ('  ', op + ' ', '= '))
                elif op in '<=>':
                    load, test = mock_xea(name, 'Compare: ')
                else:
                    raise RuntimeError('Unknown op: \'%s\'' % op)
                fpu_tests[op].append((parts, load))
            else:
                expected, actual = parts
                test = mock(expected, actual, name)

            test.__name__ = 'test %07d : %s : %s' % (i, target, name)
            setattr (ModelSim, test.__name__, test)
            i += 1

    fpu_lines = []
    for op, tests in fpu_tests.items():
        print('Verifying FPU Tests (%s)' % op)
        fpu_lines.append('\nRunning fpu (%s)\n' % op)
        proc_op = cmd_replacements[op] if op in cmd_replacements else op
        proc = subprocess.Popen(os.path.join('out', 'fpu.o') + ' ' + proc_op, shell=True, encoding='utf-8', stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        inputs = scan_for_xz(tests)
        out, err = proc.communicate(inputs)
        fpu_lines.append(out)

        if err is not None:
            raise RuntimeError(err)

        for line, e in zip(out.split('\n'), tests):
            try:
                e[1](line.split('|'))  # Outputs are split by '|'
            except Exception as err:
                raise RuntimeError('Invalid Test Process Output\n  Input  : %s\n  Output : %s' % (e[0], line.split('|'))) from err

    with open(log.replace('vsim', 'fpu'), 'w', encoding='utf-8') as f:
        f.writelines(fpu_lines)

def scan_for_xz(tests):
    errors = []
    params = []
    for test in tests:
        for param in test[0]:
            params.append(param)
            if 'x' in param or 'z' in param:
                errors.append(param)
    if errors:
        err = 'Invalid input values for FPU native tests.\nOffending lines:\n'
        if len(errors) < 10:
            err += '  ' + '\n  '.join(errors)
        else:
            err += '  ' + '\n  '.join(errors[:10]) + '\n... and %d more' % (len(errors) - 10)
        raise RuntimeError(err)
    return '\n'.join(params)


if __name__ == '__main__':
    main()
    sys.argv = sys.argv[:1]
    unittest.main()
