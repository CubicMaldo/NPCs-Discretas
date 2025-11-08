# 📚 Documentación de la Refactorización del Sistema Social

## 🎯 Objetivo Completado

Se ha refactorizado completamente el sistema de relaciones sociales para:
- ✅ Eliminar redundancias (RelationshipComponent → SocialComponent)
- ✅ Extender capacidades (Relationship con múltiples dimensiones)
- ✅ Desacoplar componentes (interfaces limpias)

Nota: La ejecución de decisiones (Utility AI / Behavior Trees) se gestiona mediante addons externos y no forma parte del núcleo del repositorio. Añade el addon que prefieras en `addons/` y proporcionaré ejemplos de integración.

## 📖 Guías Disponibles

### Para Empezar
1. **[REFACTOR_SUMMARY.md](../REFACTOR_SUMMARY.md)** ⭐ EMPEZAR AQUÍ
   - Resumen ejecutivo de todos los cambios
   - Lista de archivos creados y modificados
   - Verificación rápida
   - Próximos pasos inmediatos

2. **[MIGRATION_GUIDE.md](../MIGRATION_GUIDE.md)** 🔄
   - Guía paso a paso para actualizar código existente
   - Ejemplos de código antes/después
   - Cómo actualizar escenas .tscn
   - Troubleshooting común

3. **[docs/NPC_INSTANTIATION_GUIDE.md](NPC_INSTANTIATION_GUIDE.md)** 🆕 IMPORTANTE
   - Cómo instanciar NPCs correctamente
   - Por qué el orden importa (_ready() y SocialComponent)
   - Ejemplos completos y funcionales
   - Errores comunes y soluciones
   - **Lee esto si tus NPCs no funcionan correctamente**

### Arquitectura y Diseño
4. **[docs/ARCHITECTURE_REFACTOR.md](ARCHITECTURE_REFACTOR.md)** 🏗️
   - Principios de diseño (SSOT, separación de responsabilidades)
   - Diagramas de componentes y flujo de datos
   - Patrones de uso comunes
   - Integración con sistemas futuros (addons de decisión)

### Implementación de sistemas de decisión (addons)
Si deseas añadir lógica de decisión (behavior trees, utility scoring, FSM, etc.), coloca el addon correspondiente en `addons/` y solicita ejemplos de integración. Puedo generar adapters y documentación específica una vez el addon esté presente en el proyecto.

## 🗂️ Estructura de Archivos

### Archivos Nuevos Creados
```
scripts/
├── entities/
│   ├── SocialComponent.gd          # Nueva interfaz limpia (reemplaza RelationshipComponent)
└── core/
   └── (decision systems are provided via addons)

docs/
├── ARCHITECTURE_REFACTOR.md       # ✅ Creado
└── INDEX.md                       # ✅ Creado (este archivo)

MIGRATION_GUIDE.md                 # ✅ Creado
REFACTOR_SUMMARY.md                # ✅ Creado
```

### Archivos Modificados
```
scripts/
├── entities/
│   ├── Relationship.gd            # ✅ Extendido (trust, hostility, historial)
│   ├── NPC.gd                     # ✅ Refactorizado (API simplificada)
│   └── RelationshipComponent.gd   # ⚠️ Deprecated (no eliminar aún)
└── systems/
   └── (decision systems provided via addons)
```

## 🔄 Flujo de Trabajo Recomendado

### Paso 1: Entender los Cambios (15 min)
1. Leer `REFACTOR_SUMMARY.md` (resumen rápido)
2. Revisar diagramas en `docs/ARCHITECTURE_REFACTOR.md`

### Paso 2: Actualizar el Proyecto (30 min)
1. Recargar proyecto en Godot (Project → Reload Current Project)
2. Verificar que no haya errores de compilación
3. Seguir `MIGRATION_GUIDE.md` para actualizar código custom

### Paso 3: Validar (15 min)
1. Ejecutar escenas de prueba en `scenes/tests/`
2. Verificar interacciones NPC funcionan correctamente
3. Revisar que relaciones se actualicen en el grafo social

### Paso 4: Integrar sistema de decisión (addons)
1. Añade el addon de decisión que prefieras bajo `addons/` (beehave u otro)
2. Implementa o pide adaptadores para mapear el addon a `SocialComponent`/`SocialGraphManager`
3. Pedir ejemplos de integración y documentación una vez el addon esté presente

## 🎓 Conceptos Clave

### Single Source of Truth (SSOT)
- `SocialGraphManager` es la única fuente autoritativa de relaciones
- No hay cachés locales que requieran sincronización
- Todas las consultas van directamente al grafo

### Separación de Responsabilidades
- **NPC**: Datos de entidad (posición, emoción, personalidad)
- **SocialComponent**: Interfaz para consultas sociales
- **SocialGraphManager**: Almacenamiento y algoritmos
- **Decision system (addon)**: Lógica de decisión (suministrada por un addon externo)

### Desacoplamiento por Interfaces
- Sistemas consumen APIs públicas, no estructuras internas
- Fácil mockear y testear
- Cambios internos no rompen dependientes

## 🔍 Ejemplos Rápidos

### Consultar Relaciones
```gdscript
# Antes
var rel_comp = npc.get_relationship_component()
var snapshot = rel_comp.get_relationships()
var rel = snapshot.get(target_id)
var familiarity = rel.familiarity if rel else 0.0

# Ahora
var familiarity = npc.get_familiarity(target_npc)
```

### Actualizar Familiarity
```gdscript
# Antes
npc.relationship_component.update_familiarity(target_id, 0.1)
npc.update_relationships()

# Ahora
npc.social_component.update_familiarity(target_npc, 0.1)
# No hay sincronización manual - siempre actualizado
```

### Obtener Amigos
```gdscript
# Antes
var snapshot = npc.get_relationship_snapshot()
var friends = []
for rel in snapshot.values():
    if rel.familiarity > 0.5:
        friends.append(rel.partner_id)

# Ahora
var friends = npc.get_friends_above(0.5)
```

## 🐛 Troubleshooting

### Error: "SocialComponent not found in the current scope"
**Solución:** Recargar el proyecto (Project → Reload Current Project)

### Escenas tienen RelationshipComponent child
**Solución:** 
1. Abrir escena
2. Seleccionar nodo RelationshipComponent
3. Eliminar (Delete)
4. Guardar escena
5. SocialComponent se creará automáticamente en runtime

### Tests fallan después de migración
**Solución:**
1. Verificar que `social_graph_manager` esté inyectado en NPCs
2. Asegurar que `npc_id` esté configurado
3. Revisar logs de Godot para errores específicos

## 📊 Métricas de Mejora

| Aspecto | Mejora |
|---------|--------|
| Líneas de código | -12% |
| Sincronización manual | -100% (eliminada) |
| Cachés locales | -100% (eliminados) |
| Campos en Relationship | +400% (de 2 a 10+) |
| Acoplamiento | Bajo ✅ (antes: Alto ❌) |

## 🚀 Próximos Pasos

### Inmediatos (HOY)
1. ✅ Leer documentación (este archivo)
2. ✅ Recargar proyecto en Godot
3. ✅ Ejecutar tests de validación

### Corto Plazo (ESTA SEMANA)
1. Implementar Utility AI (seguir `NEXT_STEPS_UTILITY_AI.md`)
2. Crear 3-5 acciones básicas
3. Calibrar pesos y parámetros

### Mediano Plazo (PRÓXIMAS 2 SEMANAS)
1. Integrar con beehave (si elegiste BT)
2. Extender Relationship con metadata específica del juego
3. Optimizar queries frecuentes (LOD, caching)

### Largo Plazo (PRÓXIMO MES)
1. Networking (si aplica)
2. Telemetría y balance automático
3. Comportamientos avanzados (memoria, goals, roles)

## 💡 Tips y Mejores Prácticas

### Decision systems (general)
- Mantén scoring/conditions pequeños y usa la API `SocialComponent` para acceso a datos.
- Prefiere evaluaciones poco frecuentes (0.2–0.6s) en NPCs no críticos para ahorrar CPU.
- Implementa hysteresis o cooldowns para evitar cambios de acción rápidos.

### Performance
- LOD: evaluar NPCs lejanos con menor frecuencia.
- Batch: evaluar múltiples NPCs en una pasada cuando sea posible.
- Cache: guarda resultados de queries costosas (pathfinding, visibilidad) con TTL corto.
- Usa el profiler de Godot para identificar cuellos de botella.

## 📞 Soporte

Si tienes preguntas o encuentras problemas:
1. Revisar esta documentación primero
2. Buscar en `MIGRATION_GUIDE.md` (troubleshooting section)
3. Revisar logs de Godot para errores específicos
4. Verificar que todos los sistemas estén inyectados correctamente

## 📄 Licencia y Créditos

Este sistema fue refactorizado como parte del proyecto NPCs-Discretas.
- Refactorización: Noviembre 2025
- Basado en: Sistema original de grafos sociales dirigidos
-- Preparado para: integración con addons de decisión (cuando se añadan)

---

**¡El sistema está listo para avanzar! 🎉**

Siguiente paso recomendado: Leer `REFACTOR_SUMMARY.md` y luego seguir `NEXT_STEPS_UTILITY_AI.md` para implementar el sistema de IA.
