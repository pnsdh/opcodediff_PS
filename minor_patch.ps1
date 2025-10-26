# ========================================
# Minor Patch Opcode Comparison Script
# (e.g., 7.00h -> 7.01)
# ========================================

Write-Host "========================================"
Write-Host "Minor Patch Opcode Comparison Started"
Write-Host "========================================"
Write-Host ""

# Move to scripts folder
Set-Location $PSScriptRoot

# Load configuration from config.ps1
if (-Not (Test-Path "config.ps1")) {
    Write-Host "[ERROR] config.ps1 file not found." -ForegroundColor Red
    Write-Host "Please create and configure config.ps1 first."
    Read-Host "Press Enter to continue"
    exit 1
}

# Load config file content
$configContent = Get-Content "config.ps1" -Raw
Invoke-Expression $configContent

# Check required files
if (-Not (Test-Path $OLD_EXE)) {
    Write-Host "[ERROR] $OLD_EXE file not found." -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}

if (-Not (Test-Path $NEW_EXE)) {
    Write-Host "[ERROR] $NEW_EXE file not found." -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}

# Activate virtual environment
Write-Host "[1/5] Activating virtual environment..."
$venvActivate = "..\$VENV_PATH\Scripts\Activate.ps1"
if (-Not (Test-Path $venvActivate)) {
    Write-Host "[ERROR] Virtual environment not found: ..\$VENV_PATH" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
& $venvActivate
Write-Host ""

# Create output folder
if (-Not (Test-Path "output\$NEW_VERSION")) {
    New-Item -ItemType Directory -Path "output\$NEW_VERSION" | Out-Null
}

# 1. Run vtable_diff.py
Write-Host "[2/5] Generating vtable diff..."
$diffOutput = python ..\vtable_diff.py $OLD_EXE $NEW_EXE
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] vtable_diff.py execution failed" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
# Save as UTF-8 without BOM with proper line breaks
$diffText = $diffOutput -join "`r`n"
[System.IO.File]::WriteAllText("$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_diff.json", $diffText, [System.Text.UTF8Encoding]::new($false))
Write-Host "Complete: output\$NEW_VERSION\${NEW_VERSION}_diff.json" -ForegroundColor Green
Write-Host ""

# 2. Run generate_opcodes_file.py (only if OLD_OPCODE_FILE exists)
if ($OLD_OPCODE_FILE -and (Test-Path $OLD_OPCODE_FILE)) {
    Write-Host "[3/5] Generating opcode file..."
    python ..\generate_opcodes_file.py $OLD_VERSION $NEW_VERSION "$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_diff.json" $OLD_OPCODE_FILE -o "$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_Ipcs.cs"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] generate_opcodes_file.py execution failed" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        exit 1
    }
    Write-Host "Complete: output\$NEW_VERSION\${NEW_VERSION}_Ipcs.cs" -ForegroundColor Green
    Write-Host ""
    
    # 3. Run generate_act_format.py
    Write-Host "[4/5] Generating ACT format..."
    $actOutput = python ..\generate_act_format.py "$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_Ipcs.cs"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARNING] generate_act_format.py failed (this is optional)" -ForegroundColor Yellow
    } else {
        # Save ACT format to file with proper line breaks
        $actText = $actOutput -join "`r`n"
        [System.IO.File]::WriteAllText("$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_act_format.txt", $actText, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Complete: output\$NEW_VERSION\${NEW_VERSION}_act_format.txt" -ForegroundColor Green
    }
    Write-Host ""
    
    Write-Host "[5/5] Skipped: Validation (optional feature disabled)" -ForegroundColor Yellow
    Write-Host ""
} else {
    if (-Not $OLD_OPCODE_FILE) {
        Write-Host "[3/5] Skipped: OLD_OPCODE_FILE not configured" -ForegroundColor Yellow
        Write-Host "[4/5] Skipped: Cannot generate ACT format without opcode file" -ForegroundColor Yellow
    } else {
        Write-Host "[3/5] Skipped: OLD_OPCODE_FILE not found ($OLD_OPCODE_FILE)" -ForegroundColor Yellow
        Write-Host "[4/5] Skipped: Cannot generate ACT format without opcode file" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "[5/5] Skipped: Validation (optional feature disabled)" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "========================================"
Write-Host "Minor Patch Opcode Comparison Complete!"
Write-Host "Result files in: output\$NEW_VERSION\"
Write-Host "  - ${NEW_VERSION}_diff.json"
if ($OLD_OPCODE_FILE -and (Test-Path $OLD_OPCODE_FILE)) {
    Write-Host "  - ${NEW_VERSION}_Ipcs.cs"
    Write-Host "  - ${NEW_VERSION}_act_format.txt"
}
Write-Host "========================================"
Read-Host "Press Enter to continue"