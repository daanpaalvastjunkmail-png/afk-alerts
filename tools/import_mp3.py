#!/usr/bin/env python3
"""Choose an MP3 and install a converted sound in the local AFK ALERTS plugin."""
import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile


def lua_string(value):
    return '"' + ''.join(chr(b) if 32 <= b <= 126 and chr(b) not in '\\"' else f'\\{b:03d}'
                         for b in value.encode('utf-8')) + '"'


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        pending = Path(stream.name)
        stream.write(data)
    try:
        os.replace(pending, path)
    finally:
        pending.unlink(missing_ok=True)


def resolve_converter():
    system = {"Linux": "linux", "Windows": "windows", "Darwin": "macos"}.get(platform.system())
    arch = {"amd64": "x86_64", "x86_64": "x86_64", "arm64": "arm64", "aarch64": "arm64"}.get(platform.machine().lower())
    filename = "rs3-audio-converter.exe" if system == "windows" else "rs3-audio-converter"
    if system and arch:
        bundled = Path(__file__).resolve().parent / "bin" / (system + "-" + arch) / filename
        if bundled.is_file():
            return "bundled", str(bundled)
    # Keep compatibility with existing development installations on other platforms.
    installed = shutil.which("ffmpeg")
    if installed:
        return "ffmpeg", installed
    raise RuntimeError("Install FFmpeg on your system to use the optional MP3 importer; the public source does not bundle converter binaries.")


def sound_stem(source):
    digest = hashlib.sha256(source.read_bytes()).hexdigest()[:12]
    slug = re.sub(r'[^a-z0-9]+', '_', source.stem.lower()).strip('_')[:32] or 'sound'
    return f'custom_{slug}_{digest}'


def rebuild_archive(plugin):
    # Personal audio and converter tools belong only in the development archive.
    output = plugin.parent / 'afk_alerts_development.zip'
    pending = output.with_suffix('.zip.tmp')
    try:
        with zipfile.ZipFile(pending, 'w', zipfile.ZIP_DEFLATED, strict_timestamps=False) as bundle:
            for path in sorted(plugin.rglob('*')):
                if path.is_file() and '__pycache__' not in path.parts and 'samples' not in path.relative_to(plugin).parts:
                    bundle.write(path, path.relative_to(plugin))
        os.replace(pending, output)
    finally:
        pending.unlink(missing_ok=True)


def scan_samples(plugin, mirror=None):
    folder = plugin.parent / 'RS3 Alerts Samples'
    folder.mkdir(parents=True, exist_ok=True)
    registry = plugin / 'tools/custom_sounds.json'
    entries = json.loads(registry.read_text()) if registry.exists() else []
    known = {entry['id'] for entry in entries}
    imported, skipped, errors = [], [], []
    for source in sorted(folder.iterdir()):
        if not source.is_file() or source.suffix.lower() != '.mp3':
            continue
        try:
            stem = sound_stem(source)
            roots = [plugin] + ([mirror] if mirror and mirror.is_dir() else [])
            ready = all((root / 'resources/sounds' / (stem + '.ogg')).is_file() and
                        (root / 'resources' / ('alert_' + stem + '.ogg')).is_file() for root in roots)
            if stem + '.mp3' in known and ready:
                skipped.append(source.name)
                continue
            imported.append(import_sound(source, plugin, mirror, archive=False))
            known.add(stem + '.mp3')
        except (OSError, ValueError, RuntimeError, KeyError) as error:
            errors.append(source.name + ': ' + str(error))
    if imported:
        rebuild_archive(plugin)
    return imported, skipped, errors


def import_sound(source, plugin, mirror=None, archive=True):
    source = source.expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != '.mp3':
        raise ValueError('Choose an existing MP3 file.')
    if not (plugin / 'plugin.json').is_file():
        raise ValueError('AFK ALERTS plugin folder was not found.')
    backend, converter = resolve_converter()
    stem = sound_stem(source)
    # Decode first; invalid input never changes the existing plugin or catalogue.
    with tempfile.TemporaryDirectory(prefix='rs3-alert-audio-') as temp:
        converted = Path(temp) / 'sound.ogg'
        if backend == "bundled":
            command = [converter, str(source), str(converted)]
        else:
            command = [converter, '-nostdin', '-hide_banner', '-loglevel', 'error',
                       '-i', str(source), '-map', '0:a:0', '-vn', '-c:a', 'libvorbis',
                       '-q:a', '5', str(converted)]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError('The MP3 could not be converted: ' + result.stderr[-1500:])
        audio_bytes = converted.read_bytes()
    registry_path = plugin / 'tools' / 'custom_sounds.json'
    entries = json.loads(registry_path.read_text()) if registry_path.exists() else []
    sound_id = stem + '.mp3'
    if not any(entry['id'] == sound_id for entry in entries):
        entries.append({'id': sound_id, 'label': source.name + ' (custom)'})
    entries.sort(key=lambda entry: entry['label'].lower())
    catalogue = '-- Generated by the desktop MP3 importer.\nreturn {\n' + ''.join(
        ' {id=' + lua_string(entry['id']) + ',label=' + lua_string(entry['label']) + '},\n'
        for entry in entries) + '}\n'
    files = {
        Path('resources/sounds') / (stem + '.ogg'): audio_bytes,
        Path('resources') / ('alert_' + stem + '.ogg'): audio_bytes,
        Path('src/custom_sounds.lua'): catalogue.encode(),
        Path('tools/custom_sounds.json'): json.dumps(entries, indent=2).encode() + b'\n',
    }
    for root in [plugin] + ([mirror] if mirror and mirror.is_dir() and mirror.resolve() != plugin.resolve() else []):
        for relative, data in files.items():
            atomic_write(root / relative, data)
    if archive:
        rebuild_archive(plugin)
    return source.name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mp3', nargs='?', type=Path)
    parser.add_argument('--plugin-dir', type=Path, default=Path(__file__).resolve().parent.parent)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--samples', action='store_true', help='Open the samples folder and offer to import its MP3s')
    modes.add_argument('--scan', action='store_true', help='Import new MP3s from the samples folder')
    args = parser.parse_args()
    interactive = args.mp3 is None
    plugin = args.plugin_dir.resolve()
    mirror = plugin.parent / 'rs3_plugin_test' / 'rs3_alerts_plugin'
    try:
        if args.samples or args.scan:
            folder = plugin.parent / 'RS3 Alerts Samples'
            folder.mkdir(parents=True, exist_ok=True)
            if args.samples:
                subprocess.run(['xdg-open', str(folder)], check=True)
                answer = subprocess.run(['kdialog', '--title', 'AFK ALERTS - Samples',
                    '--yes-label', 'Import sounds', '--no-label', 'Cancel', '--yesno',
                    'Copy your MP3 files into the folder that just opened.\n\n'
                    'When you are done, click Import sounds. Existing sounds and alert settings are preserved.'])
                if answer.returncode:
                    return 0
            imported, skipped, errors = scan_samples(plugin, mirror)
            message = f'Imported: {len(imported)} · Already available: {len(skipped)}'
            if imported:
                message += ('\n\nIn the game console, run separately:\npoff rs3_alerts_plugin\n'
                            'prf\npon rs3_alerts_plugin\n\nThen reopen your alert Sound page and select the sound.')
            elif not skipped and not errors:
                message += '\n\nNo MP3 files found. Copy MP3s directly into:\n' + str(folder)
            if errors:
                message += '\n\nFiles that could not be imported:\n' + '\n'.join(errors)
            print(message)
            subprocess.run(['kdialog', '--title', 'AFK ALERTS - Samples', '--msgbox', message], check=False)
            return 1 if errors else 0
        if interactive:
            dialog = subprocess.run(['kdialog', '--title', 'AFK ALERTS - Import MP3',
                                     '--getopenfilename', str(Path.home() / 'Downloads'),
                                     'Audio files (*.mp3 *.MP3)'], capture_output=True, text=True)
            if dialog.returncode or not dialog.stdout.strip():
                return 0
            args.mp3 = Path(dialog.stdout.strip())
        plugin = args.plugin_dir.resolve()
        mirror = plugin.parent / 'rs3_plugin_test' / 'rs3_alerts_plugin'
        name = import_sound(args.mp3, plugin, mirror)
        message = (f'Imported: {name}\n\nIn the RuneScape console, run these separately:\n'
                   'poff rs3_alerts_plugin\nprf\npon rs3_alerts_plugin\n\n'
                   'Open the AFK ALERTS cog, choose your alert, then Sound.\n'
                   'Select your imported sound and click Sound only to test it.')
        print(message)
        if interactive:
            subprocess.run(['kdialog', '--title', 'AFK ALERTS', '--msgbox', message], check=False)
        return 0
    except (OSError, ValueError, RuntimeError, KeyError) as error:
        message = 'Import failed: ' + str(error)
        print(message, file=sys.stderr)
        if interactive:
            subprocess.run(['kdialog', '--title', 'AFK ALERTS', '--error', message], check=False)
        return 1


if __name__ == '__main__':
    sys.exit(main())
