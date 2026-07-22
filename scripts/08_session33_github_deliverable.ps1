# First, delete the old script
Remove-Item "C:\Users\yikib\student-performance-prediction-ml\scripts\08_session33_github_deliverable.ps1" -Force -ErrorAction SilentlyContinue

# Create the new script using a different method
$scriptContent = @'
param(
    [string]$RepoPath = "C:\Users\yikib\student-performance-prediction-ml",
    [string]$CommitMessage = "Extend classification notebook with KNN SVM and Naive Bayes"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ("=" * 78)
    Write-Host $Message
    Write-Host ("=" * 78)
}

function Assert-LastCommandSucceeded {
    param([string]$FailureMessage)
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage Exit code: $LASTEXITCODE"
    }
}

function Invoke-GitPush {
    param([string]$BranchName)
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
    throw "05_classification_models.ipynb was not found"
}

$NotebookPath = (Resolve-Path -LiteralPath $NotebookPath).Path
# Manual relative path - works on all PowerShell versions
$NotebookRelativePath = $NotebookPath.Substring($RepoPath.Length + 1).Replace("\", "/")

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

$PythonUpdater = @"
import json
import sys
import tempfile
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("Usage: update_session33_notebook.py <notebook>")

notebook_path = Path(sys.argv[1]).resolve()
if not notebook_path.exists():
    raise FileNotFoundError(f"Notebook not found: {notebook_path}")

with open(notebook_path, "r", encoding="utf-8") as f:
    notebook = json.load(f)

notebook.setdefault("nbformat", 4)
notebook.setdefault("nbformat_minor", 5)
notebook.setdefault("metadata", {})
notebook.setdefault("cells", [])

SESSION_TAG = "session33-github-deliverable"

def has_tag(cell):
    return SESSION_TAG in cell.get("metadata", {}).get("tags", [])

# Remove old session33 cells
preserved_cells = [c for c in notebook["cells"] if not has_tag(c)]

def markdown_cell(text):
    return {"cell_type": "markdown", "metadata": {"tags": [SESSION_TAG]}, "source": text.strip() + "\n"}

def code_cell(text):
    source = text.strip() + "\n"
    compile(source, "<session33>", "exec")
    return {"cell_type": "code", "execution_count": None, "metadata": {"tags": [SESSION_TAG]}, "outputs": [], "source": source}

session33_cells = [
    markdown_cell("## Session 33: KNN, SVM, and Naive Bayes Classification"),
    
    code_cell("""
import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, roc_auc_score
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC

# Verify prerequisites
for obj in ["Xtr_f", "Xte_f", "yctr", "ycte"]:
    if obj not in globals():
        raise NameError(f"Missing required object: {obj}")

print("Session 33 prerequisites verified")
print("Training shape:", Xtr_f.shape)
print("Test shape:", Xte_f.shape)
"""),
    
    code_cell("""
def evaluate_classifier(y_true, y_pred, y_prob):
    return {
        "accuracy": accuracy_score(y_true, y_pred),
        "precision": precision_score(y_true, y_pred, zero_division=0),
        "recall": recall_score(y_true, y_pred, zero_division=0),
        "f1": f1_score(y_true, y_pred, zero_division=0),
        "roc_auc": roc_auc_score(y_true, y_prob) if len(np.unique(y_true)) == 2 else np.nan,
    }
print("Evaluator ready")
"""),
    
    code_cell("""
# Train KNN, SVM, and Gaussian Naive Bayes
results = []
for code, name, family, clf in [
    ("KNN", "K-Nearest Neighbors", "Instance-based", KNeighborsClassifier()),
    ("SVM", "Support Vector Machine", "Maximum-margin", SVC(probability=True, random_state=42)),
    ("NB", "Gaussian Naive Bayes", "Probabilistic", GaussianNB()),
]:
    pipeline = make_pipeline(StandardScaler(), clf)
    pipeline.fit(Xtr_f, yctr)
    predictions = pipeline.predict(Xte_f)
    probabilities = pipeline.predict_proba(Xte_f)[:, 1]
    metrics = evaluate_classifier(ycte, predictions, probabilities)
    results.append({
        "Model": code,
        "Full_Model_Name": name,
        "Model_Family": family,
        "Scaling_Used": True,
        **metrics
    })
    print(f"{code} completed - F1: {metrics['f1']:.4f}")

results_df = pd.DataFrame(results).sort_values("f1", ascending=False).reset_index(drop=True)
results_df.insert(0, "Session33_F1_Rank", range(1, len(results_df) + 1))

print("\nSession 33 Classification Results:")
print(results_df.to_string())
"""),
    
    code_cell("""
# Save results
from pathlib import Path
repo_root = next((d for d in [Path.cwd(), *Path.cwd().parents] if (d / ".git").exists()), Path.cwd())
output_dir = repo_root / "reports" / "tables"
output_dir.mkdir(parents=True, exist_ok=True)

results_df.to_csv(output_dir / "session33_classification_rows.csv", index=False)
print("Results saved to:", output_dir / "session33_classification_rows.csv")
"""),
    
    markdown_cell("""
### Session 33 Interpretation

- **KNN** assumes similar observations in scaled feature space share the same class
- **SVM** finds a maximum-margin decision boundary
- **Gaussian Naive Bayes** assumes conditional independence of predictors

Naive Bayes provides a useful baseline even though independence may not hold perfectly.
"""),
]

notebook["cells"] = preserved_cells + session33_cells

# Write atomically
fd, tmp = tempfile.mkstemp(suffix=".ipynb", dir=str(notebook_path.parent))
import os
os.close(fd)
tmp_path = Path(tmp)
try:
    with open(tmp_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(notebook, f, indent=1, ensure_ascii=False)
        f.write("\n")
    tmp_path.replace(notebook_path)
finally:
    if tmp_path.exists():
        tmp_path.unlink()

print(f"Updated notebook: {notebook_path}")
print(f"Added {len(session33_cells)} Session 33 cells")
"@

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
    throw "Python was not found"
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
    Write-Host "The notebook update failed. Restoring backup."
    Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
    throw
}

Write-Host "Notebook update completed."

# ---------------------------------------------------------------------------
# 7. Validate the notebook
# ---------------------------------------------------------------------------
Write-Step "7. Validating the updated notebook"

$ValidationCode = @"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
with open(path, "r", encoding="utf-8") as f:
    notebook = json.load(f)

tagged = [c for c in notebook.get("cells", []) if "session33-github-deliverable" in c.get("metadata", {}).get("tags", [])]

if len(tagged) < 5:
    raise AssertionError(f"Session 33 block incomplete. Found {len(tagged)} cells")

source = "".join("".join(c.get("source", [])) if isinstance(c.get("source", []), list) else str(c.get("source", "")) for c in tagged)

for term in ["KNeighborsClassifier", "SVC", "GaussianNB", "StandardScaler"]:
    if term not in source:
        raise AssertionError(f"Missing required content: {term}")

print(f"Validation passed. Found {len(tagged)} Session 33 cells")
"@

$ValidationPath = Join-Path $env:TEMP "validate_session33_notebook_$Timestamp.py"

Set-Content -LiteralPath $ValidationPath -Value $ValidationCode -Encoding UTF8

& $PythonCommand @PythonArguments $ValidationPath $NotebookPath
Assert-LastCommandSucceeded "Notebook validation failed."

# ---------------------------------------------------------------------------
# 8. Stage, commit, and push
# ---------------------------------------------------------------------------
Write-Step "8. Staging the notebook"

git add -- $NotebookRelativePath
Assert-LastCommandSucceeded "Git could not stage the notebook."

Write-Step "9. Committing the notebook"

git diff --cached --quiet -- $NotebookRelativePath
if ($LASTEXITCODE -eq 1) {
    git commit -m $CommitMessage -- $NotebookRelativePath
    Assert-LastCommandSucceeded "Git commit failed."
    Write-Host "Committed successfully"
} else {
    Write-Host "No changes to commit"
}

Write-Step "10. Pushing to GitHub"

$CurrentBranch = (git branch --show-current).Trim()
Assert-LastCommandSucceeded "Unable to determine the current Git branch."

if ([string]::IsNullOrWhiteSpace($CurrentBranch)) {
    throw "Repository is in detached-HEAD mode."
}

Invoke-GitPush -BranchName $CurrentBranch

# ---------------------------------------------------------------------------
# 11. Final verification
# ---------------------------------------------------------------------------
Write-Step "11. Final verification"

Write-Host ("=" * 78)
Write-Host "SESSION 33 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY"
Write-Host ("=" * 78)
Write-Host "Notebook: $NotebookRelativePath"
Write-Host "Branch: $CurrentBranch"
Write-Host "KNN code: added"
Write-Host "SVM code: added"
Write-Host "Gaussian Naive Bayes code: added"

# Clean up
Remove-Item -LiteralPath $UpdaterPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ValidationPath -Force -ErrorAction SilentlyContinue
'@

# Write the script to file
$scriptContent | Out-File -FilePath "C:\Users\yikib\student-performance-prediction-ml\scripts\08_session33_github_deliverable.ps1" -Encoding UTF8 -Force

Write-Host "Script created successfully!" -ForegroundColor Green
Write-Host "Now run: cd C:\Users\yikib\student-performance-prediction-ml\scripts ; .\08_session33_github_deliverable.ps1" -ForegroundColor Yellow