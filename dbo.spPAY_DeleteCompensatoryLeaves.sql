﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_DeleteCompensatoryLeaves]
	@COSTCENTERID [int],
	@DOCID [int],
	@detID [nvarchar](max),
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

DECLARE @FROMDATE DATETIME,@INVDOCID INT,@EMPNODE INT,@STATUSID INT,@LEAVETYPE INT
DECLARE @ICOUNT INT,@RCOUNT INT,@LinkedInvDocDetailsID INT
DECLARE @Year INT,@ALStartMonth INT,@ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME,@LEAVETYPEGP INT,@CURRYEARALDOCNO INT

SET @ICOUNT=1

DECLARE @TAB1 TABLE (ID INT IDENTITY(1,1),INVDOCDETAILSID INT,FROMDATE DATETIME,EMPNODE INT,LEAVETYPE INT)
DECLARE @UPDATEASSIGNLEAVES TABLE(InvDocID INT,dcCCNID51 INT,dcCCNID53 INT,dcCCNID52 INT,
								  PrevYearAlloted INT,PrevYearBalanceOB INT,CurrYearConsumed DECIMAL(9,2),
								  Balance DECIMAL(9,2),CurrYearAlloted INT,CompensatoryLeave INT)
											

	
	IF ISNULL(@DOCID,0)>0
	BEGIN
		SELECT @STATUSID=ISNULL(STATUSID,0) FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID
		IF @STATUSID=369 
		BEGIN
				INSERT INTO @TAB1
				SELECT ID.INVDOCDETAILSID,CONVERT(DATETIME,TD.dcAlpha1),ISNULL(CC.DCCCNID51,0),ISNULL(CC.DCCCNID52,0)
				FROM   INV_DOCDETAILS ID WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK),COM_DOCCCDATA CC WITH(NOLOCK)
				WHERE  ID.INVDOCDETAILSID=TD.INVDOCDETAILSID  AND ID.INVDOCDETAILSID=CC.INVDOCDETAILSID AND TD.INVDOCDETAILSID=CC.INVDOCDETAILSID
				       AND ID.DOCID=@DOCID
				
					SELECT @RCOUNT =COUNT(*) FROM @TAB1
				  	WHILE(@ICOUNT<=@RCOUNT)
					BEGIN
								SELECT @INVDOCID=INVDOCDETAILSID,@FROMDATE=CONVERT(DATETIME,FROMDATE),@EMPNODE=EMPNODE,@LEAVETYPE=LEAVETYPE FROM @TAB1 WHERE ID=@ICOUNT
								
								----FOR START DATE AND END DATE OF LEAVEYEAR
								EXEC [spPAY_EXTGetLeaveyearDates] @FROMDATE,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
								EXEC spPAY_UpdateAssignLeavesDatewise @FROMDATE,@INVDOCID,1,@EMPNODE,@LEAVETYPE
							
							--DELETE FROM @UPDATEASSIGNLEAVES										 
							--INSERT INTO @UPDATEASSIGNLEAVES 
							--SELECT ID.INVDOCDETAILSID,DC.dcCCNID51,DC.dcCCNID53,DC.dcCCNID52,0,0,0,0,ISNULL(DN.DCNUM3,0),0
							--FROM   INV_DOCDETAILS ID WITH(NOLOCK),COM_DocCCData DC WITH(NOLOCK),COM_DocNumData DN WITH(NOLOCK)
							--WHERE  ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DN.INVDOCDETAILSID AND DC.INVDOCDETAILSID=DN.INVDOCDETAILSID
							--	   AND  CONVERT(DATETIME,ID.DOCDATE) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
							--	   AND ID.COSTCENTERID=40060
							--	   --ID.DOCID=@CURRYEARALDOCNO

							--UPDATE T SET T.CompensatoryLeave=ISNULL(LT.NOOFDAYSTAKEN,0),T.Balance=ISNULL(LT.NOOFDAYSTAKEN,0) FROM @UPDATEASSIGNLEAVES T 
							--INNER JOIN
							--(SELECT DC.dcCCNID51,DC.dcCCNID53,DC.DCCCNID52,COUNT(TD.dcAlpha1) AS NOOFDAYSTAKEN
							-- FROM COM_DocTextData TD,INV_DOCDETAILS ID,COM_DocCCData DC 
							-- WHERE  TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND TD.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND
							--		ISDATE(TD.DCALPHA1)=1 AND
							--		CONVERT(VARCHAR(25),TD.DCALPHA1,106) between CONVERT(VARCHAR(25),@ALStartMonthYear,106) and  CONVERT(VARCHAR(25),@ALEndMonthYear,106)
							--		AND ID.COSTCENTERID=40059 AND ID.INVDOCDETAILSID=@INVDOCID AND DC.dcCCNID51=@EMPNODE GROUP BY DC.dcCCNID51,DC.dcCCNID53,DC.DCCCNID52
							--) LT  
							--ON LT.DCCCNID51=T.DCCCNID51   AND LT.DCCCNID52=T.DCCCNID52 
				
							--UPDATE DN SET DN.DCNUM3= DN.DCNUM3-ISNULL(T.CompensatoryLeave,0), DN.DCNUM5= DN.DCNUM5-ISNULL(T.CompensatoryLeave,0) 
							--FROM   COM_DocNumData DN 
		   		--				   INNER JOIN  @UPDATEASSIGNLEAVES T ON T.InvDocID=DN.INVDOCDETAILSID AND T.DCCCNID51=@EMPNODE
				SET @ICOUNT=@ICOUNT+1	
				END
		END
	END
SET NOCOUNT OFF;
END
GO
