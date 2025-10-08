SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  event_name,
  COUNTIF((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NULL) AS missing_session_id_count,
  COUNTIF(user_pseudo_id IS NULL) AS missing_user_pseudo_id_count
FROM
  `your-project-id.your-dataset-id.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20250801' AND '20250831' -- Replace with your date range
GROUP BY
  event_date,
  event_name
HAVING
  missing_session_id_count > 0 OR missing_user_pseudo_id_count > 0
ORDER BY
  event_date,
  missing_session_id_count DESC;
