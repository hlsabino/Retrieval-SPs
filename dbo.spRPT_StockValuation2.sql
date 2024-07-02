USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_StockValuation2]
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
	@CurrencyType [int],
	@CurrencyID [int] = 0,
	@SortTransactionsBy [nvarchar](50),
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@RecQty FLOAT,@ProductID BIGINT,@TagSQL NVARCHAR(MAX),
			@AvgRate FLOAT,@BalQty FLOAT,@BalValue FLOAT,@COGS FLOAT,@VoucherType INT,@I INT,@COUNT INT
	DECLARE @TblProducts AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID BIGINT)
	
	DECLARE @CUR_PRODUCT cursor, @nStatusOuter int
	
	SET @CUR_PRODUCT = cursor for 
	SELECT ProductID FROM @TblProducts 
	
	OPEN @CUR_PRODUCT 
	SET @nStatusOuter = @@FETCH_STATUS
	
	INSERT INTO @TblProducts(ProductID)
	EXEC SPSplitString @ProductList,','
		
	SET @TagSQL=''
	IF (@LocationWHERE IS NOT NULL AND @LocationWHERE<>'') OR (@DIMWHERE IS NOT NULL AND @DIMWHERE<>'')
	BEGIN
		IF (@LocationWHERE IS NOT NULL AND @LocationWHERE<>'')
			SET @TagSQL=@TagSQL+' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' IN ('+@LocationWHERE+') '
		IF (@DIMWHERE IS NOT NULL AND @DIMWHERE<>'')
			SET @TagSQL=@TagSQL+@DIMWHERE
	END
				
	IF @TagID=0
	BEGIN
		DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID BIGINT,BalQty FLOAT,AvgRate FLOAT,BalValue FLOAT)

		FETCH NEXT FROM @CUR_PRODUCT Into @ProductID
		SET @nStatusOuter = @@FETCH_STATUS
	
		WHILE(@nStatusOuter<>-1)
		BEGIN
			--TO GET BALANCE DATA
			EXEC [spRPT_AvgRate] 0,@ProductID,@TagSQL,@WHERE,@ToDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
			
			INSERT INTO @Tbl(ProductID,BalQty,AvgRate,BalValue)
			SELECT @ProductID,@BalQty,@AvgRate,@BalValue
			WHERE @BalQty IS NOT NULL

			FETCH NEXT FROM @CUR_PRODUCT Into @ProductID
			SET @nStatusOuter = @@FETCH_STATUS
		END
		SELECT * FROM @Tbl
	END
	ELSE
	BEGIN
		DECLARE @TI INT,@TCNT INT,@NodeID BIGINT,@SubTagSQL NVARCHAR(MAX),@Pos int,@Nodes NVARCHAR(30)
		DECLARE @TblTagProduct AS TABLE(ID INT IDENTITY(1,1) NOT NULL,Nodes NVARCHAR(30))
		DECLARE @Tbl2 AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID BIGINT,TagID BIGINT,BalQty FLOAT,AvgRate FLOAT,BalValue FLOAT)

		INSERT INTO @TblTagProduct(Nodes)
		EXEC SPSplitString @TagsList,','
		
		--select * from @TblTagProduct
		SELECT @TI=1,@TCNT=COUNT(*) FROM @TblTagProduct	
			
		WHILE(@TI<=@TCNT)
		BEGIN
			SELECT @Nodes=Nodes FROM @TblTagProduct WHERE ID=@TI
			set @Pos = CHARINDEX('~',@Nodes)
			set @ProductID=convert(bigint, substring(@Nodes,1,@Pos-1))
			set @NodeID=convert(bigint, substring(@Nodes,@Pos+1,LEN(@Nodes)-@Pos))
			
			IF(@IsTagWise=1 and not exists (select ProductID from @Tbl2 where ProductID=@ProductID))
			BEGIN
				--TO GET BALANCE DATA
				EXEC [spRPT_AvgRate] 0,@ProductID,@TagSQL,@WHERE,@ToDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
				
				INSERT INTO @Tbl2(ProductID,BalQty,AvgRate,BalValue)
				SELECT @ProductID,@BalQty,@AvgRate,@BalValue
				WHERE @BalQty IS NOT NULL
			END
			
			IF @TagSQL=''
				SET @SubTagSQL=' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+'='+CONVERT(NVARCHAR,@NodeID)
			ELSE
				SET @SubTagSQL=@TagSQL + ' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+'='+CONVERT(NVARCHAR,@NodeID)		
		

			--TO GET BALANCE DATA
			EXEC [spRPT_AvgRate] 0,@ProductID,@SubTagSQL,@WHERE,@ToDate,@ToDate,@IncludeUpPostedDocs,@DefValuation,@CurrencyType,@CurrencyID,@SortTransactionsBy,0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
			
			INSERT INTO @Tbl2(ProductID,TagID,BalQty,AvgRate,BalValue)
			SELECT @ProductID,@NodeID,@BalQty,@AvgRate,@BalValue
			WHERE @BalQty IS NOT NULL
			
			SET @TI=@TI+1
		END

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
