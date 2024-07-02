USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAdm_GetRoleName]
	@RoleID [bigint] = 0,
	@RoleName [nvarchar](200)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION          
BEGIN TRY          
SET NOCOUNT ON;        
     
     
  --Getting  UserName.          
  if(@RoleID=0)
	 SELECT  [Name]
	  FROM  [ADM_PRoles]  
	 WHERE NAME =   @RoleName
	else
          SELECT  [Name]
	  FROM  [ADM_PRoles]  
	 WHERE NAME =   @RoleName and Roleid<>@RoleID
           
COMMIT TRANSACTION         
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
ROLLBACK TRANSACTION        
SET NOCOUNT OFF          
RETURN -999           
END CATCH        
        
        
        
GO
