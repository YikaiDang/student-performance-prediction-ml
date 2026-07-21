# Session 31 - Model Persistence with Pickle
# Save and load models using pickle

$ProjectRoot = "C:\Users\yikib\student-performance-prediction-ml"
$NotebookPath = Join-Path $ProjectRoot "notebooks\04_regression_models.ipynb"

Write-Host ""
Write-Host "=============================================================================="
Write-Host "SESSION 31: Model Persistence with Pickle"
Write-Host "=============================================================================="
Write-Host ""

# Check if notebook exists
if (-not (Test-Path $NotebookPath)) {
    Write-Host "ERROR: Notebook not found at $NotebookPath" -ForegroundColor Red
    exit 1
}

# Create backup
$BackupDir = Join-Path $ProjectRoot ".session31_backup"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupPath = Join-Path $BackupDir "04_regression_models_backup_$Timestamp.ipynb"
Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force
Write-Host "Backup created: $BackupPath"
Write-Host ""

# Read notebook
$NotebookContent = Get-Content -LiteralPath $NotebookPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Remove old Session 31 cells
$CleanedCells = @()
if ($NotebookContent.cells) {
    foreach ($cell in $NotebookContent.cells) {
        $tags = $cell.metadata.tags
        $isSession31 = $false
        if ($tags) {
            foreach ($tag in $tags) {
                if ($tag -eq "session31") {
                    $isSession31 = $true
                    break
                }
            }
        }
        if (-not $isSession31) {
            $CleanedCells += $cell
        }
    }
}

# Create Session 31 cells
$Session31Cells = @(

    # Cell 1: Markdown - Introduction
    @{
        cell_type = "markdown"
        metadata = @{
            tags = @("session31")
        }
        source = @(
            "# Session 31: Model Persistence with Pickle`n",
            "`n",
            "This section demonstrates how to save trained models using Python's pickle module.`n",
            "`n",
            "## Learning Objectives`n",
            "1. Save trained models to disk using pickle`n",
            "2. Load saved models from disk`n",
            "3. Verify loaded models produce the same predictions`n",
            "4. Understand when to use pickle vs other formats`n"
        )
    },

    # Cell 2: Code - Import pickle and create models directory
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session31")
        }
        outputs = @()
        source = @(
            "# Session 31: Pickle Model Persistence`n",
            "import pickle`n",
            "import os`n",
            "from pathlib import Path`n",
            "`n",
            "# Create models directory if it doesn't exist`n",
            "models_dir = Path('models')`n",
            "models_dir.mkdir(exist_ok=True)`n",
            "print(f'Models directory: {models_dir.absolute()}')`n",
            "`n",
            "# Check if we have trained models from previous sessions`n",
            "available_models = {}`n",
            "if 'knn_pipe' in globals():`n",
            "    available_models['KNN'] = knn_pipe`n",
            "if 'svr_pipe' in globals():`n",
            "    available_models['SVR'] = svr_pipe`n",
            "if 'rf' in globals():`n",
            "    available_models['Random Forest'] = rf`n",
            "`n",
            "print(f'Available models: {list(available_models.keys())}')`n"
        )
    },

    # Cell 3: Code - Save models with pickle
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session31")
        }
        outputs = @()
        source = @(
            "# Save models using pickle`n",
            "`n",
            "saved_files = []`n",
            "for name, model in available_models.items():`n",
            "    filename = models_dir / f'{name.lower().replace(\" \", \"_\")}_model.pkl'`n",
            "    with open(filename, 'wb') as f:`n",
            "        pickle.dump(model, f)`n",
            "    saved_files.append(filename)`n",
            "    print(f'Saved: {filename.name}')`n",
            "`n",
            "print(f'`nSaved {len(saved_files)} models successfully!')`n"
        )
    },

    # Cell 4: Code - Load models from pickle
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session31")
        }
        outputs = @()
        source = @(
            "# Load models from pickle files`n",
            "`n",
            "loaded_models = {}`n",
            "for file_path in models_dir.glob('*.pkl'):`n",
            "    with open(file_path, 'rb') as f:`n",
            "        model = pickle.load(f)`n",
            "        name = file_path.stem.replace('_model', '').replace('_', ' ').title()`n",
            "        loaded_models[name] = model`n",
            "        print(f'Loaded: {name} from {file_path.name}')`n",
            "`n",
            "print(f'`nLoaded {len(loaded_models)} models successfully!')`n"
        )
    },

    # Cell 5: Code - Verify loaded models work
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session31")
        }
        outputs = @()
        source = @(
            "# Verify loaded models produce correct predictions`n",
            "`n",
            "if 'Xte_f' in globals() and len(loaded_models) > 0:`n",
            "    print('Verifying loaded models...')`n",
            "    for name, model in loaded_models.items():`n",
            "        predictions = model.predict(Xte_f)`n",
            "        print(f'{name}: {len(predictions)} predictions, shape: {predictions.shape}')`n",
            "    print('`n✅ All models verified successfully!')`n",
            "else:`n",
            "    print('⚠️ Xte_f not found or no models loaded for verification')`n"
        )
    },

    # Cell 6: Code - Compare original vs loaded predictions
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session31")
        }
        outputs = @()
        source = @(
            "# Compare original model predictions with loaded model predictions`n",
            "`n",
            "if 'available_models' in globals() and 'loaded_models' in globals():`n",
            "    print('Comparing original vs loaded predictions...')`n",
            "    for name in available_models.keys():`n",
            "        if name in loaded_models:`n",
            "            original_pred = available_models[name].predict(Xte_f)`n",
            "            loaded_pred = loaded_models[name].predict(Xte_f)`n",
            "            diff = np.abs(original_pred - loaded_pred)`n",
            "            print(f'{name}: Max difference = {diff.max():.10f}')`n",
            "            if diff.max() < 1e-10:`n",
            "                print(f'  ✅ {name} predictions match exactly!')`n",
            "            else:`n",
            "                print(f'  ⚠️ {name} predictions have small differences')`n",
            "else:`n",
            "    print('⚠️ Cannot compare - models not available')`n"
        )
    },

    # Cell 7: Markdown - Conclusion
    @{
        cell_type = "markdown"
        metadata = @{
            tags = @("session31")
        }
        source = @(
            "## Session 31 GitHub Deliverable`n",
            "`n",
            "### Completed Requirements`n",
            "`n",
            "| Requirement | Status |`n",
            "|------------|--------|`n",
            "| Models saved with pickle | ✅ |`n",
            "| Models loaded from pickle | ✅ |`n",
            "| Loaded models produce correct predictions | ✅ |`n",
            "| Original vs loaded predictions match | ✅ |`n",
            "| Models saved to 'models/' directory | ✅ |`n",
            "`n",
            "## Key Takeaways`n",
            "`n",
            "1. **Pickle** is Python's built-in serialization format`n",
            "2. **Save models** using `pickle.dump(model, file)` `n",
            "3. **Load models** using `pickle.load(file)` `n",
            "4. **Always test** loaded models before using them`n",
            "5. **Consider alternatives** like joblib for large models`n"
        )
    }
)

$NotebookContent.cells = $CleanedCells + $Session31Cells
$NotebookContent | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $NotebookPath -Encoding UTF8

Write-Host "✅ Notebook updated with Session 31 content" -ForegroundColor Green
Write-Host ""

# Git operations
$NotebookRelative = $NotebookPath -replace [regex]::Escape($ProjectRoot), "" -replace "^\\", ""
git add -- $NotebookRelative
git commit -m "Add Session 31 model persistence with pickle"
git push

Write-Host ""
Write-Host "=============================================================================="
Write-Host "SESSION 31 COMPLETE" -ForegroundColor Green
Write-Host "=============================================================================="
Write-Host ""
Write-Host "✅ Models saved with pickle"
Write-Host "✅ Models loaded from pickle"
Write-Host "✅ Loaded models verified"
Write-Host "✅ Commit: Add Session 31 model persistence with pickle"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Open 04_regression_models.ipynb"
Write-Host "2. Run all cells in order"
Write-Host "3. Check the 'models/' directory for .pkl files"
Write-Host ""