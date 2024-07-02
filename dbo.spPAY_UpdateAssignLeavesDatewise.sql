﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_UpdateAssignLeavesDatewise]
	@DATE [datetime],
	@INVDOCDETAILSID [int],
	@Mode [int],
	@EMPNODE [int],
	@LEAVETYPE [int],
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
--START:FOR START AND END MONTH	
	DECLARE @Year INT,@ALStartMonth INT,@ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME,@CURRYEARALDOCNO INT,@ASSIGNEDLEAVES FLOAT,@BALANCELEAVES FLOAT,@ASSIGNEDLEAVESAL FLOAT
	DECLARE @CURRYEARLEAVESTAKEN FLOAT,@PREVYEARALLOTEDLEAVES FLOAT,@CURRYEARBALLEAVES FLOAT,@CURRDOCLEAVESTAKEN FLOAT,@AppliedEncashdays FLOAT,@CurrDocAppliedEncashdays FLOAT,@COMPENSATORYLEAVES FLOAT,@CURRDOCCOMPENSATORYLEAVES FLOAT,@CURRYEARFSENCASHDAYS FLOAT,@CURRDOCFSENCASHDAYS FLOAT
	
	EXEC [spPAY_EXTGetLeaveyearDates] @DATE,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
	
		--CURRENT YEAR CONSUMED LEAVES	
		SET @CURRYEARLEAVESTAKEN=(SELECT SUM(ISNULL(CONVERT(FLOAT,TD.dcAlpha7),0)) FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
		  						         INNER JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
		  						  WHERE  TD.tDocumentType=62 AND DC.DCCCNID51=@EMPNODE AND DC.DCCCNID52=@LEAVETYPE And ID.STATUSID NOT IN (372,376) --AND ID.STATUSID=369
		  								 AND ISNUMERIC(TD.DCALPHA7)=1 AND ISDATE(TD.DCALPHA4)=1
		  								 AND CONVERT(DATETIME,TD.DCALPHA4) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear))
	  
	   --CURRENT DOCUMENT CONSUMED LEAVES	  								 
	   SET @CURRDOCLEAVESTAKEN=(SELECT   SUM(ISNULL(CONVERT(FLOAT,TD.dcAlpha7),0)) FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
		  						         INNER JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
		  						  WHERE  TD.tDocumentType=62 AND DC.DCCCNID51=@EMPNODE AND DC.DCCCNID52=@LEAVETYPE And ID.STATUSID NOT IN (372,376)--AND ID.STATUSID=369
		  								 AND ISNUMERIC(TD.DCALPHA7)=1 AND ISDATE(TD.DCALPHA4)=1 AND ID.INVDOCDETAILSID=@INVDOCDETAILSID
		  								 AND CONVERT(DATETIME,TD.DCALPHA4) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear))

	   --CURRENT YEAR ENCASHED LEAVES
	   SET @AppliedEncashdays=(SELECT  SUM(CONVERT(decimal(9,2),TD.DCALPHA3))
								FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
		  						       INNER JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID And ID.STATUSID NOT IN (372,376)--AND ID.STATUSID=369
								WHERE TD.tCostCenterID=40058 AND ISNUMERIC(TD.DCALPHA3)=1 AND CONVERT(DATETIME,id.DocDate) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)  AND   DC.DCCCNID51=@EMPNODE AND DC.DCCCNID52=@LEAVETYPE)	  

	  --CURRENT DOCUMENT ENCASHED LEAVES									   
	  SET @CurrDocAppliedEncashdays=(SELECT SUM(CONVERT(decimal(9,2),TD.DCALPHA3))
								FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
		  						       INNER JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
								WHERE TD.tCostCenterID=40058 AND  ISNUMERIC(TD.DCALPHA3)=1 AND ID.INVDOCDETAILSID=@INVDOCDETAILSID And ID.STATUSID NOT IN (372,376)--AND ID.STATUSID=369
									   AND CONVERT(DATETIME,@DATE) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
									   AND  DC.DCCCNID51=@EMPNODE AND DC.DCCCNID52=@LEAVETYPE)	  									   
									   
	  --CURRENT DOCUMENT COMPENSATORY LEAVES	  								 									   
	  SET @COMPENSATORYLEAVES=(SELECT  COUNT(ID.DocID)
								FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
		  						       INNER JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
		  						        INNER JOIN COM_DOCNUMDATA DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID
								WHERE TD.tCostCenterID=40059 And  ISDATE(TD.DCALPHA1)=1 AND ID.INVDOCDETAILSID=@INVDOCDETAILSID
									   AND CONVERT(DATETIME,TD.DCALPHA1) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
									   AND ID.STATUSID NOT IN (372,376)--AND ID.STATUSID=369 
									   AND  DC.DCCCNID51=@EMPNODE AND DC.DCCCNID52=@LEAVETYPE)
									   
									   
	 SET @ASSIGNEDLEAVES=(SELECT  ISNULL(DN.DCNUM3,0)
								FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
		  						       INNER JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
		  						         INNER JOIN COM_DOCNUMDATA DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID
								WHERE TD.tCostCenterID=40060 AND  ISDATE(TD.DCALPHA3)=1 AND ID.INVDOCDETAILSID=@INVDOCDETAILSID And ID.STATUSID NOT IN (372,376)--AND ID.STATUSID=369
									   AND CONVERT(DATETIME,TD.DCALPHA3) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
									   AND  DC.DCCCNID51=@EMPNODE AND DC.DCCCNID52=@LEAVETYPE)	
									   
	SET @ASSIGNEDLEAVESAL=(SELECT  ISNULL(DN.DCNUM3,0)
								FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
		  						       INNER JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
		  						         INNER JOIN COM_DOCNUMDATA DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID
								WHERE TD.tCostCenterID=40081 AND  ISDATE(TD.DCALPHA3)=1 AND ID.INVDOCDETAILSID=@INVDOCDETAILSID And ID.STATUSID NOT IN (372,376)--AND ID.STATUSID=369
									   AND CONVERT(DATETIME,TD.DCALPHA3) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
									   AND  DC.DCCCNID51=@EMPNODE AND DC.DCCCNID52=@LEAVETYPE)									   								   										  							
	
										   
	SET @CURRYEARFSENCASHDAYS=(SELECT sum(CONVERT(decimal(9,2),TD.DCALPHA15))
							FROM   INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
							JOIN COM_DocNumData DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID 
							JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
							JOIN COM_CC50052 C52 WITH(NOLOCK) ON C52.NAME=TD.dcAlpha12
							WHERE TD.tCostCenterID=40095 AND ID.STATUSID NOT IN (372,376) AND ISNUMERIC(TD.dcAlpha1)=1 AND CONVERT(FLOAT,TD.dcAlpha1)=2 AND  DC.DCCCNID51=@EMPNODE  AND C52.NodeID=@LeaveType
							 AND ISNUMERIC(TD.DCALPHA15)=1	AND (CONVERT(DATETIME,TD.dcAlpha3)) BETWEEN (CONVERT(DATETIME,@ALStartMonthYear))  AND (CONVERT(DATETIME,@ALEndMonthYear)))		
							 
	SET @CURRDOCFSENCASHDAYS=(SELECT sum(CONVERT(decimal(9,2),TD.DCALPHA15))
							FROM   INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
							JOIN COM_DocNumData DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID 
							JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
							JOIN COM_CC50052 C52 WITH(NOLOCK) ON C52.NAME=TD.dcAlpha12
							WHERE TD.tCostCenterID=40095 AND ID.STATUSID NOT IN (372,376) AND ISNUMERIC(TD.dcAlpha1)=1 AND CONVERT(FLOAT,TD.dcAlpha1)=2 AND  DC.DCCCNID51=@EMPNODE  AND C52.NodeID=@LeaveType AND ID.INVDOCDETAILSID=@INVDOCDETAILSID
							 AND ISNUMERIC(TD.DCALPHA15)=1	AND (CONVERT(DATETIME,TD.dcAlpha3)) BETWEEN (CONVERT(DATETIME,@ALStartMonthYear))  AND (CONVERT(DATETIME,@ALEndMonthYear)))							   								   										  							
											   
	SET @ASSIGNEDLEAVES=ISNULL(@ASSIGNEDLEAVES,0)+ISNULL(@ASSIGNEDLEAVESAL,0)
		
		IF((SELECT COUNT(*) FROM PAY_EmployeeLeaveDetails WITH(NOLOCK) WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,@ALStartMonthYear))>0)
		BEGIN	
		  --DEDUCTING LEAVES
		  UPDATE PAY_EmployeeLeaveDetails SET DeductedLeaves=ISNULL(@CURRYEARLEAVESTAKEN,0)+ISNULL(@AppliedEncashdays,0)+ISNULL(@CURRYEARFSENCASHDAYS,0) WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,@ALStartMonthYear)
		  
		  --DELETING LEAVES
		  IF ISNULL(@Mode,0)=1 --DEDUCTION OF POSTED/APPROVED LEAVES(DELETE)
		  BEGIN
				UPDATE PAY_EmployeeLeaveDetails SET DeductedLeaves=ISNULL(DeductedLeaves,0)-(ISNULL(@CURRDOCLEAVESTAKEN,0)+ISNULL(@CURRDOCFSENCASHDAYS,0)+ISNULL(@CurrDocAppliedEncashdays,0)) WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,@ALStartMonthYear)
				UPDATE PAY_EmployeeLeaveDetails SET AssignedLeaves=ISNULL(AssignedLeaves,0)-(ISNULL(@COMPENSATORYLEAVES,0)) WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,@ALStartMonthYear) AND ISNULL(AssignedLeaves,0)>0
				UPDATE PAY_EmployeeLeaveDetails SET AssignedLeaves=ISNULL(AssignedLeaves,0)-(ISNULL(@ASSIGNEDLEAVES,0)) WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,@ALStartMonthYear) AND ISNULL(AssignedLeaves,0)>0
		  END
		  
		  SELECT @BALANCELEAVES=(ISNULL(OpeningBalance,0)+ISNULL(AssignedLeaves,0))-ISNULL(DeductedLeaves,0) FROM PAY_EmployeeLeaveDetails WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,@ALStartMonthYear)
		  
		  UPDATE PAY_EmployeeLeaveDetails SET OpeningBalance=@BALANCELEAVES  WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,DATEADD(YEAR,1,@ALStartMonthYear))
		  
		  --UPDATING BALANCE FOR BOTH CURRENT AND PREVIOUS YEAR LEAVES
		  UPDATE PAY_EmployeeLeaveDetails SET BalanceLeaves=(ISNULL(OpeningBalance,0)+ISNULL(AssignedLeaves,0))-ISNULL(DeductedLeaves,0) WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,@ALStartMonthYear)
		  UPDATE PAY_EmployeeLeaveDetails SET BalanceLeaves=(ISNULL(OpeningBalance,0)+ISNULL(AssignedLeaves,0))-ISNULL(DeductedLeaves,0) WHERE EMPLOYEEID=@EMPNODE AND LEAVETYPEID=@LEAVETYPE AND CONVERT(DATETIME,LeaveYear)=CONVERT(DATETIME,DATEADD(YEAR,1,@ALStartMonthYear))
	   END
SET NOCOUNT OFF;
END
GO