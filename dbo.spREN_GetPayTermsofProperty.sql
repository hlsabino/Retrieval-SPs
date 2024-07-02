USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetPayTermsofProperty]
	@where [nvarchar](max),
	@Cols [nvarchar](max),
	@Join [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY           
SET NOCOUNT ON    
  
 declare @Sql nvarchar(max)  
  
 set @Sql='select  a.CostCenterID,a.DocID,a.VoucherNo VNO,a.DocPrefix,a.DocNumber'  
 set @Sql=@Sql+@Cols  
 set @Sql=@Sql+' from INV_DocDetails a WITH(NOLOCK)  
 join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID  
 join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID  
 join COM_DocTextData t WITH(NOLOCK) on a.InvDocDetailsID=t.InvDocDetailsID '  
 set @Sql=@Sql+@Join  
 set @Sql=@Sql+@where
 
 print @Sql
 exec(@Sql)  
   
Return 1   
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS            
ErrorLine          
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID          
 END          
SET NOCOUNT OFF            
RETURN -999             
END CATCH 
GO
