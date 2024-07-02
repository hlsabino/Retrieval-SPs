USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterDetails]
	@CostCenterID [int] = 0,
	@FieldName [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		 
		--Declaration Section
		DECLARE @Table nvarchar(50),@SQL nvarchar(max) 

		--SP Required Parameters Check
		IF @CostCenterID=0 
		BEGIN
			RAISERROR('-100',16,1)
		END

		--To get costcenter table name
		SELECT @Table=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterId

		IF @CostCenterId=2
		BEGIN
			IF(@FieldName<>'')
			BEGIN 
				SET @SQL='SELECT AccountID NodeID,AccountName Name, AccountCode Code,'+@FieldName+'
				 FROM '+@Table+' WITH(nolock) '
			END
			ELSE
				SET @SQL='SELECT AccountID NodeID,AccountName Name, AccountCode Code FROM '+@Table+' WITH(nolock) '
		END
		ELSE IF @CostCenterId=3
		BEGIN		
			IF(@FieldName<>'')
			BEGIN 
				SET @SQL='SELECT P.ProductID NodeID,P.ProductName Name, P.ProductCode Code,'+@FieldName+'
				 FROM '+@Table+' P WITH(nolock) ' 
				if(@FieldName  LIKE '%Alpha%')
					SET @SQL=@SQL+' LEFT JOIN INV_ProductExtended E WITH(NOLOCK) ON P.PRODUCTID=E.PRODUCTID' 
			END
			ELSE
				SET @SQL='SELECT ProductID NodeID,ProductName Name, ProductCode Code FROM '+@Table+' WITH(nolock) '
		END
		ELSE IF @CostCenterId=5
			SET @SQL='SELECT FeatureID NodeID,Name,Name Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=7
			SET @SQL='SELECT UserID NodeID,UserName Name,UserName Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=92
			SET @SQL='SELECT NodeID,Name,Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=93
			SET @SQL='SELECT UnitID NodeID,Name,Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=94
			SET @SQL='SELECT TenantID NodeID,FirstName Name,TenantCode Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=11
			SET @SQL='SELECT U.UOMID NodeID,U.UnitName Name, U.UnitName Code, P.ProductCode, P.ProductName FROM Com_UOM U WITH(nolock) 
			LEFT JOIN INV_PRODUCT P WITH (NOLOCK) ON U.PRODUCTID=P.PRODUCTID'
		ELSE IF @CostCenterId=12
			SET @SQL='SELECT CurrencyID NodeID,Name Name, Symbol Code,ExchangeRate FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=71
			SET @SQL='SELECT ResourceID NodeID,ResourceName Name, ResourceCode Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=77
			SET @SQL='SELECT PostingGroupID NodeID,PostGroupName Name,PostGroupCode Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=72
			SET @SQL='SELECT AssetID NodeID,AssetName Name,AssetCode Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=76
			SET @SQL='SELECT BOMID NodeID,BOMName Name,BOMCode Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=83
			SET @SQL='SELECT CustomerID NodeID,CustomerName Name,CustomerCode Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId=95
			SET @SQL='SELECT ContractID NodeID,SNO Name,SNO Code FROM '+@Table+' WITH(nolock) '
		ELSE IF @CostCenterId>=50001
		BEGIN	
			IF EXISTS (select Name from sys.columns where Name='CurrencyID' and object_id=object_id(@Table))	
			BEGIN
				IF(@FieldName IS NULL OR @FieldName='')
					SET @FieldName='T.CurrencyID Curr,(SELECT ExchangeRate FROM COM_Currency CU WITH(NOLOCK) where CU.CurrencyID = T.CurrencyID) Exch'
				ELSE
					SET @FieldName=@FieldName+',T.CurrencyID Curr,(SELECT ExchangeRate FROM COM_Currency CU WITH(NOLOCK) where CU.CurrencyID = T.CurrencyID) Exch'
			END
			
			IF(@FieldName<>'')
			BEGIN 
				SET @SQL='SELECT T.NodeID,T.Name,T.Code,'+@FieldName+'
				 FROM '+@Table+' T WITH(nolock) ' 
			END
			ELSE
				SET @SQL='SELECT T.NodeID,T.Name,T.Code FROM '+@Table+' T WITH(nolock) '
		END
		ELSE
			SET @SQL='SELECT NodeID,Name, Code FROM '+@Table+' WITH(nolock) '
		PRINT (@SQL)
		EXEC(@SQL)  

COMMIT TRANSACTION 
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
