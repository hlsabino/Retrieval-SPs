USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetWorkFlow]
	@WorkFlowId [int] = null,
	@UserID [bigint],
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit

		--SP Required Parameters Check
		IF (@WorkFlowId < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END


		--User acces check
		--SET @HasAccess=dbo.fnCOM_IsUserActionAllowed(@UserID,2,2)
		
		--IF @HasAccess=0
		--BEGIN
		--	RAISERROR('-105',16,1)
		--END


		SELECT  * FROM COM_WorkFlow WITH(nolock) WHERE WorkFlowID=@WorkFlowId
		order by LevelID
 
 

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
