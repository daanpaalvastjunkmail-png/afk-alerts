"""Public package is complete/repeatable and cannot leak private audio/tools."""
import importlib.util
from pathlib import Path
import tempfile
import zipfile

root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('builder', root / 'tools/build_release.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
private_before = (root / 'src/custom_sounds.lua').read_bytes()
with tempfile.TemporaryDirectory() as temp:
    a, digest, count = builder.build(root, Path(temp) / 'a.zip')
    b, digest2, count2 = builder.build(root, Path(temp) / 'b.zip')
    assert digest == digest2 and a.read_bytes() == b.read_bytes() and count == count2
    with zipfile.ZipFile(a) as bundle:
        names = set(bundle.namelist())
        assert {'plugin.json', 'main.lua', 'src/aspects.lua', 'PRIVACY.md', 'LICENSE'} <= names
        assert bundle.read('src/custom_sounds.lua').endswith(b'return {}\n')
        assert not any('custom_' in n and n != 'src/custom_sounds.lua' for n in names)
        assert not any(n.startswith(('tools/', 'tests/', 'sounds/')) for n in names)
        assert not any(n.endswith(('.mp3', '.so', '.pyc')) or '.so.' in n for n in names)
        assert len([n for n in names if n.endswith('.ogg')]) == len(builder.SOUNDS) * 2
        for n in names:
            if n != 'src/custom_sounds.lua':
                assert bundle.read(n) == (root / n).read_bytes(), n
        clean = Path(temp) / 'clean'
        bundle.extractall(clean)
        # Syntax and static module/resource closure from the actual extracted ZIP.
        import subprocess
        for path in clean.rglob('*.lua'):
            subprocess.run(['luac', '-p', str(path)], check=True)
assert (root / 'src/custom_sounds.lua').read_bytes() == private_before
print('Release packaging passed: repeatable ZIP, module/resource closure, extracted Lua syntax, private-audio/tool exclusion and source preservation')
