USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_AvgRate_TEMP]
	@IsOpening [bit],
	@TempTableName [nvarchar](50),
	@ProductID [bigint],
	@WHERE [nvarchar](max),
	@Valuation [int] = 0,
	@OpBalanceQty [float] OUTPUT,
	@dblAvgRate [float] OUTPUT,
	@OpBalanceValue [float] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@TotalSaleSQL NVARCHAR(MAX),@RecQty FLOAT,@RecRate FLOAT,@RecValue FLOAT,@VoucherType INT,
			@I INT,@COUNT INT,@TotalSaleQty FLOAT,@ID INT,@UnAppSQL NVARCHAR(50),@DocumentType INT,@Order NVARCHAR(100),@Date float,@IFromDate FLOAT
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL,Date FLOAT,Qty FLOAT,RecRate FLOAT,RecValue FLOAT,VoucherType INT,DocumentType INT)
	DECLARE @TransactionsFound BIT,@SALESQTY FLOAT

	SELECT @dblAvgRate=0, @OpBalanceQty=0,@OpBalanceValue=0
	
	IF @Valuation=0
		SELECT @Valuation=ValuationID FROM INV_Product WITH(NOLOCK) WHERE ProductID=@ProductID
	
	SET @SQL='SELECT DocDate,Qty,RecRate,RecValue,VoucherType,DocumentType FROM PACT2C.dbo.'+@TempTableName+' with(nolock) WHERE '+@WHERE
	SET @SQL=@SQL+' ORDER BY ID'
	
	INSERT INTO @Tbl(Date,Qty,RecRate,RecValue,VoucherType,DocumentType)
	EXEC(@SQL)


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
	DECLARE @dblValue FLOAT,@dblUOMRate FLOAT,@dblCOGS FLOAT,@COGS float
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
		
		DECLARE @lstRecTbl AS TABLE(ID INT IDENTITY(1,1),Qty FLOAT,Rate FLOAT,DocumentType INT)
		WHILE(@nStatusOuter <> -1)
		BEGIN
			if @VoucherType=1
			begin
				--if(@OpBalanceValue<0)
				--	set @OpBalanceValue=0
						
				set @dblValue = @RecValue
				set @dblUOMRate = @dblValue / @RecQty;
				if (@OpBalanceQty < 0)
				begin
					set @OpBalanceQty = @RecQty + @OpBalanceQty;
					if (@OpBalanceQty > 0)
						set @RecQty = @OpBalanceQty;
					else
						set @RecQty = 0;
				end
				else
				begin
					SET @OpBalanceQty = @OpBalanceQty+@RecQty;
				end
				
				if (@Valuation=4 or @Valuation=5)--Last Purchase Rate/Landing Rate
					set @dblUOMRate=@dblAvgRate
	                     
				if (@RecQty > 0)
				begin
					--For Sales Return Voucher Avg Rate will be current Avg Rate
					if (@DocumentType=6 or @DocumentType=39)
						set @dblUOMRate=@dblAvgRate
					if (@OpBalanceValue < 0)
						set @OpBalanceValue=0
					set @OpBalanceValue += @RecQty*@dblUOMRate
				end
				
				if (@Valuation!=4 and @Valuation!=5)
				begin
					if (@OpBalanceQty > 0)
						set @dblAvgRate=@OpBalanceValue/@OpBalanceQty;
					else
					begin
						set @dblAvgRate = 0;
						set @OpBalanceValue = 0;
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
				else if (@Valuation=7)--Invoice Rate
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
			
			FETCH NEXT FROM @SPInvoice Into @Date,@VoucherType,@RecQty,@RecValue,@ID,@DocumentType
			SET @nStatusOuter = @@FETCH_STATUS
		END
	END

	IF @OpBalanceQty=0
	BEGIN
		SET @OpBalanceValue=0
	END

	CLOSE @SPInvoice
	DEALLOCATE @SPInvoice
	
GO
