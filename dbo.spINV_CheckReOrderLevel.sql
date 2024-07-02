USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_CheckReOrderLevel]
	@ProductID [bigint] = 0,
	@DocDate [datetime],
	@DocID [bigint] = 0,
	@Qty [float],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

			--Declaration Section
			DECLARE @PQty FLOAT, @SQty FLOAT, @Bal FLOAT, @LimitExceeds INT, @PUOMConvertedQty int,@SUOMConvertedQty int
			Declare @ReorderLevel float

			SET @PQty=0
			SET @SQty=0
			SET @Bal=0
			SET @LimitExceeds=0
			set @PUOMConvertedQty=0
			set @SUOMConvertedQty=0
			set @ReorderLevel=0
			SELECT @ReorderLevel = ReorderLevel from Inv_product WITH(NOLOCK)  where productid=@ProductID

			IF @ReorderLevel > 0
			BEGIN
				
				--Purchase Qty as on System Date s
				--Sales Qty as on System Date
				--if(@loc=0 and @div=0)
				--BEGIN
				if(@DocID =0)
				BEGIN			
					SELECT @PQty=SUM(ISNULL(1/isnull(UOMConversion,1)*Quantity,0)) FROM INV_DocDetails WITH(NOLOCK)  where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=1 and IsQtyIgnored=0 
					SELECT @SQty=SUM(ISNULL(1/isnull(UOMConversion,1)*Quantity,0)) FROM INV_DocDetails WITH(NOLOCK) where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=-1 and IsQtyIgnored=0 
				END
				ELSE
				BEGIN
					SELECT @PQty=SUM(ISNULL(1/isnull(UOMConversion,1)*Quantity,0)) FROM INV_DocDetails WITH(NOLOCK)  where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=1 and IsQtyIgnored=0 AND DocID not in (@DocID)
					SELECT @SQty=SUM(ISNULL(1/isnull(UOMConversion,1)*Quantity,0)) FROM INV_DocDetails WITH(NOLOCK) where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=-1 and IsQtyIgnored=0 AND DocID not in (@DocID)
				END
				--END
				 
				--Total Qty as on System Date
				SET @Bal=isnull(@PQty,0)-@ReorderLevel-isnull(@SQty,0)-@Qty
			
				if(@Bal <   0)
				BEGIN
					set @LimitExceeds=1
				END
				ELSE
				BEGIN
					set @LimitExceeds= 0
				END
			END

			
			SELECT @LimitExceeds
			
			SELECT @ReorderLevel as ReorderLevel, @PQty as PurchaseQty, @SQty  as SalesQty, @Qty as Qty, @Bal as Balance


 SET NOCOUNT OFF;
RETURN @LimitExceeds
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
