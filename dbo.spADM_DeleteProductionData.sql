USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteProductionData]
	@ModuleID [int],
	@DIMENSIONLIST [nvarchar](max),
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON;  
BEGIN TRANSACTION  
BEGIN TRY   
DECLARE @SQL NVARCHAR(MAX)
IF(@ModuleID=4)--PRODUCTION
BEGIN  
	SET @SQL='CREATE TABLE #TAB(ID BIGINT IDENTITY (1,1),COSTCENTERID BIGINT,SID BIGINT)  
	DECLARE @I INT,@RC INT,@SNO BIGINT,@TABLENAME NVARCHAR(100),@STRQRY NVARCHAR(MAX),@DIMID BIGINT,@COSTCENTERID BIGINT,@J INT,@TRC INT,@SQL NVARCHAR(MAX) 
	DECLARE @Tbl1 TABLE(ID INT IDENTITY(1,1),FeatureID INT)  
	DECLARE @Tbl TABLE(ID INT IDENTITY(1,1),FeatureID INT)  
	
	INSERT INTO @Tbl1  
	EXEC SPSplitString @DIMENSIONLIST,'',''  

	INSERT INTO @Tbl select featureid from @Tbl1  order by featureid  DESC
	DELETE FROM @Tbl1 
	     
	SELECT @J=1,@TRC=COUNT(*) FROM @Tbl  
	WHILE(@J<=@TRC)  
	BEGIN  
		 SELECT @COSTCENTERID=FeatureID FROM @Tbl WHERE ID=@J  
		 IF(@COSTCENTERID=78)--MANUFACTURING ORDER  
		 BEGIN  
			  TRUNCATE TABLE #TAB  
			  INSERT INTO #TAB SELECT @COSTCENTERID,MFGOrderID FROM PRD_MFGOrder WITH(NOLOCK) WHERE MFGOrderID>1    
			  SELECT @I=1,@RC=COUNT(*) FROM #TAB WITH(NOLOCK)  
			  WHILE(@I<=@RC)  
			  BEGIN  
				SELECT @SNO=SID FROM #TAB WITH(NOLOCK) WHERE ID=@I  
				EXEC spPRD_DeleteMO  @SNO ,@UserID ,''ADMIN'' ,@LangID ,1  
				SET @I=@I+1  
			  END  
		 END  
		 ELSE IF(@COSTCENTERID=76)--BILL OF MATERIAL  
		 BEGIN  
			  TRUNCATE TABLE #TAB  
			  INSERT INTO #TAB SELECT @COSTCENTERID,BOMID FROM PRD_BillOfMaterial WITH(NOLOCK) where BOMID>1  
			  SELECT @I=1,@RC=COUNT(*) FROM #TAB WITH(NOLOCK)  
			  WHILE(@I<=@RC)  
			  BEGIN  
				SELECT @SNO=SID FROM #TAB WITH(NOLOCK) WHERE ID=@I  
				EXEC spPRD_DeleteBOMDetails  @SNO ,@LangID  
				SET @I=@I+1  
			  END  
			  
			  --Stage Dimension
			  SET @STRQRY=''''  
			  Select @DIMID=Isnull(Value,0) From [COM_CostCenterPreferences] WITH(NOLOCK) Where CostCenterId=76 AND Name=''StageDimension''  
			  Select @TABLENAME=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@DIMID  
			  TRUNCATE TABLE #TAB  
			  SET @STRQRY=''INSERT INTO #TAB SELECT ''+ CONVERT(VARCHAR,@DIMID) +'',NODEID FROM ''+ CONVERT(VARCHAR,@TABLENAME) +'' WITH(NOLOCK) where NODEID>2''   
			  EXEC (@STRQRY)  
			
			  SELECT @I=1,@RC=COUNT(*) FROM #TAB WITH(NOLOCK)  
			  WHILE(@I<=@RC)  
			  BEGIN  
				SELECT @SNO=SID FROM #TAB WITH(NOLOCK) WHERE ID=@I  
				EXEC spCOM_DeleteCostCenter @DIMID ,@SNO ,1 ,@UserID ,@LangID     
				SET @I=@I+1  
			  END  
		  
			  --Bom Dimension
			  SET @STRQRY=''''  
			  Select @DIMID=Isnull(Value,0) From [COM_CostCenterPreferences] WITH(NOLOCK) Where CostCenterId=76 AND Name=''BomDimension''  
			  Select @TABLENAME=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@DIMID   
			  TRUNCATE TABLE #TAB  
			  SET @STRQRY=''INSERT INTO #TAB SELECT ''+ CONVERT(VARCHAR,@DIMID) +'',NODEID FROM ''+ CONVERT(VARCHAR,@TABLENAME) +'' WITH(NOLOCK) where NODEID>2''   
			  EXEC (@STRQRY)  
			     
			  SELECT @I=1,@RC=COUNT(*) FROM #TAB WITH(NOLOCK)  
			  WHILE(@I<=@RC)  
			  BEGIN  
				SELECT @SNO=SID FROM #TAB WITH(NOLOCK) WHERE ID=@I  
				EXEC spCOM_DeleteCostCenter @DIMID ,@SNO ,1 ,@UserID ,@LangID     
				SET @I=@I+1  
			  END  
			  --
		 END  
		 ELSE IF(@COSTCENTERID=71)--MACHINE/RESOURCES  
		 BEGIN  
			  SET @STRQRY=''''  
			  Select @DIMID=Isnull(Value,0) From [COM_CostCenterPreferences] WITH(NOLOCK) Where CostCenterId=76 AND Name=''MachineDimension''  
			  Select @TABLENAME=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@DIMID  
			  TRUNCATE TABLE #TAB  
			  SET @STRQRY=''INSERT INTO #TAB SELECT ''+ CONVERT(VARCHAR,@DIMID) +'',NODEID FROM ''+ CONVERT(VARCHAR,@TABLENAME) +'' WITH(NOLOCK) where NODEID>2''   
			  EXEC (@STRQRY)  
			     
			  SELECT @I=1,@RC=COUNT(*) FROM #TAB WITH(NOLOCK)  
			  WHILE(@I<=@RC)  
			  BEGIN  
				SELECT @SNO=SID FROM #TAB WITH(NOLOCK) WHERE ID=@I  
				EXEC spCOM_DeleteCostCenter @DIMID ,@SNO ,1 ,@UserID ,@LangID     
				SET @I=@I+1  
			  END  
		 END  
		 ELSE --JOBS  
		 BEGIN  
			  --Deleting preference dimensions
			  SET @STRQRY=''''  
			  Select @DIMID=Isnull(Value,0) From [COM_CostCenterPreferences] WITH(NOLOCK) Where CostCenterId=76 AND Name=''JobDimension''  
			  Select @TABLENAME=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@DIMID   
			  TRUNCATE TABLE #TAB  
			  SET @STRQRY=''INSERT INTO #TAB SELECT ''+ CONVERT(VARCHAR,@DIMID) +'',NODEID FROM ''+ CONVERT(VARCHAR,@TABLENAME) +'' WITH(NOLOCK) where NODEID>2''   
			  EXEC (@STRQRY)  
			     
			  SELECT @I=1,@RC=COUNT(*) FROM #TAB WITH(NOLOCK)  
			  WHILE(@I<=@RC)  
			  BEGIN  
				SELECT @SNO=SID FROM #TAB WITH(NOLOCK) WHERE ID=@I  
				EXEC spCOM_DeleteCostCenter @DIMID ,@SNO ,1 ,@UserID ,@LangID     
				SET @I=@I+1  
			  END  
		 END  
	SET @J=@J+1   
	END  
	DROP TABLE #TAB'
	EXEC sp_executesql @SQL,N'@DIMENSIONLIST NVARCHAR(MAX),@UserID INT,@LangID INT',@DIMENSIONLIST,@UserID,@LangID 
END	
ELSE IF(@ModuleID=13)--PAYROLL
BEGIN 

	set @SQL='CREATE TABLE #TblDeleteRows(idid bigint identity(1,1), ID BIGINT,BatchID BIGINT,linkinv bigint,DOCID bigint)

	INSERT INTO  #TblDeleteRows	
	SELECT InvDocDetailsID,BatchID,LinkedInvDocDetailsID,DOCID FROM [INV_DocDetails] WITH(NOLOCK) 
	WHERE (COSTCENTERID IN (40055,40056,40057,40063,40062,40059,40054,40058,40067,40073,40071,40072,40065,40078,40076,40080,40060,40081) OR DocumentType=68) --68 Recording of Data
	
	DELETE T FROM COM_DocCCData t WITH(NOLOCK) join #TblDeleteRows a WITH(NOLOCK) on t.InvDocDetailsID=a.ID		

	DELETE T FROM [COM_DocNumData] t WITH(NOLOCK) join #TblDeleteRows a WITH(NOLOCK) on t.InvDocDetailsID=a.ID

	DELETE T FROM [PAY_DocNumData] t WITH(NOLOCK) join #TblDeleteRows a WITH(NOLOCK) on t.InvDocDetailsID=a.ID
	
	DELETE T FROM [COM_DocTextData] T WITH(NOLOCK) join #TblDeleteRows a WITH(NOLOCK) on t.InvDocDetailsID=a.ID
	
	DELETE FROM [COM_DocID] WHERE ID in (select DISTINCT DOCID from #TblDeleteRows WITH(NOLOCK))

	DELETE FROM [INV_DocDetails] t WITH(NOLOCK) join #TblDeleteRows a WITH(NOLOCK) on t.InvDocDetailsID=a.ID	
	
	DELETE FROM COM_CostCenterCodeDef WHERE (COSTCENTERID IN (40055,40056,40057,40063,40062,40059,40054,40058,40067,40073,40071,40072,40065,40078,40076,40080,40060,40081)
						OR CostCenterID IN(Select CostCenterID FROM ADM_DocumentTypes WITH(NOLOCK) WHERE DocumentType=68)) 	AND ISNULL(CODEPREFIX,'''')<>''''
 
	UPDATE COM_CostCenterCodeDef SET CurrentCodeNumber=0,CodeNumberLength=1 
	WHERE (COSTCENTERID IN (40055,40056,40057,40063,40062,40059,40054,40058,40067,40073,40071,40072,40065,40078,40076,40080,40060,40081) 
	OR CostCenterID IN(Select CostCenterID FROM ADM_DocumentTypes WITH(NOLOCK) WHERE DocumentType=68) ) AND ISNULL(CODEPREFIX,'''')=''''
	
	TRUNCATE TABLE PAY_EmployeeLeaveDetails
	TRUNCATE TABLE PAY_EmpMonthlyAdjustments
	TRUNCATE TABLE PAY_EmpMonthlyArrears
	TRUNCATE TABLE PAY_EmpMonthlyDues
	
	drop table #TblDeleteRows'
	EXEC(@SQL)

END
COMMIT TRANSACTION  
SET NOCOUNT OFF;    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=102 AND LanguageID=@LangID  
RETURN 1  
END TRY  
BEGIN CATCH    
PRINT ERROR_NUMBER()
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE   
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  

GO
