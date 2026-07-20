Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 78)
    Write-Host $Title
    Write-Host ('=' * 78)
}

function Write-TextFile {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    $dir = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        [System.IO.Directory]::CreateDirectory($dir) | Out-Null
    }

    $content = ($Lines -join [Environment]::NewLine) + [Environment]::NewLine
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

function Get-PythonCommand {
    if (Get-Command 'py' -ErrorAction SilentlyContinue) {
        return @('py', '-3')
    }
    if (Get-Command 'python' -ErrorAction SilentlyContinue) {
        return @('python')
    }
    if (Get-Command 'python3' -ErrorAction SilentlyContinue) {
        return @('python3')
    }
    throw 'Python was not found. Install Python 3.11+ and try again.'
}

function Invoke-Python {
    param(
        [string[]]$Command,
        [string[]]$Arguments
    )

    if ($Command[0] -eq 'py') {
        & py -3 @Arguments
    }
    else {
        & $Command[0] @Arguments
    }
}

Write-Section 'SESSION 22 — GITHUB DELIVERABLE AUTOMATION'
Write-Host 'Starting Session 22 automation...'

$RepoRoot = 'C:\Users\yikib\student-performance-prediction-ml'
Set-Location $RepoRoot
Write-Host "Repository root: $RepoRoot"

$IsWindows = ($env:OS -eq 'Windows_NT')
Write-Host "Windows host: $IsWindows"

$PythonCommand = Get-PythonCommand
Write-Host ('Using Python command: ' + ($PythonCommand -join ' '))

$SrcDir = Join-Path $RepoRoot 'src'
$TestsDir = Join-Path $RepoRoot 'tests'
$DocsDir = Join-Path $RepoRoot 'docs'

New-Item -ItemType Directory -Force -Path $SrcDir | Out-Null
New-Item -ItemType Directory -Force -Path $TestsDir | Out-Null
New-Item -ItemType Directory -Force -Path $DocsDir | Out-Null

$PreprocessPath = Join-Path $SrcDir 'preprocess.py'
$TestPath = Join-Path $TestsDir 'test_preprocess_session22.py'
$DocPath = Join-Path $DocsDir 'session22_train_test_split.md'

$PreprocessLines = @(
    'from __future__ import annotations',
    'from typing import TypedDict',
    'import pandas as pd',
    'from sklearn.model_selection import train_test_split',
    '',
    'class ScenarioSplit(TypedDict):',
    '    Xtr_f: pd.DataFrame',
    '    Xte_f: pd.DataFrame',
    '    Xtr_e: pd.DataFrame',
    '    Xte_e: pd.DataFrame',
    '    ytr: pd.Series',
    '    yte: pd.Series',
    '',
    'def _coerce_target_series(y: pd.Series | pd.DataFrame) -> pd.Series:',
    '    if isinstance(y, pd.Series):',
    '        return y.copy()',
    '    if isinstance(y, pd.DataFrame):',
    '        if y.shape[1] != 1:',
    '            raise ValueError("The target DataFrame must contain exactly one column.")',
    '        target = y.iloc[:, 0].copy()',
    '        if target.name is None:',
    '            target.name = y.columns[0]',
    '        return target',
    '    raise TypeError("y must be a pandas Series or a one-column pandas DataFrame.")',
    '',
    'def split_modeling_scenarios(',
    '    X_full: pd.DataFrame,',
    '    X_early: pd.DataFrame,',
    '    y: pd.Series | pd.DataFrame,',
    '    *,',
    '    test_size: float = 0.20,',
    '    random_state: int = 42,',
    ') -> ScenarioSplit:',
    '    if not isinstance(X_full, pd.DataFrame):',
    '        raise TypeError("X_full must be a pandas DataFrame.")',
    '    if not isinstance(X_early, pd.DataFrame):',
    '        raise TypeError("X_early must be a pandas DataFrame.")',
    '    if not 0.0 < test_size < 1.0:',
    '        raise ValueError("test_size must be strictly between 0 and 1.")',
    '    if not isinstance(random_state, int):',
    '        raise TypeError("random_state must be an integer.")',
    '',
    '    target = _coerce_target_series(y)',
    '',
    '    if not X_full.index.is_unique:',
    '        raise ValueError("X_full must have a unique row index.")',
    '    if not X_early.index.is_unique:',
    '        raise ValueError("X_early must have a unique row index.")',
    '    if not target.index.is_unique:',
    '        raise ValueError("The target must have a unique row index.")',
    '    if not X_full.index.equals(X_early.index):',
    '        raise ValueError("X_full and X_early must use the same row index in the same order.")',
    '    if not X_full.index.equals(target.index):',
    '        raise ValueError("The feature matrices and target must use the same row index.")',
    '',
    '    extra_early_columns = set(X_early.columns) - set(X_full.columns)',
    '    if extra_early_columns:',
    '        raise ValueError("X_early contains columns that are absent from X_full: " + str(sorted(extra_early_columns)))',
    '',
    '    if target.name is not None:',
    '        if target.name in X_full.columns:',
    '            raise ValueError(f"Target leakage detected: {target.name!r} is present in X_full.")',
    '        if target.name in X_early.columns:',
    '            raise ValueError(f"Target leakage detected: {target.name!r} is present in X_early.")',
    '',
    '    common_indices = X_full.index.to_numpy(copy=True)',
    '    train_indices, test_indices = train_test_split(',
    '        common_indices,',
    '        test_size=test_size,',
    '        random_state=random_state,',
    '        shuffle=True,',
    '    )',
    '',
    '    return {',
    '        "Xtr_f": X_full.loc[train_indices].copy(),',
    '        "Xte_f": X_full.loc[test_indices].copy(),',
    '        "Xtr_e": X_early.loc[train_indices].copy(),',
    '        "Xte_e": X_early.loc[test_indices].copy(),',
    '        "ytr": target.loc[train_indices].copy(),',
    '        "yte": target.loc[test_indices].copy(),',
    '    }'
)

$TestLines = @(
    'from __future__ import annotations',
    'import sys',
    'from pathlib import Path',
    'import pandas as pd',
    '',
    'PROJECT_ROOT = Path(__file__).resolve().parents[1]',
    'SRC_DIRECTORY = PROJECT_ROOT / "src"',
    'if str(SRC_DIRECTORY) not in sys.path:',
    '    sys.path.insert(0, str(SRC_DIRECTORY))',
    '',
    'from preprocess import split_modeling_scenarios',
    '',
    'def make_example_data():',
    '    index = pd.Index(range(100, 120), name="student_id")',
    '    X_full = pd.DataFrame(',
    '        {',
    '            "studytime": range(20),',
    '            "failures": [0, 1] * 10,',
    '            "G1": range(5, 25),',
    '            "G2": range(6, 26),',
    '        },',
    '        index=index,',
    '    )',
    '    X_early = X_full.drop(columns=["G1", "G2"]).copy()',
    '    y = pd.Series(range(7, 27), index=index, name="G3")',
    '    return X_full, X_early, y',
    '',
    'def test_split_is_reproducible():',
    '    X_full, X_early, y = make_example_data()',
    '    first = split_modeling_scenarios(X_full, X_early, y, random_state=42)',
    '    second = split_modeling_scenarios(X_full, X_early, y, random_state=42)',
    '    pd.testing.assert_frame_equal(first["Xtr_f"], second["Xtr_f"])',
    '    pd.testing.assert_frame_equal(first["Xte_f"], second["Xte_f"])',
    '    pd.testing.assert_frame_equal(first["Xtr_e"], second["Xtr_e"])',
    '    pd.testing.assert_frame_equal(first["Xte_e"], second["Xte_e"])',
    '    pd.testing.assert_series_equal(first["ytr"], second["ytr"])',
    '    pd.testing.assert_series_equal(first["yte"], second["yte"])',
    '',
    'def test_training_and_test_sets_do_not_overlap():',
    '    X_full, X_early, y = make_example_data()',
    '    split = split_modeling_scenarios(X_full, X_early, y, random_state=42)',
    '    training_indices = set(split["Xtr_f"].index)',
    '    test_indices = set(split["Xte_f"].index)',
    '    assert training_indices.isdisjoint(test_indices)',
    '    assert (training_indices | test_indices) == set(X_full.index)',
    '',
    'def test_split_uses_expected_80_20_row_counts():',
    '    X_full, X_early, y = make_example_data()',
    '    split = split_modeling_scenarios(X_full, X_early, y, test_size=0.20, random_state=42)',
    '    assert len(split["Xtr_f"]) == 16',
    '    assert len(split["Xtr_e"]) == 16',
    '    assert len(split["ytr"]) == 16',
    '    assert len(split["Xte_f"]) == 4',
    '    assert len(split["Xte_e"]) == 4',
    '    assert len(split["yte"]) == 4'
)

$DocLines = @(
    '# Session 22: Reproducible Train/Test Splitting',
    '',
    'This deliverable adds a reusable utility to src/preprocess.py.',
    'It creates comparable train/test splits for both modeling scenarios.'
)

Write-TextFile -Path $PreprocessPath -Lines $PreprocessLines
Write-TextFile -Path $TestPath -Lines $TestLines
Write-TextFile -Path $DocPath -Lines $DocLines

Write-Host "Created: $PreprocessPath"
Write-Host "Created: $TestPath"
Write-Host "Created: $DocPath"

Write-Section 'VALIDATING PYTHON FILES'

try {
    Invoke-Python -Command $PythonCommand -Arguments @('-m', 'py_compile', $PreprocessPath)
    Write-Host 'Python compilation passed.'
}
catch {
    Write-Host ('Python compilation failed: ' + $_.Exception.Message)
}

try {
    Invoke-Python -Command $PythonCommand -Arguments @('-m', 'pytest', $TestPath, '-q')
    Write-Host 'Pytest passed.'
}
catch {
    Write-Host ('Pytest failed: ' + $_.Exception.Message)
}

Write-Host ''
Write-Host 'Done.'