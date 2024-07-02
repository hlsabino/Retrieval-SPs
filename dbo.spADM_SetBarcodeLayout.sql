USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetBarcodeLayout]
	@LayoutID [bigint],
	@DocumentID [int],
	@LayoutName [nvarchar](50),
	@BarcodeXML [nvarchar](max),
	@BodyXML [nvarchar](max),
	@DefinitionXML [nvarchar](max),
	@SelectedColsQuery [nvarchar](max),
	@JoinsQuery [nvarchar](max),
	@ISDOS [bit],
	@DOSText [nvarchar](max) = null,
	@IsSalePrint [bit],
	@Type [int],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  DECLARE @TempGuid NVARCHAR(50),@HasAccess BIT ,@ID INT 
  
  --SP Required Parameters Check  
  IF @LayoutName='' OR @LayoutName IS NULL  
  BEGIN  
   RAISERROR('-100',16,1)  
  END  
    
	--User acces check  
	IF @LayoutID=0  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,39,27)  
	ELSE  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,39,27)  

	IF @HasAccess=0  
		RAISERROR('-105',16,1)  


	IF(@Type=1)
	BEGIN
		IF @LayoutID=0--------START INSERT RECORD-----------  
		BEGIN    
			INSERT INTO ADM_DocBarcodeLayouts  
			(CostCenterID,[Name]  
			,IsDefault  
			,BarcodeXML  
			,BodyXML
			,DefinitionXML
			,SelectedColsQuery 
			,JoinsQuery
			,IsDOS,DOSText,IsSalePrint
			,[GUID]   
			,[CreatedBy]  
			,[CreatedDate],CompanyGUID)  
			VALUES  
			(@DocumentID,@LayoutName
			,0  
			,@BarcodeXML  
			,@BodyXML 
			,@DefinitionXML
			,@SelectedColsQuery
			,@JoinsQuery
			,@ISDOS,@DOSText,@IsSalePrint
			,NEWID()   
			,@UserName  
			,CONVERT(FLOAT,GETDATE()),@CompanyGUID)  

			--To get inserted record primary key  
			SET @LayoutID=SCOPE_IDENTITY()

			INSERT INTO ADM_Assign(CostCenterID,NodeID,UserID,RoleID,GroupID,CreatedBy,CreatedDate)
			SELECT 105,@LayoutID,0,RoleID,0,@UserName,CONVERT(FLOAT,GETDATE()) FROM ADM_PRoles
		END--------END INSERT RECORD-----------  
		ELSE--------START UPDATE RECORD-----------  
		BEGIN        
			SELECT @TempGuid=[GUID] FROM ADM_DocBarcodeLayouts WITH(NOLOCK)     
			WHERE BarcodeLayoutID=@LayoutID    

			IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
			BEGIN    
			   RAISERROR('-101',16,1)   
			END    
			ELSE    
			BEGIN    
				UPDATE ADM_DocBarcodeLayouts  
				SET BarcodeXML  = @BarcodeXML   
				,BodyXML = @BodyXML 
				,DefinitionXML=@DefinitionXML
				,SelectedColsQuery=@SelectedColsQuery
				,JoinsQuery=@JoinsQuery
				,IsDOS=@ISDOS
				,DOSText=@DOSText
				,IsSalePrint=@IsSalePrint
				,[GUID] = NEWID()    
				,[ModifiedBy] = @UserName  
				,[ModifiedDate] = CONVERT(FLOAT,GETDATE())  
				WHERE BarcodeLayoutID=@LayoutID  
			END  
		END--------END UPDATE RECORD-----------  
	END
	ELSE
	BEGIN
		IF exists (select * from ADM_DocBarcodeLayouts where CostCenterID=@DocumentID)
		BEGIN
			SET @ID=(select BarcodeLayoutID from ADM_DocBarcodeLayouts where CostCenterID=@DocumentID )
			
			UPDATE ADM_DocBarcodeLayouts  
			SET BarcodeXML  = @BarcodeXML   
			,BodyXML = @BodyXML 
			,DefinitionXML=@DefinitionXML
			,SelectedColsQuery=@SelectedColsQuery
			,JoinsQuery=@JoinsQuery
			,IsDOS=@ISDOS
			,DOSText=@DOSText
			,IsSalePrint=@IsSalePrint
			,[GUID] = NEWID()    
			,[ModifiedBy] = @UserName  
			,[ModifiedDate] = CONVERT(FLOAT,GETDATE())  
			WHERE BarcodeLayoutID=@ID  
		END
		ELSE
		BEGIN
			INSERT INTO ADM_DocBarcodeLayouts  
		   (CostCenterID,[Name]  
		   ,IsDefault  
		   ,BarcodeXML  
		   ,BodyXML
		   ,DefinitionXML
		   ,SelectedColsQuery 
		   ,JoinsQuery
		   ,IsDOS,DOSText,IsSalePrint
		   ,[GUID]   
		   ,[CreatedBy]  
		   ,[CreatedDate],CompanyGUID)  
		   VALUES  
		   (@DocumentID,@LayoutName
		   ,0  
		   ,@BarcodeXML  
		   ,@BodyXML 
		   ,@DefinitionXML
		   ,@SelectedColsQuery
		   ,@JoinsQuery
		   ,@ISDOS,@DOSText,@IsSalePrint
		   ,NEWID()   
		   ,@UserName  
		   ,CONVERT(FLOAT,GETDATE()),@CompanyGUID)  
		    
		   --To get inserted record primary key  
		   SET @LayoutID=SCOPE_IDENTITY()

		    INSERT INTO ADM_Assign(CostCenterID,NodeID,UserID,RoleID,GroupID,CreatedBy,CreatedDate)
			SELECT 105,@LayoutID,0,RoleID,0,@UserName,CONVERT(FLOAT,GETDATE()) FROM ADM_PRoles
		END
	END
	
	if @IsSalePrint=1 and not exists(select Name from adm_featureaction where FeatureID=@DocumentID and Name='Save&Barcode')
	begin
		declare @FAID bigint
		INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
		VALUES('Save&Barcode',null,@DocumentID,116,1,NULL,NULL,1,convert(float,getdate()),'ADMIN')
		set @FAID=scope_identity()
		INSERT INTO [adm_featureactionrolemap] ([RoleID],[FeatureActionID],[Description],[Status],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])
		VALUES(1,@FAID,NULL,1,'admin',convert(float,getdate()),NULL,NULL)
		
		INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
		VALUES('BarcodePrint',null,@DocumentID,117,1,NULL,NULL,1,convert(float,getdate()),'ADMIN')
		set @FAID=scope_identity()
		INSERT INTO [adm_featureactionrolemap] ([RoleID],[FeatureActionID],[Description],[Status],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])
		VALUES(1,@FAID,NULL,1,'admin',convert(float,getdate()),NULL,NULL)
	end
   
COMMIT TRANSACTION    
SELECT * FROM ADM_DocBarcodeLayouts WITH(nolock) WHERE BarcodeLayoutID=@LayoutID    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;    
RETURN @LayoutID    
END TRY    
BEGIN CATCH    
	--Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		SELECT * FROM ADM_DocBarcodeLayouts WITH(nolock) WHERE BarcodeLayoutID=@LayoutID     
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
