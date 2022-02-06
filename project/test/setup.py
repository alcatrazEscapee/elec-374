import sys
import unittest

class ModelSim(unittest.TestCase):
    pass

def mock(expected, actual, message):
    def apply(self):
        self.assertEqual(expected, actual, message)
    return apply

def mock_fail(message):
    def apply(self):
        self.fail(message)
    return apply

def main():
    print('Analyzing Test Results')
    log = sys.argv[1]
    target = '???'
    with open(log, 'r', encoding='utf-8') as f:
        i = 0
        for output in f.read().split('\n'):
            if output.startswith('vsim -voptargs=+acc work.'):
                *_, target = output.split('.')
                i = 0
            if output.startswith('# ** Error:'):
                test = mock_fail('External error in module %s:\n  %s\n  check out/vsim.log for more info' % (target, output))
                test.__name__ = 'test %07d : %s compile' % (i, target)
                setattr (ModelSim, test.__name__, test)
                i += 1
            if output.startswith('# Test'):
                _, name, expected, actual = map(lambda x: ' '.join(x.split()), output.split('|'))
                test = mock(expected, actual, '%s : Expected %s : Actual %s' % (name, expected, actual))
                test.__name__ = 'test %07d : %s : %s' % (i, target, name)
                setattr (ModelSim, test.__name__, test)
                i += 1
    sys.argv = sys.argv[:1]

if __name__ == '__main__':
    main()
    unittest.main()

