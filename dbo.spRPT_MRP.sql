USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_MRP]
	@ProductID [nvarchar](max),
	@ShowType [int],
	@FromDate [datetime],
	@ToDate [datetime],
	@ExpectedXML [nvarchar](max),
	@CommitedXML [nvarchar](max),
	@IncludeJobQty [bit],
	@IncludeTrForPerios [bit],
	@CCWHERE [nvarchar](max),
	@SELECT [nvarchar](max),
	@FROM [nvarchar](max),
	@StockCCWhere [nvarchar](max) = '',
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON
	--Declaration Section
	DECLARE @Query NVARCHAR(MAX),@SubTagSQL NVARCHAR(MAX),@PID INT,@TI int,@XML xml,@OrderDateField nvarchar(30),@OrderWhere nvarchar(max)
		,@OrderDetailsIDFilter nvarchar(max),@OrdersByDoc nvarchar(max)

	DECLARE @TblQOH AS TABLE(ProductID INT,Qty float)
	DECLARE @TblAvgRate AS TABLE(ProductID INT,TagID INT,BalanceQty float,AvgRate float,BalValue float)
	DECLARE @TblExpQty AS TABLE(ProductID INT,DocDate datetime,CostCenterID int,PendingQty float)
	DECLARE @TblComQty AS TABLE(ProductID INT,DocDate datetime,CostCenterID int,PendingQty float)
	CREATE TABLE #TblOrderFilter(InvDetailsID INT)
	CREATE TABLE #TblProducts(ID int IDENTITY(1,1) NOT NULL,ProductID INT,PreexpiryDays int)
	
	INSERT INTO #TblProducts(ProductID)
	EXEC SPSplitString @ProductID,','

	IF len(@CCWHERE)>0 --OR @DimensionID>0
	BEGIN
		SET @CCWHERE=' INNER JOIN COM_DocCCData DCC with(nolock) ON A.InvDocDetailsID=DCC.InvDocDetailsID '+@CCWHERE
	END

	/******* QOH *******/
	SET @Query='SELECT A.ProductID, SUM(A.UOMConvertedQty*A.VoucherType)
		FROM INV_DocDetails A WITH(NOLOCK) 
		inner join #TblProducts TP on TP.ProductID=A.ProductID'
	
	IF len(@StockCCWhere)>0 
	BEGIN
		SET @Query=@Query+' INNER JOIN COM_DocCCData DCC with(nolock) ON A.InvDocDetailsID=DCC.InvDocDetailsID '+@StockCCWhere
	END	
	SET @Query=@Query+' WHERE (A.VoucherType=1 OR A.VoucherType=-1) AND A.IsQtyIgnored=0 and A.StatusID<>376
		and (A.DocumentType=3 or A.DocDate<'+convert(nvarchar,convert(float,@FromDate))+')
		GROUP BY A.ProductID'
	print(@Query)
	INSERT INTO @TblQOH(ProductID,Qty)
	EXEC(@Query)
	
	--Expected Qty
	set @XML=@ExpectedXML
	declare @ExpectedQty nvarchar(max)
	select @ExpectedQty=X.value('PO[1]','nvarchar(max)'),@OrderDateField=X.value('@Filter','nvarchar(50)'),@OrdersByDoc=X.value('@GroupByDoc','nvarchar(50)')
	from @XML.nodes('XML') as Data(X)	
	if @OrderDateField='DueDate'
		set @OrderDateField='isnull(A.DueDate,A.DocDate)'
	else
		set @OrderDateField='A.'+@OrderDateField
	set @OrderWhere=' and convert(float,'+@OrderDateField+')<='+convert(nvarchar,convert(float,@ToDate))
	if @ShowType=11 or @ShowType=12
		set @OrderWhere=@OrderWhere+' and A.DynamicInvDocDetailsID is null'
	IF @ExpectedQty<>''
	BEGIN
		IF @OrdersByDoc='1'
			INSERT INTO @TblExpQty(ProductID,DocDate,CostCenterID,PendingQty)
			exec spRPT_MRPPendingOrders 'DocumentProductDocDateQty',@ExpectedQty,@OrderDateField,0,@OrderWhere,@CCWHERE
		ELSE
			INSERT INTO @TblExpQty(ProductID,DocDate,PendingQty)
			exec spRPT_MRPPendingOrders 'ProductDocDateQty',@ExpectedQty,@OrderDateField,0,@OrderWhere,@CCWHERE
	END
	set @ExpectedQty=''
	select @ExpectedQty=X.value('@CC','nvarchar(max)') from @XML.nodes('XML/POFilter') as Data(X)
	IF @ExpectedQty<>''
	BEGIN	
		select @OrderDetailsIDFilter=X.value('POFilter[1]','nvarchar(max)') from @XML.nodes('XML') as Data(X)
		truncate table #TblOrderFilter
		insert into #TblOrderFilter
		EXEC SPSplitString @OrderDetailsIDFilter,','

		INSERT INTO @TblExpQty(ProductID,DocDate,PendingQty)
		exec spRPT_MRPPendingOrders 'ProductDocDateQty',@ExpectedQty,@OrderDateField,1,@OrderWhere,@CCWHERE
	END

	--Commited Qty
	set @XML=@CommitedXML
	declare @CommitedQTY nvarchar(max)
	select @CommitedQTY=X.value('SO[1]','nvarchar(max)'),@OrderDateField=X.value('@Filter','nvarchar(50)'),@OrdersByDoc=X.value('@GroupByDoc','nvarchar(50)')
	from @XML.nodes('XML') as Data(X)
	if @OrderDateField='DueDate'
		set @OrderDateField='isnull(A.DueDate,A.DocDate)'
	else
		set @OrderDateField='A.'+@OrderDateField
	set @OrderWhere=' and convert(float,'+@OrderDateField+')<='+convert(nvarchar,convert(float,@ToDate))
	if @ShowType=11 or @ShowType=12
		set @OrderWhere=@OrderWhere+' and A.DynamicInvDocDetailsID is null'
	IF @CommitedQTY<>''
	BEGIN
		IF @OrdersByDoc='1'
			INSERT INTO @TblComQty(ProductID,DocDate,CostCenterID,PendingQty)
			exec spRPT_MRPPendingOrders 'DocumentProductDocDateQty',@CommitedQTY,@OrderDateField,0,@OrderWhere,@CCWHERE
		ELSE
			INSERT INTO @TblComQty(ProductID,DocDate,PendingQty)
			exec spRPT_MRPPendingOrders 'ProductDocDateQty',@CommitedQTY,@OrderDateField,0,@OrderWhere,@CCWHERE
	END
	set @CommitedQTY=''
	select @CommitedQTY=X.value('@CC','nvarchar(max)') from @XML.nodes('XML/SOFilter') as Data(X)
	IF @CommitedQTY<>''
	BEGIN	
		select @OrderDetailsIDFilter=X.value('SOFilter[1]','nvarchar(max)')	from @XML.nodes('XML') as Data(X)
		truncate table #TblOrderFilter
		insert into #TblOrderFilter
		EXEC SPSplitString @OrderDetailsIDFilter,','
		
		INSERT INTO @TblComQty(ProductID,DocDate,PendingQty)
		exec spRPT_MRPPendingOrders 'DocumentProductDocDateQty',@CommitedQTY,@OrderDateField,1,@OrderWhere,@CCWHERE
	END

	/******* Average Rate Calculation *******/
/*	DECLARE @I INT,@COUNT INT,@BalQty FLOAT,@AvgRate FLOAT,@BalValue FLOAT,@COGS FLOAT,@TI_START INT
	SELECT @I=1,@COUNT=COUNT(*) FROM #TblProducts
	if (select COUNT(*) from @TblCalc where Name='AvgRate')=0
	begin
		--INSERT INTO @TblTagSelected(NodeID)
		--EXEC SPSplitString @AvgLocations,','
		--SELECT @TCNT=COUNT(*)+MIN(ID)-1,@TI_START=MIN(ID) FROM @TblTagSelected	

		WHILE(@I<=@COUNT)
		BEGIN
			SELECT @PID=ProductID,@TI=@TI_START FROM #TblProducts WHERE ID=@I

			--OVERALL AVG RATE		
			SET @SubTagSQL=replace(@CCWHERE,'A.InvDocDetailsID','D.InvDocDetailsID')
			
			IF (SELECT count(*) from @TblAvgRate where ProductID=@PID and TagID=-1)=0
			BEGIN
				--TO GET BALANCE DATA
				EXEC [spRPT_AvgRate] 0,@PID,@SubTagSQL,'',@ToDate,@ToDate,0,0,0,0,'',@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
				
				INSERT INTO @TblAvgRate(ProductID,TagID,BalanceQty,AvgRate,BalValue)
				SELECT @PID,-1,@BalQty,@AvgRate,@BalValue
				WHERE @BalQty IS NOT NULL
			END
			
			WHILE(@TI<=@TCNT)
			BEGIN
				SELECT @NodeID=NodeID FROM @TblTagSelected WHERE ID=@TI
				
				SET @SubTagSQL=replace(@CCWHERE,'A.InvDocDetailsID','D.InvDocDetailsID') + ' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+'='+CONVERT(NVARCHAR,@NodeID)		
			--	select @SubTagSQL
				IF (SELECT count(*) from @TblAvgRate where ProductID=@PID and TagID=@NodeID)=0
				BEGIN
					--TO GET BALANCE DATA
					EXEC [spRPT_AvgRate] 0,@PID,@SubTagSQL,'',@ToDate,@ToDate,0,0,0,0,'',@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
					
					INSERT INTO @TblAvgRate(ProductID,TagID,BalanceQty,AvgRate,BalValue)
					SELECT @PID,@NodeID,@BalQty,@AvgRate,@BalValue
					WHERE @BalQty IS NOT NULL
				END
				SET @TI=@TI+1
			END

			SET @I=@I+1
		END	
	end*/
	
	select P.ProductID,QOH.Qty QOH
	from #TblProducts P 
	left join @TblQOH QOH on P.ProductID=QOH.ProductID
	order by ID
	
	select * from @TblExpQty
	select * from @TblComQty
	
	if @IncludeJobQty=1
	begin
		declare @JobDim nvarchar(50),@TblName varchar(50)
		select @JobDim=Value from COM_CostCenterPreferences WITH(NOLOCK) where CostCenterID=76 and Name='JobDimension' and ISNUMERIC(Value)=1
		if @JobDim is not null and convert(int,@JobDim)>50000
		begin
			select @TblName=TableName from ADM_Features WITH(NOLOCK) WHere FeatureID=@JobDim
			
			set @Query='Select TP.ProductID,J.Name,case when isdate(J.ccAlpha49)=1 then convert(datetime,J.ccAlpha49) else null end JobDate
,(case when a.IsBom=1 then isnull(a.Qty*b.FPQty,0) else a.Qty end) - isnull((select sum(UOMConvertedQty) from inv_docdetails INV with(nolock) inner join COM_DocCCDATA DCC with(nolock) on DCC.InvDocDetailsID=INV.InvDocDetailsID
where DCC.dcccnid'+convert(nvarchar,convert(int,@JobDim)-50000)+'=J.NodeID and IsQtyIgnored=0 and StatusID<>376 and VoucherType=1 and ProductID=TP.ProductID),0) Qty
--,BomName,[StageID],b.FPQty,a.[BomID],a.[ProductID],a.[Qty],a.IsBom,a.[UOMID],b.ProductID BomProductID,i.ProductName,b.CCID,b.CCNodeID,DimID
from PRD_JobOuputProducts a WITH(NOLOCK) 
join  '+@TblName+' J WITH(NOLOCK) on a.NodeID=J.NodeID
join #TblProducts TP on TP.ProductID=a.ProductID
join  PRD_BillOfMaterial b WITH(NOLOCK) on a.BomID=b.BOMID
join INV_Product i WITH(NOLOCK) on b.ProductID=i.ProductID
where (a.StatusID=0 or a.StatusID=5) and a.CostCenterID='+@JobDim+'
and isdate(J.ccAlpha49)=1 and convert(float,convert(datetime,J.ccAlpha49)) between '+convert(nvarchar,convert(float,@FromDate))+' and '+convert(nvarchar,convert(float,@ToDate))+'
and J.StatusID!=(select StatusID from com_status with(nolock) where CostCenterID='+@JobDim+' and Status=''In Active'')'
			print @Query
			exec(@Query)
		--	select * from PRD_JobOuputProducts
		end
	end
	else
		select 1 JobQty where 1!=1
	
	if @IncludeTrForPerios=1
	begin
		SET @Query='SELECT A.ProductID,convert(datetime,A.DocDate) DocDate,VoucherType VType, SUM(UOMConvertedQty) Qty
		FROM INV_DocDetails A WITH(NOLOCK) inner join #TblProducts TP on TP.ProductID=A.ProductID
		WHERE (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0 and A.StatusID<>376
		and A.DocumentType!=3 and A.DocDate>='+convert(nvarchar,convert(float,@FromDate))+' and A.DocDate<='+convert(nvarchar,convert(float,@ToDate))+'
		GROUP BY A.ProductID,A.DocDate,VoucherType'
		EXEC(@Query)
	end
	else
		select 1 TranQty where 1!=1
	
	
	
/*	SET @Query='SELECT P.ProductID,P.ProductCode,P.ProductName'+@SELECT+' 
	FROM INV_Product P with(nolock) INNER JOIN #TblProducts TP ON TP.ProductID=P.ProductID'+@FROM
	EXEC(@Query)
	*/
	
	/******* PRODUCT WISE VENDORS DATA *******/
	--SELECT V.ProductID,V.AccountID VendorID,(SELECT TOP 1 AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=V.AccountID) VendorName
	--FROM INV_ProductVendors V with(nolock) INNER JOIN (	
	--			SELECT V.ProductID,MAX(Priority) Prio
	--			FROM INV_ProductVendors V with(nolock) INNER JOIN #TblProducts TP ON V.ProductID=TP.ProductID 
	--			GROUP BY V.ProductID) AS T ON T.ProductID=V.ProductID AND T.Prio=V.Priority
		
	DROP TABLE #TblProducts
	DROP TABLE #TblOrderFilter

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
