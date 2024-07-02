USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetUserNamebyOwner]
	@UserID [bigint],
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON;     
 
   
  if(@UserID=1)
  begin  
	  select UserName from adm_users WITH(NOLOCK) WHERE StatusID=1
  end
  else
  begin  
	  select UserName from dbo.adm_users WITH(NOLOCK) where userid in (select nodeid from dbo.COM_CostCenterCostCenterMap WITH(NOLOCK) 
	  where Parentcostcenterid=7 and costcenterid=7 and ParentNodeid=@UserID) AND StatusID=1
	  union 
	  select UserName from adm_users WITH(NOLOCK) where Userid=@UserID AND StatusID=1
  end
     
    
   
SET NOCOUNT OFF;       
RETURN 1    
END TRY    
BEGIN CATCH      
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
