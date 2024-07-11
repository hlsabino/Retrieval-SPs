USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetSchemeScreenDetails]
	@Type [int],
	@PriceChartID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--  
BEGIN TRY  
SET NOCOUNT ON;
	
	DECLARE @SQL NVARCHAR(MAX)
	IF @Type=0 /*TO GET SCREEN DETAILS*/
	BEGIN
		SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE (FEATUREID>50000 OR FEATUREID=2)  and ISEnabled=1
		AND FEATUREID NOT IN (50051,50052,50053,50054,50068,50069,50073)

		SELECT ProfileID,ProfileName FROM [ADM_SchemesDiscounts] WITH(NOLOCK)
		where ProfileID>0
		GROUP BY ProfileID,ProfileName
		ORDER BY ProfileName
		
		 SELECT S.StatusID,R.ResourceData AS Status,Status as ActualStatus                              
		 FROM COM_Status S WITH(NOLOCK)                              
		 LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
		 WHERE CostCenterID = 151  
  

		SELECT [Value] FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE [Name]='SchemeFields'

		select SysColumnName,(SELECT TOP 1 ResourceData FROM COM_LanguageResources WITH(NOLOCK) WHERE LanguageID=@LangID AND ResourceID=C.ResourceID) ResourceData FROM ADM_CostCenterDef C
		WHERE CostCenterID=3 AND (SysColumnName LIKE 'PurchaseRate%' OR SysColumnName LIKE 'SellingRate%' 
		OR SysColumnName LIKE 'ReorderLevel%' OR SysColumnName LIKE 'ReorderQty%')
		ORDER BY SysColumnName
	END
	ELSE IF @Type=2 /*TO GET PROFILE DATA BY PROFILEID*/
	BEGIN
			
		SET @SQL='SELECT DISTINCT P.ProductCode,
		P.ProductName,CONVERT(DATETIME,T.FromDate) Fromdt,CONVERT(DATETIME,T.ToDate) Todt,
		T.*,(SELECT TOP 1 UnitName FROM COM_UOM WITH(NOLOCK) WHERE UOMID=T.UOMID AND T.UOMID>0) UOMName,
		(SELECT TOP 1 AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=T.AccountID AND T.AccountID!=0) AccountName'
		
		select @SQL=@SQL+',(SELECT TOP 1 Name FROM '+F.TableName+' WITH(NOLOCK) WHERE NodeID=T.'+C.name+' AND T.'+C.name+'>0) '+REPLACE(C.name,'NID','')
		from sys.columns C WITH(NOLOCK)
		JOIN ADM_FEATURES F WITH(NOLOCK) ON F.FEATUREID=50000+CONVERT(INT,REPLACE(C.name,'CCNID',''))
		where object_id=object_id('ADM_SchemesDiscounts') and C.name LIKE 'ccnid%' and F.FEATUREID<>50054
		
		select @SQL=@SQL+'
		FROM [ADM_SchemesDiscounts] T WITH(NOLOCK)
		INNER JOIN 	INV_Product P WITH(NOLOCK) ON P.ProductID=T.ProductID	
		WHERE T.ProfileID='+CONVERT(NVARCHAR,@PriceChartID)
		
		EXEC (@SQL)
		
		SELECT P.ProductCode,
		P.ProductName,s.Percentage,s.ProductID,s.Quantity,s.SchemeID,s.Value,s.IsQtyPercent,s.Dim1,s.SchemeRowSNo 
		FROM ADM_SchemeProducts s WITH(NOLOCK)
		JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=s.ProductID	
		JOIN [ADM_SchemesDiscounts] T WITH(NOLOCK) on s.SchemeID=T.SchemeID
		WHERE T.ProfileID=@PriceChartID
			
	END
	ELSE IF @Type=3 /*TO GET ALL PROFILES*/
	BEGIN
		SELECT ProfileID,ProfileName FROM [ADM_SchemesDiscounts] WITH(NOLOCK)
		GROUP BY ProfileID,ProfileName
		ORDER BY ProfileName
	END
	ELSE IF @Type=4 /*TO GET CUSTOMIZATION INFO*/
	BEGIN
		
		SELECT [Value],DefaultValue FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE [Name]='SchemeFields'

		SELECT [Value] FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE [Name]='SchemesDefault CC'
	END
	ELSE IF @Type=5 /*TO DELETE PROFILE*/
	BEGIN
	BEGIN TRANSACTION
		DELETE FROM ADM_SchemeProducts where SchemeID in (SELECT SchemeID from [ADM_SchemesDiscounts] WITH(NOLOCK) WHERE ProfileID=@PriceChartID)
		DELETE FROM [ADM_SchemesDiscounts] WHERE ProfileID=@PriceChartID
	COMMIT TRANSACTION
	END
	ELSE IF @Type=6 /*TO GET DEFAULT PROFILE*/
	BEGIN
		DECLARE @CC NVARCHAR(100),@GroupBy NVARCHAR(200),@Join NVARCHAR(MAX)
		CREATE TABLE #TblCC (ID INT IDENTITY(1,1),CC INT)
		
		SELECT @CC=[Value] FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE [Name]='Price Chart Default CC'
		
		SELECT @CC DefaultCC
		
		INSERT INTO #TblCC(CC)
		EXEC SPSplitString @CC,','

		SET @GroupBy='P.UOMID'
		SET @Join='P.UOMID=T.UOMID'
		
		DECLARE @WHERE NVARCHAR(MAX),@OrderBY NVARCHAR(MAX),@I INT,@COUNT INT,@J INT
		SET @WHERE='P.WEF<='+CONVERT(NVARCHAR,CONVERT(FLOAT,getdate()))+' and ProductID='+CONVERT(NVARCHAR,@PriceChartID)
		
		IF (select count(*) from #TblCC WITH(NOLOCK) WHERE CC=2)=0
			SET @WHERE=@WHERE+' AND AccountID=1'
		ELSE
		BEGIN
			SET @GroupBy=@GroupBy+',AccountID'
			SET @Join=@Join+' AND P.AccountID=T.AccountID'
		END
		
		TRUNCATE TABLE #TblCC
		
		INSERT INTO #TblCC
		select CONVERT(INT,REPLACE(name,'CCNID',''))
		from sys.columns WITH(NOLOCK)
		where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
		
		SELECT @J=1,@COUNT=COUNT(*) FROM #TblCC WITH(NOLOCK)
		
		WHILE(@J<=@COUNT)
		BEGIN
			SELECT @I=CC FROM #TblCC WITH(NOLOCK) WHERE ID=@J			
			IF PATINDEX('%'+CONVERT(NVARCHAR,@I)+'%',@CC)=0
				SET @WHERE=@WHERE+' AND CCNID'+convert(nvarchar,@I-50000)+'=1'
			ELSE
			BEGIN
				SET @GroupBy=@GroupBy+',P.CCNID'+convert(nvarchar,@I-50000)
				SET @Join=@Join+' AND P.CCNID'+convert(nvarchar,@I-50000)+'=T.CCNID'+convert(nvarchar,@I-50000)
			END
			SET @J=@J+1	
		END
		
		DROP TABLE #TblCC
		
		SET @SQL='SELECT *,CONVERT(DATETIME,WEF) WEF_DATE 
		,(SELECT TOP 1 UnitName FROM COM_UOM WITH(NOLOCK) WHERE UOMID=P.UOMID AND P.UOMID>0) UOMName
		,(SELECT TOP 1 AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=P.AccountID AND P.AccountID!=0) AccountName

		FROM COM_CCPrices P WITH(NOLOCK) WHERE PriceCCID IN( SELECT MAX(PriceCCID) FROM COM_CCPrices P WITH(NOLOCK),
		(SELECT MAX(WEF) WEF,'+@GroupBy+' FROM COM_CCPrices P WITH(NOLOCK) WHERE '+@WHERE+' GROUP BY '+@GroupBy+') T
					WHERE '+@Join+' AND '+@WHERE+' GROUP BY '+@GroupBy+')'
		print(@SQL)
		EXEC(@SQL)
			
	END
	ELSE IF @Type=7 /*TO GET SchemeID Used*/
	BEGIN
		if exists(select IsQtyFreeOffer from INV_DocDetails  with(nolock) where IsQtyFreeOffer=@PriceChartID)
			select 1
		else
			select 0
	END
	ELSE IF @Type=8 /*TO GET any Scheme Used from profile*/
	BEGIN
		if exists(select IsQtyFreeOffer from INV_DocDetails a with(nolock) 
		join [ADM_SchemesDiscounts]	b with(nolock) on a.IsQtyFreeOffer=b.Schemeid
		 where b.ProfileID=@PriceChartID)
			select 1
		else
			select 0
	END
	
-- 
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
