# Cleaning Checklist
## Project
Student Performance Prediction Using Machine Learning
## Session
Session 10: Missing Values and Duplicates
## Purpose
The purpose of this checklist is to document the data-quality checks completed
before preprocessing, feature engineering, and model development. The dataset was

checked for missing values and duplicate rows to make sure that downstream machine-
learning models are not affected by silent data-quality problems.

## 1. Missing Values Check
### Python Code Used
```python
print("Missing per column:")
print(df.isna().sum())
Result
The missing-value check showed that all columns have zero missing values.
Decision
No missing-value imputation is needed.
Reason
Imputation is only needed when some values are missing and must be replaced or estimated. Since the
dataset contains no missing values, applying imputation would be unnecessary and could introduce
artificial information into the dataset.

## Reflection Question
### Question
Why is documenting "no cleaning needed" just as important as documenting cleaning
steps?
### Answer
Documenting "no cleaning needed" is important because it confirms that the dataset
was actually checked for data-quality problems. If no missing values or duplicate
rows are found, this result should still be recorded so that future readers
understand why no imputation or duplicate removal was performed.
This improves reproducibility because another researcher can see the exact reason
cleaning was not applied. It also improves transparency because the decision is
based on evidence from the data, not assumption. In this project, the missing-value
count was 0 and the duplicate-row count was 0, so no cleaning action was required
for these two issues.