USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteArtifactData]
	@ArtifactID [bigint] = 0,
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;        
		--Declaration Section  
		DECLARE @HasAccess BIT,@FeatureID BIGINT

		SELECT @FeatureID=ISNULL(FeatureID,0) FROM COM_Artifacts WITH(NOLOCK) WHERE ArtfID=@ArtifactID 
		IF(@FeatureID=0)        
		BEGIN     
			RAISERROR('-100',16,1)       
		END        

		----User access check  
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,847)  
		

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  

		DELETE FROM COM_Artifacts WHERE ArtfID=@ArtifactID 
           
COMMIT TRANSACTION   
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID 
          
RETURN @ArtifactID        
END TRY  
BEGIN CATCH    
		--Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT ArtfID,Name,GUID FROM COM_Artifacts WITH(NOLOCK) WHERE ArtfID=@ArtifactID 
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
