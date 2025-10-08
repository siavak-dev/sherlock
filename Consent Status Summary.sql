DECLARE
  start_date STRING DEFAULT '2024-02-01';
DECLARE
  end_date STRING DEFAULT '2024-07-11';
WITH
  ConsentStatus AS (
    SELECT
      privacy_info.analytics_storage
    FROM
      `your_project.your_dataset.ga4_events_obfuscated`
    WHERE
      _TABLE_SUFFIX BETWEEN REPLACE(start_date, '-', '')
      AND REPLACE(end_date, '-', '')
  )
SELECT
  CASE
    WHEN COUNTIF(analytics_storage = 'Yes') > 0
    AND COUNTIF(analytics_storage = 'No') > 0 THEN 'Advanced'
    WHEN COUNTIF(analytics_storage = 'Yes') > 0
    AND COUNTIF(analytics_storage = 'No') = 0 THEN 'Basic'
    ELSE 'Not Implemented'
  END AS consent_mode_status
FROM
  ConsentStatus;
