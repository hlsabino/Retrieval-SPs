USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GLOnlyDimension]
	@AccountTypes [nvarchar](100),
	@FromDate [datetime],
	@ToDate [datetime],
	@UpPostedDocsList [nvarchar](200),
	@IncludePDC [bit],
	@IncludeUnApprovedPDC [bit],
	@IncludeTerminatedPDC [bit],
	@PDCSeperate [bit],
	@DrCrCSeperate [bit],
	@PDCFilterOn [nvarchar](20),
	@PDCSortOn [nvarchar](20),
	@DimensionID [int],
	@DimTable [nvarchar](20),
	@LocationWHERE [nvarchar](max),
	@IsDetailInv [bit] = 0,
	@IsDetailAcc [bit] = 0,
	@CurrencyType [int],
	@CurrencyID [int],
	@JVDetail [bit],
	@SELECTQUERY [nvarchar](max),
	@FROMQUERY [nvarchar](max),
	@SELECTQUERYALIAS [nvarchar](max),
	@IsCAD [bit] = 0,
	@FCWithExchRate [float] = 0,
	@UpPostedDocsListOP [nvarchar](200),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
/***16-Opening Balance,14-Postdated Payment,19-Postdated Receipts***/

	DECLARE @SQL NVARCHAR(MAX),@INV_SELECT NVARCHAR(MAX),@PDCSQL NVARCHAR(MAX),@Temp NVARCHAR(100),@AccountName NVARCHAR(200),@AccountCode NVARCHAR(200),@AccountType INT
	DECLARE	@From NVARCHAR(20),@To NVARCHAR(20),@AmtColumn NVARCHAR(32),@CurrWHERE1 NVARCHAR(30),@CurrWHERE2 NVARCHAR(30)
	DECLARE @DimColumn NVARCHAR(50),@DimColAlias NVARCHAR(50),@DimJoin NVARCHAR(100),@DetailSQL NVARCHAR(50),@InvDetailSQL NVARCHAR(50),@UnAppSQL NVARCHAR(MAX),@UnAppSQLOP NVARCHAR(MAX)
	declare @PartJoin1 nvarchar(100),@PartJoin2 nvarchar(100),@AccName nvarchar(30)
	DECLARE @ParticularCr NVARCHAR(500),@ParticularDr NVARCHAR(500),@ParticularCrAcc NVARCHAR(900),@ParticularCrAccJV NVARCHAR(1050),@ParticularDrAcc NVARCHAR(900),@ParticularDrAccJV NVARCHAR(1050)
	
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
	
	--if @IsCAD=1
	--begin
	--	set @PartJoin1=' join ACC_Accounts A2 with(nolock) on A2.AccountID=D.CreditAccount'
	--	set @PartJoin2=' join ACC_Accounts A2 with(nolock) on A2.AccountID=D.DebitAccount'
	--	set @AccName='A2.AccountName,A2.AccountID'
	--end	
	--else
	begin
		set @PartJoin1=''
		set @PartJoin2=''
		set @AccName='A.AccountName,A.AccountID'
	end
	
	if @AccountTypes is not null and @AccountTypes!=''
		set @AccountTypes=' AND A.AccountTypeID IN ('+@AccountTypes+')'
	
	if @UpPostedDocsList=''
		set @UnAppSQL=' AND (D.StatusID=369 or D.StatusID=429)'
	else
		set @UnAppSQL=' AND D.StatusID IN (369,429,'+@UpPostedDocsList+')'
	
	if @UpPostedDocsListOP=''
		set @UnAppSQLOP=' AND (D.StatusID=369 or D.StatusID=429)'
	else
		set @UnAppSQLOP=' AND D.StatusID IN (369,429,'+@UpPostedDocsListOP+')'	
		
	IF @CurrencyID>0
	BEGIN
		SET @AmtColumn='AmountFC'
		SET @CurrWHERE1=' AND D.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
		SET @CurrWHERE2=' AND AD.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
	END
	ELSE
	BEGIN
		IF @CurrencyType=1
			SET @AmtColumn='AmountBC'
		ELSE
			SET @AmtColumn='Amount'
		SET @CurrWHERE1=''
		SET @CurrWHERE2=''
		
		IF(@FCWithExchRate>0)
			SET @AmtColumn='Amount/'+CONVERT(NVARCHAR,@FCWithExchRate)
	END

	IF @DimensionID>0
	BEGIN
		SET @DimColumn='DCC.dcCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' AS TAG'
		SET @DimColAlias='T.TAG,D.Name'
		SET @DimJoin=' INNER JOIN '+@DimTable+' D with(nolock) ON D.NodeID=T.TAG'
	END
	ELSE
	BEGIN
		SET @DimColumn=''
		SET @DimColAlias=''
		SET @DimJoin=''
	END
	
	--INNER JOIN ACC_Accounts A ON A.AccountID=T.AccountID
	
	SET @SQL='SELECT '+@DimColumn+',D.'+@AmtColumn+' Debit,0 Credit
	FROM ACC_DocDetails D with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=D.DebitAccount'+@AccountTypes+'
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@LocationWHERE+'		
	WHERE D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+'
	UNION ALL
	SELECT '+@DimColumn+',0 Debit, D.'+@AmtColumn+' Credit
	FROM ACC_DocDetails D with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=D.CreditAccount'+@AccountTypes+'
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@LocationWHERE+'
	WHERE D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+'
	UNION ALL
	SELECT '+@DimColumn+', D.'+@AmtColumn+' Debit,0 Credit
	FROM ACC_DocDetails D with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=D.DebitAccount'+@AccountTypes+'
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@LocationWHERE+'		
	WHERE D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+'
	UNION ALL
	SELECT '+@DimColumn+',0 Debit, D.'+@AmtColumn+' Credit
	FROM ACC_DocDetails D with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=D.CreditAccount'+@AccountTypes+'
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@LocationWHERE+'
	WHERE D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1
	
	SET @SQL='SELECT '+@DimColAlias+',ISNULL(SUM(Debit)-SUM(Credit),0) BF
	FROM ('+@SQL+') AS T '+@DimJoin+'
	GROUP BY '+@DimColAlias
	
	print @SQL
	EXEC(@SQL)

	--IF @DimensionID>0
	--BEGIN
	--	SET @DimColAlias=',T.TAG'
	--END

	IF @IsDetailInv=1
	BEGIN
		SET @InvDetailSQL='AD.AccDocDetailsID,AD.DocSeqNo,'
		
		SET @ParticularCr='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=AD.CreditAccount) Particular,AD.CreditAccount ParticularID'
		SET @ParticularDr='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=AD.DebitAccount) Particular,AD.DebitAccount ParticularID'
	END
	ELSE
	BEGIN
		IF @IsDetailAcc=1
			SET @InvDetailSQL='0 AccDocDetailsID,0 DocSeqNo,'
		ELSE
			SET @InvDetailSQL=''
		
		SET @ParticularCr='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=dbo.[fnRPT_GLParticular](1,D.DocID,AD.DebitAccount,AD.CreditAccount)) Particular,dbo.[fnRPT_GLParticular](1,D.DocID,AD.DebitAccount,AD.CreditAccount) ParticularID'
		SET @ParticularDr='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=dbo.[fnRPT_GLParticular](0,D.DocID,AD.CreditAccount,AD.DebitAccount)) Particular,dbo.[fnRPT_GLParticular](0,D.DocID,AD.CreditAccount,AD.DebitAccount) ParticularID'
	END	
	
	IF @IsDetailAcc=1
	BEGIN
		SET @DetailSQL='D.AccDocDetailsID,D.DocSeqNo,'
		
		SET @ParticularCrAcc='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.CreditAccount) Particular,D.CreditAccount ParticularID'
		SET @ParticularDrAcc='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.DebitAccount) Particular,D.DebitAccount ParticularID'
		set @ParticularCrAccJV='case when D.CreditAccount>0 then (SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.CreditAccount) else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.DebitAccount,0,'+convert(nvarchar,@JVDetail)+') end Particular
,case when D.CreditAccount>0 then D.CreditAccount else (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID=D.DocID and I.CreditAccount>0) end ParticularID'
		set @ParticularDrAccJV='case when D.DebitAccount>0 then (SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.DebitAccount) else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.CreditAccount,1,'+convert(nvarchar,@JVDetail)+') end Particular
,case when D.DebitAccount>0 then D.DebitAccount else (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID and I.DebitAccount>0) end ParticularID'
	END
	ELSE
	BEGIN
		IF @IsDetailInv=1
			SET @DetailSQL='0 AccDocDetailsID,0 DocSeqNo,'
		ELSE
			SET @DetailSQL=''
		
		SET @ParticularCrAcc='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID)) Particular,(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) ParticularID'
		SET @ParticularDrAcc='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID)) Particular,(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) ParticularID'
		set @ParticularCrAccJV='case when D.CreditAccount>0 then (SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID order by IsNegative asc,AccDocDetailsID)) 
		else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.DebitAccount,0,'+convert(nvarchar,@JVDetail)+') end Particular
		,(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID and I.CreditAccount>0 order by IsNegative asc,AccDocDetailsID) ParticularID'
		set @ParticularDrAccJV='case when D.DebitAccount>0 then (SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID order by IsNegative asc,AccDocDetailsID)) 
		else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.CreditAccount,1,'+convert(nvarchar,@JVDetail)+') end Particular
		,(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID and I.DebitAccount>0 order by IsNegative asc,AccDocDetailsID) ParticularID'
		
	END
	
SET @INV_SELECT=replace(@SELECTQUERY,'D.ClearanceDate','NULL')
SET @INV_SELECT=replace(@INV_SELECT,'D.ConvertedDate','NULL')
SET @INV_SELECT=replace(@INV_SELECT,'D.BRS_Status','NULL')
SET @INV_SELECT=replace(@INV_SELECT,'D.ChequeBankName','NULL')

	--SET @DimColumn=','+@DimColumn
	--SET @DimColAlias=','+@DimColAlias
	
		--4,5,8,9,11,12,13,14
--Two Queries For Cr,Dr For Accounting Vouchers Joins With Location
--Two Queries For Cr,Dr For Inventory Vouchers Joins With Location
SET @SQL='SELECT '+@DimColumn+','+@DetailSQL+@AccName+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo, D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularCrAccJV+',D.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=D.DebitAccount'+@AccountTypes+'
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@PartJoin1+@FROMQUERY+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>='+@From+' AND D.DocDate<='+@To+' '+@LocationWHERE+@UnAppSQL+@CurrWHERE1+'
UNION ALL
SELECT '+@DimColumn+','+@DetailSQL+@AccName+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularDrAccJV+',NULL DebitAmount,D.'+@AmtColumn+' CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=D.CreditAccount'+@AccountTypes+'
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@PartJoin2+@FROMQUERY+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>='+@From+' AND D.DocDate<='+@To+' '+@LocationWHERE+@UnAppSQL+@CurrWHERE1+'
UNION ALL
SELECT '+@DimColumn+','+@InvDetailSQL+@AccName+',CONVERT(DATETIME,AD.DocDate) DocDate, AD.VoucherNo, D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularCr+',AD.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,AD.ChequeNumber,CONVERT(DATETIME,AD.ChequeDate) ChequeDate,CONVERT(DATETIME,AD.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@INV_SELECT+'
FROM ACC_DocDetails AD with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=AD.DebitAccount'+@AccountTypes+'
INNER JOIN INV_DocDetails D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+replace(@PartJoin1,'D.','AD.')+replace(@FROMQUERY,'AccDocDetailsID','InvDocDetailsID')+'
WHERE AD.DocumentType<>16 AND AD.DocumentType<>14 AND AD.DocumentType<>19 AND AD.DocDate>='+@From+' AND AD.DocDate<='+@To+' '+@LocationWHERE+@UnAppSQL+@CurrWHERE2+'
UNION ALL
SELECT '+@DimColumn+','+@InvDetailSQL+@AccName+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularDr+',NULL DebitAmount,AD.'+@AmtColumn+' CreditAmount,0.0 Balance,AD.ChequeNumber,CONVERT(DATETIME,AD.ChequeDate) ChequeDate,CONVERT(DATETIME,AD.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@INV_SELECT+'
FROM ACC_DocDetails AD with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=AD.CreditAccount'+@AccountTypes+'
INNER JOIN INV_DocDetails D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+replace(@PartJoin2,'D.','AD.')+replace(@FROMQUERY,'AccDocDetailsID','InvDocDetailsID')+'
WHERE AD.DocumentType<>16 AND AD.DocumentType<>14 AND AD.DocumentType<>19 AND AD.DocDate>='+@From+' AND AD.DocDate<='+@To+' '+@LocationWHERE+@UnAppSQL+@CurrWHERE2


IF @IncludePDC=1
BEGIN
	SET @Temp='(D.StatusID=370 OR D.StatusID=439'
	IF @IncludeUnApprovedPDC=1
		SET @Temp=@Temp+' OR D.StatusID=371 OR D.StatusID=441'
	IF @IncludeTerminatedPDC=1
		SET @Temp=@Temp+' OR D.StatusID=452'
	SET @Temp=@Temp+')'
		
	declare @LineWisePDC nvarchar(50)
	set @LineWisePDC=''
	SELECT @LineWisePDC=@LineWisePDC+convert(nvarchar,CostCenterID)+',' FROM COM_DocumentPreferences with(nolock) WHERE (DocumentType=14 or DocumentType=19) and (Prefname='LineWisePDC' and Prefvalue='true')
	if(@LineWisePDC!='')
	begin
		set @LineWisePDC=substring(@LineWisePDC,1,len(@LineWisePDC)-1)
		if(charindex(',',@LineWisePDC,1)>0)
			set @LineWisePDC=' and D.CostCenterID not IN ('+@LineWisePDC+')'
		else
			set @LineWisePDC=' and D.CostCenterID!='+@LineWisePDC
	end	
		
	SET @PDCSQL='SELECT '+@DimColumn+','+@DetailSQL+'A.AccountName,DebitAccount AccountID,CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate, D.VoucherNo,D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularCrAcc+',D.'+@AmtColumn+' DebitAmount,NULL CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,D.StatusID StatusID'+@SELECTQUERY+'
	FROM ACC_DocDetails D with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=D.DebitAccount'+@AccountTypes+'
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE '+@Temp+' AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'<='+@To+' '+@LocationWHERE+@CurrWHERE1+@LineWisePDC+'
	UNION ALL
	SELECT '+@DimColumn+','+@DetailSQL+'A.AccountName,CreditAccount,CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate,D.VoucherNo,D.BillNo,CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularDrAcc+',NULL DebitAmount,D.'+@AmtColumn+' CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,D.StatusID StatusID'+@SELECTQUERY+'
	FROM ACC_DocDetails D with(nolock) INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=D.CreditAccount'+@AccountTypes+'
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE '+@Temp+' AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'<='+@To+' '+@LocationWHERE+@CurrWHERE1+@LineWisePDC
	
END

IF @IncludePDC=1 AND @PDCSeperate=0
BEGIN
	SET @SQL=@SQL+N' union all '+@PDCSQL
END

--For Details Report Add AccDocDetailsID In GROUP BY CLAUSE	
IF @IsDetailInv=1 OR @IsDetailAcc=1
BEGIN
	SET @SQL='SELECT '+@DimColAlias+',AccountName,AccountID, DocDate, VoucherNo, BillNo, BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate,CASE WHEN AccountName=MAX(Particular) THEN MIN(Particular) ELSE MAX(Particular) END Particular,MAX(ParticularID) ParticularID, SUM(DebitAmount) Debit, SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,MAX(T.StatusID) StatusID'+@SELECTQUERYALIAS+'
	FROM ( '+@SQL+') AS T '+@DimJoin+' Group By '+@DimColAlias+',DocDate,DocSeqNo,AccDocDetailsID,VoucherNo,AccountName,AccountID,BillNo,BillDate'+@SELECTQUERYALIAS
	SET @SQL=@SQL+' order by '+@DimColAlias+',DocDate,VoucherNo,DocSeqNo,AccDocDetailsID,AccountName'
	--PRINT (@SQL)
	--SELECT @SQL
	EXEC(@SQL)

	IF @IncludePDC=1 AND @PDCSeperate=1
	BEGIN	
		SET @SQL='SELECT '+@DimColAlias+',AccountName,AccountID,DocDate, VoucherNo, BillNo, BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate,CASE WHEN AccountName=MAX(Particular) THEN MIN(Particular) ELSE MAX(Particular) END Particular,MAX(ParticularID) ParticularID, SUM(DebitAmount) Debit, SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,VType,MAX(T.StatusID) StatusID '+@SELECTQUERYALIAS+'
	FROM ( '+@PDCSQL+') AS T '+@DimJoin+' Group By '+@DimColAlias+',DocDate,DocSeqNo,AccDocDetailsID,VoucherNo,AccountName,AccountID,BillNo,BillDate,VType'+@SELECTQUERYALIAS
	SET @SQL=@SQL+' order by '+@DimColAlias+',DocDate,VoucherNo,DocSeqNo,AccDocDetailsID,AccountName,VType'
	--PRINT( @SQL)
		EXEC(@SQL)
	END
END
ELSE
BEGIN

	SET @SQL='SELECT '+@DimColAlias+',AccountName,AccountID, DocDate, VoucherNo, MAX(BillNo) BillNo, MAX(BillDate) BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate,CASE WHEN AccountName=MAX(Particular) THEN MIN(Particular) ELSE MAX(Particular) END Particular,MAX(ParticularID) ParticularID,SUM(DebitAmount) Debit, SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,MAX(T.StatusID) StatusID'+@SELECTQUERYALIAS+'
	FROM ( '+@SQL+') AS T '+@DimJoin+' Group By '+@DimColAlias+',DocDate,VoucherNo,AccountName,AccountID,BillNo,BillDate'--,ChequeNumber,ChequeDate,ChequeMaturityDate
	SET @SQL=@SQL+' order by '+@DimColAlias+',DocDate,VoucherNo,AccountName'
	PRINT (@SQL)
--select LEN(@SQL)
--5188
--PRINT (substring(@SQL,1,4000)	)
--PRINT (substring(@SQL,4000,LEN(@SQL)-4000)	)
	--SELECT @SQL
	EXEC(@SQL)
	

	IF @IncludePDC=1 AND @PDCSeperate=1
	BEGIN	
		SET @SQL='SELECT '+@DimColAlias+',AccountName,AccountID,DocDate, VoucherNo, MAX(BillNo) BillNo, MAX(BillDate) BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate,CASE WHEN AccountName=MAX(Particular) THEN MIN(Particular) ELSE MAX(Particular) END Particular,MAX(ParticularID) ParticularID,SUM(DebitAmount) Debit, SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,VType,MAX(T.StatusID) StatusID '+@SELECTQUERYALIAS+'
	FROM ( '+@PDCSQL+') AS T '+@DimJoin+' Group By '+@DimColAlias+',DocDate,VoucherNo,AccountName,AccountID,BillNo,BillDate,VType'--,ChequeNumber,ChequeDate,ChequeMaturityDate
	SET @SQL=@SQL+' order by '+@DimColAlias+',DocDate,VoucherNo,AccountName,VType'
		EXEC(@SQL)
	END
END

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
