import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
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
  static late int Function(Pointer<Uint8> template) _fpGetQuality;
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

  static bool initialize() {
    if (_initialized) return true;

    try {
      // Obtener el directorio donde se está ejecutando la aplicación
      String? executablePath;
      if (!kIsWeb && Platform.isWindows) {
        executablePath = Platform.resolvedExecutable;
        final executableDir = File(executablePath).parent.path;
        print('📁 Directorio del ejecutable: $executableDir');
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
          print('🔍 Intentando cargar SDK desde: $path');
          loadedLib = DynamicLibrary.open(path);
          print('✅ SDK cargado exitosamente desde: $path');
          break;
        } catch (e) {
          print('⚠️ No se pudo cargar desde $path: $e');
          continue;
        }
      }

      if (loadedLib == null) {
        print('❌ No se pudo encontrar la DLL del SDK en ninguna ubicación');
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
      _fpInstallMessageHandler = _lib!.lookupFunction<
        Int32 Function(Pointer<NativeFunction<FpMessageHandlerNative>>),
        int Function(Pointer<NativeFunction<FpMessageHandlerNative>>)
      >('FPModule_InstallMessageHandler');
      _fpFpEnroll = _lib!.lookupFunction<
        Int32 Function(Pointer<Uint8>),
        int Function(Pointer<Uint8>)
      >('FPModule_FpEnroll');
      _fpGetQuality = _lib!.lookupFunction<
        Int32 Function(Pointer<Uint8>),
        int Function(Pointer<Uint8>)
      >('FPModule_GetQuality');
      _fpMatchTemplate = _lib!.lookupFunction<
        Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Int32),
        int Function(Pointer<Uint8>, Pointer<Uint8>, int)
      >('FPModule_MatchTemplate');
      _fpGetDeviceInfo = _lib!.lookupFunction<
        Int32 Function(Pointer<Int8>),
        int Function(Pointer<Int8>)
      >('FPModule_GetDeviceInfo');
      _fpGetSDKVersion = _lib!.lookupFunction<
        Int32 Function(Pointer<Int8>),
        int Function(Pointer<Int8>)
      >('FPModule_GetSDKVersion');

      _initialized = true;
      print('✅ SDK Hikvision inicializado exitosamente');

      return _initialized;
    } catch (e) {
      print('❌ Error cargando SDK Hikvision: $e');
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
        print('✅ SDK Hikvision limpiado');
      } catch (e) {
        print('⚠️ Error al limpiar SDK: $e');
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

      print(
        _deviceOpen
            ? '✅ Dispositivo Hikvision abierto exitosamente'
            : '❌ Error abriendo dispositivo Hikvision: $result',
      );

      return _deviceOpen;
    } catch (e) {
      print('❌ Error en openDevice: $e');
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

      print(
        success
            ? '✅ Dispositivo Hikvision cerrado'
            : '❌ Error cerrando dispositivo Hikvision: $result',
      );

      return success;
    } catch (e) {
      print('❌ Error en closeDevice: $e');
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
      print('❌ Error detectando dedo: $e');
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
        print('⚠️ Error capturando template: $result');
        return null;
      }
    } catch (e) {
      print('❌ Error en captureTemplate: $e');
      return null;
    }
  }

  static bool startCapture() {
    // No hay función específica de start capture en este SDK
    // La captura se hace con detectFinger + captureTemplate
    return _deviceOpen;
  }

  static bool stopCapture() {
    // No hay función específica de stop capture en este SDK
    return true;
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
          '📷 Imagen capturada: ${imageWidth}x${imageHeight}, ${actualSize} bytes',
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
