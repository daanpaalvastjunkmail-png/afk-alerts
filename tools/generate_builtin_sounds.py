"""Generate original, band-limited basic alert sounds using Python and FFmpeg.

The existing health.ogg is retained as Sine. Only the named basic_ assets
are written; imported audio and legacy tones are never modified.
"""
import argparse
import array
import math
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
RATE = 44100
NAMES = ('saw', 'square', 'alarm', 'ring', 'beep', 'chime', 'siren', 'double_alarm', 'urgent_pulse')


def oscillator(kind, frequency, t):
    phase = 2 * math.pi * frequency * t
    if kind == 'sine':
        return math.sin(phase)
    harmonics = range(1, int(12000 / frequency) + 1)
    if kind == 'saw':
        return sum((-1) ** (n + 1) * math.sin(n * phase) / n for n in harmonics)
    if kind == 'square':
        return sum(math.sin(n * phase) / n for n in harmonics if n % 2)
    raise ValueError('Unknown oscillator: ' + kind)


def envelope(t, duration):
    return max(0, min(1, t / 0.012, (duration - t) / 0.035))


def samples(name):
    duration = {'alarm': 0.96, 'ring': 0.86, 'beep': 0.50, 'chime': 1.10, 'siren': 1.28, 'double_alarm': 1.10, 'urgent_pulse': 0.90}.get(name, 0.68)
    values = []
    for index in range(round(duration * RATE)):
        t = index / RATE
        if name in ('saw', 'square'):
            value = oscillator(name, 165, t) * envelope(t, duration)
        elif name == 'alarm':
            step = int(t / 0.16)
            local = t - step * 0.16
            value = oscillator('sine', 880 if step % 2 == 0 else 660, local) * envelope(local, 0.16)
        elif name == 'siren':
            # Continuous phase while sweeping 500-1250 Hz twice.
            phase = 2 * math.pi * (875 * t - 375 * 0.64 / (2 * math.pi) * math.sin(2 * math.pi * t / 0.64))
            value = (math.sin(phase) + 0.15 * math.sin(3 * phase)) * envelope(t, duration)
        elif name == 'double_alarm':
            local = t % 0.60
            start = 0 if local < 0.12 else 0.22
            pulse = local - start
            value = ((math.sin(2 * math.pi * 740 * pulse) + math.sin(2 * math.pi * 1110 * pulse))
                     * envelope(pulse, 0.12)) if 0 <= pulse < 0.12 else 0
        elif name == 'urgent_pulse':
            step = int(t / 0.12)
            pulse = t - step * 0.12
            frequency = 1400 if step % 2 == 0 else 1800
            value = oscillator('sine', frequency, pulse) * envelope(pulse, 0.08) * envelope(t, duration) if pulse < 0.08 else 0
        elif name == 'ring':
            local = t % 0.48
            value = ((math.sin(2 * math.pi * 440 * local) + math.sin(2 * math.pi * 480 * local))
                     * envelope(local, 0.36)) if local < 0.36 else 0
        elif name == 'beep':
            local = t % 0.26
            value = oscillator('sine', 1046.5, local) * envelope(local, 0.16) if local < 0.16 else 0
        else:
            value = 0
            for start, frequency in ((0, 784), (0.16, 988), (0.32, 1174)):
                local = t - start
                if local >= 0:
                    value += math.sin(2 * math.pi * frequency * local) * math.exp(-5 * local) * min(1, local / 0.008)
            value *= min(1, (duration - t) / 0.08)
        values.append(value)
    peak = max(abs(v) for v in values)
    rms = math.sqrt(sum(v * v for v in values) / len(values))
    gain = min(0.80 / peak, 0.45 / rms)
    # Leave guard silence for Vorbis encoder delay and clean playback endings.
    pcm = array.array('f', [0.0]) * round(0.02 * RATE)
    pcm.extend(v * gain for v in values)
    pcm.extend(array.array('f', [0.0]) * round(0.06 * RATE))
    return pcm


def main():
    converter = shutil.which('ffmpeg')
    if not converter:
        raise SystemExit('Install FFmpeg to regenerate the built-in OGG assets.')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='*', choices=NAMES)
    selected = parser.parse_args().names or NAMES
    for name in selected:
        pcm = samples(name)
        result = subprocess.run([
            converter, '-v', 'error', '-f', 'f32le', '-ar', str(RATE), '-ac', '1',
            '-i', 'pipe:0', '-map_metadata', '-1', '-c:a', 'libvorbis', '-q:a', '5',
            '-f', 'ogg', 'pipe:1',
        ], input=pcm.tobytes(), capture_output=True, check=True)
        for relative in (f'resources/sounds/basic_{name}.ogg', f'resources/alert_basic_{name}.ogg'):
            (ROOT / relative).write_bytes(result.stdout)
        print(f'{name}: {len(pcm) / RATE:.2f}s, {len(result.stdout)} bytes')


if __name__ == '__main__':
    main()
