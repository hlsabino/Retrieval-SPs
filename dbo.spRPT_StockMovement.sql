USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_StockMovement]
	@ProductList [nvarchar](max),
	@TagID [nvarchar](max),
	@TagsList [nvarchar](max) = NULL,
	@DimensionID [int],
	@LocationWHERE [nvarchar](max) = NULL,
	@DIMWHERE [nvarchar](max) = NULL,
	@WHERE [nvarchar](max),
	@FromDate [datetime],
	@ToDate [datetime],
	@IncludeUpPostedDocs [bit],
	@DefValuation [int],
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
	DECLARE @SQL NVARCHAR(MAX),@RecQty FLOAT,@OpQty FLOAT,@OpValue FLOAT,@RecRate FLOAT,@RecValue FLOAT,@ProductID INT,@Valuation INT,@TagSQL NVARCHAR(MAX),@AvgDimWhere NVARCHAR(MAX),
			@IssQty FLOAT,@IssValue FLOAT,@OpRate FLOAT,@AvgRate FLOAT,@BalQty FLOAT,@BalValue FLOAT,@COGS FLOAT,@VoucherType INT,@I INT,@COUNT INT,@UnAppSQL NVARCHAR(50),
			@CurrWHERE nvarchar(30),@ValColumn nvarchar(20),@TagColumn NVARCHAR(50)
	DECLARE @TblProducts AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID INT)
	declare @PCRate float,@PCi INT,@PCCnt INT,@PCcol nvarchar(50),@PCxml nvarchar(max)
	declare @TblPCRates AS TABLE(ID INT IDENTITY(1,1) NOT NULL,Rate NVARCHAR(50))
	CREATE TABLE #STMTbl(ID INT IDENTITY(1,1) NOT NULL,ProductID INT,OpQty FLOAT,OpValue FLOAT,
		RecQty FLOAT,RecValue FLOAT,IssQty FLOAT,IssValue FLOAT,BalQty FLOAT,AvgRate FLOAT,BalValue FLOAT,TagID INT,COGS FLOAT,PCxml NVARCHAR(max))
	DECLARE @From NVARCHAR(20),@To NVARCHAR(20),@DateFilterCol nvarchar(60)
	
	create table #TblAvgMn(ID int identity(0,1), FromDate Float, ToDate Float, RecQty FLOAT,RecValue FLOAT,IssQty FLOAT,IssValue FLOAT,BalQty float,AvgRate float,BalValue float,IsDone bit)
	
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)

	set @PCCnt=0
	if @PCRates!=''
	begin
		INSERT INTO @TblPCRates(Rate)
		EXEC SPSplitString @PCRates,','
		select @PCCnt=count(*) from @TblPCRates
	end
	
	SET @TagColumn=''
	SET @TagSQL=''	
	SET @AvgDimWhere=''
	IF (@LocationWHERE IS NOT NULL AND @LocationWHERE<>'') OR (@DIMWHERE IS NOT NULL AND @DIMWHERE<>'')
	BEGIN
		IF (@LocationWHERE IS NOT NULL AND @LocationWHERE<>'')
			SET @AvgDimWhere=@AvgDimWhere+' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' IN ('+@LocationWHERE+') '
		IF (@DIMWHERE IS NOT NULL AND @DIMWHERE<>'')
			SET @AvgDimWhere=@AvgDimWhere+@DIMWHERE
		SET @TagSQL=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@AvgDimWhere
	END

	IF @IncludeUpPostedDocs=0
		SET @UnAppSQL=' AND D.StatusID=369'
	ELSE
		SET @UnAppSQL=' AND D.StatusID<>376'
		
	IF @CurrencyID>0
	BEGIN
		SET @ValColumn='StockValueFC'
		--SET @GrossColumn='GrossFC'
		SET @CurrWHERE=' AND D.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
	END
	ELSE
	BEGIN
		IF @CurrencyType=1
		BEGIN
			SET @ValColumn='StockValueBC'
			--SET @GrossColumn='(Gross/ExhgRtBC)'
		END
		ELSE
		BEGIN
			SET @ValColumn='StockValue'
			--SET @GrossColumn='Gross'
		END
		SET @CurrWHERE=''
	END
	
	if @SortTransactionsBy='CreatedDate'
		set @DateFilterCol=' AND D.CreatedDate>='+@From+' AND D.CreatedDate<'+convert(nvarchar,convert(int,@To)+1)
	else if @SortTransactionsBy='ModifiedDate'
		set @DateFilterCol=' AND D.ModifiedDate>='+@From+' AND D.ModifiedDate<'+convert(nvarchar,convert(int,@To)+1)
	else
		set @DateFilterCol=' AND D.DocDate BETWEEN '+@From+' AND '+@To
	

	IF @TagID=0
	BEGIN
	
		INSERT INTO @TblProducts(ProductID)
		EXEC SPSplitString @ProductList,','
		
		SELECT @I=1,@COUNT=COUNT(*) FROM @TblProducts

		WHILE(@I<=@COUNT)
		BEGIN
			SELECT @ProductID=ProductID FROM @TblProducts WHERE ID=@I
			
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

			--TO GET OPENING DATA
			EXEC [spRPT_AvgRate] 1,@ProductID,@AvgDimWhere,@WHERE,@FromDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@OpQty OUTPUT,@OpRate OUTPUT,@OpValue OUTPUT,@COGS OUTPUT

			--TO GET BALANCE DATA
			SET @BalQty=ISNULL(@OpQty,0)
			SET @AvgRate=ISNULL(@OpRate,0)
			SET @BalValue=ISNULL(@OpValue,0)
			
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
					from #TblAvgMn T1 with(nolock)
					join #TblAvgMn T2 with(nolock) on T1.ID=T2.ID-1
					
					update #TblAvgMn set FromDate=0 where ID=0
					
					--select * from #TblAvgMn with(nolock)
					SET @SQL='UPDATE #TblAvgMn SET RecQty=(SELECT SUM(D.UOMConvertedQty)
					FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
					WHERE D.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND D.IsQtyIgnored=0 AND D.VoucherType=1 AND D.DocumentType<>3
					AND FromDate>0 AND D.DocDate BETWEEN FromDate+2 AND ToDate '+@UnAppSQL+@CurrWHERE+@WHERE+')
					,RecValue=(SELECT SUM('+@ValColumn+')
					FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
					WHERE D.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND D.IsQtyIgnored=0 AND D.VoucherType=1 AND D.DocumentType<>3
					AND FromDate>0 AND D.DocDate BETWEEN FromDate+2 AND ToDate '+@UnAppSQL+@CurrWHERE+@WHERE+')
					,IssQty=(SELECT SUM(D.UOMConvertedQty)
					FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
					WHERE D.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND D.IsQtyIgnored=0 AND D.VoucherType=-1 
					AND FromDate>0 AND D.DocDate BETWEEN FromDate+2 AND ToDate '+@UnAppSQL+@CurrWHERE+@WHERE+')
					,IssValue=(SELECT SUM('+@ValColumn+')
					FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
					WHERE D.ProductID='+CONVERT(NVARCHAR,@ProductID)+' AND D.IsQtyIgnored=0 AND D.VoucherType=-1 
					AND FromDate>0 AND D.DocDate BETWEEN FromDate+2 AND ToDate '+@UnAppSQL+@CurrWHERE+@WHERE+')'
					EXEC sp_executesql @SQL
				
				end
			
				EXEC [spRPT_AvgRate] 0,@ProductID,@AvgDimWhere,@WHERE,@ToDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,1,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
				
				INSERT INTO #STMTbl(ProductID,OpQty,OpValue,BalQty,AvgRate,BalValue,COGS,PCxml)
				SELECT @ProductID,@OpQty,@OpValue,@BalQty,@AvgRate,@BalValue,@COGS,@PCxml
				WHERE @AvgRate IS NOT NULL

				if (select count(*) from #TblAvgMn with(nolock) where BalQty IS NULL or BalQty=0)!=(select count(*) from #TblAvgMn with(nolock))
					INSERT INTO #STMTbl(ProductID,TagID,OpQty,OpValue,BalQty,AvgRate,BalValue,COGS,PCxml,RecQty,RecValue,IssQty,IssValue)
					SELECT @ProductID,ID,@OpQty,@OpValue,BalQty,AvgRate,BalValue,@COGS,@PCxml,RecQty,RecValue,IssQty,IssValue
					FROM #TblAvgMn with(nolock)
					
			end
			else
			begin
				EXEC [spRPT_AvgRate] 0,@ProductID,@AvgDimWhere,@WHERE,@FromDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
				--EXEC [spRPT_StockAvgValues] 0,@ProductID,@LocationWHERE,NULL,@ToDate,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT
				
				if @DefValuation=4 or @DefValuation=5
				begin
					INSERT INTO #STMTbl(ProductID,OpQty,OpValue,BalQty,AvgRate,BalValue,COGS,PCxml)
					SELECT @ProductID,@OpQty,@OpQty*@AvgRate,@BalQty,@AvgRate,@BalValue,@COGS,@PCxml
					WHERE @AvgRate IS NOT NULL
				end
				else
				begin
					INSERT INTO #STMTbl(ProductID,OpQty,OpValue,BalQty,AvgRate,BalValue,COGS,PCxml)
					SELECT @ProductID,@OpQty,@OpValue,@BalQty,@AvgRate,@BalValue,@COGS,@PCxml
					WHERE @AvgRate IS NOT NULL
				end
			end
			
			SET @I=@I+1
		END
		
		--TO GET RECIEDVED DATA BETWEEN DATES
		SET @SQL='SELECT D.ProductID,SUM(D.UOMConvertedQty),SUM('+@ValColumn+')
			FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
			WHERE D.ProductID IN ('+@ProductList+') AND D.IsQtyIgnored=0 AND D.VoucherType=1 AND D.DocumentType<>3
			'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE+'
			GROUP BY D.ProductID'
		
		INSERT INTO #STMTbl(ProductID,RecQty,RecValue)
		EXEC sp_executesql @SQL
		
		--TO GET ISSUE DATA BETWEEN DATES
		SET @SQL='SELECT D.ProductID,SUM(D.UOMConvertedQty),SUM('+@ValColumn+')
			FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
			WHERE D.ProductID IN ('+@ProductList+') AND D.IsQtyIgnored=0 AND D.VoucherType=-1 
			'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE+'
			GROUP BY D.ProductID'

		INSERT INTO #STMTbl(ProductID,IssQty,IssValue)
		EXEC sp_executesql @SQL
		
	END
	ELSE
	BEGIN
		DECLARE @TI INT,@TCNT INT,@NodeID INT,@SubTagSQL NVARCHAR(MAX),@Pos int,@Nodes NVARCHAR(30),@PIDCHAR NVARCHAR(15),@NIDCHAR NVARCHAR(35)
		DECLARE @TblTagProduct AS TABLE(ID INT IDENTITY(1,1) NOT NULL,Nodes NVARCHAR(30))
		DECLARE @TblNodes AS TABLE(ProductID INT,NodeID INT)

		INSERT INTO @TblTagProduct(Nodes)
		EXEC SPSplitString @TagsList,','
		
		SET @TagsList=''
		SET @ProductList=''
		
		SELECT @TI=1,@TCNT=COUNT(*) FROM @TblTagProduct	
		
		WHILE(@TI<=@TCNT)
		BEGIN
			SELECT @Nodes=Nodes FROM @TblTagProduct WHERE ID=@TI
			set @Pos = CHARINDEX('~',@Nodes)
			set @PIDCHAR=substring(@Nodes,1,@Pos-1)
			set @ProductID=convert(INT, @PIDCHAR)
			set @NIDCHAR=substring(@Nodes,@Pos+1,LEN(@Nodes)-@Pos)
			set @NodeID=convert(INT, @NIDCHAR)
			
			if not exists(select ProductID from @TblNodes where ProductID=@ProductID)
			begin
				insert into @TblNodes(ProductID) values(@ProductID)
				if len(@ProductList)>0
					set @ProductList=@ProductList+','
				set @ProductList=@ProductList+@PIDCHAR
			end
			if not exists(select NodeID from @TblNodes where NodeID=@NodeID)
			begin
				insert into @TblNodes(NodeID) values(@NodeID)
				if len(@TagsList)>0
					set @TagsList=@TagsList+','
				set @TagsList=@TagsList+@NIDCHAR
			end
			
			IF @TagID=2
				SET @SubTagSQL=''
			ELSE
				SET @SubTagSQL=' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+'='+CONVERT(NVARCHAR,@NodeID)
			
			IF @TagSQL<>''
				SET @SubTagSQL=@AvgDimWhere + @SubTagSQL
				
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

			--TO GET OPENING DATA
			EXEC [spRPT_AvgRate] 1,@ProductID,@SubTagSQL,@WHERE,@FromDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@OpQty OUTPUT,@OpRate OUTPUT,@OpValue OUTPUT,@COGS OUTPUT

			--TO GET BALANCE DATA
			SET @BalQty=ISNULL(@OpQty,0)
			SET @AvgRate=ISNULL(@OpRate,0)
			SET @BalValue=ISNULL(@OpValue,0)
			
			EXEC [spRPT_AvgRate] 0,@ProductID,@SubTagSQL,@WHERE,@FromDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
			
			INSERT INTO #STMTbl(ProductID,OpQty,OpValue,BalQty,AvgRate,BalValue,TagID,COGS)
			SELECT @ProductID,@OpQty,@OpValue,@BalQty,@AvgRate,@BalValue,@NodeID,@COGS
			WHERE @AvgRate IS NOT NULL
			
			SET @TI=@TI+1
		END

		IF @TagID=2
			SET @TagColumn=',PVG.AccountID'
		ELSE
			SET @TagColumn=',DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)
		
		IF @TagID=2
		BEGIN
			SET @TagSQL=@TagSQL + ' INNER JOIN INV_ProductVendors PVG WITH(NOLOCK) ON PVG.ProductID=D.ProductID AND PVG.AccountID IN ('+@TagsList+')'
		END
		ELSE
		BEGIN
			IF @TagSQL=''
				SET @TagSQL=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+' IN('+@TagsList+')'
			ELSE
				SET @TagSQL=@TagSQL + ' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+' IN ('+@TagsList+')'
		END
	
		--TO GET RECIEDVED DATA BETWEEN DATES
		SET @SQL='SELECT D.ProductID'+@TagColumn+',SUM(D.UOMConvertedQty),SUM('+@ValColumn+')
			FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
			WHERE D.ProductID IN ('+@ProductList+') AND D.IsQtyIgnored=0 AND D.VoucherType=1 AND D.DocumentType<>3
				'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE+'
			GROUP BY D.ProductID'+@TagColumn

		INSERT INTO #STMTbl(ProductID,TagID,RecQty,RecValue)
		EXEC sp_executesql @SQL

		--TO GET ISSUE DATA BETWEEN DATES
		SET @SQL='SELECT D.ProductID'+@TagColumn+',SUM(D.UOMConvertedQty),SUM('+@ValColumn+')
			FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
			WHERE D.ProductID IN ('+@ProductList+') AND D.IsQtyIgnored=0 AND D.VoucherType=-1 
				'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE+'
			GROUP BY D.ProductID'+@TagColumn
			

		INSERT INTO #STMTbl(ProductID,TagID,IssQty,IssValue)
		EXEC sp_executesql @SQL
	END
	
	SET @SQL=''	
	SELECT @SQL=@SQL+',SUM(CASE WHEN D.CostCenterID='+CONVERT(NVARCHAR,DT.CostCenterID)+' THEN D.UOMConvertedQty ELSE 0 END) ['+replace(DocumentName,' ','_')+'_Qty]
	,SUM(CASE WHEN D.CostCenterID='+CONVERT(NVARCHAR,DT.CostCenterID)+' THEN '+@ValColumn+' ELSE 0 END) ['+replace(DocumentName,' ','_')+'_Value]' 
	FROM ADM_DocumentTypes DT WITH(NOLOCK) 
	WHERE IsInventory=1 AND DT.CostCenterID IN (SELECT DISTINCT CostCenterID FROM INV_DocDetails WITH(NOLOCK) WHERE IsQtyIgnored=0 AND DocumentType<>3)
	
	SET @SQL='SELECT D.ProductID PID'+CASE WHEN @TagColumn<>'' THEN @TagColumn+' TID' ELSE '' END+@SQL+'
		INTO #CCTEMP
		FROM INV_DocDetails D WITH(NOLOCK) '+@TagSQL+'
		WHERE D.ProductID IN ('+@ProductList+') AND D.IsQtyIgnored=0 AND (D.VoucherType=1 OR D.VoucherType=-1) AND D.DocumentType<>3
			'+@DateFilterCol+@UnAppSQL+@CurrWHERE+@WHERE+'
		GROUP BY D.ProductID'+@TagColumn
		
	if @TagID<>0 OR (@TagsList is not null and @TagsList like '<X>%')
	begin
		SET @SQL=@SQL+' SELECT ProductID,TagID,OpQty,OpValue,RecQty,RecValue,IssQty,IssValue,BalQty,AvgRate,BalValue,case when IssQty>0 then COGS else null end COGS,PCXml,CT.*
		FROM (
			SELECT ProductID,TagID,SUM(OpQty) OpQty,SUM(OpValue) OpValue,
				SUM(RecQty) RecQty,SUM(RecValue) RecValue,SUM(IssQty) IssQty,SUM(IssValue) IssValue,
				SUM(BalQty) BalQty,SUM(AvgRate) AvgRate,SUM(BalValue) BalValue,SUM(COGS) COGS,MAX(PCXml) PCXml
		FROM #STMTbl WITH(NOLOCK)
		GROUP BY ProductID,TagID) AS T
		LEFT JOIN #CCTEMP CT WITH(NOLOCK) ON CT.PID=T.ProductID '+CASE WHEN @TagID<>0 THEN 'AND CT.TID=T.TagID' ELSE '' END
	end
	else
	begin
		SET @SQL=@SQL+' SELECT ProductID,OpQty,OpValue,RecQty,RecValue,IssQty,IssValue,BalQty,AvgRate,BalValue,case when IssQty>0 then COGS else null end COGS,PCXml,CT.*
		FROM (
			SELECT ProductID,SUM(OpQty) OpQty,SUM(OpValue) OpValue,
				SUM(RecQty) RecQty,SUM(RecValue) RecValue,SUM(IssQty) IssQty,SUM(IssValue) IssValue,
				SUM(BalQty) BalQty,SUM(AvgRate) AvgRate,SUM(BalValue) BalValue,SUM(COGS) COGS,MAX(PCXml) PCXml
		FROM #STMTbl WITH(NOLOCK)
		GROUP BY ProductID) AS T
		LEFT JOIN #CCTEMP CT WITH(NOLOCK) ON CT.PID=T.ProductID'
	end
	
	SET @SQL=@SQL+' DROP TABLE #CCTEMP'		
	
	EXEC sp_executesql @SQL
	
	DROP TABLE #TblAvgMn
	DROP TABLE #STMTbl
	
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
