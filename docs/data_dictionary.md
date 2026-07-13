
# Data Dictionary
## Project
Student Performance Prediction Using Machine Learning
## Purpose
This data dictionary describes the variables used in the student performance
dataset. The variables are grouped into demographic, social, school-related, and
academic feature groups.
## Summary
The dataset includes student background information, family and social information,
school-related behavior, and academic performance variables. The final grade
variable, G3, can serve as the primary prediction target.

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 7/48 - Week 1
## 1. Demographic Variables
| Variable | Description | Data Type | Missing Values |
|---|---|---:|---:|
| school | Student's school. | object | 0 |
| sex | Student's sex. | object | 0 |
| age | Student's age. | int64 | 0 |
| address | Student's home address type, such as urban or rural. | object | 0 |
## 2. Social Variables
| Variable | Description | Data Type | Missing Values |
|---|---|---:|---:|
| famsize | Student's family size category. | object | 0 |
| Pstatus | Parent cohabitation status. | object | 0 |
| Medu | Mother's education level. | int64 | 0 |
| Fedu | Father's education level. | int64 | 0 |
| Mjob | Mother's job category. | object | 0 |
| Fjob | Father's job category. | object | 0 |
| guardian | Student's guardian. | object | 0 |
| famrel | Quality of family relationships. | int64 | 0 |
| freetime | Student's free time after school. | int64 | 0 |
| goout | Frequency of going out with friends. | int64 | 0 |
| Dalc | Workday alcohol consumption. | int64 | 0 |
| Walc | Weekend alcohol consumption. | int64 | 0 |
| romantic | Whether the Student is in a romantic relationship. | object | 0 |
## 3. School-Related Variables
| Variable | Description | Data Type | Missing Values |
|---|---|---:|---:|
| reason | Reason for choosing the school. | object | 0 |
| traveltime | Travel time from home to school. | int64 | 0 |
| studytime | Weekly study time category. | int64 | 0 |
| schoolsup | Whether the Student receives extra school support. | object | 0 |
| famsup | Whether the Student receives family educational support. | object | 0 |
| paid | Whether the Student receives extra paid classes. | object | 0 |
| activities | Whether the Student participates in extracurricular activities. |
object | 0 |
| nursery | Whether the Student attended nursery school. | object | 0 |
| higher | Whether the Student wants to pursue higher education. | object | 0 |
| internet | Whether the Student has internet access at home. | object | 0 |
| absences | Number of school absences. | int64 | 0 |
## 4. Academic Variables
| Variable | Description | Data Type | Missing Values |
|---|---|---:|---:|
| failures | Number of past class failures. | int64 | 0 |
| G1 | First-period grade. | int64 | 0 |
| G2 | Second-period grade. | int64 | 0 |
| G3 | Final grade. This is usually the main prediction target. | int64 | 0 |
## Interpretation Notes
The demographic variables describe basic student background information.
The social variables include family structure, parents' education, parents'
occupations, social behavior, and home environment.

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 7/48 - Week 1
The school-related variables describe study habits, support systems, attendance,
and school engagement.
The academic variables describe previous academic performance. G3 is the final
grade and can serve as the primary target variable for prediction.
## Modeling Note
If the project goal is full-information prediction, G1 and G2 may be included as
predictors of G3.
If the project goal is early-warning prediction, G1 and G2 should be excluded
because they may introduce target leakage. In that case, the model should use only
information available early in the semester.

## Target Variables
This project uses two target variables: one for regression and one for
classification.
### Regression Target
| Variable | Type | Description | Use |
|---|---|---|---|
| `G3` | Numeric | Final student grade | Regression target |
`G3` is the original final grade variable. It is used when the goal is to predict
the student's actual final grade.
### Classification Target
| Variable | Type | Description | Rule | Use |

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 8/48 - Week 1
|---|---|---|---|---|
| `passed` | Binary integer | Pass/fail outcome created from `G3` | `1` if `G3 >=
10`, else `0` | Classification target |
The `passed` variable is created from the final grade `G3`.
The classification rule is:
```python
df["passed"] = (df["G3"] >= 10).astype(int)

This means:
Value Meaning
1 Student passed
0 Student did not pass
Chosen Threshold
The chosen threshold is:
G3 >= 10
Students with G3 >= 10 are labeled as passing.
Students with G3 < 10 are labeled as not passing or at risk.
Threshold Limitation
One limitation of this threshold is that it creates a hard cutoff. For example, a student with G3 = 9 is
labeled as not passing, while a student with G3 = 10 is labeled as passing, even though their
performance may be very similar.
Final Decision
For the first version of the project, the G3 >= 10 threshold will be kept because it is simple,
interpretable, and useful for creating a binary classification target. The limitation of the hard cutoff
should be documented in the final report.