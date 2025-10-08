+ Lead gen + Recommended events
+ 0 as minimum lower bound
  

-- Step 1: Prepare E-commerce Time-Series Data with Ranks
-- Creates a table containing daily counts and overall rank for key e-commerce events.
-- Creates a table containing daily counts and overall rank for a combined list of events.
-- Creates a table containing daily counts and overall rank for a combined list of events.
CREATE OR REPLACE TABLE `siavak.svk_audit2.combined_events_daily_data` AS
WITH
  -- List A: Define the specific list of key e-commerce events to ensure they are included.
  EcommerceEventsList AS (
    SELECT event_name FROM UNNEST([
      'purchase',
      'add_to_cart',
      'begin_checkout',
      'view_item',
      'sign_up',
      'add_shipping_info',
      'add_payment_info'
    ]) AS event_name
  ),

  -- List B: Identify the overall top 10 most frequent events from the raw data.
  Top10Events AS (
    SELECT
      event_name
    FROM
      `siavak.analytics_340407319.events_*`
    WHERE
      -- Ensure date range matches the data collection period below.
      _TABLE_SUFFIX BETWEEN '20250101' AND '20250831'
    GROUP BY
      event_name
    ORDER BY
      COUNT(*) DESC
    LIMIT 10
  ),

  -- Combine List A and List B into a single master list.
  -- UNION DISTINCT ensures that if an event is in both lists (e.g., 'purchase' is top 10),
  -- it only appears once in the final target list.
  TargetEvents AS (
    SELECT event_name FROM EcommerceEventsList
    UNION DISTINCT
    SELECT event_name FROM Top10Events
  ),

  -- 4. Create a complete date range for the analysis period.
  DateRange AS (
    SELECT day AS event_date
    FROM UNNEST(GENERATE_DATE_ARRAY(
        PARSE_DATE('%Y%m%d', '20250101'), -- Start date for training data
        PARSE_DATE('%Y%m%d', '20250831'), -- End date for analysis
        INTERVAL 1 DAY)) AS day
  ),

  -- 5. Calculate daily event counts for ALL events first.
  AllDailyCounts AS (
    SELECT
      PARSE_DATE('%Y%m%d', event_date) AS event_date,
      event_name,
      COUNT(*) AS event_count
    FROM
      `siavak.analytics_340407319.events_*`
    WHERE
      _TABLE_SUFFIX BETWEEN '20250101' AND '20250831'
    GROUP BY
      event_date, event_name
  ),

  -- 6. Filter counts using an explicit JOIN against the combined TargetEvents list.
  FilteredDailyCounts AS (
    SELECT
      counts.event_date,
      counts.event_name,
      counts.event_count
    FROM AllDailyCounts AS counts
    JOIN TargetEvents AS targets
      ON counts.event_name = targets.event_name
  ),

  -- 7. Calculate overall rank based on total event volume in the period.
  EventRanks AS (
    SELECT
      event_name,
      SUM(event_count) AS total_count,
      RANK() OVER (ORDER BY SUM(event_count) DESC) AS event_rank
    FROM FilteredDailyCounts
    GROUP BY event_name
  ),

  -- 8. Generate a base grid of every target event for every single day.
  BaseGrid AS (
    SELECT event_date, event_name FROM DateRange CROSS JOIN TargetEvents
  )

-- 9. Join actual counts and ranks to the base grid to create the final training data.
SELECT
  g.event_date,
  g.event_name,
  IFNULL(e.event_count, 0) AS event_count,
  r.event_rank
FROM BaseGrid AS g
LEFT JOIN FilteredDailyCounts AS e
  ON g.event_date = e.event_date AND g.event_name = e.event_name
LEFT JOIN EventRanks AS r
  ON g.event_name = r.event_name;
/* Step 2: Train the Multi-Series Anomaly Detection Model
This step trains the ARIMA_PLUS model using the curated e-commerce event data from Step 1. The model learns the individual seasonal patterns and trends for each event type specified.
*/

-- Creates one model to forecast all specified e-commerce time series.
-- Creates one model to forecast all specified event time series.
CREATE OR REPLACE MODEL `siavak.svk_audit2.combined_events_anomaly_model`
OPTIONS(
  MODEL_TYPE = 'ARIMA_PLUS',
  TIME_SERIES_TIMESTAMP_COL = 'event_date',
  TIME_SERIES_DATA_COL = 'event_count',
  TIME_SERIES_ID_COL = 'event_name' -- Groups forecasts by event name
) AS
SELECT
  event_date,
  event_name,
  event_count
FROM
  `siavak.svk_audit2.combined_events_daily_data`;

/* Step 3: Generate Full Results with Anomaly Flags and Ranks
This final query uses the trained model to generate predictions for every day. Unlike previous versions, it does not filter out normal days. Instead, it includes the boolean is_anomaly column, allowing you to display both normal operating ranges and flagged anomalies in a dashboard.
*/


-- Detects anomalies and returns all data points (normal and anomalous)
-- with the new rank and boolean flag columns.
-- Detects anomalies and returns all data points (normal and anomalous)
-- with the new rank and boolean flag columns.
-- Detects anomalies and returns all data points (normal and anomalous)
-- with the rank and boolean flag columns.
SELECT
  CAST(a.event_date AS DATE) AS event_date, -- Cast here for consistent output format
  a.event_name,
  r.event_rank,
  a.is_anomaly, -- Boolean flag (TRUE/FALSE) for anomaly status
  a.event_count AS actual_value,
  ROUND(a.lower_bound, 2) AS expected_lower_bound,
  ROUND(a.upper_bound, 2) AS expected_upper_bound,
  a.anomaly_probability
FROM
  ML.DETECT_ANOMALIES(
    MODEL `siavak.svk_audit2.combined_events_anomaly_model`,
    STRUCT(0.95 AS anomaly_prob_threshold) -- Confidence level for detection
  ) AS a
JOIN
  `siavak.svk_audit2.combined_events_daily_data` AS r
  ON CAST(a.event_date AS DATE) = r.event_date
  AND a.event_name = r.event_name
ORDER BY
  a.event_date DESC,
  r.event_rank ASC;
