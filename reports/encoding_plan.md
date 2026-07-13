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
These categories are labels only. They should not be converted into artificial numeric rankings.

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 11/48 - Week 1
Encoding decision: Use one-hot encoding.

2. Binary Variables
Binary variables contain only two categories.
Example:
schoolsup = yes, no
These variables can be converted into 0/1 values.
Encoding decision: Use binary encoding.
Suggested coding:
yes = 1
no = 0
For other two-category variables, use a clear 0/1 mapping and document the mapping.

3. Ordinal Variables
Ordinal variables contain categories with a meaningful order.
Example:
low < medium < high
or numeric educational scales such as:
1 < 2 < 3 < 4
Encoding decision: Keep numeric ordinal variables as ordered numeric features, or use ordinal
encoding only when the order is meaningful.

Categorical Variable Encoding Plan
Column Example Values Variable Type Encoding
Method

Reason

school GP, MS Binary/Nominal Binary
encoding

Two school categories; no
ranking

sex F, M Binary/Nominal Binary
encoding

Two categories only

address U, R Binary/Nominal Binary
encoding

Urban and rural are labels

famsize GT3, LE3 Binary/Nominal Binary
encoding

Two family-size categories

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 11/48 - Week 1
Pstatus A, T Binary/Nominal Binary
encoding

Two parent-status
categories

Mjob teacher, health, services,

other, at_home

Nominal One-hot
encoding

Job categories have no
natural order

Fjob teacher, health, services,

other, at_home

Nominal One-hot
encoding

Job categories have no
natural order

reason course, home, reputation,

other

Nominal One-hot
encoding

School-choice reasons are
unordered labels

guardian mother, father, other Nominal One-hot
encoding

Guardian category has no
ranking

schoolsup yes, no Binary Binary
encoding

Yes/no variable

famsup yes, no Binary Binary
encoding

Yes/no variable

paid yes, no Binary Binary
encoding

Yes/no variable

activities yes, no Binary Binary
encoding

Yes/no variable

nursery yes, no Binary Binary
encoding

Yes/no variable

higher yes, no Binary Binary
encoding

Yes/no variable

internet yes, no Binary Binary
encoding

Yes/no variable

romantic yes, no Binary Binary
encoding

Yes/no variable

Numeric Ordinal Variables
Some variables are already stored as numbers but represent ordered categories. These variables do not
need one-hot encoding.
Column Variable Type Encoding Decision Reason
Medu Ordinal Keep numeric Mother education level has ordered values
Fedu Ordinal Keep numeric Father education level has ordered values
traveltime Ordinal Keep numeric Travel-time levels are ordered
studytime Ordinal Keep numeric Study-time levels are ordered
failures Ordinal/Numeric Keep numeric Number of previous failures has numeric meaning
famrel Ordinal Keep numeric Family relationship quality is ordered
freetime Ordinal Keep numeric Free-time level is ordered
goout Ordinal Keep numeric Going-out frequency is ordered
Dalc Ordinal Keep numeric Workday alcohol consumption level is ordered
Walc Ordinal Keep numeric Weekend alcohol consumption level is ordered
health Ordinal Keep numeric Health status scale is ordered
High-Cardinality Check
A high-cardinality categorical variable has many unique categories. High-cardinality variables can
create too many columns after one-hot encoding.

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 11/48 - Week 1
In this dataset, there are no major high-cardinality categorical variables. However, the following
variables should still be checked because they contain more than two categories:
Mjob
Fjob
reason
guardian
These variables are acceptable for one-hot encoding because they have a small number of categories.

Why Ordinal Encoding Can Be Misleading
Ordinal encoding should not be used for unordered categories.
For example, encoding Mjob like this would be misleading:
teacher = 1
health = 2
services = 3
other = 4
at_home = 5
This would incorrectly suggest that at_home is greater than teacher, or that the distance between
teacher and health is the same as the distance between services and other.
For nominal variables, this artificial numeric order can mislead models that interpret numbers as
meaningful distances.

Final Encoding Recommendation
The final encoding strategy is:
1. Use binary encoding for two-category variables.
2. Use one-hot encoding for nominal variables with more than two categories.
3. Keep numeric ordinal variables as ordered numeric features.
4. Avoid ordinal encoding for unordered categorical variables.
5. Check high-cardinality variables before one-hot encoding.
This encoding plan prepares the dataset for later feature engineering and machine learning model
development.