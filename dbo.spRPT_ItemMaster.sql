USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_ItemMaster]
	@ProductID [nvarchar](max),
	@ExpectedQTY1 [nvarchar](200),
	@ExpectedQTY2 [nvarchar](200),
	@ExpectedQTY3 [nvarchar](200),
	@CommitedQTY1 [nvarchar](200),
	@CommitedQTY2 [nvarchar](200),
	@CommitedQTY3 [nvarchar](200),
	@SalesDocs [nvarchar](200),
	@SaleColumn [nvarchar](50),
	@FromDate [datetime],
	@ToDate [datetime],
	@MonthFromDate [datetime],
	@DontApplyDateFilter [bit],
	@DimensionID [int],
	@DimQuery [nvarchar](max),
	@CCWHERE [nvarchar](max),
	@SELECT [nvarchar](max),
	@FROM [nvarchar](max),
	@AvgRateWHERE [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	--Declaration Section
	DECLARE @TblAvgRate AS TABLE(ProductID BIGINT,TagID BIGINT,BalQty FLOAT,AvgRate FLOAT,BalValue FLOAT)
	DECLARE @TblQOH AS TABLE(ProductID BIGINT,TagID BIGINT,Qty FLOAT)
	DECLARE @TblBalanceQty AS TABLE(ProductID BIGINT,Qty FLOAT)
	DECLARE @TblAvgSale AS TABLE(ProductID BIGINT,TagID BIGINT,Mn FLOAT,Qty FLOAT)
	DECLARE @TblReorder AS TABLE(ProductID BIGINT,TagID BIGINT,ReorderLevel FLOAT,ReorderQty FLOAT,SellingPrice FLOAT,LastPrice FLOAT)
	DECLARE @TblPendingOrders AS TABLE(ProductID BIGINT,ExpQty1 FLOAT,ExpQty2 FLOAT,ExpQty3 FLOAT,ComQty1 FLOAT,ComQty2 FLOAT,ComQty3 FLOAT,TagID BIGINT)
	DECLARE @TblProducts AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID BIGINT)
	DECLARE @TblTagList AS TABLE(ID INT IDENTITY(1,1) NOT NULL,NodeID BIGINT,Name NVARCHAR(200))
	DECLARE @Query nvarchar(MAX),@StDate DATETIME,@EndDate DATETIME,@CurrYearMonths FLOAT,@I INT
	DECLARE @DimColumn NVARCHAR(50),@DimColAlias NVARCHAR(50),@GroupProduct BIGINT
	
	
	INSERT INTO @TblProducts(ProductID)
	EXEC SPSplitString @ProductID,','
	if((select count(*) from @TblProducts)=1)
	begin
		select @GroupProduct=ProductID from inv_product with(nolock) where productid=@ProductID and isgroup=1

		if @GroupProduct is not null
		begin
			INSERT INTO @TblProducts(ProductID)
			select ProductID from INV_Product with(nolock)
			where IsGroup=0 and lft>(select lft from inv_product with(nolock) where productid=@ProductID) and rgt<(select rgt from inv_product with(nolock) where productid=@ProductID) order by lft
					
			select @ProductID=@ProductID+','+convert(nvarchar,ProductID) from @TblProducts where ID>1
		end
	end
	
	IF len(@CCWHERE)>0 OR @DimensionID>0
	BEGIN
		INSERT INTO @TblTagList(NodeID,Name)
		EXEC(@DimQuery)
		--SELECT NodeID,Name FROM COM_Location --WHERE NodeID IN (0,1,6,7)
		
		SET @CCWHERE=' INNER JOIN COM_DocCCData DCC with(nolock) ON A.InvDocDetailsID=DCC.InvDocDetailsID '	+@CCWHERE
	END
	
	IF @DimensionID>0
	BEGIN
		SET @DimColumn=',DCC.dcCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)
		SET @DimColAlias=',DCC.dcCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' AS TAG'
	END
	ELSE
	BEGIN
		SET @DimColumn=''
		SET @DimColAlias=''		
	END
	
	--		,(SELECT TOP 1 A.Rate FROM INV_DocDetails SP '+@CCWHERE+' WHERE SP.IsQtyIgnored=0 and SP.VoucherType=1 and SP.ProductID=@PID ORDER BY SP.DocDate desc)

	/******* QOH Calculation *******/
	SET @Query='SELECT A.ProductID'+@DimColAlias+', SUM(UOMConvertedQty*VoucherType)
	FROM INV_DocDetails A WITH(NOLOCK) '+@CCWHERE+'
	WHERE A.ProductID IN ('+@ProductID+') AND (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0 and StatusID=369
	GROUP BY A.ProductID'+@DimColumn
	IF @DimensionID>0
		INSERT INTO @TblQOH(ProductID,TagID,Qty)
		EXEC(@Query)
	ELSE
		INSERT INTO @TblQOH(ProductID,Qty)
		EXEC(@Query)
	
	/******* Balance Quantity Calculation *******/
	SET @Query='SELECT A.ProductID, SUM(UOMConvertedQty*VoucherType)
	FROM INV_DocDetails A WITH(NOLOCK)
	WHERE A.ProductID IN ('+@ProductID+') AND (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0 and StatusID=369
	GROUP BY A.ProductID'
	INSERT INTO @TblBalanceQty(ProductID,Qty)
	EXEC(@Query)
	
	
	/******* Average Rate Calculation *******/
	DECLARE @TI INT,@COUNT INT,@TCNT INT,@PID BIGINT,@NodeID BIGINT,@BalQty FLOAT,@AvgRate FLOAT,@BalValue FLOAT,@COGS FLOAT,@SubTagSQL NVARCHAR(MAX)
	SELECT @I=1,@COUNT=COUNT(*) FROM @TblProducts
	IF @DimensionID=0
	BEGIN
		SET @SubTagSQL=@AvgRateWHERE

		WHILE(@I<=@COUNT)
		BEGIN
			SELECT @PID=ProductID FROM @TblProducts WHERE ID=@I		

			EXEC [spRPT_AvgRate] 0,@PID,@SubTagSQL,'',@ToDate,@ToDate,0,0,0,0,'',0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
			
			IF @BalQty IS NOT NULL
			BEGIN
				INSERT INTO @TblAvgRate(ProductID,BalQty,AvgRate,BalValue)
				SELECT @PID,@BalQty,@AvgRate,@BalValue
			END
			SET @I=@I+1
		END		
	END
	ELSE
	BEGIN
		SELECT @TCNT=COUNT(*) FROM @TblTagList	
		WHILE(@I<=@COUNT)
		BEGIN
			SELECT @PID=ProductID,@TI=1 FROM @TblProducts WHERE ID=@I
			
			WHILE(@TI<=@TCNT)
			BEGIN
				SELECT @NodeID=NodeID FROM @TblTagList WHERE ID=@TI
						
				if len(@AvgRateWHERE)>0
					SET @SubTagSQL=@AvgRateWHERE + ' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+'='+CONVERT(NVARCHAR,@NodeID)		
				else
					set @SubTagSQL=''

				--TO GET BALANCE DATA
				EXEC [spRPT_AvgRate] 0,@PID,@SubTagSQL,'',@ToDate,@ToDate,0,0,0,0,'',0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
				
				INSERT INTO @TblAvgRate(ProductID,TagID,BalQty,AvgRate,BalValue)
				SELECT @PID,@NodeID,@BalQty,@AvgRate,@BalValue
				WHERE @BalQty IS NOT NULL
				
				SET @TI=@TI+1
			END

			SET @I=@I+1
		END
	END


	/******* Expected Quantity Calculation *******/
	IF @ExpectedQTY1<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrdersWithTransfer(@ExpectedQTY1,@ProductID,1,@CCWHERE,@DimColumn)
		PRINT(@Query)
		IF @DimensionID>0
			INSERT INTO @TblPendingOrders(ProductID,ExpQty1,TagID)
			EXEC(@Query)
		ELSE
			INSERT INTO @TblPendingOrders(ProductID,ExpQty1)
			EXEC(@Query)
	END	
	IF @ExpectedQTY2<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrdersWithTransfer(@ExpectedQTY2,@ProductID,1,@CCWHERE,@DimColumn)
		IF @DimensionID>0
			INSERT INTO @TblPendingOrders(ProductID,ExpQty2,TagID)
			EXEC(@Query)
		ELSE
			INSERT INTO @TblPendingOrders(ProductID,ExpQty2)
			EXEC(@Query)
	END	
	IF @ExpectedQTY3<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrdersWithTransfer(@ExpectedQTY3,@ProductID,1,@CCWHERE,@DimColumn)
		IF @DimensionID>0
			INSERT INTO @TblPendingOrders(ProductID,ExpQty3,TagID)
			EXEC(@Query)
		ELSE
			INSERT INTO @TblPendingOrders(ProductID,ExpQty3)
			EXEC(@Query)
	END
	
	/******* Commited Quantity Calculation *******/
	IF @CommitedQTY1<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrdersWithTransfer(@CommitedQTY1,@ProductID,-1,@CCWHERE,@DimColumn)
		IF @DimensionID>0
			INSERT INTO @TblPendingOrders(ProductID,ComQTy1,TagID)
			EXEC(@Query)
		ELSE
			INSERT INTO @TblPendingOrders(ProductID,ComQTy1)
			EXEC(@Query)
	END	
	IF @CommitedQTY2<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrdersWithTransfer(@CommitedQTY2,@ProductID,-1,@CCWHERE,@DimColumn)
		IF @DimensionID>0
			INSERT INTO @TblPendingOrders(ProductID,ComQTy2,TagID)
			EXEC(@Query)
		ELSE
			INSERT INTO @TblPendingOrders(ProductID,ComQTy2)
			EXEC(@Query)
	END	
	IF @CommitedQTY3<>''
	BEGIN
		SET @Query=dbo.fnGetPendingOrdersWithTransfer(@CommitedQTY3,@ProductID,-1,@CCWHERE,@DimColumn)
		IF @DimensionID>0
			INSERT INTO @TblPendingOrders(ProductID,ComQTy3,TagID)
			EXEC(@Query)
		ELSE
			INSERT INTO @TblPendingOrders(ProductID,ComQTy3)
			EXEC(@Query)
	END
	--select * from @TblPendingOrders

	/******* Average Sales Calculation *******/
	IF @SalesDocs<>''
	BEGIN
		/*IF @MonthFromDate IS NULL
		BEGIN
			IF @DontApplyDateFilter=0
				SET @MonthFromDate=@FromDate
			ELSE
			BEGIN
				declare @minDocDate int
					SET @Query='SELECT @minDocDate=min(DocDate) FROM INV_DocDetails A WITH(NOLOCK) '+@CCWHERE+'
				WHERE A.ProductID IN ('+@ProductID+') AND A.CostCenterID IN('+@SalesDocs+')
					AND DocDate<='+CONVERT(NVARCHAR,CONVERT(INT,@ToDate))+' AND A.StatusID<>438'
				exec sp_executesql @Query,N'@minDocDate int output', @minDocDate OUTPUT
print(@Query)
				IF @minDocDate IS NULL OR @minDocDate=0
					SET @MonthFromDate=CONVERT(DATETIME,@minDocDate)
				ELSE
					SET @MonthFromDate=@ToDate				
			END
		END*/

		SET @StDate=@MonthFromDate		
		SET @Query=''
		SET @I=0
		
		WHILE(@StDate<=@ToDate)
		BEGIN

			SET @EndDate=dateadd(dd,-1,dateadd(mm,1,@StDate))
			IF @EndDate>@ToDate
				SET @EndDate=@ToDate
			
			--SELECT @StDate,@EndDate
			IF len(@Query)>0
				SET @Query=@Query+'
				 UNION ALL '
				 
			SET @Query=@Query+'
			SELECT A.ProductID'+@DimColAlias+','+CONVERT(NVARCHAR,@I)+' Mn,SUM('+@SaleColumn+'*-VoucherType) Qty
		FROM INV_DocDetails A WITH(NOLOCK) '+@CCWHERE+'
		WHERE A.ProductID IN ('+@ProductID+') AND A.CostCenterID IN('+@SalesDocs+')
			AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))
			+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+') AND A.StatusID<>438	AND A.StatusID<>376
		GROUP BY A.ProductID'+@DimColumn
			
			IF @StDate=@MonthFromDate
			BEGIN
				SET @StDate=dateadd(mm,1,@StDate)-(datepart(dd,@MonthFromDate)-1)
			END
			ELSE
				SET @StDate=dateadd(mm,1,@StDate)	
			SET @I=@I+1
		END
		
		--print @Query
		IF @DimensionID>0
			INSERT INTO @TblAvgSale(ProductID,TagID,Mn,Qty)	
			EXEC(@Query)
		ELSE
			INSERT INTO @TblAvgSale(ProductID,Mn,Qty)	
			EXEC(@Query)
		--print @Query
		IF @DontApplyDateFilter=0
			SET @Query='SELECT A.ProductID'+@DimColAlias+',-1 Mn,SUM('+@SaleColumn+'*-VoucherType) Qty
		FROM INV_DocDetails A WITH(NOLOCK) '+@CCWHERE+'
		WHERE A.ProductID IN ('+@ProductID+') AND A.CostCenterID IN('+@SalesDocs+')
			AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@FromDate))
			+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@ToDate))+') AND A.StatusID<>438 AND A.StatusID<>376
		GROUP BY A.ProductID'+@DimColumn
		ELSE
			SET @Query='SELECT A.ProductID'+@DimColAlias+',-1 Mn,SUM('+@SaleColumn+'*-VoucherType) Qty
		FROM INV_DocDetails A WITH(NOLOCK) '+@CCWHERE+'
		WHERE A.ProductID IN ('+@ProductID+') AND A.CostCenterID IN('+@SalesDocs+')
			AND DocDate<='+CONVERT(NVARCHAR,CONVERT(INT,@ToDate))+' AND A.StatusID<>438	AND A.StatusID<>376	
		GROUP BY A.ProductID'+@DimColumn
		
		IF @DimensionID>0
			INSERT INTO @TblAvgSale(ProductID,TagID,Mn,Qty)	
			EXEC(@Query)
		ELSE
			INSERT INTO @TblAvgSale(ProductID,Mn,Qty)	
			EXEC(@Query)
		--print(@Query)
			
		set @SalesDocs=' AND A.CostCenterID IN('+@SalesDocs+')'
	END	
	
	DECLARE @WHERE NVARCHAR(MAX),@OrderBY NVARCHAR(MAX)
	SET @I=50000       
	SET @COUNT=50050
	SET @WHERE='WEF<='+CONVERT(NVARCHAR,CONVERT(FLOAT,@ToDate))+' and ProductID=@PID'	
	WHILE(@I<@COUNT)
	BEGIN
		SET @I=@I+1      
		set @OrderBY=@OrderBY+',CCNID'+convert(nvarchar,@I-50000)      
		
		SET @WHERE=@WHERE+' AND CCNID'+convert(nvarchar,@I-50000)+'='
		IF @I=@DimensionID
			SET @WHERE=@WHERE+'@TAGID'
		ELSE
			SET @WHERE=@WHERE+'0'
	END
        
	DECLARE @ReorderLevel FLOAT,@ReorderQty FLOAT,@SellingPrice FLOAT,@EDATE FLOAT,@LastPrice FLOAT
	 
	SELECT @I=1,@COUNT=COUNT(*),@EDATE=CONVERT(FLOAT,@ToDate) FROM @TblProducts
	IF @DimensionID=0
	BEGIN	
		DECLARE @SQL NVARCHAR(MAX)=''
		select @SQL=@SQL+' AND '+name+'=0' 
		from sys.columns WITH(NOLOCK)
		where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
			
		WHILE(@I<=@COUNT)
		BEGIN			
			SELECT @PID=ProductID,@ReorderLevel=NULL,@ReorderQty=NULL FROM @TblProducts WHERE ID=@I		
			
			--Reorder Level
			SET @Query='SET @ReorderLevel=(SELECT TOP 1 ReorderLevel FROM COM_CCPrices with(nolock)
			WHERE WEF<='+CONVERT(NVARCHAR(MAX),@EDATE)+' and ProductID='+CONVERT(NVARCHAR,@PID)+' AND ReorderLevel>0
			'+@SQL+'	
			ORDER BY WEF DESC)'
			
			EXEC sp_executesql @Query,N'@ReorderLevel FLOAT OUTPUT',@ReorderLevel OUTPUT
			
			IF @ReorderLevel IS NULL
				SELECT @ReorderLevel=ReorderLevel FROM INV_Product with(nolock) WHERE ProductID=@PID 
			
			--Reorder Qty
			SET @Query='SET @ReorderQty=(SELECT TOP 1 ReorderQty FROM COM_CCPrices with(nolock)
			WHERE WEF<='+CONVERT(NVARCHAR(MAX),@EDATE)+' and ProductID='+CONVERT(NVARCHAR,@PID)+' AND ReorderQty>0
			'+@SQL+'	
			ORDER BY WEF DESC)'
			
			EXEC sp_executesql @Query,N'@ReorderQty FLOAT OUTPUT',@ReorderQty OUTPUT
			
			IF @ReorderQty IS NULL
				SELECT @ReorderQty=ReorderQty FROM INV_Product with(nolock) WHERE ProductID=@PID
			
			--Selling Price
			SET @Query='SET @SellingPrice=(SELECT TOP 1 SellingRate FROM COM_CCPrices with(nolock)
			WHERE WEF<='+CONVERT(NVARCHAR(MAX),@EDATE)+' and ProductID='+CONVERT(NVARCHAR,@PID)+' AND SellingRate>0
			'+@SQL+'	
			ORDER BY WEF DESC)'
			
			EXEC sp_executesql @Query,N'@SellingPrice FLOAT OUTPUT',@SellingPrice OUTPUT
			
			IF @SellingPrice IS NULL
				SELECT @SellingPrice=SellingRate FROM INV_Product with(nolock) WHERE ProductID=@PID 
				
			SET @Query='SELECT TOP 1 @LastPrice=A.Rate FROM INV_DocDetails A with(nolock) '+@CCWHERE+'
WHERE A.ProductID='+CONVERT(NVARCHAR,@PID )+@SalesDocs+' AND A.DocDate<=CONVERT(float,getdate()) ORDER BY A.DocDate desc'
			EXEC sp_executesql @Query,N' @LastPrice FLOAT OUTPUT',@LastPrice OUTPUT  

			
			--IF @ReorderQty IS NOT NULL
				INSERT INTO @TblReorder(ProductID,ReOrderLevel,ReorderQty,SellingPrice,LastPrice)
				SELECT @PID,@ReorderLevel,@ReorderQty,@SellingPrice,@LastPrice
		
			SET @I=@I+1
		END		
	END
	ELSE
	BEGIN
		SELECT @TCNT=COUNT(*) FROM @TblTagList	
		WHILE(@I<=@COUNT)
		BEGIN
			SELECT @PID=ProductID,@TI=1 FROM @TblProducts WHERE ID=@I
		
			WHILE(@TI<=@TCNT)
			BEGIN
				SELECT @NodeID=NodeID FROM @TblTagList WHERE ID=@TI
				
				SET @Query='DECLARE @ReorderLevel FLOAT,@ReorderQty FLOAT,@SellingPrice FLOAT,@LastPrice FLOAT,@PID BIGINT,@TAGID BIGINT,@TempTAGID BIGINT
SET @PID='+CONVERT(NVARCHAR,@PID)+'
SET @TempTAGID='+CONVERT(NVARCHAR,@NodeID)+'
SET @TAGID=@TempTAGID
SELECT TOP 1 @ReorderLevel=ReorderLevel FROM COM_CCPrices with(nolock) WHERE ReorderLevel>0 AND '+@WHERE+' ORDER BY WEF DESC 

SELECT TOP 1 @ReorderQty=ReorderQty FROM COM_CCPrices with(nolock) WHERE ReorderQty>0 AND '+@WHERE+' ORDER BY WEF DESC 

SELECT TOP 1 @SellingPrice=SellingRate FROM COM_CCPrices with(nolock) WHERE SellingRate>0 AND '+@WHERE+' ORDER BY WEF DESC 

SELECT TOP 1 @LastPrice=A.Rate FROM INV_DocDetails A with(nolock) '+@CCWHERE+'
WHERE A.ProductID=@PID '+@SalesDocs+' AND '+replace(@DimColumn,',','')+'=@TempTAGID AND A.DocDate<=CONVERT(float,getdate())  
ORDER BY A.DocDate desc
--A.IsQtyIgnored=0 and A.VoucherType=1 and 

IF @ReorderLevel IS NOT NULL OR @ReorderQty IS NOT NULL OR @SellingPrice IS NOT NULL OR @LastPrice IS NOT NULL
	SELECT @PID,@TempTAGID,@ReorderLevel,@ReorderQty,@SellingPrice,@LastPrice'
--print(@Query)
				INSERT INTO @TblReorder(ProductID,TagID,ReorderLevel,ReorderQty,SellingPrice,LastPrice)
				EXEC(@Query)	
				SET @TI=@TI+1
			END

			SET @I=@I+1
		END
	END
	--print(@Query)
	--select * from @TblReorder
    
    if @GroupProduct IS NOT NULL
    begin
		update @TblPendingOrders set productid=@GroupProduct
		
		--QOH
		insert into @TblQOH
		select -123,TagID,sum(Qty) from @TblQOH group by TagID
		delete from @TblQOH where productid<>-123
		update @TblQOH set productid=@GroupProduct
		
		--BalQty
		insert into @TblBalanceQty
		select -123,sum(Qty) from @TblBalanceQty
		delete from @TblBalanceQty where productid<>-123
		update @TblBalanceQty set productid=@GroupProduct
		
		--AvgRate,BalValue
		insert into @TblAvgRate
		select -123,TagID,sum(BalQty),0,sum(BalValue) from @TblAvgRate group by TagID
		delete from @TblAvgRate where productid<>-123
		update @TblAvgRate set productid=@GroupProduct
		
		--Reorder
		insert into @TblReorder
		select -123,TagID,sum(ReorderLevel),sum(ReOrderQty),0,0 from @TblReorder group by TagID
		
		delete from @TblReorder where productid<>-123
		update @TblReorder set productid=@GroupProduct
		
		update @TblAvgSale set productid=@GroupProduct
		
		delete from @TblProducts where ID>1		
		set @ProductID=@GroupProduct		
    end
    

	/******* FINAL DATA *******/
	IF @DimensionID>0
		SELECT P.ProductID,TP.Name TAG,TP.NodeID TagID--ProductCode,ProductName,
			,ISNULL(BQ.Qty,0) BalanceQty,ISNULL(QOH.Qty,0) QOH--,AVR.BalQty QOH
			,PC.ReorderLevel,PC.ReorderQty,PC.SellingPrice,PC.LastPrice
			,AVR.AvgRate,AVR.BalValue
			,PO.ExpQty1,PO.ExpQty2,PO.ExpQty3,PO.ComQty1,PO.ComQty2,PO.ComQty3
		FROM (SELECT P.ID,P.ProductID,NodeID,Name FROM @TblProducts P,@TblTagList) AS TP
			INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=TP.ProductID
			LEFT JOIN (SELECT ProductID,TagID,SUM(ExpQty1) ExpQty1,SUM(ExpQty2) ExpQty2,SUM(ExpQty3) ExpQty3
					,SUM(ComQty1) ComQty1,SUM(ComQty2) ComQty2,SUM(ComQty3) ComQty3
					FROM @TblPendingOrders
					GROUP BY ProductID,TagID) AS PO ON TP.ProductID=PO.ProductID AND PO.TagID=TP.NodeID
			LEFT JOIN @TblQOH QOH ON TP.ProductID=QOH.ProductID AND QOH.TagID=TP.NodeID
			LEFT JOIN @TblBalanceQty BQ ON P.ProductID=BQ.ProductID
			LEFT JOIN @TblAvgRate AVR ON TP.ProductID=AVR.ProductID AND AVR.TagID=TP.NodeID
			LEFT JOIN @TblReorder PC ON P.ProductID=PC.ProductID AND PC.TagID=TP.NodeID

		ORDER BY TP.ID
	ELSE
		SELECT P.ProductID,P.ReorderQty,P.ReorderLevel
			,ISNULL(BQ.Qty,0) BalanceQty,ISNULL(QOH.Qty,0) QOH--,AVR.BalQty QOH
			,AVR.AvgRate,AVR.BalValue
			,PC.ReorderLevel,PC.ReorderQty,PC.SellingPrice,PC.LastPrice			
			,PO.ExpQty1,PO.ExpQty2,PO.ExpQty3,PO.ComQty1,PO.ComQty2,PO.ComQty3
		FROM @TblProducts AS TP INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=TP.ProductID
			LEFT JOIN (SELECT ProductID,SUM(ExpQty1) ExpQty1,SUM(ExpQty2) ExpQty2,SUM(ExpQty3) ExpQty3
					,SUM(ComQty1) ComQty1,SUM(ComQty2) ComQty2,SUM(ComQty3) ComQty3
					FROM @TblPendingOrders
					GROUP BY ProductID,TagID) AS PO ON P.ProductID=PO.ProductID
			LEFT JOIN @TblQOH QOH ON P.ProductID=QOH.ProductID
			LEFT JOIN @TblBalanceQty BQ ON P.ProductID=BQ.ProductID
			LEFT JOIN @TblAvgRate AVR ON TP.ProductID=AVR.ProductID
			LEFT JOIN @TblReorder PC ON P.ProductID=PC.ProductID
		ORDER BY TP.ID
		
	SET @Query='SELECT P.ProductID,P.ProductCode,P.ProductName'+@SELECT+' 
	FROM INV_Product P with(nolock) '+@FROM+' WHERE P.ProductID IN ('+@ProductID+')'
	EXEC(@Query)
	
	if @GroupProduct IS NOT NULL
		SELECT ProductID,TagID,Mn,sum(Qty) Qty from @TblAvgSale
		WHERE Mn!=-1
		GROUP By ProductID,TagID,Mn
		Order By ProductID,TagID
	else
		SELECT ProductID,TagID,Mn,Qty from @TblAvgSale
		WHERE Mn!=-1
		Order By ProductID,TagID
	
	SELECT ProductID,TagID,SUM(Qty) Qty from @TblAvgSale
	WHERE Mn=-1
	GROUP By ProductID,TagID

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
