USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_SetReportDefaultProperties]
	@ReportID [bigint],
	@DefaultPrefrences [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50) = NULL,
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section
	DECLARE @TempGuid NVARCHAR(50),@HasAccess BIT

	--SP Required Parameters Check
	IF @ReportID<=0
	BEGIN
		RAISERROR('-100',16,1)
	END

	UPDATE ADM_RevenUReports
	SET DefaultPreferences = @DefaultPrefrences
--			,[GUID] = NEWID()  
--			,[ModifiedBy] = @UserName
--			,[ModifiedDate] = CONVERT(FLOAT,GETDATE())
	WHERE ReportID=@ReportID

COMMIT TRANSACTION  

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  

SET NOCOUNT OFF;  
RETURN @ReportID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM ADM_Reports WITH(nolock) WHERE NodeNo=@ReportID   
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
