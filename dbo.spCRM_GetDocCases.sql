﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetDocCases]
	@CostcenterID [int],
	@DocID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY       
SET NOCOUNT ON      
      
  Select CaseID,CaseNumber,Convert(datetime,CreateDate) CaseDate from CRM_Cases WITH(NOLOCK)  
  Where RefCCID=@CostCenterID and RefNodeID=@DocID 
	
        
SET NOCOUNT OFF;      
RETURN 1      
END TRY      
BEGIN CATCH        
 --Return exception info [Message,Number,ProcedureName,LineNumber]        
 IF ERROR_NUMBER()=50000      
 BEGIN      
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END      
 ELSE      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
 END      

SET NOCOUNT OFF        
RETURN -999         
END CATCH
GO
