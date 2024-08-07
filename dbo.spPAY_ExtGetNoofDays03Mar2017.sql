﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetNoofDays03Mar2017]
	@FromDate [varchar](20) = null,
	@ToDate [varchar](20) = null,
	@EmployeeID [int] = 0,
	@LeaveType [int] = 0,
	@Session [varchar](20) = null,
	@userid [int] = 1,
	@langid [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @NOOFHOLIDAYS INT,@WEEKLYOFFCOUNT INT,@GRADE INT,@INCREXC VARCHAR(50),@ATATIME INT,@MAXLEAVES DECIMAL(9,2),@CurrYearLeavestaken DECIMAL(9,2),@CurrMonthOpeningBalance DECIMAL(9,2)
	DECLARE @Year INT,@ALStartMonth INT,@ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME,@EXSTAPPLIEDENCASHDAYS DECIMAL(9,2),@PayrollDate DATETIME
	DECLARE @MONTHTAB TABLE(ID INT IDENTITY(1,1),STDATE DATETIME,EDDATE DATETIME)
	
	SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@FromDate)),0)
	
	--START:FOR START DATE AND END DATE OF LEAVE YEAR
	EXEC [spPAY_EXTGetLeaveyearDates] @FromDate,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
		
	--FOR GRADE
	SELECT @GRADE=ISNULL(CCNID53,0) FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID=@EmployeeID
	
 IF  DATEDIFF(D,CONVERT(DATETIME,@FromDate),CONVERT(DATETIME,@ToDate))<=100
 BEGIN		
		IF ((SELECT COUNT(*)  FROM COM_DocTextData TD WITH(NOLOCK),INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC  WITH(NOLOCK)
			 WHERE  TD.InvDocDetailsID=DC.InvDocDetailsID AND	ID.InvDocDetailsID=TD.InvDocDetailsID AND ID.CostCenterID=40062 AND
				    DC.dcCCNID51=@EmployeeID AND DC.dcCCNID52=@LeaveType AND --DC.dcCCNID53=@GRADE AND 
				   isnull(td.dcalpha10,0)=0 and 
				    ID.STATUSID NOT IN (372,376) AND ISDATE(TD.dcAlpha4)=1 AND ISDATE(TD.dcAlpha5)=1 AND
				    (
				     CONVERT(DATETIME,dcAlpha4) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)
					 or CONVERT(DATETIME,dcAlpha5) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)
					 or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5)
					 or CONVERT(DATETIME,@ToDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha4)) )<=0)
		BEGIN
			IF(@FromDate is not null and @ToDate is not null and isnull(@Session,'Both')='Both')
			BEGIN			
				--INCLUDE OR EXCLUDE HOLIDAYS, ATATIME,MAXLEAVES AND WEEKLYOFFS
				SELECT @INCREXC=ISNULL(INCLUDEREXCLUDE,''),@ATATIME=ISNULL(ATATIME,0),@MAXLEAVES=ISNULL(MAXLEAVES,0) FROM COM_CC50054 WITH(NOLOCK) 
				WHERE  GRADEID=@GRADE AND COMPONENTID=@LeaveType AND CONVERT(DATETIME,PAYROLLDATE)=CONVERT(DATETIME,@PayrollDate) 
								
				--FOR LEAVES TAKEN,HOLIDAYS AND WEEKLYOFFS IN A YEAR
				EXEC [spPAY_GetCurrYearLeavesInfo] @FromDate,@ToDate,@EmployeeID,@LeaveType,@userid,@langid,@FromDate,0,@CurrYearLeavestaken OUTPUT,@NOOFHOLIDAYS OUTPUT,@WEEKLYOFFCOUNT OUTPUT,@EXSTAPPLIEDENCASHDAYS OUTPUT
				PRINT @CurrYearLeavestaken
				PRINT @NOOFHOLIDAYS
				PRINT @WEEKLYOFFCOUNT
				
				IF ISNULL(@MAXLEAVES,0)>0
				BEGIN
					SET @MAXLEAVES=ISNULL(@MAXLEAVES,0)-(ISNULL(@CurrYearLeavestaken,0)+ISNULL(@EXSTAPPLIEDENCASHDAYS,0))
				END
				IF ISNULL(@INCREXC,'')='IncludeHolidays' OR ISNULL(@INCREXC,'')='ExcludeWeeklyOffs'
				BEGIN
					SELECT (DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101))-ISNULL(@NOOFHOLIDAYS,0))+1 as NoOfDays ,CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@ATATIME AS AtATIME,@MAXLEAVES AS MAXLEAVES
				END
				ELSE IF ISNULL(@INCREXC,'')='IncludeWeeklyOffs' OR ISNULL(@INCREXC,'')='ExcludeHolidays'
				BEGIN
					SELECT (DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101))-ISNULL(@WEEKLYOFFCOUNT,0))+1 as NoOfDays ,CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@ATATIME AS AtATIME,@MAXLEAVES AS MAXLEAVES
				END
				ELSE IF ISNULL(@INCREXC,'')='IncludeBoth'
				BEGIN
					SELECT (DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101))-ISNULL(@NOOFHOLIDAYS,0)-ISNULL(@WEEKLYOFFCOUNT,0))+1 as NoOfDays ,CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@ATATIME AS AtATIME,@MAXLEAVES AS MAXLEAVES
				END
				ELSE IF ISNULL(@INCREXC,'')='ExcludeBoth'
				BEGIN
					SELECT (DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101)))+1 as NoOfDays ,CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@ATATIME AS AtATIME,@MAXLEAVES AS MAXLEAVES
				END
			END	
			ELSE IF ISNULL(@Session,'')='Session1' OR ISNULL(@Session,'')='Session2'
			BEGIN
				SET @ToDate=@FromDate
				SELECT 0.5 as NoOfDays,CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@ATATIME AS AtATIME,@MAXLEAVES AS MAXLEAVES
			END
		END
		ELSE
		BEGIN
			SELECT -1 AS NoOfDays,CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,0 AS AtATIME,0 AS MAXLEAVES
		END
 END
 ELSE
 BEGIN
			SELECT -1 AS NoOfDays,CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,0 AS AtATIME,0 AS MAXLEAVES
 END
SET NOCOUNT OFF; 
END
GO
