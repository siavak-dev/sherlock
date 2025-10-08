SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  -- Combine source and medium for easier analysis
  CONCAT(collected_traffic_source.manual_source, ' / ', collected_traffic_source.manual_medium) AS session_source_medium,
  -- Find the first page location for the session
  FIRST_VALUE((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location')) OVER (
    PARTITION BY user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')
    ORDER BY event_timestamp
  ) AS landing_page,
  COUNT(DISTINCT CONCAT(user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id'))) AS misattributed_sessions,
  COUNT(DISTINCT user_pseudo_id) AS distinct_users
FROM
  `your-project-id.your-dataset-id.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20250801' AND '20250831' -- Replace with your date range
  -- Find events with a gclid
  AND collected_traffic_source.gclid IS NOT NULL
  -- Filter for sessions NOT attributed to Google Ads
  AND CONCAT(collected_traffic_source.manual_source, ' / ', collected_traffic_source.manual_medium) != 'google / cpc'
GROUP BY
  event_date,
  session_source_medium,
  landing_page
ORDER BY
  event_date,
  misattributed_sessions DESC;
