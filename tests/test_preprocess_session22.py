from __future__ import annotations
import sys
from pathlib import Path
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_DIRECTORY = PROJECT_ROOT / "src"
if str(SRC_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(SRC_DIRECTORY))

from preprocess import split_modeling_scenarios

def make_example_data():
    index = pd.Index(range(100, 120), name="student_id")
    X_full = pd.DataFrame(
        {
            "studytime": range(20),
            "failures": [0, 1] * 10,
            "G1": range(5, 25),
            "G2": range(6, 26),
        },
        index=index,
    )
    X_early = X_full.drop(columns=["G1", "G2"]).copy()
    y = pd.Series(range(7, 27), index=index, name="G3")
    return X_full, X_early, y

def test_split_is_reproducible():
    X_full, X_early, y = make_example_data()
    first = split_modeling_scenarios(X_full, X_early, y, random_state=42)
    second = split_modeling_scenarios(X_full, X_early, y, random_state=42)
    pd.testing.assert_frame_equal(first["Xtr_f"], second["Xtr_f"])
    pd.testing.assert_frame_equal(first["Xte_f"], second["Xte_f"])
    pd.testing.assert_frame_equal(first["Xtr_e"], second["Xtr_e"])
    pd.testing.assert_frame_equal(first["Xte_e"], second["Xte_e"])
    pd.testing.assert_series_equal(first["ytr"], second["ytr"])
    pd.testing.assert_series_equal(first["yte"], second["yte"])

def test_training_and_test_sets_do_not_overlap():
    X_full, X_early, y = make_example_data()
    split = split_modeling_scenarios(X_full, X_early, y, random_state=42)
    training_indices = set(split["Xtr_f"].index)
    test_indices = set(split["Xte_f"].index)
    assert training_indices.isdisjoint(test_indices)
    assert (training_indices | test_indices) == set(X_full.index)

def test_split_uses_expected_80_20_row_counts():
    X_full, X_early, y = make_example_data()
    split = split_modeling_scenarios(X_full, X_early, y, test_size=0.20, random_state=42)
    assert len(split["Xtr_f"]) == 16
    assert len(split["Xtr_e"]) == 16
    assert len(split["ytr"]) == 16
    assert len(split["Xte_f"]) == 4
    assert len(split["Xte_e"]) == 4
    assert len(split["yte"]) == 4
