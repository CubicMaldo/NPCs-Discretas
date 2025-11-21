class_name InteractionConfig
extends Resource

## Configuration for social interaction values.
## Allows designers to tune gameplay without touching code.

@export_group("Familiarity Deltas")
@export var talk_familiarity_gain: float = 5.0
@export var talk_familiarity_loss: float = -5.0
@export var fight_familiarity_loss: float = -25.0
@export var base_interaction_value: float = 2.0

@export_group("Probabilities")
@export_range(0.0, 1.0) var bad_talk_chance: float = 0.1
