-- Q1 : TOTAL NUMBER OF TRIPS IN 2019 
select count(*) as total_trips 
from mart.trips 
where EXTRACT(YEAR FROM PICKUP_DATETIME) = 2019
 		-- 6,055,474

-- Q2 : AVG FARE + TIP 
SELECT AVG(FARE_AMOUNT + TIP_AMOUNT) AS AVG_FARE_PLUS_TIP 
FROM MART.TRIPS 
 		-- ~16.323


/*
	Insight:
	- Trung bình mỗi chuyến khách trả khoảng $16.32 (fare + tip), chưa tính thêm
	  các phụ phí khác (extra, tax, tolls, surcharge) nằm trong total_amount.
	- Con số này khớp hợp lý với phân phối total_amount đã quan sát ở bước outlier 
	  (75th percentile ≈ $19), cho thấy phần lớn chuyến rơi vào khoảng $10-20,
	  không có gì bất thường sau khi đã lọc outlier.
	- Ứng dụng: nhân với tổng số chuyến (Q1: 6,055,474) ước tính tổng doanh thu 
	  fare+tip toàn hệ thống trong năm 2019 ≈ $98.8 triệu (chưa tính phụ phí).
*/

--=====================================================================================================================
		 
-- Q3 : NUMBER OF TRIPS BY PAYMENT_TYPE


SELECT COALESCE(B.PAYMENT_NAME, 'Missing') AS PAYMENT_NAME,
       COUNT(*) AS TOTAL_TRIPS,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 3) AS PERCENT_OF_TOTAL 
FROM MART.TRIPS A 
LEFT JOIN RAW.PAYMENT_TYPES B ON A.PAYMENT_TYPE = B.PAYMENT_TYPE
GROUP BY B.PAYMENT_NAME
ORDER BY TOTAL_TRIPS DESC;

/*
	Insight:
	- Credit card (51.2%) và Cash (~38.0%) là hai hình thức chính chiếm gần 90% tổng chuyến 
	- Đáng chú ý : 10.6% chuyến (646,393 dòng) thiếu payment type - đây là lỗi ghi nhận dữ liệu 
	không phải hình thức thanh toán thật . 
	- Khi phân tích dashboard ->  missing phải là 1 nhóm đại diện 
*/
 
--=====================================================================================================================


--Q4 : TOP10 PICKUP ZONES 

SELECT A.ZONE AS PICKUP_ZONE , COUNT(*) AS TRIPS_COUNT
FROM RAW.ZONES A 
JOIN MART.TRIPS B ON A.LOCATION_ID = B.PU_LOCATION_ID 
GROUP BY A.ZONE , A.LOCATION_ID 
ORDER BY TRIPS_COUNT DESC 
LIMIT 10 

/*
	Insight:
	- Top3 đều thuộc Harlem , dẫn đầu là East Harlem North với 460,965 chuyến gần gấp đôi vị trí thứ 4
	- Hợp lý với đặc thù Green Taxi: chỉ được phép đón khách ngoài khu trung tâm Manhatan ( theo quy định NYC TLC) 
	
	Recommendation:
	- Ưu tiên điều phối xe vào Harlem (3/10 vị trí top , tỷ trọng vượt trội)
	- Cân nhắc phân tích sâu hơn : so sánh cung và cầu để biết Harlem có đang thiếu xe hay không trước khi quyết định điều phối
	( nhưng hiện thực là dữ liệu hiện tại không có dữ liệu phù hợp cho số lượng taxi đang hoạt động tại mỗi khu vực )
	
*/
 
--=====================================================================================================================

--Q5 : AVG PASSENGER COUNT BY HOUR 

SELECT PICKUP_HOUR , ROUND(AVG(PASSENGER_COUNT) , 2 )  AS AVG_PASSENGER_COUNT
FROM MART.TRIPS 
GROUP BY PICKUP_HOUR
ORDER BY AVG_PASSENGER_COUNT DESC 
	/* 	Q5 INSIGHT :  
	
			- VÌ CHÊNH LỆCH NHỎ VÀ KHÔNG CÓ NHÓM RÕ RỆT , AVG_PASSENGER_COUNT KHÔNG PHẢI 
			LÀ YẾU TỐ MẠNH ĐỂ PHÂN KHÚC KHÁCH HÀNG THEO GIỜ 
	
			- NẾU CÔNG TY CÂN NHẮC DÙNG CHỈ SỐ NÀY ĐỂ ĐIÊU ĐỘNG LOẠI XE -> KẾT QUẢ Q5 CHƯA ĐỦ THUYẾT PHỤC 
			ĐỂ LÀM CĂN CỨ => CẦN KẾT HỢP THÊM ( NGÀY TRONG TUẦN , KHU VỰC )
		
	*/
	
--Q6 : TIP RATE  BY PAYMENT TYPE

SELECT COALESCE(B.PAYMENT_NAME, 'Missing') AS PAYMENT_NAME , 
 ROUND(
        AVG(
            COALESCE(A.tip_amount,0) * 100.0
            / A.fare_amount
        ) :: NUMERIC  ,
        3
    ) AS AVG_TIP_PERCENT 
FROM MART.TRIPS A 
LEFT JOIN  RAW.PAYMENT_TYPES B ON A.PAYMENT_TYPE = B.PAYMENT_TYPE 
WHERE  A.FARE_AMOUNT > 0 
GROUP BY B.PAYMENT_NAME 
ORDER BY AVG_TIP_PERCENT DESC 
/*
	Insight:
	- Credit card : tip trung binh 16.11% . Tất cả nhóm còn lại ở mức xấp xỉ 0% ( 0.00% - 0.02% )
	- Cũng không thể kết luận rằng các nhóm này không tip - do tip tiền mặt thì không đi qua hệ thống ghi nhận điện tử 
	dữ liệu tip cho các hình thức còn lại chưa đáng tin cậy 
	- Phát hiện thêm : Nhóm Missing (10.6% dữ liệu payment type bị null ) có hành vi tip 0.01% - cũng ở mức ngang với các nhóm Cash/Dispute/No Charge 
	có thể Missing thực chất là các chuyến khách trả bằng tiền mặt bị lỗi ghi nhận mã payment type 

	Recommendation: 
	- Không dùng tip_amount để đánh giá mức độ "hào phóng" giữa các hình thức thanh toán vì sai lệch thu thập dữ liệu , không phản ánh hành vi thật 
	- Có thể cân nhắc gộp Missing vào chung nhóm Cash khi trình bày dashboard 

*/
 
--=====================================================================================================================

-- Q7 : REVENUE BY HOUR x DAY OF WEEK 
SELECT A.PICKUP_HOUR , A.PICKUP_DAYOFWEEK , ROUND( SUM(TOTAL_AMOUNT) :: NUMERIC ,2  )  AS TOTAL_REVENUE 
FROM MART.TRIPS A 
GROUP BY A.PICKUP_HOUR , A.PICKUP_DAYOFWEEK
ORDER BY TOTAL_REVENUE DESC 
/*
	Insight:
	- Top 10 doanh thu rơi vào khung giờ 15h-18h các ngày Thứ 3 - Thứ 6 (giờ tan 
	  làm/tan tầm). Đỉnh cao nhất: 16h-17h Thứ 5-6.
	- Khung 2h-4h sáng các ngày trong tuần (Thứ 2-5) có doanh thu thấp nhất toàn 
	  bảng - đúng với giờ nghỉ ngơi chuẩn bị cho ngày làm việc hôm sau.
	- Ngược lại, cùng khung 2h-4h sáng nhưng vào Thứ 7 và Chủ Nhật lại ở mức cao 
	  bất thường so với các ngày khác - phản ánh khách đi chơi tối Thứ 6/Thứ 7 
	  rồi về nhà vào rạng sáng hôm sau.
	- Kết luận: tồn tại 2 loại "giờ cao điểm" có bản chất khác nhau - (1) giờ tan 
	  tầm ngày thường (nhu cầu đi làm/về nhà) và (2) giờ khuya cuối tuần (nhu cầu 
	  giải trí/về nhà sau tiệc tùng) - không thể gộp chung 1 chiến lược điều xe.
	
	Recommendation:
	- Điều phối xe theo 2 lịch riêng biệt: 
		+tăng cường xe khung 15h-18h vào các ngày Thứ 3-6 (nhu cầu tan tầm); 
		+tăng cường riêng khung 1h-4h sáng vào đêm Thứ 6 rạng Thứ 7, và đêm Thứ 7 rạng Chủ Nhật (nhu cầu về nhà sau tiệc tùng)  
	- Đây là 2 khung giờ cao điểm bị bỏ sót nếu chỉ nhìn theo "giờ trong ngày" mà không tách theo ngày trong tuần.

*/
 
--=====================================================================================================================

-- Q8 : ABNORMAL TRIPS ( TOO LONG , TOO SHORT )

SELECT
    TRIP_ID,
    PICKUP_DATETIME,
    DROPOFF_DATETIME,
    TRIP_DURATION_MINUTES,
    TRIP_DISTANCE,
    TOTAL_AMOUNT
FROM MART.TRIPS
WHERE TRIP_DURATION_MINUTES < 1
   OR TRIP_DURATION_MINUTES > 180
ORDER BY TRIP_DURATION_MINUTES DESC
LIMIT 20;
--
SELECT 
    COUNT(*) FILTER (WHERE trip_duration_minutes < 1) AS too_short,
    COUNT(*) FILTER (WHERE trip_duration_minutes > 180) AS too_long
FROM mart.trips;
/*
	Insight:
	- Đầu tiên phải nhắc đến việc 'too long ' sẽ là 0 vì thực chất qua quá trình xử lý outlier các dòng too long đã bị dọn ra 
		+ Tồn tại 33444 dòng dữ liệu chuyến đi too short (0.55% tổng trips ) tỷ lệ nhỏ : nhưng ta thấy được thể hiện qua top20 
		trip_duration đều = 0.98 ( chưa đến 1 phút ) , trip_distance < 0.5 => đây là dấu hiệu của lỗi thiết bị GPS , đây là 
		dấu hiệu của bất thường ( chuyến đi vừa bắt đầu đã bấm kết thúc)
	
	Recommendation:
	- Loại bỏ các dòng too_short, vì tỷ lệ nhỏ (0.55%) và bản chất là dữ liệu 
	  SAI/vô lý (lỗi GPS - bấm bắt đầu rồi kết thúc gần như ngay lập tức), 
	  không phải trường hợp thiếu dữ liệu như passenger_count trước đây. 
	- Loại bỏ không làm mất thông tin có giá trị, mà giúp các chỉ số trung bình 
	  (avg_fare, avg_speed) không bị lệch bởi dữ liệu lỗi thiết bị.


*/
 DELETE FROM mart.trips WHERE trip_duration_minutes < 1; -- phát hiện outlier -> cleaning (33,444 dòng)
--=====================================================================================================================

--Q9 : AIRPORT TRIPS 
	--	9a : JFK và LGA 
SELECT
    Z.ZONE AS PICKUP_ZONE,
    COUNT(*) AS TOTAL_TRIPS,
    ROUND(AVG(A.FARE_AMOUNT) :: NUMERIC,2) AS AVG_FARE,
    ROUND(AVG(A.TRIP_DURATION_MINUTES):: NUMERIC,2) AS AVG_DURATION , 
		ROUND(
		AVG(TRIP_DISTANCE) :: NUMERIC ,2 
	) AS AVG_DISTANCE,
	ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() , 2) AS PERCENT_TRIPS 
FROM MART.TRIPS A
JOIN RAW.ZONES Z
    ON A.PU_LOCATION_ID = Z.LOCATION_ID
WHERE A.DO_LOCATION_ID IN (132,138)
GROUP BY Z.ZONE
ORDER BY TOTAL_TRIPS DESC;
--
SELECT 
	CASE
		WHEN DO_LOCATION_ID IN(1,132,138) THEN 'AIRPORT TRIPS '
		ELSE 'NON AIRPORT TRIPS'
	END AS TRIP_TYPES 	,
	ROUND(
		AVG(FARE_AMOUNT)::NUMERIC , 3 
	) AS AVG_FARE_AMOUNT , 
	ROUND(
		AVG(TRIP_DURATION_MINUTES)::NUMERIC , 3 
	) AS AVG_TRIP_DURATIONS ,
	COUNT(*) AS TOTAL_TIPS ,
	ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() , 2) AS PERCENT_TRIPS 
FROM MART.TRIPS 
GROUP BY TRIP_TYPES 
/*
	Insight:
	* Thống kê về các chuyến đi tại sân bay ( JFK & LGA) :
		- Trong tổng số 100243 chuyến đi sân bay (JFK & LGA) thì khu vực Elmhust là nguồn khách lớn nhất với 19,540 chuyến , chiếm 19.49 tổng lưu lượng 
		- Elmhust tạo ra lượng yêu cầu đến sân bay gấp hơn 3 lần các khu vực kế tiếp như  Steinway (5,960 trips) , East Harlem North (5,708 trips)  & Woodside (5,594 trips) 
		- Các pickupzone gần sân bay hoặc nằm trong khu vực Queens chiếm tỷ trọng đáng kể trong lưu lượng airport trips cho thấy nhu cầu di chuyển sân bay tập trung mạnh ở các khu
		dân cư phía Đông NYC
	* So sánh airport trips & non-airport trips 
		- Các chuyến đi đến sân bay khoảng 102,019 chuyến ( chiếm 1.68% trên tổng số chuyến ) - non-airport trips có 5953619
		- Dù chiếm tỷ trọng chuyến đi không quá lớn nhưng giá trị giao dịch cao hơn đáng kể ( Giá vé trung bình của airport trips ($26.08) cao hơn khoảng 71% so với non-airport trips ($15.22).
		- Thời lượng chuyến đi trung bình của airport trips (23.35 phút) dài hơn khoảng 42% so với các chuyến thông thường (16.43 phút).
		- Tính theo $/hour (avg_fare_per_hour * duration) 
		- Tính theo $/giờ (fare_amount / duration × 60): 
			Airport ≈ $67/giờ, 
		  	Non-airport ≈ $55.6/giờ 
		  -> airport vẫn cao hơn ~20% dù chênh lệch nhỏ hơn nhiều so với con số 71% khi chỉ so sánh fare/chuyến đơn thuần.
			
	Recommendation:
		- Chưa nên triển khai chương trình khuyến khích nhận chuyến sân bay chỉ dựa trên dữ liệu hiện tại.
		- Cần thu thập thêm dữ liệu vận hành giữa hai chuyến liên tiếp của cùng một tài xế (idle time, deadhead mileage, 
		thời gian tìm khách mới) để đo chính xác hiệu quả kinh doanh thực tế của airport trips.
		- Phân tích Airport Revenue per Working Hour nên được tính lại sau khi cộng thêm thời gian chạy rỗng và thời gian chờ khách.
		- Nếu dữ liệu bổ sung cho thấy thời gian tìm khách sau khi trả khách tại sân bay quá cao, 
		airport trips có thể không phải là phân khúc tối ưu dù có giá vé trung bình cao hơn.

 */
--=====================================================================================================================

--Q10 : FARE PER MILE BY DISTANCE 
SELECT 
	CASE 
		WHEN TRIP_DISTANCE < 2 THEN '0-2' 
		WHEN TRIP_DISTANCE < 5 THEN '2-5' 
		WHEN TRIP_DISTANCE < 10 THEN '5-10' 
		ELSE  '10+' 
	END AS DISTANCE_CATEGORY  ,
	ROUND(
		AVG(FARE_AMOUNT / TRIP_DISTANCE) :: NUMERIC , 3 
	) AS AVG_FARE_PER_MILE
FROM MART.TRIPS 
WHERE TRIP_DISTANCE > 0 
GROUP BY DISTANCE_CATEGORY 
ORDER BY AVG_FARE_PER_MILE DESC

/*
	Insight:
	- Đơn giá không cố định giữa các nhóm khoảng cách 
	Chi phí trên mỗi dặm giảm dần khi quãng đường tăng : 
		- 0-2 miles: 8.63$/mile
		- 2-5 miles: 4.73$/mile
		- 5-10 miles: 3.87$/mile
		- 10+ miles: 3.24$/mile
	=> Điều này cho thấy các chuyến đi ngắn đang chịu chi phí trên mỗi dặm cao hơn đáng kể so với các chuyến đi dài.
	
	Recommendation:
	- Nên xem xét lại cách truyền thông bảng giá cho khách hàng nhằm giải thích rõ tác động của chi phí mở cửa xe ( base fare ) đối với các chuyến đi ngắn
	- Đối với nhóm thường xuyên thực hiện các chuyến đi ngắn có thể nghiên cứu các chương trình giá ưu đãi hoặc chính sách giảm chi phí cố định để cải thiện
	trải nghiệm và khả năng cạnh tranh 

*/
 
--=====================================================================================================================


-- Q11 : MONTHLY REVENUE + RUNNING TOTAL 
WITH TEMP_TABLE AS (
	SELECT DATE_TRUNC('MONTH',PICKUP_DATETIME) AS MONTH , 
	SUM(TOTAL_AMOUNT) AS REVENUE 
	FROM MART.TRIPS 
	WHERE EXTRACT(YEAR FROM PICKUP_DATETIME ) = 2019
	GROUP BY MONTH
)

SELECT MONTH ,
		ROUND(REVENUE ::NUMERIC , 2) AS REVENUE_BY_MONTH,
		ROUND((revenue - LAG(revenue) OVER (ORDER BY month))::NUMERIC, 2) AS DIFFERENCE,
		ROUND(SUM(REVENUE) OVER(ORDER BY MONTH):: NUMERIC , 2)  AS CUMULATIVE_REVENUE 
FROM TEMP_TABLE
ORDER BY MONTH 

/*
	Insight:
	- Doanh thu tổng năm 2019: $111,025,768.91.
	- Tháng 4 giảm mạnh nhất (-$1,481,335 so với tháng 3), tiếp theo là tháng 11 
	  (-$1,117,926 so với tháng 10) và tháng 6 (-$1,041,936 so với tháng 5).
	- Quan trọng hơn từng tháng riêng lẻ: doanh thu có xu hướng GIẢM LIÊN TỤC 
	  từ Tháng 1 ($11.87M) đến Tháng 8 ($7.76M) - giảm hơn 34% xuyên suốt 8 tháng 
	  đầu năm, không phải biến động ngẫu nhiên giữa vài tháng. Từ Tháng 9-12, 
	  doanh thu dao động nhẹ quanh mức thấp ($7.5M-$8.7M), không phục hồi lại 
	  mức đầu năm.
	- Đây là tín hiệu đáng lo ngại hơn nhiều so với việc chỉ nhìn 1-2 tháng giảm 
	  mạnh - toàn bộ năm 2019 cho thấy xu hướng đi xuống có hệ thống.

	  
	Limitation:
	- CFO yêu cầu phân tích 24 tháng, nhưng dataset chỉ có dữ liệu đầy đủ 12 
	  tháng (2019). Không thể so sánh year-over-year hoặc xác nhận xu hướng 
	  giảm này là theo mùa (sẽ lặp lại các năm) hay là suy giảm cấu trúc dài 
	  hạn (do cạnh tranh Uber/Lyft, thay đổi hành vi khách hàng...). Cần dataset 
	  năm 2018 hoặc 2020 để xác nhận.
	  
	Recommendation:
	- Vì chưa thể phân biệt "giảm theo mùa" vs "giảm cấu trúc dài hạn", KHÔNG 
	  nên vội kết luận công ty đang suy giảm - nhưng CFO cần được cảnh báo ngay 
	  về pattern này, vì mức giảm 34% là đáng kể.
	- Đề xuất điều tra thêm 2 hướng trước khi hành động: (1) đối chiếu với dữ 
	  liệu Yellow Taxi/Uber-Lyft cùng giai đoạn để xem đây là xu hướng chung 
	  toàn ngành hay riêng Xóm Taxi; (2) tìm dữ liệu 2018 để kiểm tra xem có 
	  lặp lại pattern giảm dần từ đầu năm tương tự hay không (nếu có, khả năng 
	  cao là yếu tố mùa vụ, không phải suy giảm thật).

*/

--=====================================================================================================================


-- Q12 : LONGEST QUIET SPELL PER ZONE 
WITH ordered_trips AS (
    SELECT 
        z.zone,
        t.pickup_datetime,
        LAG(t.pickup_datetime) OVER (
            PARTITION BY z.zone 
            ORDER BY t.pickup_datetime
        ) AS prev_pickup
    FROM mart.trips t
    JOIN raw.zones z ON t.pu_location_id = z.location_id
    WHERE EXTRACT(YEAR FROM t.pickup_datetime) = 2019
		  AND z.zone != 'N/A'
), gaps AS (
    SELECT 
        zone,
        EXTRACT(EPOCH FROM (pickup_datetime - prev_pickup)) / 60 AS gap_minutes
    FROM ordered_trips
    WHERE prev_pickup IS NOT NULL
), zone_summary AS (
    SELECT 
        zone,
        MAX(gap_minutes) AS longest_quiet_spell_minutes,
        COUNT(*) + 1 AS total_trips
    FROM gaps
    GROUP BY zone
)
SELECT 
    zone,
    ROUND(longest_quiet_spell_minutes::NUMERIC, 2) AS longest_quiet_spell_minutes,
    total_trips
FROM zone_summary
WHERE total_trips >= 1000
ORDER BY longest_quiet_spell_minutes DESC


/*
	Insight:
	- Quá trình xử lý Q12 phát hiện 2 vấn đề dữ liệu mới (chưa từng lộ ra ở Q1-Q11):
	  (1) 174 dòng (0.003%) có pickup_datetime sai năm (2008-2010, 2018, 2020) - 
	  gây nhiễu nghiêm trọng cho phép tính LAG() dù ảnh hưởng gần như bằng 0 với 
	  các phép tính trung bình/tổng trước đó; (2) zone "N/A"/Unknown (location_id 
	  264) - vị trí không xác định được, có sẵn trong dữ liệu gốc NYC TLC, không 
	  có ý nghĩa để điều phối xe.
	- Sau khi loại 2 vấn đề trên, Kips Bay có "khoảng lặng" dài nhất: 73,081 phút 
	  (~50 ngày), nhưng chỉ có 1,194 chuyến/năm (~3.3 chuyến/ngày) - khoảng lặng 
	  dài là hệ quả tự nhiên của mật độ chuyến rất thưa, không phải bất thường.
	- Các zone dẫn đầu danh sách đều có đặc điểm chung: total_trips thấp (1,000-
	  2,500 chuyến/năm) - xác nhận mối quan hệ logic: zone càng ít chuyến, khoảng 
	  lặng càng dài, đúng theo trực giác toán học.

	Recommendation:
	- KHÔNG nên điều xe thường trực đến các zone như Kips Bay, Lenox Hill East 
	  chỉ vì "quiet spell" dài - với chỉ 3-4 chuyến/ngày, tăng cường xe ở đây 
	  không hiệu quả kinh tế. "Quiet spell" dài ở nhóm này phản ánh nhu cầu thấp 
	  thật sự, không phải cơ hội bị bỏ lỡ.
	- Đề xuất VP Operations xem xét nhóm zone có total_trips TRUNG BÌNH-CAO 
	  (2,000-5,000/năm) nhưng vẫn có quiet spell đáng kể (như Bronx Park 4,720 
	  phút/2,208 chuyến, Cambria Heights 3,889 phút/4,484 chuyến) - đây mới là 
	  nhóm "cơ hội thật", vì có đủ nhu cầu nhưng vẫn xảy ra khoảng trống dài, 
	  gợi ý thiếu xe cục bộ tại thời điểm nào đó trong năm.
	- Dev note: bổ sung kiểm tra range hợp lệ cho pickup_datetime (ví dụ đúng 
	  năm 2019) vào bước validate dữ liệu ETL, để tránh phải phát hiện muộn ở 
	  bước phân tích như trường hợp Q12 này.

*/

 
--=====================================================================================================================

--Q13 : TRIP DISTANCE PERCENTILES 
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY TRIP_DISTANCE) AS MEDIAN_DISTANCE ,
		PERCENTILE_CONT(0.95) WITHIN GROUP(ORDER BY TRIP_DISTANCE) AS P95_DISTANCE , 
		MAX(TRIP_DISTANCE) AS MAX_DISTANCE 
FROM MART.TRIPS 


/*
	Insight:
	- 50% chuyến đi chỉ đạt 2.14 miles => phần lớn nhu cầu khách hàng của green taxi là những chuyến đi ngắn 
	- 95% chuyến đi chỉ đạt 12.61 miles => chỉ có 5% còn lại có chuyến đi > 13miles (tần suất xuất hiện các chuyến đi xa là khá hiếm)
	-max = 50 miles KHÔNG PHẢI là giá trị tự nhiên của dữ liệu - 
	  đây là ngưỡng cắt outlier đã áp dụng chủ động ở bước ETL (Python, giai 
	  đoạn staging → mart), dựa trên domain knowledge thực tế của taxi NYC 
	  (xem lại quyết định lọc trip_distance <= 50 trước đó). Dữ liệu gốc từng 
	  có giá trị lên đến hơn 77,000 miles trước khi bị lọc bỏ.
	- Vì vậy, con số max=50 hiện tại không phản ánh "outlier còn sót lại", mà 
	  phản ánh hiệu quả của bước cleaning đã thực hiện.


	Recommendation:
	- Dù đã xử lý được ở tầng ETL, gốc rễ vấn 
	  đề (GPS ghi nhận sai gây ra outlier hàng chục nghìn miles) vẫn tồn tại ở 
	  thiết bị/hệ thống thu thập dữ liệu. Đề xuất phối hợp với đội kỹ thuật thiết 
	  bị (nếu có) để cải thiện độ chính xác GPS tại nguồn, giảm khối lượng dữ 
	  liệu cần lọc bỏ trong tương lai (hiện đang mất khoảng 0.48% dữ liệu do 
	  distance/duration bất thường, theo phát hiện ở bước outlier ban đầu).

*/


 
--=====================================================================================================================

--Q14 : PEAK HOUR OF EACH ZONE

WITH HOURLY_TRIPS AS (
	SELECT B.ZONE , A.PICKUP_HOUR, 
	COUNT(*) AS TRIP_COUNT

	FROM MART.TRIPS A 
	JOIN RAW.ZONES B ON A.PU_LOCATION_ID =B.LOCATION_ID 
	GROUP BY B.ZONE , A.PICKUP_HOUR
),
RANKED AS (
	SELECT ZONE , PICKUP_HOUR , TRIP_COUNT , 
	ROW_NUMBER() OVER (PARTITION BY ZONE ORDER BY TRIP_COUNT DESC ) AS RANK
	FROM HOURLY_TRIPS
	
)

SELECT ZONE , PICKUP_HOUR , TRIP_COUNT ,RANK 
FROM RANKED 
WHERE RANK =1 AND TRIP_COUNT >=1000
ORDER BY TRIP_COUNT DESC 


/*
	Insight:
	- Sau khi đã lọc xong các zone có đủ dữ liệu tin cậy (>1000 chuyến) , còn 59/260 zone 
	- Ta thấy được khoảng 50% peak_zone vào khung giờ 17-18h ( giờ tan tầm ) - đây là partern chủ đạo của Green Taxi
	- Nhóm zone peak từ 8-9g sáng ( giờ đi làm ) chiếm khoảng 20 zone đáng chú ý gồm Central Harlem North , Hamilton Heights , Long Island City/Hunters Point ,Crown Heights North
	đây là các khu dân cư ( giả thuyết người đi làm vào buổi sáng từ khu này )
	-Một số ít zone có giờ peak bất thường: Williamsburg South (1h sáng), 
	  Greenpoint/Williamsburg North (23h) - gợi ý khu vực có hoạt động giải trí 
	  về đêm (bar/club), khác hẳn pattern "đi làm" thông thường.


	Recommendation:
	- Dispatch team nên điều xe theo 2 làn sóng chính: tăng cường buổi sáng 
	  (7h-9h) cho nhóm zone dân cư đã xác định (Central Harlem North, Hamilton 
	  Heights, LIC/Hunters Point...), và tăng cường buổi chiều (17h-18h) cho 
	  đa số zone còn lại.
	- Với nhóm zone giờ peak bất thường (đêm khuya), cần xử lý riêng theo lịch 
	  đặc thù, không áp dụng chung công thức sáng/chiều.
	- Với 171 zone bị loại do <1000 chuyến, dispatch không nên dựa vào "peak 
	  hour" tính toán được (không đủ tin cậy) - cần theo dõi thủ công hoặc dùng 
	  phương pháp khác (ví dụ gộp nhóm zone lân cận) nếu cần điều xe khu vực này.

*/


 
--=====================================================================================================================

--Q15 : SUGRE PRICING DETECTION 
WITH zone_hour_day AS (
    SELECT 
        z.zone,
        t.pickup_hour,
        t.pickup_dayofweek,
        AVG(t.fare_amount / t.trip_distance) AS avg_fare_per_mile,
        COUNT(*) AS trip_count
    FROM mart.trips t
    JOIN raw.zones z ON t.pu_location_id = z.location_id
    WHERE t.trip_distance >= 0.5
    GROUP BY z.zone, t.pickup_hour, t.pickup_dayofweek
    HAVING COUNT(*) >= 10
),
stats AS (
    SELECT 
        zone, pickup_hour,
        AVG(avg_fare_per_mile) AS mean_fpm,
        STDDEV(avg_fare_per_mile) AS stddev_fpm,
        COUNT(*) AS days_with_data,
        SUM(trip_count) AS total_trips
    FROM zone_hour_day
    GROUP BY zone, pickup_hour
    HAVING COUNT(*) = 7
)
SELECT 
    zone, pickup_hour,
    ROUND(mean_fpm::NUMERIC, 2) AS avg_fare_per_mile,
    ROUND(stddev_fpm::NUMERIC, 2) AS stddev_fare_per_mile,
    ROUND((stddev_fpm / NULLIF(mean_fpm, 0) * 100)::NUMERIC, 2) AS coefficient_of_variation_pct,
    total_trips
FROM stats
WHERE (stddev_fpm / NULLIF(mean_fpm, 0)) > 0.20
ORDER BY coefficient_of_variation_pct DESC
LIMIT 30;

/*
Insight:
- Sau 3 lớp kiểm soát chất lượng dữ liệu (loại chuyến <0.5 dặm tránh fare/mile 
  ảo; mỗi ngày phải có >=10 chuyến; phải đủ dữ liệu cả 7/7 ngày), phát hiện 
  ~30 tổ hợp (zone, giờ) có hệ số biến thiên (CV) của fare-per-mile vượt 20%,
  cao nhất là College Point (89.2%) và North Corona (69.2%, mẫu lớn hơn - 
  518 chuyến, đáng tin cậy hơn).
- Pattern chung: các zone dao động cao đều thuộc khu vực Outer Queens/Brooklyn 
  (College Point, Corona, Richmond Hill, Red Hook...), KHÔNG phải khu trung 
  tâm đông đúc. Nhiều khả năng đây là do các zone này có mật độ chuyến/giờ 
  thấp hơn, nên chỉ cần vài chuyến giá cao bất thường (đường xa, giờ hiếm 
  tài xế) cũng đủ kéo lệch trung bình đáng kể - không nhất thiết là surge 
  pricing chủ đích, có thể chỉ là biến động tự nhiên do cỡ mẫu nhỏ.
- Chưa tìm thấy bằng chứng rõ ràng cho "pricing bug" (dao động không hợp lý, 
  bất thường tại tất cả các zone/giờ) - dao động tập trung có chọn lọc vào 
  nhóm zone ít chuyến, phù hợp với biến động ngẫu nhiên hơn là lỗi hệ thống.

Recommendation:
- Ưu tiên điều tra North Corona trước (CV 69.2%, mẫu 518 chuyến - đáng tin 
  cậy nhất trong nhóm), xem xét log giá thực tế từng ngày để xác định có 
  surge event cụ thể hay không.
- Với các zone có total_trips dưới 200 (như College Point, Bath Beach), CV 
  cao có thể chỉ do mẫu nhỏ, chưa đủ cơ sở kết luận surge - cần theo dõi 
  thêm dữ liệu các tháng/quý tiếp theo (hiện tại chỉ có data 2019) trước khi 
  đưa ra hành động.
- Không có bằng chứng đủ mạnh để kết luận có "pricing bug" hệ thống - nếu 
  Head of Pricing nghi ngờ lỗi cụ thể, nên cung cấp thêm ngày/khung giờ nghi 
  vấn cụ thể để điều tra sâu hơn thay vì quét toàn bộ dataset.
*/






