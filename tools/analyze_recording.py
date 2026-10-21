#!/usr/bin/env python3
"""Validate an RS3 diagnostic export and summarize observed numeric changes."""
import argparse
import json
import math
from pathlib import Path


def parse_recording(text):
    text = text.strip().lstrip('\ufeff')
    if len(text) > 48000:
        raise ValueError('Recording exceeds the supported 48 KB limit.')
    if text.startswith('RS3DIAG/2;'):
        # Editors may add a newline between pages, even in the middle of a row.
        text = text.replace('\r', '').replace('\n', '')
        rows = text.split(';')
    elif text.startswith('RS3DIAG/1\n') or text.startswith('RS3DIAG/1\r\n'):
        rows = text.splitlines()
    else:
        raise ValueError('Incomplete or unknown recording: a header alone contains no data.')
    if len(rows) < 3 or not rows[1].startswith('START,') or not rows[-1].startswith('STOP,'):
        raise ValueError('Recording is incomplete: START and STOP records are required.')

    def number(value):
        result = float(value)
        if not math.isfinite(result):
            raise ValueError('Non-finite numeric value in recording.')
        return result

    start = number(rows[1].split(',', 1)[1])
    stop = rows[-1].split(',')
    if len(stop) != 3:
        raise ValueError('Malformed STOP record.')
    ended = number(stop[1])
    if ended < start:
        raise ValueError('Recording ends before it starts.')
    catalog, gaps, changes = {}, [], 0
    last_time = start
    for row in rows[2:-1]:
        parts = row.split(',')
        if parts[0] == 'D' and len(parts) == 5:
            index = int(parts[1])
            if index <= 0 or index in catalog or parts[2] not in ('C', 'P'):
                raise ValueError('Invalid or duplicate dictionary entry.')
            if not parts[4] or any(c not in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789' for c in parts[4]):
                raise ValueError('Invalid variable name.')
            catalog[index] = {'domain': parts[2], 'id': int(parts[3]), 'name': parts[4],
                              'samples': [], 'missing_at': []}
        elif parts[0] in ('V', 'M', 'GAP'):
            expected = {'V': 4, 'M': 3, 'GAP': 2}[parts[0]]
            if len(parts) != expected:
                raise ValueError('Malformed observation record.')
            when = number(parts[1])
            # Observation times are rounded to hundredths; START/STOP retain full precision.
            if when < last_time - .011 or when > ended + .011:
                raise ValueError('Observation timestamps are out of order or outside the recording.')
            last_time = max(last_time, when)
            if parts[0] == 'GAP':
                gaps.append(when)
                continue
            index = int(parts[2])
            if index not in catalog:
                raise ValueError('Observation refers to an unknown variable.')
            if parts[0] == 'V':
                catalog[index]['samples'].append({'time': when, 'value': number(parts[3])})
                changes += 1
            else:
                catalog[index]['missing_at'].append(when)
        else:
            raise ValueError('Unknown or malformed recording record.')
    variables = []
    for entry in catalog.values():
        values = [sample['value'] for sample in entry['samples']]
        entry['minimum'] = min(values) if values else None
        entry['maximum'] = max(values) if values else None
        variables.append(entry)
    return {'started': start, 'ended': ended, 'seconds': ended - start, 'stop_reason': stop[2],
            'changes': changes, 'logout_gaps': gaps, 'variables': variables,
            'note': 'Raw candidate values only. Min/max are observed values, not verified HUD caps.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('recording', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        result = parse_recording(args.recording.read_text(encoding='utf-8'))
    except (OSError, ValueError) as error:
        parser.exit(1, f'Recording could not be read: {error}\n')
    encoded = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.write_text(encoded, encoding='utf-8')
    else:
        print(encoded, end='')


if __name__ == '__main__':
    main()
