import sys
import unittest
import subprocess
import collections

class Lazy:
    value: str

class ModelSim(unittest.TestCase):
    pass

def mock(expected: str, actual: str, name: str):
    def apply(self):
        self.assertEqual(expected, actual, '%s\nExpected %s\nActual   %s' % (name, expected, actual))
    return apply

def mock_lazy(expected: Lazy, actual: Lazy, name: str):
    def apply(self):
        self.assertEqual(expected.value, actual.value, '%s\nExpected %s\nActual   %s' % (name, expected.value, actual.value))
    return apply

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
            special, name, expected, actual = map(lambda x: ' '.join(x.split()), output.split('|'))
            if special == '# Test fpu f' or special == '# Test fpu g':
                op = special[-1]
                z1, z2 = Lazy(), Lazy()
                fpu_tests[op].append((expected, z1))
                fpu_tests[op].append((actual, z2))
                test = mock_lazy(z1, z2, name)
            else:
                test = mock(expected, actual, name)
            
            test.__name__ = 'test %d : %s : %s' % (i, target, name)
            setattr (ModelSim, test.__name__, test)
            i += 1
    
    for op, tests in fpu_tests.items():
        print('Verifying FPU Tests (%s)' % op)
        proc = subprocess.Popen(('out\\fpu.o', op), shell=True, encoding='utf-8', 
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out, err = proc.communicate('\n'.join([e[0] for e in tests]))
        if err is not None:
            raise RuntimeError(err)
        for line, e in zip(out.split('\n'), tests):
            e[1].value = line


if __name__ == '__main__':
    main()
    sys.argv = sys.argv[:1]
    unittest.main()
