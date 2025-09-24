
## Idea del Proyecto (versión técnica para Flutter + WebSocket)

Actualmente, nuestra aplicación se conecta a **impresoras mediante USB** y se comunica mediante **WebSocket**.
Queremos expandir esta funcionalidad para **registrar y leer huellas dactilares**, usando el mismo enfoque de conexión USB.

### Requisitos Iniciales

1. Detectar automáticamente la huella al colocar el dedo en el lector.
2. Enviar la lectura de la huella **como cadena de texto** a un WebSocket en tiempo real.
3. Registrar en un documento interno el estado de cada objetivo (pendiente / completado).
4. Compatibilidad futura con la mayoría de lectores de huellas, no limitado a un modelo específico.

**Dispositivo de prueba actual:**

* Hikvision DS-K1F820-F


### Lista de Objetivos (tareas)
Objetivo                                                          | Estado    |
Interfaz para detectar y conectar lector en un tab en la parte de configuracion similar al de impresora | Pendiente |
Enviar lectura de huella en forma de cadena de texto al WebSocket | Pendiente |





### Flujo sugerido en Flutter

1. Detectar dispositivo USB conectado (lector de huellas).
2. Escuchar eventos de lectura de huella.
3. Cuando se detecte la huella:

   * Convertir la lectura a cadena de texto.
   * Enviar al WebSocket.
   * Actualizar automáticamente el documento de objetivos con el estado **"completado"**.



### Notas para Copilot
* No tocar nada del sistema de impresion que ya esta funcionando
* Usar paquetes Flutter que soporten **USB** o **hid** para leer el dispositivo.
* El archivo de objetivos (`objetivos.json`) debe actualizarse automáticamente al completar cada tarea.
* Inicialmente, enfocarse en **lectura y envío de huella**, no en registro biométrico completo.
* Preparar la estructura para **compatibilidad con múltiples dispositivos de huella** en el futuro.
