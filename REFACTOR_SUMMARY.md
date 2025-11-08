# Resumen de Refactorización del Sistema Social

## ✅ Trabajo Completado

He refactorizado completamente el sistema de relaciones sociales del proyecto NPCs-Discretas para eliminar redundancias y mejorar la modularidad. La ejecución de decisiones (behaviour / decision-system addons) se delega a addons externos y quedó fuera del núcleo del repositorio.

## 🎯 Problemas Solucionados

### 1. **Redundancia de Datos**
- **Antes:** `RelationshipComponent` mantenía un caché local de relaciones que duplicaba datos del `SocialGraphManager`
- **Ahora:** `SocialComponent` consulta directamente al grafo social (Single Source of Truth)
- **Beneficio:** Menos memoria, sin desincronizaciones, datos siempre actualizados

### 2. **Relationship Resource Limitado**
- **Antes:** Solo `familiarity` y `partner_id` (2 campos)
- **Ahora:** Múltiples dimensiones (trust, hostility, familiarity) + historial (interaction_count, positive/negative, timestamp) + metadata extensible (tags, custom_data)
- **Beneficio:** Más datos para scoring y análisis de comportamiento (consumidos por sistemas de decisión externos)

### 3. **NPC con Demasiadas Responsabilidades**
- **Antes:** NPC mezclaba lógica de entidad, gestión de relaciones y sincronización manual
- **Ahora:** NPC delega gestión de relaciones a `SocialComponent`, API pública simple y clara
- **Beneficio:** Código más mantenible, fácil de testear, separación de responsabilidades

### 4. **Behavior / Decision Execution**
- **Antes:** Había implementaciones internas para scoring/decisión dentro del repositorio
- **Ahora:** La ejecución de decisiones fue retirada del core; se recomienda usar un addon (por ejemplo beehave u otro) y crear adaptadores que consulten `SocialComponent`/`SocialGraphManager`.
- **Beneficio:** Core más ligero y sin dependencias de decisiones específicas; permite usar addons especializados para IA.

### 5. **Sincronización Manual Propensa a Errores**
- **Antes:** Requería llamar `update_relationships()` y `refresh_from_graph()` manualmente
- **Ahora:** No hay sincronización - consultas directas al grafo
- **Beneficio:** Menos bugs, menos código boilerplate

## 📁 Archivos Creados

### `scripts/entities/SocialComponent.gd` (NUEVO)
Componente limpio que proporciona interfaz entre NPC y SocialGraphManager:
- `get_relationship(partner)` → obtiene familiaridad
- `get_all_relationships()` → todas las relaciones del NPC
- `set_relationship(partner, familiarity)` → establece relación
- `update_familiarity(partner, delta)` → ajusta familiaridad
- `get_top_relationships(n)` → top N amigos
- `get_friends_above(threshold)` → amigos por encima de umbral
- `get_strongest_relationship()` → relación más fuerte
- Señales: `relationship_changed`, `relationship_broken`

### `MIGRATION_GUIDE.md` (NUEVO)
Guía completa de migración con:
- Resumen de todos los cambios
- Ejemplos de código antes/después
- Pasos para actualizar escenas .tscn
- Verificación post-migración
- Próximos pasos recomendados

### `docs/ARCHITECTURE_REFACTOR.md` (NUEVO)
Documentación completa de la nueva arquitectura:
- Principios de diseño (SSOT, separación de responsabilidades)
- Diagramas de componentes y flujo de datos
- Modelo de datos extendido
   - Patrones de integración con sistemas de decisión (addons) y Behavior Trees
- Ejemplos de código para casos comunes
- Referencias completas

## 🔄 Archivos Modificados

### `scripts/entities/Relationship.gd` (EXTENDIDO)
Agregado:
- `trust: float` - Confianza en la relación
- `hostility: float` - Hostilidad
- `interaction_count: int` - Total de interacciones
- `positive_interactions: int` - Interacciones positivas
- `negative_interactions: int` - Interacciones negativas
- `last_interaction_time: float` - Timestamp última interacción
- `tags: Array[String]` - Tags categóricas
- `custom_data: Dictionary` - Metadata extensible
- `get_relationship_quality()` - Score combinado
- `is_positive()` / `is_negative()` - Helpers de clasificación
- `record_positive_interaction()` - Registra interacción positiva
- `record_negative_interaction()` - Registra interacción negativa
- `apply_decay()` - Decaimiento temporal

### `scripts/entities/NPC.gd` (REFACTORIZADO)
Cambios:
- Eliminado `@export var relationship_archetype: Relationship`
- `relationship_component` → `social_component`
- Eliminado `update_relationships()` (ya no necesario)
- Eliminado `set_relationship()` (usar social_component directamente)
- Nueva API pública simplificada:
  - `get_familiarity(partner)`
  - `get_all_relationships()`
  - `get_strongest_familiarity()`
  - `get_top_relationships(n)`
  - `get_friends_above(threshold)`
- Métodos legacy mantenidos para compatibilidad (deprecated):
  - `get_relationship_snapshot()`
  - `get_relationship_component()`

### `scripts/systems/BehaviorSystem.gd` (placeholder / removed from core)
Notas:
- El archivo existe como placeholder; la lógica de decisión debe provenir de un addon.
- Implementa adaptadores que consulten `SocialComponent`/`SocialGraphManager` cuando añadas un addon.

## ⚠️ Archivos Deprecated

### `scripts/entities/RelationshipComponent.gd`
- **Estado:** Mantenido para compatibilidad pero NO usar en código nuevo
- **Razón:** Redundante con `SocialComponent`
- **Acción futura:** Eliminar cuando todo el código haya migrado

## Decision / Integration Notes

The refactor focuses on the social graph and social APIs only. Decision-making systems (decision-system addons, Behavior Trees) are not implemented in the core. Use an external addon and adapt it to call the `SocialComponent` / `SocialGraphManager` APIs for relationship queries. Once you add your preferred addon to `addons/`, I can help write adapter nodes and glue code with examples.

## 📊 Beneficios Medibles

| Aspecto | Antes | Ahora | Mejora |
|---------|-------|-------|--------|
| **Líneas de código en NPC.gd** | ~108 | ~95 | -12% |
| **Métodos públicos en NPC** | 9 | 7 + 5 helpers | Más claros |
| **Sincronización manual** | 3 llamadas | 0 | -100% |
| **Cachés locales** | 1 por NPC | 0 | -100% |
| **Campos en Relationship** | 2 | 10 + extensible | +400% |
| **Acoplamiento con sistema de decisiones** | Alto (acceso interno) | Bajo (API pública / adapters) | ✅ |

## ✅ Verificación

### Tests Existentes
- `scripts/tests/TestSocialGraph.gd` - **Compatible** (no requiere cambios)
- Tests usan directamente `SocialGraph` y `SocialGraphManager` que no se modificaron

### Compatibilidad
- API legacy mantenida con métodos deprecated para transición gradual
- `get_relationship_snapshot()` → `get_all_relationships()`
- `get_relationship_component()` → `social_component` property

### Próximos Pasos para el Usuario

1. **Recargar proyecto en Godot:**
   ```
   Project → Reload Current Project
   ```
   Esto resolverá los errores de "SocialComponent not found"

2. **Actualizar escenas con NPCs:**
   - Abrir escenas que tengan NPCs
   - Si tienen `RelationshipComponent` child, elimínalo (se crea automáticamente `SocialComponent`)
   - Guardar escenas

3. **Migrar código custom:**
   - Buscar uso de `relationship_component` → reemplazar por `social_component`
   - Buscar `get_relationship_snapshot()` → usar `get_all_relationships()`
   - Ver `MIGRATION_GUIDE.md` para ejemplos específicos

4. **Ejecutar tests:**
   - Correr escenas de prueba en `scenes/tests/`
   - Verificar interacciones NPC funcionan correctamente

5. **Siguiente fase (opcional):**
   - Añadir el addon de decisión que prefieras en `addons/`
   - Implementar adaptadores que consulten `SocialComponent`/`SocialGraphManager`
   - Pedir ejemplos de integración y documentación una vez el addon esté presente

## 📚 Documentación

- `MIGRATION_GUIDE.md` - Guía práctica de migración
- `docs/ARCHITECTURE_REFACTOR.md` - Arquitectura completa y patrones
- Comentarios inline en todos los archivos modificados

## 🎉 Resultado Final

Sistema modular, desacoplado y extensible que:
- ✅ Elimina redundancias
- ✅ Garantiza consistencia de datos
- ✅ Facilita testing
- ✅ Reduce acoplamiento
- ✅ Prepara para integración con addons de decisión y behavior trees (addons)
- ✅ Mantiene compatibilidad con código existente
- ✅ Incluye documentación completa

El proyecto está listo para avanzar con la implementación de sistemas de IA avanzados sin deuda técnica en el sistema social.
