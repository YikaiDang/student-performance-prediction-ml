[CmdletBinding()]
param(
    [string]$ProjectRoot = "C:\Users\yikib\student-performance-prediction-ml",
    [switch]$SkipExecution,
    [switch]$SkipPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 78)
    Write-Host $Text
    Write-Host ("=" * 78)
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host ">> $Description"
    & $Command

    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

Write-Section "Session 26 GitHub Deliverable Automation"

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "Project folder not found: $ProjectRoot"
}

Set-Location -LiteralPath $ProjectRoot
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or is not available in PATH."
}

$gitRoot = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0) {
    throw "This folder is not a Git repository: $ProjectRoot"
}
$gitRoot = (Resolve-Path -LiteralPath $gitRoot.Trim()).Path

if ($gitRoot -ne $ProjectRoot) {
    Write-Warning "The Git root is '$gitRoot'. The script will use that folder."
    $ProjectRoot = $gitRoot
    Set-Location -LiteralPath $ProjectRoot
}

$alreadyStaged = @(& git diff --cached --name-only)
if ($alreadyStaged.Count -gt 0) {
    throw @"
There are already staged files. Commit or unstage them before running this
automation so that the Session 26 commit does not include unrelated work.

Already staged:
$($alreadyStaged -join [Environment]::NewLine)
"@
}

Write-Section "Locate 04_regression_models.ipynb"

$candidates = @(
    (Join-Path $ProjectRoot "notebooks\04_regression_models.ipynb"),
    (Join-Path $ProjectRoot "04_regression_models.ipynb")
)

$NotebookPath = $null

foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $NotebookPath = (Resolve-Path -LiteralPath $candidate).Path
        break
    }
}

if (-not $NotebookPath) {
    $found = @(
        Get-ChildItem -LiteralPath $ProjectRoot `
            -Recurse `
            -File `
            -Filter "04_regression_models.ipynb" `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\\.venv\\" -and
            $_.FullName -notmatch "\\venv\\" -and
            $_.FullName -notmatch "\\\.git\\"
        }
    )

    if ($found.Count -eq 1) {
        $NotebookPath = $found[0].FullName
    }
    elseif ($found.Count -gt 1) {
        throw "Multiple copies of 04_regression_models.ipynb were found. Keep one authoritative copy or pass a unique project root."
    }
}

if (-not $NotebookPath) {
    throw "04_regression_models.ipynb was not found under $ProjectRoot"
}

$NotebookRelative = [System.IO.Path]::GetRelativePath($ProjectRoot, $NotebookPath)
Write-Host "Notebook: $NotebookRelative"

Write-Section "Prepare the Python environment"

$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        Invoke-Checked "Create .venv with Python 3" {
            & py -3 -m venv (Join-Path $ProjectRoot ".venv")
        }
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        Invoke-Checked "Create .venv with Python" {
            & python -m venv (Join-Path $ProjectRoot ".venv")
        }
    }
    else {
        throw "Python was not found. Install Python 3 and ensure py or python is available in PATH."
    }
}

$Python = $VenvPython

$dependencyCheck = @'
import importlib.util
required = ["nbformat", "nbconvert", "ipykernel", "pandas", "numpy", "sklearn", "matplotlib"]
missing = [name for name in required if importlib.util.find_spec(name) is None]
raise SystemExit(1 if missing else 0)
'@

& $Python -c $dependencyCheck

if ($LASTEXITCODE -ne 0) {
    Invoke-Checked "Install notebook and machine-learning dependencies" {
        & $Python -m pip install `
            nbformat `
            nbconvert `
            ipykernel `
            pandas `
            numpy `
            scikit-learn `
            matplotlib
    }
}
else {
    Write-Host "Required Python packages are already installed."
}

Write-Section "Back up and update the notebook"

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("gssrp_session26_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

$BackupPath = Join-Path $TempRoot "04_regression_models.before_session26.ipynb"
Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force

$ModifierPath = Join-Path $TempRoot "update_session26_notebook.py"

$ModifierCode = @'
from __future__ import annotations

import ast
import sys
from pathlib import Path

import nbformat
from nbformat.v4 import new_code_cell, new_markdown_cell


def tagged(cell: dict) -> bool:
    return cell.get("metadata", {}).get("gssrp_session") == 26


def metadata(section: str) -> dict:
    return {
        "gssrp_session": 26,
        "gssrp_section": section,
        "editable": True,
        "deletable": True,
    }


notebook_path = Path(sys.argv[1]).resolve()
notebook = nbformat.read(notebook_path, as_version=4)

# Idempotency: replace prior Session 26 cells instead of duplicating them.
notebook.cells = [cell for cell in notebook.cells if not tagged(cell)]

markdown_intro = r"""
## Session 26 — KNN and SVR Regression

This section adds two nonlinear regression models to the full-information
scenario:

- K-Nearest Neighbors regression
- Support Vector Regression

Both models use `StandardScaler` inside a scikit-learn pipeline so that
scaling is learned from the training data only. The resulting KNN and SVR
metrics are added to the regression comparison table.
""".strip()

imports_code = r"""
from collections.abc import Mapping

import pandas as pd
from IPython.display import display
from sklearn.neighbors import KNeighborsRegressor
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVR

print("Session 26 imports completed.")
""".strip()

checks_code = r"""
required_objects = ["Xtr_f", "Xte_f", "ytr", "yte", "eval_reg"]

missing_objects = [
    object_name
    for object_name in required_objects
    if object_name not in globals()
]

if missing_objects:
    raise NameError(
        "Run the earlier regression notebook cells first. "
        f"Missing objects: {missing_objects}"
    )

assert len(Xtr_f) == len(ytr), "Training features and targets do not match."
assert len(Xte_f) == len(yte), "Test features and targets do not match."

print("Required Session 26 objects are available.")
print("Training shape:", Xtr_f.shape)
print("Test shape:", Xte_f.shape)
""".strip()

fit_code = r"""
session26_estimators = {
    "KNN": KNeighborsRegressor(),
    "SVR": SVR(),
}

session26_models = {}
session26_result_rows = []

for model_name, estimator in session26_estimators.items():
    pipeline = make_pipeline(
        StandardScaler(),
        estimator,
    )

    pipeline.fit(Xtr_f, ytr)
    predictions = pipeline.predict(Xte_f)
    metrics = eval_reg(yte, predictions)

    if not isinstance(metrics, Mapping):
        raise TypeError(
            "eval_reg must return a dictionary-like object of metric values."
        )

    normalized_metrics = {
        str(metric_name)
        .replace("R²", "R2")
        .replace("R^2", "R2"): float(metric_value)
        for metric_name, metric_value in metrics.items()
    }

    required_metrics = {"MAE", "RMSE", "R2"}
    missing_metrics = required_metrics.difference(normalized_metrics)

    if missing_metrics:
        raise KeyError(
            f"{model_name} evaluation is missing metrics: "
            f"{sorted(missing_metrics)}"
        )

    session26_models[model_name] = pipeline
    session26_result_rows.append(
        {
            "Model": model_name,
            "MAE": normalized_metrics["MAE"],
            "RMSE": normalized_metrics["RMSE"],
            "R2": normalized_metrics["R2"],
        }
    )

session26_results_df = pd.DataFrame(session26_result_rows)

print("Session 26 KNN and SVR results:")
display(
    session26_results_df.style.format(
        {
            "MAE": "{:.4f}",
            "RMSE": "{:.4f}",
            "R2": "{:.4f}",
        }
    )
)
""".strip()

comparison_code = r"""
comparison_candidates = [
    "comparison_df",
    "model_comparison_df",
    "regression_comparison_df",
]

existing_comparison_name = next(
    (
        candidate
        for candidate in comparison_candidates
        if candidate in globals()
        and isinstance(globals()[candidate], pd.DataFrame)
    ),
    None,
)

if existing_comparison_name is None:
    comparison_df = session26_results_df.copy()
    print(
        "No prior comparison DataFrame was found. "
        "A new comparison_df was created with KNN and SVR."
    )
else:
    comparison_df = globals()[existing_comparison_name].copy()

    if "Model" not in comparison_df.columns:
        raise KeyError(
            f"{existing_comparison_name} does not contain a Model column."
        )

    comparison_df = comparison_df[
        ~comparison_df["Model"].isin(["KNN", "SVR"])
    ].copy()

    comparison_df = pd.concat(
        [comparison_df, session26_results_df],
        ignore_index=True,
    )

comparison_df = comparison_df.sort_values(
    by="RMSE",
    ascending=True,
).reset_index(drop=True)

print("Updated regression comparison table:")
display(
    comparison_df.style.format(
        {
            "MAE": "{:.4f}",
            "RMSE": "{:.4f}",
            "R2": "{:.4f}",
        }
    )
)
""".strip()

verification_code = r"""
for model_name in ["KNN", "SVR"]:
    pipeline = session26_models[model_name]

    assert isinstance(
        pipeline.steps[0][1],
        StandardScaler,
    ), f"{model_name} does not begin with StandardScaler."

    row_count = int(
        (comparison_df["Model"] == model_name).sum()
    )

    assert row_count == 1, (
        f"Expected exactly one {model_name} row, found {row_count}."
    )

session26_rows = comparison_df[
    comparison_df["Model"].isin(["KNN", "SVR"])
].copy()

print("Verified Session 26 rows:")
display(
    session26_rows.style.format(
        {
            "MAE": "{:.4f}",
            "RMSE": "{:.4f}",
            "R2": "{:.4f}",
        }
    )
)

print(
    "Session 26 completed: KNN and SVR are fitted in scaled pipelines "
    "and appear exactly once in the regression comparison table."
)
""".strip()

for source in [imports_code, checks_code, fit_code, comparison_code, verification_code]:
    ast.parse(source)

new_cells = [
    new_markdown_cell(markdown_intro, metadata=metadata("introduction")),
    new_code_cell(imports_code, metadata=metadata("imports")),
    new_code_cell(checks_code, metadata=metadata("prerequisite-checks")),
    new_code_cell(fit_code, metadata=metadata("fit-and-evaluate")),
    new_code_cell(comparison_code, metadata=metadata("comparison-table")),
    new_code_cell(verification_code, metadata=metadata("verification")),
]

notebook.cells.extend(new_cells)
nbformat.write(notebook, notebook_path)

print(f"Updated notebook: {notebook_path}")
print(f"Added Session 26 cells: {len(new_cells)}")
'@

Set-Content `
    -LiteralPath $ModifierPath `
    -Value $ModifierCode `
    -Encoding UTF8

try {
    Invoke-Checked "Insert or replace Session 26 notebook cells" {
        & $Python $ModifierPath $NotebookPath
    }
}
catch {
    Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
    throw "Notebook update failed. The original notebook was restored. $($_.Exception.Message)"
}

Write-Section "Verify the notebook structure"

$VerifierCode = @'
from pathlib import Path
import sys
import nbformat

path = Path(sys.argv[1])
nb = nbformat.read(path, as_version=4)

session_cells = [
    cell
    for cell in nb.cells
    if cell.get("metadata", {}).get("gssrp_session") == 26
]

combined = "\n".join(cell.get("source", "") for cell in session_cells)

required_tokens = [
    "KNeighborsRegressor",
    "SVR",
    "StandardScaler",
    "make_pipeline",
    "session26_results_df",
    "comparison_df",
]

missing = [token for token in required_tokens if token not in combined]

if len(session_cells) != 6:
    raise SystemExit(
        f"Expected 6 Session 26 cells, found {len(session_cells)}."
    )

if missing:
    raise SystemExit(f"Notebook verification failed. Missing tokens: {missing}")

print("Notebook structure verification passed.")
print("Session 26 cell count:", len(session_cells))
'@

Invoke-Checked "Confirm Session 26 cells and required model code" {
    & $Python -c $VerifierCode $NotebookPath
}

if (-not $SkipExecution) {
    Write-Section "Execute the notebook locally"

    $ExecutionLog = Join-Path $TempRoot "session26_notebook_execution.log"

    & $Python -m jupyter nbconvert `
        --to notebook `
        --execute `
        --inplace `
        --ExecutePreprocessor.timeout=900 `
        --ExecutePreprocessor.cwd="$ProjectRoot" `
        "$NotebookPath" 2>&1 |
        Tee-Object -FilePath $ExecutionLog

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Warning "The notebook was updated, but local execution failed."
        Write-Warning "Nothing has been committed or pushed."
        Write-Host "Execution log: $ExecutionLog"
        Write-Host "Notebook retained for diagnosis: $NotebookRelative"
        exit 1
    }

    Write-Host "Notebook execution completed successfully."
}
else {
    Write-Warning "Notebook execution was skipped because -SkipExecution was used."
}

Write-Section "Review and commit only the Session 26 notebook change"

& git status --short -- "$NotebookRelative"
& git diff --check -- "$NotebookRelative"

if ($LASTEXITCODE -ne 0) {
    throw "git diff --check found whitespace or patch-format problems."
}

Invoke-Checked "Stage the regression notebook" {
    & git add -- "$NotebookRelative"
}

& git diff --cached --stat
& git diff --cached --check

if ($LASTEXITCODE -ne 0) {
    & git restore --staged -- "$NotebookRelative"
    throw "The staged notebook failed git diff --cached --check."
}

& git diff --cached --quiet
$HasStagedChanges = ($LASTEXITCODE -ne 0)

if (-not $HasStagedChanges) {
    Write-Host "No new Session 26 change was detected. The notebook is already current."
}
else {
    Invoke-Checked "Commit Session 26" {
        & git commit -m "Add KNN and SVR regression models"
    }
}

if (-not $SkipPush) {
    Write-Section "Push to GitHub"

    $Branch = (& git branch --show-current).Trim()
    if (-not $Branch) {
        throw "Unable to determine the current Git branch."
    }

    & git remote get-url origin *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "The repository does not have an origin remote."
    }

    & git rev-parse --abbrev-ref --symbolic-full-name "@{u}" *> $null

    if ($LASTEXITCODE -eq 0) {
        Invoke-Checked "Push branch '$Branch'" {
            & git push
        }
    }
    else {
        Invoke-Checked "Set upstream and push branch '$Branch'" {
            & git push -u origin $Branch
        }
    }
}
else {
    Write-Warning "GitHub push was skipped because -SkipPush was used."
}

Write-Section "Final verification"

& git status --short
& git log -1 --oneline

Write-Host ""
Write-Host "SESSION 26 GITHUB DELIVERABLE COMPLETED"
Write-Host "Notebook updated: $NotebookRelative"
Write-Host "Added models: KNN and SVR"
Write-Host "Scaling: StandardScaler is inside both pipelines"
Write-Host "Comparison artifact: KNN and SVR rows are added to comparison_df"

Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
