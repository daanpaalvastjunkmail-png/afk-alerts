"""Exercise actual MP3 conversion in an isolated temporary plugin."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from unittest.mock import patch

root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('importer', root / 'tools/import_mp3.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as temp:
    base = Path(temp)
    plugin = base / 'plugin'
    mirror = base / 'mirror'
    plugin.mkdir()
    mirror.mkdir()
    (plugin / 'plugin.json').write_text('{}')
    mp3 = base / 'My bell $(echo nope) "é".MP3'
    # Generate the fixture locally; public source needs no MP3s or converter binaries.
    assert shutil.which('ffmpeg') and shutil.which('ffprobe'), 'Importer tests need system FFmpeg/ffprobe'
    subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
                    'sine=frequency=660:duration=0.2', '-y', str(mp3)], check=True)
    module.import_sound(mp3, plugin, mirror)
    # Preserve coverage of an existing private bundle without shipping it.
    bundled = Path(module.__file__).parent / 'bin/linux-x86_64/rs3-audio-converter'
    if bundled.is_file():
        with patch.object(module.shutil, 'which', return_value=None):
            assert module.resolve_converter()[0] == 'bundled'
    entries = json.loads((plugin / 'tools/custom_sounds.json').read_text())
    assert len(entries) == 1 and 'My bell' in entries[0]['label']
    assert (mirror / 'src/custom_sounds.lua').read_bytes() == (plugin / 'src/custom_sounds.lua').read_bytes()
    sound = next((plugin / 'resources/sounds').glob('*.ogg'))
    subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries',
                    'stream=codec_name', '-of', 'default=noprint_wrappers=1', str(sound)], check=True)
    subprocess.run(['luac', '-p', str(plugin / 'src/custom_sounds.lua')], check=True)
    module.import_sound(mp3, plugin, mirror)
    assert len(json.loads((plugin / 'tools/custom_sounds.json').read_text())) == 1
    before = (plugin / 'src/custom_sounds.lua').read_bytes()
    invalid = base / 'bad.mp3'
    invalid.write_text('invalid audio')
    try:
        module.import_sound(invalid, plugin, mirror)
        raise AssertionError('Invalid audio must fail')
    except RuntimeError:
        pass
    assert (plugin / 'src/custom_sounds.lua').read_bytes() == before
    samples = base / 'RS3 Alerts Samples'
    samples.mkdir()
    shutil.copy(mp3, samples / 'First bell.mp3')
    shutil.copy(mp3, samples / 'Second bell.MP3')
    (samples / 'Broken.mp3').write_text('not an mp3')
    (samples / 'Ignored.txt').write_text('ignore this')
    imported, skipped, errors = module.scan_samples(plugin, mirror)
    assert len(imported) == 2 and not skipped and len(errors) == 1
    imported, skipped, errors = module.scan_samples(plugin, mirror)
    assert not imported and len(skipped) == 2 and len(errors) == 1
    assert len(json.loads((plugin / 'tools/custom_sounds.json').read_text())) == 3
    assert mp3.is_file() and (samples / 'First bell.mp3').is_file()
    # A missing live audio resource must be restored rather than skipped.
    stem = module.sound_stem(samples / 'First bell.mp3')
    (mirror / 'resources/sounds' / (stem + '.ogg')).unlink()
    imported, skipped, errors = module.scan_samples(plugin, mirror)
    assert len(imported) == 1 and len(skipped) == 1
    assert (mirror / 'resources/sounds' / (stem + '.ogg')).is_file()
print('MP3 importer passed: conversion, special filenames, folder scan, unchanged-file skipping, partial failures, resource repair and mirroring')
