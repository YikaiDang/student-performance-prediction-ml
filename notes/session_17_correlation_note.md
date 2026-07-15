# Session 17: Correlation Analysis Note
## Purpose
This analysis examines Pearson correlations among the numeric variables in
the student-performance dataset, with particular attention to the final-grade
target, G3.
## Strongest Correlates of G3
| Rank | Feature | Correlation with G3 | Direction |
|---:|---|---:|---|
| 1 | G2 | Replace with exact value | Positive or negative |
| 2 | G1 | Replace with exact value | Positive or negative |
| 3 | Replace with feature | Replace with exact value | Positive or negative |
| 4 | Replace with feature | Replace with exact value | Positive or negative |
| 5 | Replace with feature | Replace with exact value | Positive or negative |
## G1 and G2 Highlight
G1 represents the first-period grade, G2 represents the second-period grade,
and G3 represents the final grade. G1 and G2 should be highlighted because
they are earlier measurements of academic performance and are expected to
have strong relationships with G3.
Their use depends on the intended prediction time. They may be acceptable in
a full-information model when those grades are already known. However, they
may create temporal leakage in an early-warning model intended to predict
student outcomes before G1 or G2 become available.
## Interpretation
The heatmap shows the direction and strength of the linear relationships
between numeric variables. Positive correlations indicate that higher values
of a feature tend to occur with higher G3 values. Negative correlations
indicate that higher values of a feature tend to occur with lower G3 values.
The strong relationships between G1, G2, and G3 may improve predictive
performance, but they may also cause the model to depend heavily on prior
grade information.
## Recommendation

GSSRP 2026 - Kean University | Predicting Student Performance Using Machine Learning Session 17/48 - Week 2
The project should compare two modeling scenarios:
1. A full-information model that includes G1 and G2.
2. An early-warning model that excludes G1 and G2.
This comparison will show how much model performance depends on prior-grade
information and whether the model remains useful when late-stage predictors
are unavailable.
## Limitation
Correlation measures linear association and does not establish causation.
## Artifact
The corresponding visualization is stored at:
`figures/correlation_heatmap.png`