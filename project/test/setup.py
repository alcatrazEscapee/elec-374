import os
import sys
import subprocess

def vsim(cls):
    cmd = 'vsim < test/%s.do' % cls.__name__
    print('Running %s' % cmd)
    proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    while proc.poll() is None:
        output = proc.stdout.readline().decode('utf-8').replace('\r', '').replace('\n', '')
        print(output)
        if output.startswith('# Test'):
            _, name, expected, actual = map(lambda x: ' '.join(x.split()), output.split('|'))
            test = mock(expected, actual)
            test.__name__ = 'test_' + name
            setattr (cls, test.__name__, test)
    proc.wait()

def mock(expected, actual):
    def apply(self):
        self.assertEqual(expected, actual)
    return apply

def main():
    if len(sys.argv) == 3 and sys.argv[1] == 'generate':
        module = sys.argv[2]
        if not os.path.isfile('%s.v' % module):
            print('No Verilog module: %s.v' % module)
            return
        print('Generating template test for module %s' % module)
        with open('test/%s.do' % module, 'w', encoding='utf-8') as f:
            f.write(TEST_DO_TEMPLATE.format(module=module))
        with open('test/%s.py' % module, 'w', encoding='utf-8') as f:
            f.write(TEST_PY_TEMPLATE.format(module=module))
        print('Done')
    else:
        print('Usage: setup.py generate <module>')

TEST_DO_TEMPLATE = """
vlog +acc "{module}.v"
vsim -voptargs=+acc work.{module}_test
run 100ns
"""

TEST_PY_TEMPLATE = """
import setup
import unittest

class {module}(unittest.TestCase):
    pass

setup.vsim({module})
"""


if __name__ == '__main__':
    main()

