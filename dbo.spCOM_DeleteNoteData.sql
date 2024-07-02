USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteNoteData]
	@NoteID [bigint] = 0,
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;        
		--Declaration Section  
		DECLARE @HasAccess BIT,@FeatureID BIGINT

		SELECT @FeatureID=ISNULL(FeatureID,0) FROM COM_Notes WITH(NOLOCK) WHERE NoteID=@NoteID  
		IF(@FeatureID=0)        
		BEGIN     
			RAISERROR('-100',16,1)       
		END        

		--User access check  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,11)  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  

		DELETE FROM COM_Notes WHERE NoteID=@NoteID        
           
COMMIT TRANSACTION   
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID 
          
RETURN @NoteID        
END TRY  
BEGIN CATCH    
		--Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT NoteID,Note,GUID FROM COM_Notes WITH(NOLOCK) WHERE NoteID=@NoteID      
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
