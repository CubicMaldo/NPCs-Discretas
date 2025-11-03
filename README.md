# Medieval Social Simulator (Godot 4.x)

## Overview
- Small-scale top-down sandbox focused on emergent social dynamics between pixel-art NPCs in a medieval village.
- NPC relationships are modeled as **directed, weighted edges** in a dynamic social graph, allowing asymmetric relationships (A can know B without B knowing A).
- The graph maintains an explicit node registry, supports both NPC objects (with `npc_id`) and integer ids as keys, and layers an adjacency cache for hot-path queries.
- Advanced analytics (shortest paths, strongest paths, mutual-friend metrics, rumor propagation) are built atop the same primitives and exposed through `SocialGraphManager` for gameplay scripts.

## Requirements
- Godot Engine 4.5+

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
  - `utils/` – Generic helpers (`Graph.gd`, `GraphAlgorithms.gd`, `Logger.gd`, `MathUtils.gd`, `Vertex.gd`, `Edge.gd`, `VertexMeta.gd`, `NPCVertexMeta.gd`).
  - `tests/` – Test suites (`TestSuiteBase.gd`, `TestSocialGraph.gd`, `TestResourceMetadata.gd`).

## Core Systems (current state)

- **SocialGraph** (`scripts/systems/SocialGraph.gd`)
  - **Directed graph** specialized for NPC relationships, extending the base `Graph` class.
  - Uses NPC objects as first-order keys when possible, with integer `npc_id` fallback for persistence scenarios.
  - Maintains WeakRef registry for active NPCs, automatically cleaning up freed nodes via lifecycle hooks.
  - Bidirectional adjacency cache layers (`_adjacency_by_key`, `_adjacency_by_id`) enable O(1) neighbor queries.
  - **Directed API**: `connect_npcs(a, b, familiarity)` creates A→B edge only; `connect_npcs_mutual(a, b, fam_ab, fam_ba)` creates bidirectional A↔B with independent weights.
  - **Resource-based metadata**: Vertices support flexible `Resource` metadata (e.g., `NPCVertexMeta`) for type-safe node attributes. Metadata is serialized via `to_dict()`/`from_dict()` methods.
  - Core methods: `ensure_npc`, `connect_npcs`, `connect_npcs_mutual`, `break_relationship`, `get_relationships_for`, `get_cached_neighbors`, `register_interaction`.
  - Advanced queries: `get_shortest_path`, `get_strongest_path`, `get_mutual_connections`, `simulate_rumor` (all respect edge directionality).
  - Lifecycle: `apply_decay`, `cleanup_invalid_nodes`, `validate_graph`, `repair_graph`.
  - Persistence: `serialize`, `deserialize`, `save_to_file`, `load_from_file` with optional compression. Metadata is automatically serialized if it implements `to_dict()`.

- **SocialGraphManager** (`scripts/systems/SocialGraphManager.gd`)
  - Runtime façade that instantiates and manages a `SocialGraph` singleton.
  - Provides a clean API for gameplay systems: `ensure_npc`, `add_connection`, `add_connection_mutual`, `remove_connection`, `register_interaction`.
  - Mirrors graph signals (`interaction_registered`, `interaction_registered_ids`) for observer systems.
  - Exposes all analytics and validation methods from the underlying `SocialGraph`.
  - Accepts both NPC objects and integer ids, normalizing keys when exposing results.

- **Graph** (`scripts/utils/Graph.gd`)
  - Lightweight, domain-agnostic **undirected graph** base class (RefCounted).
  - Uses explicit `Vertex` and `Edge` objects (see `scripts/utils/Vertex.gd` and `scripts/utils/Edge.gd`).
  - **Vertex metadata**: Each `Vertex` has a flexible `meta: Resource` field that accepts any Resource subclass for custom node data.
  - **Edge metadata**: Each `Edge` has a `metadata: Resource` field for custom edge attributes.
  - Core API: `add_node(key, meta: Resource)`, `ensure_node(key, meta: Resource)`, `remove_node`, `add_connection`, `remove_connection`, `get_edge`, `get_edges`, `get_neighbor_weights`, `get_neighbors`, `get_degree`.
  - `clear()` and `remove_node()` call `Vertex.dispose()` to break cyclic references and allow proper garbage collection.
  - `rekey_vertex()` supports dynamic key changes (used when pending NPCs are instantiated from saved data).
  - Metadata preservation: `ensure_node()` only updates metadata if explicitly provided; existing metadata is preserved when calling without meta argument.

- **RelationshipComponent** (`scripts/entities/RelationshipComponent.gd`)
  - Per-NPC component that manages local relationship state and synchronizes with the `SocialGraphManager`.
  - Stores relationships locally and mirrors graph changes.
  - Methods: `set_graph_manager`, `refresh_from_graph`, `update_familiarity`, `get_relationship`, `store_relationship`, `get_relationships`.
  - Interoperates with both object references and integer ids, exposing id-keyed snapshots for systems.

- **BehaviorSystem** (`scripts/systems/BehaviorSystem.gd`)
  - Scores candidate actions using relationship affinities, emotions, and personality modifiers.
  - Subscribes to interaction/register events and can propose state transitions via `choose_action_for(npc)`.
  - Notified of interactions via `notify_interaction(npc_a, npc_b)` to update decision-making context.

- **NPC** (`scripts/entities/NPC.gd`)
  - CharacterBody2D node representing individual NPCs.
  - Exports: `npc_id`, `npc_name`, `personality` (Personality resource), `base_emotion` (Emotion resource), `relationship_archetype` (Relationship resource).
  - Auto-instantiates `RelationshipComponent` if not present.
  - `set_systems(graph_manager, behavior)` injects dependencies and registers NPC in the social graph.
  - `interact_with(other_npc)` handles direct interactions: notifies systems, evaluates interaction delta via `_evaluate_interaction_delta(other)`, updates local relationships.
  - `update_relationships()` syncs local cache from `SocialGraphManager`.
  - `choose_action()` delegates to `BehaviorSystem` for state transitions.

- **NPC State Machine** (`scripts/states/`)
  - Base class `NPCState` is a `Resource` with overridable lifecycle methods: `enter`, `exit`, `physics_process`, `evaluate`.
  - Concrete states: `IdleState`, `WalkState`, `InteractState`.
  - NPCs delegate `_physics_process` to the active state instance.

## Usage Examples

### Creating NPCs with Metadata
```gdscript
# Create typed metadata for an NPC
var meta := NPCVertexMeta.new()
meta.id = 42
meta.display_name = "Alice"
meta.role = "warrior"
meta.faction = "knights"
meta.level = 15

# Register NPC with metadata
social_graph.ensure_npc(npc_alice, meta)

# Metadata is preserved across operations
social_graph.connect_npcs(npc_alice, npc_bob, 75.0)  # Alice's metadata unchanged

# Custom metadata for different vertex types
var location_meta := LocationMeta.new()
location_meta.name = "Tavern"
location_meta.location_type = "social"
location_meta.population = 20
graph.add_node("tavern_square", location_meta)
```

### Creating Directed Relationships
```gdscript
# Unidirectional: Alice knows Bob (Bob doesn't know Alice)
social_graph.connect_npcs("Alice", "Bob", 75.0)

# Bidirectional with same weight: Both know each other equally
social_graph.connect_npcs_mutual("Carol", "Dave", 80.0)

# Bidirectional with different weights: Asymmetric trust
social_graph.connect_npcs_mutual("Eve", "Frank", 90.0, 50.0)
# Eve trusts Frank (90), but Frank trusts Eve less (50)

# Via SocialGraphManager with metadata
var meta := NPCVertexMeta.new()
meta.role = "merchant"
manager.ensure_npc(npc_id, meta)
manager.add_connection_mutual(npc_a, npc_b, 75.0, 60.0)
```

### Querying Relationships
```gdscript
# Check if A knows B (directed)
if social_graph.has_edge("Alice", "Bob"):
    var familiarity = social_graph.get_edge("Alice", "Bob")
    print("Alice's familiarity with Bob: ", familiarity)

# Get all out-neighbors (who Alice knows)
var neighbors = social_graph.get_cached_neighbors("Alice")
for neighbor_key in neighbors:
    print("Alice knows: ", neighbor_key, " (", neighbors[neighbor_key], ")")

# Find shortest directed path
var path = social_graph.get_shortest_path("Alice", "Eve")
if path.reachable:
    print("Path: ", path.path)  # ["Alice", "Bob", "Carol", "Eve"]
    print("Distance: ", path.distance)
```

### Interaction System
```gdscript
# NPCs interact and update relationships
npc_alice.interact_with(npc_bob)
# 1. Evaluates interaction delta based on emotions/personality
# 2. Updates familiarity in RelationshipComponent
# 3. Notifies SocialGraphManager and BehaviorSystem
# 4. Refreshes local cache from graph

# Manual interaction registration with custom options
manager.register_interaction(npc_a, npc_b, 5.0, {
    "min_weight": 0.0,
    "max_weight": 100.0,
    "smoothing": 0.3  # Gradual changes
})
```

## NPC Composition
- `NPC.gd` (CharacterBody2D) exports `Personality`, `Emotion`, and `Relationship` resources; instantiates a `RelationshipComponent` at runtime.
- Helper accessors (`get_relationship_snapshot`, `get_relationship_component`) simplify subsystem queries.
- `_evaluate_interaction_delta(other)` provides a tunable heuristic for affinity changes per interaction, considering current emotion intensity and existing relationship data.

## Working With States
- Base class `NPCState` is a `Resource` with overridable `enter`, `exit`, `physics_process`, and `evaluate` methods.
- To add a new state:
  1) Create a script extending `NPCState` under `scripts/states/`.
  2) Implement lifecycle methods and export any tunable parameters.
  3) Register via state transition logic in `BehaviorSystem.choose_action_for(npc)`.

## Extending Personalities & Emotions
- **Personality** (`scripts/entities/Personality.gd`) stores a `traits` dictionary usable by `BehaviorSystem` for action scoring modifiers.
- **Emotion** (`scripts/entities/Emotion.gd`) holds `label` and `intensity`; NPCs duplicate it at runtime to avoid shared state.
- **Relationship** (`scripts/entities/Relationship.gd`) defines `familiarity` and `partner_id`; resources can be used for authored defaults and serialization.

## UI & Visualization (Work in Progress)
- **GraphVisualizer** (`scenes/ui/GraphVisualizer.tscn`, `scripts/ui/GraphVisualizer.gd`) will render the social graph in real time with directed edge indicators (arrows).
- **HUD** (`scenes/ui/HUD.tscn`, `scripts/ui/HUDController.gd`) placeholder for simulation metrics (most social NPCs, relationship stats, etc.).
- **LogPanel** (`scenes/ui/LogPanel.tscn`, `scripts/ui/LogController.gd`) placeholder for event history and interaction logs.
- Future features: heatmap overlays for rumor propagation, timeline widgets for relationship evolution, community detection visualization.

## Testing & Tooling
- **TestSuiteBase** (`scripts/tests/TestSuiteBase.gd`) provides a lightweight harness for GDScript tests with shared assertion helpers.
- **TestSocialGraph** (`scripts/tests/TestSocialGraph.gd`) exercises:
  - Directed graph behavior and asymmetric relationships
  - Mutual connection helpers (`connect_npcs_mutual`)
  - Node registration with objects and integer ids
  - Serialization and deserialization (with pending vertices)
  - Decay mechanics and cleanup of invalid nodes
  - Adjacency cache validation (directed edges only)
  - Shortest path (Dijkstra) and strongest path algorithms
  - Mutual connection metrics (common out-neighbors)
  - Rumor propagation respecting edge directionality
  - Run tests via the scene `scenes/tests/test_social_graph.tscn` or call `run_all_tests()` programmatically.
- **TestResourceMetadata** (`scripts/tests/TestResourceMetadata.gd`) validates:
  - Resource-based vertex metadata (NPCVertexMeta)
  - Custom data fields in metadata
  - Serialization/deserialization of metadata
  - Metadata persistence across graph operations
  - Type-safe metadata access
- Built-in stress tests and edge case validation: `SocialGraph.stress_test(num_nodes, num_edges)`, `SocialGraph.test_edge_cases()`.
- All tests include cleanup (`clear()`) to prevent memory leaks and verify proper resource management.
- Benchmark results documented in `docs/benchmark_results.md`.

## Coding Guidelines
- Favor composition over inheritance for game entities.
- Use `@export` for editor-friendly tuning and `@onready` for child lookups.
- Keep scripts concise and documented around complex logic blocks.
- Place new graph algorithms in `scripts/utils/GraphAlgorithms.gd` to keep systems lean.

### Working with Directed Graphs
- **Use `connect_npcs_mutual()` for reciprocal relationships** (friendships, alliances) to avoid creating two separate edges manually.
- **Use `connect_npcs()` for asymmetric relationships** (espionage, hierarchies, one-sided knowledge).
- Always verify both directions when checking bidirectional relationships: `has_edge(a, b) and has_edge(b, a)`.
- Remember that `get_cached_neighbors()` returns **out-neighbors only** (who A knows), not in-neighbors (who knows A).
- Graph algorithms (shortest path, rumor propagation) respect edge directionality; paths may not be reversible.
- When iterating relationships, consider whether you need out-edges, in-edges, or both.

### Best Practices for NPC Systems
- Inject dependencies via `set_systems(graph_manager, behavior)` after NPC instantiation.
- Use `RelationshipComponent` as the single source of truth for local relationship data.
- Call `update_relationships()` or `refresh_from_graph()` after bulk graph changes.
- Leverage `_evaluate_interaction_delta()` for context-aware relationship updates.
- Use `register_interaction()` for centralized interaction handling with heuristics.

## Key Features

### Directed Graph System
- **Asymmetric relationships**: A can know B without B knowing A.
- **Independent edge weights**: Bidirectional relationships can have different familiarity levels in each direction.
- **Resource-based metadata**: Type-safe vertex and edge metadata using Godot's Resource system.
  - **Flexible**: Accept any Resource subclass (NPCVertexMeta, LocationMeta, ItemMeta, custom types).
  - **Serializable**: Automatic serialization via `to_dict()`/`from_dict()` methods.
  - **Preserved**: Metadata is only updated when explicitly provided, preventing accidental overwrites.
- **Efficient queries**: O(1) neighbor lookups via adjacency cache for out-neighbors.
- **Automatic cleanup**: WeakRef-based registry with lifecycle hooks (`tree_exiting`) prevents memory leaks.
- **Persistence**: Full serialization/deserialization with pending vertex support for loading NPCs asynchronously, including metadata.

### Graph Algorithms
All algorithms respect edge directionality:
- **Shortest Path** (Dijkstra): Finds minimal-cost directed path from A to B.
- **Strongest Path**: Finds maximal-trust directed path (product of edge weights).
- **Mutual Connections**: Identifies common out-neighbors between two NPCs.
- **Rumor Propagation**: Simulates information spread following directed edges with attenuation.

### Documentation
- **docs/GRAFOS_DIRIGIDOS.md**: Comprehensive guide on directed graph concepts, API usage, migration patterns, and practical examples.
- **docs/architecture_decisions.md**: Design rationale and technical decisions.
- **docs/benchmark_results.md**: Performance metrics and stress test results.

## Roadmap / TODO
- Build real-time graph visualization with directed edge rendering and HUD metrics.
- Flesh out `GameManager`, `TimeManager`, and `EventSystem` for daily cycles and event logging.
- Implement richer interaction outcomes based on personality traits and emotions.
- Populate the world with tiles, pathfinding, and dynamic NPC spawn logic.
- Add social history snapshots for rolling-trend analytics and timeline UI.
- Wire rumor propagation into gameplay UX (signals, visual indicators, heatmaps).
- Implement in-neighbor queries (who knows X) with optimized reverse indices if needed.

## Additional Resources
- **Directed Graph Guide** (`docs/GRAFOS_DIRIGIDOS.md`): Comprehensive reference for directed graph API, migration patterns, algorithms, and practical examples.
- **Architecture Decisions** (`docs/architecture_decisions.md`): Design rationale for key technical choices.
- **Benchmark Results** (`docs/benchmark_results.md`): Performance metrics and stress test data.
- **Example Scripts** (`scripts/examples/`): Sample code demonstrating graph usage patterns.

## Contributing Workflow
1. Create a feature branch; keep commits scoped to one system when possible.
2. Update or add scenes/scripts using Godot 4.x; ensure the project still opens without warnings.
3. Run the test suite (`scenes/tests/test_social_graph.tscn`) to validate graph integrity.
4. Run the simulation (F5) to verify there are no runtime errors or graph inconsistencies.
5. Update relevant documentation (README, `docs/GRAFOS_DIRIGIDOS.md`) for API changes.
6. Document noteworthy systems or tuning knobs inline with GDScript doc comments.

### Testing Checklist
- [ ] Run `TestSocialGraph.run_all_tests()` - all tests pass
- [ ] Run `TestResourceMetadata` - metadata serialization/deserialization works
- [ ] Execute `SocialGraph.validate_graph()` - no errors reported
- [ ] Check `SocialGraph.test_edge_cases()` - all edge cases handled
- [ ] Verify directed graph behavior with asymmetric relationships
- [ ] Test metadata preservation across graph operations
- [ ] Test serialization/deserialization if persistence code changed
- [ ] Validate WeakRef cleanup with `cleanup_invalid_nodes()`
- [ ] Verify no memory leaks (object count should stabilize after tests)

Happy simulating!
