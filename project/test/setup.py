import os
import sys
import unittest

class ModelSim(unittest.TestCase):
    pass

def mock(expected, actual, message):
    def apply(self):
        self.assertEqual(expected, actual, message)
    return apply

def main():
    print('Analyzing Test Results')
    log = sys.argv[1]
    with open(log, 'r', encoding='utf-8') as f:
        i = 0
        for output in f.read().split('\n'):
            if output.startswith('# Test'):
                _, name, expected, actual = map(lambda x: ' '.join(x.split()), output.split('|'))
                test = mock(expected, actual, '%s : Expected %s : Actual %s' % (name, expected, actual))
                test.__name__ = 'test %d: %s' %(i, name)
                setattr (ModelSim, test.__name__, test)
                i += 1
    sys.argv = sys.argv[:1]

if __name__ == '__main__':
    main()
    unittest.main()

