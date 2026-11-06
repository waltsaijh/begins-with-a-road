"""Check reproducibility without treating deterministic replays as new trials."""
import json
from pathlib import Path
from analyze import validate

ROOT = Path(__file__).resolve().parents[2]
FIELDS = ('damage', 'killed', 'leaked', 'overkill', 'healing')


def compare(original, replay):
    left = {p.name: validate(p) for p in (ROOT/original).glob('*.jsonl')}
    right = {p.name: validate(p) for p in (ROOT/replay).glob('*.jsonl')}
    assert left.keys() == right.keys() and len(left) == 72
    differences = []
    for name, row in left.items():
        changed = {key: [row[key], right[name][key]] for key in FIELDS
                   if abs(row[key] - right[name][key]) > .0001}
        if changed:
            differences.append({'id': name, 'metrics': changed})
    return {'original': original, 'replay': replay, 'samples': len(left),
            'compared_metrics': FIELDS, 'differences': differences}


def main():
    changed_stream = compare('.godot/phase5/baseline-v2', '.godot/phase5/baseline-reproduced')
    legacy_stream = compare('.godot/phase5/baseline-v2', '.godot/phase5/baseline-legacy-rng')
    assert not legacy_stream['differences'], 'Original RNG replay no longer matches'
    result = {'status': 'Current PASS', 'scope': 'Five encounter aggregates, not byte-identical traces',
              'stream_migration_diagnostic': changed_stream, 'restored_stream_replay': legacy_stream}
    (ROOT/'reports/phase5/replay_audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print('REPLAY_AUDIT: 72/72 match with original RNG; changed stream differs in', len(changed_stream['differences']))


if __name__ == '__main__':
    main()
