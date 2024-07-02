USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetUser]
	@SaveUserID [int] = 0,
	@RoleId [int],
	@SaveUserName [nvarchar](50),
	@Pwd [nvarchar](50),
	@Status [int],
	@DefLanguage [int],
	@IsOffline [bit],
	@TwoStepVerMode [nvarchar](50) = NULL,
	@Query [nvarchar](max),
	@CompanyIndex [int],
	@CompanyUserXML [nvarchar](max),
	@RestrictXML [nvarchar](max),
	@DefaultScreenXML [nvarchar](max) = null,
	@LicenseCnt [int] = 1,
	@LincenseXML [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@RolesXML [nvarchar](max) = null,
	@StatusXML [nvarchar](max) = null,
	@LocationID [int] = 0,
	@DivisionID [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LoginRoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY

	--Declaration Section
	DECLARE @TempGuid NVARCHAR(50),@HasAccess BIT,@ActionType INT,@IsEdit bit,@HistoryStatus NVARCHAR(300),@PrevRoleID INT
	DECLARE @XML XML, @RXML XML ,@Dt float,@PwdModifiedon float
	DECLARE @2CUserID INT, @2CCOMPANYID INT 
	DECLARE @UPDUSR  NVARCHAR(MAX) , @UPDUSRSRV NVARCHAR(MAX) 
	--SP Required Parameters Check
	IF @CompanyGUID IS NULL OR @CompanyGUID=''
	BEGIN
		RAISERROR('-100',16,1)
	END

	set @Dt=CONVERT(FLOAT,GETDATE())
	set @PwdModifiedon=@Dt
	--User acces check
	IF @SaveUserID=0
	BEGIN
		SET @ActionType =1
		SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,7,1)
		set @HistoryStatus='Add'
	END
	ELSE
	BEGIN
		SET @ActionType =3 
		SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,7,3)
		set @HistoryStatus='Update'
	END
	
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END
	
	IF EXISTS(SELECT UserID FROM ADM_Users with(nolock) WHERE UserName = @SaveUserName AND USERID <> @SaveUserID )
	BEGIN
		RAISERROR('-353',16,1)
	END
 
	IF @SaveUserID=0--------START INSERT RECORD-----------
	BEGIN
		SET @IsEdit=0
		IF EXISTS(SELECT UserID FROM [PACT2C].dbo.ADM_Users with(nolock) WHERE UserName=@SaveUserName)
		BEGIN
			RAISERROR('-403',16,1)
		END
	
		INSERT INTO ADM_Users(UserName,[Password],StatusID,DefaultLanguage,IsOffline,IsPassEncr,[GUID],
				CreatedBy,CreatedDate,DefaultScreenXML,LocationID,DivisionID,PwdModifiedon,TwoStepVerMode)
		VALUES(@SaveUserName,@Pwd,@Status,@DefLanguage,@IsOffline,1,NEWID(),
				@UserName,@Dt,@DefaultScreenXML,@LocationID,@DivisionID,@PwdModifiedon,@TwoStepVerMode)

		--To get inserted record primary key
		SET @SaveUserID=SCOPE_IDENTITY()

		INSERT INTO [PACT2C].dbo.ADM_Users(UserName,[Password],StatusID,DefaultLanguage,IsPassEncr,InstanceCount,
				IsUserdefined,CompanyGUID,[GUID],CreatedBy,CreatedDate)
		VALUES(@SaveUserName,@Pwd,@Status,@DefLanguage,1,@LicenseCnt,1,@CompanyGUID,NEWID(),@UserName,@Dt)
		SET @2CUserID=SCOPE_IDENTITY()
		
		--To Map User To License Site
		if @LincenseXML is not null and @LincenseXML!=''
		begin
			set @XML=@LincenseXML
			delete from [PACT2C].dbo.ADM_Sites where [Type]=2 and UserID=@2CUserID
			insert into [PACT2C].dbo.ADM_Sites([Type],SiteMap,UserID)
			select 2,X.value('@ID','int'),@2CUserID
			FROM @XML.nodes('/Lic/R') as Data(X) 	
		end

		INSERT INTO [ADM_UserRoleMap]([RoleID],[UserID],[UserName],[Status],[CreatedBy],[CreatedDate])
		VALUES(@RoleId,@SaveUserID,@SaveUserName,1,@UserName,@Dt)
		
		-- UPDATING THE CURRENT RECORD WITH DETAILS
		IF(@Query <> '' or @Query is not null)
		BEGIN
		 
			SET @UPDUSR = 'UPDATE ADM_Users
			SET  '+ @Query +' ModifiedBy = '''+@UserName+''' , ModifiedDate = '''+ convert(nvarchar(50),@Dt) +''' WHERE USERID = '+ CONVERT(NVARCHAR(10),@SaveUserID)
			EXEC (@UPDUSR)
			
			SET @UPDUSRSRV = 'UPDATE [PACT2C].dbo.ADM_Users
			SET  '+ @Query +' ModifiedBy = '''+@UserName+''' , ModifiedDate = '''+ convert(nvarchar(50),@Dt) +'''  WHERE USERID = '+ CONVERT(NVARCHAR(10),@2CUserID)
			EXEC (@UPDUSRSRV)
		END  
				
		SELECT @2CCOMPANYID = COMPANYID FROM [PACT2C].[dbo].[ADM_COMPANY] with(nolock)
		WHERE DBINDEX = @CompanyIndex
		
		INSERT INTO [PACT2C].[dbo].[ADM_UserCompanyMap]([UserID],[CompanyID],[IsDefault],[GUID],[CreatedBy],[CreatedDate])
		VALUES(@2CUserID,@2CCOMPANYID,1,NEWID(),@UserName,@Dt)
		
		-- INSERTING DEFAULT DIVISIONS FOR USERS
		IF(@CompanyUserXML <> '' AND @CompanyUserXML IS NOT NULL)  
		BEGIN   
			EXEC [spCOM_SetCCCCMap] 7,@SaveUserID,@CompanyUserXML,@UserName,@LangID
		END 
	END--------END INSERT RECORD-----------
	ELSE--------START UPDATE RECORD-----------
	BEGIN
		set @IsEdit=1
        DECLARE @USRNM NVARCHAR(50)

		SELECT @USRNM = USERNAME FROM ADM_Users with(nolock) WHERE USERID=@SaveUserID

		SELECT @2CUserID=UserID, @TempGuid=[GUID] FROM [PACT2C].dbo.ADM_Users WITH(NOLOCK)   
		WHERE USERNAME=@USRNM
		
		--To Map User To License Site
		if @LincenseXML is not null and @LincenseXML!=''
		begin
			set @XML=@LincenseXML
			delete from [PACT2C].dbo.ADM_Sites where [Type]=2 and UserID=@2CUserID
			insert into [PACT2C].dbo.ADM_Sites([Type],SiteMap,UserID)
			select 2,X.value('@ID','int'),@2CUserID
			FROM @XML.nodes('/Lic/R') as Data(X) 	
		end
		
		select @PwdModifiedon=PwdModifiedon from ADM_Users with(nolock) where USERNAME=@USRNM and Password=@Pwd
	 
		UPDATE [PACT2C].dbo.ADM_Users
		SET [Password]=@Pwd,
			StatusID=@Status,
			DefaultLanguage=@DefLanguage,IsPassEncr=1,InstanceCount=@LicenseCnt,
			ModifiedBy=@UserName,
			ModifiedDate=@Dt 
		WHERE USERNAME=@USRNM

		UPDATE ADM_Users
		SET [Password]=@Pwd,
			StatusID=@Status,
			DefaultLanguage=@DefLanguage,IsPassEncr=1,
			ModifiedBy=@UserName,PwdModifiedon=@PwdModifiedon,
			ModifiedDate=@Dt,DefaultScreenXML=@DefaultScreenXML
			,LocationID=@LocationID,DivisionID=@DivisionID
			,IsOffline=@IsOffline,TwoStepVerMode=@TwoStepVerMode
		WHERE  USERNAME = @USRNM
		
		select @PrevRoleID=RoleID from ADM_UserRoleMap with(nolock) where UserID=@SaveUserID

		UPDATE dbo.ADM_UserRoleMap
		SET RoleID=@RoleId,
		ModifiedBy=@UserName,
		ModifiedDate=@Dt
		WHERE  UserName = @USRNM and IsDefault=1
		
		IF(@Query <> '' or @Query is not null)
		BEGIN
			SET @UPDUSR = 'UPDATE ADM_Users
			SET  '+ @Query +' ModifiedBy = '''+@UserName+''' , ModifiedDate = '''+ convert(nvarchar(50),@Dt) +	
			''' WHERE USERNAME = '''+  @USRNM + '''' 
			EXEC (@UPDUSR)
	
			SET @UPDUSRSRV = 'UPDATE [PACT2C].dbo.ADM_Users
			SET  '+ @Query +' ModifiedBy = '''+@UserName+''' , ModifiedDate = '''+ convert(nvarchar(50),@Dt) +
			'''  WHERE USERNAME = ''' +  @USRNM  +'''' 
			EXEC (@UPDUSRSRV) 
		END  
		
		IF(@CompanyUserXML <> '' AND @CompanyUserXML IS NOT NULL)  
		BEGIN  
			EXEC [spCOM_SetCCCCMap] 7,@SaveUserID,@CompanyUserXML,@UserName,@LangID
		END 

	END--------END UPDATE RECORD-----------


	IF(@RestrictXML <>'' and  @RestrictXML is not null)
	BEGIN 
		SET @RXML=@RestrictXML
		delete from adm_featuretypevalues where Userid=@SaveUserID and RoleID is null
		
		INSERT INTO [ADM_FeatureTypeValues]
		   ([FeatureID]
		   ,[CostCenterID]
		   ,[FeatureTypeID]
		   ,[GUID] 
		   ,[CreatedBy]
		   ,[CreatedDate]
		   ,[RoleID] 
		   ,[UserID])
		SELECT     
			X.value('@CostCenterId','INT')    
			,X.value('@CostCenterId','INT')    
			,X.value('@FeatureTypeID','INT') 
			,newid()   
			,@UserName    
			,@Dt
			,null
			,@SaveUserID   
		FROM @RXML.nodes('/XML/Row') AS Data(X)    
	END

	--Insert Notifications
	EXEC spCOM_SetNotifEvent @ActionType,7,@SaveUserID,@CompanyGUID,@UserName,@UserID,-1
	
	--Inserts Multiple Attachments    
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '') 
		exec [spCOM_SetAttachments] @SaveUserID,7,@AttachmentsXML,@UserName,@Dt  
	
	IF (@RolesXML IS NOT NULL AND @RolesXML <> '')
	BEGIN
		SET @XML=@RolesXML
		INSERT INTO ADM_UserRoleMap([RoleID],[UserID],[UserName],[Status],IsDefault,FromDate,ToDate
		,[CreatedBy],[CreatedDate])
		SELECT X.value('@RoleID','int'),@SaveUserID,@SaveUserName,X.value('@StatusID','int'),0
		,convert(float,X.value('@FromDate','datetime')),convert(float,X.value('@ToDate','datetime'))
		,@UserName,@Dt
		FROM @XML.nodes('/XML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

		--If Action is MODIFY then update Attachments  
		UPDATE ADM_UserRoleMap  
		SET [Status]=X.value('@StatusID','int'),
		FromDate=convert(float,X.value('@FromDate','datetime')),
		ToDate=convert(float,X.value('@ToDate','datetime')),
		ModifiedBy=@UserName,  
		ModifiedDate=@Dt
		FROM ADM_UserRoleMap C   
		INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
		ON convert(INT,X.value('@MapID','INT'))=C.UserRoleMapID  
		WHERE X.value('@Action','NVARCHAR(500)')='EDIT'
	END
	
	IF (@StatusXML IS NOT NULL AND @StatusXML <> '')
	BEGIN
		SET @XML=@StatusXML
		INSERT INTO [COM_CostCenterStatusMap] ([CostCenterID],[NodeID],[Status],FromDate,ToDate,[CreatedBy],[CreatedDate])
		SELECT 7,@SaveUserID,X.value('@StatusID','int'),convert(float,X.value('@FromDate','datetime')),convert(float,X.value('@ToDate','datetime'))
		,@UserName,@Dt
		FROM @XML.nodes('/XML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

		--If Action is MODIFY then update Attachments  
		UPDATE [COM_CostCenterStatusMap]  
		SET [Status]=X.value('@StatusID','int'),
		FromDate=convert(float,X.value('@FromDate','datetime')),
		ToDate=convert(float,X.value('@ToDate','datetime')),
		ModifiedBy=@UserName,  
		ModifiedDate=@Dt
		FROM [COM_CostCenterStatusMap] C WITH(NOLOCK)  
		INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
		ON convert(INT,X.value('@MapID','INT'))=C.StatusMapID  
		WHERE X.value('@Action','NVARCHAR(500)')='EDIT'
	END
	
	--Insert into User history   
	insert into ADM_UsersHistory
	select UserID,UserName,Password,StatusID,DefaultLanguage,IsUserDeleted,FirstName,MiddleName,LastName
      ,Address1,Address2,Address3,City,State,Zip,Country,Phone1,Phone2,Fax,Email1,Email2,Website,GUID
      ,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate
      ,Email1Password,Email2Password,DefaultScreenXML,IsPassEncr,CalendarXML,@HistoryStatus,TwoStepVerMode from ADM_Users with(nolock) WHERE UserID=@SaveUserID
	
	--Audit User Role
	if @PrevRoleID is null or not exists (select RoleID from ADM_UserRoleMap with(nolock) WHERE UserID=@SaveUserID and RoleID=@PrevRoleID)
		insert into ADM_UserRoleMapHistory(UserRoleMapID,RoleID,UserID,UserName,Description,Status,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,IsDefault,FromDate,ToDate,HistoryStatus)
		select UserRoleMapID,RoleID,UserID,UserName,Description,Status,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,IsDefault,FromDate,ToDate,@HistoryStatus from ADM_UserRoleMap with(nolock) where UserRoleMapID=(select max(UserRoleMapID) from ADM_UserRoleMap with(nolock) WHERE UserID=@SaveUserID and IsDefault=1)
	--Audit User Mapped Role
	if(@RolesXML IS NOT NULL AND @RolesXML <> '')
	begin
		insert into ADM_UserRoleMapHistory(UserRoleMapID,RoleID,UserID,UserName,Description,Status,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,IsDefault,FromDate,ToDate,HistoryStatus)
		select UserRoleMapID,RoleID,UserID,UserName,Description,Status,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,IsDefault,FromDate,ToDate,@HistoryStatus 
		from ADM_UserRoleMap with(nolock) 
		where UserID=@SaveUserID and IsDefault=0
	end
	 
	SELECT * FROM [PACT2C].dbo.ADM_Users WITH(nolock) WHERE UserID=@SaveUserID

COMMIT TRANSACTION  

	IF @IsEdit=1
	BEGIN
		--changes made on dec 20 2012 by hafeez,to update password in other assinged companies
		DECLARE @TABLE TABLE(ID INT IDENTITY(1,1),COMPANY INT)
		INSERT INTO @TABLE
		SELECT DISTINCT COMPANYID FROM [PACT2C].dbo.ADM_UserCompanyMap with(nolock) WHERE USERID=@2CUserID
		AND CompanyID<>@CompanyIndex
		DECLARE @COUNT INT,@I INT,@COMPANY NVARCHAR(200),@COMINDEX INT,@SQL NVARCHAR(MAX)
		SELECT @COUNT=COUNT(*),@I=1 FROM @TABLE
		--SELECT * FROM @TABLE
		WHILE @I<=@COUNT
		BEGIN
			SELECT @COMINDEX=DBINDEX FROM [PACT2C].dbo.ADM_COMPANY with(nolock) WHERE COMPANYID=(
			SELECT COMPANY FROM @TABLE WHERE ID=@I)  
			SET @COMPANY='PACT2C'+ CONVERT(NVARCHAR(200),@COMINDEX)				 
			if exists(select * from sys.databases where name=@COMPANY)
			begin
				SET @SQL='USE '+@COMPANY+' 
if not exists(select * from ADM_Users with(nolock) WHERE USERNAME='''+@USRNM+''' and Password='''+@Pwd+''' and IsPassEncr=1)
	UPDATE ADM_Users SET Password='''+@Pwd+''',IsPassEncr=1 WHERE USERNAME=''' +  @USRNM  +'''' 	
				BEGIN TRY		
				--	print(@SQL) 
					EXEC (@SQL)
				END TRY
				BEGIN CATCH  
				END CATCH 
				SET @SQL=''
			end
			SET @I=@I+1
		END
	END


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
