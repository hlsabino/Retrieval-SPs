USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_ReOrderLevel]
	@ProductID [nvarchar](max),
	@ToDateFilter [datetime] = null,
	@IsGroupWise [bit],
	@ExpectedQTY1 [nvarchar](200),
	@ExpectedQTY2 [nvarchar](200),
	@ExpectedQTY3 [nvarchar](200),
	@CommitedQTY1 [nvarchar](200),
	@CommitedQTY2 [nvarchar](200),
	@CommitedQTY3 [nvarchar](200),
	@SalesDocs [nvarchar](200),
	@SalesFromDate [datetime],
	@SalesToDate [datetime],
	@Slot1 [int],
	@Slot2 [int],
	@Slot3 [int],
	@CCWHERE [nvarchar](max),
	@DimensionID [int],
	@Locations [nvarchar](max),
	@AvgLocations [nvarchar](max),
	@ReorderLocations [nvarchar](max),
	@HiddenFields [nvarchar](max),
	@SelectedLocation [int],
	@SalesCostField [nvarchar](40),
	@SalesValueField [nvarchar](40),
	@SELECT [nvarchar](max),
	@FROM [nvarchar](max),
	@ExpiryWhere [nvarchar](max),
	@ExpirySlab [nvarchar](max) = '',
	@DontShowExUnApproved [bit],
	@PostedQtyFor [nvarchar](max) = '',
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON
	--Declaration Section
	DECLARE @TblQOH AS TABLE(ProductID INT,Qty FLOAT)
	DECLARE @TblBalanceQty AS TABLE(ProductID INT,TagID INT,Qty FLOAT)
	DECLARE @TblAvgRate AS TABLE(ProductID INT,TagID INT,BalanceQty FLOAT,AvgRate FLOAT,BalValue FLOAT)

	DECLARE @TblAvgSale AS TABLE(ProductID INT,TagID INT,CY1 FLOAT,CY2 FLOAT,CY3 FLOAT,CYAvgSale FLOAT,TotalSaleQty FLOAT,FC1 FLOAT,FC2 FLOAT,FC3 FLOAT,FCPYAvgSale FLOAT)
	DECLARE @TblSale AS TABLE(ProductID INT,TagID INT default(-1),SLQ1 FLOAT,SLQ2 FLOAT,SLQ3 FLOAT,SLV1 FLOAT,SLV2 FLOAT,SLV3 FLOAT,SLC1 FLOAT,SLC2 FLOAT,SLC3 FLOAT)
	DECLARE @TblBatch AS TABLE(ProductID INT,BEx0 FLOAT,BEx1 FLOAT,BEx2 FLOAT,BExGreater FLOAT)
	CREATE TABLE #TblReorder(ProductID INT,TagID INT,ReorderLevel FLOAT,ReorderQty FLOAT,SellingPrice FLOAT,LastPrice FLOAT,MaxInventoryLevel FLOAT)
	DECLARE @TblPendingOrders AS TABLE(ProductID INT,ExpQty1 FLOAT,ExpQty2 FLOAT,ExpQty3 FLOAT,ComQty1 FLOAT,ComQty2 FLOAT,ComQty3 FLOAT,TagID INT)
	CREATE TABLE #TblProducts(ID INT IDENTITY(1,1) NOT NULL,ProductID INT,PreexpiryDays INT,ParentID INT)
	CREATE TABLE #TblGroups(ID INT IDENTITY(1,1) NOT NULL,ProductID INT)
	DECLARE @Query nvarchar(MAX),@ToDate DATETIME,@StDate DATETIME,@EndDate DATETIME,@ProductIDCol nvarchar(50)
	DECLARE @TblTagList AS TABLE(ID INT IDENTITY(1,1) NOT NULL,NodeID INT)
	DECLARE @TblTagSelected AS TABLE(ID INT IDENTITY(1,1) NOT NULL,NodeID INT)
	DECLARE @TCNT INT,@PID INT,@TI INT,@NodeID INT,@SubTagSQL NVARCHAR(MAX)
	DECLARE @ReorderLevel FLOAT,@ReorderQty FLOAT,@SellingPrice FLOAT,@LastPrice FLOAT,@EDATE FLOAT,@DimWhere NVARCHAR(MAX),@DimCol NVARCHAR(MAX),@MaxInventoryLevel float
	DECLARE @TblCalc AS TABLE(Name NVARCHAR(50))

	IF @ToDateFilter is not null
		SET @ToDate=@ToDateFilter
	ELSE
	BEGIN
		SET @ToDate=getdate()
		SET @ToDate=CONVERT(DATETIME, CONVERT(NVARCHAR,DATEPART(day,@ToDate))+' '+datename(month,@ToDate)+' '+CONVERT(NVARCHAR,DATEPART(year,@ToDate)))
	END
	
	IF @SalesToDate is null
		set @SalesToDate=@ToDate
	
	IF @IsGroupWise=1
	BEGIN
		SET @ProductIDCol='TP.ParentID'
		SET @Query='select ProductID,ParentID from INV_Product with(nolock) where ParentID in ('+@ProductID+')'
		INSERT INTO #TblProducts(ProductID,ParentID)
		EXEC(@Query)
		
		INSERT INTO #TblGroups(ProductID)
		EXEC SPSplitString @ProductID,','
	END
	ELSE
	BEGIN
		SET @ProductIDCol='A.ProductID'
		INSERT INTO #TblProducts(ProductID)
		EXEC SPSplitString @ProductID,','
	END
	
	if @ExpiryWhere like '%TP.PreexpiryDays%'
	begin
		update #TblProducts
		set PreexpiryDays=floor(convert(float,getdate()))+ isnull(P.PreexpiryDays,0) 
		from #TblProducts TP 
		inner join INV_Product P with(nolock) ON P.ProductID=TP.ProductID
	end
	
	INSERT INTO @TblCalc(Name)
	EXEC SPSplitString @HiddenFields,','
	
	INSERT INTO @TblTagList(NodeID)
	EXEC SPSplitString @Locations,','
	
	INSERT INTO @TblTagList(NodeID) VALUES(-1)
	
	set @DimWhere=''
	IF len(@CCWHERE)>0 OR @DimensionID>0
	BEGIN
		set @DimWhere=@CCWHERE
		SET @CCWHERE=' INNER JOIN COM_DocCCData DCC with(nolock) ON A.InvDocDetailsID=DCC.InvDocDetailsID '	+@CCWHERE		
	END

	if(@DimensionID>0)
		set @DimCol=',DCC.dcCCNID'+convert(nvarchar,@DimensionID-50000)
	else
		set @DimCol=',DCC.dcCCNID2'

	/******* QOH Calculation *******/
	/*SET @Query='SELECT A.ProductID, SUM(UOMConvertedQty*VoucherType)
	FROM INV_DocDetails A WITH(NOLOCK) 
	WHERE A.ProductID IN ('+@ProductID+') AND (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0
	GROUP BY A.ProductID'*/
	if @ExpiryWhere=''
		SET @Query='SELECT '+@ProductIDCol+', SUM(UOMConvertedQty*VoucherType)
		FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID
		WHERE (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0'
	else
	begin
		SET @Query='SELECT '+@ProductIDCol+', SUM(A.UOMConvertedQty*A.VoucherType)
		FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID
		left join INV_Batches B on B.BatchID=A.BatchID
		WHERE (A.VoucherType=1 OR A.VoucherType=-1) AND A.IsQtyIgnored=0 '+@ExpiryWhere
	end
	if @PostedQtyFor like '%(QOH)%'
		set @Query=@Query+' and A.StatusID=369'
	else
		set @Query=@Query+' and A.StatusID<>376 AND A.StatusID<>372'
	set @Query=@Query+' and A.DocDate<='+convert(nvarchar,convert(int,@ToDate))
	set @Query=@Query+' GROUP BY '+@ProductIDCol

	INSERT INTO @TblQOH(ProductID,Qty)
	EXEC(@Query)
	
	/******* Balance Quantity Calculation *******/
	if (select COUNT(*) from @TblCalc where Name='BalanceQty')=0
	begin
		if @ExpiryWhere=''
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID, SUM(UOMConvertedQty*VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0'
		else
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID, SUM(A.UOMConvertedQty*A.VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			left join INV_Batches B on B.BatchID=A.BatchID  
			WHERE (A.VoucherType=1 OR A.VoucherType=-1) AND A.IsQtyIgnored=0'+@ExpiryWhere	
		if @PostedQtyFor like '%(BalQty)%'
			set @Query=@Query+' and A.StatusID=369'
		else
			set @Query=@Query+' and A.StatusID<>376 AND A.StatusID<>372'
		set @Query=@Query+' and A.DocDate<='+convert(nvarchar,convert(int,@ToDate))
		set @Query=@Query+' GROUP BY '+@ProductIDCol+@DimCol
		--print(@Query)
		INSERT INTO @TblBalanceQty(ProductID,TagID,Qty)		
		EXEC(@Query)
		
		--select * from @TblBalanceQty
		----BalQty ALL Locations
		insert into @TblBalanceQty
		select ProductID,-1 TagID,sum(Qty) from @TblBalanceQty
		group by ProductID
	end
	
	/******* Expected Quantity Calculation *******/
	IF @ExpectedQTY1<>'' and (select COUNT(*) from @TblCalc where Name='ExpQty1')=0
	BEGIN		
		SET @Query=dbo.fnGetPendingQtyQueryForReorder(@ExpectedQTY1,@CCWHERE,@DimCol,@DontShowExUnApproved)
		INSERT INTO @TblPendingOrders(ProductID,ExpQty1,TagID)
		EXEC(@Query)
		
	END	
	IF @ExpectedQTY2<>'' and (select COUNT(*) from @TblCalc where Name='ExpQty2')=0
	BEGIN
		SET @Query=dbo.fnGetPendingQtyQueryForReorder(@ExpectedQTY2,@CCWHERE,@DimCol,@DontShowExUnApproved)
		INSERT INTO @TblPendingOrders(ProductID,ExpQty2,TagID)
		EXEC(@Query)
	END	
	IF @ExpectedQTY3<>'' and (select COUNT(*) from @TblCalc where Name='ExpQty3')=0
	BEGIN
		SET @Query=dbo.fnGetPendingQtyQueryForReorder(@ExpectedQTY3,@CCWHERE,@DimCol,@DontShowExUnApproved)
		INSERT INTO @TblPendingOrders(ProductID,ExpQty3,TagID)
		EXEC(@Query)
	END

	
	/******* Commited Quantity Calculation *******/
	IF @CommitedQTY1<>'' and (select COUNT(*) from @TblCalc where Name='ComQty1')=0
	BEGIN		
		SET @Query=dbo.fnGetPendingQtyQueryForReorder(@CommitedQTY1,@CCWHERE,@DimCol,@DontShowExUnApproved)
		INSERT INTO @TblPendingOrders(ProductID,ComQTy1,TagID)
		EXEC(@Query)
	END	
	IF @CommitedQTY2<>'' and (select COUNT(*) from @TblCalc where Name='ComQty2')=0
	BEGIN
		SET @Query=dbo.fnGetPendingQtyQueryForReorder(@CommitedQTY2,@CCWHERE,@DimCol,@DontShowExUnApproved)
		INSERT INTO @TblPendingOrders(ProductID,ComQTy2,TagID)
		EXEC(@Query)
	END	
	IF @CommitedQTY3<>'' and (select COUNT(*) from @TblCalc where Name='ComQty3')=0
	BEGIN
		SET @Query=dbo.fnGetPendingQtyQueryForReorder(@CommitedQTY3,@CCWHERE,@DimCol,@DontShowExUnApproved)
		INSERT INTO @TblPendingOrders(ProductID,ComQTy3,TagID)
		EXEC(@Query)
	END
	
	if @ExpirySlab!=''
	begin
		declare @XML xml,@EX1 int,@EX2 int,@EX3 int
		set @XML=@ExpirySlab
		select @EX1=isnull(X.value('@S0','int'),0),@EX2=X.value('@S1','int'),@EX3=X.value('@S2','int')
		from @XML.nodes('/Exp') as data(x)
		set @Query='declare @AsOn FLOAT
		declare @Tbl As Table(ID INT,FromDate FLOAT,ToDate FLOAT)
		set @AsOn=CONVERT(FLOAT,getdate())
		--INSERT INTO @Tbl VALUES(-1,0,@AsOn-1)
		INSERT INTO @Tbl VALUES(0,@AsOn,@AsOn+'+convert(nvarchar,@EX1-1)+')'
		if(@EX2 is not null)
			set @Query=@Query+' INSERT INTO @Tbl VALUES(1,@AsOn+'+convert(nvarchar,@EX1)+',@AsOn+'+convert(nvarchar,@EX2-1)+')'
		if(@EX3 is not null)
			set @Query=@Query+' INSERT INTO @Tbl VALUES(2,@AsOn+'+convert(nvarchar,@EX2)+',@AsOn+'+convert(nvarchar,@EX3-1)+')'
		--INSERT INTO @Tbl VALUES(3,@AsOn+'+convert(nvarchar,@EX3)+',123456)
		set @Query=@Query+'
		select ProductID,sum(BEx0) BEx0,sum(BEx1) BEx1,sum(BEx2) BEx2,sum(BExGreater) BExGreater from (
		SELECT '+@ProductIDCol+' ProductID--,T.ID,SUM(A.UOMConvertedQty*A.VoucherType) Quantity
		,case when T.ID=0 then SUM(A.UOMConvertedQty*A.VoucherType) else null end BEx0
		,case when T.ID=1 then SUM(A.UOMConvertedQty*A.VoucherType) else null end BEx1
		,case when T.ID=2 then SUM(A.UOMConvertedQty*A.VoucherType) else null end BEx2
		,case when T.ID=3 then SUM(A.UOMConvertedQty*A.VoucherType) else null end BExGreater
		FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID
		JOIN INV_Batches B WITH(NOLOCK) ON B.BatchID=A.BatchID
		JOIN @Tbl T ON B.ExpiryDate BETWEEN T.FromDate AND T.ToDate '+@CCWHERE+'
		WHERE A.BatchID>1 and (A.VoucherType=1 or A.VoucherType=-1) and A.IsQtyIgnored=0 AND A.DocDate<=@AsOn and B.ExpiryDate is not null AND A.StatusID<>438 AND A.StatusID<>372 AND A.StatusID<>376
		GROUP BY '+@ProductIDCol+',T.ID)AS T group by ProductID'
		--print(@Query)
		insert into @TblBatch
		EXEC(@Query)	
	end
	
	--For All Locations
	IF @IsGroupWise=1
		INSERT INTO @TblPendingOrders(ProductID,ExpQty1,ExpQty2,ExpQty3,ComQTy1,ComQTy2,ComQTy3,TagID)
		SELECT TP.ParentID,SUM(ExpQty1),SUM(ExpQty2),SUM(ExpQty3),SUM(ComQTy1),SUM(ComQTy2),SUM(ComQTy3),-1 
		FROM @TblPendingOrders T
		JOIN #TblProducts TP on T.ProductID=Tp.ProductID
		GROUP BY TP.ParentID
	ELSE
		INSERT INTO @TblPendingOrders(ProductID,ExpQty1,ExpQty2,ExpQty3,ComQTy1,ComQTy2,ComQTy3,TagID)
		SELECT ProductID,SUM(ExpQty1),SUM(ExpQty2),SUM(ExpQty3),SUM(ComQTy1),SUM(ComQTy2),SUM(ComQTy3),-1 FROM @TblPendingOrders
		GROUP BY ProductID

	/******* Current Year Slots Calculation *******/
	SET @StDate=CONVERT(DATETIME,'01 jan '+CONVERT(NVARCHAR,year(@SalesToDate)))

	IF @SalesDocs<>''
	BEGIN
		declare @CurrYearMonths FLOAT
		SET @CurrYearMonths=datediff(dd,@StDate,@SalesToDate)/30.0
		IF @CurrYearMonths=0
			SET @CurrYearMonths=1
		declare @SaleStatusWhere nvarchar(100)

		if @PostedQtyFor like '%(SaleQty)%'
			set @SaleStatusWhere=' and A.StatusID=369'
		else
			set @SaleStatusWhere=' AND A.StatusID<>438 AND A.StatusID<>376 AND A.StatusID<>372'

		if (select COUNT(*) from @TblCalc where Name='TotalSaleQty')=0
		begin
		
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@SalesFromDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@SalesToDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblAvgSale(ProductID,TAGID,TotalSaleQty)
			EXEC(@Query)	
		end
		if (select COUNT(*) from @TblCalc where Name='CYAvgSale')=0
		begin
			if (select COUNT(*) from @TblCalc where Name='AvgSaleByTrMn')=1
			begin
				SET @Query='select ProductID,TAGID,round(sum(Qty)/count(*),4) from (SELECT '+@ProductIDCol+@DimCol+' TAGID,month(convert(datetime,A.DocDate)) Mn,SUM(isnull(UOMConvertedQty,0)*-VoucherType) Qty
				FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
				WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@SalesToDate))+')'
				+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol+',month(convert(datetime,A.DocDate))) as T
				GROUP BY ProductID,TAGID'
			end
			else
			begin
				SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(isnull(UOMConvertedQty,0)*-VoucherType)/'+convert(nvarchar,@CurrYearMonths)+'
				FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
				WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@SalesToDate))+')'
				+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			end
			INSERT INTO @TblAvgSale(ProductID,TAGID,CYAvgSale)
			EXEC(@Query)
--			print @Query
		end

		SET @EndDate=@SalesToDate
		SET @StDate=DATEADD(dd,-(@Slot1-1),@SalesToDate)
		if (select COUNT(*) from @TblCalc where Name='CY1')=0
		begin
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblAvgSale(ProductID,TAGID,CY1)
			EXEC(@Query)
		end

		--SET @EndDate=DATEADD(dd,-1,@StDate)
		--SET @StDate=DATEADD(dd,-(@Slot2-1),@EndDate)
		SET @StDate=DATEADD(dd,-@Slot2,@StDate)		
		if (select COUNT(*) from @TblCalc where Name='CY2')=0
		begin		
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblAvgSale(ProductID,TAGID,CY2)
			EXEC(@Query)	
		end
		--SET @EndDate=DATEADD(dd,-1,@StDate)
		--SET @StDate=DATEADD(dd,-(@Slot3-1),@EndDate)
		SET @StDate=DATEADD(dd,-@Slot3,@StDate)
		if (select COUNT(*) from @TblCalc where Name='CY3')=0
		begin
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+')AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblAvgSale(ProductID,TAGID,CY3)
			EXEC(@Query)	
		end
		
		/******* Forecast based on previous Year Slots Calculation *******/
		SET @StDate=CONVERT(DATETIME,'01 jan '+CONVERT(NVARCHAR,year(@SalesToDate)-1))
		SET @EndDate=DATEADD(dd,-1,DATEADD(yy,1,@StDate))

		if (select COUNT(*) from @TblCalc where Name='FCPYAvgSale')=0
		begin
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblAvgSale(ProductID,TAGID,FCPYAvgSale)
			EXEC(@Query)
		end
		
		SET @StDate=DATEADD(yy,-1,@SalesToDate)
		SET @EndDate=DATEADD(dd,(@Slot1-1),@StDate)	
		if (select COUNT(*) from @TblCalc where Name='FC1')=0
		begin
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblAvgSale(ProductID,TAGID,FC1)
			EXEC(@Query)
		end
		--SET @StDate=DATEADD(dd,1,@EndDate)
		--SET @EndDate=DATEADD(dd,(@Slot2-1),@StDate)	
		SET @EndDate=DATEADD(dd,@Slot2,@EndDate)
		if (select COUNT(*) from @TblCalc where Name='FC2')=0
		begin
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblAvgSale(ProductID,TAGID,FC2)
			EXEC(@Query)
		end
		--SET @StDate=DATEADD(dd,1,@EndDate)
		--SET @EndDate=DATEADD(dd,(@Slot3-1),@StDate)
		if (select COUNT(*) from @TblCalc where Name='FC3')=0
		begin
			SET @EndDate=DATEADD(dd,@Slot3,@EndDate)
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblAvgSale(ProductID,TAGID,FC3)
			EXEC(@Query)
		end
		
		if (select COUNT(*) from @TblCalc where Name='SalesQty')=0 or (select COUNT(*) from @TblCalc where Name='SalesValue')=0
			or (select COUNT(*) from @TblCalc where Name='SalesCost')=0 or (select COUNT(*) from @TblCalc where Name='SalesProfit')=0
		begin
			SET @EndDate=@SalesToDate
			SET @StDate=DATEADD(dd,-(@Slot1-1),@SalesToDate)
			
			declare @SaleCost nvarchar(200),@SaleCostFrom nvarchar(200)
			set @SaleCost=''
			if (select COUNT(*) from @TblCalc where Name='SalesCost')=0 or (select COUNT(*) from @TblCalc where Name='SalesProfit')=0
			begin
				set @SaleCost=',sum(ANUM.'+@SalesCostField+'*-VoucherType)'
				set @SaleCostFrom=' inner join COM_DocNumData ANUM with(nolock) on ANUM.InvDocDetailsID=A.InvDocDetailsID'
			end
			else
			begin
				set @SaleCost=',0'
				set @SaleCostFrom=''
			end
			
			if @SalesValueField=''
				set @SalesValueField='Gross'
			if @SalesValueField like 'dcNum%' 
			begin
				set @SalesValueField=',sum(ANUM.'+@SalesValueField+'*-VoucherType)'
				if @SaleCostFrom=''
					set @SaleCostFrom=' inner join COM_DocNumData ANUM with(nolock) on ANUM.InvDocDetailsID=A.InvDocDetailsID'
			end
			else
				set @SalesValueField=',sum('+@SalesValueField+'*-VoucherType)'
		
			--select @StDate,@EndDate
			--SLQ1 FLOAT,SLQ2 FLOAT,SLQ3 FLOAT,SLV1 FLOAT,SLV2 FLOAT,SLV3 FLOAT,SLC1 FLOAT,SLC2 FLOAT,SLC3 FLOAT
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)'+@SalesValueField+@SaleCost+'
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@SaleCostFrom+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			print(@Query)
			INSERT INTO @TblSale(ProductID,TAGID,SLQ1,SLV1,SLC1)
			EXEC(@Query)

			SET @EndDate=DATEADD(dd,-1,@StDate)
			SET @StDate=DATEADD(dd,-@Slot2,@StDate)	
			--select @StDate,@EndDate
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)'+@SalesValueField+@SaleCost+'
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@SaleCostFrom+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate))+' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			--print(@Query)
			INSERT INTO @TblSale(ProductID,TAGID,SLQ2,SLV2,SLC2)
			EXEC(@Query)
			
			SET @EndDate=DATEADD(dd,-1,@StDate)
			SET @StDate=DATEADD(dd,-@Slot3,@StDate)	
			--select @StDate,@EndDate
			SET @Query='SELECT '+@ProductIDCol+@DimCol+' TAGID,SUM(UOMConvertedQty*-VoucherType)'+@SalesValueField+@SaleCost+'
			FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID '+@SaleCostFrom+@CCWHERE+'
			WHERE A.CostCenterID IN('+@SalesDocs+') AND (DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(INT,@StDate)) +' AND '+CONVERT(NVARCHAR,CONVERT(INT,@EndDate))+')'
			+@SaleStatusWhere+' GROUP BY '+@ProductIDCol+@DimCol
			INSERT INTO @TblSale(ProductID,TAGID,SLQ3,SLV3,SLC3)
			EXEC(@Query)
			
			--For All Locations
			INSERT INTO @TblSale(ProductID,TAGID,SLQ1,SLQ2,SLQ3,SLV1,SLV2,SLV3,SLC1,SLC2,SLC3)
			SELECT ProductID,-1,SUM(SLQ1),SUM(SLQ2),SUM(SLQ3),SUM(SLV1),SUM(SLV2),SUM(SLV3),SUM(SLC1),SUM(SLC2),SUM(SLC3) FROM @TblSale
			GROUP BY ProductID
		end	
		
		--For All Locations
		INSERT INTO @TblAvgSale(ProductID,TAGID,CY1,CY2,CY3,CYAvgSale,TotalSaleQty,FC1,FC2,FC3,FCPYAvgSale)
		SELECT ProductID,-1,SUM(CY1),SUM(CY2),SUM(CY3),SUM(CYAvgSale),SUM(TotalSaleQty),SUM(FC1),SUM(FC2),SUM(FC3),SUM(FCPYAvgSale) FROM @TblAvgSale
		GROUP BY ProductID
	END
	--SELECT * FROM @TblAvgSale

	/******* Average Rate Calculation *******/
	DECLARE @I INT,@COUNT INT,@BalQty FLOAT,@AvgRate FLOAT,@BalValue FLOAT,@COGS FLOAT,@TI_START INT
	SELECT @I=1,@COUNT=COUNT(*) FROM #TblProducts
	if (select COUNT(*) from @TblCalc where Name='AvgRate')=0
	begin
		INSERT INTO @TblTagSelected(NodeID)
		EXEC SPSplitString @AvgLocations,','
		SELECT @TCNT=COUNT(*)+MIN(ID)-1,@TI_START=MIN(ID) FROM @TblTagSelected	

		WHILE(@I<=@COUNT)
		BEGIN
			SELECT @PID=ProductID,@TI=@TI_START FROM #TblProducts WHERE ID=@I

			--OVERALL AVG RATE
			SET @SubTagSQL=@DimWhere
			
			IF (SELECT count(*) from @TblAvgRate where ProductID=@PID and TagID=-1)=0
			BEGIN
				--TO GET BALANCE DATA
				EXEC [spRPT_AvgRate] 0,@PID,@SubTagSQL,'',@ToDate,@ToDate,0,0,0,0,'',0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
				
				INSERT INTO @TblAvgRate(ProductID,TagID,BalanceQty,AvgRate,BalValue)
				SELECT @PID,-1,@BalQty,@AvgRate,@BalValue
				WHERE @BalQty IS NOT NULL
			END
			
			WHILE(@TI<=@TCNT)
			BEGIN
				SELECT @NodeID=NodeID FROM @TblTagSelected WHERE ID=@TI
				
				SET @SubTagSQL=@DimWhere+ ' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+'='+CONVERT(NVARCHAR,@NodeID)		
			--	select @SubTagSQL
				IF (SELECT count(*) from @TblAvgRate where ProductID=@PID and TagID=@NodeID)=0
				BEGIN
					--TO GET BALANCE DATA
					EXEC [spRPT_AvgRate] 0,@PID,@SubTagSQL,'',@ToDate,@ToDate,0,0,0,0,'',0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
					
					INSERT INTO @TblAvgRate(ProductID,TagID,BalanceQty,AvgRate,BalValue)
					SELECT @PID,@NodeID,@BalQty,@AvgRate,@BalValue
					WHERE @BalQty IS NOT NULL
				END
				SET @TI=@TI+1
			END

			SET @I=@I+1
		END	
	end
	
	/*********Reorder Level,Reorder Qty,Selling Price,LAST PRICE*********/
	DECLARE @WHERE NVARCHAR(MAX)
	SET @I=50000       
	SET @COUNT=50050
	SET @WHERE='WEF<='+CONVERT(NVARCHAR,CONVERT(FLOAT,@ToDate))+' and ProductID=@PID'	
	WHILE(@I<@COUNT)
	BEGIN
		SET @I=@I+1      
		SET @WHERE=@WHERE+' AND CCNID'+convert(nvarchar,@I-50000)+'='
		IF @I=@DimensionID
			SET @WHERE=@WHERE+'@TAGID'
		ELSE
			SET @WHERE=@WHERE+'0'
	END

	declare @CalcReOrderLevel int,@CalcReOrderQty int,@CalcSellingPrice int,@CalcLastPrice int,@CalcMaxInventoryLevel int
	select @CalcReOrderLevel=COUNT(*) from @TblCalc where Name='ReOrderLevel'
	select @CalcReOrderQty=COUNT(*) from @TblCalc where Name='ReOrderQty'
	select @CalcSellingPrice=COUNT(*) from @TblCalc where Name='SellingPrice'
	select @CalcLastPrice=COUNT(*) from @TblCalc where Name='LastPrice'
	select @CalcMaxInventoryLevel=COUNT(*) from @TblCalc where Name='MaxInventoryLevel'
	
	if @CalcReOrderLevel=0 or @CalcReOrderQty=0 or @CalcSellingPrice=0 or @CalcLastPrice=0 or @CalcMaxInventoryLevel=0
	begin
		SELECT @I=1,@COUNT=COUNT(*),@EDATE=CONVERT(FLOAT,@ToDate) FROM #TblProducts	

		IF @DimensionID=0
		BEGIN	
			DECLARE @SQL NVARCHAR(MAX)=''
			select @SQL=@SQL+' AND '+name+'=0' 
			from sys.columns WITH(NOLOCK)
			where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
		
			WHILE(@I<=@COUNT)
			BEGIN			
				SELECT @PID=ProductID,@ReorderLevel=NULL,@ReorderQty=NULL,@MaxInventoryLevel=NULL FROM #TblProducts WHERE ID=@I		
				
				--Reorder Level
				if @CalcReOrderLevel=0
				begin
					SET @Query='SET @ReorderLevel=(SELECT TOP 1 ReorderLevel FROM COM_CCPrices with(nolock)
					WHERE WEF<='+CONVERT(NVARCHAR(MAX),@EDATE)+' and ProductID='+CONVERT(NVARCHAR,@PID)+' AND ReorderLevel>0 AND (PriceType=0 or PriceType=3)
					'+@SQL+'	
					ORDER BY WEF DESC)'
					
					EXEC sp_executesql @Query,N'@ReorderLevel FLOAT OUTPUT',@ReorderLevel OUTPUT
			
					IF @ReorderLevel IS NULL
						SELECT @ReorderLevel=ReorderLevel FROM INV_Product with(nolock) WHERE ProductID=@PID 
				end
				
				--MaxInventory Level
				if @CalcMaxInventoryLevel=0
				begin
					SET @Query='SET @MaxInventoryLevel=(SELECT TOP 1 MaxInventoryLevel FROM COM_CCPrices with(nolock)
					WHERE WEF<='+CONVERT(NVARCHAR(MAX),@EDATE)+' and ProductID='+CONVERT(NVARCHAR,@PID)+' AND MaxInventoryLevel>0 AND (PriceType=0 or PriceType=3)
					'+@SQL+'	
					ORDER BY WEF DESC)'
					
					EXEC sp_executesql @Query,N'@MaxInventoryLevel FLOAT OUTPUT',@MaxInventoryLevel OUTPUT
			
					IF @MaxInventoryLevel IS NULL
						SELECT @MaxInventoryLevel=MaxInventoryLevel FROM INV_Product with(nolock) WHERE ProductID=@PID 
				end
				
				--Reorder Qty
				if @CalcReOrderQty=0
				begin
					SET @Query='SET @ReorderQty=(SELECT TOP 1 ReorderQty FROM COM_CCPrices with(nolock)
					WHERE WEF<='+CONVERT(NVARCHAR(MAX),@EDATE)+' and ProductID='+CONVERT(NVARCHAR,@PID)+' AND ReorderQty>0 AND (PriceType=0 or PriceType=3)
					'+@SQL+'	
					ORDER BY WEF DESC)'
					
					EXEC sp_executesql @Query,N'@ReorderQty FLOAT OUTPUT',@ReorderQty OUTPUT
			
					IF @ReorderQty IS NULL
						SELECT @ReorderQty=ReorderQty FROM INV_Product with(nolock) WHERE ProductID=@PID
				end
				--Selling Price
				if @CalcSellingPrice=0
				begin
					SET @Query='SET @SellingPrice=(SELECT TOP 1 SellingRate FROM COM_CCPrices with(nolock)
					WHERE WEF<='+CONVERT(NVARCHAR(MAX),@EDATE)+' and ProductID='+CONVERT(NVARCHAR,@PID)+' AND SellingRate>0 AND (PriceType=0 or PriceType=1)
					'+@SQL+'	
					ORDER BY WEF DESC)'
					
					EXEC sp_executesql @Query,N'@SellingPrice FLOAT OUTPUT',@SellingPrice OUTPUT
					
					IF @SellingPrice IS NULL
						SELECT @SellingPrice=SellingRate FROM INV_Product with(nolock) WHERE ProductID=@PID 
				end
				--Last Price
				if @CalcLastPrice=0
				begin
					SELECT TOP 1 @LastPrice=A.Rate FROM INV_DocDetails A with(nolock) 
					WHERE A.IsQtyIgnored=0 and A.VoucherType=1 and A.ProductID=@PID AND A.DocDate<=CONVERT(float,getdate())  
					ORDER BY A.DocDate desc
				end
				
				--IF @ReorderQty IS NOT NULL
				INSERT INTO #TblReorder(ProductID,ReOrderLevel,ReorderQty,SellingPrice,LastPrice,MaxInventoryLevel)
				SELECT @PID,@ReorderLevel,@ReorderQty,@SellingPrice,@LastPrice,@MaxInventoryLevel
			
				SET @I=@I+1
			END		
		END
		ELSE
		BEGIN
		
			DELETE FROM @TblTagSelected
			
			INSERT INTO @TblTagSelected(NodeID)
			EXEC SPSplitString @ReorderLocations,','
			
			IF (select COUNT(*) from @TblTagSelected where NodeID=@SelectedLocation)=0
				INSERT INTO @TblTagSelected(NodeID) VALUES(@SelectedLocation)
	
			SELECT @TCNT=COUNT(*)+MIN(ID)-1,@TI_START=MIN(ID) FROM @TblTagSelected	
			WHILE(@I<=@COUNT)
			BEGIN
			
				SELECT @PID=ProductID,@TI=@TI_START FROM #TblProducts WHERE ID=@I
			
				WHILE(@TI<=@TCNT)
				BEGIN				
					SELECT @NodeID=NodeID FROM @TblTagSelected WHERE ID=@TI
		
					SET @Query='DECLARE @ReorderLevel FLOAT,@MaxInventoryLevel FLOAT,@ReorderQty FLOAT,@SellingPrice FLOAT,@PID INT,@TAGID INT,@TempTAGID INT,@LastPrice FLOAT,@EDATE float
	set @EDATE='+CONVERT(NVARCHAR,CONVERT(FLOAT,@ToDate))+'					
	SET @PID='+CONVERT(NVARCHAR,@PID)+'
	SET @TempTAGID='+CONVERT(NVARCHAR,@NodeID)+'
	SET @TAGID=@TempTAGID
'
	if @CalcReOrderLevel=0
	SET @Query=@Query+'SELECT TOP 1 @ReorderLevel=ReorderLevel FROM COM_CCPrices with(nolock) WHERE ReorderLevel>0 AND (PriceType=0 or PriceType=3) AND '+@WHERE+' ORDER BY WEF DESC 
IF @ReorderLevel IS NULL
	SET @ReorderLevel=(SELECT TOP 1 ReorderLevel FROM COM_CCPrices with(nolock) WHERE WEF<=@EDATE and ProductID=@PID AND ReorderLevel>0 AND (PriceType=0 or PriceType=3) AND CCNID1=0 AND CCNID2=0 AND CCNID3=0 AND CCNID4=0 AND CCNID5=0 AND CCNID6=0 AND CCNID7=0 AND CCNID8=0 AND CCNID9=0 AND CCNID10=0 AND CCNID11=0 AND CCNID12=0 AND CCNID13=0 AND CCNID14=0 AND CCNID15=0 AND CCNID16=0 AND CCNID17=0 AND CCNID18=0 AND CCNID19=0 AND CCNID20=0 AND CCNID21=0 AND CCNID22=0 AND CCNID23=0 AND CCNID24=0 AND CCNID25=0 AND CCNID26=0 AND CCNID27=0 AND CCNID28=0 AND CCNID29=0 AND CCNID30=0 AND CCNID31=0 AND CCNID32=0 AND CCNID33=0 AND CCNID34=0 AND CCNID35=0 AND CCNID36=0 AND CCNID37=0 AND CCNID38=0 AND CCNID39=0 AND CCNID40=0 AND CCNID41=0 AND CCNID42=0 AND CCNID43=0 AND CCNID44=0 AND CCNID45=0 AND CCNID46=0 AND CCNID47=0 AND CCNID48=0 AND CCNID49=0 AND CCNID50=0	ORDER BY WEF DESC)
IF @ReorderLevel IS NULL
	SELECT @ReorderLevel=ReorderLevel FROM INV_Product with(nolock) WHERE ProductID=@PID 
'
if @CalcMaxInventoryLevel=0
	SET @Query=@Query+'SELECT TOP 1 @MaxInventoryLevel=MaxInventoryLevel FROM COM_CCPrices with(nolock) WHERE MaxInventoryLevel>0 AND (PriceType=0 or PriceType=3) AND '+@WHERE+' ORDER BY WEF DESC 
IF @MaxInventoryLevel IS NULL
	SET @MaxInventoryLevel=(SELECT TOP 1 MaxInventoryLevel FROM COM_CCPrices with(nolock) WHERE WEF<=@EDATE and ProductID=@PID AND MaxInventoryLevel>0 AND (PriceType=0 or PriceType=3) AND CCNID1=0 AND CCNID2=0 AND CCNID3=0 AND CCNID4=0 AND CCNID5=0 AND CCNID6=0 AND CCNID7=0 AND CCNID8=0 AND CCNID9=0 AND CCNID10=0 AND CCNID11=0 AND CCNID12=0 AND CCNID13=0 AND CCNID14=0 AND CCNID15=0 AND CCNID16=0 AND CCNID17=0 AND CCNID18=0 AND CCNID19=0 AND CCNID20=0 AND CCNID21=0 AND CCNID22=0 AND CCNID23=0 AND CCNID24=0 AND CCNID25=0 AND CCNID26=0 AND CCNID27=0 AND CCNID28=0 AND CCNID29=0 AND CCNID30=0 AND CCNID31=0 AND CCNID32=0 AND CCNID33=0 AND CCNID34=0 AND CCNID35=0 AND CCNID36=0 AND CCNID37=0 AND CCNID38=0 AND CCNID39=0 AND CCNID40=0 AND CCNID41=0 AND CCNID42=0 AND CCNID43=0 AND CCNID44=0 AND CCNID45=0 AND CCNID46=0 AND CCNID47=0 AND CCNID48=0 AND CCNID49=0 AND CCNID50=0	ORDER BY WEF DESC)
IF @MaxInventoryLevel IS NULL
	SELECT @MaxInventoryLevel=MaxInventoryLevel FROM INV_Product with(nolock) WHERE ProductID=@PID 
'
PRINT @Query
	if @CalcReOrderQty=0
	SET @Query=@Query+'SELECT TOP 1 @ReorderQty=ReorderQty FROM COM_CCPrices with(nolock) WHERE ReorderQty>0 AND (PriceType=0 or PriceType=3) AND '+@WHERE+' ORDER BY WEF DESC
IF @ReorderQty IS NULL
	SET @ReorderQty=(SELECT TOP 1 ReorderQty FROM COM_CCPrices with(nolock) WHERE WEF<=@EDATE and ProductID=@PID AND ReorderQty>0 AND (PriceType=0 or PriceType=3) AND CCNID1=0 AND CCNID2=0 AND CCNID3=0 AND CCNID4=0 AND CCNID5=0 AND CCNID6=0 AND CCNID7=0 AND CCNID8=0 AND CCNID9=0 AND CCNID10=0 AND CCNID11=0 AND CCNID12=0 AND CCNID13=0 AND CCNID14=0 AND CCNID15=0 AND CCNID16=0 AND CCNID17=0 AND CCNID18=0 AND CCNID19=0 AND CCNID20=0 AND CCNID21=0 AND CCNID22=0 AND CCNID23=0 AND CCNID24=0 AND CCNID25=0 AND CCNID26=0 AND CCNID27=0 AND CCNID28=0 AND CCNID29=0 AND CCNID30=0 AND CCNID31=0 AND CCNID32=0 AND CCNID33=0 AND CCNID34=0 AND CCNID35=0 AND CCNID36=0 AND CCNID37=0 AND CCNID38=0 AND CCNID39=0 AND CCNID40=0 AND CCNID41=0 AND CCNID42=0 AND CCNID43=0 AND CCNID44=0 AND CCNID45=0 AND CCNID46=0 AND CCNID47=0 AND CCNID48=0 AND CCNID49=0 AND CCNID50=0 ORDER BY WEF DESC)
IF @ReorderQty IS NULL
	SELECT @ReorderQty=ReorderQty FROM INV_Product with(nolock) WHERE ProductID=@PID
'
	if @CalcSellingPrice=0
	SET @Query=@Query+'SELECT TOP 1 @SellingPrice=SellingRate FROM COM_CCPrices with(nolock) WHERE SellingRate>0 AND (PriceType=0 or PriceType=1) AND '+@WHERE+' ORDER BY WEF DESC 
'
	if @CalcLastPrice=0
	SET @Query=@Query+'SELECT TOP 1 @LastPrice=A.Rate FROM INV_DocDetails A with(nolock) INNER JOIN COM_DocCCData DCC with(nolock) ON A.InvDocDetailsID=DCC.InvDocDetailsID
	WHERE A.IsQtyIgnored=0 and A.VoucherType=1 and A.ProductID=@PID AND '+substring(@DimCol,2,len(@DimCol))+'=@TempTAGID AND A.DocDate<=CONVERT(float,getdate())  
	ORDER BY A.DocDate desc
'
	SET @Query=@Query+'
	IF @ReorderLevel IS NOT NULL OR @ReorderQty IS NOT NULL OR @SellingPrice IS NOT NULL OR @LastPrice IS NOT NULL OR @MaxInventoryLevel IS NOT NULL
		--INSERT INTO #TblReorder(ProductID,TagID,ReorderLevel,ReorderQty,SellingPrice,LastPrice)
		--VALUES(@PID,@TempTAGID,@ReorderLevel,@ReorderQty,@SellingPrice,@LastPrice)
		SELECT @PID,@TempTAGID,@ReorderLevel,@ReorderQty,@SellingPrice,@LastPrice,@MaxInventoryLevel
'
				--print(@Query)
					INSERT INTO #TblReorder(ProductID,TagID,ReorderLevel,ReorderQty,SellingPrice,LastPrice,MaxInventoryLevel)
					EXEC(@Query)	
					SET @TI=@TI+1
				END

				SET @I=@I+1
			END
			
			--To Get Reorder of Selected Location
			INSERT INTO #TblReorder
			SELECT ProductID,-1,ReorderLevel,ReorderQty,SellingPrice,LastPrice,MaxInventoryLevel FROM #TblReorder 
			WHERE TagID=@SelectedLocation	

		END
	end
	--SELECT * FROM #TblReorder
	/******* FINAL DATA *******/
	IF @IsGroupWise=1
		SELECT P.ProductID,TP.NodeID TAGID,P.Description,G.ProductName ProductGroup,ISNULL(PC.ReorderQty,0) ReorderQty,ISNULL(PC.ReOrderLevel,0) ReOrderLevel,PC.SellingPrice,PC.LastPrice,
		ISNULL(QOH.Qty,0) QOH,
		ISNULL(BQ.Qty,0) BalanceQty,--AVR.BalanceQty,
		AVR.AvgRate
		,P.UOMID UOM_Key,(SELECT TOP 1 UnitName FROM COM_UOM WITH(NOLOCK) WHERE UOMID=P.UOMID) UOM--,P.Description
		,PO.ExpQty1,PO.ExpQty2,PO.ExpQty3,PO.ComQty1,PO.ComQty2,PO.ComQty3
		,AVS.CY1,AVS.CY2,AVS.CY3,ISNULL(AVS.CYAvgSale,0) CYAvgSale,AVS.TotalSaleQty
		,AVS.FC1,AVS.FC2,AVS.FC3,ISNULL(AVS.FCPYAvgSale,0)/12 FCPYAvgSale
		,SL.SalesQty1,SalesValue1,SalesCost1,SL.SalesQty2,SalesValue2,SalesCost2,SL.SalesQty3,SalesValue3,SalesCost3
		,BEx0,BE.BEx1,BE.BEx2,BE.BExGreater,ISNULL(PC.MaxInventoryLevel,0) MaxInventoryLevel
	--	,TP.AvgRate
		FROM (SELECT P.ID,P.ProductID,NodeID FROM #TblGroups P,@TblTagList) AS TP 
		INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=TP.ProductID	
		LEFT JOIN INV_Product G WITH(NOLOCK) ON G.ProductID=P.ParentID
	 
		LEFT JOIN (SELECT ProductID,TagID,SUM(ExpQty1) ExpQty1,SUM(ExpQty2) ExpQty2,SUM(ExpQty3) ExpQty3
				,SUM(ComQty1) ComQty1,SUM(ComQty2) ComQty2,SUM(ComQty3) ComQty3
				FROM @TblPendingOrders
				GROUP BY ProductID,TagID) AS PO ON P.ProductID=PO.ProductID AND PO.TagID=TP.NodeID
	
		LEFT JOIN @TblQOH QOH ON P.ProductID=QOH.ProductID
		LEFT JOIN @TblBalanceQty BQ ON P.ProductID=BQ.ProductID AND BQ.TagID=TP.NodeID
		LEFT JOIN (select TP.ParentID ProductID,AVR.TagID,max(AVR.AvgRate) AvgRate
				from @TblAvgRate AVR join #TblProducts TP on TP.ProductID=AVR.ProductID group by TP.ParentID,AVR.TagID) AVR ON TP.ProductID=AVR.ProductID AND AVR.TagID=TP.NodeID
		LEFT JOIN (select TP.ParentID ProductID,PC.TagID,max(PC.ReorderQty) ReorderQty,max(PC.ReOrderLevel) ReOrderLevel,max(PC.SellingPrice) SellingPrice,max(PC.LastPrice) LastPrice 
				from #TblReorder PC join #TblProducts TP on TP.ProductID=PC.ProductID group by TP.ParentID,PC.TagID)PC ON P.ProductID=PC.ProductID AND PC.TagID=TP.NodeID
		LEFT JOIN @TblBatch BE ON P.ProductID=BE.ProductID
		
		LEFT JOIN (SELECT ProductID,TagID,SUM(CY1) CY1,SUM(CY2) CY2,SUM(CY3) CY3,SUM(CYAvgSale) CYAvgSale,SUM(TotalSaleQty) TotalSaleQty
				,SUM(FC1) FC1,SUM(FC2) FC2,SUM(FC3) FC3,SUM(FCPYAvgSale) FCPYAvgSale
				FROM @TblAvgSale
				GROUP BY ProductID,TagID) AS AVS ON P.ProductID=AVS.ProductID AND AVS.TagID=TP.NodeID	
				
		LEFT JOIN (SELECT ProductID,TagID,SUM(SLQ1) SalesQty1,SUM(SLV1) SalesValue1,SUM(SLC1) SalesCost1,SUM(SLQ2) SalesQty2,SUM(SLV2) SalesValue2,SUM(SLC2) SalesCost2,SUM(SLQ3) SalesQty3,SUM(SLV3) SalesValue3,SUM(SLC3) SalesCost3
				FROM @TblSale
				GROUP BY ProductID,TagID) AS SL ON P.ProductID=SL.ProductID AND SL.TagID=TP.NodeID			
					
		ORDER BY P.lft,TAGID
	
	ELSE
	SELECT P.ProductID,TP.NodeID TAGID,P.Description,G.ProductName ProductGroup,ISNULL(PC.ReorderQty,0) ReorderQty,ISNULL(PC.ReOrderLevel,0) ReOrderLevel,PC.SellingPrice,PC.LastPrice,
		ISNULL(QOH.Qty,0) QOH,
		ISNULL(BQ.Qty,0) BalanceQty,--AVR.BalanceQty,
		AVR.AvgRate
		,P.UOMID UOM_Key,(SELECT TOP 1 UnitName FROM COM_UOM WITH(NOLOCK) WHERE UOMID=P.UOMID) UOM--,P.Description
		,PO.ExpQty1,PO.ExpQty2,PO.ExpQty3,PO.ComQty1,PO.ComQty2,PO.ComQty3
		,AVS.CY1,AVS.CY2,AVS.CY3,ISNULL(AVS.CYAvgSale,0) CYAvgSale,AVS.TotalSaleQty
		,AVS.FC1,AVS.FC2,AVS.FC3,ISNULL(AVS.FCPYAvgSale,0)/12 FCPYAvgSale
		,SL.SalesQty1,SalesValue1,SalesCost1,SL.SalesQty2,SalesValue2,SalesCost2,SL.SalesQty3,SalesValue3,SalesCost3
		,BEx0,BE.BEx1,BE.BEx2,BE.BExGreater,ISNULL(PC.MaxInventoryLevel,0) MaxInventoryLevel
	--	,TP.AvgRate
	FROM (SELECT P.ID,P.ProductID,NodeID FROM #TblProducts P,@TblTagList) AS TP 
		INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=TP.ProductID	
		LEFT JOIN INV_Product G WITH(NOLOCK) ON G.ProductID=P.ParentID
	 
		LEFT JOIN (SELECT ProductID,TagID,SUM(ExpQty1) ExpQty1,SUM(ExpQty2) ExpQty2,SUM(ExpQty3) ExpQty3
				,SUM(ComQty1) ComQty1,SUM(ComQty2) ComQty2,SUM(ComQty3) ComQty3
				FROM @TblPendingOrders
				GROUP BY ProductID,TagID) AS PO ON P.ProductID=PO.ProductID AND PO.TagID=TP.NodeID
	
		LEFT JOIN @TblQOH QOH ON P.ProductID=QOH.ProductID
		LEFT JOIN @TblBalanceQty BQ ON P.ProductID=BQ.ProductID AND BQ.TagID=TP.NodeID
		LEFT JOIN @TblAvgRate AVR ON TP.ProductID=AVR.ProductID AND AVR.TagID=TP.NodeID
		LEFT JOIN #TblReorder PC ON P.ProductID=PC.ProductID AND PC.TagID=TP.NodeID
		LEFT JOIN @TblBatch BE ON P.ProductID=BE.ProductID
		
		LEFT JOIN (SELECT ProductID,TagID,SUM(CY1) CY1,SUM(CY2) CY2,SUM(CY3) CY3,SUM(CYAvgSale) CYAvgSale,SUM(TotalSaleQty) TotalSaleQty
				,SUM(FC1) FC1,SUM(FC2) FC2,SUM(FC3) FC3,SUM(FCPYAvgSale) FCPYAvgSale
				FROM @TblAvgSale
				GROUP BY ProductID,TagID) AS AVS ON P.ProductID=AVS.ProductID AND AVS.TagID=TP.NodeID	
				
		LEFT JOIN (SELECT ProductID,TagID,SUM(SLQ1) SalesQty1,SUM(SLV1) SalesValue1,SUM(SLC1) SalesCost1,SUM(SLQ2) SalesQty2,SUM(SLV2) SalesValue2,SUM(SLC2) SalesCost2,SUM(SLQ3) SalesQty3,SUM(SLV3) SalesValue3,SUM(SLC3) SalesCost3
				FROM @TblSale
				GROUP BY ProductID,TagID) AS SL ON P.ProductID=SL.ProductID AND SL.TagID=TP.NodeID			
					
	ORDER BY P.lft,TAGID
	
	SET @Query='SELECT P.ProductID,P.ProductCode,P.ProductName'+@SELECT+' 
	FROM INV_Product P with(nolock) INNER JOIN '
	IF @IsGroupWise=1
		SET @Query=@Query+'#TblGroups TP'
	ELSE
		SET @Query=@Query+'#TblProducts TP'
	SET @Query=@Query+' ON TP.ProductID=P.ProductID'+@FROM
	EXEC(@Query)
	
	/******* PRODUCT WISE VENDORS DATA *******/
	IF @IsGroupWise=1
		SELECT TP.ParentID ProductID,V.AccountID VendorID,(SELECT TOP 1 AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=V.AccountID) VendorName
		FROM INV_ProductVendors V with(nolock) 
			INNER JOIN #TblProducts TP ON V.ProductID=TP.ProductID 
			INNER JOIN (	
				SELECT V.ProductID,MAX(Priority) Prio
				FROM INV_ProductVendors V with(nolock) INNER JOIN #TblProducts TP ON V.ProductID=TP.ProductID 
				GROUP BY V.ProductID) AS T ON T.ProductID=V.ProductID AND T.Prio=V.Priority
				
	ELSE
		SELECT V.ProductID,V.AccountID VendorID,(SELECT TOP 1 AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=V.AccountID) VendorName
		FROM INV_ProductVendors V with(nolock) INNER JOIN (	
				SELECT V.ProductID,MAX(Priority) Prio
				FROM INV_ProductVendors V with(nolock) INNER JOIN #TblProducts TP ON V.ProductID=TP.ProductID 
				GROUP BY V.ProductID) AS T ON T.ProductID=V.ProductID AND T.Prio=V.Priority
		
	DROP TABLE #TblReorder
	DROP TABLE #TblProducts
	DROP TABLE #TblGroups

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
