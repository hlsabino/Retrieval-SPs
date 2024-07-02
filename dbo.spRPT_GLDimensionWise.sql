USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GLDimensionWise]
	@Account [nvarchar](max),
	@IncomeExpAccounts [nvarchar](max),
	@YearStartDate [datetime] = NULL,
	@IsCtrlAcc [bit],
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
	@SortDateBy [nvarchar](30),
	@SELECTQUERY [nvarchar](max),
	@FROMQUERY [nvarchar](max),
	@SELECTQUERYALIAS [nvarchar](max),
	@FCWithExchRate [float] = 0,
	@UpPostedDocsListOP [nvarchar](200),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
/***16-Opening Balance,14-Postdated Payment,19-Postdated Receipts***/

	DECLARE @SQL NVARCHAR(MAX),@INV_SELECT NVARCHAR(MAX),@PDCSQL NVARCHAR(MAX),@Temp NVARCHAR(max),@AccountName NVARCHAR(200),@AccountCode NVARCHAR(200),@AccountType INT
	DECLARE	@From NVARCHAR(20),@To NVARCHAR(20),@YearStart NVARCHAR(20),@AmtColumn NVARCHAR(32),@CurrWHERE1 NVARCHAR(30),@CurrWHERE2 NVARCHAR(30)
	DECLARE @DimColumn NVARCHAR(50),@DimColAlias NVARCHAR(50),@DimJoin NVARCHAR(100),@DetailSQL NVARCHAR(50),@InvDetailDr NVARCHAR(50),@InvDetailCr NVARCHAR(50),@UnAppSQL NVARCHAR(MAX),@UnAppSQLOP NVARCHAR(MAX)
	DECLARE @ParticularCr NVARCHAR(350), @ParticularDr NVARCHAR(350), @ParticularCrAcc NVARCHAR(350), @ParticularDrAcc NVARCHAR(350),@ReportByPDCConvDate bit,@IntermediatePDC NVARCHAR(max), @ParticularCrAccJV NVARCHAR(MAX), @ParticularDrAccJV NVARCHAR(MAX)
		,@TblAccName varchar(max),@CntrlAccWhere varchar(max),@SortAccountID varchar(10)
	create table #TblAcc(AccountID INT primary key,IsExpense bit default(1))
	
	if exists (select Value from adm_globalpreferences with(nolock) where name ='ReportByPDCConvDate' and Value='True')
		set @ReportByPDCConvDate=1
	else
		set @ReportByPDCConvDate=0
	
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
	SET @YearStart=CONVERT(FLOAT,@YearStartDate)

	insert into #TblAcc(AccountID)
	exec SPSplitString @Account,','
	update #TblAcc set IsExpense=0 

	if @IsCtrlAcc=1
	begin		
		set @TblAccName='Acc_Accounts'
		set @CntrlAccWhere=' and AL.ParentID='+@Account
		set @SortAccountID='1'
	end
	else
	begin		
		set @TblAccName='#TblAcc'
		set @CntrlAccWhere=''
		set @SortAccountID='AccountID'
		if len(@IncomeExpAccounts)>0
		begin
			insert into #TblAcc(AccountID)
			exec SPSplitString @IncomeExpAccounts,','
		end
	end

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
		SET @DimColumn=',DCC.dcCCNID'+CONVERT(NVARCHAR,@DimensionID-50000)+' AS TAG'
		SET @DimColAlias=',T.TAG,D.Name'
		SET @DimJoin=' INNER JOIN '+@DimTable+' D with(nolock) ON D.NodeID=T.TAG'
	END
	ELSE
	BEGIN
		SET @DimColumn=''
		SET @DimColAlias=''
		SET @DimJoin=''
	END
	
	set @IntermediatePDC=''
	if @ReportByPDCConvDate=1 and exists(select Value from adm_globalPreferences with(nolock) where name='IntermediatePDConConversionDate' and Value='False')
	begin		
		select @IntermediatePDC=@IntermediatePDC+convert(nvarchar,IntermediateConvertion)+',' from adm_documenttypes 
		where IntermediateConvertion>0
		group by IntermediateConvertion
		if len(@IntermediatePDC)!=''
		begin
			set @IntermediatePDC=substring(@IntermediatePDC,1,len(@IntermediatePDC)-1)
			set @IntermediatePDC=' and (D.CostCenterID not in ('+@IntermediatePDC+') or D.ConvertedDate is null or D.ConvertedDate<='+@To+')'
		end
	end
	--INNER JOIN ACC_Accounts A ON A.AccountID=T.AccountID
	SET @SQL=''
	IF LEN(@Account)>0
	BEGIN
		SET @SQL='SELECT '+(case when @IsCtrlAcc=0 then 'D.DebitAccount' else 'AL.ParentID' end)+' AccountID'+@DimColumn+',D.'+@AmtColumn+' Debit,0 Credit
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@LocationWHERE+'		
WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+' and D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+@IntermediatePDC+'
UNION ALL
SELECT '+(case when @IsCtrlAcc=0 then 'D.CreditAccount' else 'AL.ParentID' end)+@DimColumn+',0 Debit, D.'+@AmtColumn+' Credit
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@LocationWHERE+'
WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+' and D.DocumentType<>14 AND D.DocumentType<>19  AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+@IntermediatePDC+'
UNION ALL
SELECT '+(case when @IsCtrlAcc=0 then 'D.DebitAccount' else 'AL.ParentID' end)+' AccountID'+@DimColumn+', D.'+@AmtColumn+' Debit,0 Credit
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@LocationWHERE+'		
WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+' and (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+'
UNION ALL
SELECT '+(case when @IsCtrlAcc=0 then 'D.CreditAccount' else 'AL.ParentID' end)+@DimColumn+',0 Debit, D.'+@AmtColumn+' Credit
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@LocationWHERE+'
WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+' and (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1
	END
	
	IF LEN(@IncomeExpAccounts)>0
	BEGIN

		IF LEN(@Account)>0
			SET @SQL=@SQL+' UNION ALL '
		SET @SQL=@SQL+'SELECT D.DebitAccount AccountID'+@DimColumn+',D.'+@AmtColumn+' Debit,0 Credit
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@LocationWHERE+@IntermediatePDC+'	
WHERE AL.IsExpense=1 and D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+'
UNION ALL
SELECT D.CreditAccount'+@DimColumn+',0 Debit, D.'+@AmtColumn+' Credit
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@LocationWHERE+@IntermediatePDC+'
WHERE AL.IsExpense=1 and D.DocumentType<>14 AND D.DocumentType<>19  AND ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+'
UNION ALL
SELECT D.DebitAccount AccountID'+@DimColumn+', D.'+@AmtColumn+' Debit,0 Credit
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@LocationWHERE+'		
WHERE AL.IsExpense=1 and ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1+'
UNION ALL
SELECT D.CreditAccount'+@DimColumn+',0 Debit, D.'+@AmtColumn+' Credit
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@LocationWHERE+'
WHERE AL.IsExpense=1 and ((D.DocDate>='+@YearStart+' and D.DocDate<'+@From+') OR D.DocumentType=16)'+@UnAppSQLOP+@CurrWHERE1
	END
			
	SET @SQL='SELECT A.AccountName,A.AccountID,A.AccountTypeID'+@DimColAlias+',ISNULL(SUM(Debit)-SUM(Credit),0) BF 
	FROM ('+@SQL+') AS T INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID
	'+@DimJoin+' join #TblAcc AL on AL.AccountID=A.AccountID
	GROUP BY A.AccountName,A.AccountID,A.AccountTypeID'+@DimColAlias
	
	--print @SQL
	EXEC(@SQL)

	--IF @DimensionID>0
	--BEGIN
	--	SET @DimColAlias=',T.TAG'
	--END

	IF @IsDetailInv=1
	BEGIN
		SET @InvDetailDr='AD.CreditAccount AccDocDetailsID,AD.DocSeqNo,'
		SET @InvDetailCr='AD.DebitAccount AccDocDetailsID,AD.DocSeqNo,'
		SET @ParticularCr='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=AD.CreditAccount) Particular,AD.CreditAccount ParticularID'
		SET @ParticularDr='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=AD.DebitAccount) Particular,AD.DebitAccount ParticularID'
	END
	ELSE
	BEGIN
		if @IsDetailAcc=1
		begin
			SET @InvDetailDr='0 AccDocDetailsID,0 DocSeqNo,'
			SET @InvDetailCr='0 AccDocDetailsID,0 DocSeqNo,'
		end
		else
		begin
			SET @InvDetailDr=''
			SET @InvDetailCr=''
		end
		SET @ParticularCr='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=dbo.[fnRPT_GLParticular](1,D.DocID,AD.DebitAccount,AD.CreditAccount)) Particular,dbo.[fnRPT_GLParticular](1,D.DocID,AD.DebitAccount,AD.CreditAccount) ParticularID'
		SET @ParticularDr='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=dbo.[fnRPT_GLParticular](0,D.DocID,AD.CreditAccount,AD.DebitAccount)) Particular,dbo.[fnRPT_GLParticular](0,D.DocID,AD.CreditAccount,AD.DebitAccount) ParticularID'
	
	END
	
	IF @IsDetailAcc=1
	BEGIN
		SET @DetailSQL='D.AccDocDetailsID,D.DocSeqNo,'
		SET @ParticularCrAcc='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.CreditAccount) Particular,D.CreditAccount ParticularID'
		SET @ParticularDrAcc='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.DebitAccount) Particular,D.DebitAccount ParticularID'
		
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
			
		SET @ParticularCrAcc='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID)) Particular,(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) ParticularID'
		SET @ParticularDrAcc='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID)) Particular,(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) ParticularID'
		
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

--Two Queries For Cr,Dr For Accounting Vouchers Joins With Location
--Two Queries For Cr,Dr For Inventory Vouchers Joins With Location
SET @SQL='SELECT '+@DetailSQL+'A1.AccountName,DebitAccount AccountID'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate'+@SortDateBy+', D.VoucherNo, D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularCrAccJV+',D.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount
LEFT JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=DebitAccount
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=CreditAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>='+@From+' AND D.DocDate<='+@To+' '+@CntrlAccWhere+@LocationWHERE+@UnAppSQL+@CurrWHERE1+@IntermediatePDC+'
UNION ALL
SELECT '+@DetailSQL+'A1.AccountName,CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate'+@SortDateBy+', D.VoucherNo,D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularDrAccJV+',NULL DebitAmount,D.'+@AmtColumn+' CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount
LEFT JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=CreditAccount
LEFT JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=DebitAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>='+@From+' AND D.DocDate<='+@To+' '+@CntrlAccWhere+@LocationWHERE+@UnAppSQL+@CurrWHERE1+@IntermediatePDC+'
UNION ALL
SELECT '+@InvDetailDr+'A1.AccountName,AD.DebitAccount'+@DimColumn+',CONVERT(DATETIME,AD.DocDate) DocDate'+@SortDateBy+', AD.VoucherNo, D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularCr+',AD.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,AD.ChequeNumber,CONVERT(DATETIME,AD.ChequeDate) ChequeDate,CONVERT(DATETIME,AD.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@INV_SELECT+'
FROM ACC_DocDetails AD with(nolock) join '+@TblAccName+' AL on AL.AccountID=AD.DebitAccount
INNER JOIN INV_DocDetails D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=AD.DebitAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+replace(@FROMQUERY,'AccDocDetailsID','InvDocDetailsID')+'
WHERE AD.DocDate>='+@From+' AND AD.DocDate<='+@To+' '+@CntrlAccWhere+@LocationWHERE+@UnAppSQL+@CurrWHERE2+'
UNION ALL
SELECT '+@InvDetailCr+'A1.AccountName,AD.CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.DocDate) DocDate'+@SortDateBy+', D.VoucherNo,D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularDr+',NULL DebitAmount,AD.'+@AmtColumn+' CreditAmount,0.0 Balance,AD.ChequeNumber,CONVERT(DATETIME,AD.ChequeDate) ChequeDate,CONVERT(DATETIME,AD.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@INV_SELECT+'
FROM ACC_DocDetails AD with(nolock) join '+@TblAccName+' AL on AL.AccountID=AD.CreditAccount
INNER JOIN INV_DocDetails D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=AD.CreditAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+replace(@FROMQUERY,'AccDocDetailsID','InvDocDetailsID')+'
WHERE AD.DocDate>='+@From+' AND AD.DocDate<='+@To+' '+@CntrlAccWhere+@LocationWHERE+@UnAppSQL+@CurrWHERE2

IF @IncludePDC=1
BEGIN
	SET @Temp='(D.StatusID=370 OR D.StatusID=439'
	IF @IncludeUnApprovedPDC=1
		SET @Temp=@Temp+' OR D.StatusID=371 OR D.StatusID=441'
	IF @IncludeTerminatedPDC=1
		SET @Temp=@Temp+' OR D.StatusID=452'
	if @ReportByPDCConvDate=1
		SET @Temp=@Temp+' or ((D.StatusID=369 or D.StatusID=429) and D.ConvertedDate>'+@To+')'
	SET @Temp=@Temp+')'
		
	declare @LineWisePDC nvarchar(max)
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
		
	SET @PDCSQL='SELECT '+@DetailSQL+'A1.AccountName,DebitAccount AccountID'+@DimColumn+',CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate'+@SortDateBy+', D.VoucherNo,D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularCrAcc+',D.'+@AmtColumn+' DebitAmount,NULL CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,D.StatusID StatusID'+@SELECTQUERY+'
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=DebitAccount
	INNER JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=CreditAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE '+@Temp+' AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'<='+@To+' '+@CntrlAccWhere+@LocationWHERE+@CurrWHERE1+@LineWisePDC+'
	UNION ALL
	SELECT '+@DetailSQL+'A1.AccountName,CreditAccount'+@DimColumn+',CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate'+@SortDateBy+',D.VoucherNo,D.BillNo,CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularDrAcc+',NULL DebitAmount,D.'+@AmtColumn+' CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,D.StatusID StatusID'+@SELECTQUERY+'
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=CreditAccount
	INNER JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=DebitAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE '+@Temp+' AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'<='+@To+' '+@CntrlAccWhere+@LocationWHERE+@CurrWHERE1+@LineWisePDC
	
END

IF @IncludePDC=1 AND @PDCSeperate=0
BEGIN
	SET @SQL=@SQL+N' union all '+@PDCSQL
END

declare @SortOrder NVARCHAR(MAX)
set @SortOrder=''
if @SortDateBy!=''
begin
	set @SortDateBy=',Max(SortDate) SortDate'
	set @SortOrder=',SortDate'
end

--For Details Report Add AccDocDetailsID In GROUP BY CLAUSE	
IF @IsDetailInv=1 OR @IsDetailAcc=1
BEGIN
	SET @SQL='SELECT AccountName,AccountID'+@DimColAlias+', DocDate'+@SortDateBy+', VoucherNo, BillNo, BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate, MAX(Particular) Particular,MAX(ParticularID) ParticularID, SUM(DebitAmount) Debit, SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,MAX(T.StatusID) StatusID'+@SELECTQUERYALIAS+'
	FROM ( '+@SQL+') AS T '+@DimJoin+' Group By AccountName,AccountID'+@DimColAlias+',DocDate,DocSeqNo,AccDocDetailsID,VoucherNo,BillNo,BillDate'+@SELECTQUERYALIAS
	SET @SQL=@SQL+' order by '+@SortAccountID+@DimColAlias+',DocDate'+@SortOrder+',VoucherNo,DocSeqNo,AccDocDetailsID'
	--PRINT (@SQL)
	--SELECT @SQL
	EXEC(@SQL)

	IF @IncludePDC=1 AND @PDCSeperate=1
	BEGIN	
		SET @SQL='SELECT AccountName,AccountID'+@DimColAlias+',DocDate'+@SortDateBy+', VoucherNo, BillNo, BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate, MAX(Particular) Particular,MAX(ParticularID) ParticularID, SUM(DebitAmount) Debit, SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,VType,MAX(T.StatusID) StatusID '+@SELECTQUERYALIAS+'
	FROM ( '+@PDCSQL+') AS T '+@DimJoin+' Group By AccountName,AccountID'+@DimColAlias+',DocDate,DocSeqNo,AccDocDetailsID,VoucherNo,BillNo,BillDate,VType'+@SELECTQUERYALIAS
	SET @SQL=@SQL+' order by '+@SortAccountID+@DimColAlias+',DocDate'+@SortOrder+',VoucherNo,DocSeqNo,AccDocDetailsID,VType'
	--PRINT( @SQL)
		EXEC(@SQL)
	END
END
ELSE
BEGIN

	SET @SQL='SELECT AccountName,AccountID'+@DimColAlias+', DocDate'+@SortDateBy+', VoucherNo, MAX(BillNo) BillNo, MAX(BillDate) BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate, Particular,MAX(ParticularID) ParticularID, SUM(DebitAmount) Debit, SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,MAX(T.StatusID) StatusID'+@SELECTQUERYALIAS+'
	FROM ( '+@SQL+') AS T '+@DimJoin+' Group By AccountName,AccountID'+@DimColAlias+',DocDate,VoucherNo,BillNo,BillDate,Particular'--,ChequeNumber,ChequeDate,ChequeMaturityDate
	SET @SQL=@SQL+' order by '+@SortAccountID+@DimColAlias+',DocDate'+@SortOrder+',VoucherNo'
	--PRINT (@SQL)
	--SELECT @SQL
	EXEC(@SQL)
	

	IF @IncludePDC=1 AND @PDCSeperate=1
	BEGIN	
		SET @SQL='SELECT AccountName,AccountID'+@DimColAlias+',DocDate'+@SortDateBy+', VoucherNo, MAX(BillNo) BillNo, MAX(BillDate) BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate, Particular,MAX(ParticularID) ParticularID, SUM(DebitAmount) Debit, SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr,0.0 Balance,VType,MAX(T.StatusID) StatusID '+@SELECTQUERYALIAS+'
	FROM ( '+@PDCSQL+') AS T '+@DimJoin+' Group By AccountName,AccountID'+@DimColAlias+',DocDate,VoucherNo,BillNo,BillDate,Particular,VType'--,ChequeNumber,ChequeDate,ChequeMaturityDate
	SET @SQL=@SQL+' order by '+@SortAccountID+@DimColAlias+',DocDate'+@SortOrder+',VoucherNo,VType'
		EXEC(@SQL)
	END
END

DROP TABLE #TblAcc

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
