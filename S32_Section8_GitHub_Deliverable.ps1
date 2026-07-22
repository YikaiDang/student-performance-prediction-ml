# Session 32 - Logistic Regression Classification Baseline
# Save this to your Documents folder (outside the repository)

$ScriptPath = "C:\Users\yikib\Documents\S32_Section8_GitHub_Deliverable.ps1"

$ScriptContent = @'
[CmdletBinding()]
param(
    [string]$RepoPath = "C:\Users\yikib\student-performance-prediction-ml",
    [string]$NotebookRelativePath = "notebooks\05_classification_models.ipynb",
    [string]$CommitMessage = "Add Session 32 logistic regression classification baseline",
    [switch]$SkipNotebookExecution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Executable,
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$FailureMessage
    )
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage Exit code: $LASTEXITCODE"
    }
}

Write-Step "SESSION 32 SECTION 8 AUTOMATION STARTED"

# ---------------------------------------------------------------------
# 1. Validate the repository path
# ---------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
    throw "Repository folder not found: $RepoPath"
}

Push-Location $RepoPath
try {
    if (-not (Test-Path -LiteralPath ".git" -PathType Container)) {
        throw "This folder is not a Git repository: $RepoPath"
    }

    Write-Host "Repository:"
    Write-Host $RepoPath

    # -----------------------------------------------------------------
    # 2. Confirm Git and Python
    # -----------------------------------------------------------------
    Write-Step "CHECKING GIT AND PYTHON"

    $GitCommand = Get-Command git -ErrorAction Stop
    $GitExecutable = $GitCommand.Source

    if (Test-Path -LiteralPath ".venv\Scripts\python.exe") {
        $PythonExecutable = (Resolve-Path ".venv\Scripts\python.exe").Path
        Write-Host "Using project virtual environment:"
        Write-Host $PythonExecutable
    }
    else {
        $PythonCommand = Get-Command python -ErrorAction Stop
        $PythonExecutable = $PythonCommand.Source
        Write-Host "Project .venv was not found."
        Write-Host "Using available Python:"
        Write-Host $PythonExecutable
    }

    Invoke-ExternalCommand -Executable $GitExecutable -Arguments @("--version") -FailureMessage "Git validation failed."
    Invoke-ExternalCommand -Executable $PythonExecutable -Arguments @("--version") -FailureMessage "Python validation failed."

    # -----------------------------------------------------------------
    # 3. Protect unrelated staged work
    # -----------------------------------------------------------------
    Write-Step "CHECKING THE GIT STAGING AREA"

    $InitiallyStagedFiles = @(& $GitExecutable diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the Git staging area."
    }

    if ($InitiallyStagedFiles.Count -gt 0) {
        Write-Host "The following files are already staged:"
        $InitiallyStagedFiles | ForEach-Object { Write-Host " $_" }
        throw @"
The automation stopped to avoid committing unrelated staged files.
Commit or unstage those files before rerunning this script.
"@
    }
    Write-Host "No unrelated files are currently staged."

    # -----------------------------------------------------------------
    # 4. Determine the current branch and remote
    # -----------------------------------------------------------------
    Write-Step "CHECKING THE CURRENT GIT BRANCH"

    $CurrentBranch = (& $GitExecutable branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to determine the current Git branch."
    }
    if ([string]::IsNullOrWhiteSpace($CurrentBranch)) {
        throw "The repository is in detached HEAD state."
    }
    Write-Host "Current branch: $CurrentBranch"

    $OriginUrl = (& $GitExecutable remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($OriginUrl)) {
        throw "The Git remote named origin is not configured."
    }
    Write-Host "Origin remote:"
    Write-Host $OriginUrl

    # -----------------------------------------------------------------
    # 5. Select required Python packages
    # -----------------------------------------------------------------
    Write-Step "CHECKING REQUIRED PYTHON PACKAGES"

    $PackageCheckCode = @'
import importlib.util
required = {
    "numpy": "numpy",
    "pandas": "pandas",
    "sklearn": "scikit-learn",
    "matplotlib": "matplotlib",
    "IPython": "ipython",
    "jupyter_core": "jupyter",
    "nbconvert": "nbconvert",
    "ipykernel": "ipykernel",
    "pyarrow": "pyarrow",
}
missing = [
    package
    for module, package in required.items()
    if importlib.util.find_spec(module) is None
]
print(" ".join(missing))
'@

    $MissingPackagesOutput = (& $PythonExecutable -c $PackageCheckCode)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the Python environment."
    }

    $MissingPackagesText = ($MissingPackagesOutput | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($MissingPackagesText)) {
        $MissingPackages = @($MissingPackagesText -split "\s+")
        Write-Host "Installing missing packages:"
        $MissingPackages | ForEach-Object { Write-Host " $_" }

        Invoke-ExternalCommand -Executable $PythonExecutable -Arguments @("-m", "pip", "install", "--upgrade", "pip") -FailureMessage "Unable to upgrade pip."

        $PipInstallArguments = @("-m", "pip", "install") + $MissingPackages
        Invoke-ExternalCommand -Executable $PythonExecutable -Arguments $PipInstallArguments -FailureMessage "Unable to install the required packages."
    }
    else {
        Write-Host "All required Python packages are installed."
    }

    # -----------------------------------------------------------------
    # 6. Create the notebook folder
    # -----------------------------------------------------------------
    Write-Step "CREATING THE NOTEBOOK DIRECTORY"

    $NotebookPath = Join-Path $RepoPath $NotebookRelativePath
    $NotebookDirectory = Split-Path -Parent $NotebookPath
    New-Item -ItemType Directory -Path $NotebookDirectory -Force | Out-Null
    Write-Host "Notebook path:"
    Write-Host $NotebookPath

    # -----------------------------------------------------------------
    # 7. Back up an existing notebook outside the repository
    # -----------------------------------------------------------------
    if (Test-Path -LiteralPath $NotebookPath) {
        $BackupDirectory = Join-Path $env:TEMP "GSSRP_S32_Backups"
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupPath = Join-Path $BackupDirectory "05_classification_models_$Timestamp.ipynb"
        Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force
        Write-Host "Existing notebook backup:"
        Write-Host $BackupPath
    }

    # -----------------------------------------------------------------
    # 8. Build the notebook
    # -----------------------------------------------------------------
    Write-Step "BUILDING 05_classification_models.ipynb"

    $BuilderPath = Join-Path $env:TEMP ("build_session32_notebook_" + [guid]::NewGuid().ToString("N") + ".py")

    $BuilderCode = @'
import json
import sys
from pathlib import Path

def markdown_cell(text):
    return {
        "cell_type": "markdown",
        "metadata": {},
        "source": text.strip().splitlines(keepends=True),
    }

def code_cell(text):
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": text.strip().splitlines(keepends=True),
    }

output_path = Path(sys.argv[1])
output_path.parent.mkdir(parents=True, exist_ok=True)

cells = []

cells.append(
    markdown_cell(
        r"""
# Session 32: Logistic Regression Classification
## GitHub Deliverable
This notebook implements the Session 32 Logistic Regression baseline for
student at-risk classification.

### Classification target
- `1` = at-risk student, where `G3 < 10`
- `0` = successful student, where `G3 >= 10`

The positive class is defined as **at risk** so that recall measures the
percentage of actual at-risk students correctly identified.

The original Session 32 source snippet used `y >= 10`, which assigns class
`1` to successful students. This notebook reverses that definition to match
the stated early-warning research objective.
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 1. Imports and repository configuration
The notebook searches upward from the current working directory until it
finds the project Git repository.
"""
    )
)

cells.append(
    code_cell(
        r"""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from IPython.display import display
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    ConfusionMatrixDisplay,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

def find_repository_root(start_path=None):
    start = Path(start_path or Path.cwd()).resolve()
    candidates = [start, *start.parents]
    for candidate in candidates:
        if (candidate / ".git").exists():
            return candidate
    raise FileNotFoundError("Unable to locate the Git repository root.")

REPO_ROOT = find_repository_root()
DATA_DIRECTORY = REPO_ROOT / "data"
PROCESSED_DIRECTORY = DATA_DIRECTORY / "processed"
RAW_DIRECTORY = DATA_DIRECTORY / "raw"

print("Repository root:")
print(REPO_ROOT)
print("\nProcessed-data directory:")
print(PROCESSED_DIRECTORY)
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 2. Load the full-information modeling dataset
The loader first searches for the Session 20 full-information feature and
target files. If they are unavailable, it searches the repository for a
student dataset containing the `G3` target column.

The notebook supports CSV, Parquet, and pickle files.
"""
    )
)

cells.append(
    code_cell(
        r"""
def read_table(path):
    path = Path(path)
    suffix = path.suffix.lower()
    if suffix == ".csv":
        return pd.read_csv(path, sep=None, engine="python")
    if suffix == ".parquet":
        return pd.read_parquet(path)
    if suffix in {".pkl", ".pickle"}:
        return pd.read_pickle(path)
    raise ValueError(f"Unsupported data-file type: {path}")

def first_existing_path(paths):
    for path in paths:
        if Path(path).exists():
            return Path(path)
    return None

x_candidates = [
    PROCESSED_DIRECTORY / "X_full.parquet",
    PROCESSED_DIRECTORY / "X_full.csv",
    PROCESSED_DIRECTORY / "X_full.pkl",
    PROCESSED_DIRECTORY / "X_full.pickle",
]
y_candidates = [
    PROCESSED_DIRECTORY / "y_full.parquet",
    PROCESSED_DIRECTORY / "y_full.csv",
    PROCESSED_DIRECTORY / "y_full.pkl",
    PROCESSED_DIRECTORY / "y_full.pickle",
]

x_path = first_existing_path(x_candidates)
y_path = first_existing_path(y_candidates)
data_source = None

if x_path is not None and y_path is not None:
    X_full = read_table(x_path)
    y_loaded = read_table(y_path)
    if isinstance(y_loaded, pd.DataFrame):
        if "G3" in y_loaded.columns:
            y = y_loaded["G3"].copy()
        elif y_loaded.shape[1] == 1:
            y = y_loaded.iloc[:, 0].copy()
        else:
            raise ValueError("The target file must have one column or a column named G3.")
    else:
        y = pd.Series(y_loaded).copy()
    data_source = f"Features: {x_path.relative_to(REPO_ROOT)}; Target: {y_path.relative_to(REPO_ROOT)}"
else:
    search_directories = [PROCESSED_DIRECTORY, RAW_DIRECTORY, DATA_DIRECTORY]
    candidate_files = []
    for directory in search_directories:
        if not directory.exists():
            continue
        for extension in ("*.csv", "*.parquet", "*.pkl", "*.pickle"):
            candidate_files.extend(directory.rglob(extension))

    excluded_name_terms = {
        "classification",
        "comparison",
        "leaderboard",
        "metric",
        "result",
        "coefficient",
        "prediction",
    }

    selected_dataset = None
    selected_path = None

    for candidate_path in sorted(set(candidate_files)):
        lower_name = candidate_path.name.lower()
        if any(term in lower_name for term in excluded_name_terms):
            continue
        try:
            candidate_frame = read_table(candidate_path)
        except Exception:
            continue
        if not isinstance(candidate_frame, pd.DataFrame):
            continue
        if "G3" in candidate_frame.columns and candidate_frame.shape[0] >= 20 and candidate_frame.shape[1] >= 5:
            selected_dataset = candidate_frame
            selected_path = candidate_path
            break

    if selected_dataset is None:
        raise FileNotFoundError(
            "No usable dataset was found. Expected either data/processed/X_full and y_full files, or a dataset containing the G3 target column."
        )

    y = selected_dataset["G3"].copy()
    X_full = selected_dataset.drop(columns=["G3"]).copy()
    data_source = str(selected_path.relative_to(REPO_ROOT))

if not isinstance(X_full, pd.DataFrame):
    X_full = pd.DataFrame(X_full)

X_full = X_full.copy()
unnamed_columns = [column for column in X_full.columns if str(column).startswith("Unnamed:")]
if unnamed_columns:
    X_full = X_full.drop(columns=unnamed_columns)

if "G3" in X_full.columns:
    X_full = X_full.drop(columns=["G3"])

X_full.columns = X_full.columns.map(str)

y = pd.Series(np.asarray(y).reshape(-1), name="G3")

X_full = X_full.reset_index(drop=True)
y = y.reset_index(drop=True)
y = pd.to_numeric(y, errors="raise")

if len(X_full) != len(y):
    raise ValueError("Feature and target row counts do not match.")

print("Loaded data source:")
print(data_source)
print("\nFeature matrix before encoding:")
print(X_full.shape)
print("\nTarget length:")
print(len(y))
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 3. Prepare numeric model features
Categorical variables are one-hot encoded. Missing numeric values are filled
with their medians, while missing categorical values are assigned a
`Missing` category.
"""
    )
)

cells.append(
    code_cell(
        r"""
X_full = X_full.replace([np.inf, -np.inf], np.nan)

numeric_columns = X_full.select_dtypes(include="number").columns.tolist()
categorical_columns = [column for column in X_full.columns if column not in numeric_columns]

for column in numeric_columns:
    median_value = X_full[column].median()
    if pd.isna(median_value):
        median_value = 0.0
    X_full[column] = X_full[column].fillna(median_value)

for column in categorical_columns:
    X_full[column] = X_full[column].astype("string").fillna("Missing")

X_full = pd.get_dummies(X_full, columns=categorical_columns, drop_first=True, dtype=float)
X_full = X_full.astype(float)

if X_full.isna().any().any():
    raise ValueError("The prepared feature matrix contains missing values.")

if not np.isfinite(X_full.to_numpy(dtype=float)).all():
    raise ValueError("The prepared feature matrix contains non-finite values.")

if "G3" in X_full.columns:
    raise ValueError("Target leakage detected: G3 appears among the features.")

print("Prepared feature matrix:")
print(X_full.shape)
print("\nNumber of numeric model features:")
print(X_full.shape[1])
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 4. Reproduce the full-information train/test split
The split uses the same fixed random state used throughout the project.
The classification labels are derived after the split so that training and
test row indices remain aligned with the regression task.
"""
    )
)

cells.append(
    code_cell(
        r"""
Xtr_f, Xte_f, ytr, yte = train_test_split(
    X_full,
    y,
    test_size=0.20,
    random_state=42,
)

yc = (y < 10).astype(int)
yc.name = "at_risk"

yctr = yc.loc[ytr.index].copy()
ycte = yc.loc[yte.index].copy()

if set(yctr.unique()) != {0, 1}:
    raise ValueError("The training target does not contain both classes.")

if set(ycte.unique()) != {0, 1}:
    raise ValueError("The test target does not contain both classes.")

print("Training features:", Xtr_f.shape)
print("Test features:", Xte_f.shape)

print("\nTraining target distribution:")
display(yctr.value_counts().sort_index().rename(index={0: "Successful", 1: "At-risk"}).to_frame("Count"))

print("Test target distribution:")
display(ycte.value_counts().sort_index().rename(index={0: "Successful", 1: "At-risk"}).to_frame("Count"))
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 5. Define the classification evaluation function
"""
    )
)

cells.append(
    code_cell(
        r"""
def eval_clf(y_true, y_pred, y_proba=None):
    results = {
        "accuracy": accuracy_score(y_true, y_pred),
        "precision": precision_score(y_true, y_pred, zero_division=0),
        "recall": recall_score(y_true, y_pred, zero_division=0),
        "f1": f1_score(y_true, y_pred, zero_division=0),
    }
    if y_proba is not None:
        if len(np.unique(y_true)) == 2:
            results["roc_auc"] = roc_auc_score(y_true, y_proba)
        else:
            results["roc_auc"] = np.nan
    return results

print("Classification evaluation function created.")
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 6. Fit the Logistic Regression baseline
`StandardScaler` is placed inside the pipeline so that scaling parameters are
learned from the training data only.
"""
    )
)

cells.append(
    code_cell(
        r"""
clf = make_pipeline(
    StandardScaler(),
    LogisticRegression(
        max_iter=1000,
        random_state=42,
    ),
)

clf.fit(Xtr_f, yctr)

y_pred_logistic = clf.predict(Xte_f)
y_proba_logistic = clf.predict_proba(Xte_f)[:, 1]

logistic_metrics = eval_clf(ycte, y_pred_logistic, y_proba_logistic)

logistic_metrics_df = pd.DataFrame(
    [
        {
            "Model": "Logistic Regression",
            "Accuracy": logistic_metrics["accuracy"],
            "Precision": logistic_metrics["precision"],
            "Recall": logistic_metrics["recall"],
            "F1": logistic_metrics["f1"],
            "ROC_AUC": logistic_metrics["roc_auc"],
        }
    ]
)

print("Logistic Regression test metrics:")
display(
    logistic_metrics_df.style.format(
        {
            "Accuracy": "{:.4f}",
            "Precision": "{:.4f}",
            "Recall": "{:.4f}",
            "F1": "{:.4f}",
            "ROC_AUC": "{:.4f}",
        }
    )
)
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 7. Classification report and confusion matrix
Recall for the at-risk class measures the proportion of actual at-risk
students correctly identified by the model.
"""
    )
)

cells.append(
    code_cell(
        r"""
print(
    classification_report(
        ycte,
        y_pred_logistic,
        labels=[0, 1],
        target_names=["Successful", "At-risk"],
        digits=4,
        zero_division=0,
    )
)

logistic_confusion_matrix = confusion_matrix(ycte, y_pred_logistic, labels=[0, 1])

confusion_table = pd.DataFrame(
    logistic_confusion_matrix,
    index=["Actual successful", "Actual at-risk"],
    columns=["Predicted successful", "Predicted at-risk"],
)
display(confusion_table)

ConfusionMatrixDisplay(
    confusion_matrix=logistic_confusion_matrix,
    display_labels=["Successful", "At-risk"],
).plot(values_format="d")
plt.title("Session 32 Logistic Regression Confusion Matrix")
plt.tight_layout()
plt.show()
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 8. Inspect the Logistic Regression coefficients
Because class `1` represents at-risk students:
- Positive coefficients push predictions toward at risk.
- Negative coefficients push predictions toward successful.
- Larger absolute coefficients indicate stronger linear contributions.
- Coefficients show model associations, not causal effects.
"""
    )
)

cells.append(
    code_cell(
        r"""
fitted_logistic = clf.named_steps["logisticregression"]

logistic_coefficients = pd.DataFrame(
    {
        "Feature": Xtr_f.columns,
        "Coefficient": fitted_logistic.coef_[0],
    }
)

logistic_coefficients["Absolute_Coefficient"] = logistic_coefficients["Coefficient"].abs()
logistic_coefficients["Odds_Ratio"] = np.exp(logistic_coefficients["Coefficient"])

logistic_coefficients["Direction"] = np.select(
    [
        logistic_coefficients["Coefficient"] > 0,
        logistic_coefficients["Coefficient"] < 0,
    ],
    [
        "Toward at-risk",
        "Toward successful",
    ],
    default="No directional effect",
)

logistic_coefficients = logistic_coefficients.sort_values(by="Absolute_Coefficient", ascending=False).reset_index(drop=True)

print("Largest Logistic Regression coefficients:")
display(
    logistic_coefficients.head(20).style.format(
        {
            "Coefficient": "{:.4f}",
            "Absolute_Coefficient": "{:.4f}",
            "Odds_Ratio": "{:.4f}",
        }
    )
)
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 9. Create the Logistic Regression classification-table row
This row is the Session 32 output artifact represented inside the notebook.
"""
    )
)

cells.append(
    code_cell(
        r"""
tn, fp, fn, tp = logistic_confusion_matrix.ravel()

classification_row = pd.DataFrame(
    [
        {
            "Session": 32,
            "Model": "Logistic Regression",
            "Task": "Binary Classification",
            "Scenario": "Full-information",
            "Positive_Class": "At-risk: G3 < 10",
            "Decision_Threshold": 0.50,
            "Accuracy": logistic_metrics["accuracy"],
            "Precision": logistic_metrics["precision"],
            "Recall": logistic_metrics["recall"],
            "F1": logistic_metrics["f1"],
            "ROC_AUC": logistic_metrics["roc_auc"],
            "True_Negative": int(tn),
            "False_Positive": int(fp),
            "False_Negative": int(fn),
            "True_Positive": int(tp),
            "Test_Rows": int(len(ycte)),
        }
    ]
)

print("Session 32 classification-table row:")
display(
    classification_row.style.format(
        {
            "Decision_Threshold": "{:.2f}",
            "Accuracy": "{:.4f}",
            "Precision": "{:.4f}",
            "Recall": "{:.4f}",
            "F1": "{:.4f}",
            "ROC_AUC": "{:.4f}",
        }
    )
)
"""
    )
)

cells.append(
    markdown_cell(
        r"""
## 10. Final validation
"""
    )
)

cells.append(
    code_cell(
        r"""
assert isinstance(clf.named_steps["standardscaler"], StandardScaler)
assert isinstance(clf.named_steps["logisticregression"], LogisticRegression)
assert clf.named_steps["logisticregression"].max_iter == 1000
assert set(clf.classes_) == {0, 1}
assert len(y_pred_logistic) == len(ycte)
assert len(y_proba_logistic) == len(ycte)
assert np.isfinite(y_proba_logistic).all()
assert ((y_proba_logistic >= 0) & (y_proba_logistic <= 1)).all()
assert len(logistic_coefficients) == Xtr_f.shape[1]
assert classification_row.shape[0] == 1
assert classification_row.loc[0, "Positive_Class"] == "At-risk: G3 < 10"

print("SESSION 32 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY")
print("\nModel:")
print("Logistic Regression")
print("\nAccuracy:")
print(f"{logistic_metrics['accuracy']:.4f}")
print("\nAt-risk recall:")
print(f"{logistic_metrics['recall']:.4f}")
print("\nNotebook:")
print("notebooks/05_classification_models.ipynb")
"""
    )
)

notebook = {
    "cells": cells,
    "metadata": {
        "kernelspec": {
            "display_name": "Python 3",
            "language": "python",
            "name": "python3",
        },
        "language_info": {
            "name": "python",
            "version": "3",
            "mimetype": "text/x-python",
            "codemirror_mode": {"name": "ipython", "version": 3},
            "pygments_lexer": "ipython3",
            "nbconvert_exporter": "python",
            "file_extension": ".py",
        },
    },
    "nbformat": 4,
    "nbformat_minor": 5,
}

output_path.write_text(
    json.dumps(notebook, indent=2, ensure_ascii=False),
    encoding="utf-8",
)

print(f"Notebook created: {output_path}")
print(f"Number of cells: {len(cells)}")
'@

    Set-Content -LiteralPath $BuilderPath -Value $BuilderCode -Encoding UTF8

    try {
        Invoke-ExternalCommand -Executable $PythonExecutable -Arguments @($BuilderPath, $NotebookPath) -FailureMessage "Notebook construction failed."
    }
    finally {
        if (Test-Path -LiteralPath $BuilderPath) {
            Remove-Item -LiteralPath $BuilderPath -Force
        }
    }

    if (-not (Test-Path -LiteralPath $NotebookPath)) {
        throw "The notebook was not created."
    }

    # -----------------------------------------------------------------
    # 9. Validate the notebook structure and required content
    # -----------------------------------------------------------------
    Write-Step "VALIDATING THE NOTEBOOK CONTENT"

    $ValidationCode = @'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

with path.open("r", encoding="utf-8") as handle:
    notebook = json.load(handle)

assert notebook["nbformat"] == 4
assert len(notebook["cells"]) >= 10

all_source = "\n".join(
    "".join(cell.get("source", []))
    for cell in notebook["cells"]
)

required_text = [
    "LogisticRegression",
    "StandardScaler",
    "make_pipeline",
    "predict_proba",
    "eval_clf",
    "classification_row",
    "At-risk: G3 < 10",
    "max_iter=1000",
    "logistic_coefficients",
]

missing = [text for text in required_text if text not in all_source]
if missing:
    raise AssertionError("Notebook is missing required content: " + ", ".join(missing))

print("Notebook JSON is valid.")
print("Required Logistic Regression content is present.")
'@

    Invoke-ExternalCommand -Executable $PythonExecutable -Arguments @("-c", $ValidationCode, $NotebookPath) -FailureMessage "Notebook-content validation failed."

    # -----------------------------------------------------------------
    # 10. Execute the notebook locally
    # -----------------------------------------------------------------
    if (-not $SkipNotebookExecution) {
        Write-Step "EXECUTING THE NOTEBOOK LOCALLY"

        $KernelName = "gssrp-s32-" + [guid]::NewGuid().ToString("N")
        $KernelPrefix = Join-Path $env:TEMP $KernelName
        $PreviousJupyterPath = $env:JUPYTER_PATH

        try {
            New-Item -ItemType Directory -Path $KernelPrefix -Force | Out-Null

            Invoke-ExternalCommand -Executable $PythonExecutable -Arguments @("-m", "ipykernel", "install", "--prefix", $KernelPrefix, "--name", $KernelName, "--display-name", "GSSRP Session 32") -FailureMessage "Unable to create the temporary notebook kernel."

            $TemporaryJupyterPath = Join-Path $KernelPrefix "share\jupyter"
            if ([string]::IsNullOrWhiteSpace($PreviousJupyterPath)) {
                $env:JUPYTER_PATH = $TemporaryJupyterPath
            }
            else {
                $env:JUPYTER_PATH = "$TemporaryJupyterPath;$PreviousJupyterPath"
            }

            Invoke-ExternalCommand -Executable $PythonExecutable -Arguments @("-m", "jupyter", "nbconvert", "--to", "notebook", "--execute", "--inplace", "--ExecutePreprocessor.timeout=600", "--ExecutePreprocessor.kernel_name=$KernelName", $NotebookPath) -FailureMessage "Notebook execution failed."

            Write-Host "Notebook execution completed successfully."
        }
        finally {
            $env:JUPYTER_PATH = $PreviousJupyterPath
            if (Test-Path -LiteralPath $KernelPrefix) {
                Remove-Item -LiteralPath $KernelPrefix -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    else {
        Write-Host ""
        Write-Host "Notebook execution was skipped by request."
    }

    # -----------------------------------------------------------------
    # 11. Confirm successful notebook execution
    # -----------------------------------------------------------------
    if (-not $SkipNotebookExecution) {
        Write-Step "VERIFYING EXECUTED NOTEBOOK OUTPUT"

        $ExecutionValidationCode = @'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

with path.open("r", encoding="utf-8") as handle:
    notebook = json.load(handle)

error_outputs = []
combined_output = []

for cell in notebook.get("cells", []):
    for output in cell.get("outputs", []):
        if output.get("output_type") == "error":
            error_outputs.append(output)
        if "text" in output:
            text = output["text"]
            if isinstance(text, list):
                combined_output.extend(text)
            else:
                combined_output.append(str(text))

if error_outputs:
    raise AssertionError(f"The notebook contains {len(error_outputs)} execution errors.")

output_text = "\n".join(combined_output)
required_completion_text = "SESSION 32 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY"

if required_completion_text not in output_text:
    raise AssertionError("The final completion message was not found in the executed notebook output.")

print("The notebook contains no execution errors.")
print("The final completion message is present.")
'@

        Invoke-ExternalCommand -Executable $PythonExecutable -Arguments @("-c", $ExecutionValidationCode, $NotebookPath) -FailureMessage "Executed-notebook validation failed."
    }

    # -----------------------------------------------------------------
    # 12. Stage only the required notebook
    # -----------------------------------------------------------------
    Write-Step "STAGING THE SESSION 32 NOTEBOOK"

    Invoke-ExternalCommand -Executable $GitExecutable -Arguments @("add", "--", $NotebookRelativePath) -FailureMessage "Unable to stage the Session 32 notebook."

    $StagedFiles = @(& $GitExecutable diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to list staged files."
    }

    Write-Host "Staged files:"
    $StagedFiles | ForEach-Object { Write-Host " $_" }

    $ExpectedGitPath = $NotebookRelativePath -replace "\\", "/"
    $UnexpectedStagedFiles = @($StagedFiles | Where-Object { $_ -ne $ExpectedGitPath })

    if ($UnexpectedStagedFiles.Count -gt 0) {
        throw @"
Unexpected files were staged. The automation stopped before committing.
Unexpected files:
$($UnexpectedStagedFiles -join "`n")
"@
    }

    # -----------------------------------------------------------------
    # 13. Commit the notebook when it changed
    # -----------------------------------------------------------------
    Write-Step "COMMITTING THE SESSION 32 DELIVERABLE"

    & $GitExecutable diff --cached --quiet -- $NotebookRelativePath
    $DiffExitCode = $LASTEXITCODE

    if ($DiffExitCode -eq 1) {
        Invoke-ExternalCommand -Executable $GitExecutable -Arguments @("commit", "-m", $CommitMessage) -FailureMessage "Git commit failed."
        Write-Host "Commit created successfully."
    }
    elseif ($DiffExitCode -eq 0) {
        Write-Host "The notebook already matches the committed version."
        Write-Host "No new commit was required."
    }
    else {
        throw "Unable to inspect the staged notebook changes."
    }

    # -----------------------------------------------------------------
    # 14. Push to GitHub
    # -----------------------------------------------------------------
    Write-Step "PUSHING THE CURRENT BRANCH TO GITHUB"

    & $GitExecutable push -u origin $CurrentBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Initial push did not succeed."
        Write-Host "Attempting pull --rebase --autostash and retry."

        Invoke-ExternalCommand -Executable $GitExecutable -Arguments @("pull", "--rebase", "--autostash", "origin", $CurrentBranch) -FailureMessage "Unable to rebase onto the remote branch."

        Invoke-ExternalCommand -Executable $GitExecutable -Arguments @("push", "-u", "origin", $CurrentBranch) -FailureMessage "GitHub push failed after the rebase."
    }

    # -----------------------------------------------------------------
    # 15. Verify local and remote commit hashes
    # -----------------------------------------------------------------
    Write-Step "VERIFYING THE GITHUB PUSH"

    $LocalCommit = (& $GitExecutable rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read the local commit hash."
    }

    $RemoteReference = @(& $GitExecutable ls-remote origin "refs/heads/$CurrentBranch")
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read the remote branch commit."
    }

    if ($RemoteReference.Count -eq 0) {
        throw "The remote branch was not found after the push."
    }

    $RemoteCommit = ($RemoteReference[0] -split "\s+")[0]

    Write-Host "Local commit:"
    Write-Host $LocalCommit
    Write-Host ""
    Write-Host "Remote commit:"
    Write-Host $RemoteCommit

    if ($LocalCommit -ne $RemoteCommit) {
        throw @"
The local and GitHub commit hashes do not match.
Local: $LocalCommit
Remote: $RemoteCommit
"@
    }

    # -----------------------------------------------------------------
    # 16. Final repository status
    # -----------------------------------------------------------------
    Write-Step "FINAL REPOSITORY STATUS"

    & $GitExecutable status --short
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to display the final Git status."
    }

    Write-Host ""
    Write-Host "Latest commit:"
    & $GitExecutable log -1 --oneline
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to display the latest commit."
    }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "SESSION 32 SECTION 8 COMPLETED SUCCESSFULLY"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "Notebook:"
    Write-Host $NotebookPath
    Write-Host ""
    Write-Host "Branch:"
    Write-Host $CurrentBranch
    Write-Host ""
    Write-Host "Verified GitHub commit:"
    Write-Host $RemoteCommit
    Write-Host ""
    Write-Host "GitHub remote:"
    Write-Host $OriginUrl
}
finally {
    Pop-Location
}
'@

# Save and run the script
$ScriptContent | Set-Content -LiteralPath $ScriptPath -Encoding UTF8 -Force

Write-Host "✅ Script saved to: $ScriptPath" -ForegroundColor Green
Write-Host ""

# Run it
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
& $ScriptPath