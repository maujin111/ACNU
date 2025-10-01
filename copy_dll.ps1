# Script para copiar la DLL del SDK de Hikvision al directorio de salida
param(
    [string]$BuildType = "release"
)

Write-Host "Copiando DLL del SDK de Hikvision..." -ForegroundColor Green

# Rutas
$sourceDir = "SDKHIKVISION\libs\x64"
$sourceDll = "$sourceDir\FPModule_SDK_x64.dll"

if ($BuildType -eq "release") {
    $targetDir = "build\windows\x64\runner\Release"
} else {
    $targetDir = "build\windows\x64\runner\Debug"
}

$targetDll = "$targetDir\FPModule_SDK_x64.dll"

# Verificar que existe la DLL fuente
if (-not (Test-Path $sourceDll)) {
    Write-Host "ERROR: No se encontro la DLL fuente: $sourceDll" -ForegroundColor Red
    exit 1
}

# Crear directorio destino si no existe
if (-not (Test-Path $targetDir)) {
    Write-Host "Creando directorio destino: $targetDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# Copiar la DLL
try {
    Copy-Item -Path $sourceDll -Destination $targetDll -Force
    Write-Host "EXITO: DLL copiada exitosamente a: $targetDll" -ForegroundColor Green
    
    # Verificar que se copio correctamente
    if (Test-Path $targetDll) {
        $fileInfo = Get-Item $targetDll
        Write-Host "Tamano: $($fileInfo.Length) bytes" -ForegroundColor Cyan
        Write-Host "Fecha: $($fileInfo.LastWriteTime)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "ERROR: Error copiando la DLL: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Proceso completado exitosamente!" -ForegroundColor Green