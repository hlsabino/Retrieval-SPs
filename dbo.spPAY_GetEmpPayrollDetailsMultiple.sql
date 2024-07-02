USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmpPayrollDetailsMultiple]
	@EmpIDs [nvarchar](max),
	@PayrollMonth [nvarchar](100),
	@PayrollStart [nvarchar](100),
	@PayrollEnd [nvarchar](100),
	@IsPayrollOther [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  

--Declaration Section  
DECLARE @HasAccess BIT,@CostCenterID INT,@SQL NVARCHAR(MAX),@Val nvarchar(50),@Val2 nvarchar(50),@ConsiderVacationDayswhilePayrollProcessing BIT
SET @CostCenterID=40054
  
--User access check   
/*
SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)  

IF @HasAccess=0  
BEGIN  
	RAISERROR('-105',16,1)  
END  
*/

DECLARE @DontConsiderDocs NVARCHAR(10),@DontConsiderDocsDays NVARCHAR(10),@DontConsiderEmpAttendanceData NVARCHAR(10),@DontConsiderEmpAttendanceDataDays NVARCHAR(10),@DontConsiderDocsBasedonPostedDate NVARCHAR(10),@DontConsiderDocsDaysBasedonPostedDate NVARCHAR(10),@XML xml,@DontConsiderEmpLeavesVacationDataDaysBasedonPostedDateXML nvarchar(max)
SELECT @DontConsiderDocs=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DontConsiderEmpLeavesLoansRecData'
SELECT @DontConsiderDocsDays=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DontConsiderEmpLeavesLoansRecDataDays'
SELECT @ConsiderVacationDayswhilePayrollProcessing=CONVERT(BIT,PrefValue) FROM com_documentpreferences WITH(NOLOCK) WHERE PrefName='ConsiderVacationDayswhilePayrollProcessing'
SELECT @DontConsiderEmpAttendanceData=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DontConsiderEmpAttendanceData'
SELECT @DontConsiderEmpAttendanceDataDays=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DontConsiderEmpAttendanceDataDays'
SELECT @DontConsiderDocsBasedonPostedDate=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DontConsiderEmpLeavesVacationDataBasedonPostedDate'
SELECT @DontConsiderEmpLeavesVacationDataDaysBasedonPostedDateXML=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DontConsiderEmpLeavesVacationDataDaysBasedonPostedDate'

SET @SQL=''

--0-- EMPLOYEE INFORMATION

SET @SQL='SELECT a.NodeID as EmpSeqNo,a.*,CONVERT(DATETIME,a.DOJ) CDOJ,CONVERT(DATETIME,a.DOB) CDOB,CONVERT(DATETIME,a.DOConfirmation) CDOC,CONVERT(DATETIME,a.DORelieve) CDORelieve,
ISNULL(ET.Name,'''') as sEmpType,ISNULL(N.Name,'''') as sNationality,ISNULL(R.Name,'''') as sReligion,
ISNULL(G.Name,'''') as sGender,ISNULL(MS.Name,'''') as sMaritalStatus

FROM COM_CC50051 a WITH(NOLOCK)
LEFT JOIN COM_Lookup ET WITH(NOLOCK) on ET.NodeID=a.EmpType
LEFT JOIN COM_Lookup N WITH(NOLOCK) on N.NodeID=a.Nationality
LEFT JOIN COM_Lookup R WITH(NOLOCK) on R.NodeID=a.Religion
LEFT JOIN COM_Lookup G WITH(NOLOCK) on G.NodeID=a.Gender
LEFT JOIN COM_Lookup MS WITH(NOLOCK) on MS.NodeID=a.MaritalStatus
WHERE a.NodeID IN('+@EmpIDs+')'
--print @SQL
EXEC sp_executesql @SQL

--1-- PAYROLL STRUCTURE INFORMATION

DECLARE @IsGradeWiseMP BIT
SELECT @IsGradeWiseMP=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='GradeWiseMonthlyPayroll'
IF @IsGradeWiseMP=1
BEGIN
	--SET @SQL='	
	--SELECT b.Name as ComponentName,CONVERT(DATETIME,a.PayrollDate) as CPayrollDate,a.* FROM COM_CC50054 a WITH(NOLOCK) 
	--Left Join COM_CC50052 b on b.NodeID=a.ComponentID
	--WHERE PayrollDate=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''')) 
	--AND GradeID IN( SELECT GradeID FROM COM_CC50054 WITH(NOLOCK) WHERE PayrollDate=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+'''))
	--				AND GradeID IN(	SELECT  DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
	--								WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID=50053   
	--								AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
	--								AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL)
	--							  ) 
	--			  ) ORDER BY GradeID,Type,SNo '
		SET @SQL='	
	SELECT b.Name as ComponentName,CONVERT(DATETIME,a.PayrollDate) as CPayrollDate,a.* FROM COM_CC50054 a WITH(NOLOCK) 
	Left Join COM_CC50052 b WITH(NOLOCK) on b.NodeID=a.ComponentID
	WHERE GradeID IN(SELECT  DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
									WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID=50053   
									AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
									AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL))
	and PayrollDate=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') 
					AND GradeID IN(	SELECT  DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
									WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID=50053   
									AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
									AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL))
								  ) 
				   ORDER BY GradeID,Type,SNo  '
				  
				  --print @SQL
	EXEC sp_executesql @SQL
END
ELSE 
BEGIN
	SET @SQL='SELECT b.Name as ComponentName,CONVERT(DATETIME,a.PayrollDate) as CPayrollDate,a.* FROM COM_CC50054 a WITH(NOLOCK) 
	Left Join COM_CC50052 b WITH(NOLOCK) on b.NodeID=a.ComponentID
	WHERE GradeID=1 AND PayrollDate=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') 
					AND GradeID =1)	ORDER BY Type,SNo'
	--SET @SQL='SELECT b.Name as ComponentName,a.* FROM COM_CC50054 a WITH(NOLOCK) 
	--Left Join COM_CC50052 b on b.NodeID=a.ComponentID
	--WHERE GradeID=1 AND CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''')
	--ORDER BY Type,SNo'
	--print (@SQL)
	EXEC sp_executesql @SQL
END


--2-- LAST APPRAISAL INFORMATION
SET @SQL='
SELECT EmployeeID,MAX(EffectFrom) as EffectFrom INTO #t1LAP FROM PAY_EmpPay WITH(NOLOCK) 
WHERE EmployeeID IN('+@EmpIDs+') AND CONVERT(DATETIME,EffectFrom)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
GROUP BY EmployeeID

SELECT b.EmployeeID as EmpSeqNo,a.*,CONVERT(DATETIME,a.EffectFrom) AS CEffectFrom,CONVERT(DATETIME,a.ApplyFrom) AS CApplyFrom
FROM PAY_EmpPay a WITH(NOLOCK) 
JOIN #t1LAP b WITH(NOLOCK) ON b.EmployeeID=a.EmployeeID and b.EffectFrom=a.EffectFrom
WHERE a.EmployeeID IN('+@EmpIDs+') 

DROP TABLE #t1LAP '
--print (@SQL)
EXEC sp_executesql @SQL

--3-- PROFESSIONAL TAX (PT) SLABS INFORMATION

SELECT @Val= Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='PayrollPTDimension'

IF(@Val IS NOT NULL AND @Val<>'' and @Val>50000)
BEGIN

	Select @Val2='CCNID'+CONVERT(NVARCHAR,(CONVERT(INT,@Val)-50000))
	SET @SQL='
	
	DECLARE @CCType NVARCHAR(50)
	SELECT @CCType= ISNULL(UserProbableValues,'''') FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID='+@Val+' AND IsColumnInUse=1  
	IF(ISNULL(@CCType,'''')=''H'')
	BEGIN
		SELECT CONVERT(DATETIME,PayrollDate) AS CPayrollDate,* FROM PAY_PayrollPT WITH(NOLOCK)
		WHERE CONVERT(DATETIME,PayrollDate)=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') AND GradeID =1)
		AND CostCenterID='+@Val+' 
		AND NodeID IN( SELECT  HistoryNodeID as PTDimension FROM COM_HistoryDetails WITH(NOLOCK) 
						WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID='+@Val+'   
						AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
						AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL)
					  ) 
	END
	ELSE
	BEGIN
		SELECT CONVERT(DATETIME,PayrollDate) AS CPayrollDate,* FROM PAY_PayrollPT WITH(NOLOCK)
		WHERE CONVERT(DATETIME,PayrollDate)=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') AND GradeID =1)
		AND CostCenterID='+@Val+' 
		AND NodeID IN( SELECT '+@Val2+' as PTDimension FROM COM_CCCCDATA WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+@EmpIDs+')  )
	END
	'
	--PRINT @SQL
	EXEC sp_executesql @SQL
END
ELSE
BEGIN
	SELECT CONVERT(DATETIME,PayrollDate) AS CPayrollDate,* FROM PAY_PayrollPT WITH(NOLOCK) WHERE 1<>1
END

--4-- WEEKLY OFFS DEFINITION INFORMATION 

DECLARE @WeeklyOffsDefBasedOn NVARCHAR(MAX),@WhereCond NVARCHAR(MAX),@HCCID INT,@CCType NVARCHAR(50),@Col NVARCHAR(50)
SELECT @WeeklyOffsDefBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='WeeklyOffsDefBasedOn'
SET @SQL='' SET @WhereCond='' SET @HCCID='' SET @CCType='' SET @Col=''

IF(@WeeklyOffsDefBasedOn<>'')
BEGIN
	DECLARE @BasedOn TABLE (HCCID INT)  
	INSERT INTO @BasedOn  
	EXEC SPSplitString @WeeklyOffsDefBasedOn,','  
	
	DECLARE CUR CURSOR FOR SELECT HCCID FROM @BasedOn
	OPEN CUR
	FETCH NEXT FROM CUR INTO @HCCID
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF EXISTS(SELECT CostCenterColID FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1)
		BEGIN
			SELECT @CCType= ISNULL(UserProbableValues,'') FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1  

			IF(LEN(@Col)>0)
				SET @Col=@Col + ' ,'

			SET @Col=@Col + 'c.dcCCNID'+ CONVERT(NVARCHAR,(@HCCID-50000)) +' AS CCNID'+ CONVERT(NVARCHAR,(@HCCID-50000)) 

			IF(@CCType='')
			BEGIN
			print @WhereCond
				SET @WhereCond=@WhereCond+' 
											AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( Select CCNID'+CONVERT(NVARCHAR,(@HCCID-50000))+' FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN(1,'+@EmpIDs+') )) '
			END
			ELSE
			BEGIN
				SET @WhereCond=@WhereCond+' AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
											WHERE NodeID IN(1,'+@EmpIDs+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@HCCID)+'   
											AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR 
												CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
											AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL) )) '
									
			END
		END
	FETCH NEXT FROM CUR INTO @HCCID
	END
	CLOSE CUR
	DEALLOCATE CUR	

END

	IF(LEN(@Col)>0)
		SET @Col=@Col + ' ,'

SET @SQL='

SELECT '+ @Col +' b.dcAlpha2 as Week1_W1,b.dcAlpha3 as Week1_W2,
b.dcAlpha4 as Week2_W1,b.dcAlpha5 as Week2_W2,b.dcAlpha6 as Week3_W1,b.dcAlpha7 as Week3_W2,
b.dcAlpha8 as Week4_W1,b.dcAlpha9 as Week4_W2,b.dcAlpha10 as Week5_W1,b.dcAlpha11 as Week5_W2
FROM INV_DOCDETAILS a WITH(NOLOCK)
Left Join COM_DocTextData b WITH(NOLOCK) on b.InvDocdetailsID=a.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=a.InvDocDetailsId
Where a.StatusID=369 AND a.CostCenterID=40053 AND dcAlpha1=''No'' AND CONVERT(DATETIME,a.DueDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''')
 '

IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
BEGIN
	SET @SQL=@SQL+ @WhereCond
END

SET @SQL=@SQL+  'ORDER BY     CONVERT(DATETIME,a.DUEDATE) DESC'

PRINT @SQL
EXEC sp_executesql @SQL

--5-- LIST OF HOLIDAYS INFORMATION
----------
DECLARE @HolidayBasedOn NVARCHAR(MAX)
SELECT @HolidayBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='HolidaysBasedOn'
SET @SQL='' SET @WhereCond='' SET @HCCID='' SET @CCType='' SET @Col=''
IF(@HolidayBasedOn<>'')
BEGIN
	DECLARE @HBOn TABLE (HCCID INT)  
	INSERT INTO @HBOn  
	EXEC SPSplitString @HolidayBasedOn,','  
	
	DECLARE CUR CURSOR FOR SELECT HCCID FROM @HBOn
	OPEN CUR
	FETCH NEXT FROM CUR INTO @HCCID
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF EXISTS(SELECT CostCenterColID FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1)
		BEGIN
			SELECT @CCType= ISNULL(UserProbableValues,'') FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1  

			IF(LEN(@Col)>0)
				SET @Col=@Col + ' ,'

			SET @Col=@Col + 'c.dcCCNID'+ CONVERT(NVARCHAR,(@HCCID-50000)) +' AS CCNID'+ CONVERT(NVARCHAR,(@HCCID-50000)) 

			IF(@CCType='')
			BEGIN
				SET @WhereCond=@WhereCond+' 
											AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( Select CCNID'+CONVERT(NVARCHAR,(@HCCID-50000))+' FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+@EmpIDs+') )) '
			END
			ELSE
			BEGIN
				SET @WhereCond=@WhereCond+' 
											AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
											WHERE NodeID IN('+@EmpIDs+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@HCCID)+'   
											AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR 
												CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
											AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL) )) '
			END
		END
	FETCH NEXT FROM CUR INTO @HCCID
	END
	CLOSE CUR
	DEALLOCATE CUR
	
END

	IF(LEN(@Col)>0)
		SET @Col=@Col + ' ,'

SET @SQL='
SELECT '+ @Col +' CONVERT(DATETIME,b.dcAlpha1) as HolidayDate 
FROM INV_DOCDETAILS a WITH(NOLOCK)
Left Join COM_DocTextData b WITH(NOLOCK) on b.InvDocdetailsID=a.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=a.InvDocDetailsId
Where b.tCostCenterID=40051  and a.StatusID=369 AND  isdate(ISNULL(b.dcAlpha1,''''))=1
AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')  '
IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
BEGIN
	SET @SQL=@SQL+ @WhereCond
END
PRINT @SQL
EXEC sp_executesql @SQL
----------
/*
DECLARE @colName nvarchar(500),@colId int ,@Qry nvarchar(max)
SET @Qry=''
DECLARE Cur1 CURSOR FOR 
SELECT SysColumnName,ParentCostCenterID FROM ADM_COSTCENTERDEF 
WHERE COSTCENTERID=40051 AND ParentCostCenterID>50000 AND IsColumnInUse=1
OPEN Cur1
FETCH NEXT FROM Cur1 INTO @colName,@colId
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @Qry =@Qry + ' AND c.'+@colName+' IN (SELECT 1 as HistoryNodeID UNION ALL SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
						WHERE NodeID IN('+@EmpIDs+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@colId)+'   
						AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
						AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL) 
						)'
	
FETCH NEXT FROM Cur1 INTO @colName,@colId
END
CLOSE Cur1
DEALLOCATE Cur1
PRINT @Qry

SET @SQL='
SELECT DISTINCT CONVERT(DATETIME,b.dcAlpha1) as HolidayDate 
FROM INV_DOCDETAILS a WITH(NOLOCK)
Left Join COM_DocTextData b WITH(NOLOCK) on b.InvDocdetailsID=a.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=a.InvDocDetailsId
Where a.StatusID=369 AND a.CostCenterID=40051  and isdate(b.dcAlpha1)=1
AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')  '

IF(@Qry IS NOT NULL AND LEN(@Qry)>0)
BEGIN
	SET @SQL=@SQL+ @Qry
END
print 'hd'
PRINT @SQL
EXEC sp_executesql @strEQry
*/

--6-- ALREADY PAYROLL PROCESSED DATA
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT b.dcCCNID51 as EmpSeqNo,e.Status as DocStatus,* FROM INV_DocDetails a WITH(NOLOCK) 
	JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
	JOIN PAY_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
	JOIN COM_Status e WITH(NOLOCK) ON e.StatusID=a.StatusID and e.CostCenterID=400
	WHERE a.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' 
	AND b.dcCCNID51 IN('+@EmpIDs+') AND CONVERT(DATETIME,a.DueDate)=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') '

	EXEC sp_executesql @SQL
END

--7-- GETTING WORKFLOWS  
SELECT distinct [WorkFlowDefID],[CostCenterID],[Action],[Expression],a.WorkFlowID,a.LevelID,IsLineWise,IsExpressionLineWise  
FROM [COM_WorkFlowDef]  a   WITH(NOLOCK)
join COM_WorkFlow b WITH(NOLOCK) on a.WorkFlowID=b.WorkFlowID  and a.LevelID=b.LevelID
LEFT JOIN COM_Groups G WITH(NOLOCK) on b.GroupID=G.GID
where [CostCenterID]=@CostCenterID and IsEnabled=1  
and (b.UserID =@UserID or b.RoleID=@RoleID or G.UserID=@UserID or G.RoleID=@RoleID or b.RoleID=-1 )
  
--8-- ASSIGNED LEAVES DATA
DECLARE @ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME
EXEC [spPAY_EXTGetLeaveyearDates] @PayrollMonth,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
CREATE TABLE #TABTOPUP (EMPSEQNO INT,LeaveType VARCHAR(100),Total FLOAT,ActualDays FLOAT,NoOfMonths INT,FromDate DATETIME,ToDate DATETIME,RefNodeID INT,CommonNarration NVARCHAR(MAX))
CREATE TABLE #TABAL (EMPSEQNO INT,LeaveType VARCHAR(100),Total FLOAT,Deducted FLOAT,Balance FLOAT)
---CURRENT YEAR ASSGINED LEAVES
SET @SQL='INSERT INTO #TABAL
SELECT B.dcCCNID51 as EmpSeqNo,D.Name as LeaveType,sum(C.dcNum3) as Total,0 as Deducted,0 as Balance
FROM INV_DocDetails A WITH(NOLOCK)
JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_DocNumData C WITH(NOLOCK) ON C.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_DoctextData TD WITH(NOLOCK) ON TD.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_CC50052 D WITH(NOLOCK) ON D.NodeID=B.dcCCNID52
WHERE a.StatusID=369 AND TD.tCostCenterID =40081 AND b.dcCCNID51 IN('+@EmpIDs+') AND ISDATE(ISNULL(TD.dcAlpha3,''''))=1 
AND CONVERT(DATETIME,TD.dcAlpha3) between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ALStartMonthYear)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ALEndMonthYear)+''') 
group by B.dcCCNID51,D.Name'
--PRINT (@SQL)
EXEC sp_executesql @SQL
--TOPUP LEAVES
SET @SQL=''
SET @SQL='INSERT INTO #TABTOPUP
SELECT B.dcCCNID51 as EmpSeqNo,D.Name as LeaveType,isnull(C.dcNum3,0),isnull(C.dcNum3,0),(DATEDIFF(M,CONVERT(DATETIME,TD.DCALPHA3),CONVERT(DATETIME,TD.DCALPHA4))+1)
,CONVERT(DATETIME,TD.dcAlpha3),CONVERT(DATETIME,TD.dcAlpha4),ISNULL(A.REFNODEID,0),a.CommonNarration as CommonNarration
FROM INV_DocDetails A WITH(NOLOCK)
JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_DocNumData C WITH(NOLOCK) ON C.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_DoctextData TD WITH(NOLOCK) ON TD.InvDocDetailsID=A.InvDocDetailsID
JOIN COM_CC50052 D WITH(NOLOCK) ON D.NodeID=B.dcCCNID52
WHERE TD.tCostCenterID =40060 AND a.StatusID=369 AND b.dcCCNID51 IN('+@EmpIDs+') AND ISDATE(ISNULL(TD.dcAlpha3,''''))=1 AND ISDATE(ISNULL(TD.dcAlpha4,''''))=1 
AND CONVERT(DATETIME,TD.dcAlpha3) between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ALStartMonthYear)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ALEndMonthYear)+''') '
--PRINT (@SQL)
EXEC sp_executesql @SQL
UPDATE #TABTOPUP SET TOTAL=isnull(ActualDays,0)/isnull(NoOfMonths,0) WHERE isnull(ActualDays,0)>0 AND ISNULL(RefNodeID,0)=0 AND CommonNarration NOT IN('#Opening#','#CarryForward#')

INSERT INTO #TABAL
	SELECT EMPSEQNO,LeaveType,Total,0,0 FROM #TABTOPUP WITH(NOLOCK) WHERE CONVERT(DATETIME,CONVERT(NVARCHAR,@PayrollMonth)) BETWEEN CONVERT(DATETIME,FromDate) AND CONVERT(DATETIME,ToDate)
---PREVIOUS YEAR ASSGINED LEAVES
INSERT INTO #TABAL
EXEC spPAY_GetLeavesOpeningBalance @EmpIDs,@PayrollMonth,@UserID,@LangID

SELECT EmpSeqNo,LeaveType,sum(Total) Total,sum(Deducted) Deducted,Sum(Balance) Balance FROM #TABAL
Group by EmpSeqNo,LeaveType
DROP TABLE #TABAL
DROP TABLE #TABTOPUP

--9-- APPROVED LEAVES DATA
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT B.dcCCNID51 as EmpSeqNo,D.NodeID as ComponentID,D.Name as LeaveType,
	CONVERT(DATETIME,c.dcAlpha4) as FromDate,CONVERT(DATETIME,c.dcAlpha5) as ToDate,c.dcAlpha7 as NoOfDays,A.StatusID,Convert(DATETIME,DocDate) as DocDate,CONVERT(DATETIME,c.dcAlpha15) as RejoinDate,ISNULL(c.dcAlpha16,'''') as PostedFrom
	FROM INV_DocDetails A WITH(NOLOCK)
	JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=A.InvDocDetailsID
	JOIN COM_DocTextData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
	JOIN COM_CC50052 D WITH(NOLOCK) ON D.NodeID=B.dcCCNID52'

	IF(@DontConsiderDocsBasedonPostedDate='True')
	BEGIN
		declare @tblp table(id int identity(1,1),PayrollMonth datetime,CutOffDays nvarchar(50))
		if(@DontConsiderEmpLeavesVacationDataDaysBasedonPostedDateXML <>'')      
		BEGIN      
			SET @XML=@DontConsiderEmpLeavesVacationDataDaysBasedonPostedDateXML
			INSERT INTO @tblp      
			SELECT X.value('@PayrollMonth','datetime') 
			,X.value('@CutOffDays','nvarchar(50)')       
			from @XML.nodes('XML/Row') as Data(X)      
		end

		SELECT top 1 @DontConsiderDocsDaysBasedonPostedDate=CutOffDays FROM @tblp WHERE PayrollMonth<=@PayrollMonth order by PayrollMonth desc
		
		IF(CONVERT(INT,isnull(@DontConsiderDocsDaysBasedonPostedDate,0))>0)
		BEGIN
		SET @SQL=@SQL + ' join com_approvals App WITH(NOLOCK) ON App.CCNODEID=a.DocID and app.ApprovalID in (select top 1 ApprovalID from com_approvals A1 WITH(NOLOCK) where  a1.CCNODEID=a.DocID AND a1.CCID=a.CostCenterID AND a1.StatusID=369 AND CONVERT(DATETIME,a1.CreatedDate)< CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderDocsDaysBasedonPostedDate) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') order by CONVERT(DATETIME,a1.CreatedDate) desc) '
		END
	END

	SET @SQL=@SQL + ' WHERE C.tDocumentType=62 AND a.StatusID=369 AND  ISDATE(ISNULL(c.dcAlpha4,''''))=1 AND ISDATE(ISNULL(c.dcAlpha5,''''))=1  AND B.dcCCNID51 IN('+@EmpIDs+') '

	IF(@ConsiderVacationDayswhilePayrollProcessing=1 )
	BEGIN
		SET @SQL=@SQL + ' AND A.InvDocDetailsID NOT IN (Select aa.InvDocDetailsID
		FROM INV_DocDetails a WITH(NOLOCK) 
		JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
		JOIN INV_DocDetails aa WITH(NOLOCK) on aa.VoucherNo=d.dcAlpha1 AND aa.DocSeqNo=d.dcAlpha5
		WHERE d.tDocumentType=73 and a.StatusID IN(369,371,441) AND ISNULL(D.DCALPHA4,'''')=''Yes'') '
	END

	IF(@DontConsiderDocs='True' AND CONVERT(INT,@DontConsiderDocsDays)>0 )
	BEGIN
		SET @SQL=@SQL + ' AND CONVERT(DATETIME,A.DocDate)< CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderDocsDays) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') '
	END
	print @SQL
	EXEC sp_executesql @SQL
END

--print 'Loan'
--10-- APPROVED LOANS DATA
SET @SQL='

SELECT a.InvDocDetailsID INTO #ttmp1 FROM INV_DocDetails a WITH(NOLOCK)
LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_CC50052 e WITH(NOLOCK) ON e.NodeID=b.dcCCNID52
WHERE d.tCostCenterID=40057 and a.StatusID=369 AND  b.dcCCNID51 IN('+@EmpIDs+') and ISDATE(ISNULL(d.dcAlpha4,''''))=1 and ISDATE(ISNULL(d.dcAlpha5,''''))=1 AND CONVERT(DATETIME,d.dcAlpha5) = CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') AND d.dcAlpha6=''1'' '

SET @SQL=@SQL + 'SELECT b.dcCCNID51 as EmpSeqNo,b.dcCCNID52 as LoanType,CONVERT(DATETIME,d.dcAlpha4) PayrollMonth,a.RefNo,c.dcNum1,SUM(c.dcNum3) as dcNum3 into #tLp1
			FROM INV_DocDetails a WITH(NOLOCK)
			LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
			WHERE d.tCostCenterID=40057 and a.StatusID=369 AND  b.dcCCNID51 IN('+@EmpIDs+') AND A.InvDocDetailsID NOT IN(Select InvDocDetailsID FROM #ttmp1 WITH(NOLOCK))
			GROUP BY b.dcCCNID51,b.dcCCNID52,CONVERT(DATETIME,d.dcAlpha4),a.RefNo,c.dcNum1 '

SET @SQL=@SQL + '
SELECT b.dcCCNID51 as EmpSeqNo,a.InvDocDetailsID,a.DocID as NodeNo,a.VoucherNo as DocNo,b.dcCCNID52 as LoanCompID,e.Name as LoanType,d.dcAlpha2 as ApprovedAmt,c.dcNum1 as InstallmentNo,ISNULL(c.dcNum2,0) as InstallmentAmt,d.dcAlpha4 as NoOfInstallments,CONVERT(DATETIME,d.dcAlpha6) as DeductionMonth,
ISNULL(f.dcNum1,0) AS InstNo,ISNULL(f.dcNum3,0) as Paid,ISNULL(c.dcNum2,0)-ISNULL(f.dcNum3,0) as InstBalance,PayrollMonth,0 Flag
FROM INV_DocDetails a WITH(NOLOCK)
LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
LEFT JOIN COM_CC50052 e WITH(NOLOCK) ON e.NodeID=b.dcCCNID52
LEFT JOIN #tLp1 f WITH(NOLOCK) on f.EmpSeqNo=b.dcCCNID51 AND f.RefNo=a.VoucherNo AND f.dcNum1=c.dcNum1
WHERE d.tCostCenterID=40056 AND b.dcCCNID51 IN('+@EmpIDs+')
AND a.StatusID=369 and ISDATE(ISNULL(d.dcAlpha6,''''))=1 '

IF(@DontConsiderDocs='True' AND CONVERT(INT,@DontConsiderDocsDays)>0 )
BEGIN
	SET @SQL=@SQL + ' AND CONVERT(DATETIME,A.DocDate)< CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderDocsDays) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') '
END

SET @SQL=@SQL + ' Order By b.dcCCNID52 DROP TABLE #ttmp1 '
--print @SQL
EXEC sp_executesql @SQL

--11-- LOAN REPAYMENT DETAILS, ONLY PAID FROM MONTHLY PAYROLL
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT b.dcCCNID51 as EmpSeqNo,* FROM INV_DocDetails a WITH(NOLOCK)
	LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
	LEFT JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
	LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
	LEFT JOIN COM_CC50052 e WITH(NOLOCK) ON e.NodeID=b.dcCCNID52
	WHERE d.tCostCenterID=40057 and a.StatusID=369 AND  b.dcCCNID51 IN('+@EmpIDs+') and ISDATE(ISNULL(d.dcAlpha4,''''))=1 and ISDATE(ISNULL(d.dcAlpha5,''''))=1 AND CONVERT(DATETIME,d.dcAlpha5) = CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') AND d.dcAlpha6=''1'' '
	EXEC sp_executesql @SQL
END

--12-- GETTING ALL EMPLOYEES GRADES INFO

SET @SQL='	SELECT NodeID as EmpSeqNo,HistoryNodeID as GradeID FROM COM_HistoryDetails WITH(NOLOCK) 
			WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID=50053   
			AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
			AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL) '
EXEC sp_executesql @SQL

--13-- GETTING ALL EMPLOYEES PT DIMENSION

SELECT @Val= Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='PayrollPTDimension'
IF(@Val IS NOT NULL AND @Val<>'' and @Val>50000)
BEGIN
	Select @Val2='CCNID'+CONVERT(NVARCHAR,(CONVERT(INT,@Val)-50000))
	SET @SQL='
		
	DECLARE @CCType NVARCHAR(50)
	SELECT @CCType= ISNULL(UserProbableValues,'''') FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID='+@Val+' AND IsColumnInUse=1  
	IF(ISNULL(@CCType,'''')=''H'')
	BEGIN
		SELECT  NodeID as EmpSeqNo,HistoryNodeID as PTDimension FROM COM_HistoryDetails WITH(NOLOCK) 
		WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID='+@Val+'   
		AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
		AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL) 
	END
	ELSE
	BEGIN
		SELECT NodeID as EmpSeqNo,'+@Val2+' as PTDimension FROM COM_CCCCDATA WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+@EmpIDs+')
	END
				
	'
	EXEC sp_executesql @SQL
	
END
ELSE
BEGIN
	SELECT  NodeID as EmpSeqNo,HistoryNodeID as PTDimension FROM COM_HistoryDetails WITH(NOLOCK)  WHERE 1<>1
END

--14-- GETTING ALL EMPLOYEES DAILY ATTENDANCE

SET @SQL='	SELECT CONVERT(DATETIME,TD.dcAlpha1) as DailyAttendanceDate,DC.dcCCNID51 as EmpSeqNo,EMP.Code as EmpCode,EMP.Name as EmpName,CONVERT(DATETIME,TD.dcAlpha2) as StartTime,CONVERT(DATETIME,TD.dcAlpha3) as EndTime,
DN.dcNum1 as TotalHours,DN.dcNum2 as NormalWorkingHours,DN.dcNum3 as NormalRate,DN.dcNum4 as BreakHours,
DN.dcNum5 as OT1,DN.dcNum6 as OT1Rate,DN.dcNum7 as OT2,DN.dcNum8 as OT2Rate,DN.dcNum9 as OT3,DN.dcNum10 as OT3Rate,
DN.dcNum11 as OT4,DN.dcNum12 as OT4Rate,DN.dcNum13 as OT5,DN.dcNum14 OT5Rate,DN.DCNUM15 TotalCost,c73.ccAlpha22 ShiftType,dc.*,DN.*
FROM INV_DOCDETAILS ID WITH(NOLOCK) 
join COM_DOCTEXTDATA TD WITH(NOLOCK) on  ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
join COM_DOCNUMDATA DN WITH(NOLOCK) on ID.INVDOCDETAILSID=DN.INVDOCDETAILSID
join COM_DOCCCDATA DC WITH(NOLOCK) on  ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
join COM_CC50051 EMP WITH(NOLOCK) on  EMP.NODEID=DC.DCCCNID51
JOIN COM_CC50073 C73 WITH(NOLOCK) ON C73.NodeID=DC.dcCCNID73
WHERE TD.tDocumentType=67 AND ID.STATUSID=369 AND LEN(TD.DCALPHA1)=11 AND ISDATE(ISNULL(TD.DCALPHA1,''''))=1 AND ISDATE(ISNULL(TD.DCALPHA2,''''))=1 AND ISDATE(ISNULL(TD.DCALPHA3,''''))=1  
AND DC.DCCCNID51 IN('+@EmpIDs+')
AND CONVERT(DATETIME,TD.DCALPHA1) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')'

IF(@DontConsiderEmpAttendanceData='True' AND CONVERT(INT,@DontConsiderEmpAttendanceDataDays)>0 )
BEGIN
	SET @SQL=@SQL + ' AND CONVERT(DATETIME,TD.DCALPHA1)< CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderEmpAttendanceDataDays) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') '
END

SET @SQL=@SQL + 'ORDER BY DC.DCCCNID51,CONVERT(DATETIME,TD.DCALPHA1)
'

EXEC sp_executesql @SQL

--15-- GETTING ALL EMPLOYEES DAYS ATTENDED BASED ON DAILY ATTENDANCE
SELECT 'NODATA'

--SET @SQL='	
--DECLARE @RC INT,@TRC INT, @MINHRSHDAY DECIMAL(9,2),@MINHRSFDAY DECIMAL(9,2),@FROMDATE DATETIME,@EMPNODE INT,@NORMALWRKDHOURS DECIMAL(9,2)
--DECLARE @TABATTENDANCE TABLE(ID INT IDENTITY(1,1),DailyAttendanceDate DATETIME,EmpSeqNo INT,EmpCode NVARCHAR(500),EmpName NVARCHAR(500),NormalWorkingHours DECIMAL(9,2),DaysAttended DECIMAL(9,2))

--INSERT INTO @TABATTENDANCE
--SELECT CONVERT(DATETIME,TD.DCALPHA1) ,DC.DCCCNID51,EMP.CODE ,EMP.NAME ,SUM(DN.dcNum2) ,0
--FROM INV_DOCDETAILS ID WITH(NOLOCK),COM_DOCTEXTDATA TD WITH(NOLOCK),COM_DOCCCDATA DC WITH(NOLOCK),COM_DOCNUMDATA DN WITH(NOLOCK),COM_CC50051 EMP WITH(NOLOCK)
--WHERE TD.tDocumentType=67 AND ID.STATUSID=369
--AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DN.INVDOCDETAILSID AND TD.INVDOCDETAILSID=DC.INVDOCDETAILSID AND TD.INVDOCDETAILSID=DN.INVDOCDETAILSID 
--AND LEN(TD.DCALPHA1)=11 AND ISDATE(ISNULL(TD.DCALPHA1,''''))=1  
--AND EMP.NODEID=DC.DCCCNID51 
--AND DC.DCCCNID51 IN('+@EmpIDs+')
--AND CONVERT(DATETIME,TD.DCALPHA1) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
--GROUP BY CONVERT(DATETIME,TD.DCALPHA1) ,DC.DCCCNID51,EMP.CODE,EMP.NAME ORDER BY CONVERT(DATETIME,TD.DCALPHA1) DESC,DC.DCCCNID51  DESC

--SET @RC=1
--SELECT @TRC=COUNT(*) FROM @TABATTENDANCE

--WHILE (@RC<=@TRC)
--BEGIN	
--	SELECT @EMPNODE= EmpSeqNo,@FROMDATE=CONVERT(DATETIME,DailyAttendanceDate),@NORMALWRKDHOURS=ISNULL(NormalWorkingHours,0)  FROM @TABATTENDANCE WHERE ID=@RC
--	SELECT  @MINHRSHDAY=ISNULL(TD.dcAlpha3,0),@MINHRSFDAY=ISNULL(TD.dcAlpha4,0) FROM INV_DOCDETAILS ID WITH(NOLOCK),COM_DocCCData DC WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK) 
--	WHERE TD.tCOSTCENTERID=40066 AND ID.STATUSID=369
--	AND ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND DC.INVDOCDETAILSID=TD.INVDOCDETAILSID 
--			AND ISNULL(DC.DCCCNID51,1)=@EMPNODE  AND ISDATE(ISNULL(TD.dcAlpha6,''''))=1  
--   		    AND CONVERT(DATETIME,TD.DCALPHA6) <=CONVERT(DATETIME,@FROMDATE) ORDER BY CONVERT(DATETIME,TD.dcAlpha6) 
   		    
--   		    IF ISNULL(@MINHRSHDAY,0)<=0
--			BEGIN
--				SELECT  @MINHRSHDAY=ISNULL(TD.dcAlpha3,0),@MINHRSFDAY=ISNULL(TD.dcAlpha4,0) 
--				FROM INV_DOCDETAILS ID WITH(NOLOCK),COM_DocCCData DC WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK) 
--				WHERE TD.tCOSTCENTERID=40066 AND ID.STATUSID=369
--				AND ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND DC.INVDOCDETAILSID=TD.INVDOCDETAILSID 
--				AND ISNULL(DC.DCCCNID51,1)=1 AND  ISDATE(ISNULL(TD.dcAlpha6,''''))=1  
--	   		    AND CONVERT(DATETIME,TD.DCALPHA6) <=CONVERT(DATETIME,@FROMDATE) ORDER BY CONVERT(DATETIME,TD.dcAlpha6) 
--			END
					
	
--	UPDATE @TABATTENDANCE SET DaysAttended=CASE WHEN @MINHRSFDAY<=@NORMALWRKDHOURS THEN 1.0 WHEN @MINHRSHDAY<=@NORMALWRKDHOURS THEN 0.5 ELSE 0 END WHERE ID=@RC
--SET @RC=@RC+1
--END

--SELECT * FROM @TABATTENDANCE
--'
----print @SQL
--EXEC sp_executesql @SQL

--16-- GETTING RECORDING OF DATA INFORMATION
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT a.InvDocDetailsID,a.VoucherNo,CONVERT(DATETIME,a.DocDate) as DocDate,b.dcCCNID51 as EmpSeqNo,b.dcCCNID52,d.dcAlpha1,d.dcAlpha2 as PayrollMonth,d.dcAlpha2 as FromPayrollMonth,d.dcAlpha4 as ToPayrollMonth,
	CONVERT(INT,d.dcAlpha3) as ComponentID,c.dcNum1 as Amount,a.LineNarration as Remarks
	FROM INV_DocDetails A WITH(NOLOCK)
	JOIN COM_DocCCData B WITH(NOLOCK) ON B.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocNumData c WITH(NOLOCK) ON c.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
	WHERE d.tDocumentType=68 AND b.dcCCNID51 IN('+@EmpIDs+') AND a.StatusID=369 
	AND LEN(dcAlpha2)<15 AND LEN(dcAlpha4)<15
	AND ISDATE(dcAlpha2)=1 AND ISDATE(dcAlpha4)=1 AND ISNUMERIC(d.dcAlpha3)=1
	AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') BETWEEN CONVERT(DATETIME,dcAlpha2) AND CONVERT(DATETIME,dcAlpha4) '


	IF(@DontConsiderDocs='True' AND CONVERT(INT,@DontConsiderDocsDays)>0 )
	BEGIN
		SET @SQL=@SQL + ' AND CONVERT(DATETIME,A.DocDate)< CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderDocsDays) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') '
	END
	--PRINT @SQL
	EXEC sp_executesql @SQL
END

--17-- GETTING PAYROLL LOCK /UNLOCK INFORMATION
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT A.InvDocDetailsID,A.DocID,A.CostCenterID,A.VoucherNo,CONVERT(DATETIME,A.DocDate) as DocDate,
	d.dcAlpha1 as PayrollMonth,d.dcAlpha2 as PayrollMonthStart,d.dcAlpha3 as PayrollMonthEnd,d.dcAlpha4 as MPLockStatus,d.dcAlpha5 as DALockStatus,B.*
	FROM INV_DocDetails A WITH(NOLOCK)
	JOIN COM_DocCCData B WITH(NOLOCK) ON B.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
	WHERE d.tCostCenterID=40077 and a.StatusID=369 AND ISDATE(ISNULL(d.dcAlpha1,''''))=1 AND CONVERT(DATETIME,d.dcAlpha1)=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') '
	EXEC sp_executesql @SQL
END

--18-- GETTING VACATION DATA INFORMATION
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT DISTINCT b.dcCCNID51 as EmpSeqNo,b.dcCCNID52 as VacationField,a.CostCenterID,a.DocID,a.DocumentType,a.VoucherNo,a.DocNumber,CONVERT(DateTime,DocDate) as DocDate,
	CONVERT(DATETIME,ISNULL(d.dcAlpha1,''Jan 1 1900 12:00AM'')) as ReJoinDate,CONVERT(DATETIME,d.dcAlpha2) as FromDate,CONVERT(DATETIME,d.dcAlpha3) as ToDate,d.dcAlpha4 as NoOfDays,
	d.dcAlpha7 as CreditedDays,d.dcAlpha8 as AppliedDays,d.dcAlpha9 as ApprovedDays,
	d.dcAlpha10 as PaidDays,d.dcAlpha11 as ExcessDays,d.dcAlpha12 as RemainingDays,d.dcAlpha14 as EncashedDays,d.dcAlpha16 as IsEncash,d.dcAlpha24 as PayWithSalary 
	INTO #TVAC
	FROM INV_DocDetails a WITH(NOLOCK) 
	JOIN COM_DocCCData b WITH(NOLOCK) ON b.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID'

	IF(@DontConsiderDocsBasedonPostedDate='True')
	BEGIN
		SELECT top 1 @DontConsiderDocsDaysBasedonPostedDate=CutOffDays FROM @tblp WHERE PayrollMonth<=@PayrollMonth order by PayrollMonth desc
		
		IF(CONVERT(INT,isnull(@DontConsiderDocsDaysBasedonPostedDate,0))>0)
		BEGIN
		SET @SQL=@SQL + ' join com_approvals App WITH(NOLOCK) ON App.CCNODEID=a.DocID and app.ApprovalID in (select top 1 ApprovalID from com_approvals A1 WITH(NOLOCK) where  a1.CCNODEID=a.DocID AND a1.CCID=a.CostCenterID AND a1.StatusID=369 AND CONVERT(DATETIME,a1.CreatedDate)< CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderDocsDaysBasedonPostedDate) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') order by CONVERT(DATETIME,a1.CreatedDate) desc) '
		END
	END

	SET @SQL=@SQL + ' WHERE d.tCostCenterID=40072 and a.StatusID=369 AND ISNULL(d.dcAlpha17,'''')=''No'' AND b.dcCCNID51 IN('+@EmpIDs+') 
	AND ISDATE(ISNULL(d.dcAlpha2,''''))=1 AND ISDATE(ISNULL(d.dcAlpha3,''''))=1' 

	IF(@ConsiderVacationDayswhilePayrollProcessing=0 )
	BEGIN
		SET @SQL=@SQL + ' AND a.RefNodeID=0 '
	END

	SET @SQL=@SQL + ' ORDER BY CONVERT(DATETIME,d.dcAlpha2) DESC
	IF(SELECT COUNT(*) FROM #TVAC WITH(NOLOCK))=0
	BEGIN
		SELECT  b.dcCCNID51 as EmpSeqNo,a.DocID,MAX(CONVERT(DATETIME,d.dcAlpha2)) as FromDate INTO #TVAC2
		FROM INV_DocDetails a WITH(NOLOCK) 
		JOIN COM_DocCCData b WITH(NOLOCK) ON b.INVDOCDETAILSID=a.INVDOCDETAILSID
		JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
		WHERE d.tCostCenterID=40072 and a.StatusID=369 AND ISNULL(d.dcAlpha17,'''')=''No'' AND b.dcCCNID51 IN('+@EmpIDs+') 
		AND ISDATE(ISNULL(d.dcAlpha2,''''))=1 AND ISDATE(ISNULL(d.dcAlpha3,''''))=1 
		AND DATEDIFF(day,CONVERT(DATETIME,d.dcAlpha2),'''+CONVERT(NVARCHAR,@PayrollStart)+''')>0'

	IF(@ConsiderVacationDayswhilePayrollProcessing=0 )
	BEGIN
		SET @SQL=@SQL + ' AND a.RefNodeID=0 '
	END

	SET @SQL=@SQL + '	GROUP BY a.DocID,b.dcCCNID51
		----
			SELECT DISTINCT b.dcCCNID51 as EmpSeqNo,b.dcCCNID52 as VacationField,a.CostCenterID,a.DocID,a.DocumentType,a.VoucherNo,a.DocNumber,CONVERT(DateTime,DocDate) as DocDate,
			CONVERT(DATETIME,ISNULL(d.dcAlpha1,''Jan 1 1900 12:00AM'')) as ReJoinDate,CONVERT(DATETIME,d.dcAlpha2) as FromDate,CONVERT(DATETIME,d.dcAlpha3) as ToDate,d.dcAlpha4 as NoOfDays,
			d.dcAlpha7 as CreditedDays,d.dcAlpha8 as AppliedDays,d.dcAlpha9 as ApprovedDays,
			d.dcAlpha10 as PaidDays,d.dcAlpha11 as ExcessDays,d.dcAlpha12 as RemainingDays,d.dcAlpha14 as EncashedDays,d.dcAlpha16 as IsEncash,d.dcAlpha24 as PayWithSalary  
			FROM INV_DocDetails a WITH(NOLOCK) 
			JOIN COM_DocCCData b WITH(NOLOCK) ON b.INVDOCDETAILSID=a.INVDOCDETAILSID
			JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
			WHERE ISDATE(ISNULL(d.dcAlpha2,''''))=1 AND ISDATE(ISNULL(d.dcAlpha3,''''))=1 AND a.DocID IN(SELECT DocID From #TVAC2 WITH(NOLOCK))
		----
		DROP TABLE #TVAC2
	END
	ELSE
		SELECT * FROM #TVAC WITH(NOLOCK)

	DROP TABLE #TVAC


	'
	--PRINT @SQL
	EXEC sp_executesql @SQL
END

--19-- GETTING ARREARS DATA 
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT * FROM PAY_EmpMonthlyArrears WITH(NOLOCK) 
	WHERE EmpSeqNo IN('+@EmpIDs+') AND PayrollMonth='''+CONVERT(NVARCHAR,@PayrollMonth)+''' '
	EXEC sp_executesql @SQL
END

--20-- GETTING ADJUSTMENTS DATA 
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT * FROM PAY_EmpMonthlyAdjustments WITH(NOLOCK) 
	WHERE EmpSeqNo IN('+@EmpIDs+') AND PayrollMonth='''+CONVERT(NVARCHAR,@PayrollMonth)+''' '
	EXEC sp_executesql @SQL
END

--21-- GETTING LOANS CREATED FROM MONTHLY PAYROLL WHEN NETSALARY < 0 
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT b.dcCCNID51 as EmpSeqNo,a.InvDocDetailsID,a.DocID,a.CostCenterID,a.VoucherNo
	FROM INV_DocDetails a WITH(NOLOCK)
	LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
	LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
	WHERE d.tCostCenterID=40056 and a.StatusID=369 AND  b.dcCCNID51 IN('+@EmpIDs+') and ISDATE(ISNULL(d.dcAlpha7,''''))=1 AND CONVERT(DATETIME,d.dcAlpha7) = CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') '
	EXEC sp_executesql @SQL
END

--22-- GETTING ADJUSTMENTS DATA 
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT * FROM PAY_EmpMonthlyDues WITH(NOLOCK) 
	WHERE EmpSeqNo IN('+@EmpIDs+') AND PayrollMonth='''+CONVERT(NVARCHAR,@PayrollMonth)+''' '
	EXEC sp_executesql @SQL
END
--23-- GETTING DEPENDENT INFORMATION

SET @SQL='
SELECT a.EmployeeID as EmpSeqNo,a.*,CONVERT(DATETIME,Field2) as ChildDOB,ISNULL(b.Name,'''') as Relation,ISNULL(c.Name,'''') as Nationality 
FROM PAY_EmpDetail a WITH(NOLOCK) 
LEFT JOIN COM_Lookup b WITH(NOLOCK) on b.NodeID=a.Field5
LEFT JOIN COM_Lookup c WITH(NOLOCK) on c.NodeID=a.Field15
WHERE DType=255 AND a.EmployeeID IN('+@EmpIDs+')'
EXEC sp_executesql @SQL

--24-- GETTING USED DIMENSIONS NODEID BASED ON DATE
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	DECLARE @SysColName NVARCHAR(100),@FType NVARCHAR(100),@AsOnDate DATETIME
	SET @AsOnDate=@PayrollEnd
	SET @SQL='SELECT a.NodeID as EmpSeqNo'

	DECLARE CUR CURSOR FOR 
	Select SysColumnName,
	Case When (ISNULL(UserProbableValues,'')='H' OR ISNULL(UserProbableValues,'')='History' OR ISNULL(UserProbableValues,'')='HP2') THEN 'HISTORY' ELSE 'LISTBOX' END
	From ADM_CostCenterDef WITH(NOLOCK) Where CostCenterID=50051 and SysColumnName Like 'CCNID%' and IsColumnInUse=1
	OPEN CUR
	FETCH NEXT FROM CUR INTO @SysColName,@FType
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF(LEN(@SQL)>0)
			SET @SQL=@SQL+','
	
		IF(@FType='HISTORY')
		BEGIN
			SET @SQL=@SQL+'
							ISNULL((SELECT TOP 1 HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
							Where CostCenterID=50051 AND NodeID=a.NodeID AND HistoryCCID='+ CONVERT(NVARCHAR,(50000+ CONVERT(INT,(REPLACE(@SysColName,'CCNID',''))))) +' 
							AND CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@AsOnDate,106)+''') 
							ORDER BY FromDate DESC ),1) as '+@SysColName
		END
		ELSE
		BEGIN
			SET @SQL=@SQL+ '
							ISNULL((Select TOP 1 '+@SysColName+' FROM COM_CCCCDATA WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID=a.NodeID Order By ModifiedDate DESC ),1) as '+@SysColName
		END

	FETCH NEXT FROM CUR INTO @SysColName,@FType
	END
	CLOSE CUR
	DEALLOCATE CUR

	SET @SQL =@SQL+'
	FROM COM_CC50051 a WITH(NOLOCK)
	WHERE a.IsGroup=0
	AND a.NodeID IN('+@EmpIDs+')'

	--PRINT @SQL
	EXEC sp_executesql @SQL
END

--25-- GETTING LEAVE ENCASHMENT DETAILS  ---------
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	declare @LY nvarchar(100),@D1 DateTime,@D2 DateTime
	SELECT  @LY = convert(nvarchar, YEAR(@PayrollMonth))+'-'+Value+'-1' From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='LeaveYear'
	SELECT @D1=CONVERT(dateTime,@LY)
	if(MONTH(@D1)>MONTH(@PayrollMonth))
		SET @D1=dateadd(year,-1,@D1)
	SET @D2=dateadd(day,-1,(dateadd(YEAR,1,@D1)))
	--SELECT @D1,@D2
	
	SET @SQL='
	SELECT a.InvDocDetailsID,a.VoucherNo,CONVERT(DATETIME,a.DocDate) as DocDate,b.dcCCNID51 as EmpSeqNo,b.dcCCNID52 as LeaveType,
	d.dcAlpha1 as AvailableDays, d.dcAlpha2 as MaxEncashable,  d.dcAlpha3 as AppliedDays, d.dcAlpha4 as IsonResignTerm,  d.dcAlpha5 as IsValidDays,  
	d.dcAlpha6 as IsEditable, d.dcAlpha7 as ActualAvailableLeaves, c.dcNum1 as LEAmount,a.LineNarration as Remarks
	FROM INV_DocDetails A WITH(NOLOCK)
	JOIN COM_DocCCData B WITH(NOLOCK) ON B.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocNumData c WITH(NOLOCK) ON c.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
	WHERE d.tCostCenterID=40058 AND b.dcCCNID51 IN('+@EmpIDs+') AND a.StatusID=369
	AND CONVERT(DATETIME,a.DocDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@D1)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@D2)+''')  '

	EXEC sp_executesql @SQL
END
--26-- GETTING VACATION MANAGEMENT DETAILS
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	DECLARE @IsGradeWiseVM BIT
	SELECT @IsGradeWiseVM=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='GradeWiseVacation'

	SET @SQL=' 
	SELECT a.InvDocDetailsID,a.VoucherNo,CONVERT(DATETIME,a.DocDate) as DocDate,b.dcCCNID53 as GradeID,b.dcCCNID52 as ComponentID,
	d.dcAlpha1 as VacationField,d.dcAlpha2 as Percentage,d.dcAlpha3 as [0To6Month],d.dcAlpha4 as [6To12Month],d.dcAlpha5 as VacationDays,
	d.dcAlpha6 as ExcludeWeeklyOffs,d.dcAlpha7 as ExcludeHolidays,d.dcAlpha8 as ConsiderLOPWhileCalcCreditDays,d.dcAlpha9 as ConsiderVacationDayForVacationPeriod,
	d.dcAlpha10 as Adults,d.dcAlpha11 as Children,d.dcAlpha12 as Infants,d.dcAlpha13 as LeaveAccrual,d.dcAlpha14 as Formula,d.dcAlpha15 as ConsiderExcessDaysAsLOP,
	d.dcAlpha16 as PerDaySalCalc,d.dcAlpha17 as Earnings,d.dcAlpha18 as CreditDaysCalc,c.dcNum1 as ComponentPercentage,c.dcNum2 as NewValue,
	c.dcNum3 as AmountPaid,a.LineNarration as Remarks
	FROM INV_DocDetails A WITH(NOLOCK)
	JOIN COM_DocCCData B WITH(NOLOCK) ON B.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocNumData c WITH(NOLOCK) ON c.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
	WHERE d.tCostCenterID=40061 AND a.StatusID=369 '

	IF @IsGradeWiseVM=0
		SET @SQL=@SQL+' AND b.dcCCNID53=1 '
	ELSE
	BEGIN
	SET @SQL=@SQL+' AND b.dcCCNID53 IN (
						SELECT  DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
						WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID=50053   
						AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
						AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL)
					)
					'
	END
	--print @SQL
	EXEC sp_executesql @SQL
END
--27-- GETTING LEAVE ENCASH PAYMENT INFORMATION
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT a.InvDocDetailsID,a.VoucherNo,CONVERT(DATETIME,a.DocDate) as DocDate,b.dcCCNID51 as EmpSeqNo,b.dcCCNID52 as LeaveComponentID,
	d.dcAlpha10 as PayrollMonth,CONVERT(FLOAT,d.dcAlpha3) as AppliedDays,c.dcNum1 as LEAmount
	FROM INV_DocDetails A WITH(NOLOCK)
	JOIN COM_DocCCData B WITH(NOLOCK) ON B.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocNumData c WITH(NOLOCK) ON c.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
	WHERE d.tCostCenterID=40058 AND ISDATE(ISNULL(d.dcAlpha10,''''))=1 AND ISNUMERIC(d.dcAlpha3)=1 AND ISNULL(d.dcAlpha9,'''')=''Yes'' 
	AND b.dcCCNID51 IN('+@EmpIDs+') AND a.StatusID=369
	AND CONVERT(DATETIME,dcAlpha10) = CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') '

	--print @SQL
	EXEC sp_executesql @SQL
END
--28-- GETTING ATTENDANCE DIMENSION WISE DETAIL INFORMATION
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='
	SELECT a.InvDocDetailsID,a.DocID,a.CostCenterID,a.DocumentType,a.VoucherNo,CONVERT(DATETIME,a.DocDate) as DocDate,b.dcCCNID51 as EmpSeqNo,
	d.dcAlpha1 as PayrollMonth,d.dcAlpha2 as DaysAttended,d.dcAlpha3 as AbsentDays,d.dcAlpha4 as Leaves,
	c.dcNum5 as OT1,c.dcNum7 as OT2,c.dcNum9 as OT3,c.dcNum11 as OT4,c.dcNum13 as OT5
	FROM INV_DocDetails A WITH(NOLOCK)
	JOIN COM_DocCCData B WITH(NOLOCK) ON B.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocNumData c WITH(NOLOCK) ON c.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
	WHERE d.tCostCenterID=40079 AND ISDATE(ISNULL(d.dcAlpha1,''''))=1 
	AND b.dcCCNID51 IN('+@EmpIDs+') AND a.StatusID=369
	AND CONVERT(DATETIME,dcAlpha1) = CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') '

	--print @SQL
	EXEC sp_executesql @SQL
END

--29-- GETTING HOURS DEFINITION CHARTS
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SELECT a.InvDocDetailsID,a.DocID,a.CostCenterID,a.DocumentType,a.VoucherNo,
	d.dcAlpha1 as NormalHrs,d.dcAlpha2 as BreakHrs,d.dcAlpha3 as MinHalfHrs,d.dcAlpha4 as MinFullHrs,d.dcAlpha5 as MaxHrsPerDay,CONVERT(DATETIME,d.dcAlpha6) as WEF,
	d.dcAlpha8 as OT1,d.dcAlpha9 as OT2,d.dcAlpha10 as OT3,d.dcAlpha11 as OT4,d.dcAlpha12 as OT5,
	b.*
	FROM INV_DocDetails a WITH(NOLOCK) 
	JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
	JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
	WHERE d.tCostCenterID=40066 and a.StatusID=369 AND ISDATE(dcAlpha6)=1
END
--30-- GETTING VACATION FLDS
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='SELECT t.EmpSeqNo AS EmpSeqNo,SUM(t.VACAMOUNT) AS VACAMOUNT,SUM(t.ENCASHAMOUNT) AS ENCASHAMOUNT,SUM(t.EXCESSAMOUNT) AS EXCESSAMOUNT,CONVERT(FLOAT,ISNULL(t.VACDAYS,0)) AS VACDAYS,CONVERT(FLOAT,ISNULL(t.ENCASHDAYS,0)) AS ENCASHDAYS,CONVERT(FLOAT,ISNULL(t.EXCESSDAYS,0)) AS EXCESSDAYS,CONVERT(FLOAT,REPLACE(ISNULL(t.NETTOTAL,0),'','','''')) AS NETTOTAL
	FROM(
	SELECT b.dcCCNID51 AS EmpSeqNo,dcAlpha21,
	case when dcAlpha21=2 then dcCalcNum1 else -1* dcCalcNum1 end AS VACAMOUNT,dcCalcNum2 AS ENCASHAMOUNT,dcCalcNum3 AS EXCESSAMOUNT,CONVERT(FLOAT,ISNULL(dcAlpha4,0)) AS VACDAYS,CONVERT(FLOAT,ISNULL(dcAlpha14,0)) AS ENCASHDAYS,CONVERT(FLOAT,ISNULL(dcAlpha11,0)) AS EXCESSDAYS,CONVERT(FLOAT,REPLACE(ISNULL(dcAlpha6,0),'','','''')) AS NETTOTAL
	FROM INV_DocDetails a WITH(NOLOCK) 
	JOIN COM_DOCNUMDATA N WITH(NOLOCK) ON N.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocCCData b WITH(NOLOCK) ON b.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
	WHERE d.tCostCenterID=40072 AND  b.dcCCNID51 IN('+@EmpIDs+') AND a.StatusID=369 AND d.dcAlpha24=''Yes'' 
	AND ISDATE(d.dcAlpha25)=1 AND CONVERT(DATETIME,d.dcAlpha25)=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''')  ) t
	GROUP BY t.EmpSeqNo,t.VACDAYS,t.ENCASHDAYS,t.EXCESSDAYS,t.NETTOTAL'

	--PRINT(@SQL)
	EXEC sp_executesql @SQL
END
--31-- GETTING LATES INFORMATION

SET @SQL='SELECT b.dcCCNID51 AS EmpSeqNo,CONVERT(DATETIME,d.dcAlpha33) AS PayrollMonth,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha19,0))) as TotCheckInLateMins,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha20,0))) as TotCheckOutEarlyMins,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha21,0))) as TotBreak1MoreMins,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha22,0))) as TotBreak2MoreMins,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha23,0))) as TotBreak3MoreMins,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha24,0))) as TotBreak4MoreMins,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha25,0))) as TotBreak5MoreMins,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha26,0))) as TotLateHrsToDeduct,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha27,0))) as TotLateLeavesToDeduct,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha30,0))) as TotWorkingMinsLessBy,
SUM(CONVERT(FLOAT,ISNULL(dcAlpha32,0))) as TotAbsentMinsLessBy
FROM INV_DocDetails a WITH(NOLOCK)
JOIN COM_DOCNUMDATA N WITH(NOLOCK) ON N.INVDOCDETAILSID=a.INVDOCDETAILSID
JOIN COM_DocCCData b WITH(NOLOCK) ON b.INVDOCDETAILSID=a.INVDOCDETAILSID
JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
WHERE d.tCostCenterID=40097 AND a.StatusID=369
AND b.dcCCNID51 IN('+@EmpIDs+') 
AND ISDATE(d.dcAlpha33)=1 AND CONVERT(DATETIME,d.dcAlpha33)=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''')
GROUP BY b.dcCCNID51,CONVERT(DATETIME,d.dcAlpha33) 
'
--PRINT(@SQL)
EXEC sp_executesql @SQL


--32-- GETTING VACATION REJOIN INFO
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	SET @SQL='SELECT ISNULL(T.dcAlpha1,'''') as ReJoinDate,CONVERT(DATETIME,T.dcAlpha2) as FromDate,CONVERT(DATETIME,T.dcAlpha3) as ToDate,C.dcCCNID51 AS EmpSeqNo,I.VoucherNo,I.DocNumber FROM INV_DOCDETAILS I WITH(NOLOCK)
	JOIN COM_DOCCCDATA C WITH(NOLOCK) ON C.INVDOCDETAILSID=I.INVDOCDETAILSID
	JOIN COM_DOCTEXTDATA T WITH(NOLOCK) ON T.INVDOCDETAILSID=I.INVDOCDETAILSID
	WHERE T.tCostCenterID=40072 AND StatusID=369 AND LEN(T.DCALPHA2)<=15  AND ISDATE(ISNULL(T.DCALPHA2,''''))=1 AND ISNULL(T.dcAlpha1,'''')='''' AND C.dcCCNID51 IN('+@EmpIDs+')
	AND CONVERT(DATETIME,T.DCALPHA2)<CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''')
	'
	--PRINT(@SQL)
	EXEC sp_executesql @SQL
END

--33-- GETTING VACATION LATE REJOIN 
SELECT 'NODATA'
--SET @SQL='SELECT ISNULL(T.dcAlpha1,'''') as ReJoinDate,CONVERT(DATETIME,T.dcAlpha2) as FromDate,CONVERT(DATETIME,T.dcAlpha3) as ToDate,C.dcCCNID51 AS EmpSeqNo,I.VoucherNo,I.DocNumber FROM INV_DOCDETAILS I
--JOIN COM_DOCCCDATA C ON C.INVDOCDETAILSID=I.INVDOCDETAILSID
--JOIN COM_DOCTEXTDATA T ON T.INVDOCDETAILSID=I.INVDOCDETAILSID
--WHERE T.tCostCenterID=40072 AND StatusID=369 AND ISDATE(ISNULL(T.DCALPHA2,''''))=1 AND ISDATE(ISNULL(T.DCALPHA3,''''))=1 AND ISDATE(ISNULL(T.DCALPHA1,''''))=1 AND C.dcCCNID51 IN('+@EmpIDs+')
--AND CONVERT(DATETIME,T.DCALPHA3)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''')
--AND CONVERT(DATETIME,T.DCALPHA1)>CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
--'
----PRINT(@SQL)
--EXEC sp_executesql @SQL

--34-- Apprisal Month

SET @SQL='
SELECT EmployeeID,MAX(EffectFrom) as EffectFrom INTO #t1LAP FROM PAY_EmpPay WITH(NOLOCK) 
WHERE EmployeeID IN('+@EmpIDs+') AND CONVERT(DATETIME,EffectFrom)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
GROUP BY EmployeeID
HAVING COUNT(EmployeeID)>1

SELECT b.EmployeeID as EmpSeqNo,a.*,CONVERT(DATETIME,a.EffectFrom) AS CEffectFrom,CONVERT(DATETIME,a.ApplyFrom) AS CApplyFrom
FROM PAY_EmpPay a WITH(NOLOCK) 
JOIN #t1LAP b WITH(NOLOCK) ON b.EmployeeID=a.EmployeeID and b.EffectFrom=a.EffectFrom
WHERE a.EmployeeID IN('+@EmpIDs+') 

DROP TABLE #t1LAP '
--print (@SQL)
EXEC sp_executesql @SQL

--35-- ALL Apprisals

SET @SQL='

SELECT a.EmployeeID as EmpSeqNo,a.*,CONVERT(DATETIME,a.EffectFrom) AS CEffectFrom,CONVERT(DATETIME,a.ApplyFrom) AS CApplyFrom
FROM PAY_EmpPay a WITH(NOLOCK) 
WHERE a.EmployeeID IN('+@EmpIDs+') 
'
--print (@SQL)
EXEC sp_executesql @SQL

--36-- Approved Level Documents
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	DECLARE @DonotProcessPayrollIfDocumentareinApproval BIT
	SELECT @DonotProcessPayrollIfDocumentareinApproval=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DonotProcessPayrollIfDocumentareinApproval'
	IF @DonotProcessPayrollIfDocumentareinApproval=1
	BEGIN
		SET @SQL='
		SELECT VoucherNo,CC.dcCCNID51 EmpSeqNo FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		WHERE T.tDOCUMENTTYPE=62 AND I.STATUSID IN(371,441) AND CC.dcCCNID51 IN('+@EmpIDs+')
		AND ISDATE(T.DCALPHA4)=1 AND ISDATE(T.dcAlpha5)=1
		AND (  CONVERT(DateTime,T.DCALPHA4) between CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
				   or CONVERT(DateTime,T.DCALPHA5) between CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
				   or CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollStart)+''') between CONVERT(DateTime,T.DCALPHA4) and CONVERT(DateTime,T.DCALPHA5)
				   or CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollEnd)+''') between CONVERT(DateTime,T.DCALPHA4) and CONVERT(DateTime,T.DCALPHA5))
		UNION ALL
		SELECT VoucherNo,CC.dcCCNID51 EmpSeqNo FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		WHERE T.tCostCenterID=40072 AND I.STATUSID IN(371,441) AND CC.dcCCNID51 IN('+@EmpIDs+')
		AND ISDATE(T.DCALPHA2)=1 AND ISDATE(T.dcAlpha3)=1
		AND (  CONVERT(DateTime,T.DCALPHA2) between CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
				   or CONVERT(DateTime,T.dcAlpha3) between CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
				   or CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollStart)+''') between CONVERT(DateTime,T.DCALPHA2) and CONVERT(DateTime,T.dcAlpha3)
				   or CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollEnd)+''') between CONVERT(DateTime,T.DCALPHA2) and CONVERT(DateTime,T.dcAlpha3))
		UNION ALL
		SELECT VoucherNo,CC.dcCCNID51 EmpSeqNo FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		WHERE T.tDOCUMENTTYPE=67 AND I.STATUSID IN(371,441) AND CC.dcCCNID51 IN('+@EmpIDs+')
		AND LEN(dcAlpha1)=11 AND ISDATE(T.DCALPHA1)=1
		AND CONVERT(DateTime,T.DCALPHA1) between CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DateTime,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
		UNION ALL
		SELECT VoucherNo,CC.dcCCNID51 EmpSeqNo FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		WHERE T.tDocumentType=68 AND I.STATUSID IN(371,441) AND CC.dcCCNID51 IN('+@EmpIDs+')
		AND LEN(dcAlpha2)=11 AND LEN(dcAlpha4)=11 AND ISDATE(T.dcAlpha2)=1 AND ISDATE(T.dcAlpha4)=1
		AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') BETWEEN CONVERT(DATETIME,dcAlpha2) AND CONVERT(DATETIME,dcAlpha4)
		UNION ALL
		SELECT VoucherNo,CC.dcCCNID51 EmpSeqNo FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		WHERE T.tCostCenterID=40056 AND I.STATUSID IN(371,441) AND CC.dcCCNID51 IN('+@EmpIDs+')
		AND ISDATE(T.dcAlpha6)=1 
		AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''')= CONVERT(DATETIME,dcAlpha6)
		UNION ALL
		SELECT VoucherNo,CC.dcCCNID51 EmpSeqNo FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		WHERE T.tCostCenterID=40057 AND I.STATUSID IN(371,441) AND CC.dcCCNID51 IN('+@EmpIDs+')
		AND ISDATE(T.dcAlpha4)=1 
		AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''')= CONVERT(DATETIME,dcAlpha4)
		'
	END
	ELSE
	BEGIN
		SET @SQL='
		SELECT '''' VoucherNo,0 EmpSeqNo
		'
	END

	--print (@SQL)
	EXEC sp_executesql @SQL
END

--37-- PAYROLL STRUCTURE LATEST
IF @IsGradeWiseMP=1
BEGIN
		SET @SQL='	
	SELECT b.Name as ComponentName,CONVERT(DATETIME,a.PayrollDate) as CPayrollDate,a.* FROM COM_CC50054 a WITH(NOLOCK) 
	Left Join COM_CC50052 b WITH(NOLOCK) on b.NodeID=a.ComponentID
	WHERE GradeID IN(SELECT  DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
									WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID=50053   
									AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
									AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL))
	and PayrollDate=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE  
					 GradeID IN(	SELECT  DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
									WHERE NodeID IN('+@EmpIDs+')AND CostCenterID=50051 AND HistoryCCID=50053   
									AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
									AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''') OR ToDate IS NULL))
								  ) 
				   ORDER BY GradeID,Type,SNo  '
				  
				  --print @SQL
	EXEC sp_executesql @SQL
END
ELSE 
BEGIN
	SET @SQL='SELECT b.Name as ComponentName,a.* FROM COM_CC50054 a WITH(NOLOCK) 
	Left Join COM_CC50052 b WITH(NOLOCK) on b.NodeID=a.ComponentID
	WHERE GradeID=1 AND PayrollDate=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE 
					 GradeID =1)	ORDER BY Type,SNo'
	--print (@SQL)
	EXEC sp_executesql @SQL
END

--38--Previous Month Payroll Data
IF(@IsPayrollOther=1)
BEGIN
	SELECT 'NODATA'
END
ELSE
BEGIN
	DECLARE @DonotprocesspayrollifPreviousPayrollMonthnotprocessed BIT
	SELECT @DonotprocesspayrollifPreviousPayrollMonthnotprocessed=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DonotprocesspayrollifPreviousPayrollMonthnotprocessed'
	IF @DonotprocesspayrollifPreviousPayrollMonthnotprocessed=1
	BEGIN
	SET @SQL='
	SELECT DISTINCT b.dcCCNID51 as EmpSeqNo,a.VoucherNo as VoucherNo FROM INV_DocDetails a WITH(NOLOCK) 
	JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
	WHERE a.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' 
	AND b.dcCCNID51 IN('+@EmpIDs+') AND CONVERT(DATETIME,a.DueDate)=DATEADD(M,-1,CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollMonth)+''')) '
	END
	ELSE
	BEGIN
	SET @SQL='
		SELECT 0 EmpSeqNo,'''' VoucherNo
		'
	END

	EXEC sp_executesql @SQL
END

--39--Daily Attendance Def
SELECT CostCenterID,UserColumnName,SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=40067 AND IsColumnInUse=1 AND SysColumnName LIKE'dcNum%'

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
