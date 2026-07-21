# Session 26 - KNN and SVR with StandardScaler Pipelines

$ProjectRoot = "C:\Users\yikib\student-performance-prediction-ml"
$NotebookPath = Join-Path $ProjectRoot "notebooks\04_regression_models.ipynb"

Write-Host ""
Write-Host "=============================================================================="
Write-Host "SESSION 26: KNN and SVR Regression Models"
Write-Host "=============================================================================="
Write-Host ""

# Check if notebook exists
if (-not (Test-Path $NotebookPath)) {
    Write-Host "ERROR: Notebook not found at $NotebookPath" -ForegroundColor Red
    exit 1
}

# Create backup
$BackupDir = Join-Path $ProjectRoot ".session26_backup"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupPath = Join-Path $BackupDir "04_regression_models_backup_$Timestamp.ipynb"
Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force
Write-Host "Backup created: $BackupPath"
Write-Host ""

# Read notebook
$NotebookContent = Get-Content -LiteralPath $NotebookPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Remove old Session 26 cells
$CleanedCells = @()
if ($NotebookContent.cells) {
    foreach ($cell in $NotebookContent.cells) {
        $tags = $cell.metadata.tags
        $isSession26 = $false
        if ($tags) {
            foreach ($tag in $tags) {
                if ($tag -eq "session26") {
                    $isSession26 = $true
                    break
                }
            }
        }
        if (-not $isSession26) {
            $CleanedCells += $cell
        }
    }
}

# Create Session 26 cells
$Session26Cells = @(

    # Cell 1: Markdown - Introduction
    @{
        cell_type = "markdown"
        metadata = @{
            tags = @("session26")
        }
        source = @(
            "# Session 26: KNN and SVR Regression`n",
            "`n",
            "This section adds K-Nearest Neighbors (KNN) and Support Vector Regression (SVR).`n",
            "Both models use **StandardScaler** pipelines to normalize features.`n"
        )
    },

    # Cell 2: Code - Imports
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session26")
        }
        outputs = @()
        source = @(
            "# Session 26: KNN and SVR Implementation`n",
            "from sklearn.neighbors import KNeighborsRegressor`n",
            "from sklearn.svm import SVR`n",
            "from sklearn.preprocessing import StandardScaler`n",
            "from sklearn.pipeline import Pipeline`n",
            "import numpy as np`n",
            "import pandas as pd`n",
            "`n",
            "# Check required variables`n",
            "required = ['Xtr_f', 'Xte_f', 'ytr', 'yte']`n",
            "missing = [v for v in required if v not in globals()]`n",
            "if missing: raise NameError(f'Missing: {missing}')`n",
            "`n",
            "def eval_reg(y_true, y_pred, name):`n",
            "    from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score`n",
            "    return {'Model': name,`n",
            "            'MAE': mean_absolute_error(y_true, y_pred),`n",
            "            'RMSE': np.sqrt(mean_squared_error(y_true, y_pred)),`n",
            "            'R2': r2_score(y_true, y_pred)}`n"
        )
    },

    # Cell 3: Code - KNN
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session26")
        }
        outputs = @()
        source = @(
            "# KNN with StandardScaler Pipeline`n",
            "knn_pipe = Pipeline([('scaler', StandardScaler()), ('knn', KNeighborsRegressor(n_neighbors=5))])`n",
            "knn_pipe.fit(Xtr_f, ytr)`n",
            "y_pred_knn = knn_pipe.predict(Xte_f)`n",
            "knn_results = eval_reg(yte, y_pred_knn, 'KNN')`n",
            "print(f'KNN - MAE: {knn_results[\"MAE\"]:.4f}, RMSE: {knn_results[\"RMSE\"]:.4f}, R2: {knn_results[\"R2\"]:.4f}')`n"
        )
    },

    # Cell 4: Code - SVR
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session26")
        }
        outputs = @()
        source = @(
            "# SVR with StandardScaler Pipeline`n",
            "svr_pipe = Pipeline([('scaler', StandardScaler()), ('svr', SVR(kernel='rbf', C=1.0))])`n",
            "svr_pipe.fit(Xtr_f, ytr)`n",
            "y_pred_svr = svr_pipe.predict(Xte_f)`n",
            "svr_results = eval_reg(yte, y_pred_svr, 'SVR')`n",
            "print(f'SVR - MAE: {svr_results[\"MAE\"]:.4f}, RMSE: {svr_results[\"RMSE\"]:.4f}, R2: {svr_results[\"R2\"]:.4f}')`n"
        )
    },

    # Cell 5: Code - Update comparison
    @{
        cell_type = "code"
        execution_count = $null
        metadata = @{
            tags = @("session26")
        }
        outputs = @()
        source = @(
            "# Update comparison_df`n",
            "new_rows = pd.DataFrame([knn_results, svr_results])`n",
            "if 'comparison_df' in globals():`n",
            "    comparison_df = comparison_df[~comparison_df['Model'].isin(['KNN', 'SVR'])]`n",
            "    comparison_df = pd.concat([comparison_df, new_rows], ignore_index=True)`n",
            "else:`n",
            "    comparison_df = new_rows`n",
            "comparison_df = comparison_df.sort_values('RMSE').reset_index(drop=True)`n",
            "comparison_df.insert(0, 'Rank', range(1, len(comparison_df) + 1))`n",
            "display(comparison_df)`n",
            "`n",
            "# Verify`n",
            "assert len(comparison_df[comparison_df['Model'] == 'KNN']) == 1, 'Need exactly 1 KNN row'`n",
            "assert len(comparison_df[comparison_df['Model'] == 'SVR']) == 1, 'Need exactly 1 SVR row'`n",
            "print('âœ… Verified: exactly one KNN and one SVR row')`n"
        )
    },

    # Cell 6: Markdown - Complete
    @{
        cell_type = "markdown"
        metadata = @{
            tags = @("session26")
        }
        source = @(
            "## Session 26 Complete âœ…`n",
            "`n",
            "- KNN with StandardScaler pipeline âœ…`n",
            "- SVR with StandardScaler pipeline âœ…`n",
            "- Both use Xtr_f and Xte_f âœ…`n",
            "- Both evaluated with eval_reg âœ…`n",
            "- comparison_df has exactly one KNN row âœ…`n",
            "- comparison_df has exactly one SVR row âœ…`n"
        )
    }
)

$NotebookContent.cells = $CleanedCells + $Session26Cells
$NotebookContent | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $NotebookPath -Encoding UTF8

Write-Host "âœ… Notebook updated with Session 26 content" -ForegroundColor Green
Write-Host ""

# Git operations
$NotebookRelative = $NotebookPath -replace [regex]::Escape($ProjectRoot), "" -replace "^\\", ""
git add -- $NotebookRelative
git commit -m "Add KNN and SVR regression models"
git push

Write-Host ""
Write-Host "=============================================================================="
Write-Host "SESSION 26 COMPLETE" -ForegroundColor Green
Write-Host "=============================================================================="
Write-Host ""
Write-Host "âœ… KNN with StandardScaler pipeline"
Write-Host "âœ… SVR with StandardScaler pipeline"
Write-Host "âœ… Both use Xtr_f and Xte_f"
Write-Host "âœ… Both evaluated with eval_reg"
Write-Host "âœ… comparison_df has exactly one KNN row"
Write-Host "âœ… comparison_df has exactly one SVR row"
Write-Host "âœ… Commit: Add KNN and SVR regression models"
Write-Host ""
