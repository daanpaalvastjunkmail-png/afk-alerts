"""Build a clean, reproducible source archive for public review and contributions.

Reuse the installable package's explicit resource allowlist and empty custom
catalogue. Add only project documentation, test scripts and editable tools;
never traverse the private converter/audio directories into the archive.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DOCS = ('.gitignore', 'CHANGELOG.md', 'CONTRIBUTING.md', 'PUBLISHING.md',
               'MODIO_DESCRIPTION.txt', 'MODIO_SUMMARY.txt', 'media/listing.svg', 'media/listing.png')
SOURCE_TOOLS = ('analyze_recording.py', 'build_effect_catalog.py', 'build_release.py',
                'build_source.py', 'check_release.py', 'generate_builtin_sounds.py',
                'import_mp3.py')
GITHUB_FILES = ('.github/workflows/check.yml', '.github/ISSUE_TEMPLATE/bug_report.md')


def source_files(root=ROOT):
    root = Path(root)
    spec = importlib.util.spec_from_file_location('public_release', root / 'tools/build_release.py')
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    files = builder.release_files(root)
    for name in (*SOURCE_DOCS, *GITHUB_FILES, *(f'tools/{name}' for name in SOURCE_TOOLS)):
        files[name] = (root / name).read_bytes()
    for path in sorted((root / 'tests').iterdir()):
        if path.is_file() and path.suffix in ('.lua', '.py'):
            files[path.relative_to(root).as_posix()] = path.read_bytes()
    return files


def build(root=ROOT, output=None):
    root = Path(root)
    version = json.loads((root / 'plugin.json').read_text())['version']
    output = Path(output) if output else root.parent / f'afk_alerts_source_{version}.zip'
    spec = importlib.util.spec_from_file_location('public_release', root / 'tools/build_release.py')
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    return builder.write_archive(source_files(root), output, prefix='afk-alerts/')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output, digest, count = build(output=args.output)
    print(f'{output}\n{count} source files\nSHA256 {digest}')
