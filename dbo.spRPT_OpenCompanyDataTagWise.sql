USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_OpenCompanyDataTagWise]
	@ReportType [int],
	@FromDate [datetime],
	@ToDate [datetime],
	@TagID [int],
	@LocationWHERE [nvarchar](max) = NULL,
	@GetAllIncomeExpBalance [bit] = 1,
	@UnapprovedDocs [nvarchar](200),
	@IncludePDC [bit] = 0,
	@IncludeTerminatedPDC [bit] = 1,
	@YearXML [nvarchar](max),
	@CurrencyType [int],
	@CurrencyID [int],
	@ExchRate [float],
	@UserID [bigint],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@TempFromDate FLOAT,@ACCJOIN NVARCHAR(MAX),@INVJOIN NVARCHAR(MAX),@AmtColumn NVARCHAR(20),@CurrWHERE NVARCHAR(30),@Tag1 nvarchar(30),@Tag2 nvarchar(30),@Tag3 nvarchar(30)
	CREATE TABLE #TblAcc(AccountID BIGINT,FromDate FLOAT,ToDate FLOAT)
	CREATE TABLE #TblYearBalance(Mn NVARCHAR(20),AccountID BIGINT,Dr FLOAT,Cr FLOAT)
	CREATE TABLE #TblDates(ID INT IDENTITY(1,1),Mn NVARCHAR(10),StartDate FLOAT)
	
	IF @CurrencyID>0
	BEGIN
		SET @AmtColumn='AmountFC'
		SET @CurrWHERE=' AND ACC.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
	END
	ELSE
	BEGIN
		IF @CurrencyType=1
			SET @AmtColumn='AmountBC'
		ELSE
			SET @AmtColumn='Amount'
		SET @CurrWHERE=''
		
		IF @ExchRate>1
		BEGIN
			SET @AmtColumn='Amount/'+convert(nvarchar,@ExchRate)
		END		
	END
	
	set @Tag1=''
	set @Tag2=''
	set @Tag3=''
	if @TagID>50000
	begin
		set @Tag1=',DCC.dcCCNID'+convert(nvarchar,(@TagID-50000))
		set @Tag2=',DCC.dcCCNID'+convert(nvarchar,(@TagID-50000))+' TagID'
		set @Tag3=',TagID'
	end
	
	
	DECLARE @UnAppSQL nvarchar(max),@PDCWhere nvarchar(max),@AccountTypeFilter nvarchar(100)
	
	if @ReportType=7
		set @AccountTypeFilter='1,2,3,6,7,10,13,14,15,16'
	else
		set @AccountTypeFilter='4,5,8,9,11,12'
	
	if @UnapprovedDocs=''
		set @UnAppSQL=' AND (ACC.StatusID=369 or ACC.StatusID=429)'
	else
		set @UnAppSQL=' AND ACC.StatusID IN (369,429,'+@UnapprovedDocs+')'

	if @IncludePDC=1
	begin
		declare @Temp nvarchar(200)
		SET @Temp='(ACC.StatusID=370 OR ACC.StatusID=439'
		IF @IncludeTerminatedPDC=1
			SET @Temp=@Temp+' OR ACC.StatusID=452'
		SET @Temp=@Temp+')'
		set @PDCWhere=' AND ACC.DocumentType<>16 AND ('+@Temp+' OR (ACC.DocumentType<>14 AND ACC.DocumentType<>19'+@UnAppSQL+ '))'
	end
	else
		set @PDCWhere=' AND ACC.DocumentType NOT IN (16,14,19)'+@UnAppSQL;
		

	SET @TempFromDate=CONVERT(FLOAT,@FromDate)

	if (@Tag1!='' or (@LocationWHERE IS NOT NULL AND @LocationWHERE!=''))
	begin
		set @ACCJOIN=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=ACC.AccDocDetailsID ' + @LocationWHERE
		set @INVJOIN=' INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=ACC.InvDocDetailsID ' + @LocationWHERE
	end
	else
	begin
		set @ACCJOIN=''
		set @INVJOIN=''
	end
	
	SET @SQL='	SELECT Y.AccountID AccountID'+@Tag2+',ISNULL(sum(ACC.'+@AmtColumn+'),0) Dr, 0 Cr
			FROM ACC_DocDetails ACC WITH(NOLOCK)'+@ACCJOIN+'
			INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.DebitAccount AND A.AccountTypeID IN ('+@AccountTypeFilter+'),
			#TblAcc Y 
			WHERE (ACC.DocDate BETWEEN Y.FromDate AND Y.ToDate)'+@PDCWhere+@CurrWHERE+'
			GROUP BY Y.AccountID'+@Tag1+'
			UNION ALL
			SELECT Y.AccountID AccountID'+@Tag2+',0 Dr,ISNULL(sum(ACC.'+@AmtColumn+'),0) Cr
			FROM ACC_DocDetails ACC WITH(NOLOCK)'+@ACCJOIN+'
			INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.CreditAccount AND A.AccountTypeID IN ('+@AccountTypeFilter+'),
			#TblAcc Y 
			WHERE (ACC.DocDate BETWEEN Y.FromDate AND Y.ToDate)'+@PDCWhere+@CurrWHERE+'
			GROUP BY Y.AccountID'+@Tag1+'
		'	
		IF @ACCJOIN!=''
		BEGIN
			SET @SQL=@SQL+'
			--Inventory Data
				UNION ALL
				SELECT Y.AccountID AccountID'+@Tag2+',ISNULL(sum(ACC.'+@AmtColumn+'),0) Dr, 0 Cr
				FROM ACC_DocDetails ACC WITH(NOLOCK)'+@INVJOIN+'			
				INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.DebitAccount AND A.AccountTypeID IN ('+@AccountTypeFilter+'),
				#TblAcc Y 
				WHERE (ACC.DocDate BETWEEN Y.FromDate AND Y.ToDate)'+@PDCWhere+@CurrWHERE+'
				GROUP BY Y.AccountID'+@Tag1+'
				UNION ALL
				SELECT Y.AccountID AccountID'+@Tag2+',0 Dr,ISNULL(sum(ACC.'+@AmtColumn+'),0) Cr
				FROM ACC_DocDetails ACC WITH(NOLOCK)'+@INVJOIN+'
				INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.CreditAccount AND A.AccountTypeID IN ('+@AccountTypeFilter+'),
				#TblAcc Y 
				WHERE (ACC.DocDate BETWEEN Y.FromDate AND Y.ToDate)'+@PDCWhere+@CurrWHERE+'
				GROUP BY Y.AccountID'+@Tag1
		END

		SET @SQL='SELECT AccountID'+@Tag3+',SUM(Dr) Dr,SUM(Cr) Cr FROM (
		'+@SQL+'
	) AS T
	GROUP BY AccountID'+@Tag3
	
	if @YearXML!=''
	BEGIN
		DECLARE @XML xml,@I INT,@CNT INT,@TempYearFromDate FLOAT,@ColID NVARCHAR(20)
		SET @XML=@YearXML
		INSERT INTO #TblDates
		SELECT X.value('@ID','NVARCHAR(20)'),convert(float,X.value('@EndDate','DATETIME')) 		
		FROM @XML.nodes('XML/Row') as Data(X)  
	
	--	select * from #TblDates
		select @I=1,@CNT=COUNT(*) from #TblDates
		while(@I<=@CNT)
		begin
			SELECT @ColID=Mn,@TempYearFromDate=StartDate FROM #TblDates WHERE ID=@I
			
			TRUNCATE TABLE #TblAcc
			
			if @ReportType=7
			begin
				INSERT INTO #TblAcc
				SELECT AccountID,FromDate,ToDate FROM ADM_FinancialYears WITH(NOLOCK) 
				WHERE FromDate<=@TempYearFromDate
			end
			else
			begin
				INSERT INTO #TblAcc
				SELECT AccountID,FromDate,ToDate FROM ADM_FinancialYears WITH(NOLOCK) 
				WHERE FromDate<@TempYearFromDate
				
				UPDATE #TblAcc SET ToDate=@TempYearFromDate-1
				WHERE ToDate>=@TempYearFromDate
			
				UPDATE #TblAcc SET ToDate=@TempYearFromDate-1
				WHERE ToDate>=@TempYearFromDate
			end
			
			SET @I=@I+1
			INSERT INTO #TblYearBalance(AccountID,Dr,Cr)
			EXEC(@SQL)
			print(@SQL)
			
			UPDATE #TblYearBalance
			SET Mn=@ColID
			WHERE Mn IS NULL
		end
		
		SELECT * FROM #TblYearBalance
		
		--Refreshing Year Slots
		TRUNCATE TABLE #TblAcc
		SET @TempFromDate=CONVERT(FLOAT,@FromDate)
		
		INSERT INTO #TblAcc
		SELECT AccountID,FromDate,ToDate
		FROM ADM_FinancialYears WITH(NOLOCK) 
		WHERE FromDate<@TempFromDate
		
		UPDATE #TblAcc
		SET ToDate=@TempFromDate-1
		WHERE ToDate>=@TempFromDate
	END
	ELSE
	BEGIN
		if @ReportType=7
		begin
			INSERT INTO #TblAcc
			SELECT AccountID,FromDate,ToDate FROM ADM_FinancialYears WITH(NOLOCK) 
			WHERE FromDate<=@ToDate
			
			UPDATE #TblAcc	SET ToDate=CONVERT(FLOAT,@ToDate)--CONVERT(FLOAT,@ToDate)-1 removed for BS error of THARAWAT	
			WHERE ToDate>=CONVERT(FLOAT,@ToDate)
		end
		else
		begin
			INSERT INTO #TblAcc
			SELECT AccountID,FromDate,ToDate FROM ADM_FinancialYears WITH(NOLOCK) 
			WHERE FromDate<@TempFromDate
			
			UPDATE #TblAcc	SET ToDate=@TempFromDate-1
			WHERE ToDate>=@TempFromDate
		end
		
		--Check For User-Wise Accounts
		if @UserID!=1
		begin
			declare @UserDims nvarchar(max)
			declare @TblUserDims as table(ID BigiNT)
			select @UserDims=Value from ADM_GlobalPreferences where Name='Dimension List'
			insert into @TblUserDims
			exec SPSplitString @UserDims,','
			if exists (select ID from @TblUserDims where ID=2)
			begin
				delete from #TblAcc where AccountID not in (
					select T.AccountID from Acc_Accounts A with(nolock)
					join #TblAcc T on T.AccountID=A.AccountID
					where A.AccountID in (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=2 and CostCenterID=7 AND NodeID=@UserID)
					or A.CreatedBy=(select UserName from ADM_Users with(nolock) where UserID=@UserID)
				)
			end
		end

		--select *,convert(datetime,fromdate) fromdate,convert(datetime,Todate) Todate from #TblAcc

		print(@SQL)
		EXEC(@SQL)
	END
	
	
	--Getting All Income & Expenes Opening Balances As On Data
	IF @GetAllIncomeExpBalance=1
	BEGIN
		SET @SQL='	SELECT ISNULL(sum(ACC.'+@AmtColumn+'),0) Dr, 0 Cr
			FROM ACC_DocDetails ACC WITH(NOLOCK)'+@ACCJOIN+'
			INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.DebitAccount AND A.AccountTypeID IN ('+@AccountTypeFilter+')
			WHERE ACC.DebitAccount>1 and ACC.DocDate<@TempFromDate'+@PDCWhere+@CurrWHERE+'
			UNION ALL
			SELECT 0 Dr,ISNULL(sum(ACC.'+@AmtColumn+'),0) Cr
			FROM ACC_DocDetails ACC WITH(NOLOCK)'+@ACCJOIN+'
			INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.CreditAccount AND A.AccountTypeID IN ('+@AccountTypeFilter+')
			WHERE ACC.CreditAccount>1 and ACC.CreditAccount>1 and ACC.DocDate<@TempFromDate'+@PDCWhere+@CurrWHERE
		
		IF @ACCJOIN!=''
		BEGIN
			SET @SQL=@SQL+'--Inventory Data
				UNION ALL
				SELECT ISNULL(sum(ACC.'+@AmtColumn+'),0) Dr, 0 Cr
				FROM ACC_DocDetails ACC WITH(NOLOCK)'+@INVJOIN+'
				INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.DebitAccount AND A.AccountTypeID IN ('+@AccountTypeFilter+')
				WHERE ACC.DebitAccount>1 and ACC.DocDate<@TempFromDate'+@PDCWhere+@CurrWHERE+'
				UNION ALL
				SELECT 0 Dr,ISNULL(sum(ACC.'+@AmtColumn+'),0) Cr
				FROM ACC_DocDetails ACC WITH(NOLOCK)'+@INVJOIN+'
				INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.CreditAccount AND A.AccountTypeID IN ('+@AccountTypeFilter+')
				WHERE ACC.CreditAccount>1 and ACC.DocDate<@TempFromDate'+@PDCWhere+@CurrWHERE
		END
		SET @SQL='DECLARE @TempFromDate FLOAT
		SET @TempFromDate='+CONVERT(NVARCHAR,@TempFromDate)+'
		SELECT SUM(Dr) Dr,SUM(Cr) Cr FROM (
	'+@SQL+'
	) AS T'
		--print(@SQL)
		EXEC(@SQL)
	END

	SELECT CONVERT(DATETIME,MAX(ToDate)) PreviousYearEndDate from #TblAcc
	
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
