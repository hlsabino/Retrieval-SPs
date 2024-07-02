USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_CheckNegativeStock]
	@ProductID [bigint] = 0,
	@DocDate [datetime],
	@DocID [bigint] = 0,
	@Qty [float],
	@loc [bigint] = 0,
	@div [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

			--Declaration Section
			DECLARE @PQty FLOAT, @SQty FLOAT, @Bal FLOAT, @LimitExceeds INT, @QtyDecimals int
  
			--Purchase Qty as on System Date s
			select @QtyDecimals=value from adm_globalpreferences
			 where name='DecimalsinQty'
			
			--Sales Qty as on System Date
			if(@loc=0 and @div=0)
			BEGIN
			if(@DocID =0)
			BEGIN			
				SELECT @PQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=1 and IsQtyIgnored=0 
				SELECT @SQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=-1 and IsQtyIgnored=0 
			END
			ELSE
			BEGIN
				SELECT @PQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=1 and IsQtyIgnored=0 AND DocID not in (@DocID)
				SELECT @SQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=-1 and IsQtyIgnored=0 AND DocID not in (@DocID)
			END
			END
			ELSE IF(@loc>0)
			BEGIN
				if(@DocID =0)
				BEGIN			
					SELECT @PQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  join COM_DOCCCData cc WITH(NOLOCK) on cc.Invdocdetailsid=INV_DocDetails.Invdocdetailsid
					where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=1 and IsQtyIgnored=0 and cc.dcCCNID2=@loc
					SELECT @SQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  join COM_DOCCCData cc WITH(NOLOCK) on cc.Invdocdetailsid=INV_DocDetails.Invdocdetailsid
					where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=-1 and IsQtyIgnored=0 and cc.dcCCNID2=@loc
				END
				ELSE
				BEGIN
					SELECT @PQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  join COM_DOCCCData cc WITH(NOLOCK)  on cc.Invdocdetailsid=INV_DocDetails.Invdocdetailsid
					where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=1 and IsQtyIgnored=0 AND DocID not in (@DocID) and cc.dcCCNID2=@loc
					SELECT @SQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  join COM_DOCCCData cc WITH(NOLOCK)  on cc.Invdocdetailsid=INV_DocDetails.Invdocdetailsid
					where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=-1 and IsQtyIgnored=0 AND DocID not in (@DocID) and cc.dcCCNID2=@loc
				END
			END
			ELSE IF (@div>0)
			 BEGIN
				if(@DocID =0)
				BEGIN			
					SELECT @PQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK)  join COM_DOCCCData   cc WITH(NOLOCK) on cc.Invdocdetailsid=INV_DocDetails.Invdocdetailsid
					where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=1 and IsQtyIgnored=0 and cc.dcCCNID1=@div
					SELECT @SQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK) join COM_DOCCCData   cc WITH(NOLOCK) on cc.Invdocdetailsid=INV_DocDetails.Invdocdetailsid
					where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=-1 and IsQtyIgnored=0 and cc.dcCCNID1=@div
				END
				ELSE
				BEGIN
					SELECT @PQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK) join COM_DOCCCData cc WITH(NOLOCK) on cc.Invdocdetailsid=INV_DocDetails.Invdocdetailsid
					where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=1 and IsQtyIgnored=0 AND DocID not in (@DocID) and cc.dcCCNID1=@div
					SELECT @SQty=SUM(ISNULL(UOMConvertedQty,0)) FROM INV_DocDetails WITH(NOLOCK) join COM_DOCCCData cc WITH(NOLOCK) on cc.Invdocdetailsid=INV_DocDetails.Invdocdetailsid
					where ProductID= @ProductID and DocDate<=@DocDate and VoucherType=-1 and IsQtyIgnored=0 AND DocID not in (@DocID) and cc.dcCCNID1=@div
				END
			END
			--Total Qty as on System Date
			SET @Bal=round(isnull(@PQty,0)-isnull(@SQty,0),@QtyDecimals)-@Qty
			
			if(round(@Bal,@QtyDecimals) <   0)  
			BEGIN
				set @LimitExceeds=1
			END
			ELSE
			BEGIN
				set @LimitExceeds= 0
			END

			SELECT @LimitExceeds
			
			SELECT  @PQty as PurchaseQty, @SQty  as SalesQty, @Qty as Qty, @Bal as Balance



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
