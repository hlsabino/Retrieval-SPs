USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetLookup]
	@LookType [int],
	@NodeID [bigint],
	@Code [nvarchar](150) = NULL,
	@Name [nvarchar](150),
	@AliasName [nvarchar](500) = NULL,
	@StatusID [smallint],
	@IsDefault [int] = 0,
	@Data [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@ResourceID BIGINT

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
		
		IF(@Code='')
			SET @Code=@Name
		
		IF(@AliasName='')
			SET @AliasName=@Name
		
		IF @IsDefault=1 and @Data is not null and @Data<>''
		BEGIN
		
			DECLARE @XML XML
			SET @XML=@Data
			
				UPDATE COM_Lookup  
				SET isDefault=X.value('@Default','bit')
				FROM COM_Lookup C   
				INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
				ON convert(bigint,X.value('@NodeID','bigint'))= C.NodeID  
				 set @NodeID=1
		END
		ELSE IF (@NodeID=0)
		BEGIN
			IF EXISTS (SELECT NodeID FROM COM_Lookup WITH(nolock) WHERE LookupType=@LookType AND Name=@Name) 
			BEGIN  
				RAISERROR('-112',16,1)  
			END
		
			SELECT @ResourceID=MAX(ResourceID)+1 FROM COM_LanguageResources

			INSERT INTO COM_LanguageResources(ResourceID,ResourceName,LanguageID,LanguageName,ResourceData)
			SELECT @ResourceID,@Name,LanguageID,Name,@Name FROM ADM_Laguages

			INSERT INTO COM_Lookup(LookupType,Code,Name,AliasName,ResourceID,Status,CompanyGUID,GUID,CreatedBy,CreatedDate,isDefault)  
			VALUES(@LookType,@Code,@Name,@AliasName,@ResourceID,@StatusID,@CompanyGUID,NEWID(),@UserName,convert(float,getdate()),@IsDefault)  

			SET @NodeID=SCOPE_IDENTITY()
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT NodeID FROM COM_Lookup WITH(nolock) WHERE LookupType=@LookType AND Name=@Name AND NodeID<>@NodeID) 
			BEGIN  
				RAISERROR('-112',16,1)  
			END
			
			SELECT @ResourceID=ResourceID FROM COM_Lookup WHERE NodeID=@NodeID
			
			UPDATE COM_Lookup  
			SET Code = @Code,Name = @Name,AliasName = @AliasName,Status = @StatusID,
				ModifiedBy=@UserName,ModifiedDate=CONVERT(float,GETDATE())
			WHERE NodeID=@NodeID

			DECLARE @COUNT BIGINT
			SELECT @COUNT=COUNT(*) FROM COM_LanguageResources WHERE ResourceID=@ResourceID

			IF @COUNT<5
			BEGIN
				UPDATE COM_LanguageResources
				SET ResourceName=@Name,ResourceData=@Name
				WHERE ResourceID=@ResourceID AND LanguageID = @LangID
			END
		END

COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
--SELECT * FROM COM_Lookup WITH(nolock) WHERE NodeID=@NodeID  
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
--[spADM_SetLookup] 0,0,'lokkup',0,1,'<XML><Row Default=''0'' NodeID=''17'' /><Row Default=''0'' NodeID=''18'' /><Row Default=''1'' NodeID=''19'' /><Row Default=''0'' NodeID=''20'' /><Row Default=''0'' NodeID=''34'' /><Row Default=''0'' NodeID=''35'' /></XML>',
--'830b4366-ab3c-4150-aefe-f5acaddc7089','admin',1,1
GO
