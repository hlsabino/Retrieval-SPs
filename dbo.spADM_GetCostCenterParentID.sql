USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterParentID]
	@CostCenterColID [int] = 0,
	@WhereCondition [nvarchar](max) = null,
	@Type [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
SET NOCOUNT ON  

IF(@Type=0)
BEGIN
	select ColumnCostCenterID,ColumnCCListViewTypeID from Adm_CostCenterDef where CostCenterColID=@CostCenterColID
END
ELSE
BEGIN
	declare @TableName nvarchar(50),@SQL nvarchar(max)
	
	select @TableName=TableName from ADM_FEATURES where FeatureID=@CostCenterColID
	
	set @SQL='select * from '+@TableName+' where '+ @WhereCondition
	
	print @SQL
	exec(@SQL)
END
 
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
  
SET NOCOUNT OFF    
RETURN -999     
END CATCH    
  
GO
