USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteAlertData]
	@AlertID [bigint] = 0,
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;        
		--Declaration Section  
		DECLARE @HasAccess BIT,@FeatureID BIGINT,@AttachmentID INT

		SELECT @FeatureID=ISNULL(FeatureID,0),@AttachmentID=ISNULL(AttachmentID,0) FROM COM_Alerts WITH(NOLOCK) WHERE AlertID=@AlertID  
		IF(@FeatureID=0)        
		BEGIN     
			RAISERROR('-100',16,1)       
		END        

		----User access check  
		IF(@FeatureID=94)
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,843)  
		END
		ELSE IF(@FEATUREID=92)
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,839)  
		END

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  

		IF(@AttachmentID>0)
			DELETE FROM COM_Files WHERE FileID=@AttachmentID      
			
		DELETE FROM COM_Alerts WHERE AlertID=@AlertID      
		
           
COMMIT TRANSACTION   
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID 
          
RETURN @AlertID        
END TRY  
BEGIN CATCH    
		--Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT AlertID,AlertMessage,GUID FROM COM_Alerts WITH(NOLOCK) WHERE AlertID=@AlertID   
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
