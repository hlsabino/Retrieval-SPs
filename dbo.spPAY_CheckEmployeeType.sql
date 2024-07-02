﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_CheckEmployeeType]
	@UserID [int],
	@RoleID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	DECLARE @EmpID INTEGER
	SELECT @EmpID=EMP.NodeID 
		FROM COM_CostCenterCostCenterMap CCMAP WITH(NOLOCK),
			COM_CC50051 EMP WITH(NOLOCK)
		WHERE CCMAP.NodeID=EMP.NodeID 
			AND CCMAP.COSTCENTERID=50051 
			AND CCMAP.ParentNodeID=@UserID
		
	SELECT NodeID,Name,IsManager,RptManager 
		FROM COM_CC50051 
		WHERE NodeID = @EmpID
	
create table #TblUsrWF(WID int,LevelID int,Type int)
EXEC spRPT_GetReportData @Type=8,@Param1=@UserID,@strXML=null,@RoleID=@RoleID
 SELECT INV.INVDOCDETAILSID,INV.VoucherNo ,INV.DocAbbr,INV.DocPrefix,CONVERT(INT,INV.DocNumber)DocNumber,T4.Status
 ,CONVERT(NVARCHAR(12),CONVERT(DATETIME,T5.DCALPHA4),106) FROMDATE,CONVERT(NVARCHAR(12),CONVERT(DATETIME,T5.DCALPHA5),106) TODATE,T5.DCALPHA7 NOOFDAYS
 ,T7.Name EmpName,T8.Name LeaveType,INV.LINENARRATION,INV.StatusID,T5.dcAlpha3 Balance
 FROM INV_DocDetails INV with(nolock),
	ADM_Users T3 with(nolock),
	COM_Status T4 with(nolock),
	COM_DocTextData T5 with(nolock),
	COM_DocCCData T6 with(nolock),
	COM_CC50051 T7 WITH(NOLOCK),
	COM_CC50052 T8 WITH(NOLOCK),
	#TblUsrWF WF
 WHERE  INV.CreatedBy=T3.Username 
AND INV.StatusID=T4.StatusID 
AND T4.StatusID IN (371) 
AND INV.INVDOCDETAILSID=T5.InvDocDetailsID
AND INV.INVDOCDETAILSID=T6.InvDocDetailsID
AND T7.NodeID= T6.dcCCNID51
AND T8.NodeID=T6.dcCCNID52	
AND WF.WID=INV.WorkflowID 
and WF.LevelID>INV.WorkFlowLevel 
and (INV.StatusID=371 or INV.StatusID=372 or INV.StatusID=441) 
AND (WF.Type=1 or (INV.WorkFlowLevel+1=WF.LevelID and INV.StatusID!=372))
AND INV.CostCenterID=40062
DROP TABLE #TblUsrWF

	

END
GO