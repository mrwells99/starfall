"""Analyze raw native frame captures without hiding long frames in an FPS average.
Usage: python tools/analyze_frame_capture.py artifacts/frame-capture/forward-baseline
"""
import bisect
import collections
import csv
import json
import pathlib
import statistics
import sys


def quantile(values, fraction):
    values = sorted(values)
    index = (len(values) - 1) * fraction
    left = int(index)
    return values[left] + (values[min(left + 1, len(values) - 1)] - values[left]) * (index - left)


def describe(rows):
    if not rows:
        return {}
    ms = [r['wall_us'] / 1000 for r in rows]
    return dict(frames=len(rows), seconds=sum(ms) / 1000, median_ms=statistics.median(ms),
                mean_ms=statistics.mean(ms), p95_ms=quantile(ms, .95), p99_ms=quantile(ms, .99),
                max_ms=max(ms), over_33_ms=sum(t > 33.333 for t in ms), over_50_ms=sum(t > 50 for t in ms),
                over_100_ms=sum(t > 100 for t in ms), over_250_ms=sum(t > 250 for t in ms),
                over_1000_ms=sum(t > 1000 for t in ms),
                max_physics_cpu_ms=max(r['physics_cpu_us'] for r in rows) / 1000,
                max_visual_cpu_ms=max(r['visual_cpu_us'] for r in rows) / 1000,
                median_gpu_ms=statistics.median(r['gpu_ms'] for r in rows),
                max_gpu_ms=max(r['gpu_ms'] for r in rows),
                max_render_setup_ms=max(r['render_setup_ms'] for r in rows),
                unfocused_frames=sum(not r['focused'] for r in rows))


def analyze(directory):
    with (directory / 'frames.csv').open(encoding='utf-8') as stream:
        frames = [{k: float(v) for k, v in row.items()} for row in csv.DictReader(stream)]
    events = json.loads((directory / 'events.json').read_text(encoding='utf-8'))
    metadata = json.loads((directory / 'metadata.json').read_text(encoding='utf-8'))
    ends = [r['end_us'] for r in frames]
    for event in events:
        event['duration_ms'] = (event['end_us'] - event['start_us']) / 1000
        index = bisect.bisect_left(ends, event['end_us'])
        matching = [r for r in frames[index:index+3] if r['round'] == event['round'] and not r['round_boundary']]
        event['next_3_frame_max_ms'] = max((r['wall_us'] / 1000 for r in matching), default=0)
    hitches = []
    pipeline_keys = ['pipeline_canvas', 'pipeline_mesh', 'pipeline_surface', 'pipeline_draw', 'pipeline_specialization']
    previous = None
    for row in frames:
        row['pipeline_delta'] = {key: row[key] - previous[key] if previous else 0 for key in pipeline_keys}
        previous = row
        if row['wall_us'] <= 50000 or row['round'] not in [1, 2] or row['round_boundary']:
            continue
        start = row['end_us'] - row['wall_us']
        overlapping = [e for e in events if e['round'] == row['round'] and e['end_us'] >= start and e['start_us'] <= row['end_us']]
        preceding = [e for e in events if e['round'] == row['round'] and start - 50000 <= e['end_us'] < start]
        hitches.append(dict(round=int(row['round']), tick=int(row['physics_tick']), frame=int(row['frame']),
                            wall_ms=row['wall_us']/1000, physics_ms=row['physics_cpu_us']/1000,
                            visuals_ms=row['visual_cpu_us']/1000, gpu_ms=row['gpu_ms'], render_cpu_ms=row['render_cpu_ms'],
                            render_setup_ms=row['render_setup_ms'], focused=bool(row['focused']),
                            pipeline_delta=row['pipeline_delta'], events=overlapping, preceding_50ms_events=preceding))
    rounds = {}
    for number in [1, 2]:
        rows = [r for r in frames if r['round'] == number and not r['round_boundary']]
        rounds[number] = describe(rows)
        rounds[number]['focused_only'] = describe([r for r in rows if r['focused']])
        rounds[number]['pipeline_increments'] = {key: sum(r['pipeline_delta'][key] for r in rows) for key in pipeline_keys}
        rounds[number]['resolved_abilities'] = sorted(set(e['ability'] for e in events if e['round'] == number and e['kind'] == 'resolve'))
    def signature(e):
        return e['tick'], e['kind'], e['ability'], e['source'], e['victim']
    first = [e for e in events if e['round'] == 1 and e['kind'] in ['cast', 'resolve', 'impact']]
    second = [e for e in events if e['round'] == 2 and e['kind'] in ['cast', 'resolve', 'impact']]
    lookup = collections.defaultdict(collections.deque)
    for event in second:
        lookup[signature(event)].append(event)
    pairs = []
    for event in first:
        if not lookup[signature(event)]:
            continue
        replay = lookup[signature(event)].popleft()
        pairs.append(dict(tick=event['tick'], kind=event['kind'], ability=event['ability'], source=event['source'], victim=event['victim'],
                          first_call_ms=event['duration_ms'], second_call_ms=replay['duration_ms'],
                          first_near_frame_ms=event['next_3_frame_max_ms'], second_near_frame_ms=replay['next_3_frame_max_ms']))
    result = dict(metadata=metadata, rounds=rounds, hitches=hitches,
                  replay_mismatches=[e for e in events if e['kind'] in ['replay_mismatch', 'replay_missing']],
                  identical_ordered_event_signature=[signature(e) for e in first] == [signature(e) for e in second],
                  first_events=len(first), second_events=len(second), paired_events=len(pairs),
                  slowest_calls=sorted(events, key=lambda e:e['duration_ms'], reverse=True)[:25],
                  event_pairs=sorted(pairs, key=lambda e:e['first_near_frame_ms'], reverse=True))
    (directory / 'analysis.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    with (directory / 'hitches.csv').open('w', newline='', encoding='utf-8') as stream:
        columns = ['round','tick','frame','wall_ms','physics_ms','visuals_ms','gpu_ms','render_cpu_ms','render_setup_ms','focused','pipeline_delta','events','preceding_50ms_events']
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        for hitch in hitches:
            writer.writerow({**hitch, 'pipeline_delta':json.dumps(hitch['pipeline_delta']),
                             'events':'; '.join(f"{e['kind']}: {e['ability']} ({e['source']}->{e['victim']}) {e['duration_ms']:.3f}ms" for e in hitch['events']),
                             'preceding_50ms_events':'; '.join(f"{e['kind']}: {e['ability']} ({e['source']}->{e['victim']})" for e in hitch['preceding_50ms_events'])})
    print(json.dumps({k:result[k] for k in ['rounds','identical_ordered_event_signature','first_events','second_events','paired_events']}, indent=2))
    print('REPLAY ERRORS', len(result['replay_mismatches']))
    for h in sorted(hitches, key=lambda h:h['wall_ms'], reverse=True)[:15]:
        labels = sorted(set(e['kind']+':'+e['ability'] for e in h['events']))
        print(f"HITCH round={h['round']} tick={h['tick']} ms={h['wall_ms']:.3f} cpu={h['physics_ms']:.3f} visuals={h['visuals_ms']:.3f} gpu={h['gpu_ms']:.3f} setup={h['render_setup_ms']:.3f} pipes={h['pipeline_delta']} events={labels}")
    return result


if __name__ == '__main__':
    for name in sys.argv[1:]:
        analyze(pathlib.Path(name))
