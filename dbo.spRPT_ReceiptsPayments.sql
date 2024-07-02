USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_ReceiptsPayments]
	@Vertical [bit],
	@GTPQuery [nvarchar](max),
	@GTPWhere [nvarchar](max),
	@FromDate [datetime],
	@ToDate [datetime],
	@UpPostedDocsList [nvarchar](200),
	@PDCSeperate [bit],
	@IncludePDC [bit],
	@IncludeTerminatedPDC [bit],
	@LocationWHERE [nvarchar](max),
	@ShowLevel [bit],
	@ShowMonthWise [bit],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@AccWhere NVARCHAR(50)
	DECLARE	@From NVARCHAR(20),@To NVARCHAR(20),@MonthColumn NVARCHAR(40)
	DECLARE @SQL1 NVARCHAR(MAX),@SQL2 NVARCHAR(MAX),@UnAppSQL NVARCHAR(MAX),@PDCWHERE NVARCHAR(MAX),@PDCWHERE2 NVARCHAR(MAX)
	CREATE TABLE #TblAccounts(AccountID INT,AccountName NVARCHAR(200) collate database_default)
		
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
	
	if @ShowMonthWise=1
		set @MonthColumn=',convert(datetime,D.DocDate) DocDate'
	else
		set @MonthColumn=',NULL DocDate'
	
	if @UpPostedDocsList=''
		set @UnAppSQL=' AND (D.StatusID=369 or D.StatusID=429)'
	else
		set @UnAppSQL=' AND D.StatusID IN (369,429,'+@UpPostedDocsList+')'
	
	if @IncludePDC=1
	begin
		declare @PDCStatus nvarchar(200)
		set @PDCStatus='(D.StatusID=370 OR D.StatusID=439'
		if @IncludeTerminatedPDC=1
			set @PDCStatus=@PDCStatus+' OR D.StatusID=452'
		set @PDCStatus=@PDCStatus+')'
		--set @PDCWHERE=' AND D.DocumentType<>16 AND ('+@PDCStatus+' OR (D.DocumentType<>14 AND D.DocumentType<>19'+@UnAppSQL+'))'
		set @PDCWHERE2=' OR (DocDate<='+@To+' AND (D.DocumentType=14 OR D.DocumentType=19) AND '+@PDCStatus+')';
        set @PDCWHERE=' AND D.DocumentType NOT IN (16,14,19)'+@UnAppSQL
	end
	else
	begin
		set @PDCWHERE2=''
		set @PDCWHERE=' AND D.DocumentType NOT IN (16,14,19)'+@UnAppSQL
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
	
	IF len(@GTPWhere)=0
		SET @AccWhere='A1.AccountTypeID IN (1,2,3,4) AND A1.AccountID>0'
	ELSE
		SET @AccWhere=@GTPWhere
	
	IF len(@GTPWhere)=0
		SET @SQL='SELECT AccountID,AccountName FROM ACC_Accounts A1 with(nolock) WHERE A1.AccountTypeID IN (1,2,3,4) AND A1.AccountID>0'
	ELSE
		SET @SQL='SELECT A1.AccountID,A1.AccountName FROM ACC_Accounts A1 with(nolock)'+@GTPQuery+' WHERE '+@GTPWhere

	INSERT INTO #TblAccounts
	EXEC(@SQL)
	
--	select * from #TblAccounts
if @Vertical=1
begin
	CREATE TABLE #TblVTrans(AccountID INT,AccountName NVARCHAR(200) collate database_default,TrAccountID INT,TrAccount NVARCHAR(200) collate database_default,Depth INT,lft INT,Amount FLOAT,StatusID int,DocDate datetime)

	SET @SQL='
	select A1.AccountID,A1.AccountName,D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN ACC_Accounts A1 with(nolock) ON D.DebitAccount=A1.AccountID'+@GTPQuery+'
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+'
	UNION ALL
	select A1.AccountID,A1.AccountName,-D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN ACC_Accounts A1 with(nolock) ON D.CreditAccount=A1.AccountID'+@GTPQuery+'
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL
	IF LEN(@SQL1)>0
	BEGIN
		SET @SQL=@SQL+' UNION ALL 
	select A1.AccountID,A1.AccountName,D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN ACC_Accounts A1 with(nolock) ON D.DebitAccount=A1.AccountID'+@GTPQuery+'
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+'
	UNION ALL
	select A1.AccountID,A1.AccountName,-D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN ACC_Accounts A1 with(nolock) ON D.CreditAccount=A1.AccountID'+@GTPQuery+'
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL
	END
	SET @SQL='select sum(Amount) OpAmount
	FROM ( '+@SQL+' ) AS T'
	--Rec_Amount,Pay_Name,Pay_Amount
	--print @SQL
	EXEC(@SQL)
	
	declare @PdcCol1 nvarchar(20)
	if @PDCSeperate=1
	begin
		set @PdcCol1=''
	end
	else
	begin
		set @PdcCol1=''
	end

	SET @SQL='
	select A.AccountID,A.AccountName,AO.AccountID TrAccountID,AO.AccountName TrAccount,AO.Depth,AO.lft,D.Amount,D.StatusID'+@MonthColumn+'
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN #TblAccounts A with(nolock) ON D.DebitAccount=A.AccountID
	INNER JOIN ACC_Accounts AO with(nolock) ON D.CreditAccount=AO.AccountID AND AO.AccountID>0
	WHERE (((DocDate BETWEEN '+@From+' AND '+@To+')'+@PDCWHERE+')'+@PDCWHERE2+')
	UNION ALL
	select A.AccountID,A.AccountName,AO.AccountID TrAccountID,AO.AccountName TrAccount,AO.Depth,AO.lft,-D.Amount,D.StatusID'+@MonthColumn+'
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN #TblAccounts A with(nolock) ON D.CreditAccount=A.AccountID
	INNER JOIN ACC_Accounts AO with(nolock) ON D.DebitAccount=AO.AccountID AND AO.AccountID>0
	WHERE (((DocDate BETWEEN '+@From+' AND '+@To+')'+@PDCWHERE+')'+@PDCWHERE2+')'
	
	IF LEN(@SQL1)>0
	BEGIN
		SET @SQL=@SQL+' UNION ALL 
	select A.AccountID,A.AccountName,AO.AccountID TrAccountID,AO.AccountName TrAccount,AO.Depth,AO.lft,D.Amount,D.StatusID'+@MonthColumn+'
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN #TblAccounts A with(nolock) ON D.DebitAccount=A.AccountID
	INNER JOIN ACC_Accounts AO with(nolock) ON D.CreditAccount=AO.AccountID AND AO.AccountID>0
	WHERE (DocDate BETWEEN '+@From+' AND '+@To+')'+@PDCWHERE+'
	UNION ALL
	select A.AccountID,A.AccountName,AO.AccountID TrAccountID,AO.AccountName TrAccount,AO.Depth,AO.lft,-D.Amount,D.StatusID'+@MonthColumn+'
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN #TblAccounts A with(nolock) ON D.CreditAccount=A.AccountID
	INNER JOIN ACC_Accounts AO with(nolock) ON D.DebitAccount=AO.AccountID AND AO.AccountID>0
	WHERE (DocDate BETWEEN '+@From+' AND '+@To+')'+@PDCWHERE
	END
	--SET @SQL='select AccountID,AccountName Rec_Name,sum(Amount) Amount
	--FROM ( '+@SQL+' ) AS T
	--GROUP BY AccountID,AccountName'
	--Rec_Amount,Pay_Name,Pay_Amount
	INSERT INTO #TblVTrans
	EXEC(@SQL)

	--SELECT * FROM #TblTrans

	--ACCOUNT TRANSACTION DATA
	IF @ShowMonthWise=1
	BEGIN
		if @PDCSeperate=1
			SELECT T.TrAccountID AccountID,StatusID,MAX(T.TrAccount) Account,SUM(Amount) Amount,convert(nvarchar,YEAR(DocDate))+'_'+convert(nvarchar,MONTH(DocDate)) YM
			FROM #TblVTrans T with(nolock) LEFT JOIN #TblAccounts A with(nolock) ON A.AccountID=T.TrAccountID
			WHERE A.AccountID IS NULL
			GROUP BY T.TrAccountID,StatusID,YEAR(DocDate),MONTH(DocDate)
		else
			SELECT T.TrAccountID AccountID,MAX(T.TrAccount) Account,SUM(Amount) Amount,convert(nvarchar,YEAR(DocDate))+'_'+convert(nvarchar,MONTH(DocDate)) YM
			FROM #TblVTrans T with(nolock) LEFT JOIN #TblAccounts A with(nolock) ON A.AccountID=T.TrAccountID
			WHERE A.AccountID IS NULL
			GROUP BY T.TrAccountID,YEAR(DocDate),MONTH(DocDate)
	END
	ELSE
	BEGIN
		if @PDCSeperate=1
			SELECT T.TrAccountID AccountID,StatusID,MAX(T.TrAccount) Account,SUM(Amount) Amount
			FROM #TblVTrans T with(nolock) LEFT JOIN #TblAccounts A with(nolock) ON A.AccountID=T.TrAccountID
			WHERE A.AccountID IS NULL
			GROUP BY T.TrAccountID,StatusID
		else
			SELECT T.TrAccountID AccountID,MAX(T.TrAccount) Account,SUM(Amount) Amount
			FROM #TblVTrans T with(nolock) LEFT JOIN #TblAccounts A with(nolock) ON A.AccountID=T.TrAccountID
			WHERE A.AccountID IS NULL
			GROUP BY T.TrAccountID	
	END

	--BANK TRANSACTION DATA
	IF @ShowMonthWise=1
		SELECT SUM(Amount) Amount,convert(nvarchar,YEAR(DocDate))+'_'+convert(nvarchar,MONTH(DocDate)) YM
		FROM #TblVTrans T with(nolock)
		GROUP BY YEAR(DocDate),MONTH(DocDate)
	ELSE
		SELECT SUM(Amount) Amount
		FROM #TblVTrans T with(nolock)
		GROUP BY T.AccountID
		
	DROP TABLE #TblAccounts
	DROP TABLE #TblVTrans
end
else
begin
	CREATE TABLE #TblTrans(AccountID INT,AccountName NVARCHAR(200) collate database_default,TrAccountID INT,TrAccount NVARCHAR(200) collate database_default,Depth INT,lft INT,Amount FLOAT,DocDate datetime)
	declare @LevelCols nvarchar(max),@LevelJoin nvarchar(max),@LevelGroup nvarchar(max)

	IF @ShowLevel=1
	BEGIN
		set @LevelGroup=',A.IsGroup'
		set @LevelCols=',max(A.Depth) Depth,max(A.lft) lft,A.IsGroup'
		set @LevelJoin=' join ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID'
	END
	ELSE
	BEGIN
		set @LevelGroup=''
		set @LevelCols=''
		set @LevelJoin=''
	END
	--OPENING BALANCE
	SET @SQL='
	select A1.AccountID,A1.AccountName,D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN ACC_Accounts A1 with(nolock) ON D.DebitAccount=A1.AccountID'+@GTPQuery+'
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+'
	UNION ALL
	select A1.AccountID,A1.AccountName,-D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN ACC_Accounts A1 with(nolock) ON D.CreditAccount=A1.AccountID'+@GTPQuery+'
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL
	IF LEN(@SQL1)>0
	BEGIN
		SET @SQL=@SQL+' UNION ALL 
	select A1.AccountID,A1.AccountName,D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN ACC_Accounts A1 with(nolock) ON D.DebitAccount=A1.AccountID'+@GTPQuery+'
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL+'
	UNION ALL
	select A1.AccountID,A1.AccountName,-D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN ACC_Accounts A1 with(nolock) ON D.CreditAccount=A1.AccountID'+@GTPQuery+'
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<'+@From+' OR D.DocumentType=16)'+@UnAppSQL
	END
	SET @SQL='select T.AccountID,T.AccountName Rec_Name,sum(Amount) Amount'+@LevelCols+'
	FROM ( '+@SQL+' ) AS T'+@LevelJoin+'
	GROUP BY T.AccountID,T.AccountName'+@LevelGroup
	--Rec_Amount,Pay_Name,Pay_Amount
	--print @SQL
	EXEC(@SQL)

	--AO.AccountID>0 condition added to remove -ve accounts like JV,DebitNote,..
	--TRANSACTION DATA
	SET @SQL='
	select A.AccountID,A.AccountName,AO.AccountID TrAccountID,AO.AccountName TrAccount,AO.Depth,AO.lft,D.Amount'+@MonthColumn+'
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN #TblAccounts A with(nolock) ON D.DebitAccount=A.AccountID
	INNER JOIN ACC_Accounts AO with(nolock) ON D.CreditAccount=AO.AccountID AND AO.AccountID>0
	WHERE (((DocDate BETWEEN '+@From+' AND '+@To+')'+@PDCWHERE+')'+@PDCWHERE2+')
	UNION ALL
	select A.AccountID,A.AccountName,AO.AccountID TrAccountID,AO.AccountName TrAccount,AO.Depth,AO.lft,-D.Amount'+@MonthColumn+'
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN #TblAccounts A with(nolock) ON D.CreditAccount=A.AccountID
	INNER JOIN ACC_Accounts AO with(nolock) ON D.DebitAccount=AO.AccountID AND AO.AccountID>0
	WHERE (((DocDate BETWEEN '+@From+' AND '+@To+')'+@PDCWHERE+')'+@PDCWHERE2+')'
	
	IF LEN(@SQL1)>0
	BEGIN
		SET @SQL=@SQL+' UNION ALL 
	select A.AccountID,A.AccountName,AO.AccountID TrAccountID,AO.AccountName TrAccount,AO.Depth,AO.lft,D.Amount'+@MonthColumn+'
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN #TblAccounts A with(nolock) ON D.DebitAccount=A.AccountID
	INNER JOIN ACC_Accounts AO with(nolock) ON D.CreditAccount=AO.AccountID AND AO.AccountID>0
	WHERE (DocDate BETWEEN '+@From+' AND '+@To+')'+@PDCWHERE+'
	UNION ALL
	select A.AccountID,A.AccountName,AO.AccountID TrAccountID,AO.AccountName TrAccount,AO.Depth,AO.lft,-D.Amount'+@MonthColumn+'
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN #TblAccounts A with(nolock) ON D.CreditAccount=A.AccountID
	INNER JOIN ACC_Accounts AO with(nolock) ON D.DebitAccount=AO.AccountID AND AO.AccountID>0
	WHERE (DocDate BETWEEN '+@From+' AND '+@To+')'+@PDCWHERE
	END
	--SET @SQL='select AccountID,AccountName Rec_Name,sum(Amount) Amount
	--FROM ( '+@SQL+' ) AS T
	--GROUP BY AccountID,AccountName'
	--Rec_Amount,Pay_Name,Pay_Amount
	--print @SQL
	INSERT INTO #TblTrans
	EXEC(@SQL)

	--SELECT * FROM #TblTrans

	--SELECT T.TrAccountID,T.TrAccount,Amount
	--FROM #TblTrans T LEFT JOIN #TblAccounts A ON A.AccountID=T.TrAccountID
	--WHERE A.AccountID IS NULL

	--ACCOUNT TRANSACTION DATA
	IF @ShowMonthWise=1		
		SELECT T.TrAccountID AccountID,MAX(T.TrAccount) Account,SUM(Amount) Amount,convert(nvarchar,YEAR(DocDate))+'_'+convert(nvarchar,MONTH(DocDate)) YM
		FROM #TblTrans T with(nolock) LEFT JOIN #TblAccounts A with(nolock) ON A.AccountID=T.TrAccountID
		WHERE A.AccountID IS NULL
		GROUP BY T.TrAccountID,YEAR(DocDate),MONTH(DocDate)
	ELSE
	BEGIN
		IF @ShowLevel=1
			SELECT T.TrAccountID AccountID,MAX(T.TrAccount) Account,SUM(Amount) Amount,MAX(T.Depth) Depth,MAX(T.lft) lft,0 IsGroup
			FROM #TblTrans T with(nolock) LEFT JOIN #TblAccounts A with(nolock) ON A.AccountID=T.TrAccountID
			WHERE A.AccountID IS NULL
			GROUP BY T.TrAccountID
			union all
			select AccountID,AccountName,0,Depth,lft,IsGroup from acc_accounts with(nolock) where IsGroup=1
			ORDER BY lft
		ELSE
			SELECT T.TrAccountID AccountID,MAX(T.TrAccount) Account,SUM(Amount) Amount
			FROM #TblTrans T  with(nolock) LEFT JOIN #TblAccounts A with(nolock) ON A.AccountID=T.TrAccountID
			WHERE A.AccountID IS NULL
			GROUP BY T.TrAccountID	
	END

	--BANK TRANSACTION DATA
	IF @ShowMonthWise=1
		SELECT T.AccountID AccountID,MAX(T.AccountName) Rec_Name,SUM(Amount) Amount,convert(nvarchar,YEAR(DocDate))+'_'+convert(nvarchar,MONTH(DocDate)) YM
		FROM #TblTrans T with(nolock)
		GROUP BY T.AccountID,YEAR(DocDate),MONTH(DocDate)
	ELSE
	BEGIN
		IF @ShowLevel=1
			SELECT T.AccountID AccountID,MAX(T.AccountName) Rec_Name,SUM(Amount) Amount,MAX(A.Depth) Depth,MAX(A.lft) lft,convert(bit,0) IsGroup
			FROM #TblTrans T with(nolock)
			join ACC_Accounts A with(nolock) on A.AccountID=T.AccountID
			GROUP BY T.AccountID
		else
			SELECT T.AccountID AccountID,MAX(T.AccountName) Rec_Name,SUM(Amount) Amount
			FROM #TblTrans T with(nolock)
			GROUP BY T.AccountID
	END

	IF @ShowLevel=1
		SELECT AccountID,AccountName Account,convert(float,0) Amount,Depth,lft,convert(bit,1) IsGroup 
		FROM ACC_Accounts with(nolock) 
		WHERE AccountID>1 and IsGroup=1 ORDER BY lft
	ELSE
		SELECT 1 'NOLevel' where 1!=1
	

/*	--CLOSING BALANCE
	SET @SQL='
	select A.AccountID,A.AccountName,D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN ACC_Accounts A with(nolock) ON D.DebitAccount=A.AccountID
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<='+@To+' OR D.DocumentType=16)'+@UnAppSQL+'
	UNION ALL
	select A.AccountID,A.AccountName,-D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL1+'
	INNER JOIN ACC_Accounts A with(nolock) ON D.CreditAccount=A.AccountID
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<='+@To+' OR D.DocumentType=16)'+@UnAppSQL
	IF LEN(@SQL1)>0
	BEGIN
		SET @SQL=@SQL+' UNION ALL 
	select A.AccountID,A.AccountName,D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN ACC_Accounts A with(nolock) ON D.DebitAccount=A.AccountID
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<='+@To+' OR D.DocumentType=16)'+@UnAppSQL+'
	UNION ALL
	select A.AccountID,A.AccountName,-D.Amount
	from ACC_DocDetails D with(nolock)'+@SQL2+'
	INNER JOIN ACC_Accounts A with(nolock) ON D.CreditAccount=A.AccountID
	WHERE '+@AccWhere+' AND D.DocumentType<>14 AND D.DocumentType<>19 AND (D.DocDate<='+@To+' OR D.DocumentType=16)'+@UnAppSQL
	END
	SET @SQL='select AccountID,AccountName,sum(Amount) Amount
	FROM ( '+@SQL+' ) AS T
	GROUP BY AccountID,AccountName'
	
	--print @SQL
	EXEC(@SQL)*/
	DROP TABLE #TblAccounts
	DROP TABLE #TblTrans
end
	

	

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
