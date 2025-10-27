# Medieval Social Simulator (Godot 4.x)

## Overview
- Small-scale top-down sandbox focused on emergent social dynamics between pixel-art NPCs in a medieval village.
- NPC relationships are modeled as weighted edges in a dynamic social graph. The graph maintains an explicit node registry, supports both NPC objects (with `npc_id`) and integer ids as keys, and layers an adjacency cache for hot-path queries.
- Advanced analytics (shortest paths, mutual-friend metrics, rumor propagation) are built atop the same primitives and exposed through `SocialGraphManager` for gameplay scripts.

## Requirements
- Godot Engine 4.5.

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

- SocialGraphManager (`scripts/systems/SocialGraphManager.gd`)
  - Runtime façade that composes the reusable `Graph` data structure (preloads/instantiates `Graph`).
  - Maintains the node registry and connects NPCs via the graph API. Accepts integer `npc_id` or NPC objects where appropriate, normalizes keys when exposing id-keyed results, and mirrors relationships into cached adjacency dictionaries.
  - Exposes helpers to add/remove connections, a central `register_interaction(a, b)` hook (delegating to NPC heuristics when available), cache-backed queries (`get_cached_neighbors`, `get_cached_degree`), and analytics (`get_shortest_path`, `get_mutual_connections`, `simulate_rumor`). Emits domain signals for observers.

- Graph (`scripts/utils/Graph.gd`)
  - Lightweight, domain-agnostic graph implemented as a RefCounted data class.
  - Uses explicit `Vertex` and `Edge` objects (see `scripts/utils/Vertex.gd` and `scripts/utils/Edge.gd`). Adjacency is stored per-vertex (no global string edge keys); edge listing deduplicates with a stable comparator.
  - Important API: `add_node`, `ensure_node`, `remove_node`, `add_connection`, `remove_connection`, `get_edge`, `get_edges`, `get_neighbor_weights`, `get_neighbors`, `get_degree`.
  - `clear()` and `remove_node()` call `Vertex.dispose()` to break cyclic references and allow Godot to reclaim RefCounted objects.
  - The `SocialGraph` subclass layers weak-ref NPC registries and adjacency caches that stay synchronized during rekeys and cleanup.

- RelationshipComponent (`scripts/entities/RelationshipComponent.gd`)
  - Per-NPC component that manages local relationship state and synchronizes with the `SocialGraphManager`.
  - Stores relationships and mirrors graph changes; updated to interoperate with object references as keys where convenient while exposing id-keyed snapshots for systems that expect ids.

- BehaviorSystem (`scripts/systems/BehaviorSystem.gd`)
  - Scores candidate actions using relationship affinities, emotions, and personality modifiers.
  - Subscribes to interaction/register events and can propose state transitions.

- NPC State Machine (`scripts/entities/NPC.gd` + `scripts/states/`)
  - NPCs hold a `Resource` state instance (derived from `NPCState`) and delegate physics processing to the active state.
  - `set_systems(graph_manager, behavior)` injects subsystems and registers the NPC as a node in the social graph with metadata.
  - `interact_with(other_npc)` notifies systems and applies an affinity delta derived from emotion and relationship context.

## NPC Composition
- `NPC.gd` (CharacterBody2D) exports `Personality`, `Emotion`, and `Relationship` resources; instantiates a `RelationshipComponent` at runtime.
- Helper accessors (`get_relationship_snapshot`, `get_relationship_component`) simplify subsystem queries.
- `_evaluate_interaction_delta(other)` provides a tunable heuristic for affinity changes per interaction.

## Working With States
- Base class `NPCState` is a `Resource` with overridable `enter`, `exit`, `physics_process`, and `evaluate` methods.
- To add a new state:
  1) Create a script extending `NPCState` under `scripts/states/`.
  2) Implement lifecycle methods and export any tunable parameters.
  3) Register via `NPC.set_state_by_name` or inject dynamically through `BehaviorSystem`.

## Extending Personalities & Emotions
- `Personality.gd` stores a `traits` dictionary usable by `BehaviorSystem` for scoring modifiers.
- `Emotion.gd` holds `label` and `intensity`; NPCs duplicate it at runtime to avoid shared state.
- `Relationship.gd` defines `affinity` and `partner_id`; resources can be used for authored defaults and serialization.

## Planned UI & Visualization
- `scenes/ui/GraphVisualizer.tscn` and `scripts/ui/GraphVisualizer.gd` will render the social graph in real time (work-in-progress).
- `HUD` and `LogPanel` scenes are placeholders for simulation metrics and event history.

## Testing & Tooling
- `scripts/tests/TestSuiteBase.gd` provides a lightweight harness for registering GDScript-based checks with shared assertion helpers.
- `scripts/tests/TestSocialGraph.gd` exercises registration, serialization, decay, cleanup, caching, path finding, mutual analytics, and rumor propagation (run the scene or call `run_all_tests()` headless).
- Benchmarks and stress tests live alongside the graph (`SocialGraph.stress_test`, `simulate_rumor`) with aggregate numbers in `docs/benchmark_results.md`.

## Coding Guidelines
- Favor composition over inheritance for game entities.
- Use `@export` for editor-friendly tuning and `@onready` for child lookups.
- Keep scripts concise and documented around complex logic blocks.
- Place new graph algorithms in `scripts/utils/GraphAlgorithms.gd` to keep systems lean.

## Roadmap / TODO
- Build real-time graph visualization and HUD metrics (e.g., most social NPCs, community overlays).
- Flesh out `GameManager`, `TimeManager`, and `EventSystem` for daily cycles and logging.
- Implement richer interaction outcomes that feed into `RelationshipComponent.update_affinity`.
- Populate the world (tiles, simple pathfinding) and NPC spawn logic.
- Persist social history snapshots to unlock rolling-trend analytics and UI charts.
- Add delta-zero indices for instant “new connection” detection and event hooks.
- Wire rumor propagation into UX (signals, timeline widgets, optional heatmap overlays).
- Integrate tests or debug scenes to validate behavior transitions and graph dynamics.

## Contributing Workflow
1. Create a feature branch; keep commits scoped to one system when possible.
2. Update or add scenes/scripts using Godot 4.x; ensure the project still opens without warnings.
3. Run the simulation (F5) to verify there are no runtime errors or graph inconsistencies.
4. Document noteworthy systems or tuning knobs inline or here.

Happy simulating!
