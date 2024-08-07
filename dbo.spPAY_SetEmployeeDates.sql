﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_SetEmployeeDates]
	@COSTCENTERID [int] = 0,
	@DOCID [int],
	@USERID [int] = 1,
	@LANGID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN  
SET NOCOUNT ON;  
DECLARE @INVDOCDETAILSID INT,@STATUSID INT,@FROMDATE DATETIME,@TODATE DATETIME,@RESIGNSTATUS NVARCHAR(50),@ComponentID BIGINT,@EmpNode BIGINT,@REDATE NVARCHAR(100)  
DECLARE @STRQRY NVARCHAR(MAX) ,@LINKID BIGINT ,@TempToDate datetime ,@Session NVARCHAR(100),@LDocID BIGINT,@NoOfDays float
DECLARE @t TABLE(NoOfDays FLOAT,FromDate DATETIME,ToDate DATETIME,AtATime FLOAT,MAXLEAVES FLOAT,Leavetaken FLOAT,WeekOffCount FLOAT,NoofHolidays FLOAT)

SET @STRQRY=''  
  
IF ISNULL(@DOCID,0)>0  
BEGIN  
 SELECT @INVDOCDETAILSID=INVDOCDETAILSID,@STATUSID=STATUSID FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID  
 IF (@COSTCENTERID=40065)--REJOIN FROM VACATION  
 BEGIN  
  IF((SELECT COUNT(*) FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID AND STATUSID=369)>0) --AND STATUSID=369
  BEGIN  
     
   DECLARE @tID INT  
   SELECT TOP 1 @tID= CONVERT(INT,dcAlpha1)  
   FROM INV_DocDetails a WITH(NOLOCK)   
   JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID  
   WHERE D.tCostCenterID=40061 and a.StatusID=369  
   AND ISNUMERIC(dcAlpha1)=1  
  
   SELECT @FROMDATE=CONVERT(DATETIME,TD.DCALPHA1),@TODATE=CONVERT(DATETIME,TD.DCALPHA2),@ComponentID=cc.dcCCNID52,@EmpNode=cc.dcCCNID51,@REDATE=dcAlpha3,@LINKID=CASE WHEN ID.LinkedInvDocDetailsID>0 THEN ID.LinkedInvDocDetailsID ELSE ID.RefNodeid END FROM 
   COM_DOCTEXTDATA TD WITH(NOLOCK) 
   JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID 
   JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=ID.InvDocDetailsID
   WHERE ID.DOCID=@DOCID  
  
   IF(@tID=@ComponentID)  
   BEGIN  
		UPDATE TD SET TD.dcAlpha1=@REDATE FROM COM_DOCTEXTDATA TD WITH(NOLOCK) INNER JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON TD.INVDOCDETAILSID=CC.INVDOCDETAILSID AND CC.dcCCNID51=@EMPNODE  
		INNER JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID And TD.tCostCenterID=40072 AND ISDATE(TD.DCALPHA2)=1 AND ISDATE(TD.DCALPHA3)=1  
		AND CONVERT(DATETIME,TD.DCALPHA2)=CONVERT(DATETIME,@FROMDATE) AND CONVERT(DATETIME,TD.DCALPHA3)=CONVERT(DATETIME,@TODATE)  
   END  
   ELSE  
   BEGIN  
		SELECT @LDocID=I.DocID,@Session=T.dcAlpha6 FROM INV_DocDetails I WITH(NOLOCK) 
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		WHERE I.InvDocDetailsID=@LINKID

		IF(CONVERT(DATETIME,@REDATE)<=CONVERT(DATETIME,@TODATE) AND ISNULL(@Session,'Both')='Both')
	   	BEGIN
			set @TempToDate=DATEADD(d,-1,convert(datetime,@REDATE))

			INSERT INTO @t
			EXEC spPAY_ExtGetNoofDays @FROMDATE,@TempToDate,@EmpNode,@ComponentID,'Both',@LDocID,1,1

			SELECT @NoOfDays=ISNULL(NoOfDays,0) From @t

			UPDATE TD   
			SET TD.dcAlpha15=@REDATE,TD.dcAlpha17=TD.dcAlpha5,TD.dcAlpha18=TD.dcAlpha7
			FROM COM_DOCTEXTDATA TD  WITH(NOLOCK) 
			JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON TD.INVDOCDETAILSID=CC.INVDOCDETAILSID   
			JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID   
			WHERE TD.tDocumentType=62 AND CC.dcCCNID51=@EMPNODE AND CC.dcCCNID52=@ComponentID  
			AND ISDATE(TD.DCALPHA4)=1 AND ISDATE(TD.DCALPHA5)=1  
			AND CONVERT(DATETIME,TD.DCALPHA4)=CONVERT(DATETIME,@FROMDATE) AND CONVERT(DATETIME,TD.DCALPHA5)=CONVERT(DATETIME,@TODATE)

			UPDATE TD   
			SET TD.dcAlpha5=CONVERT(VARCHAR(20), DATEADD(D,-1,CONVERT(DATETIME,@REDATE)), 106),TD.dcAlpha7=@NoOfDays
			FROM COM_DOCTEXTDATA TD  WITH(NOLOCK) 
			JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON TD.INVDOCDETAILSID=CC.INVDOCDETAILSID   
			JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID   
			WHERE TD.tDocumentType=62 AND CC.dcCCNID51=@EMPNODE AND CC.dcCCNID52=@ComponentID  
			AND ISDATE(TD.DCALPHA4)=1 AND ISDATE(TD.DCALPHA5)=1  
			AND CONVERT(DATETIME,TD.DCALPHA4)=CONVERT(DATETIME,@FROMDATE) AND CONVERT(DATETIME,TD.DCALPHA5)=CONVERT(DATETIME,@TODATE)

			UPDATE TD SET  TD.DCALPHA2=CONVERT(VARCHAR(20), DATEADD(D,-1,CONVERT(DATETIME,@REDATE)), 106)
			FROM COM_DOCTEXTDATA TD WITH(NOLOCK) 
			JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID 
			WHERE ID.DOCID=@DOCID 
	   END
	   ELSE
	   BEGIN
			UPDATE TD   
			SET TD.dcAlpha15=@REDATE
			FROM COM_DOCTEXTDATA TD  WITH(NOLOCK) 
			JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON TD.INVDOCDETAILSID=CC.INVDOCDETAILSID   
			JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID   
			WHERE TD.tDocumentType=62 AND CC.dcCCNID51=@EMPNODE AND CC.dcCCNID52=@ComponentID  
			AND ISDATE(TD.DCALPHA4)=1 AND ISDATE(TD.DCALPHA5)=1  
			AND CONVERT(DATETIME,TD.DCALPHA4)=CONVERT(DATETIME,@FROMDATE) AND CONVERT(DATETIME,TD.DCALPHA5)=CONVERT(DATETIME,@TODATE)  
	END	
   END  
  
  END   
 END  
END  
END
GO
