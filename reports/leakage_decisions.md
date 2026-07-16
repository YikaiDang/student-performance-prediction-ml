# Leakage-Decision Note

## Session Information
- **Program:** GSSRP 2026
- **Project:** Predicting Student Academic Success Using Interpretable Machine Learning
- **Session:** 18 of 48
- **Topic:** Data-leakage discussion
- **Target variable:** G3
- **Prior-grade predictors under review:** G1 and G2

## 1. Decision Purpose
This note documents the project decision regarding whether the first-period grade, G1, and second-period grade, G2, should be included when predicting the final grade, G3.

The decision is based on three considerations:
1. The predictive value of G1 and G2.
2. The time at which G1 and G2 become available.
3. The intended operational purpose of the model.

## 2. Correlation Evidence
The Session 18 correlation analysis produced the following results:
- Correlation between G1 and G3: **0.801**
- Correlation between G2 and G3: **0.905**

These results indicate that prior course grades contain substantial information about the final grade. Including G1 and G2 is therefore expected to improve predictive performance.

However, correlation strength alone does not determine whether a predictor is appropriate. The predictor must also be available at the intended prediction time. Correlation also represents association rather than proof of causation.

## 3. Data-Leakage Interpretation
Data leakage occurs when a model uses information that would not realistically be available when the prediction is supposed to be made.

G1 and G2 are not automatically leakage variables in every modeling context. They are legitimate predictors when the model is used after those grades have been recorded. However, they are inappropriate for a beginning-of-course early-warning model because they are not available at the required prediction time.

The project will therefore use two separately defined modeling scenarios.

## 4. Scenario 1: Full-Information Model
### Decision
The full-information model will include G1 and G2.

### Purpose
This scenario will measure predictive performance when prior course grades are known.

### Prediction Time
The prediction is assumed to occur after G1 and G2 have been recorded.

### Predictor Treatment
The model may include:
- G1
- G2
- Demographic variables
- Behavioral variables
- Family-related variables
- School-support variables
- Academic-history variables
- Other eligible predictors

### Expected Performance
This model is expected to achieve higher predictive accuracy because G1 and G2 contain direct information about academic progress in the same course.

### Intended Use
The full-information model will serve as:
- A high-information prediction model
- A performance benchmark
- A measure of the predictive contribution of prior grades
- A possible late-stage student-support model

### Limitation
The model may have limited early-warning value because a substantial portion of the academic term has already passed when G1 and G2 become available. It must not be described as a beginning-of-course early-warning system.

## 5. Scenario 2: Early-Warning Model
### Decision
The early-warning model will exclude G1 and G2.

### Purpose
This scenario will determine whether students can be identified as at risk before prior course grades become available.

### Prediction Time
The prediction is assumed to occur early in the academic term.

### Excluded Variables
The following variables will be excluded:
- G1
- G2

### Eligible Predictors
The model may use variables available at the intended early prediction time, including:
- Study time
- Previous academic failures
- Family support
- School support
- Travel time
- Internet access
- Educational aspirations
- Social and behavioral factors
- Demographic characteristics
- Other approved early-available predictors

Absence information may be used only if the absence measurement corresponds to the intended prediction time.

### Expected Performance
This model is expected to have lower predictive accuracy because it excludes two of the strongest predictors of G3.

### Intended Use
The early-warning model will serve as:
- An early student-risk identification model
- A basis for tutoring or advising decisions
- A test of the predictive value of early student characteristics
- An intervention-oriented modeling scenario

### Limitation
The model may produce larger prediction errors and lower R-squared values than the full-information model.

## 6. Scenario Comparison

| Criterion | Full-Information Model | Early-Warning Model |
| :--- | :--- | :--- |
| **Includes G1** | Yes | No |
| **Includes G2** | Yes | No |
| **Prediction timing** | After prior grades are recorded | Before prior grades are recorded |
| **Expected accuracy** | Higher | Lower |
| **Time available for intervention** | Less | More |
| **Primary purpose** | Maximum predictive performance | Early risk identification |
| **Leakage interpretation** | Valid when used after G1 and G2 exist | G1 and G2 excluded to match prediction timing |
| **Main limitation** | Limited early-warning value | Lower statistical performance |

## 7. Evaluation Plan
The two scenarios will be trained and evaluated separately.
Where appropriate, both scenarios will use the same:
- Training and testing split
- Cross-validation procedure
- Model algorithms
- Random seed
- Preprocessing procedures
- Evaluation metrics

Regression performance will be evaluated using metrics such as:
- Mean absolute error
- Mean squared error
- Root mean squared error
- R-squared

The analysis will also consider practical criteria:
- Prediction timing
- Feature availability
- Time available for intervention
- Interpretability
- Operational usefulness

The model with the highest statistical accuracy will not automatically be treated as the most useful model.

## 8. Final Project Decision
The project will retain two separate modeling scenarios.
1. **Full-information scenario:** Include G1 and G2.
2. **Early-warning scenario:** Exclude G1 and G2.

The results will be reported separately because the two scenarios answer different research questions.

The full-information scenario measures predictive performance when prior grades are known. The early-warning scenario evaluates whether student risk can be identified early enough to support meaningful intervention. This two-scenario design prevents a high-accuracy late-stage model from being incorrectly presented as an early-warning system.