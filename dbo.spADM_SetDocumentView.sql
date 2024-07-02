USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDocumentView]
	@DocumentViewID [int],
	@ViewName [nvarchar](200),
	@ViewFor [int],
	@DocumentTypeID [int],
	@CostCenterID [int],
	@ViewXml [nvarchar](max),
	@RoleXml [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](200),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
   
	Declare @XML XML
	--SP Required Parameters Check  
	IF @DocumentTypeID=0 and @CostCenterID=0
	BEGIN  
		RAISERROR('-100',16,1)  
	END  
	if(@DocumentTypeID>0 and @CostCenterID=0)
	begin
		SELECT @CostCenterID=COSTCENTERID FROM ADM_DocumentTypes WITH(NOLOCK) 
		WHERE  DocumentTypeID=@DocumentTypeID
	end

	IF EXISTS (SELECT DocumentViewID FROM ADM_DocumentViewDef WITH(NOLOCK) 
			   WHERE VIEWNAME=@ViewName AND DocumentTypeID=@DocumentTypeID AND CostCenterID=@CostCenterID AND @DocumentViewID=0)
	BEGIN 
		RAISERROR('-202',16,1)
	END

	SET @XML=@ViewXml
	IF(@DocumentViewID=0)
	BEGIN
		SELECT @DocumentViewID=ISNULL(MAX(DocumentViewID),0) +1 FROM [ADM_DocumentViewDef] WITH(NOLOCK)
	END
	ELSE
	BEGIN
		DELETE FROM [ADM_DocumentViewDef]
		WHERE [DocumentViewID]=@DocumentViewID 
		and DocumentViewDefID NOT IN (SELECT X.value('@DocumentViewDefID','INT')  from @XML.nodes('/DocViewXML/Row') as Data(X)    
		WHERE X.value('@DocumentViewDefID','INT') IS NOT NULL AND  X.value('@DocumentViewDefID','INT')>0) 
	END
 
	INSERT INTO [ADM_DocumentViewDef] (
		  [DocumentViewID]
		  ,[DocumentTypeID]
		  ,[CostCenterID]
		  ,[ViewName]
		  ,ViewFor
		  ,[CompoundRuleID]
		  ,[IsReadonly]
		  ,[TabOptionID]
		  ,[CostCenterColID]
		  ,[IsEditable]
		  ,[NumFieldEditOptionID]
		  ,[IsVisible]
		  ,Expression,Mode
		  ,[FailureMessage]
		  ,[ActionOptionID]
		  ,IsMandatory
		  ,[CompanyGUID]
		  ,[GUID]
		  ,[CreatedBy]
		  ,[CreatedDate]
		  ,TabID,description,FieldColor)
	SELECT @DocumentViewID
		  ,@DocumentTypeID
		  ,@CostCenterID
		  ,@ViewName
		  ,@ViewFor
		  ,0
		  ,isnull(X.value('@ReadOnly','BIT'),0)
		  ,0
		  ,X.value('@CostCenterColID','INT') 
		  ,X.value('@IsEditable','BIT') 
		  ,X.value('@NumFieldEditOptionID','INT') 
		  ,X.value('@IsVisible','BIT') 
		  ,X.value('@Expression','NVARCHAR(MAX)') ,X.value('@Mode','INT') 
		  ,X.value('@FailureMessage','NVARCHAR(MAX)') 
		  ,X.value('@ActionOptionID','INT'),X.value('@IsMandatory','INT')
		  ,@CompanyGUID,NEWID()
		  ,@UserName,CONVERT(FLOAT,GETDATE())
		  ,X.value('@TabID','INT') ,X.value('@Descr','NVARCHAR(MAX)')
		  ,X.value('@FieldColor','NVARCHAR(400)')
	from @XML.nodes('/DocViewXML/Row') as Data(X)    
	WHERE X.value('@DocumentViewDefID','INT') IS NULL OR X.value('@DocumentViewDefID','INT')=0
	
  
	UPDATE [ADM_DocumentViewDef] set ViewName=@ViewName
		  ,ViewFor=@ViewFor
		  ,[CostCenterColID]=X.value('@CostCenterColID','INT') 
		  ,[IsEditable]=X.value('@IsEditable','BIT') 
		  ,[NumFieldEditOptionID]=X.value('@NumFieldEditOptionID','INT') 
		  ,[IsVisible]=X.value('@IsVisible','BIT') 
		  ,Expression=X.value('@Expression','NVARCHAR(MAX)') 
		  ,Mode=X.value('@Mode','INT') 
		  ,[FailureMessage]=X.value('@FailureMessage','NVARCHAR(MAX)') 
		  ,[ActionOptionID]=X.value('@ActionOptionID','INT')
		  ,IsMandatory=X.value('@IsMandatory','INT')
		  ,IsReadOnly=isnull(X.value('@ReadOnly','BIT'),0)
		  ,ModifiedBy=@UserName
		  ,ModifiedDate=CONVERT(FLOAT,GETDATE())
		  ,description=X.value('@Descr','NVARCHAR(MAX)')
		  ,FieldColor=X.value('@FieldColor','NVARCHAR(MAX)')
	from @XML.nodes('/DocViewXML/Row') as Data(X)    
	WHERE X.value('@DocumentViewDefID','INT') IS NOT NULL AND  X.value('@DocumentViewDefID','INT')>0
	AND DocumentViewDefID=X.value('@DocumentViewDefID','INT')

	DELETE from [ADM_DocViewUserRoleMap] where [DocumentViewID]=@DocumentViewID
  
	SET @XML=@RoleXml
	
	if exists(select A.[DocumentViewID] from [ADM_DocViewUserRoleMap] A WITH(NOLOCK) 
			  LEFT JOIN [ADM_DocumentViewDef] DV WITH(NOLOCK) ON A.[DocumentViewID]=DV.[DocumentViewID] 
			  where A.DocumentTypeID=@DocumentTypeID AND A.[CostCenterID]=@CostCenterID and  DV.ViewFor=@ViewFor AND
			  A.RoleID in(SELECT  X.value('@RoleID','INT') from @XML.nodes('/XML/Row') as Data(X) where  X.value('@RoleID','INT') is not null ))
	begin
		RAISERROR('-382',16,1)
	end
	if exists(select A.[DocumentViewID] from [ADM_DocViewUserRoleMap] A WITH(NOLOCK)
			  LEFT JOIN [ADM_DocumentViewDef] DV WITH(NOLOCK) ON A.[DocumentViewID]=DV.[DocumentViewID] 
			  where A.DocumentTypeID=@DocumentTypeID AND A.[CostCenterID]=@CostCenterID and  DV.ViewFor=@ViewFor AND
			  A.UserID in(SELECT  X.value('@UserID','INT') from @XML.nodes('/XML/Row') as Data(X) where  X.value('@UserID','INT') is not null ))
	begin
		RAISERROR('-383',16,1)
	end
	if exists(select A.[DocumentViewID] from [ADM_DocViewUserRoleMap] A WITH(NOLOCK)
			  LEFT JOIN [ADM_DocumentViewDef] DV WITH(NOLOCK) ON A.[DocumentViewID]=DV.[DocumentViewID] 
			  where A.DocumentTypeID=@DocumentTypeID AND A.[CostCenterID]=@CostCenterID and  DV.ViewFor=@ViewFor AND 
			  A.GroupID in(SELECT  X.value('@GroupID','INT') from @XML.nodes('/XML/Row') as Data(X) where  X.value('@GroupID','INT') is not null ))
	begin
		RAISERROR('-384',16,1)
	end
		  
		  
	if exists(select [DocumentViewID] from [ADM_DocumentViewDef] WITH(NOLOCK) where [DocumentViewID]=@DocumentViewID)
	begin
		 INSERT INTO [ADM_DocViewUserRoleMap]([DocumentViewID]
			  ,[DocumentTypeID]
			  ,[CostCenterID],UserID,RoleID,GroupID
			  ,[CompanyGUID]
			  ,[GUID]
			  ,[CreatedBy]
			  ,[CreatedDate])
		  SELECT @DocumentViewID 
			  ,@DocumentTypeID
			  ,@CostCenterID,X.value('@UserID','INT')
			  ,X.value('@RoleID','INT') 
			  ,X.value('@GroupID','INT') 
			  ,@CompanyGUID,NEWID()
			  ,@UserName,CONVERT(FLOAT,GETDATE())
		  from @XML.nodes('/XML/Row') as Data(X)    
	end
	
	COMMIT TRANSACTION   
	SET NOCOUNT OFF;  
	SELECT * FROM [ADM_DocumentViewDef] WITH(nolock) WHERE DocumentViewID=@DocumentViewID  
	
	UPDATE ADM_DocumentTypes SET GUID=NEWID()where CostCenterID=@CostCenterID 
	
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID
	 
	RETURN @DocumentViewID
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
	ROLLBACK TRANSACTION  
	SET NOCOUNT OFF    
	RETURN -999     
END CATCH
GO
