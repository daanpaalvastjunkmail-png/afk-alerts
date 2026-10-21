"""Published files are the exact allowlisted source/plugin with matching hashes."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import zipfile

root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('prepare_release', root / 'tools/prepare_release.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)
version = json.loads((root / 'plugin.json').read_text())['version']
with tempfile.TemporaryDirectory() as temp:
    folder = Path(temp)
    actual, files = tool.prepare(root, folder / 'dist')
    assert actual == version
    plugin, source, checksums = files
    assert plugin.name == f'afk_alerts_{version}.zip'
    assert source.name == f'afk_alerts_source_{version}.zip'
    for line, path in zip(checksums.read_text().splitlines(), (plugin, source), strict=True):
        digest, name = line.split('  ')
        assert name == path.name and digest == hashlib.sha256(path.read_bytes()).hexdigest()
    with zipfile.ZipFile(plugin) as bundle:
        assert bundle.testzip() is None
        assert json.loads(bundle.read('plugin.json'))['version'] == version
        assert b'AI (OpenAI Codex)' in bundle.read('AI_DISCLOSURE.md')
        assert bundle.read('src/custom_sounds.lua').endswith(b'return {}\n')
    with zipfile.ZipFile(source) as bundle:
        assert bundle.testzip() is None
        assert json.loads(bundle.read('afk-alerts/plugin.json'))['version'] == version
        assert bundle.read('afk-alerts/.github/workflows/release.yml') == (root / '.github/workflows/release.yml').read_bytes()
        assert bundle.read('afk-alerts/GITHUB_RELEASE.md') == (root / 'GITHUB_RELEASE.md').read_bytes()
    outputs = folder / 'outputs.txt'
    tool.write_github_outputs(outputs, version)
    assert outputs.read_text() == f'version={version}\ntag=v{version}\n'
print('Release preparation passed: source/plugin archives, AI disclosure, manifest versions, checksums and workflow outputs')
