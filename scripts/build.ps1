
$ErrorActionPreference = "Stop"

# ============================================================
# PIC Assembly Build Script
# Target: PIC16F1455
# Assembler: MPLAB X v3.35 MPASMX
#
# Source files are staged in Windows TEMP because MPASMX
# can have problems accessing files through WSL UNC paths.
# ============================================================

Write-Host ""
Write-Host "Building PIC16F1455..." -ForegroundColor Cyan

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

$MpasmDir = "C:\Program Files (x86)\Microchip\MPLABX\v3.35\mpasmx"

$Assembler = Join-Path $MpasmDir "mpasmx.exe"
$DeviceInclude = Join-Path $MpasmDir "P16F1455.INC"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$ProjectRoot = Join-Path $WorkspaceRoot "projects\PIC16F1455_project"

$SourceFile = Join-Path $ProjectRoot "src\main.asm"
$BuildDir = Join-Path $ProjectRoot "build"

$StagingDir = Join-Path $env:TEMP "PIC16F1455_build"

# ------------------------------------------------------------
# Helper: Validate Intel HEX
# ------------------------------------------------------------

function Test-IntelHex {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Write-Host "Validating HEX: $Path"

    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Host "FAIL: HEX file does not exist."
        return $false
    }

    $Lines = @(Get-Content -LiteralPath $Path)

    if ($Lines.Count -eq 0) {
        Write-Host "FAIL: HEX file is empty."
        return $false
    }

    $EofFound = $false

    foreach ($Line in $Lines) {

        if ($Line -notmatch '^:[0-9A-Fa-f]+$') {
            Write-Host "FAIL: Invalid record format: $Line"
            return $false
        }

        $Hex = $Line.Substring(1)

        if (($Hex.Length % 2) -ne 0) {
            Write-Host "FAIL: Invalid record length."
            return $false
        }

        $Bytes = @(
            for ($i = 0; $i -lt $Hex.Length; $i += 2) {
                [Convert]::ToInt32($Hex.Substring($i, 2), 16)
            }
        )

        if ($Bytes.Length -lt 5) {
            Write-Host "FAIL: Record too short."
            return $false
        }

        # Byte count must match record length.
        if ($Bytes[0] -ne ($Bytes.Length - 5)) {
            Write-Host "FAIL: Byte count mismatch."
            return $false
        }

        # Checksum: sum of all bytes must be divisible by 256.
        $Sum = 0

        foreach ($Byte in $Bytes) {
            $Sum += $Byte
        }

        if (($Sum % 256) -ne 0) {
            Write-Host "FAIL: Invalid checksum."
            return $false
        }

        # End-of-file record.
        if ($Bytes[3] -eq 1) {

            if ($Bytes[0] -ne 0) {
                Write-Host "FAIL: Invalid EOF record."
                return $false
            }

            $EofFound = $true
        }
    }

    if (!$EofFound) {
        Write-Host "FAIL: EOF record not found."
        return $false
    }

    return $true
}

# ------------------------------------------------------------
# Helper: Check assembler errors
# ------------------------------------------------------------

function Test-AssemblerErrors {
    param (
        [string]$ErrorFile
    )

    if (!(Test-Path -LiteralPath $ErrorFile)) {
        return $false
    }

    $Content = Get-Content -LiteralPath $ErrorFile -Raw

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $false
    }

    if ($Content -match '(?im)^\s*(Error|Fatal)\[\d+\]') {
        Write-Host "Assembler errors found:"
        Write-Host $Content
        return $true
    }

    return $false
}

# ------------------------------------------------------------
# Check required files
# ------------------------------------------------------------

if (!(Test-Path -LiteralPath $Assembler -PathType Leaf)) {
    Write-Host "BUILD FAILED: MPASMX executable not found." -ForegroundColor Red
    exit 1
}

if (!(Test-Path -LiteralPath $DeviceInclude -PathType Leaf)) {
    Write-Host "BUILD FAILED: PIC16F1455 include file not found." -ForegroundColor Red
    exit 1
}

if (!(Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
    Write-Host "BUILD FAILED: Source file not found: $SourceFile" -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------
# Prepare directories
# ------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null

# Remove previous generated files from staging.
Get-ChildItem -LiteralPath $StagingDir -Filter "main.*" -File |
    Remove-Item -Force

# ------------------------------------------------------------
# Stage source and device include
# ------------------------------------------------------------

Copy-Item -LiteralPath $SourceFile `
    -Destination (Join-Path $StagingDir "main.asm") -Force

Copy-Item -LiteralPath $DeviceInclude `
    -Destination (Join-Path $StagingDir "P16F1455.INC") -Force

Write-Host "Assembler: $Assembler"
Write-Host "Source:    $SourceFile"
Write-Host "Staging:   $StagingDir"
Write-Host ""

# ------------------------------------------------------------
# Run MPASMX
# ------------------------------------------------------------

try {

    $Process = Start-Process `
        -FilePath $Assembler `
        -ArgumentList "/p16F1455", "/aINHX32", "/l", "/e", "main.asm" `
        -WorkingDirectory $StagingDir `
        -Wait `
        -PassThru

    $AssemblerExitCode = $Process.ExitCode

}
catch {

    Write-Host "BUILD FAILED: Could not start MPASMX." -ForegroundColor Red
    Write-Host $_
    exit 1
}

Write-Host "MPASMX exit code: $AssemblerExitCode"

if ($AssemblerExitCode -ne 0) {
    Write-Host "WARNING: MPASMX returned a non-zero exit code." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Inspect generated files
# ------------------------------------------------------------

$HexSource = Join-Path $StagingDir "main.HEX"
$ErrorSource = Join-Path $StagingDir "main.ERR"

Write-Host ""
Write-Host "Generated files:"

Get-ChildItem -LiteralPath $StagingDir -Filter "main.*" -File |
    Select-Object Name, Length |
    Format-Table -AutoSize

# ------------------------------------------------------------
# Check assembler diagnostics
# ------------------------------------------------------------

$AssemblerErrors = Test-AssemblerErrors -ErrorFile $ErrorSource

if ($AssemblerErrors) {
    Write-Host "BUILD FAILED: Assembler reported errors." -ForegroundColor Red
    exit 1
}


# ------------------------------------------------------------
# Locate generated HEX file (case-insensitive)
# ------------------------------------------------------------

$HexFile = Get-ChildItem -LiteralPath $StagingDir -File |
    Where-Object { $_.BaseName -ieq "main" -and $_.Extension -ieq ".hex" } |
    Select-Object -First 1

if ($null -eq $HexFile) {
    Write-Host "BUILD FAILED: MPASMX did not generate a HEX file." -ForegroundColor Red
    exit 1
}

# Locate assembler error file
$ErrorFile = Get-ChildItem -LiteralPath $StagingDir -File |
    Where-Object { $_.BaseName -ieq "main" -and $_.Extension -ieq ".err" } |
    Select-Object -First 1

if ($null -ne $ErrorFile) {
    $AssemblerErrors = Test-AssemblerErrors -ErrorFile $ErrorFile.FullName

    if ($AssemblerErrors) {
        Write-Host "BUILD FAILED: Assembler reported errors." -ForegroundColor Red
        exit 1
    }
}

# ------------------------------------------------------------
# Copy generated outputs into project build directory
# ------------------------------------------------------------

Get-ChildItem -LiteralPath $StagingDir -File |
    Where-Object { $_.BaseName -ieq "main" -and $_.Extension -ine ".asm" } |
    Copy-Item -Destination $BuildDir -Force

# Use the actual generated filename
$HexDestination = Join-Path $BuildDir $HexFile.Name

Write-Host ""
Write-Host "HEX source:      $($HexFile.FullName)"
Write-Host "HEX destination: $HexDestination"

# ------------------------------------------------------------
# Validate final HEX output
# ------------------------------------------------------------

if (!(Test-IntelHex -Path $HexDestination)) {
    Write-Host "BUILD FAILED: HEX file missing or invalid." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "HEX validation successful." -ForegroundColor Green
Write-Host "Output: $HexDestination"
Write-Host ""
Write-Host "BUILD SUCCESSFUL." -ForegroundColor Green
