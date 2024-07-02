USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_EXTGetAssignLeavesDates]
	@StartDate [datetime] = null,
	@EndDate [datetime] = null,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
	Declare @FromMonthName VARCHAR(15),@StartYear INT,@StartDateOP DATETIME,@EndDateOP DATETIME,@FromDate DATETIME,@ToDate DATETIME
	select @StartYear=year(@StartDate)
	select @FromMonthName=DATENAME(M,@StartDate)
		
	SET @StartDateOP= CONVERT(VARCHAR,@StartYear)+'-' + @FromMonthName +'-' +'01'
	SET @StartDateOP=CONVERT(DATETIME,@StartDateOP)
	
	IF convert(datetime,@StartDate)<> convert(datetime,@EndDate)
	BEGIN
		SET @EndDateOP=@EndDate
		--SET LAST DATE TO ENDMONTH 
		SET @EndDateOP=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@EndDateOP)+1,0))
		SET @EndDateOP=CONVERT(DATETIME,@EndDateOP)
	END
	ELSE
	BEGIN
	SET @EndDateOP=@EndDate
	END
	
	
	--START : FISCAL YEAR	
	DECLARE @Year INT,@ALStartMonth INT,@ALStartMonthYear1 DATETIME,@ALEndMonthYear1 DATETIME
	
	SELECT @Year=YEAR(CONVERT(DATETIME,@StartDate))
	--PRINT @Year
	--FOR READING START MONTH FROM GLOBAL PREFERENCES
	SELECT @ALStartMonth=ISNULL(VALUE,1) FROM ADM_GlobalPreferences WHERE (NAME='LeaveYear' OR RESOURCEID=94471)
	
	--SET FIRST DATE TO GIVEN MONTH IN GLOBAL PREFERENCES
	SET @ALStartMonthYear1= CONVERT(VARCHAR,@Year)+'-' + DATENAME(MONTH,DATEADD(MONTH,@ALStartMonth,-1))+'-' +'01'
	SET @ALStartMonthYear1=CONVERT(DATETIME,@ALStartMonthYear1)
	--PRINT @ALStartMonthYear
	
	--SET ENDMONTH FOR THE NEXT YEAR (1YEAR)
	SET @ALEndMonthYear1=DATEADD(M,11,@ALStartMonthYear1)
	
	--SET LAST DATE TO ENDMONTH FOR THE NEXT YEAR (1YEAR)
	SET @ALEndMonthYear1=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALEndMonthYear1)+1,0))
	SET @ALEndMonthYear1=CONVERT(DATETIME,@ALEndMonthYear1)
	--PRINT @ALEndMonthYear
		
	if CONVERT(DATETIME,@StartDate)<CONVERT(DATETIME,@ALStartMonthYear1)
	BEGIN
		SET @ALStartMonthYear1=DATEADD(YEAR,-1,CONVERT(DATETIME,@ALStartMonthYear1))
		SET @ALEndMonthYear1=DATEADD(YEAR,-1,CONVERT(DATETIME,@ALEndMonthYear1))
	END
	
	SELECT @FromDate=CONVERT(DATETIME,@ALStartMonthYear1),@ToDate=CONVERT(DATETIME,@ALEndMonthYear1)
	--END : FISCAL YEAR		
	IF convert(datetime,@StartDate)<> convert(datetime,@EndDate)
	BEGIN
		SELECT @StartDateOP as FromDate,@EndDateOP as Todate,@ToDate AS LeaveyearEndDate
	END
	ELSE
	BEGIN
		SELECT @StartDateOP as FromDate,@ToDate AS LeaveyearEndDate
	END		
	
	print @StartDateOP
	print @EndDateOP
	SET NOCOUNT OFF;		
END
GO
