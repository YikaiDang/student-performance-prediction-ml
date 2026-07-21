$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================================
# Session 27 GitHub Deliverable
# Implements and evaluates random forest regression
# Creates: notebooks/05_random_forest_regression.ipynb
# ============================================================

$RepoRoot = "C:\Users\yikib\student-performance-prediction-ml"
$NotebookDirectory = Join-Path $RepoRoot "notebooks"
$NotebookPath = Join-Path $NotebookDirectory "05_random_forest_regression.ipynb"
$RelativeNotebookPath = "notebooks/05_random_forest_regression.ipynb"

Write-Host ""
Write-Host "============================================================"
Write-Host " SESSION 27: GITHUB DELIVERABLE AUTOMATION"
Write-Host "============================================================"
Write-Host ""

# ------------------------------------------------------------
# 1. Validate the repository path
# ------------------------------------------------------------
if (-not (Test-Path -LiteralPath $RepoRoot)) {
    throw "Repository folder not found: $RepoRoot"
}
Set-Location -LiteralPath $RepoRoot
Write-Host "[1/8] Repository located:"
Write-Host " $RepoRoot"

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot ".git"))) {
    throw "This folder is not a Git repository: $RepoRoot"
}

# ------------------------------------------------------------
# 2. Check Git
# ------------------------------------------------------------
$GitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $GitCommand) {
    throw "Git is not installed or is not available in PATH."
}
Write-Host "[2/8] Git is available:"
git --version

# ------------------------------------------------------------
# 3. Resolve the Python interpreter
# ------------------------------------------------------------
$VenvPython = Join-Path $RepoRoot ".venv\Scripts\python.exe"
$PythonExe = $null

if (Test-Path -LiteralPath $VenvPython) {
    $PythonExe = $VenvPython
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonExe = (Get-Command python).Source
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonExe = (Get-Command py).Source
}
else {
    throw "Python was not found. Create or activate the project virtual environment first."
}

Write-Host "[3/8] Python interpreter:"
Write-Host " $PythonExe"
& $PythonExe --version

# ------------------------------------------------------------
# 4. Create the notebooks directory
# ------------------------------------------------------------
New-Item -ItemType Directory -Path $NotebookDirectory -Force | Out-Null
Write-Host "[4/8] Notebook directory ready:"
Write-Host " $NotebookDirectory"

# ------------------------------------------------------------
# 5. Create the Random Forest notebook
# ------------------------------------------------------------
Write-Host "[5/8] Creating Random Forest regression notebook..."

$NotebookContent = @'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Session 27: Random Forest Regression\\n",
    "**Week 4 — Ensemble Regression Baseline**\\n",
    "\\n",
    "This notebook trains and evaluates a Random Forest regressor.\\n",
    "\\n",
    "The model uses the same full-information training and test split.\\n",
    "\\n",
    "Test performance is measured using:\\n",
    "- Mean Absolute Error (MAE)\\n",
    "- Root Mean Squared Error (RMSE)\\n",
    "- R-squared\\n",
    "\\n",
    "The primary model-ranking metric is RMSE. Lower RMSE indicates\\n",
    "smaller prediction errors."
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 1. Imports and Project Paths"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "from pathlib import Path\\n",
    "import pickle\\n",
    "import warnings\\n",
    "import numpy as np\\n",
    "import pandas as pd\\n",
    "import matplotlib.pyplot as plt\\n",
    "from IPython.display import display\\n",
    "from sklearn.ensemble import RandomForestRegressor\\n",
    "from sklearn.metrics import (\\n",
    "    mean_absolute_error,\\n",
    "    mean_squared_error,\\n",
    "    r2_score,\\n",
    ")\\n",
    "from sklearn.model_selection import train_test_split\\n",
    "\\n",
    "RANDOM_STATE = 42\\n",
    "TEST_SIZE = 0.20\\n",
    "\\n",
    "def find_project_root(start: Path | None = None) -> Path:\\n",
    "    start = (start or Path.cwd()).resolve()\\n",
    "    for candidate in [start, *start.parents]:\\n",
    "        if (candidate / \".git\").exists():\\n",
    "            return candidate\\n",
    "    return start\\n",
    "\\n",
    "PROJECT_ROOT = find_project_root()\\n",
    "DATA_DIRECTORY = PROJECT_ROOT / \"data\"\\n",
    "PROCESSED_DIRECTORY = DATA_DIRECTORY / \"processed\"\\n",
    "REPORTS_DIRECTORY = PROJECT_ROOT / \"reports\"\\n",
    "TABLES_DIRECTORY = REPORTS_DIRECTORY / \"tables\"\\n",
    "TABLES_DIRECTORY.mkdir(parents=True, exist_ok=True)\\n",
    "\\n",
    "print(\"Project root:\", PROJECT_ROOT)\\n",
    "print(\"Processed-data directory:\", PROCESSED_DIRECTORY)\\n",
    "print(\"Output-table directory:\", TABLES_DIRECTORY)"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 2. Load the Shared Full-Information Train/Test Split"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "REQUIRED_SPLIT_KEYS = {\\n",
    "    \"Xtr_f\",\\n",
    "    \"Xte_f\",\\n",
    "    \"ytr\",\\n",
    "    \"yte\",\\n",
    "}\\n",
    "\\n",
    "def _as_feature_frame(values, prefix: str = \"feature\") -> pd.DataFrame:\\n",
    "    if isinstance(values, pd.DataFrame):\\n",
    "        return values.reset_index(drop=True).copy()\\n",
    "    array = np.asarray(values)\\n",
    "    if array.ndim != 2:\\n",
    "        raise ValueError(\\n",
    "            f\"Expected a two-dimensional feature matrix; received shape {array.shape}.\"\\n",
    "        )\\n",
    "    columns = [\\n",
    "        f\"{prefix}_{index:03d}\"\\n",
    "        for index in range(array.shape[1])\\n",
    "    ]\\n",
    "    return pd.DataFrame(array, columns=columns)\\n",
    "\\n",
    "def _as_target_series(values) -> pd.Series:\\n",
    "    if isinstance(values, pd.Series):\\n",
    "        return values.reset_index(drop=True).copy()\\n",
    "    if isinstance(values, pd.DataFrame):\\n",
    "        if values.shape[1] != 1:\\n",
    "            raise ValueError(\\n",
    "                \"The target DataFrame must have exactly one column.\"\\n",
    "            )\\n",
    "        return values.iloc[:, 0].reset_index(drop=True)\\n",
    "    array = np.asarray(values).reshape(-1)\\n",
    "    return pd.Series(array, name=\"G3\")\\n",
    "\\n",
    "def _normalize_split(values: dict):\\n",
    "    Xtr_f = _as_feature_frame(values[\"Xtr_f\"])\\n",
    "    Xte_f = _as_feature_frame(values[\"Xte_f\"])\\n",
    "    ytr = _as_target_series(values[\"ytr\"])\\n",
    "    yte = _as_target_series(values[\"yte\"])\\n",
    "\\n",
    "    if Xtr_f.shape[1] != Xte_f.shape[1]:\\n",
    "        raise ValueError(\\n",
    "            \"Training and test feature matrices have different numbers of columns.\"\\n",
    "        )\\n",
    "    if Xtr_f.shape[0] != len(ytr):\\n",
    "        raise ValueError(\\n",
    "            \"Training feature and target row counts differ.\"\\n",
    "        )\\n",
    "    if Xte_f.shape[0] != len(yte):\\n",
    "        raise ValueError(\\n",
    "            \"Test feature and target row counts differ.\"\\n",
    "        )\\n",
    "\\n",
    "    Xte_f.columns = Xtr_f.columns\\n",
    "    return Xtr_f, Xte_f, ytr, yte\\n",
    "\\n",
    "def load_split_from_npz():\\n",
    "    if not DATA_DIRECTORY.exists():\\n",
    "        return None\\n",
    "    for path in sorted(DATA_DIRECTORY.rglob(\"*.npz\")):\\n",
    "        try:\\n",
    "            with np.load(path, allow_pickle=True) as archive:\\n",
    "                if REQUIRED_SPLIT_KEYS.issubset(archive.files):\\n",
    "                    values = {\\n",
    "                        key: archive[key]\\n",
    "                        for key in REQUIRED_SPLIT_KEYS\\n",
    "                    }\\n",
    "                    print(\"Loaded train/test split from:\", path)\\n",
    "                    return _normalize_split(values)\\n",
    "        except Exception:\\n",
    "            continue\\n",
    "    return None\\n",
    "\\n",
    "def load_split_from_pickle():\\n",
    "    if not DATA_DIRECTORY.exists():\\n",
    "        return None\\n",
    "    pickle_paths = [\\n",
    "        *DATA_DIRECTORY.rglob(\"*.pkl\"),\\n",
    "        *DATA_DIRECTORY.rglob(\"*.pickle\"),\\n",
    "    ]\\n",
    "    for path in sorted(pickle_paths):\\n",
    "        try:\\n",
    "            with path.open(\"rb\") as file:\\n",
    "                values = pickle.load(file)\\n",
    "                if (\\n",
    "                    isinstance(values, dict)\\n",
    "                    and REQUIRED_SPLIT_KEYS.issubset(values)\\n",
    "                ):\\n",
    "                    print(\"Loaded train/test split from:\", path)\\n",
    "                    return _normalize_split(values)\\n",
    "        except Exception:\\n",
    "            continue\\n",
    "    return None\\n",
    "\\n",
    "def _read_array_file(path: Path):\\n",
    "    suffix = path.suffix.lower()\\n",
    "    if suffix == \".npy\":\\n",
    "        return np.load(path, allow_pickle=True)\\n",
    "    if suffix == \".csv\":\\n",
    "        return pd.read_csv(path)\\n",
    "    if suffix == \".parquet\":\\n",
    "        return pd.read_parquet(path)\\n",
    "    raise ValueError(f\"Unsupported array file: {path}\")\\n",
    "\\n",
    "def load_split_from_separate_files():\\n",
    "    if not DATA_DIRECTORY.exists():\\n",
    "        return None\\n",
    "    supported_suffixes = {\\n",
    "        \".npy\",\\n",
    "        \".csv\",\\n",
    "        \".parquet\",\\n",
    "    }\\n",
    "    file_index = {}\\n",
    "    for path in DATA_DIRECTORY.rglob(\"*\"):\\n",
    "        if path.is_file() and path.suffix.lower() in supported_suffixes:\\n",
    "            file_index.setdefault(path.stem.lower(), []).append(path)\\n",
    "\\n",
    "    aliases = {\\n",
    "        \"Xtr_f\": [\"xtr_f\", \"x_train_full\", \"xtrain_full\"],\\n",
    "        \"Xte_f\": [\"xte_f\", \"x_test_full\", \"xtest_full\"],\\n",
    "        \"ytr\": [\"ytr\", \"y_train\", \"ytrain\"],\\n",
    "        \"yte\": [\"yte\", \"y_test\", \"ytest\"],\\n",
    "    }\\n",
    "\\n",
    "    resolved = {}\\n",
    "    for required_name, possible_stems in aliases.items():\\n",
    "        match = None\\n",
    "        for stem in possible_stems:\\n",
    "            paths = file_index.get(stem.lower(), [])\\n",
    "            if paths:\\n",
    "                match = sorted(paths)[0]\\n",
    "                break\\n",
    "        if match is None:\\n",
    "            return None\\n",
    "        resolved[required_name] = match\\n",
    "\\n",
    "    values = {\\n",
    "        key: _read_array_file(path)\\n",
    "        for key, path in resolved.items()\\n",
    "    }\\n",
    "    print(\"Loaded separate train/test files:\")\\n",
    "    for key, path in resolved.items():\\n",
    "        print(f\"  {key}: {path}\")\\n",
    "    return _normalize_split(values)\\n",
    "\\n",
    "def _read_table(path: Path) -> pd.DataFrame:\\n",
    "    if path.suffix.lower() == \".csv\":\\n",
    "        return pd.read_csv(path)\\n",
    "    if path.suffix.lower() == \".parquet\":\\n",
    "        return pd.read_parquet(path)\\n",
    "    raise ValueError(f\"Unsupported table format: {path}\")\\n",
    "\\n",
    "def load_split_from_processed_table():\\n",
    "    if not PROCESSED_DIRECTORY.exists():\\n",
    "        return None\\n",
    "    candidates = [\\n",
    "        *PROCESSED_DIRECTORY.rglob(\"*.parquet\"),\\n",
    "        *PROCESSED_DIRECTORY.rglob(\"*.csv\"),\\n",
    "    ]\\n",
    "    excluded_terms = {\\n",
    "        \"comparison\",\\n",
    "        \"prediction\",\\n",
    "        \"result\",\\n",
    "        \"metric\",\\n",
    "        \"summary\",\\n",
    "        \"correlation\",\\n",
    "    }\\n",
    "    usable_candidates = []\\n",
    "    for path in candidates:\\n",
    "        lowered_name = path.name.lower()\\n",
    "        if any(term in lowered_name for term in excluded_terms):\\n",
    "            continue\\n",
    "        usable_candidates.append(path)\\n",
    "\\n",
    "    preferred_terms = [\\n",
    "        \"full\",\\n",
    "        \"encoded\",\\n",
    "        \"processed\",\\n",
    "        \"model\",\\n",
    "        \"student\",\\n",
    "    ]\\n",
    "\\n",
    "    def candidate_score(path: Path):\\n",
    "        name = path.name.lower()\\n",
    "        score = sum(\\n",
    "            1\\n",
    "            for term in preferred_terms\\n",
    "            if term in name\\n",
    "        )\\n",
    "        return (-score, str(path).lower())\\n",
    "\\n",
    "    for path in sorted(usable_candidates, key=candidate_score):\\n",
    "        try:\\n",
    "            table = _read_table(path)\\n",
    "            target_column = next(\\n",
    "                (\\n",
    "                    column\\n",
    "                    for column in table.columns\\n",
    "                    if str(column).strip().lower() == \"g3\"\\n",
    "                ),\\n",
    "                None,\\n",
    "            )\\n",
    "            if target_column is None:\\n",
    "                continue\\n",
    "\\n",
    "            y = pd.to_numeric(\\n",
    "                table[target_column],\\n",
    "                errors=\"raise\",\\n",
    "            )\\n",
    "            X = table.drop(columns=[target_column]).copy()\\n",
    "\\n",
    "            X = pd.get_dummies(\\n",
    "                X,\\n",
    "                drop_first=True,\\n",
    "                dtype=float,\\n",
    "            )\\n",
    "            X = X.apply(\\n",
    "                pd.to_numeric,\\n",
    "                errors=\"raise\",\\n",
    "            )\\n",
    "\\n",
    "            if X.empty:\\n",
    "                continue\\n",
    "\\n",
    "            Xtr_f, Xte_f, ytr, yte = train_test_split(\\n",
    "                X,\\n",
    "                y,\\n",
    "                test_size=TEST_SIZE,\\n",
    "                random_state=RANDOM_STATE,\\n",
    "            )\\n",
    "            print(\"Created shared split from processed table:\", path)\\n",
    "            return _normalize_split(\\n",
    "                {\\n",
    "                    \"Xtr_f\": Xtr_f,\\n",
    "                    \"Xte_f\": Xte_f,\\n",
    "                    \"ytr\": ytr,\\n",
    "                    \"yte\": yte,\\n",
    "                }\\n",
    "            )\\n",
    "        except Exception:\\n",
    "            continue\\n",
    "    return None\\n",
    "\\n",
    "split = (\\n",
    "    load_split_from_npz()\\n",
    "    or load_split_from_pickle()\\n",
    "    or load_split_from_separate_files()\\n",
    "    or load_split_from_processed_table()\\n",
    ")\\n",
    "\\n",
    "if split is None:\\n",
    "    raise FileNotFoundError(\\n",
    "        \"No usable full-information train/test split or processed \"\\n",
    "        \"table containing G3 was found under data/. Run the earlier \"\\n",
    "        \"data-preparation sessions before executing this notebook.\"\\n",
    "    )\\n",
    "\\n",
    "Xtr_f, Xte_f, ytr, yte = split\\n",
    "\\n",
    "print()\\n",
    "print(\"Training features:\", Xtr_f.shape)\\n",
    "print(\"Test features: \", Xte_f.shape)\\n",
    "print(\"Training targets: \", ytr.shape)\\n",
    "print(\"Test targets: \", yte.shape)"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 3. Validate the Modeling Arrays"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "assert Xtr_f.shape[0] == len(ytr)\\n",
    "assert Xte_f.shape[0] == len(yte)\\n",
    "assert Xtr_f.shape[1] == Xte_f.shape[1]\\n",
    "assert list(Xtr_f.columns) == list(Xte_f.columns)\\n",
    "\\n",
    "target_like_columns = {\\n",
    "    str(column).strip().lower()\\n",
    "    for column in Xtr_f.columns\\n",
    "    if str(column).strip().lower() == \"g3\"\\n",
    "}\\n",
    "assert not target_like_columns, (\\n",
    "    \"Target leakage detected: G3 appears among the features.\"\\n",
    ")\\n",
    "\\n",
    "training_array = Xtr_f.to_numpy(dtype=float)\\n",
    "test_array = Xte_f.to_numpy(dtype=float)\\n",
    "\\n",
    "assert np.isfinite(training_array).all()\\n",
    "assert np.isfinite(test_array).all()\\n",
    "assert np.isfinite(np.asarray(ytr, dtype=float)).all()\\n",
    "assert np.isfinite(np.asarray(yte, dtype=float)).all()\\n",
    "\\n",
    "print(\"Modeling-array validation passed.\")"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 4. Regression Evaluation Helper"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "def eval_reg(y_true, y_pred) -> dict[str, float]:\\n",
    "    mse = mean_squared_error(y_true, y_pred)\\n",
    "    return {\\n",
    "        \"MAE\": float(\\n",
    "            mean_absolute_error(y_true, y_pred)\\n",
    "        ),\\n",
    "        \"RMSE\": float(\\n",
    "            np.sqrt(mse)\\n",
    "        ),\\n",
    "        \"R2\": float(\\n",
    "            r2_score(y_true, y_pred)\\n",
    "        ),\\n",
    "    }\\n",
    "\\n",
    "print(\"Regression evaluation helper is ready.\")"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 5. Define and Train Random Forest Regressor"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Initialize Random Forest with default parameters\\n",
    "rf_model = RandomForestRegressor(\\n",
    "    n_estimators=100,\\n",
    "    random_state=RANDOM_STATE,\\n",
    ")\\n",
    "\\n",
    "print(\"Random Forest Regressor:\")\\n",
    "print(rf_model)"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 6. Fit and Evaluate Random Forest"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "with warnings.catch_warnings():\\n",
    "    warnings.simplefilter(\"always\")\\n",
    "    rf_model.fit(Xtr_f, ytr)\\n",
    "\\n",
    "rf_predictions = rf_model.predict(Xte_f)\\n",
    "rf_metrics = eval_reg(yte, rf_predictions)\\n",
    "\\n",
    "print(\"=\" * 60)\\n",
    "print(\"Random Forest Regression Results\")\\n",
    "print(f\"MAE: {rf_metrics['MAE']:.4f}\")\\n",
    "print(f\"RMSE: {rf_metrics['RMSE']:.4f}\")\\n",
    "print(f\"R2: {rf_metrics['R2']:.4f}\")\\n",
    "print(\"=\" * 60)"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 7. Feature Importance"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Get feature importances\\n",
    "importances = rf_model.feature_importances_\\n",
    "feature_names = Xtr_f.columns\\n",
    "\\n",
    "# Create a DataFrame of feature importances\\n",
    "importance_df = pd.DataFrame({\\n",
    "    'feature': feature_names,\\n",
    "    'importance': importances\\n",
    "}).sort_values('importance', ascending=False)\\n",
    "\\n",
    "# Show top 10 features\\n",
    "print(\"Top 10 Most Important Features:\")\\n",
    "display(importance_df.head(10))\\n",
    "\\n",
    "# Plot feature importances\\n",
    "plt.figure(figsize=(10, 6))\\n",
    "plt.barh(importance_df.head(10)['feature'], importance_df.head(10)['importance'])\\n",
    "plt.xlabel('Importance')\\n",
    "plt.title('Top 10 Feature Importances (Random Forest)')\\n",
    "plt.gca().invert_yaxis()\\n",
    "plt.tight_layout()\\n",
    "plt.show()"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 8. Compare with Session 25 Baselines"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Load the Session 25 baseline results if they exist\\n",
    "comparison_path = TABLES_DIRECTORY / \"model_comparison_table.csv\"\\n",
    "\\n",
    "if comparison_path.exists():\\n",
    "    comparison_table = pd.read_csv(comparison_path)\\n",
    "    print(\"Existing model comparison table loaded.\")\\n",
    "else:\\n",
    "    comparison_table = pd.DataFrame()\\n",
    "    print(\"No existing comparison table found. Creating new one.\")\\n",
    "\\n",
    "# Add Random Forest results\\n",
    "rf_row = {\\n",
    "    \"Session\": 27,\\n",
    "    \"Week\": 4,\\n",
    "    \"Task\": \"Regression\",\\n",
    "    \"Scenario\": \"Full-information\",\\n",
    "    \"Feature Set\": \"X_full\",\\n",
    "    \"Target\": \"G3\",\\n",
    "    \"Model\": \"Random Forest\",\\n",
    "    \"MAE\": rf_metrics[\"MAE\"],\\n",
    "    \"RMSE\": rf_metrics[\"RMSE\"],\\n",
    "    \"R2\": rf_metrics[\"R2\"],\\n",
    "}\\n",
    "\\n",
    "# Remove any existing Random Forest rows\\n",
    "if not comparison_table.empty:\\n",
    "    comparison_table = comparison_table[\\n",
    "        comparison_table[\"Model\"] != \"Random Forest\"\\n",
    "    ].copy()\\n",
    "\\n",
    "# Append the new row\\n",
    "comparison_table = pd.concat(\\n",
    "    [comparison_table, pd.DataFrame([rf_row])],\\n",
    "    ignore_index=True\\n",
    ")\\n",
    "\\n",
    "# Save the updated comparison table\\n",
    "comparison_table.to_csv(comparison_path, index=False)\\n",
    "print(f\"Random Forest results saved to: {comparison_path}\")\\n",
    "\\n",
    "# Show the comparison\\n",
    "display(comparison_table.sort_values('RMSE').round(4))"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 9. Reflection\\n",
    "Random Forest is an ensemble of decision trees that can capture nonlinear relationships.\\n",
    "\\n",
    "Key advantages of Random Forest:\\n",
    "- Handles nonlinear relationships well\\n",
    "- Provides feature importance rankings\\n",
    "- Less prone to overfitting than a single decision tree\\n",
    "- Robust to outliers and noise\\n",
    "\\n",
    "Potential limitations:\\n",
    "- Less interpretable than linear models\\n",
    "- May require more computational resources\\n",
    "- May not improve if relationships are already linear\\n",
    "\\n",
    "Consider comparing Random Forest performance to the baseline models to see if the ensemble approach provides meaningful improvements."
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 10. Completion Check"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Verify all required components are present\\n",
    "assert 'rf_model' in locals()\\n",
    "assert 'rf_predictions' in locals()\\n",
    "assert 'rf_metrics' in locals()\\n",
    "assert all(k in rf_metrics for k in ['MAE', 'RMSE', 'R2'])\\n",
    "assert 'importances' in locals()\\n",
    "\\n",
    "print(\"Session 27 notebook validation passed.\")\\n",
    "print(f\"Random Forest RMSE: {rf_metrics['RMSE']:.4f}\")\\n",
    "print(f\"Random Forest R2: {rf_metrics['R2']:.4f}\")"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3",
   "mimetype": "text/x-python",
   "codemirror_mode": {
    "name": "ipython",
    "version": 3
   },
   "pygments_lexer": "ipython3",
   "nbconvert_exporter": "python",
   "file_extension": ".py"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 5
}
'@

# Save the notebook
$NotebookContent | Set-Content -Path $NotebookPath -Encoding UTF8

Write-Host "[6/8] Notebook created:"
Write-Host " $NotebookPath"

# ------------------------------------------------------------
# 6. Stage and commit the notebook
# ------------------------------------------------------------
Write-Host "[7/8] Staging and committing the notebook..."

git add -- $RelativeNotebookPath
if ($LASTEXITCODE -ne 0) {
    throw "Git could not stage the notebook."
}

git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "No new notebook changes required a commit."
    Write-Host "The Session 27 notebook is already up to date."
}
else {
    $CommitMessage = "Add Session 27 random forest regression notebook"
    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed."
    }
    Write-Host "[8/8] Git commit created:"
    git log -1 --oneline
}

# ------------------------------------------------------------
# 7. Push to GitHub
# ------------------------------------------------------------
Write-Host ""
Write-Host "Pushing to GitHub..."

$CurrentBranch = git branch --show-current
if (-not $CurrentBranch) {
    throw "Git is in detached-HEAD state. Check out a branch before pushing."
}

git push -u origin $CurrentBranch
if ($LASTEXITCODE -ne 0) {
    throw "Git push failed."
}

Write-Host ""
Write-Host "============================================================"
Write-Host " SESSION 27 GITHUB DELIVERABLE COMPLETED"
Write-Host "============================================================"
Write-Host ""
Write-Host "Created and pushed:"
Write-Host " $RelativeNotebookPath"
Write-Host ""
Write-Host "The notebook contains:"
Write-Host " - Random Forest Regression"
Write-Host " - MAE, RMSE, and R-squared evaluation"
Write-Host " - Feature importance analysis"
Write-Host " - Comparison with Session 25 baselines"
Write-Host ""