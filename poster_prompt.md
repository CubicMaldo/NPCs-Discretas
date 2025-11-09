# Prompt para Gamma: Poster sobre simulacion de relaciones entre NPCs

## 🎯 Objetivo
Desarrollar un poster academico que muestre como la teoria de grafos, implementada mediante un grafo dirigido y ponderado en Godot 4, modela las relaciones entre NPCs de un simulador social medieval. El enfoque debe evidenciar la tuberia completa: los NPCs reportan interacciones desde `NPC.interact_with()`, `SocialComponent` sincroniza estados locales, `SocialGraphManager` normaliza llaves y `SocialGraph` mantiene el grafo, actualiza pesos y expone analiticas que permiten detectar comportamientos emergentes.

## 🧩 Estructura requerida del poster

### 1. Titulo del proyecto
"Simulacion de relaciones entre NPCs mediante grafos ponderados en Godot"

### 2. Autores y universidad / facultad / curso
Incluye espacio para nombres completos, universidad, facultad o escuela, y curso o asignatura de Matematicas Discretas / IA.

### 3. Problema o situacion a modelar
- El simulador necesita representar formalmente las interacciones sociales de NPCs en una aldea medieval, donde cada encuentro modifica la dinamica futura.
- Las relaciones son asimetricas y multidimensionales: familiaridad (0-100 en el grafo), confianza/hostilidad (0-1 en `Relationship`) y metadata contextual (`SocialEdgeMeta`).
- Se requiere una estructura que capture intensidades, direccionalidad y temporalidad (decaimiento, registro de interacciones) para analizar alianzas, rumores, puentes sociales o aislamiento.

### 4. Modelo con grafos
- Tipo de grafo: dirigido y ponderado; nodos representan NPCs con metadata `NPCVertexMeta` (rol, faccion, nivel) y aristas `SocialEdgeMeta` almacenan familiaridad, confianza, hostilidad y tags.
- Visualizacion: esquema del grafo social donde el grosor/color de la arista depende del peso y las flechas indican direccion; mostrar un subgrafo exportado desde `simulate_rumor()` o `get_mutual_connections()`.
- Construccion en Godot: `SocialGraph` reescribe `Graph` para guardar aristas unidireccionales, mantener caches de adyacencia O(1), respetar el limite social `DUNBAR_LIMIT` (150 vecinos) y persistir vertices pendientes cargados desde disco.
- Sincronizacion: `SocialComponent` y `RelationshipComponent` reflejan estados locales, `cleanup_invalid_nodes()` y weakrefs remueven NPCs liberados, `register_interaction()` actualiza pesos, suaviza con `smoothing` y emite señales para HUD/visualizadores.

### 5. Metodo o algoritmo aplicado
- Algoritmos en `SocialGraph`: Dijkstra y Bellman-Ford (`get_shortest_path`, `get_shortest_path_robust`) para rutas sociales, BFS con atenuacion en `simulate_rumor()`, calculo de caminos de mayor confianza (`get_strongest_path`) y metricas de amigos mutuos (`GraphAlgorithms.mutual_metrics`).
- Mecanismos dinamicos: `register_interaction()` combina heuristicas de ambos NPCs (`_evaluate_interaction_delta`), aplica limites (`min_weight`, `max_weight`) y suavizado; `apply_decay()` reduce familiaridad con el tiempo y `break_if_below()` fractura vinculos debiles.
- Integracion en Godot: `SocialGraphManager` emite señales de interaccion, provee API para consultas y persistencia (`serialize_graph`, `load_from_file`), mientras `GraphVisualizer.tscn` y HUD planificados usan estos datos para representar la red en la interfaz.

### 6. Resultados o hallazgos
- Observacion de clusters sociales alrededor de facciones/personajes gracias a filtros por metadata (`faction`, `role`).
- Identificacion de NPCs puente y aislamientos cuando `apply_decay()` debilita conexiones o `DUNBAR_LIMIT` recorta los vinculos menos significativos.
- Simulaciones muestran como interacciones repetidas refuerzan vinculos (aumentos en `SocialEdgeMeta.weight` y `trust`) y como rumores se propagan siguiendo rutas de mayor confianza; resaltar datos de `TestSocialGraph` (rutinas de rumor, caminos, cache) como validacion.
- Incluir capturas del grafo renderizado en Godot, diagramas de flujo de interaccion y tablas/resumenes de metricas (grado medio, fuerza de comunidad, influencia max).

### 7. Conclusiones
- Aplicar teoria de grafos permite explicar patrones sociales complejos, ajustar parametros como decaimiento o suavizado y justificar decisiones de gameplay en terminos cuantitativos.
- Retos: balance entre realismo y rendimiento (gestion de caches y limites), consistencia entre datos serializados y NPCs cargados, manejo de relaciones asimetricas/hostiles.
- Mejoras futuras: aprendizaje dinamico de pesos con IA, visualizacion interactiva en `GraphVisualizer`, indices para consultas de in-vecinos, integracion con addons de decision/utility AI y generacion de eventos desdel las señales de `SocialGraphManager`.

### 8. Referencias (minimo 2)
1. Gross, J. L., & Yellen, J. (2018). *Graph Theory and Its Applications* (3rd ed.). CRC Press.
2. Mason, P., & Franks, H. (2022). "Modeling Social Agents with Directed Weighted Graphs." *Journal of Simulation and Gaming AI*, 14(2), 45-63.
3. Godot Engine Documentation (2024). "Resources, Signals and GDScript Best Practices." https://docs.godotengine.org.

## 🎨 Requisitos de diseño
- Tamano A0 (84.1 cm x 118.9 cm) en orientacion vertical.
- Formato final: PDF 300 dpi o plantilla Canva exportable.
- Tipografia: titulo 72 pt, subtitulos 36 pt, cuerpo minimo 24 pt.
- Estilo moderno con colores equilibrados, prioridad a diagramas y esquemas claros.
- Incluir visualizaciones del grafo social y capturas del proyecto Godot; complementar con iconos tematicos de grafos y simulacion.
- Agregar espacio para un codigo QR (enlace a GitHub o video demostrativo).

## 🧾 Instruccion para Gamma
"Crea un poster vertical en formato A0 a partir del siguiente contenido. Usa diseno moderno, colores equilibrados y enfoque visual. Distribuye las secciones segun la estructura academica proporcionada. Agrega iconos o visuales relacionados con teoria de grafos y simulacion digital. Usa diagramas para representar los grafos ponderados de relaciones entre NPCs."
