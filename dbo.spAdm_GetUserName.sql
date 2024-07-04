USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAdm_GetUserName]
	@UserName [nvarchar](200)
WITH ENCRYPTION, EXECUTE AS CALLER
AS          
BEGIN TRY          
SET NOCOUNT ON;        

  --Getting  UserName.          
 SELECT  AUSR.UserName FROM [PACT2C].[dbo].[ADM_USERS] AUSR WITH(NOLOCK)   
 LEFT JOIN [ADM_USERS] USR WITH(NOLOCK) ON AUSR.UserName collate database_default = USR.UserName collate database_default  
WHERE  AUSR.UserName collate database_default = @UserName collate database_default and IsUserDeleted=0
                  
SET NOCOUNT OFF;        
RETURN 1        
END TRY        
BEGIN CATCH          
  --Return exception info [Message,Number,ProcedureName,LineNumber]          
  IF ERROR_NUMBER()=50000        
  BEGIN        
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE()          
  END        
  ELSE        
  BEGIN        
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine        
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999        
  END        
        
SET NOCOUNT OFF          
RETURN -999           
END CATCH
GO
