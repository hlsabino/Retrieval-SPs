USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetCurrencyExchangeRate]
	@NodeID [int],
	@DocDate [datetime],
	@DimNodeID [bigint],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	 DECLARE @CNT BIGINT
	 SET @CNT = 0
	 SELECT @CNT = COUNT(CurrencyID) FROM COM_EXCHANGERATES WITH(NOLOCK) 
	 WHERE CURRENCYID = @NodeID and EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
	 and DimNodeID=@DimNodeID
	
	 --IF (@NodeID = 1)
	 --  SELECT ExchangeRate Rate, Name  FROM 
	 --  COM_Currency where CurrencyID = @NodeID
	 
	 IF( @CNT > 0 )
	   BEGIN
			 SELECT TOP 1 ExchangeRate Rate,'' Name  FROM 
			COM_EXCHANGERATES WITH(NOLOCK) where CurrencyID = @NodeID AND EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
			and DimNodeID=@DimNodeID
			ORDER BY EXCHANGEDATE DESC
	   END 
	ELSE
		   SELECT ExchangeRate Rate, Name  FROM COM_Currency WITH(NOLOCK) where CurrencyID = @NodeID
	
 
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
