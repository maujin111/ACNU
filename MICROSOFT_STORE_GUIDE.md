# Guía Completa: Publicar en Microsoft Store

Esta guía te ayudará a compilar y publicar tu aplicación Flutter en la Microsoft Store.

## 📋 Requisitos Previos

- [x] Cuenta de Microsoft Partner Center (ya la tienes)
- [ ] Windows 10/11 con modo desarrollador habilitado
- [ ] Flutter SDK instalado
- [ ] Visual Studio 2019+ o Visual Studio Build Tools

## 🔧 Paso 1: Configuración Inicial

### 1.1 Instalar dependencias

Abre una terminal en el directorio de tu proyecto y ejecuta:

```bash
flutter pub get
```

### 1.2 Verificar que tu proyecto compila

```bash
flutter build windows --release
```

Si hay errores, corrígelos antes de continuar.

## 🎨 Paso 2: Preparar Recursos Visuales

### 2.1 Icono de la aplicación

Asegúrate de tener un icono de buena calidad:
- **Ubicación actual**: `assets/icon/app_icon.ico`
- **Requisitos**: Mínimo 256x256 píxeles
- **Formato**: PNG o ICO

### 2.2 Capturas de pantalla (para la Store)

Necesitarás preparar capturas de pantalla:
- **Mínimo**: 1 captura de pantalla
- **Recomendado**: 3-5 capturas
- **Tamaño**: 1366 x 768 píxeles (o mayor)
- **Formato**: PNG o JPG

**Cómo capturarlas:**
1. Ejecuta tu app: `flutter run -d windows`
2. Usa Windows + Shift + S para capturar pantallas
3. Guárdalas en una carpeta `screenshots/` para subirlas después

## 🆔 Paso 3: Obtener tu Publisher ID de Microsoft

### 3.1 Crear una reserva de nombre en Partner Center

1. Ve a [Microsoft Partner Center](https://partner.microsoft.com/dashboard)
2. Navega a: **Apps and games** → **New product** → **MSIX or PWA app**
3. Reserva el nombre: **"Anfibius Web Utility"** (o el que prefieras)
4. Guarda el nombre reservado

### 3.2 Obtener tu Publisher ID

1. En Partner Center, ve a la sección de tu app
2. Clic en **Product management** → **Product identity**
3. Encontrarás información como:
   - **Package/Identity/Name**: Por ejemplo `12345YourCompany.AnfibiusWebUtility`
   - **Package/Identity/Publisher**: Por ejemplo `CN=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`
   - **Publisher display name**: Tu nombre o empresa

**Copia estos valores**, los necesitarás en el siguiente paso.

## ⚙️ Paso 4: Configurar pubspec.yaml

Abre `pubspec.yaml` y busca la sección `msix_config:` que ya agregué. Actualízala con tus valores:

```yaml
msix_config:
  display_name: Anfibius Web Utility
  publisher_display_name: TU_NOMBRE_DE_PUBLISHER  # Del Partner Center
  identity_name: 12345YourCompany.AnfibiusWebUtility  # Package/Identity/Name del Partner Center
  publisher: CN=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX  # Package/Identity/Publisher del Partner Center
  msix_version: 1.0.0.0
  logo_path: assets/icon/icon.png
  capabilities: 'internetClient,removableStorage'
  store: true
  # Opcional: agregar descripción
  description: 'Utilidad web para gestión de impresoras térmicas y WebSocket'
  # Opcional: sitio web
  publisher_url: https://tudominio.com
  # Opcional: idiomas soportados
  languages: es-MX, en-US
```

### Capabilities (Permisos) explicados:

- `internetClient`: Conexión a internet (para WebSocket)
- `removableStorage`: Acceso a dispositivos USB (para impresoras)

**Otros capabilities disponibles** (agrégalos si los necesitas):
- `bluetooth`: Para impresoras Bluetooth
- `documentsLibrary`: Acceso a documentos
- `picturesLibrary`: Acceso a imágenes
- `videosLibrary`: Acceso a videos
- `musicLibrary`: Acceso a música

## 🏗️ Paso 5: Compilar el Paquete MSIX

### 5.1 Método 1: Usando el plugin MSIX (Recomendado para Store)

```bash
# Primero, limpia el proyecto
flutter clean

# Compila el paquete MSIX para la Store
flutter pub run msix:create --store
```

**Salida esperada:**
```
Building MSIX package...
✓ Package created successfully
  Location: build/windows/runner/Release/anfibius_uwu.msix
```

### 5.2 Método 2: Compilación manual con Flutter

```bash
# Compila la app en modo release
flutter build windows --release

# Crea el paquete MSIX
flutter pub run msix:create --store
```

### 5.3 Verificar el paquete

El archivo `.msix` estará en:
```
build/windows/runner/Release/anfibius_uwu.msix
```

**Tamaño aproximado**: 15-50 MB (depende de dependencias)

## ✅ Paso 6: Probar el Paquete Localmente

Antes de subirlo a la Store, pruébalo:

### 6.1 Habilitar modo desarrollador en Windows

1. Ve a **Configuración** → **Actualización y seguridad** → **Para desarrolladores**
2. Activa **Modo de desarrollador**

### 6.2 Instalar el paquete

```bash
# Instalar el MSIX
Add-AppxPackage -Path "build/windows/runner/Release/anfibius_uwu.msix"
```

O simplemente haz doble clic en el archivo `.msix`

### 6.3 Probar la aplicación

1. Busca "Anfibius" en el menú inicio
2. Ejecuta la app
3. Verifica que todas las funcionalidades trabajen:
   - WebSocket se conecta
   - Impresoras se detectan
   - System tray funciona
   - Notificaciones funcionan

### 6.4 Desinstalar (si necesitas hacer cambios)

```bash
# Listar apps instaladas
Get-AppxPackage | Select Name, PackageFullName | Where-Object {$_.Name -like "*anfibius*"}

# Desinstalar (usa el PackageFullName de arriba)
Remove-AppxPackage -Package "PackageFullName"
```

## 📤 Paso 7: Subir a Microsoft Store

### 7.1 Preparar la información de la Store

Antes de subir, prepara:

**Textos:**
- **Descripción corta** (máx. 200 caracteres):
  ```
  Utilidad para gestionar impresoras térmicas vía WebSocket. Ideal para sistemas POS y puntos de venta.
  ```

- **Descripción completa** (hasta 10,000 caracteres):
  ```
  Anfibius Web Utility es una aplicación profesional diseñada para conectar sistemas web con impresoras térmicas locales.
  
  ✨ Características principales:
  • Soporte para múltiples impresoras (USB, Bluetooth, Red)
  • Conexión WebSocket persistente
  • Detección automática de tamaño de papel (58mm, 72mm, 80mm)
  • Sistema de cola inteligente para impresión simultánea
  • Notificaciones en tiempo real
  • Se ejecuta en segundo plano (system tray)
  • Inicio automático con Windows
  
  🖨️ Impresoras soportadas:
  • Impresoras térmicas USB
  • Impresoras Bluetooth
  • Impresoras de red (TCP/IP)
  
  💼 Casos de uso:
  • Restaurantes y cocinas
  • Puntos de venta (POS)
  • Sistemas de tickets
  • Impresión de comandas
  
  🔒 Privacidad:
  La aplicación solo se conecta a tu servidor WebSocket configurado. No recopilamos datos de usuario.
  ```

- **Palabras clave** (máx. 7):
  ```
  impresora, térmica, POS, websocket, ticket, cocina, restaurante
  ```

- **Notas de versión** (para la v1.0.0):
  ```
  • Primera versión pública
  • Soporte para múltiples impresoras
  • Sistema de cola de impresión
  • Conexión WebSocket estable
  • Inicio automático opcional
  ```

### 7.2 Subir el paquete a Partner Center

1. **Iniciar sesión**: [Microsoft Partner Center](https://partner.microsoft.com/dashboard)

2. **Ir a tu app**: Encuentra "Anfibius Web Utility" en tus productos

3. **Crear una nueva submission**:
   - Clic en **Start your submission**

4. **Pricing and availability**:
   - **Visibility**: Public / Private (según prefieras)
   - **Markets**: Selecciona países donde estará disponible
   - **Pricing**: Gratuita o de pago
   - Guarda

5. **Properties**:
   - **Category**: Utilities & tools
   - **Subcategory**: (opcional)
   - **Privacy policy URL**: (si tienes)
   - **Support contact info**: Tu email de soporte
   - Guarda

6. **Age ratings**:
   - Responde el cuestionario (probablemente será "Everyone")
   - Guarda

7. **Packages**:
   - Clic en **Browse files**
   - Sube tu archivo `anfibius_uwu.msix`
   - Espera a que se procese (puede tardar 5-10 minutos)
   - La Store detectará automáticamente los requisitos del sistema
   - Guarda

8. **Store listings**:
   - **Descripción**: Pega la descripción completa que preparaste
   - **Screenshots**: Sube las capturas de pantalla (mínimo 1, recomendado 3-5)
   - **App icon** (opcional): La Store usará el icono del MSIX
   - **Additional graphics** (opcional): Logo promocional, etc.
   - Guarda

9. **Submission options**:
   - **Publishing hold options**: None (publicar inmediatamente tras aprobación)
   - **Notes for certification**: (opcional) Información adicional para revisores
     ```
     Esta aplicación requiere conexión a un servidor WebSocket para funcionar.
     Para probar: configurar un servidor WebSocket local o usar ws://echo.websocket.org para testing.
     Las impresoras USB necesitan estar conectadas para ver funcionalidad completa.
     ```
   - Guarda

10. **Revisar y enviar**:
    - Revisa todas las secciones (deben tener ✓ verde)
    - Clic en **Submit to the Store**

### 7.3 Proceso de certificación

**Tiempos:**
- **Validación inicial**: 1-4 horas
- **Certificación**: 1-3 días hábiles
- **Publicación**: Automática tras aprobación

**Estados:**
- **Validation**: Verificando el paquete
- **Certification**: En revisión manual
- **Publishing**: Publicando en la Store
- **In the Store**: ¡Publicado! 🎉

**Si es rechazado:**
- Revisa el email/notificación con los motivos
- Corrige los problemas
- Crea una nueva submission

## 🔄 Paso 8: Actualizaciones Futuras

Cuando quieras publicar una actualización:

### 8.1 Actualizar la versión

En `pubspec.yaml`:
```yaml
version: 1.0.1+2  # Incrementa la versión

msix_config:
  msix_version: 1.0.1.0  # Incrementa también aquí
```

### 8.2 Recompilar

```bash
flutter clean
flutter pub get
flutter pub run msix:create --store
```

### 8.3 Subir a Partner Center

1. Ve a tu app en Partner Center
2. Clic en **Update** (o crear nueva submission)
3. Ve a **Packages** → Sube el nuevo `.msix`
4. Actualiza **Notas de versión** en Store listings
5. Submit

**Las actualizaciones se instalarán automáticamente** en los dispositivos de los usuarios.

## 🐛 Solución de Problemas

### Error: "Publisher mismatch"
**Solución**: Verifica que el `publisher` en `pubspec.yaml` coincida exactamente con el de Partner Center.

### Error: "Package identity name already exists"
**Solución**: Usa el `identity_name` exacto que reservaste en Partner Center.

### Error al compilar MSIX
**Solución**:
```bash
flutter clean
flutter pub cache repair
flutter pub get
flutter pub run msix:create --store
```

### La app no se instala en Windows
**Solución**: Habilita "Modo desarrollador" en Windows Settings.

### Capabilities insuficientes
**Solución**: Si tu app necesita más permisos, agrégalos en `capabilities:` del `msix_config`.

### El icono no aparece correctamente
**Solución**: Asegúrate que `app_icon.ico` tenga múltiples resoluciones (16, 32, 48, 256 píxeles).

## 📊 Paso 9: Monitorear tu App

Una vez publicada:

1. **Analytics**: Partner Center → **Analyze** → Ver descargas, uso, crashes
2. **Reviews**: Responde a las reseñas de usuarios
3. **Health**: Monitorea crashes y errores reportados
4. **Acquisition**: Ve de dónde vienen tus usuarios

## ✅ Checklist Final

Antes de submit:

- [ ] `pubspec.yaml` tiene valores correctos de Publisher ID
- [ ] Versión actualizada en `pubspec.yaml` y `msix_config`
- [ ] App compila sin errores: `flutter build windows --release`
- [ ] MSIX creado exitosamente: `flutter pub run msix:create --store`
- [ ] MSIX probado localmente en Windows
- [ ] Capturas de pantalla preparadas (3-5 imágenes)
- [ ] Descripción completa y keywords preparados
- [ ] Información de contacto/soporte disponible
- [ ] Partner Center submission completada

## 🎯 Comandos Rápidos de Referencia

```bash
# Limpiar proyecto
flutter clean

# Obtener dependencias
flutter pub get

# Compilar para Windows (Release)
flutter build windows --release

# Crear paquete MSIX para Store
flutter pub run msix:create --store

# Probar en Windows
Add-AppxPackage -Path "build/windows/runner/Release/anfibius_uwu.msix"

# Desinstalar paquete local
Get-AppxPackage | Where-Object {$_.Name -like "*anfibius*"} | Remove-AppxPackage
```

## 📚 Recursos Adicionales

- [Microsoft Partner Center](https://partner.microsoft.com/dashboard)
- [Documentación MSIX Flutter](https://pub.dev/packages/msix)
- [Windows App Policies](https://docs.microsoft.com/windows/uwp/publish/store-policies)
- [Flutter Windows Deployment](https://docs.flutter.dev/deployment/windows)

## 💰 Costos

- **Cuenta de desarrollador Microsoft**: $19 USD (un solo pago)
- **Publicación de apps**: GRATIS
- **Actualizaciones**: GRATIS

---

¿Necesitas ayuda? Revisa la sección de **Solución de Problemas** o contacta al soporte de Microsoft Partner Center.

**¡Buena suerte con tu publicación!** 🚀
