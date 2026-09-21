# FitFlow Subscription Analytics — Retention & A/B Testing

[Lietuvių](#-lietuvių-kalba) | [English](#-english-version)

---

# 🇱🇹 Lietuvių kalba

## Projekto apžvalga

**FitFlow Subscription Analytics** – portfolio projektas, skirtas prenumeratų verslo analizei, daugiausia dėmesio skiriant **retention, cancellation/churn, vartotojų įsitraukimui ir A/B testavimui**.

Projektas imituoja SaaS / subscription verslo scenarijų: vartotojai registruojasi, naudojasi produktu, pradeda prenumeratas, jas atšaukia ir dalyvauja eksperimente. Analizė atlikta naudojant **PostgreSQL**, o galutinis dashboardas sukurtas su **Power BI**.

Duomenys yra **sintetiniai** ir buvo sugeneruoti specialiai šiam portfolio projektui.

## Tikslai

- Įvertinti bendrą subscription conversion rate.
- Išanalizuoti cancellation rate pagal prenumeratos planą.
- Patikrinti, kaip ankstyvas vartotojo engagement susijęs su cancellation.
- Įvertinti trial naudojimo ryšį su cancellation.
- Atlikti subscription cohort retention analizę.
- Įvertinti A/B eksperimento rezultatą ir statistinį reikšmingumą.

## Naudotos technologijos

- **PostgreSQL** – duomenų analizė, cohort logika, A/B testas, reporting views
- **SQL** – CTE, `CASE`, `EXISTS`, `GENERATE_SERIES`, `DATE_TRUNC`, `AGE`, agregacijos
- **Power BI** – dashboardas, KPI, cohort retention heatmap ir vizualizacijos
- **DAX** – KPI ir cancellation rate matavimai
- **Python** – sintetinių duomenų generavimas
- **DBeaver** – PostgreSQL užklausų kūrimas ir validacija

## Duomenų modelis

Projektą sudaro 7 pagrindinės šaltinio lentelės:

| Lentelė | Paskirtis |
|---|---|
| `users` | Vartotojų registracija, demografija ir acquisition informacija |
| `subscriptions` | Prenumeratos planas, pradžia, statusas ir atšaukimas |
| `payments` | Mokėjimų istorija ir mokėjimo statusas |
| `sessions` | Produkto naudojimo sesijos ir jų trukmė |
| `events` | Vartotojų elgsenos įvykiai |
| `experiments` | A/B eksperimento priskyrimas ir variantas |
| `marketing_spend` | Marketingo išlaidos, parodymai, paspaudimai ir installs |

Pagrindiniame Power BI retention / experiment dashboarde naudojamos `users`, `subscriptions`, `sessions` ir `experiments` lentelės. Ryšiai sukurti per `user_id`, naudojant **1-to-many** logiką nuo `users` lentelės.

## Pagrindiniai KPI

| KPI | Rezultatas |
|---|---:|
| Total Users | 100,000 |
| Subscribers | 27,142 |
| Subscription Conversion Rate | 27.14% |
| Cancellation Rate | 37.68% |

## Pagrindinės įžvalgos

### Cancellation rate pagal planą

| Planas | Cancellation Rate |
|---|---:|
| Monthly | 49.90% |
| Quarterly | 28.31% |
| Annual | 10.02% |

**Įžvalga:** ilgesnės trukmės planai turi ženkliai mažesnį cancellation rate. Monthly plano cancellation rate yra beveik 5 kartus didesnis nei Annual plano.

### Ankstyvas engagement ir cancellation

| Sesijos per pirmas 30 dienų | Cancellation Rate |
|---|---:|
| 0 | 41.17% |
| 1–2 | 38.82% |
| 3–5 | 36.93% |
| 6–10 | 34.28% |
| 11+ | 22.01% |

**Įžvalga:** didesnis ankstyvas produkto naudojimas yra susijęs su mažesniu cancellation rate. Tai yra **asociacija, o ne priežastinio ryšio įrodymas**.

### Trial naudojimas

| Trial | Cancellation Rate |
|---|---:|
| No Trial | 37.36% |
| Trial Used | 37.89% |

Skirtumas yra tik apie **0.53 procentinio punkto**, todėl šiame sintetiniame duomenų rinkinyje trial naudojimas neturi reikšmingo ryšio su cancellation.

### Cohort retention

Subscription cohort'ai formuojami pagal prenumeratos pradžios mėnesį. SQL logika:

- nustato `cohort_month`;
- sugeneruoja aktyvius prenumeratos mėnesius;
- apskaičiuoja `months_since_start`;
- suskaičiuoja retained users;
- apskaičiuoja `retention_rate`.

Power BI dashboarde rezultatas pateikiamas kaip **12 mėnesių cohort retention heatmap**.

### A/B testas – New Onboarding Flow

Vartotojas laikomas konvertavusiu, jei pradeda prenumeratą per **30 dienų nuo eksperimento priskyrimo datos**.

| Variant | Assigned Users | Converted Users | Conversion Rate |
|---|---:|---:|---:|
| Control | 15,068 | 3,692 | 24.50% |
| Variant_A | 14,932 | 3,586 | 24.02% |

Rezultatai:

- **Absolute uplift:** -0.49 pp
- **Relative uplift:** -1.99%
- **Z-score:** -0.983
- **95% CI:** -1.46 pp iki 0.48 pp
- **Statistical significance:** Not statistically significant

**Išvada:** Variant_A neparodė statistiškai reikšmingo subscription conversion pagerėjimo.

## Power BI dashboardas

Dashboarde pateikiama:

- Total Users
- Subscribers
- Subscription Conversion Rate
- Cancellation Rate
- Subscription Cohort Retention heatmap
- Cancellation Rate by Plan
- A/B Test Conversion Rate by Variant
- Absolute Uplift
- Relative Uplift
- Statistical Significance

> Dashboard screenshot'ą įkelkite kaip `images/dashboard.png`.

![Dashboard preview](images/dashboard.png)

## Reporting views

Sudėtingesnė analizės logika PostgreSQL pusėje paruošta kaip reusable views:

```sql
vw_cohort_retention
vw_ab_test_results
vw_ab_test_summary
```

Tai leidžia Power BI naudoti jau paruoštą reporting sluoksnį ir nedubliuoti sudėtingos analizės logikos DAX'e.

## SQL failai

```text
sql/
├── subscription_retention.sql
├── cohort_retention.sql
├── ab_testing.sql
└── create_analytics_views.sql
```

- `subscription_retention.sql` – subscription duration, cancellation by plan, trial vs cancellation, engagement vs cancellation.
- `cohort_retention.sql` – cohort retention ir retention milestones.
- `ab_testing.sql` – conversion rate, uplift, two-proportion z-test, 95% CI ir significance.
- `create_analytics_views.sql` – Power BI naudojami reporting views.

## Projekto struktūra

```text
fitflow-subscription-analytics/
│
├── data/
│   └── synthetic data files
├── sql/
│   ├── subscription_retention.sql
│   ├── cohort_retention.sql
│   ├── ab_testing.sql
│   └── create_analytics_views.sql
├── images/
│   └── dashboard.png
├── powerbi/
│   └── FitFlow_Subscription_Analytics.pbix
├── data_generation/
│   └── generate_data.py
└── README.md
```

## Analitinis workflow

```text
Python synthetic data generation
            ↓
PostgreSQL
            ↓
SQL analysis
            ↓
Reporting Views
            ↓
Power BI Data Model
            ↓
DAX + Visualizations
            ↓
Retention & Experiment Dashboard
```

## Duomenų validacija

Buvo tikrinama:

- `user_id` duomenų tipų suderinamumas;
- datų tipai ir NULL reikšmės;
- subscription status reikšmės;
- cohort month 0 retention;
- ar `retained_users <= cohort_size`;
- A/B testo vartotojų skaičius pagal variantą;
- ar SQL ir Power BI KPI rezultatai sutampa.

## Apribojimai

- Duomenys yra sintetiniai ir neatspindi realios įmonės klientų.
- Engagement ir cancellation analizė rodo asociaciją, bet ne priežastinį ryšį.
- A/B testas vertina vieną conversion metric – subscription pradžią per 30 dienų.
- Rezultatai skirti demonstruoti analitinį workflow, o ne realias verslo prognozes.

## Demonstruojami įgūdžiai

- SQL duomenų analizė
- Cohort retention analizė
- Subscription / churn analizė
- A/B testavimo logika
- Statistinio reikšmingumo interpretacija
- Power BI duomenų modeliavimas
- DAX KPI kūrimas
- SQL reporting layer kūrimas naudojant views
- Duomenų validacija
- Verslo įžvalgų formulavimas

---

# 🇬🇧 English version

## Project overview

**FitFlow Subscription Analytics** is a portfolio project focused on subscription business analytics, with emphasis on **retention, cancellation/churn, user engagement, and A/B testing**.

The project simulates a SaaS / subscription business scenario in which users sign up, interact with the product, start subscriptions, cancel them, and participate in an experiment. The analysis was performed in **PostgreSQL**, while the final dashboard was built in **Power BI**.

The dataset is **synthetic** and was generated specifically for this portfolio project.

## Objectives

- Measure overall subscription conversion.
- Analyze cancellation rate by subscription plan.
- Evaluate the relationship between early engagement and cancellation.
- Assess trial usage vs cancellation.
- Perform subscription cohort retention analysis.
- Evaluate an A/B experiment and its statistical significance.

## Tech stack

- **PostgreSQL** – analysis, cohort logic, A/B testing, reporting views
- **SQL** – CTEs, `CASE`, `EXISTS`, `GENERATE_SERIES`, `DATE_TRUNC`, `AGE`, aggregations
- **Power BI** – dashboard, KPIs, cohort retention heatmap, visualizations
- **DAX** – core KPIs and cancellation-rate measures
- **Python** – synthetic data generation
- **DBeaver** – PostgreSQL development and validation

## Data model

The project contains 7 main source tables:

| Table | Purpose |
|---|---|
| `users` | User signup, demographics, and acquisition data |
| `subscriptions` | Subscription plan, start date, status, and cancellation |
| `payments` | Payment history and payment status |
| `sessions` | Product usage sessions and duration |
| `events` | User behavior events |
| `experiments` | A/B experiment assignment and variant |
| `marketing_spend` | Marketing spend, impressions, clicks, and installs |

The main Power BI retention / experiment dashboard uses `users`, `subscriptions`, `sessions`, and `experiments`. Relationships are built through `user_id`, using **one-to-many** relationships from the `users` table.

## Core KPIs

| KPI | Result |
|---|---:|
| Total Users | 100,000 |
| Subscribers | 27,142 |
| Subscription Conversion Rate | 27.14% |
| Cancellation Rate | 37.68% |

## Key insights

### Cancellation rate by plan

| Plan | Cancellation Rate |
|---|---:|
| Monthly | 49.90% |
| Quarterly | 28.31% |
| Annual | 10.02% |

**Insight:** longer-term plans show substantially lower cancellation rates. The Monthly plan has almost five times the cancellation rate of the Annual plan.

### Early engagement vs cancellation

| Sessions in first 30 days | Cancellation Rate |
|---|---:|
| 0 | 41.17% |
| 1–2 | 38.82% |
| 3–5 | 36.93% |
| 6–10 | 34.28% |
| 11+ | 22.01% |

**Insight:** stronger early product engagement is associated with lower cancellation. This is an **association, not proof of causation**.

### Trial usage

| Trial | Cancellation Rate |
|---|---:|
| No Trial | 37.36% |
| Trial Used | 37.89% |

The difference is only around **0.53 percentage points**, suggesting no meaningful relationship between trial usage and cancellation in this synthetic dataset.

### Cohort retention

Subscription cohorts are defined by subscription start month. The SQL logic:

- assigns `cohort_month`;
- generates active subscription months;
- calculates `months_since_start`;
- counts retained users;
- calculates `retention_rate`.

The final Power BI dashboard displays a **12-month cohort retention heatmap**.

### A/B test – New Onboarding Flow

A user is considered converted if they start a subscription within **30 days after experiment assignment**.

| Variant | Assigned Users | Converted Users | Conversion Rate |
|---|---:|---:|---:|
| Control | 15,068 | 3,692 | 24.50% |
| Variant_A | 14,932 | 3,586 | 24.02% |

Results:

- **Absolute uplift:** -0.49 pp
- **Relative uplift:** -1.99%
- **Z-score:** -0.983
- **95% CI:** -1.46 pp to 0.48 pp
- **Statistical significance:** Not statistically significant

**Conclusion:** Variant_A did not produce a statistically significant improvement in subscription conversion.

## Power BI dashboard

The dashboard includes:

- Total Users
- Subscribers
- Subscription Conversion Rate
- Cancellation Rate
- Subscription Cohort Retention heatmap
- Cancellation Rate by Plan
- A/B Test Conversion Rate by Variant
- Absolute Uplift
- Relative Uplift
- Statistical Significance

> Store the dashboard screenshot as `images/dashboard.png`.

![Dashboard preview](images/dashboard.png)

## Reporting views

More complex analytical logic is prepared in PostgreSQL as reusable reporting views:

```sql
vw_cohort_retention
vw_ab_test_results
vw_ab_test_summary
```

This keeps complex analytical transformations in the database layer and avoids duplicating the same logic in DAX.

## SQL files

```text
sql/
├── subscription_retention.sql
├── cohort_retention.sql
├── ab_testing.sql
└── create_analytics_views.sql
```

- `subscription_retention.sql` – subscription duration, cancellation by plan, trial vs cancellation, engagement vs cancellation.
- `cohort_retention.sql` – cohort retention and retention milestones.
- `ab_testing.sql` – conversion rate, uplift, two-proportion z-test, 95% CI, and significance.
- `create_analytics_views.sql` – reporting views used by Power BI.

## Project structure

```text
fitflow-subscription-analytics/
│
├── data/
│   └── synthetic data files
├── sql/
│   ├── subscription_retention.sql
│   ├── cohort_retention.sql
│   ├── ab_testing.sql
│   └── create_analytics_views.sql
├── images/
│   └── dashboard.png
├── powerbi/
│   └── FitFlow_Subscription_Analytics.pbix
├── data_generation/
│   └── generate_data.py
└── README.md
```

## Analytical workflow

```text
Python synthetic data generation
            ↓
PostgreSQL
            ↓
SQL analysis
            ↓
Reporting Views
            ↓
Power BI Data Model
            ↓
DAX + Visualizations
            ↓
Retention & Experiment Dashboard
```

## Data validation

Validation checks included:

- matching `user_id` data types;
- date types and NULL values;
- subscription status values;
- month 0 cohort retention;
- ensuring `retained_users <= cohort_size`;
- experiment sample sizes by variant;
- matching SQL and Power BI KPI results.

## Limitations

- The dataset is synthetic and does not represent real customer behavior.
- Engagement vs cancellation shows association, not causality.
- The A/B test evaluates one conversion metric: starting a subscription within 30 days.
- Results demonstrate an analytical workflow rather than real business forecasts.

## Skills demonstrated

- SQL data analysis
- Cohort retention analysis
- Subscription / churn analysis
- A/B testing methodology
- Statistical significance interpretation
- Power BI data modeling
- DAX KPI development
- SQL reporting-layer design using views
- Data validation
- Translating analysis into business insights
