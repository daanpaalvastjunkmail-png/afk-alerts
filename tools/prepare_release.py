"""Prepare the two public archives and checksums from this exact source tree.

This tool never uploads anything. The manual release workflow runs tests first,
then uses these allowlisted artifacts and its own GitHub token to publish.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load_tool(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def prepare(root=ROOT, output=None):
    root = Path(root)
    release = load_tool('plugin_release', root / 'tools/build_release.py')
    # Validate the manifest before using its version in any output paths.
    release.release_files(root)
    version = json.loads((root / 'plugin.json').read_text())['version']
    output = Path(output) if output else root / 'dist'
    output.mkdir(parents=True, exist_ok=True)
    plugin, _, _ = release.build(root, output / f'afk_alerts_{version}.zip')
    source = load_tool('source_release', root / 'tools/build_source.py')
    archive, _, _ = source.build(root, output / f'afk_alerts_source_{version}.zip')
    checksums = output / 'SHA256SUMS.txt'
    checksums.write_text(''.join(
        f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n'
        for path in (plugin, archive)), encoding='utf-8')
    return version, (plugin, archive, checksums)


def write_github_outputs(path, version):
    # The numeric manifest version has already passed the release builder checks.
    with Path(path).open('a', encoding='utf-8') as stream:
        stream.write(f'version={version}\ntag=v{version}\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--github-output', action='store_true')
    args = parser.parse_args()
    if args.github_output and not os.environ.get('GITHUB_OUTPUT'):
        parser.error('--github-output requires GITHUB_OUTPUT from GitHub Actions')
    version, files = prepare(output=args.output_dir)
    if args.github_output:
        write_github_outputs(os.environ['GITHUB_OUTPUT'], version)
    print(f'Prepared public release v{version}:')
    for path in files:
        print(path)
