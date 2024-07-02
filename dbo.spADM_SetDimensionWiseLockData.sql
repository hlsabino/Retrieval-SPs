USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDimensionWiseLockData]
	@MODE [int],
	@DimensionWiseLock [nvarchar](max),
	@RoleID [int] = 1,
	@UserName [nvarchar](50),
	@UserID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY    
	SET NOCOUNT ON;    
	declare @XML xml,@NodeID INT=0,@SQL NVARCHAR(MAX)
	IF (@MODE=0)
	BEGIN
		set @xml=@DimensionWiseLock

		if(@DimensionWiseLock is not null and @DimensionWiseLock <> '')
		begin
			
			set @SQL='INSERT INTO [dbo].[ADM_DimensionWiseLockData]
			   ([FromDate]
			   ,[ToDate]
			   ,[AccountID]
			   ,[ProductID]
			   ,[CompanyGUID]
			   ,[GUID]
			   ,[Description]
			   ,[CreatedBy]
			   ,[CreatedDate]
			   ,[DocumentID]
			   ,[isEnable]'
			
			select @SQL=@SQL+',['+name+']' 
			from sys.columns 
			where object_id=object_id('ADM_DimensionWiseLockData') and name LIKE 'ccnid%'
				
			SET @SQL=@SQL+')
			SELECT Convert(float,X.value(''@FromDate'',''Datetime''))
		   ,Convert(float,X.value(''@ToDate'',''Datetime''))
		   ,isnull(X.value(''@AccountID'',''INT''),0)
		   ,isnull(X.value(''@ProductID'',''INT''),0)
			,NEWID()
		   ,NEWID()
		   ,NULL
		   ,'''+@UserName+'''
		   ,convert(float,getdate())
		   ,isnull(X.value(''@DocumentID'',''INT''),1)
		   ,isnull(X.value(''@isEnable'',''bit''),1)'
			
			select @SQL=@SQL+',ISNULL(X.value(''@'+name+''',''INT''),0)' 
			from sys.columns 
			where object_id=object_id('ADM_DimensionWiseLockData') and name LIKE 'ccnid%'
					
			SET @SQL=@SQL+' from @xml.nodes(''/DimensionWiseLockXML/Rows'') as data(x)
				 SET @NodeID=@@IDENTITY  '
		
			EXEC sp_executesql @SQL,N'@XML XML,@NodeID INT OUTPUT',@XML,@NodeID OUTPUT
		 
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
			WHERE ErrorNumber=100 AND LanguageID=1 
		end
	END
	ELSE IF(@MODE=1)
	BEGIN
		
		SET @SQL='SELECT *,convert(datetime,FromDate) FromDate_Key,convert(datetime,ToDate) ToDate_Key 
		FROM ADM_DimensionWiseLockData WITH(NOLOCK)'
		
		IF @RoleID<>1
		BEGIN
			SET @SQL=@SQL+' WHERE (DocumentID=1 OR DocumentID IN (SELECT DISTINCT FA.FeatureID FROM ADM_FeatureAction FA WITH(NOLOCK)
						LEFT JOIN ADM_FeatureActionRoleMap FAM WITH(NOLOCK) ON FAM.FeatureActionID=FA.FeatureActionID
						WHERE (FA.FeatureID BETWEEN 40001 AND 49999 OR FA.FeatureID IN (95,103,104,129)) AND FA.FeatureActionTypeID IN (1,2,3,4) AND FAM.RoleID='+CONVERT(NVARCHAR,@RoleID)+'))'
			
			DECLARE @ISDIMWISE BIT
			SELECT @ISDIMWISE=Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='EnableDivisionWise'
			IF @ISDIMWISE=1
				SET @SQL=@SQL+' AND (CCNID1 IN (0,1) OR CCNID1 IN (SELECT DISTINCT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK)
						 WHERE ((ParentCostCenterID=6 AND ParentNodeID='+CONVERT(NVARCHAR,@RoleID)+') OR (ParentCostCenterID=7 AND ParentNodeID='+CONVERT(NVARCHAR,@UserID)+')) 
						 AND CostCenterID=50001) OR 1 IN (SELECT DISTINCT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK)
						WHERE ((ParentCostCenterID=6 AND ParentNodeID=2) OR (ParentCostCenterID=7 AND ParentNodeID=10011)) 
						AND CostCenterID=50001))'
			
			SELECT @ISDIMWISE=Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='EnableLocationWise'
			IF @ISDIMWISE=1
				SET @SQL=@SQL+' AND (CCNID2 IN (0,1) OR CCNID2 IN (SELECT DISTINCT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK)
						 WHERE ((ParentCostCenterID=6 AND ParentNodeID='+CONVERT(NVARCHAR,@RoleID)+') OR (ParentCostCenterID=7 AND ParentNodeID='+CONVERT(NVARCHAR,@UserID)+')) 
						 AND CostCenterID=50002) OR 1 IN (SELECT DISTINCT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK)
						WHERE ((ParentCostCenterID=6 AND ParentNodeID=2) OR (ParentCostCenterID=7 AND ParentNodeID=10011)) 
						AND CostCenterID=50002))'
		END
		SET @SQL=@SQL+' ORDER BY NodeID'
		PRINT(@SQL)
		EXEC(@SQL)
		
		SELECT CostCenterID,DocumentName FROM dbo.ADM_DocumentTypes WITH(NOLOCK)
		WHERE CostCenterID IN (SELECT DISTINCT FA.FeatureID FROM ADM_FeatureAction FA WITH(NOLOCK)
					LEFT JOIN ADM_FeatureActionRoleMap FAM WITH(NOLOCK) ON FAM.FeatureActionID=FA.FeatureActionID
					WHERE FA.FeatureID BETWEEN 40001 AND 49999 AND FA.FeatureActionTypeID IN (1,2,3,4) AND FAM.RoleID=@RoleID)
		UNION ALL
		SELECT FeatureID CostCenterID,Name DocumentName FROM dbo.ADM_Features WITH(NOLOCK)
		WHERE FeatureID IN (SELECT DISTINCT FA.FeatureID FROM ADM_FeatureAction FA WITH(NOLOCK)
					LEFT JOIN ADM_FeatureActionRoleMap FAM WITH(NOLOCK) ON FAM.FeatureActionID=FA.FeatureActionID
					WHERE FA.FeatureID IN (95,103,104,129) AND FA.FeatureActionTypeID IN (1,2,3,4) AND FAM.RoleID=@RoleID)
					ORDER BY DocumentName	
	END
	IF (@MODE=2)
	BEGIN
		set @xml=@DimensionWiseLock

		if(@DimensionWiseLock is not null and @DimensionWiseLock <> '')
		begin
			
			SET @SQL ='UPDATE [ADM_DimensionWiseLockData] SET
			   [FromDate]=Convert(float,X.value(''@FromDate'',''Datetime''))
			   ,[ToDate]=Convert(float,X.value(''@ToDate'',''Datetime''))
			   ,[AccountID]=isnull(X.value(''@AccountID'',''INT''),0)
			   ,[ProductID]=isnull(X.value(''@ProductID'',''INT''),0)
			   ,[CompanyGUID]=NEWID()
			   ,[GUID]=NEWID()
			   ,[Description]=NULL
			   ,[ModifiedBy]=@UserName
			   ,[ModifiedDate]=convert(float,getdate())
			   ,[DocumentID]=isnull(X.value(''@DocumentID'',''INT''),1)
			   ,[isEnable]=isnull(X.value(''@isEnable'',''bit''),1)'
				   
			select @SQL=@SQL+',['+name+']=ISNULL(X.value(''@'+name+''',''INT''),0)' 
			from sys.columns 
			where object_id=object_id('ADM_DimensionWiseLockData') and name LIKE 'ccnid%'
				
			SET @SQL=@SQL+' from @xml.nodes(''/DimensionWiseLockXML/Rows'') as data(x)
			WHERE NodeID=isnull(X.value(''@NodeID'',''INT''),0)'
			
			EXEC sp_executesql @SQL,N'@XML XML,@UserName nvarchar(50)',@XML,@UserName
			
			SELECT @NodeID=isnull(X.value('@NodeID','INT'),0)  from @xml.nodes('/DimensionWiseLockXML/Rows') as data(x) 
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
			WHERE ErrorNumber=100 AND LanguageID=1 
		end
	END
	ELSE IF(@MODE=3)
	BEGIN
		set @NodeID=CONVERT(INT,@DimensionWiseLock)
		DELETE FROM ADM_DimensionWiseLockData WHERE NodeID=@NodeID
		
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
		WHERE ErrorNumber=102 AND LanguageID=1 	
	END
	
	if(@MODE<>1)
		exec [spADM_SetPriceTaxUsedCC] 3,0,1
		
	COMMIT TRANSACTION  
	SET NOCOUNT OFF;    
	RETURN @NodeID 
END TRY  
BEGIN CATCH    
	--Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1  
	END  
	ELSE IF ERROR_NUMBER()=547  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)  
		WHERE ErrorNumber=-110 AND LanguageID=1  
	END  
	ELSE   
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
		FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=-999 AND LanguageID=1  
	END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
