"""Run release checks, then build the clean public ZIP. Requires Lua and Python 3."""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def run(args):
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        print(result.stdout + result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audio-tools', action='store_true',
                        help='Also test the optional MP3 helper; requires system FFmpeg and ffprobe')
    parser.add_argument('--audio-assets', action='store_true',
                        help='Decode/verify the shipped basic sound assets; requires FFmpeg and ffprobe')
    args = parser.parse_args()
    lua = sorted((ROOT / 'tests').glob('*.lua'))
    for path in lua:
        run(['lua', str(path.relative_to(ROOT))])
    for path in sorted(ROOT.rglob('*.lua')):
        run(['luac', '-p', str(path)])
    for name in ('analyze_recording.py', 'release_packaging.py', 'source_packaging.py', 'prepare_release.py'):
        run([sys.executable, '-B', 'tests/' + name])
    if args.audio_assets:
        run([sys.executable, '-B', 'tests/basic_audio.py'])
    if args.audio_tools:
        run([sys.executable, '-B', 'tests/import_mp3.py'])
    spec = importlib.util.spec_from_file_location('release_builder', ROOT / 'tools/build_release.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    output, digest, count = module.build()
    print(f"Passed: {len(lua)} Lua scripts, all Lua syntax, analyzer, public/source-package checks{', audio assets' if args.audio_assets else ''}{', MP3 helper' if args.audio_tools else ''}.")
    print(f'Public ZIP: {output} ({count} files)\nSHA256: {digest}')
    print('Native installation, permissions, audio and platform acceptance remain manual checks.')


if __name__ == '__main__':
    main()
