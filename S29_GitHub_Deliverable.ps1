param(
    [string]$ProjectRoot = "C:\Users\yikib\student-performance-prediction-ml",
    [string]$NotebookRelativePath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Helper function to get relative path (compatible with PowerShell 5.1)
function Get-RelativePath {
    param(
        [string]$From,
        [string]$To
    )
    
    $From = (Resolve-Path $From).Path
    $To = (Resolve-Path $To).Path
    
    $FromParts = $From -split '\\'
    $ToParts = $To -split '\\'
    
    $CommonPrefix = 0
    for ($i = 0; $i -lt $FromParts.Count -and $i -lt $ToParts.Count; $i++) {
        if ($FromParts[$i] -ne $ToParts[$i]) { break }
        $CommonPrefix++
    }
    
    $RelativeParts = @()
    
    # Add ".." for each remaining part in From
    for ($i = $CommonPrefix; $i -lt $FromParts.Count; $i++) {
        $RelativeParts += ".."
    }
    
    # Add remaining parts from To
    for ($i = $CommonPrefix; $i -lt $ToParts.Count; $i++) {
        $RelativeParts += $ToParts[$i]
    }
    
    return ($RelativeParts -join '\')
}

Write-Host ""
Write-Host "============================================================"
Write-Host " SESSION 29 - GITHUB DELIVERABLE AUTOMATION"
Write-Host " Extra Trees and Gradient Boosting Regression"
Write-Host "============================================================"
Write-Host ""

# ------------------------------------------------------------
# 1. Validate the project directory
# ------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "Project directory does not exist: $ProjectRoot"
}
Set-Location -LiteralPath $ProjectRoot
Write-Host "[1/12] Project directory:"
Write-Host " $ProjectRoot"
Write-Host ""

if (-not (Test-Path -LiteralPath ".git")) {
    throw "This directory is not a Git repository: $ProjectRoot"
}

# ------------------------------------------------------------
# 2. Validate Git
# ------------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or is not available in PATH."
}
$GitVersion = git --version
if ($LASTEXITCODE -ne 0) {
    throw "Git could not be executed."
}
Write-Host "[2/12] Git detected:"
Write-Host " $GitVersion"
Write-Host ""

# ------------------------------------------------------------
# 3. Select Python
# ------------------------------------------------------------
$PythonExecutable = $null
$PythonArguments = @()
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (Test-Path -LiteralPath $VenvPython) {
    $PythonExecutable = $VenvPython
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonExecutable = (Get-Command py).Source
    $PythonArguments = @("-3")
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonExecutable = (Get-Command python).Source
}
else {
    throw "Python was not found. Create the project virtual environment or install Python."
}
Write-Host "[3/12] Python selected:"
Write-Host " $PythonExecutable"
Write-Host ""

# ------------------------------------------------------------
# 4. Locate the regression notebook
# ------------------------------------------------------------
$NotebooksDirectory = Join-Path $ProjectRoot "notebooks"
if (-not (Test-Path -LiteralPath $NotebooksDirectory)) {
    throw "The notebooks directory does not exist: $NotebooksDirectory"
}

if (-not [string]::IsNullOrWhiteSpace($NotebookRelativePath)) {
    $NotebookPath = Join-Path $ProjectRoot $NotebookRelativePath
    if (-not (Test-Path -LiteralPath $NotebookPath)) {
        throw "Specified notebook was not found: $NotebookPath"
    }
}
else {
    $NotebookCandidates = Get-ChildItem -LiteralPath $NotebooksDirectory -Filter "*.ipynb" -File -Recurse
    if (-not $NotebookCandidates) {
        throw "No Jupyter notebooks were found in: $NotebooksDirectory"
    }
    
    $ScoredCandidates = foreach ($Candidate in $NotebookCandidates) {
        $Score = 0
        $Content = ""
        try {
            $Content = Get-Content -LiteralPath $Candidate.FullName -Raw -Encoding UTF8
        }
        catch {
            $Content = ""
        }
        
        if ($Candidate.Name -match "regression") { $Score += 15 }
        if ($Candidate.Name -match "model") { $Score += 5 }
        if ($Candidate.Name -match "comparison") { $Score += 5 }
        if ($Content -match "Xtr_f") { $Score += 10 }
        if ($Content -match "Xte_f") { $Score += 10 }
        if ($Content -match "comparison_table") { $Score += 10 }
        if ($Content -match "RandomForestRegressor") { $Score += 8 }
        if ($Content -match "eval_reg") { $Score += 5 }
        
        [PSCustomObject]@{
            File = $Candidate
            Score = $Score
            LastWriteTime = $Candidate.LastWriteTime
        }
    }
    
    $SelectedCandidate = $ScoredCandidates |
        Sort-Object -Property @{Expression = "Score"; Descending = $true}, @{Expression = "LastWriteTime"; Descending = $true} |
        Select-Object -First 1
    
    if ($SelectedCandidate.Score -le 0) {
        Write-Host "Available notebooks:"
        $ScoredCandidates | ForEach-Object {
            Write-Host " - $($_.File.FullName)"
        }
        throw @"
The script could not identify the regression notebook confidently.
Set NotebookRelativePath at the top of the script, for example:
`$NotebookRelativePath = "notebooks\regression_modeling.ipynb"
"@
    }
    $NotebookPath = $SelectedCandidate.File.FullName
}

# Use the custom relative path function
$NotebookRelative = Get-RelativePath -From $ProjectRoot -To $NotebookPath
Write-Host "[4/12] Regression notebook selected:"
Write-Host " $NotebookRelative"
Write-Host ""

# ------------------------------------------------------------
# 5. Exclude this local automation file from Git
# ------------------------------------------------------------
$ScriptPath = $MyInvocation.MyCommand.Path
if ($ScriptPath -and $ScriptPath.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    $ExcludeFile = Join-Path $ProjectRoot ".git\info\exclude"
    $ScriptRelative = (Get-RelativePath -From $ProjectRoot -To $ScriptPath).Replace("\", "/")
    $ExcludeEntry = "/$ScriptRelative"
    $CurrentExclusions = ""
    if (Test-Path -LiteralPath $ExcludeFile) {
        $CurrentExclusions = Get-Content -LiteralPath $ExcludeFile -Raw -ErrorAction SilentlyContinue
    }
    if ($CurrentExclusions -notmatch [regex]::Escape($ExcludeEntry)) {
        Add-Content -LiteralPath $ExcludeFile -Value $ExcludeEntry -Encoding UTF8
    }
}

# ------------------------------------------------------------
# 6. Create a notebook backup
# ------------------------------------------------------------
$BackupDirectory = Join-Path $ProjectRoot ".session29_backup"
New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFilename = "{0}_{1}{2}" -f [System.IO.Path]::GetFileNameWithoutExtension($NotebookPath), $Timestamp, [System.IO.Path]::GetExtension($NotebookPath)
$BackupPath = Join-Path $BackupDirectory $BackupFilename
Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force
Write-Host "[5/12] Backup created:"
Write-Host " $BackupPath"
Write-Host ""

# ------------------------------------------------------------
# 7. Create temporary Python notebook editor
# ------------------------------------------------------------
$TemporaryPythonFile = Join-Path $env:TEMP "update_session29_notebook_$Timestamp.py"

$PythonEditor = @'
import ast
import json
import sys
from pathlib import Path

MARKER = "SESSION_29_ADVANCED_ENSEMBLES"
TAG = "session29-advanced-ensembles"

def source_text(cell):
    source = cell.get("source", "")
    if isinstance(source, list):
        return "".join(source)
    return str(source)

def source_lines(text):
    return text.splitlines(keepends=True)

def markdown_cell(text):
    return {
        "cell_type": "markdown",
        "metadata": {
            "tags": [TAG]
        },
        "source": source_lines(text),
    }

def code_cell(text):
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {
            "tags": [TAG]
        },
        "outputs": [],
        "source": source_lines(text),
    }

def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: update_session29_notebook.py NOTEBOOK_PATH")
    
    notebook_path = Path(sys.argv[1]).resolve()
    if not notebook_path.exists():
        raise FileNotFoundError(f"Notebook does not exist: {notebook_path}")
    
    with notebook_path.open("r", encoding="utf-8-sig") as file:
        notebook = json.load(file)
    
    if "cells" not in notebook:
        raise ValueError("Invalid notebook: the cells collection is missing.")
    
    # Remove older copies of the Session 29 section so that the operation remains idempotent.
    retained_cells = []
    for cell in notebook["cells"]:
        text = source_text(cell)
        tags = cell.get("metadata", {}).get("tags", [])
        if MARKER in text or TAG in tags:
            continue
        retained_cells.append(cell)
    
    heading = """# Session 29: Extra Trees and Gradient Boosting Regression
<!-- SESSION_29_ADVANCED_ENSEMBLES -->
This section trains two advanced ensemble regressors:
- Extra Trees Regressor
- Gradient Boosting Regressor
Both models use the same full-information training and test split as the earlier
regression models. Test RMSE is used as the primary leaderboard metric.
"""
    
    training_code = r'''# SESSION_29_ADVANCED_ENSEMBLES
import numpy as np
import pandas as pd
from IPython.display import display
from sklearn.ensemble import (
    ExtraTreesRegressor,
    GradientBoostingRegressor,
)
from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)

# ------------------------------------------------------------
# Validate the required data objects
# ------------------------------------------------------------
required_variables = [
    "Xtr_f",
    "Xte_f",
    "ytr",
    "yte",
]
missing_variables = [
    name
    for name in required_variables
    if name not in globals()
]
if missing_variables:
    raise NameError(
        "Run the earlier data-preparation and train/test-split "
        "cells first. Missing variables: "
        + ", ".join(missing_variables)
    )
if Xtr_f.shape[0] != len(ytr):
    raise ValueError(
        "Training features and targets have different row counts."
    )
if Xte_f.shape[0] != len(yte):
    raise ValueError(
        "Test features and targets have different row counts."
    )
if Xtr_f.shape[1] != Xte_f.shape[1]:
    raise ValueError(
        "Training and test feature counts do not match."
    )

# ------------------------------------------------------------
# Train and evaluate the Session 29 models
# ------------------------------------------------------------
session29_models = {
    "Extra Trees": ExtraTreesRegressor(
        n_estimators=300,
        random_state=42,
    ),
    "Gradient Boosting": GradientBoostingRegressor(
        random_state=42,
    ),
}

session29_result_rows = []
session29_predictions = {}
session29_estimators = {}

for model_name, estimator in session29_models.items():
    estimator.fit(Xtr_f, ytr)
    predictions = estimator.predict(Xte_f)
    
    if len(predictions) != len(yte):
        raise ValueError(
            f"{model_name} produced an incorrect number "
            "of predictions."
        )
    if not np.isfinite(predictions).all():
        raise ValueError(
            f"{model_name} produced a non-finite prediction."
        )
    
    mae = mean_absolute_error(yte, predictions)
    rmse = np.sqrt(mean_squared_error(yte, predictions))
    r2 = r2_score(yte, predictions)
    
    session29_estimators[model_name] = estimator
    session29_predictions[model_name] = predictions
    session29_result_rows.append(
        {
            "Model": model_name,
            "MAE": mae,
            "RMSE": rmse,
            "R2": r2,
        }
    )

advanced_ensemble_results = pd.DataFrame(session29_result_rows)

# ------------------------------------------------------------
# Validate the Session 29 result rows
# ------------------------------------------------------------
required_models = {"Extra Trees", "Gradient Boosting"}
if set(advanced_ensemble_results["Model"]) != required_models:
    raise ValueError(
        "The advanced-ensemble result table does not contain "
        "the required model names."
    )
if advanced_ensemble_results[["MAE", "RMSE", "R2"]].isna().any().any():
    raise ValueError(
        "The advanced-ensemble results contain missing values."
    )
if not np.isfinite(advanced_ensemble_results[["MAE", "RMSE", "R2"]].to_numpy()).all():
    raise ValueError(
        "The advanced-ensemble results contain invalid values."
    )

# ------------------------------------------------------------
# Recover or create the main model comparison table
# ------------------------------------------------------------
if "comparison_table" in globals():
    comparison_table = comparison_table.copy()
elif "leaderboard" in globals():
    comparison_table = leaderboard.copy()
else:
    comparison_table = pd.DataFrame(
        columns=[
            "Model",
            "MAE",
            "RMSE",
            "R2",
        ]
    )

comparison_table = comparison_table.rename(
    columns={
        "Model Name": "Model",
        "R2": "R2",
        "R-squared": "R2",
    }
)
comparison_table = comparison_table.drop(columns=["Rank"], errors="ignore")

required_columns = {"Model", "MAE", "RMSE", "R2"}
missing_columns = required_columns - set(comparison_table.columns)
if missing_columns and len(comparison_table) > 0:
    raise ValueError(
        "The existing comparison table is missing columns: "
        + ", ".join(sorted(missing_columns))
    )

# ------------------------------------------------------------
# Add the advanced-ensemble rows
# ------------------------------------------------------------
comparison_table = pd.concat(
    [
        comparison_table,
        advanced_ensemble_results,
    ],
    ignore_index=True,
)
comparison_table = (
    comparison_table
    .drop_duplicates(subset="Model", keep="last")
    .sort_values(
        by=["RMSE", "MAE"],
        ascending=[True, True],
    )
    .reset_index(drop=True)
)
comparison_table.insert(0, "Rank", range(1, len(comparison_table) + 1))
comparison_table = comparison_table[
    [
        "Rank",
        "Model",
        "MAE",
        "RMSE",
        "R2",
    ]
]
leaderboard = comparison_table.copy()

# ------------------------------------------------------------
# Create the required Session 29 output artifact
# ------------------------------------------------------------
advanced_ensemble_comparison_artifact = (
    comparison_table[
        comparison_table["Model"].isin(
            [
                "Extra Trees",
                "Gradient Boosting",
            ]
        )
    ]
    .copy()
    .sort_values(by="RMSE", ascending=True)
    .reset_index(drop=True)
)

if len(advanced_ensemble_comparison_artifact) != 2:
    raise ValueError(
        "The Session 29 artifact must contain exactly two rows."
    )

best_session29_model = advanced_ensemble_comparison_artifact.iloc[0]
overall_leader = comparison_table.iloc[0]

print("Session 29 advanced-ensemble results")
print("=" * 60)
display(advanced_ensemble_comparison_artifact.round(4))

print("\nComplete regression leaderboard")
print("=" * 60)
display(comparison_table.round(4))

print(
    "\nBest Session 29 model:",
    best_session29_model["Model"],
)
print(
    "Current overall leader:",
    overall_leader["Model"],
)
'''
    
    artifact_code = r'''# SESSION_29_ADVANCED_ENSEMBLES
# Display the two advanced-ensemble rows required for Session 29.
display(advanced_ensemble_comparison_artifact.round(4))

# Display the complete updated regression comparison table.
display(comparison_table.round(4))

print(
    "Advanced-ensemble rows successfully added "
    "to the regression comparison table."
)
'''
    
    conclusion = """## Session 29 GitHub Deliverable
<!-- SESSION_29_ADVANCED_ENSEMBLES -->
The regression notebook now includes:
1. An Extra Trees Regressor with 300 estimators.
2. A Gradient Boosting Regressor.
3. Test MAE, RMSE, and R2 for both models.
4. Advanced-ensemble rows in the main regression comparison table.
5. An updated ranking based primarily on test RMSE.
6. Identification of the best Session 29 model and current overall leader.
The final model-selection decision remains provisional until all planned
validation, cross-validation, tuning, and diagnostic comparisons are complete.
"""
    
    inserted_cells = [
        markdown_cell(heading),
        code_cell(training_code),
        code_cell(artifact_code),
        markdown_cell(conclusion),
    ]
    
    # Validate the inserted Python source before writing.
    ast.parse(training_code)
    ast.parse(artifact_code)
    
    notebook["cells"] = retained_cells + inserted_cells
    
    with notebook_path.open("w", encoding="utf-8", newline="\n") as file:
        json.dump(notebook, file, ensure_ascii=False, indent=1)
        file.write("\n")
    
    # Reopen and perform final validation.
    with notebook_path.open("r", encoding="utf-8") as file:
        checked_notebook = json.load(file)
    
    combined_source = "\n".join(
        source_text(cell)
        for cell in checked_notebook["cells"]
    )
    
    required_text = [
        MARKER,
        "ExtraTreesRegressor",
        "GradientBoostingRegressor",
        "advanced_ensemble_results",
        "advanced_ensemble_comparison_artifact",
        "comparison_table",
    ]
    missing_text = [
        item
        for item in required_text
        if item not in combined_source
    ]
    if missing_text:
        raise ValueError(
            "Notebook validation failed. Missing content: "
            + ", ".join(missing_text)
        )
    
    print(f"Updated notebook: {notebook_path}")
    print("Session 29 cells added successfully.")

if __name__ == "__main__":
    main()
'@

Set-Content -LiteralPath $TemporaryPythonFile -Value $PythonEditor -Encoding UTF8

# ------------------------------------------------------------
# 8. Update the notebook
# ------------------------------------------------------------
Write-Host "[6/12] Adding Session 29 cells to the notebook..."
try {
    & $PythonExecutable @PythonArguments $TemporaryPythonFile $NotebookPath
    if ($LASTEXITCODE -ne 0) {
        throw "The Python notebook update failed."
    }
}
catch {
    Write-Host ""
    Write-Host "Notebook update failed."
    Write-Host "Restoring the original notebook from the backup."
    Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
    throw
}
finally {
    if (Test-Path -LiteralPath $TemporaryPythonFile) {
        Remove-Item -LiteralPath $TemporaryPythonFile -Force
    }
}
Write-Host ""
Write-Host "[7/12] Notebook updated successfully."
Write-Host ""

# ------------------------------------------------------------
# 9. Validate the updated notebook in PowerShell
# ------------------------------------------------------------
$UpdatedNotebookContent = Get-Content -LiteralPath $NotebookPath -Raw -Encoding UTF8
$RequiredNotebookItems = @(
    "SESSION_29_ADVANCED_ENSEMBLES",
    "ExtraTreesRegressor",
    "GradientBoostingRegressor",
    "advanced_ensemble_results",
    "advanced_ensemble_comparison_artifact",
    "comparison_table"
)

foreach ($RequiredItem in $RequiredNotebookItems) {
    if ($UpdatedNotebookContent -notmatch [regex]::Escape($RequiredItem)) {
        Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
        throw @"
Notebook validation failed because this content is missing:
$RequiredItem
The original notebook was restored.
"@
    }
}
Write-Host "[8/12] Notebook validation passed."
Write-Host ""

# ------------------------------------------------------------
# 10. Display the notebook Git difference
# ------------------------------------------------------------
Write-Host "[9/12] Git change summary:"
Write-Host ""
git diff --stat -- "$NotebookRelative"
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the notebook Git difference."
}
Write-Host ""

# ------------------------------------------------------------
# 11. Stage and commit only the notebook
# ------------------------------------------------------------
git add -- "$NotebookRelative"
if ($LASTEXITCODE -ne 0) {
    throw "Git could not stage the updated notebook."
}

git diff --cached --quiet -- "$NotebookRelative"
$HasStagedNotebookChange = ($LASTEXITCODE -ne 0)

if ($HasStagedNotebookChange) {
    Write-Host "[10/12] Creating the Session 29 commit..."
    Write-Host ""
    git commit -m "Add Session 29 advanced ensemble results"
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed."
    }
}
else {
    Write-Host "[10/12] No new notebook change required."
    Write-Host " Session 29 content is already present."
    Write-Host ""
}

# ------------------------------------------------------------
# 12. Push to GitHub
# ------------------------------------------------------------
$CurrentBranch = (git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($CurrentBranch)) {
    throw "Could not determine the current Git branch."
}

$OriginUrl = (git remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($OriginUrl)) {
    throw "The Git remote named origin is not configured."
}

Write-Host "[11/12] Pushing branch '$CurrentBranch' to GitHub..."
Write-Host " Remote: $OriginUrl"
Write-Host ""

git push -u origin $CurrentBranch
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Initial push failed."
    Write-Host "Attempting a rebase against the remote branch..."
    Write-Host ""
    
    git pull --rebase --autostash origin $CurrentBranch
    if ($LASTEXITCODE -ne 0) {
        throw @"
The remote update could not be rebased automatically.
The notebook and local commit were preserved.
Resolve the reported Git conflict before pushing again.
"@
    }
    
    git push -u origin $CurrentBranch
    if ($LASTEXITCODE -ne 0) {
        throw "Git push failed after the rebase."
    }
}

# ------------------------------------------------------------
# 13. Final verification
# ------------------------------------------------------------
Write-Host ""
Write-Host "[12/12] FINAL VERIFICATION"
Write-Host "============================================================"
Write-Host ""
Write-Host "Latest commit:"
git log -1 --oneline
Write-Host ""
Write-Host "Current branch:"
Write-Host $CurrentBranch
Write-Host ""
Write-Host "Git remote:"
Write-Host $OriginUrl
Write-Host ""
Write-Host "Notebook delivered:"
Write-Host $NotebookRelative
Write-Host ""
Write-Host "Working-tree status:"
git status --short
Write-Host ""
Write-Host "============================================================"
Write-Host " SESSION 29 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY"
Write-Host "============================================================"
Write-Host ""
Write-Host "The regression notebook now contains:"
Write-Host " - Extra Trees Regressor"
Write-Host " - Gradient Boosting Regressor"
Write-Host " - Advanced-ensemble metric rows"
Write-Host " - Updated comparison table"
Write-Host " - Session 29 model ranking"
Write-Host ""
Write-Host "The updated notebook has been committed and pushed."
Write-Host ""