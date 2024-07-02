USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_DeleteRecurrence]
	@ScheduleID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
	
	IF (SELECT COUNT(*) FROM COM_SchEvents WITH(NOLOCK) WHERE ScheduleID=@ScheduleID AND StatusID=2)=0
	BEGIN
		DELETE FROM COM_UserSchedules 
		WHERE ScheduleID=@ScheduleID

		DELETE FROM COM_CCSchedules 
		WHERE ScheduleID=@ScheduleID

		DELETE FROM COM_Schedules 
		WHERE ScheduleID=@ScheduleID
		
		DELETE FROM COM_SchEvents
		WHERE ScheduleID=@ScheduleID
		
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=102 AND LanguageID=@LangID  
	END
	ELSE
	BEGIN
		UPDATE COM_Schedules 
		SET StatusID=2
		WHERE ScheduleID=@ScheduleID
		
		UPDATE COM_SchEvents 
		SET StatusID=3
		WHERE ScheduleID=@ScheduleID AND StatusID=1
		
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=108 AND LanguageID=@LangID  
	END
		
COMMIT TRANSACTION         
SET NOCOUNT OFF;

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
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
