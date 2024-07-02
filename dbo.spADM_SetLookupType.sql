USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetLookupType]
	@NodeID [bigint],
	@Name [nvarchar](150),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@ResourceID BIGINT,@ListViewID BIGINT

		--SP Required Parameters Check
		IF @Name IS NULL OR @Name=''
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		--User acces check
		IF @NodeID=0
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,44,1)
		END
		ELSE
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,44,3)
		END
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		IF (@NodeID=0)
		BEGIN
			IF EXISTS (SELECT NodeID FROM COM_LookupTypes WITH(nolock) WHERE LookupName=@Name) 
			BEGIN  
				RAISERROR('-112',16,1)  
			END
			
			SELECT @NodeID=MAX(NodeID)+1 FROM COM_LookupTypes
			
			IF @NodeID<1000
				SET @NodeID=1001
		
			SELECT @ResourceID=MAX(ResourceID)+1 FROM COM_LanguageResources
			INSERT INTO COM_LanguageResources(ResourceID,ResourceName,LanguageID,LanguageName,ResourceData,GUID,CreatedBy,CreatedDate)
			SELECT @ResourceID,@Name,LanguageID,Name,@Name,NEWID(),@UserName,convert(float,getdate()) FROM ADM_Laguages

			INSERT INTO COM_LookupTypes(NodeID,LookupName,ResourceID,Module,CompanyGUID,GUID,CreatedBy,CreatedDate)  
			VALUES(@NodeID,@Name,@ResourceID,'USER',@CompanyGUID,NEWID(),@UserName,convert(float,getdate()))
			
			INSERT INTO [ADM_ListView] ([ListViewName],[CostCenterID],[FeatureID],[ListViewTypeID],[SearchFilter],[FilterXML],[RoleID],[UserID],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[SearchOption],[SearchOldValue])
			VALUES(@Name,44,44,@NodeID,'LookupType='+CONVERT(NVARCHAR,@NodeID),'',1,1,0,'830b4366-ab3c-4150-aefe-f5acaddc7089','48155F23-F5C8-4D23-967F-4CA0A6D8F817',NULL,'admin',2,'admin',4,1,1)
			SET @ListViewID=SCOPE_IDENTITY()
			
			INSERT INTO [ADM_ListViewColumns] ([ListViewID],[CostCenterColID],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])
			VALUES(@ListViewID,21359,1,200,'Description','ADMIN',4,'admin',4)
			
			declare @FAID bigint
			insert into adm_featureaction(Name,ResourceID,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)
			select @Name,@ResourceID,44,100+@NodeID*5,1,1,1,'ADMIN'
			SET @FAID=SCOPE_IDENTITY()
			
			insert into adm_featureactionrolemap(RoleID,FeatureActionID,Status,CreatedBy,CreatedDate)
			select distinct RoleID,@FAID,1,@UserName,4  from adm_UserRoleMap where UserID=@UserID or RoleID=1
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT NodeID FROM COM_LookupTypes WITH(nolock) WHERE LookupName=@Name AND NodeID<>@NodeID) 
			BEGIN  
				RAISERROR('-112',16,1)  
			END
			
			--SELECT @ResourceID=ResourceID FROM COM_Lookup WHERE NodeID=@NodeID
			
			--UPDATE COM_Lookup  
			--SET Name = @Name,Status = @StatusID,
			--	ModifiedBy=@UserName,ModifiedDate=CONVERT(float,GETDATE())
			--WHERE NodeID=@NodeID

			--DECLARE @COUNT BIGINT
			--SELECT @COUNT=COUNT(*) FROM COM_LanguageResources WHERE ResourceID=@ResourceID

			--IF @COUNT<5
			--BEGIN
			--	UPDATE COM_LanguageResources
			--	SET ResourceName=@Name,ResourceData=@Name
			--	WHERE ResourceID=@ResourceID AND LanguageID = @LangID
			--END
		END
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
SELECT * FROM COM_Lookup WITH(nolock) WHERE NodeID=@NodeID  
SET NOCOUNT OFF;  
RETURN @NodeID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM COM_Lookup WITH(nolock) WHERE NodeID=@NodeID  
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
