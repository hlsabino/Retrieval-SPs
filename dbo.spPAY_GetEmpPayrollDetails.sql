USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmpPayrollDetails]
	@EmpID [int],
	@PayrollMonth [datetime],
	@PayrollStart [datetime],
	@PayrollEnd [datetime],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  

--Declaration Section  
DECLARE @HasAccess BIT,@CostCenterID INT,@SQL NVARCHAR(MAX),@Val nvarchar(50),@Val2 nvarchar(50)
SET @CostCenterID=40054
  
--User access check   
SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)  

IF @HasAccess=0  
BEGIN  
	RAISERROR('-105',16,1)  
END  
	
--0-- EMPLOYEE INFORMATION
SELECT a.*,CONVERT(DATETIME,a.DOJ) CDOJ,CONVERT(DATETIME,a.DOB) CDOB,CONVERT(DATETIME,a.DOConfirmation) CDOC
FROM COM_CC50051 a WITH(NOLOCK)
WHERE a.NodeID=@EmpID

--1-- PAYROLL STRUCTURE INFORMATION
DECLARE @Grade int,@IsGradeWiseMP BIT
SELECT @IsGradeWiseMP=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK)
WHERE Name='GradeWiseMonthlyPayroll'
IF @IsGradeWiseMP=1
BEGIN
	IF((SELECT COUNT(*) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID53' and IsColumnInUse=1 and UserProbableValues='H')>0)
		SELECT @Grade=ISNULL(HistoryNodeID,0) FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmpID AND CostCenterID=50051 AND HistoryCCID=50053 AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,@PayrollMonth)) AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,@PayrollMonth) OR ToDate IS NULL)
	ELSE
		SELECT @Grade=ISNULL(CCNID53,0) FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=50051 AND NODEID=@EmpID
END

IF ISNULL(@GRADE,0)=0
	SET @GRADE=1
	--SELECT TOP 1 @Grade=GradeID FROM COM_CC50054 WITH(NOLOCK) 
	--WHERE CONVERT(DATETIME,PAYROLLDATE)=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,CONVERT(NVARCHAR,@PayrollMonth)))
	--AND GradeID=(	SELECT TOP 1 HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
	--				WHERE NodeID=@EmpID AND CostCenterID=50051 AND HistoryCCID=50053   
	--				AND (CONVERT(DATETIME,FromDate)<=@PayrollMonth OR CONVERT(DATETIME,FromDate) BETWEEN @PayrollStart and @PayrollEnd) 
	--				AND (CONVERT(DATETIME,ToDate)>=@PayrollMonth OR ToDate IS NULL) 
	--				ORDER BY FromDate DESC ) 
	--ORDER BY PayrollDate DESC
	
		
--IF @Grade IS NULL
--Begin
--	SET @Grade=1
--End

SELECT b.Name as ComponentName,a.* 
FROM COM_CC50054 a WITH(NOLOCK) 
Left Join COM_CC50052 b on b.NodeID=a.ComponentID
WHERE GradeID=@Grade AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,CONVERT(NVARCHAR,@PayrollMonth)) AND GRADEID=@Grade)
ORDER BY Type,SNo

--2-- LAST APPRAISAL INFORMATION
SELECT TOP 1 *,CONVERT(DATETIME,EffectFrom) AS CEffectFrom,CONVERT(DATETIME,ApplyFrom) AS CApplyFrom
FROM PAY_EmpPay WITH(NOLOCK) 
WHERE EmployeeID=@EmpID AND CONVERT(DATETIME,EffectFrom)<=@PayrollEnd
ORDER BY EffectFrom DESC,SeqNo DESC

--3-- PROFESSIONAL TAX (PT) SLABS INFORMATION

SELECT @Val= Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='PayrollPTDimension'
IF(@Val IS NOT NULL AND @Val<>'' and @Val>50000)
BEGIN
	Select @Val2='CCNID'+CONVERT(NVARCHAR,(CONVERT(INT,@Val)-50000))
	SET @SQL='
	SELECT CONVERT(DATETIME,PayrollDate) AS CPayrollDate,* FROM PAY_PayrollPT WITH(NOLOCK)
	WHERE CONVERT(DATETIME,PayrollDate)='''+CONVERT(NVARCHAR,@PayrollMonth)+''' AND CostCenterID='+@Val+' 
	AND NodeID=(Select '+@Val2+' From COM_CCCCData WITH(NOLOCK) 
				WHERE CostcenterID=50051 AND NodeID='+CONVERT(NVARCHAR,@EmpID)+' ) '
	PRINT @SQL
	EXEC sp_executesql @SQL
	
END
ELSE
BEGIN
	SELECT CONVERT(DATETIME,PayrollDate) AS CPayrollDate,* FROM PAY_PayrollPT WITH(NOLOCK) WHERE 1<>1
END

--4-- WEEKLY OFFS DEFINITION INFORMATION 
SELECT TOP 1 c.dcCCNID51 AS EmpID,b.dcAlpha2 as Week1_W1,b.dcAlpha3 as Week1_W2,
b.dcAlpha4 as Week2_W1,b.dcAlpha5 as Week2_W2,b.dcAlpha6 as Week3_W1,b.dcAlpha7 as Week3_W2,
b.dcAlpha8 as Week4_W1,b.dcAlpha9 as Week4_W2,b.dcAlpha10 as Week5_W1,b.dcAlpha11 as Week5_W2
FROM INV_DOCDETAILS a WITH(NOLOCK)
Left Join COM_DocTextData b WITH(NOLOCK) on b.InvDocdetailsID=a.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=a.InvDocDetailsId
Where a.CostCenterID=40053 AND dcAlpha1='No' AND c.dcCCNID51=@EmpID
ORDER BY a.DueDate DESC

--5-- LIST OF HOLIDAYS INFORMATION
DECLARE @colName nvarchar(500),@colId int ,@Qry nvarchar(max)
SET @Qry=''
DECLARE Cur1 CURSOR FOR 
SELECT SysColumnName,ParentCostCenterID FROM ADM_COSTCENTERDEF 
WHERE COSTCENTERID=40051
AND ParentCostCenterID>50000 AND IsColumnInUse=1
OPEN Cur1
FETCH NEXT FROM Cur1 INTO @colName,@colId
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @Qry =@Qry + ' AND c.'+@colName+' IN (1,(SELECT TOP 1 HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
						WHERE NodeID='+CONVERT(NVARCHAR,@EmpID)+' AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@colId)+'   
						AND (CONVERT(DATETIME,FromDate)<='''+convert(nvarchar,@PayrollMonth)+''' OR CONVERT(DATETIME,FromDate) BETWEEN '''+convert(nvarchar,@PayrollStart)+''' and '''+convert(nvarchar,@PayrollEnd)+''') 
						AND (CONVERT(DATETIME,ToDate)>='''+convert(nvarchar,@PayrollMonth)+''' OR ToDate IS NULL) 
						ORDER BY FromDate DESC))'
	
FETCH NEXT FROM Cur1 INTO @colName,@colId
END
CLOSE Cur1
DEALLOCATE Cur1
----PRINT @Qry

SET @SQL='
SELECT DISTINCT CONVERT(DATETIME,b.dcAlpha1) as HolidayDate 
FROM INV_DOCDETAILS a WITH(NOLOCK)
Left Join COM_DocTextData b WITH(NOLOCK) on b.InvDocdetailsID=a.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=a.InvDocDetailsId
Where a.CostCenterID=40051  and isdate(b.dcAlpha1)=1
AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN '''+convert(nvarchar,@PayrollStart)+''' AND '''+convert(nvarchar,@PayrollEnd)+'''  '

IF(@Qry IS NOT NULL AND LEN(@Qry)>0)
BEGIN
	SET @SQL=@SQL+ @Qry
END
PRINT @SQL
EXEC sp_executesql @SQL

--6-- ALREADY PAYROLL PROCESSED DATA
SELECT e.Status as DocStatus,* FROM INV_DocDetails a WITH(NOLOCK) 
JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
JOIN PAY_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_Status e WITH(NOLOCK) ON e.StatusID=a.StatusID and e.CostCenterID=400
WHERE a.CostCenterID=@CostCenterID
AND b.dcCCNID51=@EmpID AND CONVERT(DATETIME,a.DOCDATE)=@PayrollMonth

--7-- GETTING WORKFLOWS  
SELECT distinct [WorkFlowDefID],[CostCenterID],[Action],[Expression],a.WorkFlowID,a.LevelID,IsLineWise,IsExpressionLineWise  
FROM [COM_WorkFlowDef]  a   WITH(NOLOCK)
join COM_WorkFlow b WITH(NOLOCK) on a.WorkFlowID=b.WorkFlowID  and a.LevelID=b.LevelID
LEFT JOIN COM_Groups G WITH(NOLOCK) on b.GroupID=G.GID
where [CostCenterID]=@CostCenterID and IsEnabled=1  
and (b.UserID =@UserID or b.RoleID=@RoleID or G.UserID=@UserID or G.RoleID=@RoleID )
  
--8-- ASSIGNED LEAVES DATA
Declare @Month datetime
SELECT Top 1 @Month=CONVERT(DATETIME,DocDate)FROM INV_DocDetails A WITH(NOLOCK) 
JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
WHERE A.CostCenterID=40060 AND B.dcCCNID51=@EmpID AND CONVERT(DATETIME,DocDate)<=@PayrollMonth  Order by CONVERT(DATETIME,DocDate) DESC 

SELECT D.Name as LeaveType,C.dcNum2+C.dcNum3 as Total,C.dcNum4 as Deducted,C.dcNum5 as Balance
FROM INV_DocDetails A WITH(NOLOCK)
JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_DocNumData C WITH(NOLOCK) ON C.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_CC50052 D WITH(NOLOCK) ON D.NodeID=B.dcCCNID52
WHERE A.CostCenterID=40060 AND B.dcCCNID51=@EmpID AND CONVERT(DATETIME,DocDate)=@Month

--9-- APPROVED LEAVES DATA
SELECT B.dcCCNID51 as EmpSeqNo,D.Name as LeaveType,
c.dcAlpha4 as FromDate,c.dcAlpha5 as ToDate,c.dcAlpha7 as NoOfDays,A.StatusID
FROM INV_DocDetails A WITH(NOLOCK)
JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_DocTextData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_CC50052 D WITH(NOLOCK) ON D.NodeID=B.dcCCNID52
WHERE A.DocumentType=62 AND B.dcCCNID51=@EmpID AND A.StatusID=369 

--10-- APPROVED LOANS DATA
SELECT a.InvDocDetailsID,a.DocID as NodeNo,a.VoucherNo as DocNo,b.dcCCNID52 as LoanCompID,e.Name as LoanType,d.dcAlpha2 as ApprovedAmt,c.dcNum1 as InstallmentNo,ISNULL(c.dcNum2,0) as InstallmentAmt,d.dcAlpha4 as NoOfInstallments,CONVERT(DATETIME,d.dcAlpha6) as DeductionMonth,
ISNULL(f.dcNum1,0) AS InstNo,ISNULL(f.dcNum3,0) as Paid,ISNULL(c.dcNum2,0)-ISNULL(f.dcNum3,0) as InstBalance,PayrollMonth
FROM INV_DocDetails a WITH(NOLOCK)
LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_CC50052 e WITH(NOLOCK) ON e.NodeID=b.dcCCNID52
LEFT JOIN ( SELECT b.dcCCNID51 as EmpSeqNo,b.dcCCNID52 as LoanType,CONVERT(DATETIME,d.dcAlpha4) as PayrollMonth,a.RefNo,c.dcNum1,c.dcNum3
			FROM INV_DocDetails a WITH(NOLOCK)
			LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN COM_CC50052 e WITH(NOLOCK) ON e.NodeID=b.dcCCNID52
			WHERE a.CostCenterID=40057 and b.dcCCNID51=@EmpID and isdate(d.dcAlpha4)=1 ) as f on f.RefNo=a.VoucherNo AND f.dcNum1=c.dcNum1

WHERE a.CostCenterID=40056 AND b.dcCCNID51=@EmpID
AND a.StatusID=369 and ISDATE(d.dcAlpha6)=1
Order By b.dcCCNID52

--11-- LOAN REPAYMENT DETAILS, ONLY PAID FROM MONTHLY PAYROLL
SELECT * FROM INV_DocDetails a WITH(NOLOCK)
LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_CC50052 e WITH(NOLOCK) ON e.NodeID=b.dcCCNID52
WHERE a.CostCenterID=40057 and b.dcCCNID51=@EmpID and ISDATE(d.dcAlpha4)=1 AND CONVERT(DATETIME,d.dcAlpha5) = @PayrollMonth AND d.dcAlpha6='1'

--12-- 


--------------------------------------------------------------------------------
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
