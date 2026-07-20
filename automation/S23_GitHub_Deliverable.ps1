[CmdletBinding()]
param(
[string]$ProjectRoot = "C:\Users\yikib\student-performance-prediction-ml",
[string]$CommitMessage = "Add reusable regression evaluation metrics"
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function Write-Step {
param(
[Parameter(Mandatory = $true)]
[string]$Message
)
Write-Host ""
Write-Host "============================================================"
Write-Host $Message
Write-Host "============================================================"
}
function Invoke-ProjectPython {
param(
[Parameter(Mandatory = $true)]
[string]$ScriptPath,
[string[]]$ScriptArguments = @()
)
if ($script:PythonKind -eq "venv") {
& $script:PythonCommand $ScriptPath @ScriptArguments
}
elseif ($script:PythonKind -eq "py") {
& py -3 $ScriptPath @ScriptArguments
}
else {
& python $ScriptPath @ScriptArguments
}
if ($LASTEXITCODE -ne 0) {
throw "Python validation failed with exit code $LASTEXITCODE."
}
}
Write-Step "Session 23 GitHub Deliverable"
Write-Host "Project root:"

 Write-Host $ProjectRoot
# ------------------------------------------------------------
# 1. Validate the repository location
# ------------------------------------------------------------
Write-Step "1. Validate the local repository"
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
throw "The project directory does not exist: $ProjectRoot"
}
Set-Location -LiteralPath $ProjectRoot
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
throw "Git is not installed or is not available in PATH."
}
$RepositoryCheck = & git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $RepositoryCheck -ne "true") {
throw "The selected project directory is not a Git repository."
}
Write-Host "Git repository confirmed."
$Branch = (& git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($Branch)) {
throw "The repository is in detached-HEAD mode. Check out a branch before
continuing."
}
Write-Host "Current branch: $Branch"
$RemoteUrl = (& git remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RemoteUrl)) {
throw "The repository does not have an 'origin' remote."
}
$RemoteUrl = $RemoteUrl.Trim()
Write-Host "Remote origin: $RemoteUrl"
# ------------------------------------------------------------
# 2. Prevent unrelated staged files from entering the commit
# ------------------------------------------------------------
Write-Step "2. Check for existing staged changes"
$PreviouslyStaged = @(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) {
throw "Git could not inspect the staging area."
}
if ($PreviouslyStaged.Count -gt 0) {
Write-Host "The following files are already staged:"
$PreviouslyStaged | ForEach-Object {

 Write-Host " $_"
}
throw @"
Existing staged changes were detected.
To avoid committing unrelated work, unstage those files first:
git restore --staged .
Then rerun this automation.
"@
}
Write-Host "No unrelated staged changes were found."
# ------------------------------------------------------------
# 3. Select a Python interpreter
# ------------------------------------------------------------
Write-Step "3. Select the Python interpreter"
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (Test-Path -LiteralPath $VenvPython -PathType Leaf) {
$script:PythonKind = "venv"
$script:PythonCommand = $VenvPython
Write-Host "Using project virtual environment:"
Write-Host $VenvPython
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
$script:PythonKind = "py"
$script:PythonCommand = "py"
Write-Host "Using the Windows Python launcher: py -3"
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
$script:PythonKind = "python"
$script:PythonCommand = "python"
Write-Host "Using Python from PATH."
}
else {
throw "No Python interpreter was found."
}
# ------------------------------------------------------------
# 4. Create src/evaluate_models.py
# ------------------------------------------------------------
Write-Step "4. Create src/evaluate_models.py"
$SrcDirectory = Join-Path $ProjectRoot "src"
$EvaluationFile = Join-Path $SrcDirectory "evaluate_models.py"
$RelativeEvaluationFile = "src/evaluate_models.py"
New-Item `
-ItemType Directory `
-Path $SrcDirectory `
-Force | Out-Null
$ExistingFile = Test-Path -LiteralPath $EvaluationFile -PathType Leaf

 $BackupFile = $null
if ($ExistingFile) {
$BackupFile = Join-Path `
$env:TEMP `
("evaluate_models_S23_backup_{0}.py" -f [guid]::NewGuid().ToString("N"))
Copy-Item `
-LiteralPath $EvaluationFile `
-Destination $BackupFile `
-Force
Write-Host "An existing evaluate_models.py file was backed up to:"
Write-Host $BackupFile
}
$PythonSource = @'
"""Reusable evaluation helpers for regression models."""
from typing import Dict, Sequence, Union
import numpy as np
from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)

ArrayLike1D = Union[Sequence[float], np.ndarray]

def eval_reg(
    y_true: ArrayLike1D,
    y_pred: ArrayLike1D,
) -> Dict[str, float]:
    """
    Calculate standard regression evaluation metrics.

    Parameters
    ----------
    y_true
        Actual observed target values.
    y_pred
        Predicted target values produced by a regression model.

    Returns
    -------
    dict
        Dictionary containing:
        - ``MAE``: Mean Absolute Error
        - ``RMSE``: Root Mean Squared Error
        - ``R2``: R-squared score

    Raises
    ------
    ValueError
        If the inputs are not one-dimensional, are empty, have different
        lengths, contain fewer than two observations, or contain non-finite
        values.
    """
    true_values = np.asarray(y_true, dtype=float)
    predicted_values = np.asarray(y_pred, dtype=float)

    if true_values.ndim != 1 or predicted_values.ndim != 1:
        raise ValueError("y_true and y_pred must be one-dimensional.")

    if true_values.size == 0 or predicted_values.size == 0:
        raise ValueError("y_true and y_pred cannot be empty.")

    if true_values.size != predicted_values.size:
        raise ValueError(
            "y_true and y_pred must contain the same number of values."
        )

    if true_values.size < 2:
        raise ValueError(
            "At least two observations are required to calculate R2."
        )

    if not np.all(np.isfinite(true_values)):
        raise ValueError(
            "y_true contains missing or infinite values."
        )

    if not np.all(np.isfinite(predicted_values)):
        raise ValueError(
            "y_pred contains missing or infinite values."
        )

    mse = mean_squared_error(
        true_values,
        predicted_values,
    )

    return {
        "MAE": float(
            mean_absolute_error(
                true_values,
                predicted_values,
            )
        ),
        "RMSE": float(np.sqrt(mse)),
        "R2": float(
            r2_score(
                true_values,
                predicted_values,
            )
        ),
    }
'@
$Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
$EvaluationFile,
$PythonSource,

 $Utf8WithoutBom
)
if (-not (Test-Path -LiteralPath $EvaluationFile -PathType Leaf)) {
throw "The evaluation utility was not created."
}
Write-Host "Created:"
Write-Host $EvaluationFile
# ------------------------------------------------------------
# 5. Validate the Python utility
# ------------------------------------------------------------
Write-Step "5. Validate the evaluation utility"
$SmokeTestFile = Join-Path `
$env:TEMP `
("session23_evaluation_test_{0}.py" -f [guid]::NewGuid().ToString("N"))
$SmokeTestSource = @'
"""Temporary validation script for Session 23."""
import importlib.util
import pathlib
import sys
import numpy as np

module_path = pathlib.Path(sys.argv[1]).resolve()
if not module_path.exists():
    raise FileNotFoundError(module_path)

spec = importlib.util.spec_from_file_location(
    "evaluate_models",
    module_path,
)
if spec is None or spec.loader is None:
    raise ImportError(
        f"Could not load the module from {module_path}"
    )
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

results = module.eval_reg(
    [1, 2, 3, 4],
    [1, 2, 3, 5],
)

assert np.isclose(results["MAE"], 0.25), results
assert np.isclose(results["RMSE"], 0.50), results
assert np.isclose(results["R2"], 0.80), results

perfect_results = module.eval_reg(
    [1, 2, 3, 4],
    [1, 2, 3, 4],
)
assert np.isclose(perfect_results["MAE"], 0.0)
assert np.isclose(perfect_results["RMSE"], 0.0)
assert np.isclose(perfect_results["R2"], 1.0)

mismatch_rejected = False
try:
    module.eval_reg(
        [1, 2, 3],
        [1, 2],
    )
except ValueError:
    mismatch_rejected = True
assert mismatch_rejected, (
    "The function did not reject inputs with different lengths."
)

print("Session 23 regression utility validation passed.")
print(f"MAE: {results['MAE']:.2f}")
print(f"RMSE: {results['RMSE']:.2f}")
print(f"R2: {results['R2']:.2f}")
'@
[System.IO.File]::WriteAllText(
$SmokeTestFile,
$SmokeTestSource,
$Utf8WithoutBom
)
try {
Invoke-ProjectPython `
-ScriptPath $SmokeTestFile `
-ScriptArguments @($EvaluationFile)
}
catch {
Write-Host ""
Write-Host "The new utility did not pass validation."
if ($ExistingFile -and $BackupFile) {
Copy-Item `
-LiteralPath $BackupFile `
-Destination $EvaluationFile `
-Force
Write-Host "The original evaluate_models.py file was restored."
}
elseif (Test-Path -LiteralPath $EvaluationFile) {
Remove-Item `
-LiteralPath $EvaluationFile `
-Force
Write-Host "The invalid new file was removed."
}
throw
}
finally {

 if (Test-Path -LiteralPath $SmokeTestFile) {
Remove-Item `
-LiteralPath $SmokeTestFile `
-Force
}
}
Write-Host "The utility passed all validation checks."
# ------------------------------------------------------------
# 6. Review the exact Git change
# ------------------------------------------------------------
Write-Step "6. Review the Git difference"
& git --no-pager diff -- $RelativeEvaluationFile
if ($LASTEXITCODE -ne 0) {
throw "Git could not display the file difference."
}
# ------------------------------------------------------------
# 7. Stage only the required deliverable
# ------------------------------------------------------------
Write-Step "7. Stage the required deliverable"
& git add -- $RelativeEvaluationFile
if ($LASTEXITCODE -ne 0) {
throw "Git could not stage $RelativeEvaluationFile."
}
Write-Host "Staged file:"
Write-Host $RelativeEvaluationFile
Write-Host ""
Write-Host "Staged difference:"
& git --no-pager diff --cached -- $RelativeEvaluationFile
if ($LASTEXITCODE -ne 0) {
throw "Git could not display the staged difference."
}
& git diff --cached --check
if ($LASTEXITCODE -ne 0) {
throw "Git detected whitespace or formatting problems."
}
# ------------------------------------------------------------
# 8. Commit the file
# ------------------------------------------------------------
Write-Step "8. Commit the regression metric helper"
& git diff --cached --quiet
$StagedDifferenceExitCode = $LASTEXITCODE

 if ($StagedDifferenceExitCode -eq 0) {
Write-Host "No new file difference was detected."
Write-Host "The required utility may already be committed."
}
elseif ($StagedDifferenceExitCode -eq 1) {
$GitUserName = (& git config user.name).Trim()
$GitUserEmail = (& git config user.email).Trim()
if (
[string]::IsNullOrWhiteSpace($GitUserName) -or
[string]::IsNullOrWhiteSpace($GitUserEmail)
) {
throw @"
Git user identity is not configured.
Configure it with:
git config --global user.name "Yousef Nejatbakhsh"
git config --global user.email "YOUR_GITHUB_EMAIL"
Then rerun this automation.
"@
}
& git commit -m $CommitMessage
if ($LASTEXITCODE -ne 0) {
throw "Git could not create the commit."
}
Write-Host "Commit created successfully."
}
else {
throw "Git could not inspect the staged difference."
}
# ------------------------------------------------------------
# 9. Push the current branch
# ------------------------------------------------------------
Write-Step "9. Push the commit to GitHub"
& git push -u origin $Branch
if ($LASTEXITCODE -ne 0) {
throw @"
The local work is valid, but Git could not push the branch.
Review the Git authentication or remote-branch message shown above.
"@
}
Write-Host "Push completed successfully."
# ------------------------------------------------------------
# 10. Final verification
# ------------------------------------------------------------
Write-Step "10. Final verification"

 Write-Host "Repository status:"
& git status --short
Write-Host ""
Write-Host "Latest commit:"
& git --no-pager log -1 --oneline
Write-Host ""
Write-Host "Latest commit contents:"
& git --no-pager show `
--stat `
--oneline `
--summary `
HEAD
Write-Host ""
Write-Host "Remote:"
Write-Host $RemoteUrl
if ($BackupFile -and (Test-Path -LiteralPath $BackupFile)) {
Remove-Item `
-LiteralPath $BackupFile `
-Force
}
Write-Step "Session 23 GitHub deliverable completed"
Write-Host "Required file:"
Write-Host " src/evaluate_models.py"
Write-Host ""
Write-Host "Branch:"
Write-Host " $Branch"
Write-Host ""
Write-Host "Commit message:"
Write-Host " $CommitMessage"