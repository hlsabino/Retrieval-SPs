USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetProductsUOM]
	@ProductID [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY 
	declare @SQL NVARCHAR(MAX)
	
   	set @SQL='
   		declare @Tbl as Table(ProductID bigint,BaseID int,PCode nvarchar(200))
   		insert into @Tbl
   	 	select P.ProductID,B.BaseID,case when B.IsProductWise=1 then P.ProductCode else null end
   	 	from INV_Product P with(nolock) 
   	 	inner join COM_UOM B with(nolock) on B.UOMID=P.UOMID
   	 	where P.ProductID IN ('+@ProductID+')
   	
   	 	select * from @Tbl
   	 	
   	 	select U.UOMID,U.UnitName,U.UnitID,B.BaseID
   	 	from COM_UOM U with(nolock)
   	 	inner join (select BaseID from @Tbl group by BaseID) as B on U.BaseID=B.BaseID
   	 	order by U.UOMID
   	 	'
   	 	
	EXEC(@SQL)
			 
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
