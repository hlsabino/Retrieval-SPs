USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetAPIMapFieldsDetail]
	@CostCenterID [int],
	@Mode [int],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON;
	
	IF @Mode>0
		SELECT * FROM [COM_APIFieldsMapping] WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID AND Mode=@Mode
	ELSE
		SELECT * FROM [COM_APIFieldsMapping] WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID 

SET NOCOUNT OFF;
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
