USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDocumentReports]
	@DocumentViewID [int],
	@ViewName [nvarchar](200),
	@CostCenterID [int],
	@RoleXml [nvarchar](max),
	@ReportXml [nvarchar](max),
	@HeaderFields [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](200),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
     
	Declare @DocumentTypeID int,@XML XML  
	--SP Required Parameters Check    
	IF @CostCenterID=0    
	BEGIN    
		RAISERROR('-100',16,1)    
	END    

	SELECT @DocumentTypeID=DocumentTypeID FROM ADM_DocumentTypes               
	WITH(NOLOCK) WHERE  COSTCENTERID=@CostCenterID 
    
    if(@DocumentTypeID is null)
		set @DocumentTypeID=@CostCenterID
    
	IF EXISTS (SELECT DocumentViewID FROM ADM_DocumentReportDef with(nolock) WHERE VIEWNAME=@ViewName AND CostCenterID=@CostCenterID AND @DocumentViewID=0)  
	BEGIN   
		RAISERROR('-202',16,1)  
	END  
  
	IF(@DocumentViewID=0)  
	BEGIN  
		SELECT @DocumentViewID=ISNULL(MAX(DocumentViewID),0) +1 FROM [ADM_DocumentReportDef]  with(nolock)
	END  
	ELSE  
	BEGIN  
		DELETE FROM [ADM_DocumentReportDef]  
		WHERE DocumentViewID=@DocumentViewID   
	END  
	
	INSERT INTO  [ADM_DocumentReportDef] (  
	  DocumentViewID  
	  ,[DocumentTypeID]  
	  ,[CostCenterID]  
	  ,[ViewName]  
	  ,[CompanyGUID]  
	  ,[GUID]  
	  ,[CreatedBy]  
	  ,[CreatedDate])  
	  SELECT @DocumentViewID,@DocumentTypeID,@CostCenterID,@ViewName  
	,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())  

	UPDATE [ADM_DocumentReportDef] set ViewName=@ViewName  
	,ModifiedBy=@UserName,ModifiedDate=CONVERT(FLOAT,GETDATE())  
	where DocumentViewID=@DocumentViewID  

	DELETE from [ADM_DocReportUserRoleMap] where [DocumentViewID]=@DocumentViewID  
	Delete from ADM_DocumentReports  where [DocumentViewID]=@DocumentViewID  
    
	SET @XML=@RoleXml  
    
	INSERT INTO [ADM_DocReportUserRoleMap](  
	[DocumentViewID]  
	,[DocumentTypeID]  
	,[CostCenterID],UserID,RoleID,GroupID  
	,[CompanyGUID]  
	,[GUID]  
	,[CreatedBy]  
	,[CreatedDate])  
	SELECT  @DocumentViewID ,@DocumentTypeID,@CostCenterID,X.value('@UserID','BIGINT'),X.value('@RoleID','BIGINT') ,X.value('@GroupID','BIGINT')   
	,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())  
	from @XML.nodes('/XML/Row') as Data(X)      
     
     
	SET @XML=@ReportXml  
	declare @RID bigint
	insert into ADM_DocumentReports(  
	[DocumentReportID] ,ReportName,ReportField,ReportFieldName,Shortcut,DisplayAsPopup,GroupLevel,
	DocumentField ,DocumentFieldName,Width,Height,IsTreeFilter,MapXML,MapType
	,[DocumentViewID]  
	,ViewName  
	,CostCenterID  
	,[CompanyGUID]  
	,[GUID]  
	,[CreatedBy]  
	,[CreatedDate])  
	select X.value('@ReportID','BIGINT'), X.value('@ReportName','NVarchar(50)'),X.value('@ReportFieldID','BIGINT'), X.value('@ReportFieldName','NVarchar(50)'), X.value('@Shortcut','NVarchar(50)'),X.value('@DisplayAsPopup','INT'),X.value('@GroupLevel','BIT'),
	X.value('@DocumentFieldID','BIGINT'), X.value('@DocumentFieldName','NVarchar(50)'),X.value('@Width','FLOAT'),X.value('@Height','FLOAT'),isnull(X.value('@IsTreeFilter','BIT'),1)
	,X.value('@MapXML','nvarchar(max)'),X.value('@MapType','BIT'),@DocumentViewID,@ViewName,@CostCenterID,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())  
	from @XML.nodes('/XML/Row') as Data(X)      
    
    SET @RID= SCOPE_IDENTITY()
    
	UPDATE ADM_DocumentReports SET HeaderFields=@HeaderFields WHERE  ReportID=@RID
		
    UPDATE ADM_DocumentTypes SET GUID=NEWID()where CostCenterID=@CostCenterID 
      
	COMMIT TRANSACTION     
	SET NOCOUNT OFF;    
	SELECT * FROM [ADM_DocumentReportDef] WITH(nolock) WHERE DocumentViewID=@DocumentViewID  
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
	WHERE ErrorNumber=100 AND LanguageID=@LangID   
	RETURN @DocumentViewID  
END TRY    
BEGIN CATCH      
	--Return exception info [Message,Number,ProcedureName,LineNumber]      
	IF ERROR_NUMBER()=50000    
	BEGIN    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
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
