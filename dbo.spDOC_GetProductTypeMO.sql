USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductTypeMO]
	@ProductID [bigint] = 0,
	@DocDate [datetime],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON

    DECLARE @QOH float 
    DECLARE @AvgRate float,@LastPRate float
    
	set @QOH=(isnull((SELECT isnull(sum(Quantity),0) FROM INV_DocDetails i  WITH(NOLOCK)
    join COM_DocCCData d WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID
	WHERE ProductID=@ProductID AND IsQtyIgnored=0 AND VoucherType=1 
	and DocDate<=CONVERT(float,@DocDate)),0)-isnull((SELECT  isnull(sum(Quantity),0)  FROM INV_DocDetails  i  WITH(NOLOCK)
    join COM_DocCCData d WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID
	WHERE ProductID=@ProductID AND IsQtyIgnored=0 AND VoucherType=-1
	AND  DocDate<=CONVERT(float,@DocDate)),0))
   
     select @AvgRate=sum(Quantity*Rate)/sum(Quantity) from INV_DocDetails WITH(NOLOCK)
    where IsQtyIgnored=0 and VoucherType=1 and ProductID=@ProductID and DocDate<=CONVERT(float,@DocDate)
    
    set @LastPRate=(select top 1 Rate from INV_DocDetails WITH(NOLOCK)
    where IsQtyIgnored=0 and VoucherType=1 and ProductID=@ProductID and DocDate<=CONVERT(float,@DocDate)
    order by DocDate desc)
     
    
    SELECT ProductTypeID,ProductName
     ,PurchaseRate,PurchaseRateA,PurchaseRateB,PurchaseRateC,PurchaseRateD,PurchaseRateE,PurchaseRateF,PurchaseRateG
    ,SellingRate,SellingRateA,SellingRateB,SellingRateC,SellingRateD,SellingRateE,SellingRateF,SellingRateG
    ,@AvgRate AvgRate,@LastPRate LastPurchaseRate,@QOH QOH
    FROM INV_Product a WITH(NOLOCK)
    WHERE ProductID = @ProductID
 

SET NOCOUNT OFF;
RETURN 1
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
