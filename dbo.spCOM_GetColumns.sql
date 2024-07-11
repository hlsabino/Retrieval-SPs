USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetColumns]
	@CCID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON;    
		--Declaration Section  
		
		SELECT c.CostCenterColID,SysColumnName,r.ResourceData UserColumnName,ISNULL(IsMandatory,0)IsMandatory,ISNULL(IsEditable,0)IsEditable,c.ColumnDataType 
		FROM ADM_CostCenterDef c WITH(NOLOCK) 
		join COM_LanguageResources r WITH(NOLOCK)  on c.ResourceID=r.ResourceID
		WHERE CostCenterID=@CCID and r.LanguageID=@LangID and c.IsColumnInUse=1
		
		  
    
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
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine  
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
		END  
   
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH   

GO
