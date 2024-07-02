USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetPDCdocuments]
	@FilterOn [nvarchar](50),
	@SortOn [nvarchar](50),
	@FromDate [datetime],
	@ToDate [datetime],
	@ForeignCurrency [int],
	@Locations [nvarchar](max),
	@Divisions [nvarchar](max),
	@Dimensions [nvarchar](max),
	@BankAccountID [int],
	@Status [int],
	@Filter [int],
	@SELECTQRY [nvarchar](max),
	@FROMQRY [nvarchar](max),
	@CostCenterID [nvarchar](max),
	@WhereCondition [nvarchar](max) = '',
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

		DECLARE @From FLOAT,@To FLOAT,@sql nvarchar(max),@WHERE nvarchar(max),@PDPsql nvarchar(max),@PDRsql nvarchar(max),@Amount NVARCHAR(20),
		@FCWhere NVARCHAR(20),@ExcTerminatedPDC NVARCHAR(20) ,@ExcRefPDC NVARCHAR(20),@isCrossDimRct BIT,@PDCFilterDimension INT,@IsHold bit
		
		
		if exists(select * from sys.columns 
			where name ='HoldStatus' and object_id=object_id('ACC_DocDetails'))
		and exists(select Value from ADM_GlobalPreferences with(nolock)
		where Name='Enablechequehold' and Value is not null and Value='true')
			set @IsHold=1
		else
			set @IsHold=0	
	 
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
		
		if exists(select PrefValue from COM_DocumentPreferences with(nolock)
		where PrefName = 'UseasCrossDimension' and PrefValue='true' and DocumentType=19)
			set @isCrossDimRct =1
		ELSE
			set @isCrossDimRct =0
		
		select @ExcTerminatedPDC=Value from ADM_GlobalPreferences with(nolock)
		where Name='ExcludePDCTerminatedContracts' and Value is not null and Value<>''

		select @ExcRefPDC=Value from ADM_GlobalPreferences with(nolock)
		where Name='ExcludePDCCloseRefundContracts' and Value is not null and Value<>''	
		
		select @PDCFilterDimension=Value from ADM_GlobalPreferences with(nolock)
		where Name='PDCFilterDimension' and Value is not null and Value<>''	
		
		DECLARE @HoldDim nvarchar(50)
		SELECT @HoldDim=Value FROM ADM_GlobalPreferences with(nolock) where Name='PDCHoldDimension'
		if(@HoldDim!='' and isnumeric(@HoldDim)=1 and convert(int,@HoldDim)>50000)
		begin
			select @SELECTQRY=@SELECTQRY+',L.dcCCNID'+convert(nvarchar,(convert(int,@HoldDim)-50000))+' HoldDimension_Key'
			select @SELECTQRY=@SELECTQRY+',HOLDDIM.Name HoldDimension'
			select @FROMQRY=@FROMQRY+' left join '+(select TableName from ADM_Features with(nolock) where FeatureID=@HoldDim)+' HOLDDIM with(nolock) on HOLDDIM.NodeID=L.dcCCNID'+convert(nvarchar,(convert(int,@HoldDim)-50000))
			select @FROMQRY=@FROMQRY+' join COM_DOCTextData TXT with(nolock) on TXT.AccDocDetailsID=D.AccDocDetailsID'
			SELECT @HoldDim=Value FROM ADM_GlobalPreferences with(nolock) where Name='PDCHoldDate'
			if(@HoldDim!='')
				select @SELECTQRY=@SELECTQRY+','''' HoldDate,case when isdate(TXT.dcAlpha'+@HoldDim+')=1 then convert(datetime,TXT.dcAlpha'+@HoldDim+') else NULL end HoldDate_Key'	
			SELECT @HoldDim=Value FROM ADM_GlobalPreferences with(nolock) where Name='PDCHoldRemarks'
			if(@HoldDim!='')
				select @SELECTQRY=@SELECTQRY+',TXT.dcAlpha'+@HoldDim+' HoldRemarks'	
		end
		
		
		------------RECEIPTS-------
		--WHERE CLAUSE
		set @WHERE='
		where  (D.DocumentType=19 or (D.DocumentType=16 and D.OpPdcStatus in(370,369,429))) and (D.LinkedAccDocDetailsID is null or D.LinkedAccDocDetailsID=0) and D.StatusID not in (371,372,441,447,448) and (D.DocOrder is null or D.DocOrder!=5)'
		 if(@IsHold=1 and @FilterOn='ChequeMaturityDate')
			 set @WHERE=@WHERE+'and ((D.HoldStatus=1 and D.HoldTillDate Between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)+') or ((D.HoldStatus is null or D.HoldStatus=0) and D.ChequeMaturityDate Between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)+'))'
		 ELSE
			set @WHERE=@WHERE+'and D.'+@FilterOn+' Between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)
		 
		 set @WHERE=@WHERE+@FCWhere
		
		if(@BankAccountID>0)
			set @WHERE=@WHERE+' and (D.DebitAccount='+convert(nvarchar,@BankAccountID)+' or D.BankAccountID='+convert(nvarchar,@BankAccountID)+' or (isnull(D.IsNegative,0)=1 and D.CreditAccount='+convert(nvarchar,@BankAccountID)+')) '
		if(@Locations<>'')	
			set @WHERE=@WHERE+' and L.dcCCNID2 in ('+@Locations+')'
		if(@Divisions<>'')	
			set @WHERE=@WHERE+' and L.dcCCNID1 in ('+@Divisions+')'
		if(@PDCFilterDimension IS NOT NULL AND @PDCFilterDimension >0 AND @Dimensions<>'')	
			set @WHERE=@WHERE+' and L.dcCCNID'+CONVERT(NVARCHAR,(@PDCFilterDimension-50000))+' in ('+@Dimensions+')'		
		if(@Status>0)
			set @WHERE=@WHERE+' and (D.StatusID = '+convert(nvarchar,@Status)+' or D.OpPdcStatus = '+convert(nvarchar,@Status)+')'
		if(@CostCenterID<>'')
			set @WHERE=@WHERE+' and D.CostCenterID in ('+convert(nvarchar(max),@CostCenterID)+')'
		if(@ExcTerminatedPDC is not null and @ExcTerminatedPDC='true')
		BEGIN	
			if(@ExcRefPDC is not null and @ExcRefPDC='true')
				set @WHERE=@WHERE+' and (RC.StatusID is null or RC.StatusID not in (428,450) or (RC.StatusID in (428,450) and RCM.Type in(-4,101)) )'
			ELSE
				set @WHERE=@WHERE+' and (RC.StatusID is null or RC.StatusID<>428  or (RC.StatusID=428 and RCM.Type in(-4,101)) )'
		END	
		if(@WhereCondition is not null and @WhereCondition<>'')
			set @WHERE=@WHERE+@WhereCondition
		
		--Reference Vouchers Temp Table
		if @Status!=370 and @Filter!=2
		begin
			CREATE TABLE #TblPDR(AccDocDetailsID INT,ConvertedCostCenterID int,ConvertedVoucherNO nvarchar(100),ConvertedDocID INT,ConvertedDocUser nvarchar(100),ConvertedDocDate datetime)
			
			set @PDRsql='
		INSERT INTO #TblPDR
		select D.AccDocDetailsID,RD.CostCenterID ConvertedCostCenterID,max(RD.VoucherNo) ConvertedVoucherNO,max(RD.AccDocDetailsID) ConvertedDocID,max(RD.createdby) ConvertedDocUser,convert(datetime,max(RD.DocDate)) ConvertedDocDate
	from  ACC_DocDetails D with(nolock)
	inner join ACC_DocDetails RD with(nolock) on RD.RefCCID=400 and RD.RefNodeid=D.AccDocDetailsID
	join COM_Status C with(nolock) on D.StatusID=C.StatusID				
	join ACC_Accounts A with(nolock) on D.DebitAccount=A.AccountID
	join ACC_Accounts S with(nolock) on D.CreditAccount=S.AccountID
	left join ACC_Accounts BA with(nolock) on D.BankAccountID=BA.AccountID'
			if(@ExcTerminatedPDC is not null and @ExcTerminatedPDC='true')
				set @PDRsql=@PDRsql+' left join Ren_contract RC with(nolock) on Rc.ContractID=D.RefNOdeID and D.refccid=95 
									  left join REN_ContractDocMapping RCM with(nolock) on D.DOCID=RCM.DOCID and RCM.IsAccDOc=1 '
			if(@FROMQRY!='' or @Locations!='' or @Divisions!='' or (@PDCFilterDimension IS NOT NULL AND @PDCFilterDimension >0 AND @Dimensions!=''))
				set @PDRsql=@PDRsql+' join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'
			
			set @PDRsql=@PDRsql+@WHERE
			set @PDRsql=@PDRsql+' group by D.AccDocDetailsID,RD.CostCenterID'
			print(@PDRsql)
			EXEC(@PDRsql)
		end

		--All Receipts Query
		set @PDRsql='select  D.AccDocDetailsID,D.DocID,D.ChequeNumber,isnull(D.IsNegative,0) IsNegative,
			D.CostCenterID,DocPrefix,DocNumber,D.VoucherNo,D.'+@Amount+' Amount,case when D.DocumentType=16 then D.OpPdcStatus ELSE D.StatusID END StatusID,convert(datetime,DocDate) DocDate,
			convert(datetime,ChequeMaturityDate) ChequeMaturityDate'
			
			if(@IsHold=1)	
				set @PDRsql=@PDRsql+',case when D.HoldStatus=1  THEN  convert(datetime,D.HoldTillDate) ELSE convert(datetime,ChequeMaturityDate) END BillDate'
			ELSE
				set @PDRsql=@PDRsql+',convert(datetime,ChequeMaturityDate) BillDate'
				
			set @PDRsql=@PDRsql+',D.BillDate BillNo,
			Case when D.StatusID=429 then (select count(DocNO) from COM_ChequeReturn CR with(nolock) where cr.RefDocNo=D.VoucherNo) else 0 end as AdjCnt
			,case when D.DocumentType=16 then CD.Status else C.Status end Status,D.ChequeNumber,A.AccountName as BankAccountID,D.DebitAccount as BankAccountID_Key,
			S.AccountName as AccountID,D.CreditAccount as AccountID_Key,D.CreditAccount as ActDr,D.BankAccountID BankID,BA.AccountName BankName,D.DocumentType,convert(datetime,D.ChequeDate) ChequeDate'
		
		if(@isCrossDimRct=1)
			set @PDRsql=@PDRsql+ ',D.RefCCID,D.RefNodeID '
		if(@IsHold=1)
				set @PDRsql=@PDRsql+ ',D.HoldStatus,convert(datetime,D.HoldTillDate) HoldTillDate'
		if @Status=370
			set @PDRsql=@PDRsql+','''' ConvertedVoucherNO,0 ConvertedDocID,null ConvertedDocUser,convert(datetime,1) ConvertedDocDate'
		else
			set @PDRsql=@PDRsql+',Case when (D.StatusID=369 or D.StatusID=429) then T.ConvertedVoucherNO else '''' end	as ConvertedVoucherNO
				,Case when (D.StatusID=369 or D.StatusID=429) then T.ConvertedDocID else '''' end	as ConvertedDocID
				,Case when (D.StatusID=369 or D.StatusID=429) then T.ConvertedDocUser else '''' end	as ConvertedDocUser 
				,Case when (D.StatusID=369 or D.StatusID=429) then T.ConvertedDocDate else '''' end	as ConvertedDocDate'
		if @Status=370
			set @PDRsql=@PDRsql+','''' InterMediateVoucherNO,0 InterMediateDocID,null InterMediateDocUser,null InterMediateDocDate'
		else
			set @PDRsql=@PDRsql+',Case when (D.StatusID=369 or D.StatusID=429) then IT.ConvertedVoucherNO else '''' end	as InterMediateVoucherNO
				,Case when (D.StatusID=369 or D.StatusID=429) then IT.ConvertedDocID else ''''  end	as InterMediateDocID
				,Case when (D.StatusID=369 or D.StatusID=429) then IT.ConvertedDocUser else ''''  end as InterMediateDocUser
				,Case when (D.StatusID=369 or D.StatusID=429) then IT.ConvertedDocDate else ''''  end	as InterMediateDocDate'
		if @Status=370
			set @PDRsql=@PDRsql+',null BouncedVoucher,null BouncedVoucherDocID,null BouncedDocUser,null BouncedDocDate'
		else				
			set @PDRsql=@PDRsql+',BT.ConvertedVoucherNO BouncedVoucher
				,BT.ConvertedDocID BouncedVoucherDocID
				,BT.ConvertedDocUser BouncedDocUser
				,BT.ConvertedDocDate BouncedDocDate'

				set @PDRsql=@PDRsql+',DT.BounceInvDoc,DT.PDCAmtFld,DT.PDCActionFld,BA.PDCReplaceAccount ReplaceAccountID'
						
		set @PDRsql=@PDRsql+@SELECTQRY+'
			from  ACC_DocDetails D with(nolock)
			join COM_Status C with(nolock) on D.StatusID=C.StatusID				
			left join COM_Status CD with(nolock) on D.OpPdcStatus=Cd.StatusID				
			join ACC_Accounts A with(nolock) on D.DebitAccount=A.AccountID
			join ACC_Accounts S with(nolock) on D.CreditAccount=S.AccountID
			join ADM_DocumentTypes DT with(nolock) on DT.CostCenterID=D.CostCenterID
			left join ACC_Accounts BA with(nolock) on D.BankAccountID=BA.AccountID'
		if @Status!=370
			set @PDRsql=@PDRsql+'
			left join #TblPDR T with(nolock) on T.AccDocDetailsID=D.AccDocDetailsID  and DT.ConvertAS=T.ConvertedCostCenterID
			left join #TblPDR IT with(nolock) on IT.AccDocDetailsID=D.AccDocDetailsID  and DT.IntermediateConvertion=IT.ConvertedCostCenterID
			left join #TblPDR BT with(nolock) on BT.AccDocDetailsID=D.AccDocDetailsID  and DT.Bounce=BT.ConvertedCostCenterID'
			
		if(@ExcTerminatedPDC is not null and @ExcTerminatedPDC='true')
			set @PDRsql=@PDRsql+' left join Ren_contract RC with(nolock) on Rc.ContractID=D.RefNOdeID and D.refccid=95 
									  left join REN_ContractDocMapping RCM with(nolock) on D.DOCID=RCM.DOCID and RCM.IsAccDOc=1 '
		if(@FROMQRY!='' or @Locations!='' or @Divisions!='' or (@PDCFilterDimension IS NOT NULL AND @PDCFilterDimension >0 AND @Dimensions!=''))
			set @PDRsql=@PDRsql+' join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'+@FROMQRY
		
		set @PDRsql=@PDRsql+@WHERE
		
		
		------------PAYMENTS-------
		--WHERE CLAUSE
		set @WHERE='			
		where D.DocumentType=14 and (D.LinkedAccDocDetailsID is null or D.LinkedAccDocDetailsID=0) and D.StatusID not in (371,372,441,447,448)  and (D.DocOrder is null or D.DocOrder!=5) and D.'+@FilterOn+' Between '+convert(nvarchar(100),@From)+' and '+convert(nvarchar(100),@To)+@FCWhere
		if(@BankAccountID>0)
			set @WHERE=@WHERE+' and (D.CreditAccount='+convert(nvarchar,@BankAccountID)+' or D.BankAccountID='+convert(nvarchar,@BankAccountID)+' or (isnull(D.IsNegative,0)=1 and D.DebitAccount='+convert(nvarchar,@BankAccountID)+')) '
		if(@Locations<>'')	
			set @WHERE=@WHERE+' and L.dcCCNID2 in ('+@Locations+')'
		if(@Divisions<>'')	
			set @WHERE=@WHERE+' and L.dcCCNID1 in ('+@Divisions+')'
		if(@PDCFilterDimension IS NOT NULL AND @PDCFilterDimension >0 AND @Dimensions<>'')	
			set @WHERE=@WHERE+' and L.dcCCNID'+CONVERT(NVARCHAR,(@PDCFilterDimension-50000))+' in ('+@Dimensions+')'
		if(@Status>0)
			set @WHERE=@WHERE+' and D.StatusID = '+convert(nvarchar,@Status)
		if(@CostCenterID<>'')
			set @WHERE=@WHERE+' and D.CostCenterID in ('+convert(nvarchar(max),@CostCenterID)+')'
		if(@ExcTerminatedPDC is not null and @ExcTerminatedPDC='true')
		BEGIN
			if(@ExcRefPDC is not null and @ExcRefPDC='true')				
				set @WHERE=@WHERE+' and (RC.StatusID is null or RC.StatusID not in (428,450) or (RC.StatusID in (428,450) and RCM.Type in(-4,101)) )'
			ELSE
				set @WHERE=@WHERE+' and (RC.StatusID is null or RC.StatusID<>428 or (RC.StatusID=428 and RCM.Type in(-4,101)) )'
		END	
		
		if(@WhereCondition is not null and @WhereCondition<>'')
			set @WHERE=@WHERE+@WhereCondition
				
		--Reference Vouchers Temp Table
		if @Status!=370 and @Filter!=1
		begin
			CREATE TABLE #TblPDP(AccDocDetailsID INT,ConvertedCostCenterID int,ConvertedVoucherNO nvarchar(100),ConvertedDocID INT,ConvertedDocUser nvarchar(100),ConvertedDocDate datetime)
			
			set @PDPsql='
		INSERT INTO #TblPDP
		select D.AccDocDetailsID,RD.CostCenterID ConvertedCostCenterID,max(RD.VoucherNo) ConvertedVoucherNO,max(RD.AccDocDetailsID) ConvertedDocID,max(RD.createdby) ConvertedDocUser,convert(datetime,max(RD.DocDate)) ConvertedDocDate
		from  ACC_DocDetails D  with(nolock)
		inner join ACC_DocDetails RD with(nolock) on RD.RefCCID=400 and RD.RefNodeid=D.AccDocDetailsID
		join COM_Status C with(nolock) on D.StatusID=C.StatusID					
		join ACC_Accounts A with(nolock) on D.DebitAccount=A.AccountID
		join ACC_Accounts S with(nolock) on D.CreditAccount=S.AccountID
		left join ACC_Accounts BA with(nolock) on D.BankAccountID=BA.AccountID '
			if(@ExcTerminatedPDC is not null and @ExcTerminatedPDC='true')
				set @PDPsql=@PDPsql+' left join Ren_contract RC with(nolock) on Rc.ContractID=D.RefNOdeID and D.refccid=95
									  left join REN_ContractDocMapping RCM with(nolock) on D.DOCID=RCM.DOCID and RCM.IsAccDOc=1 '
			if(@FROMQRY!='' or @Locations!='' or @Divisions!='' or (@PDCFilterDimension IS NOT NULL AND @PDCFilterDimension >0 AND @Dimensions!=''))
				set @PDPsql=@PDPsql+' join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'
		
			set @PDPsql=@PDPsql+@WHERE
			set @PDPsql=@PDPsql+' group by D.AccDocDetailsID,RD.CostCenterID'
			print(@PDPsql)
			EXEC(@PDPsql)
		end
		
		--All Payament Query
		set @PDPsql='select  D.AccDocDetailsID,D.DocID,D.ChequeNumber,isnull(D.IsNegative,0) IsNegative,
			D.CostCenterID,DocPrefix,DocNumber,D.VoucherNo,D.'+@Amount+' Amount,D.StatusID,
			convert(datetime,DocDate) DocDate,convert(datetime,ChequeMaturityDate) ChequeMaturityDate,
			convert(datetime,ChequeMaturityDate) BillDate,D.BillDate BillNo,
			Case when D.StatusID=429 then (select count(DocNO) from COM_ChequeReturn CR with(nolock) where cr.RefDocNo=D.VoucherNo) else 0 end as AdjCnt
			,C.Status, D.ChequeNumber, S.AccountName as BankAccountID,D.CreditAccount as BankAccountID_Key,
			A.AccountName as AccountID,D.DebitAccount as AccountID_Key,
			D.DebitAccount as ActDr,D.BankAccountID BankID,BA.AccountName BankName,D.DocumentType,convert(datetime,D.ChequeDate) ChequeDate'
			
		if(@isCrossDimRct=1)
			set @PDPsql=@PDPsql+ ',D.RefCCID,D.RefNodeID '

		if(@IsHold=1)
				set @PDPsql=@PDPsql+ ',D.HoldStatus,convert(datetime,D.HoldTillDate) HoldTillDate'
			
		if @Status=370
			set @PDPsql=@PDPsql+ ','''' ConvertedVoucherNO,0 ConvertedDocID,null ConvertedDocUser,convert(datetime,1) ConvertedDocDate'
		else
			set @PDPsql=@PDPsql+',Case when (D.StatusID=369 or D.StatusID=429) then T.ConvertedVoucherNO else '''' end	as ConvertedVoucherNO
				,Case when (D.StatusID=369 or D.StatusID=429) then T.ConvertedDocID else '''' end	as ConvertedDocID
				,Case when (D.StatusID=369 or D.StatusID=429) then T.ConvertedDocUser else '''' end	as ConvertedDocUser 
				,Case when (D.StatusID=369 or D.StatusID=429) then T.ConvertedDocDate else '''' end	as ConvertedDocDate'
		if @Status=370
			set @PDPsql=@PDPsql+ ','''' InterMediateVoucherNO,0 InterMediateDocID,null InterMediateDocUser,null InterMediateDocDate'
		else
			set @PDPsql=@PDPsql+',Case when (D.StatusID=369 or D.StatusID=429) then IT.ConvertedVoucherNO else '''' end	as InterMediateVoucherNO
				,Case when (D.StatusID=369 or D.StatusID=429) then IT.ConvertedDocID else ''''  end	as InterMediateDocID
				,Case when (D.StatusID=369 or D.StatusID=429) then IT.ConvertedDocUser else ''''  end as InterMediateDocUser
				,Case when (D.StatusID=369 or D.StatusID=429) then IT.ConvertedDocDate else ''''  end	as InterMediateDocDate'
		if @Status=370
			set @PDPsql=@PDPsql+ ',null BouncedVoucher,null BouncedVoucherDocID,null BouncedDocUser,null BouncedDocDate'
		else
			set @PDPsql=@PDPsql+',BT.ConvertedVoucherNO BouncedVoucher
				,BT.ConvertedDocID BouncedVoucherDocID
				,BT.ConvertedDocUser BouncedDocUser
				,BT.ConvertedDocDate BouncedDocDate'

		set @PDPsql=@PDPsql+ ',DT.BounceInvDoc,DT.PDCAmtFld,DT.PDCActionFld,BA.PDCReplaceAccount ReplaceAccountID'
			
		set @PDPsql=@PDPsql+@SELECTQRY+'
		from  ACC_DocDetails D  with(nolock)
		join COM_Status C with(nolock) on D.StatusID=C.StatusID					
		join ACC_Accounts A with(nolock) on D.DebitAccount=A.AccountID
		join ACC_Accounts S with(nolock) on D.CreditAccount=S.AccountID
		join ADM_DocumentTypes DT with(nolock) on DT.CostCenterID=D.CostCenterID
		left join ACC_Accounts BA with(nolock) on D.BankAccountID=BA.AccountID '
		if @Status!=370
			set @PDPsql=@PDPsql+'
			left join #TblPDP T with(nolock) on T.AccDocDetailsID=D.AccDocDetailsID  and DT.ConvertAS=T.ConvertedCostCenterID
			left join #TblPDP IT with(nolock) on IT.AccDocDetailsID=D.AccDocDetailsID  and DT.IntermediateConvertion=IT.ConvertedCostCenterID
			left join #TblPDP BT with(nolock) on BT.AccDocDetailsID=D.AccDocDetailsID  and DT.Bounce=BT.ConvertedCostCenterID'
		if(@ExcTerminatedPDC is not null and @ExcTerminatedPDC='true')
			set @PDPsql=@PDPsql+' left join Ren_contract RC with(nolock) on Rc.ContractID=D.RefNOdeID and D.refccid=95 
								  left join REN_ContractDocMapping RCM with(nolock) on D.DOCID=RCM.DOCID and RCM.IsAccDOc=1 '
		if(@FROMQRY!='' or @Locations!='' or @Divisions!='' or (@PDCFilterDimension IS NOT NULL AND @PDCFilterDimension >0 AND @Dimensions!=''))
			set @PDPsql=@PDPsql+' join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'+@FROMQRY

		set @PDPsql=@PDPsql+@WHERE
						
		
		--All
		if @Filter =0
		begin
		 		set @sql=	@PDRsql+'
		 		 UNION ALL
		 		 '+@PDPsql 
		end
		else if @Filter=1--PDR
		begin
				 set @sql=	@PDRsql
		end		
		else--PDP
		begin
			 set @sql=	@PDPsql
		end
		
		
		if(@isCrossDimRct=1)	------------CrossDimRECEIPTS-------
		BEGIN
				
			 
			--All Receipts Query
			set @PDRsql=' UNION ALL 
			select distinct D.AccDocDetailsID,D.DocID,D.ChequeNumber,isnull(D.IsNegative,0) IsNegative,
				D.CostCenterID,DocPrefix,DocNumber,D.VoucherNo,D.'+@Amount+' Amount,t.StatusID
				,convert(datetime,DocDate) DocDate,
				convert(datetime,ChequeMaturityDate) ChequeMaturityDate,convert(datetime,ChequeMaturityDate) BillDate,D.BillDate BillNo,
				Case when t.StatusID=429 then (select count(DocNO) from COM_ChequeReturn CR with(nolock) where cr.RefDocNo=D.VoucherNo) else 0 end as AdjCnt
				,C.Status,D.ChequeNumber,A.AccountName as BankAccountID,D.DebitAccount as BankAccountID_Key,
				S.AccountName as AccountID,D.CreditAccount as AccountID_Key,D.CreditAccount as ActDr,D.BankAccountID BankID,BA.AccountName BankName,D.DocumentType,convert(datetime,D.ChequeDate) ChequeDate
				,D.RefCCID,D.RefNodeID '

			if(@IsHold=1)
				set @PDRsql=@PDRsql+ ',D.HoldStatus,convert(datetime,D.HoldTillDate) HoldTillDate'
				
				set @PDRsql=@PDRsql+','''' ConvertedVoucherNO,0 ConvertedDocID,null ConvertedDocUser,convert(datetime,1) ConvertedDocDate'
				set @PDRsql=@PDRsql+','''' InterMediateVoucherNO,0 InterMediateDocID,null InterMediateDocUser,null InterMediateDocDate'
				set @PDRsql=@PDRsql+',null BouncedVoucher,null BouncedVoucherDocID,null BouncedDocUser,null BouncedDocDate,DT.BounceInvDoc,DT.PDCAmtFld,DT.PDCActionFld,BA.PDCReplaceAccount'
			
			set @PDRsql=@PDRsql+@SELECTQRY+'
				from  ACC_DocDetails D with(nolock)							
				join ACC_Accounts A with(nolock) on D.DebitAccount=A.AccountID
				join ACC_Accounts S with(nolock) on D.CreditAccount=S.AccountID
				join ADM_DocumentTypes DT with(nolock) on DT.CostCenterID=D.CostCenterID
				left join ACC_Accounts BA with(nolock) on D.BankAccountID=BA.AccountID '
				
				if(@FROMQRY!='')
					set @PDRsql=@PDRsql+' join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'+@FROMQRY

				set @PDRsql=@PDRsql+',(select  b.AccDocDetailsID,a.DocID,b.statusid from  ACC_DocDetails a with(nolock)	
				join ACC_DocDetails b with(nolock)	 on a.AccDocDetailsID=b.RefNodeid'
				
				if(@Locations!='' or @Divisions!='' or (@PDCFilterDimension IS NOT NULL AND @PDCFilterDimension >0 AND @Dimensions!=''))
					set @PDRsql=@PDRsql+' join COM_DocCCData CC with(nolock) on CC.AccDocDetailsID=a.AccDocDetailsID'

				
				set @PDRsql=@PDRsql+' where b.RefCCID=400 and a.StatusID=448 and a.DocumentType=19
				and a.'+@FilterOn+' Between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)+'
				and (a.LinkedAccDocDetailsID is null or a.LinkedAccDocDetailsID=0)
				and (b.LinkedAccDocDetailsID is null or b.LinkedAccDocDetailsID=0)'
				
				if(@BankAccountID>0)
					set @PDRsql=@PDRsql+' and (a.DebitAccount='+convert(nvarchar,@BankAccountID)+' or a.BankAccountID='+convert(nvarchar,@BankAccountID)+' or (isnull(a.IsNegative,0)=1 and a.CreditAccount='+convert(nvarchar,@BankAccountID)+')) '
				if(@Locations<>'')	
					set @PDRsql=@PDRsql+' and CC.dcCCNID2 in ('+@Locations+')'
				if(@Divisions<>'')	
					set @PDRsql=@PDRsql+' and CC.dcCCNID1 in ('+@Divisions+')'	
				if(@PDCFilterDimension IS NOT NULL AND @PDCFilterDimension >0 AND @Dimensions<>'')	
					set @PDRsql=@PDRsql+' and CC.dcCCNID'+CONVERT(NVARCHAR,(@PDCFilterDimension-50000))+' in ('+@Dimensions+')'	
				if(@CostCenterID<>'')
					set @PDRsql=@PDRsql+' and a.CostCenterID in ('+convert(nvarchar(max),@CostCenterID)+')'
				if(@Status>0)
					set @WHERE=@WHERE+' and b.StatusID = '+convert(nvarchar,@Status)

				
				set @PDRsql=@PDRsql+' ) as t'
				
			set @PDRsql=@PDRsql+' join COM_Status C with(nolock) on t.StatusID=C.StatusID '
			set @PDRsql=@PDRsql+' where (D.AccDocDetailsID=t.AccDocDetailsID or D.DocID=t.DocID) '
			
			set @sql=@sql+@PDRsql
		END
		
		SET @SortOn=' ORDER BY '+@SortOn
		set @sql=	@sql+@SortOn

		Print substring(@sql,1,4000)
		Print substring(@sql,4001,4000)
		Print substring(@sql,8001,4000)
		exec(@sql)

	
SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
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
