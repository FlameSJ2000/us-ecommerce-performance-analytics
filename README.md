# U.S. E-Commerce Performance Analytics

## Project Overview

This project analyzes a synthetic U.S. e-commerce dataset containing approximately 1 million orders from 2019 to 2025.

The project focuses on three main business areas:

- Sales
- Delivery
- Customer Satisfaction

The analysis also includes a machine learning component to investigate whether late deliveries can be predicted immediately after payment confirmation using information available at that time.

## Tools

- PostgreSQL — data preparation, validation, staging, analytics, and modeling datasets
- Python — exploratory data analysis, feature engineering, machine learning, and diagnostic investigation
- R — statistical analysis, hypothesis testing, effect sizes, and business interpretation
- Power BI — business visualization and dashboard development

## Project Workflow

### 1. SQL Data Preparation

The original dataset contains multiple related tables, including:

- Customers
- Orders
- Order Items
- Payments
- Reviews
- Products
- Sellers
- Geolocation

The SQL workflow was organized into:

- Raw layer
- Staging layer
- Analytics layer
- Analysis layer
- Modeling layer

The final modeling dataset was created at one row per order to avoid duplication caused by one-to-many relationships.

## 2. Python Analysis and Machine Learning

Python was used for:

- Data validation
- Exploratory data analysis
- Feature audit
- Feature engineering
- Chronological train, validation, and test split
- Model comparison
- Diagnostic investigation

Models evaluated included:

- Logistic Regression
- Random Forest
- XGBoost
- LightGBM
- CatBoost

Primary late-delivery models performed close to random discrimination, with ROC-AUC values around 0.50.

A sensitivity model using estimated delivery duration achieved much higher performance, but the feature was not included in the primary operational model because its data-generation mechanism and prediction-time availability could not be fully verified.

## 3. R Statistical Analysis

R was used for explanatory and statistical analysis across the three business areas.

The analysis included:

- Kruskal-Wallis tests
- Pairwise Wilcoxon tests
- Spearman correlation
- Chi-square tests
- Effect sizes
- Confidence intervals
- Sensitivity and robustness checks

## Key Findings

### Sales

The dataset generated approximately:

- $910.61 million in merchandise revenue
- $233.89 million in merchandise profit
- 25.69% revenue-weighted merchandise margin

Customer segments showed differences in merchandise profitability, with VIP orders having lower average merchandise margins than Consumer and Corporate orders.

### Delivery

Shipping distance was strongly associated with delivery time.

However, longer shipping distances were not clearly associated with higher late-delivery rates.

The synthetic dataset also contained unusual fixed delivery-delay patterns:

- On-time orders were delivered approximately 2 days before the estimated date
- Late orders were delivered approximately 5 days after the estimated date

### Customer Satisfaction

Approximately 75% of orders received 4-5 star reviews.

Late deliveries were strongly associated with negative reviews.

VIP customers also showed higher negative review rates than other customer segments, including among on-time orders.

## Machine Learning Conclusion

The approved predictor set available immediately after payment confirmation did not provide sufficient predictive utility for a reliable late-delivery model.

The best-performing primary model remained close to random classification.

This result highlights the importance of evaluating:

- Data leakage
- Feature availability
- Synthetic data-generation rules
- Predictive signal
- Model reliability

rather than selecting a model only because it produces a high numerical score.

## Power BI Dashboard

The Power BI dashboard summarizes the project through three areas:

1. Sales
2. Delivery
3. Customer Satisfaction

The dashboard is designed as a simple business-facing summary of the analytical results.

## Repository Structure

```text
us-ecommerce-performance-analytics/
│
├── image/
├── python/
│   ├── late_delivery_analysis_main.ipynb
│   └── late_delivery_analysis_main.html
│
├── r/
│   ├── ecommerce_statistical_analysis.Rmd
│   └── ecommerce_statistical_analysis.html
│
├── sql/
│   ├── 00_database/
│   ├── 01_raw/
│   ├── 02_staging/
│   ├── 03_analytics/
│   ├── 04_analysis/
│   └── 05_modeling/
│
└── .gitignore
```

## Dataset

The project uses the Synthetic U.S. E-Commerce Dataset (2019-2025) available on Kaggle.

The raw dataset is not included in this repository because of its size.

## Limitations

This dataset is fully synthetic and contains several highly structured relationships that may reflect simulation rules rather than real-world e-commerce behavior.

Therefore:

- Results should not be interpreted as causal evidence
- Business recommendations should be validated using real-world transactional data
- High model performance should be reviewed carefully for potential leakage or synthetic artifacts

## Author

Siripaiboon Janpetch  
M.S. Data Analytics  
The University of Texas at San Antonio
