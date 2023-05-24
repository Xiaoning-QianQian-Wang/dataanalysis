/*Payment records analysis Data Exploration 

Skills used: Checking system tables, data manipulation on date and string, CTE, Temp Tables, window function, stored procedure, cursor*/


--**Preparation: check column type
select object_NAME(c.object_id) AS table_name
       , c.name column_name
	   , t.name column_type
	   , c.max_length as column_length
from sys.columns c
LEFT JOIN sys.types t
    ON t.user_type_id = c.user_type_id
Where c.OBJECT_ID= (SELECT OBJECT_ID FROM SYS.tables WHERE NAME='payment')

--**Preparation: convert data type if necessary
DROP TABLE IF EXISTS #payment
SELECT [business_code]
      ,[cust_number]
      ,LOWER(TRIM([name_customer])) as name_customer
      ,CAST([clear_date] AS DATE) AS clear_date
	  ,DATEPART(quarter,clear_date) AS clear_quarter
	  , CASE WHEN DATEPART(DW,clear_date)=1 THEN 7
	         ELSE DATEPART(DW,clear_date)-1 END AS clear_dow --Set Monday is the first day
      ,[business_year]
      ,[doc_id]
      ,[posting_date]
	  ,DATEDIFF(day,posting_date,due_in_date) as grace_period
      ,[document_create_date]
      ,[document_create_date_1]
      ,[due_in_date]
      ,[invoice_currency]
      ,[document_type]
      ,[posting_id]
      ,[area_business]
      ,[total_open_amount]
      ,[baseline_create_date]
      ,[cust_payment_terms]
      ,[invoice_id]
      ,[isOpen]
INTO #payment
FROM [MyPortfolio].[dbo].[payment]


--1. Caculate clear total amount by each quarter

SELECT business_year
      ,clear_quarter
	  ,SUM(total_open_amount) AS total_clear_amount
FROM #payment
WHERE isOpen=0
GROUP BY business_year,clear_quarter
ORDER BY business_year,clear_quarter

--2. Running total clear amount by each year
WITH monthly_clear AS(
SELECT business_year
      ,DATEPART(MONTH,clear_date) AS business_month
	  ,SUM(total_open_amount) AS total_clear_amount
FROM #payment
WHERE isOpen=0
GROUP BY business_year,DATEPART(MONTH,clear_date)
)

SELECT business_year
      ,business_month
	  ,total_clear_amount
	  ,SUM(total_clear_amount) OVER (PARTITION BY business_year ORDER BY business_month ASC) AS running_clear_amount
FROM monthly_clear
ORDER BY business_year,business_month

--3. Top ten customer with most overdue repayment times
SELECT top 10 cust_number
	  ,COUNT(*) overdue_times
FROM #payment
WHERE DATEDIFF(DAY,due_in_date,clear_date)>0
GROUP BY cust_number
ORDER BY COUNT(*) DESC

--4. If repayment is overdue and beyond graceday, the customer should be charged penalty as 8% rate of total amount, calculation total penalty
--(graceday can be adjusted)

DECLARE @graceday int
SET @graceday=3

SELECT SUM(PENALTY) AS TOTAL_PENALTY
FROM (
SELECT invoice_id
      ,total_open_amount
	  ,CAST(total_open_amount*(DATEDIFF(DAY,due_in_date,clear_date)-@graceday)*0.08/365 AS decimal(12,2)) AS PENALTY
FROM #payment
WHERE DATEDIFF(DAY,due_in_date,clear_date)>@graceday
AND isOpen=0) T1

--5 Transfer task 4 into a stored procedure, which can let user input graceday as the want and compare the results.
----1) create stored procedure
		--DROP PROCEDURE IF EXISTS graceday_penalty
		CREATE PROCEDURE graceday_penalty
		@graceday INT
		AS
		BEGIN
				SELECT @graceday AS GRACE_DAY
					  ,SUM(PENALTY) AS TOTAL_PENALTY
				FROM (
				SELECT invoice_id
					  ,total_open_amount
					  ,CAST(total_open_amount*(DATEDIFF(DAY,due_in_date,clear_date)-@graceday)*0.08/365 AS decimal(12,2)) AS PENALTY
				FROM (SELECT [business_code]
					  ,[cust_number]
					  ,LOWER(TRIM([name_customer])) as name_customer
					  ,CAST([clear_date] AS DATE) AS clear_date
					  ,DATEPART(quarter,clear_date) AS clear_quarter
					  , CASE WHEN DATEPART(DW,clear_date)=1 THEN 7
							 ELSE DATEPART(DW,clear_date)-1 END AS clear_dow --Set Monday is the first day
					  ,[business_year]
					  ,[doc_id]
					  ,[posting_date]
					  ,DATEDIFF(day,posting_date,due_in_date) as grace_period
					  ,[document_create_date]
					  ,[document_create_date_1]
					  ,[due_in_date]
					  ,[invoice_currency]
					  ,[document_type]
					  ,[posting_id]
					  ,[area_business]
					  ,[total_open_amount]
					  ,[baseline_create_date]
					  ,[cust_payment_terms]
					  ,[invoice_id]
					  ,[isOpen]
				FROM [MyPortfolio].[dbo].[payment]) A
				WHERE DATEDIFF(DAY,due_in_date,clear_date)>@graceday
				AND isOpen=0) T1
		END
		
----2)Business Users can execute with single value
		EXEC graceday_penalty @graceday=2
----3)Business User can also execute multiple times with different values of graceday and compare results in on table.
------create input table
		DROP TABLE IF EXISTS #params
		CREATE TABLE #params (param1 int)
		INSERT INTO #params (param1)
		VALUES (1),(2),(3)   --user can input vlaues here in bracket and seperated by comma
------create output table
		DROP TABLE IF EXISTS #penalty_cal
		CREATE TABLE #penalty_cal
		(
			GRACE_DAY INT,
			TOTAL_PENALTY DECIMAL
		)
------automatically execute mulitple times using cursor
		DECLARE @param INT
		DECLARE curs CURSOR LOCAL FAST_FORWARD FOR
			SELECT param1 FROM #params 

		OPEN curs

		FETCH NEXT FROM curs INTO @param

		WHILE @@FETCH_STATUS = 0 BEGIN
			INSERT INTO #penalty_cal
			EXEC graceday_penalty  @param
			FETCH NEXT FROM curs INTO @param
		END

		CLOSE curs
		DEALLOCATE curs
------show output
		SELECT *
		FROM #penalty_cal
