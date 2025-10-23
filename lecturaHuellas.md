# Contexto del Proyecto

Este módulo forma parte del apartado **Nómina** dentro del proyecto principal.
Su finalidad es **gestionar el registro de huellas dactilares de los empleados** para control de asistencia.

---

## 📘 Antecedentes

1. En el archivo `configuraciones.dart` existen **5 pestañas (TabViews)**.
2. En **Configuraciones → Lectores (`lector_huella.dart`)**,
   - Se conecta el lector de huellas con la app.
   - Permite **escanear dispositivos** y **probar el lector** con dos botones:
     - `fingerprintService.startListening()` → inicia la lectura de prueba.
     - `fingerprintService.stopListening()` → detiene la lectura de prueba.
3. El **registro real de huellas de empleados** se hace desde:
   `Configuraciones → Nómina → Administrar empleados → Registro de huellas (fingerprint_registration_screen.dart)`.
   Desde esta pantalla se envía la huella al backend.

---

## ⚙️ Estado actual

- La huella se **registra correctamente**.
- El backend **recibe el ID del empleado y la huella como `bytes[]`**.
- El backend almacena la huella en **PostgreSQL** (campo tipo `bytea`).

---

## 🚨 Problemas detectados

1. **Escucha persistente indebida:**Después de registrar una huella, el servicio de huella (`fingerprintService`) sigue escuchando.Cuando el usuario vuelve a `Configuraciones → Lector`, aparece como si todavía estuviera activo, y al colocar un dedo, se intenta registrar nuevamente.👉 **Debe escuchar solo dentro de la pantalla de registro y detenerse automáticamente al salir.**
2. **Interfaz congelada durante la lectura:**Mientras se lee la huella, la pantalla parece congelada.👉 Debe mostrar un mensaje o indicador visual de estado:

   - “Leyendo huella…”
   - “Error al leer huella”
   - “Huella registrada correctamente”
3. **Lentitud y fallos en la lectura:**
   La lectura de huella es **muy lenta** y **falla frecuentemente**, aunque el hardware funciona bien en otro software.
   👉 Optimizar la captura de datos o reducir el tiempo de procesamiento para que sea más ágil y confiable.

---

## 🎯 Objetivos actuales

1. **Registrar huellas solo desde la pantalla de registro.**
2. **Acelerar la lectura de huellas** (optimizar lógica o buffer).
3. **Mostrar mensajes de estado** durante el proceso (lectura, éxito, error).

---

## ⚠️ Restricciones

1. **No modificar** la funcionalidad de **WebSockets** → ya funciona correctamente.
2. **No modificar** la funcionalidad de **impresión** → ya funciona correctamente.

---

## 💡 Recomendaciones para Copilot

- Revisar el ciclo de vida del `fingerprintService`: iniciar y detener correctamente según la pantalla.
- Implementar un sistema de **estado visual** (loading / success / error).
- Optimizar la función de captura para evitar bloqueos del hilo principal (usar `Future`, `async/await`, o `compute()` si es necesario).
- Mantener el código existente estable; **solo añadir o mejorar**, no eliminar funciones actuales.
