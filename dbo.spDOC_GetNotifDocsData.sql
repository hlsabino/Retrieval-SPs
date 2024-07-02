USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetNotifDocsData]
	@DocumentID [bigint],
	@DocumentSeqNo [bigint],
	@LinkDetails [nvarchar](max) = NULL,
	@ExtendedDataQuery [nvarchar](max),
	@DynamicSet [int],
	@UserID [bigint],
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;

	--Declaration Section
	DECLARE @HasAccess BIT, @SQL NVARCHAR(MAX),@TableName NVARCHAR(300)
	DECLARE @code NVARCHAR(200),@no BIGINT, @IsInventoryDoc BIT,@docType int
	DECLARE @VoucherNo NVARCHAR(100),@VoucherType INT, @SELECTSQL NVARCHAR(MAX), @FROMSQL NVARCHAR(MAX)
	
	SELECT @IsInventoryDoc=IsInventory,@docType=documentType FROM ADM_DocumentTypes WITH(NOLOCK) 
	WHERE CostCenterID=@DocumentID

	SET @SELECTSQL=''
	SET @FROMSQL=''
	
	IF @IsInventoryDoc=1 OR @LinkDetails IS NOT NULL
	BEGIN
		DECLARE @Ind INT
		SET @Ind=CHARINDEX('FROM INV_DocDetails',@ExtendedDataQuery)
		IF @Ind>0
		BEGIN
			--@FROMSQL
			SET @ExtendedDataQuery=replace(@ExtendedDataQuery,'#PACTLRID#',CONVERT(NVARCHAR,@LangID))

			SET @FROMSQL=replace(substring(@ExtendedDataQuery,@Ind+len('FROM INV_DocDetails'),len(@ExtendedDataQuery)),'INV_DocDetails.','D.')
			SET @SELECTSQL=substring(@ExtendedDataQuery,7,@Ind-7)+','
		END	
	
	--select * from INV_DocDetails
		SELECT @VoucherNo=VoucherNo,@VoucherType=VoucherType FROM INV_DocDetails WITH(NOLOCK) WHERE DocID=@DocumentSeqNo

		SET @SQL=''
		IF @LinkDetails IS NOT NULL
		BEGIN
			SET @SQL='DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1),LinkID BIGINT)
			INSERT INTO @Tbl(LinkID)
			EXEC SPSplitString '''+@LinkDetails+''','',''
			'		
		END
		
		SET @SQL=@SQL+'SELECT CASE WHEN D.DynamicInvDocDetailsID IS NULL THEN D.DocSeqNo ELSE (SELECT TOP 1 DocSeqNo FROM INV_DocDetails with(nolock) WHERE InvDocDetailsID=D.DynamicInvDocDetailsID) END SeqNo,
				'+@SELECTSQL+'
				D.ProductID,D.DynamicInvDocDetailsID,D.BillNo,D.VoucherNo,D.VoucherType,D.DebitAccount,D.CreditAccount,
				CONVERT(DATETIME,D.DocDate) DocDate,D.DocAbbr,D.DocPrefix [Doc Prefix],D.DocNumber [Doc Serial No],
				CONVERT(DATETIME,D.DueDate) DueDate,
				D.Quantity,D.Rate,D.HoldQuantity,D.AverageRate,D.Gross,D.GrossFC,D.CommonNarration,D.LineNarration,
				D.CreatedBy,CONVERT(DATETIME,D.CreatedDate) CreatedDate,
				D.ModifiedBy,CONVERT(DATETIME,D.ModifiedDate) ModifiedDate,
				(select voucherno from inv_docdetails WITH(NOLOCK) where InvDocDetailsID=D.LinkedInvDocDetailsID) [RefNo],
				D.CurrencyID CURRENCY_ID,C.Name CurrencyID,S.Status,D.ExchangeRate [ExchangeRate],
				D.LinkedInvDocDetailsID,LD.VoucherNo LinkDocNo,CONVERT(DATETIME,LD.DocDate) LinkDocDate,LD.DocAbbr LinkDocAbbr,LD.DocPrefix LinkDocPrefix,LD.DocNumber LinkDocSerialNo,LD.CommonNarration LinkCommonNarration,LD.LineNarration LinkLineNarration,
				LD.DocPrefix+LD.DocNumber as LinkSerialNoWithPrefix,
				LDR.AccountCode LinkDrAccountCode,LDR.AccountName LinkDrAccountName,LDR.AliasName LinkDrAccountAlias,
				LCR.AccountCode LinkCrAccountCode,LCR.AccountName LinkCrAccountName,LCR.AliasName LinkCrAccountAlias,
				T.*,N.*,UOM.BaseName Unit
			FROM INV_DocDetails D WITH(NOLOCK) LEFT JOIN
			INV_DocDetails LD WITH(NOLOCK) ON LD.InvDocDetailsID=D.LinkedInvDocDetailsID LEFT JOIN
			ACC_Accounts LDR WITH(NOLOCK) ON LDR.AccountID=LD.DebitAccount LEFT JOIN
			ACC_Accounts LCR WITH(NOLOCK) ON LCR.AccountID=LD.CreditAccount LEFT JOIN				
			COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=D.InvDocDetailsID LEFT JOIN
			COM_DocNumData N WITH(NOLOCK) ON N.InvDocDetailsID=D.InvDocDetailsID LEFT JOIN
			COM_Currency C WITH(NOLOCK) ON C.CurrencyID=D.CurrencyID LEFT JOIN
			COM_Status S WITH(NOLOCK) ON S.StatusID=D.StatusID LEFT JOIN 
			COM_UOM UOM WITH(NOLOCK) on D.Unit=UOM.UOMID'+@FROMSQL
		IF @LinkDetails IS NULL
			SET @SQL=@SQL+' WHERE D.DocID='+CONVERT(NVARCHAR,@DocumentSeqNo)
		ELSE
		BEGIN
		
			SET @SQL=@SQL+' INNER JOIN @Tbl TLink ON TLink.LinkID=D.InvDocDetailsID WHERE 1=1'
		END
		
		IF @docType=5
			SET @SQL=@SQL+' AND D.VoucherType=-1'
		IF @DynamicSet=0
			SET @SQL=@SQL+' AND D.DynamicInvDocDetailsID IS NULL'
		ELSE IF @DynamicSet=1
			SET @SQL=@SQL+' AND (D.DynamicInvDocDetailsID IS NOT NULL OR D.ProductID>0)'
			
		IF @LinkDetails IS NULL
			SET @SQL=@SQL+' ORDER BY SeqNo,D.InvDocDetailsID'
		ELSE
			SET @SQL=@SQL+' ORDER BY TLink.ID'
	
	--	PRINT(@SQL)
		EXEC(@SQL)

	END
	ELSE
	BEGIN
		
		SELECT @VoucherNo=VoucherNo,@VoucherType=DocumentType FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID=@DocumentSeqNo
		DECLARE @IsReceipt INT
		
		IF @VoucherType IN (18,19,21,22)
			SET @IsReceipt=1
		ELSE
			SET @IsReceipt=0
		
		SET @SQL='
		DECLARE @IsReceipt BIT 
		SET @IsReceipt='+CONVERT(NVARCHAR,@IsReceipt)+'
		SELECT D.BillNo, D.VoucherNo,D.DebitAccount,D.CreditAccount,D.DocumentType,D.DocSeqNo SNO,
		CONVERT(DATETIME,D.DocDate) DocDate,CONVERT(DATETIME,D.DueDate) DueDate,D.DocAbbr,D.DocPrefix [Doc Prefix],D.DocNumber [Doc Serial No],
		D.ChequeBankName,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,
		CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.LineNarration,D.CommonNarration,
		D.CreatedBy,CONVERT(DATETIME,D.CreatedDate) CreatedDate,D.ExchangeRate [ExchangeRate],
		(select voucherno from acc_docdetails WITH(NOLOCK) where AccDocDetailsID=D.LinkedAccDocDetailsID) [RefNo],
		D.CurrencyID CURRENCY_ID,C.Name CurrencyID,S.Status,
		D.LinkedAccDocDetailsID,LD.VoucherNo LinkDocNo,CONVERT(DATETIME,LD.DocDate) LinkDocDate,LD.DocAbbr LinkDocAbbr,LD.DocPrefix LinkDocPrefix,LD.DocNumber LinkDocSerialNo,LD.CommonNarration LinkCommonNarration,LD.LineNarration LinkLineNarration,
		LD.DocPrefix+LD.DocNumber as LinkSerialNoWithPrefix,
		LDR.AccountCode LinkDrAccountCode,LDR.AccountName LinkDrAccountName,LDR.AliasName LinkDrAccountAlias,
		LCR.AccountCode LinkCrAccountCode,LCR.AccountName LinkCrAccountName,LCR.AliasName LinkCrAccountAlias,
		T.*,N.*'
		IF @VoucherType IN (16,17,28,29)--JV,Opening Balance,DebitNote(JV),CreditNote(JV)
				SET @SQL=@SQL+',D.Amount,D.AmountFC
				,CASE WHEN D.DebitAccount>0 THEN Amount ELSE 0 END DebitAmount
				,CASE WHEN D.CreditAccount>0 THEN Amount ELSE 0 END CreditAmount
				,(SELECT TOP 1 AccountName From ACC_Accounts with(nolock) WHERE AccountID=(CASE WHEN D.DebitAccount>0 THEN D.DebitAccount ELSE D.CreditAccount END )) AccountName
				,(SELECT TOP 1 AccountCode From ACC_Accounts with(nolock) WHERE AccountID=(CASE WHEN D.DebitAccount>0 THEN D.DebitAccount ELSE D.CreditAccount END )) AccountCode
			'
		ELSE
			SET @SQL=@SQL+' ,CASE WHEN IsNegative=1 THEN -D.Amount ELSE D.Amount END Amount,CASE WHEN IsNegative=1 THEN -D.AmountFC ELSE D.AmountFC END AmountFC
			,CASE WHEN (((LinkedAccDocDetailsID IS NULL OR LinkedAccDocDetailsID=0) AND IsNegative=0) OR (LinkedAccDocDetailsID>0 AND IsNegative=1)) THEN  
					(CASE WHEN @IsReceipt=1 THEN D.CreditAccount ELSE D.DebitAccount END) ELSE (CASE WHEN @IsReceipt=1 THEN D.DebitAccount ELSE D.CreditAccount END) END
		AccountID,
		(SELECT TOP 1 AccountCode From ACC_Accounts with(nolock) WHERE AccountID=(CASE WHEN (((LinkedAccDocDetailsID IS NULL OR LinkedAccDocDetailsID=0) AND IsNegative=0) OR (LinkedAccDocDetailsID>0 AND IsNegative=1)) THEN  
					(CASE WHEN @IsReceipt=1 THEN D.CreditAccount ELSE D.DebitAccount END) ELSE (CASE WHEN @IsReceipt=1 THEN D.DebitAccount ELSE D.CreditAccount END) END)) AccountCode
		,(SELECT TOP 1 AccountName From ACC_Accounts with(nolock) WHERE AccountID=(CASE WHEN (((LinkedAccDocDetailsID IS NULL OR LinkedAccDocDetailsID=0)  AND IsNegative=0) OR (LinkedAccDocDetailsID>0 AND IsNegative=1)) THEN  
					(CASE WHEN @IsReceipt=1 THEN D.CreditAccount ELSE D.DebitAccount END) ELSE (CASE WHEN @IsReceipt=1 THEN D.DebitAccount ELSE D.CreditAccount END) END)) AccountName 
			'
			
		SET @SQL=@SQL+' FROM ACC_DocDetails D WITH(NOLOCK) LEFT JOIN 
		INV_DocDetails LD WITH(NOLOCK) ON LD.InvDocDetailsID=D.LinkedAccDocDetailsID LEFT JOIN
		ACC_Accounts LDR WITH(NOLOCK) ON LDR.AccountID=LD.DebitAccount LEFT JOIN
		ACC_Accounts LCR WITH(NOLOCK) ON LCR.AccountID=LD.CreditAccount LEFT JOIN				
		COM_DocTextData T WITH(NOLOCK) ON T.AccDocDetailsID=D.AccDocDetailsID LEFT JOIN 
		COM_DocNumData N WITH(NOLOCK) ON N.AccDocDetailsID=D.AccDocDetailsID LEFT JOIN
		COM_Currency C WITH(NOLOCK) ON C.CurrencyID=D.CurrencyID LEFT JOIN
		COM_Status S WITH(NOLOCK) ON S.StatusID=D.StatusID
		WHERE (D.DocID='+CONVERT(NVARCHAR,@DocumentSeqNo)+' OR D.VoucherNo='''+@VoucherNo+''')'
		
		IF @DynamicSet=0
		BEGIN
			SET @SQL=@SQL+' AND (D.LinkedAccDocDetailsID IS NULL OR D.LinkedAccDocDetailsID=0)'
			SET @ExtendedDataQuery=@ExtendedDataQuery+' AND (ACC_DocDetails.LinkedAccDocDetailsID IS NULL OR ACC_DocDetails.LinkedAccDocDetailsID=0)'
		END
		
		SET @SQL=@SQL+' ORDER BY D.DocSeqNo ASC'
		
		EXEC(@SQL)

		select 1 where 1<>1

		----BATCH DETAILS
		--SELECT 1 BATCH_DETAILS
		
		--Amount
		IF @VoucherType NOT IN (16,17,28,29)
		BEGIN
			DECLARE @AccID BIGINT
			
			IF @IsReceipt=1
				SELECT TOP 1 @AccID=(CASE WHEN IsNegative=0 THEN DebitAccount ELSE CreditAccount END)
				FROM ACC_DocDetails WITH(NOLOCK) WHERE VoucherNo=@VoucherNo
				ORDER BY AccDocDetailsID asc
			ELSE
				SELECT TOP 1 @AccID=(CASE WHEN IsNegative=0 THEN CreditAccount ELSE DebitAccount END)
				FROM ACC_DocDetails WITH(NOLOCK) WHERE VoucherNo=@VoucherNo
				ORDER BY AccDocDetailsID asc
				
			DECLARE @Sign INT
			IF @IsReceipt=1
				SET @Sign=1
			ELSE
				SET @Sign=-1
				
			--SELECT 
			SELECT  @Sign*(ISNULL((SELECT SUM(Amount) FROM ACC_DocDetails D WITH(NOLOCK) 
				WHERE VoucherNo=@VoucherNo AND DebitAccount=@AccID),0) -
				ISNULL((SELECT SUM(Amount) FROM ACC_DocDetails D WITH(NOLOCK) 
				WHERE VoucherNo=@VoucherNo AND CreditAccount=@AccID),0)) Amount,
				
				@Sign*(ISNULL((SELECT SUM(AmountFC) FROM ACC_DocDetails D WITH(NOLOCK) 
				WHERE (LinkedAccDocDetailsID IS NULL OR LinkedAccDocDetailsID=0) AND VoucherNo=@VoucherNo AND DebitAccount=@AccID),0) -
				ISNULL((SELECT SUM(AmountFC) FROM ACC_DocDetails D WITH(NOLOCK) 
				WHERE (LinkedAccDocDetailsID IS NULL OR LinkedAccDocDetailsID=0) AND VoucherNo=@VoucherNo AND CreditAccount=@AccID),0)) AmountFC
				
			
			SELECT DocSeqNo,DebitAccount AccountID,@Sign*(SUM(Cr)-SUM(Dr)) Amount FROM 
			(SELECT DocSeqNo,DebitAccount,SUM(Amount) Dr, 0.0 Cr FROM ACC_DocDetails D WITH(NOLOCK) 
			WHERE VoucherNo=@VoucherNo GROUP BY DocSeqNo,DebitAccount
			UNION ALL 
			SELECT DocSeqNo,CreditAccount AccountID, 0.0 Dr,SUM(Amount) Cr FROM ACC_DocDetails D WITH(NOLOCK) 
			WHERE VoucherNo=@VoucherNo GROUP BY DocSeqNo,CreditAccount) AS T
			GROUP BY DocSeqNo,DebitAccount
			
			--SELECT * FROM ACC_DocDetails WHERE VoucherNo=@VoucherNo
		END
		ELSE
		BEGIN
			SELECT 0 WHERE 1<>1
			SELECT 0 WHERE 1<>1
		END
	END
	

	/* EXTRA QUERY */
	IF @IsInventoryDoc=0 AND @ExtendedDataQuery IS NOT NULL AND @ExtendedDataQuery<>''
	BEGIN
		SET @ExtendedDataQuery=replace(@ExtendedDataQuery,'#PACTLRID#',CONVERT(NVARCHAR,@LangID))

		SET @ExtendedDataQuery=@ExtendedDataQuery+N' WHERE DocID='+CONVERT(NVARCHAR,@DocumentSeqNo)+'  OR VoucherNo='''+@VoucherNo+''' ORDER BY DocSeqNo ASC'
		
		IF @IsInventoryDoc=1
		BEGIN
			IF @DynamicSet=0
				SET @ExtendedDataQuery=@ExtendedDataQuery+' AND INV_DocDetails.DynamicInvDocDetailsID IS NULL'
			ELSE IF @DynamicSet=1
				SET @ExtendedDataQuery=@ExtendedDataQuery+' AND (INV_DocDetails.DynamicInvDocDetailsID IS NOT NULL OR INV_DocDetails.ProductID>0)'
		END
		
		print @ExtendedDataQuery
		BEGIN TRY 
			EXEC(@ExtendedDataQuery)
		END TRY
		BEGIN CATCH
			SELECT ERROR_MESSAGE(),@ExtendedDataQuery
		END CATCH
		
		--SELECT @ExtendedDataQuery
	END
	
	--NUMERIC FIELDS
	SELECT C.UserColumnName,substring(C.SysColumnName,6,5) ColIndex,D.Formula,C.SectionID
	FROM ADM_CostCenterDef C WITH(NOLOCK) 
	INNER JOIN ADM_DocumentDef D with(nolock) ON D.CostCenterColID=C.CostCenterColID
	WHERE C.CostCenterID=@DocumentID and C.SysColumnName like 'dcnum%' --AND C.SectionID=4 
	ORDER BY C.SectionSeqNumber
	

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

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
