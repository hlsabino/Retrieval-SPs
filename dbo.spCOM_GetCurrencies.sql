USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCurrencies]
	@CurrencyID [int] = 0,
	@DimNodeID [bigint],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

SET NOCOUNT ON
BEGIN TRY 
		--Declaration Section
		DECLARE @dim int,@table nvarchar(200),@Name nvarchar(200)
		
		IF(@CurrencyID=0)--GETTING ALL CURRENCIES IF @CurrencyID IS 0
		BEGIN
			SELECT 	CurrencyID,'' [SNO] ,[Name],[Symbol],[Change],[GUID]
			FROM [COM_Currency] WITH(NOLOCK)
			WHERE ISBASECURRENCY=1

			SELECT CurrencyID,row_number() over(order by currencyid) [SNO] 
			,[Name]  
			,[Symbol]  
			,[Change]  
			,[ExchangeRate]  
			,[Decimals]
			,[IsDailyRates]   	
			,[StatusID]
			,[GUID] ,IsDivide		 
			FROM [COM_Currency] WITH(NOLOCK)  where isnull(ISBASECURRENCY,0)=0
		END
		ELSE --GETTING INFO FOR GIVEN @CurrencyID 
		BEGIN
			SELECT [CurrencyID]  
			,[Name]  
			,[Symbol]  
			,[Change]  
			,[ExchangeRate]  
			,[Decimals]  
			,[IsBaseCurrency] 
			,[GUID]   
			,[IsDailyRates] 
			,[StatusID],IsDivide
			FROM [COM_Currency] WITH(NOLOCK)  
			WHERE CurrencyID=@CurrencyID
		END

		  
		SELECT b.CurrencyID  CurrencyID,b.[Name] Name,a.[ExchangeRate]  ExchangeRate 
		,CONVERT(DATETIME,a.ExchangeDate) ExchangeDate,a.GUID as GUID,a.ExchangeDate ED
		FROM COM_EXCHANGERATES a WITH(NOLOCK) 
		LEFT JOIN COM_CURRENCY b WITH(NOLOCK) ON a.CURRENCYID = b.CURRENCYID
		WHERE DimNodeID=@DimNodeID
		
	 select @dim=value from ADM_GlobalPreferences WITH(NOLOCK) 
	 where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(bigint,value)>50000
	 
	 if(@dim is not null)
	 BEGIN	 
		select @table=TableName,@Name=Name from ADM_Features WITH(NOLOCK) where FeatureID=@dim
		set @table='select CurrencyID,'''+@Name+''' Name from '+@table+' WITH(NOLOCK) where NodeID='+convert(nvarchar,@DimNodeID)
		--print @table
		exec(@table)
	 END
	 else
		select 1 NoDimCurrency where 1!=1
	
	select Name,Value from com_costcenterpreferences with(nolock) where CostCenterID=12
			 
   

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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
