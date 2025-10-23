import 'dart:ffi';
import 'dart:io';
import 'dart:async'; // Import for Timer
import 'dart:developer' as developer; // Import for developer.log
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// Definir el callback para mensajes
typedef FpMessageHandlerNative =
    Void Function(Int32 msgType, Pointer<Void> msgData);
typedef FpMessageHandlerDart =
    void Function(int msgType, Pointer<Void> msgData);

// Constantes del SDK
class HikvisionConstants {
  static const int FP_SUCCESS = 0;
  static const int FP_CONNECTION_ERR = 1;
  static const int FP_TIMEOUT = 2;
  static const int FP_ENROLL_FAIL = 3;
  static const int FP_PARAM_ERR = 4;
  static const int FP_EXTRACT_FAIL = 5;
  static const int FP_MATCH_FAIL = 6;
  static const int FP_FTP_MAX = 512;
  static const int FP_IMAGE_WIDTH = 256;
  static const int FP_IMAGE_HEIGHT = 360;
  static const int FP_BMP_HEADER = 1078;

  // Tipos de mensajes
  static const int FP_MSG_PRESS_FINGER = 0;
  static const int FP_MSG_RISE_FINGER = 1;
  static const int FP_MSG_ENROLL_TIME = 2;
  static const int FP_MSG_CAPTURED_IMAGE = 3;
}

// Estructura de información de imagen
final class FpImageData extends Struct {
  @Int32()
  external int dwWidth;

  @Int32()
  external int dwHeight;

  external Pointer<Uint8> pbyImage;
}

class HikvisionSDK {
  static DynamicLibrary? _lib;

  // Funciones del SDK
  static late int Function() _fpOpenDevice;
  static late int Function() _fpCloseDevice;
  static late int Function(Pointer<Int32> fpStatus) _fpDetectFinger;
  static late int Function(
    Pointer<Uint8> imageData,
    Pointer<Int32> width,
    Pointer<Int32> height,
  )
  _fpCaptureImage;
  static late int Function(int timeout) _fpSetTimeout;
  static late int Function(Pointer<Int32> timeout) _fpGetTimeout;
  static late int Function(int times) _fpSetCollectTimes;
  static late int Function(Pointer<Int32> times) _fpGetCollectTimes;
  static late int Function(
    Pointer<NativeFunction<FpMessageHandlerNative>> handler,
  )
  _fpInstallMessageHandler;
  static late int Function(Pointer<Uint8> template) _fpFpEnroll;
  static late int Function(Pointer<Uint8> quality) _fpGetQuality;
  static late int Function(
    Pointer<Uint8> template1,
    Pointer<Uint8> template2,
    int securityLevel,
  )
  _fpMatchTemplate;
  static late int Function(Pointer<Int8> deviceInfo) _fpGetDeviceInfo;
  static late int Function(Pointer<Int8> sdkVersion) _fpGetSDKVersion;

  static bool _initialized = false;
  static bool _deviceOpen = false;
  static Timer? _captureTimer;

  // Callback para manejar mensajes del SDK
  static Function(int msgType, Pointer<Void> msgData)? _messageHandler;

  // Puntero al callback nativo. Se guarda para evitar que el GC lo elimine.
  static Pointer<NativeFunction<FpMessageHandlerNative>>? _callbackPointer;

  // Método público para verificar si el SDK está inicializado
  static bool isInitialized() => _initialized;

  // Wrapper para el callback que se pasa al SDK nativo
  @pragma('vm:entry-point')
  static void _nativeMessageHandler(int msgType, Pointer<Void> msgData) {
    // Filtrar mensajes para reducir el ruido - solo procesar mensajes relevantes
    if (msgType == HikvisionConstants.FP_MSG_PRESS_FINGER) {
      // No hacer log aquí para evitar spam, el servicio ya lo hace
      _messageHandler?.call(msgType, msgData);
    }
    // Ignorar otros tipos de mensajes silenciosamente
  }

  static bool initialize() {
    if (_initialized) return true;

    try {
      // Obtener el directorio donde se está ejecutando la aplicación
      String? executablePath;
      if (!kIsWeb && Platform.isWindows) {
        executablePath = Platform.resolvedExecutable;
        final executableDir = File(executablePath).parent.path;
        developer.log('📁 Directorio del ejecutable: $executableDir');
      }

      // Lista de posibles rutas para la DLL del SDK
      final possiblePaths = <String>[];

      // En release, buscar primero en el directorio del ejecutable
      if (executablePath != null && !kDebugMode) {
        final executableDir = File(executablePath).parent.path;
        possiblePaths.addAll([
          '$executableDir\\FPModule_SDK_x64.dll',
          '$executableDir\\SDKHIKVISION\\libs\\x64\\FPModule_SDK_x64.dll',
          '$executableDir\\libs\\FPModule_SDK_x64.dll',
          '$executableDir\\data\\flutter_assets\\SDKHIKVISION\\libs\\x64\\FPModule_SDK_x64.dll',
        ]);
      }

      // Rutas para desarrollo/debug y fallbacks
      possiblePaths.addAll([
        'SDKHIKVISION/libs/x64/FPModule_SDK_x64.dll',
        'FPModule_SDK_x64.dll',
        'SDKHIKVISION/FPModule_SDK_x64.dll',
        'libs/FPModule_SDK_x64.dll',
      ]);

      DynamicLibrary? loadedLib;

      // Intentar cargar la DLL desde diferentes ubicaciones
      for (String path in possiblePaths) {
        try {
          developer.log('🔍 Intentando cargar SDK desde: $path');
          loadedLib = DynamicLibrary.open(path);
          developer.log('✅ SDK cargado exitosamente desde: $path');
          break;
        } catch (e) {
          developer.log('⚠️ No se pudo cargar desde $path: $e');
          continue;
        }
      }

      if (loadedLib == null) {
        developer.log(
          '❌ No se pudo encontrar la DLL del SDK en ninguna ubicación',
        );
        return false;
      }

      _lib = loadedLib;

      // Mapear las funciones del SDK
      _fpOpenDevice = _lib!.lookupFunction<Int32 Function(), int Function()>(
        'FPModule_OpenDevice',
      );
      _fpCloseDevice = _lib!.lookupFunction<Int32 Function(), int Function()>(
        'FPModule_CloseDevice',
      );
      _fpDetectFinger = _lib!.lookupFunction<
        Int32 Function(Pointer<Int32>),
        int Function(Pointer<Int32>)
      >('FPModule_DetectFinger');
      _fpCaptureImage = _lib!.lookupFunction<
        Int32 Function(Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>),
        int Function(Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>)
      >('FPModule_CaptureImage');
      _fpInstallMessageHandler = _lib!.lookupFunction<
        Int32 Function(Pointer<NativeFunction<FpMessageHandlerNative>>),
        int Function(Pointer<NativeFunction<FpMessageHandlerNative>>)
      >('FPModule_InstallMessageHandler');
      _fpFpEnroll = _lib!.lookupFunction<
        Int32 Function(Pointer<Uint8>),
        int Function(Pointer<Uint8>)
      >('FPModule_FpEnroll');
      _fpGetDeviceInfo = _lib!.lookupFunction<
        Int32 Function(Pointer<Int8>),
        int Function(Pointer<Int8>)
      >('FPModule_GetDeviceInfo');
      _fpGetSDKVersion = _lib!.lookupFunction<
        Int32 Function(Pointer<Int8>),
        int Function(Pointer<Int8>)
      >('FPModule_GetSDKVersion');
      _fpSetTimeout = _lib!
          .lookupFunction<Int32 Function(Int32), int Function(int)>(
            'FPModule_SetTimeout',
          );
      _fpGetTimeout = _lib!.lookupFunction<
        Int32 Function(Pointer<Int32>),
        int Function(Pointer<Int32>)
      >('FPModule_GetTimeout');
      _fpSetCollectTimes = _lib!
          .lookupFunction<Int32 Function(Int32), int Function(int)>(
            'FPModule_SetCollectTimes',
          );
      _fpGetCollectTimes = _lib!.lookupFunction<
        Int32 Function(Pointer<Int32>),
        int Function(Pointer<Int32>)
      >('FPModule_GetCollectTimes');

      _initialized = true;
      developer.log('✅ SDK Hikvision inicializado exitosamente');

      return _initialized;
    } catch (e) {
      developer.log('❌ Error cargando SDK Hikvision: $e');
      return false;
    }
  }

  static void cleanup() {
    if (_initialized && _lib != null) {
      try {
        if (_deviceOpen) {
          closeDevice();
        }
        _initialized = false;
        developer.log('✅ SDK Hikvision limpiado');
      } catch (e) {
        developer.log('⚠️ Error al limpiar SDK: $e');
      }
    }
  }

  static List<Map<String, dynamic>> enumDevices() {
    if (!_initialized) return [];

    // Este SDK no tiene enumeración de dispositivos
    // Solo puede abrir un dispositivo predeterminado
    return [
      {
        'id': '0',
        'name': 'DS-K1F820-F',
        'type': 'Hikvision Fingerprint Reader',
      },
    ];
  }

  static bool openDevice() {
    if (!_initialized) return false;

    try {
      final result = _fpOpenDevice();
      _deviceOpen = (result == HikvisionConstants.FP_SUCCESS);

      if (_deviceOpen) {
        // Configurar timeout (8000ms = 8 segundos)
        final timeoutResult = _fpSetTimeout(8000);
        if (timeoutResult == HikvisionConstants.FP_SUCCESS) {
          developer.log('✅ Timeout configurado a 8 segundos');
        } else {
          developer.log('⚠️ No se pudo configurar timeout: $timeoutResult');
        }
        // Configurar número de colecciones (5 intentos)
        final collectResult = _fpSetCollectTimes(5);
        if (collectResult == HikvisionConstants.FP_SUCCESS) {
          developer.log('✅ Colecciones configuradas a 5 intentos');
        } else {
          developer.log('⚠️ No se pudo configurar colecciones: $collectResult');
        }

        developer.log('✅ Dispositivo Hikvision abierto exitosamente');
      } else {
        developer.log('❌ Error abriendo dispositivo Hikvision: $result');
      }

      return _deviceOpen;
    } catch (e) {
      developer.log('❌ Error en openDevice: $e');
      return false;
    }
  }

  static bool closeDevice() {
    if (!_initialized) return false;

    try {
      final result = _fpCloseDevice();
      final success = (result == HikvisionConstants.FP_SUCCESS);

      if (success) {
        _deviceOpen = false;
      }

      developer.log(
        success
            ? '✅ Dispositivo Hikvision cerrado'
            : '❌ Error cerrando dispositivo Hikvision: $result',
      );

      return success;
    } catch (e) {
      developer.log('❌ Error en closeDevice: $e');
      return false;
    }
  }

  static bool detectFinger() {
    if (!_initialized || !_deviceOpen) return false;

    try {
      final fpStatus = malloc<Int32>();
      final result = _fpDetectFinger(fpStatus);

      if (result == HikvisionConstants.FP_SUCCESS) {
        final hasFingerprint = fpStatus.value == 1;
        malloc.free(fpStatus);
        return hasFingerprint;
      } else {
        malloc.free(fpStatus);
        return false;
      }
    } catch (e) {
      developer.log('❌ Error detectando dedo: $e');
      return false;
    }
  }

  static Uint8List? captureTemplate() {
    if (!_initialized || !_deviceOpen) return null;

    try {
      final template = malloc<Uint8>(HikvisionConstants.FP_FTP_MAX);
      final result = _fpFpEnroll(template);

      if (result == HikvisionConstants.FP_SUCCESS) {
        final templateData = Uint8List.fromList(
          template.asTypedList(HikvisionConstants.FP_FTP_MAX),
        );
        malloc.free(template);
        return templateData;
      } else {
        malloc.free(template);
        developer.log('⚠️ Error capturando template: $result');
        return null;
      }
    } catch (e) {
      developer.log('❌ Error en captureTemplate: $e');
      return null;
    }
  }

  static bool startCapture() {
    if (!_initialized || !_deviceOpen) return false;
    if (_captureTimer != null && _captureTimer!.isActive) return true;

    developer.log('👂 Iniciando captura continua de huellas...');
    _captureTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_deviceOpen) {
        timer.cancel();
        developer.log('🛑 Deteniendo captura: Dispositivo cerrado.');
        return;
      }
      final fpStatus = malloc<Int32>();
      final result = _fpDetectFinger(fpStatus);

      if (result == HikvisionConstants.FP_SUCCESS) {
        final hasFingerprint = fpStatus.value == 1;
        if (hasFingerprint) {
          // No hacer log para evitar spam
          _messageHandler?.call(
            HikvisionConstants.FP_MSG_PRESS_FINGER,
            nullptr,
          );
        }
      } else if (result != HikvisionConstants.FP_TIMEOUT) {
        // Solo registrar errores críticos
        developer.log('⚠️ Error en _fpDetectFinger: $result');
      }
      malloc.free(fpStatus);
    });
    return true;
  }

  static bool stopCapture() {
    if (_captureTimer != null) {
      _captureTimer!.cancel();
      _captureTimer = null;
      developer.log('🛑 Captura continua de huellas detenida.');
    }
    return true;
  }

  static bool installMessageHandler(void Function(int, Pointer<Void>) handler) {
    if (!_initialized) return false;

    try {
      _messageHandler = handler;

      // Crear y guardar el puntero solo si no existe, para evitar problemas con el GC.
      _callbackPointer ??= Pointer.fromFunction<FpMessageHandlerNative>(
        _nativeMessageHandler,
      );

      final result = _fpInstallMessageHandler(_callbackPointer!);

      if (result == HikvisionConstants.FP_SUCCESS) {
        developer.log(
          '✅ Manejador de mensajes instalado correctamente en el SDK.',
        );
        return true;
      } else {
        developer.log(
          '❌ Error del SDK al instalar el manejador de mensajes: código=$result',
        );
        return false;
      }
    } catch (e) {
      print('❌ Excepción en installMessageHandler: $e');
      return false;
    }
  }

  static Uint8List? captureImage() {
    if (!_initialized || !_deviceOpen) return null;

    try {
      final width = malloc<Int32>();
      final height = malloc<Int32>();

      // Crear buffer para la imagen
      final imageBufferSize =
          HikvisionConstants.FP_IMAGE_WIDTH *
          HikvisionConstants.FP_IMAGE_HEIGHT;
      final imageBuffer = malloc<Uint8>(imageBufferSize);

      final result = _fpCaptureImage(imageBuffer, width, height);

      if (result == HikvisionConstants.FP_SUCCESS) {
        final imageWidth = width.value;
        final imageHeight = height.value;
        final actualSize = imageWidth * imageHeight;

        final imageData = Uint8List.fromList(
          imageBuffer.asTypedList(actualSize),
        );

        malloc.free(imageBuffer);
        malloc.free(width);
        malloc.free(height);

        print(
          '📷 Imagen capturada: ${imageWidth}x$imageHeight, $actualSize bytes',
        );
        return imageData;
      } else {
        malloc.free(imageBuffer);
        malloc.free(width);
        malloc.free(height);
        print('⚠️ Error capturando imagen: $result');
        return null;
      }
    } catch (e) {
      print('❌ Error en captureImage: $e');
      return null;
    }
  }

  static String getDeviceInfo() {
    if (!_initialized) return '';

    try {
      final deviceInfo = malloc<Int8>(64);
      final result = _fpGetDeviceInfo(deviceInfo);

      if (result == HikvisionConstants.FP_SUCCESS) {
        final info = deviceInfo.cast<Utf8>().toDartString();
        malloc.free(deviceInfo);
        return info;
      } else {
        malloc.free(deviceInfo);
        return '';
      }
    } catch (e) {
      print('❌ Error obteniendo info del dispositivo: $e');
      return '';
    }
  }

  static String getSDKVersion() {
    if (!_initialized) return '';

    try {
      final sdkVersion = malloc<Int8>(64);
      final result = _fpGetSDKVersion(sdkVersion);

      if (result == HikvisionConstants.FP_SUCCESS) {
        final version = sdkVersion.cast<Utf8>().toDartString();
        malloc.free(sdkVersion);
        return version;
      } else {
        malloc.free(sdkVersion);
        return '';
      }
    } catch (e) {
      print('❌ Error obteniendo versión del SDK: $e');
      return '';
    }
  }
}
