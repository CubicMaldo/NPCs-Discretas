# Guía de Grafos Dirigidos - Sistema Social de NPCs

## 📋 Resumen

El sistema de grafos sociales ha sido convertido de **no dirigido** a **dirigido**, permitiendo relaciones asimétricas entre NPCs. Esto significa que:

- **A puede conocer a B sin que B conozca a A**
- Cada dirección de una relación puede tener diferente intensidad
- Las relaciones bidireccionales deben crearse explícitamente

---

## 🎯 Conceptos Clave

### Grafo Dirigido
- **Arista dirigida (A→B)**: A conoce a B
- **No implica reciprocidad**: B puede no conocer a A
- **Pesos independientes**: Si A→B y B→A existen, pueden tener valores diferentes

### Familiaridad/Conocimiento
- Rango: `[0..100]`
- Representa qué tanto un NPC conoce o confía en otro
- Es **direccional**: La familiaridad de A hacia B puede diferir de la de B hacia A

---

## 🔧 API Principal

### 1. Crear Relaciones Dirigidas

#### Relación Unidireccional (A conoce a B)
```gdscript
# Alice conoce a Bob, pero Bob NO conoce a Alice
social_graph.connect_npcs("Alice", "Bob", 75.0)

# O desde el manager
manager.add_connection("Alice", "Bob", 75.0)
```

**Resultado:**
- ✅ Arista: Alice→Bob (peso: 75.0)
- ❌ NO existe: Bob→Alice

#### Relación Bidireccional (Ambos se conocen)
```gdscript
# Método 1: Crear ambas direcciones manualmente
social_graph.connect_npcs("Alice", "Bob", 80.0)
social_graph.connect_npcs("Bob", "Alice", 60.0)

# Método 2: Usar helper de conexión mutua (RECOMENDADO)
social_graph.connect_npcs_mutual("Alice", "Bob", 80.0, 60.0)
# O desde el manager
manager.add_connection_mutual("Alice", "Bob", 80.0, 60.0)

# Método 3: Pesos simétricos (mismo valor en ambas direcciones)
social_graph.connect_npcs_mutual("Carol", "Dave", 90.0)  # Ambos 90.0
```

**Resultado del Método 2:**
- ✅ Arista: Alice→Bob (peso: 80.0)
- ✅ Arista: Bob→Alice (peso: 60.0)

---

### 2. Consultar Relaciones

#### Verificar Existencia de Arista
```gdscript
# Verificar si existe A→B (dirigido)
if social_graph.has_edge("Alice", "Bob"):
    print("Alice conoce a Bob")

# NO implica que Bob→Alice exista
if not social_graph.has_edge("Bob", "Alice"):
    print("Bob NO conoce a Alice")
```

#### Obtener Familiaridad
```gdscript
# Obtener familiaridad dirigida A→B
var familiarity_a_to_b = social_graph.get_familiarity("Alice", "Bob")
var familiarity_b_to_a = social_graph.get_familiarity("Bob", "Alice", 0.0)  # Default si no existe

print("Alice conoce a Bob: ", familiarity_a_to_b)
print("Bob conoce a Alice: ", familiarity_b_to_a)
```

#### Obtener Vecinos (Aristas Salientes)
```gdscript
# Obtiene SOLO las aristas salientes de Alice (a quién conoce Alice)
var neighbors = social_graph.get_cached_neighbors("Alice")
# neighbors = {"Bob": 80.0, "Carol": 70.0, ...}

# Grado saliente (out-degree)
var out_degree = social_graph.get_cached_degree("Alice")
print("Alice conoce a ", out_degree, " personas")
```

**⚠️ Importante:** 
- `get_cached_neighbors()` solo devuelve aristas **salientes**
- Para saber quién conoce a Alice, necesitas iterar sobre todos los nodos

---

### 3. Modificar Relaciones

#### Actualizar Familiaridad
```gdscript
# Actualiza solo A→B
social_graph.set_familiarity("Alice", "Bob", 85.0)

# Para actualizar ambas direcciones:
social_graph.set_familiarity("Alice", "Bob", 85.0)
social_graph.set_familiarity("Bob", "Alice", 85.0)
```

#### Eliminar Arista
```gdscript
# Elimina solo A→B
social_graph.break_relationship("Alice", "Bob")

# Para eliminar relación bidireccional:
social_graph.break_relationship("Alice", "Bob")
social_graph.break_relationship("Bob", "Alice")
```

---

## 🧮 Algoritmos en Grafos Dirigidos

### Camino Más Corto (Dijkstra)
```gdscript
# Busca el camino dirigido más corto de A a B
var result = social_graph.get_shortest_path("Alice", "Eve")

if result.reachable:
    print("Camino: ", result.path)  # ["Alice", "Bob", "Carol", "Eve"]
    print("Distancia: ", result.distance)
else:
    print("No hay camino dirigido de Alice a Eve")
```

**⚠️ Importante:** Solo encuentra caminos que sigan las direcciones de las aristas.

### Camino Más Fuerte
```gdscript
# Busca el camino con mayor confianza acumulada (producto de familiaridades)
var result = social_graph.get_strongest_path("Alice", "Eve")

if result.reachable:
    print("Camino más confiable: ", result.path)
    print("Fuerza del camino: ", result.strength)  # 0.0 a 1.0
```

### Amigos Mutuos
```gdscript
# Encuentra nodos que AMBOS conocen (vecinos salientes comunes)
var result = social_graph.get_mutual_connections("Alice", "Bob", 50.0)

print("Amigos mutuos: ", result.count)
for entry in result.entries_ids:
    print("  - ", entry.neighbor_id, " (avg: ", entry.average_weight, ")")
```

**Nota:** En grafo dirigido, busca nodos donde tanto A→N como B→N existen.

### Propagación de Rumor
```gdscript
# Simula cómo un rumor se propaga siguiendo aristas dirigidas
var result = social_graph.simulate_rumor("Alice", 3, 0.6, 0.05)

print("Nodos alcanzados: ", result.reached)
for npc_id in result.influence_ids:
    var influence = result.influence_ids[npc_id]
    print(npc_id, " tiene influencia: ", influence)
```

**⚠️ Importante:** El rumor SOLO se propaga en la dirección de las aristas (A→B→C).

---

## 📊 Ejemplos Prácticos

### Escenario 1: Relaciones Asimétricas (Espionaje)
```gdscript
# El espía conoce al guardia, pero el guardia no lo conoce
social_graph.connect_npcs("Spy", "Guard", 85.0)

# Verificar
assert(social_graph.has_edge("Spy", "Guard"))
assert(not social_graph.has_edge("Guard", "Spy"))

# El espía puede obtener información del guardia
var info = social_graph.get_neighbor_attribute_map("Spy", "faction")
print("El espía conoce a: ", info.keys())  # ["Guard"]

# Pero el guardia no sabe nada del espía
var guard_knows = social_graph.get_cached_neighbors("Guard")
print("El guardia conoce a: ", guard_knows.keys())  # []
```

### Escenario 2: Amistad con Diferentes Niveles de Confianza
```gdscript
# Alice confía mucho en Bob (80), pero Bob confía poco en Alice (40)
social_graph.connect_npcs_mutual("Alice", "Bob", 80.0, 40.0)

# Verificar asimetría
var alice_to_bob = social_graph.get_familiarity("Alice", "Bob")  # 80.0
var bob_to_alice = social_graph.get_familiarity("Bob", "Alice")  # 40.0

print("Relación asimétrica: ", alice_to_bob, " vs ", bob_to_alice)

# Esto afecta algoritmos como el camino más fuerte
var path_a_to_b = social_graph.get_strongest_path("Alice", "Bob")
var path_b_to_a = social_graph.get_strongest_path("Bob", "Alice")
# Pueden tener diferentes fuerzas
```

### Escenario 3: Red de Información Dirigida
```gdscript
# Crear una jerarquía de información: Líder → Capitán → Soldados
social_graph.connect_npcs("Leader", "Captain", 100.0)
social_graph.connect_npcs("Captain", "Soldier1", 90.0)
social_graph.connect_npcs("Captain", "Soldier2", 90.0)

# Los soldados NO conocen al líder directamente
assert(not social_graph.has_edge("Soldier1", "Leader"))

# Propagar un rumor desde el líder
var result = social_graph.simulate_rumor("Leader", 3, 0.8, 0.05)

print("Rumor alcanzó a: ", result.reached)
# ["Leader", "Captain", "Soldier1", "Soldier2"]

# Verificar influencia
print("Influencia en Soldier1: ", result.influence_ids.get("Soldier1"))
# La influencia se atenúa en cada salto
```

---

## 🔄 Migración desde Sistema No Dirigido

### ⚠️ Cambios Importantes

#### ANTES (No Dirigido):
```gdscript
# Una sola llamada creaba arista bidireccional automáticamente
social_graph.connect_npcs("Alice", "Bob", 80.0)
# Resultado: Alice↔Bob (80.0 en ambas direcciones)
```

#### AHORA (Dirigido):
```gdscript
# Crea SOLO Alice→Bob
social_graph.connect_npcs("Alice", "Bob", 80.0)
# Resultado: Alice→Bob (NO existe Bob→Alice)

# Para bidireccional, usar:
social_graph.connect_npcs_mutual("Alice", "Bob", 80.0)
# Resultado: Alice↔Bob (80.0 en ambas direcciones)
```

### Actualizar Código Existente

#### Patrón 1: Reemplazar `connect_npcs` por `connect_npcs_mutual`
```gdscript
# ANTES
social_graph.connect_npcs(npc_a, npc_b, familiarity)

# DESPUÉS (si quieres mantener comportamiento bidireccional)
social_graph.connect_npcs_mutual(npc_a, npc_b, familiarity)
```

#### Patrón 2: Usar el nuevo manager API
```gdscript
# ANTES
manager.add_connection(npc_a, npc_b, 75.0)

# DESPUÉS (comportamiento dirigido)
manager.add_connection(npc_a, npc_b, 75.0)  # Solo A→B

# O para bidireccional
manager.add_connection_mutual(npc_a, npc_b, 75.0)  # A↔B
```

---

## 🧪 Testing

### Tests Incluidos
El sistema incluye tests exhaustivos en `TestSocialGraph.gd`:

1. **`_test_directed_graph_behavior`**: Verifica relaciones asimétricas
2. **`_test_mutual_connection_helper`**: Prueba conexiones bidireccionales
3. **`_test_caching_layer`**: Valida que el caché solo almacena aristas salientes
4. **`_test_shortest_path`**: Confirma que no hay caminos inversos
5. **`_test_strongest_path`**: Verifica direccionalidad en caminos fuertes
6. Todos los demás tests actualizados para grafos dirigidos

### Ejecutar Tests
```gdscript
# Los tests se ejecutan automáticamente en _ready() del nodo TestSocialGraph
# O puedes ejecutarlos manualmente:
var test_suite = TestSocialGraph.new()
test_suite._ready()
```

---

## 📚 Referencias de API

### SocialGraph
- `connect_npcs(a, b, familiarity)` - Arista dirigida A→B
- `connect_npcs_mutual(a, b, fam_a_b, fam_b_a)` - Aristas bidireccionales
- `has_edge(a, b)` - Verifica existencia de A→B
- `get_familiarity(a, b)` - Obtiene peso de A→B
- `break_relationship(a, b)` - Elimina arista A→B
- `get_cached_neighbors(key)` - Vecinos salientes (out-neighbors)
- `get_cached_degree(key)` - Grado saliente (out-degree)

### SocialGraphManager
- `add_connection(a, b, affinity)` - Arista dirigida A→B
- `add_connection_mutual(a, b, aff_ab, aff_ba)` - Bidireccional **[NUEVO]**
- `remove_connection(a, b)` - Elimina A→B
- `get_shortest_path(a, b)` - Camino dirigido más corto
- `get_strongest_path(a, b)` - Camino dirigido más fuerte
- `simulate_rumor(seed, steps, attenuation, min_strength)` - Propagación dirigida

### GraphAlgorithms
- `shortest_path(graph, source, target)` - Dijkstra dirigido
- `shortest_path_bellman_ford(graph, source, target)` - Bellman-Ford dirigido
- `strongest_path(graph, source, target)` - Camino más fuerte dirigido
- `mutual_metrics(graph, a, b, min_weight)` - Vecinos salientes comunes
- `propagate_rumor(graph, seed, steps, attenuation, min_strength)` - Propagación dirigida

---

## 💡 Mejores Prácticas

### 1. Usa `connect_npcs_mutual()` para Amistades Normales
```gdscript
# ✅ RECOMENDADO para amistades recíprocas
social_graph.connect_npcs_mutual("Alice", "Bob", 80.0)

# ❌ EVITAR (requiere dos llamadas)
social_graph.connect_npcs("Alice", "Bob", 80.0)
social_graph.connect_npcs("Bob", "Alice", 80.0)
```

### 2. Usa `connect_npcs()` Solo para Relaciones Asimétricas
```gdscript
# ✅ CORRECTO para espionaje, jerarquías, etc.
social_graph.connect_npcs("Spy", "Target", 90.0)
# El target NO conoce al espía
```

### 3. Verifica Ambas Direcciones si es Necesario
```gdscript
# ✅ Verificar relación bidireccional completa
func are_mutual_friends(a, b) -> bool:
    return social_graph.has_edge(a, b) and social_graph.has_edge(b, a)
```

### 4. Considera la Direccionalidad en Algoritmos
```gdscript
# ✅ Los caminos respetan direccionalidad
var path = social_graph.get_shortest_path(a, b)
# Puede ser diferente de:
var reverse_path = social_graph.get_shortest_path(b, a)
```

---

## 🐛 Debugging

### Visualizar Relaciones de un NPC
```gdscript
func debug_npc_relationships(npc_key):
    print("=== Relaciones de ", npc_key, " ===")
    
    # Aristas salientes (a quién conoce)
    var out_neighbors = social_graph.get_cached_neighbors(npc_key)
    print("Conoce a (aristas salientes):")
    for neighbor in out_neighbors:
        print("  → ", neighbor, " (", out_neighbors[neighbor], ")")
    
    # Para ver quién lo conoce, necesitas buscar en todo el grafo
    print("Es conocido por (aristas entrantes):")
    var all_nodes = social_graph.get_nodes()
    for node_key in all_nodes:
        if social_graph.has_edge(node_key, npc_key):
            var weight = social_graph.get_edge(node_key, npc_key)
            print("  ← ", node_key, " (", weight, ")")
```

### Validar Integridad del Grafo
```gdscript
# Ejecutar validaciones integradas
var validation = social_graph.validate_graph()
print("Validación: ", validation)

# Reparar inconsistencias si es necesario
if validation.get("errors", []).size() > 0:
    var repair_result = social_graph.repair_graph()
    print("Reparaciones: ", repair_result)
```

---

## 📈 Rendimiento

### Ventajas de Grafos Dirigidos
- ✅ **Menor uso de memoria**: Solo se almacenan las aristas que existen
- ✅ **Mayor flexibilidad**: Relaciones asimétricas sin overhead
- ✅ **Caché más eficiente**: Solo vecinos salientes

### Consideraciones
- ⚠️ Para encontrar vecinos entrantes (quién conoce a X), necesitas iterar el grafo
- ⚠️ Algoritmos bidireccionales requieren verificar ambas direcciones explícitamente

---

## 🔮 Casos de Uso Avanzados

### Jerarquías Organizacionales
```gdscript
# Líder → Oficiales → Soldados
for officer in officers:
    social_graph.connect_npcs("Leader", officer, 100.0)
    for soldier in officer.subordinates:
        social_graph.connect_npcs(officer, soldier, 90.0)

# Los soldados no tienen acceso directo al líder
assert(not social_graph.has_edge("Soldier1", "Leader"))
```

### Redes de Espionaje
```gdscript
# Agentes conocen objetivos, pero objetivos no conocen agentes
for agent in agents:
    for target in targets:
        social_graph.connect_npcs(agent, target, 80.0)
        # NO se crea la arista inversa
```

### Difusión de Información Asimétrica
```gdscript
# Fuente confiable → Intermediarios → Población
social_graph.connect_npcs("Source", "Intermediary1", 100.0)
social_graph.connect_npcs("Source", "Intermediary2", 100.0)

for intermediary in intermediaries:
    for citizen in citizens:
        # Credibilidad decreciente
        social_graph.connect_npcs(intermediary, citizen, 60.0)
```

---

## 📞 Soporte y Contribuciones

Este sistema está diseñado para ser extensible. Si necesitas:
- Algoritmos adicionales para grafos dirigidos
- Visualización de relaciones asimétricas
- Optimizaciones de rendimiento

Consulta la documentación de código en:
- `scripts/utils/Graph.gd`
- `scripts/systems/SocialGraph.gd`
- `scripts/utils/GraphAlgorithms.gd`
- `scripts/systems/SocialGraphManager.gd`

---

**¡Disfruta del nuevo sistema de grafos dirigidos!** 🎮🚀
