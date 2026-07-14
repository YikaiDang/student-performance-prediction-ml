# Scaling Plan
## Session 12: Numerical Variables
## Purpose
The purpose of this scaling plan is to decide which numerical variables should be
scaled before machine-learning models are trained. Scaling is important because
some models are sensitive to the size and range of numeric features.
## Numeric Variable Review
The dataset was reviewed using the following Python code:
```python
num_cols = df.select_dtypes(include="number").columns.tolist()
print(df[num_cols].agg(["min", "max", "mean"]).T)
This code identified all numeric columns and summarized their minimum, maximum, and mean values.

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 12/48 - Week 1
Why Scaling Is Needed
Some numeric variables may have different ranges. For example, one variable may range from 0 to 4,
while another may range from 0 to 100. Models that use distances, gradients, or coefficients can be
affected by these differences.
Models That Need Scaling
The following models should use scaled numeric features:
1. Logistic Regression
Logistic regression uses coefficients and optimization. Scaling helps the model train more
reliably.
2. Linear Regression
Linear regression can be affected when numeric variables are on very different scales, especially
when regularization is used.
3. K-Nearest Neighbors
KNN is distance-based. Variables with larger ranges can dominate the distance calculation if
scaling is not used.
4. Support Vector Machine
SVM is sensitive to feature scale because it depends on distances and margins.
5. Neural Networks
Neural networks train better when numeric input features are scaled because gradient-based
optimization becomes more stable.
Models That Usually Do Not Require Scaling
The following models usually do not require scaling:
1. Decision Tree
Decision trees split variables by thresholds. The relative order of values matters more than the
scale.
2. Random Forest
Random forests are collections of decision trees, so they are usually not sensitive to feature scale.
3. Gradient Boosting Trees
Tree-based boosting models also split based on thresholds and usually do not require scaling.
Recommended Pipeline Approach
The project should use preprocessing pipelines so that scaling is applied only where needed.
Recommended strategy:
• Use StandardScaler for linear, distance-based, SVM, and neural-network models.
• Do not apply scaling for tree-based models unless required by a specific experiment.
• Keep preprocessing inside a scikit-learn Pipeline to avoid data leakage.
• Fit the scaler only on the training data.
• Apply the fitted scaler to validation and test data.

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 12/48 - Week 1
Final Recommendation
Scaling should be included in the preprocessing pipeline for Logistic Regression, Linear Regression,
KNN, SVM, and Neural Networks. Scaling is not required for Decision Tree, Random Forest, or
Gradient Boosting models. The project should use separate model pipelines so each algorithm receives
the correct preprocessing.