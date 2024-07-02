USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GeneralLedger]
	@Account [nvarchar](max),
	@IncomeExpAccounts [nvarchar](max),
	@YearStartDate [datetime] = NULL,
	@IsCtrlAcc [bit],
	@ClubTrBy [int],
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
	@TagID [int],
	@ReportType [int],
	@WHEREQUERY [nvarchar](max),
	@DateFilter [nvarchar](20) = '',
	@RoundOff [nvarchar](max) = '',
	@ShowIntPDCBank [bit],
	@NonAccDocs [nvarchar](max),
	@PDCatOPB [bit],
	@LocationWHERE [nvarchar](max),
	@IsDetailInv [bit] = 0,
	@IsDetailAcc [int] = 2,
	@CurrencyType [int],
	@CurrencyID [int],
	@JVDetail [bit],
	@SortDateBy [nvarchar](30),
	@SELECTQUERY [nvarchar](max),
	@FROMQUERY [nvarchar](max),
	@SELECTQUERYALIAS [nvarchar](max),
	@FCWithExchRate [float] = 0,
	@UpPostedDocsListOP [nvarchar](200) = NULL,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
--16 Opening Balance
--14 Postdated Payment
--19 Postdated Receipts
	DECLARE @SQL NVARCHAR(MAX),@FinalSQL NVARCHAR(MAX),@INV_SELECT NVARCHAR(MAX),@PDCSQL NVARCHAR(MAX),@Temp NVARCHAR(MAX),@AccountName NVARCHAR(200),@AccountCode NVARCHAR(200),@AccountType INT,@RoundSQL nvarchar(max)
	DECLARE	@From NVARCHAR(20),@To NVARCHAR(20),@YearStart NVARCHAR(20),@AmtColumn NVARCHAR(32),@CurrWHERE1 NVARCHAR(30),@CurrWHERE2 NVARCHAR(30),@JVParticularCr nvarchar(200),@JVParticularDr nvarchar(200)
	DECLARE @SQL1 NVARCHAR(MAX),@SQL2 NVARCHAR(MAX),@DetailSQL NVARCHAR(50),@InvDetailDr NVARCHAR(50),@InvDetailCr NVARCHAR(50),@UnAppSQL NVARCHAR(MAX),@UnAppSQLOP NVARCHAR(MAX),@TagColumn NVARCHAR(50),@TagDBColumn NVARCHAR(50),@OpDateFilter NVARCHAR(100),@ACCDateFilter NVARCHAR(100),@INVDateFilter NVARCHAR(100)
	DECLARE @ParticularCr NVARCHAR(500),@ParticularDr NVARCHAR(500),@ParticularCrAcc NVARCHAR(900),@ParticularCrAccJV NVARCHAR(1050),@ParticularDrAcc NVARCHAR(900),@ParticularDrAccJV NVARCHAR(1050),@UNION NVARCHAR(20),@IntermediatePDC NVARCHAR(max)
	DECLARE @LocalAmountDB nvarchar(100),@LocalAmount nvarchar(100),@LocalAmtJoin nvarchar(100),@TblAccName varchar(max),@CntrlAccWhere varchar(max),@SortAccountID varchar(10),@INV_FROMQUERY nvarchar(max),@ReportByPDCConvDate bit,@LineWisePDC nvarchar(max),@PDCStatWh nvarchar(max),@PDCStatWhOP nvarchar(max)
	declare @AmtCol NVARCHAR(10)
	create table #TblAcc(AccountID INT primary key,IsExpense bit default(1))
	SET @TagDBColumn=''
	SET @LocalAmountDB=''
	SET @RoundSQL=''
	SET @LocalAmtJoin=''
	SET @SQL1=''
	SET @CurrWHERE1=''
	SET @LineWisePDC=''
	
	if exists (select Value from adm_globalpreferences with(nolock) where name ='ReportByPDCConvDate' and Value='True')
		set @ReportByPDCConvDate=1
	else
		set @ReportByPDCConvDate=0
	
	if @WHEREQUERY like '%D.RefCCID=95%'
		set @UNION='UNION'
	else
		set @UNION='UNION ALL'	
		
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
		set @SortAccountID=''
	end
	else
	begin		
		set @TblAccName='#TblAcc'
		set @CntrlAccWhere=''
		set @SortAccountID='AccountID,'
		if len(@IncomeExpAccounts)>0
		begin
			insert into #TblAcc(AccountID)
			exec SPSplitString @IncomeExpAccounts,','
		end
	end
	
	if @ClubTrBy>0
	begin
		set @IsDetailAcc=0
		set @IsDetailInv=0
	end

	if @UpPostedDocsList=''
		set @UnAppSQL=' AND (D.StatusID=369 or D.StatusID=429)'
	else
		set @UnAppSQL=' AND D.StatusID IN (369,429,'+@UpPostedDocsList+')'
	
	if @UpPostedDocsListOP=''
		set @UnAppSQLOP=' AND (D.StatusID=369 or D.StatusID=429)'
	else
		set @UnAppSQLOP=' AND D.StatusID IN (369,429,'+@UpPostedDocsListOP+')'
		
	IF @LocationWHERE<>'' OR @TagID>0
	BEGIN
		SET @SQL1=' INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@LocationWHERE--D.InvDocDetailsID IS NULL AND 
		SET @SQL2=' INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@LocationWHERE
	END
	ELSE
	BEGIN
		SET @SQL1=''
		SET @SQL2=''
	END
	
	IF @TagID>0
	BEGIN
		SET @TagColumn=',TagID'
		SET @TagDBColumn=',DCC.dcCCNID'+convert(nvarchar,(@TagID-50000))+' TagID'
	END
	ELSE
	BEGIN
		SET @TagColumn=''
		SET @TagDBColumn=''
	END
	
	IF @CurrencyID>0
	BEGIN
		SET @AmtColumn='AmountFC'
		SET @CurrWHERE1=' AND D.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
		SET @CurrWHERE2=' AND AD.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
		set @SELECTQUERY=@SELECTQUERY+',CR.ExchangeRate*D.AmountFC LocalAmount'
		set @LocalAmountDB=',CR.ExchangeRate*D.AmountFC LocalAmount'
		set @LocalAmount=',isnull(sum(LocalAmount),0) LocalAmount'
		set @LocalAmtJoin=' inner join COM_Currency CR with(nolock) on CR.CurrencyID=D.CurrencyID'	
		set @FROMQUERY=@FROMQUERY+' inner join COM_Currency CR with(nolock) on CR.CurrencyID=D.CurrencyID'	
	END
	ELSE
	BEGIN
		IF @CurrencyType=1
			SET @AmtColumn='AmountBC'
		ELSE 
			SET @AmtColumn='Amount'
		SET @CurrWHERE1=''
		SET @CurrWHERE2=''
		set @LocalAmountDB=''
		set @LocalAmount=''
		set @LocalAmtJoin=''
		
		IF(@FCWithExchRate>0)
			SET @AmtColumn='Amount/'+CONVERT(NVARCHAR,@FCWithExchRate)
		
		IF @CurrencyType=-1
		BEGIN
			SET @TagColumn=@TagColumn+',CurrencyID'
			SET @TagDBColumn=@TagDBColumn+',D.CurrencyID'
			SET @AmtColumn='AmountFC'
		END
	END
	
	if @DateFilter='ChequeDate' or @DateFilter='MaturityDate'
	begin
		if @DateFilter='MaturityDate'
			set @DateFilter='ChequeMaturityDate'
		set @OpDateFilter=' AND (isnull(D.'+@DateFilter+',D.DocDate)<@From OR D.DocumentType=16)'
		set @ACCDateFilter=' AND isnull(D.'+@DateFilter+',D.DocDate) between @From AND @To'
		set @INVDateFilter=' AND isnull(AD.'+@DateFilter+',AD.DocDate) between @From AND @To'
	end
	else if @DateFilter=''
	begin
		set @OpDateFilter=' AND (D.DocDate<@From OR D.DocumentType=16)'
		set @ACCDateFilter=' AND D.DocDate>=@From AND D.DocDate<=@To'
		set @INVDateFilter=' AND AD.DocDate>=@From AND AD.DocDate<=@To'
	end
	
	set @IntermediatePDC=''
	if @ReportByPDCConvDate=1 and exists(select Value from adm_globalPreferences with(nolock) where name='IntermediatePDConConversionDate' and Value='False')
	begin		
		select @IntermediatePDC=@IntermediatePDC+convert(nvarchar,IntermediateConvertion)+',' from adm_documenttypes 
		where IntermediateConvertion>0
		group by IntermediateConvertion
		if len(@IntermediatePDC)!=''
		begin
			set @IntermediatePDC=substring(@IntermediatePDC,1,len(@IntermediatePDC)-1)
			set @IntermediatePDC=' and (D.CostCenterID not in ('+@IntermediatePDC+') or D.ConvertedDate is null or D.ConvertedDate<=@To)'
		end
	end
	
	IF @IncludePDC=1
	BEGIN
		SET @PDCStatWh=' (D.StatusID=370 OR D.StatusID=439'
		IF @IncludeUnApprovedPDC=1
			SET @PDCStatWh=@PDCStatWh+' OR D.StatusID=371 OR D.StatusID=441'
		IF @IncludeTerminatedPDC=1
			SET @PDCStatWh=@PDCStatWh+' OR D.StatusID=452'
		if @ReportByPDCConvDate=1
			SET @PDCStatWh=@PDCStatWh+' or ((D.StatusID=369 or D.StatusID=429) and D.ConvertedDate>@To)'
		if (@ReportType=3 AND @UpPostedDocsList<>'')
		BEGIN
			SET @PDCStatWhOP=@PDCStatWh+' OR D.StatusID IN ('+@UpPostedDocsListOP+')'
			SET @PDCStatWh=@PDCStatWh+' OR D.StatusID IN ('+@UpPostedDocsList+')'
		END
		ELSE
			SET @PDCStatWhOP=@PDCStatWh
		SET @PDCStatWhOP=@PDCStatWhOP+')'	
		SET @PDCStatWh=@PDCStatWh+')'
		
		set @LineWisePDC=''
		SELECT @LineWisePDC=@LineWisePDC+convert(nvarchar,CostCenterID)+',' FROM COM_DocumentPreferences with(nolock) WHERE (DocumentType=14 or DocumentType=19) and (Prefname='LineWisePDC' and Prefvalue='true')
		if(@LineWisePDC!='')
		begin
			set @LineWisePDC=substring(@LineWisePDC,1,len(@LineWisePDC)-1)
			if(charindex(',',@LineWisePDC,1)>0)
				set @LineWisePDC=' and D.CostCenterID not IN ('+@LineWisePDC+')'
			else
				set @LineWisePDC=' and D.CostCenterID!='+@LineWisePDC
			--select @LineWisePDC
		end	
	END

	/*if @WHEREQUERY like '%D.RefCCID=95%'
	begin
		SET @SQL='SELECT A.AccountName,A.AccountID,A.AccountTypeID,0 BF'+@TagColumn+'
		FROM (select 1 TagID) AS T, ACC_Accounts A with(nolock)
		join '+@TblAccName+' AL on AL.AccountID=A.AccountID
		GROUP BY A.AccountName,A.AccountID,A.AccountTypeID'+@TagColumn
	end
	else*/
	begin
		if @RoundOff!=''
			set @RoundSQL=',D.VoucherNo'
		else
			set @RoundSQL=''
		SET @SQL=''

		IF LEN(@Account)>0
		BEGIN
			SET @SQL='SELECT '+(case when @IsCtrlAcc=0 then 'D.DebitAccount' else 'AL.ParentID' end)+' AccountID, D.'+@AmtColumn+' Debit,0 Credit'+@TagDBColumn+@LocalAmountDB+@RoundSQL+'
			FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount'+@SQL1+@LocalAmtJoin+'		
			WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+' and D.DocumentType<>14 AND D.DocumentType<>19'+@OpDateFilter+@UnAppSQLOP+@WHEREQUERY+@CurrWHERE1+@IntermediatePDC+'
			UNION ALL
			SELECT '+(case when @IsCtrlAcc=0 then 'D.CreditAccount' else 'AL.ParentID' end)+',0 Debit, D.'+@AmtColumn+' Credit'+@TagDBColumn+replace(@LocalAmountDB,',',',-')+@RoundSQL+'
			FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount '+@SQL1+@LocalAmtJoin+'
			WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+' and D.DocumentType<>14 AND D.DocumentType<>19'+@OpDateFilter+@UnAppSQLOP+@WHEREQUERY+@CurrWHERE1+@IntermediatePDC
			IF LEN(@SQL1)>0
			BEGIN
				SET @SQL=@SQL+' UNION ALL
			SELECT '+(case when @IsCtrlAcc=0 then 'D.DebitAccount' else 'AL.ParentID' end)+' AccountID, D.'+@AmtColumn+' Debit,0 Credit'+@TagDBColumn+@LocalAmountDB+@RoundSQL+'
			FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount '+@SQL2+@LocalAmtJoin+'		
			WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+' and D.DocumentType<>14 AND D.DocumentType<>19'+@OpDateFilter+@UnAppSQLOP+@WHEREQUERY+@CurrWHERE1+'
			UNION ALL
			SELECT '+(case when @IsCtrlAcc=0 then 'D.CreditAccount' else 'AL.ParentID' end)+',0 Debit, D.'+@AmtColumn+' Credit'+@TagDBColumn+replace(@LocalAmountDB,',',',-')+@RoundSQL+'
			FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount '+@SQL2+@LocalAmtJoin+'
			WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+' and D.DocumentType<>14 AND D.DocumentType<>19'+@OpDateFilter+@UnAppSQLOP+@WHEREQUERY+@CurrWHERE1
			END
			
			IF @PDCatOPB=1
			BEGIN
				SET @SQL=@SQL+'
UNION ALL
SELECT '+(case when @IsCtrlAcc=0 then 'D.DebitAccount' else 'AL.ParentID' end)+' AccountID, D.'+@AmtColumn+' Debit,0 Credit'+@TagDBColumn+@LocalAmountDB+@RoundSQL+'
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount'
+@SQL1+@LocalAmtJoin+'
WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+(CASE WHEN isnull(@PDCStatWhOP,'')<>'' THEN ' AND '+@PDCStatWhOP ELSE '' END)+' AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'<@From '+@LocationWHERE+@WHEREQUERY+@CurrWHERE1+@LineWisePDC+'
UNION ALL
SELECT '+(case when @IsCtrlAcc=0 then 'D.CreditAccount' else 'AL.ParentID' end)+',0 Debit, D.'+@AmtColumn+' Credit'+@TagDBColumn+replace(@LocalAmountDB,',',',-')+@RoundSQL+'
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount'+@SQL1+@LocalAmtJoin+'
WHERE '+(case when @IsCtrlAcc=0 then 'AL.IsExpense=0' else 'AL.ParentID='+@Account end)+(CASE WHEN isnull(@PDCStatWhOP,'')<>'' THEN ' AND '+@PDCStatWhOP ELSE '' END)+' AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'<@From '+@LocationWHERE+@WHEREQUERY+@CurrWHERE1+@LineWisePDC
			END
		END
		
		IF LEN(@IncomeExpAccounts)>0
		BEGIN
			IF LEN(@Account)>0
				SET @SQL=@SQL+' UNION ALL '

			--select @YearStart,@From

			SET @SQL=@SQL+' SELECT D.DebitAccount AccountID, D.'+@AmtColumn+' Debit,0 Credit'+@TagDBColumn+@LocalAmountDB+@RoundSQL+'
			FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount '+@SQL1+@LocalAmtJoin+'		
			WHERE AL.IsExpense=1 and D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate>='+@YearStart+' and (D.DocDate<@From OR (D.DocumentType=16 and D.DocDate<=@To)))'+@UnAppSQLOP+@WHEREQUERY+@CurrWHERE1+@IntermediatePDC+'
			UNION ALL
			SELECT D.CreditAccount,0 Debit, D.'+@AmtColumn+' Credit'+@TagDBColumn+replace(@LocalAmountDB,',',',-')+@RoundSQL+'
			FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount '+@SQL1+@LocalAmtJoin+'
			WHERE AL.IsExpense=1 and D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate>='+@YearStart+' and (D.DocDate<@From OR (D.DocumentType=16 and D.DocDate<=@To)))'+@UnAppSQLOP+@WHEREQUERY+@CurrWHERE1+@IntermediatePDC
			IF LEN(@SQL1)>0
			BEGIN
				SET @SQL=@SQL+' UNION ALL SELECT D.DebitAccount AccountID, D.'+@AmtColumn+' Debit,0 Credit'+@TagDBColumn+@LocalAmountDB+@RoundSQL+'
			FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount '+@SQL2+@LocalAmtJoin+'		
			WHERE AL.IsExpense=1 and D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate>='+@YearStart+' and (D.DocDate<@From OR (D.DocumentType=16 and D.DocDate<=@To)))'+@UnAppSQLOP+@WHEREQUERY+@CurrWHERE1+'
			UNION ALL
			SELECT D.CreditAccount,0 Debit, D.'+@AmtColumn+' Credit'+@TagDBColumn+replace(@LocalAmountDB,',',',-')+@RoundSQL+'
			FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount '+@SQL2+@LocalAmtJoin+'
			WHERE AL.IsExpense=1 AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate>='+@YearStart+' and (D.DocDate<@From OR (D.DocumentType=16 and D.DocDate<=@To)))'+@UnAppSQLOP+@WHEREQUERY+@CurrWHERE1
			END
			
			IF @PDCatOPB=1
			BEGIN
				SET @SQL=@SQL+'
UNION ALL
SELECT D.DebitAccount AccountID, D.'+@AmtColumn+' Debit,0 Credit'+@TagDBColumn+@LocalAmountDB+@RoundSQL+'
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount'
+@SQL1+@LocalAmtJoin+'
WHERE AL.IsExpense=1  '+(CASE WHEN isnull(@PDCStatWhOP,'')<>'' THEN ' AND '+@PDCStatWhOP ELSE '' END)+' AND (D.DocumentType=14 OR D.DocumentType=19) AND (D.'+@PDCFilterOn+'>='+@YearStart+' and D.'+@PDCFilterOn+'<@From) '+@LocationWHERE+@WHEREQUERY+@CurrWHERE1+@LineWisePDC+'
UNION ALL
SELECT D.CreditAccount,0 Debit, D.'+@AmtColumn+' Credit'+@TagDBColumn+replace(@LocalAmountDB,',',',-')+@RoundSQL+'
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount'+@SQL1+@LocalAmtJoin+'
WHERE AL.IsExpense=1  '+(CASE WHEN isnull(@PDCStatWhOP,'')<>'' THEN ' AND '+@PDCStatWhOP ELSE '' END)+' AND (D.DocumentType=14 OR D.DocumentType=19) AND (D.'+@PDCFilterOn+'>='+@YearStart+' and D.'+@PDCFilterOn+'<@From) '+@LocationWHERE+@WHEREQUERY+@CurrWHERE1+@LineWisePDC
			END
		END

		if @RoundOff!=''
		begin
			SET @SQL='SELECT AccountName,AccountID,AccountTypeID,round(SUM(BF),'+@RoundOff+') BF'+@TagColumn+@LocalAmount+'
			FROM(
			SELECT A.AccountName,A.AccountID,A.AccountTypeID,round(convert(decimal(15,5),ISNULL(SUM(Debit)-SUM(Credit),0)),'+@RoundOff+') BF'+@TagColumn+@LocalAmount+'
			FROM ('+@SQL+') AS T  RIGHT JOIN ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID
			join #TblAcc AL on AL.AccountID=A.AccountID
			GROUP BY A.AccountName,A.AccountID,A.AccountTypeID'+@TagColumn+',VoucherNo
			) AS T
			GROUP BY AccountName,AccountID,AccountTypeID'+@TagColumn
		end
		else
		begin
			SET @SQL='SELECT A.AccountName,A.AccountID,A.AccountTypeID,ISNULL(SUM(Debit)-SUM(Credit),0) BF'+@TagColumn+@LocalAmount+'
			FROM ('+@SQL+') AS T  RIGHT JOIN ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID
			join #TblAcc AL on AL.AccountID=A.AccountID
			GROUP BY A.AccountName,A.AccountID,A.AccountTypeID'+@TagColumn
		end
	end
	SET @SQL='DECLARE @FROM FLOAT='+@FROM+',@To FLOAT='+@To+' '+@SQL
	print @SQL
	EXEC sp_executesql @SQL
	
	IF @IsDetailInv=1
	BEGIN
		SET @InvDetailDr='AD.CreditAccount AccDocDetailsID,AD.DocSeqNo,'
		SET @InvDetailCr='AD.DebitAccount AccDocDetailsID,AD.DocSeqNo,'
		SET @ParticularCr='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=AD.CreditAccount) Particular,AD.CreditAccount ParticularID'
		SET @ParticularDr='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=AD.DebitAccount) Particular,AD.DebitAccount ParticularID'
	END
	ELSE
	BEGIN
		if @IsDetailAcc>0
		begin
			SET @InvDetailDr='0 AccDocDetailsID,0 DocSeqNo,'
			SET @InvDetailCr='0 AccDocDetailsID,0 DocSeqNo,'
		end
		else
		begin
			SET @InvDetailDr=''
			SET @InvDetailCr=''
		end
				
		--SET @ParticularCr='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.CreditAccount FROM INV_DocDetails I with(nolock) WHERE I.DocID=D.DocID)) Particular,(SELECT TOP 1 I.CreditAccount FROM INV_DocDetails I with(nolock) WHERE I.DocID= D.DocID) ParticularID'
		--SET @ParticularDr='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.DebitAccount FROM INV_DocDetails I with(nolock) WHERE I.DocID=D.DocID)) Particular,(SELECT TOP 1 I.DebitAccount FROM INV_DocDetails I with(nolock) WHERE I.DocID= D.DocID) ParticularID'
		SET @ParticularCr='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=dbo.[fnRPT_GLParticular](1,D.DocID,AD.DebitAccount,AD.CreditAccount)) Particular,dbo.[fnRPT_GLParticular](1,D.DocID,AD.DebitAccount,AD.CreditAccount) ParticularID'
		SET @ParticularDr='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=dbo.[fnRPT_GLParticular](0,D.DocID,AD.CreditAccount,AD.DebitAccount)) Particular,dbo.[fnRPT_GLParticular](0,D.DocID,AD.CreditAccount,AD.DebitAccount) ParticularID'

	END	
	
	IF @IsDetailAcc>0
	BEGIN
		IF @IsDetailAcc=1
			SET @DetailSQL='D.AccDocDetailsID,D.DocSeqNo,'
		ELSE
			SET @DetailSQL='0 AccDocDetailsID,0 DocSeqNo,'	
		if @ReportType=3
		begin
			SET @ParticularCrAcc='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),D.CreditAccount)
			 else D.CreditAccount end)) Particular
			,case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),D.CreditAccount) else D.CreditAccount end ParticularID'
			SET @ParticularDrAcc='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),D.DebitAccount)
			 else D.DebitAccount end)) Particular
			,case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),D.DebitAccount) else D.DebitAccount end ParticularID'
						
			set @ParticularCrAccJV='case when D.CreditAccount>0 then (SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),D.CreditAccount)
			 else D.CreditAccount end)) else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.DebitAccount,0,'+convert(nvarchar,@JVDetail)+') end Particular
,isnull(case when RefCCID=400 and D.RefNodeID>0 then (SELECT I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0) else null end,(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID=D.DocID and I.CreditAccount>0)) ParticularID'
			set @ParticularDrAccJV='case when D.DebitAccount>0 then (SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),D.DebitAccount)
			 else D.DebitAccount end)) else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.CreditAccount,1,'+convert(nvarchar,@JVDetail)+') end Particular
,isnull(case when RefCCID=400 and D.RefNodeID>0 then (SELECT I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0) else null end,(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID=D.DocID and I.DebitAccount>0)) ParticularID'
		end
		else
		begin
			SET @ParticularCrAcc='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.CreditAccount) Particular,D.CreditAccount ParticularID'
			SET @ParticularDrAcc='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.DebitAccount) Particular,D.DebitAccount ParticularID'
			set @ParticularCrAccJV='case when D.CreditAccount>0 then (SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.CreditAccount) else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.DebitAccount,0,'+convert(nvarchar,@JVDetail)+') end Particular
,case when D.CreditAccount>0 then D.CreditAccount else (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID=D.DocID and I.CreditAccount>0) end ParticularID'
			set @ParticularDrAccJV='case when D.DebitAccount>0 then (SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID=D.DebitAccount) else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.CreditAccount,1,'+convert(nvarchar,@JVDetail)+') end Particular
,case when D.DebitAccount>0 then D.DebitAccount else (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID and I.DebitAccount>0) end ParticularID'
		end
		
	END
	ELSE
	BEGIN
		IF @IsDetailInv=1
			SET @DetailSQL='0 AccDocDetailsID,0 DocSeqNo,'
		ELSE
			SET @DetailSQL=''

		if @ReportType=3
		begin
			SET @ParticularCrAcc='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID))
			 else (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) end)) Particular
			,case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID)) else (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) end ParticularID'
			SET @ParticularDrAcc='(SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID))
			 else (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) end)) Particular
			,case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID)) else (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) end ParticularID'
			
			set @ParticularCrAccJV='case when D.CreditAccount>0 then (SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID))
			 else (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) end)) else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.DebitAccount,0,'+convert(nvarchar,@JVDetail)+') end Particular
,isnull(case when RefCCID=400 and D.RefNodeID>0 then (SELECT I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0) else null end,(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID=D.DocID and I.CreditAccount>0)) ParticularID'
			set @ParticularDrAccJV='case when D.DebitAccount>0 then (SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (case when RefCCID=400 and D.RefNodeID>0 then isnull((SELECT I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0),(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID))
			 else (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) end)) else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.CreditAccount,1,'+convert(nvarchar,@JVDetail)+') end Particular
,isnull(case when RefCCID=400 and D.RefNodeID>0 then (SELECT I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.AccDocDetailsID=D.RefNodeID and I.BankAccountID>0) else null end,(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID=D.DocID and I.DebitAccount>0)) ParticularID'
		end
		else
		begin		
			SET @ParticularCrAcc='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID)) Particular,(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) ParticularID'
			SET @ParticularDrAcc='(SELECT AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID)) Particular,(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID) ParticularID'
			set @ParticularCrAccJV='case when D.CreditAccount>0 then (SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID order by IsNegative asc,AccDocDetailsID)) 
			else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.DebitAccount,0,'+convert(nvarchar,@JVDetail)+') end Particular
			,(SELECT TOP 1 I.CreditAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID and I.CreditAccount>0 order by IsNegative asc,AccDocDetailsID) ParticularID'
			set @ParticularDrAccJV='case when D.DebitAccount>0 then (SELECT TOP 1 AccountName FROM ACC_Accounts with(nolock) WHERE AccountID IN (SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID order by IsNegative asc,AccDocDetailsID)) 
			else dbo.fnRPT_GLAccCrDr(D.CostCenterID,D.DocID,D.CreditAccount,1,'+convert(nvarchar,@JVDetail)+') end Particular
			,(SELECT TOP 1 I.DebitAccount FROM ACC_DocDetails I with(nolock) WHERE I.DocID= D.DocID and I.DebitAccount>0 order by IsNegative asc,AccDocDetailsID) ParticularID'
		end
		
	END	
	
	if @ClubTrBy>0
	begin
		SET @ParticularCr=''''' Particular,0 ParticularID'
		SET @ParticularDr=''''' Particular,0 ParticularID'
		SET @ParticularCrAcc=''''' Particular,0 ParticularID'
		SET @ParticularDrAcc=''''' Particular,0 ParticularID'
		SET @ParticularCrAccJV=''''' Particular,0 ParticularID'
		SET @ParticularDrAccJV=''''' Particular,0 ParticularID'
	end

SET @INV_SELECT=replace(@SELECTQUERY,'D.ConvertedDate','NULL')
SET @INV_SELECT=replace(@INV_SELECT,'D.ClearanceDate','NULL')
SET @INV_SELECT=replace(@INV_SELECT,'D.BRS_Status','AD.BRS_Status')
SET @INV_SELECT=replace(@INV_SELECT,'D.Amount','AD.Amount')
SET @INV_SELECT=replace(@INV_SELECT,'D.ChequeBankName','NULL')
SET @INV_SELECT=replace(@INV_SELECT,'D.BankAccountID','NULL')

SET @SELECTQUERY=replace(@SELECTQUERY,'D.BankAccountID','(select AccountName from ACC_Accounts AB with(nolock) where AB.AccountID=D.BankAccountID)')
--select len(@INV_SELECT)
--SET @INV_SELECT=replace(@INV_SELECT,'(SELECT top 1 CPDC.VoucherNo FROM ACC_DocDetails CPDC with(nolock) WHERE CPDC.RefCCID=400 AND CPDC.refnodeid=D.AccDocDetailsID and CPDC.CostCenterID=(select IntermediateConvertion from ADM_DocumentTypes DT with(nolock) where dT.CostCenterID=D.CostCenterID ))','NULL')
--SET @INV_SELECT=replace(@INV_SELECT,'(SELECT top 1 CPDC.VoucherNo FROM ACC_DocDetails CPDC with(nolock) WHERE CPDC.RefCCID=400 AND CPDC.refnodeid=D.AccDocDetailsID and CPDC.CostCenterID=(select TOP 1ConvertAS from ADM_DocumentTypes DTP with(nolock) where DTP.CostCenterID=D.CostCenterID ))','NULL')
--select len(@INV_SELECT)

declare @SELECTQUERY_CR nvarchar(max),@INV_SELECT_CR nvarchar(max)
set @SELECTQUERY_CR=replace(@SELECTQUERY,'D.Amount','-D.Amount')
set @INV_SELECT_CR=replace(@INV_SELECT,'AD.Amount','-AD.Amount')
set @INV_FROMQUERY=@FROMQUERY
IF @CurrencyID>0
	SET @INV_FROMQUERY=replace(@INV_FROMQUERY,'CUR.CurrencyID=D.CurrencyID','CUR.CurrencyID=AD.CurrencyID')

--Two Queries For Cr,Dr For Accounting Vouchers Joins With Location
--Two Queries For Cr,Dr For Inventory Vouchers Joins With Location
SET @SQL='SELECT '+@DetailSQL+'A1.AccountName,DebitAccount AccountID,CONVERT(DATETIME,D.DocDate) DocDate'+@SortDateBy+', D.VoucherNo, D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularCrAccJV+',D.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@TagDBColumn+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount
LEFT JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=DebitAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19'+@CntrlAccWhere+@ACCDateFilter+' '+@WHEREQUERY+@LocationWHERE+@UnAppSQL+@CurrWHERE1+@IntermediatePDC+'
'+@UNION+'
SELECT '+@DetailSQL+'A1.AccountName,CreditAccount,CONVERT(DATETIME,D.DocDate) DocDate'+@SortDateBy+', D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularDrAccJV+',NULL DebitAmount,D.'+@AmtColumn+'  CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@TagDBColumn+@SELECTQUERY_CR+'
FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount
LEFT JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=CreditAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19'+@CntrlAccWhere+@ACCDateFilter+' '+@WHEREQUERY+@LocationWHERE+@UnAppSQL+@CurrWHERE1+@IntermediatePDC+'
'+@UNION+'
SELECT '+@InvDetailDr+'A1.AccountName,AD.DebitAccount,CONVERT(DATETIME,AD.DocDate) DocDate'+@SortDateBy+', AD.VoucherNo,AD.DocAbbr,AD.DocPrefix,CONVERT(BIGINT,AD.DocNumber) DocNumber,
 D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularCr+',AD.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,AD.ChequeNumber,CONVERT(DATETIME,AD.ChequeDate) ChequeDate,CONVERT(DATETIME,AD.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+replace(@TagDBColumn,',D.CurrencyID',',AD.CurrencyID')+@INV_SELECT+'
FROM ACC_DocDetails AD with(nolock) join '+@TblAccName+' AL on AL.AccountID=AD.DebitAccount
INNER JOIN INV_DocDetails D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=AD.DebitAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+replace(@INV_FROMQUERY,'AccDocDetailsID','InvDocDetailsID')+'
WHERE AD.DocumentType<>16 AND AD.DocumentType<>14 AND AD.DocumentType<>19'+@CntrlAccWhere+@INVDateFilter+' '+@WHEREQUERY+@LocationWHERE+@UnAppSQL+@CurrWHERE2+'
'+@UNION+'
SELECT '+@InvDetailCr+'A1.AccountName,AD.CreditAccount,CONVERT(DATETIME,D.DocDate) DocDate'+@SortDateBy+', D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber
,D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularDr+',NULL DebitAmount,AD.'+@AmtColumn+' CreditAmount,0.0 Balance,AD.ChequeNumber,CONVERT(DATETIME,AD.ChequeDate) ChequeDate,CONVERT(DATETIME,AD.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+replace(@TagDBColumn,',D.CurrencyID',',AD.CurrencyID')+@INV_SELECT_CR+'
FROM ACC_DocDetails AD with(nolock) join '+@TblAccName+' AL on AL.AccountID=AD.CreditAccount
INNER JOIN INV_DocDetails D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=AD.CreditAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+replace(@INV_FROMQUERY,'AccDocDetailsID','InvDocDetailsID')+'
WHERE AD.DocumentType<>16 AND AD.DocumentType<>14 AND AD.DocumentType<>19'+@CntrlAccWhere+@INVDateFilter+' '+@WHEREQUERY+@LocationWHERE+@UnAppSQL+@CurrWHERE2

if @WHEREQUERY like '%D.RefCCID=95%'
begin
	SET @Temp='
	SELECT '+@DetailSQL+'A1.AccountName,D.DebitAccount,CONVERT(DATETIME,D.DocDate) DocDate'+@SortDateBy+', D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
	D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularCrAcc+',D.'+@AmtColumn+' DebitAmount,NULL CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@TagDBColumn+@SELECTQUERY+'
FROM ACC_DocDetails D with(nolock)
inner join (SELECT D.AccDocDetailsID,D.VoucherNo,D.CreditAccount DrAccountID
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=DebitAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE D.StatusID=369 AND D.BankAccountID>0 AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'<=@To '+@WHEREQUERY+@LocationWHERE+@CurrWHERE1
+') T on D.RefNodeID=t.AccDocDetailsID and D.RefCCID=400 --and D.DebitAccount=t.DrAccountID
LEFT JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=DebitAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<=@To '+@LocationWHERE+@UnAppSQL+@CurrWHERE1
	SET @SQL=@SQL+' '+@UNION+' '+@Temp
	--print(@Temp)	
	--exec(@Temp)

	SET @Temp='
	SELECT '+@DetailSQL+'A1.AccountName,D.CreditAccount,CONVERT(DATETIME,D.DocDate) DocDate'+@SortDateBy+', D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
	D.BillNo,  CONVERT(DATETIME, D.BillDate) BillDate,
'+@ParticularDrAcc+',NULL DebitAmount,D.'+@AmtColumn+'  CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,0 VType,D.StatusID'+@TagDBColumn+@SELECTQUERY_CR+'
FROM ACC_DocDetails D with(nolock)
inner join (SELECT D.AccDocDetailsID,D.VoucherNo,D.CreditAccount CrAccountID
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=CreditAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE D.StatusID=369 AND D.BankAccountID>0 AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'<=@To '+@WHEREQUERY+@LocationWHERE+@CurrWHERE1
+') T on D.RefNodeID=t.AccDocDetailsID and D.RefCCID=400 --and D.creditaccount=t.CrAccountID
LEFT JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=CreditAccount
INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
WHERE D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<=@To '+@LocationWHERE+@UnAppSQL+@CurrWHERE1
	SET @SQL=@SQL+' '+@UNION+' '+@Temp
	--print(@Temp)
	--exec(@Temp)
end

IF @IncludePDC=1
BEGIN
	if @PDCatOPB=1
		set @PDCStatWh=@PDCStatWh+' AND D.'+@PDCFilterOn+'>='+@From
	SET @PDCSQL='SELECT '+@DetailSQL+'A1.AccountName,DebitAccount AccountID,CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate'+@SortDateBy+', D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
	D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularCrAcc+',D.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,D.StatusID StatusID'+@TagDBColumn+@SELECTQUERY+'
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=DebitAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE '+@PDCStatWh+' AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'>=@From AND D.'+@PDCFilterOn+'<=@To '+@CntrlAccWhere+@WHEREQUERY+@LocationWHERE+@CurrWHERE1+@LineWisePDC+'
	UNION ALL
	SELECT '+@DetailSQL+'A1.AccountName,CreditAccount,CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate'+@SortDateBy+',D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
	D.BillNo,CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularDrAcc+',NULL DebitAmount,D.'+@AmtColumn+' CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,D.StatusID StatusID'+@TagDBColumn+@SELECTQUERY_CR+'
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=CreditAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE '+@PDCStatWh+' AND (D.DocumentType=14 OR D.DocumentType=19) AND D.'+@PDCFilterOn+'>=@From AND D.'+@PDCFilterOn+'<=@To '+@CntrlAccWhere+@WHEREQUERY+@LocationWHERE+@CurrWHERE1+@LineWisePDC
	
	
	if @ShowIntPDCBank=1
	begin
		SET @PDCSQL=@PDCSQL+'
UNION ALL
	SELECT '+@DetailSQL+'A1.AccountName,BankAccountID AccountID,CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate'+@SortDateBy+', D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
	D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularCrAcc+',D.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,-1 StatusID'+@TagDBColumn+@SELECTQUERY+'
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.BankAccountID
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=BankAccountID
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE '+@PDCStatWh+' AND D.DocumentType=19 AND isnull(D.'+@PDCSortOn+',D.DocDate)<=@To '+@CntrlAccWhere+@WHEREQUERY+@LocationWHERE+@CurrWHERE1+'
	UNION ALL
	SELECT '+@DetailSQL+'A1.AccountName,BankAccountID,CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate'+@SortDateBy+',D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
	D.BillNo,CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularDrAcc+',NULL DebitAmount,D.'+@AmtColumn+' CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,-1 StatusID'+@TagDBColumn+@SELECTQUERY_CR+'
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.BankAccountID
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=BankAccountID
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE '+@PDCStatWh+' AND D.DocumentType=14 AND isnull(D.'+@PDCSortOn+',D.DocDate)<=@To '+@CntrlAccWhere+@WHEREQUERY+@LocationWHERE+@CurrWHERE1
		/*SET @PDCSQL=@PDCSQL+'
UNION ALL
	SELECT '+@DetailSQL+'A1.AccountName,DebitAccount AccountID,CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate'+@SortDateBy+', D.VoucherNo,D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularCrAcc+',D.'+@AmtColumn+' DebitAmount,NULL  CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,-2 StatusID'+@TagDBColumn+@SELECTQUERY+'
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=DebitAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE D.StatusID=448 AND isnull(D.ChequeMaturityDate,D.DocDate)<=@To '+@CntrlAccWhere+@WHEREQUERY+@LocationWHERE+@CurrWHERE1+'
	UNION ALL
	SELECT '+@DetailSQL+'A1.AccountName,CreditAccount,CONVERT(DATETIME,D.'+@PDCSortOn+') DocDate'+@SortDateBy+',D.VoucherNo,D.BillNo,CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularDrAcc+',NULL DebitAmount,D.'+@AmtColumn+' CreditAmount,0.0 Balance,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.DocumentType VType,-2 StatusID'+@TagDBColumn+@SELECTQUERY_CR+'
	FROM ACC_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=CreditAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID '+@FROMQUERY+'
	WHERE D.StatusID=448 AND isnull(D.ChequeMaturityDate,D.DocDate)<=@To '+@CntrlAccWhere+@WHEREQUERY+@LocationWHERE+@CurrWHERE1
	end*/
	
	if @NonAccDocs!=''
		SET @PDCSQL=@PDCSQL+'
UNION ALL
	SELECT '+@DetailSQL+'A1.AccountName,DebitAccount AccountID,CONVERT(DATETIME,isnull(D.DueDate,D.DocDate)) DocDate'+@SortDateBy+', D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
	D.BillNo, CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularCrAcc+',D.Gross DebitAmount,NULL  CreditAmount,0.0 Balance,null ChequeNumber,null  ChequeDate,CONVERT(DATETIME,D.DueDate) ChequeMaturityDate,19 VType,-2 StatusID'+@TagDBColumn+@SELECTQUERY+'
	FROM INV_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.DebitAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=DebitAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
	WHERE D.CostCenterID in ('+@NonAccDocs+') AND isnull(D.DueDate,D.DocDate)<=@To '+@CntrlAccWhere+@WHEREQUERY+@LocationWHERE+@CurrWHERE1+'
	UNION ALL
	SELECT '+@DetailSQL+'A1.AccountName,CreditAccount,CONVERT(DATETIME,isnull(D.DueDate,D.DocDate)) DocDate'+@SortDateBy+',D.VoucherNo,D.DocAbbr,D.DocPrefix,CONVERT(BIGINT,D.DocNumber) DocNumber,
	D.BillNo,CONVERT(DATETIME, D.BillDate) BillDate,
	'+@ParticularDrAcc+',NULL DebitAmount,D.Gross CreditAmount,0.0 Balance,null ChequeNumber,null  ChequeDate,CONVERT(DATETIME,D.DueDate) ChequeMaturityDate,14 VType,-2 StatusID'+@TagDBColumn+@SELECTQUERY_CR+'
	FROM INV_DocDetails D with(nolock) join '+@TblAccName+' AL on AL.AccountID=D.CreditAccount
	INNER JOIN ACC_Accounts A1 with(nolock) ON A1.AccountID=CreditAccount
	INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID '+@FROMQUERY+'
	WHERE D.CostCenterID in ('+@NonAccDocs+') AND isnull(D.DueDate,D.DocDate)<=@To '+@CntrlAccWhere+@WHEREQUERY+@LocationWHERE+@CurrWHERE1
	end
	

--AND D.'+@PDCFilterOn+'>=@From 	
END

--select @SQL
--print(@PDCSQL)
 --print (@SQL)
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

if @RoundOff!=''
	set @RoundSQL=',round(SUM(convert(decimal(18,5),DebitAmount)),'+@RoundOff+') Debit,round(SUM(convert(decimal(18,5),CreditAmount)),'+@RoundOff+') Credit,round(ISNULL(SUM(convert(decimal(18,5),DebitAmount)),0)-ISNULL(SUM(convert(decimal(18,5),CreditAmount)),0),'+@RoundOff+') DiffDrCr'
else
	set @RoundSQL=',SUM(DebitAmount) Debit,SUM(CreditAmount) Credit,ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) DiffDrCr'

	IF @JVDetail=0
	BEGIN
		SET @ParticularCr='A2.AccountName'
		SET @ParticularDr='INNER JOIN ACC_Accounts A2 with(nolock) ON A2.AccountID=T.ParticularID'
	END	
	ELSE
	BEGIN
		SET @ParticularCr='T.Particular'
		SET @ParticularDr=''
	END
	
	
--For Details Report Add AccDocDetailsID In GROUP BY CLAUSE	
IF @IsDetailInv=1 OR @IsDetailAcc>0
BEGIN
	SET @SQL='SELECT T.AccountName,T.AccountID, DocDate'+@SortDateBy+', VoucherNo,MAX(DocAbbr) DocAbbr,MAX(DocPrefix) DocPrefix,MAX(DocNumber) DocNumber,DocSeqNo, BillNo, BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate,CASE WHEN T.AccountName=MAX('+@ParticularCr+') THEN MIN('+@ParticularCr+') ELSE MAX('+@ParticularCr+') END Particular,MAX(ParticularID) ParticularID'+@RoundSQL+',0.0 Balance,MAX(T.StatusID) StatusID'+@TagColumn+@LocalAmount+@SELECTQUERYALIAS+'
	FROM ('+@SQL+') AS T '+@ParticularDr+' Group By T.AccountName,T.AccountID,DocDate'
	IF @IsDetailAcc=2
		SET @SQL=@SQL+',DocSeqNo,AccDocDetailsID,ParticularID'
	ELSE
		SET @SQL=@SQL+',DocSeqNo,AccDocDetailsID'
	SET @SQL=@SQL+',VoucherNo,BillNo,BillDate'+@TagColumn+@SELECTQUERYALIAS
	SET @SQL=@SQL+' order by '+@SortAccountID+'DocDate'+@SortOrder+',DocSeqNo,AccDocDetailsID,DocAbbr,DocPrefix,DocNumber'
	
	SET @SQL='DECLARE @FROM FLOAT='+@FROM+',@To FLOAT='+@To+' '+@SQL
	PRINT (substring(@SQL,1,4000))
	PRINT (substring(@SQL,4001,4000))
	PRINT (substring(@SQL,8001,4000))
	PRINT (substring(@SQL,12001,4000))
	PRINT (substring(@SQL,16001,4000))

	EXEC sp_executesql @SQL

	IF @IncludePDC=1 AND @PDCSeperate=1
	BEGIN	
		SET @SQL='SELECT T.AccountName,T.AccountID,DocDate'+@SortDateBy+', VoucherNo,MAX(DocAbbr) DocAbbr,MAX(DocPrefix) DocPrefix,MAX(DocNumber) DocNumber,DocSeqNo, BillNo, BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate,CASE WHEN T.AccountName=MAX('+@ParticularCr+') THEN MIN('+@ParticularCr+') ELSE MAX('+@ParticularCr+') END Particular,MAX(ParticularID) ParticularID'+@RoundSQL+',0.0 Balance,VType,MAX(T.StatusID) StatusID '+@TagColumn+@LocalAmount+@SELECTQUERYALIAS+'
	FROM ( '+@PDCSQL+') AS T '+@ParticularDr+' Group By T.AccountName,T.AccountID,DocDate,DocSeqNo,AccDocDetailsID,VoucherNo,BillNo,BillDate,VType'+@TagColumn+@SELECTQUERYALIAS	
		SET @SQL=@SQL+' order by '+@SortAccountID+'DocDate'+@SortOrder+',DocAbbr,DocSeqNo,AccDocDetailsID,VType,DocPrefix,DocNumber'
		SET @SQL='DECLARE @FROM FLOAT='+@FROM+',@To FLOAT='+@To+' '+@SQL
	--PRINT( @SQL)
		EXEC sp_executesql @SQL
	END
END
ELSE
BEGIN
	declare @DocDate nvarchar(max)
	set @FinalSQL=''
	set @DocDate=',DocDate'
	if @ClubTrBy>0
	begin
		if @ClubTrBy=2
			set @DocDate=',dateadd(day,1-day(DocDate),DocDate) DocDate'
		set @FinalSQL='select  AccountName,AccountID,DocDate,sum(Debit) Debit,sum(Credit) Credit,sum(DiffDrCr) DiffDrCr,0.0 Balance,'''' Particular,0 ParticularID,369 StatusID'+@TagColumn+@LocalAmount+'
from('
		set @SELECTQUERYALIAS=''
	end
	
	SET @FinalSQL=@FinalSQL+'SELECT T.AccountName,T.AccountID'+@DocDate+@SortDateBy+', VoucherNo,MAX(DocAbbr) DocAbbr,MAX(DocPrefix) DocPrefix,MAX(DocNumber) DocNumber, MAX(BillNo) BillNo, MAX(BillDate) BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate,CASE WHEN T.AccountName=MAX('+@ParticularCr+') THEN MIN('+@ParticularCr+') ELSE MAX('+@ParticularCr+') END Particular	
	,MAX(ParticularID) ParticularID'+@RoundSQL+',0.0 Balance,MAX(T.StatusID) StatusID'+@TagColumn+@LocalAmount+@SELECTQUERYALIAS+'
	FROM ( '+@SQL+') AS T '+@ParticularDr+' Group By T.AccountName,T.AccountID,DocDate,VoucherNo'+@TagColumn
	
	if @ClubTrBy>0
	begin
		set @FinalSQL=@FinalSQL+') AS T group by AccountName,AccountID,DocDate'+@TagColumn
		SET @FinalSQL=@FinalSQL+' order by '+@SortAccountID+'DocDate'+@SortOrder
	end
	else
	begin
		SET @FinalSQL=@FinalSQL+' order by '+@SortAccountID+'DocDate'+@SortOrder+',VoucherNo'
	end
	SET @FinalSQL='DECLARE @FROM FLOAT='+@FROM+',@To FLOAT='+@To+' '+@FinalSQL
	print(substring(@FinalSQL,1,4000))
	print(substring(@FinalSQL,4001,4000))
	print(substring(@FinalSQL,8001,4000))
	print(substring(@FinalSQL,12001,4000))
	--SELECT @SQL
	EXEC sp_executesql @FinalSQL
	--,BillNo,BillDate,ChequeNumber,ChequeDate

	IF @IncludePDC=1 AND @PDCSeperate=1
	BEGIN
		set @FinalSQL=''
		if @ClubTrBy>0
		begin
			if @ClubTrBy=2
				set @DocDate=',dateadd(day,1-day(DocDate),DocDate) DocDate'
			set @FinalSQL='select  AccountName,AccountID,DocDate,sum(Debit) Debit,sum(Credit) Credit,sum(DiffDrCr) DiffDrCr,0.0 Balance,'''' Particular,0 ParticularID,370 StatusID'+@TagColumn+@LocalAmount+'
from('
		end
		
		SET @FinalSQL=@FinalSQL+'SELECT T.AccountName,T.AccountID'+@DocDate+@SortDateBy+', VoucherNo,MAX(DocAbbr) DocAbbr,MAX(DocPrefix) DocPrefix,MAX(DocNumber) DocNumber, MAX(BillNo) BillNo, MAX(BillDate) BillDate,MAX(ChequeNumber) ChequeNumber,MAX(ChequeDate) ChequeDate,MAX(ChequeMaturityDate) ChequeMaturityDate,CASE WHEN T.AccountName=MAX('+@ParticularCr+') THEN MIN('+@ParticularCr+') ELSE MAX('+@ParticularCr+') END Particular,MAX(ParticularID) ParticularID'+@RoundSQL+',0.0 Balance,VType,MAX(T.StatusID) StatusID '+@TagColumn+@LocalAmount+@SELECTQUERYALIAS+'
	FROM ( '+@PDCSQL+') AS T '+@ParticularDr+' Group By T.AccountName,T.AccountID,DocDate,VoucherNo,VType'+@TagColumn	
		SET @FinalSQL=@FinalSQL
		if @ClubTrBy>0
		begin
			set @FinalSQL=@FinalSQL+') AS T group by AccountName,AccountID,DocDate'+@TagColumn
			SET @FinalSQL=@FinalSQL+' order by '+@SortAccountID+'DocDate'+@SortOrder
		end
		else
		begin
			SET @FinalSQL=@FinalSQL+' order by '+@SortAccountID+'DocDate'+@SortOrder+',VoucherNo,VType'
		end
		--print @PDCSQL
		SET @FinalSQL='DECLARE @FROM FLOAT='+@FROM+',@To FLOAT='+@To+' '+@FinalSQL
			print(substring(@FinalSQL,1,4000))
			print(substring(@FinalSQL,4001,4000))
			print(substring(@FinalSQL,8001,4000))
			print(substring(@FinalSQL,12001,4000))
		EXEC sp_executesql @FinalSQL
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
