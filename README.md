
# Sherlock: Foundational GA4 BigQuery Audits

This repository contains a set of foundational **SQL queries** for auditing the health and quality of your **Google Analytics 4 (GA4)** data exported to **BigQuery**.

These audits are provided as a starting point for any organization looking to build a more reliable and trustworthy analytics foundation.

---

## The Challenge: Ensuring GA4 Data Reliability

As businesses increasingly rely on GA4 for critical decision-making, the integrity of the underlying data becomes paramount. Undetected issues—such as tracking implementation errors, consent management gaps, or unexpected changes in user behavior—can silently corrupt datasets, leading to flawed analysis and poor business outcomes.

Manual data validation is not scalable. A systematic, automated approach is required to move from reactive problem-solving to **proactive data quality assurance**.

---

## About These Queries

The SQL files in this repository represent a set of standard, **unoptimized audits**. They are designed to be run directly in the BigQuery console to provide an immediate snapshot of common data quality issues.

⚠️ **Important Note: Cost Warning**
These queries are provided for educational purposes to demonstrate foundational audit principles. They are **not cost-optimized** and are designed to run over your **raw `events_*` table**. Running them frequently on large datasets can result in significant query costs.

---

## The Audits Included

| File Name | Description |
| :--- | :--- |
| `consent_analysis.sql` | Analyzes the **consent status** (`analytics_storage`) of your users to understand the impact of privacy settings on your data volume. |
| `duplicate_pageviews.sql` | Identifies instances where `page_view` events may have been fired multiple times for a single user at the exact same timestamp. |
| `gads_misattribution.sql` | Finds sessions with a Google Ads Click ID (`gclid`) that are not correctly attributed to the `"google / cpc"` source/medium, a common sign of tracking issues. |
| `null_identifiers.sql` | Flags events that are missing a **`user_pseudo_id`** or **`ga_session_id`**, which can break sessionization and user analysis. |
| `parameter_length.sql` | Scans for event and user parameters that **exceed GA4's documented length limits**, which can result in data loss. |

---

## How to Use

1.  Navigate to one of the SQL files in this repository.
2.  **Copy** the entire query.
3.  Go to the **BigQuery SQL workspace** in your Google Cloud project.
4.  **Paste** the query.
5.  **Crucially:** Replace the placeholder table name (e.g., `your-project.your-dataset.events_*`) with the **full path** to your own GA4 event export table.
6.  Run the query and analyze the results.

---

## The Limitations of Manual Auditing

While these queries provide valuable initial insights, they illustrate the challenges of relying on manual processes for enterprise-scale data quality monitoring:

* **High Operational Cost:** Each query scans the entire raw event table, making frequent, comprehensive auditing prohibitively expensive.
* **Lack of Automation:** Manual execution is time-consuming and inconsistent, leading to gaps in monitoring.
* **No Proactive Alerting:** Findings are passive. Your team must remember to run the queries and manually interpret the results to discover issues.
* **Limited Scope:** These simple, rule-based checks cannot detect **statistical anomalies** (e.g., a sudden 50% drop in purchases from a specific country) or identify new, emerging trends in your data.

---

## The Next Step: Enterprise-Grade GA4 Monitoring & Alerts

These manual queries highlight the need for a more sophisticated system. An enterprise-grade solution transforms these basic checks into a **cost-optimized, automated, and proactive monitoring pipeline.**

**We built Sherlock to be that solution.**

Sherlock is a fully-managed, end-to-end service that provides a robust framework for GA4 data quality and anomaly detection.

The Sherlock service delivers:

* **Cost Optimization:** A sophisticated Dataform pipeline processes your raw data only once, creating a clean, aggregated base layer for all audits and reducing query costs by over **90%**.
* **Full Automation:** The entire pipeline is event-driven, running automatically as new GA4 data arrives.
* **Real-Time, Contextual Alerting:** Get detailed summaries of all findings—from data quality errors to statistical anomalies—delivered directly to your Google Chat or Slack.
* **Advanced ML Models:** Sherlock includes powerful, pre-built BQML models for bot detection and multi-series ARIMA+ models for anomaly detection across all your key metrics and dimensions.
* **Emerging Trend Analysis:** The system automatically discovers and alerts you to **new countries, landing pages, or traffic sources** as they appear in your data for the first time.

### Build a Reliable Analytics Foundation

Manual checks are a great start, but enterprise data requires an enterprise solution. Visit our landing page to learn more about the Sherlock service and how it can provide the confidence you need in your GA4 data.

➡️ **Learn more about Sherlock at [analyticsdetectives.com/sherlock](https://analyticsdetectives.com/sherlock)**
