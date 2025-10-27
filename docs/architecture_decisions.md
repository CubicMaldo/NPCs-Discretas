# Architecture Decisions

## Decision 1: NPC Objects as Primary Keys

**Problem**: Determine whether to store relationships by raw integer IDs or NPC object references.

**Decision**: Use NPC objects as the canonical key, backed by a secondary integer ID inside `Vertex`.

**Rationale**:
- Maintains type safety and expressiveness for gameplay systems written in GDScript.
- Simplifies lookups when AI subsystems already operate on NPC instances.
- Reuses the existing `Vertex.id` slot for persistence and fallback queries.
- Weak references plus lifecycle hooks (`tree_exiting`) prevent leaks when NPCs are freed.

**Trade-offs**:
- Requires lifecycle management and pending-vertex logic during deserialization.
- Necessitates `Graph.rekey_vertex()` to swap temporary IDs for NPC objects post-load.

---

## Decision 2: Lifecycle Registry with WeakRef

**Problem**: Avoid dangling references when NPCs despawn or scenes unload.

**Decision**: Maintain `_npc_registry` (id -> WeakRef), `_npc_to_vertex` (NPC -> Vertex) and connect `tree_exiting` for automatic cleanup.

**Rationale**:
- Guarantees `cleanup_invalid_nodes()` can sweep stale entries without manual bookkeeping.
- Allows `get_npc_by_id()` to return live instances only when valid.
- Supports background persistence workflows where vertices exist before NPC instances.

**Trade-offs**:
- Requires additional bookkeeping during ensure/remove paths.
- Keeps short-lived callables to disconnect signals when clearing/disposing graphs.

---

## Decision 3: JSON Serialization with Two-Phase Reconstruction

**Problem**: Persist large graphs efficiently while keeping runtime objects decoupled from save files.

**Decision**: Serialize to JSON (optionally GZip compressed) using vertex IDs and rebuild the structure in two phases (`deserialize` + `register_loaded_npc`).

**Rationale**:
- Avoids storing direct object references in saves; only the stable `npc_id` travels to disk.
- Supports incremental scene loading: vertices are ready immediately, NPCs bind later.
- Allows future migrations via `_migrate_from_v1()` without breaking existing saves.

**Trade-offs**:
- Requires clients to call `register_loaded_npc()` after instantiating NPC scenes.
- Metadata must remain JSON-friendly to avoid parse errors during load.

---

## Decision 4: Dunbar Limit Enforcement

**Problem**: Keep relationship degrees realistic and performant for large populations.

**Decision**: Enforce `DUNBAR_LIMIT` (default 150) in `connect_npcs()` and `register_interaction()` to drop the weakest ties beyond the threshold.

**Rationale**:
- Prevents unbounded degree growth that would slow down neighbor queries.
- Encapsulates trimming logic centrally, avoiding ad-hoc cleanup in gameplay code.

**Trade-offs**:
- Hard limit may remove edges unexpectedly if designers push beyond 150 active relationships.
- Requires predictable ordering (by weight) when trimming to avoid surprising oscillations.

---

## Decision 5: Validation & Repair Utilities in Core Graph

**Problem**: Need visibility into data integrity without relying on external tooling.

**Decision**: Ship `validate_graph()`, `repair_graph()`, `stress_test()` and `test_edge_cases()` inside `SocialGraph`.

**Rationale**:
- Offers immediate diagnostics for QA and automated tests.
- Encapsulates knowledge of internal structures (pending vertices, weak refs) with the class that owns them.

**Trade-offs**:
- Slightly increases script size and responsibility of `SocialGraph`.
- Stress test creates throwaway graphs; callers must interpret metrics responsibly.
