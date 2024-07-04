USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterDetailsWithoutGroup]
	@CostCenterID [int] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
    
BEGIN TRY    
SET NOCOUNT ON;  
  
     
   --Declaration Section  
   DECLARE @HasAccess BIT,@Table nvarchar(50),@SQL nvarchar(max)   
  
   --SP Required Parameters Check  
   IF @CostCenterID=0   
   BEGIN  
    RAISERROR('-100',16,1)  
   END  
  

   --To get costcenter table name  
	SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterID  
  
   SET @SQL='SELECT  NodeID,Name FROM '+@Table+' WITH(nolock) where isgroup <>1  '  
  
   EXEC(@SQL)     
  
  
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
