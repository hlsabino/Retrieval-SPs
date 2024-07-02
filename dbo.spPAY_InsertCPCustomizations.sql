USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_InsertCPCustomizations]
	@CostCenterID [int],
	@ValueXML [nvarchar](max),
	@RoleID [nvarchar](max),
	@CreatedUserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
Begin Try
	DELETE FROM PAY_CustomizePayrollFields WHERE RoleID=@RoleID AND CostCenterID=@CostCenterID
	IF(ISNULL(@ValueXML,'')<>'')
	BEGIN
		INSERT INTO [PAY_CustomizePayrollFields]
			   ([CostCenterID]
			   ,[ValueXml]
			   ,[RoleID]
			   ,[CreatedUserID]
			   ,[ModifiedDate])
		 VALUES
			   (@CostCenterID
			   ,@ValueXML
			   ,@RoleID
			   ,@CreatedUserID
			   ,convert(datetime,getdate()))
	END
COMMIT TRANSACTION
IF(ISNULL(@ValueXML,'')<>'')
BEGIN
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=100 AND LanguageID=@LangID  
END
ELSE
BEGIN
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=102 AND LanguageID=@LangID  
END

SET NOCOUNT OFF;    
RETURN @CostCenterID    

End Try
Begin Catch
   IF ERROR_NUMBER()=50000  
	BEGIN  
		--SELECT * FROM PAY_CustomizePayrollFields WITH(NOLOCK) WHERE RoleID=@RoleID
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK)   
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END  
	ELSE IF ERROR_NUMBER()=547  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(NOLOCK)  
		WHERE ErrorNumber=-110 AND LanguageID=@LangID  
	END   
	ELSE  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
	END  
	ROLLBACK TRANSACTION  
	SET NOCOUNT OFF    
	RETURN -999     
End Catch
GO
