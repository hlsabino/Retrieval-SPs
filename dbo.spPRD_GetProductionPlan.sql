USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetProductionPlan]
	@ProductIDs [nvarchar](max),
	@FROMDATE [datetime],
	@TODATE [datetime],
	@NOOFMONTHS [int],
	@ColumnName [nvarchar](100),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
		declare @sql nvarchar(max)
		
		set @sql='select P.ProductID,P.ProductCode,ProductName,'
		if(@ColumnName='')
			set @sql=@sql+'isnull(sum(Quantity)/'+CONVERT(nvarchar,@NOOFMONTHS) +',0) AvgSales,'
		else 
			set @sql=@sql+'isnull(E.'+ @ColumnName +',0) AvgSales,'
		set @sql=@sql+'isnull(((SELECT isnull(SUM(Quantity),0) FROM INV_DocDetails i  WITH(NOLOCK)
		WHERE ProductID=P.ProductID AND IsQtyIgnored=0 AND VoucherType=1 and docdate<'+convert(nvarchar,convert(float,@Fromdate))+')
		-(SELECT  isnull(SUM(Quantity),0)  FROM INV_DocDetails  i  WITH(NOLOCK)
		WHERE ProductID=P.ProductID AND IsQtyIgnored=0 AND VoucherType=-1 and docdate<'+convert(nvarchar,convert(float,@Fromdate))+')),0) AS Opening
		
		,isnull((SELECT  isnull(SUM(Quantity),0)  FROM INV_DocDetails  i  WITH(NOLOCK)
		WHERE ProductID=P.ProductID AND documenttype=34 and docdate between '+convert(nvarchar,convert(float,@Fromdate))+' and '+convert(nvarchar,convert(float,@TODATE))+'),0) as RFP
		,isnull((SELECT  isnull(SUM(Quantity),0)  FROM INV_DocDetails  i  WITH(NOLOCK)
		WHERE ProductID=P.ProductID AND IsQtyIgnored=0 AND VoucherType=-1  and docdate between '+convert(nvarchar,convert(float,@Fromdate))+' and '+convert(nvarchar,convert(float,@TODATE))+'),0) as TotalSales
	
		from INV_Product P WITH(NOLOCK)'
		if(@ColumnName<>'')
			set @sql=@sql+' join INV_ProductExtended E WITH(NOLOCK) on P.ProductID=E.ProductID '
		else 
			set @sql=@sql+'left join INV_DocDetails  A WITH(NOLOCK) on P.ProductID=A.ProductID AND DocDate between '+convert(nvarchar,CONVERT(FLOAT,@FROMDATE))+' AND '+convert(nvarchar,CONVERT(FLOAT,@TODATE))+' AND DocumentType=11  '
		
		set @sql=@sql+'where P.ProductID IN ('+@ProductIDs+') 
		GROUP BY P.ProductID ,P.ProductCode,ProductName '
		if(@ColumnName<>'')
			set @sql=@sql+',E.'+ @ColumnName
		print @sql
		exec(@sql)

	
COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
