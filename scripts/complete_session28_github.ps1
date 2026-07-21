[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Users\yikib\student-performance-prediction-ml"
$CommitMessage = "Add Session 28 Random Forest regression results"

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Require-Command {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found."
    }
}

Write-Step "SESSION 28: VERIFYING PROJECT"

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "Project folder was not found: $ProjectRoot"
}
Set-Location -LiteralPath $ProjectRoot
Require-Command -Name "git"

$InsideRepository = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $InsideRepository.Trim() -ne "true") {
    throw "This folder is not a Git repository: $ProjectRoot"
}

$OriginUrl = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($OriginUrl)) {
    throw "The repository does not have an 'origin' remote."
}

$Branch = git branch --show-current
if ([string]::IsNullOrWhiteSpace($Branch)) {
    throw "The repository is in detached-HEAD mode."
}

Write-Host "Project root : $ProjectRoot"
Write-Host "Git branch : $Branch"
Write-Host "Origin : $OriginUrl"

Write-Step "SELECTING PYTHON"
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (Test-Path -LiteralPath $VenvPython) {
    $PythonExecutable = $VenvPython
    $PythonBaseArguments = @()
}
elseif (Get-Command "py" -ErrorAction SilentlyContinue) {
    $PythonExecutable = (Get-Command "py").Source
    $PythonBaseArguments = @("-3")
}
elseif (Get-Command "python" -ErrorAction SilentlyContinue) {
    $PythonExecutable = (Get-Command "python").Source
    $PythonBaseArguments = @()
}
else {
    throw "Python 3 was not found."
}

$PythonVersion = & $PythonExecutable @PythonBaseArguments --version
if ($LASTEXITCODE -ne 0) {
    throw "Python could not be started."
}
Write-Host "Python : $PythonVersion"
Write-Host "Executable : $PythonExecutable"

Write-Step "LOCATING THE REGRESSION NOTEBOOK"
$ExcludedPathPattern = "\\(\.git|\.venv|venv|node_modules|\.ipynb_checkpoints|archive|archives|backup|backups)\\"
$NotebookCandidates = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Filter "*.ipynb" |
    Where-Object { $_.FullName -notmatch $ExcludedPathPattern }

$ScoredCandidates = foreach ($Notebook in $NotebookCandidates) {
    $BaseName = $Notebook.BaseName.ToLowerInvariant()
    $FullName = $Notebook.FullName.ToLowerInvariant()
    $Score = 0
    if ($BaseName -eq "regression_model_comparison") { $Score += 200 }
    if ($BaseName -match "regression") { $Score += 100 }
    if ($BaseName -match "model.*comparison|comparison.*model") { $Score += 60 }
    if ($BaseName -match "week.?3") { $Score += 30 }
    if ($BaseName -match "student.*performance") { $Score += 20 }
    if ($BaseName -match "model") { $Score += 10 }
    if ($FullName -match "\\notebooks\\") { $Score += 20 }
    [PSCustomObject]@{
        Path = $Notebook.FullName
        Name = $Notebook.Name
        Score = $Score
        Modified = $Notebook.LastWriteTime
    }
}

$SelectedCandidate = $ScoredCandidates |
    Where-Object { $_.Score -gt 0 } |
    Sort-Object -Property @{ Expression = "Score"; Descending = $true }, @{ Expression = "Modified"; Descending = $true } |
    Select-Object -First 1

if ($null -ne $SelectedCandidate) {
    $NotebookPath = $SelectedCandidate.Path
    Write-Host "Selected existing notebook:"
    Write-Host $NotebookPath
    Write-Host "Selection score: $($SelectedCandidate.Score)"
}
else {
    $NotebookDirectory = Join-Path $ProjectRoot "notebooks"
    New-Item -ItemType Directory -Force -Path $NotebookDirectory | Out-Null
    $NotebookPath = Join-Path $NotebookDirectory "regression_model_comparison.ipynb"
    Write-Host "No suitable regression notebook was found."
    Write-Host "A canonical notebook will be created:"
    Write-Host $NotebookPath
}

Write-Step "CREATING A NOTEBOOK BACKUP"
if (Test-Path -LiteralPath $NotebookPath) {
    $BackupDirectory = Join-Path $ProjectRoot ".git\session28_backups"
    New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupName = "{0}.session28_backup_{1}.ipynb" -f [System.IO.Path]::GetFileNameWithoutExtension($NotebookPath), $Timestamp
    $BackupPath = Join-Path $BackupDirectory $BackupName
    Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force
    Write-Host "Backup created:"
    Write-Host $BackupPath
}
else {
    Write-Host "The notebook is new; no backup was necessary."
}

Write-Host "Session 28 setup completed!"
Write-Host "Notebook path: $NotebookPath"

Write-Step "CREATING SESSION 28 EVIDENCE"
$EvidenceDirectory = Join-Path $ProjectRoot "reports\evidence"
New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
$EvidencePath = Join-Path $EvidenceDirectory "session28_github_deliverable.txt"

$RelativeNotebook = (Resolve-Path -LiteralPath $NotebookPath -Relative) -replace "^[.][\\/]", ""
$RelativeAutomation = (Resolve-Path -LiteralPath $PSCommandPath -Relative) -replace "^[.][\\/]", ""

$EvidenceContent = @"
GSSRP 2026 — Session 28 GitHub Deliverable
==========================================
Completed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Project: $ProjectRoot
Branch: $Branch
Remote: $OriginUrl
Regression notebook: $RelativeNotebook
Automation: $RelativeAutomation
"@

Set-Content -LiteralPath $EvidencePath -Value $EvidenceContent -Encoding UTF8
Write-Host "Evidence file created:"
Write-Host $EvidencePath

Write-Step "REVIEWING GIT CHANGES"
$RelativeEvidence = (Resolve-Path -LiteralPath $EvidencePath -Relative) -replace "^[.][\\/]", ""
git status --short

Write-Host ""
Write-Host "Files that will be staged:"
Write-Host " $RelativeNotebook"
Write-Host " $RelativeAutomation"
Write-Host " $RelativeEvidence"

Write-Step "STAGING SESSION 28 FILES"
git add -- $RelativeNotebook $RelativeAutomation $RelativeEvidence
if ($LASTEXITCODE -ne 0) {
    throw "Git staging failed."
}

git diff --cached --stat
git diff --cached --check
if ($LASTEXITCODE -ne 0) {
    throw "Git detected whitespace or patch-format errors."
}

Write-Step "COMMITTING SESSION 28"
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "No new staged changes were found."
    Write-Host "The Session 28 deliverable may already be committed."
}
else {
    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed."
    }
    Write-Host "Commit created successfully."
}

Write-Step "SYNCHRONIZING WITH GITHUB"
git ls-remote --exit-code --heads origin $Branch *> $null
$RemoteBranchExists = ($LASTEXITCODE -eq 0)

if ($RemoteBranchExists) {
    Write-Host "Remote branch exists. Pulling with rebase and autostash."
    git pull --rebase --autostash origin $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "Git pull --rebase failed. Resolve the conflict before pushing."
    }
}
else {
    Write-Host "Remote branch does not yet exist. Initial push will create it."
}

Write-Step "PUSHING SESSION 28 TO GITHUB"
git push -u origin $Branch
if ($LASTEXITCODE -ne 0) {
    throw "Git push failed."
}

Write-Step "FINAL VERIFICATION"
$LatestCommit = git log -1 --pretty=format:"%h | %ad | %s" --date=iso
Write-Host "Latest commit:"
Write-Host $LatestCommit
Write-Host ""
Write-Host "Repository status:"
git status --short
Write-Host ""
Write-Host "Session 28 notebook:"
Write-Host $RelativeNotebook
Write-Host ""
Write-Host "Evidence file:"
Write-Host $RelativeEvidence
Write-Host ""
Write-Host "============================================================"
Write-Host "SESSION 28 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY"
Write-Host "============================================================"
