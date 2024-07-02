USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_AvgRateForProducts]
	@ProductList [nvarchar](max),
	@IsOpening [bit],
	@DIMWHERE [nvarchar](max) = NULL,
	@IncludeUpPostedDocs [bit],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@RecQty FLOAT,@TagSQL NVARCHAR(MAX),
			@AvgRate FLOAT,@BalQty FLOAT,@BalValue FLOAT,@COGS FLOAT,@VoucherType INT,@I INT,@COUNT INT
	DECLARE @TblProducts AS TABLE(ID INT IDENTITY(1,1) NOT NULL,strProduct nvarchar(30))
	
	DECLARE @CUR_PRODUCT cursor, @nStatusOuter int
	
	SET @CUR_PRODUCT = cursor for 
	SELECT strProduct FROM @TblProducts 
	
	OPEN @CUR_PRODUCT 
	SET @nStatusOuter = @@FETCH_STATUS
	
	INSERT INTO @TblProducts(strProduct)
	EXEC SPSplitString @ProductList,','
	
	IF (@DIMWHERE IS NOT NULL AND @DIMWHERE<>'')
	BEGIN
		SET @TagSQL=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'
	
		IF (@DIMWHERE IS NOT NULL AND @DIMWHERE<>'')
			SET @TagSQL=@TagSQL+@DIMWHERE
	END
	ELSE
	BEGIN
		SET @TagSQL=''
	END
				
	declare @ToDate datetime,@TDate int,@PID bigint,@ind int,@strProduct nvarchar(30)
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL,Product nvarchar(30),DocDate INT,BalQty FLOAT,AvgRate FLOAT,BalValue FLOAT)

	FETCH NEXT FROM @CUR_PRODUCT Into @strProduct
	SET @nStatusOuter = @@FETCH_STATUS

	WHILE(@nStatusOuter<>-1)
	BEGIN
		set @ind=CHARINDEX('~',@strProduct)
		set @PID=convert(bigint,substring(@strProduct,1,@ind-1))
		set @TDate=convert(int, substring(@strProduct,@ind+1,20))	
		
		if @IsOpening=1
		begin
			set @ToDate=convert(datetime,@TDate-1)
			exec [spRPT_AvgRate] 0,@PID,@DIMWHERE,'',@ToDate,@ToDate,@IncludeUpPostedDocs,0,0,0,'',0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
		end
		else
		begin
			set @ToDate=convert(datetime,@TDate)
			exec [spRPT_AvgRate] 0,@PID,@DIMWHERE,'',@ToDate,@ToDate,@IncludeUpPostedDocs,0,0,0,'',0,@BalQty OUTPUT,@AvgRate OUTPUT,@BalValue OUTPUT,@COGS OUTPUT
		end
		
		INSERT INTO @Tbl(Product,BalQty,AvgRate,BalValue)
		SELECT @strProduct,@BalQty,@AvgRate,@BalValue
		WHERE @BalQty IS NOT NULL

		FETCH NEXT FROM @CUR_PRODUCT Into @strProduct
		SET @nStatusOuter = @@FETCH_STATUS
	END
	
	SELECT * FROM @Tbl
	
	
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
