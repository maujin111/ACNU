## Descripción
La aplicación Anfibius Connect Nexus Utility utiliza un sistema para el envió o recepción de solicitudes a dispositivos en tiempo real desde sistemas externos. Este manual explica cómo conectarse, configurar y usar todas las funcionalidades disponibles.

## Configuración Inicial

### 1. Obtener el Token de Conexión
Para conectarse al WebSocket, necesitas un **token único** proporcionado en el sistema Anfibius Web, este token se encuentra ubicado en la sección de sistema →  sucursales → API Key:

- **Formato**: Token alfanumérico único
- **Ejemplo**: `abc123xyz789token`
- **Fuente**: Solicitar al administrador del sistema Anfibius

### 2. Configurar la Conexión

#### Desde la Aplicación:
1. Abrir la aplicación
2. Ir a **"Configuración"** → **"Conexión"**
3. Introducir el token en el campo **"Token"**
4. Hacer clic en el botón de **enlace (🔗)** para conectar
5. Verificar que el estado cambie a **"Conectado"** (ícono verde ✅)

### Características de Conexión:
- **Reconexión automática**: Se reconecta cada 5 segundos si se pierde la conexión

## Soporte para Múltiples Impresoras

### Descripción

La aplicación ahora soporta conectar y gestionar múltiples impresoras simultáneamente. Cada petición de impresión puede especificar el nombre de la impresora donde desea imprimir.

### Características
#### 1. Gestión de Múltiples Impresoras

- **Conectar múltiples impresoras**: Puedes tener varias impresoras conectadas al mismo tiempo
- **Lista de impresoras**: Ver todas las impresoras conectadas y su estado
- **Agregar impresoras**: Buscar y agregar nuevas impresoras a la lista
- **Remover impresoras**: Eliminar impresoras de la lista de conectadas
- **Estado individual**: Cada impresora tiene su propio estado de conexión
#### 2. Selección Automática de Impresora

- **Por nombre**: Las peticiones pueden especificar `printerName` en el JSON
- **Retrocompatibilidad**: Si no se especifica nombre, usa la impresora principal
- **Verificación**: Solo imprime si la impresora especificada está conectada
#### 3. Interfaz de Usuario Mejorada

- **Sección "Impresoras Conectadas"**: Nueva sección en la configuración
- **Botón "Agregar"**: Para buscar y agregar nuevas impresoras
- **Estado visual**: Indicadores de conexión para cada impresora
- **Acciones**: Conectar/desconectar y eliminar impresoras individualmente
### Uso
#### Agregar una nueva impresora:
1. Ir a "Configuración" → "Impresoras"
2. En la sección "Impresoras Conectadas", hacer clic en "Agregar"
3. Seleccionar la impresora de la lista de dispositivos disponibles
4. La impresora se agregará automáticamente y se intentará conectar

#### Gestionar impresoras existentes:
- **Ver estado**: Verde = conectada, Rojo = desconectada
- **Conectar/Desconectar**: Usar el botón de enlace (🔗/🔗✂️)
- **Eliminar**: Usar el botón de eliminar (🗑️)

### Comportamiento del Sistema

#### Carga al Iniciar
- Se cargan todas las impresoras guardadas anteriormente
- Se intenta conectar automáticamente a cada una
- Se mantiene retrocompatibilidad con la impresora principal
#### Procesamiento de Peticiones

1. **Con nombre específico**:
   - Verifica que la impresora exista y esté conectada
   - Imprime solo en esa impresora
   - Falla si la impresora no está disponible

1. **Sin nombre específico**:
   - Usa la impresora principal (comportamiento original)
   - Mantiene retrocompatibilidad completa

#### Gestión de Conexiones

- Cada impresora mantiene su propio estado de conexión
- Verificación automática periódica del estado
- Reconexión automática cuando es posible

### Configuración Persistente
- Las impresoras agregadas se guardan automáticamente
- Se restauran al reiniciar la aplicación
- Configuración independiente para cada impresora
### Oficina con impresoras compartidas:
- Cada solicitud puede dirigirse a una impresora específica
- Balanceo de carga manual según disponibilidad
- Respaldo automático a impresora principal

### Beneficios

1. **Mayor flexibilidad**: Múltiples puntos de impresión
2. **Mejor rendimiento**: Distribución de carga de trabajo
3. **Redundancia**: Respaldo si una impresora falla
4. **Organización**: Impresoras dedicadas por función
5. **Escalabilidad**: Fácil agregar más impresoras

### Tipos de Documentos Soportados para impresión

La aplicación puede procesar diferentes tipos de documentos de impresión:

1. Facturas
2. Prefecturas
3. Comandas
4. Ticket de sorteo (Anfibius Tickets)

## Funcionalidades

### 1. Gestión del Historial

#### Ver historial de impresiones:
1. Ir a **"Dispositivos"**
2. Sección **"Historial de Impresión"**
3. Lista de todas las solicitudes recibidas

#### Reimprimir desde historial:
- Hacer clic en el botón **🖨️** junto a cualquier elemento
- Se reimprimirá usando la impresora actual

#### Limpiar historial:
- Botón **"Limpiar Historial"** en la sección de historial
- Elimina todos los registros guardados

### 2. Estados de Conexión

#### Indicadores Visuales:
- **Verde ✅**: WebSocket conectado
- **Rojo ❌**: WebSocket desconectado
- **Botón Reconectar**: Disponible cuando hay token configurado

### 3. Configuración de Papel

#### Tamaños soportados:
- **58mm**: 34 caracteres por línea
- **72mm**: 42 caracteres por línea  
- **80mm**: 48 caracteres por línea
- **Personalizado**: Ancho configurable

#### Configurar desde la aplicación:
1. **"Configuración"** → **"Impresoras"**
2. Sección **"Configuración de Papel"**
3. Seleccionar tamaño o configurar ancho personalizado

### Solución de Problemas

### 1. Problemas de Conexión

#### Error: "No se puede conectar"
**Solución:**
1. Verificar que el token sea correcto
2. Comprobar conexión a internet
3. Intentar reconectar desde la configuración
4. Verificar que no haya firewall bloqueando

### 2. Problemas de Impresión

#### Error: "Impresora no conectada"
**Solución:**
1. Verificar que la impresora esté encendida
2. Comprobar conexión USB/Bluetooth/Red
3. Reconectar desde "Configuración" → "Impresoras"

## Configuración Avanzada

### 1. Inicio Automático con Windows

#### Descripción

Esta aplicación incluye funcionalidad para iniciarse automáticamente cuando Windows arranca, permitiendo que esté siempre disponible en segundo plano.

#### Cómo funciona
##### 1. Configuración automática

- Al iniciar la aplicación por primera vez, se configura automáticamente el sistema de inicio
- Se obtiene la ruta del ejecutable actual y se registra en Windows
- La configuración se guarda tanto en el registro de Windows como en las preferencias de la aplicación
##### 2. Inicio con Windows

- Cuando Windows arranca, la aplicación se ejecuta automáticamente
- La aplicación inicia minimizada en la bandeja del sistema
- No interfiere con el tiempo de arranque del sistema
##### 3. Comportamiento en segundo plano

- Al cerrar la ventana (X), la aplicación se minimiza a la bandeja del sistema
- Para salir completamente, usa el menú contextual del ícono de la bandeja: "Salir"
- También puedes cerrar desde la configuración de la aplicación
##### 4. Control manual

- Puedes habilitar/deshabilitar el inicio automático desde:
  - Configuración → Sistema → "Iniciar con Windows"
- La aplicación verificará automáticamente la sincronización entre la configuración guardada y el estado real del sistema
#### Ubicación en Windows

El registro de inicio automático se almacena en:
- **Registro de Windows**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`
- **Preferencias de la app**: `SharedPreferences` con clave `start_with_windows`
### Solución de problemas

#### La aplicación no inicia con Windows

1. Verificar que el interruptor esté activado en Configuración
2. Usar el botón "Verificar estado actual" (icono de refresh) en la configuración
3. Reiniciar la aplicación si es necesario
4. Comprobar permisos de Windows (ejecutar como administrador si es necesario)
#### Error de configuración

- Si aparece un error en la configuración, usar el botón de verificación
- Cerrar completamente la aplicación y reiniciarla
- En casos extremos, deshabilitar y volver a habilitar el inicio automático

### 2. Configuración de Red

#### Para impresoras de red:
1. **"Configuración"** → **"Impresoras"**
2. Sección **"Impresora de Red"**
3. Introducir **IP** y **Puerto** (default: 9100)
4. Guardar y conectar

#### Configuración típica:
- **IP**: `192.168.1.100`
- **Puerto**: `9100` (estándar para impresoras ESC/POS)

### 3. Personalización de Papel

#### Desde la interfaz:
1. **"Configuración"** → **"Impresoras"**
2. **"Configuración de Papel"**
3. Activar **"Usar ancho personalizado"**
4. Introducir ancho en milímetros

## Conclusión

El sistema de WebSocket de Anfibius Connect Nexus Utility proporciona una solución completa y robusta para la impresión automática de documentos desde sistemas externos. Con soporte para múltiples impresoras, reconexión automática, y una amplia variedad de tipos de documentos, se adapta perfectamente a las necesidades de restaurantes, oficinas, y puntos de venta.

### Características Clave:
- ✅ **Conexión automática** con múltiples endpoints de respaldo
- ✅ **Soporte para múltiples impresoras** simultáneas
- ✅ **Reconexión automática** en caso de pérdida de conexión
- ✅ **Historial persistente** de todas las impresiones
- ✅ **Retrocompatibilidad** completa con sistemas existentes
- ✅ **Inicio automático** con Windows
- ✅ **Configuración flexible** de papel y impresoras

### Soporte
Para soporte técnico o consultas adicionales:
- **Documentación**: Este manual
- **Logs del sistema**: Disponibles en la aplicación
- **Estado en tiempo real**: Visible en la interfaz de dispositivos
