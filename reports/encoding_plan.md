# Encoding Plan
## Project
**Predicting Student Academic Success Using Interpretable Machine Learning, Public
Educational Data, and Prompt-Engineered Research Workflows**
## Session
Session 11: Categorical Variables
## Purpose
This encoding plan documents how categorical variables will be converted into
numeric features for machine learning. Most machine learning algorithms require
numeric input, so categorical variables must be encoded before model training.
The encoding strategy depends on whether each categorical variable is nominal,
binary, or ordinal.
---
## Encoding Rules
### 1. Nominal Variables
Nominal variables contain categories with no natural order.
Example:
```text
Mjob = teacher, health, services, other, at_home