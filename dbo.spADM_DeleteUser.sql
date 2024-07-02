USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteUser]
	@DataUserID [bigint],
	@DataUserName [nvarchar](50),
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY
		
		--Declaration Section
		DECLARE @HasAccess BIT,@RowsDeleted INT, @IsUserdefined BIT
		DECLARE @Table TABLE(ID INT IDENTITY(1,1),DBName NVARCHAR(50))
		DECLARE @I INT,@Cnt int,@DBName NVARCHAR(50),@SQL NVARCHAR(500)
 
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
		FROM [PACT2C].dbo.ADM_Users WITH(NOLOCK) WHERE UserName =@DataUserName

 

		IF @IsUserdefined IS NULL
		BEGIN
			RAISERROR('-100',16,1)	
		END
		ELSE IF @IsUserdefined = 0
			RAISERROR('-102',16,1)	
		 
	 
		--Change the status to deleted
		UPDATE [PACT2C].dbo.ADM_Users 
		SET StatusID=2--For Deleted
		WHERE UserName = @DataUserName

		UPDATE  dbo.ADM_Users 
		SET IsUserDeleted=1, statusid=10--For Deleted
		WHERE UserID=@DataUserID 
		and UserName = @DataUserName
		
       -- Added by Mustafeez on 5th Jan
		UPDATE  ADM_UserRoleMap
		SET STATUS = 2
		WHERE UserID=@DataUserID 
		and UserName = @DataUserName


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
