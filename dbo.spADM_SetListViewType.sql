USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetListViewType]
	@COSTCENTERID [int],
	@StrXml [nvarchar](max),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
SET NOCOUNT ON    
BEGIN TRY    
	declare @XML xml,@cols nvarchar(max),@vals nvarchar(max),@sql nvarchar(max),@where nvarchar(max)
	set @XML=@StrXml
		
			DELETE FROM ADM_ListViewCCMap WHERE SourceCostCenterID=@CostCenterID

			INSERT INTO ADM_ListViewCCMap(SourceCostCenterID,CostCenterID,ListViewTypeID,UserID,RoleID)
			SELECT @CostCenterID,X.value('@CostCenterID','INT'),X.value('@ListViewTypeID','int'),@UserID,@RoleID
			FROM @XML.nodes('/XML/Type') as Data(X)  

SET NOCOUNT OFF;     
COMMIT TRANSACTION 
 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID        
SET NOCOUNT OFF;      
RETURN 1
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT * FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID=@COSTCENTERID     
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
 ROLLBACK TRANSACTION    
 SET NOCOUNT OFF      
 RETURN -999       
END CATCH
GO
