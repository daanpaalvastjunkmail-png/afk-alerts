"""Decode shipped OGGs and verify waveform identity, levels and resource pairs."""
import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
assert shutil.which('ffmpeg') and shutil.which('ffprobe'), 'Audio asset checks require FFmpeg and ffprobe'
names = ('health', 'basic_saw', 'basic_square', 'basic_alarm',
         'basic_ring', 'basic_beep', 'basic_chime', 'basic_siren', 'basic_double_alarm', 'basic_urgent_pulse')
signals = {}
digests = set()
for name in names:
    path = root / 'resources/sounds' / (name + '.ogg')
    payload = path.read_bytes()
    assert payload == (root / 'resources' / ('alert_' + name + '.ogg')).read_bytes()
    assert payload.startswith(b'OggS')
    digests.add(hashlib.sha256(payload).hexdigest())
    probe = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(path)],
                           capture_output=True, check=True)
    stream = json.loads(probe.stdout)['streams'][0]
    assert stream['codec_name'] == 'vorbis' and stream['channels'] == 1
    assert int(stream['sample_rate']) == 44100
    decoded = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le',
                              '-acodec', 'pcm_f32le', '-ac', '1', '-ar', '44100', '-'],
                             capture_output=True, check=True)
    signal = array.array('f'); signal.frombytes(decoded.stdout)
    assert 0.45 <= len(signal) / 44100 <= 1.45
    assert all(math.isfinite(value) for value in signal)
    peak = max(abs(value) for value in signal)
    rms = math.sqrt(sum(value * value for value in signal) / len(signal))
    assert 0.05 < rms < 0.65 and peak < 0.99, (name, peak, rms)
    if name != 'health':
        assert max(abs(value) for value in signal[-32:]) < 0.04, 'Release envelope must end smoothly'
    signals[name] = signal
assert len(digests) == 10, 'Ten distinct audible choices'


def amplitude(signal, frequency):
    # A steady central segment contains an integer number of 165 Hz periods.
    segment = signal[4410:22050]
    real = sum(value * math.cos(2 * math.pi * frequency * index / 44100)
               for index, value in enumerate(segment))
    imag = sum(value * math.sin(2 * math.pi * frequency * index / 44100)
               for index, value in enumerate(segment))
    return 2 * math.hypot(real, imag) / len(segment)


for name in ('basic_saw', 'basic_square'):
    signal = signals[name]
    fundamental = amplitude(signal, 165)
    assert fundamental > 0.15, 'Saw/Square fundamental must be 165 Hz: two octaves below 660 Hz'
    if name == 'basic_square':
        assert amplitude(signal, 330) / fundamental < 0.03, 'Square has no even harmonics'
        assert abs(amplitude(signal, 495) / fundamental - 1 / 3) < 0.035
    else:
        assert abs(amplitude(signal, 330) / fundamental - 0.5) < 0.04
assert not (root / 'resources/sounds/basic_triangle.ogg').exists(), 'Triangle resource removed'
assert not (root / 'resources/alert_basic_triangle.ogg').exists()
print('Basic audio passed: ten distinct Vorbis sounds, resource pairs, levels/fades and 165 Hz saw/square harmonics')
