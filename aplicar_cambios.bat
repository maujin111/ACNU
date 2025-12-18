@echo off
REM ========================================
REM Script para aplicar cambios de paquetes
REM ========================================

echo.
echo ========================================
echo APLICANDO CAMBIOS DE PAQUETES
echo ========================================
echo.

echo [1/5] Limpiando build anterior...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: flutter clean fallo
    pause
    exit /b 1
)
echo ✅ Build limpiado
echo.

echo [2/5] Obteniendo dependencias...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: flutter pub get fallo
    echo.
    echo Posibles causas:
    echo - Conflicto de versiones
    echo - Conexion a internet
    echo.
    pause
    exit /b 1
)
echo ✅ Dependencias obtenidas
echo.

echo [3/5] Verificando conflictos...
call flutter pub deps > deps_output.txt
findstr /C:"!" deps_output.txt
if %errorlevel% equ 0 (
    echo ⚠️ ADVERTENCIA: Se encontraron conflictos
    echo Revisa deps_output.txt para detalles
    pause
) else (
    echo ✅ Sin conflictos detectados
)
del deps_output.txt
echo.

echo [4/5] Compilando para Windows...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo ERROR: Compilacion fallo
    echo.
    echo Revisa los errores arriba
    echo Si hay errores de paquetes, ejecuta:
    echo   flutter pub upgrade --major-versions
    echo.
    pause
    exit /b 1
)
echo ✅ Compilacion exitosa
echo.

echo [5/5] Verificando ejecutable...
if exist "build\windows\x64\runner\Release\anfibius_uwu.exe" (
    echo ✅ Ejecutable creado correctamente
    echo.
    echo Ubicacion: build\windows\x64\runner\Release\anfibius_uwu.exe
) else (
    echo ⚠️ No se encontro el ejecutable
)
echo.

echo ========================================
echo CAMBIOS APLICADOS EXITOSAMENTE
echo ========================================
echo.
echo Resumen de cambios:
echo   ✅ flutter_local_notifications: 19.2.1 → 17.2.3
echo   ✅ flutter_local_notifications_windows: REMOVIDO
echo   ✅ system_tray: REMOVIDO
echo   ✅ share_plus: 10.1.2 → 7.2.2
echo.
echo Ejecutar app:
echo   build\windows\x64\runner\Release\anfibius_uwu.exe
echo.
pause
