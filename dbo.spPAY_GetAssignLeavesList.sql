USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetAssignLeavesList]
	@DimWise [nvarchar](20) = 'GradeWise',
	@EmpIDs [nvarchar](max) = null,
	@Date [datetime] = null,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
DECLARE @Year INT,@ALStartMonth INT,@ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME,@strQuery NVARCHAR(MAX)
CREATE TABLE #TAB (ID INT IDENTITY(1,1),dcID INT,EmployeeID INT,GradeID INT,LeaveTypeID INT,
				   PrevYearAlloted INT,Leaves float,PrevYearBalanceOB INT,CurrYearConsumed DECIMAL(9,2),Balance DECIMAL(9,2),Location INT)	
				   
--FOR START DATE AND END DATE OF LEAVE YEAR
EXEC [spPAY_EXTGetLeaveyearDates] @Date,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
						
IF UPPER(@DimWise)='GRADEWISE'  
BEGIN
	IF((SELECT COUNT(*) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID53' and IsColumnInUse=1 and UserProbableValues='H')>0)
	BEGIN	
		INSERT INTO #TAB 
		--LOADING FOR NEW GRADES
		SELECT 0,1 EmpNode,C53.NODEID,C52.NODEID,0,0,0,0,0,0 FROM COM_CC50053 C53 WITH(NOLOCK) 
		CROSS JOIN COM_CC50052 C52 WITH(NOLOCK) WHERE C52.PARENTID=5 AND C52.ISGROUP=0  AND C53.ISGROUP=0
		AND  C52.NodeID IN (Select ComponentID from Com_CC50054  with(nolock) where Type=4 And Convert(Datetime,Payrolldate)=(Select Max(Convert(Datetime,Payrolldate)) from Com_CC50054 with(nolock)))
		UNION
		--LOADING FOR NEW EMPLOYEES
		SELECT 0,C51.NODEID EMPNODE,
		--C53.NODEID GRADENODE
		(SELECT top 1 HISTORYNODEID FROM COM_HISTORYDETAILS WITH(NOLOCK) WHERE  COSTCENTERID=50051 AND HISTORYCCID=50053 AND NODEID=C51.NODEID AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,@ALEndMonthYear) OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,@ALEndMonthYear) AND CONVERT(DATETIME,@ALEndMonthYear)) AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,@ALEndMonthYear) OR ToDate IS NULL)) GRADENODE
		,C52.NODEID,0,0,0,0,0,0 
		FROM COM_CC50051 C51 WITH(NOLOCK) 
		inner join COM_CCCCData cc WITH(NOLOCK) on cc.nodeid=c51.nodeid and cc.costcenterid=50051 and isnull(cc.ccnid53,'')<>''
		inner JOIN COM_CC50053 C53 WITH(NOLOCK) on cc.ccnid53=c53.nodeid AND C53.ISGROUP=0
		CROSS JOIN COM_CC50052 C52 WITH(NOLOCK) 
		WHERE  C52.PARENTID=5 AND C52.ISGROUP=0 AND C51.ISGROUP=0 AND C51.StatusID in (250,302,303,304,305) --AND ISNULL(CONVERT(DATETIME,C51.DORelieve),'01-Jan-9000')='01-Jan-9000'
		AND  C52.NodeID IN (Select ComponentID from Com_CC50054  with(nolock) where Type=4 And Convert(Datetime,Payrolldate)=(Select Max(Convert(Datetime,Payrolldate)) from Com_CC50054 with(nolock)))
		AND ( CONVERT(DATETIME,C51.DOJ) <= @ALEndMonthYear AND ISNULL(CONVERT(DATETIME,C51.DORelieve),'01-Jan-9000') >=@ALStartMonthYear ) 
	END
	ELSE
	BEGIN
		INSERT INTO #TAB 
		--LOADING FOR NEW GRADES
		SELECT 0,1 EmpNode,C53.NODEID,C52.NODEID,0,0,0,0,0,0 FROM COM_CC50053 C53 WITH(NOLOCK) 
		CROSS JOIN COM_CC50052 C52 WITH(NOLOCK) WHERE C52.PARENTID=5 AND C52.ISGROUP=0  AND C53.ISGROUP=0
		AND  C52.NodeID IN (Select ComponentID from Com_CC50054  with(nolock) where Type=4 And Convert(Datetime,Payrolldate)=(Select Max(Convert(Datetime,Payrolldate)) from Com_CC50054 with(nolock)))
		UNION
		--LOADING FOR NEW EMPLOYEES
		SELECT 0,C51.NODEID EMPNODE,
		C53.NODEID GRADENODE
		,C52.NODEID,0,0,0,0,0,0 
		FROM COM_CC50051 C51 WITH(NOLOCK) 
		inner join COM_CCCCData cc WITH(NOLOCK) on cc.nodeid=c51.nodeid and cc.costcenterid=50051 and isnull(cc.ccnid53,'')<>''
		inner JOIN COM_CC50053 C53 WITH(NOLOCK) on cc.ccnid53=c53.nodeid  AND C53.ISGROUP=0
		CROSS JOIN COM_CC50052 C52 WITH(NOLOCK) 
		WHERE  C52.PARENTID=5 AND C52.ISGROUP=0 AND C51.ISGROUP=0 AND C51.StatusID in (250,302,303,304,305) --AND ISNULL(CONVERT(DATETIME,C51.DORelieve),'01-Jan-9000')='01-Jan-9000'
		AND  C52.NodeID IN (Select ComponentID from Com_CC50054  with(nolock) where Type=4 And Convert(Datetime,Payrolldate)=(Select Max(Convert(Datetime,Payrolldate)) from Com_CC50054 with(nolock)))
		AND ( CONVERT(DATETIME,C51.DOJ) <= @ALEndMonthYear AND ISNULL(CONVERT(DATETIME,C51.DORelieve),'01-Jan-9000') >=@ALStartMonthYear ) 
	END
END

SELECT 0 as GradeID INTO #TGR

IF(ISNULL(@EmpIDs,'')<>'')
BEGIN
	SET @strQuery=''
	SET @strQuery='DELETE FROM #TAB WHERE EmployeeID<>1 AND EmployeeID NOT IN (Select a.NodeID From COM_CC50051 a WITH(NOLOCK) WHERE '+ CONVERT(NVARCHAR(MAX),@EmpIDs) +')'
	SET @strQuery=@strQuery + ' SELECT DISTINCT ISNULL(GradeID,0) as GradeID INTO #TGR FROM #TAB WHERE EmployeeID>1
								DELETE FROM #TAB WHERE ISNULL(GRADEID,0) NOT IN (SELECT GRADEID FROM #TGR)'
	EXEC sp_executesql @STRQUERY
END

IF((SELECT COUNT(*) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID2' and IsColumnInUse=1 and UserProbableValues='H')>0)
BEGIN
	Update T Set Location=HistoryNodeID 
	FROM COM_HistoryDetails H WITH(NOLOCK),#TAB T WHERE H.NodeID=T.EmployeeID AND H.CostCenterID=50051 AND H.HistoryCCID=50002 AND (CONVERT(DATETIME,H.FromDate)<=CONVERT(DATETIME,@ALEndMonthYear)) AND (CONVERT(DATETIME,H.ToDate)>=CONVERT(DATETIME,@ALEndMonthYear) OR H.ToDate IS NULL)
END
ELSE IF((SELECT COUNT(*) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID2' and IsColumnInUse=1 and UserProbableValues<>'H')>0)
BEGIN
	Update T Set T.Location=ISNULL(CC.CCNID2,1) FROM #TAB T,COM_CCCCDATA CC WITH(NOLOCK) WHERE T.EmployeeID=CC.NODEID AND CC.CostCenterID=50051
END	

SELECT ID,dcID,EmployeeID dcCCNID51_Key,ISNULL(GradeID,1) dcCCNID53_Key,LeaveTypeID dcCCNID52_Key,PrevYearAlloted,Leaves dcNum3,PrevYearBalanceOB,CurrYearConsumed,Balance,Location FROM #TAB 
WHERE  Convert(Varchar,LeaveTypeID)  NOT IN (Select Isnull(TD.dcAlpha1,'0') From Com_DocTextData TD with(nolock),Inv_DocDetails ID with(nolock) Where ID.InvDocDetailsID=TD.InvDocDetailsID And ID.CostCenterID=40061)
 
DROP TABLE #TAB
DROP TABLE #TGR
SET NOCOUNT OFF;		
END

----spPAY_GetAssignLeavesList 
-- 'GradeWise'
-- ,' 1=1 '
-- ,'1/1/2019 12:00:00 AM'
-- ,1
-- ,1
GO
