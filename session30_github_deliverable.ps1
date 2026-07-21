[CmdletBinding()]
param(
    [string]$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml",
    [switch]$SkipExecution,
    [switch]$SkipPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Text)

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

Write-Section "Session 30 GitHub Deliverable Automation"

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "Project folder not found: $ProjectRoot"
}

Set-Location -LiteralPath $ProjectRoot
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or is not available in PATH."
}

$GitRootText = (& git rev-parse --show-toplevel 2>$null)

if ($LASTEXITCODE -ne 0 -or -not $GitRootText) {
    throw "This folder is not a Git repository: $ProjectRoot"
}

$GitRoot = (Resolve-Path -LiteralPath $GitRootText.Trim()).Path

if ($GitRoot -ne $ProjectRoot) {
    Write-Warning "The Git root is '$GitRoot'. The script will use that folder."
    $ProjectRoot = $GitRoot
    Set-Location -LiteralPath $ProjectRoot
}

$AlreadyStaged = @(& git diff --cached --name-only)

if ($AlreadyStaged.Count -gt 0) {
    throw @"
There are already staged files. Commit or unstage them before running this
automation so the Session 30 commit does not include unrelated work.

Already staged:
$($AlreadyStaged -join [Environment]::NewLine)
"@
}

Write-Section "Locate 04_regression_models.ipynb"

$NotebookCandidates = @(
    (Join-Path $ProjectRoot "notebooks\04_regression_models.ipynb"),
    (Join-Path $ProjectRoot "04_regression_models.ipynb")
)

$NotebookPath = $null

foreach ($Candidate in $NotebookCandidates) {
    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        $NotebookPath = (Resolve-Path -LiteralPath $Candidate).Path
        break
    }
}

if (-not $NotebookPath) {
    $FoundNotebooks = @(
        Get-ChildItem `
            -LiteralPath $ProjectRoot `
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

    if ($FoundNotebooks.Count -eq 1) {
        $NotebookPath = $FoundNotebooks[0].FullName
    }
    elseif ($FoundNotebooks.Count -gt 1) {
        $Locations = $FoundNotebooks.FullName -join [Environment]::NewLine

        throw @"
Multiple copies of 04_regression_models.ipynb were found:

$Locations

Keep one authoritative copy or pass a project root containing only the
intended notebook.
"@
    }
}

if (-not $NotebookPath) {
    throw "04_regression_models.ipynb was not found under $ProjectRoot"
}

$NotebookRelative = [System.IO.Path]::GetRelativePath(
    $ProjectRoot,
    $NotebookPath
)

Write-Host "Project root: $ProjectRoot"
Write-Host "Notebook:     $NotebookRelative"

Write-Section "Prepare the local Python environment"

$VenvRoot = Join-Path $ProjectRoot ".venv"
$Python = Join-Path $VenvRoot "Scripts\python.exe"

if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        Invoke-Checked "Create .venv using the Python launcher" {
            & py -3 -m venv $VenvRoot
        }
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        Invoke-Checked "Create .venv using python" {
            & python -m venv $VenvRoot
        }
    }
    else {
        throw "Python 3 was not found. Install Python and reopen VS Code."
    }
}

$DependencyCheck = @'
import importlib.util

required_modules = [
    "nbformat",
    "nbconvert",
    "ipykernel",
    "pandas",
    "numpy",
    "sklearn",
    "matplotlib",
]

missing = [
    name
    for name in required_modules
    if importlib.util.find_spec(name) is None
]

if missing:
    print("Missing modules:", ", ".join(missing))
    raise SystemExit(1)

print("Required Python packages are available.")
'@

& $Python -c $DependencyCheck

if ($LASTEXITCODE -ne 0) {
    Invoke-Checked "Upgrade pip" {
        & $Python -m pip install --upgrade pip
    }

    Invoke-Checked "Install notebook and machine-learning packages" {
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

Write-Section "Back up and update the regression notebook"

$TempRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("gssrp_session30_" + [guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

$BackupPath = Join-Path `
    $TempRoot `
    "04_regression_models.before_session30.ipynb"

Copy-Item `
    -LiteralPath $NotebookPath `
    -Destination $BackupPath `
    -Force

$ModifierPath = Join-Path $TempRoot "update_session30_notebook.py"

$ModifierCode = @'
from __future__ import annotations

import ast
import sys
from pathlib import Path

import nbformat
from nbformat.v4 import new_code_cell, new_markdown_cell


SESSION_NUMBER = 30


def is_session_cell(cell: dict) -> bool:
    return (
        cell.get("metadata", {}).get("gssrp_session")
        == SESSION_NUMBER
    )


def cell_metadata(section: str) -> dict:
    return {
        "gssrp_session": SESSION_NUMBER,
        "gssrp_section": section,
        "editable": True,
        "deletable": True,
    }


notebook_path = Path(sys.argv[1]).resolve()
notebook = nbformat.read(notebook_path, as_version=4)

# Idempotency: remove old Session 30 cells before inserting the current version.
notebook.cells = [
    cell
    for cell in notebook.cells
    if not is_session_cell(cell)
]

introduction_markdown = r"""
## Session 30 — Neural-Network Regression

This section trains a scaled multilayer perceptron (MLP) regressor for
the full-information scenario. The model uses two hidden layers with
64 and 32 neurons. Its held-out test metrics are added to the shared
regression comparison table.

Required configuration:

- `StandardScaler`
- `MLPRegressor(hidden_layer_sizes=(64, 32))`
- `max_iter=1000`
- `random_state=42`
""".strip()

imports_code = r"""
from collections.abc import Mapping
import warnings

import numpy as np
import pandas as pd
from IPython.display import display
from sklearn.exceptions import ConvergenceWarning
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

print("Session 30 imports completed.")
""".strip()

prerequisite_code = r"""
required_objects = [
    "Xtr_f",
    "Xte_f",
    "ytr",
    "yte",
    "eval_reg",
]

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

ytr_session30 = np.asarray(ytr).ravel()
yte_session30 = np.asarray(yte).ravel()

if len(Xtr_f) != len(ytr_session30):
    raise ValueError(
        "Training features and targets have different row counts."
    )

if len(Xte_f) != len(yte_session30):
    raise ValueError(
        "Test features and targets have different row counts."
    )

if not np.isfinite(np.asarray(Xtr_f)).all():
    raise ValueError(
        "Xtr_f contains missing or infinite values."
    )

if not np.isfinite(np.asarray(Xte_f)).all():
    raise ValueError(
        "Xte_f contains missing or infinite values."
    )

if not np.isfinite(ytr_session30).all():
    raise ValueError(
        "ytr contains missing or infinite values."
    )

if not np.isfinite(yte_session30).all():
    raise ValueError(
        "yte contains missing or infinite values."
    )

print("Session 30 prerequisites verified.")
print("Training shape:", Xtr_f.shape)
print("Test shape:", Xte_f.shape)
""".strip()

fit_code = r"""
mlp = make_pipeline(
    StandardScaler(),
    MLPRegressor(
        hidden_layer_sizes=(64, 32),
        max_iter=1000,
        random_state=42,
    ),
)

with warnings.catch_warnings(record=True) as session30_warnings:
    warnings.simplefilter("always")
    mlp.fit(Xtr_f, ytr_session30)

mlp_predictions = mlp.predict(Xte_f)
mlp_metrics_raw = eval_reg(
    yte_session30,
    mlp_predictions,
)

if not isinstance(mlp_metrics_raw, Mapping):
    raise TypeError(
        "eval_reg must return a dictionary-like object."
    )

mlp_metrics = {
    str(metric_name)
    .replace("R²", "R2")
    .replace("R^2", "R2"): float(metric_value)
    for metric_name, metric_value in mlp_metrics_raw.items()
}

required_metrics = {"MAE", "RMSE", "R2"}
missing_metrics = required_metrics.difference(mlp_metrics)

if missing_metrics:
    raise KeyError(
        "MLP evaluation is missing metrics: "
        f"{sorted(missing_metrics)}"
    )

session30_result_df = pd.DataFrame(
    [
        {
            "Model": "MLP Regressor",
            "MAE": mlp_metrics["MAE"],
            "RMSE": mlp_metrics["RMSE"],
            "R2": mlp_metrics["R2"],
        }
    ]
)

convergence_warnings = [
    warning
    for warning in session30_warnings
    if issubclass(warning.category, ConvergenceWarning)
]

print("Session 30 MLP test result:")
display(
    session30_result_df.style.format(
        {
            "MAE": "{:.4f}",
            "RMSE": "{:.4f}",
            "R2": "{:.4f}",
        }
    )
)

fitted_mlp = mlp.named_steps["mlpregressor"]

print("Iterations completed:", fitted_mlp.n_iter_)
print("Maximum iterations:", fitted_mlp.max_iter)
print("Final training loss:", round(float(fitted_mlp.loss_), 6))

if convergence_warnings:
    print("Convergence warning:")
    print(convergence_warnings[-1].message)
else:
    print("No convergence warning was detected.")
""".strip()

comparison_code = r"""
comparison_candidates = [
    "comparison_df",
    "comparison_table",
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
    comparison_df = session30_result_df.copy()

    print(
        "No earlier comparison DataFrame was found. "
        "A new comparison_df was created."
    )
else:
    comparison_df = globals()[
        existing_comparison_name
    ].copy()

    if "Model" not in comparison_df.columns:
        raise KeyError(
            f"{existing_comparison_name} does not contain "
            "a Model column."
        )

    for metric_column in ["MAE", "RMSE", "R2"]:
        if metric_column not in comparison_df.columns:
            comparison_df[metric_column] = np.nan

    mlp_aliases = {
        "mlp",
        "mlp regressor",
        "neural network",
        "neural-network regressor",
    }

    normalized_model_names = (
        comparison_df["Model"]
        .astype(str)
        .str.strip()
        .str.lower()
    )

    comparison_df = comparison_df[
        ~normalized_model_names.isin(mlp_aliases)
    ].copy()

    for new_column in session30_result_df.columns:
        if new_column not in comparison_df.columns:
            comparison_df[new_column] = np.nan

    for existing_column in comparison_df.columns:
        if existing_column not in session30_result_df.columns:
            session30_result_df[existing_column] = np.nan

    session30_result_df = session30_result_df[
        comparison_df.columns
    ]

    comparison_df = pd.concat(
        [
            comparison_df,
            session30_result_df,
        ],
        ignore_index=True,
    )

for metric_column in ["MAE", "RMSE", "R2"]:
    comparison_df[metric_column] = pd.to_numeric(
        comparison_df[metric_column],
        errors="coerce",
    )

comparison_df = (
    comparison_df
    .sort_values(
        by="RMSE",
        ascending=True,
        na_position="last",
    )
    .reset_index(drop=True)
)

print("Updated regression comparison table:")
display(
    comparison_df.style.format(
        {
            "MAE": "{:.4f}",
            "RMSE": "{:.4f}",
            "R2": "{:.4f}",
        },
        na_rep="—",
    )
)
""".strip()

verification_code = r"""
if not isinstance(
    mlp.steps[0][1],
    StandardScaler,
):
    raise AssertionError(
        "The MLP pipeline does not begin with StandardScaler."
    )

if not isinstance(
    mlp.steps[1][1],
    MLPRegressor,
):
    raise AssertionError(
        "The pipeline does not contain an MLPRegressor."
    )

fitted_mlp = mlp.named_steps["mlpregressor"]

if fitted_mlp.hidden_layer_sizes != (64, 32):
    raise AssertionError(
        "Unexpected hidden-layer configuration."
    )

if fitted_mlp.max_iter != 1000:
    raise AssertionError(
        "MLP max_iter must equal 1000."
    )

if fitted_mlp.random_state != 42:
    raise AssertionError(
        "MLP random_state must equal 42."
    )

mlp_row_mask = (
    comparison_df["Model"]
    .astype(str)
    .str.strip()
    .str.lower()
    == "mlp regressor"
)

mlp_row_count = int(mlp_row_mask.sum())

if mlp_row_count != 1:
    raise AssertionError(
        "Expected exactly one MLP Regressor row, "
        f"found {mlp_row_count}."
    )

mlp_artifact_row = comparison_df.loc[
    mlp_row_mask,
    ["Model", "MAE", "RMSE", "R2"],
].copy()

if not np.isfinite(
    mlp_artifact_row[
        ["MAE", "RMSE", "R2"]
    ].to_numpy(dtype=float)
).all():
    raise AssertionError(
        "The MLP artifact row contains missing or "
        "non-finite metrics."
    )

print("Verified Session 30 output artifact:")
display(
    mlp_artifact_row.style.format(
        {
            "MAE": "{:.4f}",
            "RMSE": "{:.4f}",
            "R2": "{:.4f}",
        }
    )
)

print(
    "SESSION 30 NOTEBOOK VERIFICATION PASSED: "
    "the scaled MLP is fitted and appears exactly once "
    "in comparison_df."
)
""".strip()

for source in [
    imports_code,
    prerequisite_code,
    fit_code,
    comparison_code,
    verification_code,
]:
    ast.parse(source)

session30_cells = [
    new_markdown_cell(
        introduction_markdown,
        metadata=cell_metadata("introduction"),
    ),
    new_code_cell(
        imports_code,
        metadata=cell_metadata("imports"),
    ),
    new_code_cell(
        prerequisite_code,
        metadata=cell_metadata("prerequisite-checks"),
    ),
    new_code_cell(
        fit_code,
        metadata=cell_metadata("fit-and-evaluate"),
    ),
    new_code_cell(
        comparison_code,
        metadata=cell_metadata("comparison-table"),
    ),
    new_code_cell(
        verification_code,
        metadata=cell_metadata("verification"),
    ),
]

notebook.cells.extend(session30_cells)
nbformat.write(notebook, notebook_path)

print(f"Updated notebook: {notebook_path}")
print(f"Added Session 30 cells: {len(session30_cells)}")
'@

Set-Content `
    -LiteralPath $ModifierPath `
    -Value $ModifierCode `
    -Encoding UTF8

try {
    Invoke-Checked "Insert or replace Session 30 notebook cells" {
        & $Python $ModifierPath $NotebookPath
    }
}
catch {
    Copy-Item `
        -LiteralPath $BackupPath `
        -Destination $NotebookPath `
        -Force

    throw (
        "Notebook update failed. The original notebook was restored. " +
        $_.Exception.Message
    )
}

Write-Section "Verify the inserted notebook structure"

$StructureVerifier = @'
from pathlib import Path
import sys

import nbformat

path = Path(sys.argv[1]).resolve()
notebook = nbformat.read(path, as_version=4)

session_cells = [
    cell
    for cell in notebook.cells
    if cell.get("metadata", {}).get("gssrp_session") == 30
]

combined_source = "\n".join(
    cell.get("source", "")
    for cell in session_cells
)

required_tokens = [
    "MLPRegressor",
    "hidden_layer_sizes=(64, 32)",
    "StandardScaler",
    "max_iter=1000",
    "random_state=42",
    "session30_result_df",
    "comparison_df",
    "MLP Regressor",
]

missing_tokens = [
    token
    for token in required_tokens
    if token not in combined_source
]

if len(session_cells) != 6:
    raise SystemExit(
        "Expected exactly 6 Session 30 cells, "
        f"found {len(session_cells)}."
    )

if missing_tokens:
    raise SystemExit(
        "Notebook structure verification failed. "
        f"Missing tokens: {missing_tokens}"
    )

print("Notebook structure verification passed.")
print("Session 30 cell count:", len(session_cells))
'@

try {
    Invoke-Checked "Confirm Session 30 cells and required MLP code" {
        & $Python -c $StructureVerifier $NotebookPath
    }
}
catch {
    Copy-Item `
        -LiteralPath $BackupPath `
        -Destination $NotebookPath `
        -Force

    throw (
        "Notebook structure verification failed. " +
        "The original notebook was restored. " +
        $_.Exception.Message
    )
}

if (-not $SkipExecution) {
    Write-Section "Execute the notebook locally in VS Code"

    $ExecutionLog = Join-Path `
        $TempRoot `
        "session30_notebook_execution.log"

    & $Python -m jupyter nbconvert `
        --to notebook `
        --execute `
        --inplace `
        --ExecutePreprocessor.timeout=1200 `
        --ExecutePreprocessor.cwd="$ProjectRoot" `
        "$NotebookPath" 2>&1 |
        Tee-Object -FilePath $ExecutionLog

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Warning "The notebook was updated, but local execution failed."
        Write-Warning "Nothing was committed or pushed."
        Write-Host "Execution log: $ExecutionLog"
        Write-Host "Notebook retained for diagnosis: $NotebookRelative"
        Write-Host ""
        Write-Host "After correcting an earlier notebook dependency, rerun:"
        Write-Host ".\session30_github_deliverable.ps1"
        exit 1
    }

    Write-Host "Notebook execution completed successfully."

    $OutputVerifier = @'
from pathlib import Path
import sys

import nbformat

path = Path(sys.argv[1]).resolve()
notebook = nbformat.read(path, as_version=4)

session_cells = [
    cell
    for cell in notebook.cells
    if cell.get("metadata", {}).get("gssrp_session") == 30
]

output_text = []

for cell in session_cells:
    for output in cell.get("outputs", []):
        output_type = output.get("output_type")

        if output_type == "error":
            raise SystemExit(
                "A Session 30 cell contains an execution error: "
                f"{output.get('ename')}: {output.get('evalue')}"
            )

        if "text" in output:
            text = output["text"]
            if isinstance(text, list):
                text = "".join(text)
            output_text.append(str(text))

        data = output.get("data", {})
        for mime_value in data.values():
            if isinstance(mime_value, list):
                mime_value = "".join(mime_value)
            output_text.append(str(mime_value))

combined_output = "\n".join(output_text)

required_output_tokens = [
    "Session 30 MLP test result",
    "MLP Regressor",
    "SESSION 30 NOTEBOOK VERIFICATION PASSED",
]

missing = [
    token
    for token in required_output_tokens
    if token not in combined_output
]

if missing:
    raise SystemExit(
        "Executed notebook output verification failed. "
        f"Missing output tokens: {missing}"
    )

print("Executed Session 30 outputs verified.")
'@

    Invoke-Checked "Verify executed MLP outputs" {
        & $Python -c $OutputVerifier $NotebookPath
    }
}
else {
    Write-Warning (
        "Notebook execution was skipped. Structural verification passed, " +
        "but model metrics were not regenerated locally."
    )
}

Write-Section "Review and stage only the regression notebook"

& git status --short -- "$NotebookRelative"

& git diff --check -- "$NotebookRelative"

if ($LASTEXITCODE -ne 0) {
    throw "git diff --check found whitespace or patch-format problems."
}

Invoke-Checked "Stage the Session 30 regression notebook" {
    & git add -- "$NotebookRelative"
}

& git diff --cached --stat
& git diff --cached --check

if ($LASTEXITCODE -ne 0) {
    & git restore --staged -- "$NotebookRelative"

    throw (
        "The staged notebook failed git diff --cached --check. " +
        "The file was unstaged."
    )
}

& git diff --cached --quiet
$HasStagedChanges = ($LASTEXITCODE -ne 0)

if (-not $HasStagedChanges) {
    Write-Host (
        "No new Session 30 change was detected. " +
        "The regression notebook is already current."
    )
}
else {
    Invoke-Checked "Commit Session 30 notebook update" {
        & git commit -m "Add MLP regression result"
    }
}

if (-not $SkipPush) {
    Write-Section "Push the Session 30 commit to GitHub"

    $Branch = (& git branch --show-current).Trim()

    if (-not $Branch) {
        throw "Unable to determine the current Git branch."
    }

    & git remote get-url origin *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "The repository does not have an origin remote."
    }

    & git rev-parse `
        --abbrev-ref `
        --symbolic-full-name `
        "@{u}" *> $null

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

$CurrentCommit = (& git rev-parse HEAD).Trim()
Write-Host "Current commit: $CurrentCommit"

if (-not $SkipPush) {
    $RemoteBranch = (& git rev-parse --abbrev-ref "@{u}").Trim()
    $RemoteCommit = (& git rev-parse $RemoteBranch).Trim()

    if ($CurrentCommit -ne $RemoteCommit) {
        throw (
            "Local HEAD does not match the tracked remote branch. " +
            "The push may not have completed."
        )
    }

    Write-Host "Remote branch: $RemoteBranch"
    Write-Host "Remote commit: $RemoteCommit"
}

Write-Host ""
Write-Host "SESSION 30 GITHUB DELIVERABLE COMPLETED"
Write-Host "Notebook updated: $NotebookRelative"
Write-Host "Model added: MLP Regressor"
Write-Host "Pipeline: StandardScaler -> MLPRegressor(64, 32)"
Write-Host "Artifact: one MLP row in the regression comparison table"
Write-Host "Commit message: Add MLP regression result"

Remove-Item `
    -LiteralPath $TempRoot `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue
