USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOc_SearchPOSProduct]
	@SearchText [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON;    

	declare @sql nvarchar(max),@table nvarchar(max) 
	
	 select @table= b.TableName from adm_globalpreferences a
	join adm_features b on a.value=b.featureid
	where a.Name='POSItemCodeDimension'
	
	set @SQL='select a.ProductID,ProductCode,ProductName,a.Code,a.NodeID from '+@table+'  a  with(nolock)
	join INV_Product b  with(nolock) on a.ProductID=b.ProductID
	where a.COde like ''%' +@SearchText + '%''
	UNION
	select p.productid,ProductCode,ProductName,max(b.code),max(b.NodeID) from INV_Product p with(nolock)
	join  '+@table+' b on p.productid=b.productid 
	where ProductCode like ''%' +@SearchText + '%'' or ProductName like ''%' +@SearchText + '%''
	group by p.productid,ProductCode,ProductName'
print @sql
 exec(@sql)   
      
   
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
