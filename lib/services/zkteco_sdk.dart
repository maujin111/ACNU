import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

class ZKTecoSDK {
  late final DynamicLibrary _lib;

  ZKTecoSDK() {
    final dllPath = 'C:\\Windows\\System32\\libzkfp.dll';

    try {
      _lib = DynamicLibrary.open(dllPath);
      print('✅ DLL cargada correctamente desde $dllPath');
    } catch (e) {
      print('❌ Error al cargar DLL: $dllPath\n$e');
      rethrow;
    }
  }

  // =============================
  // SDK BASICO
  // =============================

  late final int Function() init =
      _lib.lookupFunction<Int32 Function(), int Function()>('ZKFPM_Init');

  late final int Function() terminate =
      _lib.lookupFunction<Int32 Function(), int Function()>('ZKFPM_Terminate');

  late final int Function() getDeviceCount =
      _lib.lookupFunction<Int32 Function(), int Function()>('ZKFPM_GetDeviceCount');

  late final Pointer<Void> Function(int) openDevice =
      _lib.lookupFunction<Pointer<Void> Function(Int32),
          Pointer<Void> Function(int)>('ZKFPM_OpenDevice');

  late final int Function(Pointer<Void>) closeDevice =
      _lib.lookupFunction<Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)>('ZKFPM_CloseDevice');

  // =============================
  // PARAMETROS
  // =============================

  late final int Function(
    Pointer<Void>,
    int,
    Pointer<Uint8>,
    Pointer<Uint32>,
  ) getParameters =
      _lib.lookupFunction<
          Int32 Function(
              Pointer<Void>, Int32, Pointer<Uint8>, Pointer<Uint32>),
          int Function(Pointer<Void>, int, Pointer<Uint8>,
              Pointer<Uint32>)>('ZKFPM_GetParameters');

  late final int Function(
    Pointer<Void>,
    int,
    Pointer<Uint8>,
    int,
  ) setParameters =
      _lib.lookupFunction<
          Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>, Int32),
          int Function(
              Pointer<Void>, int, Pointer<Uint8>, int)>('ZKFPM_SetParameters');

  // =============================
  // CAPTURA
  // =============================

  late final int Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Uint8>,
    Pointer<Uint32>,
  ) acquireFingerprint =
      _lib.lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint32,
              Pointer<Uint8>, Pointer<Uint32>),
          int Function(Pointer<Void>, Pointer<Uint8>, int,
              Pointer<Uint8>, Pointer<Uint32>)>('ZKFPM_AcquireFingerprint');

  // =============================
  // BASE DE DATOS
  // =============================

  late final Pointer<Void> Function() dbInit =
      _lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'ZKFPM_DBInit');

  late final int Function(Pointer<Void>) dbFree =
      _lib.lookupFunction<Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)>('ZKFPM_DBFree');

  late final int Function(
    Pointer<Void>,
    int,
    Pointer<Uint8>,
    int,
  ) dbAdd =
      _lib.lookupFunction<
          Int32 Function(Pointer<Void>, Uint32, Pointer<Uint8>, Uint32),
          int Function(
              Pointer<Void>, int, Pointer<Uint8>, int)>('ZKFPM_DBAdd');

  late final int Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Uint8>,
    int,
  ) dbMatch =
      _lib.lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint32,
              Pointer<Uint8>, Uint32),
          int Function(Pointer<Void>, Pointer<Uint8>, int,
              Pointer<Uint8>, int)>('ZKFPM_DBMatch');

  late final int Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Uint32>,
    Pointer<Uint32>,
  ) dbIdentify =
      _lib.lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint32,
              Pointer<Uint32>, Pointer<Uint32>),
          int Function(Pointer<Void>, Pointer<Uint8>, int,
              Pointer<Uint32>, Pointer<Uint32>)>('ZKFPM_DBIdentify');

  late final int Function(
    Pointer<Void>,
    Pointer<Uint8>,
    Pointer<Uint8>,
    Pointer<Uint8>,
    Pointer<Uint8>,
    Pointer<Uint32>,
  ) dbMerge =
      _lib.lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>,
              Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint32>),
          int Function(
              Pointer<Void>,
              Pointer<Uint8>,
              Pointer<Uint8>,
              Pointer<Uint8>,
              Pointer<Uint8>,
              Pointer<Uint32>)>('ZKFPM_DBMerge');

  // ============================================================
  // METODOS AUXILIARES
  // ============================================================

  int _getIntParameter(Pointer<Void> deviceHandle, int code,
      {int defaultValue = 0}) {
    final valuePtr = calloc<Uint32>();
    final sizePtr = calloc<Uint32>()..value = 4;

    try {
      final result = getParameters(
        deviceHandle,
        code,
        valuePtr.cast<Uint8>(),
        sizePtr,
      );

      if (result != 0) {
        // En lugar de lanzar excepción, devolvemos un valor por defecto
        // para que la app no se cierre si el sensor está ocupado
        return defaultValue;
      }

      return valuePtr.value;
    } finally {
      calloc.free(valuePtr);
      calloc.free(sizePtr);
    }
  }

  int getImageWidth(Pointer<Void> deviceHandle) =>
      _getIntParameter(deviceHandle, 1, defaultValue: 300);

  int getImageHeight(Pointer<Void> deviceHandle) =>
      _getIntParameter(deviceHandle, 2, defaultValue: 375);

  // ============================================================
  // CAPTURA CORRECTA
  // ============================================================

  ZKCaptureResult? captureFingerprint(Pointer<Void> deviceHandle,
      {int? prefWidth, int? prefHeight}) {
    const templateMaxSize = 2048;

    int width = prefWidth ?? getImageWidth(deviceHandle);
    int height = prefHeight ?? getImageHeight(deviceHandle);

    // Normalización para ZK9500 si detectamos el patrón de ~112k
    if ((width * height) > 110000 && (width * height) < 115000) {
      width = 300;
      height = 375;
    }

    final imageSize = width * height;
    final imagePtr = calloc<Uint8>(imageSize + 2048);
    final templatePtr = calloc<Uint8>(templateMaxSize);
    final templateLenPtr = calloc<Uint32>()..value = templateMaxSize;

    try {
      final result = acquireFingerprint(
        deviceHandle,
        imagePtr,
        imageSize,
        templatePtr,
        templateLenPtr,
      );

      // Log para ver qué está pasando realmente
      if (result != -1) { // Ignoramos -1 que es "sin dedo" constante
        print("DEBUG: ZK Acquire Result = $result, TemplateLen = ${templateLenPtr.value}");
      }

      // Si el resultado es != 0 y != -8, no hay dedo
      if (result != 0 && result != -8) return null;

      final imageData = Uint8List.fromList(imagePtr.asTypedList(imageSize));
      
      // FILTRO DE "NO DEDO": Comprobamos si la imagen tiene contenido real
      // Las imágenes vacías suelen tener todos los píxeles iguales o muy parecidos
      bool hasContent = false;
      final firstPixel = imageData[0];
      // Muestreamos algunos píxeles para ser eficientes
      for (int i = 0; i < imageData.length; i += 100) {
        if ((imageData[i] - firstPixel).abs() > 30) { // Diferencia de contraste mínima
          hasContent = true;
          break;
        }
      }

      if (!hasContent) return null;

      final length = templateLenPtr.value;
      return ZKCaptureResult(
        image: imageData,
        template: (result == 0 && length > 0)
            ? Uint8List.fromList(templatePtr.asTypedList(length))
            : Uint8List(0),
        width: width,
        height: height,
      );
    } catch (e) {
      print("DEBUG: Exception in capture: $e");
      return null;
    } finally {
      calloc.free(imagePtr);
      calloc.free(templatePtr);
      calloc.free(templateLenPtr);
    }
  }
}

class ZKCaptureResult {
  final Uint8List image;
  final Uint8List template;
  final int width;
  final int height;

  ZKCaptureResult({
    required this.image,
    required this.template,
    required this.width,
    required this.height,
  });
}
  