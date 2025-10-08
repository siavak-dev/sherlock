
/* Step 1: Create a Daily Time-Series Table
This query aggregates your raw data into a clean, daily time series. The ARIMA_PLUS model requires a table with a timestamp column and a numeric data column.
*/

-- Creates a table with daily counts of a specific event, which will be the input for the time-series model.
CREATE OR REPLACE View `your-project-id.your-audit-dataset.daily_purchase_counts` AS
WITH
  -- 1. Create a complete date range to ensure no days are missing.
  date_range AS (
    SELECT
      day AS event_date
    FROM
      UNNEST(GENERATE_DATE_ARRAY(
        '2024-08-01', -- Start date should be far enough in the past for robust training.
        '2025-08-31', -- End date for the analysis.
        INTERVAL 1 DAY)
      ) AS day
  ),
  -- 2. Count the number of 'purchase' events per day.
  event_counts AS (
    SELECT
      PARSE_DATE('%Y%m%d', event_date) AS event_date,
      COUNT(event_name) AS event_count
    FROM
      `your-project-id.your-dataset-id.events_*`
    WHERE
      event_name = 'purchase'
    GROUP BY
      event_date
  )
-- 3. Left join the counts to the date range to fill in missing days with 0.
SELECT
  d.event_date,
  IFNULL(e.event_count, 0) AS event_count
FROM
  date_range AS d
LEFT JOIN
  event_counts AS e
  ON d.event_date = e.event_date
ORDER BY
  d.event_date;

/* Step 2: Train the Anomaly Detection Model
This query creates and trains an ARIMA_PLUS model on the daily time-series data. This type of model is specifically designed to understand trends, seasonality, and normal fluctuations in time-series data.
*/

-- Creates a time-series model to learn the normal pattern of daily purchase events.
CREATE OR REPLACE MODEL `your-project-id.your-audit-dataset.purchase_anomaly_model`
OPTIONS(
  MODEL_TYPE = 'ARIMA_PLUS',
  TIME_SERIES_TIMESTAMP_COL = 'event_date',
  TIME_SERIES_DATA_COL = 'event_count',
  DATA_FREQUENCY = 'DAILY',
  HOLIDAY_REGION = 'US' -- Optional: Specify a holiday region to improve accuracy
) AS
SELECT
  event_date,
  event_count
FROM
  `your-project-id.your-audit-dataset.daily_purchase_counts`;

/* Step 3: Detect and Display Anomalies
This final query uses the trained model to analyze the time series and flag any data points that fall outside the expected range (the confidence interval). The WHERE clause filters the results to show only the dates where an anomaly was detected, providing context by showing the values from the previous week and month.
*/

-- Use the trained model to detect anomalies and show only the anomalous days.
SELECT
  a.event_date,
  a.event_count AS actual_value,
  -- The model provides an expected range (lower and upper bounds).
  ROUND(a.lower_bound, 2) AS expected_lower_bound,
  ROUND(a.upper_bound, 2) AS expected_upper_bound,
  -- Historical context for comparison
  LAG(a.event_count, 7) OVER (ORDER BY a.event_date) AS value_7_days_ago,
  LAG(a.event_count, 28) OVER (ORDER BY a.event_date) AS value_28_days_ago
FROM
  ML.DETECT_ANOMALIES(
    MODEL `your-project-id.your-audit-dataset.purchase_anomaly_model`,
    -- The threshold determines sensitivity. 0.95 is a common starting point.
    STRUCT(0.95 AS anomaly_prob_threshold)
  ) AS a
WHERE
  -- Filter to show only the dates that the model flagged as anomalies.
  a.is_anomaly = TRUE
ORDER BY
  a.event_date DESC;
