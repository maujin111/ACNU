# Script para copiar la DLL del SDK de Hikvision al directorio de salida
param(
    [string]$BuildType = "release"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Copiando DLL del SDK de Hikvision..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Rutas
$sourceDir = "SDKHIKVISION\libs\x64"
$sourceDll = "$sourceDir\FPModule_SDK_x64.dll"

# Determinar rutas de destino
$targets = @()

if ($BuildType -eq "release") {
    $targets += "build\windows\x64\runner\Release"
} else {
    $targets += "build\windows\x64\runner\Debug"
}

# Agregar ubicaciones adicionales para asegurar que la DLL sea encontrada
$targets += "build\windows\runner\Release"
$targets += "build\windows\runner\Debug"
$targets += "windows"

# Verificar que existe la DLL fuente
if (-not (Test-Path $sourceDll)) {
    Write-Host "ERROR: No se encontro la DLL fuente: $sourceDll" -ForegroundColor Red
    Write-Host "Buscando en ubicaciones alternativas..." -ForegroundColor Yellow
    
    # Buscar en otras ubicaciones posibles
    $alternatePaths = @(
        "SDKHIKVISION\FPModule_SDK_x64.dll",
        "FPModule_SDK_x64.dll"
    )
    
    foreach ($altPath in $alternatePaths) {
        if (Test-Path $altPath) {
            $sourceDll = $altPath
            Write-Host "Encontrada en: $altPath" -ForegroundColor Green
            break
        }
    }
    
    if (-not (Test-Path $sourceDll)) {
        Write-Host "No se encontro la DLL en ninguna ubicacion conocida." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nDLL Fuente encontrada:" -ForegroundColor Green
$sourceInfo = Get-Item $sourceDll
Write-Host "  Ruta: $sourceDll" -ForegroundColor Cyan
Write-Host "  Tamano: $($sourceInfo.Length) bytes" -ForegroundColor Cyan
Write-Host "  Fecha: $($sourceInfo.LastWriteTime)" -ForegroundColor Cyan

$successCount = 0
$totalTargets = $targets.Count

Write-Host "`nCopiando a $totalTargets ubicaciones..." -ForegroundColor Yellow

foreach ($targetDir in $targets) {
    $targetDll = "$targetDir\FPModule_SDK_x64.dll"
    
    # Crear directorio destino si no existe
    if (-not (Test-Path $targetDir)) {
        Write-Host "`nCreando directorio: $targetDir" -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        } catch {
            Write-Host "  No se pudo crear el directorio: $_" -ForegroundColor Red
            continue
        }
    }
    
    # Copiar la DLL
    try {
        Copy-Item -Path $sourceDll -Destination $targetDll -Force
        Write-Host "`n  OK: $targetDll" -ForegroundColor Green
        $successCount++
        
        # Verificar que se copio correctamente
        if (Test-Path $targetDll) {
            $fileInfo = Get-Item $targetDll
            Write-Host "      Tamano: $($fileInfo.Length) bytes" -ForegroundColor Gray
        }
    } catch {
        Write-Host "`n  ERROR: $targetDll - $_" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Resultado: $successCount de $totalTargets copias exitosas" -ForegroundColor $(if ($successCount -eq $totalTargets) { "Green" } else { "Yellow" })
Write-Host "========================================" -ForegroundColor Cyan

if ($successCount -gt 0) {
    Write-Host "`nProceso completado exitosamente!" -ForegroundColor Green
    Write-Host "Ahora puedes ejecutar la aplicacion y el SDK deberia detectar el lector." -ForegroundColor Cyan
} else {
    Write-Host "`nAdvertencia: No se pudo copiar la DLL a ninguna ubicacion." -ForegroundColor Red
    exit 1
}
