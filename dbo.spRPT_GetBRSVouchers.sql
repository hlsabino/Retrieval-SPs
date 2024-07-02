USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetBRSVouchers]
	@BankAccountID [int],
	@Status [int],
	@FromDate [datetime],
	@ToDate [datetime],
	@Locations [nvarchar](max) = null,
	@ForeignCurrency [int],
	@isFromReport [bit],
	@LockWhere [nvarchar](max) = '',
	@SortOn [nvarchar](max) = '',
	@UserID [int],
	@RoleID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

		DECLARE @SQL NVARCHAR(MAX),@SELECT nvarchar(max),@WHERE NVARCHAR(MAX),@DrWHERE NVARCHAR(MAX),@CrWHERE NVARCHAR(MAX),@FROMSQL NVARCHAR(MAX),@ACCFROMSQL NVARCHAR(MAX),@INVFROMSQL NVARCHAR(MAX),@XML XML,@cols NVARCHAR(MAX),@join NVARCHAR(MAX)
		DECLARE @From FLOAT,@To FLOAT,@Amount NVARCHAR(20),@FCWhere NVARCHAR(20)	
		
		if(@LockWhere <>'' and  dbo.fnCOM_HasAccess(@RoleID,43,193)<>0)
			set @LockWhere=''
			
		if(@LockWhere <>'' and  dbo.fnCOM_HasAccess(@RoleID,43,469)<>0)
			set @LockWhere=''
		
		set @join=''
		set @cols=''
		SET @From=CONVERT(FLOAT,@FromDate)
		SET @To=CONVERT(FLOAT,@ToDate)
		
		IF @ForeignCurrency=0
		BEGIN
			SET @Amount='Amount'
			SET @FCWhere=''
		END
		ELSE
		BEGIN
			SET @Amount='AmountFC'
			SET @FCWhere=' AND D.CurrencyID='+CONVERT(NVARCHAR,@ForeignCurrency)
		END

		Select @XML=ReportDefnXML From ADM_RevenUReports with(nolock) where ReportID=72
		
		declare @tab table(ccid int,syscol nvarchar(200),head nvarchar(max))
		insert into @tab
		select case when SF.CostCenterID is not null then SF.CostCenterID else f.CostCenterID end,
			case when SF.CostCenterID is not null then SF.SysColumnName else f.SysColumnName end,
			X.value('ID[1]','nvarchar(max)')
		from @XML.nodes('PactRevenURpts/PactRevenURptDef/Columns/ColumnDef/Identity') as Data(X)
		left join ADM_CostCenterDef f with(nolock) ON X.value('Field[1]','INT')=f.CostCenterColID
		left join ADM_CostCenterDef SF with(nolock) ON X.value('SelectedField[1]','INT')=SF.CostCenterColID  
		where f.CostCenterID>50000 or SF.CostCenterID>50000  
		
		select @join=@join+' join '+f.TableName+' CC'+convert(nvarchar,d.ccid)+' with(nolock) on CC.dcCCNID'+convert(nvarchar,(d.ccid-50000))+'=CC'+convert(nvarchar,d.ccid)+'.NodeID ',@cols=@cols+ ',CC'+convert(nvarchar,d.ccid)+'.'+d.syscol+' as ['+case when @isFromReport=0 THEN f.Name ELSE  d.head end +']'
		from @tab d
		join adm_features f with(nolock) ON  d.ccid=f.FeatureID
		
		delete from @tab
		insert into @tab
		select 0,f.SysColumnName , case when @isFromReport=0 THEN  X.value('Caption[1]','nvarchar(max)') else X.value('ID[1]','nvarchar(max)') end
		from @XML.nodes('PactRevenURpts/PactRevenURptDef/Columns/ColumnDef/Identity') as Data(X)
		left join ADM_CostCenterDef f with(nolock) ON X.value('Field[1]','INT')=f.CostCenterColID
		where f.SysColumnName like 'dcAlpha%'

		insert into @tab
		select 0,f.SysColumnName , case when @isFromReport=0 THEN  X.value('Caption[1]','nvarchar(max)') else X.value('ID[1]','nvarchar(max)') end
		from @XML.nodes('PactRevenURpts/PactRevenURptDef/Columns/ColumnDef/Identity') as Data(X)
		left join ADM_CostCenterDef f with(nolock) ON abs(X.value('Field[1]','INT'))=f.CostCenterColID
		where X.value('Category[1]','INT')=402
		
		--select *,@XML from @tab
		
		
		select @cols=@cols+ ',txt.'+d.syscol+' as ['+case when @isFromReport=0 THEN d.syscol+'~'+d.head else  d.head end+']'
		from @tab d
		
		delete from @tab
		insert into @tab
		select 0,f.SysColumnName , case when @isFromReport=0 THEN  X.value('Caption[1]','nvarchar(max)') else X.value('ID[1]','nvarchar(max)') end
		from @XML.nodes('PactRevenURpts/PactRevenURptDef/Columns/ColumnDef/Identity') as Data(X)
		left join ADM_CostCenterDef f with(nolock) ON X.value('Field[1]','INT')=f.CostCenterColID
		where f.SysColumnName like 'dcNum%'

	--	select *,@XML from @tab		
		
		select @cols=@cols+ ',num.'+d.syscol+' as ['+case when @isFromReport=0 THEN d.syscol+'~'+d.head else  d.head end+']'
		from @tab d
		
		set @join=@join+' left join COM_DocNumData num with(nolock) on D.AccDocDetailsID=num.AccDocDetailsID'
	
		set @SELECT='SELECT distinct D.DocID,D.CostCenterID, L.DocumentName, D.DocPrefix, D.DocNumber,D.AccDocDetailsID,D.VoucherNo,CONVERT(DATETIME,DocDate) Date,case when D.BankAccountID is not null and D.BankAccountID>0 then BA.AccountName else A.AccountName end Account,D.CommonNarration,
				D.ChequeNumber ChequeNo,CONVERT(DATETIME,D.ChequeDate) ChequeDate,#@AMT@#
				D.BRS_Status,CONVERT(DATETIME,ClearanceDate) ClearanceDate, D.RefCCID,D.REfNodeid'
		if(@LockWhere <>'')
			SET @SELECT=@SELECT+',case when BL.FromDate is null AND c.fromdate is null then 0 else 1 end as IsLock' 
		else
			SET @SELECT=@SELECT+',case when BL.FromDate is null then 0 else 1 end as IsLock'
		SET @SELECT=@SELECT+@cols
		
		SET @ACCFROMSQL='
FROM ACC_DocDetails D WITH(NOLOCK)
LEFT JOIN ACC_Accounts BA WITH(NOLOCK) ON BA.AccountID=D.BankAccountID
JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.CreditAccount
JOIN  ADM_DocumentTypes AS L WITH(NOLOCK) ON L.CostCenterID = D.CostCenterID
join COM_DocTextData txt with(nolock) on txt.AccDocDetailsID=isnull(D.linkedAccDocDetailsID,D.AccDocDetailsID)
join COM_DocCCData CC with(nolock) on D.AccDocDetailsID=CC.AccDocDetailsID'
		if(@LockWhere <>'')
			  SET @ACCFROMSQL=@ACCFROMSQL+' left join ADM_DimensionWiseLockData c  WITH(NOLOCK) on D.DocDate between c.fromdate and c.todate and c.isEnable=1 '+@LockWhere
			  
		SET @WHERE=@FCWhere+' AND  (
	(D.DocDate BETWEEN '+CONVERT(NVARCHAR,@From)+' AND '+CONVERT(NVARCHAR,@To)+')
	or (D.BRS_Status=0 and D.DocDate <'+CONVERT(NVARCHAR,@To)+')
	or (D.BRS_Status=1 and D.ClearanceDate is not null and D.ClearanceDate>='+CONVERT(NVARCHAR,@From)+' and D.DocDate<'+CONVERT(NVARCHAR,@From)+')
)'
	
		if(@Locations<>'')	
			set @WHERE=@WHERE+' and CC.dcCCNID2 in ('+@Locations+')'
			
		--Accounting Select
		SET @SQL=replace(@SELECT,'#@AMT@#','NULL Cr,D.'+@Amount+' Dr,')+@ACCFROMSQL+@join
		set @SQL=@SQL+'
LEFT JOIN ADM_BRSLockedDates BL WITH(NOLOCK) ON BL.AccountID=D.DebitAccount AND D.DocDate between BL.FromDate and BL.ToDate and BL.isEnable=1 
WHERE D.DocumentType<>14 and  D.DocumentType<>19 and (D.StatusID=369 or D.StatusID=449 or D.StatusID=429) and  D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)
		set @SQL=@SQL+@WHERE
			
		set @SQL=@SQL+' 
		UNION ALL 
'
		set @SQL=@SQL+replace(@SELECT,'#@AMT@#','D.'+@Amount+' Cr,NULL Dr,')+replace(@ACCFROMSQL,'D.CreditAccount','D.DebitAccount')+@join
		set @SQL=@SQL+'
LEFT JOIN ADM_BRSLockedDates BL WITH(NOLOCK) ON BL.AccountID=D.CreditAccount AND D.DocDate between BL.FromDate and BL.ToDate and BL.isEnable=1  
WHERE D.DocumentType<>14 and  D.DocumentType<>19 and (D.StatusID=369 or D.StatusID=449 or D.StatusID=429) and D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)
		set @SQL=@SQL+@WHERE
		
		--Inventory Select
		SET @SQL=@SQL+' 
		UNION ALL 
'
		set @join=replace(@join,'D.AccDocDetailsID=num.AccDocDetailsID','D.InvDocDetailsID=num.InvDocDetailsID')
		set @SQL=@SQL+replace(@SELECT,'#@AMT@#','NULL Cr,D.'+@Amount+' Dr,')+replace(replace(@ACCFROMSQL,'D.AccDocDetailsID=CC.AccDocDetailsID','D.InvDocDetailsID=CC.InvDocDetailsID'),'txt.AccDocDetailsID=isnull(D.linkedAccDocDetailsID,D.AccDocDetailsID)','txt.InvDocDetailsID=D.InvDocDetailsID')+@join
		set @SQL=@SQL+'
LEFT JOIN ADM_BRSLockedDates BL WITH(NOLOCK) ON BL.AccountID=D.DebitAccount AND D.DocDate between BL.FromDate and BL.ToDate and BL.isEnable=1  
WHERE (D.StatusID=369 or D.StatusID=449 or D.StatusID=429) and  D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)
		set @SQL=@SQL+@WHERE
			
		set @SQL=@SQL+' 
		UNION ALL 
'
		set @SQL=@SQL+replace(@SELECT,'#@AMT@#','D.'+@Amount+' Cr,NULL Dr,')+replace(replace(replace(@ACCFROMSQL,'D.CreditAccount','D.DebitAccount'),'D.AccDocDetailsID=CC.AccDocDetailsID','D.InvDocDetailsID=CC.InvDocDetailsID'),'txt.AccDocDetailsID=isnull(D.linkedAccDocDetailsID,D.AccDocDetailsID)','txt.InvDocDetailsID=D.InvDocDetailsID')+@join
		set @SQL=@SQL+'
LEFT JOIN ADM_BRSLockedDates BL WITH(NOLOCK) ON BL.AccountID=D.CreditAccount AND D.DocDate between BL.FromDate and BL.ToDate and BL.isEnable=1   
WHERE (D.StatusID=369 or D.StatusID=449 or D.StatusID=429) and D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)
		set @SQL=@SQL+@WHERE
		
		

		--ORDER BY	
		if(@SortOn<>'')
			set @SQL=@SQL+' order by '+@SortOn+',VoucherNo'
		else
			set @SQL=@SQL+' order by Date,VoucherNo'
		
		print (@SQL)
		print (substring(@SQL,4001,4000))
		print 'ww'
		EXEC(@SQL)
	
		
		SET @SQL='select sum(Dr-Cr) as Bal from ('
		
		if @Locations=''
		begin
			SET @SQL=@SQL+'
			SELECT D.'+@Amount+' Dr,0 Cr
			FROM ACC_DocDetails D WITH(NOLOCK) '
			set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19  and (D.StatusID=369 or D.StatusID=429) and  D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@FCWhere+' 
			AND D.DocDate<='+CONVERT(NVARCHAR,@To)+''
			set @SQL=@SQL+' union all
			SELECT 0 Dr,D.'+@Amount+'  Cr
			FROM ACC_DocDetails D WITH(NOLOCK)	'
			set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19 and (D.StatusID=369 or D.StatusID=429)
			 and  D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@FCWhere+' AND D.DocDate<='+CONVERT(NVARCHAR,@To)+''
		end
		else
		begin	
				
			set @WHERE=@FCWhere+'
			and (D.StatusID=369 or D.StatusID=429) AND D.DocDate<='+CONVERT(NVARCHAR,@To)+''
			if(@Locations<>'')	
				set @WHERE=@WHERE+' and CC.dcCCNID2 in ('+@Locations+')'
			--Accounting
			set @SQL=@SQL+'
			SELECT D.'+@Amount+' Dr,0 Cr
			FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData CC with(nolock) on D.AccDocDetailsID=CC.AccDocDetailsID'
			set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19  and D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
			set @SQL=@SQL+' union all
			SELECT 0 Dr,D.'+@Amount+'  Cr
			FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData CC with(nolock) on D.AccDocDetailsID=CC.AccDocDetailsID'
			set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19  and D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
			-- Inventory
			set @SQL=@SQL+' union all
			SELECT D.'+@Amount+' Dr,0 Cr
			FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData CC with(nolock) on D.InvDocDetailsID=CC.InvDocDetailsID'
			set @SQL=@SQL+' WHERE D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
			set @SQL=@SQL+' union all
			SELECT 0 Dr,D.'+@Amount+'  Cr
			FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData CC with(nolock) on D.InvDocDetailsID=CC.InvDocDetailsID'
			set @SQL=@SQL+' WHERE D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
			 
		end
		set @SQL=@SQL+') as t'
	--	print (@SQL)
		EXEC(@SQL)
		
		
		SET @SQL='select sum(Dr-Cr) as Bal from ('
		if @Locations=''
		begin
				SET @SQL=@SQL+'
				SELECT D.'+@Amount+' Dr,0 Cr
				FROM ACC_DocDetails D WITH(NOLOCK)	 '
					set @SQL=@SQL+' WHERE (D.StatusID=369 or D.StatusID=449 or D.StatusID=429) and  D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@FCWhere+' 
				and D.DocumentType<>14 and  D.DocumentType<>19 and D.BRS_Status=1 AND '
				
				if(@isFromReport=0)
					set @SQL=@SQL+'D.ClearanceDate<'+CONVERT(NVARCHAR,@From)
				else
					set @SQL=@SQL+'D.ClearanceDate<='+CONVERT(NVARCHAR,@To)
						
				set @SQL=@SQL+' union all
				SELECT 0 Dr,D.'+@Amount+'  Cr
				FROM ACC_DocDetails D WITH(NOLOCK)'
					set @SQL=@SQL+' WHERE (D.StatusID=369 or D.StatusID=449 or D.StatusID=429) and  D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@FCWhere+'
				and D.DocumentType<>14 and  D.DocumentType<>19 and D.BRS_Status=1 AND '
			
				if(@isFromReport=0)
					set @SQL=@SQL+'D.ClearanceDate<'+CONVERT(NVARCHAR,@From)
				else
					set @SQL=@SQL+'D.ClearanceDate<='+CONVERT(NVARCHAR,@To)
		
		end
		else
		begin
			set @WHERE=@FCWhere+' 
		and (D.StatusID=369 or D.StatusID=449 or D.StatusID=429) and D.BRS_Status=1 AND '
		
		if(@isFromReport=0)
			set @WHERE=@WHERE+'D.ClearanceDate<'+CONVERT(NVARCHAR,@From)
		else
			set @WHERE=@WHERE+'D.ClearanceDate<='+CONVERT(NVARCHAR,@To)
				
		
			if(@Locations<>'')	
				set @WHERE=@WHERE+' and L.dcCCNID2 in ('+@Locations+')'
			--Accounting
			SET @SQL=@SQL+'
		SELECT D.'+@Amount+' Dr,0 Cr
		FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'
			set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19 and D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
			set @SQL=@SQL+' union all
		SELECT 0 Dr,D.'+@Amount+'  Cr
		FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'
			set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19 and D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
			--Inventory
			set @SQL=@SQL+' union all
			SELECT D.'+@Amount+' Dr,0 Cr
		FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData L with(nolock) on D.InvDocDetailsID=L.InvDocDetailsID'
			set @SQL=@SQL+' WHERE D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
			set @SQL=@SQL+' union all
		SELECT 0 Dr,D.'+@Amount+'  Cr
		FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData L with(nolock) on D.InvDocDetailsID=L.InvDocDetailsID'
			set @SQL=@SQL+' WHERE D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE 
		end
		set @SQL=@SQL+'
		) as t'
		print (@SQL)
			
		EXEC(@SQL)
		
		SELECT AccountCode,AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=@BankAccountID
		
		select [Balance] Bal from [ACC_BankStmtBalance] WITH(NOLOCK)
		where [AccountID]=@BankAccountID
		and [Year]=year(@ToDate) and [Month]=month(@ToDate)
		
		
		if(@isFromReport=1)
		BEGIN
				SET @SQL='select sum(Dr-Cr) as Bal from ('
				
				if @Locations=''
				begin
					SET @SQL=@SQL+'
					SELECT D.'+@Amount+' Dr,0 Cr
					FROM ACC_DocDetails D WITH(NOLOCK) '
					set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19  and (D.StatusID=369 or D.StatusID=449 or D.StatusID=429) and  D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@FCWhere+' 
					AND D.DocDate<='+CONVERT(NVARCHAR,@To)+''
					if(@isFromReport=1)
							set @SQL=@SQL+' and D.BRS_Status=0'
					set @SQL=@SQL+' union all
					SELECT 0 Dr,D.'+@Amount+'  Cr
					FROM ACC_DocDetails D WITH(NOLOCK)	'
					set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19 and (D.StatusID=369 or D.StatusID=449 or D.StatusID=429)
					 and  D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@FCWhere+' AND D.DocDate<='+CONVERT(NVARCHAR,@To)+''
					 if(@isFromReport=1)
							set @SQL=@SQL+' and D.BRS_Status=0'
				end
				else
				
				begin	
						
					set @WHERE=@FCWhere+'
					and (D.StatusID=369 or D.StatusID=429 or D.StatusID=449) AND D.DocDate<='+CONVERT(NVARCHAR,@To)+''
					if(@Locations<>'')	
						set @WHERE=@WHERE+' and CC.dcCCNID2 in ('+@Locations+')'
					--Accounting
					set @SQL=@SQL+'
					SELECT D.'+@Amount+' Dr,0 Cr
					FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData CC with(nolock) on D.AccDocDetailsID=CC.AccDocDetailsID'
					set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19  and D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
					 if(@isFromReport=1)
							set @SQL=@SQL+' and D.BRS_Status=0'
					set @SQL=@SQL+' union all
					SELECT 0 Dr,D.'+@Amount+'  Cr
					FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData CC with(nolock) on D.AccDocDetailsID=CC.AccDocDetailsID'
					set @SQL=@SQL+' WHERE D.DocumentType<>14 and  D.DocumentType<>19  and D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
					 if(@isFromReport=1)
							set @SQL=@SQL+' and D.BRS_Status=0'
					-- Inventory
					set @SQL=@SQL+' union all
					SELECT D.'+@Amount+' Dr,0 Cr
					FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData CC with(nolock) on D.InvDocDetailsID=CC.InvDocDetailsID'
					set @SQL=@SQL+' WHERE D.DebitAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
					 if(@isFromReport=1)
							set @SQL=@SQL+' and D.BRS_Status=0'
					set @SQL=@SQL+' union all
					SELECT 0 Dr,D.'+@Amount+'  Cr
					FROM ACC_DocDetails D WITH(NOLOCK) join COM_DocCCData CC with(nolock) on D.InvDocDetailsID=CC.InvDocDetailsID'
					set @SQL=@SQL+' WHERE D.CreditAccount='+CONVERT(NVARCHAR,@BankAccountID)+@WHERE
					 if(@isFromReport=1)
							set @SQL=@SQL+' and D.BRS_Status=0'
					 
				end
				set @SQL=@SQL+') as t'
			
				print (@SQL)
				EXEC(@SQL)
		END
		ELSE
		BEGIN
		
			SELECT D.DocID,D.CostCenterID, L.DocumentName, D.DocPrefix, D.DocNumber,D.AccDocDetailsID,D.VoucherNo
			,CONVERT(DATETIME,DocDate) DocDate,A.AccountName Account,D.CommonNarration,
			D.ChequeNumber ChequeNo,CONVERT(DATETIME,D.ChequeDate) ChequeDate,NULL Cr,D.Amount Dr

			FROM ACC_DocDetails D WITH(NOLOCK)
			LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.CreditAccount
			LEFT JOIN  ADM_DocumentTypes AS L WITH(NOLOCK) ON L.CostCenterID = D.CostCenterID

			WHERE D.DebitAccount=@BankAccountID AND  D.DocDate BETWEEN @From AND @To and D.StatusID=500
			union all
			SELECT D.DocID,D.CostCenterID, L.DocumentName, D.DocPrefix, D.DocNumber,D.AccDocDetailsID,D.VoucherNo
			,CONVERT(DATETIME,DocDate) DocDate,A.AccountName Account,D.CommonNarration,
			D.ChequeNumber ChequeNo,CONVERT(DATETIME,D.ChequeDate) ChequeDate,D.Amount Cr,NULL Dr

			FROM ACC_DocDetails D WITH(NOLOCK)
			LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.CreditAccount
			LEFT JOIN  ADM_DocumentTypes AS L WITH(NOLOCK) ON L.CostCenterID = D.CostCenterID

			WHERE D.CreditAccount=@BankAccountID AND  D.DocDate BETWEEN @From AND @To and D.StatusID=500
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
