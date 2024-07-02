USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductByStockCode]
	@StockCode [nvarchar](max),
	@table [nvarchar](100),
	@StCCID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON        
        
    DECLARE @SQL NVARCHAR(MAX),@stockID BIGINT

	
   if(@StockCode is not null and @StockCode<>'')
   BEGIN
		set @SQL='select @stockID=NodeID
		 from '+@table+' with(nolock)  where COde='''+@StockCode+''''

		exec sp_executesql @SQL,N'@stockID BIGINT OUTPUT',@stockID output
		if(@stockID is null or @stockID=0)
		BEGIN
			set @SQL='select @stockID=NodeID
			from '+@table+' with(nolock)  where EAN='''+@StockCode+''''

			exec sp_executesql @SQL,N'@stockID BIGINT OUTPUT',@stockID output

			if(@stockID is null or @stockID=0)
			BEGIN
				select @stockID=ProductID from INV_Product with(NOLOCK) where ProductCode=@StockCode
				if(@stockID is null or @stockID=0)
					return;  
				else
				BEGIN
					set @SQL='select  a.ProductID,a.UOMID,s.DealerPrice,s.AvgPrice,s.RetailPrice,c.UnitName,a.ProductCode,a.ProductName,a.ProductTypeID,s.NodeID,s.Code,c.Conversion from INV_Product a with(NOLOCK)
					join '+@table+' s with(NOLOCK) on s.nodeid=
					(select max(nodeid)  from '+@table+' b with(NOLOCK)  where b.ProductID='+CONVERT(nvarchar, @stockID)+'
					group by b.ProductID) 
					join COM_UOM c with(NOLOCK) on a.UOMID=c.UOMID
					where a.ProductID='+CONVERT(nvarchar, @stockID)
					exec(@SQL)
					return
				END	
			END
		END	
   END
   
	set @SQL='select  a.ProductID,p.UOMID,a.DealerPrice,a.AvgPrice,a.RetailPrice,c.UnitName,p.ProductCode,p.ProductName,p.ProductTypeID,a.NodeID,a.Code,c.Conversion
	from '+@table+' a with(NOLOCK)
	join INV_Product p with(NOLOCK) on p.ProductID=a.ProductID
	join COM_UOM c with(NOLOCK) on p.UOMID=c.UOMID
	where a.NodeID='+CONVERT(nvarchar, @stockID) 
	exec(@SQL)

    
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
