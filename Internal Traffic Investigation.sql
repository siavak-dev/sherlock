SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'traffic_type') AS traffic_type,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS user_count
FROM
  `your-project-id.your-dataset-id.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20250801' AND '20250831' -- Replace with your date range
  AND (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'traffic_type') = 'internal'
GROUP BY
  event_date,
  traffic_type
ORDER BY
  event_date;
