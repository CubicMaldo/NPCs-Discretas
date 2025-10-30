extends Node
## Ejemplos de uso del sistema de grafos dirigidos para relaciones sociales entre NPCs.
##
## Este script contiene ejemplos prácticos y casos de uso comunes del nuevo sistema
## de grafos dirigidos. Ejecuta `run_all_examples()` para ver todos los ejemplos.

const SocialGraphClass = preload("res://scripts/systems/SocialGraph.gd")

## Ejecuta todos los ejemplos de manera secuencial.
func run_all_examples() -> void:
	print("\n" + "=".repeat(80))
	print("EJEMPLOS DE GRAFOS DIRIGIDOS - SISTEMA SOCIAL")
	print("=".repeat(80))
	
	example_1_basic_directed_edge()
	example_2_bidirectional_relationship()
	example_3_asymmetric_trust()
	example_4_espionage_network()
	example_5_organizational_hierarchy()
	example_6_information_flow()
	example_7_rumor_propagation()
	example_8_shortest_path()
	example_9_strongest_path()
	example_10_mutual_friends()
	
	print("\n" + "=".repeat(80))
	print("TODOS LOS EJEMPLOS COMPLETADOS")
	print("=".repeat(80) + "\n")


## Ejemplo 1: Crear una arista dirigida básica (A conoce a B, pero B no conoce a A)
func example_1_basic_directed_edge() -> void:
	print("\n--- EJEMPLO 1: Arista Dirigida Básica ---")
	
	var graph := SocialGraphClass.new()
	
	# Alice conoce a Bob, pero Bob NO conoce a Alice
	graph.connect_npcs("Alice", "Bob", 75.0)
	
	# Verificar direccionalidad
	print("Alice conoce a Bob: ", graph.has_edge("Alice", "Bob"))  # true
	print("Bob conoce a Alice: ", graph.has_edge("Bob", "Alice"))  # false
	
	# Obtener familiaridad
	var alice_to_bob = graph.get_familiarity("Alice", "Bob")
	var bob_to_alice = graph.get_familiarity("Bob", "Alice", 0.0)
	
	print("Familiaridad Alice→Bob: ", alice_to_bob)  # 75.0
	print("Familiaridad Bob→Alice: ", bob_to_alice)  # 0.0 (no existe)
	
	# Vecinos
	var alice_neighbors = graph.get_cached_neighbors("Alice")
	var bob_neighbors = graph.get_cached_neighbors("Bob")
	
	print("Alice conoce a: ", alice_neighbors.keys())  # ["Bob"]
	print("Bob conoce a: ", bob_neighbors.keys())     # []


## Ejemplo 2: Crear relación bidireccional (ambos se conocen mutuamente)
func example_2_bidirectional_relationship() -> void:
	print("\n--- EJEMPLO 2: Relación Bidireccional ---")
	
	var graph := SocialGraphClass.new()
	
	# Método 1: Crear ambas direcciones manualmente
	graph.connect_npcs("Alice", "Bob", 80.0)
	graph.connect_npcs("Bob", "Alice", 80.0)
	
	# Método 2 (RECOMENDADO): Usar helper de conexión mutua
	graph.connect_npcs_mutual("Carol", "Dave", 90.0)
	
	# Verificar relaciones bidireccionales
	print("Alice ↔ Bob:")
	print("  Alice→Bob: ", graph.get_familiarity("Alice", "Bob"))  # 80.0
	print("  Bob→Alice: ", graph.get_familiarity("Bob", "Alice"))  # 80.0
	
	print("Carol ↔ Dave:")
	print("  Carol→Dave: ", graph.get_familiarity("Carol", "Dave"))  # 90.0
	print("  Dave→Carol: ", graph.get_familiarity("Dave", "Carol"))  # 90.0


## Ejemplo 3: Confianza asimétrica (A confía en B más que B en A)
func example_3_asymmetric_trust() -> void:
	print("\n--- EJEMPLO 3: Confianza Asimétrica ---")
	
	var graph := SocialGraphClass.new()
	
	# Alice confía mucho en Bob (80), pero Bob confía poco en Alice (40)
	graph.connect_npcs_mutual("Alice", "Bob", 80.0, 40.0)
	
	var alice_to_bob = graph.get_familiarity("Alice", "Bob")
	var bob_to_alice = graph.get_familiarity("Bob", "Alice")
	
	print("Relación asimétrica:")
	print("  Alice→Bob (alta confianza): ", alice_to_bob)  # 80.0
	print("  Bob→Alice (baja confianza): ", bob_to_alice)  # 40.0
	print("  Diferencia: ", alice_to_bob - bob_to_alice)   # 40.0
	
	# Esto afecta algoritmos como el camino más fuerte
	var path_a_to_b = graph.get_strongest_path("Alice", "Bob")
	var path_b_to_a = graph.get_strongest_path("Bob", "Alice")
	
	print("Fuerza del camino Alice→Bob: ", path_a_to_b.strength)  # 0.8
	print("Fuerza del camino Bob→Alice: ", path_b_to_a.strength)  # 0.4


## Ejemplo 4: Red de espionaje (agentes conocen objetivos, pero no al revés)
func example_4_espionage_network() -> void:
	print("\n--- EJEMPLO 4: Red de Espionaje ---")
	
	var graph := SocialGraphClass.new()
	
	# Agentes espías
	var agents = ["Agent007", "AgentX", "AgentY"]
	var targets = ["Guard1", "Guard2", "Merchant"]
	
	# Los agentes conocen a sus objetivos (información recopilada)
	for agent in agents:
		for target in targets:
			graph.connect_npcs(agent, target, 85.0)
	
	# Los objetivos NO conocen a los agentes
	print("Agent007 conoce a Guard1: ", graph.has_edge("Agent007", "Guard1"))  # true
	print("Guard1 conoce a Agent007: ", graph.has_edge("Guard1", "Agent007"))  # false
	
	# Análisis de inteligencia
	var agent_intel = graph.get_cached_neighbors("Agent007")
	print("Agent007 tiene inteligencia sobre: ", agent_intel.keys())
	# ["Guard1", "Guard2", "Merchant"]
	
	var guard_knows = graph.get_cached_neighbors("Guard1")
	print("Guard1 conoce a: ", guard_knows.keys())  # [] (no sabe nada)


## Ejemplo 5: Jerarquía organizacional (cadena de mando)
func example_5_organizational_hierarchy() -> void:
	print("\n--- EJEMPLO 5: Jerarquía Organizacional ---")
	
	var graph := SocialGraphClass.new()
	
	# Estructura: Líder → Capitanes → Soldados
	graph.connect_npcs("Leader", "Captain1", 100.0)
	graph.connect_npcs("Leader", "Captain2", 100.0)
	
	graph.connect_npcs("Captain1", "Soldier1", 90.0)
	graph.connect_npcs("Captain1", "Soldier2", 90.0)
	graph.connect_npcs("Captain2", "Soldier3", 90.0)
	
	# Los soldados NO tienen acceso directo al líder
	print("Leader conoce a Captain1: ", graph.has_edge("Leader", "Captain1"))     # true
	print("Captain1 conoce a Soldier1: ", graph.has_edge("Captain1", "Soldier1")) # true
	print("Soldier1 conoce a Leader: ", graph.has_edge("Soldier1", "Leader"))     # false
	
	# Camino de comunicación
	var path = graph.get_shortest_path("Leader", "Soldier1")
	if path.reachable:
		print("Cadena de mando Leader→Soldier1: ", path.path)
		# ["Leader", "Captain1", "Soldier1"]
	
	# Camino inverso no existe
	var reverse = graph.get_shortest_path("Soldier1", "Leader")
	print("Soldier1 puede contactar a Leader: ", reverse.reachable)  # false


## Ejemplo 6: Flujo de información direccional
func example_6_information_flow() -> void:
	print("\n--- EJEMPLO 6: Flujo de Información ---")
	
	var graph := SocialGraphClass.new()
	
	# Fuente de información → Intermediarios → Consumidores
	graph.connect_npcs("NewsSource", "Reporter1", 100.0)
	graph.connect_npcs("NewsSource", "Reporter2", 100.0)
	
	graph.connect_npcs("Reporter1", "Citizen1", 70.0)
	graph.connect_npcs("Reporter1", "Citizen2", 70.0)
	graph.connect_npcs("Reporter2", "Citizen3", 70.0)
	
	# Análisis de alcance de información
	print("NewsSource informa a:")
	var direct_reach = graph.get_cached_neighbors("NewsSource")
	print("  Directo: ", direct_reach.keys())  # ["Reporter1", "Reporter2"]
	
	# Alcance indirecto (2 saltos)
	var reporter1_reach = graph.get_cached_neighbors("Reporter1")
	print("  Via Reporter1: ", reporter1_reach.keys())  # ["Citizen1", "Citizen2"]
	
	# Verificar que la información no fluye hacia atrás
	print("Citizen1 puede informar a NewsSource: ", 
		  graph.has_edge("Citizen1", "NewsSource"))  # false


## Ejemplo 7: Propagación de rumor direccional
func example_7_rumor_propagation() -> void:
	print("\n--- EJEMPLO 7: Propagación de Rumor ---")
	
	var graph := SocialGraphClass.new()
	
	# Crear red social dirigida
	graph.connect_npcs("Alice", "Bob", 100.0)
	graph.connect_npcs("Bob", "Carol", 80.0)
	graph.connect_npcs("Carol", "Dave", 60.0)
	graph.connect_npcs("Bob", "Eve", 70.0)
	
	# Simular rumor desde Alice
	var result: Dictionary = graph.simulate_rumor("Alice", 3, 0.7, 0.05)

	print("Rumor iniciado por Alice:")
	print("  Nodos alcanzados: ", result.get("reached", []))

	# Mostrar influencia en cada nodo
	var influence_map: Dictionary = result.get("influence", {})
	for node in influence_map:
		var influence = influence_map[node]
		print("  ", node, ": ", "%.2f" % influence, " (", "%.0f" % (influence * 100), "%)")
	
	# El rumor NO se propaga hacia atrás
	# Si Dave inicia el rumor, NO alcanza a Alice
	var reverse_result: Dictionary = graph.simulate_rumor("Dave", 3, 0.7, 0.05)
	print("Rumor iniciado por Dave alcanza a Alice: ", "Alice" in (reverse_result.get("reached", [])))  # false


## Ejemplo 8: Camino más corto en grafo dirigido
func example_8_shortest_path() -> void:
	print("\n--- EJEMPLO 8: Camino Más Corto Dirigido ---")
	
	var graph := SocialGraphClass.new()
	
	# Crear red con múltiples caminos
	graph.connect_npcs("A", "B", 1.0)
	graph.connect_npcs("B", "C", 1.0)
	graph.connect_npcs("C", "D", 1.0)
	graph.connect_npcs("A", "E", 2.0)
	graph.connect_npcs("E", "D", 1.0)
	graph.connect_npcs("A", "D", 10.0)  # Camino directo pero costoso
	
	# Encontrar camino más corto
	var result = graph.get_shortest_path("A", "D")
	
	if result.reachable:
		print("Camino más corto A→D:")
		print("  Ruta: ", result.path)          # ["A", "E", "D"]
		print("  Distancia: ", result.distance)  # 3.0
	
	# Verificar que no hay camino inverso (grafo dirigido)
	var reverse = graph.get_shortest_path("D", "A")
	print("Existe camino D→A: ", reverse.reachable)  # false


## Ejemplo 9: Camino más fuerte (máxima confianza acumulada)
func example_9_strongest_path() -> void:
	print("\n--- EJEMPLO 9: Camino Más Fuerte ---")
	
	var graph := SocialGraphClass.new()
	
	# Crear red con diferentes niveles de confianza
	# Camino directo: A→D (50% confianza)
	# Camino via B: A→B→D (80% * 90% = 72% confianza)
	graph.connect_npcs("A", "B", 80.0)
	graph.connect_npcs("B", "D", 90.0)
	graph.connect_npcs("A", "D", 50.0)
	
	var result = graph.get_strongest_path("A", "D")
	
	if result.reachable:
		print("Camino más fuerte A→D:")
		print("  Ruta: ", result.path)                      # ["A", "B", "D"]
		print("  Fuerza: ", "%.2f" % result.strength)       # 0.72 (72%)
		print("  Confianza: ", "%.0f" % (result.strength * 100), "%")
		
		# Comparar con camino directo
		var direct = graph.get_familiarity("A", "D") / 100.0
		print("  Directo A→D: ", "%.2f" % direct, " (", "%.0f" % (direct * 100), "%)")


## Ejemplo 10: Amigos mutuos en grafo dirigido
func example_10_mutual_friends() -> void:
	print("\n--- EJEMPLO 10: Amigos Mutuos ---")
	
	var graph := SocialGraphClass.new()
	
	# Crear red social con relaciones bidireccionales y dirigidas
	graph.connect_npcs_mutual("Alice", "Bob", 80.0, 80.0)
	graph.connect_npcs_mutual("Alice", "Carol", 70.0, 70.0)
	graph.connect_npcs_mutual("Bob", "Carol", 75.0, 75.0)
	
	# Dave solo conoce a Alice (unidireccional)
	graph.connect_npcs("Alice", "Dave", 60.0)
	
	# Encontrar amigos mutuos de Alice y Bob
	var result = graph.get_mutual_connections("Alice", "Bob", 50.0)
	
	print("Amigos mutuos de Alice y Bob:")
	print("  Total: ", result.count)  # 1 (Carol)
	
	for entry in result.entries:
		print("  - ", entry.neighbor)
		print("    Alice→", entry.neighbor, ": ", entry.weight_a)
		print("    Bob→", entry.neighbor, ": ", entry.weight_b)
		print("    Promedio: ", entry.average_weight)
	
	# Dave NO es amigo mutuo (solo Alice lo conoce)
	var has_dave = false
	for entry in result.entries:
		if entry.neighbor == "Dave":
			has_dave = true
	print("  Dave es amigo mutuo: ", has_dave)  # false


## Función auxiliar para ejecutar los ejemplos desde la línea de comandos
func _ready() -> void:
	# Descomentar para ejecutar automáticamente al cargar el nodo
	# run_all_examples()
	pass
