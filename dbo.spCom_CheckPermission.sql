USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_CheckPermission]
	@COSTCENTERID [bigint],
	@TYPE [nvarchar](300),
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    


declare  @HasAccess bit,@FeatureActionID int

SET @HasAccess=0

 IF @TYPE='Create'
	SELECT @FeatureActionID=FEATUREACTIONTYPEID FROM ADM_FEATUREACTION with(nolock) WHERE FEATUREID=@COSTCENTERID AND NAME='Create'
	
 SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@COSTCENTERID,@FeatureActionID)  

 
 select @HasAccess
 
 COMMIT TRANSACTION     
SET NOCOUNT OFF;       
RETURN @HasAccess
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
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH      
GO
