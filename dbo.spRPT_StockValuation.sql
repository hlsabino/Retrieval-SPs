USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_StockValuation]
	@ProductList [nvarchar](max),
	@TagID [nvarchar](max),
	@TagsList [nvarchar](max) = NULL,
	@DimensionID [int],
	@LocationWHERE [nvarchar](max) = NULL,
	@DIMWHERE [nvarchar](max) = NULL,
	@WHERE [nvarchar](max),
	@ToDate [datetime],
	@IncludeUpPostedDocs [bit],
	@DefValuation [int],
	@IsTagWise [bit],
	@IgnoreTagWiseRate [bit] = 0,
	@PCRates [nvarchar](500),
	@PCFilter [nvarchar](500),
	@CurrencyType [int],
	@CurrencyID [int] = 0,
	@SortTransactionsBy [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@RecQty FLOAT,@ProductID INT,@TagSQL NVARCHAR(MAX),
			@AvgRate FLOAT,@BalQty FLOAT,@BalValue FLOAT,@COGS FLOAT,@VoucherType INT,@I INT,@COUNT INT
	create table #TblProducts(ID INT IDENTITY(1,1) NOT NULL,ProductID INT)
	declare @PCRate float,@PCi INT,@PCCnt INT,@PCcol nvarchar(50),@PCxml nvarchar(max)
	declare @TblPCRates AS TABLE(ID INT IDENTITY(1,1) NOT NULL,Rate NVARCHAR(50))
	
	create table #TblAvgMn(ID int identity(0,1), FromDate Float, ToDate Float, BalQty float,AvgRate float,BalValue float,IsDone bit)
	
	
	DECLARE @CUR_PRODUCT cursor, @nStatusOuter int
	
	SET @CUR_PRODUCT = cursor for 
	SELECT ProductID FROM #TblProducts 
	
	OPEN @CUR_PRODUCT 
	SET @nStatusOuter = @@FETCH_STATUS
	
	INSERT INTO #TblProducts(ProductID)
	EXEC SPSplitString @ProductList,','
	
	set @PCCnt=0
	if @PCRates!=''
	begin
		INSERT INTO @TblPCRates(Rate)
		EXEC SPSplitString @PCRates,','
		select @PCCnt=count(*) from @TblPCRates
	end
	
	SET @TagSQL=''
	IF (@LocationWHERE IS NOT NULL AND @LocationWHERE<>'') OR (@DIMWHERE IS NOT NULL AND @DIMWHERE<>'')
	BEGIN
		IF (@LocationWHERE IS NOT NULL AND @LocationWHERE<>'')
			SET @TagSQL=@TagSQL+' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' IN ('+@LocationWHERE+') '
		IF (@DIMWHERE IS NOT NULL AND @DIMWHERE<>'')
			SET @TagSQL=@TagSQL+@DIMWHERE
	END
	
	DECLARE @Tbl2 AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID INT,TagID INT,BalQty FLOAT,AvgRate FLOAT,BalValue FLOAT,PCxml NVARCHAR(max))
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID INT,BalQty FLOAT,AvgRate FLOAT,BalValue FLOAT,PCxml NVARCHAR(max))

	IF @TagID=0
	BEGIN
		FETCH NEXT FROM @CUR_PRODUCT Into @ProductID
		SET @nStatusOuter = @@FETCH_STATUS
		
		WHILE(@nStatusOuter<>-1)
		BEGIN
			--Price chart Data			
			if @PCCnt>0
			begin
				set @PCxml=''
				set @PCi=1
				while(@PCi<=@PCCnt)
				begin
					select @PCcol=Rate from @TblPCRates where ID=@PCi
					EXEC spRPT_PCRate @ProductID,@ToDate,@PCcol,@PCFilter,@PCRate OUTPUT					
					if @PCi>1
						set @PCxml=@PCxml+','
					if @PCRate is null
						set @PCRate=0
					set @PCxml=@PCxml+convert(nvarchar,@PCRate)
					set @PCi=@PCi+1
				end
			end
			
			--TO GET BALANCE DATA
			if @TagsList is not null and @TagsList like '<X>%'
			begin
				--update #TblAvgMn 
				--set BalQty=null,AvgRate=null,BalValue=null,IsDone=0
				truncate table #TblAvgMn
				if @TagsList is not null and @TagsList like '<X>%'
				begin
					declare @XML xml
					set @XML=@TagsList
					--insert into #TblAvgMn(FromDate)
					--values(0)
					
					insert into #TblAvgMn(ToDate)
					select convert(float,X.value('@D','datetime'))
					from @XML.nodes('/X/R') as Data(X)  
					
					/*update #TblAvgMn
					set FromDate=100(select ToDate-1 from #TblAvgMn where ID=ID-1)
					where ID>0*/
					
					update T2
					set FromDate=T1.ToDate -1
					from #TblAvgMn T1
					join #TblAvgMn T2 on T1.ID=T2.ID-1
					
					update #TblAvgMn set FromDate=0 where ID=0
					
					--select * from #TblAvgMn
				end
				
				EXEC [spRPT_AvgRate] 0,@ProductID,@TagSQL,@WHERE,@ToDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,1,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT

				INSERT INTO @Tbl2(ProductID,BalQty,AvgRate,BalValue,PCxml)
				SELECT @ProductID,@BalQty,isnull(@AvgRate,0),@BalValue,@PCxml
				WHERE @BalQty IS NOT NULL

				if (select count(*) from #TblAvgMn where BalQty IS NULL or BalQty=0)!=(select count(*) from #TblAvgMn)
					INSERT INTO @Tbl2(ProductID,TagID,BalQty,AvgRate,BalValue,PCxml)
					SELECT @ProductID,ID,BalQty,AvgRate,BalValue,@PCxml
					FROM #TblAvgMn
			end
			else
			begin
				EXEC [spRPT_AvgRate] 0,@ProductID,@TagSQL,@WHERE,@ToDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
			
				INSERT INTO @Tbl(ProductID,BalQty,AvgRate,BalValue,PCxml)
				SELECT @ProductID,@BalQty,isnull(@AvgRate,0),@BalValue,@PCxml
				WHERE @BalQty IS NOT NULL
			end
				

			FETCH NEXT FROM @CUR_PRODUCT Into @ProductID
			SET @nStatusOuter = @@FETCH_STATUS
		END
		if @TagsList is not null and @TagsList like '<X>%'
			SELECT * FROM @Tbl2
		else
			SELECT * FROM @Tbl
	END
	ELSE
	BEGIN

		DECLARE @TI INT,@TCNT INT,@NodeID INT,@SubTagSQL NVARCHAR(MAX)
		create table #TblTags(ID INT IDENTITY(1,1) NOT NULL,NodeID INT)

		INSERT INTO #TblTags(NodeID)
		EXEC SPSplitString @TagsList,','
		
		SELECT @TCNT=COUNT(*) FROM #TblTags	
		
		FETCH NEXT FROM @CUR_PRODUCT Into @ProductID
		SET @nStatusOuter = @@FETCH_STATUS
		
		WHILE(@nStatusOuter<>-1)
		BEGIN
			SET @TI=1
			IF(@IsTagWise=1)
			BEGIN
				--TO GET BALANCE DATA
			--	insert into #TblAvgMn
				EXEC [spRPT_AvgRate] 0,@ProductID,@TagSQL,@WHERE,@ToDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
				
				--Price chart Data			
				if @PCCnt>0
				begin
					set @PCxml=''
					set @PCi=1
					while(@PCi<=@PCCnt)
					begin
						select @PCcol=Rate from @TblPCRates where ID=@PCi
						EXEC spRPT_PCRate @ProductID,@ToDate,@PCcol,@PCFilter,@PCRate OUTPUT					
						if @PCi>1
							set @PCxml=@PCxml+','
						if @PCRate is null
							set @PCRate=0
						set @PCxml=@PCxml+convert(nvarchar,@PCRate)
						set @PCi=@PCi+1
					end
				end
				
				INSERT INTO @Tbl2(ProductID,BalQty,AvgRate,BalValue,PCxml)
				SELECT @ProductID,@BalQty,isnull(@AvgRate,0),@BalValue,@PCxml
				WHERE @BalQty IS NOT NULL
			END

			if @IgnoreTagWiseRate=0
			begin
				WHILE(@TI<=@TCNT)
				BEGIN
					SELECT @NodeID=NodeID FROM #TblTags WHERE ID=@TI
					
					IF @TagSQL=''
						SET @SubTagSQL=' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+'='+CONVERT(NVARCHAR,@NodeID)
					ELSE
						SET @SubTagSQL=@TagSQL + ' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+'='+CONVERT(NVARCHAR,@NodeID)		
				
					--TO GET BALANCE DATA
					EXEC [spRPT_AvgRate] 0,@ProductID,@SubTagSQL,@WHERE,@ToDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
					
					INSERT INTO @Tbl2(ProductID,TagID,BalQty,AvgRate,BalValue)
					SELECT @ProductID,@NodeID,@BalQty,isnull(@AvgRate,0),@BalValue
					WHERE @BalQty IS NOT NULL-- and (@BalQty!=0 or @AvgRate!=0)
					
					SET @TI=@TI+1
				END
			end
			FETCH NEXT FROM @CUR_PRODUCT Into @ProductID
			SET @nStatusOuter = @@FETCH_STATUS
			
		END

		if @IgnoreTagWiseRate=1
		begin
			set @SubTagSQL='
select P.ProductID,T.NodeID AS TagID,ISNULL(SUM(D.UOMConvertedQty*D.VoucherType),0) BalQty
FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'
			set @SubTagSQL=@SubTagSQL+'
INNER JOIN #TblProducts P WITH(NOLOCK) ON P.ProductID=D.ProductID
INNER JOIN #TblTags T ON DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+'=T.NodeID 
WHERE D.ProductID=P.ProductID AND (D.VoucherType=1 OR D.VoucherType=-1) AND D.IsQtyIgnored=0 AND (D.DocumentType=3 OR D.DocDate<='+convert(nvarchar,convert(float,@TODATE))+')'
			if @IncludeUpPostedDocs=0
				set @SubTagSQL=@SubTagSQL+' AND D.StatusID=369'
			else
				set @SubTagSQL=@SubTagSQL+' AND D.StatusID<>376'
		set @SubTagSQL=@SubTagSQL+'
GROUP BY P.ProductID,T.NodeID having ISNULL(SUM(D.UOMConvertedQty*D.VoucherType),0)!=0 
Order BY P.ProductID,T.NodeID'
			--print(@SubTagSQL)
			INSERT INTO @Tbl2(ProductID,TagID,BalQty)
			exec(@SubTagSQL)
			
			--update @Tbl2 set AvgRate=@AvgRate,BalValue=@AvgRate*BalQty
			
			update T1
			set AvgRate=T2.AvgRate
			from @Tbl2 T1
			join @Tbl2 T2 on T1.ProductID=T2.ProductID and T2.TagID is null
			where T1.TagID is not null
			
			update @Tbl2 set BalValue=AvgRate*BalQty where BalValue is null
		end
		
		SELECT * FROM @Tbl2
	END
	
	CLOSE @CUR_PRODUCT
	DEALLOCATE @CUR_PRODUCT
	
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
