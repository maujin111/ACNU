# Configuración de Inicio Automático

## Descripción
Esta aplicación incluye funcionalidad para iniciarse automáticamente cuando Windows arranca, permitiendo que esté siempre disponible en segundo plano.

## Cómo funciona

### 1. Configuración automática
- Al iniciar la aplicación por primera vez, se configura automáticamente el sistema de inicio
- Se obtiene la ruta del ejecutable actual y se registra en Windows
- La configuración se guarda tanto en el registro de Windows como en las preferencias de la aplicación

### 2. Inicio con Windows
- Cuando Windows arranca, la aplicación se ejecuta automáticamente
- La aplicación inicia minimizada en la bandeja del sistema
- No interfiere con el tiempo de arranque del sistema

### 3. Comportamiento en segundo plano
- Al cerrar la ventana (X), la aplicación se minimiza a la bandeja del sistema
- Para salir completamente, usa el menú contextual del ícono de la bandeja: "Salir"
- También puedes cerrar desde la configuración de la aplicación

### 4. Control manual
- Puedes habilitar/deshabilitar el inicio automático desde:
  - Configuración → Sistema → "Iniciar con Windows"
- La aplicación verificará automáticamente la sincronización entre la configuración guardada y el estado real del sistema

## Ubicación en Windows
El registro de inicio automático se almacena en:
- **Registro de Windows**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`
- **Preferencias de la app**: `SharedPreferences` con clave `start_with_windows`

## Solución de problemas

### La aplicación no inicia con Windows
1. Verificar que el interruptor esté activado en Configuración
2. Usar el botón "Verificar estado actual" (icono de refresh) en la configuración
3. Reiniciar la aplicación si es necesario
4. Comprobar permisos de Windows (ejecutar como administrador si es necesario)

### Error de configuración
- Si aparece un error en la configuración, usar el botón de verificación
- Cerrar completamente la aplicación y reiniciarla
- En casos extremos, deshabilitar y volver a habilitar el inicio automático