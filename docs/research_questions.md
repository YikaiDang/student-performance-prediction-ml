# Research Questions and Hypotheses
## Project Title
Student Performance Prediction Using Machine Learning
## Purpose of This Document
This document defines the research roadmap for the project. It lists the six
research questions, five hypotheses, the two-scenario modeling design, and the
shared Research Questions table completed during Session 2.
The purpose is to make the project measurable, testable, reproducible, and
connected to the machine-learning workflow.
---
## Six Research Questions

GSSRP 2026 Kean University
Predicting Student Academic Success Using Interpretable Machine Learning

Page
74

Session 02 | Dr. Yousef Nejatbakhsh, Ph.D.
| # | Research Question | Type | Connected Hypothesis |
|---|---|---|---|
| RQ1 | Which student-related variables are most strongly associated with academic
performance? | Factor analysis | H4 |
| RQ2 | Which machine-learning algorithm gives the best predictive performance for
final-grade prediction? | Prediction | H1 |
| RQ3 | Do ensemble models, such as Random Forest and Gradient Boosting, outperform
simpler models, such as Linear or Logistic Regression and Decision Trees? |
Prediction | H1 |
| RQ4 | How does performance change when prior grades G1 and G2 are removed from
the feature set? | Intervention / prediction comparison | H2, H3 |
| RQ5 | Which model best balances accuracy, interpretability, robustness, and
educational usefulness? | Prediction / model evaluation | H3, H4 |
| RQ6 | Can prompt-engineered workflows improve clarity, reproducibility, and
documentation quality? | Process | H5 |
---
## Five Hypotheses
| # | Hypothesis | Answers / Connects To |
|---|---|---|
| H1 | Ensemble tree-based models, especially Random Forest and Gradient Boosting,
will outperform Linear Regression and Decision Trees. | RQ2, RQ3 |
| H2 | Models that include prior grades G1 and G2 will perform substantially better
than models that exclude them. | RQ4 |
| H3 | The early-warning model, which excludes G1 and G2, will be less accurate but
more useful for intervention decisions. | RQ4, RQ5 |
| H4 | Feature importance will highlight prior achievement, failures, study time,
attendance, and support variables. | RQ1, RQ5 |
| H5 | Prompt-engineered documentation will improve students' ability to explain
methods and produce a reproducible report. | RQ6 |
---
## Two-Scenario Design
This project uses two modeling scenarios because the UCI Student Performance
dataset includes three grade variables: G1, G2, and G3. G1 is the first-period
grade, G2 is the second-period grade, and G3 is the final grade. Since G1 and G2
are strongly related to G3, including them as predictors can yield very strong
model performance. However, if the goal is early-warning prediction, using G1 and
G2 may create a leakage problem because those grades may not be available early
enough for intervention.
Therefore, the project compares two scenarios:
1. **Full-information scenario:** models are allowed to use G1 and G2 as predictors
of G3. This scenario measures maximum predictive performance when prior grades are
available.
2. **Early-warning scenario:** models exclude G1 and G2. This scenario tests
whether student risk can be predicted earlier using demographic, behavioral,
attendance, support, and background variables.
This design is central to RQ4, H2, and H3 because it separates high predictive
accuracy from realistic early-intervention usefulness.
---

GSSRP 2026 Kean University
Predicting Student Academic Success Using Interpretable Machine Learning

Page
75

Session 02 | Dr. Yousef Nejatbakhsh, Ph.D.
## Shared Research Questions Activity Table
| Pair | Assigned RQ | Refined Measurable Sentence | Target Variable | Predictor(s)
| Task Type | Matching Hypothesis | Category | G1/G2 Leakage? |
|---|---|---|---|---|---|---|---|---|
| Pair 1 | RQ1 | Which student demographic, academic, behavioral, attendance, and
support variables are most strongly associated with final grade G3 in the UCI
Student Performance dataset? | G3 final grade | Study time, absences, failures,
school support, family support, demographic variables, and optionally G1/G2 in the
full-information scenario | Factor analysis | Prior achievement, failures, study
time, attendance, and support variables will be among the strongest predictors of
final performance. | Factor analysis | Partly. If G1 and G2 are included, they may
dominate the analysis. |
| Pair 2 | RQ2 | Which machine-learning algorithm achieves the best predictive
performance when predicting final grade G3 using student demographic, academic,
behavioral, attendance, and support variables? | G3 final grade | Student
demographic, academic, behavioral, attendance, and support variables | Regression |
Ensemble tree-based models, especially Random Forest and Gradient Boosting, will
outperform Linear Regression and Decision Trees. | Prediction | Yes, if G1 and G2

are included. Results should be reported under both full-information and early-
warning scenarios. |

| Pair 3 | RQ3 | Do Random Forest and Gradient Boosting achieve better predictive
performance than Linear Regression, Logistic Regression, and Decision Trees when
predicting G3 final grade or at-risk status? | G3 final grade or at_risk status |
Student demographic, academic, behavioral, attendance, and support variables |
Regression or classification | Ensemble tree-based models will outperform simpler
models because they can capture nonlinear relationships and feature interactions. |
Prediction | Yes, if G1 and G2 are used as predictors. |
| Pair 4 | RQ4 | How does model performance change when predicting G3 final grade
or at-risk status after removing prior grade variables G1 and G2 from the feature
set? | G3 final grade or at_risk status | Full-information scenario: all allowed
predictors including G1 and G2. Early-warning scenario: all allowed predictors
excluding G1 and G2. | Regression or classification | Models that include G1 and G2
will perform substantially better, but models without G1 and G2 will be more useful
for early intervention. | Intervention | Yes. This is the central leakage question.
|
| Pair 5 | RQ5 | Which model provides the best balance of predictive performance,
interpretability, robustness, and usefulness for identifying student academic risk?
| G3 final grade or at_risk status | Student demographic, academic, behavioral,
attendance, and support variables evaluated under both scenarios | Prediction/model
evaluation | The early-warning model may be less accurate than the full-information
model, but it will be more educationally useful for intervention decisions. |
Prediction / intervention | Yes. Educational usefulness depends on whether the
prediction is made before or after G1 and G2 are available. |
| Pair 6 | RQ6 | Can prompt-engineered workflows improve the clarity,
reproducibility, and documentation quality of student machine-learning research
reports? | Documentation quality, reproducibility checklist score, or clarity score
| Use of standard prompt templates, structured reporting format, GitHub
documentation checklist | Process evaluation | Prompt-engineered documentation will
improve students' ability to explain methods and produce a reproducible report. |
Process | No. This question is about documentation workflow, not predictive
modeling. |
---
## Notes for Future Sessions
This document should be updated only when the research design changes. Future
coding notebooks, model comparison tables, interpretation results, and the final
report should refer back to these research questions and hypotheses.