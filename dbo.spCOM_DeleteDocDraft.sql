USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteDocDraft]
	@DraftID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
SET NOCOUNT ON  
BEGIN TRY  
  DECLARE @RowsDeleted INT  
  
  --TO Remove currencies    
  DELETE FROM COM_DocDraft WHERE DraftID=@DraftID  
  SET @RowsDeleted=@@rowcount  
  
COMMIT TRANSACTION  
select D.DraftID,DocName,NoOfProducts,NetValue,D.CostCenterID,Status,CONVERT(DATETIME,ModifiedDate) AS [Date],'Delete' as [Delete],(SELECT Top 1 DocumentName FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=D.CostCenterID) [Type]   from COM_DocDraft D
SET NOCOUNT OFF;  
RETURN @RowsDeleted    
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  
   
    
    
    
    
  
  
  
GO
