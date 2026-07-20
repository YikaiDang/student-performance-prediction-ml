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
# ---------------------------------------------------------------------------
# Session 24: Binary-classification evaluation helper
# ---------------------------------------------------------------------------
def eval_clf(y_true, y_pred, y_proba=None):
    """
    Evaluate binary-classification predictions.
    The positive class is label 1, representing an at-risk student.

    Parameters
    ----------
    y_true : array-like
        Actual binary class labels.
    y_pred : array-like
        Predicted binary class labels.
    y_proba : array-like or None, default=None
        Predicted probabilities for the positive class. When supplied,
        ROC-AUC is included in the returned results.

    Returns
    -------
    dict
        Dictionary containing accuracy, precision, recall, F1 score,
        and optional ROC-AUC.
    """
    from sklearn.metrics import (
        accuracy_score,
        f1_score,
        precision_score,
        recall_score,
        roc_auc_score,
    )

    results = {
        "accuracy": accuracy_score(y_true, y_pred),
        "precision": precision_score(
            y_true,
            y_pred,
            zero_division=0,
        ),
        "recall": recall_score(
            y_true,
            y_pred,
            zero_division=0,
        ),
        "f1": f1_score(
            y_true,
            y_pred,
            zero_division=0,
        ),
    }

    if y_proba is not None:
        results["roc_auc"] = roc_auc_score(
            y_true,
            y_proba,
        )

    return results
