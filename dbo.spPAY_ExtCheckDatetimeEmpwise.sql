﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtCheckDatetimeEmpwise]
	@COSTCENTERID [int],
	@DOCID [int],
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

DECLARE @DAILYATTENDANCEDATE DATETIME
DECLARE @RC AS INT,@TRC AS INT,@EmployeeID INT
DECLARE @TAB1 TABLE(ID INT IDENTITY(1,1),EMPNODE INT,DAILYATTDATE DATETIME,STARTDATETIME DATETIME,PREVIOUSRECORDENDDATIME DATETIME,DOCID INT)

INSERT INTO @TAB1    
	SELECT DC.DCCCNID51,CONVERT(DATETIME,TD.DCALPHA1),CONVERT(DATETIME,TD.DCALPHA2),'',@DOCID FROM COM_DOCTEXTDATA TD WITH(NOLOCK)
		   JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
	WHERE  ID.DOCID=@DOCID AND ID.COSTCENTERID=@COSTCENTERID
 
SET @DAILYATTENDANCEDATE=(SELECT TOP 1 CONVERT(DATETIME,DAILYATTDATE) FROM @TAB1)

SET @RC=1
SELECT @TRC=COUNT(*) FROM @TAB1
WHILE (@RC<=@TRC)
BEGIN	
	SELECT @EmployeeID=EMPNODE FROM @TAB1 WHERE ID=@RC
	UPDATE T1 SET T1.PREVIOUSRECORDENDDATIME=CONVERT(DATETIME,T.EDT) FROM @TAB1 AS T1 INNER JOIN 
		(SELECT TOP 1 DC.DCCCNID51 A ,CONVERT(DATETIME,TD.DCALPHA3) EDT FROM COM_DOCTEXTDATA TD WITH(NOLOCK) JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
	     WHERE ID.DOCID<>@DOCID AND DC.DCCCNID51=@EmployeeID AND ID.STATUSID NOT IN (372,376)AND ISDATE(TD.DCALPHA1)=1 AND ISDATE(TD.DCALPHA3)=1 AND ID.COSTCENTERID=@COSTCENTERID 
			   AND CONVERT(DATETIME,DCALPHA1)<=CONVERT(DATETIME,@DAILYATTENDANCEDATE) ORDER BY CONVERT(DATETIME,DCALPHA1) DESC) T ON T.A=T1.EMPNODE
SET @RC=@RC+1
END

IF((SELECT COUNT(*) FROM @TAB1 WHERE   CONVERT(DATETIME,STARTDATETIME)<CONVERT(DATETIME,PREVIOUSRECORDENDDATIME))>0)
	RAISERROR('-550',16,1) 
ELSE
	EXEC spPAY_GetExtPayrollProcessedDetails @COSTCENTERID,@DOCID,@UserID,@LangID

SET NOCOUNT OFF;
END
GO
