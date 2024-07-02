USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetGSTMapping]
	@GSTType [nvarchar](16),
	@CostCenterID [int],
	@MappingXML [nvarchar](max),
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	IF (@MappingXML IS NOT NULL AND @MappingXML <> '')  
	BEGIN  
		DELETE FROM INV_GSTMapping WHERE GSTType=@GSTType AND CostCenterID=@CostCenterID
		DECLARE @XML XML
		SET @XML=@MappingXML  

		INSERT INTO INV_GSTMapping(GSTType,ValueType,GSTColumnName,CostCenterID,SysColumnName,IsCalc,Reference,DefColumnName)  
		SELECT @GSTType,X.value('@ValueType','NVARCHAR(16)'),X.value('@GSTColumnName','NVARCHAR(32)')
		,@CostCenterID,X.value('@SysColumnName','NVARCHAR(32)'),ISNULL(X.value('@IsCalc','BIT'),0),ISNULL(X.value('@Reference','INT'),0),X.value('@DefColumnName','NVARCHAR(MAX)')   
		FROM @XML.nodes('/XML/Row') as Data(X)  
		
		IF @GSTType<>'UBL'
			SET @GSTType='GST'
			
		IF EXISTS (SELECT * FROM INV_GSTMapping WITH(NOLOCK) WHERE CostCenterID=@CostCenterID)
		BEGIN
			IF EXISTS (SELECT * FROM INV_GSTMapping WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND Reference=92)
				UPDATE COM_DocumentPreferences SET PrefValue='True' WHERE CostCenterID=@CostCenterID AND PrefName='PrimaryAddress' 
			IF EXISTS (SELECT * FROM INV_GSTMapping WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND Reference=93)
				UPDATE COM_DocumentPreferences SET PrefValue='True' WHERE CostCenterID=@CostCenterID AND PrefName='BillingAddress' 
			IF EXISTS (SELECT * FROM INV_GSTMapping WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND Reference=94)
				UPDATE COM_DocumentPreferences SET PrefValue='True' WHERE CostCenterID=@CostCenterID AND PrefName='ShippingAddress' 
			 
			IF NOT EXISTS (SELECT * FROM [ADM_FeatureAction] WITH(NOLOCK) WHERE [FeatureID]=@CostCenterID AND [Name]=@GSTType) 
			BEGIN
				DECLARE @RID INT,@FeatureActionID INT
				SELECT @RID=MAX(ResourceID)+1 FROM Com_LanguageResources WITH(NOLOCK)

				INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[FEATURE])
				VALUES(@RID,@GSTType,1,'English',@GSTType,'Documents',NULL,'1',4.000000000000000e+001,'Document')

				INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[FEATURE])
				VALUES(@RID,@GSTType,2,'Arabic',@GSTType,'Documents',NULL,'1',4.000000000000000e+001,'Document')
			
				INSERT INTO [ADM_FeatureAction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
				SELECT @GSTType,@RID,@CostCenterID,511,1,NULL,NULL,1,4003,'ADMIN'

				SET @FeatureActionID=SCOPE_IDENTITY()

				INSERT INTO [ADM_FeatureActionRoleMap]([RoleID],[FeatureActionID],[Description],[Status],[CreatedBy],[CreatedDate])
				SELECT 1,@FeatureActionID,NULL,1,'Admin',CONVERT(FLOAT,GETDATE())
			END
        END
        ELSE 
        BEGIN
			IF EXISTS (SELECT * FROM [ADM_FeatureAction] WITH(NOLOCK) WHERE [FeatureID]=@CostCenterID AND [Name]=@GSTType )
			BEGIN
				DELETE FROM [Com_LanguageResources] 
				WHERE [ResourceID] IN (SELECT ResourceID FROM [ADM_FeatureAction] WITH(NOLOCK) WHERE [FeatureID]=@CostCenterID AND [Name]=@GSTType )

				DELETE FROM [ADM_FeatureActionRoleMap] 
				WHERE [FeatureActionID]=(SELECT FeatureActionID FROM [ADM_FeatureAction] WITH(NOLOCK) WHERE [FeatureID]=@CostCenterID AND [Name]=@GSTType )

				DELETE FROM [ADM_FeatureAction] WHERE [FeatureID]=@CostCenterID AND [Name]=@GSTType
			END
        END
	END
			
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		if isnumeric(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		else
			SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber
	END
	ELSE 
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	BEGIN TRY
		ROLLBACK TRANSACTION
	END TRY
	BEGIN CATCH 
	END CATCH 
	
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
