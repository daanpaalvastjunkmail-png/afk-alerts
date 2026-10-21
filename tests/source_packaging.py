"""Public source rebuilds itself without private sounds, binaries or local files."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('source_builder', root / 'tools/build_source.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
private_before = (root / 'src/custom_sounds.lua').read_bytes()
with tempfile.TemporaryDirectory() as temp:
    folder = Path(temp)
    first, digest, count = builder.build(root, folder / 'first.zip')
    second, digest2, count2 = builder.build(root, folder / 'second.zip')
    assert digest == digest2 and count == count2 and first.read_bytes() == second.read_bytes()
    with zipfile.ZipFile(first) as bundle:
        assert bundle.testzip() is None
        names = {name.removeprefix('afk-alerts/') for name in bundle.namelist()}
        assert {'LICENSE', 'AI_DISCLOSURE.md', 'GITHUB_RELEASE.md', 'MODIO_SETUP.md', 'CONTRIBUTING.md', 'PUBLISHING.md', 'tests/ui.lua',
                'tools/check_release.py', 'tools/build_source.py', 'tools/prepare_release.py', '.github/workflows/release.yml', '.github/workflows/check.yml', 'media/listing.svg', 'media/listing.png'} <= names
        assert bundle.read('afk-alerts/src/custom_sounds.lua').endswith(b'return {}\n')
        assert not any(name.startswith(('tools/bin/', 'sounds/')) or name.endswith(('.mp3', '.zip', '.so', '.pyc')) or '.so.' in name for name in names)
        assert not any('custom_' in name and name != 'src/custom_sounds.lua' for name in names)
        bundle.extractall(folder / 'extracted')
    clean = folder / 'extracted/afk-alerts'
    spec = importlib.util.spec_from_file_location('clean_source_builder', clean / 'tools/build_source.py')
    clean_builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(clean_builder)
    rebuilt, rebuilt_digest, _ = clean_builder.build(clean, folder / 'rebuilt.zip')
    assert rebuilt_digest == digest and rebuilt.read_bytes() == first.read_bytes(), 'Clean source must reproduce itself'
    # A consumer can run every Lua regression with an empty personal catalogue.
    for path in sorted((clean / 'tests').glob('*.lua')):
        subprocess.run(['lua', str(path.relative_to(clean))], cwd=clean,
                       capture_output=True, text=True, check=True)
assert (root / 'src/custom_sounds.lua').read_bytes() == private_before
print('Source packaging passed: clean source closure, repeatability, rebuilt archive, all Lua tests and private-data exclusion')
