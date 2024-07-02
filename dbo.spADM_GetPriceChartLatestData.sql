USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetPriceChartLatestData]
	@PriceXML [nvarchar](max) = null,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section  
	DECLARE @XML XML
	DECLARE @TblXML TABLE(ID INT,ProductID INT,UOMID INT,AccountID INT
	    ,PurchaseRate FLOAT,PurchaseRateA FLOAT,PurchaseRateB FLOAT,PurchaseRateC FLOAT,PurchaseRateD FLOAT,PurchaseRateE FLOAT,PurchaseRateF FLOAT,PurchaseRateG FLOAT
	    ,SellingRate FLOAT,SellingRateA FLOAT,SellingRateB FLOAT,SellingRateC FLOAT,SellingRateD FLOAT,SellingRateE FLOAT,SellingRateF FLOAT,SellingRateG FLOAT
        ,ReorderLevel FLOAT,ReorderQty FLOAT
	   ,CCNID1 INT,CCNID2 INT,CCNID3 INT,CCNID4 INT,CCNID5 INT,CCNID6 INT,CCNID7 INT,CCNID8 INT)

	SET @XML=@PriceXML
	
	INSERT INTO @TblXML(ID,[ProductID],UOMID,AccountID
	   ,CCNID1,CCNID2,CCNID3,CCNID4,CCNID5,CCNID6,CCNID7,CCNID8)
	SELECT X.value('@ID','INT'), ISNULL(X.value('@ProductID','INT'),1),ISNULL(X.value('@UOMID','INT'),1),ISNULL(X.value('@AccountID','INT'),0),
		ISNULL(X.value('@CC1','INT'),0),ISNULL(X.value('@CC2','INT'),0),ISNULL(X.value('@CC3','INT'),0),ISNULL(X.value('@CC4','INT'),0),ISNULL(X.value('@CC5','INT'),0),ISNULL(X.value('@CC6','INT'),0),ISNULL(X.value('@CC7','INT'),0),ISNULL(X.value('@CC8','INT'),0)			
	FROM @XML.nodes('/XML/Row') as Data(X)
	
	DECLARE @I INT,@CNT INT,@PriceCCID INT
	SELECT @I=1,@CNT=COUNT(*) FROM @TblXML
	   
	WHILE(@I<=@CNT)
	BEGIN
 
  		SELECT TOP 1 @PriceCCID=PriceCCID
		FROM COM_CCPrices P WITH(NOLOCK)
		INNER JOIN @TblXML X ON X.ProductID=P.ProductID AND X.UOMID=P.UOMID AND X.AccountID=P.AccountID
		WHERE X.ID=@I AND X.CCNID1=P.CCNID1 AND X.CCNID2=P.CCNID2 AND X.CCNID3=P.CCNID3 AND X.CCNID4=P.CCNID4
			AND X.CCNID5=P.CCNID5 AND X.CCNID6=P.CCNID6 AND X.CCNID7=P.CCNID7 AND X.CCNID8=P.CCNID8
		ORDER BY WEF DESC
		
		UPDATE @TblXML
		SET PurchaseRate=P.PurchaseRate,PurchaseRateA=P.PurchaseRateA,PurchaseRateB=P.PurchaseRateB,PurchaseRateC=P.PurchaseRateC,PurchaseRateD=P.PurchaseRateD,PurchaseRateE=P.PurchaseRateE,PurchaseRateF=P.PurchaseRateF,PurchaseRateG=P.PurchaseRateG
		    ,SellingRate=P.SellingRate,SellingRateA=P.SellingRateA,SellingRateB=P.SellingRateB,SellingRateC=P.SellingRateC,SellingRateD=P.SellingRateD,SellingRateE=P.SellingRateE,SellingRateF=P.SellingRateF,SellingRateG=P.SellingRateG
            ,ReorderLevel=P.ReorderLevel,ReorderQty=P.ReorderQty
		FROM COM_CCPrices P WITH(NOLOCK)
		WHERE P.PriceCCID=@PriceCCID AND ID=@I
	
		SET @I=@I+1	
	END
	
	 select ID,PurchaseRate,PurchaseRateA,PurchaseRateB,PurchaseRateC,PurchaseRateD,PurchaseRateE,PurchaseRateF,PurchaseRateG
		    ,SellingRate,SellingRateA,SellingRateB,SellingRateC,SellingRateD,SellingRateE,SellingRateF,SellingRateG
            ,ReorderLevel,ReorderQty from @TblXML


COMMIT TRANSACTION  
--ROLLBACK TRANSACTION


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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
