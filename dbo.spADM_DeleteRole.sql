USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteRole]
	@DataRoleID [int] = 0,
	@RoleID [bigint] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
SET NOCOUNT ON; 
 
	--Declaration Section  
	DECLARE @IsUserdefined BIT,@HasAccess BIT,@RowsDeleted int  

	--SP Required Parameters Check
	IF @DataRoleID=0
	BEGIN
		RAISERROR('-100',16,1)
	END

	--User access check 
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,6,4)

	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END

	--Fetch IsUserdefined role  
	SELECT @IsUserdefined = IsUserdefined  
	FROM ADM_PRoles WITH(NOLOCK) WHERE RoleID=@DataRoleID  

	IF @IsUserdefined = 0  
	BEGIN
		RAISERROR('-104',16,1)  
	END

	--Delete role
	SELECT @RowsDeleted = COUNT(UserName) FROM  dbo.ADM_UserRoleMap
	WHERE ROLEID = @DataRoleID AND STATUS = 1
	IF(@RowsDeleted =  0 )
	BEGIN
	BEGIN TRANSACTION
		UPDATE  dbo.ADM_PRoles 
		SET IsRoleDeleted=1--For Deleted
		WHERE RoleId=@DataRoleID
	COMMIT TRANSACTION 
	END	 


SET NOCOUNT OFF;  
RETURN 1 
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
