USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteAllNotifications]
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
SET NOCOUNT ON  
BEGIN TRY  
     
 --Declaration Section  
 DECLARE @HasAccess BIT 
 --User acces check  
 SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,7,4)  
 IF @HasAccess=0  
 BEGIN  
  RAISERROR('-105',16,1)  
 END  
    DELETE FROM COM_CCSchedules 
    DELETE FROM COM_Schedules 
    DELETE FROM COM_SchEvents 
    
COMMIT TRANSACTION  
SET NOCOUNT OFF;  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
 WHERE ErrorNumber=102 AND LanguageID=@LangID  
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
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH 
GO
