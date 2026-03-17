# Script de diagnóstico para el SDK de Hikvision
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Diagnóstico del SDK de Hikvision" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Verificar la DLL fuente
Write-Host "`n1. Verificando DLL fuente..." -ForegroundColor Yellow

$sourcePaths = @(
    "SDKHIKVISION\libs\x64\FPModule_SDK_x64.dll",
    "SDKHIKVISION\FPModule_SDK_x64.dll",
    "FPModule_SDK_x64.dll"
)

$dllFound = $false
foreach ($path in $sourcePaths) {
    if (Test-Path $path) {
        Write-Host "  OK: Encontrada en $path" -ForegroundColor Green
        $fileInfo = Get-Item $path
        Write-Host "      Tamaño: $($fileInfo.Length) bytes" -ForegroundColor Cyan
        Write-Host "      Fecha: $($fileInfo.LastWriteTime)" -ForegroundColor Cyan
        $dllFound = $true
        break
    }
}

if (-not $dllFound) {
    Write-Host "  ERROR: No se encontró la DLL fuente" -ForegroundColor Red
    Write-Host "  Asegúrate de que el SDK está en SDKHIKVISION\libs\x64\" -ForegroundColor Yellow
}

# Verificar las DLLs en los directorios de compilación
Write-Host "`n2. Verificando DLLs en directorios de compilación..." -ForegroundColor Yellow

$buildPaths = @(
    "build\windows\x64\runner\Release\FPModule_SDK_x64.dll",
    "build\windows\x64\runner\Debug\FPModule_SDK_x64.dll",
    "build\windows\runner\Release\FPModule_SDK_x64.dll",
    "build\windows\runner\Debug\FPModule_SDK_x64.dll"
)

$buildDllsFound = 0
foreach ($path in $buildPaths) {
    if (Test-Path $path) {
        Write-Host "  OK: $path" -ForegroundColor Green
        $buildDllsFound++
    } else {
        Write-Host "  No encontrada: $path" -ForegroundColor Gray
    }
}

if ($buildDllsFound -eq 0) {
    Write-Host "`n  ADVERTENCIA: No se encontraron DLLs en los directorios de compilación" -ForegroundColor Red
    Write-Host "  Ejecuta: .\copy_dll.ps1" -ForegroundColor Yellow
}

# Verificar dispositivos USB conectados
Write-Host "`n3. Verificando dispositivos USB..." -ForegroundColor Yellow

try {
    $usbDevices = Get-PnpDevice | Where-Object { $_.Class -eq "Biometric" -or $_.FriendlyName -like "*fingerprint*" -or $_.FriendlyName -like "*huella*" }
    
    if ($usbDevices) {
        Write-Host "  Dispositivos biométricos encontrados:" -ForegroundColor Green
        foreach ($device in $usbDevices) {
            Write-Host "    - $($device.FriendlyName) [$($device.Status)]" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  No se encontraron dispositivos biométricos USB" -ForegroundColor Yellow
        Write-Host "  Verificando todos los dispositivos USB..." -ForegroundColor Gray
        
        $allUsb = Get-PnpDevice | Where-Object { $_.Class -eq "USB" -and $_.Status -eq "OK" }
        Write-Host "  Dispositivos USB conectados: $($allUsb.Count)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "  No se pudo verificar dispositivos USB: $_" -ForegroundColor Red
}

# Verificar estructura de directorios del SDK
Write-Host "`n4. Verificando estructura del SDK..." -ForegroundColor Yellow

$sdkPaths = @(
    "SDKHIKVISION\libs\x64",
    "SDKHIKVISION\include",
    "SDKHIKVISION\docs"
)

foreach ($path in $sdkPaths) {
    if (Test-Path $path) {
        $itemCount = (Get-ChildItem $path -File).Count
        Write-Host "  OK: $path ($itemCount archivos)" -ForegroundColor Green
    } else {
        Write-Host "  No existe: $path" -ForegroundColor Red
    }
}

# Recomendaciones finales
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Recomendaciones:" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

if (-not $dllFound) {
    Write-Host "1. Copia la DLL del SDK a SDKHIKVISION\libs\x64\" -ForegroundColor Red
}

if ($buildDllsFound -eq 0) {
    Write-Host "2. Ejecuta: .\copy_dll.ps1 para copiar la DLL" -ForegroundColor Yellow
}

Write-Host "3. Asegúrate de que el lector de huellas esté conectado por USB" -ForegroundColor Cyan
Write-Host "4. Ejecuta la aplicación y presiona 'Buscar Dispositivos'" -ForegroundColor Cyan
Write-Host "5. Revisa la consola de la app para ver los logs del SDK" -ForegroundColor Cyan

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Diagnóstico completado" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
