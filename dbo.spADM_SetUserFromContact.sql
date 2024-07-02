USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetUserFromContact]
	@ContactID [int],
	@iVendorMax [int],
	@iCustomerMax [int],
	@CompanyGUID [nvarchar](50),
	@GUID [varchar](50),
	@UserName [nvarchar](50),
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1,
	@CompIndex [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
	SET NOCOUNT ON;
	print 't'
	--Declaration Section 
	DECLARE @CostCenterID INT,@AccountType INT,@Hasaccesss BIT,@pwd nvarchar(max),
			@LoginUserID nvarchar(max),
			@LoginRoleID int,@Email1 nvarchar(max),@Code nvarchar(max),
			@TempGuid NVARCHAR(50),@UpdateSql NVARCHAR(max),@ContactUserID INT,@TEMPDOJ DATETIME, @tStatus INT,@HistoryStatus NVARCHAR(300),@Audit NVARCHAR(100)
			
	--@LoginUserID=AccountCode+'_'+C.FirstName,
	select @AccountType=A.AccountTypeID,@LoginUserID=C.Email1, @pwd=AccountCode, @Code =C.FirstName , @LoginRoleID =C.RoleLookUpID
	,@UpdateSql='FirstName=N'''+ISNULL(C.FirstName,'')+''',MiddleName=N'''+ISNULL(C.MiddleName,'')+''',LastName=N'''+ISNULL(C.LastName,'')+''',Address1=N'''+ISNULL(C.Address1,'')+''',Address2=N'''+ISNULL(C.Address2,'')+''',Address3=N'''+ISNULL(C.Address3,'')+''',City='''+ISNULL(C.City,'')+''',State=N'''+ISNULL(C.State,'')+''',Zip=N'''+ISNULL(C.Zip,'')+''',Country=N'''+ISNULL(C.Country,'')+''',Phone1=N'''+ISNULL(C.Phone1,'')+''',Phone2=N'''+ISNULL(C.Phone2,'')+''',Fax=N'''+ISNULL(C.Fax,'')+''',Website=N'''',Description=N'''',Email1=N'''+ISNULL(C.Email1,'')+''','
	from COM_Contacts C with(nolock)
	join ACC_Accounts A with(nolock) on A.AccountID=C.FeaturePK and C.FeatureID=2
	where ContactID=@ContactID 
	
	
	if(@AccountType=6)--Vendor
	begin
		--SELECT @LoginRoleID=RoleID FROM ADM_PRoles with(nolock) WHERE RoleType=2
		
		if (select count(*) from (
			select U.UserID from adm_Proles R with(nolock)
			join ADM_UserRoleMap UR WITH(NOLOCK) on UR.RoleID=R.RoleID
			join ADM_Users U with(nolock) on U.UserID=UR.UserID
			where R.StatusID=434 and R.RoleType=2 and U.StatusID!=2
			group by U.UserID) AS T)>@iVendorMax-1
			
		begin
			set @LoginUserID='Max Vendors License('+convert(nvarchar,@iVendorMax)+') Exceeds.'
			RAISERROR(@LoginUserID,16,1)
		end
	end
	else if(@AccountType=7)--Customer
	begin
		SELECT @LoginRoleID=RoleID FROM ADM_PRoles with(nolock) WHERE RoleType=3
		if (select count(*) from (
			select U.UserID from adm_Proles R with(nolock)
			join ADM_UserRoleMap UR WITH(NOLOCK) on UR.RoleID=R.RoleID
			join ADM_Users U with(nolock) on U.UserID=UR.UserID
			where R.StatusID=434 and R.RoleType=3 and U.StatusID!=2
			group by U.UserID) AS T)>@iCustomerMax-1
		begin
			set @LoginUserID='Max Customers License('+convert(nvarchar,@iVendorMax)+') Exceeds.'
			RAISERROR(@LoginUserID,16,1)
		end
	end
	--select @AccountType, @LoginRoleID
	IF @LoginRoleID is null
	BEGIN
	--RAISERROR(-335,16,1)
		set @LoginUserID='Role not found'
		RAISERROR(@LoginUserID,16,1)
	END
	IF EXISTS(SELECT UserID FROM ADM_Users with(nolock) WHERE UserName = @LoginUserID)
	BEGIN
	--RAISERROR(-335,16,1)
		set @LoginUserID='User name already exists-"'+@LoginUserID+'"'
		RAISERROR(@LoginUserID,16,1)
	END
	
	EXEC @ContactUserID = spADM_SetUser 
		@SaveUserID=0 ,
		@RoleId=@LoginRoleID,
		@SaveUserName=@LoginUserID ,
		@Pwd=@Code ,@Status=1 ,
		@DefLanguage='1' ,@IsOffline = NULL,
		@Query=@UpdateSql ,
		@CompanyIndex=@CompIndex ,
		@CompanyUserXML='' ,
		@RestrictXML='<XML></XML>' ,
		@DefaultScreenXML='' ,
		@LicenseCnt=0 ,
		@LincenseXML='' ,
		@AttachmentsXML='',
		@RolesXML='',
		@CompanyGUID='admin' ,
		@GUID='GUID' ,
		@UserName=@UserName ,
		@UserID=1,
		@LoginRoleID=@RoleID ,
		@LangID=1
	
		if(@ContactUserID=-999)
			return @ContactUserID
		
	UPDATE ADM_Users SET IsNewLogin=1 WHERE UserName=@LoginUserID AND Password=@pwd

	update COM_Contacts set UserID=@ContactUserID
	where ContactID=@ContactID 

	COMMIT TRANSACTION
	--ROLLBACK TRANSACTION

	SELECT   ErrorMessage + ' ''' + ISNULL(@Code,'')+'''' AS ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK)       
	WHERE ErrorNumber=105 AND LanguageID=@LangID 
	
	SET NOCOUNT OFF; 
	RETURN @ContactID   
END TRY    
BEGIN CATCH  

if(@ContactUserID=-999)
			return @ContactUserID
		  
	--Return exception info Message,Number,ProcedureName,LineNumber    
	IF ERROR_NUMBER()=50000  
	BEGIN  
	IF ISNUMERIC(ERROR_MESSAGE())=1
	BEGIN
		    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK)   
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  	
	END
	ELSE
		SELECT ERROR_MESSAGE() ErrorMessage,-100 ErrorNumber
	
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
END CATCH
GO
