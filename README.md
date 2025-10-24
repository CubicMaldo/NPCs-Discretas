# Medieval Social Simulator (Godot 4.x)

## Overview
- Small-scale top-down sandbox focused on emergent social dynamics between pixel-art NPCs in a medieval village.
- NPC relationships are stored as weighted edges in a dynamic social graph; interactions reinforce or weaken affinities.
- Systems emphasize composition: NPC nodes wire reusable Resources (personality, emotion, relationships) and child components (e.g., `RelationshipComponent`).
- Tactical combat and economy are not priorities; the goal is to observe how social ties evolve over time and surface them via future HUD/graph views.

## Requirements
- Godot Engine 4.5 (matches `project.godot` feature tags).
- Optional: Git LFS or similar for future art/audio assets (current repo uses lightweight placeholder sprites).

## Getting Started
1. Open Godot 4.5 and import the project by selecting the root directory that contains `project.godot`.
2. Set `scenes/main/Main.tscn` as the startup scene (already configured in `project.godot`).
3. Run the project (`F5`) to load the main scene; placeholder content is minimal until world generation and UI systems are fleshed out.

## Project Layout
- `scenes/` – Godot scenes grouped by domain.
  - `main/` – Entry point scenes (`Main.tscn`, `Camera2D.tscn`).
  - `world/` – Map container, tile scripts/scene.
  - `npcs/` – NPC scene and supporting visuals (`NPC.tscn`, `NPCSprite.tscn`, emotion icon scene).
  - `ui/` – HUD, graph visualizer, log panel scenes (placeholders for now).
- `scripts/`
  - `core/` – Global orchestration stubs (`GameManager.gd`, `TimeManager.gd`, `EventSystem.gd`).
  - `entities/` – NPC-focused scripts (`NPC.gd`, `RelationshipComponent.gd`, Resource definitions).
  - `systems/` – Simulation subsystems (`SocialGraphManager.gd`, `BehaviorSystem.gd`, state base class).
  - `states/` – Resource-based NPC state machine scripts (`IdleState.gd`, `WalkState.gd`, `InteractState.gd`).
  - `ui/` – Controllers for future HUD/graph/log features.
  - `utils/` – Generic helpers (math, graph algorithms, logging placeholders).
- `assets/`
  - `sprites/` – Placeholder folders for NPC and tile art.
  - `fonts/` – Reserved for UI fonts.
- `.godot/` – Engine metadata (auto-managed).

## Core Systems
- **SocialGraphManager (`scripts/systems/SocialGraphManager.gd`)**
  - Maintains a bidirectional adjacency dictionary keyed by NPC id.
  - Provides `add_connection`, `remove_connection`, `get_relationships_for`, and a hook (`register_interaction`) for analytics/decay logic.
  - Enforces removal of edges when affinity drops below zero.
- **BehaviorSystem (`scripts/systems/BehaviorSystem.gd`)**
  - Calculates probabilistic action scores based on strongest relationship affinities, emotion intensity, and optional personality modifiers.
  - Emits `action_chosen` so other systems can react to planned behavior.
  - Convenience method `choose_state_for` maps actions to Resource-based NPC states.
- **NPC State Machine (`scripts/entities/NPC.gd` + `scripts/states/`)**
  - NPCs hold a `Resource` state instance (derived from `NPCState`) and delegate `_physics_process` to the current state.
  - States may call `evaluate()` to suggest transitions or defer to `BehaviorSystem` for pull-based changes.
  - Sample states: idle (time-based), walk (wander target), interact (placeholder).
- **RelationshipComponent (`scripts/entities/RelationshipComponent.gd`)**
  - Node child on each NPC that owns runtime `Relationship` instances, synchronizes with `SocialGraphManager`, and exposes helper methods (`add_relationship`, `update_affinity`, `break_relationship`, `get_relationship`).
  - Emits `relationship_broken` when affinity crosses the break threshold.
  - Accepts externally defined `Relationship` resources via `store_relationship` for scripted setups.

## NPC Composition
- `NPC.gd` (CharacterBody2D) exports `Personality`, `Emotion`, and `Relationship` resources while instantiating a `RelationshipComponent` child at runtime.
- `set_systems` injects subsystem singletons and refreshes the relationship cache.
- `interact_with(other_npc)` notifies systems and applies an affinity delta derived from current emotion + existing relationship data.
- Helper accessors (`get_relationship_snapshot`, `get_relationship_component`) simplify subsystem queries.

## Working With States
- Base class `NPCState` is a `Resource` with overridable `enter`, `exit`, `physics_process`, and `evaluate` methods.
- To add a new state:
  1. Create a script extending `NPCState` under `scripts/states/`.
  2. Implement lifecycle methods and export any tunable parameters.
  3. Register the state in `NPC.set_state_by_name` or inject it dynamically via `BehaviorSystem.choose_state_for`.
- States should avoid storing NPC references persistently; use the provided arguments instead.

## Extending Personalities & Emotions
- `Personality.gd` currently stores a `traits` dictionary; implement helper functions (e.g., `get_behavior_modifiers`) to influence `BehaviorSystem` scoring.
- `Emotion.gd` holds `label` and `intensity`. Duplicate or mutate per NPC via `_instantiate_emotion()` to avoid shared state.
- `Relationship.gd` defines `affinity` and `partner_id`. Use resource instances for authoring default bonds or serialization.

## Planned UI & Visualization
- `scenes/ui/GraphVisualizer.tscn` and `scripts/ui/GraphVisualizer.gd` will render the social graph in real time.
- `HUD` and `LogPanel` scenes provide placeholders for simulation metrics and event history; connect them to `EventSystem` once logging is implemented.

## Coding Guidelines
- Favor composition: attach nodes or resources instead of deep inheritance chains.
- Use `@export` for editor-friendly tuning and `@onready` for child lookups.
- Keep scripts ASCII-only and add concise comments explaining complex logic blocks (avoid redundant narration).
- Run linting via Godot's script editor; avoid introducing unused preloads or signals.
- When adding new graph algorithms, place them in `scripts/utils/GraphAlgorithms.gd` to keep `SocialGraphManager` lean.

## Roadmap / TODO
- Flesh out `GameManager`, `TimeManager`, and `EventSystem` to orchestrate daily cycles and log interactions.
- Implement interaction outcomes (positive/negative) that feed into `RelationshipComponent.update_affinity` with richer context.
- Populate the world with tile data, simple pathfinding, and NPC spawn logic.
- Build real-time graph visualization and HUD metrics (e.g., most social NPCs, community detection).
- Add saving/loading of social graph state and configurable simulation parameters.
- Integrate automated tests or debug scenes to validate graph dynamics and behavior transitions.

## Contributing Workflow
1. Create a feature branch; keep commits scoped to a single system when possible.
2. Update or add scenes/scripts using Godot 4.x; ensure the project still opens without warnings.
3. Run the simulation (`F5`) to verify there are no runtime errors or graph inconsistencies.
4. Document noteworthy systems or tuning knobs in this README or inline comments.

Happy simulating!
