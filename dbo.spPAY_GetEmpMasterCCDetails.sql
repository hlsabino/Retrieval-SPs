USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmpMasterCCDetails]
	@AsOnDate [datetime],
	@Where [nvarchar](max),
	@Flag [int] = 0,
	@RoleID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  
	--Declaration Section  
	DECLARE @HasAccess BIT,@CostCenterID INT
	SET @CostCenterID=50051
	  
	--User access check   
	--SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2) 

	--IF @HasAccess=0  
	--BEGIN  
	--	RAISERROR('-105',16,1)  
	--END  


DECLARE @SQL NVARCHAR(MAX),@SelCols NVARCHAR(MAX),@From NVARCHAR(MAX),@DCCs NVARCHAR(MAX),@HCCs NVARCHAR(MAX),@CCName NVARCHAR(MAX),@CCNameJOIN NVARCHAR(MAX)
SELECT @DCCs=STUFF( (SELECT ',ISNULL(b.'+SysColumnName+',1) AS '+ SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 AND SysColumnName Like 'CCNID%' AND IsColumnInUse=1 AND ISNULL(UserProbableValues,'')<>'H' AND ISNULL(UserProbableValues,'')<>'HP2'  FOR XML PATH('') ),1,1,'') 
SELECT @HCCs=STUFF( (SELECT ',ISNULL('+SysColumnName+',1) AS '+ SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 AND SysColumnName Like 'CCNID%' AND IsColumnInUse=1 AND (ISNULL(UserProbableValues,'')='H' OR ISNULL(UserProbableValues,'')='HP2')  FOR XML PATH('') ),1,1,'') 

SELECT @CCName=STUFF( (SELECT ',ISNULL('+SysColumnName+'M.Name,'''') AS '+ SysColumnName+'_Name' FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 AND SysColumnName Like 'CCNID%' AND IsColumnInUse=1 FOR XML PATH('') ),1,1,'') 
SELECT @CCNameJOIN=STUFF( (SELECT ' LEFT JOIN '+ParentCostCenterSysName+ ' '+ SysColumnName+'M WITH(NOLOCK) ON '+SysColumnName+'M.NodeID=EMP.'+SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 AND SysColumnName Like 'CCNID%' AND IsColumnInUse=1 FOR XML PATH('') ),1,1,'') 

--SELECT @DCCs DirectCCs,@HCCs HistoryCCs,@CCName,@CCNameJOIN

SET @SelCols='SELECT EMP.* '

IF(LEN(@CCName)>0)
	SET @SelCols=@SelCols+','+@CCName

SET @SelCols=@SelCols+' FROM ( SELECT a.NodeID as EmpSeqNo,a.Code as EmpCode,a.Name as EmpName,a.Name as Emp_Name,ISNULL(CONVERT(DATETIME,a.DOJ),''01-Jan-9000'') as DOJ,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-9000'') as DORelieve,a.lft,a.PaymentMode,ISNULL(a.RptManager,0) as RptManager,ISNULL(RM.Name,'''') as RptManager_Name   '
SET @From=' FROM COM_CC50051 a WITH(NOLOCK) 
LEFT JOIN COM_CC50051 RM WITH(NOLOCK) on RM.NodeID=a.RptManager '

IF(LEN(@DCCs)>0)
BEGIN
	SET @SelCols=@SelCols+','+@DCCs
	SET @From=@From+' LEFT JOIN COM_CCCCData b WITH(NOLOCK) ON b.CostCenterID=50051 AND b.NodeID=a.NodeID'
END

IF(LEN(@HCCs)>0)
BEGIN
	DECLARE @RCnt INT,@RId INT,@SysColName NVARCHAR(100)
	CREATE TABLE #HC1(RId INT IDENTITY(1,1),SysColName NVARCHAR(100))
	INSERT INTO #HC1
	SELECT SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) 
	WHERE CostCenterID=50051 AND SysColumnName Like 'CCNID%' AND IsColumnInUse=1 AND (ISNULL(UserProbableValues,'')='H' OR ISNULL(UserProbableValues,'')='HP2')
	SET @RCnt=@@ROWCOUNT
	SET @RId=1
	WHILE(@RId<=@RCnt)
	BEGIN
		SELECT @SysColName=SysColName FROM #HC1 WHERE RId=@RId
		
		SET @SelCols=@SelCols+','+'ISNULL((SELECT TOP 1 HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
										WHERE CostCenterID=50051 AND NodeID=a.NodeID AND HistoryCCID='+ CONVERT(NVARCHAR,(50000+CONVERT(INT,REPLACE(@SysColName,'CCNID','')))) +'
										AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@AsOnDate)+''') BETWEEN CONVERT(DATETIME,FromDate) AND CONVERT(DATETIME,ISNULL(ToDate,CONVERT(FLOAT,CONVERT(DATETIME,''01-01-2200'')) ))  
										ORDER BY FromDate DESC 
										),1) AS '+@SysColName
		
		SET @RId=@RId+1
	END
	DROP TABLE #HC1
END

SET @SQL=@SelCols+@From
IF (ISNULL(@Flag,0)=0)
BEGIN
	SET @SQL=@SQL+' WHERE a.IsGroup=0 AND a.StatusID NOT IN (251,300,301) ) AS EMP '
END
ELSE IF (ISNULL(@Flag,0)=1)-- Payslip
BEGIN
	SET @SQL=@SQL+' WHERE a.IsGroup=0 ) AS EMP '
END

IF(LEN(@CCNameJOIN)>0)
	SET @SQL=@SQL+@CCNameJOIN 

SET @SQL=@SQL+' WHERE 1=1  '

IF (ISNULL(@Flag,0)=1)-- Payslip
BEGIN
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,261,672) --Do not show sub ordinates Payslips
	IF @HasAccess=1  
	BEGIN   
		DECLARE @EmpNodeID INT
		Select @EmpNodeID=NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE IsGroup=0 AND LoginUserID=(SELECT USERNAME FROM ADM_Users WHERE UserID=@UserID)
		IF(ISNULL(@EmpNodeID,0)>0)
			SET @SQL=@SQL+' AND EmpSeqNo IN('+CONVERT(nvarchar,@EmpNodeID)+')'
	END 
END

IF(LEN(@Where)>0)
BEGIN
	SET @SQL=@SQL+@Where 
END


PRINT @SQL
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
