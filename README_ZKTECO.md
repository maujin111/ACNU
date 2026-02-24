# Integración ZKTeco ZK9500 en Flutter Desktop

1. Coloca las DLLs de ZKTeco en:
   - `windows/dll/x64/ZKFingerSDK64.dll` (para 64 bits)
   - `windows/dll/x86/ZKFingerSDK.dll` (para 32 bits)

2. El sistema selecciona el SDK automáticamente según el tipo de dispositivo.

3. Para registrar/capturar huella con ZKTeco:
   - El método `startFingerprintRegistration` inicializa el SDK y realiza la captura.
   - El template de la huella se retorna como base64 por el callback `onFingerprintRead`.

4. Compila y ejecuta normalmente. Las DLLs se copiarán junto al ejecutable.

5. Si necesitas agregar más funciones del SDK, edita `lib/services/zkteco_sdk.dart` siguiendo el header del SDK.

---

**Nota:** Si usas Linux, coloca los archivos `.so` en `linux/so/` y adapta el binding si es necesario.
