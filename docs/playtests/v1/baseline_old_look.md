# Baseline of the old look (V1-03)

Full analysis, procedure, tiers and the M1-vs-style-frame explanation: `docs/perf/render_baseline.md`. Summary table of the other scenarios is there too.

Verdict versus the M1 baseline (31.9 fps): the M1 LOAD scenario (wave 60, 165 enemies, live sim) now averages **25.5 fps** (windows 21.4-29.5), 6.4 fps lower, because the M2 HUD and upgrade panel (about 41 draws) are in the frame; M1 had a placeholder panel. HUD hidden the battlefield alone runs 29.6 fps (M1-like).

LOAD wave 60 live, HIGH, vsync on, tower_phone 14 min after cold boot, 10 s windows after 20 s warm-up (PSS sampled every 10 s):

| win | enemies | fps avg | fps min (1 s) | p95 frame ms | tick ms | draws | objects | tex MB | vid MB | PSS MB |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 165 | 29.3 | 24 | 45 | 1.21 | 116 | 502 | 24.3 | 31.2 | 202.8 |
| 2 | 165 | 23.2 | 13 | 58.5 | 1.56 | 116 | 502 | 24.3 | 31.2 | 202.8 |
| 3 | 165 | 27 | 17 | 61.5 | 1.32 | 116 | 502 | 24.3 | 31.2 | 202.8 |
| 4 | 165 | 28.1 | 16 | 65 | 1.31 | 116 | 502 | 24.3 | 31.2 | 202.8 |
| 5 | 165 | 26.9 | 21 | 50.5 | 1.26 | 116 | 502 | 24.3 | 31.2 | 202.8 |
| 6 | 165 | 26.3 | 17 | 64 | 1.41 | 116 | 502 | 24.3 | 31.2 | 203 |
| 7 | 165 | 22.4 | 19 | 64.5 | 1.49 | 116 | 502 | 24.3 | 31.2 | 203 |
| 8 | 165 | 25.5 | 20 | 55 | 1.35 | 116 | 502 | 24.3 | 31.2 | 203 |
| 9 | 165 | 22 | 14 | 83 | 1.53 | 116 | 502 | 24.3 | 31.2 | 203 |
| 10 | 165 | 28.5 | 18 | 50.5 | 1.3 | 116 | 502 | 24.3 | 31.2 | 203 |
| 11 | 165 | 21.4 | 15 | 66.5 | 1.61 | 116 | 502 | 24.3 | 31.2 | 203 |
| 12 | 165 | 29.5 | 21 | 46 | 1.13 | 116 | 502 | 24.3 | 31.2 | 203 |
| 13 | 165 | 24.2 | 16 | 64 | 1.44 | 116 | 502 | 24.3 | 31.2 | 203 |
| 14 | 165 | 24.4 | 12 | 69 | 1.39 | 116 | 502 | 24.3 | 31.2 | 203 |
| 15 | 165 | 29.1 | 19 | 51.5 | 1.4 | 116 | 502 | 24.3 | 31.2 | 203 |
| 16 | 165 | 25 | 21 | 56 | 1.4 | 116 | 502 | 24.3 | 31.2 | 203 |
| 17 | 165 | 23.9 | 19 | 57.5 | 1.44 | 116 | 502 | 24.3 | 31.2 | 203 |
| 18 | 165 | 23.1 | 19 | 56 | 1.48 | 116 | 502 | 24.3 | 31.2 | 203 |
| 19 | 165 | 25.3 | 17 | 55.5 | 1.3 | 116 | 502 | 24.3 | 31.2 | 203.3 |
