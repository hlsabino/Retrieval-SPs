USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_StockLedger]
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
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@From NVARCHAR(20),@To NVARCHAR(20),@TagSQL NVARCHAR(MAX),@Order NVARCHAR(100),@CloseDt nvarchar(20),
			@PRD_I INT,@PRD_COUNT INT,@ProductID INT,@UnAppSQL NVARCHAR(50),@Valuation INT,@ShowNegativeStock bit,
			@CurrWHERE nvarchar(30),@ValColumn nvarchar(20),@GrossColumn nvarchar(20),@TransactionsBy nvarchar(100),
			@TransactionsByOp nvarchar(100),@TransactionsByOpHardClose nvarchar(50),
			@DateFilterCol nvarchar(60),@DateFilterLPRate nvarchar(60),@DateFilterOp1 nvarchar(120),@DateFilterOp2 nvarchar(80)

	DECLARE @TblOpening AS TABLE(ProductID INT,OpQty FLOAT,AvgRate FLOAT,OpValue FLOAT,DocumentType INT)

	if(select Value from adm_globalpreferences with(nolock) where Name='ShowNegativeStockInReports')='True'
		set @ShowNegativeStock=1
	else
		set @ShowNegativeStock=0
		
	SET @From=CONVERT(FLOAT,@FromDate)
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
	
	if @SortTransactionsBy=''
	begin
		set @SortTransactionsBy='OP,DocDate'
		set @TransactionsBy='CONVERT(DATETIME,D.DocDate) DocDate'
		set @TransactionsByOp='D.DocDate DocDate'
		set @TransactionsByOpHardClose=''
		set @DateFilterCol=' AND D.DocDate BETWEEN '+@From+' AND '+@To
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
		set @DateFilterLPRate=' AND D.DocDate<='+@To
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.DocDate>='+@CloseDt+@DateFilterCol
			set @DateFilterOp1=' and D.DocDate>='+@CloseDt+@DateFilterOp1
			set @DateFilterOp2=' and D.DocDate>='+@CloseDt+@DateFilterOp2
		end		
	end
	else if @SortTransactionsBy='CreatedDate'
	begin
		set @SortTransactionsBy='OP,DocDate,CreateTime'
		set @TransactionsBy='CONVERT(DATETIME,D.CreatedDate) DocDate,CONVERT(DATETIME,D.CreatedDate) CreateTime'
		set @TransactionsByOp='D.CreatedDate DocDate,D.CreatedDate CreateTime'
		set @TransactionsByOpHardClose=',null CreateTime'
		set @DateFilterCol=' AND D.CreatedDate>='+@From+' AND D.CreatedDate<'+convert(nvarchar,convert(int,@To)+1)
		set @DateFilterOp1=' AND (D.CreatedDate<@FromDate OR (D.DocumentType=3 AND D.CreatedDate<@ToDate+1))'
		set @DateFilterOp2=' AND D.CreatedDate<@FromDate'
		set @DateFilterLPRate=' AND D.CreatedDate<'+convert(nvarchar,convert(int,@To)+1)
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.CreatedDate>='+@CloseDt+@DateFilterCol
			set @DateFilterOp1=' and D.CreatedDate>='+@CloseDt+@DateFilterOp1
			set @DateFilterOp2=' and D.CreatedDate>='+@CloseDt+@DateFilterOp2
		end	
	end
	else if @SortTransactionsBy='DocDate,CreatedDate'
	begin
		set @SortTransactionsBy='OP,DocDate,CTime'
		set @TransactionsBy='CONVERT(DATETIME,D.DocDate) DocDate,CONVERT(DATETIME,D.CreatedDate) CTime'
		set @TransactionsByOp='D.DocDate DocDate,D.CreatedDate CTime'
		set @TransactionsByOpHardClose=',null CTime'
		set @DateFilterCol=' AND D.DocDate BETWEEN '+@From+' AND '+@To
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
		set @DateFilterLPRate=' AND D.DocDate<='+@To
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.DocDate>='+@CloseDt+@DateFilterCol
			set @DateFilterOp1=' and D.DocDate>='+@CloseDt+@DateFilterOp1
			set @DateFilterOp2=' and D.DocDate>='+@CloseDt+@DateFilterOp2
		end
	end
	else if @SortTransactionsBy='ModifiedDate'
	begin
		set @SortTransactionsBy='OP,DocDate,ModTime'
		set @TransactionsBy='CONVERT(DATETIME,D.ModifiedDate) DocDate,CONVERT(DATETIME,D.ModifiedDate) ModTime'
		set @TransactionsByOp='D.ModifiedDate DocDate,D.ModifiedDate ModTime'
		set @TransactionsByOpHardClose=',null ModTime'
		set @DateFilterCol=' AND D.ModifiedDate>='+@From+' AND D.ModifiedDate<'+convert(nvarchar,convert(int,@To)+1)
		set @DateFilterOp1=' AND (D.ModifiedDate<@FromDate OR (D.DocumentType=3 AND D.ModifiedDate<@ToDate+1))'
		set @DateFilterOp2=' AND D.ModifiedDate<@FromDate'
		set @DateFilterLPRate=' AND D.ModifiedDate<'+convert(nvarchar,convert(int,@To)+1)
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.ModifiedDate>='+@CloseDt+@DateFilterCol
			set @DateFilterOp1=' and D.ModifiedDate>='+@CloseDt+@DateFilterOp1
			set @DateFilterOp2=' and D.ModifiedDate>='+@CloseDt+@DateFilterOp2
		end
	end
	else if @SortTransactionsBy='DocDate,ModifiedDate'
	begin
		set @SortTransactionsBy='OP,DocDate,ModTime'
		set @TransactionsBy='CONVERT(DATETIME,D.DocDate) DocDate,CONVERT(DATETIME,D.ModifiedDate) ModTime'
		set @TransactionsByOp='D.DocDate,D.ModifiedDate ModTime'
		set @TransactionsByOpHardClose=',null ModTime'
		set @DateFilterCol=' AND D.DocDate BETWEEN '+@From+' AND '+@To
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
		set @DateFilterLPRate=' AND D.DocDate<='+@To
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.DocDate>='+@CloseDt+@DateFilterCol
			set @DateFilterOp1=' and D.DocDate>='+@CloseDt+@DateFilterOp1
			set @DateFilterOp2=' and D.DocDate>='+@CloseDt+@DateFilterOp2
		end
	end	
	
	SET @TagSQL=''
	if (@LocationWHERE IS NOT NULL AND @LocationWHERE<>'') OR @DIMWHERE<>''
	begin
		if(@LocationWHERE IS NOT NULL AND @LocationWHERE<>'')
			set @DIMWHERE=@DIMWHERE+' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' IN ('+@LocationWHERE+') '
		set @TagSQL=@DIMWHERE			
		set @Order=@SortTransactionsBy+',ST DESC,VoucherType DESC,VoucherNo,RecQty DESC'
	end
	else
	begin
		set @Order=@SortTransactionsBy+',ST DESC,VoucherNo,VoucherType DESC,RecQty DESC'
	end
	
	/*if @LocationWHERE IS NOT NULL AND @LocationWHERE<>''
	begin
		SET @TagSQL=' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' IN ('+@LocationWHERE+') '
		set @Order='DocDate,ST DESC,VoucherType DESC,VoucherNo'
	end
	else
	begin
		SET @TagSQL=''	
		set @Order='DocDate,ST DESC,VoucherNo,VoucherType DESC'
	end*/
	
	if(@DefValuation=4)
		set @SELECTQUERY=@SELECTQUERY+','+@GrossColumn+' Gross'
	
	if(@DefValuation=8)
		set @SELECTQUERY=@SELECTQUERY+','+@GrossColumn+' BatchValue'
		
	--case when Quantity=0 then StockValue else StockValue/Quantity end
	
	SET @SQL='
	SELECT P.ProductID,'+@TransactionsBy+',D.VoucherNo,D.InvDocDetailsID,case when D.DocumentType=5 then Dr.AccountName else A.AccountName end CustomerName,
	D.Quantity RecQty,UOM.UnitName RecUnit,D.'+@ValColumn+'/D.Quantity RecRate,D.'+@ValColumn+' RecValue,
	NULL IssQty,NULL IssUnit,NULL IssRate,NULL IssValue,D.UOMConvertedQty,D.VoucherType,D.DocumentType,case when D.DocumentType=3 then 1 else 2 end OP,case when D.DocumentType=5 then 1 else 2 end ST'
	if(@DefValuation=8)
		SET @SQL=@SQL+',D.'+@ValColumn+' BatchValue'	
	SET @SQL=@SQL+@SELECTQUERY+'
	FROM INV_DocDetails D WITH(NOLOCK) 
	INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
	LEFT JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
	LEFT JOIN COM_UOM UOM WITH(NOLOCK) ON UOM.UOMID=D.Unit
	LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.CreditAccount
	LEFT JOIN ACC_Accounts Dr WITH(NOLOCK) ON Dr.AccountID=D.DebitAccount
	WHERE P.ProductID IN ('+@Products+') AND IsQtyIgnored=0 AND D.VoucherType=1 AND D.DocumentType<>3
		AND Quantity>0'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE+' '+@TagSQL+'
	UNION ALL
	SELECT P.ProductID,'+@TransactionsBy+',D.VoucherNo,D.InvDocDetailsID,A.AccountName,
	NULL RecQty,NULL RecUnit,NULL RecRate,NULL RecValue,
	Quantity IssQty,UOM.UnitName IssUnit,D.'+@ValColumn+'/D.Quantity IssRate,D.'+@ValColumn+' IssValue,D.UOMConvertedQty,D.VoucherType,D.DocumentType,2 OP,case when D.DocumentType=5 then 1 else 0 end ST'
	if(@DefValuation=8)
		SET @SQL=@SQL+',CASE WHEN P.ProductTypeID=5 THEN ISNULL((SELECT TOP 1 BD.'+@ValColumn+'/BD.Quantity FROM INV_DocDetails BD WITH(NOLOCK) WHERE BD.InvDocDetailsID=D.RefInvDocDetailsID AND BD.BatchID=D.BatchID),0)*D.Quantity ELSE D.'+@ValColumn+' END BatchValue'	
	SET @SQL=@SQL+@SELECTQUERY+'
	FROM INV_DocDetails D WITH(NOLOCK) 
	INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
	LEFT JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
	LEFT JOIN COM_UOM UOM WITH(NOLOCK) ON UOM.UOMID=D.Unit
	LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.DebitAccount
	WHERE P.ProductID IN ('+@Products+') AND IsQtyIgnored=0 AND D.VoucherType=-1 
		AND Quantity>0'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE+' '+@TagSQL+'
	ORDER BY '+@Order--ORDER BY DocDate,VoucherType DESC,VoucherNo
	--AND Quantity>0
	
	print(@SQL)
	EXEC(@SQL)
	
	
	DECLARE @LPRateI int,@LPRateCNT int
	DECLARE @TblLastRate AS TABLE(ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,ProductID INT,Rate FLOAT)
	if (@DefValuation=4 or @DefValuation=5)
	begin
		SET @SQL='SELECT P.ProductID,'
		if @DefValuation=4
			SET @SQL=@SQL+@GrossColumn+'/UOMConvertedQty RecRate'
		else if @DefValuation=5
			SET @SQL=@SQL+@ValColumn+'/UOMConvertedQty RecRate'
		SET @SQL=@SQL+'
	FROM INV_DocDetails D WITH(NOLOCK) 
	INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID
	LEFT JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
	LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.CreditAccount
	WHERE P.ProductID IN ('+@Products+') AND IsQtyIgnored=0 AND D.VoucherType=1 AND D.DocumentType<>3
		AND Quantity>0'+@DateFilterLPRate+@UnAppSQL+@CurrWHERE+@WHERE+' '+@TagSQL+'
	ORDER BY P.ProductID,DocDate,VoucherNo'
		insert into @TblLastRate
		EXEC(@SQL)
		
		SELECT @LPRateCNT=COUNT(*) FROM @TblLastRate
	end
	
	DECLARE @TblProducts AS TABLE(ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,ProductID INT)
	DECLARE @TblOpeningTransaction AS TABLE(ProductID INT,Qty FLOAT,Rate FLOAT,DocumentType INT)--ID INT IDENTITY(1,1) NOT NULL

	INSERT INTO @TblProducts(ProductID)
	EXEC SPSplitString @Products,','
	
	SELECT @PRD_I=1,@PRD_COUNT=COUNT(*) FROM @TblProducts
				
	DECLARE @TotalSaleSQL NVARCHAR(MAX),@RecQty FLOAT,@RecRate FLOAT,@RecValue FLOAT,@VoucherType INT,
		@I INT,@COUNT INT,@TotalSaleQty FLOAT,@ID INT,@AvgRate FLOAT,@DocumentType INT
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,Date FLOAT,Qty FLOAT,RecRate FLOAT,RecValue FLOAT,VoucherType INT,DocumentType INT)
	DECLARE @TransactionsFound BIT,@SALESQTY FLOAT,@Qty FLOAT,@StockValue FLOAT,@IsOpening BIT
	DECLARE @lstRecTbl AS TABLE(ID INT,Qty FLOAT,Rate FLOAT,DocumentType INT)

	--IF @LocationWHERE IS NOT NULL AND @LocationWHERE<>''
	IF @TagSQL IS NOT NULL AND @TagSQL<>''
		SET @TagSQL=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@TagSQL
	ELSE
		SET @TagSQL=''	
		
	WHILE(@PRD_I<=@PRD_COUNT)
	BEGIN
		SELECT @ProductID=ProductID FROM @TblProducts WHERE ID=@PRD_I
		
		SELECT @AvgRate=0, @Qty=0,@StockValue=0,@IsOpening=1
		
		IF @DefValuation=0
			SELECT @Valuation=ValuationID FROM INV_Product WITH(NOLOCK) WHERE ProductID=@ProductID
			
		SET @SQL='DECLARE @FromDate FLOAT,@ToDate FLOAT,@ProductID INT
		SET @FromDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+'
		SET @ToDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@ToDate))+'
		SET @ProductID='+CONVERT(NVARCHAR,@ProductID)+' '

		IF @IsOpening=1
		BEGIN
			SET @SQL=@SQL+'SELECT DocDate,Qty,RecRate,RecValue,VoucherType,DocumentType FROM ('
			if(@CloseDt is not null)
			begin
				SET @SQL=@SQL+'
			SELECT CloseDate DocDate'+@TransactionsByOpHardClose+',''HardClose'' VoucherNo,Qty,Rate RecRate,BalValue RecValue,1 VoucherType,0 DocumentType,1 OP,2 ST
			FROM INV_ProductClose DCC WITH(NOLOCK)
			WHERE ProductID=@ProductID AND CloseDate='+convert(nvarchar,(@CloseDt-1))+@DIMWHERE
				SET @SQL=@SQL+' UNION ALL '
			end
			SET @SQL=@SQL+'
			SELECT '+@TransactionsByOp+',D.VoucherNo,D.UOMConvertedQty Qty,D.'+@ValColumn+'/D.UOMConvertedQty RecRate,D.'+@ValColumn+' RecValue,D.VoucherType,D.DocumentType,case when D.DocumentType=3 then 1 else 2 end OP,case when D.DocumentType=5 then 1 else 2 end ST
			FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
			WHERE D.ProductID=@ProductID AND D.IsQtyIgnored=0 AND D.UOMConvertedQty!=0 AND D.VoucherType=1'+@DateFilterOp1+@UnAppSQL+@CurrWHERE+@WHERE
			--IF @Valuation=3
			--BEGIN
				SET @SQL=@SQL+' UNION ALL
				SELECT '+@TransactionsByOp+',D.VoucherNo,D.UOMConvertedQty,0 RecRate'
				if @DefValuation=7
					SET @SQL=@SQL+',D.'+@ValColumn+' RecValue'
				else if @DefValuation=8
					SET @SQL=@SQL+',CASE WHEN P.ProductTypeID=5 THEN ISNULL((SELECT TOP 1 BD.'+@ValColumn+'/BD.Quantity FROM INV_DocDetails BD WITH(NOLOCK) WHERE BD.InvDocDetailsID=D.RefInvDocDetailsID AND BD.BatchID=D.BatchID),0)*D.Quantity ELSE D.'+@ValColumn+' END RecValue'
				else
					SET @SQL=@SQL+',0 RecValue'					
				SET @SQL=@SQL+',-1 VoucherType,D.DocumentType,2 OP,case when D.DocumentType=5 then 1 else 0 end ST
				FROM INV_DocDetails D WITH(NOLOCK) '
				if @DefValuation=8
					SET @SQL=@SQL+'INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID '
				SET @SQL=@SQL+@TagSQL+'
				WHERE D.ProductID=@ProductID AND D.IsQtyIgnored=0 AND D.VoucherType=-1'
					+@DateFilterOp2+@UnAppSQL+@CurrWHERE+@WHERE
			--END
			--ELSE
			--BEGIN
			--	SET @TotalSaleSQL='SELECT @TotalSaleQty=SUM(UOMConvertedQty) FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
			--		WHERE D.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND IsQtyIgnored=0 AND D.VoucherType=-1
			--		AND CONVERT(DATETIME,D.DocDate)<'+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+@UnAppSQL
			--END
		END
		
		SET @SQL=@SQL+') AS T'
		
		--BELOW CODE COMMENTED TO ADD ST ORDER BY 
		SET @SQL=@SQL+' ORDER BY '+replace(@Order,',RecQty DESC',',Qty DESC')--DocDate,ST DESC,VoucherNo,VoucherType DESC'
		
		--print(@SQL)
		--print(@TotalSaleSQL)
		
		DELETE FROM @Tbl
		INSERT INTO @Tbl(Date,Qty,RecRate,RecValue,VoucherType,DocumentType)
		EXEC(@SQL)
		
		--SELECT * FROM @Tbl
		--SELECT getdate() Loop_Start
			
		SELECT @I=1, @COUNT=COUNT(*) FROM @Tbl
		
		DECLARE @SPInvoice cursor, @nStatusOuter int
		
		DECLARE @lstI INT,@lstCNT INT,@lstQty FLOAT,@lstRate FLOAT,@lstDocumentType INT
		DECLARE @dblValue FLOAT,@dblUOMRate FLOAT,@OpBalanceQty FLOAT,@dblAvgRate FLOAT,
			@OpBalanceValue FLOAT,@dblCOGS FLOAT
			
		IF @Valuation=6
		BEGIN
			DECLARE @Date float,@dtDate datetime,@Mn int,@Yr int,@PrMn int,@PrYr int,@dblQty float,@dblMnOpValue float,@dblIssueQty float,@dblPrevAvgRate float
		
			SET @SPInvoice = cursor for 
			SELECT Date,VoucherType,Qty,RecValue,ID,DocumentType FROM @Tbl
			
			OPEN @SPInvoice 
			SET @nStatusOuter = @@FETCH_STATUS
			
			--SELECT * FROM @Tbl
			--SELECT getdate() Loop_Start
				
			SELECT @I=1, @COUNT=COUNT(*) FROM @Tbl
			
			FETCH NEXT FROM @SPInvoice Into @Date,@VoucherType,@RecQty,@RecValue,@ID,@DocumentType
			SET @nStatusOuter = @@FETCH_STATUS
			
			set @dblQty=0
			set @dblValue=0
			set @OpBalanceQty=0
			set @dblMnOpValue=0
			set @dblPrevAvgRate=0
			set @dblIssueQty=0
			
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

				FETCH NEXT FROM @SPInvoice Into @Date,@VoucherType,@RecQty,@RecValue,@ID,@DocumentType
				SET @nStatusOuter = @@FETCH_STATUS
			END
			
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
			SELECT VoucherType,Qty,RecValue,ID,DocumentType FROM @Tbl
			
			OPEN @SPInvoice 
			SET @nStatusOuter = @@FETCH_STATUS
			
			FETCH NEXT FROM @SPInvoice Into @VoucherType,@RecQty,@RecValue,@ID,@DocumentType
			SET @nStatusOuter = @@FETCH_STATUS

			SELECT @OpBalanceValue=0,@OpBalanceQty=0,@lstI=1,@lstCNT=0,@dblAvgRate=0
	
			delete from @lstRecTbl
			
			--Set Last Purchase Rate
			if (@Valuation=4 or @Valuation=5)
			begin
				set @dblAvgRate=0
				set @LPRateI=@LPRateCNT
				while(@LPRateI>0)
				begin
					SELECT @dblAvgRate=Rate FROM @TblLastRate where ProductID=@ProductID and ID=@LPRateI
					if @@rowcount=1
						break
					set @LPRateI=@LPRateI-1
				end
			end
			
			SET @I=1
			WHILE(@nStatusOuter <> -1)
			BEGIN
				if(@RecQty<0)
				begin
					set @RecQty=-@RecQty
					set @VoucherType=-@VoucherType
				end	
			
				if @VoucherType=1
				begin
					--if(@OpBalanceValue<0)
					--	set @OpBalanceValue=0
						
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
							--if @dblAvgRate<0
							--begin
							--	set @dblAvgRate = 0;
							--	set @OpBalanceValue = 0;
							--end
						end
					end

					if (@RecQty>0)
					begin
						SELECT @lstCNT=@lstCNT+1
						INSERT INTO @lstRecTbl(ID,Qty,Rate,DocumentType)
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
					--else if (@Valuation=7)--Invoice Rate
					--begin
					--	set @OpBalanceValue=@OpBalanceValue-@RecValue
					--	if(@OpBalanceValue<0)
					--		set @OpBalanceValue=0
					--	if(@OpBalanceQty<=0)
					--	begin
					--		set @dblAvgRate=0
					--		set @OpBalanceValue=0
					--	end
					--	else	
					--		set @dblAvgRate=@OpBalanceValue/@OpBalanceQty
					--end
					else if (@Valuation = 1 OR @Valuation = 2)--FIFO & LIFO
					begin
						set @dblCOGS = 0;
						
						if (@Valuation=1)
						begin
							while(@lstI<=@lstCNT)
							begin
								SELECT @lstQty=Qty,@lstRate=Rate FROM @lstRecTbl WHERE ID=@lstI
								set @RecQty=@RecQty-@lstQty
								if(@RecQty<0)
								begin
									set @dblCOGS=@dblCOGS+(@lstQty+@RecQty)*@lstRate
									UPDATE @lstRecTbl SET Qty=-@RecQty WHERE ID=@lstI
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
								SELECT @lstQty=Qty,@lstRate=Rate FROM @lstRecTbl WHERE ID=@lstI
								if @lstQty IS NULL
									continue;
								
								set @RecQty=@RecQty-@lstQty
								if(@RecQty<0)
								begin
									set @dblCOGS=@dblCOGS+(@lstQty+@RecQty)*@lstRate
									UPDATE @lstRecTbl SET Qty=-@RecQty WHERE ID=@lstI
									break;
								end
								else
								begin
									set @dblCOGS=@dblCOGS+(@lstQty*@lstRate);
									DELETE FROM @lstRecTbl WHERE ID=@lstI
							        
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
							--else
							--	set @dblAvgRate = 0;
						end

					end
				end
				
				FETCH NEXT FROM @SPInvoice Into @VoucherType,@RecQty,@RecValue,@ID,@DocumentType
				SET @nStatusOuter = @@FETCH_STATUS
			END
		END -- End of else of if val=6
		--select * from @lstRecTbl
		--SELECT getdate() Loop_AVG_Start, @I _I,@COUNT _COUNT,@TotalSaleQty,@ID,@nStatusOuter nStatusOuter
			
		IF @OpBalanceQty=0
		BEGIN
			SET @OpBalanceValue=0
			--IF @TotalSaleQty IS NULL
			--BEGIN
			--	SET @Qty=NULL
			--	SET @AvgRate=NULL
			--	SET @OpBalanceValue=NULL
			--END
			--ELSE
			--BEGIN
				--SET @OpBalanceQty=-@TotalSaleQty
				--SET @dblAvgRate=0
				--SET @OpBalanceValue=0
			--END
		END
		--ELSE IF @OpBalanceQty<0
		--BEGIN
		--	SET @OpBalanceValue=0
		--END
		
		CLOSE @SPInvoice
		DEALLOCATE @SPInvoice
		
		
		IF (@OpBalanceQty<>0 or @dblAvgRate>0) -- AvgRate condition added  if stock return document is comes as first row
		BEGIN
			INSERT INTO @TblOpening
			VALUES(@ProductID,@OpBalanceQty,@dblAvgRate,@OpBalanceValue,@DocumentType)
			
			IF @OpBalanceQty>0
			BEGIN
				IF @Valuation=1
					INSERT INTO @TblOpeningTransaction(ProductID,Qty,Rate,DocumentType)
					SELECT @ProductID ProductID,Qty,Rate,DocumentType FROM @lstRecTbl WHERE ID>=@lstI --ORDER BY ID
				ELSE IF @Valuation=2
					INSERT INTO @TblOpeningTransaction(ProductID,Qty,Rate,DocumentType)
					SELECT @ProductID ProductID,Qty,Rate,DocumentType FROM @lstRecTbl ORDER BY ID
			END
		END
		
		SET @PRD_I=@PRD_I+1
	END
	
	--Products Opening Data
	SELECT * FROM @TblOpening 
	
	--SELECT @BalQty,@AvgRate,@BalValue
	SELECT * FROM @TblOpeningTransaction
	
	
SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
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
