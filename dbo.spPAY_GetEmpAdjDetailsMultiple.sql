USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmpAdjDetailsMultiple]
	@EmpIDs [nvarchar](max),
	@PayrollMonth [nvarchar](100),
	@PayrollStart [nvarchar](100),
	@PayrollEnd [nvarchar](100),
	@Flag [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON; 

DECLARE @SQL NVARCHAR(MAX),@ConsiderLOPBasedOn NVARCHAR(500),@SQ NVARCHAR(MAX),@DontConsiderDocsDaysBasedonPostedDate NVARCHAR(10),@IsGradeWiseMP BIT,@DontConsiderEmpLeavesVacationDataDaysBasedonPostedDateXML nvarchar(max),@XML xml

SELECT @ConsiderLOPBasedOn=Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='ConsiderLOPBasedOn'
SELECT @DontConsiderEmpLeavesVacationDataDaysBasedonPostedDateXML=Value From ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DontConsiderEmpLeavesVacationDataDaysBasedonPostedDate'
SELECT @IsGradeWiseMP=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='GradeWiseMonthlyPayroll'

--0-- Getting PrevMonth Leave based on PostedDate

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
begin

SET @SQ=''

IF(@Flag=0)-- LOP Auto Adj. 
BEGIN
	SET @SQ='
	SELECT B.dcCCNID51 as EmpSeqNo,D.NodeID as ComponentID,D.Name as LeaveType,
		CONVERT(DATETIME,c.dcAlpha4) as FromDate,CONVERT(DATETIME,c.dcAlpha5) as ToDate,c.dcAlpha7 as NoOfDays,A.StatusID,Convert(DATETIME,DocDate) as DocDate,CONVERT(DATETIME,c.dcAlpha15) as RejoinDate,ISNULL(c.dcAlpha16,'''') as PostedFrom
		FROM INV_DocDetails A WITH(NOLOCK)
		JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=A.InvDocDetailsID
		JOIN COM_DocTextData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_CC50052 D WITH(NOLOCK) ON D.NodeID=B.dcCCNID52 
		join com_approvals App WITH(NOLOCK) ON App.CCNODEID=a.DocID and app.ApprovalID in (select top 1 ApprovalID from com_approvals A1 WITH(NOLOCK) where  a1.CCNODEID=a.DocID AND a1.CCID=a.CostCenterID AND a1.StatusID=369 AND CONVERT(DATETIME,a1.CreatedDate)>= CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderDocsDaysBasedonPostedDate) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') order by CONVERT(DATETIME,a1.CreatedDate) desc)  
		WHERE C.tDocumentType=62 AND a.StatusID=369 AND  ISDATE(ISNULL(c.dcAlpha4,''''))=1 AND ISDATE(ISNULL(c.dcAlpha5,''''))=1  AND B.dcCCNID51 IN('+@EmpIDs+') 
		AND B.dcCCNID52 IN ('+@ConsiderLOPBasedOn+') AND
	(
		CONVERT(DATETIME,dcAlpha4) between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
		or CONVERT(DATETIME,dcAlpha5) between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
		or CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5)
		or CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''') between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha4))'
END
ELSE IF(@Flag=1)-- PAID Leave in MP Formula
BEGIN
	SET @SQ='
	SELECT B.dcCCNID51 as EmpSeqNo,D.NodeID as ComponentID,D.Name as LeaveType,
		CONVERT(DATETIME,c.dcAlpha4) as FromDate,CONVERT(DATETIME,c.dcAlpha5) as ToDate,c.dcAlpha7 as NoOfDays,A.StatusID,Convert(DATETIME,DocDate) as DocDate,CONVERT(DATETIME,c.dcAlpha15) as RejoinDate,ISNULL(c.dcAlpha16,'''') as PostedFrom
		FROM INV_DocDetails A WITH(NOLOCK)
		JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=A.InvDocDetailsID
		JOIN COM_DocTextData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_CC50052 D WITH(NOLOCK) ON D.NodeID=B.dcCCNID52 
		join com_approvals App WITH(NOLOCK) ON App.CCNODEID=a.DocID and app.ApprovalID in (select top 1 ApprovalID from com_approvals A1 WITH(NOLOCK) where  a1.CCNODEID=a.DocID AND a1.CCID=a.CostCenterID AND a1.StatusID=369 AND CONVERT(DATETIME,a1.CreatedDate)>= CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderDocsDaysBasedonPostedDate) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') order by CONVERT(DATETIME,a1.CreatedDate) desc)  
		WHERE C.tDocumentType=62 AND a.StatusID=369 AND  ISDATE(ISNULL(c.dcAlpha4,''''))=1 AND ISDATE(ISNULL(c.dcAlpha5,''''))=1  AND B.dcCCNID51 IN('+@EmpIDs+')'
		 
		if(Len(@ConsiderLOPBasedOn)>0)
			SET @SQ= @SQ + ' AND B.dcCCNID52 NOT IN ('+@ConsiderLOPBasedOn+') '

		SET @SQ= @SQ + ' AND (
		CONVERT(DATETIME,dcAlpha4) between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
		or CONVERT(DATETIME,dcAlpha5) between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
		or CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5)
		or CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''') between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha4))
		
		UNION
		SELECT DISTINCT b.dcCCNID51 as EmpSeqNo,b.dcCCNID52 as VacationField,'''',CONVERT(DATETIME,d.dcAlpha2) as FromDate,CONVERT(DATETIME,d.dcAlpha3) as ToDate,d.dcAlpha4 as NoOfDays,A.StatusID,CONVERT(DateTime,DocDate) as DocDate ,CONVERT(DATETIME,d.dcAlpha1) as RejoinDate,''''
	FROM INV_DocDetails a WITH(NOLOCK) 
	JOIN COM_DocCCData b WITH(NOLOCK) ON b.INVDOCDETAILSID=a.INVDOCDETAILSID
	JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID join com_approvals App WITH(NOLOCK) ON App.CCNODEID=a.DocID and app.ApprovalID in (select top 1 ApprovalID from com_approvals A1 WITH(NOLOCK) where  a1.CCNODEID=a.DocID AND a1.CCID=a.CostCenterID AND a1.StatusID=369 AND CONVERT(DATETIME,a1.CreatedDate)>= CONVERT(DATETIME,'''+CONVERT(NVARCHAR,( CONVERT(NVARCHAR,@DontConsiderDocsDaysBasedonPostedDate) +'-'+ CONVERT(NVARCHAR(3),DATENAME(MONTH,@PayrollMonth))+'-'+ CONVERT(NVARCHAR,YEAR(@PayrollMonth)) ))+''') order by CONVERT(DATETIME,a1.CreatedDate) desc)  
	WHERE d.tCostCenterID=40072 and a.StatusID=369 AND ISNULL(d.dcAlpha17,'''')=''No'' AND b.dcCCNID51 IN('+@EmpIDs+') 
	AND ISDATE(ISNULL(d.dcAlpha2,''''))=1 AND ISDATE(ISNULL(d.dcAlpha3,''''))=1 AND a.RefNodeID=0 
	AND (
		CONVERT(DATETIME,dcAlpha2) between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
		or CONVERT(DATETIME,dcAlpha3) between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') and CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')
		or CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') between CONVERT(DATETIME,dcAlpha2) and CONVERT(DATETIME,dcAlpha3)
		or CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''') between CONVERT(DATETIME,dcAlpha2) and CONVERT(DATETIME,dcAlpha3))
	'
END

PRINT @SQ
EXEC(@SQ)
end
else
select 'nodata'

--1-- PAYROLL STRUCTURE INFORMATION

IF @IsGradeWiseMP=1
BEGIN
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
	EXEC sp_executesql @SQL
END

--2-- WEEKLY OFFS DEFINITION INFORMATION 

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

--PRINT @SQL
EXEC sp_executesql @SQL

--3-- LIST OF HOLIDAYS INFORMATION
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
--PRINT @SQL
EXEC sp_executesql @SQL


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
