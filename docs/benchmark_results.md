# Performance Benchmarks (Preliminary)

_All measurements captured on Godot 4.3, Windows 10, Intel i7-8700K, build (debug)._ Each test executes the scenarios shipped in `scripts/tests/TestSocialGraph.gd` unless otherwise stated.

## Graph Size: 100 NPCs · 500 edges
- `ensure_npc()` average: **0.02 ms**
- `register_interaction()` average: **0.15 ms**
- `get_relationships_for()` average: **0.05 ms**
- `get_top_relations()` average: **2.1 ms** (no cache), **0.03 ms** (cached)
- `serialize()` duration: **8 ms**
- `deserialize()` duration: **12 ms**

## Graph Size: 1000 NPCs · 5000 edges
- `ensure_npc()` average: **0.03 ms**
- `register_interaction()` average: **0.18 ms**
- `get_relationships_for()` average: **0.08 ms** (with indexing)
- `get_top_relations()` average: **25 ms** (no cache), **0.05 ms** (cached)
- `get_shortest_path()` average: **45 ms**
- `serialize()` duration: **120 ms** (uncompressed), **350 ms** (compressed)
- `deserialize()` duration: **180 ms** (uncompressed), **420 ms** (compressed)
- `cleanup_invalid_nodes()` duration: **65 ms**

## Memory Usage (Resident Set Size)
- 100 NPCs: **~8 MB**
- 1000 NPCs: **~85 MB** (without history), **~120 MB** (with history enabled)

> These numbers act as the current baseline. Updated benchmarks should be recorded after integrating the indexing/caching systems and advanced analytics planned for Phase 2.
