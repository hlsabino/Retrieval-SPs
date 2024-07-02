USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_AvgRate]
	@IsOpening [bit],
	@ProductID [int],
	@TagSQL [nvarchar](max) = NULL,
	@WHERE [nvarchar](max),
	@FromDate [datetime],
	@ToDate [datetime],
	@IncludeUpPostedDocs [bit],
	@Valuation [int] = 0,
	@CurrencyType [int],
	@CurrencyID [int] = 0,
	@SortTransactionsBy [nvarchar](50) = '',
	@IsMnWise [bit] = 0,
	@OpBalanceQty [float] OUTPUT,
	@dblAvgRate [float] OUTPUT,
	@OpBalanceValue [float] OUTPUT,
	@COGS [float] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON;  
	DECLARE @SQL NVARCHAR(MAX),@TotalSaleSQL NVARCHAR(MAX),@RecQty FLOAT,@RecRate FLOAT,@RecValue FLOAT,@VoucherType INT,@DimWhere NVARCHAR(MAX),
			@I INT,@COUNT INT,@TotalSaleQty FLOAT,@ID INT,@UnAppSQL NVARCHAR(50),@DocumentType INT,@Order NVARCHAR(100),@CloseDt nvarchar(20),
			@CurrWHERE nvarchar(30),@ValColumn nvarchar(20),@GrossColumn nvarchar(20),@Date float,@IFromDate FLOAT,@ShowNegativeStock bit
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,Date FLOAT,Qty FLOAT,RecRate FLOAT,RecValue FLOAT,VoucherType INT,DocumentType INT)
	DECLARE @TransactionsFound BIT,@SALESQTY FLOAT,@RecRateColumn nvarchar(100),@TransactionsByOp nvarchar(100),@TransactionsByOpHardClose nvarchar(50),
			@DateFilterCol nvarchar(60),@DateFilterOp1 nvarchar(120),@DateFilterOp2 nvarchar(80)

	if(select Value from adm_globalpreferences with(nolock) where Name='ShowNegativeStockInReports')='True'
		set @ShowNegativeStock=1
	else
		set @ShowNegativeStock=0

	SELECT @dblAvgRate=0, @OpBalanceQty=0,@OpBalanceValue=0
	
	SET @IFromDate=convert(int,@FromDate)
	
	IF @Valuation=0
		SELECT @Valuation=ValuationID FROM INV_Product WITH(NOLOCK) WHERE ProductID=@ProductID
	
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
	
	--select convert(datetime,@CloseDt),@FromDate
	
	if @SortTransactionsBy=''
	begin
		set @SortTransactionsBy='OP,DocDate'
		set @TransactionsByOp='D.DocDate DocDate'
		set @TransactionsByOpHardClose=''
		set @DateFilterCol=' AND D.DocDate<=@ToDate'
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
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
		set @TransactionsByOp='D.CreatedDate DocDate,D.CreatedDate CreateTime'
		set @TransactionsByOpHardClose=',null CreateTime'
		set @DateFilterCol=' AND D.CreatedDate<@ToDate+1'
		set @DateFilterOp1=' AND (D.CreatedDate<@FromDate OR (D.DocumentType=3 AND D.CreatedDate<@ToDate+1))'
		set @DateFilterOp2=' AND D.CreatedDate<@FromDate'
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
		set @TransactionsByOp='D.DocDate DocDate,D.CreatedDate CTime'
		set @TransactionsByOpHardClose=',null CTime'
		set @DateFilterCol=' AND D.DocDate<=@ToDate'
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
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
		set @TransactionsByOp='D.ModifiedDate DocDate,D.ModifiedDate ModTime'
		set @TransactionsByOpHardClose=',null ModTime'
		set @DateFilterCol=' AND D.ModifiedDate<@ToDate+1'
		set @DateFilterOp1=' AND (D.ModifiedDate<@FromDate OR (D.DocumentType=3 AND D.ModifiedDate<@ToDate+1))'
		set @DateFilterOp2=' AND D.ModifiedDate<@FromDate'
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
		set @TransactionsByOp='D.DocDate,D.ModifiedDate ModTime'
		set @TransactionsByOpHardClose=',null ModTime'
		set @DateFilterCol=' AND D.DocDate<=@ToDate'
		set @DateFilterOp1=' AND (D.DocDate<@FromDate OR (D.DocumentType=3 AND D.DocDate<=@ToDate))'
		set @DateFilterOp2=' AND D.DocDate<@FromDate'
		if(@CloseDt is not null)
		begin
			set @DateFilterCol=' and D.DocDate>='+@CloseDt+@DateFilterCol
			set @DateFilterOp1=' and D.DocDate>='+@CloseDt+@DateFilterOp1
			set @DateFilterOp2=' and D.DocDate>='+@CloseDt+@DateFilterOp2
		end
	end
	
	set @DimWhere=@TagSQL
	IF @TagSQL like '%DCCCNID%'
	begin
		set @TagSQL=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@TagSQL
		set @Order=@SortTransactionsBy+',ST DESC,VoucherType DESC,VoucherNo,Qty DESC'
	end
	ELSE
		set @Order=@SortTransactionsBy+',ST DESC,VoucherNo,VoucherType DESC,Qty DESC'
		
	SET @SQL='DECLARE @FromDate FLOAT,@ToDate FLOAT,@ProductID INT
	SET @FromDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+'
	SET @ToDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@ToDate))+'
	SET @ProductID='+CONVERT(NVARCHAR,@ProductID)+' '
	
	if @Valuation=4
		set @RecRateColumn=','+@GrossColumn+'/UOMConvertedQty RecRate,'+@GrossColumn+' RecValue'
	else
		set @RecRateColumn=','+@ValColumn+'/UOMConvertedQty RecRate,'+@ValColumn+' RecValue'
	
	--select @IsOpening,@FromDate,@ToDate
	
	IF @IsOpening=1
	BEGIN
		SET @SQL=@SQL+'SELECT DocDate,Qty,RecRate,RecValue,VoucherType,DocumentType FROM ('
		if(@CloseDt is not null)
		begin
			SET @SQL=@SQL+'
		SELECT CloseDate DocDate'+@TransactionsByOpHardClose+',''HardClose'' VoucherNo,Qty,Rate RecRate,BalValue RecValue,1 VoucherType,0 DocumentType,1 OP,2 ST
		FROM INV_ProductClose DCC WITH(NOLOCK)
		WHERE ProductID=@ProductID AND CloseDate='+convert(nvarchar,(@CloseDt-1))+@DimWhere
			SET @SQL=@SQL+' UNION ALL '
		end
		SET @SQL=@SQL+'
		SELECT '+@TransactionsByOp+',D.VoucherNo,D.UOMConvertedQty Qty'+@RecRateColumn+',D.VoucherType,D.DocumentType,case when D.DocumentType=3 then 1 else 2 end OP,case when D.DocumentType=5 then 1 else 2 end ST
		FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
		WHERE D.ProductID=@ProductID AND D.IsQtyIgnored=0 AND D.UOMConvertedQty!=0 AND D.VoucherType=1'+@DateFilterOp1+@UnAppSQL+@CurrWHERE+@WHERE
		--IF @Valuation=3
		--BEGIN		
			SET @SQL=@SQL+' UNION ALL
			SELECT '+@TransactionsByOp+',D.VoucherNo,D.UOMConvertedQty,0 RecRate'
			if @Valuation=7
				SET @SQL=@SQL+',D.'+@ValColumn+' RecValue'
			else if @Valuation=8
					SET @SQL=@SQL+',CASE WHEN P.ProductTypeID=5 THEN ISNULL((SELECT TOP 1 BD.'+@ValColumn+'/BD.Quantity FROM INV_DocDetails BD WITH(NOLOCK) WHERE BD.InvDocDetailsID=D.RefInvDocDetailsID AND BD.BatchID=D.BatchID),0)*D.Quantity ELSE D.'+@ValColumn+' END RecValue'
			else
				SET @SQL=@SQL+',0 RecValue'
			SET @SQL=@SQL+',-1 VoucherType,D.DocumentType,2 OP,case when D.DocumentType=5 then 1 else 0 end ST
			FROM INV_DocDetails D WITH(NOLOCK) '
			if @Valuation=8
					SET @SQL=@SQL+'INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID '
			SET @SQL=@SQL+@TagSQL+'
			WHERE D.ProductID=@ProductID AND D.IsQtyIgnored=0 AND D.VoucherType=-1'+@DateFilterOp2+@UnAppSQL+@CurrWHERE+@WHERE
		--END
		--ELSE
		--BEGIN
		--	SET @TotalSaleSQL='SELECT @TotalSaleQty=SUM(UOMConvertedQty) FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
		--		WHERE D.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND IsQtyIgnored=0 AND D.VoucherType=-1
		--		AND CONVERT(DATETIME,D.DocDate)<'+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+@UnAppSQL
		--END
	END
	ELSE
	BEGIN
		SET @SQL=@SQL+'SELECT DocDate,Qty,RecRate,RecValue,VoucherType,DocumentType FROM ('
		if(@CloseDt is not null)
		begin
			SET @SQL=@SQL+'
		SELECT CloseDate DocDate'+@TransactionsByOpHardClose+',''HardClose'' VoucherNo,Qty,Rate RecRate,BalValue RecValue,1 VoucherType,0 DocumentType,1 OP,2 ST
		FROM INV_ProductClose DCC WITH(NOLOCK)
		WHERE ProductID=@ProductID AND CloseDate='+convert(nvarchar,(@CloseDt-1))+@DimWhere
			SET @SQL=@SQL+' UNION ALL '
		end

		SET @SQL=@SQL+'
		SELECT '+@TransactionsByOp+',D.VoucherNo,D.UOMConvertedQty Qty'+@RecRateColumn+',D.VoucherType,D.DocumentType,case when D.DocumentType=3 then 1 else 2 end OP,case when D.DocumentType=5 then 1 else 2 end ST
		FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
		WHERE D.ProductID=@ProductID AND D.IsQtyIgnored=0 AND D.UOMConvertedQty!=0 AND D.VoucherType=1'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE
		SET @SQL=@SQL+' UNION ALL
		SELECT '+@TransactionsByOp+',D.VoucherNo,D.UOMConvertedQty,0 RecRate'
		if @Valuation=7
			SET @SQL=@SQL+',D.'+@ValColumn+' RecValue'
		else if @Valuation=8
					SET @SQL=@SQL+',CASE WHEN P.ProductTypeID=5 THEN ISNULL((SELECT TOP 1 BD.'+@ValColumn+'/BD.Quantity FROM INV_DocDetails BD WITH(NOLOCK) WHERE BD.InvDocDetailsID=D.RefInvDocDetailsID AND BD.BatchID=D.BatchID),0)*D.Quantity ELSE D.'+@ValColumn+' END RecValue'
		else
			SET @SQL=@SQL+',0 RecValue'
		SET @SQL=@SQL+',-1 VoucherType,D.DocumentType,2 OP,case when D.DocumentType=5 then 1 else 0 end ST
		FROM INV_DocDetails D WITH(NOLOCK) '
		if @Valuation=8
			SET @SQL=@SQL+'INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=D.ProductID '
		SET @SQL=@SQL+@TagSQL+'
		WHERE D.ProductID=@ProductID AND D.IsQtyIgnored=0 AND D.VoucherType=-1'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE


	END

	SET @SQL=@SQL+') AS T'

	--BELOW CODE COMMENTED TO ADD ST ORDER BY 
	SET @SQL=@SQL+' ORDER BY '+@Order--DocDate,ST DESC,VoucherNo,VoucherType DESC'
	/*IF @Valuation=1
		--SET @SQL=@SQL+' ORDER BY DocDate,D.InvDocDetailsID'      
		SET @SQL=@SQL+' ORDER BY DocDate,VoucherType DESC,VoucherNo'   
	ELSE IF @Valuation=2
		--SET @SQL=@SQL+' ORDER BY DocDate DESC,D.InvDocDetailsID DESC'      
		SET @SQL=@SQL+' ORDER BY DocDate,VoucherType DESC,VoucherNo'   
	ELSE IF @Valuation=3
		SET @SQL=@SQL+' ORDER BY DocDate,VoucherType DESC,VoucherNo'   */
	print(@SQL)
	INSERT INTO @Tbl(Date,Qty,RecRate,RecValue,VoucherType,DocumentType)
	EXEC(@SQL)
	
	--select * from @Tbl

	--Set Last Purchase Rate
	if (@Valuation=4 or @Valuation=5)
	begin
		declare @LPRateI int
		select @LPRateI=count(*) from @Tbl		
		while(@LPRateI>0)
		begin
			SELECT @dblAvgRate=RecRate FROM @Tbl where ID=@LPRateI and VoucherType=1
			if @@rowcount=1
				break
			set @LPRateI=@LPRateI-1
		end
	end

	DECLARE @SPInvoice cursor, @nStatusOuter int
	DECLARE @dblValue FLOAT,@dblUOMRate FLOAT,@dblCOGS FLOAT
	set @COGS=0
	
	IF @Valuation=6
	BEGIN
		DECLARE @dtDate datetime,@Mn int,@Yr int,@PrMn int,@PrYr int,@dblQty float,@dblMnOpValue float,@dblIssueQty float,@dblSelectedIssueQty float,@dblPrevAvgRate float
	
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
		set @dblSelectedIssueQty=0
		
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
                    set @COGS=@COGS+@dblSelectedIssueQty*@dblAvgRate
                 end
                 set @PrMn=@Mn
                 set @PrYr=@Yr
                 set @dblIssueQty=0
                 set @dblSelectedIssueQty=0
                 set @dblValue=0
            end
            if @VoucherType=1
            begin
			    if (@DocumentType!=6 and @DocumentType!=39)
                begin
                    set @dblQty=@dblQty+@RecQty
                    set @dblValue=@dblValue+@RecValue
                end
            end
            else
            begin
                set @dblIssueQty=@dblIssueQty+@RecQty
                if(@Date>=@IFromDate)
					set @dblSelectedIssueQty=@dblSelectedIssueQty+@RecQty
            end
			
			if @IsMnWise=1
			begin
				set @OpBalanceQty=@dblQty-@dblIssueQty
				set @dblAvgRate=@dblPrevAvgRate
				if(@PrMn is not null)
				begin				
					if @dblQty>0
						set @dblAvgRate=(@dblMnOpValue+@dblValue)/@dblQty
				end
				set @OpBalanceValue=@OpBalanceQty*@dblAvgRate
				update #TblAvgMn
				set  BalQty=@OpBalanceQty,AvgRate=@dblAvgRate
					,BalValue=case when @OpBalanceQty!=0 then @OpBalanceValue else 0 end
					,IsDone=1
				where @Date between FromDate and ToDate
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
        set @COGS=@COGS+@dblSelectedIssueQty*@dblAvgRate
	END
	ELSE
	BEGIN
		SET @SPInvoice = cursor for 
		SELECT Date,VoucherType,Qty,RecValue,ID,DocumentType FROM @Tbl 
				
		OPEN @SPInvoice 
		SET @nStatusOuter = @@FETCH_STATUS
				
		--SELECT * FROM @Tbl
		--SELECT getdate() Loop_Start
			
		--SELECT @I=1, @COUNT=COUNT(*) FROM @Tbl
		
		FETCH NEXT FROM @SPInvoice Into @Date,@VoucherType,@RecQty,@RecValue,@ID,@DocumentType
		SET @nStatusOuter = @@FETCH_STATUS
		
		DECLARE @lstI INT,@lstCNT INT,@lstQty FLOAT,@lstRate FLOAT,@lstDocumentType INT
		SELECT @OpBalanceValue=0,@OpBalanceQty=0,@lstI=1,@lstCNT=0
		
		DECLARE @lstRecTbl AS TABLE(ID INT IDENTITY(1,1) PRIMARY KEY,Qty FLOAT,Rate FLOAT,DocumentType INT)
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
	                     
				if ((@RecQty>0 and @ShowNegativeStock=0) or (@RecQty!=0 and @ShowNegativeStock=1))--NegStkChange (@RecQty>0)
				begin
					--For Sales Return Voucher Avg Rate will be current Avg Rate
					if (@DocumentType=6 or @DocumentType=39)
					BEGIN
						if @dblAvgRate IS NULL
							set @dblAvgRate=0
						if (@Valuation=7 or @Valuation=8)
							set @dblAvgRate=@dblUOMRate
                        else
							set @dblUOMRate=@dblAvgRate
					end
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
					if (@Valuation=1)--FIFO
					begin
						INSERT INTO @lstRecTbl(Qty,Rate,DocumentType)
						VALUES(@RecQty,@dblUOMRate,@DocumentType);
					    						
						SELECT @lstCNT=@lstCNT+1

					end
					else if (@Valuation=2)--LIFO
					begin
						INSERT INTO @lstRecTbl(Qty,Rate,DocumentType)
						VALUES(@RecQty,@dblUOMRate,@DocumentType);
					    						
						SELECT @lstCNT=@lstCNT+1
					end
				end
				
			end
			else
			begin
				set @OpBalanceQty=@OpBalanceQty-@RecQty

				if (@Valuation=3 or @Valuation=4 or @Valuation=5)--WEIGHTED AVGG
				begin
					set @OpBalanceValue = @dblAvgRate * @OpBalanceQty;
					if(@Date>=@IFromDate)
						set @COGS=@COGS+@dblAvgRate*@RecQty
				end
				else if (@Valuation=7 OR @Valuation=8)--Invoice Rate
				begin
					set @OpBalanceValue=@OpBalanceValue-@RecValue
					if(@OpBalanceValue<0)
						set @OpBalanceValue=0
					if(@OpBalanceQty<=0)
					begin
						set @dblAvgRate=0
						set @OpBalanceValue=0
					end
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
							SELECT @lstQty=Qty,@lstRate=Rate FROM @lstRecTbl WHERE ID=@lstI
							set @RecQty=@RecQty-@lstQty
							if(@RecQty<0)
							begin
								set @dblCOGS=@dblCOGS+(@lstQty+@RecQty)*@lstRate
								if(@Date>=@IFromDate)
									set @COGS=@COGS+(@lstQty+@RecQty)*@lstRate
								UPDATE @lstRecTbl SET Qty=-@RecQty WHERE ID=@lstI								
								break;
							end
							else
							begin
								set @dblCOGS=@dblCOGS+(@lstQty*@lstRate);
								if(@Date>=@IFromDate)
									set @COGS=@COGS+(@lstQty*@lstRate)
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
								if(@Date>=@IFromDate)
									set @COGS=@COGS+(@lstQty+@RecQty)*@lstRate								
								UPDATE @lstRecTbl SET Qty=-@RecQty WHERE ID=@lstI
								break;
							end
							else
							begin
								set @dblCOGS=@dblCOGS+(@lstQty*@lstRate);
								if(@Date>=@IFromDate)
									set @COGS=@COGS+(@lstQty*@lstRate)
								DELETE FROM @lstRecTbl WHERE ID=@lstI						        
								set @lstI=@lstI-1
								if (@RecQty=0)
									break;
							end
						end
					end

					set @OpBalanceValue=@OpBalanceValue-@dblCOGS;
					--set @COGS=@COGS+@dblCOGS

					if (@OpBalanceValue < 0)
						set @OpBalanceValue = 0;
						
					if (@Valuation!=4 and @Valuation!=5)
					begin
						if (@OpBalanceQty > 0)
							set @dblAvgRate = @OpBalanceValue / @OpBalanceQty;
						--else
							--set @dblAvgRate = 0;
					end

				end
			end
			
			if @IsMnWise=1
			begin
				update #TblAvgMn
				set  BalQty=@OpBalanceQty,AvgRate=@dblAvgRate
					,BalValue=case when @OpBalanceQty!=0 then @OpBalanceValue else 0 end
					,IsDone=1
				where @Date between FromDate and ToDate
			end
			

			FETCH NEXT FROM @SPInvoice Into @Date,@VoucherType,@RecQty,@RecValue,@ID,@DocumentType
			SET @nStatusOuter = @@FETCH_STATUS
		END
	END

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
	
	if @IsMnWise=1 and @OpBalanceQty IS NOT NULL
	begin
		set @I=null
		select @I=max(ID) from #TblAvgMn
	
		update #TblAvgMn
		set  BalQty=@OpBalanceQty,AvgRate=@dblAvgRate,BalValue=@OpBalanceValue,IsDone=1
		where ID=@I
	end
--select * from #TblAvgMn


	--IF @Qty>0
	--BEGIN
	--	select * from @lstRecTbl
	--	SELECT @ProductID ProductID,@Valuation Valuation, @OpBalanceQty Qty,@dblAvgRate AvgRate,@OpBalanceValue StockValue--getdate() Loop_END,
	--END
	--IF @InclueTransactions=1
	--BEGIN 
	--	IF @Valuation=1 OR @Valuation=2
	--		SELECT @ProductID ProductID,Qty,RecRate Rate FROM @Tbl WHERE ID>=@ID --ORDER BY ID
	--	ELSE
	--		SELECT NULL ProductID,NULL Qty, NULL Rate WHERE 1<>1
	--END
	
	--SELECT @ProductID ProductID,Qty,RecRate Rate FROM @Tbl WHERE ID>=@ID
	
--SELECT @ProductID ProductID,@Valuation Valuation, @OpBalanceQty Qty,@dblAvgRate AvgRate,@OpBalanceValue StockValue--getdate() Loop_END,
GO
