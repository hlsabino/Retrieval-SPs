USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_SalesAnalasys]
	@ProductID [nvarchar](max),
	@ExpectedQTY1 [nvarchar](200),
	@ExpectedQTY2 [nvarchar](200),
	@ExpectedQTY3 [nvarchar](200),
	@CommitedQTY1 [nvarchar](200),
	@CommitedQTY2 [nvarchar](200),
	@CommitedQTY3 [nvarchar](200),
	@SalesDocs [nvarchar](200),
	@FromDate [datetime],
	@ToDate [datetime],
	@CCWHERE [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON
	--Declaration Section
	DECLARE @TblQOH AS TABLE(ProductID BIGINT,Qty FLOAT)
	DECLARE @TblBalanceQty AS TABLE(ProductID BIGINT,Qty FLOAT)
	DECLARE @TblAvgSale AS TABLE(ProductID BIGINT,Mn FLOAT,Qty FLOAT)
	DECLARE @TblPendingOrders AS TABLE(ProductID BIGINT,ExpQty1 FLOAT,ExpQty2 FLOAT,ExpQty3 FLOAT,ComQty1 FLOAT,ComQty2 FLOAT,ComQty3 FLOAT)
	DECLARE @TblPList AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID BIGINT,AvgRate FLOAT)
	DECLARE @Query nvarchar(MAX),@StDate DATETIME,@EndDate DATETIME,@CurrYearMonths FLOAT,@I INT
	
		
	INSERT INTO @TblPList(ProductID)
	EXEC SPSplitString @ProductID,','

	IF len(@CCWHERE)>0
	BEGIN
		SET @CCWHERE=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON A.InvDocDetailsID=DCC.InvDocDetailsID '	+@CCWHERE
	END

	/******* QOH Calculation *******/
	SET @Query='SELECT A.ProductID, SUM(UOMConvertedQty*VoucherType)
	FROM INV_DocDetails A WITH(NOLOCK) '+@CCWHERE+'
	WHERE A.ProductID IN ('+@ProductID+') AND (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0
	GROUP BY A.ProductID'
	INSERT INTO @TblQOH(ProductID,Qty)
	EXEC(@Query)
	
	/******* Balance Quantity Calculation *******/
	SET @Query='SELECT A.ProductID, SUM(UOMConvertedQty*VoucherType)
	FROM INV_DocDetails A WITH(NOLOCK)
	WHERE A.ProductID IN ('+@ProductID+') AND (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0
	GROUP BY A.ProductID'
	INSERT INTO @TblBalanceQty(ProductID,Qty)
	EXEC(@Query)

	/******* Expected Quantity Calculation *******/
	IF @ExpectedQTY1<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrders(@ExpectedQTY1,@ProductID,@CCWHERE,'',0)
		INSERT INTO @TblPendingOrders(ProductID,ExpQty1)
		EXEC(@Query)
	END	
	IF @ExpectedQTY2<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrders(@ExpectedQTY2,@ProductID,@CCWHERE,'',0)
		INSERT INTO @TblPendingOrders(ProductID,ExpQty2)
		EXEC(@Query)
	END	
	IF @ExpectedQTY3<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrders(@ExpectedQTY3,@ProductID,@CCWHERE,'',0)
		INSERT INTO @TblPendingOrders(ProductID,ExpQty3)
		EXEC(@Query)
	END
	
	/******* Commited Quantity Calculation *******/
	IF @CommitedQTY1<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrders(@CommitedQTY1,@ProductID,@CCWHERE,'',0)
		INSERT INTO @TblPendingOrders(ProductID,ComQTy1)
		EXEC(@Query)
	END	
	IF @CommitedQTY2<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrders(@CommitedQTY2,@ProductID,@CCWHERE,'',0)
		INSERT INTO @TblPendingOrders(ProductID,ComQTy2)
		EXEC(@Query)
	END	
	IF @CommitedQTY3<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrders(@CommitedQTY3,@ProductID,@CCWHERE,'',0)
		INSERT INTO @TblPendingOrders(ProductID,ComQTy3)
		EXEC(@Query)
	END
	

	/******* Forecast based on previous Year Slots Calculation *******/
	IF @SalesDocs<>''
	BEGIN
		SET @Query=''
		SET @I=0
		SET @StDate=@FromDate
		WHILE(@StDate<=@ToDate)
		BEGIN
			SET @EndDate=dateadd(mm,1,@StDate)
			IF @EndDate>@ToDate
				SET @EndDate=@ToDate
			
			--SELECT @StDate,@EndDate
			IF len(@Query)>0
				SET @Query=@Query+'
				 UNION ALL '	
				 
			SET @Query=@Query+'
			SELECT A.ProductID,'+CONVERT(NVARCHAR,@I)+' Mn, SUM(UOMConvertedQty*-VoucherType) Qty
		FROM INV_DocDetails A WITH(NOLOCK) '+@CCWHERE+'
		WHERE A.ProductID IN ('+@ProductID+') AND A.CostCenterID IN('+@SalesDocs+')
			AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))
			+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+') AND A.StatusID<>438
		GROUP BY A.ProductID'
			
			IF @StDate=@FromDate
			BEGIN
				SET @StDate=dateadd(mm,1,@StDate)-(datepart(dd,@FromDate)-1)
			END
			ELSE
				SET @StDate=dateadd(mm,1,@StDate)	
			SET @I=@I+1
		END
		
		INSERT INTO @TblAvgSale(ProductID,Mn,Qty)	
		EXEC(@Query)
	END
	

	/******* FINAL DATA *******/
	SELECT P.ProductID,ProductCode,ProductName,
		ISNULL(QOH.Qty,0) QOH,ISNULL(BQ.Qty,0) BalanceQty
		,PO.ExpQty1,PO.ExpQty2,PO.ExpQty3,PO.ComQty1,PO.ComQty2,PO.ComQty3
		
	FROM @TblPList TP INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=TP.ProductID
		LEFT JOIN (SELECT ProductID,SUM(ExpQty1) ExpQty1,SUM(ExpQty2) ExpQty2,SUM(ExpQty3) ExpQty3
				,SUM(ComQty1) ComQty1,SUM(ComQty2) ComQty2,SUM(ComQty3) ComQty3
				FROM @TblPendingOrders
				GROUP BY ProductID) AS PO ON P.ProductID=PO.ProductID
		LEFT JOIN @TblQOH QOH ON P.ProductID=QOH.ProductID
		LEFT JOIN @TblBalanceQty BQ ON P.ProductID=BQ.ProductID
	ORDER BY TP.ID
	
	
	SELECT * from @TblAvgSale
	Order By ProductID


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
