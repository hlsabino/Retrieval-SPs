USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetVPTDocumentsData]
	@DocumentID [int],
	@DocumentSeqNo [int],
	@LinkDetails [nvarchar](max) = NULL,
	@ExtendedDataQuery [nvarchar](max),
	@DynamicSet [int],
	@KIT [int],
	@Attachments [int],
	@BWBillNo [bit],
	@Version [int],
	@RevisionColumns [nvarchar](max),
	@UserID [int],
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;

	--Declaration Section
	DECLARE @HasAccess BIT, @SQL NVARCHAR(MAX),@TableName NVARCHAR(50),@History nvarchar(50),@HistoryWh nvarchar(50)
	DECLARE @code NVARCHAR(200),@no INT, @IsInventoryDoc BIT,@docType int
	DECLARE @VoucherNo NVARCHAR(100),@VoucherType INT, @SELECTSQL NVARCHAR(MAX), @FROMSQL NVARCHAR(MAX)
	DECLARE @Ind INT
	DECLARE @k int,@cnt int,@SQLTABLE NVARCHAR(MAX),@SQL1 NVARCHAR(MAX),@PreviousRevision int
	DECLARE @txtJoin nvarchar(max),@numJoin nvarchar(max),@srevisionColumns nvarchar(max),@selectrevisionColumns nvarchar(max)
	--------
	DECLARE @IsLineWisePDC bit
	Declare @docPref table(name nvarchar(100),value nvarchar(100))

	insert into @docPref
	SELECT PrefName,PrefValue  FROM [COM_DocumentPreferences]  WITH(NOLOCK) 
	WHERE CostCenterID=@DocumentID AND PrefName in('LineWisePDC','UseasCrossDimension')
	
	set @IsLineWisePDC=0
	select @IsLineWisePDC=isnull(Value,0) from @docPref
	where Name='LineWisePDC' 
	-----------

	SELECT @IsInventoryDoc=IsInventory,@docType=documentType FROM ADM_DocumentTypes WITH(NOLOCK) 
	WHERE CostCenterID=@DocumentID

	SET @SELECTSQL=''
	SET @FROMSQL=''
	
	--Check For Company Fields Exists
	if(@ExtendedDataQuery like '%#PACTCOMPANYID#%')
	begin		
		SET @ExtendedDataQuery=replace(@ExtendedDataQuery,'#PACTCOMPANYID#',replace(db_name(),'PACT2C',''))
	end

	IF @IsInventoryDoc=1 OR (@LinkDetails IS NOT NULL and @LinkDetails!='AccBillwise')
	BEGIN		
		SET @Ind=CHARINDEX('FROM INV_DocDetails ',@ExtendedDataQuery)
		IF @Ind>0
		BEGIN
			--@FROMSQL
			SET @ExtendedDataQuery=replace(@ExtendedDataQuery,'#PACTLRID#',CONVERT(NVARCHAR,@LangID))

			SET @FROMSQL=replace(substring(@ExtendedDataQuery,@Ind+len('FROM INV_DocDetails '),len(@ExtendedDataQuery)),'INV_DocDetails.','D.')
			SET @SELECTSQL=substring(@ExtendedDataQuery,7,@Ind-7)+','
		END	

	--select * from INV_DocDetails
		SELECT @VoucherNo=VoucherNo,@VoucherType=VoucherType FROM INV_DocDetails WITH(NOLOCK) WHERE DocID=@DocumentSeqNo

		SET @SQL=''
		IF @LinkDetails IS NOT NULL and @LinkDetails NOT LIKE 'BillWise~%'
		BEGIN
			SET @SQL='DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1),LinkID INT)
			INSERT INTO @Tbl(LinkID)
			EXEC SPSplitString '''+@LinkDetails+''','',''
			'
		END
		
		--Start:Previous Revision
		set @History=''
		set @HistoryWh=''
		SET @SQL=''
		SET @SQL1=''
		SET @SQLTABLE=''
		SET @PreviousRevision=0
		SET @srevisionColumns=''
		SET @txtJoin=''
		SET @numJoin=''
		SET @selectrevisionColumns=''
		IF(ISNULL(@RevisionColumns,'')<>'')
			SET @PreviousRevision=1
		IF(@PreviousRevision=1)
		BEGIN			
			IF (@Version>=-1)
			BEGIN				
				 --Start:Temp Table
				SET @SQLTABLE='	 CREATE TABLE #TAB(INVDOCDETAILSID INT,'
				CREATE TABLE #TABSELECT (ID INT IDENTITY(1,1),COLNAME NVARCHAR(MAX))
				INSERT INTO #TABSELECT(COLNAME)
					exec SPSplitString @RevisionColumns,'~'
				
				SET @k=1
				select @cnt=count(*) from #TABSELECT
				while(@k<=@cnt)
				begin
					IF(@k=1)
						SELECT  @srevisionColumns=COLNAME FROM #TABSELECT WHERE ID=@k
					ELSE IF (@k=2)
						SELECT  @selectrevisionColumns=COLNAME FROM #TABSELECT WHERE ID=@k
					ELSE IF (@k=3)
						SELECT  @txtJoin=COLNAME FROM #TABSELECT WHERE ID=@k
					ELSE IF (@K=4)
						SELECT  @numJoin=COLNAME FROM #TABSELECT WHERE ID=@k
				set @k=@k+1
				end
				SET @SQLTABLE=@SQLTABLE+@srevisionColumns+') '
				----End:Temp Table
				
				IF @Version=-1
				BEGIN
					SET @History='_History'
					SET @SQL=@SQL+'	declare @ModDate float
									select @ModDate=max(h.ModifiedDate) from inv_docdetails_History h with(nolock) ,inv_docdetails b with(nolock) where h.invdocdetailsid=b.invdocdetailsid and h.DocID='+CONVERT(NVARCHAR,@DocumentSeqNo)+' and h.versionno<>b.versionno  '
					set @FROMSQL=replace(@FROMSQL,'COM_DocCCData','COM_DocCCData_History')
					set @FROMSQL=replace(@FROMSQL,'ON D.InvDocDetailsID=COM_DocCCData_History.InvDocDetailsID','ON D.InvDocDetailsID=COM_DocCCData_History.InvDocDetailsID and COM_DocCCData_History.ModifiedDate=@ModDate')
				END			
				set @SQL=@SQL+@SQLTABLE
				SET @SQL=@SQL+' insert into #TAB
					SELECT  distinct D.INVDOCDETAILSID,'+  @selectrevisionColumns +'
					FROM INV_DocDetails'+@History+' D WITH(NOLOCK) LEFT JOIN
					INV_DocDetails'+@History+' LD WITH(NOLOCK) ON LD.InvDocDetailsID=D.LinkedInvDocDetailsID LEFT JOIN
					ACC_Accounts LDR WITH(NOLOCK) ON LDR.AccountID=LD.DebitAccount LEFT JOIN
					ACC_Accounts LCR WITH(NOLOCK) ON LCR.AccountID=LD.CreditAccount '
					IF(ISNULL(@txtJoin,'')<>'')
					BEGIN
						SET @SQL=@SQL+ @txtJoin +' '
						IF @Version=-1
							SET @SQL=@SQL+' and T.ModifiedDate=@ModDate '
					END
					
						print @numJoin
				IF(ISNULL(@numJoin,'')<>'')
				BEGIN
					SET @SQL=@SQL+ @numJoin
					IF @Version=-1
						SET @SQL=@SQL+' and N.ModifiedDate=@ModDate '
				END		
				SET @SQL=@SQL+' LEFT JOIN 
					COM_Currency C WITH(NOLOCK) ON C.CurrencyID=D.CurrencyID LEFT JOIN
					COM_Status S WITH(NOLOCK) ON S.StatusID=D.StatusID LEFT JOIN 
					COM_UOM UOM WITH(NOLOCK) on D.Unit=UOM.UOMID'+@FROMSQL
				
				if @DynamicSet=1
				begin
					if(@FROMSQL not like '%INV_Product AS P with(nolock) ON P.ProductID=D.ProductID%')
						SET @SQL=@SQL+' LEFT JOIN INV_Product AS P with(nolock) ON P.ProductID=D.ProductID'
				end
				
				SET @SQL=@SQL+' join INV_DocDetails b with(nolock) on D.InvDocDetailsID=b.InvDocDetailsID '
					
				IF @LinkDetails IS NULL
					SET @SQL=@SQL+' WHERE D.DocID='+CONVERT(NVARCHAR,@DocumentSeqNo)
				ELSE
					SET @SQL=@SQL+' INNER JOIN @Tbl TLink ON TLink.LinkID=D.InvDocDetailsID WHERE 1=1'
				
				IF @docType=5
					SET @SQL=@SQL+' AND D.VoucherType=-1'
					
				IF @DynamicSet=0
					SET @SQL=@SQL+' AND D.DynamicInvDocDetailsID IS NULL'
				ELSE IF @DynamicSet=1
					SET @SQL=@SQL+' AND (D.DynamicInvDocDetailsID IS NOT NULL OR (D.ProductID>0 and P.ProductTypeID!=3))'
					
				if @Version=-1
					SET @SQL=@SQL+' and  D.versionno<>b.versionno  '
					
				IF @Version=-1
					SET @SQL=@SQL+' order by D.INVDOCDETAILSID,'+  @selectrevisionColumns +' desc'
				ELSE 
					SET @SQL=@SQL+' ORDER BY D.InvDocDetailsID'
				--EXEC(@SQL)
			END
			SET @SQL1=@SQL
		END
		--End:Previous Revision
		
		SET @SQL=''
		set @History=''
		set @HistoryWh=''
		SET @SQL=@SQL+@SQL1
		if @Version>-1
		begin
			set @History='_History'
			set @HistoryWh=' and D.ModifiedDate=@ModDate'
			set @SQL=@SQL+'
			declare @ModDate float
			select @ModDate=max(ModifiedDate) from inv_docdetails_History with(nolock) where DocID='+CONVERT(NVARCHAR,@DocumentSeqNo)+' and VersionNo='+CONVERT(NVARCHAR,@Version)
			set @FROMSQL=replace(@FROMSQL,'COM_DocCCData','COM_DocCCData_History')
			set @FROMSQL=replace(@FROMSQL,'ON D.InvDocDetailsID=COM_DocCCData_History.InvDocDetailsID','ON D.InvDocDetailsID=COM_DocCCData_History.InvDocDetailsID and COM_DocCCData_History.ModifiedDate=@ModDate')
		end
		
		SET @SQL=@SQL+'
					SELECT CASE WHEN D.DynamicInvDocDetailsID IS NULL THEN D.DocSeqNo ELSE (SELECT TOP 1 DocSeqNo FROM INV_DocDetails with(nolock) WHERE InvDocDetailsID=D.DynamicInvDocDetailsID) END SeqNo,
					'+@SELECTSQL+'
					D.ProductID,D.DynamicInvDocDetailsID,D.BillNo,D.VoucherNo,D.VoucherType,D.DocumentType,D.DebitAccount,D.CreditAccount,
					CONVERT(DATETIME,D.DocDate) DocDate,D.DocAbbr,D.DocPrefix [Doc Prefix],D.DocNumber [Doc Serial No],D.DocSeqNo DocLineNo,
					CONVERT(DATETIME,D.DueDate) DueDate,CONVERT(DATETIME,D.BillDate) BillDate,D.WorkFlowID,D.WorkFlowLevel,
					D.Quantity,D.Rate,D.HoldQuantity,D.AverageRate,D.Gross,D.GrossFC,D.CommonNarration,D.LineNarration,
					D.CreatedBy,CONVERT(DATETIME,D.CreatedDate) CreatedDate,
					D.ModifiedBy,CONVERT(DATETIME,D.ModifiedDate) ModifiedDate,
					(select voucherno from inv_docdetails WITH(NOLOCK) where InvDocDetailsID=D.LinkedInvDocDetailsID) [RefNo],
					D.CurrencyID CURRENCY_ID,C.Name CurrencyID,C.Symbol CurrencySymbol,S.Status,D.ExchangeRate [ExchangeRate],
					D.LinkedInvDocDetailsID,LD.VoucherNo LinkDocNo,CONVERT(DATETIME,LD.DocDate) LinkDocDate,LD.DocAbbr LinkDocAbbr,LD.DocPrefix LinkDocPrefix,LD.DocNumber LinkDocSerialNo,LD.CommonNarration LinkCommonNarration,LD.LineNarration LinkLineNarration,
					LD.DocPrefix+LD.DocNumber as LinkSerialNoWithPrefix,
					LDR.AccountCode LinkDrAccountCode,LDR.AccountName LinkDrAccountName,LDR.AliasName LinkDrAccountAlias,
					LCR.AccountCode LinkCrAccountCode,LCR.AccountName LinkCrAccountName,LCR.AliasName LinkCrAccountAlias,
					CASE WHEN D.IsQtyFreeOffer=1 or (D.ParentSchemeID!='''' and D.ParentSchemeID is not null) THEN D.Quantity ELSE 0.0 END FreeQty,
					D.IsQtyFreeOffer,D.ParentSchemeID,D.VersionNo,
					T.*,N.*,UOM.UnitName Unit,D.UOMConversion,D.UOMConvertedQty '

		IF(@PreviousRevision=1)
			SET @SQL=@SQL+',TT.* '


		IF(@docType=220)
		BEGIN
			declare @BidOpenVendorsEmail1 NVARCHAR(MAX),@BidOpenVendorsPhone1 NVARCHAR(MAX),@S1 NVARCHAR(MAX)
			SELECT @S1 =' SELECT @BidOpenVendorsEmail1=STUFF( (Select '',''+ a.EMail1 
							From COM_Address a WITH(NOLOCK) 
							JOIN COM_BiddingDocs b WITH(NOLOCK) on a.FeatureID=2  AND b.VendorID=a.FeaturePK
							WHERE a.EMail1 IS NOT NULL AND a.EMail1<>'''' AND a.AddressTypeID=1 AND b.BODocID='++CONVERT(NVARCHAR,@DocumentSeqNo)+'  FOR XML PATH('''') ),1,1,'''')
							
							,@BidOpenVendorsPhone1=STUFF( (Select '',''+ a.Phone1 
							From COM_Address a WITH(NOLOCK) 
							JOIN COM_BiddingDocs b WITH(NOLOCK) on a.FeatureID=2  AND b.VendorID=a.FeaturePK
							WHERE a.Phone1 IS NOT NULL AND a.Phone1<>'''' AND a.AddressTypeID=1 AND b.BODocID='++CONVERT(NVARCHAR,@DocumentSeqNo)+'  FOR XML PATH('''') ),1,1,'''')
							 '
			
			EXEC sp_executesql @S1,N'@BidOpenVendorsEmail1 nvarchar(MAX) output,@BidOpenVendorsPhone1 nvarchar(MAX) output',@BidOpenVendorsEmail1 output,@BidOpenVendorsPhone1 output
			SET @SQL=@SQL+','''+ISNULL(@BidOpenVendorsEmail1,'')+''' as BidOpenVendorsEmail1,'''+ISNULL(@BidOpenVendorsPhone1,'')+''' as BidOpenVendorsPhone1 '
		END
		

		SET @SQL=@SQL+' FROM INV_DocDetails'+@History+' D WITH(NOLOCK) LEFT JOIN
		INV_DocDetails'+@History+' LD WITH(NOLOCK) ON LD.InvDocDetailsID=D.LinkedInvDocDetailsID '  

		IF(@PreviousRevision=1)
			SET @SQL=@SQL+' LEFT JOIN #TAB TT ON TT.InvDocDetailsID=D.InvDocDetailsID '
			
		SET @SQL=@SQL+' LEFT JOIN
		ACC_Accounts LDR WITH(NOLOCK) ON LDR.AccountID=LD.DebitAccount LEFT JOIN
		ACC_Accounts LCR WITH(NOLOCK) ON LCR.AccountID=LD.CreditAccount LEFT JOIN				
		COM_DocTextData'+@History+' T WITH(NOLOCK) ON T.InvDocDetailsID=D.InvDocDetailsID'+replace(@HistoryWh,'D.','T.')+' LEFT JOIN
		'
		if @DocumentID=40054
			set @SQL=@SQL+'PAY_DocNumData'+@History
		else
			set @SQL=@SQL+'COM_DocNumData'+@History
		set @SQL=@SQL+' N WITH(NOLOCK) ON N.InvDocDetailsID=D.InvDocDetailsID'+replace(@HistoryWh,'D.','N.')+' LEFT JOIN
		COM_Currency C WITH(NOLOCK) ON C.CurrencyID=D.CurrencyID LEFT JOIN
		COM_Status S WITH(NOLOCK) ON S.StatusID=D.StatusID LEFT JOIN 
		COM_UOM UOM WITH(NOLOCK) on D.Unit=UOM.UOMID'+@FROMSQL
		
		if @DynamicSet=1
		begin
			if(@FROMSQL not like '%INV_Product AS P with(nolock) ON P.ProductID=D.ProductID%')
				SET @SQL=@SQL+' LEFT JOIN INV_Product AS P with(nolock) ON P.ProductID=D.ProductID'
		end
			
		IF @LinkDetails IS NULL
			SET @SQL=@SQL+' WHERE D.DocID='+CONVERT(NVARCHAR,@DocumentSeqNo)
		ELSE
			SET @SQL=@SQL+' INNER JOIN @Tbl TLink ON TLink.LinkID=D.InvDocDetailsID WHERE 1=1'
		
		IF @docType=5
			SET @SQL=@SQL+' AND D.VoucherType=-1'
			
		IF @DynamicSet=0
			SET @SQL=@SQL+' AND D.DynamicInvDocDetailsID IS NULL'
		ELSE IF @DynamicSet=1
			SET @SQL=@SQL+' AND (D.DynamicInvDocDetailsID IS NOT NULL OR (D.ProductID>0 and P.ProductTypeID!=3))'
			
		if @Version>-1
			SET @SQL=@SQL+' AND D.VersionNo='+convert(nvarchar,@Version)+@HistoryWh
			
		IF @LinkDetails IS NULL
			SET @SQL=@SQL+' ORDER BY SeqNo,D.InvDocDetailsID'
		ELSE
			SET @SQL=@SQL+' ORDER BY TLink.ID'
		
		IF(@PreviousRevision=1)
			SET @SQL=@SQL+' Drop Table #TAB'	
			
		--select @SQL
	 	--PRINT(@SQL)
	 	print(substring(@SQL,1,4000))
		print(substring(@SQL,4001,4000))
		print(substring(@SQL,8001,4000))
		print(substring(@SQL,12001,4000))
		print(substring(@SQL,16001,4000))
		EXEC(@SQL)
		
		--BillWise Data
		SELECT B.BillWiseID,B.RefDocNo BillWiseRefDocNo,CONVERT(DATETIME,B.RefDocDate) BillWiseRefDocDate, B.DocSeqNo SeqNo, B.AccountID,
		abs(B.AdjAmount) BillWiseAmount,abs(B.AmountFC) BillWiseAmountFC, D.BillNo as BillWiseRefBillNo,
		(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmount,
		(select abs(SUM(BB.AdjAmount/BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmountFC,
		
		(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
		(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0) BillWiseRefDocUnAdjustedAmount,
		
		((select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
		(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0))
		*(select abs(SUM(BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1) BillWiseRefDocUnAdjustedAmountFC,
		
		case when D.billdate is null then ' ' else Convert(datetime,D.BillDate)  end as BillWiseRefBillDate,null BillWiseRefDueDate
		,isnull((select top 1 commonNarration from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 commonNarration from INV_DocDetails with(nolock) where VoucherNo=B.RefDocNo)) BillWiseRefDocNarration
		,(select top 1 DocNumber from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo) BillWiseRefDocSerialNo
		,1 IsSaveAdjustment
		FROM  COM_Billwise B with(nolock)
		left join Inv_DocDetails D with(nolock) ON B.RefDocNo=D.VoucherNo
		WHERE B.DocNo=@VoucherNo AND B.IsNewReference=0
		UNION
		SELECT B.BillWiseID,B.DocNo BillWiseRefDocNo,CONVERT(DATETIME,B.DocDate) BillWiseRefDocDate, B.RefDocSeqNo SeqNo,B.AccountID, 
		abs(B.AdjAmount) BillWiseAmount,abs(B.AmountFC) BillWiseAmountFC, D.BillNo as BillWiseRefBillNo,
		(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmount,
		(select abs(SUM(BB.AdjAmount/BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmountFC,
		(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID)
		-(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.DocNo=B.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0) BillWiseRefDocUnAdjustedAmount,		
		((select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID)
		-(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.DocNo=B.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0))
		 *(select abs(SUM(BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocUnAdjustedAmount,		
		
		case when D.billdate is null then ' ' else Convert(datetime,D.BillDate)  end as BillWiseRefBillDate,null BillWiseRefDocDueDate
		,isnull((select top 1 commonNarration from ACC_DocDetails with(nolock) where VoucherNo=B.DocNo),(select top 1 commonNarration from INV_DocDetails with(nolock) where VoucherNo=B.DocNo)) BillWiseRefDocNarration
		,(select top 1 DocNumber from ACC_DocDetails with(nolock) where VoucherNo=B.DocNo) BillWiseRefDocSerialNo
		,0 IsSaveAdjustment
		FROM   COM_Billwise B with(nolock)
		left join Inv_DocDetails D with(nolock) ON B.DocNo=D.VoucherNo
		WHERE B.RefDocNo=@VoucherNo AND B.IsNewReference=0
		ORDER BY BillWiseID
		
		--BATCH DETAILS
		SELECT D.InvDocDetailsID, B.BatchNumber Batch_No, B.BatchCode Batch_Code
		,CONVERT(DATETIME,B.MfgDate) Batch_MfgDate,CONVERT(DATETIME,B.ExpiryDate) Batch_ExpDate,CONVERT(DATETIME,B.ReTestDate) Batch_ReTestDate
		FROM  INV_Batches AS B with(nolock) 
		INNER JOIN Inv_DocDetails D with(nolock) ON B.BatchID=D.BatchID
		WHERE D.VoucherNo=@VoucherNo and D.BatchID!=1
				
		--PAYMENT TERMS
		SELECT P.Amount PayTerms_Amount,P.days PayTerms_Days,CONVERT(datetime,P.DueDate) PayTerms_DueDate,P.Percentage PayTerms_Percentage
		,P.Remarts PayTerms_Remarks,PD.ProfileName PayTerms_ProfileName,P.Remarks1 PayTerms_Remarks1
		FROM COM_DocPayTerms P with(nolock) 
		left join Acc_PaymentDiscountProfile PD with(nolock) on P.ProfileID=PD.ProfileID
		WHERE VoucherNo=@VoucherNo
		ORDER BY DocPaytermID
		
		--SERIAL NOS
		SELECT D.InvDocDetailsID,S.SerialNumber Product_SerialNumbers
		FROM INV_SerialStockProduct AS S with(nolock) 
		INNER JOIN Inv_DocDetails D with(nolock) ON D.InvDocDetailsID=S.InvDocDetailsID
		WHERE D.VoucherNo=@VoucherNo   
		
	END
	ELSE
	BEGIN
		SET @Ind=CHARINDEX('FROM ACC_DocDetails ',@ExtendedDataQuery)
		IF @Ind>0
		BEGIN
			--@FROMSQL
			SET @ExtendedDataQuery=replace(@ExtendedDataQuery,'#PACTLRID#',CONVERT(NVARCHAR,@LangID))

			SET @FROMSQL=replace(substring(@ExtendedDataQuery,@Ind+len('FROM ACC_DocDetails '),len(@ExtendedDataQuery)),'ACC_DocDetails.','D.')
			SET @SELECTSQL=substring(@ExtendedDataQuery,7,@Ind-7)+','
		END
		
			
		IF @LinkDetails is not null and @LinkDetails='AccBillwise'
		BEGIN
			
			SELECT @DocumentSeqNo=DocID,@VoucherNo=VoucherNo FROM ACC_DocDetails WITH(NOLOCK) WHERE RefCCID=300 and RefNodeID=@DocumentSeqNo
			if @VoucherNo is null
			begin
				SELECT @VoucherNo=VoucherNo FROM INV_DocDetails WITH(NOLOCK) WHERE DocID=@DocumentSeqNo
				set @DocumentSeqNo=null
				select @DocumentSeqNo=DocID from ACC_DocDetails WITH(NOLOCK) where VoucherNo IN (
					SELECT DocNo FROM COM_BillWise WITH(NOLOCK) WHERE RefDocNo=@VoucherNo 
					union all
					SELECT RefDocNo FROM COM_BillWise WITH(NOLOCK) WHERE DocNo=@VoucherNo)
			end
		END
		
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
'+@SELECTSQL+'
CONVERT(DATETIME,D.DocDate) DocDate,CONVERT(DATETIME,D.DueDate) DueDate,D.DocAbbr,D.DocPrefix [Doc Prefix],D.DocNumber [Doc Serial No],D.DocSeqNo DocLineNo,
D.ChequeBankName,D.ChequeNumber,CONVERT(DATETIME,D.ChequeDate) ChequeDate,D.WorkFlowID,D.WorkFlowLevel,
CONVERT(DATETIME,D.ChequeMaturityDate) ChequeMaturityDate,D.LineNarration,D.CommonNarration,
D.CreatedBy,CONVERT(DATETIME,D.CreatedDate) CreatedDate,D.ExchangeRate [ExchangeRate],
case when D.LinkedAccDocDetailsID>0 then ''0'' else ''1'' end IsMainRow,
D.CurrencyID CURRENCY_ID,C.Name CurrencyID,C.Symbol CurrencySymbol,S.Status,
D.LinkedAccDocDetailsID		
,D.VersionNo,T.*,N.*'
		IF @VoucherType IN (16,17,28,29)--JV,Opening Balance,DebitNote(JV),CreditNote(JV)
				SET @SQL=@SQL+',D.Amount,D.AmountFC
				,CASE WHEN D.DebitAccount>0 THEN Amount ELSE 0 END DebitAmount
				,CASE WHEN D.CreditAccount>0 THEN Amount ELSE 0 END CreditAmount
				,CASE WHEN D.DebitAccount>0 THEN D.DebitAccount ELSE D.CreditAccount END AccountID
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
		COM_DocTextData T WITH(NOLOCK) ON T.AccDocDetailsID=D.AccDocDetailsID LEFT JOIN 
		COM_DocNumData N WITH(NOLOCK) ON N.AccDocDetailsID=D.AccDocDetailsID LEFT JOIN
		COM_Currency C WITH(NOLOCK) ON C.CurrencyID=D.CurrencyID LEFT JOIN
		COM_Status S WITH(NOLOCK) ON S.StatusID=D.StatusID'+@FROMSQL
		
		--,LD.VoucherNo LinkDocNo,CONVERT(DATETIME,LD.DocDate) LinkDocDate,LD.DocAbbr LinkDocAbbr,LD.DocPrefix LinkDocPrefix,LD.DocNumber LinkDocSerialNo,LD.CommonNarration LinkCommonNarration,LD.LineNarration LinkLineNarration,
		--LD.DocPrefix+LD.DocNumber as LinkSerialNoWithPrefix,
		--LDR.AccountCode LinkDrAccountCode,LDR.AccountName LinkDrAccountName,LDR.AliasName LinkDrAccountAlias,
		--LCR.AccountCode LinkCrAccountCode,LCR.AccountName LinkCrAccountName,LCR.AliasName LinkCrAccountAlias
		
		/*INV_DocDetails LD WITH(NOLOCK) ON LD.InvDocDetailsID=D.LinkedAccDocDetailsID LEFT JOIN
		ACC_Accounts LDR WITH(NOLOCK) ON LDR.AccountID=LD.DebitAccount LEFT JOIN
		ACC_Accounts LCR WITH(NOLOCK) ON LCR.AccountID=LD.CreditAccount LEFT JOIN	*/
		
		SET @SQL=@SQL+' WHERE (D.DocID='+CONVERT(NVARCHAR,@DocumentSeqNo)+' OR D.VoucherNo='''+@VoucherNo+''')'
		
		IF @DynamicSet=0--To Get Account Linked Rows
		BEGIN
			SET @SQL=@SQL+' AND (D.LinkedAccDocDetailsID IS NULL OR D.LinkedAccDocDetailsID=0)'
			SET @ExtendedDataQuery=@ExtendedDataQuery+' AND (ACC_DocDetails.LinkedAccDocDetailsID IS NULL OR ACC_DocDetails.LinkedAccDocDetailsID=0)'
		END
		
		
		SET @SQL=@SQL+' ORDER BY D.DocSeqNo ASC'
		--print(@SQL)
		--print(SUBSTRING(@SQL,4001,4000))
		
		EXEC(@SQL)

		--Billwise
		IF @BWBillNo=1--Returns cross join data if line wise bill no exists
		BEGIN
			if(@IsLineWisePDC=1 or exists(	select Value from @docPref
			where Name='UseasCrossDimension' and Value='true'))
			BEGIN
				SELECT DISTINCT B.BillWiseID, B.RefDocNo BillWiseRefDocNo,CONVERT(DATETIME,B.RefDocDate) BillWiseRefDocDate, B.DocSeqNo SeqNo,B.AccountID,
				abs(AdjAmount) BillWiseAmount,abs(B.AmountFC) BillWiseAmountFC,
				isnull(D.BillNo,DA.BillNo) as BillWiseRefBillNo,
				Convert(datetime,isnull(D.BillDate,DA.BillDate)) as BillWiseRefBillDate,
				Convert(datetime,isnull(D.DueDate,DA.DueDate)) as BillWiseRefDocDueDate,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmount,
				(select abs(SUM(BB.AdjAmount/BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmountFC,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0) BillWiseRefDocUnAdjustedAmount,
				((select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0))
				/(select abs(SUM(BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1) BillWiseRefDocUnAdjustedAmountFC,
			
				isnull((select top 1 commonNarration from inv_docdetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 commonNarration from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo)) BillWiseRefDocNarration
				,(select top 1 DocNumber from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo) BillWiseRefDocSerialNo
				,1 IsSaveAdjustment
				FROM COM_Billwise B with(nolock)
				left join Inv_DocDetails D with(nolock) ON B.RefDocNo=D.VoucherNo
				left join ACC_DocDetails DA with(nolock) ON B.RefDocNo=DA.VoucherNo and B.RefDocSeqNo=DA.DocSeqNo and DA.InvDocDetailsID is null

				join [ACC_DocDetails] B1 WITH(NOLOCK) on  B.[DocNo] =B1.VoucherNo
				join [ACC_DocDetails] C1 WITH(NOLOCK) on  B1.RefNodeid =C1.AccDocDetailsID
				WHERE C1.VoucherNo=@VoucherNo  AND IsNewReference=0
				ORDER BY B.BillWiseID
			END
			ELSE
			BEGIN
				SELECT B.BillWiseID, B.RefDocNo BillWiseRefDocNo,CONVERT(DATETIME,B.RefDocDate) BillWiseRefDocDate, B.DocSeqNo SeqNo,B.AccountID,
				abs(AdjAmount) BillWiseAmount,abs(B.AmountFC) BillWiseAmountFC,
				isnull(D.BillNo,DA.BillNo) as BillWiseRefBillNo,
				Convert(datetime,isnull(D.BillDate,DA.BillDate)) as BillWiseRefBillDate,
				Convert(datetime,isnull(D.DueDate,DA.DueDate)) as BillWiseRefDocDueDate,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmount,
				(select abs(SUM(BB.AdjAmount/BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmountFC,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0) BillWiseRefDocUnAdjustedAmount,
				((select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0))
				/(select abs(SUM(BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1) BillWiseRefDocUnAdjustedAmountFC,
			
				isnull((select top 1 commonNarration from inv_docdetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 commonNarration from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo)) BillWiseRefDocNarration
				,(select top 1 DocNumber from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo) BillWiseRefDocSerialNo
				,1 IsSaveAdjustment
				FROM COM_Billwise B with(nolock)
				left join Inv_DocDetails D with(nolock) ON B.RefDocNo=D.VoucherNo
				left join ACC_DocDetails DA with(nolock) ON B.RefDocNo=DA.VoucherNo and B.RefDocSeqNo=DA.DocSeqNo and DA.InvDocDetailsID is null
				WHERE DocNo=@VoucherNo AND IsNewReference=0
				UNION
				SELECT B.BillWiseID, B.DocNo BillWiseRefDocNo,CONVERT(DATETIME,B.DocDate) BillWiseRefDocDate, RefDocSeqNo SeqNo,B.AccountID,
				abs(AdjAmount) BillWiseAmount,abs(B.AmountFC) BillWiseAmountFC,
				isnull(D.BillNo,DA.BillNo) as BillWiseRefBillNo,
				Convert(datetime,isnull(D.BillDate,DA.BillDate)) as BillWiseRefBillDate,
				Convert(datetime,isnull(D.DueDate,DA.DueDate)) as BillWiseRefDocDueDate,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmount,
				(select abs(SUM(BB.AdjAmount/BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmountFC,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID)
				-(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.DocNo=B.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0) BillWiseRefDocUnAdjustedAmount,
				((select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID)
				-(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.DocNo=B.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0))
				/(select abs(SUM(BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocUnAdjustedAmountFC,
			
				isnull((select top 1 commonNarration from inv_docdetails with(nolock) where VoucherNo=B.DocNo),(select top 1 commonNarration from ACC_DocDetails with(nolock) where VoucherNo=B.DocNo)) BillWiseRefDocNarration
				,(select top 1 DocNumber from ACC_DocDetails with(nolock) where VoucherNo=B.DocNo) BillWiseRefDocSerialNo
				,0 IsSaveAdjustment
				FROM COM_Billwise B with(nolock)
				left join Inv_DocDetails D with(nolock) ON B.DocNo=D.VoucherNo
				left join ACC_DocDetails DA with(nolock) ON B.DocNo=DA.VoucherNo and DA.InvDocDetailsID is null
				WHERE  B.RefDocNo=@VoucherNo AND IsNewReference=0
				ORDER BY BillWiseID
			END
		END
		ELSE--Returns top 1 bill no,bill date
		BEGIN
			if(@IsLineWisePDC=1 or exists(	select Value from @docPref
			where Name='UseasCrossDimension' and Value='true'))
			BEGIN
				SELECT DISTINCT B.BillWiseID, B.RefDocNo BillWiseRefDocNo,CONVERT(DATETIME,B.RefDocDate) BillWiseRefDocDate, C1.DocSeqNo SeqNo,B.AccountID,
				abs(AdjAmount) BillWiseAmount,abs(B.AmountFC) BillWiseAmountFC,
				isnull((select top 1 BillNo from inv_docdetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 BillNo from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo)) BillWiseRefBillNo,
				Convert(datetime,isnull((select top 1 BillDate from inv_docdetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 BillDate from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo))) BillWiseRefBillDate,
				null BillWiseRefDocDueDate,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmount,
				(select abs(SUM(BB.AdjAmount/BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmountFC,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0) BillWiseRefDocUnAdjustedAmount,
				((select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0))
				/(select abs(SUM(BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)  BillWiseRefDocUnAdjustedAmountFC,
			
				isnull((select top 1 commonNarration from inv_docdetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 commonNarration from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo)) BillWiseRefDocNarration
				,(select top 1 DocNumber from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo) BillWiseRefDocSerialNo
				,1 IsSaveAdjustment
				FROM COM_Billwise B with(nolock)
				join [ACC_DocDetails] B1 WITH(NOLOCK) on  B.[DocNo] =B1.VoucherNo
				join [ACC_DocDetails] C1 WITH(NOLOCK) on  B1.RefNodeid =C1.AccDocDetailsID
				WHERE C1.VoucherNo=@VoucherNo  AND IsNewReference=0
				ORDER BY B.BillWiseID
			END
			ELSE
			BEGIN
				SELECT B.BillWiseID, B.RefDocNo BillWiseRefDocNo,CONVERT(DATETIME,B.RefDocDate) BillWiseRefDocDate, B.DocSeqNo SeqNo,B.AccountID,
				abs(AdjAmount) BillWiseAmount,abs(B.AmountFC) BillWiseAmountFC,
				isnull((select top 1 BillNo from inv_docdetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 BillNo from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo)) BillWiseRefBillNo,
				Convert(datetime,isnull((select top 1 BillDate from inv_docdetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 BillDate from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo))) BillWiseRefBillDate,
				null BillWiseRefDocDueDate,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmount,
				(select abs(SUM(BB.AdjAmount/BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmountFC,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0) BillWiseRefDocUnAdjustedAmount,
				((select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)-
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.RefDocNo=B.RefDocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0))
				/(select abs(SUM(BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.RefDocNo=BB.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=1)  BillWiseRefDocUnAdjustedAmountFC,
			
				isnull((select top 1 commonNarration from inv_docdetails with(nolock) where VoucherNo=B.RefDocNo),(select top 1 commonNarration from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo)) BillWiseRefDocNarration
				,(select top 1 DocNumber from ACC_DocDetails with(nolock) where VoucherNo=B.RefDocNo) BillWiseRefDocSerialNo
				,1 IsSaveAdjustment
				FROM COM_Billwise B with(nolock)
				WHERE DocNo=@VoucherNo AND IsNewReference=0
				UNION
				SELECT B.BillWiseID, B.DocNo BillWiseRefDocNo,CONVERT(DATETIME,B.DocDate) BillWiseRefDocDate, RefDocSeqNo SeqNo,B.AccountID,
				abs(AdjAmount) BillWiseAmount,abs(B.AmountFC) BillWiseAmountFC,
				isnull((select top 1 BillNo from inv_docdetails with(nolock) where VoucherNo=B.DocNo),(select top 1 BillNo from ACC_DocDetails with(nolock) where VoucherNo=B.DocNo)) BillWiseRefBillNo,
				Convert(datetime,isnull((select top 1 BillDate from inv_docdetails with(nolock) where VoucherNo=B.DocNo),(select top 1 BillDate from ACC_DocDetails with(nolock) where VoucherNo=B.DocNo))) BillWiseRefBillDate,
				null BillWiseRefDocDueDate,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmount,
				(select abs(SUM(BB.AdjAmount/BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocTotalAmountFC,
				(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID)
				-(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.DocNo=B.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0) BillWiseRefDocUnAdjustedAmount,
				((select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID)
				-(select abs(SUM(BB.AdjAmount)) from COM_Billwise BB with(nolock) where BB.DocNo=B.DocNo and B.AccountID=BB.AccountID and BB.IsNewReference=0)) 
				/(select abs(SUM(BB.AdjExchRT)) from COM_Billwise BB with(nolock) where B.DocNo=BB.DocNo and B.AccountID=BB.AccountID) BillWiseRefDocUnAdjustedAmountFC,
			
				isnull((select top 1 commonNarration from inv_docdetails with(nolock) where VoucherNo=B.DocNo),(select top 1 commonNarration from ACC_DocDetails with(nolock) where VoucherNo=B.DocNo)) BillWiseRefDocNarration
				,(select top 1 DocNumber from ACC_DocDetails with(nolock) where VoucherNo=B.DocNo) BillWiseRefDocSerialNo
				,0 IsSaveAdjustment
				FROM COM_Billwise B with(nolock)
				WHERE  B.RefDocNo=@VoucherNo AND IsNewReference=0
				ORDER BY BillWiseID
			END
		END
			
		--Amount
		IF @VoucherType NOT IN (16,17,28,29)
		BEGIN
			DECLARE @AccID INT
			
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
	
	--Email On Print
	SELECT COUNT(*) EmailOnPrint
	FROM COM_NotifTemplate N WITH(NOLOCK)
	INNER JOIN COM_NotifTemplateAction NA WITH(NOLOCK) ON NA.TemplateID=N.TemplateID AND NA.ActionID=-1
	WHERE CostCenterID=@DocumentID AND StatusID=383
		
	--ATTACHMENTS
	if @Attachments=0
		select '' [GUID],'' ActualFileName,'' FileExtension where 1<>1
	else if @Attachments=1
		select [GUID],ActualFileName,FileExtension  from COM_Files with(nolock)
		where FeatureID=@DocumentID AND FeaturePK=@DocumentSeqNo and AllowinPrint=1
	else if @Attachments=2
		select [GUID],max(ActualFileName) ActualFileName,max(FileExtension) FileExtension from COM_Files with(nolock)
		where GUID IN (select GUID from COM_Files with(nolock)
			where FeatureID=@DocumentID AND FeaturePK=@DocumentSeqNo and AllowinPrint=1)
		GROUP BY [GUID]
		HAVING COUNT([GUID])>1
	else if @Attachments=3
		select [GUID],max(ActualFileName) ActualFileName,max(FileExtension) FileExtension from COM_Files with(nolock)
		where GUID IN (select GUID from COM_Files with(nolock)
			where FeatureID=@DocumentID AND FeaturePK=@DocumentSeqNo and AllowinPrint=1)
		GROUP BY [GUID]
		HAVING COUNT([GUID])=1
	
	--NUMERIC FIELDS
	SELECT C.UserColumnName,convert(int,substring(C.SysColumnName,6,5)) ColIndex,D.Formula,C.SectionID,C.SectionSeqNumber,0 IsAlpha,D.IsCalculate
	FROM ADM_CostCenterDef C WITH(NOLOCK) 
	INNER JOIN ADM_DocumentDef D with(nolock) ON D.CostCenterColID=C.CostCenterColID
	WHERE C.CostCenterID=@DocumentID and C.SysColumnName like 'dcnum%'--AND C.SectionID=4 
	UNION ALL
	SELECT C.UserColumnName,convert(int,substring(C.SysColumnName,8,3)) ColIndex,'' Formula,C.SectionID,C.SectionSeqNumber,1 IsAlpha,0 IsCalculate--case when C.UserColumnType='Date' then 2 else 1 end IsAlpha
	FROM ADM_CostCenterDef C WITH(NOLOCK) 
	WHERE C.CostCenterID=@DocumentID and (C.SysColumnName like 'dcAlpha%' and C.UserColumnType='Numeric') -- or C.UserColumnType='Date'
	ORDER BY IsAlpha,SectionSeqNumber

	--select *  from COM_Files with(nolock)
	--where FeatureID=@DocumentID AND FeaturePK=@DocumentSeqNo and AllowinPrint=1

	--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA
	DECLARE @AuditTrial BIT
	SET @AuditTrial=0
	SELECT @AuditTrial=CONVERT(BIT,PrefValue)  FROM [COM_DocumentPreferences] with(nolock)
	WHERE CostCenterID=@DocumentID AND PrefName='AuditTrial'
	IF @AuditTrial=1
	BEGIN
		IF @IsInventoryDoc=1
			INSERT INTO INV_DocDetails_History_ATUser(DocType,DocID,VoucherNo,ActionType,ActionTypeID,UserID,CreatedBy,CreatedDate)
			VALUES(@DocumentID,@DocumentSeqNo,@VoucherNo,'Print',2,@UserID,@UserName,CONVERT(FLOAT,GETDATE()))
		ELSE
			INSERT INTO ACC_DocDetails_History_ATUser(DocType,DocID,VoucherNo,ActionType,ActionTypeID,UserID,CreatedBy,CreatedDate)
			VALUES(@DocumentID,@DocumentSeqNo,@VoucherNo,'Print',2,@UserID,@UserName,CONVERT(FLOAT,GETDATE()))
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
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
