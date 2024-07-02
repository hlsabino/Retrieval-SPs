USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_ActiveDeActivateUser]
	@DataUserID [bigint],
	@DataUserName [nvarchar](50),
	@Type [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY
		
		--Declaration Section
		DECLARE @HasAccess BIT,@RowsDeleted INT, @IsUserdefined BIT
 
		--SP Required Parameters Check
		IF @DataUserID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,7,4)
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		--Fetch IsUserdefined user.
		SELECT @IsUserdefined = IsUserdefined
		FROM [PACT2C].dbo.ADM_Users WITH(NOLOCK) WHERE UserName=@DataUserName


		IF @IsUserdefined IS NULL
		BEGIN
			RAISERROR('-100',16,1)	
		END
		ELSE IF @IsUserdefined = 0
			RAISERROR('-102',16,1)	
		 
	 if(@Type=1)
	 BEGIN
		if exists(select * from ADM_Users where UserID=@DataUserID and UserName = @DataUserName and StatusID=1)
		BEGIN
			RAISERROR('-132',16,1)	
		END
		
		UPDATE [PACT2C].dbo.ADM_Users 
		SET StatusID=1
		WHERE UserID=@DataUserID 
		and UserName = @DataUserName	
		
		
		UPDATE ADM_Users 
		SET StatusID=1
		WHERE UserID=@DataUserID 
		and UserName = @DataUserName
		
		UPDATE  ADM_UserRoleMap
		SET STATUS = 1
		WHERE UserID=@DataUserID 
		and UserName = @DataUserName
	 END
	 
	 if(@Type=2)
	 BEGIN
		if exists(select * from ADM_Users where UserID=@DataUserID and UserName = @DataUserName and StatusID=2)
		BEGIN
			RAISERROR('-133',16,1)	
		END
		
		UPDATE [PACT2C].dbo.ADM_Users 
		SET StatusID=2
		WHERE UserID=@DataUserID 
		and UserName = @DataUserName
		
		UPDATE ADM_Users 
		SET StatusID=2
		WHERE UserID=@DataUserID 
		and UserName = @DataUserName
		
		UPDATE  ADM_UserRoleMap
		SET STATUS = 2
		WHERE UserID=@DataUserID 
		and UserName = @DataUserName
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
