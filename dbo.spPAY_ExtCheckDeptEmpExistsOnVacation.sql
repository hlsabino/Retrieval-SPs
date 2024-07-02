USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtCheckDeptEmpExistsOnVacation]
	@CurEmpSeqNo [int],
	@VacFromDate [datetime]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @DeptSeqNo INT

--SET @CurEmpSeqNo=658
--SET @VacFromDate='15-Aug-2019'

Select @DeptSeqNo=CCNID4 FROM  COM_CCCCDATA Where CostCenterID=50051 AND NodeID=@CurEmpSeqNo 

IF EXISTS(
SELECT TOP 1 dcAlpha2 as FromDate,dcAlpha3 as ToDate,d.dcAlpha1 as RejoinDate,b.dcCCNID51 as EmpSeqNo
FROM INV_DocDetails a WITH(NOLOCK) 
JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
WHERE a.CostCenterID=40072 and a.StatusID=369
AND @VacFromDate BETWEEN CONVERT(DATETIME,d.dcAlpha2) AND CONVERT(DATETIME,d.dcAlpha3)
AND ISNULL(d.dcAlpha1,'')=''
AND b.dcCCNID51 IN ( Select NodeID From COM_CCCCDATA
WHERE CostCenterID=50051 AND CCNID4=@DeptSeqNo  )
)
	SELECT 1
ELSE
	SELECT 0
GO
