# ========================================
# Major Patch Opcode Comparison Script
# (e.g., 6.58h -> 7.00)
# WARNING: This will take a very long time!
# ========================================

Write-Host "========================================"
Write-Host "Major Patch Opcode Comparison Started"
Write-Host "WARNING: This operation will take a very long time!"
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
Write-Host "[1/7] Activating virtual environment..."
$venvActivate = "..\$VENV_PATH\Scripts\Activate.ps1"
if (-Not (Test-Path $venvActivate)) {
    Write-Host "[ERROR] Virtual environment not found: ..\$VENV_PATH" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
& $venvActivate
Write-Host ""

# Create output folders
if (-Not (Test-Path "output\$NEW_VERSION")) {
    New-Item -ItemType Directory -Path "output\$NEW_VERSION" | Out-Null
}
if (-Not (Test-Path "traces")) {
    New-Item -ItemType Directory -Path "traces" | Out-Null
}

# 1. generate_deep_traces.py - Old version
Write-Host "[2/7] Generating traces for old version ($OLD_VERSION)..."
Write-Host "NOTE: This step will take a long time."
python ..\generate_deep_traces.py $OLD_EXE "traces\$OLD_VERSION-traces"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] generate_deep_traces.py failed (old version)" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
Write-Host "Complete: traces\$OLD_VERSION-traces" -ForegroundColor Green
Write-Host ""

# 2. generate_deep_traces.py - New version
Write-Host "[3/7] Generating traces for new version ($NEW_VERSION)..."
Write-Host "NOTE: This step will take a long time."
python ..\generate_deep_traces.py $NEW_EXE "traces\$NEW_VERSION-traces"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] generate_deep_traces.py failed (new version)" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
Write-Host "Complete: traces\$NEW_VERSION-traces" -ForegroundColor Green
Write-Host ""

# 3. generate_similarity_matrix.py
Write-Host "[4/7] Generating similarity matrix..."
Write-Host "NOTE: Very slow without GPU."
python ..\generate_similarity_matrix.py "traces\$OLD_VERSION-traces" "traces\$NEW_VERSION-traces" "$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_similarity.json"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] generate_similarity_matrix.py failed" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
Write-Host "Complete: output\$NEW_VERSION\${NEW_VERSION}_similarity.json" -ForegroundColor Green
Write-Host ""

# 4. vtable_alignment.py
Write-Host "[5/7] Aligning vtable and generating diff..."
$alignOutput = python ..\vtable_alignment.py $OLD_EXE $NEW_EXE "$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_similarity.json"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] vtable_alignment.py failed" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
# Save as UTF-8 without BOM with proper line breaks
$alignText = $alignOutput -join "`r`n"
[System.IO.File]::WriteAllText("$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_diff.json", $alignText, [System.Text.UTF8Encoding]::new($false))
Write-Host "Complete: output\$NEW_VERSION\${NEW_VERSION}_diff.json" -ForegroundColor Green
Write-Host ""

# 5. generate_opcodes_file.py (only if OLD_OPCODE_FILE exists)
if ($OLD_OPCODE_FILE -and (Test-Path $OLD_OPCODE_FILE)) {
    Write-Host "[6/7] Generating opcode file..."
    python ..\generate_opcodes_file.py $OLD_VERSION $NEW_VERSION "$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_diff.json" $OLD_OPCODE_FILE -o "$PSScriptRoot\output\$NEW_VERSION\${NEW_VERSION}_Ipcs.cs"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] generate_opcodes_file.py failed" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        exit 1
    }
    Write-Host "Complete: output\$NEW_VERSION\${NEW_VERSION}_Ipcs.cs" -ForegroundColor Green
    Write-Host ""
    
    # 6. generate_act_format.py
    Write-Host "[7/7] Generating ACT format..."
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
} else {
    if (-Not $OLD_OPCODE_FILE) {
        Write-Host "[6/7] Skipped: OLD_OPCODE_FILE not configured" -ForegroundColor Yellow
        Write-Host "[7/7] Skipped: Cannot generate ACT format without opcode file" -ForegroundColor Yellow
    } else {
        Write-Host "[6/7] Skipped: OLD_OPCODE_FILE not found ($OLD_OPCODE_FILE)" -ForegroundColor Yellow
        Write-Host "[7/7] Skipped: Cannot generate ACT format without opcode file" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "========================================"
Write-Host "Major Patch Opcode Comparison Complete!"
Write-Host "Result files in: output\$NEW_VERSION\"
Write-Host "  - ${NEW_VERSION}_diff.json"
Write-Host "  - ${NEW_VERSION}_similarity.json"
Write-Host "Trace files: traces\ folder"
if ($OLD_OPCODE_FILE -and (Test-Path $OLD_OPCODE_FILE)) {
    Write-Host "  - ${NEW_VERSION}_Ipcs.cs"
    Write-Host "  - ${NEW_VERSION}_act_format.txt"
}
Write-Host "========================================"
Read-Host "Press Enter to continue"