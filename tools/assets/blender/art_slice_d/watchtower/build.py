"""Rebuild the six-asset source set, including this tower; preserves prior rounds.
All implementation and source dependencies are documented in ../model-spec.md.
"""
from pathlib import Path
import runpy,sys
p=Path(__file__).resolve().parent.parent/'build.py'
sys.argv=[str(p),'--','--build','--finalize']
runpy.run_path(str(p),run_name='__main__')
