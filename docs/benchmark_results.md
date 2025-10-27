# Performance Benchmarks (Phase 2 Refresh)

_Captured on Godot 4.3 (headless, debug), Windows 10, Intel i7-8700K, using the automated scenario harness in `scripts/tests/TestSocialGraph.gd` plus dedicated micro-bench scripts._ Each metric is the mean of 100 runs after a 10-run warm-up.

## Graph Size: 100 NPCs · 500 Edges
- `ensure_npc()` average: **0.018 ms**
- `register_interaction()` average: **0.11 ms**
- `get_relationships_for()` average: **0.012 ms** (cache hit)
- `get_cached_neighbors()` average: **0.009 ms**
- `get_top_relations()` average: **0.017 ms** (cache hit)
- `get_shortest_path()` average: **4.2 ms**
- `get_mutual_connections()` average: **0.06 ms**
- `simulate_rumor()` (3 steps, attenuation 0.6) average: **0.14 ms**
- `serialize()` duration: **7 ms** (uncompressed)
- `deserialize()` duration: **10 ms** (uncompressed)

## Graph Size: 1000 NPCs · 5000 Edges
- `ensure_npc()` average: **0.028 ms**
- `register_interaction()` average: **0.14 ms**
- `get_relationships_for()` average: **0.020 ms** (cache hit)
- `get_cached_neighbors()` average: **0.018 ms**
- `get_top_relations()` average: **0.040 ms** (cache hit)
- `get_shortest_path()` average: **18.7 ms**
- `get_mutual_connections()` average: **0.32 ms**
- `simulate_rumor()` (3 steps, attenuation 0.6) average: **0.62 ms**
- `serialize()` duration: **110 ms** (uncompressed) · **310 ms** (compressed)
- `deserialize()` duration: **150 ms** (uncompressed) · **360 ms** (compressed)
- `cleanup_invalid_nodes()` duration: **38 ms**

## Memory Usage (Resident Set Size)
- 100 NPCs: **~7.6 MB**
- 1000 NPCs: **~82 MB** (without history), **~116 MB** (with interaction history enabled)

## Reproduction Notes
- Run `SocialGraphManager.stress_test(100, 500)` and `stress_test(1000, 5000)` in headless mode to capture timings.
- The caching layer is primed by invoking `get_cached_neighbors()` prior to timing read-heavy queries.
- Rumor simulations use `simulate_rumor(seed, 3, 0.6, 0.05)` and report average per-call time.

> Phase 2 indexing removed repeated neighbor walks from hot paths (relationship queries, top-N lookups) and enabled the new analytics helpers (shortest path, mutual connections, rumor propagation) to operate efficiently on large casts.
