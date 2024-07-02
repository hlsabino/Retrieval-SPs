USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportJobOutputData]
	@JobXML [nvarchar](max) = null,
	@CostCenterID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
	--Declaration Section 
	DECLARE @XML XML
	SET @XML=@JobXML
		
	INSERT INTO [PRD_JobOuputProducts]
	([CostCenterID],[NodeID],[StageID],[BomID],[ProductID],[Qty],[UOMID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate]
	,[ModifiedBy],[ModifiedDate],[StatusID],[IsBom],[Remarks],[Dimid])	
	SELECT 50021,X.value('@NodeID','nvarchar(500)'),BS.StageID,X.value('@BOMID','nvarchar(500)')
	,X.value('@ProductID','nvarchar(500)'),X.value('@Qty','nvarchar(500)'),X.value('@UOMID','nvarchar(500)'),NewID(),NewID(),'Admin',CONVERT(FLOAT,GetDate()),NULL,NULL	
	,X.value('@StatusID','nvarchar(500)'),X.value('@IsBom','nvarchar(500)'),X.value('@Remarks','nvarchar(500)'),1 
   from @XML.nodes('/XML/Row') as Data(X)
   JOIN PRD_BOMStages BS WITH(NOLOCK) ON BS.StageNodeID=X.value('@StageID','nvarchar(500)') AND BS.BomID=X.value('@BOMID','nvarchar(500)')
   SELECT ErrorMessage,* FROM COM_ErrorMessages WHERE ErrorNumber=100 AND LanguageId=1   

COMMIT TRANSACTION 
END TRY    
BEGIN CATCH 
	ROLLBACK TRANSACTION   
	RETURN -999 
END CATCH

GO
