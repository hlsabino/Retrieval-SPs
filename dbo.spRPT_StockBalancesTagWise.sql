USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_StockBalancesTagWise]
	@TempTableName [nvarchar](50),
	@TagID [int],
	@TagsList [nvarchar](max) = NULL,
	@DimensionID [int],
	@LocationWHERE [nvarchar](max) = NULL,
	@ToDate [datetime],
	@DefValuation [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@RecQty FLOAT,@ProductID BIGINT,@TagSQL NVARCHAR(MAX),@ProductList NVARCHAR(MAX),@WHERE NVARCHAR(MAX),
			@AvgRate FLOAT,@BalQty FLOAT,@BalValue FLOAT,@VoucherType INT,@I INT,@COUNT INT,@TotalBalQty FLOAT,@TotalBalValue FLOAT
	DECLARE @TblProducts AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID BIGINT)
	
	DECLARE @CUR_PRODUCT cursor, @nStatusOuter int
	
	SET @CUR_PRODUCT = cursor for 
	SELECT ProductID FROM @TblProducts 
	
	
	IF @LocationWHERE IS NOT NULL AND @LocationWHERE<>'' AND @TagID!=@DimensionID
	BEGIN
		SET @TagSQL=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID AND DCC.DCCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' IN ('+@LocationWHERE+') '
	END
	ELSE
	BEGIN
		SET @TagSQL=''		
	END
	
	DECLARE @TI INT,@TCNT INT,@NodeID BIGINT,@SubTagSQL NVARCHAR(MAX)
	DECLARE @TblTags AS TABLE(ID INT IDENTITY(1,1) NOT NULL,NodeID BIGINT)
	DECLARE @Tbl2 AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ProductID BIGINT,TagID BIGINT,BalQty FLOAT,AvgRate FLOAT,BalValue FLOAT)

	INSERT INTO @TblProducts(ProductID)
	EXEC SPSplitString @ProductList,','
	
	INSERT INTO @TblTags(NodeID)
	EXEC SPSplitString @TagsList,','
	
	SELECT @TI=1,@TCNT=COUNT(*) FROM @TblTags	

	WHILE(@TI<=@TCNT)
	BEGIN
		SELECT @NodeID=NodeID FROM @TblTags WHERE ID=@TI
		
		IF @TagSQL=''
		BEGIN
			SET @SubTagSQL=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+'='+CONVERT(NVARCHAR,@NodeID)
		END
		ELSE
		BEGIN
			SET @SubTagSQL=@TagSQL + ' AND DCC.DCCCNID'+CONVERT(NVARCHAR,@TagID-50000)+'='+CONVERT(NVARCHAR,@NodeID)		
		END
		
		SET @SQL='SELECT ProductID FROM INV_DocDetails D with(nolock)'+@SubTagSQL+' WHERE D.IsQtyIgnored=0 GROUP BY ProductID'
		--print(@SQL)
		INSERT INTO @TblProducts
		EXEC(@SQL)
		
		--set @SQL=(select count(*) from @TblProducts)
		--print 'COUNT: '+@SQL
		
		SET @TotalBalQty=0
		SET @TotalBalValue=0
		
		IF(select count(*) from @TblProducts)>0
		BEGIN
			OPEN @CUR_PRODUCT
			SET @nStatusOuter = @@FETCH_STATUS
	
			FETCH NEXT FROM @CUR_PRODUCT Into @ProductID
			SET @nStatusOuter = @@FETCH_STATUS
			
			
			WHILE(@nStatusOuter<>-1)
			BEGIN
			
				SET @WHERE=' ProductID='+CONVERT(nvarchar,@ProductID)+' AND TagID='+CONVERT(nvarchar,@NodeID)

				--TO GET BALANCE DATA
				EXEC [spRPT_AvgRate_TEMP] 0,@TempTableName,@ProductID,@WHERE,@DefValuation,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT
				
				--IF @BalQty>0
				BEGIN
					SET @TotalBalQty=@TotalBalQty+@BalQty
					SET @TotalBalValue=@TotalBalValue+@BalValue
					--IF (select count(*) from @Tbl2 WHERE TagID=@NodeID)=0
					--	INSERT INTO @Tbl2(ProductID,TagID,BalQty,AvgRate,BalValue)
					--	SELECT @ProductID,@NodeID,@BalQty,@AvgRate,@BalValue
					--	WHERE @BalQty IS NOT NULL
					--ELSE
					--	UPDATE @Tbl2 SET BalQty=BalQty+@BalQty,BalValue=BalValue+@BalValue WHERE TagID=@NodeID
				END
				
				FETCH NEXT FROM @CUR_PRODUCT Into @ProductID
				SET @nStatusOuter = @@FETCH_STATUS
			END
			CLOSE @CUR_PRODUCT

			DELETE FROM @TblProducts
		END
		
		INSERT INTO @Tbl2(ProductID,TagID,BalQty,AvgRate,BalValue)
		SELECT @ProductID,@NodeID,@TotalBalQty,0,@TotalBalValue
		
		SET @TI=@TI+1
	END

	
	SELECT TagID,BalQty,BalValue FROM @Tbl2
	--GROUP BY
	
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
