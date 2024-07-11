USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetGSTIRN]
	@CCID [int],
	@DocID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
          
BEGIN TRY          
SET NOCOUNT ON;        
     
declare @sql nvarchar(max)    
SELECT @Sql='SELECT TOP 1 DTD.'+ SysColumnName +' as IRN from INV_DocDetails INV WITH(NOLOCK)    
 JOIN COM_DocTextData DTD WITH(NOLOCK) ON DTD.InvDocDetailsID=INV.InvDocDetailsID    
 WHERE ISNULL(DTD.'+ SysColumnName +','''')<>'''' and INV.DocID='+convert(nvarchar,@DocID)+''     
 FROM INV_GSTMapping WITH(NOLOCK)    
 WHERE GSTType='EINV' AND GSTColumnName='IRN' AND SysColumnName<>'' AND CostCenterID=@CCID  
    
 print @Sql    
 exec (@Sql)    
   
      
             
SET NOCOUNT OFF;    
    
RETURN 1    
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
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
