"""Build a repeatable, allowlisted public ZIP; never bundle personal audio/tools."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SOUNDS = ('health', 'adrenaline', 'prayer', 'summoning', 'skill', 'familiar',
          'overload', 'antifire', 'aggression', 'buff', 'drop',
          'basic_saw', 'basic_square', 'basic_alarm',
          'basic_ring', 'basic_beep', 'basic_chime',
          'basic_siren', 'basic_double_alarm', 'basic_urgent_pulse')
DOCS = ('LICENSE', 'README.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'PUBLISHING.md', 'PRESETS.md', 'SOUND_GUIDE.md', 'EFFECT_COVERAGE.md',
        'BUFF_DURATIONS.md', 'GREGOROVIC.md', 'PRIVACY.md', 'THIRD_PARTY_NOTICES.md',
        'RELEASE_CHECKLIST.md', 'MODIO_RELEASE_NOTES.txt')


def release_files(root):
    root = Path(root)
    manifest = json.loads((root / 'plugin.json').read_text())
    assert manifest['name'] == 'AFK ALERTS'
    assert re.fullmatch(r'\d+\.\d+\.\d+', manifest['version'])
    runtime_version = re.search(r'version\s*=\s*"([^"]+)"', (root / 'src/core/vars.lua').read_text())
    assert runtime_version and runtime_version[1] == manifest['version'], 'Runtime/manifest version mismatch'
    assert manifest['requiredDependencies'] == {'prettyui': 6398181}
    assert set(manifest['optionalPermissions']) == {'httpAccess', 'chatAccess'}
    assert manifest['urls'] == {'ge': 'https://secure.runescape.com'}
    files = {}
    for name in ('main.lua', 'plugin.json', *DOCS):
        files[name] = (root / name).read_bytes()
    for folder, pattern in (('src', '*.lua'), ('presets', '*.txt')):
        for path in sorted((root / folder).rglob(pattern)):
            files[path.relative_to(root).as_posix()] = path.read_bytes()
    # The local catalogue is kept intact on disk, but is never published.
    files['src/custom_sounds.lua'] = b'-- Public package: built-in audio only.\nreturn {}\n'
    for name in SOUNDS:
        # Retain both supported resource layouts for client compatibility.
        for relative in (f'resources/alert_{name}.ogg', f'resources/sounds/{name}.ogg'):
            payload = (root / relative).read_bytes()
            assert payload.startswith(b'OggS'), relative
            files[relative] = payload
    for name, payload in files.items():
        if name.endswith('.lua'):
            for module in re.findall(rb'require\s*\(?\s*[\'\"](src/[^\'\"]+)', payload):
                assert module.decode() + '.lua' in files, (name, module)
    return files


def build(root=ROOT, output=None):
    root = Path(root)
    output = Path(output) if output else root.parent / 'afk_alerts_plugin.zip'
    return write_archive(release_files(root), output)


def write_archive(files, output, prefix=''):
    output = Path(output)
    pending = output.with_suffix('.zip.tmp')
    try:
        with zipfile.ZipFile(pending, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
            for name, payload in sorted(files.items()):
                entry = zipfile.ZipInfo(prefix + name, (2020, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                bundle.writestr(entry, payload)
        with zipfile.ZipFile(pending) as bundle:
            assert bundle.testzip() is None
            assert set(bundle.namelist()) == {prefix + name for name in files}
            for name, payload in files.items():
                assert bundle.read(prefix + name) == payload, name
        pending.replace(output)
    finally:
        pending.unlink(missing_ok=True)
    return output, hashlib.sha256(output.read_bytes()).hexdigest(), len(files)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output, digest, count = build(output=args.output)
    print(f'{output}\n{count} allowlisted files\nSHA256 {digest}')
