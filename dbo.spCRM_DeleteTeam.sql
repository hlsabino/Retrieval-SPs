USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_DeleteTeam]
	@NodeID [bigint] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
	--Declaration Section
	DECLARE @HasAccess bit,@RowsDeleted bigint,@lft bigint,@rgt bigint,@Width bigint

	--SP Required Parameters Check
	if(@NodeID=0)
	BEGIN
		RAISERROR('-100',16,1)
	END

	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,91,4)

	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END

	SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
	FROM CRM_Teams WITH(NOLOCK) WHERE NodeID=@NodeID 

	DELETE FROM CRM_Teams WHERE lft >= @lft AND rgt <= @rgt

	UPDATE CRM_Teams SET rgt = rgt - @Width WHERE rgt > @rgt;
	UPDATE CRM_Teams SET lft = lft - @Width WHERE lft > @rgt;

    SET @RowsDeleted=@@rowcount
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN @RowsDeleted
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
