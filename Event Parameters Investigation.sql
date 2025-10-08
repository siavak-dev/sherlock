SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  event_name,
  param.key AS param_key,
  param.value.string_value AS param_value
FROM
  `your-project-id.your-dataset-id.events_*`,
  UNNEST(event_params) AS param
WHERE
  _TABLE_SUFFIX BETWEEN '20250801' AND '20250831' -- Replace with your date range
  AND (LENGTH(param.key) > 40 OR LENGTH(param.value.string_value) > 100)
  -- Exclude common long-value parameters to reduce noise
  AND param.key NOT IN ('page_title', 'page_referrer', 'page_location')
GROUP BY -- Use GROUP BY to get distinct violating parameters
  event_date,
  event_name,
  param_key,
  param_value
ORDER BY
  event_date;
