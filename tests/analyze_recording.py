"""Validate legacy/new recording formats and reject incomplete exports."""
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('analyzer', root / 'tools/analyze_recording.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
rows = ['RS3DIAG/1', 'START,10', 'D,1,P,-16464,BONFIRE_HEALTH_BOOST', 'V,10,1,0',
        'V,12,1,495', 'M,13,1', 'GAP,14', 'STOP,20,manual']
a = module.parse_recording('\n'.join(rows))
b = module.parse_recording('RS3DIAG/2;' + ';'.join(rows[1:]))
paged='RS3DIAG/2;' + ';'.join(rows[1:])
paged=paged[:45]+'\n'+paged[45:75]+'\r\n'+paged[75:]
assert module.parse_recording(paged)==b, 'Newlines between copied pages must be accepted even inside a row'
assert a == b and a['changes'] == 2 and a['variables'][0]['maximum'] == 495
assert a['variables'][0]['missing_at'] == [13] and a['logout_gaps'] == [14]
for invalid in ['RS3DIAG/1', 'RS3DIAG/2', 'RS3DIAG/2;START,1',
                'RS3DIAG/2;START,1;V,2,1,99;STOP,3,manual',
                'RS3DIAG/2;START,1;D,1,P,0,LIFEPOINTS;V,2,1,nan;STOP,3,manual',
                'RS3DIAG/2;START,1;D,1,P,0,LIFEPOINTS;V,4,1,1;STOP,3,manual']:
    try:
        module.parse_recording(invalid)
    except ValueError:
        pass
    else:
        raise AssertionError('Invalid recording accepted: ' + invalid)
print('Recording analyzer passed: legacy/new equivalence, boost changes, gaps and malformed/truncated input')
