USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocFlow]
	@ProfileID [int],
	@RefCCID [int],
	@RefNodeID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;    
   
   select *,(select Status From COM_Status s WITH(NOLOCK) where T.StatusID=s.StatusID) Status from ( 
  select DISTINCT DocFlowDefID,RefStatusID,a.CCID,case when c.CCID=1000 THEN 369 ELSE D.StatusID END StatusID,a.Action,b.DocumentName,c.DocID,@ProfileID ProfileID,a.Description
  from ADM_DocFlowDef a with(nolock)   
  left join ADM_DocumentTypes b with(nolock) on a.CCID=b.CostCenterID  
  left join COM_DocFlow c with(nolock) on a.CCID=c.CCID and c.ProfileID=@ProfileID and c.RefCCID=@RefCCID and c.RefNodeID=@RefNodeID  
  left join INV_DocDetails D with(nolock) on D.DocID=c.DocID  
  where a.ProfileID=@ProfileID) as t
  
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  
GO
