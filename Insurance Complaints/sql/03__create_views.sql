-------
CREATE VIEW dbo.vw_Backlog AS
WITH LatestStatus AS (
    SELECT sh.ComplaintID, sh.ComplaintStatusID, sh.StatusDate,
           ROW_NUMBER() OVER (PARTITION BY sh.ComplaintID ORDER BY sh.StatusDate DESC) AS rn
    FROM dbo.StatusHistoryData sh
)
SELECT cd.ID AS ComplaintID, st.Description AS CurrentStatus, ls.StatusDate
FROM LatestStatus ls
JOIN dbo.Statuses st       ON ls.ComplaintStatusID = st.ID
JOIN dbo.ComplainsData cd  ON ls.ComplaintID = cd.ID
WHERE ls.rn = 1
  AND st.Description IN ('IN PROGRESS','OUTSTANDING');


  ---
  SELECT DISTINCT Description FROM dbo.Categories WHERE Description LIKE 'DISCLAIMER%';



  --
  ALTER VIEW dbo.vw_Backlog AS
WITH LatestStatus AS (
    SELECT sh.ComplaintID, sh.ComplaintStatusID, sh.StatusDate,
           ROW_NUMBER() OVER (PARTITION BY sh.ComplaintID ORDER BY sh.StatusDate DESC) AS rn
    FROM dbo.StatusHistoryData sh
),
AsOf AS (SELECT MAX(StatusDate) AS AsOfDate FROM dbo.StatusHistoryData)
SELECT
    cd.ID AS ComplaintID,
    st.Description AS CurrentStatus,
    ls.StatusDate,
    DATEDIFF(DAY, ls.StatusDate, AsOf.AsOfDate) AS DaysInCurrentStatus,
    CASE
        WHEN DATEDIFF(DAY, ls.StatusDate, AsOf.AsOfDate) BETWEEN 31 AND 90  THEN '31-90 days'
        WHEN DATEDIFF(DAY, ls.StatusDate, AsOf.AsOfDate) BETWEEN 91 AND 180 THEN '91-180 days'
        WHEN DATEDIFF(DAY, ls.StatusDate, AsOf.AsOfDate) BETWEEN 181 AND 365 THEN '181-365 days'
        ELSE 'Over 1 year'
    END AS SeverityBucket ,
	-- thêm vào SELECT của vw_Backlog, cạnh SeverityBucket
	CASE
		WHEN DATEDIFF(DAY, ls.StatusDate, AsOf.AsOfDate) BETWEEN 31 AND 90  THEN 1
		WHEN DATEDIFF(DAY, ls.StatusDate, AsOf.AsOfDate) BETWEEN 91 AND 180 THEN 2
		WHEN DATEDIFF(DAY, ls.StatusDate, AsOf.AsOfDate) BETWEEN 181 AND 365 THEN 3
		ELSE 4
	END AS SeverityBucketOrder

FROM LatestStatus ls
JOIN dbo.Statuses st       ON ls.ComplaintStatusID = st.ID
JOIN dbo.ComplainsData cd  ON ls.ComplaintID = cd.ID
CROSS JOIN AsOf
WHERE ls.rn = 1
  AND st.Description IN ('IN PROGRESS','OUTSTANDING')
  AND DATEDIFF(DAY, ls.StatusDate, AsOf.AsOfDate) > 30;

  ----


  CREATE VIEW dbo.vw_Bottleneck AS
WITH StatusDuration AS (
    SELECT ComplaintID, ComplaintStatusID, StatusDate,
           LEAD(StatusDate) OVER (PARTITION BY ComplaintID ORDER BY StatusDate) AS NextStatusDate
    FROM dbo.StatusHistoryData
)
SELECT st.Description AS Status,
       sd.ComplaintID, sd.StatusDate, sd.NextStatusDate,
       DATEDIFF(DAY, sd.StatusDate, sd.NextStatusDate) AS DaysInStatus
FROM StatusDuration sd
JOIN dbo.Statuses st ON sd.ComplaintStatusID = st.ID
WHERE sd.NextStatusDate IS NOT NULL
  AND sd.NextStatusDate <> sd.StatusDate;


  ---
  CREATE VIEW dbo.vw_CustomerComplaintCount AS
SELECT CustomerID, 
       COUNT(*) AS ComplaintCount,
       CASE WHEN COUNT(*) = 1 THEN 'Single' ELSE 'Repeat' END AS CustomerType
FROM dbo.ComplainsData
GROUP BY CustomerID;