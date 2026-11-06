"""Build this tower with Blender --background --python build.py.
Shared modeling implementation lives in ../build.py and ../geometry.py.
"""
from pathlib import Path
import importlib.util
p=Path(__file__).resolve().parent.parent/'build.py'
s=importlib.util.spec_from_file_location('bwar_family',p)
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
m.build('barracks')
m.finalize_all('barracks')
