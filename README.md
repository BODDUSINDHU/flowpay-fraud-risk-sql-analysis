# flowpay-fraud-risk-sql-analysis
End-to-end SQL fraud analytics project covering fraud detection, risk scoring, merchant intelligence, payment analysis, and transaction monitoring.
# FlowPay Fraud Risk & Revenue Leakage Analysis

## 📌 Project Overview

FlowPay Fraud Risk & Revenue Leakage Analysis is an end-to-end SQL analytics project focused on identifying fraud patterns, revenue leakage, operational risks, and user behavior anomalies in a fintech payment ecosystem.

The project simulates a real-world digital payments platform and investigates:

* Fraudulent transactions
* Payment failures
* Refund leakage
* Retry recovery behavior
* Velocity abuse
* Device anomalies
* Impossible travel patterns
* Merchant-level risk
* Revenue retention
* User risk scoring

The analysis was built entirely using PostgreSQL and advanced SQL concepts including:

* CTEs
* Window Functions
* Aggregations
* Segmentation
* Views
* Risk Scoring Logic
* Funnel Analytics

---

# 🎯 Business Problem

Digital payment platforms lose revenue due to:

* Failed transactions
* Fraudulent activity
* Refund abuse
* High-risk users
* Operational inefficiencies

The goal of this project is to:

1. Quantify revenue leakage
2. Detect risky behavioral patterns
3. Segment users and merchants by risk
4. Measure retry recovery impact
5. Build a rule-based fraud risk scoring model

---

# 🛠 Tech Stack

* PostgreSQL
* pgAdmin 4
* SQL
* GitHub

---

# 🗂 Database Schema

The project contains the following core tables:

| Table         | Description                 |
| ------------- | --------------------------- |
| users         | Customer information        |
| merchants     | Merchant metadata           |
| devices       | User-device mapping         |
| transactions  | Payment transaction records |
| refunds       | Refund transaction data     |
| fraud_reports | Fraud case reports          |

---

# 📊 Key Analysis Areas

## 1️⃣ Revenue Leakage Analysis

Measured:

* Attempted payment volume
* Success revenue
* Failed transaction loss
* Fraud loss
* Refund leakage
* Net revenue retention

### Key Findings

* Total attempted revenue: ₹5.65B
* Net retained revenue: ₹4.84B
* Failure loss rate: 9.95%
* Fraud loss rate: 2.41%
* Refund rate: 2.22%
* Final revenue retention: 85.69%

---

## 2️⃣ Payment Method Risk Analysis

Compared:

* UPI
* Credit Card
* Debit Card
* Wallet

### Findings

* Credit Cards showed the highest failure rates
* UPI generated the largest payment volume
* Wallets had elevated refund rates
* All methods retained ~85% revenue efficiency

---

## 3️⃣ Merchant Category Risk Analysis

Analyzed:

* Fraud rate
* Refund rate
* Failure rate
* Net revenue retention

### High-Risk Categories

* Gaming → highest refund rate
* Real Estate → elevated fraud risk
* Utilities → highest failure rate
* Jewelry → high refund leakage

---

## 4️⃣ User Segmentation Analysis

Users segmented into:

* 💎 Valuable Users
* 🚨 High Value - Low Activity
* 🤖 High Activity - Low Value
* 🟢 Normal Users

### Findings

* Valuable users showed strong retention (~88%)
* High Activity–Low Value users showed the worst efficiency
* High-value users had the lowest fraud rates

---

## 5️⃣ Multi-Device User Analysis

Users segmented by device usage:

* Normal (1–2 devices)
* Watchlist (3 devices)
* Suspicious (4+ devices)

### Findings

* 6.17% of users used 4+ devices
* Multi-device users contributed over ₹327M revenue
* Suspicious users showed elevated fraud exposure

---

## 6️⃣ Multi-City & Impossible Travel Detection

Detected users transacting from multiple cities within unrealistic time windows.

### Findings

* 699 users showed suspicious travel behavior
* 3 users showed extreme impossible-travel activity
* High-risk travelers had elevated fraud rates

---

## 7️⃣ Velocity Analysis

Two separate velocity frameworks were built:

### A. Time-Gap Velocity Detection

Detected rapid bursts of transactions within 5-minute windows.

### Findings

* Medium velocity users had 12.68% failure rates
* High velocity bursts were rare but operationally risky

### B. System Velocity Flag Analysis

Used platform-generated velocity flags.

### Findings

* 4.36% users classified as high velocity
* Medium velocity users drove large transaction volumes

---

## 8️⃣ Retry Behavior Analysis

Tracked failed transactions that were retried successfully.

### Findings

* Retry users contributed ~64% of platform revenue
* High retry users had elevated failure rates
* Retry recovery reclaimed ₹140.58M revenue

---

## 9️⃣ Retry Recovery & Failure Loss

Measured how much failed revenue was recovered through retries.

### Results

* Total failed amount: ₹562.13M
* Retry recovered amount: ₹140.58M
* Recovery rate: 25.01%
* Unrecovered loss: ₹421.55M

---

# 🔥 Fraud Intelligence

## Fraud Type Distribution

Top fraud categories:

| Fraud Type       | Share  |
| ---------------- | ------ |
| Account Takeover | 22.55% |
| Identity Theft   | 15.82% |
| Device Spoofing  | 15.58% |
| Card Not Present | 15.53% |

---

# 🔁 Refund Intelligence

## Refund Reason Distribution

Top refund drivers:

| Refund Reason            | Share  |
| ------------------------ | ------ |
| Wrong Amount Charged     | 22.64% |
| Duplicate Transaction    | 19.10% |
| Merchant Error           | 14.01% |
| Unauthorized Transaction | 13.95% |

---

# ⚠️ Risk Scoring Model

A final rule-based fraud scoring model was developed using:

* Fraud history
* Failure rate
* Velocity behavior
* Retry behavior
* Device usage
* City anomalies
* User segment behavior

### Risk Levels

| Risk Level     | Users  |
| -------------- | ------ |
| 🚨 High Risk   | 3,573  |
| 🟡 Medium Risk | 11,060 |
| 🟢 Low Risk    | 10,367 |

### Validation Results

| Risk Level     | Fraud User Rate |
| -------------- | --------------- |
| 🚨 High Risk   | 69.02%          |
| 🟡 Medium Risk | 64.86%          |
| 🟢 Low Risk    | 0%              |

The scoring model successfully concentrated fraud users into higher-risk buckets.

---

# 📈 Major Business Insights

* Payment failures are the largest source of revenue leakage
* Retry recovery recovers 25% of failed revenue
* Velocity abuse correlates strongly with operational failure risk
* Multi-device behavior is a strong fraud indicator
* Impossible travel events are rare but highly suspicious
* High-value users are operationally healthier
* Gaming and Real Estate categories require enhanced monitoring
* Fraud concentration is highly visible in high-risk scored users

---

# ✅ Business Recommendations

## Fraud Prevention

* Add stricter controls for velocity spikes
* Monitor multi-device users aggressively
* Implement impossible-travel detection rules
* Add stronger authentication for account takeover patterns

## Revenue Optimization

* Improve payment retry infrastructure
* Reduce duplicate transaction refunds
* Strengthen payment gateway reliability
* Prioritize recovery workflows for failed payments

## Merchant Monitoring

* Flag high-risk merchant categories
* Monitor refund-heavy merchants
* Apply category-based risk thresholds

## Risk Scoring

* Deploy real-time user risk scoring
* Use dynamic fraud thresholds
* Trigger manual review for high-risk users

---

# 📚 SQL Concepts Used

This project demonstrates:

* CTEs
* Window Functions
* CASE WHEN logic
* FILTER clauses
* Aggregate analytics
* Segmentation logic
* Risk modeling
* View creation
* KPI calculations
* Funnel analysis

---

# 🚀 Future Improvements

Potential extensions:

* Machine Learning fraud prediction
* Real-time streaming analytics
* Dashboard integration (Power BI/Tableau)
* Time-series anomaly detection
* Merchant risk scoring
* Device fingerprint intelligence

---

# 👨‍💻 Author

Sindhu
Data Analytics / Fraud Analytics Project
