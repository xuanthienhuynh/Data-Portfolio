
/* 1.
		Thời gian trung bình để đóng một khiếu nại (CompletionDate - ComplainDate) là 
		bao lâu? So sánh sự khác biệt về thời gian này theo từng 
		ComplainType và Priority.
*/
select b.Description as Complain_Type , c.Description as Complain_Priority ,
count(*) as total_complain ,
cast(avg(DATEDIFF(day,a.ComplainDate,a.CompletionDate))as FLOAT) as Avg_Processing_Days
from ComplainsData a 
join Types b on a.ComplainTypeID = b.ID 
join Priorities c on a.ComplainPriorityID = c.ID 
where a.CompletionDate is not null 
group by b.Description  , c.Description 
order by Avg_Processing_Days desc

--========================================================================================

/* 2.
		Danh mục khiếu nại 
		(Category) nào đang nhận tỷ lệ không hài lòng (ClientSatisfaction = 'NSA') cao nhất? 
*/
SELECT 
    a.ComplainCategoryID, 
    b.Description, 
    COUNT(*) AS total_evaluated, -- không đếm N/A
    SUM(CASE WHEN a.ClientSatisfaction = 'NSA' THEN 1 ELSE 0 END) AS count_NSA,
    CAST(
        SUM(CASE WHEN a.ClientSatisfaction = 'NSA' THEN 1 ELSE 0 END) * 100.0 
        / COUNT(*) 
        AS DECIMAL(5,2)
    ) AS NSA_Rate_Pct
FROM ComplainsData a
JOIN Categories b 
    ON a.ComplainCategoryID = b.ID
WHERE a.ClientSatisfaction IN ('NSA','SAT')
GROUP BY a.ComplainCategoryID, b.Description
ORDER BY NSA_Rate_Pct DESC;
--========================================================================================

/* 3.
	Có sự khác biệt 
	nào về hiệu quả xử lý khiếu nại (thời gian và tỷ lệ SAT) giữa các 
	DistributionNetwork (Bancassurance, Tele sales, XPA...)?
*/

SELECT 
    b.DistributionNetwork,
    CAST(AVG(DATEDIFF(day, a.ComplainDate, a.CompletionDate))AS FLOAT) AS Avg_processing_days,
    COUNT(*) AS total_complains,
    CAST(
        SUM(CASE WHEN a.ClientSatisfaction = 'SAT' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(SUM(CASE WHEN a.ClientSatisfaction IN ('SAT','NSA') THEN 1 ELSE 0 END), 0)
        AS DECIMAL(5,2)
    ) AS SAT_ratePct
FROM ComplainsData a
JOIN Brokers b 
    ON a.BrokerID = b.BrokerID
WHERE a.CompletionDate IS NOT NULL
GROUP BY b.DistributionNetwork
ORDER BY SAT_ratePct DESC;





--========================================================================================
/* 4.
	Sử dụng bảng Status History Data 
	để đếm số lượng khiếu nại đang nằm ở trạng thái IN PROGRESS 
	hoặc OUTSTANDING vượt quá 30 ngày. 
*/

-- ver 1 : vì dùng getdate() lấy ngày hiện tại nên dữ liệu days_in_current_status bị thổi bùng lên 
with lastestStatus as (
	select  a.ComplaintID , a.ComplaintStatusID ,a.StatusDate,
		ROW_NUMBER() over (
			partition by a.complaintID order by a.StatusDate desc ) as status_rank 
	from StatusHistoryData a 
)

select c.ID , b.Description as Current_Status , a.StatusDate,
DATEDIFF(day,a.StatusDate, GETDATE()) as Days_In_current_status 
from lastestStatus a 
join Statuses b on a.ComplaintStatusID = b.ID
join ComplainsData c on a.ComplaintID = c.ID
where a.status_rank = 1 
	and b.Description IN ('IN PROGRESS' , 'OUTSTANDING') 
	AND DATEDIFF(day,a.StatusDate, GETDATE()) > 30 
order by Days_In_current_status  desc 

------------
--ver2 : để tiện cho việc phân tích -> chọn ngày lớn nhất xuất hiện trong toàn bộ dataset 
DECLARE @AsOfDate DATE = (SELECT MAX(StatusDate) FROM dbo.StatusHistoryData);
SELECT @AsOfDate AS AsOfDate;  -- xem thử ngày mốc là bao nhiêu

-- ============================================
-- BƯỚC 1: Tính 1 LẦN — trạng thái mới nhất + số ngày kẹt của MỌI khiếu nại
-- Lưu vào bảng tạm để tái sử dụng cho các bước sau
-- ============================================
IF OBJECT_ID('tempdb..#Backlog') IS NOT NULL DROP TABLE #Backlog;

WITH LatestStatus AS (
    SELECT
        sh.ComplaintID,
        sh.ComplaintStatusID,
        sh.StatusDate,
        ROW_NUMBER() OVER (PARTITION BY sh.ComplaintID ORDER BY sh.StatusDate DESC) AS rn
    FROM dbo.StatusHistoryData sh
)
SELECT
    cd.ID AS ComplaintID,
    st.Description AS Current_Status,
    ls.StatusDate,
    DATEDIFF(DAY, ls.StatusDate, @AsOfDate) AS Days_In_Current_Status
INTO #Backlog
FROM LatestStatus ls
JOIN dbo.Statuses st       ON ls.ComplaintStatusID = st.ID
JOIN dbo.ComplainsData cd  ON ls.ComplaintID = cd.ID
WHERE ls.rn = 1
  AND st.Description IN ('IN PROGRESS','OUTSTANDING')
  AND DATEDIFF(DAY, ls.StatusDate, @AsOfDate) > 30;

-- ============================================
-- BƯỚC 2: Danh sách chi tiết (giống bảng bạn đã xem)
-- ============================================
SELECT * FROM #Backlog ORDER BY Days_In_Current_Status DESC;

-- ============================================
-- BƯỚC 3: Tổng số lượng & tỷ lệ trên toàn bộ khiếu nại
-- ============================================
SELECT
    COUNT(*) AS BacklogCount,
    (SELECT COUNT(*) FROM dbo.ComplainsData) AS TotalComplaints,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.ComplainsData) AS DECIMAL(5,2)) AS PctOfTotal
FROM #Backlog;

-- ============================================
-- BƯỚC 4: Tách theo từng trạng thái (OUTSTANDING vs IN PROGRESS)
-- ============================================
SELECT
    Current_Status,
    COUNT(*) AS BacklogCount,
    AVG(Days_In_Current_Status) AS AvgDaysStuck
FROM #Backlog
GROUP BY Current_Status;

-- ============================================
-- BƯỚC 5: Chia theo mức độ nghiêm trọng (bucket)
-- ============================================
SELECT
    CASE
        WHEN Days_In_Current_Status BETWEEN 31 AND 90  THEN '31-90 days'
        WHEN Days_In_Current_Status BETWEEN 91 AND 180 THEN '91-180 days'
        WHEN Days_In_Current_Status BETWEEN 181 AND 365 THEN '181-365 days'
        ELSE 'Over 1 year'
    END AS BacklogBucket,
    COUNT(*) AS Cnt
FROM #Backlog
GROUP BY
    CASE
        WHEN Days_In_Current_Status BETWEEN 31 AND 90  THEN '31-90 days'
        WHEN Days_In_Current_Status BETWEEN 91 AND 180 THEN '91-180 days'
        WHEN Days_In_Current_Status BETWEEN 181 AND 365 THEN '181-365 days'
        ELSE 'Over 1 year'
    END
ORDER BY MIN(Days_In_Current_Status);

-- Dọn bảng tạm sau khi xong (không bắt buộc, tempdb tự dọn khi đóng session)
DROP TABLE #Backlog;

--========================================================================================

/* 5.
 Các tiểu bang (State) 
hoặc khu vực (Region) nào đang có số lượng khiếu nại trên mỗi 1000 
khách hàng là cao nhất?
*/

with customer_by_region as (
	select c.Region , count(distinct a.CustomerID) as total_customers 
	from Customers a 
	join Regions b on a.RegionID =b.RegionID 
	join StateRegions c on b.StateCode = c.StateCode
	group by c.Region
),
complaints_by_region as (
	select d.Region , count(*) as total_complaints 
	from ComplainsData a 
	join Customers b on a.CustomerID =b.CustomerID
	join Regions c on c.RegionID = b.RegionID 
	join StateRegions d on c.StateCode = d.StateCode 
	group by d.Region
)
select a.Region , 
		b.total_complaints,
		a.total_customers,
		cast( b.total_complaints * 1000.0 / a.total_customers as Decimal(10,2)) as complaints_Per_1000customers 
from customer_by_region a 
join complaints_by_region b on a.Region = b.Region 
order by complaints_Per_1000customers  desc 

--========================================================================================

/* 6.
	Phân tích mối 
	tương quan giữa ExpectedReimbursement (số tiền đòi bồi thường kỳ vọng) 
	và kết quả sự hài lòng của khách hàng.
*/

select 
ClientSatisfaction ,
count(*) as total_complaints ,
avg(ExpectedReimbursement) as avg_ExpectedReimbursement,
min(ExpectedReimbursement) as min_ExpectedReimbursement,
max(ExpectedReimbursement) as max_ExpectedReimbursement
from ComplainsData
where ClientSatisfaction in ('NSA','SAT') 
group by ClientSatisfaction 

--========================================================================================
/* 7.
	Kênh tiếp nhận khiếu 
	nại nào (Source) giúp quy trình giải quyết nhanh nhất? 
*/

select a.Description , count(*) as total_complaints ,
	CAST(avg( DATEDIFF(day,b.ComplainDate,b.CompletionDate))AS FLOAT) as avg_processing_days 

from Sources a 
join ComplainsData b on a.ID = b.ComplainSourceID 
where b.CompletionDate is not null
group by a.Description 
order by avg_processing_days  asc 


------ trong quá trình làm các dòng null của completionDate bị null -> 1990-01-01  -> phải update lại về null 
select b.ComplainDate, b.CompletionDate
from ComplainsData b
where DATEDIFF(day, b.ComplainDate, b.CompletionDate) < 0


SELECT ID, ComplainDate, CompletionDate,
       DATEDIFF(DAY, ComplainDate, CompletionDate) AS ProcessingDays
FROM dbo.ComplainsData
WHERE DATEDIFF(DAY, ComplainDate, CompletionDate) < 0
ORDER BY ProcessingDays ASC;
---------------

UPDATE dbo.ComplainsData
SET CompletionDate = NULL
WHERE CompletionDate = '1900-01-01';

--========================================================================================

/*8.
	Dựa trên bảng 
	Status History Data, trạng thái nào (StatusID) khiến khiếu nại bị "kẹt" 
	lâu nhất trước khi chuyển sang trạng thái tiếp theo?
*/

with statusDaration as (
	select a.ComplaintID , a.ComplaintStatusID , a.StatusDate ,
	lead(a.StatusDate) over(partition by a.complaintID order by a.statusDate ) as Next_Status_Date  
	from StatusHistoryData a 
)

select a.ComplaintStatusID , b.Description , count(*) as Occurences ,
		CAST(avg(DATEDIFF(day,a.StatusDate,a.Next_Status_Date))AS FLOAT ) as AVG_days_in_status 

from statusDaration a 
join Statuses b on a.ComplaintStatusID = b.ID 
where a.Next_Status_Date is not null 
group by a.ComplaintStatusID , b.Description
order by avg_days_in_status desc

 
--========================================================================================

/*	9.
	Loại sản phẩm bảo 
	hiểm (ProductCategory) nào đang là "điểm nóng" tạo ra nhiều khiếu 
	nại nhất? 
*/

select b.ProductCategory , count(*) as total_complaints ,
CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Pct_Of_Total
from  ComplainsData a
join Products b on a.ProductID = b.ProductID 
group by b.ProductCategory 
order by total_complaints  desc

--========================================================================================

/*	10.
	Khách hàng có thông tin nhân khẩu học (độ tuổi, giới tính, tình trạng hôn 
	nhân) như thế nào thường có xu hướng gửi khiếu nại "Urgent"? 
*/

select b.Gender , b.MaritalStatus ,
	case 
		when DATEDIFF(year,BirthDate, a.ComplainDate) <30 then 'Under 30' 
		when DATEDIFF(year,BirthDate, a.ComplainDate) between 30 and 45 then '30 - 45' 
		when DATEDIFF(year,BirthDate, a.ComplainDate) between 46 and 60 then '46-60'
		else 'over 60' 
	end as Age_Group ,
	count(*) as Urgent_complaints 

from ComplainsData a 
join Customers b on a.CustomerID = b.CustomerID 
join Priorities c on a.ComplainPriorityID = c.ID
where c.Description ='Urgent'
and b.ParticipantType ='INDIVIDUAL'
group by b.Gender , b.MaritalStatus ,
	case 
		when DATEDIFF(year,BirthDate, a.ComplainDate) <30 then 'Under 30' 
		when DATEDIFF(year,BirthDate, a.ComplainDate) between 30 and 45 then '30 - 45' 
		when DATEDIFF(year,BirthDate, a.ComplainDate) between 46 and 60 then '46-60'
		else 'over 60' 
	end 
order by Urgent_complaints desc 
