
from distutils.core import setup
from git import Repo

repo = Repo()

# Get version before adding version file
ver = repo.git.describe('--tags')

# append version constant to package init
with open('python/l2si_core/__init__.py','a') as vf:
    vf.write(f'\n__version__="{ver}"\n')

setup (
   name='l2si_core',
   version=ver,
   packages=['l2si_core', ],
   package_dir={'':'python'},
)

