[CmdletBinding()]
param(
    [string]$ProjectPath = "C:\Users\yikib\student-performance-prediction-ml"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$BranchName = "session-34-decision-tree-classifier"
$CommitMessage = "Add Session 34 decision tree classifier"
$ScriptName = "08_session34_github_deliverable.ps1"

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

function Invoke-GitPush {
    param(
        [string]$BranchName
    )
    Write-Host "Attempting to push branch '$BranchName' to GitHub..."
    Write-Host ""
    
    # Check if remote exists
    $remoteUrl = git remote get-url origin 2>$null
    if (-not $remoteUrl) {
        throw "No remote 'origin' configured. Please run: git remote add origin <your-repo-url>"
    }
    
    Write-Host "Remote URL: $remoteUrl"
    Write-Host ""
    
    # Try to push with upstream
    Write-Host "Running: git push -u origin $BranchName"
    $pushOutput = git push -u origin $BranchName 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Push failed with error:"
        Write-Host $pushOutput -ForegroundColor Red
        Write-Host ""
        Write-Host "Possible solutions:"
        Write-Host "1. Make sure you have authentication set up:"
        Write-Host "   - For HTTPS: git config --global credential.helper cache"
        Write-Host "   - For SSH: Make sure your SSH key is added to GitHub"
        Write-Host ""
        Write-Host "2. Try pushing manually with:"
        Write-Host "   git push -u origin $BranchName"
        Write-Host ""
        Write-Host "3. If using HTTPS with personal access token:"
        Write-Host "   git remote set-url origin https://<username>:<token>@github.com/<username>/<repo>.git"
        Write-Host ""
        throw "Git push failed. Please fix authentication and try again."
    }
    
    Write-Host "Push successful!"
}

Write-Step "SESSION 34 GITHUB DELIVERABLE"
Write-Host "Project Path: $ProjectPath"
Write-Host "Branch: $BranchName"
Write-Host "Script: $ScriptName"

# ---------------------------------------------------------------------------
# 1. Validate the project folder
# ---------------------------------------------------------------------------
Write-Step "1. Validating the project repository"

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "The project directory does not exist: $ProjectPath"
}

Set-Location -LiteralPath $ProjectPath

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
# 2. Create and switch to the session branch
# ---------------------------------------------------------------------------
Write-Step "2. Creating and switching to branch: $BranchName"

# Check if branch exists locally
$LocalBranchExists = git branch --list $BranchName
if ($LocalBranchExists) {
    Write-Host "Branch $BranchName already exists locally. Switching to it..."
    git checkout $BranchName
    Assert-LastCommandSucceeded "Failed to checkout existing branch."
} else {
    Write-Host "Creating new branch: $BranchName"
    git checkout -b $BranchName
    Assert-LastCommandSucceeded "Failed to create and checkout new branch."
}

Write-Host "Current branch: $BranchName"

# ---------------------------------------------------------------------------
# 3. Locate the classification notebook
# ---------------------------------------------------------------------------
Write-Step "3. Locating 05_classification_models.ipynb"

$NotebookCandidates = @(
    (Join-Path $ProjectPath "05_classification_models.ipynb"),
    (Join-Path $ProjectPath "notebooks\05_classification_models.ipynb")
)

$NotebookPath = $null
foreach ($Candidate in $NotebookCandidates) {
    if (Test-Path -LiteralPath $Candidate) {
        $NotebookPath = $Candidate
        break
    }
}

if (-not $NotebookPath) {
    $FoundNotebook = Get-ChildItem -LiteralPath $ProjectPath -Filter "05_classification_models.ipynb" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($FoundNotebook) {
        $NotebookPath = $FoundNotebook.FullName
    }
}

if (-not $NotebookPath) {
    throw "05_classification_models.ipynb was not found"
}

$NotebookPath = (Resolve-Path -LiteralPath $NotebookPath).Path
$NotebookRelativePath = $NotebookPath.Substring($ProjectPath.Length + 1).Replace("\", "/")

Write-Host "Notebook found:"
Write-Host $NotebookPath

# ---------------------------------------------------------------------------
# 4. Back up the existing notebook
# ---------------------------------------------------------------------------
Write-Step "4. Creating a temporary notebook backup"

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupPath = Join-Path $env:TEMP "05_classification_models_before_session34_$Timestamp.ipynb"

Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force

Write-Host "Temporary backup:"
Write-Host $BackupPath

# ---------------------------------------------------------------------------
# 5. Select Python
# ---------------------------------------------------------------------------
Write-Step "5. Selecting the Python interpreter"

$VenvPython = Join-Path $ProjectPath ".venv\Scripts\python.exe"
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
# 6. Add Decision Tree to the notebook
# ---------------------------------------------------------------------------
Write-Step "6. Adding Decision Tree classifier to the notebook"

$UpdaterPath = Join-Path $env:TEMP "update_session34_notebook_$Timestamp.py"

# Create the Python script using an array to avoid quoting issues
$pythonLines = @(
'import json',
'import sys',
'import tempfile',
'from pathlib import Path',
'',
'if len(sys.argv) != 2:',
'    raise SystemExit("Usage: update_session34_notebook.py <notebook>")',
'',
'notebook_path = Path(sys.argv[1]).resolve()',
'if not notebook_path.exists():',
'    raise FileNotFoundError(f"Notebook not found: {notebook_path}")',
'',
'with open(notebook_path, "r", encoding="utf-8") as f:',
'    notebook = json.load(f)',
'',
'notebook.setdefault("nbformat", 4)',
'notebook.setdefault("nbformat_minor", 5)',
'notebook.setdefault("metadata", {})',
'notebook.setdefault("cells", [])',
'',
'SESSION_TAG = "session34-github-deliverable"',
'',
'def has_tag(cell):',
'    return SESSION_TAG in cell.get("metadata", {}).get("tags", [])',
'',
'# Remove old session34 cells',
'preserved_cells = [c for c in notebook["cells"] if not has_tag(c)]',
'',
'def markdown_cell(text):',
'    return {"cell_type": "markdown", "metadata": {"tags": [SESSION_TAG]}, "source": text.strip() + "\n"}',
'',
'def code_cell(text):',
'    source = text.strip() + "\n"',
'    compile(source, "<session34>", "exec")',
'    return {"cell_type": "code", "execution_count": None, "metadata": {"tags": [SESSION_TAG]}, "outputs": [], "source": source}',
'',
'# Create the new cells',
'new_cells = []',
'',
'# Markdown intro',
'new_cells.append(markdown_cell("""',
'## Session 34: Decision Tree Classifier',
'',
'This section adds a Decision Tree classifier with different depths.',
'"""))',
'',
'# Code cell 1 - Imports and validation',
'new_cells.append(code_cell("""',
'from sklearn.tree import DecisionTreeClassifier',
'import numpy as np',
'import pandas as pd',
'from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, roc_auc_score',
'',
'# Verify prerequisites',
'for obj in ["Xtr_f", "Xte_f", "yctr", "ycte"]:',
'    if obj not in globals():',
'        raise NameError(f"Missing required object: {obj}")',
'',
'print("Session 34 prerequisites verified")',
'print("Training shape:", Xtr_f.shape)',
'print("Test shape:", Xte_f.shape)',
'"""))',
'',
'# Code cell 2 - Evaluator function',
'new_cells.append(code_cell("""',
'def evaluate_classifier(y_true, y_pred, y_prob):',
'    return {',
'        "accuracy": accuracy_score(y_true, y_pred),',
'        "precision": precision_score(y_true, y_pred, zero_division=0),',
'        "recall": recall_score(y_true, y_pred, zero_division=0),',
'        "f1": f1_score(y_true, y_pred, zero_division=0),',
'        "roc_auc": roc_auc_score(y_true, y_prob) if len(np.unique(y_true)) == 2 else np.nan,',
'    }',
'print("Evaluator ready")',
'"""))',
'',
'# Code cell 3 - Train Decision Tree with different depths',
'new_cells.append(code_cell("""',
'# Train Decision Tree with different depths',
'depths = [3, 5, 7, 10, None]',
'results = []',
'',
'for depth in depths:',
'    dt = DecisionTreeClassifier(max_depth=depth, random_state=42)',
'    dt.fit(Xtr_f, yctr)',
'    predictions = dt.predict(Xte_f)',
'    probabilities = dt.predict_proba(Xte_f)[:, 1]',
'    metrics = evaluate_classifier(ycte, predictions, probabilities)',
'    results.append({',
'        "Model": f"DT_depth_{depth if depth else "None"}",',
'        "Max_Depth": depth,',
'        **metrics',
'    })',
'    print(f"DT depth {depth if depth else "None"} completed - F1: {metrics["f1"]:.4f}")',
'',
'results_df = pd.DataFrame(results).sort_values("f1", ascending=False).reset_index(drop=True)',
'print("\\nDecision Tree Results:")',
'print(results_df.to_string())',
'"""))',
'',
'# Code cell 4 - Save results',
'new_cells.append(code_cell("""',
'# Save results',
'from pathlib import Path',
'repo_root = next((d for d in [Path.cwd(), *Path.cwd().parents] if (d / ".git").exists()), Path.cwd())',
'output_dir = repo_root / "reports" / "tables"',
'output_dir.mkdir(parents=True, exist_ok=True)',
'',
'results_df.to_csv(output_dir / "session34_decision_tree_results.csv", index=False)',
'print("Results saved to:", output_dir / "session34_decision_tree_results.csv")',
'"""))',
'',
'# Markdown interpretation',
'new_cells.append(markdown_cell("""',
'### Session 34 Interpretation',
'',
'- **Decision Trees** split data based on feature values',
'- Different depths test the trade-off between interpretability and performance',
'- Shallower trees are more interpretable but may underfit',
'- Deeper trees capture complex patterns but risk overfitting',
'"""))',
'',
'# Update the notebook',
'notebook["cells"] = preserved_cells + new_cells',
'',
'# Write atomically',
'fd, tmp = tempfile.mkstemp(suffix=".ipynb", dir=str(notebook_path.parent))',
'import os',
'os.close(fd)',
'tmp_path = Path(tmp)',
'try:',
'    with open(tmp_path, "w", encoding="utf-8", newline="\n") as f:',
'        json.dump(notebook, f, indent=1, ensure_ascii=False)',
'        f.write("\n")',
'    tmp_path.replace(notebook_path)',
'finally:',
'    if tmp_path.exists():',
'        tmp_path.unlink()',
'',
'print(f"Updated notebook: {notebook_path}")',
'print(f"Added {len(new_cells)} Session 34 cells")'
)

# Write the Python script
$pythonLines | Out-File -FilePath $UpdaterPath -Encoding UTF8 -Force

Write-Host "Notebook updater created:"
Write-Host $UpdaterPath

# Run the Python script
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

tagged = [c for c in notebook.get("cells", []) if "session34-github-deliverable" in c.get("metadata", {}).get("tags", [])]

if len(tagged) < 5:
    raise AssertionError(f"Session 34 block incomplete. Found {len(tagged)} cells")

source = "".join("".join(c.get("source", [])) if isinstance(c.get("source", []), list) else str(c.get("source", "")) for c in tagged)

for term in ["DecisionTreeClassifier", "max_depth"]:
    if term not in source:
        raise AssertionError(f"Missing required content: {term}")

print(f"Validation passed. Found {len(tagged)} Session 34 cells")
"@

$ValidationPath = Join-Path $env:TEMP "validate_session34_notebook_$Timestamp.py"

Set-Content -LiteralPath $ValidationPath -Value $ValidationCode -Encoding UTF8

& $PythonCommand @PythonArguments $ValidationPath $NotebookPath
Assert-LastCommandSucceeded "Notebook validation failed."

# ---------------------------------------------------------------------------
# 8. Stage and commit
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

# ---------------------------------------------------------------------------
# 10. Push to GitHub
# ---------------------------------------------------------------------------
Write-Step "10. Pushing to GitHub"

# Call the push function with proper error handling
Invoke-GitPush -BranchName $BranchName

# ---------------------------------------------------------------------------
# 11. Final verification
# ---------------------------------------------------------------------------
Write-Step "11. Final verification"

Write-Host ("=" * 78)
Write-Host "SESSION 34 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY"
Write-Host ("=" * 78)
Write-Host "Notebook: $NotebookRelativePath"
Write-Host "Branch: $BranchName"
Write-Host "Decision Tree code: added"
Write-Host ""

# Show the remote branch URL
Write-Host "Remote branch URL:"
$OriginUrl = git remote get-url origin
$GitHubUrl = $OriginUrl -replace "\.git$", "" -replace "git@github\.com:", "https://github.com/"
Write-Host "$GitHubUrl/tree/$BranchName"

# Clean up
Remove-Item -LiteralPath $UpdaterPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ValidationPath -Force -ErrorAction SilentlyContinue