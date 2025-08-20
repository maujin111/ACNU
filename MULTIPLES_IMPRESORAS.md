# Soporte para Múltiples Impresoras

## Descripción
La aplicación ahora soporta conectar y gestionar múltiples impresoras simultáneamente. Cada petición de impresión puede especificar el nombre de la impresora donde desea imprimir.

## Características Nuevas

### 1. Gestión de Múltiples Impresoras
- **Conectar múltiples impresoras**: Puedes tener varias impresoras conectadas al mismo tiempo
- **Lista de impresoras**: Ver todas las impresoras conectadas y su estado
- **Agregar impresoras**: Buscar y agregar nuevas impresoras a la lista
- **Remover impresoras**: Eliminar impresoras de la lista de conectadas
- **Estado individual**: Cada impresora tiene su propio estado de conexión

### 2. Selección Automática de Impresora
- **Por nombre**: Las peticiones pueden especificar `printerName` en el JSON
- **Retrocompatibilidad**: Si no se especifica nombre, usa la impresora principal
- **Verificación**: Solo imprime si la impresora especificada está conectada

### 3. Interfaz de Usuario Mejorada
- **Sección "Impresoras Conectadas"**: Nueva sección en la configuración
- **Botón "Agregar"**: Para buscar y agregar nuevas impresoras
- **Estado visual**: Indicadores de conexión para cada impresora
- **Acciones**: Conectar/desconectar y eliminar impresoras individualmente

## Uso

### Para Desarrolladores

#### Estructura del JSON con impresora específica:
```json
{
  "tipo": "VENTA",
  "id": "12345",
  "printerName": "EPSON TM-T88V",
  "copias": "1",
  "data": {
    // ... datos de la impresión
  }
}
```

#### Si no se especifica impresora:
```json
{
  "tipo": "VENTA", 
  "id": "12345",
  "copias": "1",
  "data": {
    // ... datos de la impresión
  }
}
```
En este caso usará la impresora principal (retrocompatibilidad).

### Para Usuarios

#### Agregar una nueva impresora:
1. Ir a "Configuración" → "Impresoras"
2. En la sección "Impresoras Conectadas", hacer clic en "Agregar"
3. Seleccionar la impresora de la lista de dispositivos disponibles
4. La impresora se agregará automáticamente y se intentará conectar

#### Gestionar impresoras existentes:
- **Ver estado**: Verde = conectada, Rojo = desconectada
- **Conectar/Desconectar**: Usar el botón de enlace (🔗/🔗✂️)
- **Eliminar**: Usar el botón de eliminar (🗑️)

## Comportamiento del Sistema

### Carga al Iniciar
- Se cargan todas las impresoras guardadas anteriormente
- Se intenta conectar automáticamente a cada una
- Se mantiene retrocompatibilidad con la impresora principal

### Procesamiento de Peticiones
1. **Con nombre específico**: 
   - Verifica que la impresora exista y esté conectada
   - Imprime solo en esa impresora
   - Falla si la impresora no está disponible

2. **Sin nombre específico**:
   - Usa la impresora principal (comportamiento original)
   - Mantiene retrocompatibilidad completa

### Gestión de Conexiones
- Cada impresora mantiene su propio estado de conexión
- Verificación automática periódica del estado
- Reconexión automática cuando es posible

## Configuración Persistente
- Las impresoras agregadas se guardan automáticamente
- Se restauran al reiniciar la aplicación
- Configuración independiente para cada impresora

## Casos de Uso

### Restaurante con múltiples estaciones:
- **Impresora Cocina**: "EPSON Kitchen"
- **Impresora Bar**: "STAR Bar Printer" 
- **Impresora Caja**: "HP Receipt"

Petición para cocina:
```json
{
  "tipo": "COMANDA",
  "printerName": "EPSON Kitchen",
  "data": { /* datos de comanda */ }
}
```

Petición para caja:
```json
{
  "tipo": "VENTA", 
  "printerName": "HP Receipt",
  "data": { /* datos de factura */ }
}
```

### Oficina con impresoras compartidas:
- Cada solicitud puede dirigirse a una impresora específica
- Balanceo de carga manual según disponibilidad
- Respaldo automático a impresora principal

## Beneficios
1. **Mayor flexibilidad**: Múltiples puntos de impresión
2. **Mejor rendimiento**: Distribución de carga de trabajo
3. **Redundancia**: Respaldo si una impresora falla
4. **Organización**: Impresoras dedicadas por función
5. **Escalabilidad**: Fácil agregar más impresoras

## Retrocompatibilidad
- ✅ **100% compatible** con código existente
- ✅ **Sin cambios requeridos** en aplicaciones actuales  
- ✅ **Migración gradual** posible
- ✅ **Configuración existente** se mantiene
