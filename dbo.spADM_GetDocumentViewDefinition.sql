USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDocumentViewDefinition]
	@DocumentViewID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
   
BEGIN TRY    
SET NOCOUNT ON;  
   
	Declare @CostCenterID int
  --SP Required Parameters Check  
  IF @DocumentViewID=0  
  BEGIN  
   RAISERROR('-100',16,1)  
  END  
  
SELECT [DocumentViewDefID]
      ,[DocumentViewID]
      ,[DocumentTypeID]
      ,[CostCenterID]
      ,[CostCenterColID]
      ,[ViewName]
      ,[IsEditable]
      ,[IsReadonly]
      ,[NumFieldEditOptionID]
      ,[IsVisible]
      ,[TabOptionID]
      ,[CompoundRuleID],Expression,Mode
      ,[FailureMessage]
      ,[ActionOptionID],IsMandatory
      ,[CompanyGUID]
      ,[GUID]
      ,[Description]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate],TabID,ViewFor,ISNULL(FieldColor,'') FieldColor
  FROM [ADM_DocumentViewDef] with(nolock)
  where [DocumentViewID]=@DocumentViewID
  
  SELECT [DocViewUserRoleMapID]
      ,[DocumentViewID]
      ,[DocumentTypeID]
      ,[CostCenterID]
      ,[CompanyGUID],UserID,RoleID,GroupID
      ,[GUID]
      ,[Description]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
  FROM [ADM_DocViewUserRoleMap] with(nolock)
   where [DocumentViewID]=@DocumentViewID 
    
   
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
