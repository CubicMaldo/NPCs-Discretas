# Medieval Social Simulator (Godot 4.x)

## Overview
- Small-scale top-down sandbox focused on emergent social dynamics between pixel-art NPCs in a medieval village.
- NPC relationships are modeled as weighted edges in a dynamic social graph. The graph maintains an explicit node registry and supports using either NPC objects (with npc_id) or integer ids as keys.

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
  - Inherits `Graph` and is the runtime façade for social relations.
  - Maintains an explicit node registry and a bidirectional adjacency map.
  - Strict key policy: accepts either integer `npc_id` or NPC objects exposing `npc_id`.
  - Provides `add_connection`, `remove_connection`, `get_relationships_for`, and a central `register_interaction(a, b)` hook that computes an affinity delta (leveraging `NPC._evaluate_interaction_delta` when available) and updates the edge weight. Emits `interaction_registered` for observers.
  - `get_relationships_for` returns a dictionary keyed by `npc_id` to interoperate cleanly with components that expect ids.
- Graph (`scripts/utils/Graph.gd`)
  - Reusable graph with explicit nodes and weighted, undirected edges.
  - API: `add_node`, `ensure_node`, `remove_node`, `add_connection`, `remove_connection`, `get_edge`, `get_edges`, `get_relationships_for`.
  - Returns id-keyed neighbor maps when possible; meta per node can be stored by callers as needed (e.g., name, position, runtime refs).
- RelationshipComponent (`scripts/entities/RelationshipComponent.gd`)
  - Child node on each NPC. Owns runtime `Relationship` instances, synchronizes with `SocialGraphManager`, and exposes helpers: `add_relationship`, `update_affinity`, `break_relationship`, `get_relationship`.
  - Uses `owner_id` and partner ids for storage. Emits `relationship_broken` when crossing `break_threshold`.
  - Reads from the graph via `get_relationships_for(owner_id)` and mirrors changes locally.
- BehaviorSystem (`scripts/systems/BehaviorSystem.gd`)
  - Scores candidate actions from relationship affinities, current emotion intensity, and optional personality modifiers.
  - Can suggest state transitions and react to `register_interaction` events.
- NPC State Machine (`scripts/entities/NPC.gd` + `scripts/states/`)
  - NPCs hold a `Resource` state instance (derived from `NPCState`) and delegate `_physics_process` to the current state.
  - `set_systems(graph_manager, behavior)` injects subsystems and registers the NPC as a node in the social graph with basic metadata.
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

## Coding Guidelines
- Favor composition over inheritance for game entities.
- Use `@export` for editor-friendly tuning and `@onready` for child lookups.
- Keep scripts concise and documented around complex logic blocks.
- Place new graph algorithms in `scripts/utils/GraphAlgorithms.gd` to keep systems lean.

## Roadmap / TODO
- Build real-time graph visualization and HUD metrics (e.g., most social NPCs, simple community detection).
- Flesh out `GameManager`, `TimeManager`, and `EventSystem` for daily cycles and logging.
- Implement richer interaction outcomes that feed into `RelationshipComponent.update_affinity`.
- Populate the world (tiles, simple pathfinding) and NPC spawn logic.
- Add saving/loading of social graph state and configurable simulation parameters.
- Integrate tests or debug scenes to validate behavior transitions and graph dynamics.

## Contributing Workflow
1. Create a feature branch; keep commits scoped to one system when possible.
2. Update or add scenes/scripts using Godot 4.x; ensure the project still opens without warnings.
3. Run the simulation (F5) to verify there are no runtime errors or graph inconsistencies.
4. Document noteworthy systems or tuning knobs inline or here.

Happy simulating!