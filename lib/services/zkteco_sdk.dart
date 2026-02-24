import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

/// Clase FFI para el SDK de ZKTeco ZK9500
class ZKTecoSDK {
  late final DynamicLibrary _lib;

  ZKTecoSDK() {
    // Carga la DLL según la plataforma y arquitectura
    final libName = Platform.isWindows
        ? (Platform.version.contains('x64') ? 'ZKFingerSDK64.dll' : 'ZKFingerSDK.dll')
        : 'libzkfpc.so';
    _lib = DynamicLibrary.open(libName);
  }

  // Ejemplo: Declaración de función FFI para inicializar el dispositivo
  late final int Function() zkf_init =
      _lib.lookupFunction<Int32 Function(), int Function()>('zkf_init');

  // Ejemplo: Declaración de función FFI para cerrar el dispositivo
  late final int Function() zkf_exit =
      _lib.lookupFunction<Int32 Function(), int Function()>('zkf_exit');

  // Agrega aquí más funciones del SDK según el header de ZKTeco

  // Ejemplo: Captura de huella (debes adaptar según el SDK real)
  // int zkf_acquire_fingerprint(unsigned char* image, unsigned char* template, int* length)
  late final int Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>) zkf_acquire_fingerprint =
      _lib.lookupFunction<
        Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>),
        int Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>)
      >('zkf_acquire_fingerprint');
}
