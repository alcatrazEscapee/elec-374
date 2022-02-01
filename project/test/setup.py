from email import message
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

class LazyTest:
    expected: str
    actual: str
    message: str

def mock(expected: str, actual: str, name: str):
    def apply(self):
        self.assertEqual(expected, actual, '%s\nExpected %s\nActual   %s' % (name, expected, actual))
    return apply

def mock_ea(name: str):
    expected, actual = Lazy(), Lazy()
    def load(parts):
        expected.value, actual.value = parts
    def apply(self):
        self.assertEqual(expected.value, actual.value, '%s\nExpected %s\nActual   %s' % (name, expected, actual))
    return load, apply

def mock_xxea(name: str, format):
    line1, line2, expected, actual = Lazy(), Lazy(), Lazy(), Lazy()
    def load(parts):
        line1.value, line2.value, expected.value, actual.value = parts
    def apply(self):
        self.assertEqual(expected.value, actual.value, '%s\nExpected\n%s%s\n%s%s\n%s%s\nActual\n%s%s\n%s%s\n%s%s' % (name,
            format[0], line1,
            format[1], line2,
            format[2], expected,
            format[0], line1,
            format[1], line2,
            format[2], actual
        ))
    return load, apply

def main():
    print('Analyzing Test Results')
    log = sys.argv[1]
    target = '???'
    i = 0
    fpu_tests = collections.defaultdict(list)

    with open(log, 'r', encoding='utf-8') as f:
        lines = f.read().split('\n')
    
    for output in lines:
        if output.startswith('vsim -voptargs=+acc work.'):
            *_, target = output.split('.')
            i = 0
        if output.startswith('# Test'):
            special, name, *parts = map(lambda x: ' '.join(x.split()), output.split('|'))
            if special == '# Test fpu f' or special == '# Test fpu g':
                op = special[-1]
                load, test = mock_ea(name)
                fpu_tests[op].append((parts, load))
            elif special == '# Test fpu +' or special == '# Test fpu -':
                op = special[-1]
                load, test = mock_xxea(name, ('  ', op + ' ', '= '))
                fpu_tests[op].append((parts, load))
            else:
                expected, actual = parts
                test = mock(expected, actual, name)
            
            test.__name__ = 'test %d : %s : %s' % (i, target, name)
            setattr (ModelSim, test.__name__, test)
            i += 1
    
    for op, tests in fpu_tests.items():
        print('Verifying FPU Tests (%s)' % op)
        proc = subprocess.Popen(('out\\fpu.o', op), shell=True, encoding='utf-8', 
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out, err = proc.communicate('\n'.join(['\n'.join(e[0]) for e in tests]))  # Inputs are joined by newline
        if err is not None:
            raise RuntimeError(err)
        for line, e in zip(out.split('\n'), tests):
            e[1](line.split('|'))  # Outputs are split by '|'


if __name__ == '__main__':
    main()
    sys.argv = sys.argv[:1]
    unittest.main()
