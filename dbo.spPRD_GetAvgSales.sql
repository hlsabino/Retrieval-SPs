USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetAvgSales]
	@ProductIDs [nvarchar](max),
	@BOMIDs [nvarchar](max),
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
		declare @sql nvarchar(max),@POSQL NVARCHAR(MAX),@GITSQL NVARCHAR(MAX)
		DECLARE @MOSFEnablePendingOrders BIT,@MOSFEnableGoodsInTransit BIT,@MOSFPendingOrdersDocs NVARCHAR(500),@MOSFGoodsInTransitDocs NVARCHAR(500)
		SELECT @MOSFEnablePendingOrders=CONVERT(BIT,Value) FROM COM_CostCenterPreferences WHERE CostCenterID=78 AND Name='MOSFEnablePendingOrders'
		SELECT @MOSFEnableGoodsInTransit=CONVERT(BIT,Value) FROM COM_CostCenterPreferences WHERE CostCenterID=78 AND Name='MOSFEnablePendingOrders'
		SELECT @MOSFPendingOrdersDocs=Value FROM COM_CostCenterPreferences WHERE CostCenterID=78 AND Name='MOSFPendingOrdersDocs'
		SELECT @MOSFGoodsInTransitDocs=Value FROM COM_CostCenterPreferences WHERE CostCenterID=78 AND Name='MOSFGoodsInTransitDocs'

		IF @MOSFEnablePendingOrders=1 AND @MOSFPendingOrdersDocs IS NOT NULL AND @MOSFPendingOrdersDocs<>''
		SET @POSQL='(select isnull(sum(qty),0) from (SELECT isnull(a.Quantity,0) -isnull(sum(b.LinkedFieldValue),0) as qty 
					FROM INV_DocDetails a WITH(NOLOCK)
					left join INV_DocDetails B on a.InvDocDetailsID =b.LinkedInvDocDetailsID
					 WHERE a.ProductID=P.ProductID AND a.CostCenterID IN ('+@MOSFPendingOrdersDocs+')
					 group by a.InvDocDetailsID,a.Quantity) as tt) AS po'
		ELSE
			SET @POSQL='0 AS po'
			
		IF @MOSFEnableGoodsInTransit=1 AND @MOSFGoodsInTransitDocs IS NOT NULL AND @MOSFGoodsInTransitDocs<>''
			SET @GITSQL='(SELECT isnull(SUM(Quantity),0) FROM INV_DocDetails WITH(NOLOCK) WHERE ProductID=P.ProductID AND CostCenterID IN ('+@MOSFGoodsInTransitDocs+')) AS git'
		ELSE
			SET @GITSQL='0 AS git'

		set @sql='select P.ProductID,'
		if(@ColumnName='')
			set @sql=@sql+'isnull(sum(Quantity)/'+CONVERT(nvarchar,@NOOFMONTHS) +',0) AvgSales,'
		else 
			set @sql=@sql+'isnull(E.'+ @ColumnName +',0) AvgSales,'
		set @sql=@sql+'isnull(((SELECT isnull(SUM(Quantity),0) FROM INV_DocDetails i  WITH(NOLOCK)
		WHERE ProductID=P.ProductID AND IsQtyIgnored=0 AND VoucherType=1)
		-(SELECT  isnull(SUM(Quantity),0)  FROM INV_DocDetails  i  WITH(NOLOCK)
		WHERE ProductID=P.ProductID AND IsQtyIgnored=0 AND VoucherType=-1)),0) AS qoh
		,'+@POSQL+','+@GITSQL+'
		from INV_Product P WITH(NOLOCK)'
		if(@ColumnName<>'')
			set @sql=@sql+' join INV_ProductExtended E WITH(NOLOCK) on P.ProductID=E.ProductID '
		else 
			set @sql=@sql+'left join INV_DocDetails  A WITH(NOLOCK) on P.ProductID=A.ProductID AND DocDate between '+convert(nvarchar,CONVERT(FLOAT,@FROMDATE))+' AND '+convert(nvarchar,CONVERT(FLOAT,@TODATE))+' AND DocumentType=11  '
		
		set @sql=@sql+'where P.ProductID IN ('+@ProductIDs+') 
		GROUP BY P.ProductID  '
		if(@ColumnName<>'')
			set @sql=@sql+',E.'+ @ColumnName
		print @sql
		exec(@sql)

	
		set @sql='SELECT BP.ProductID,P.ProductName,BP.BOMID,BP.BOMProductID,BP.Quantity			
		,((SELECT isnull(SUM(Quantity),0) FROM INV_DocDetails i  WITH(NOLOCK)
		WHERE ProductID=BP.ProductID AND IsQtyIgnored=0 AND VoucherType=1)
		-(SELECT  isnull(SUM(Quantity),0)  FROM INV_DocDetails  i  WITH(NOLOCK)
		WHERE ProductID=BP.ProductID AND IsQtyIgnored=0 AND VoucherType=-1)) AS qoh
		,'+@POSQL+','+@GITSQL+'
		FROM  [PRD_BOMProducts] BP WITH(NOLOCK)
		INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=BP.ProductID 			
		WHERE BP.BOMID IN ('+@BOMIDs+') and BP.ProductUse=1 order by BP.ProductID'	
		
		exec(@sql)
			
	
		SELECT @MOSFEnablePendingOrders EnablePendingOrders,@MOSFEnableGoodsInTransit EnableGoodsInTransit

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
