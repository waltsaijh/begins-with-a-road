"""Combine three native benchmark logs and the Web collector's JSON report."""
import hashlib
import json
import math
import statistics
from pathlib import Path

root = Path(__file__).resolve().parents[2]
prefix = 'DIVERSE_BENCHMARK:'
native = []
for suffix in ('', '_2', '_3'):
    log = (root / f'.godot/diverse_benchmark_native{suffix}.out').read_text(encoding='utf-8')
    native.append(json.loads(next(s[len(prefix):] for s in log.splitlines() if s.startswith(prefix))))
report = native[0]
for i, case in enumerate(report['cases']):
    for other in native[1:]:
        assert case['plan'] == other['cases'][i]['plan']
        assert case['distribution'] == other['cases'][i]['distribution']
        for name, values in other['cases'][i]['raw_us'].items():
            case['raw_us'][name].extend(values)
report['rounds'] = 60
report['batches'] = 3
report['build'] = 'Windows template_release, MSVC C++17'
report['timing_note'] = ('Cold total includes snapshot, graph building, fresh tile records, evaluation, '
                        'prepare, local weighted data, route pool and local display data packing. '
                        'Excludes scene load, rendering and validation. 3 warmups per batch, '
                        '20 retained measurements per batch. Sample timing is 256 walks/batch. '
                        'Full scene only uses its original start; both origins tested separately.')
report['memory_note'] = ('Main retained C++ vector capacity estimates only; excludes Godot Variant '
                        'packed summaries, Resources, allocator overhead, scratch buffers and process peak.')
report['extension_sha256'] = hashlib.sha256((root / 'bin/road_graph.diverse.windows.template_release.x86_64.dll').read_bytes()).hexdigest()
web = json.loads((root / 'reports/navigation/diverse_routes_web.json').read_text(encoding='utf-8'))
web['extension_sha256'] = hashlib.sha256((root / 'bin/road_graph.diverse.web.template_release.wasm32.nothreads.wasm').read_bytes()).hexdigest()
for data in (report, web):
    for case in data['cases']:
        case['summary_us'] = {}
        for key, raw in case['raw_us'].items():
            values = sorted(raw)
            case['summary_us'][key] = {'median': statistics.median(values),
                                       'p95': values[math.ceil(len(values)*.95)-1],
                                       'min': min(values), 'max': max(values)}
for name, data in (('windows', report), ('web', web)):
    (root / f'reports/navigation/diverse_routes_{name}.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
lines = ['# 完整入口圖與分散路線池', '',
         '測試日期：2026-10-15。Godot 4.7.2 Compatibility；Windows release；Web 為 Edge 無頭瀏覽器、WebGL 2.0、單執行緒 release。兵種每格成本 1、overlap_penalty=1、search_budget=64。', '',
         '直接在完整雙向入口圖上執行 Dijkstra，沒有全域 DAG 定向。首條保留原圖最佳；後續以探索懲罰分散，原始成本分差必須嚴格小於 threshold。連續 8 次沒有新增或達到預算便停止。不是全部路線，也不是前 K 佳。', '',
         '9x9 是使用者現有複雜場景：345 格、110 節點、602 個雙向成本選項；11x11big 是目前加入第二起點後的場景：151 格、10 節點、24 個選項。效能表量測各場景原起點；11x11big 兩起點另有功能測試。', '',
         'Windows 每組三輪、每輪暖機 3 次後保留 20 次，共 60 次；Web 每組暖機 3 次後保留 20 次。Cold 包含快照、建圖、每格 Resource、evaluation、prepare、局部資料、路線池與局部顯示資料封裝；不含載入場景、渲染、測試斷言。搜尋欄只含全域候選池生成。', '',
         '| 地圖 | threshold | 路線池 | 搜尋次數 | Windows cold 中位／P95 ms | Windows 全域搜尋 ms | Web cold 中位／P95 ms |',
         '|---|---:|---:|---:|---:|---:|---:|']
for a, b in zip(report['cases'], web['cases']):
    assert a['distribution'] == b['distribution']
    p = a['plan']; w = a['summary_us']; browser = b['summary_us']
    lines.append(f"| {a['scene']} | {a['threshold']} | {p['routes']} | {p['attempts']} | {w['cold_total']['median']/1000:.3f} / {w['cold_total']['p95']/1000:.3f} | {w['search']['median']/1000:.3f} | {browser['cold_total']['median']/1000:.3f} / {browser['cold_total']['p95']/1000:.3f} |")
lines += ['', '| 地圖／threshold | Windows 抽一條 µs | Web 抽一條 µs | C++ 幾何＋計畫容量估算 KiB |', '|---|---:|---:|---:|']
for a, b in zip(report['cases'], web['cases']):
    p = a['plan']
    lines.append(f"| {a['scene']} / {a['threshold']} | {a['summary_us']['sample']['median']:.2f} | {b['summary_us']['sample']['median']:.2f} | {(p['geometry_bytes_estimate']+p['plan_bytes_estimate'])/1024:.1f} |")
lines += ['', '容量是主要常駐 C++ vector capacity 估算，排除 Godot Variant／已封裝摘要、Resource、配置器、暫存與程序峰值，不是整個遊戲的記憶體用量。', '',
          '## 路線分散', '',
          '每組以相同 256 個 seed 抽樣；Windows／Web 六組候選數與完整逐格行程 fingerprint 全部一致。', '',
          '| 地圖／threshold | 抽到的不同節點路線 | 中後段離開主路再往前匯回的樣本數 | 最大樣本原始成本 |', '|---|---:|---:|---:|']
for case in report['cases']:
    d = case['distribution']
    lines.append(f"| {case['scene']} / {case['threshold']} | {d['unique_vertex_routes_in_256_samples']} | {d['late_main_road_departures_and_rejoins']} / 256 | {d['max_sample_score']} |")
lines += ['', '中後段指從 y=0、x≥12 的入口離開主路，之後在更大的 x 回到 y=0；這個指標主要用於 9x9 的中央直路診斷。全域最優仍為 9x9 的 23、11x11big 原起點 33、第二起點 38。保留最佳不代表每批抽樣必然抽到最佳。', '',
          '9x9 在 threshold=10 時只收錄 10 條，連續無新增而提前停止；不表示圖上只有 10 條合規路線。threshold=25 時收錄 62 條，INF 時 63 條，均受 64 次搜尋限制。局部同成本走法另行保留，不計入節點路線池數量。', '',
          '## 驗證與重測', '',
          '- tests/native/diverse_routes.cpp：25,600 組小圖起終點對照 simple-path oracle；原圖最優、反向道路、共用橋、無重複節點、非對稱成本、threshold 等號排除與預算限制。',
          '- tests/navigation/route_planner.gd、tile_costs.gd、enemy_profiles.gd、multiple_starts.tscn：兩張現有場景、逐格實際行程、局部全部同分走法、成本／兵種失效、多起點與 N／R 預覽。',
          '- tests/navigation/diverse_benchmark.tscn：本次 Windows／Web 使用相同測試。tools/benchmarks/benchmark_diverse.cjs 收集 Web，tools/benchmarks/summarize_diverse.py 彙整三份原生 log 與 Web JSON。', '',
          '四種 Windows／Web debug／release 擴充皆已重建。原始資料保存在 diverse_routes_windows.json 與 diverse_routes_web.json；場景與擴充 SHA256 位於 JSON。舊 DAG 報告屬於不同演算法，不能把其路線總數當成本版候選池數量比較。', '']
(root / 'reports/navigation/diverse_routes.md').write_text('\n'.join(lines), encoding='utf-8')
print('\n'.join(lines[10:20]))
