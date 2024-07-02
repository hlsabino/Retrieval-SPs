USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetAPIFieldsMapping]
	@CostCenterID [int],
	@DocumentFieldsXml [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON;
	
	IF @DocumentFieldsXml IS NOT NULL AND @DocumentFieldsXml<>''
	BEGIN
		DECLARE @XML XML=@DocumentFieldsXml     
		DECLARE @DT FLOAT=CONVERT(FLOAT,GETDATE())
		
		IF @CostCenterID<>50
		BEGIN
			DELETE DM FROM COM_APIFieldsMapping DM WITH(NOLOCK) 
			WHERE DM.CostCenterID=@CostCenterID 
			AND DM.MapID NOT IN (SELECT X.value('@MapID','int') FROM @XML.nodes('XML/Row') as DATA(X))
		END
		ELSE
		BEGIN
			DELETE DM FROM COM_APIFieldsMapping DM WITH(NOLOCK) 
			WHERE DM.CostCenterID=@CostCenterID 
			AND DM.Mode IN (SELECT X.value('@Mode','int') FROM @XML.nodes('XML/Row') as DATA(X))
			AND DM.MapID NOT IN (SELECT X.value('@MapID','int') FROM @XML.nodes('XML/Row') as DATA(X))
		END
		
		INSERT INTO [COM_APIFieldsMapping] (CostCenterID,Mode,Url,ActionType,Format,Headers,Params,Body
		,AuthorizationUrl,AuthorizationHeader,CreatedBy,CreatedDate,APIName,APISysName,APIType
		,Client,Audit,Result)
		SELECT @CostCenterID
		,ISNULL(X.value('@Mode','int'),0)
		,ISNULL(X.value('@Url','nvarchar(MAX)'),'')                
		,ISNULL(X.value('@ActionType','nvarchar(32)'),'')                
		,ISNULL(X.value('@Format','nvarchar(32)'),'')                
		,ISNULL(X.value('@Headers','nvarchar(MAX)'),'')                
		,ISNULL(X.value('@Params','nvarchar(MAX)'),'') 
		,ISNULL(X.value('@Body','nvarchar(MAX)'),'')
		,ISNULL(X.value('@AuthorizationUrl','nvarchar(MAX)'),'')
		,ISNULL(X.value('@AuthorizationHeader','nvarchar(MAX)'),'')
		,@UserName
		,@DT
		,ISNULL(X.value('@APIName','nvarchar(32)'),'')
		,ISNULL(X.value('@APIName','nvarchar(32)'),'')
		,ISNULL(X.value('@APIType','nvarchar(32)'),'API')
		,ISNULL(X.value('@Client','nvarchar(32)'),'HTTP')
		,ISNULL(X.value('@Audit','nvarchar(32)'),'NO')
		,ISNULL(X.value('@Result','nvarchar(MAX)'),'')
		FROM @XML.nodes('XML/Row') as DATA(X) 
		WHERE X.value('@MapID','int')=0

		UPDATE DM SET DM.Mode=ISNULL(X.value('@Mode','int'),0)
		,DM.Url=ISNULL(X.value('@Url','nvarchar(MAX)'),'')     
		,DM.ActionType=ISNULL(X.value('@ActionType','nvarchar(32)'),'')       
		,DM.Format=ISNULL(X.value('@Format','nvarchar(32)'),'')    
		,DM.Headers=ISNULL(X.value('@Headers','nvarchar(MAX)'),'')    
		,DM.Params=ISNULL(X.value('@Params','nvarchar(MAX)'),'')  
		,DM.Body=ISNULL(X.value('@Body','nvarchar(MAX)'),'')
		,DM.AuthorizationUrl=ISNULL(X.value('@AuthorizationUrl','nvarchar(MAX)'),'')
		,DM.AuthorizationHeader=ISNULL(X.value('@AuthorizationHeader','nvarchar(MAX)'),'')
		,DM.ModifiedBy=@UserName
		,DM.ModifiedDate=@DT
		,DM.APIName=ISNULL(X.value('@APIName','nvarchar(32)'),'')
		,DM.APISysName=ISNULL(X.value('@APIName','nvarchar(32)'),'')
		,DM.APIType=ISNULL(X.value('@APIType','nvarchar(32)'),'API')
		,DM.Client=ISNULL(X.value('@Client','nvarchar(32)'),'HTTP')
		,DM.Audit=ISNULL(X.value('@Audit','nvarchar(32)'),'NO')
		,DM.Result=ISNULL(X.value('@Result','nvarchar(MAX)'),'')
		FROM COM_APIFieldsMapping DM WITH(NOLOCK) 
		JOIN @XML.nodes('XML/Row') as DATA(X) ON DM.MapID=X.value('@MapID','int')
		WHERE DM.CostCenterID=@CostCenterID
	END
	ELSE
	BEGIN
		IF @CostCenterID<>50
		BEGIN
			DELETE DM FROM COM_APIFieldsMapping DM WITH(NOLOCK) 
			WHERE DM.CostCenterID=@CostCenterID 
		END
	END
	
	IF @CostCenterID<>50
	BEGIN
		IF EXISTS (SELECT * FROM COM_APIFieldsMapping WITH(NOLOCK) WHERE CostCenterID=@CostCenterID) 
		BEGIN
			IF NOT EXISTS (SELECT * FROM ADM_FeatureAction WITH(NOLOCK) WHERE FeatureID=@CostCenterID AND Name='API')
			BEGIN
				DECLARE @FeatureActionID INT=0
				INSERT INTO [ADM_FeatureAction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
				VALUES('API',NULL,@CostCenterID,70,1,NULL,NULL,1,@DT,@UserName)
				
				SET @FeatureActionID=SCOPE_IDENTITY()       
				 
				INSERT INTO [ADM_FeatureActionRoleMap]([RoleID],[FeatureActionID],[Description],[Status],[CreatedBy],[CreatedDate])
				VALUES(1,@FeatureActionID,NULL,1,@UserName,@DT)
			END 
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT * FROM ADM_FeatureAction WITH(NOLOCK) WHERE FeatureID=@CostCenterID AND Name='API')
			BEGIN
				DELETE FAM FROM [ADM_FeatureAction] FA WITH(NOLOCK) 
				JOIN [ADM_FeatureActionRoleMap] FAM WITH(NOLOCK) ON FAM.[FeatureActionID]=FA.[FeatureActionID]
				WHERE FA.FeatureID=@CostCenterID AND FA.Name='API'
				
				DELETE FA FROM [ADM_FeatureAction] FA WITH(NOLOCK) 
				WHERE FA.FeatureID=@CostCenterID AND FA.Name='API'
			END
		END
	END
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)                 
WHERE ErrorNumber=100 AND LanguageID=@LangID 
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
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
