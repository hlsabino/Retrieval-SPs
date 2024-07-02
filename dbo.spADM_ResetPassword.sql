USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_ResetPassword]
	@SaveUserID [bigint] = 0,
	@SaveUserName [nvarchar](50),
	@Pwd [nvarchar](50),
	@CompanyIndex [int],
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY
	--select  @SaveUserID,@RoleId,@SaveUserName,@Pwd,@Status,@DefLanguage,@Query,@CompanyIndex,@CompanyGUID,@GUID,@UserName,@UserID,@LangID
		--Declaration Section
		DECLARE @TempGuid NVARCHAR(50),@HasAccess BIT
		DECLARE @XML XML, @RXML XML  
		DECLARE @2CUserID BIGINT, @2CCOMPANYID BIGINT 
		DECLARE @UPDUSR  NVARCHAR(MAX)  , @UPDUSRSRV NVARCHAR(MAX) 

		IF EXISTS(SELECT UserID FROM ADM_Users with(nolock) WHERE UserName = @SaveUserName AND USERID <> @SaveUserID )
		BEGIN
				RAISERROR('-353',16,1)
		END
		 
		BEGIN
			DECLARE @USRNM NVARCHAR(50)
			SELECT @USRNM = USERNAME FROM ADM_Users with(nolock) WHERE USERID = @SaveUserID
			SELECT @2CUserID=UserID FROM [PACT2C].dbo.ADM_Users WITH(NOLOCK)   
			WHERE USERNAME=@USRNM
 		 
			UPDATE [PACT2C].dbo.ADM_Users
			SET Password=@Pwd,IsPassEncr=1,
				ModifiedBy=@UserName,
				ModifiedDate=CONVERT(FLOAT,GETDATE())
			WHERE USERNAME = @USRNM   
 
			UPDATE ADM_Users
			SET Password=@Pwd,IsPassEncr=1,PwdModifiedOn=CONVERT(FLOAT,GETDATE()),
				ModifiedBy=@UserName,				
				ModifiedDate=CONVERT(FLOAT,GETDATE()),IsNewLogin =0
			WHERE  USERNAME = @USRNM
			
		  
		END--------END UPDATE RECORD-----------
		 
COMMIT TRANSACTION  

--changes made on dec 20 2012 by hafeez,to update password in other assinged companies
DECLARE @TABLE TABLE(ID INT IDENTITY(1,1),COMPANY BIGINT)
INSERT INTO @TABLE
SELECT DISTINCT COMPANYID FROM [PACT2C].dbo.ADM_UserCompanyMap with(nolock) WHERE USERID=@2CUserID
AND CompanyID<>@CompanyIndex
DECLARE @COUNT INT,@I INT,@COMPANY NVARCHAR(200),@COMINDEX BIGINT,@SQL NVARCHAR(MAX)
SELECT @COUNT=COUNT(*),@I=1 FROM @TABLE
WHILE @I<=@COUNT
BEGIN
	SELECT @COMINDEX=DBINDEX FROM [PACT2C].dbo.ADM_COMPANY with(nolock) WHERE COMPANYID =(
	SELECT COMPANY FROM @TABLE WHERE ID=@I) 
	SET @COMPANY='PACT2C'+ CONVERT(NVARCHAR(200),@COMINDEX)				 
	SET @SQL='UPDATE '+@COMPANY+'.dbo.ADM_Users SET Password='''+@Pwd+''',IsPassEncr=1,PwdModifiedOn=CONVERT(FLOAT,GETDATE()) WHERE USERNAME = ''' +  @USRNM  +'''' 	
	BEGIN TRY		
		--print(@SQL) 
		EXEC (@SQL)
	END TRY
	BEGIN CATCH  
	END CATCH 
	SET @SQL=''
SET @I=@I+1
END


SELECT * FROM [PACT2C].dbo.ADM_Users WITH(nolock) WHERE USERNAME= @SaveUserName
SET NOCOUNT OFF;  
RETURN @SaveUserID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM [PACT2C].dbo.ADM_Users WITH(nolock) WHERE UserID=@SaveUserID
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
