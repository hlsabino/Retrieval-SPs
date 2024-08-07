﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetTimings]
	@DailyAttDate [datetime],
	@EmpID [int] = 0,
	@WhereDim [nvarchar](max) = NULL,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ISVALIDDAY INT

	DECLARE @TAB2 TABLE (ISVALIDDAY INT,LEAVETYPENAME VARCHAR(50),LEAVETYPENODEID INT)
	DECLARE @STARTTIME TIME,@ENDTIME TIME,@STARTDATETIME VARCHAR(30),@ENDDATETIME VARCHAR(30),@HOURS DECIMAL(9,2),@STRQUERY NVARCHAR(MAX)
	CREATE TABLE #GENERALTIMINGS (ID INT IDENTITY(1,1),STARTTIME TIME,ENDTIME TIME,LOCATION INT)

	--FOR CHECKING THE SELECTED DATE IS WEEKLYOFF OR HOLIDAY
	INSERT INTO @TAB2
	EXEC [spPAY_ExtGetCompensatoryLeaveDates] @DailyAttDate,@EmpID

	SELECT @ISVALIDDAY=ISVALIDDAY FROM @TAB2

	SET @STRQUERY=''
	SET @STRQUERY='
					 SELECT '''+CONVERT(VARCHAR,CONVERT(DATE,@DailyAttDate))+'''+ '' '' + CONVERT(VARCHAR,CAST(ISNULL(TD.DCALPHA1,''00:00'')AS TIME)) STARTTIME,'''+CONVERT(VARCHAR,CONVERT(DATE,@DailyAttDate))+'''+ '' '' + CONVERT(VARCHAR,CAST(ISNULL(TD.DCALPHA2,''00:00'')AS TIME)) ENDTIME,'''+CONVERT(VARCHAR,@ISVALIDDAY)+''' VALIDDAY,CONVERT(DATETIME,TD.dcAlpha3) EffectFrom,DC.* 
					 FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
					 WHERE TD.tCOSTCENTERID=40052 AND ID.STATUSID=369 AND ISDATE(TD.dcAlpha3)=1 AND CONVERT(DATETIME,TD.dcAlpha3)<='''+ CONVERT(NVARCHAR,CONVERT(DATETIME,@DailyAttDate),106)+''''
		
	IF LEN(@WhereDim)>0
	BEGIN
		SET @STRQUERY=@STRQUERY+@WhereDim
		SET @STRQUERY=@STRQUERY+' ORDER BY CONVERT(DATETIME,TD.dcAlpha3) DESC'
	END
	--PRINT (@STRQUERY)
	EXEC sp_executesql @STRQUERY

	
	--IF((SELECT COUNT(*) FROM #GENERALTIMINGS)>0)
	--BEGIN
	--	SELECT @STARTTIME=STARTTIME,@ENDTIME=ENDTIME FROM #GENERALTIMINGS
	--	SET @STARTDATETIME=CONVERT(VARCHAR,CONVERT(DATE,@DailyAttDate))+' '+CONVERT(VARCHAR,CONVERT(TIME,@STARTTIME))
	--	SET @ENDDATETIME=CONVERT(VARCHAR,CONVERT(DATE,@DailyAttDate))+' '+CONVERT(VARCHAR,CONVERT(TIME,@ENDTIME))
	--END
	--ELSE
	--BEGIN
	--	SET @STARTDATETIME=CONVERT(VARCHAR,CONVERT(DATE,@DailyAttDate))+' '+'00:00'
	--	SET @ENDDATETIME=CONVERT(VARCHAR,CONVERT(DATE,@DailyAttDate))+' '+'00:00'
	--END

	--SELECT @STARTDATETIME AS STARTTIME,@ENDDATETIME AS ENDTIME,@ISVALIDDAY AS VALIDDAY

	DROP TABLE #GENERALTIMINGS	

SET NOCOUNT OFF; 
END

GO
