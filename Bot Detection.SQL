/* Step 1: Create Labeled Training Data
This query processes historical data to create a feature set for each traffic segment. It then calculates a bot_score based on a series of heuristic rules and assigns a bot_check label if the score exceeds a threshold. This table will be used to train the classification model.
*/
-- Creates a table with features and a ground-truth label ('bot_check') for model training.
CREATE OR REPLACE View `your-project-id.your-audit-dataset.bot_detection_training_data` AS
WITH
  -- 1. Preprocess raw event data into session-level metrics.
  cte_preprocessed AS (
    SELECT
      geo.country AS country,
      device.category AS device_category,
      traffic_source.medium AS traffic_medium,
      -- Engagement time in seconds
      SAFE_DIVIDE(
        SUM((SELECT value.int_value FROM UNNEST(event_params) WHERE key = "engagement_time_msec")), 1000
      ) AS engagement_time_seconds,
      -- Create a unique session identifier
      CONCAT(user_pseudo_id, CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = "ga_session_id") AS STRING)) AS session_id,
      user_pseudo_id,
      -- Count specific events per session
      SUM(CASE WHEN event_name = "page_view" THEN 1 ELSE 0 END) AS page_views,
      SUM(CASE WHEN event_name = "scroll" THEN 1 ELSE 0 END) AS scroll_events,
      SUM(CASE WHEN event_name = "purchase" THEN 1 ELSE 0 END) AS purchase_events
    FROM
      `your-project-id.your-dataset-id.events_*`
    WHERE
      -- Use a historical date range for training
      _TABLE_SUFFIX BETWEEN '20250701' AND '20250731'
    GROUP BY
      country, device_category, traffic_medium, session_id, user_pseudo_id
  ),
  -- 2. Aggregate session data into behavioral segments.
  aggregated AS (
    SELECT
      country,
      device_category,
      traffic_medium,
      COUNT(DISTINCT user_pseudo_id) AS total_users,
      SAFE_DIVIDE(SUM(engagement_time_seconds), COUNT(DISTINCT session_id)) AS avg_engagement_time_per_session,
      SAFE_DIVIDE(COUNT(DISTINCT session_id), COUNT(DISTINCT user_pseudo_id)) AS sessions_per_user,
      SUM(page_views) AS total_page_views,
      SUM(scroll_events) AS total_scroll_events,
      SUM(purchase_events) AS total_purchase_events
    FROM cte_preprocessed
    GROUP BY
      country, device_category, traffic_medium
    HAVING
      -- Filter out segments with very low traffic to ensure statistical significance
      COUNT(DISTINCT session_id) > 50
  )
-- 3. Calculate a heuristic bot score and final label.
SELECT
  *,
  -- Define the heuristic bot score based on a set of rules
  (
    CASE WHEN avg_engagement_time_per_session <= 10 THEN 3 ELSE 0 END
    + CASE WHEN sessions_per_user > 10 THEN 2 ELSE 0 END
    + CASE WHEN total_scroll_events = 0 THEN 2 ELSE 0 END
    + CASE WHEN traffic_medium IN ('(none)', 'direct', 'referral') THEN 1 ELSE 0 END
    -- Give negative points for legitimate user actions
    + CASE WHEN total_purchase_events > 0 THEN -5 ELSE 0 END
  ) AS bot_score,
  -- Assign the final label: 1 for bot, 0 for human
  CASE
    WHEN (
      CASE WHEN avg_engagement_time_per_session <= 10 THEN 3 ELSE 0 END
      + CASE WHEN sessions_per_user > 10 THEN 2 ELSE 0 END
      + CASE WHEN total_scroll_events = 0 THEN 2 ELSE 0 END
      + CASE WHEN traffic_medium IN ('(none)', 'direct', 'referral') THEN 1 ELSE 0 END
      + CASE WHEN total_purchase_events > 0 THEN -5 ELSE 0 END
    ) >= 5 THEN 1
    ELSE 0
  END AS bot_check
FROM
  aggregated;

/* Step 2: Train the Bot Detection Model
This query uses the labeled data from the previous step to train a LOGISTIC_REG model. The model learns the relationship between the behavioral features and the bot_check label.
*/

-- Creates a machine learning model to classify traffic segments as bots or not.
CREATE OR REPLACE MODEL `your-project-id.your-audit-dataset.bot_detection_model`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['bot_check']
) AS
SELECT
  -- The model will learn from these features
  country,
  device_category,
  traffic_medium,
  avg_engagement_time_per_session,
  sessions_per_user,
  total_page_views,
  total_scroll_events,
  -- The label the model is trying to predict
  bot_check
FROM
  `your-project-id.your-audit-dataset.bot_detection_training_data`;

/* Step 3: Generate and Filter Bot Detection Results
This final query uses the trained model to predict which traffic segments from a new date range are bots. The ML.PREDICT function applies the model, and the WHERE clause filters the results to show only the segments classified as bots.
*/

-- Use the trained model to predict on new data and show only the results flagged as bots.
SELECT
  *
FROM
  ML.PREDICT(
    MODEL `your-project-id.your-audit-dataset.bot_detection_model`,
    (
      -- This inner query gathers and aggregates the new data to be scored.
      -- The structure matches the training data but without the heuristic score/label.
      SELECT
        country,
        device_category,
        traffic_medium,
        COUNT(DISTINCT user_pseudo_id) AS total_users,
        SAFE_DIVIDE(SUM(engagement_time_seconds), COUNT(DISTINCT session_id)) AS avg_engagement_time_per_session,
        SAFE_DIVIDE(COUNT(DISTINCT session_id), COUNT(DISTINCT user_pseudo_id)) AS sessions_per_user,
        SUM(page_views) AS total_page_views,
        SUM(scroll_events) AS total_scroll_events
      FROM (
        SELECT
          geo.country AS country,
          device.category AS device_category,
          traffic_source.medium AS traffic_medium,
          SAFE_DIVIDE(
            SUM((SELECT value.int_value FROM UNNEST(event_params) WHERE key = "engagement_time_msec")), 1000
          ) AS engagement_time_seconds,
          CONCAT(user_pseudo_id, CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = "ga_session_id") AS STRING)) AS session_id,
          user_pseudo_id,
          SUM(CASE WHEN event_name = "page_view" THEN 1 ELSE 0 END) AS page_views,
          SUM(CASE WHEN event_name = "scroll" THEN 1 ELSE 0 END) AS scroll_events
        FROM
          `your-project-id.your-dataset-id.events_*`
        WHERE
          -- Use a recent date range for prediction
          _TABLE_SUFFIX BETWEEN '20250801' AND '20250831'
        GROUP BY
          country, device_category, traffic_medium, session_id, user_pseudo_id
      )
      GROUP BY
        country, device_category, traffic_medium
    )
  )
WHERE
  -- Filter to show only the traffic segments the model predicted as bots.
  predicted_bot_check = 1
ORDER BY
  -- Order by the probability score to see the most confident predictions first
  (SELECT prob FROM UNNEST(predicted_bot_check_probs) WHERE label = 1) DESC;
