# Medieval Social Simulator (Godot 4.x)

## Overview
- Small-scale top-down sandbox focused on emergent social dynamics between pixel-art NPCs in a medieval village.
- NPC relationships are modeled as **directed weighted edges** in a dynamic social graph, allowing asymmetric relationships (A knows B, but B may not know A). The graph maintains an explicit node registry, supports both NPC objects (with `npc_id`) and integer ids as keys, and layers an adjacency cache for hot-path queries.
- Edge weights represent **familiaridad/conocimiento** (familiarity/knowledge) in the range [0..100], indicating how much one NPC knows or trusts another.
- Advanced analytics (shortest paths, mutual-friend metrics, rumor propagation) are built atop the same primitives and exposed through `SocialGraphManager` for gameplay scripts. All algorithms respect graph directionality.

## Requirements
- Godot Engine 4.5.

## Key Features

### 🎯 Directed Social Graph System
The project uses a **directed graph** architecture for NPC relationships, enabling:
- **Asymmetric relationships**: A can know B without B knowing A (espionage, hierarchies, one-way awareness)
- **Bidirectional relationships with independent weights**: Alice trusts Bob (80%), Bob trusts Alice (40%)
- **Edge weights as familiarity/knowledge**: [0..100] representing how much one NPC knows another
- **Directional algorithms**: All pathfinding, rumor propagation, and analytics respect edge directionality

**Quick Start:**
```gdscript
# Directed relationship (A knows B, but B doesn't know A)
social_graph.connect_npcs("Spy", "Target", 85.0)

# Bidirectional relationship (both know each other)
social_graph.connect_npcs_mutual("Alice", "Bob", 80.0, 60.0)

# Query directed familiarity
var familiarity = social_graph.get_familiarity("Alice", "Bob")  # 80.0
var reverse = social_graph.get_familiarity("Bob", "Alice")      # 60.0
```

See `GRAFOS_DIRIGIDOS.md` for comprehensive documentation and `scripts/examples/DirectedGraphExamples.gd` for 10 executable examples.

### 📊 Advanced Analytics
- **Shortest Path** (Dijkstra): Find minimum-cost directed paths between NPCs
- **Strongest Path**: Find maximum-trust paths (multiplicative weights)
- **Mutual Connections**: Discover common acquaintances (shared outgoing neighbors)
- **Rumor Propagation**: Simulate information spread following directed edges
- **All algorithms** respect graph directionality and include extensive documentation

## Getting Started
1. Open Godot 4.5 and import the project by selecting the root directory that contains `project.godot`.
2. The startup scene is `scenes/main/Main.tscn`.
3. Run the project (F5). Current content is minimal; focus is on validating social graph dynamics and basic NPC state flow.

## Project Layout
- `scenes/` – Godot scenes grouped by domain.
  - `main/` – Entry scenes (`Main.tscn`, `Camera2D.tscn`).
  - `world/` – World container and tile scripts/scenes.
  - `npcs/` – NPC scene and visuals (`NPC.tscn`, `NPCSprite.tscn`, emotion icon scene).
  - `ui/` – HUD, Graph Visualizer, and Log Panel scenes (currently placeholders).
- `scripts/`
  - `core/` – Orchestration stubs (`GameManager.gd`, `TimeManager.gd`, `EventSystem.gd`).
  - `entities/` – NPC-focused scripts (`NPC.gd`, `RelationshipComponent.gd`, Resource definitions).
  - `systems/` – Simulation subsystems (`SocialGraphManager.gd`, `BehaviorSystem.gd`).
  - `states/` – Resource-based NPC states (`IdleState.gd`, `WalkState.gd`, `InteractState.gd`).
  - `ui/` – Future HUD/graph/log controllers.
  - `utils/` – Generic helpers (`Graph.gd`, `GraphAlgorithms.gd`, `Logger.gd`, `MathUtils.gd`, `Vertex.gd`, `Edge.gd`).

## Core Systems (current state)

### SocialGraphManager (`scripts/systems/SocialGraphManager.gd`)
- Runtime façade that composes the reusable `Graph` data structure (preloads/instantiates `SocialGraph`).
- Maintains the node registry and connects NPCs via the **directed graph API**. Accepts integer `npc_id` or NPC objects where appropriate, normalizes keys when exposing id-keyed results, and mirrors relationships into cached adjacency dictionaries.
- **Key Methods**:
  - `add_connection(a, b, affinity)` - Creates **directed edge A→B only**. For bidirectional relationships, use `add_connection_mutual()`.
  - `add_connection_mutual(a, b, aff_ab, aff_ba)` - **NEW**: Creates bidirectional relationship A↔B with independent weights in each direction.
  - `remove_connection(a, b)` - Removes directed edge A→B (call twice to remove both directions).
  - `get_familiarity(a, b)` - Returns familiaridad that A has towards B (directed).
  - Cache-backed queries: `get_cached_neighbors(key)` returns **outgoing neighbors only** (out-degree).
- **Analytics**: `get_shortest_path`, `get_strongest_path`, `get_mutual_connections`, `simulate_rumor` - all respect graph directionality.
- Emits domain signals for observers: `interaction_registered`, `interaction_registered_ids`.

### Graph (`scripts/utils/Graph.gd`)
- Lightweight, domain-agnostic **directed graph** implemented as a RefCounted data class.
- Uses explicit `Vertex` and `Edge` objects (see `scripts/utils/Vertex.gd` and `scripts/utils/Edge.gd`).
- **Important API**:
  - `add_connection(a, b, weight)` - Creates directed edge A→B (does NOT create B→A automatically).
  - `remove_connection(a, b)` - Removes directed edge A→B only.
  - `has_edge(a, b)` - Checks if directed edge A→B exists.
  - `get_edge(a, b)` - Returns weight of directed edge A→B.
  - `get_neighbor_weights(key)` - Returns **outgoing neighbors** only (edges from key).
  - `get_edges()` - Returns all directed edges (no duplicates, no filtering needed).
- `clear()` and `remove_node()` call `Vertex.dispose()` to break cyclic references and allow Godot to reclaim RefCounted objects.
- The `SocialGraph` subclass (`scripts/systems/SocialGraph.gd`) layers weak-ref NPC registries and adjacency caches that stay synchronized during rekeys and cleanup.

### SocialGraph (`scripts/systems/SocialGraph.gd`)
- Extends `Graph` with social-specific features and NPC management.
- **Directed Graph Methods**:
  - `connect_npcs(a, b, familiarity)` - Creates directed edge A→B with specified familiarity [0..100].
  - `connect_npcs_mutual(a, b, fam_ab, fam_ba)` - **NEW**: Creates bidirectional relationship with independent weights.
  - `set_familiarity(a, b, weight)` - Updates directed edge A→B.
- **Caching System**: Maintains `_adjacency_by_key` and `_adjacency_by_id` for fast lookups of outgoing edges.
- **File I/O**: `save_to_file(path, compressed)` and `load_from_file(path)` with pretty-printed JSON support.
- **Validation & Testing**: Built-in `validate_graph()`, `repair_graph()`, and `stress_test()` methods.

### GraphAlgorithms (`scripts/utils/GraphAlgorithms.gd`)
- Static utility class with graph algorithms, **all updated for directed graphs**:
  - `shortest_path(graph, source, target)` - Dijkstra's algorithm respecting edge directionality.
  - `shortest_path_bellman_ford(graph, source, target)` - Handles negative weights in directed graphs.
  - `strongest_path(graph, source, target)` - Finds path with maximum accumulated trust (product of normalized weights).
  - `mutual_metrics(graph, a, b, min_weight)` - Finds common outgoing neighbors (mutual acquaintances).
  - `propagate_rumor(graph, seed, steps, attenuation, min_strength)` - Simulates information spread following directed edges only.
- All algorithms include extensive documentation clarifying directed graph behavior.

### RelationshipComponent (`scripts/entities/RelationshipComponent.gd`)
- Per-NPC component that manages local relationship state and synchronizes with the `SocialGraphManager`.
- Stores relationships and mirrors graph changes; updated to interoperate with object references as keys where convenient while exposing id-keyed snapshots for systems that expect ids.
- **Note**: Works with directed relationships - tracks both outgoing (who this NPC knows) and can query incoming (who knows this NPC) via graph traversal.

### BehaviorSystem (`scripts/systems/BehaviorSystem.gd`)
- Scores candidate actions using relationship affinities, emotions, and personality modifiers.
- Subscribes to interaction/register events and can propose state transitions.
- **Updated** to work with directed relationships - considers asymmetric familiarity when scoring interactions.

### NPC State Machine (`scripts/entities/NPC.gd` + `scripts/states/`)
- NPCs hold a `Resource` state instance (derived from `NPCState`) and delegate physics processing to the active state.
- `set_systems(graph_manager, behavior)` injects subsystems and registers the NPC as a node in the social graph with metadata.
- `interact_with(other_npc)` notifies systems and applies a familiarity delta derived from emotion and relationship context.
- **Important**: Interactions create directed edges by default. Use `connect_npcs_mutual()` for reciprocal relationships.

## NPC Composition
- `NPC.gd` (CharacterBody2D) exports `Personality`, `Emotion`, and `Relationship` resources; instantiates a `RelationshipComponent` at runtime.
- Helper accessors (`get_relationship_snapshot`, `get_relationship_component`) simplify subsystem queries.
- `_evaluate_interaction_delta(other)` provides a tunable heuristic for familiarity changes per interaction.
- **Edge weights** represent **familiaridad** (familiarity/knowledge), not affinity. Higher values = stronger familiarity/trust.

## Working With States
- Base class `NPCState` is a `Resource` with overridable `enter`, `exit`, `physics_process`, and `evaluate` methods.
- To add a new state:
  1) Create a script extending `NPCState` under `scripts/states/`.
  2) Implement lifecycle methods and export any tunable parameters.
  3) Register via `NPC.set_state_by_name` or inject dynamically through `BehaviorSystem`.

## Extending Personalities & Emotions
- `Personality.gd` stores a `traits` dictionary usable by `BehaviorSystem` for scoring modifiers.
- `Emotion.gd` holds `label` and `intensity`; NPCs duplicate it at runtime to avoid shared state.
- `Relationship.gd` defines `familiarity` (formerly `affinity`) and `partner_id`; resources can be used for authored defaults and serialization.
- **Terminology**: "Familiarity" represents how well one NPC knows another. "Affinity" methods remain for backward compatibility but map to familiarity.

## Planned UI & Visualization
- `scenes/ui/GraphVisualizer.tscn` and `scripts/ui/GraphVisualizer.gd` will render the social graph in real time (work-in-progress).
- `HUD` and `LogPanel` scenes are placeholders for simulation metrics and event history.

## Testing & Tooling
- `scripts/tests/TestSuiteBase.gd` provides a lightweight harness for registering GDScript-based checks with shared assertion helpers.
- `scripts/tests/TestSocialGraph.gd` exercises all graph functionality with **18 comprehensive tests**:
  - NPC registration, serialization/deserialization roundtrip
  - Decay behavior, cleanup of invalid nodes
  - **Directed graph behavior** (asymmetric relationships)
  - **Bidirectional connection helpers** (`connect_npcs_mutual`)
  - Caching layer (outgoing edges only)
  - Path finding (shortest, strongest) respecting directionality
  - Mutual connections, rumor propagation
  - File I/O (compressed/uncompressed, pretty-print JSON)
- **All tests pass** - run the TestSocialGraph scene or call `run_all_tests()` headless.
- Benchmarks and stress tests live alongside the graph (`SocialGraph.stress_test`, `simulate_rumor`) with aggregate numbers in `docs/benchmark_results.md`.

## Documentation
- **`GRAFOS_DIRIGIDOS.md`** - Comprehensive guide (8,000+ words) covering:
  - Directed graph concepts and theory
  - Complete API reference with examples
  - Migration guide from undirected to directed graphs
  - Best practices and use cases
  - 10+ practical scenarios (espionage, hierarchies, information flow, etc.)
- **`scripts/examples/DirectedGraphExamples.gd`** - 10 executable code examples demonstrating:
  - Basic directed edges and bidirectional relationships
  - Asymmetric trust scenarios
  - Espionage networks and organizational hierarchies
  - Information flow and rumor propagation
  - Shortest/strongest path algorithms
  - Mutual friend detection

## Coding Guidelines
- Favor composition over inheritance for game entities.
- Use `@export` for editor-friendly tuning and `@onready` for child lookups.
- Keep scripts concise and documented around complex logic blocks.
- Place new graph algorithms in `scripts/utils/GraphAlgorithms.gd` to keep systems lean.
- **Directed Graph Best Practices**:
  - Use `connect_npcs_mutual()` for reciprocal relationships (friendships).
  - Use `connect_npcs()` only for asymmetric relationships (espionage, hierarchies, one-way knowledge).
  - Always verify both directions when checking bidirectional relationships.
  - Remember: `get_cached_neighbors()` returns **outgoing edges only** (out-degree).

## Roadmap / TODO
- Build real-time graph visualization and HUD metrics (e.g., most social NPCs, community overlays).
  - Consider visualizing directed edges with arrows to show relationship directionality.
- Flesh out `GameManager`, `TimeManager`, and `EventSystem` for daily cycles and logging.
- Implement richer interaction outcomes that feed into `RelationshipComponent.update_familiarity`.
- Populate the world (tiles, simple pathfinding) and NPC spawn logic.
- Persist social history snapshots to unlock rolling-trend analytics and UI charts.
- Add delta-zero indices for instant "new connection" detection and event hooks.
- Wire rumor propagation into UX (signals, timeline widgets, optional heatmap overlays).
- Integrate tests or debug scenes to validate behavior transitions and graph dynamics.
- **Directed Graph Enhancements**:
  - Add in-degree analysis (who knows this NPC) alongside existing out-degree queries.
  - Implement centrality metrics (PageRank-style influence for directed graphs).
  - Consider visualization of asymmetric relationships (different arrow colors/thickness per direction).

## Contributing Workflow
1. Create a feature branch; keep commits scoped to one system when possible.
2. Update or add scenes/scripts using Godot 4.x; ensure the project still opens without warnings.
3. Run the simulation (F5) to verify there are no runtime errors or graph inconsistencies.
4. Document noteworthy systems or tuning knobs inline or here.

Happy simulating!
