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

  // --- Bindings FFI según demo Java y SDK C ---
  // int ZKFP_Init();
  late final int Function() init = _lib.lookupFunction<Int32 Function(), int Function()>('ZKFP_Init');
  // int ZKFP_Terminate();
  late final int Function() terminate = _lib.lookupFunction<Int32 Function(), int Function()>('ZKFP_Terminate');
  // int ZKFP_GetDeviceCount();
  late final int Function() getDeviceCount = _lib.lookupFunction<Int32 Function(), int Function()>('ZKFP_GetDeviceCount');
  // HANDLE ZKFP_OpenDevice(int index);
  late final Pointer<Void> Function(Int32) openDevice = _lib.lookupFunction<Pointer<Void> Function(Int32), Pointer<Void> Function(int)>('ZKFP_OpenDevice');
  // int ZKFP_CloseDevice(HANDLE hDevice);
  late final int Function(Pointer<Void>) closeDevice = _lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('ZKFP_CloseDevice');
  // HANDLE ZKFP_DBInit();
  late final Pointer<Void> Function() dbInit = _lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>('ZKFP_DBInit');
  // int ZKFP_DBFree(HANDLE hDB);
  late final int Function(Pointer<Void>) dbFree = _lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('ZKFP_DBFree');
  // int ZKFP_GetParameters(HANDLE hDevice, int paramCode, Pointer<Uint8> paramValue, Pointer<Int32> size);
  late final int Function(Pointer<Void>, Int32, Pointer<Uint8>, Pointer<Int32>) getParameters = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>, Pointer<Int32>),
    int Function(Pointer<Void>, int, Pointer<Uint8>, Pointer<Int32>)>('ZKFP_GetParameters');
  // int ZKFP_AcquireFingerprint(HANDLE hDevice, Pointer<Uint8> imageBuf, Pointer<Uint8> templateBuf, Pointer<Int32> templateLen);
  late final int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>) acquireFingerprint = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>),
    int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>)>('ZKFP_AcquireFingerprint');
  // int ZKFP_DBAdd(HANDLE hDB, int fid, Pointer<Uint8> templateBuf);
  late final int Function(Pointer<Void>, Int32, Pointer<Uint8>) dbAdd = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>),
    int Function(Pointer<Void>, int, Pointer<Uint8>)>('ZKFP_DBAdd');
  // int ZKFP_DBMatch(HANDLE hDB, Pointer<Uint8> template1, Pointer<Uint8> template2);
  late final int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>) dbMatch = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>),
    int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>)>('ZKFP_DBMatch');
  // int ZKFP_DBIdentify(HANDLE hDB, Pointer<Uint8> templateBuf, Pointer<Int32> fid, Pointer<Int32> score);
  late final int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>) dbIdentify = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>),
    int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>)>('ZKFP_DBIdentify');
  // int ZKFP_DBMerge(HANDLE hDB, Pointer<Uint8> t1, Pointer<Uint8> t2, Pointer<Uint8> t3, Pointer<Uint8> outTemplate, Pointer<Int32> outLen);
  late final int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>) dbMerge = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>),
    int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>)>('ZKFP_DBMerge');
}
