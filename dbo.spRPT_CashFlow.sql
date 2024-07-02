USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_CashFlow]
	@FromDate [datetime],
	@ToDate [datetime],
	@IncludeUpPostedDocs [bit],
	@IncludePDC [bit],
	@IncludeTerminatedPDC [bit],
	@Groups [nvarchar](max),
	@Accounts [nvarchar](max),
	@MonthWise [bit],
	@Documents [nvarchar](max),
	@LocationWHERE [nvarchar](max),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@PDCSQL NVARCHAR(MAX),@PDCStatus nvarchar(50)
	DECLARE	@From NVARCHAR(20),@To NVARCHAR(20)
	DECLARE @SQL1 NVARCHAR(MAX),@SQL2 NVARCHAR(MAX),@Mn1 NVARCHAR(50),@Mn2 NVARCHAR(100),@Mn3 NVARCHAR(50),@Mn4 NVARCHAR(50),@UnAppSQL NVARCHAR(MAX)
	
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
	
	set @PDCStatus='370,439'
	if @IncludePDC=1
    begin
		declare @Temp nvarchar(200)
		SET @Temp='(D.StatusID=370 OR D.StatusID=439'
		IF @IncludeTerminatedPDC=1
		begin
			SET @Temp=@Temp+' OR D.StatusID=452'
			SET @PDCStatus=@PDCStatus+',452'
		end
		SET @Temp=@Temp+')'
        if @IncludeUpPostedDocs=1
        begin
            set @UnAppSQL = ' AND D.DocumentType<>16 AND ('+@Temp+' OR (D.DocumentType<>14 AND D.DocumentType<>19))'
        end
        else
        begin
            set @UnAppSQL = ' AND D.DocumentType<>16 AND ('+@Temp+' OR (D.DocumentType<>14 AND D.DocumentType<>19 AND D.StatusID=369))'
        end
    end
    else
    begin
        set @UnAppSQL = ' AND D.DocumentType NOT IN (16,14,19)'
        if @IncludeUpPostedDocs=0
        begin
            set @UnAppSQL =@UnAppSQL + ' AND D.StatusID=369'
        end
    end
    
    set @Mn1=''
    set @Mn2=''
    set @Mn3=''
    set @Mn4=''
    if @MonthWise=1
    begin
		set @Mn1=',CONVERT(DATETIME,DocDate) DocDate'
		--set @Mn2=',''Y''+CONVERT(NVARCHAR,YEAR(T.DocDate))+''M''+ CONVERT(NVARCHAR,MONTH(T.DocDate)) Mn'
		set @Mn2=',''Y''+CONVERT(NVARCHAR,T.yy)+''M''+ CONVERT(NVARCHAR,T.mm) Mn'
		set @Mn3=',yy,mm'
		set @Mn4=',YEAR(D.DocDate) yy, MONTH(D.DocDate) mm'
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

	/********** FOR ACCOUNTS **********/
	IF @Accounts!=''
	BEGIN
		SET @SQL='SELECT D.DebitAccount AccountID, 0 Debit,D.Amount Credit'+@Mn4+'
		FROM ACC_DocDetails D with(nolock) '+@SQL1+'
		INNER JOIN ACC_Accounts AType with(nolock) ON AType.AccountID=D.CreditAccount AND (AType.AccountTypeID=1 OR AType.AccountTypeID=2 OR AType.AccountTypeID=3)
		WHERE D.DebitAccount IN ('+@Accounts+')	AND (D.DocDate>='+@From+' AND D.DocDate<='+@To+')'+@UnAppSQL+'
		UNION ALL
		SELECT D.CreditAccount,D.Amount Debit, 0 Credit'+@Mn4+'
		FROM ACC_DocDetails D with(nolock) '+@SQL1+'
		INNER JOIN ACC_Accounts AType with(nolock) ON AType.AccountID=D.DebitAccount AND (AType.AccountTypeID=1 OR AType.AccountTypeID=2 OR AType.AccountTypeID=3)
		WHERE D.CreditAccount IN ('+@Accounts+') AND (D.DocDate>='+@From+' AND D.DocDate<='+@To+')'+@UnAppSQL
		
		IF LEN(@SQL1)>0
		BEGIN
			SET @SQL=@SQL+' UNION ALL SELECT D.DebitAccount AccountID, D.Amount Debit,0 Credit'+@Mn4+'
			FROM ACC_DocDetails D with(nolock) '+@SQL2+'		
			INNER JOIN ACC_Accounts AType with(nolock) ON AType.AccountID=D.CreditAccount AND (AType.AccountTypeID=1 OR AType.AccountTypeID=2 OR AType.AccountTypeID=3)
			WHERE D.DebitAccount IN ('+@Accounts+')	AND (D.DocDate>='+@From+' AND D.DocDate<='+@To+')'+@UnAppSQL+'
			UNION ALL
			SELECT D.CreditAccount,0 Debit, D.Amount Credit'+@Mn4+'
			FROM ACC_DocDetails D with(nolock) '+@SQL2+'
			INNER JOIN ACC_Accounts AType with(nolock) ON AType.AccountID=D.DebitAccount AND (AType.AccountTypeID=1 OR AType.AccountTypeID=2 OR AType.AccountTypeID=3)
			WHERE D.CreditAccount IN ('+@Accounts+') AND (D.DocDate>='+@From+' AND D.DocDate<='+@To+')'+@UnAppSQL
		END
		
		--IF @Documents!=''
		--BEGIN
		--	SET @SQL=@SQL+' UNION ALL SELECT AccountID,
 	--			 AdjAmount+ISNULL((SELECT SUM(CB.AdjAmount) FROM COM_Billwise CB WHERE CB.RefDocNo=B.DocNo AND CB.RefDocSeqNo=B.DocSeqNo AND IsNewReference=0 AND CB.DocDate<='+@To+'
		--		 AND DocType<>14 AND DocType<>19),0) Debit,0 Credit'+replace(@Mn4,'D.DocDate','B.DocDueDate')+'
		--		FROM COM_Billwise B WITH(NOLOCK) 
		--		INNER JOIN ACC_DocDetails ACC ON ACC.VoucherNo=B.DocNo AND ACC.CostCenterID IN ('+@Documents+')
		--		WHERE B.IsNewReference=1 AND B.DocDueDate>='+@From+' AND B.DocDueDate<='+@To+' AND DocType<>14 AND DocType<>19 AND B.AccountID IN ('+@Accounts+')'+replace(@LocationWHERE,'DCC.','B.')
		--	--print(@SQL)
		--END
		
		SET @SQL='SELECT A.AccountID, A.AccountName Particulars,ISNULL(SUM(Debit)-SUM(Credit),0) Balance'+@Mn2+'
		FROM ('+@SQL+') AS T  RIGHT JOIN ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID		
		GROUP BY A.AccountName,A.AccountID'+@Mn3+' HAVING A.AccountID IN ('+@Accounts+')'
		
		--print @SQL
		EXEC(@SQL)
		
		IF @Documents!=''
		BEGIN
			--@MonthWise
			--SET @SQL='SELECT B.DocNo, CONVERT(DATETIME, B.DocDueDate) DocDate,AccountID,
 		--		 AdjAmount+ISNULL((SELECT SUM(CB.AdjAmount) FROM COM_Billwise CB WHERE CB.RefDocNo=B.DocNo AND CB.RefDocSeqNo=B.DocSeqNo AND IsNewReference=0 AND CB.DocDate<='+@To+'
			--	 AND DocType<>14 AND DocType<>19),0) Balance,				 
			--	 ISNULL((SELECT SUM(CB.AdjAmount) FROM COM_Billwise CB WHERE CB.RefDocNo=B.DocNo AND CB.RefDocSeqNo=B.DocSeqNo AND IsNewReference=0 AND CB.DocDate<='+@To+' AND (SELECT TOP 1 ACC.StatusID FROM ACC_DocDetails ACC WITH(NOLOCK) WHERE ACC.VoucherNo=CB.DocNo)=370),0)
			--	 TotalPDC
			--	FROM COM_Billwise B WITH(NOLOCK) 
			--	INNER JOIN ACC_DocDetails ACC ON ACC.VoucherNo=B.DocNo AND ACC.CostCenterID IN ('+@Documents+')
			--	WHERE B.IsNewReference=1 AND B.DocDueDate<='+@To+' AND DocType<>14 AND DocType<>19 AND B.AccountID IN ('+@Accounts+')'+replace(@LocationWHERE,'DCC.','B.')

--Payment term
SET @SQL='SELECT *,Amount+Paid AdjAmount FROM (SELECT B.DocNo, CASE WHEN EXISTS (select * from COM_DocPayTerms with(nolock) where VoucherNo=B.DocNo)
THEN (select CONVERT(DATETIME,max(DueDate)) from COM_DocPayTerms with(nolock) where VoucherNo=B.DocNo and DueDate<='+@To+' )
ELSE CONVERT(DATETIME,B.DocDueDate) END DocDate,B.AccountID
,CASE WHEN EXISTS (select * from COM_DocPayTerms with(nolock) where VoucherNo=B.DocNo)
THEN (select sum(amount)*sign(B.AdjAmount) from COM_DocPayTerms with(nolock) where VoucherNo=B.DocNo and DueDate<='+@To+' )
ELSE AdjAmount END Amount,
ISNULL((SELECT SUM(CB.AdjAmount) FROM COM_Billwise CB with(nolock) WHERE CB.RefDocNo=B.DocNo AND CB.RefDocSeqNo=B.DocSeqNo AND IsNewReference=0 AND CB.DocDate<='+@To+' AND  DocType<>14 AND DocType<>19),0) Paid
,ISNULL((SELECT SUM(CB.AdjAmount) FROM COM_Billwise CB WHERE CB.RefDocNo=B.DocNo AND CB.RefDocSeqNo=B.DocSeqNo AND IsNewReference=0 AND CB.DocDate<='+@To+' AND (SELECT TOP 1 ACC.StatusID FROM ACC_DocDetails ACC WITH(NOLOCK) WHERE ACC.VoucherNo=CB.DocNo)=370),0) TotalPDC  FROM COM_Billwise B WITH(NOLOCK) WHERE B.IsNewReference=1 AND DocType<>14 AND DocType<>19

 AND B.AccountID IN (140)
 
) AS T WHERE DocDate<='+@To+' AND Amount IS NOT NULL 

SELECT PT.VoucherNo,PT.Amount,CONVERT(DATETIME,PT.DueDate) DueDate
FROM  COM_Billwise B with(nolock) INNER JOIN COM_DocPayTerms PT with(nolock) ON PT.VoucherNo=B.DocNo
WHERE B.IsNewReference=1 AND PT.DueDate<='+@To+' AND B.AccountID IN ('+@Accounts+')'


			--EXEC(@SQL)
			--print(@SQL)
		END
	END
	ELSE
		SELECT 0 AccountID WHERE 1<>1
		
	
	--SELECT * FROM COM_BillWise WHERE AccountID=140
	
	/********** FOR ACCOUNT GROUPS **********/
	IF @Groups!=''
	BEGIN
	
		SET @SQL='SELECT AG.GroupID AccountID, 0 Debit,D.Amount Credit'+@Mn4+'
		FROM ACC_DocDetails D with(nolock) '+@SQL1+'
		INNER JOIN ACC_Accounts AType with(nolock) ON AType.AccountID=D.CreditAccount AND (AType.AccountTypeID=1 OR AType.AccountTypeID=2 OR AType.AccountTypeID=3)
		INNER JOIN (SELECT AGRP.AccountID GroupID,A.AccountID AccountID FROM ACC_Accounts A with(nolock)
				INNER JOIN ACC_Accounts AGRP with(nolock) ON A.lft BETWEEN AGRP.lft AND AGRP.rgt AND A.IsGroup=0
				WHERE AGRP.AccountID IN ('+@Groups+')) AS AG ON AG.AccountID=D.DebitAccount
		WHERE (D.DocDate>='+@From+' AND D.DocDate<='+@To+')'+@UnAppSQL+'
		UNION ALL
		SELECT AG.GroupID,D.Amount Debit, 0 Credit'+@Mn4+'
		FROM ACC_DocDetails D with(nolock) '+@SQL1+'
		INNER JOIN ACC_Accounts AType with(nolock) ON AType.AccountID=D.DebitAccount AND (AType.AccountTypeID=1 OR AType.AccountTypeID=2 OR AType.AccountTypeID=3)
		INNER JOIN (SELECT AGRP.AccountID GroupID,A.AccountID AccountID FROM ACC_Accounts A with(nolock)
				INNER JOIN ACC_Accounts AGRP with(nolock) ON A.lft BETWEEN AGRP.lft AND AGRP.rgt AND A.IsGroup=0
				WHERE AGRP.AccountID IN ('+@Groups+')) AS AG ON AG.AccountID=D.CreditAccount
		WHERE (D.DocDate>='+@From+' AND D.DocDate<='+@To+')'+@UnAppSQL
		
		IF LEN(@SQL1)>0
		BEGIN
			SET @SQL=@SQL+' UNION ALL SELECT D.DebitAccount AccountID, D.Amount Debit,0 Credit'+@Mn4+'
			FROM ACC_DocDetails D with(nolock) '+@SQL2+'		
			INNER JOIN ACC_Accounts AType with(nolock) ON AType.AccountID=D.CreditAccount AND (AType.AccountTypeID=1 OR AType.AccountTypeID=2 OR AType.AccountTypeID=3)
			INNER JOIN (SELECT AGRP.AccountID GroupID,A.AccountID AccountID FROM ACC_Accounts A with(nolock)
				INNER JOIN ACC_Accounts AGRP with(nolock) ON A.lft BETWEEN AGRP.lft AND AGRP.rgt AND A.IsGroup=0
				WHERE AGRP.AccountID IN ('+@Groups+')) AS AG ON AG.AccountID=D.DebitAccount
			WHERE (D.DocDate>='+@From+' AND D.DocDate<='+@To+')'+@UnAppSQL+'
			UNION ALL
			SELECT D.CreditAccount,0 Debit, D.Amount Credit'+@Mn4+'
			FROM ACC_DocDetails D with(nolock) '+@SQL2+'
			INNER JOIN ACC_Accounts AType with(nolock) ON AType.AccountID=D.DebitAccount AND (AType.AccountTypeID=1 OR AType.AccountTypeID=2 OR AType.AccountTypeID=3)
			INNER JOIN (SELECT AGRP.AccountID GroupID,A.AccountID AccountID FROM ACC_Accounts A with(nolock)
				INNER JOIN ACC_Accounts AGRP with(nolock) ON A.lft BETWEEN AGRP.lft AND AGRP.rgt AND A.IsGroup=0
				WHERE AGRP.AccountID IN ('+@Groups+')) AS AG ON AG.AccountID=D.CreditAccount
			WHERE (D.DocDate>='+@From+' AND D.DocDate<='+@To+')'+@UnAppSQL
		END
		
		SET @SQL='SELECT A.AccountID, A.AccountName Particulars,ISNULL(SUM(Debit)-SUM(Credit),0) Balance'+@Mn2+'
		FROM ('+@SQL+') AS T  RIGHT JOIN ACC_Accounts A with(nolock) ON A.AccountID=T.AccountID		
		GROUP BY A.AccountName,A.AccountID'+@Mn3+' HAVING A.AccountID IN ('+@Groups+')'
		
		--print @SQL
		EXEC(@SQL)
		
		
	END
	ELSE
		SELECT 0 AccountID WHERE 1<>1	
		
		
	
	IF @Documents!=''
	BEGIN
		if @Accounts!=''
		begin
			if @Groups!=''
				set @Groups=@Groups+','
				
			set @Groups=@Groups+@Accounts
		end

		SET @SQL='SELECT *,Amount+Paid AdjAmount FROM (SELECT B.DocNo, CASE WHEN EXISTS (select * from COM_DocPayTerms with(nolock) where VoucherNo=B.DocNo)
		THEN (select CONVERT(DATETIME,max(DueDate)) from COM_DocPayTerms with(nolock) where VoucherNo=B.DocNo and DueDate<='+@To+' )
		ELSE CONVERT(DATETIME,B.DocDueDate) END DocDate,AG.GroupID AccountID
		,CASE WHEN EXISTS (select * from COM_DocPayTerms with(nolock) where VoucherNo=B.DocNo)
		THEN (select sum(amount)*sign(B.AdjAmount) from COM_DocPayTerms with(nolock) where VoucherNo=B.DocNo and DueDate<='+@To+' )
		ELSE AdjAmount END Amount,
		ISNULL((SELECT SUM(CB.AdjAmount) FROM COM_Billwise CB with(nolock) WHERE CB.RefDocNo=B.DocNo AND CB.RefDocSeqNo=B.DocSeqNo AND IsNewReference=0 AND CB.DocDate<='+@To+' AND  DocType<>14 AND DocType<>19),0) Paid,ISNULL((SELECT SUM(CB.AdjAmount) FROM COM_Billwise CB WHERE CB.RefDocNo=B.DocNo AND CB.RefDocSeqNo=B.DocSeqNo AND IsNewReference=0 AND CB.DocDate<='+@To+' AND (SELECT TOP 1 ACC.StatusID FROM ACC_DocDetails ACC WITH(NOLOCK) WHERE ACC.VoucherNo=CB.DocNo) IN ('+@PDCStatus+')),0) TotalPDC  
		FROM COM_Billwise B WITH(NOLOCK) 
		
		INNER JOIN (SELECT AGRP.AccountID GroupID,A.AccountID AccountID FROM ACC_Accounts A with(nolock)
				INNER JOIN ACC_Accounts AGRP with(nolock) ON A.lft BETWEEN AGRP.lft AND AGRP.rgt AND A.IsGroup=0
				WHERE AGRP.AccountID IN ('+@Groups+')) AS AG ON AG.AccountID=B.AccountID
		
		WHERE B.IsNewReference=1 AND DocType<>14 AND DocType<>19 '+replace(@LocationWHERE,'DCC.','B.')+'
		) AS T WHERE DocDate<='+@To+' AND (Amount IS NOT NULL AND (Amount+Paid)<>0)

		SELECT PT.VoucherNo,PT.Amount,CONVERT(DATETIME,PT.DueDate) DueDate
		FROM  COM_Billwise B with(nolock) INNER JOIN COM_DocPayTerms PT with(nolock) ON PT.VoucherNo=B.DocNo
				INNER JOIN (SELECT AGRP.AccountID GroupID,A.AccountID AccountID FROM ACC_Accounts A with(nolock)
				INNER JOIN ACC_Accounts AGRP with(nolock) ON A.lft BETWEEN AGRP.lft AND AGRP.rgt AND A.IsGroup=0
				WHERE AGRP.AccountID IN ('+@Groups+')) AS AG ON AG.AccountID=B.AccountID
		WHERE B.IsNewReference=1 AND PT.DueDate<='+@To

--		print(@SQL)
		EXEC(@SQL)
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
--spRPT_CashFlow '1 Jan 2013','31 May 2013',1,1,'1589,520','',1,'40011','',1-- AND DCC.dcCCNID2=1
GO
