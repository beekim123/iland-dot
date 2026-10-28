"""Regenerate runtime atlases from preserved AI source artwork."""
from pathlib import Path
import runpy
from PIL import Image
D=Path(__file__).parent
runpy.run_path(str(D/'normalize_hero.py'))
runpy.run_path(str(D/'build_enemies.py'))
Image.open(D/'sources/arena-ai-original.png').convert('RGB').resize((1280,800),Image.Resampling.LANCZOS).save(D/'arena.png')
