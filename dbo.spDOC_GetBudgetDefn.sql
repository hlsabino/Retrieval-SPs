USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetBudgetDefn]
	@BudgetID [int],
	@CostCenterID [int],
	@DocDate [datetime],
	@DimWhere [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	--Declaration Section
	declare @BudDim nvarchar(20),@BudAcc nvarchar(20),@BudAccID INT
	DECLARE @SQL NVARCHAR(max),@MultipleBudgets nvarchar(max)
	
	--SELECT TOP 1 @BudgetID=BudgetDefID FROM COM_BudgetDef 
	--WHERE IsGroup=0 AND StatusID=1 AND @DocDate>=CONVERT(DATETIME,FinYearStartDate) AND @DocDate<dateadd(year,1,CONVERT(DATETIME,FinYearStartDate))
	
	set @MultipleBudgets=''
	IF @BudgetID=0
	BEGIN
		SELECT TOP 1 @BudgetID=a.BudgetID FROM ADM_DocumentBudgets a WITH(NOLOCK)
		join COM_BudgetDef b WITH(NOLOCK) on a.BudgetID=b.BudgetDefID
		WHERE a.CostCenterID=@CostCenterID AND FromDate<=CONVERT(INT,@DocDate) AND ToDate>=CONVERT(INT,@DocDate)
		and b.QtyBudget=0
		
		SELECT @MultipleBudgets=@MultipleBudgets+','+convert(nvarchar,a.BudgetID) FROM ADM_DocumentBudgets a WITH(NOLOCK)
		join COM_BudgetDef b WITH(NOLOCK) on a.BudgetID=b.BudgetDefID
		WHERE a.CostCenterID=@CostCenterID AND FromDate<=CONVERT(INT,@DocDate) AND ToDate>=CONVERT(INT,@DocDate)
		and b.QtyBudget=0
		if @MultipleBudgets!=''
			set @MultipleBudgets=substring(@MultipleBudgets,2,len(@MultipleBudgets))
	END
	
	IF @BudgetID<>0 AND NOT EXISTS (SELECT BudgetID FROM ADM_DocumentBudgets WITH(NOLOCK) 
	WHERE BudgetID=@BudgetID AND CostCenterID=@CostCenterID AND FromDate<=CONVERT(INT,@DocDate) AND ToDate>=CONVERT(INT,@DocDate))
		SET @BudgetID=0
	
	SELECT @BudgetID BudgetID,BudgetTypeID,NumDimensions,QtyBudget,CONVERT(DATETIME,FinYearStartDate) StartYear,QtyType
		,ChkBudgetOnlyForDefnAccounts,NonAccDocs,NonAccDocsField,AccountTypes
	FROM COM_BudgetDef  WITH(NOLOCK)
	WHERE BudgetDefID=@BudgetID 

	SELECT C.CostCenterID,F.Name Name FROM COM_BudgetDefDims C WITH(NOLOCK),ADM_Features F WITH(NOLOCK)
	WHERE C.BudgetDefID=@BudgetID and C.CostCenterID=F.FeatureID
	ORDER BY C.CostCenterID
	
	SET @SQL='SELECT A.CurrencyID,ExchangeRT,AnnualAmount,YearH1Amount,YearH2Amount,Qtr1Amount,Qtr2Amount,Qtr3Amount,Qtr4Amount,
					Month1Amount,Month2Amount,Month3Amount,Month4Amount,Month5Amount,Month6Amount,Month7Amount,Month8Amount,Month9Amount,Month10Amount,Month11Amount,Month12Amount,RowID,CF'
	SELECT @SQL=@SQL+',A.AccountID AS D2' FROM COM_BudgetDefDims C WITH(NOLOCK)
	WHERE C.BudgetDefID=@BudgetID AND C.CostCenterID=2
	
	SELECT @SQL=@SQL+',A.ProductID AS D3' FROM COM_BudgetDefDims C WITH(NOLOCK)
	WHERE C.BudgetDefID=@BudgetID AND C.CostCenterID=3
	
	SELECT @SQL=@SQL+',A.CCNID'+CONVERT(NVARCHAR,C.CostCenterID-50000)+' AS D'+CONVERT(NVARCHAR,C.CostCenterID) FROM COM_BudgetDefDims C WITH(NOLOCK)
	WHERE C.BudgetDefID=@BudgetID AND C.CostCenterID>50000 
	ORDER BY C.CostCenterID

	SET @SQL=@SQL+' FROM COM_BudgetAlloc A WITH(NOLOCK)
	WHERE '
	if @MultipleBudgets!=''
		SET @SQL=@SQL+'A.BudgetDefID IN ('+@MultipleBudgets+')'
	else 
		SET @SQL=@SQL+'A.BudgetDefID='+CONVERT(NVARCHAR,@BudgetID)
		
	if @DimWhere is not null and @DimWhere<>''
	BEGIN
		IF EXISTS(SELECT ChkBudgetOnlyForDefnAccounts FROM COM_BudgetDef  WITH(NOLOCK)
					WHERE BudgetDefID=@BudgetID AND ChkBudgetOnlyForDefnAccounts=1)
			SET @DimWhere=REPLACE(REPLACE(@DimWhere,'(',''),')','')			
		SET @SQL=@SQL+' AND ( '+@DimWhere+' ) '
	END 
		
	SET @SQL=@SQL+' Order By A.RowID ASC'
 print(@SQL)
	EXEC(@SQL)
	
	--select * from COM_BudgetAlloc
	select @BudDim=value from ADM_GlobalPreferences with(nolock) where  name='BudgetDimension'
	if @BudDim!='' and isnumeric(@BudDim)=1
	begin
		select @BudAcc=value from ADM_GlobalPreferences with(nolock) where  name='BudgetAccount'
		if @BudAcc!='' and isnumeric(@BudAcc)=1 and convert(INT,@BudAcc)>0
		begin
			set @BudAccID=convert(int,@BudAcc)
		end
	end
	
	if @BudAccID is null or (select count(*) from COM_BudgetAlloc B with(nolock) where AccountID=@BudAccID)=0
		select 1 BudgetDimensionAccounts where 1!=1
	else
	begin
		set @SQL='
		select A.NodeID DimID,ParentNodeID AccountID
		from COM_CostCenterCostCenterMap A with(nolock) 
		inner join COM_BudgetAlloc B with(nolock) ON B.CCNID'+convert(nvarchar,convert(int,@BudDim)-50000)+'=A.NodeID
		where B.BudgetDefID='+CONVERT(NVARCHAR,@BudgetID)+' and AccountID='+convert(nvarchar,@BudAccID)+' and ParentCostCenterID=2 and CostCenterID='+@BudDim
		exec(@SQL)
	end


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
