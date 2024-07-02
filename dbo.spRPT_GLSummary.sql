USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GLSummary]
	@Account [nvarchar](max),
	@IncomeExpAccounts [nvarchar](max),
	@YearStartDate [datetime] = NULL,
	@FromDate [datetime],
	@ToDate [datetime],
	@UpPostedDocsList [nvarchar](200),
	@IncludePDC [bit],
	@IncludeTerminatedPDC [bit],
	@DimensionID [int],
	@DimTable [nvarchar](20) = null,
	@LocationWHERE [nvarchar](max),
	@IsOpeningTagWise [bit] = 0,
	@CurrencyType [int],
	@CurrencyID [int],
	@SELECTQUERY [nvarchar](max),
	@FROMQUERY [nvarchar](max),
	@SELECTQUERYALIAS [nvarchar](max),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
--16 Opening Balance
--14 Postdated Payment
--19 Postdated Receipts
	DECLARE @SQL NVARCHAR(MAX),@PDCSQL NVARCHAR(MAX),@Temp NVARCHAR(200),@AccountName NVARCHAR(200),@AccountCode NVARCHAR(200),@AccountType INT
	DECLARE	@From NVARCHAR(20),@To NVARCHAR(20),@YearStart NVARCHAR(20),@AmtColumn NVARCHAR(10),@CurrWHERE1 NVARCHAR(30),@CurrWHERE2 NVARCHAR(30)
	DECLARE @SQL1 NVARCHAR(MAX),@SQL2 NVARCHAR(MAX),@UnAppSQL NVARCHAR(MAX),@strPDCWhere NVARCHAR(MAX),@strOpeningPDCWhere NVARCHAR(MAX)
	DECLARE @ParticularCr NVARCHAR(350), @ParticularDr NVARCHAR(350),@GrpByVno nvarchar(50)
	DECLARE @DimColumn NVARCHAR(100),@DimColAlias1 NVARCHAR(50),@DimColAlias2 NVARCHAR(50),@DimJoin NVARCHAR(100),@DimOrderBy NVARCHAR(50)
	
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
	SET @YearStart=CONVERT(FLOAT,@YearStartDate)

	set @strOpeningPDCWhere='DocDate<'+@From

	if @UpPostedDocsList=''
		set @UnAppSQL=' AND (D.StatusID=369 or D.StatusID=429)'
	else
		set @UnAppSQL=' AND D.StatusID IN (369,429,'+@UpPostedDocsList+')'
		
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
	END
		
	if @IncludePDC=1
    begin
		SET @Temp='(D.StatusID=370 OR D.StatusID=439'
		IF @IncludeTerminatedPDC=1
			SET @Temp=@Temp+' OR D.StatusID=452'
		SET @Temp=@Temp+')'
        set @strPDCWhere=' AND ('+@Temp+')';
        set @strOpeningPDCWhere =@strOpeningPDCWhere+' AND ('+@Temp+' OR (D.DocumentType<>14 AND D.DocumentType<>19' + @UnAppSQL + '))';
    end
    else
    begin
        set @strPDCWhere=' AND D.DocumentType NOT IN (16,14,19)' + @UnAppSQL;
        set @strOpeningPDCWhere =@strOpeningPDCWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19' + @UnAppSQL;
    end
	
	IF @LocationWHERE<>''
	BEGIN
		SET @SQL1=' INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@LocationWHERE--D.InvDocDetailsID IS NULL AND 
		SET @SQL2=' INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@LocationWHERE
	END
	ELSE
	BEGIN
		SET @SQL1=''
		SET @SQL2=''
	END
	
	IF @DimensionID>0
	BEGIN
		SET @DimColumn=',DCC.dcCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' AS TAG'
		SET @DimColAlias1=',T.TAG,D.Name'
		SET @DimColAlias2=',T.TAG,D.Name DocumentName'
		SET @DimJoin=' INNER JOIN '+@DimTable+' D with(nolock) ON D.NodeID=T.TAG'
		SET @DimOrderBy=''
		SET @GrpByVno=',TAG'
	END
	ELSE IF @DimensionID=-100
	BEGIN
		SET @DimColumn=',dateadd(d,1-day(convert(datetime,D.DocDate)),convert(datetime,D.DocDate)) AS TAG'
		SET @DimColAlias1=',T.TAG'
		SET @DimColAlias2=',T.TAG DocumentName'
		SET @DimJoin=''
		SET @DimOrderBy=''
		SET @GrpByVno=',TAG'
	END
	ELSE
	BEGIN
		SET @DimColumn=''
		SET @DimColAlias1=',DT.DocumentName,DT.DocumentAbbr,T.CostCenterID'
		SET @DimColAlias2=',DT.DocumentName,DT.DocumentAbbr,T.CostCenterID'
		SET @DimJoin=' INNER JOIN ADM_DocumentTypes DT with(nolock) ON DT.CostCenterID=T.CostCenterID'
		SET @DimOrderBy=',DT.DocumentName'
		SET @GrpByVno=',CostCenterID'
	END

IF @IsOpeningTagWise=0
BEGIN
	SET @SQL=''
	IF LEN(@Account)>0
	BEGIN
		SET @SQL='SELECT D.DebitAccount AccountID, D.'+@AmtColumn+' Debit,0 Credit
	FROM ACC_DocDetails D with(nolock) '+@SQL1+'		
	WHERE D.DebitAccount IN ('+@Account+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+'
	UNION ALL
	SELECT D.CreditAccount,0 Debit, D.'+@AmtColumn+' Credit
	FROM ACC_DocDetails D with(nolock) '+@SQL1+'
	WHERE D.CreditAccount IN ('+@Account+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1
	
		IF LEN(@SQL1)>0
		BEGIN
			SET @SQL=@SQL+' UNION ALL SELECT D.DebitAccount AccountID, D.'+@AmtColumn+' Debit,0 Credit
	FROM ACC_DocDetails D with(nolock) '+@SQL2+'		
	WHERE D.DebitAccount IN ('+@Account+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+'
	UNION ALL
	SELECT D.CreditAccount,0 Debit, D.'+@AmtColumn+' Credit
	FROM ACC_DocDetails D with(nolock) '+@SQL2+'
	WHERE D.CreditAccount IN ('+@Account+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1
		END
	END
	
	IF LEN(@IncomeExpAccounts)>0
	BEGIN
		IF LEN(@Account)>0
			SET @SQL=@SQL+' UNION ALL '
		
		SET @SQL=@SQL+'SELECT D.DebitAccount AccountID, D.'+@AmtColumn+' Debit,0 Credit
	FROM ACC_DocDetails D with(nolock) '+@SQL1+'		
	WHERE D.DebitAccount IN ('+@IncomeExpAccounts+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+'
	UNION ALL
	SELECT D.CreditAccount,0 Debit, D.'+@AmtColumn+' Credit
	FROM ACC_DocDetails D with(nolock) '+@SQL1+'
	WHERE D.CreditAccount IN ('+@IncomeExpAccounts+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1
	
		IF LEN(@SQL1)>0
		BEGIN
			SET @SQL=@SQL+' UNION ALL SELECT D.DebitAccount AccountID, D.'+@AmtColumn+' Debit,0 Credit
	FROM ACC_DocDetails D with(nolock) '+@SQL2+'		
	WHERE D.DebitAccount IN ('+@IncomeExpAccounts+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+'
	UNION ALL
	SELECT D.CreditAccount,0 Debit, D.'+@AmtColumn+' Credit
	FROM ACC_DocDetails D with(nolock) '+@SQL2+'
	WHERE D.CreditAccount IN ('+@IncomeExpAccounts+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1
		END
			
		IF LEN(@Account)>0
			SET @Account=@Account+','+@IncomeExpAccounts
		ELSE
			SET @Account=@IncomeExpAccounts
	END
	--exec(@SQL)
	
	SET @SQL='SELECT A.AccountName,A.AccountID,A.AccountTypeID,isnull(SUM(Debit),0)-isnull(SUM(Credit),0) BF 
	FROM ('+@SQL+') AS T  RIGHT JOIN ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID		
	GROUP BY A.AccountName,A.AccountID,A.AccountTypeID HAVING A.AccountID IN ('+@Account+')'
	
	print @SQL
	EXEC(@SQL)


	SET @SQL=''
END
ELSE
BEGIN
	DECLARE @AllAccounts NVARCHAR(MAX)
	SET @AllAccounts=@Account
	
	IF LEN(@IncomeExpAccounts)>0
	BEGIN
		IF LEN(@Account)>0
			SET @AllAccounts=@Account+','+@IncomeExpAccounts
		ELSE
			SET @AllAccounts=@IncomeExpAccounts
	END
			
	SET @SQL='SELECT A.AccountName,A.AccountID,A.AccountTypeID,0 BF 
	FROM ACC_Accounts A with(nolock)
	GROUP BY A.AccountName,A.AccountID,A.AccountTypeID HAVING A.AccountID IN ('+@AllAccounts+')'
	
	print @SQL
	EXEC(@SQL)

	SET @SQL=''
	
	IF LEN(@Account)>0
	BEGIN
		SET @SQL='SELECT DebitAccount AccountID'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,D.'+@AmtColumn+' OpDr,0.0 OpCr,0.0 DebitAmount,0.0  CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=CreditAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DebitAccount IN ('+@Account+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+@LocationWHERE+'
UNION ALL
SELECT CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,D.'+@AmtColumn+' OpCr,0.0 DebitAmount,0.0 CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=DebitAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.CreditAccount IN ('+@Account+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+@LocationWHERE+'
UNION ALL
SELECT DebitAccount AccountID'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,D.'+@AmtColumn+' OpDr,0.0 OpCr,0.0 DebitAmount,0.0  CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=CreditAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
WHERE D.DebitAccount IN ('+@Account+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+@LocationWHERE+'
UNION ALL
SELECT CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,D.'+@AmtColumn+' OpCr,0.0 DebitAmount,0.0 CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=DebitAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
WHERE D.CreditAccount IN ('+@Account+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+@LocationWHERE+'
UNION ALL
'
	END
	
	IF LEN(@IncomeExpAccounts)>0
	BEGIN
			
		SET @SQL=@SQL+' SELECT DebitAccount AccountID'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,D.'+@AmtColumn+' OpDr,0.0 OpCr,0.0 DebitAmount,0.0  CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=CreditAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DebitAccount IN ('+@IncomeExpAccounts+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+@LocationWHERE+'
UNION ALL
SELECT CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,D.'+@AmtColumn+' OpCr,0.0 DebitAmount,0.0 CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=DebitAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.CreditAccount IN ('+@IncomeExpAccounts+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+@LocationWHERE+'
UNION ALL
SELECT DebitAccount AccountID'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,D.'+@AmtColumn+' OpDr,0.0 OpCr,0.0 DebitAmount,0.0 CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=CreditAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
WHERE D.DebitAccount IN ('+@IncomeExpAccounts+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+@LocationWHERE+'
UNION ALL
SELECT CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,D.'+@AmtColumn+' OpCr,0.0 DebitAmount,0.0 CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=DebitAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
WHERE D.CreditAccount IN ('+@IncomeExpAccounts+') AND D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQL+@CurrWHERE1+@LocationWHERE+'
UNION ALL
'
			
		IF LEN(@Account)>0
			SET @Account=@Account+','+@IncomeExpAccounts
		ELSE
			SET @Account=@IncomeExpAccounts
	END
	
END
--select @strPDCWhere
--Two Queries For Cr,Dr For Accounting Vouchers Joins With Location
--Two Queries For Cr,Dr For Inventory Vouchers Joins With Location
SET @SQL=@SQL+'
SELECT DebitAccount AccountID'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,0.0 OpCr,D.'+@AmtColumn+' DebitAmount,0.0 CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=CreditAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DebitAccount IN ('+@Account+') AND D.DocDate>='+@From+' AND D.DocDate<='+@To+' AND D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 '+@LocationWHERE+@UnAppSQL+@CurrWHERE1+'
UNION ALL
SELECT CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,0.0 OpCr,0.0 DebitAmount,D.'+@AmtColumn+'  CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=DebitAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.CreditAccount IN ('+@Account+') AND D.DocDate>='+@From+' AND D.DocDate<='+@To+' AND D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 '+@LocationWHERE+@UnAppSQL+@CurrWHERE1+'
UNION ALL
SELECT DebitAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo, D.CostCenterID,0.0 OpDr,0.0 OpCr,D.'+@AmtColumn+' DebitAmount,0.0 CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
	WHERE D.DebitAccount IN ('+@Account+') AND D.DocDate>='+@From+' AND D.DocDate<='+@To+' '+@LocationWHERE+@UnAppSQL+@CurrWHERE1+'
UNION ALL
SELECT CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,0.0 OpCr,0.0 DebitAmount,D.'+@AmtColumn+'  CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
WHERE D.CreditAccount IN ('+@Account+') AND D.DocDate>='+@From+' AND D.DocDate<='+@To+' '+@LocationWHERE+@UnAppSQL+@CurrWHERE1
--PDC
if @IncludePDC=1
begin
	SET @SQL=@SQL+'
UNION ALL
SELECT DebitAccount AccountID'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,0.0 OpCr,D.'+@AmtColumn+' DebitAmount,0.0  CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=CreditAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DebitAccount IN ('+@Account+') AND (D.DocumentType=14 OR D.DocumentType=19) AND D.DocDate<='+@To+' '+@LocationWHERE+@strPDCWhere+@CurrWHERE1+'
UNION ALL
SELECT CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,D.CostCenterID,0.0 OpDr,0.0 OpCr,0.0 DebitAmount,D.'+@AmtColumn+'  CreditAmount,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=DebitAccount
JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.CreditAccount IN ('+@Account+') AND (D.DocumentType=14 OR D.DocumentType=19) AND D.DocDate<='+@To+' '+@LocationWHERE+@strPDCWhere+@CurrWHERE1
end

--AND D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 

--For Details Report Add AccDocDetailsID In GROUP BY CLAUSE	
IF @IsOpeningTagWise=0
BEGIN
	SET @SQL='SELECT A.AccountName,T.AccountID'+@DimColAlias2+',SUM(DebitAmount) Debit,SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,count(*) VoucherCount,getdate() DocDate'+@SELECTQUERYALIAS+'
FROM (
SELECT AccountID'+@GrpByVno+',SUM(OpDr) OpDr,SUM(OpCr) OpCr
,CASE WHEN SUM(DebitAmount)-SUM(CreditAmount)>0 THEN SUM(DebitAmount)-SUM(CreditAmount) ELSE 0 END DebitAmount
,CASE WHEN SUM(CreditAmount)-SUM(DebitAmount)>0 THEN SUM(CreditAmount)-SUM(DebitAmount) ELSE 0 END CreditAmount
'+@SELECTQUERYALIAS+'
FROM ( '+@SQL+'
) AS T
GROUP BY T.AccountID'+@GrpByVno+',T.VoucherNo'+@SELECTQUERYALIAS+'
) AS T 
INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID'+@DimJoin+'
Group By T.AccountID,A.AccountName'+@DimColAlias1+@SELECTQUERYALIAS+'
ORDER BY A.AccountName'+@DimOrderBy
END
ELSE
BEGIN
	SET @SQL='SELECT A.AccountName,T.AccountID'+@DimColAlias2+',isnull(SUM(OpDr),0)-isnull(SUM(OpCr),0) OpBalance,SUM(DebitAmount) Debit,SUM(CreditAmount) Credit,isnull(SUM(OpDr),0)+ISNULL(SUM(DebitAmount),0)-(isnull(SUM(OpCr),0)+ISNULL(SUM(CreditAmount),0)) Balance'+@SELECTQUERYALIAS+'
FROM (
SELECT AccountID'+@GrpByVno+',SUM(OpDr) OpDr,SUM(OpCr) OpCr
,CASE WHEN SUM(DebitAmount)-SUM(CreditAmount)>0 THEN SUM(DebitAmount)-SUM(CreditAmount) ELSE 0 END DebitAmount
,CASE WHEN SUM(CreditAmount)-SUM(DebitAmount)>0 THEN SUM(CreditAmount)-SUM(DebitAmount) ELSE 0 END CreditAmount
'+@SELECTQUERYALIAS+'
FROM (
'+@SQL+'
) AS T
GROUP BY T.AccountID'+@GrpByVno+',T.VoucherNo'+@SELECTQUERYALIAS+'
) AS T 
INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID'+@DimJoin+'
Group By T.AccountID,A.AccountName'+@DimColAlias1+@SELECTQUERYALIAS+'
ORDER BY A.AccountName'+@DimOrderBy
END
PRINT (substring(@SQL,1,4000))
PRINT (substring(@SQL,4001,4000))
EXEC(@SQL)


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
