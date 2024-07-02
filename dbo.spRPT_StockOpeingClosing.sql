USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_StockOpeingClosing]
	@BalanceType [bit],
	@Products [nvarchar](max),
	@LocationWHERE [nvarchar](max) = NULL,
	@FromDate [datetime],
	@ToDate [datetime],
	@IncludeUpPostedDocs [bit]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON;  

	DECLARE @TblProducts AS TABLE(ProductID BIGINT)
	DECLARE @SPInvoice cursor, @nStatusOuter int
	DECLARE @ProductID BIGINT,@TagSQL NVARCHAR(MAX)
	DECLARE @Qty FLOAT,@AvgRate FLOAT,@StockValue FLOAT,@COGS FLOAT
	
	IF len(@Products)>0
	BEGIN
		INSERT INTO @TblProducts
		EXEC SPSplitString @Products,','
	END
	ELSE
	BEGIN
		INSERT INTO @TblProducts
		SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE IsGroup=0
	END
	
	SET @SPInvoice = cursor for 
	SELECT ProductID FROM @TblProducts
	--SELECT ProductID,ValuationID FROM INV_Product WHERE IsGroup=0
	
	SET @TagSQL=''
	IF @LocationWHERE IS NOT NULL AND @LocationWHERE<>''
		SET @TagSQL=@TagSQL+@LocationWHERE
	
	DECLARE @Tbl AS TABLE(ProductID BIGINT,Qty FLOAT,AvgRate FLOAT,StockValue FLOAT)
	
	OPEN @SPInvoice 
	SET @nStatusOuter = @@FETCH_STATUS
	
	FETCH NEXT FROM @SPInvoice Into @ProductID
	SET @nStatusOuter = @@FETCH_STATUS
	
	WHILE(@nStatusOuter <> -1)
	BEGIN

		EXEC [spRPT_AvgRate] @BalanceType,@ProductID,@TagSQL,'',@FromDate,@ToDate,@IncludeUpPostedDocs,0,0,0,'',0,@Qty OUTPUT,@AvgRate OUTPUT,@StockValue OUTPUT,@COGS OUTPUT
		
		IF @Qty>0
		BEGIN
			INSERT INTO @Tbl(ProductID,Qty,AvgRate,StockValue)
			VALUES(@ProductID,@Qty,@AvgRate,@StockValue)
		END
	--	select @ProductID
	
	--print(@ProductID)
	
		FETCH NEXT FROM @SPInvoice Into @ProductID
		SET @nStatusOuter = @@FETCH_STATUS
	END
	
	SELECT ISNULL(SUM(Qty),0) Qty,ISNULL(SUM(StockValue),0) Value FROM @Tbl
	
	--SELECT * FROM @Tbl
--EXEC [spRPT_StockOpeingClosing] 0,NULL,'27 sep 2010','30 May 2012'
GO
