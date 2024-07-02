USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spSSRS_StockLedger]
	@Products [nvarchar](max),
	@DimensionID [int],
	@LocationWHERE [nvarchar](max) = NULL,
	@DIMWHERE [nvarchar](max),
	@WHERE [nvarchar](max),
	@FromDate [datetime],
	@ToDate [datetime],
	@IncludeUpPostedDocs [bit],
	@DefValuation [int] = 0,
	@CurrencyType [int],
	@CurrencyID [int] = 0,
	@SELECTQUERY [nvarchar](max),
	@FROMQUERY [nvarchar](max),
	@SortTransactionsBy [nvarchar](50),
	@UserID [int],
	@LangID [int]
WITH RECOMPILE, ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@To NVARCHAR(20),@TagSQL NVARCHAR(MAX),@Order NVARCHAR(100),@CloseDt nvarchar(20),@PR_I INT,@PR_COUNT INT,
			@PRD_I INT,@PRD_COUNT INT,@ProductID INT,@UnAppSQL NVARCHAR(50),@Valuation INT,@ShowNegativeStock bit,
			@CurrWHERE nvarchar(30),@ValColumn nvarchar(20),@GrossColumn nvarchar(20),@TransactionsBy nvarchar(100),
			@TransactionsByOp nvarchar(100),@TransactionsByOpHardClose nvarchar(50),
			@DateFilterCol nvarchar(60),@DateFilterLPRate nvarchar(60),@DateFilterOp1 nvarchar(120),@DateFilterOp2 nvarchar(80),@Extracol nvarchar(max),
			@strSQL nvarchar(max),@Transcol nvarchar(max),@k int,@kcnt int,@SelectCols nvarchar(max)
			
	CREATE TABLE #TblOpening (ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,ProductID INT,OpQty FLOAT,AvgRate FLOAT,OpValue FLOAT,DocumentType INT)
	CREATE TABLE #tblPeriodicAvgRate (ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,monthyear nvarchar(10),MYAvgRate FLOAT)
	CREATE TABLE #TblOpeningTransaction (ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,ProductID INT,Qty FLOAT,Rate FLOAT,DocumentType INT)
	
	CREATE TABLE #Tbl(ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,PRODUCTID INT,[Date] FLOAT,Qty FLOAT,RecRate FLOAT,RecValue FLOAT,VoucherType INT,DocumentType INT)
	CREATE NONCLUSTERED INDEX [Tbl_ProductID_Index] ON #Tbl([ProductID] ASC) 
	
	CREATE TABLE #TblTransactions (ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,PRODUCTID INT,UOMConvertedQty FLOAT,RecQty FLOAT,RecValue FLOAT,DOCDATE DATETIME,InvDocDetailsID INT,DocumentType INT,IssValue FLOAT,BatchValue FLOAT,Gross FLOAT)
	CREATE NONCLUSTERED INDEX [TblTransactions_ProductID_Index] ON #TblTransactions([ProductID] ASC) 
	
	CREATE TABLE #lstRecTbl2 (ID INT,Qty FLOAT,Rate FLOAT,DocumentType INT)
	Create Table #TblProds (ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,ProductID INT,ProductName NVARCHAR(MAX),ProductCode NVARCHAR(MAX),ValuationID INT)
	Create Table #TblLastRate(ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,ProductID INT,ProductName NVARCHAR(MAX),Rate FLOAT)
	CREATE TABLE #Tblextracols(Rptcol1 nvarchar(max))	
	
	DECLARE @LPRateI int,@LPRateCNT int
	DECLARE @Gross FLOAT,@PrdName nvarchar(max),@IsValExist bit,@RRRecQty float,@RRRecValue float,@RDocumentType int,@RIssValue float,@RBatchValue float,@RstrPeriodMn nvarchar(10),@INVID FLOAT
	
	--INSERT PRODUCTS INTO #TBLPRODS
	--IF (ISNULL(@Products,'')<>'')
	IF(ISNULL(@Products,'')<>'' )
	BEGIN
		INSERT INTO #TblProds(ProductID)
			EXEC SPSplitString @Products,','
			UPDATE T SET T.PRODUCTNAME=P.ProductName,T.PRODUCTCODE=P.PRODUCTCODE,T.ValuationID=P.ValuationID	FROM #TblProds T WITH(NOLOCK) JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=T.ProductID
	END
	ELSE
	BEGIN
		INSERT INTO #TblProds(ProductID,ProductName,ProductCode,ValuationID)
			SELECT ProductID,ProductName,ProductCode,ValuationID FROM INV_PRODUCT WITH(NOLOCK) WHERE ISGROUP=0 
	END
	
	set @Extracol=''
	set @strSQL=''
	set @Transcol=''
	
	SET @TagSQL=''
	SET @Order=''
	SET @UnAppSQL=''
	SET @CurrWHERE=''
	SET @ValColumn=''
	SET @GrossColumn=''
	SET @TransactionsBy=''
	SET @TransactionsByOp=''
	SET @TransactionsByOpHardClose=''
	SET @DateFilterCol=''
	SET @DateFilterLPRate=''
	SET @DateFilterOp1=''
	SET @DateFilterOp2=''

	if(select Value from adm_globalpreferences with(nolock) where Name='ShowNegativeStockInReports')='True'
		set @ShowNegativeStock=1
	else
		set @ShowNegativeStock=0
		
	SET @FromDate=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
	SET @Valuation=@DefValuation
	
	IF @IncludeUpPostedDocs=0
		SET @UnAppSQL=' AND D.StatusID=369'
	ELSE
		SET @UnAppSQL=' AND D.StatusID<>376'

	IF @CurrencyID>0
	BEGIN
		SET @ValColumn='StockValueFC'
		SET @GrossColumn='GrossFC'
		SET @CurrWHERE=' AND D.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
		
	END
	ELSE
	BEGIN
		IF @CurrencyType=1
		BEGIN
			SET @ValColumn='StockValueBC'
			SET @GrossColumn='(Gross/ExhgRtBC)'
		END
		ELSE
		BEGIN
			SET @ValColumn='StockValue'
			SET @GrossColumn='Gross'
		END
		SET @CurrWHERE=''
	END
	
	SELECT @CloseDt=convert(nvarchar(20), max(ToDate)+1) FROM ADM_FinancialYears with(nolock) where InvClose=1 and ToDate<convert(int,@FromDate)
	
	if @SortTransactionsBy='CreatedDate'
	begin
		set @Transcol=' DocDate DateTime,CreateTime Datetime'
		set @SortTransactionsBy='OP,DocDate,CreateTime'
		set @TransactionsBy='CONVERT(DATETIME,D.CreatedDate) DocDate,CONVERT(DATETIME,D.CreatedDate) CreateTime'
		set @TransactionsByOp='D.CreatedDate DocDate,D.CreatedDate CreateTime'
		set @TransactionsByOpHardClose=',null CreateTime'
		set @DateFilterCol=' AND D.CreatedDate>=@FromDate AND D.CreatedDate<@ToDate+1'
		set @DateFilterOp1=' AND (D.CreatedDate<@FromDate OR (D.DocumentType=3 AND D.CreatedDate<@ToDate+1))'
		set @DateFilterOp2=' AND D.CreatedDate<@FromDate'
		set @DateFilterLPRate=' AND D.CreatedDate<@ToDate+1'
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.CreatedDate>=@CloseDt'+@DateFilterCol
			set @DateFilterOp1=' and D.CreatedDate>=@CloseDt'+@DateFilterOp1
			set @DateFilterOp2=' and D.CreatedDate>=@CloseDt'+@DateFilterOp2
		end	
	end
	else if @SortTransactionsBy='DocDate,CreatedDate'
	begin
		set @Transcol=' DocDate DateTime,CTime Datetime'
		set @SortTransactionsBy='OP,DocDate,CTime'
		set @TransactionsBy='CONVERT(DATETIME,D.DocDate) DocDate,CONVERT(DATETIME,D.CreatedDate) CTime'
		set @TransactionsByOp='D.DocDate DocDate,D.CreatedDate CTime'
		set @TransactionsByOpHardClose=',null CTime'
		set @DateFilterCol=' AND D.DocDate BETWEEN @FromDate AND @ToDate'
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
		set @DateFilterLPRate=' AND D.DocDate<=@ToDate'
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.DocDate>=@CloseDt'+@DateFilterCol
			set @DateFilterOp1=' and D.DocDate>=@CloseDt'+@DateFilterOp1
			set @DateFilterOp2=' and D.DocDate>=@CloseDt'+@DateFilterOp2
		end
	end
	else if @SortTransactionsBy='ModifiedDate'
	begin
		set @Transcol=' DocDate DateTime,ModTime Datetime'
		set @TransactionsBy='CONVERT(DATETIME,D.ModifiedDate) DocDate,CONVERT(DATETIME,D.ModifiedDate) ModTime'
		set @SortTransactionsBy='OP,DocDate,ModTime'
		set @TransactionsBy='CONVERT(DATETIME,D.ModifiedDate) DocDate,CONVERT(DATETIME,D.ModifiedDate) ModTime'
		set @TransactionsByOp='D.ModifiedDate DocDate,D.ModifiedDate ModTime'
		set @TransactionsByOpHardClose=',null ModTime'
		set @DateFilterCol=' AND D.ModifiedDate>=@FromDate AND D.ModifiedDate<@ToDate+1'
		set @DateFilterOp1=' AND (D.ModifiedDate<@FromDate OR (D.DocumentType=3 AND D.ModifiedDate<@ToDate+1))'
		set @DateFilterOp2=' AND D.ModifiedDate<@FromDate'
		set @DateFilterLPRate=' AND D.ModifiedDate<@ToDate+1'
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.ModifiedDate>=@CloseDt'+@DateFilterCol
			set @DateFilterOp1=' and D.ModifiedDate>=@CloseDt'+@DateFilterOp1
			set @DateFilterOp2=' and D.ModifiedDate>=@CloseDt'+@DateFilterOp2
		end
	end
	else if @SortTransactionsBy='DocDate,ModifiedDate'
	begin
		set @Transcol=' DocDate DateTime,ModTime Datetime'
		set @SortTransactionsBy='OP,DocDate,ModTime'
		set @TransactionsBy='CONVERT(DATETIME,D.DocDate) DocDate,CONVERT(DATETIME,D.ModifiedDate) ModTime'
		set @TransactionsByOp='D.DocDate,D.ModifiedDate ModTime'
		set @TransactionsByOpHardClose=',null ModTime'
		set @DateFilterCol=' AND D.DocDate BETWEEN @FromDate AND @ToDate'
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
		set @DateFilterLPRate=' AND D.DocDate<=@ToDate'
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.DocDate>=@CloseDt'+@DateFilterCol
			set @DateFilterOp1=' and D.DocDate>=@CloseDt'+@DateFilterOp1
			set @DateFilterOp2=' and D.DocDate>=@CloseDt'+@DateFilterOp2
		end
	end	
	else
	begin
		set @Transcol=' DocDate DateTime'
		set @SortTransactionsBy='OP,DocDate'
		set @TransactionsBy='CONVERT(DATETIME,D.DocDate) DocDate'
		set @TransactionsByOp='D.DocDate DocDate'
		set @TransactionsByOpHardClose=''
		set @DateFilterCol=' AND D.DocDate BETWEEN @FromDate AND @ToDate'
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
		set @DateFilterLPRate=' AND D.DocDate<=@ToDate'
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.DocDate>=@CloseDt'+@DateFilterCol
			set @DateFilterOp1=' and D.DocDate>=@CloseDt'+@DateFilterOp1
			set @DateFilterOp2=' and D.DocDate>=@CloseDt'+@DateFilterOp2
		end		
	end
	
	SET @TagSQL=''
	
	IF ((ISNULL(@LocationWHERE,'')<>'' AND @LocationWHERE<>NULL) OR (ISNULL(@DIMWHERE,'')<>'' AND @DIMWHERE<>NULL))
	begin
		IF (ISNULL(@LocationWHERE,'')<>'' AND @LocationWHERE<>NULL)
			set @DIMWHERE=@DIMWHERE+' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' IN ('+@LocationWHERE+') '
		set @TagSQL=@DIMWHERE			
		set @Order=@SortTransactionsBy+',ST DESC,VoucherType DESC,VoucherNo,RecQty DESC'
	end
	else
	begin
		set @Order=@SortTransactionsBy+',ST DESC,VoucherNo,VoucherType DESC,RecQty DESC'
	end		
	
	if(@DefValuation=4)
		set @SELECTQUERY=@SELECTQUERY+','+@GrossColumn+' Gross'
	
	if(@DefValuation=8)
		set @SELECTQUERY=@SELECTQUERY+','+@GrossColumn+' BatchValue'
		
	--Reconcile flag
	declare @XML xml,@Cogs nvarchar(50),@IsReconcile bit
	set @XML=(Select CustomPreferences From ADM_RevenUReports with(nolock) where ReportID=14)
	set @Cogs=''
	set @IsReconcile=0
	select @Cogs=X.value('COGS[1]','nvarchar(50)'),@IsReconcile=X.value('Reconcile[1]','bit') from @XML.nodes('XML') as Data(X)
	if(isnull(@Cogs,'')<>'')
		set @IsReconcile=0
		
	--#TBLMAIN : TEMP TABLE FOR INSERTING TRANSACTION DATA	
	SET @SelectCols=''
	SET @SelectCols='ProductID,ProductName,DocDate,VoucherNo,CustomerName,RecQty,RecUnit,RecRate,RecValue,IssQty,IssUnit,IssRate,IssValue,VoucherType,DocumentType,
			AvgRate,COGS,BalanceQty,'+ convert(nvarchar,isnull(@IsReconcile,0))+' IsReconcile,BalanceValue,UOMConvertedQty'
	--START: EXTRA COLUMNS FROM SELECTQUERY 
	INSERT INTO #Tblextracols(Rptcol1)
		exec SPSplitString @SELECTQUERY,','
	
	Delete From #Tblextracols where isnull(Rptcol1,'')=''
	set @Extracol=''
	Select @k=1 ,@kcnt=count(*) from #Tblextracols 
	While(@k<=@kcnt)
	Begin
		SET @Extracol=@Extracol+',ExtraColumn'+convert(nvarchar(max),@k) +' nvarchar(max)'
		SET @SelectCols=@SelectCols+',ExtraColumn'+convert(nvarchar(max),@k)
	Set @k=@k+1
	End
	--END: EXTRA COLUMNS FROM SELECTQUERY 	
	CREATE Table #tblMain(ProductID INT,ProductName nvarchar(max))
		set @strSQL='alter table #tblMain add '+ @Transcol + ',VoucherNo nvarchar(200),InvDocDetailsID int,CustomerName nvarchar(200),RecQty float,RecUnit nvarchar(100) '
		set @strSQL=@strSQL+',RecRate float,RecValue float,IssQty float,IssUnit nvarchar(100) ,IssRate float,IssValue float,UOMConvertedQty float,VoucherType int'
		set @strSQL=@strSQL+',DocumentType int,OP int,ST int'
	--if(@DefValuation=8)
		set @strSQL=@strSQL+', BatchValue nvarchar(200)'	
		set @strSQL=@strSQL+', Gross float '
	if(isnull(@Extracol,'')<>'')
		set @strSQL=@strSQL+@Extracol
		
	--if(@DefValuation=4)
		--set @strSQL=@strSQL+', Gross float '
	if(@DefValuation=8)
		set @strSQL=@strSQL+',BatchValue1 nvarchar(200)'			

	set @strSQL=@strSQL+',AvgRate float,COGS float,BalanceQty float,IsReconcile bit,BalanceValue float'	
	--if(@DefValuation=4 OR @DefValuation=5 OR @DefValuation=6)
		set @strSQL=@strSQL+',ID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY'
	exec (@strSQL)
	CREATE NONCLUSTERED INDEX [TblMain_ProductID_Index] ON #tblMain([ProductID] ASC,[InvDocDetailsID],[VoucherType],[DocumentType]) 
	
	
	--#TBLMAINOP : TEMP TABLE FOR INSERTING OPENING BALANCE DATA	
	CREATE Table #tblMainOP(ProductID INT,ProductName nvarchar(max))
	set @strSQL='alter table #tblMainOP add '+ @Transcol + ',VoucherNo nvarchar(200),InvDocDetailsID int,CustomerName nvarchar(200),RecQty float,RecUnit nvarchar(100) '
	set @strSQL=@strSQL+',RecRate float,RecValue float,IssQty float,IssUnit nvarchar(100) ,IssRate float,IssValue float,UOMConvertedQty float,VoucherType int'
	set @strSQL=@strSQL+',DocumentType int,OP int,ST int'
	--if(@DefValuation=8)
		set @strSQL=@strSQL+', BatchValue nvarchar(200)'	
	set @strSQL=@strSQL+', Gross float '			
	if(isnull(@Extracol,'')<>'')
		set @strSQL=@strSQL+@Extracol
	----if(@DefValuation=4)
	--	set @strSQL=@strSQL+', Gross float '
	if(@DefValuation=8)
		set @strSQL=@strSQL+',BatchValue1 nvarchar(200)'			
	set @strSQL=@strSQL+',AvgRate float,COGS float,BalanceQty float,IsReconcile bit,BalanceValue float'	
	--if(@DefValuation=4 OR @DefValuation=5 OR @DefValuation=6)
		set @strSQL=@strSQL+',ID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY'
	exec (@strSQL)
	CREATE NONCLUSTERED INDEX [TblMainOP_ProductID_Index] ON #tblmainOP([ProductID] ASC,[VoucherType]) 
	--INSERT INTO #tblmainOP(ProductID,ProductName,BalanceQty ,AvgRate ,BalanceValue,VoucherType) SELECT ProductID,ProductName,0,0,0,0 FROM #TblProds	with(nolock)
	------------------
	SET @LPRateI =0
	SET @LPRateCNT=0
	
	print 'START MAIN QUERY'
	print convert(varchar(24),getdate(),121)
	--START:INSERTING TRANSACTION DATA INTO #TBLMAIN
	SET @SQL=' DECLARE @FromDate FLOAT,@ToDate FLOAT
			   SET @FromDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+''
			  IF (@SortTransactionsBy='CreatedDate' or @SortTransactionsBy='ModifiedDate')
				SET @SQL=@SQL+' SET @ToDate='+convert(nvarchar,convert(int,@ToDate)+1)+''
			  ELSE
				SET @SQL=@SQL+' SET @ToDate='+convert(nvarchar,convert(int,@ToDate))+''
				if(@CloseDt is not null)
		SET @SQL=@SQL+' DECLARE @CloseDt FLOAT='+@CloseDt
		
	SET @SQL=@SQL+' INSERT INTO #tblMain '
	
	
	SET @SQL=@SQL+'	SELECT P.ProductID,P.ProductName,'+@TransactionsBy+',D.VoucherNo,D.InvDocDetailsID,A.AccountName,
		NULL RecQty,NULL RecUnit,NULL RecRate,NULL RecValue,
		Quantity IssQty,UOM.UnitName IssUnit,D.'+@ValColumn+'/D.Quantity IssRate,D.'+@ValColumn+' IssValue,D.UOMConvertedQty,D.VoucherType,D.DocumentType,2 OP,case when D.DocumentType=5 then 1 else 0 end ST'
	if(@DefValuation=8)
		SET @SQL=@SQL+',CASE WHEN P.ProductTypeID=5 THEN ISNULL((SELECT TOP 1 BD.'+@ValColumn+'/BD.Quantity FROM INV_DocDetails BD WITH(NOLOCK) WHERE BD.InvDocDetailsID=D.RefInvDocDetailsID AND BD.BatchID=D.BatchID),0)*D.Quantity ELSE D.'+@ValColumn+' END BatchValue'	
	else 
		SET @SQL=@SQL+',0 BatchValue'	
	if(@DefValuation=4)
		SET @SQL=@SQL+' ,Gross Gross'
	else 
		SET @SQL=@SQL+' ,0 Gross'				
	SET @SQL=@SQL+@SELECTQUERY+',0 avgrate,0 COGS,0 BalanceQty,0 IsReconcile,0 BalanceValue 
		FROM #TblProds T WITH(NOLOCK)
		JOIN INV_DocDetails D WITH(NOLOCK) ON T.ProductID=D.ProductID	
		INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
		LEFT JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
		LEFT JOIN COM_UOM UOM WITH(NOLOCK) ON UOM.UOMID=D.Unit
		LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.DebitAccount
		WHERE IsQtyIgnored=0 AND D.VoucherType=-1 AND Quantity>0'
	if(ISNULL(@DateFilterCol,'')<>'')
		SET @SQL=@SQL+@DateFilterCol
	 if(ISNULL(@UnAppSQL,'')<>'')
		SET @SQL=@SQL+@UnAppSQL
	 if(ISNULL(@CurrWHERE,'')<>'')
		SET @SQL=@SQL+@CurrWHERE
	 if(ISNULL(@WHERE,'')<>'' AND @WHERE<>NULL)
		SET @SQL=@SQL+ISNULL(@WHERE,'')
	 if(ISNULL(@TagSQL,'')<>'')
		SET @SQL=@SQL+' '+@TagSQL
			SET @SQL=@SQL+' UNION ALL '
		SET @SQL=@SQL+' SELECT P.ProductID,P.ProductName,'+@TransactionsBy+',D.VoucherNo,D.InvDocDetailsID,case when D.DocumentType=5 then Dr.AccountName else A.AccountName end CustomerName,
		D.Quantity RecQty,UOM.UnitName RecUnit,D.'+@ValColumn+'/D.Quantity RecRate,D.'+@ValColumn+' RecValue,
		NULL IssQty,NULL IssUnit,NULL IssRate,NULL IssValue,D.UOMConvertedQty,D.VoucherType,D.DocumentType,case when D.DocumentType=3 then 1 else 2 end OP,case when D.DocumentType=5 then 1 else 2 end ST'
	if(@DefValuation=8)
		SET @SQL=@SQL+',D.'+@ValColumn+' BatchValue'
	else 
		SET @SQL=@SQL+',0 BatchValue'	
	if(@DefValuation=4)
		SET @SQL=@SQL+' ,Gross Gross'
	else 
		SET @SQL=@SQL+' ,0 Gross'		
			
	--P.ProductID IN ('+@Products+') AND 			
	SET @SQL=@SQL+@SELECTQUERY+',0 avgrate,0 COGS,0 BalanceQty,0 IsReconcile,0 BalanceValue
		FROM #TblProds T WITH(NOLOCK)
		JOIN INV_DocDetails D WITH(NOLOCK) ON T.ProductID=D.ProductID	
		INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
		LEFT JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
		LEFT JOIN COM_UOM UOM WITH(NOLOCK) ON UOM.UOMID=D.Unit
		LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.CreditAccount
		LEFT JOIN ACC_Accounts Dr WITH(NOLOCK) ON Dr.AccountID=D.DebitAccount 
		WHERE IsQtyIgnored=0 AND D.VoucherType=1 AND D.DocumentType<>3 AND Quantity>0'
	 if(ISNULL(@DateFilterCol,'')<>'')
		SET @SQL=@SQL+@DateFilterCol
	 if(ISNULL(@UnAppSQL,'')<>'')
		SET @SQL=@SQL+@UnAppSQL
	 if(ISNULL(@CurrWHERE,'')<>'')
		SET @SQL=@SQL+@CurrWHERE
	 if(ISNULL(@WHERE,'')<>'' AND @WHERE<>NULL)
		SET @SQL=@SQL+ISNULL(@WHERE,'')
	 if(ISNULL(@TagSQL,'')<>'')
		SET @SQL=@SQL+' '+@TagSQL
	
	SET @SQL=@SQL+' ORDER BY '+@Order
	--print(@SQL)
	--EXEC(@SQL)
	--END:INSERTING TRANSACTION DATA INTO #TBLMAIN
	
	--START:INSERTING OP DATA INTO #TBL
	IF @TagSQL IS NOT NULL AND @TagSQL<>''
		SET @TagSQL=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@TagSQL
	ELSE
		SET @TagSQL=''
	
	--TRUNCATE TABLE #Tbl
	SET @SQL=@SQL+' INSERT INTO #Tbl(PRODUCTID,Date,Qty,RecRate,RecValue,VoucherType,DocumentType)	 
				SELECT ProductID,DocDate,Qty,RecRate,RecValue,VoucherType,DocumentType FROM ('
	if(@CloseDt is not null)
	begin
		SET @SQL=@SQL+'
			SELECT T.ProductID,CloseDate DocDate'+@TransactionsByOpHardClose+',''HardClose'' VoucherNo,Qty,Rate RecRate,BalValue RecValue,1 VoucherType,0 DocumentType,1 OP,2 ST
			FROM #TblProds T WITH(NOLOCK)
			JOIN INV_ProductClose DCC WITH(NOLOCK) ON T.ProductID=DCC.ProductID
			WHERE DCC.CloseDate=(@CloseDt-1) '
		if(ISNULL(@DIMWHERE,'')<>'' AND @DIMWHERE<>NULL)
		SET @SQL=@SQL+' '+ISNULL(@WHERE,'')
		SET @SQL=@SQL+' UNION ALL '
	end
	SET @SQL=@SQL+'
		SELECT T.ProductID,'+@TransactionsByOp+',D.VoucherNo,D.UOMConvertedQty Qty,D.'+@ValColumn+'/D.UOMConvertedQty RecRate,D.'+@ValColumn+' RecValue,D.VoucherType,D.DocumentType,case when D.DocumentType=3 then 1 else 2 end OP,case when D.DocumentType=5 then 1 else 2 end ST
		FROM #TblProds T WITH(NOLOCK)
		JOIN INV_DocDetails D WITH(NOLOCK) ON T.ProductID=D.ProductID '+@TagSQL+'
		WHERE  D.IsQtyIgnored=0 AND D.UOMConvertedQty!=0 AND D.VoucherType=1'
		if(ISNULL(@DateFilterOp1,'')<>'')
			SET @SQL=@SQL+@DateFilterOp1
		if(ISNULL(@UnAppSQL,'')<>'')
			SET @SQL=@SQL+@UnAppSQL
		if(ISNULL(@CurrWHERE,'')<>'')
			SET @SQL=@SQL+@CurrWHERE
		if(ISNULL(@WHERE,'')<>'' AND @WHERE<>NULL)
			SET @SQL=@SQL+ISNULL(@WHERE,'')
		
	SET @SQL=@SQL+' UNION ALL
		SELECT T.ProductID,'+@TransactionsByOp+',D.VoucherNo,D.UOMConvertedQty,0 RecRate'
		if @DefValuation=7
			SET @SQL=@SQL+',D.'+@ValColumn+' RecValue'
		else if @DefValuation=8
			SET @SQL=@SQL+',CASE WHEN P.ProductTypeID=5 THEN ISNULL((SELECT TOP 1 BD.'+@ValColumn+'/BD.Quantity FROM INV_DocDetails BD WITH(NOLOCK) WHERE BD.InvDocDetailsID=D.RefInvDocDetailsID AND BD.BatchID=D.BatchID),0)*D.Quantity ELSE D.'+@ValColumn+' END RecValue'
		else
			SET @SQL=@SQL+',0 RecValue'					
		SET @SQL=@SQL+',-1 VoucherType,D.DocumentType,2 OP,case when D.DocumentType=5 then 1 else 0 end ST
						FROM #TblProds T WITH(NOLOCK)
				JOIN INV_DocDetails D WITH(NOLOCK) ON T.ProductID=D.ProductID '
		if @DefValuation=8
			SET @SQL=@SQL+'INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID '
		SET @SQL=@SQL+@TagSQL+'
			WHERE D.IsQtyIgnored=0 AND D.VoucherType=-1'
		 if(ISNULL(@DateFilterOp2,'')<>'')
			SET @SQL=@SQL+@DateFilterOp2
		 if(ISNULL(@UnAppSQL,'')<>'')
			SET @SQL=@SQL+@UnAppSQL
		 if(ISNULL(@CurrWHERE,'')<>'')
			SET @SQL=@SQL+@CurrWHERE
		 if(ISNULL(@WHERE,'')<>'' AND @WHERE<>NULL)
			SET @SQL=@SQL+ISNULL(@WHERE,'')
	SET @SQL=@SQL+') AS T'
	--BELOW CODE COMMENTED TO ADD ST ORDER BY 
	--SET @SQL=@SQL+' ORDER BY '+replace(@Order,',RecQty DESC',',Qty DESC')--DocDate,ST DESC,VoucherNo,VoucherType DESC'
	SET @SQL=@SQL+' ORDER BY ProductID,'+replace(@Order,',RecQty DESC',',Qty DESC')
	--print(substring(@SQL,1,4000))
	--print(substring(@SQL,4001,4000))
	--print(substring(@SQL,8001,4000))
	EXEC sp_executesql @SQL
	
	print 'END MAIN QUERY'
	print convert(varchar(24),getdate(),121)
	--END:INSERTING OP DATA INTO #TBL	
	
	--START: INSERTING LAST PURCHASE RATE AND LAST LANDING RATE DATA INTO #TblLastRate		
	if (@DefValuation=4 or @DefValuation=5)
	begin
		SET @SQL='DECLARE @FromDate FLOAT,@ToDate FLOAT
		SET @FromDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+'
		SET @ToDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@ToDate))
		if(@CloseDt is not null)
			SET @SQL=@SQL+' DECLARE @CloseDt FLOAT='+@CloseDt
			
		SET @SQL='SELECT P.ProductID,P.ProductName,'
		if @DefValuation=4
			SET @SQL=@SQL+@GrossColumn+'/UOMConvertedQty RecRate'
		else if @DefValuation=5
			SET @SQL=@SQL+@ValColumn+'/UOMConvertedQty RecRate'
		SET @SQL=@SQL+'
			FROM #TblProds T WITH(NOLOCK)
			JOIN INV_DocDetails D WITH(NOLOCK) ON T.ProductID=D.ProductID	
			INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
			LEFT JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
			LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.CreditAccount
			WHERE IsQtyIgnored=0 AND D.VoucherType=1 AND D.DocumentType<>3 AND Quantity>0'
		 if(ISNULL(@DateFilterLPRate,'')<>'')
			SET @SQL=@SQL+@DateFilterLPRate
		 if(ISNULL(@UnAppSQL,'')<>'')
			SET @SQL=@SQL+@UnAppSQL
		 if(ISNULL(@CurrWHERE,'')<>'')
			SET @SQL=@SQL+@CurrWHERE
		 if(ISNULL(@WHERE,'')<>'' AND @WHERE<>NULL)
			SET @SQL=@SQL+ISNULL(@WHERE,'')
		 if(ISNULL(@TagSQL,'')<>'')
			SET @SQL=@SQL+' '+@TagSQL
		SET @SQL=@SQL+' ORDER BY P.ProductID,DocDate,VoucherNo'
		--print(@SQL)
		insert into #TblLastRate
		EXEC sp_executesql @SQL
		--EXEC(@SQL)		
		SELECT @LPRateCNT=COUNT(*) FROM #TblLastRate
	end
	--END: INSERTING LAST PURCHASE RATE AND LAST LANDING RATE DATA INTO #TblLastRate

	--START: INSERTING OPENING AND OPENING TRANSACTIONS DATA INTO #TblLastRate
	print 'START OP CALC'
	print convert(varchar(24),getdate(),121)
	
	DECLARE @IsOpening BIT,@TotalSaleSQL NVARCHAR(MAX),@RecQty FLOAT,@RecRate FLOAT,@RecValue FLOAT,@VoucherType INT
	DECLARE	@I INT,@COUNT INT,@TotalSaleQty FLOAT,@ID INT,@AvgRate FLOAT,@DocumentType INT
	DECLARE @TransactionsFound BIT,@SALESQTY FLOAT,@Qty FLOAT,@StockValue FLOAT
	CREATE TABLE #lstRecTbl(ID INT,Qty FLOAT,Rate FLOAT,DocumentType INT)
	SET @IsOpening=1
	DECLARE @lstI INT,@lstCNT INT,@lstQty FLOAT,@lstRate FLOAT,@lstDocumentType INT
	DECLARE @dblValue FLOAT,@dblUOMRate FLOAT,@OpBalanceQty FLOAT,@dblAvgRate FLOAT,@OpBalanceValue FLOAT,@dblCOGS FLOAT,@r int			
	
	DECLARE @nStatusOuter int,@SPInvoice cursor
	
	SELECT @PRD_I=1,@PRD_COUNT=COUNT(*) FROM #TblProds  with(nolock)
	
	WHILE(@PRD_I<=@PRD_COUNT)
	BEGIN
		IF @DefValuation=0
			SELECT @ProductID=ProductID,@Valuation=ValuationID FROM #TblProds WITH(NOLOCK) WHERE ID=@PRD_I
		ELSE
			SELECT @ProductID=ProductID FROM #TblProds WITH(NOLOCK) WHERE ID=@PRD_I
		
		IF @Valuation=6
		BEGIN
			DECLARE @Date float,@dtDate datetime,@Mn int,@Yr int,@PrMn int,@PrYr int,@dblQty float,@dblMnOpValue float,@dblIssueQty float,@dblPrevAvgRate float
		
			SET @SPInvoice = cursor for 
			SELECT Date,VoucherType,Qty,RecValue,DocumentType FROM #Tbl WITH(NOLOCK) WHERE ProductID=@ProductID
			
			OPEN @SPInvoice 
			SET @nStatusOuter = @@FETCH_STATUS
			
			FETCH NEXT FROM @SPInvoice Into @Date,@VoucherType,@RecQty,@RecValue,@DocumentType
			SET @nStatusOuter = @@FETCH_STATUS
			
			SELECT @dblQty=0,@dblValue=0, @OpBalanceQty=0,@dblMnOpValue=0,@dblPrevAvgRate=0,@dblIssueQty=0,@dblAvgRate=0
			
			WHILE(@nStatusOuter <> -1)
			BEGIN
				set @dtDate=convert(datetime,@Date)
				set @Mn=month(@dtDate)
				set @Yr=year(@dtDate)
	
				if (@PrMn is null or @PrMn!=@Mn or @PrYr!=@Yr)
                begin
					if(@PrMn is not null)
                    begin
						if(@dblQty>0)
							set @dblPrevAvgRate=(@dblMnOpValue+@dblValue)/@dblQty
						set @dblAvgRate=@dblPrevAvgRate
                        set @dblQty=(@dblQty-@dblIssueQty);
                        set @dblMnOpValue=@dblQty*@dblAvgRate;
                     end
                     set @PrMn=@Mn
                     set @PrYr=@Yr
                     set @dblIssueQty=0
                     set @dblValue=0
                end
                if @VoucherType=1
                begin
				    if (@DocumentType!= 6 and @DocumentType!=39)
                    begin
                        set @dblQty=@dblQty+@RecQty
                        set @dblValue=@dblValue+@RecValue
                    end
                end
                else
                begin
                    set @dblIssueQty=@dblIssueQty+@RecQty
                end

				FETCH NEXT FROM @SPInvoice Into @Date,@VoucherType,@RecQty,@RecValue,@DocumentType
				SET @nStatusOuter = @@FETCH_STATUS
			END
			CLOSE @SPInvoice
			
			set @OpBalanceQty=@dblQty-@dblIssueQty
			set @dblAvgRate=@dblPrevAvgRate
			if(@PrMn is not null)
            begin				
                if @dblQty>0
                    set @dblAvgRate=(@dblMnOpValue+@dblValue)/@dblQty
            end
            set @OpBalanceValue=@OpBalanceQty*@dblAvgRate
           
		END
		ELSE
		BEGIN
			SET @SPInvoice = cursor for 
			SELECT VoucherType,Qty,RecValue,DocumentType FROM #Tbl WITH(NOLOCK) WHERE ProductID=@ProductID
			
			OPEN @SPInvoice 
			SET @nStatusOuter = @@FETCH_STATUS
			
			FETCH NEXT FROM @SPInvoice Into @VoucherType,@RecQty,@RecValue,@DocumentType
			SET @nStatusOuter = @@FETCH_STATUS

			SELECT @dblValue=0,@dblUOMRate=0,@OpBalanceValue=0,@OpBalanceQty=0,@lstI=1,@lstCNT=0,@dblAvgRate=0
	
			TRUNCATE TABLE #lstRecTbl
			
			--Set Last Purchase Rate
			if (@Valuation=4 or @Valuation=5)
			begin
				set @dblAvgRate=0
				set @LPRateI=@LPRateCNT
				while(@LPRateI>0)
				begin
					SELECT @dblAvgRate=Rate FROM #TblLastRate where ProductID=@ProductID and ID=@LPRateI
					if @@rowcount=1
						break
					set @LPRateI=@LPRateI-1
				end
			end
			
			--SET @I=1
			WHILE(@nStatusOuter <> -1)
			BEGIN
				if(@RecQty<0)
				begin
					set @RecQty=-@RecQty
					set @VoucherType=-@VoucherType
				end	
			
				if @VoucherType=1
				begin
					set @dblValue = @RecValue
					set @dblUOMRate = @dblValue / @RecQty;
					
					if (@OpBalanceQty < 0)
					begin
						set @OpBalanceQty = @RecQty + @OpBalanceQty;
						if (Abs(@OpBalanceQty) < 0.00000001)
							set @OpBalanceQty = 0;
						if @ShowNegativeStock=0--NegStkChange
						begin
							if (@OpBalanceQty > 0)
								set @RecQty = @OpBalanceQty;
							else
								set @RecQty = 0;
						end
					end
					else
					begin
						SET @OpBalanceQty = @OpBalanceQty+@RecQty;
					end
					
					if (@Valuation=4 or @Valuation=5)--Last Purchase Rate/Landing Rate
						 set @dblUOMRate=@dblAvgRate
	              --       select @RecQty,@ShowNegativeStock
					if ((@RecQty>0 and @ShowNegativeStock=0) or (@RecQty!=0 and @ShowNegativeStock=1))--NegStkChange (@RecQty>0)
					begin
						--For Sales Return Voucher Avg Rate will be current Avg Rate
						if (@DocumentType=6 or @DocumentType=39)
						BEGIN
							if @dblAvgRate IS NULL
								set @dblAvgRate=0
							if (@Valuation=7 OR @Valuation=8)
								set @dblAvgRate=@dblUOMRate
							else
								set @dblUOMRate=@dblAvgRate
						END
						if @ShowNegativeStock=0
						begin
							if (@OpBalanceValue < 0)
								set @OpBalanceValue=0
						end
						set @OpBalanceValue += @RecQty*@dblUOMRate
					end
					
					if (@Valuation!=4 and @Valuation!=5)
					begin
						if @ShowNegativeStock=0--NegStkChange
						begin
							if @OpBalanceQty>0
								set @dblAvgRate=@OpBalanceValue/@OpBalanceQty;
							else
							begin
								set @dblAvgRate = 0;
								set @OpBalanceValue = 0;
							end
						end
						else
						begin
							if @OpBalanceQty!=0
								set @dblAvgRate=@OpBalanceValue/@OpBalanceQty;
						end
					end

					if (@RecQty>0)
					begin
						SELECT @lstCNT=@lstCNT+1
						INSERT INTO #lstRecTbl(ID,Qty,Rate,DocumentType)
						VALUES(@lstCNT,@RecQty,@dblUOMRate,@DocumentType)
					end
					--select convert(datetime,@Date),@dblAvgRate,@RecQty
				end
				else
				begin
					set @OpBalanceQty=@OpBalanceQty-@RecQty

					if (@Valuation=3 or @Valuation=4 or @Valuation=5)--WEIGHTED AVGG
						set @OpBalanceValue = @dblAvgRate * @OpBalanceQty;
					else if (@Valuation=7 or @Valuation=8)--Invoice Rate
					begin
						set @OpBalanceValue=@OpBalanceValue-@RecValue
						if(@OpBalanceValue<0)
							set @OpBalanceValue=0
						if(@OpBalanceQty<=0)
							set @dblAvgRate=0
						else	
							set @dblAvgRate=@OpBalanceValue/@OpBalanceQty
					end
					else if (@Valuation = 1 OR @Valuation = 2)--FIFO & LIFO
					begin
						set @dblCOGS = 0;
						
						if (@Valuation=1)
						begin
							while(@lstI<=@lstCNT)
							begin
								SELECT @lstQty=Qty,@lstRate=Rate FROM #lstRecTbl WITH(NOLOCK) WHERE ID=@lstI
								set @RecQty=@RecQty-@lstQty
								if(@RecQty<0)
								begin
									set @dblCOGS=@dblCOGS+(@lstQty+@RecQty)*@lstRate
									UPDATE #lstRecTbl SET Qty=-@RecQty WHERE ID=@lstI
									break;
								end
								else
								begin
									set @dblCOGS=@dblCOGS+(@lstQty*@lstRate);
									set @lstI=@lstI+1
									if (@RecQty=0)
										break;
								end
							end
						end
						else if (@Valuation=2)
						begin
							set @lstI=@lstCNT
							while(@lstI>=1)
							begin
								SELECT @lstQty=Qty,@lstRate=Rate FROM #lstRecTbl WITH(NOLOCK) WHERE ID=@lstI
								if @lstQty IS NULL
									continue;
								
								set @RecQty=@RecQty-@lstQty
								if(@RecQty<0)
								begin
									set @dblCOGS=@dblCOGS+(@lstQty+@RecQty)*@lstRate
									UPDATE #lstRecTbl SET Qty=-@RecQty WHERE ID=@lstI
									break;
								end
								else
								begin
									set @dblCOGS=@dblCOGS+(@lstQty*@lstRate);
									DELETE T FROM #lstRecTbl T WITH(NOLOCK) WHERE T.ID=@lstI
							        
									set @lstI=@lstI-1
									if (@RecQty=0)
										break;
								end
							end
						end

						set @OpBalanceValue=@OpBalanceValue-@dblCOGS;

						if (@OpBalanceValue < 0)
							set @OpBalanceValue = 0;
						
						if (@Valuation!=4 and @Valuation!=5)
						begin
							if (@OpBalanceQty > 0)
								set @dblAvgRate = @OpBalanceValue / @OpBalanceQty;
						end

					end
				end
				
				FETCH NEXT FROM @SPInvoice Into @VoucherType,@RecQty,@RecValue,@DocumentType
				SET @nStatusOuter = @@FETCH_STATUS
			END
			
			CLOSE @SPInvoice
		END -- End of else of if val=6
		IF @OpBalanceQty=0
			SET @OpBalanceValue=0

		
		DEALLOCATE @SPInvoice
		
		
		IF (@OpBalanceQty<>0 or @dblAvgRate>0) -- AvgRate condition added  if stock return document is comes as first row
		BEGIN						
			INSERT INTO #TblOpening
			VALUES(@ProductID,@OpBalanceQty,@dblAvgRate,@OpBalanceValue,@DocumentType)
			
			IF @OpBalanceQty>0
			BEGIN
				IF @Valuation=1
					INSERT INTO #TblOpeningTransaction(ProductID,Qty,Rate,DocumentType)
					SELECT @ProductID ProductID,Qty,Rate,DocumentType FROM #lstRecTbl WITH(NOLOCK) WHERE ID>=@lstI --ORDER BY ID
				ELSE IF @Valuation=2
					INSERT INTO #TblOpeningTransaction(ProductID,Qty,Rate,DocumentType)
					SELECT @ProductID ProductID,Qty,Rate,DocumentType FROM #lstRecTbl WITH(NOLOCK) ORDER BY ID
			END
			
			IF(isnull(@OpBalanceQty,0)<>0)
				INSERT INTO #tblmainOP(ProductID,ProductName,BalanceQty ,AvgRate ,BalanceValue,VoucherType) VALUES(@ProductID,'',0,0,0,0)
		END
		
		---------Avg Rate Calculation-------------------------------------------------------------
		SET @Gross=0
		SET @RRRecQty=0 
		SET @RIssValue=0 
		SET @RBatchValue=0
		SET @INVID=0
		SET @RRRecValue =0
		SET @PrdName=''
		SET @RstrPeriodMn=''
		SET @IsValExist=0
		SET @RDocumentType=0
		--PRODUCT LOOP				
		--print 'START AVG CALC: '+CONVERT(VARCHAR,@ProductID)
		--print convert(varchar(24),getdate(),121)		
		--SELECT @PR_I=1,@PR_COUNT=COUNT(*) FROM #TblProds with(nolock)
		--WHILE(@PR_I<=@PR_COUNT )--Product Loop Start
		--BEGIN
			--SELECT @ProductID=ProductID FROM #TblProds with(nolock) WHERE ID=@PR_I
			
			TRUNCATE TABLE #TblTransactions
			INSERT INTO #TblTransactions SELECT PRODUCTID,UOMConvertedQty,RecQty,RecValue,DOCDATE,InvDocDetailsID,DocumentType,IssValue,BatchValue,Gross  FROM #tblmain with(nolock) WHERE PRODUCTID=@ProductID
			
			SELECT @OpBalanceValue=0,@OpBalanceQty=0, @dblAvgRate=0,@IsValExist=0,@dblQty=0,@dblIssueQty=0,@INVID=0,@lstCNT=0, @lstI=1, @PrdName=''
			SELECT @AvgRate=0, @Qty=0,@StockValue=0,@IsOpening=1
			TRUNCATE TABLE #lstRecTbl2
			
			
			--IF @DefValuation=0
			--	SELECT @Valuation=ValuationID FROM #TblProds WITH(NOLOCK) WHERE ProductID=@ProductID
			
			SELECT @OpBalanceQty=isnull(opqty,0),@OpBalanceValue=isnull(OpValue,0),@dblAvgRate=isnull(AvgRate,0) FROM #TblOpening with(nolock) WHERE ProductID=@ProductID
			
			if((select count(*) from #TblOpeningTransaction where ProductID=@ProductID)>0)
			BEGIN
				if (@Valuation = 1 or @Valuation = 2)
				begin
					
					SELECT @lstCNT=@lstCNT+1
					INSERT INTO #lstRecTbl2(ID,Qty,Rate,DocumentType) SELECT @lstCNT,qty,Rate,DocumentType FROM #TblOpeningTransaction  with(nolock) WHERE ProductID=@ProductID
				end
			END
			
			if((select count(*) from #TblOpening with(nolock) where ProductID=@ProductID and isnull(OpQty,0)<>0)>0)
			BEGIN
				if((select count(*) from #tblmain with(nolock) where ProductID=@ProductID)>1)
					UPDATE #tblmainOP SET BalanceQty=@OpBalanceQty ,AvgRate=@dblAvgRate ,BalanceValue=@OpBalanceValue WHERE ProductID=@ProductID AND VOUCHERTYPE=0
				else if((select count(*) from #tblmain with(nolock) where ProductID=@ProductID)=0 and (select count(*) from #tblmainOP where ProductID=@ProductID)=1)
					UPDATE #tblmainOP SET BalanceQty=@OpBalanceQty ,AvgRate=@dblAvgRate ,BalanceValue=@OpBalanceValue WHERE ProductID=@ProductID AND VOUCHERTYPE=0	
				else if((select count(*) from #tblmain with(nolock) where ProductID=@ProductID)>0)
					DELETE T FROM #tblmainOP T WITH(NOLOCK) WHERE T.ProductID=@ProductID AND T.VOUCHERTYPE=0
			END
			ELSE
			BEGIN 
				if((select count(*) from #tblmain with(nolock) where ProductID=@ProductID)>0)
					DELETE T FROM #tblmainOP T WITH(NOLOCK) WHERE T.ProductID=@ProductID AND T.VOUCHERTYPE=0
			END
			
			----valuation 4,5,6	
			if(@Valuation=4 OR @Valuation=5)
			begin
				SELECT @I=1, @COUNT=COUNT(*) FROM #TblTransactions with(nolock) WHERE VOUCHERTYPE<>0 AND ProductID=@ProductID and VoucherType=1
				WHILE(@I<=@COUNT)
				BEGIN
					SELECT @dblQty=UOMConvertedQty,@dblValue=RecValue,@Gross=ISNULL(Gross,0) from #TblTransactions with(nolock) where ProductID=@ProductID and VoucherType=1
					--print @dblQty
					if(@dblQty>0 )
					begin
						if(@Valuation=4)
							 set @dblAvgRate = @Gross / @dblQty
						else if(@Valuation=5) 
							set @dblAvgRate = @dblValue / @dblQty
						break;
					end
					
				SET @I=@I+1
				END
			end
			else if(@Valuation=6)
			begin
				DECLARE @strPeriodMn NVARCHAR(10),@strPrev NVARCHAR(10),@RRecQty float,@UUOMConvertedQty float,@RRecValue float,@DDocumentType int
				declare @myavgrate float
				--delete from @tblPeriodicAvgRate
				TRUNCATE TABLE #tblPeriodicAvgRate
				set @RRecQty=0
				set @dblMnOpValue = 0
				set @dblIssueQty = 0 
				set @dblPrevAvgRate = @dblAvgRate
				set @dblQty = @OpBalanceQty
				set @dblMnOpValue = @OpBalanceValue
				set @strPrev=''
				set @strPeriodMn=''
				set @myavgrate=0
				SELECT @I=1, @COUNT=COUNT(*) FROM #tblmain with(nolock) where ProductID=@ProductID 
				WHILE(@I<=@COUNT)
				BEGIN
					SELECT @strPeriodMn=UPPER(SUBSTRING(DateName(Month,DocDate),1,3)+CAST(DatePart(Year,DocDate) as varchar(4))),@RRecQty=Qty,@DDocumentType=DocumentType,
						   @UUOMConvertedQty=UOMConvertedQty,@RRecValue=isnull(RecValue,0) from #TblTransactions with(nolock) where ProductID=@ProductID and id=@i
					 if (@strPrev != @strPeriodMn)
					 begin
						 if (@I > 0)
						 begin
							 if (@dblQty > 0)
							 begin
								if(isnull(@strPrev,'')<>'')
								begin
									
									set @dblPrevAvgRate = (@dblMnOpValue + @dblValue) / @dblQty   
									insert into #tblPeriodicAvgRate select  @strPrev,@dblPrevAvgRate                      
								end
							 end
							 else
							 begin
								if(isnull(@strPrev,'')<>'')
								begin
									insert into #tblPeriodicAvgRate select  @strPrev,round(@dblPrevAvgRate,0)
								end
							 end
							 set @dblQty = (@dblQty - @dblIssueQty)
							  set @myavgrate=0
							 select  @myavgrate=myAvgRate from #tblPeriodicAvgRate where monthyear=@strPrev
							 if(@myavgrate>0)
								set @dblMnOpValue = @dblQty * @myavgrate
						 end
						 set @strPrev = @strPeriodMn
						 set @dblIssueQty = 0
						 set @dblValue = 0
					 end

					 if (@RRecQty > 0)
					 begin
						 if (@DDocumentType != 6 and @DDocumentType != 39)
						 begin
							 set @dblQty +=@UUOMConvertedQty
							 set @dblValue +=@RRecValue
						 end
					 end
					 else
					 begin
						 set @dblIssueQty += @UUOMConvertedQty
					 end
		             
		             
				SET @I=@I+1
				END
				   SELECT @COUNT=COUNT(*) FROM #TblTransactions with(nolock) where ProductID=@ProductID 
				if (@COUNT > 0)
				begin
					if (@dblQty > 0)
					begin
						if(isnull(@strPrev,'')<>'')
						begin
							insert into #tblPeriodicAvgRate select  @strPrev,(@dblMnOpValue + @dblValue) / @dblQty   
						end
					end
					else
					begin
						if(isnull(@strPrev,'')<>'')
						begin
							insert into #tblPeriodicAvgRate select  @strPrev,@dblPrevAvgRate   
						end
					end
				end
			end
			---		
			SELECT @I=1, @COUNT=COUNT(*) FROM #TblTransactions with(nolock)  where ProductID=@ProductID
			WHILE(@I<=@COUNT) --Produt Transactions Loop Start
			BEGIN
					set @dblQty=0
					set @RRRecQty=0	
					set @RRRecValue=0
					set @RstrPeriodMn=''
					set @RDocumentType=0
					set @RIssValue=0
					SET @RBatchValue=0
					SET @INVID=0
					
					SELECT @dblQty=UOMConvertedQty ,@RRRecQty=RecQty,@RRRecValue=RecValue,@RstrPeriodMn=UPPER(SUBSTRING(DateName(Month,docdate),1,3)+CAST(DatePart(Year,docdate) as varchar(4))),--convert(DATETIME,docdate),
								@INVID=InvDocDetailsID,@RDocumentType=DocumentType,@RIssValue=IssValue,@RBatchValue=BatchValue from #TblTransactions with(nolock) where ProductID=@ProductID and id=@I
				   if (@RRRecQty > 0)
				   begin
						set @dblValue = @RRRecValue
						set @dblUOMRate = @dblValue / @dblQty;

						if (@OpBalanceQty < 0)
					   begin
							set @OpBalanceQty = @dblQty + @OpBalanceQty;
							if (Abs(@OpBalanceQty) < 0.00000001)
							   set @OpBalanceQty = 0;
							if (@ShowNegativeStock=0)
							begin
								if (@OpBalanceQty > 0)
									set @dblQty = @OpBalanceQty;
								else
								begin
									set @dblQty = 0;
								end
							end
						end
						else
						begin
							set @OpBalanceQty += @dblQty;
						end

						if (@Valuation = 4 or @Valuation = 5)--Last Rate
						begin
							set @dblUOMRate = @dblAvgRate;
						end
						else if (@Valuation = 6)--Periodic Monthly
						begin
							set @strPeriodMn = @RstrPeriodMn
							select  @dblUOMRate=myAvgRate,@dblAvgRate=myAvgRate  from #tblPeriodicAvgRate  with(nolock) where monthyear=@strPeriodMn
						end

						if (@dblQty > 0)
						begin
							--For Sales Return Voucher Avg Rate will be current Avg Rate
							if (@RDocumentType= 6 or @RDocumentType= 39)
							begin
								if (@Valuation = 7)
									set @dblAvgRate = @dblUOMRate;
								else
									set @dblUOMRate = @dblAvgRate;

          						UPDATE #tblmain SET COGS=@dblQty * @dblAvgRate WHERE  PRODUCTID=@ProductID AND InvDocDetailsID=@INVID
							end
						   --Code added to stop -ve avg rate
							if (@ShowNegativeStock=0)
							begin
								if (@OpBalanceValue < 0)
									set @OpBalanceValue = 0;
							end
							set @OpBalanceValue += @dblQty * @dblUOMRate;
						end

						if (@Valuation != 4 and @Valuation != 5 and @Valuation != 6)
						begin
							if (@ShowNegativeStock=0)
							begin
								if (@OpBalanceQty > 0)
									set @dblAvgRate = @OpBalanceValue / @OpBalanceQty;
								else
								begin
									set @dblAvgRate = 0;
									set @OpBalanceValue = 0;
								end
							end
							else
							begin
								if (@OpBalanceQty != 0)
									set @dblAvgRate = @OpBalanceValue / @OpBalanceQty;
							end
						end


						if (@dblQty > 0)
						begin
							if (@Valuation = 1 or @Valuation = 2)
							begin
								SELECT @lstCNT=@lstCNT+1
								INSERT INTO #lstRecTbl2(ID,Qty,Rate,DocumentType)
								VALUES(@lstCNT,@dblQty,@dblUOMRate,@RDocumentType)
							end
						end
					end
					else
					begin
						set  @OpBalanceQty -= @dblQty;
						if (@Valuation = 3 or @Valuation = 4 or @Valuation = 5)--WEIGHTED AVGG
						begin
							set @OpBalanceValue = @dblAvgRate * @OpBalanceQty;
							UPDATE #tblmain SET COGS=@dblQty * @dblAvgRate WHERE  PRODUCTID=@ProductID AND InvDocDetailsID=@INVID
						end
						else if (@Valuation = 6)--Periodic Monthly
						begin
							set @strPeriodMn = @RstrPeriodMn;
							set @OpBalanceValue = @dblAvgRate * @OpBalanceQty;
							select  @dblUOMRate=myAvgRate,@dblAvgRate=myAvgRate  from #tblPeriodicAvgRate  with(nolock) where monthyear=@strPeriodMn
							UPDATE #tblmain SET COGS=@dblQty * @dblAvgRate WHERE  PRODUCTID=@ProductID AND InvDocDetailsID=@INVID
						end
						else if (@Valuation = 7)--Invoice Rate
						begin
							set @OpBalanceValue = @OpBalanceValue -@RIssValue
							if (@OpBalanceValue < 0)
								set @OpBalanceValue = 0;
							if (@OpBalanceQty = 0)
							begin
								set @dblAvgRate = 0;
								set @OpBalanceValue = 0;
							end
							else
								set @dblAvgRate = @OpBalanceValue / @OpBalanceQty;
		                        
							UPDATE #tblmain SET COGS=@RIssValue WHERE  PRODUCTID=@ProductID AND InvDocDetailsID=@INVID
						end
						else if (@Valuation = 8)--Batch Rate
						begin
							set @OpBalanceValue = @OpBalanceValue - @RBatchValue
							if (@OpBalanceValue < 0)
								set @OpBalanceValue = 0;
							if (@OpBalanceQty = 0)
							begin
								set @dblAvgRate = 0;
								set @OpBalanceValue = 0;
							end
							else
							   set  @dblAvgRate = @OpBalanceValue / @OpBalanceQty;
							UPDATE #tblmain SET COGS=@RBatchValue WHERE  PRODUCTID=@ProductID AND InvDocDetailsID=@INVID
						end
						else if (@Valuation = 1 or @Valuation = 2)--FIFO & LIFO
						begin
							set @dblCOGS = 0
							if (@Valuation=1)
							begin
								while(@lstI<=@lstCNT)
								begin
									SELECT @lstQty=Qty,@lstRate=Rate FROM #lstRecTbl2 with(nolock) WHERE ID=@lstI
									 set @dblQty = @dblQty -@lstQty
									if(@dblQty<0)
									begin
										set @dblCOGS=@dblCOGS+(@lstQty+@dblQty)*@lstRate
										UPDATE #lstRecTbl2 SET Qty=-@dblQty WHERE ID=@lstI
										break;
									end
									else
									begin
										set @dblCOGS=@dblCOGS+(@lstQty*@lstRate)
										set @lstI=@lstI+1
										if (@dblQty=0)
											break;
									end
								end
							end
							else if (@Valuation=2)
							begin
								set @lstI=@lstCNT
								while(@lstI>=1)
								begin
									SELECT @lstQty=Qty,@lstRate=Rate FROM #lstRecTbl2 with(nolock) WHERE ID=@lstI
									if @lstQty IS NULL
										continue;
									
									set @dblQty=@dblQty-@lstQty
									if(@dblQty<0)
									begin
									
										set @dblCOGS=@dblCOGS+(@lstQty+@dblQty)*@lstRate
										UPDATE #lstRecTbl2 SET Qty=-@dblQty WHERE ID=@lstI
										break;
									end
									else
									begin
										set @dblCOGS=@dblCOGS+(@lstQty*@lstRate);
									
										DELETE FROM #lstRecTbl2 WHERE ID=@lstI
										set @lstI=@lstI-1
										set @lstCNT=@lstCNT-1
										if (@dblQty=0)
											break;
									end
								end
							end
							
							 set  @OpBalanceValue = @OpBalanceValue - @dblCOGS;

							if (@OpBalanceValue < 0)
								set @OpBalanceValue = 0;

							if (@Valuation != 4 and @Valuation != 5)
							begin
								if (@OpBalanceQty > 0)
									set @dblAvgRate = @OpBalanceValue / @OpBalanceQty;
							end
							UPDATE #tblmain SET COGS=@dblCOGS WHERE  PRODUCTID=@ProductID AND InvDocDetailsID=@INVID
						end
					end

					if (@OpBalanceQty = 0)
						set @OpBalanceValue = 0
		                
					UPDATE #tblmain SET AvgRate=@dblAvgRate, BalanceQty=@OpBalanceQty,BalanceValue=@OpBalanceValue WHERE  PRODUCTID=@ProductID  AND InvDocDetailsID=@INVID
			SET @I=@I+1
			END --Product Transactions Loop End
		
			IF @OpBalanceQty=0
				SET @OpBalanceValue=0
			
			DELETE TI FROM #TblOpening TI WITH(NOLOCK) WHERE TI.ProductID=@ProductID 
			DELETE TT FROM #TblOpeningTransaction TT WITH(NOLOCK) WHERE TT.ProductID=@ProductID 
		--SET @PR_I=@PR_I+1
		--END --Produt Loop End
		--End Avg Rate calculation
		
		SET @PRD_I=@PRD_I+1
	END
	print 'END OP CALC'
	print convert(varchar(24),getdate(),121)
	--SELECT * FROM #TBLMAIN WITH(NOLOCK)			
	--Products Opening Data
	--SELECT * FROM #TblOpening WITH(NOLOCK) order by id
	
	--SELECT @BalQty,@AvgRate,@BalValue
	--SELECT * FROM #TblOpeningTransaction WITH(NOLOCK)
	
	--declare @sqry nvarchar(max)
	--set @sqry=''
	--set @sqry=N'UPDATE OP SET OP.PRODUCTNAME=T.PRODUCTNAME FROM #tblmainOP OP WITH(NOLOCK) JOIN #TblProds T WITH(NOLOCK) ON T.ProductID=OP.ProductID'
	--EXEC sp_executesql @sqry 
	UPDATE OP SET OP.PRODUCTNAME=T.PRODUCTNAME FROM #tblmainOP OP WITH(NOLOCK) JOIN #TblProds T WITH(NOLOCK) ON T.ProductID=OP.ProductID		
	if (@Valuation=5 or @Valuation=6)
	begin
		SELECT * FROM #tblmainOP WITH(NOLOCK)
		UNION ALL
		SELECT * FROM #tblmain WITH(NOLOCK) order by id 
	end
	else
	begin
		print 'START SELECT TBLMAIN'
		print convert(varchar(24),getdate(),121)
		SELECT * FROM #tblmain WITH(NOLOCK)
		UNION ALL
		SELECT * FROM #tblmainOP WITH(NOLOCK)
		print 'END SELECT TBLMAIN'
		--print convert(varchar(24),getdate(),121)
		--print 'START SELECT TBLMAIN'
		--print convert(varchar(24),getdate(),121)
		----SELECT * FROM #tblmainOP WITH(NOLOCK)
		--declare @sSQL nvarchar(max)
		--set @sSQL=''
		--set @sSQL='select '+ convert(nvarchar(max),@SelectCols) +' From #tblmainop with(nolock) '
		--set @sSQL= @sSQL+' UNION ALL'
		--set @sSQL= @sSQL+' select '+ convert(nvarchar(max),@SelectCols) +' From #tblmain with(nolock)'
		--print @sSQL
		--EXEC sp_executesql @sSQL
		
		print 'END SELECT TBLMAIN'
		print convert(varchar(24),getdate(),121)
	end
	
	DROP TABLE #tblmain
	DROP TABLE #tblmainOP
	DROP TABLE #TblTransactions
	DROP TABLE #Tblextracols
	DROP TABLE #lstRecTbl2
	DROP TABLE #TblProds
	DROP TABLE #Tbl
	DROP TABLE #lstRecTbl
	DROP TABLE #TblOpening
	DROP TABLE #TblOpeningTransaction
	DROP TABLE #tblPeriodicAvgRate
	
SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
