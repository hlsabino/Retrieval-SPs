﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAdm_GetRoleMapped]
	@RoleID [bigint]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION            
BEGIN TRY            
SET NOCOUNT ON;    
      
    --Getting  UserName. 
    SELECT UserRoleMapID,RoleID,UserID,UserName FROM  dbo.ADM_UserRoleMap
	WHERE ROLEID = @RoleID  AND STATUS = 1
           
             
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
