from __future__ import annotations
from typing import TypedDict
import pandas as pd
from sklearn.model_selection import train_test_split

class ScenarioSplit(TypedDict):
    Xtr_f: pd.DataFrame
    Xte_f: pd.DataFrame
    Xtr_e: pd.DataFrame
    Xte_e: pd.DataFrame
    ytr: pd.Series
    yte: pd.Series

def _coerce_target_series(y: pd.Series | pd.DataFrame) -> pd.Series:
    if isinstance(y, pd.Series):
        return y.copy()
    if isinstance(y, pd.DataFrame):
        if y.shape[1] != 1:
            raise ValueError("The target DataFrame must contain exactly one column.")
        target = y.iloc[:, 0].copy()
        if target.name is None:
            target.name = y.columns[0]
        return target
    raise TypeError("y must be a pandas Series or a one-column pandas DataFrame.")

def split_modeling_scenarios(
    X_full: pd.DataFrame,
    X_early: pd.DataFrame,
    y: pd.Series | pd.DataFrame,
    *,
    test_size: float = 0.20,
    random_state: int = 42,
) -> ScenarioSplit:
    if not isinstance(X_full, pd.DataFrame):
        raise TypeError("X_full must be a pandas DataFrame.")
    if not isinstance(X_early, pd.DataFrame):
        raise TypeError("X_early must be a pandas DataFrame.")
    if not 0.0 < test_size < 1.0:
        raise ValueError("test_size must be strictly between 0 and 1.")
    if not isinstance(random_state, int):
        raise TypeError("random_state must be an integer.")

    target = _coerce_target_series(y)

    if not X_full.index.is_unique:
        raise ValueError("X_full must have a unique row index.")
    if not X_early.index.is_unique:
        raise ValueError("X_early must have a unique row index.")
    if not target.index.is_unique:
        raise ValueError("The target must have a unique row index.")
    if not X_full.index.equals(X_early.index):
        raise ValueError("X_full and X_early must use the same row index in the same order.")
    if not X_full.index.equals(target.index):
        raise ValueError("The feature matrices and target must use the same row index.")

    extra_early_columns = set(X_early.columns) - set(X_full.columns)
    if extra_early_columns:
        raise ValueError("X_early contains columns that are absent from X_full: " + str(sorted(extra_early_columns)))

    if target.name is not None:
        if target.name in X_full.columns:
            raise ValueError(f"Target leakage detected: {target.name!r} is present in X_full.")
        if target.name in X_early.columns:
            raise ValueError(f"Target leakage detected: {target.name!r} is present in X_early.")

    common_indices = X_full.index.to_numpy(copy=True)
    train_indices, test_indices = train_test_split(
        common_indices,
        test_size=test_size,
        random_state=random_state,
        shuffle=True,
    )

    return {
        "Xtr_f": X_full.loc[train_indices].copy(),
        "Xte_f": X_full.loc[test_indices].copy(),
        "Xtr_e": X_early.loc[train_indices].copy(),
        "Xte_e": X_early.loc[test_indices].copy(),
        "ytr": target.loc[train_indices].copy(),
        "yte": target.loc[test_indices].copy(),
    }
