# This will overwrite your script with the fixed version
$fixedScript = @'
# scripts\08_session33_github_deliverable.ps1

param(
    [string]$RepoPath = "C:\Users\yikib\student-performance-prediction-ml",
    [string]$CommitMessage = "Extend classification notebook with KNN SVM and Naive Bayes"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param(
        [string]$Message
    )
    Write-Host ""
    Write-Host ("=" * 78)
    Write-Host $Message
    Write-Host ("=" * 78)
}

function Assert-LastCommandSucceeded {
    param(
        [string]$FailureMessage
    )
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage Exit code: $LASTEXITCODE"
    }
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )
    
    # Normalize paths
    $BasePath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\')
    $FullPath = [System.IO.Path]::GetFullPath($FullPath).TrimEnd('\')
    
    # Split paths into parts
    $BaseParts = $BasePath.Split('\')
    $FullParts = $FullPath.Split('\')
    
    # Find where they diverge
    $CommonPrefixLength = 0
    $MinLength = [Math]::Min($BaseParts.Length, $FullParts.Length)
    
    for ($i = 0; $i -lt $MinLength; $i++) {
        if ($BaseParts[$i] -eq $FullParts[$i]) {
            $CommonPrefixLength++
        } else {
            break
        }
    }
    
    # Build relative path
    $RelativeParts = @()
    
    # Add ".." for each remaining part in base path
    for ($i = $CommonPrefixLength; $i -lt $BaseParts.Length; $i++) {
        $RelativeParts += ".."
    }
    
    # Add the remaining parts from the full path
    for ($i = $CommonPrefixLength; $i -lt $FullParts.Length; $i++) {
        $RelativeParts += $FullParts[$i]
    }
    
    if ($RelativeParts.Count -eq 0) {
        return "."
    }
    
    return [string]::Join("\", $RelativeParts)
}

function Invoke-GitPush {
    param(
        [string]$BranchName
    )
    git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        git push
        Assert-LastCommandSucceeded "Git push failed."
    }
    else {
        git push -u origin $BranchName
        Assert-LastCommandSucceeded "Git push with upstream configuration failed."
    }
}

Write-Step "SESSION 33 GITHUB DELIVERABLE"
Write-Host "Repository:"
Write-Host $RepoPath

# ---------------------------------------------------------------------------
# 1. Validate the project folder
# ---------------------------------------------------------------------------
Write-Step "1. Validating the project repository"

if (-not (Test-Path -LiteralPath $RepoPath)) {
    throw "The project directory does not exist: $RepoPath"
}

Set-Location -LiteralPath $RepoPath

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or is not available in PATH."
}

git rev-parse --is-inside-work-tree | Out-Null
Assert-LastCommandSucceeded "The selected directory is not a Git repository."

$OriginUrl = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($OriginUrl)) {
    throw "The repository does not have an origin remote."
}

Write-Host "Git repository: verified"
Write-Host "Origin remote: $OriginUrl"

# ---------------------------------------------------------------------------
# 2. Locate the classification notebook
# ---------------------------------------------------------------------------
Write-Step "2. Locating 05_classification_models.ipynb"

$NotebookCandidates = @(
    (Join-Path $RepoPath "05_classification_models.ipynb"),
    (Join-Path $RepoPath "notebooks\05_classification_models.ipynb")
)

$NotebookPath = $null
foreach ($Candidate in $NotebookCandidates) {
    if (Test-Path -LiteralPath $Candidate) {
        $NotebookPath = $Candidate
        break
    }
}

if (-not $NotebookPath) {
    $FoundNotebook = Get-ChildItem -LiteralPath $RepoPath -Filter "05_classification_models.ipynb" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($FoundNotebook) {
        $NotebookPath = $FoundNotebook.FullName
    }
}

if (-not $NotebookPath) {
    throw @"
05_classification_models.ipynb was not found.
Expected locations include:
$RepoPath\05_classification_models.ipynb
or
$RepoPath\notebooks\05_classification_models.ipynb
"@
}

$NotebookPath = (Resolve-Path -LiteralPath $NotebookPath).Path
# Use custom Get-RelativePath function instead of [System.IO.Path]::GetRelativePath
$NotebookRelativePath = Get-RelativePath -BasePath $RepoPath -FullPath $NotebookPath
$NotebookRelativePath = $NotebookRelativePath.Replace("\", "/")

Write-Host "Notebook found:"
Write-Host $NotebookPath

# ---------------------------------------------------------------------------
# 3. Back up the existing notebook
# ---------------------------------------------------------------------------
Write-Step "3. Creating a temporary notebook backup"

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupPath = Join-Path $env:TEMP "05_classification_models_before_session33_$Timestamp.ipynb"

Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force

Write-Host "Temporary backup:"
Write-Host $BackupPath

# ---------------------------------------------------------------------------
# 4. Create a temporary Python notebook updater
# ---------------------------------------------------------------------------
Write-Step "4. Creating the notebook update program"

$UpdaterPath = Join-Path $env:TEMP "update_session33_notebook_$Timestamp.py"

$PythonUpdater = @'
from __future__ import annotations
import json
import os
import sys
import tempfile
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit(
        "Usage: update_session33_notebook.py "
        "<05_classification_models.ipynb>"
    )

notebook_path = Path(sys.argv[1]).resolve()
if not notebook_path.exists():
    raise FileNotFoundError(
        f"Notebook not found: {notebook_path}"
    )

with notebook_path.open(
    "r",
    encoding="utf-8",
) as notebook_file:
    notebook = json.load(notebook_file)

if not isinstance(notebook, dict):
    raise TypeError(
        "The notebook root must be a JSON object."
    )

notebook.setdefault("nbformat", 4)
notebook.setdefault("nbformat_minor", 5)
notebook.setdefault("metadata", {})
notebook.setdefault("cells", [])

if not isinstance(notebook["cells"], list):
    raise TypeError(
        "The notebook cells value must be a list."
    )

SESSION_TAG = "session33-github-deliverable"

def normalized_tags(cell: dict) -> list[str]:
    metadata = cell.get("metadata", {})
    if not isinstance(metadata, dict):
        return []
    tags = metadata.get("tags", [])
    if not isinstance(tags, list):
        return []
    return [
        str(tag)
        for tag in tags
    ]

# Remove an earlier copy of the Session 33 block.
preserved_cells = [
    cell
    for cell in notebook["cells"]
    if SESSION_TAG not in normalized_tags(cell)
]

def markdown_cell(text: str) -> dict:
    return {
        "cell_type": "markdown",
        "metadata": {
            "tags": [SESSION_TAG],
        },
        "source": text.strip() + "\n",
    }

def code_cell(text: str) -> dict:
    source = text.strip() + "\n"
    # Confirm that every generated code cell is valid Python.
    compile(
        source,
        "<session33-notebook-cell>",
        "exec",
    )
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {
            "tags": [SESSION_TAG],
        },
        "outputs": [],
        "source": source,
    }

session33_cells = [
    markdown_cell(
        r"""
<!-- SESSION 33 GITHUB DELIVERABLE START -->
## Session 33: KNN, SVM, and Naive Bayes Classification

This section extends the classification-model notebook with three
additional classifier families:

1. K-Nearest Neighbors
2. Support Vector Machine
3. Gaussian Naive Bayes

All three classifiers use the same training and test observations.
KNN and SVM require scaling because their results depend directly on
feature distances or margins. Gaussian Naive Bayes is included in the
same pipeline to preserve a consistent modeling workflow.

The required output is a classification table containing KNN, SVM,
and NB rows.
"""
    ),
    code_cell(
        r"""
# Session 33 imports and prerequisite validation
from pathlib import Path
import numpy as np
import pandas as pd
from IPython.display import display
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC

required_session33_objects = [
    "Xtr_f",
    "Xte_f",
    "yctr",
    "ycte",
]

missing_session33_objects = [
    object_name
    for object_name in required_session33_objects
    if object_name not in globals()
]

if missing_session33_objects:
    raise NameError(
        "Run the earlier feature-preparation and classification-target "
        "cells before Session 33. Missing objects: "
        f"{missing_session33_objects}"
    )

if len(Xtr_f) != len(yctr):
    raise ValueError(
        "Xtr_f and yctr must contain the same number of rows."
    )

if len(Xte_f) != len(ycte):
    raise ValueError(
        "Xte_f and ycte must contain the same number of rows."
    )

training_classes = set(
    np.unique(
        np.asarray(yctr).ravel()
    )
)
test_classes = set(
    np.unique(
        np.asarray(ycte).ravel()
    )
)

if training_classes != {0, 1}:
    raise ValueError(
        "yctr must contain binary classes 0 and 1. "
        f"Found: {training_classes}"
    )

if test_classes != {0, 1}:
    raise ValueError(
        "ycte must contain binary classes 0 and 1. "
        f"Found: {test_classes}"
    )

print("Session 33 prerequisites verified.")
print("Training feature shape:", Xtr_f.shape)
print("Test feature shape:", Xte_f.shape)
print("Training classes:", sorted(training_classes))
print("Test classes:", sorted(test_classes))
"""
    ),
    markdown_cell(
        r"""
### Class definitions

The notebook uses the existing project target definition:

- `0` = at-risk student
- `1` = successful student

The standard precision, recall, and F1 metrics below treat class `1`
as the positive class. Additional at-risk metrics treat class `0` as
the target class.
"""
    ),
    code_cell(
        r"""
# Define a reusable Session 33 classification evaluator.
def evaluate_session33_classifier(
    y_true,
    y_pred,
    y_probability,
):
    """
    Return standard and at-risk classification metrics.

    Standard precision, recall, and F1 treat class 1 as positive.
    At-risk precision, recall, and F1 treat class 0 as positive.
    """
    unique_classes = np.unique(
        np.asarray(y_true).ravel()
    )
    if len(unique_classes) == 2:
        roc_auc = roc_auc_score(
            y_true,
            y_probability,
        )
    else:
        roc_auc = np.nan

    return {
        "accuracy": accuracy_score(
            y_true,
            y_pred,
        ),
        "precision": precision_score(
            y_true,
            y_pred,
            zero_division=0,
        ),
        "recall": recall_score(
            y_true,
            y_pred,
            zero_division=0,
        ),
        "f1": f1_score(
            y_true,
            y_pred,
            zero_division=0,
        ),
        "roc_auc": roc_auc,
        "at_risk_precision": precision_score(
            y_true,
            y_pred,
            pos_label=0,
            zero_division=0,
        ),
        "at_risk_recall": recall_score(
            y_true,
            y_pred,
            pos_label=0,
            zero_division=0,
        ),
        "at_risk_f1": f1_score(
            y_true,
            y_pred,
            pos_label=0,
            zero_division=0,
        ),
    }

print(
    "Session 33 classification evaluator is ready."
)
"""
    ),
    code_cell(
        r"""
# Train KNN, SVM, and Gaussian Naive Bayes.
session33_estimators = [
    (
        "KNN",
        "K-Nearest Neighbors",
        "Instance-based",
        KNeighborsClassifier(),
    ),
    (
        "SVM",
        "Support Vector Machine",
        "Maximum-margin",
        SVC(
            probability=True,
            random_state=42,
        ),
    ),
    (
        "NB",
        "Gaussian Naive Bayes",
        "Probabilistic",
        GaussianNB(),
    ),
]

session33_models = {}
session33_predictions = {}
session33_probabilities = {}
session33_result_rows = []

for (
    model_code,
    full_model_name,
    model_family,
    estimator,
) in session33_estimators:
    pipeline = make_pipeline(
        StandardScaler(),
        estimator,
    )
    pipeline.fit(
        Xtr_f,
        yctr,
    )
    predictions = pipeline.predict(
        Xte_f
    )
    probabilities = pipeline.predict_proba(
        Xte_f
    )[:, 1]
    metrics = evaluate_session33_classifier(
        y_true=ycte,
        y_pred=predictions,
        y_probability=probabilities,
    )
    session33_models[model_code] = pipeline
    session33_predictions[model_code] = predictions
    session33_probabilities[model_code] = probabilities
    session33_result_rows.append(
        {
            "Model": model_code,
            "Full_Model_Name": full_model_name,
            "Model_Family": model_family,
            "Scaling_Used": True,
            **metrics,
        }
    )
    print(
        f"{model_code} completed: "
        f"F1 = {metrics['f1']:.4f}, "
        f"At-risk F1 = {metrics['at_risk_f1']:.4f}"
    )

session33_results_df = pd.DataFrame(
    session33_result_rows
)
session33_results_df = (
    session33_results_df
    .sort_values(
        by="f1",
        ascending=False,
    )
    .reset_index(drop=True)
)
session33_results_df.insert(
    0,
    "Session33_F1_Rank",
    range(
        1,
        len(session33_results_df) + 1,
    ),
)

print()
print("Session 33 classifier comparison:")
display(
    session33_results_df.style.format(
        {
            "accuracy": "{:.4f}",
            "precision": "{:.4f}",
            "recall": "{:.4f}",
            "f1": "{:.4f}",
            "roc_auc": "{:.4f}",
            "at_risk_precision": "{:.4f}",
            "at_risk_recall": "{:.4f}",
            "at_risk_f1": "{:.4f}",
        }
    )
)
"""
    ),
    code_cell(
        r"""
# Add KNN, SVM, and NB to the cumulative classification table.
classification_metric_columns = [
    "Model",
    "Full_Model_Name",
    "Model_Family",
    "Scaling_Used",
    "accuracy",
    "precision",
    "recall",
    "f1",
    "roc_auc",
    "at_risk_precision",
    "at_risk_recall",
    "at_risk_f1",
]

possible_existing_tables = [
    "classification_table",
    "classification_comparison_df",
    "classification_results_df",
]

existing_classification_table = None
for table_name in possible_existing_tables:
    candidate = globals().get(table_name)
    if isinstance(candidate, pd.DataFrame):
        existing_classification_table = candidate.copy()
        print(
            f"Existing classification table found: "
            f"{table_name}"
        )
        break

new_session33_rows = session33_results_df[
    classification_metric_columns
].copy()

if (
    existing_classification_table is None
    or existing_classification_table.empty
    or "Model" not in existing_classification_table.columns
):
    classification_table = new_session33_rows.copy()
else:
    for column_name in classification_metric_columns:
        if column_name not in existing_classification_table.columns:
            existing_classification_table[column_name] = np.nan

    # Remove previous copies before adding the current Session 33 rows.
    existing_classification_table = (
        existing_classification_table.loc[
            ~existing_classification_table["Model"].isin(
                ["KNN", "SVM", "NB"]
            ),
            classification_metric_columns,
        ]
        .copy()
    )

    classification_table = pd.concat(
        [
            existing_classification_table,
            new_session33_rows,
        ],
        ignore_index=True,
    )

classification_table = (
    classification_table
    .sort_values(
        by="f1",
        ascending=False,
        na_position="last",
    )
    .reset_index(drop=True)
)

classification_table.insert(
    0,
    "Overall_F1_Rank",
    range(
        1,
        len(classification_table) + 1,
    ),
)

print("Updated classification table:")
display(
    classification_table.style.format(
        {
            "accuracy": "{:.4f}",
            "precision": "{:.4f}",
            "recall": "{:.4f}",
            "f1": "{:.4f}",
            "roc_auc": "{:.4f}",
            "at_risk_precision": "{:.4f}",
            "at_risk_recall": "{:.4f}",
            "at_risk_f1": "{:.4f}",
        }
    )
)
"""
    ),
    code_cell(
        r"""
# Save the Session 33 classification artifacts.
current_directory = Path.cwd()
repository_root = next(
    (
        directory
        for directory in [
            current_directory,
            *current_directory.parents,
        ]
        if (directory / ".git").exists()
    ),
    current_directory,
)

output_directory = (
    repository_root
    / "reports"
    / "tables"
)
output_directory.mkdir(
    parents=True,
    exist_ok=True,
)

session33_rows_path = (
    output_directory
    / "session33_classification_rows.csv"
)
classification_table_path = (
    output_directory
    / "classification_table.csv"
)

session33_results_df.to_csv(
    session33_rows_path,
    index=False,
)
classification_table.to_csv(
    classification_table_path,
    index=False,
)

print("Session 33 artifact files created:")
print(session33_rows_path)
print(classification_table_path)
"""
    ),
    code_cell(
        r"""
# Validate the Session 33 GitHub deliverable.
expected_session33_models = {
    "KNN",
    "SVM",
    "NB",
}
actual_session33_models = set(
    session33_results_df["Model"]
)

if actual_session33_models != expected_session33_models:
    raise AssertionError(
        "Session 33 results must contain exactly "
        "KNN, SVM, and NB."
    )

if len(session33_results_df) != 3:
    raise AssertionError(
        "Session 33 results must contain exactly three rows."
    )

if session33_results_df["Model"].duplicated().any():
    raise AssertionError(
        "Duplicate Session 33 model rows were found."
    )

required_metric_columns = [
    "accuracy",
    "precision",
    "recall",
    "f1",
    "roc_auc",
    "at_risk_precision",
    "at_risk_recall",
    "at_risk_f1",
]

if session33_results_df[
    required_metric_columns
].isna().any().any():
    raise AssertionError(
        "One or more Session 33 metrics are missing."
    )

metric_values = session33_results_df[
    required_metric_columns
].to_numpy(
    dtype=float
)

if not np.isfinite(metric_values).all():
    raise AssertionError(
        "One or more Session 33 metrics are not finite."
    )

if not (
    (metric_values >= 0)
    & (metric_values <= 1)
).all():
    raise AssertionError(
        "All Session 33 classification metrics must "
        "be between 0 and 1."
    )

rows_in_main_table = classification_table[
    classification_table["Model"].isin(
        expected_session33_models
    )
]

if len(rows_in_main_table) != 3:
    raise AssertionError(
        "The cumulative classification table must contain "
        "exactly one KNN, one SVM, and one NB row."
    )

best_session33_row = session33_results_df.iloc[0]

print("=" * 72)
print(
    "SESSION 33 GITHUB DELIVERABLE "
    "COMPLETED SUCCESSFULLY"
)
print("=" * 72)
print("KNN row: verified")
print("SVM row: verified")
print("NB row: verified")
print("Classification table: verified")
print("CSV artifact code: verified")
print()
print(
    "Highest-F1 Session 33 classifier:",
    best_session33_row["Full_Model_Name"],
)
print(
    "Highest Session 33 F1:",
    f"{best_session33_row['f1']:.4f}",
)
"""
    ),
    markdown_cell(
        r"""
### Session 33 interpretation

- **KNN** assumes that observations close to one another in the scaled
  feature space tend to share the same class.
- **SVM** searches for a maximum-margin decision boundary separating
  the classes.
- **Gaussian Naive Bayes** assumes that predictors are conditionally
  independent given the class label and that continuous predictors are
  approximately Gaussian within each class.

The Naive Bayes independence assumption is unlikely to be fully
realistic for student-performance data because variables such as prior
grades, failures, study time, absences, and support may remain related
within each outcome class. Naive Bayes nevertheless provides a useful,
efficient, and interpretable baseline.

<!-- SESSION 33 GITHUB DELIVERABLE END -->
"""
    ),
]

notebook["cells"] = (
    preserved_cells
    + session33_cells
)

# Validate all newly generated code cells one final time.
for cell in session33_cells:
    if cell.get("cell_type") == "code":
        compile(
            cell.get("source", ""),
            "<session33-notebook-validation>",
            "exec",
        )

# Write atomically so that a partial write cannot corrupt the notebook.
temporary_file_descriptor, temporary_file_name = tempfile.mkstemp(
    prefix=notebook_path.stem + "_",
    suffix=".ipynb",
    dir=str(notebook_path.parent),
)
os.close(temporary_file_descriptor)
temporary_path = Path(temporary_file_name)

try:
    with temporary_path.open(
        "w",
        encoding="utf-8",
        newline="\n",
    ) as notebook_file:
        json.dump(
            notebook,
            notebook_file,
            indent=1,
            ensure_ascii=False,
        )
        notebook_file.write("\n")
    temporary_path.replace(
        notebook_path
    )
finally:
    if temporary_path.exists():
        temporary_path.unlink()

print(
    f"Updated notebook: {notebook_path}"
)
print(
    f"Preserved existing cells: "
    f"{len(preserved_cells)}"
)
print(
    f"Added Session 33 cells: "
    f"{len(session33_cells)}"
)
'@

Set-Content -LiteralPath $UpdaterPath -Value $PythonUpdater -Encoding UTF8

Write-Host "Notebook updater created:"
Write-Host $UpdaterPath

# ---------------------------------------------------------------------------
# 5. Select Python
# ---------------------------------------------------------------------------
Write-Step "5. Selecting the Python interpreter"

$VenvPython = Join-Path $RepoPath ".venv\Scripts\python.exe"
$PythonCommand = $null
$PythonArguments = @()

if (Test-Path -LiteralPath $VenvPython) {
    $PythonCommand = $VenvPython
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonCommand = "py"
    $PythonArguments = @("-3")
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonCommand = "python"
}
else {
    throw @"
Python was not found.
Install Python or create the project virtual environment before
running this automation.
"@
}

Write-Host "Python command:"
Write-Host $PythonCommand

# ---------------------------------------------------------------------------
# 6. Update the notebook
# ---------------------------------------------------------------------------
Write-Step "6. Extending the classification notebook"

try {
    & $PythonCommand @PythonArguments $UpdaterPath $NotebookPath
    Assert-LastCommandSucceeded "The notebook update program failed."
}
catch {
    Write-Host ""
    Write-Host "The notebook update failed."
    Write-Host "Restoring the backup."
    Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
    throw
}

Write-Host "Notebook update completed."

# ---------------------------------------------------------------------------
# 7. Validate the notebook JSON
# ---------------------------------------------------------------------------
Write-Step "7. Validating the updated notebook"

$ValidationCode = @'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(
    "r",
    encoding="utf-8",
) as file:
    notebook = json.load(file)

cells = notebook.get(
    "cells",
    [],
)

tagged_cells = [
    cell
    for cell in cells
    if "session33-github-deliverable"
    in cell.get(
        "metadata",
        {},
    ).get(
        "tags",
        [],
    )
]

if len(tagged_cells) < 8:
    raise AssertionError(
        "The Session 33 notebook block appears incomplete."
    )

combined_source = "\n".join(
    (
        "".join(cell.get("source", []))
        if isinstance(cell.get("source", []), list)
        else str(cell.get("source", ""))
    )
    for cell in tagged_cells
)

required_terms = [
    "KNeighborsClassifier",
    "SVC",
    "GaussianNB",
    "StandardScaler",
    "session33_results_df",
    "classification_table",
    "session33_classification_rows.csv",
    "SESSION 33 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY",
]

missing_terms = [
    term
    for term in required_terms
    if term not in combined_source
]

if missing_terms:
    raise AssertionError(
        f"Missing required Session 33 content: {missing_terms}"
    )

print(
    "Notebook JSON validation passed."
)
print(
    f"Session 33 tagged cells: {len(tagged_cells)}"
)
'@

$ValidationPath = Join-Path $env:TEMP "validate_session33_notebook_$Timestamp.py"

Set-Content -LiteralPath $ValidationPath -Value $ValidationCode -Encoding UTF8

& $PythonCommand @PythonArguments $ValidationPath $NotebookPath
Assert-LastCommandSucceeded "Notebook validation failed."

# ---------------------------------------------------------------------------
# 8. Run Git quality checks
# ---------------------------------------------------------------------------
Write-Step "8. Running Git validation"

git diff --check -- $NotebookRelativePath
Assert-LastCommandSucceeded "Git detected formatting or whitespace errors."

Write-Host ""
Write-Host "Notebook Git status:"
git status --short -- $NotebookRelativePath

Write-Host ""
Write-Host "Notebook diff summary:"
git diff --stat -- $NotebookRelativePath

# ---------------------------------------------------------------------------
# 9. Stage only the notebook
# ---------------------------------------------------------------------------
Write-Step "9. Staging the Session 33 notebook"

git add -- $NotebookRelativePath
Assert-LastCommandSucceeded "Git could not stage the notebook."

git diff --cached --name-only -- $NotebookRelativePath

# ---------------------------------------------------------------------------
# 10. Commit the notebook
# ---------------------------------------------------------------------------
Write-Step "10. Committing the Session 33 deliverable"

git diff --cached --quiet -- $NotebookRelativePath
$StagedDiffExitCode = $LASTEXITCODE

if ($StagedDiffExitCode -eq 1) {
    git commit -m $CommitMessage -- $NotebookRelativePath
    Assert-LastCommandSucceeded "Git commit failed."
    Write-Host "Session 33 notebook committed."
}
elseif ($StagedDiffExitCode -eq 0) {
    Write-Host @"
No new notebook changes required a commit.
The Session 33 block may already be present and current.
"@
}
else {
    throw @"
Unable to determine whether the notebook contains staged changes.
Exit code: $StagedDiffExitCode
"@
}

# ---------------------------------------------------------------------------
# 11. Push to GitHub
# ---------------------------------------------------------------------------
Write-Step "11. Pushing the current branch to GitHub"

$CurrentBranch = (git branch --show-current).Trim()
Assert-LastCommandSucceeded "Unable to determine the current Git branch."

if ([string]::IsNullOrWhiteSpace($CurrentBranch)) {
    throw "The repository is in detached-HEAD mode."
}

Write-Host "Current branch: $CurrentBranch"

Invoke-GitPush -BranchName $CurrentBranch

# ---------------------------------------------------------------------------
# 12. Final verification
# ---------------------------------------------------------------------------
Write-Step "12. Final verification"

$LatestCommit = git log -1 --oneline
Assert-LastCommandSucceeded "Unable to read the latest commit."

$FinalStatus = git status --short -- $NotebookRelativePath

if (-not [string]::IsNullOrWhiteSpace($FinalStatus)) {
    Write-Host "Notebook status:"
    Write-Host $FinalStatus
    throw @"
The notebook still has uncommitted changes after the push.
"@
}

Write-Host "Latest commit:"
Write-Host $LatestCommit
Write-Host ""
Write-Host "Remote:"
Write-Host $OriginUrl
Write-Host ""
Write-Host ("=" * 78)
Write-Host "SESSION 33 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY"
Write-Host ("=" * 78)
Write-Host "Notebook: $NotebookRelativePath"
Write-Host "Branch: $CurrentBranch"
Write-Host "KNN code: added"
Write-Host "SVM code: added"
Write-Host "Gaussian Naive Bayes code: added"
Write-Host "Classification table code: added"
Write-Host "CSV artifact code: added"
Write-Host "Notebook validation: passed"
Write-Host "Git commit: completed or already current"
Write-Host "GitHub push: completed"

# Remove only temporary helper files.
Remove-Item -LiteralPath $UpdaterPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ValidationPath -Force -ErrorAction SilentlyContinue
'@

# Save the fixed script
$fixedScript | Out-File -FilePath "C:\Users\yikib\student-performance-prediction-ml\scripts\08_session33_github_deliverable.ps1" -Encoding UTF8 -Force