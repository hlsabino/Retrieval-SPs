USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetBillwiseDetails]
	@AccountID [int] = 0,
	@AccXml [nvarchar](max),
	@IsCredit [bit],
	@VoucherNo [nvarchar](500),
	@DocSeqNo [int],
	@LocationWhere [nvarchar](max),
	@DivisionWhere [nvarchar](max),
	@DimensionWhere [nvarchar](max),
	@DimWhere [nvarchar](max),
	@Docdate [datetime],
	@CostCenterID [int],
	@IsInv [bit],
	@LinkedVchrs [nvarchar](max),
	@getAmt [bit],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY 
   
		DECLARE @Sql nvarchar(max),@CustomQuery1 nvarchar(max),@PrefValue nvarchar(max),@Where NVARCHAR(max),
		@CustomQuery2 nvarchar(max),@CustomQuery3 nvarchar(max),@i int ,@CNT int,@inclDBCR bit,@TableName nvarchar(100)
		,@TabRef nvarchar(3),@CCID int,@xml xml,@NonAccdocs nvarchar(max),@IsFc bit,@inclUnapp bit,@inclPDCS bit,@inclfrmdoc bit
		
		IF(@VoucherNo<>'')
		BEGIN
			set @VoucherNo=replace(@VoucherNo,'''','''''')
			set @VoucherNo=replace(@VoucherNo,''''',''''',''',''')
		END
		
		if @VoucherNo<>'' and exists(select name from sys.columns where name='FromDocNo' and object_id=object_id('COM_Billwise'))
		BEGIN
			set @Sql=' if exists(select * from COM_Billwise with(nolock) where FromDocNo in('''+@VoucherNo+'''))
				set @inclfrmdoc=1
			else
				set @inclfrmdoc=0	'
			EXEC sp_executesql @Sql,N'@inclfrmdoc bit output',@inclfrmdoc output	
		END	
		else
			set @inclfrmdoc=0
				
		set @Where=''
		if exists(select value from ADM_GlobalPreferences with(nolock) where Name='BillwiseCurrency'  and value='true')
			set @IsFc=1
		else
			set @IsFc=0	
		
		--SP Required Parameters Check
		IF (@AccountID=0 and (@AccXml is null or @AccXml=''))
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		set @xml=@AccXml
		IF (@AccountID=0 and @AccXml is not null and @AccXml<>'')
		BEGIN
			select @AccountID=AccountID,@IsCredit=X.value('@Iscr','BIT'),@DocSeqNo=X.value('@DocSeqNo','int') from ACC_Accounts a WITH(NOLOCK)
			join @XML.nodes('/XML/Row') as Data(X) on X.value('@AccountID','INT')=a.AccountID
			where IsBillwise=1 
			
			if(@AccountID=0)
				return 1;
				
			if(@DocSeqNo is null)
				set @DocSeqNo=1	
		END
		ELSE IF(@AccountID>0 and @IsInv=0)
		BEGIN
			if not exists(select IsBillwise from ACC_Accounts a WITH(NOLOCK)
			where IsBillwise=1 and AccountID=@AccountID)
				return 1;
		END
		ELSE IF(@AccountID>0 and @getAmt=1)
		BEGIN
			if not exists(select IsBillwise from ACC_Accounts a WITH(NOLOCK)
			where IsBillwise=1 and AccountID=@AccountID)
				return 1;
		END
		
		set @inclDBCR=0
		if(@IsInv=0)
		BEGIN
			select @NonAccdocs=PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and PrefName='NonAccDocs'
			
			if exists(select [PrefValue] from [COM_DOCUMENTPREFERENCES] WITH(NOLOCK)
			where [CostCenterID]=@CostCenterID and [PrefName]='DbCrBills' and [PrefValue]='true')
				set @inclDBCR=1
		END
		
		
		if(@LocationWhere is not null and @LocationWhere<>'')
			set @Where=@Where+' and dcCCNID2 in ('+@LocationWhere+')'

		if(@DivisionWhere is not null and @DivisionWhere<>'')
			set @Where=@Where+' and dcCCNID1 in ('+@DivisionWhere+')'
			
		if(@DimensionWhere is not null and @DimensionWhere<>'')
		begin
			 set @PrefValue=''
			select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise Bills'  
		    
			if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
			begin
				  set @PrefValue=convert(INT,@PrefValue)-50000  						 
				  set @Where=@Where+' and dcCCNID'+@PrefValue+' in ('+@DimensionWhere+')'
			end  			
		end
		
		set @Where=@Where+@DimWhere
		
		if exists(select [PrefValue] from [COM_DOCUMENTPREFERENCES] WITH(NOLOCK)
			where [CostCenterID]=@CostCenterID and [PrefName]='UnappinBills' and [PrefValue]='true')
			set @inclUnapp=1
		else
			set @inclUnapp=0
		
		if exists(select Value from ADM_GlobalPreferences WITH(NOLOCK)
			where Name='PDCBILLS' and Value='true')
			set @inclPDCS=1
		else
			set @inclPDCS=0
			
		declare @Tab table(ID int identity(1,1) PRIMARY KEY,FeatID int,TabName nvarchar(100))
		
		insert into @Tab
		SELECT a.FeatureID,TableName
		FROM ADM_Features a WITH(NOLOCK)
		join ADM_GridViewColumns g WITH(NOLOCK) on a.FeatureID=g.CostCenterColID
		join adm_gridview gr WITH(NOLOCK) on gr.GridViewID=g.GridViewID and gr.costcenterid=99
		WHERE  IsEnabled=1  and a.FeatureID>50000
		
		set @i=0
		set @CustomQuery1=''
		set @CustomQuery2=', '
		set @CustomQuery3=', '
		select @CNT=count(id) from @Tab
		while (@i <	@CNT)
		begin
			set @i=@i+1		
			select @TableName=TabName,@CCID=FeatID from @Tab where ID=@i
	 
    		set @TabRef='A'+CONVERT(nvarchar,@i)
    		
			if(@CCID>50000)
			begin			
				set @CustomQuery3=@CustomQuery3+' '+@TabRef+'.Name as A'+convert(nvarchar,@CCID)+' ,'
				set @CCID=@CCID-50000	    	
				set @CustomQuery1=@CustomQuery1+' left join '+@TableName+' '+@TabRef+' with(nolock) on '+@TabRef+'.NodeID=B.dcCCNID'+CONVERT(nvarchar,@CCID)
				set @CustomQuery2=@CustomQuery2+' '+@TabRef+'.Name ,'
			end 
		end  
		--select @CustomQuery1,@CustomQuery2,@CustomQuery3
		--Added for Text fields for Billwise pranathi
		declare @TabText table(ID int identity(1,1) PRIMARY KEY,Syscolumnname nvarchar(100))
		
		declare @syscolumnname nvarchar(100)
		insert into @TabText
		SELECT a.Syscolumnname
		FROM ADM_Costcenterdef a WITH(NOLOCK)
		join ADM_GridViewColumns g WITH(NOLOCK) on a.CostcenterColID=g.CostCenterColID
		join adm_gridview gr WITH(NOLOCK) on gr.GridViewID=g.GridViewID and gr.costcenterid=99
		WHERE a.costcenterid=99 and systablename='COM_DocTextData'
		 
		set @i=0
		select @CNT=count(id) from @TabText
		if(@CNT>0)
			set @CustomQuery1=@CustomQuery1+' left join COM_DocTextData acctext with(nolock) on acctext.accdocdetailsid=a.accdocdetailsid and acctext.accdocdetailsid is not null
			left join COM_DocTextData invtext with(nolock) on invtext.invdocdetailsid=a.invdocdetailsid and invtext.invdocdetailsid is not null '
			
		while (@i <	@CNT)
		begin
			set @i=@i+1		 
			select @syscolumnname=Syscolumnname from @TabText where ID=@i 
			set @CustomQuery3=@CustomQuery3 +'isnull(acctext.'+@Syscolumnname+',invtext.'+@Syscolumnname+') '+ @Syscolumnname+' ,'
			set @CustomQuery2=@CustomQuery2 +'acctext.'+@Syscolumnname+',invtext.'+@Syscolumnname+' ,'
		end
		
		if(len(@CustomQuery2)>0)
		begin
			set @CustomQuery2=SUBSTRING(@CustomQuery2,0,LEN(@CustomQuery2)-1)
	    end
	    
		if(len(@CustomQuery3)>0)
		begin
			set @CustomQuery3=SUBSTRING(@CustomQuery3,0,LEN(@CustomQuery3)-1)
		end
		
		--select @CustomQuery1,@CustomQuery2,@CustomQuery3
		
		 
		select @PrefValue= [PrefValue] from [COM_DOCUMENTPREFERENCES] WITH(NOLOCK) 
		where [CostCenterID]=	@CostCenterID and [PrefName]='ShowDueBills'  
		if(@PrefValue='true')
		begin
				select @PrefValue= [PrefValue] from [COM_DOCUMENTPREFERENCES] WITH(NOLOCK) 
				where [CostCenterID]=	@CostCenterID and [PrefName]='DueBillsDays'  
				begin try
					set @PrefValue=CONVERT(nvarchar,convert(int,@PrefValue))
				end try
				begin catch
					set @PrefValue='0'
				end catch
				if(@Where is null)
					set @Where=''
				set @Where =@Where+' and DocDueDate<='+convert(nvarchar,convert(float,(@Docdate+convert(int,@PrefValue))))
		end
		   
		if(@IsCredit=1 or @inclDBCR=1)
		begin
			IF(@VoucherNo<>'')
			BEGIN
			  
				set @Sql='SELECT 0 NonAc,abs(sum(case when DocType in(40,42) then B.VatAdvance else 0 end)) VatAdvance,B.StatusID,a.CostCenterID CostCenterID, DocAbbr,DocPrefix,Docnumber,  DocNo, abs(sum(AdjAmount)) Amount,abs(sum(B.AmountFC)) AmountFC,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE SQ.AccountID='+convert(nvarchar,@AccountID)+' and   SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo in('''+@VoucherNo+'''))),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				Paid,'
				
				if(@IsFc=1)
					set @Sql=@Sql+'ISNULL((SELECT abs(SUM(SQ.amountfc)) FROM COM_Billwise SQ with(nolock) WHERE SQ.AccountID='+convert(nvarchar,@AccountID)+' and   SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo in('''+@VoucherNo+'''))),0) 
					+ISNULL((SELECT abs(SUM(SQ.amountfc)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
					Paidfc,'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+'FromDocNo,'
				set @Sql=@Sql+'[AdjCurrID],c.Name'+@CustomQuery3
				
				set @Sql=@Sql+',max(case when  IsNewReference=1 then [AdjExchRT] else 0 end) AdjExchRT,
				a.BILLNO,Convert(DATETIME, a.Billdate) as BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber, 
				Convert(DATETIME,a.ChequeDate) as ChequeDate,
				Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_Billwise B  with(nolock)
				join (select VoucherNo,CostCenterID, DocAbbr,DocPrefix,Docnumber,DocSeqNo,min(AccDocDetailsID) AccDocDetailsID,min(INVDocDetailsID) INVDocDetailsID,min(BILLNO) BILLNO ,min(Convert(DATETIME, Billdate)) BillDate, min(CommonNarration) CommonNarration,min(ChequeBankName) ChequeBankName, min(ChequeNumber) ChequeNumber, 
				min(Convert(DATETIME,ChequeDate)) ChequeDate,min(statusid) statusid,
				min(Convert(DATETIME,ChequeMaturityDate)) ChequeMaturityDate 
				from acc_docdetails with(nolock)
				where DebitAccount='+convert(nvarchar,@AccountID)+'
				group by VoucherNo,DocSeqNo,CostCenterID, DocAbbr,DocPrefix,Docnumber
				) as a on B.DocNo=a.VoucherNo and (B.DocSeqNo=a.DocSeqNo  or a.INVDocDetailsID>0)
								
				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				'+@CustomQuery1+'
			 	WHERE a.statusid in ('
			 	if(@inclUnapp=1)
			 		set @Sql=@Sql+'369,441,371'
			 	else
			 		set @Sql=@Sql+'369'
			 	if(@inclPDCS=1)	
			 		set @Sql=@Sql+',370'
			 	set @Sql=@Sql+') and  AccountID='+convert(nvarchar,@AccountID)+' and AdjAmount>0 '
				
				set @Sql=@Sql+@Where

				set @Sql=@Sql+' Group By B.StatusID,DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name'+@CustomQuery2
				
				set @Sql=@Sql+', a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,a.CostCenterID  , DocAbbr,DocPrefix,Docnumber,  
				a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+',FromDocNo'
					
				set @Sql=@Sql+' having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and   SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo in('''+@VoucherNo+''') )),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0) '
				if(@inclfrmdoc=1)
					set @Sql=@Sql+' or FromDocNo in('''+@VoucherNo+''')'
				if(@NonAccdocs is not null and @NonAccdocs<>'')
				BEGIN
					set @PrefValue=''
					select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='NetFld'  
					if(@PrefValue<>'')
					BEGIN
						set @Sql=@Sql+' UNION 
						SELECT 1 NonAc,0 VatAdvance,a.StatusID,a.CostCenterID CostCenterID, a.DocAbbr,a.DocPrefix,a.Docnumber,  a.VoucherNO, abs(sum('+@PrefValue+')) Amount,abs(sum('+@PrefValue+')) AmountFC,1 DocSeqNo,CONVERT(DATETIME,a.DocDate) DocDate ,CONVERT(DATETIME,a.DueDate) DocDueDate,
						ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno AND not (SQ.DocNo in('''+@VoucherNo+''') )),0) 
						Paid,'
						if(@IsFc=1)
							set @Sql=@Sql+'ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno AND not (SQ.DocNo in('''+@VoucherNo+''') )),0) Paidfc,'
						if(@inclfrmdoc=1)
							set @Sql=@Sql+''''','
							
						set @Sql=@Sql+'a.CurrencyID,c.Name'+@CustomQuery3
						
						set @Sql=@Sql+',a.[ExchangeRate],
						a.BILLNO,Convert(DATETIME, a.Billdate) as BillDate, a.CommonNarration,NULL, NULL, 
						NULL,NULL 
						FROM INV_docdetails a  with(nolock)
						left join INV_docdetails lnk with(nolock) on lnk.LinkedinvDocDetailsid=a.invDocDetailsid
						left join COM_Currency c with(nolock) on c.CurrencyID=a.CurrencyID
						join COM_DocCCData b with(nolock) on b.invDocDetailsid=a.invDocDetailsid
						join COM_DocNumData d with(nolock) on d.invDocDetailsid=a.invDocDetailsid
						'+@CustomQuery1+'
		 				WHERE lnk.invDocDetailsid is null and a.statusid =369 and  a.DebitAccount='+convert(nvarchar,@AccountID)
		 				
		 				set @Sql=@Sql+' and a.costcenterID in('+@NonAccdocs+')'
						
						set @Sql=@Sql+@Where

						set @Sql=@Sql+' Group By a.StatusID,a.CostCenterID, a.DocAbbr,a.DocPrefix,a.Docnumber,a.DocDate,a.DueDate , a.VoucherNO,a.[ExchangeRate], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration,a.CostCenterID    
						'+@CustomQuery2+',a.CurrencyID,c.Name
						having abs(sum('+@PrefValue+')) >ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno AND not (SQ.DocNo in('''+@VoucherNo+'''))),0) 
						
						order by DocDate,DocNo'
					END
					ELSE
						set @Sql=@Sql+'order by B.DocDate,DocNo'
				END
				ELSE
					set @Sql=@Sql+'order by B.DocDate,DocNo'
				
				print @Sql
				exec(@Sql)
				
			 SELECT [BillwiseID]
			  ,[DocNo]
			  ,b.[DocSeqNo]
			  ,[AccountID]
			  ,[AdjAmount]
			  ,[AdjCurrID]
			  ,[AdjExchRT] 
			  ,[DocType]
			  ,[IsNewReference]
			  ,[RefDocNo]
			  ,[RefDocSeqNo] 
			  ,[RefBillWiseID]
			  ,[DiscAccountID]
			  ,[DiscAmount]
			  ,[DiscCurrID]
			  ,[DiscExchRT]
			  ,[Narration]
			  ,[IsDocPDC],abs(B.VatAdvance) VatAdvance,b.AmountFC,a.CostCenterID,case when d.InvDocDetailsID is null then a.DocID else d.DocID end as DocID,
			 CONVERT(DATETIME,b.DocDate) DocDate,CONVERT(DATETIME,DocDueDate) DocDueDate,CONVERT(DATETIME,RefDocDate) RefDocDate,CONVERT(DATETIME,RefDocDueDate) RefDocDueDate
			,c.Name	from COM_Billwise b WITH(NOLOCK)
			left join COM_Currency c WITH(NOLOCK) on c.CurrencyID=b.AdjCurrID
			inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo)
			left join INV_DocDetails d  WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID
			 	where RefDocNo=@VoucherNo and RefDocSeqNo=@DocSeqNo
				and [AccountID]=@AccountID
			END
			ELSE
			BEGIN
				set @Sql='SELECT 0 NonAc,abs(sum(case when DocType in(40,42) then B.VatAdvance else 0 end)) VatAdvance,B.StatusID,a.CostCenterID CostCenterID, DocAbbr,DocPrefix,Docnumber,  DocNo, abs(sum(AdjAmount)) Amount,abs(sum(B.AmountFC)) AmountFC,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.RefDocNo=B.DocNo  AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				Paid,'
				
				if(@IsFc=1)
					set @Sql=@Sql+'ISNULL((SELECT abs(SUM(SQ.amountfc)) FROM COM_Billwise SQ with(nolock) WHERE SQ.AccountID='+convert(nvarchar,@AccountID)+' and   SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
					+ISNULL((SELECT abs(SUM(SQ.amountfc)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
					Paidfc,'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+'FromDocNo,'
				set @Sql=@Sql+'[AdjCurrID],c.Name'+@CustomQuery3
				
					
				set @Sql=@Sql+',max(case when  IsNewReference=1 then [AdjExchRT] else 0 end) [AdjExchRT],
				a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber,
				Convert(DATETIME,a.ChequeDate) as ChequeDate,
				Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_Billwise B  with(nolock)
				join (select VoucherNo,CostCenterID, DocAbbr,DocPrefix,Docnumber,DocSeqNo,min(AccDocDetailsID) AccDocDetailsID,min(INVDocDetailsID) INVDocDetailsID,min(BILLNO) BILLNO ,min(Convert(DATETIME, Billdate)) BillDate, min(CommonNarration) CommonNarration,min(ChequeBankName) ChequeBankName, min(ChequeNumber) ChequeNumber, 
				min(Convert(DATETIME,ChequeDate)) ChequeDate,min(statusid) statusid,
				min(Convert(DATETIME,ChequeMaturityDate)) ChequeMaturityDate 
				from acc_docdetails with(nolock)
				where DebitAccount='+convert(nvarchar,@AccountID)+'
				group by VoucherNo,DocSeqNo,CostCenterID, DocAbbr,DocPrefix,Docnumber
				) as a on B.DocNo=a.VoucherNo and (B.DocSeqNo=a.DocSeqNo  or a.INVDocDetailsID>0)				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				'+@CustomQuery1+'
			 	WHERE a.statusid  in ('
			 	if(@inclUnapp=1)
			 		set @Sql=@Sql+'369,441,371'
			 	else
			 		set @Sql=@Sql+'369'
			 	if(@inclPDCS=1)	
			 		set @Sql=@Sql+',370'	
			 	set @Sql=@Sql+')  and  AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount>0'
			 	
				set @Sql=@Sql+@Where
				
				set @Sql=@Sql+'Group By B.StatusID,DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name'+@CustomQuery2
				set @Sql=@Sql+', a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,a.CostCenterID , DocAbbr,DocPrefix,Docnumber,  
         		  a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+',FromDocNo'
					
				set @Sql=@Sql+' having abs(sum(AdjAmount)) >
					ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
					+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+' or FromDocNo in('''+@VoucherNo+''')'
					
				if(@NonAccdocs is not null and @NonAccdocs<>'')
				BEGIN
					set @PrefValue=''
					select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='NetFld'  
					if(@PrefValue<>'')
					BEGIN
						set @Sql=@Sql+' UNION 
						SELECT 1 NonAc,0 VatAdvance,a.StatusID,a.CostCenterID CostCenterID, a.DocAbbr,a.DocPrefix,a.Docnumber,  a.VoucherNO, abs(sum('+@PrefValue+')) Amount,abs(sum('+@PrefValue+')) AmountFC,1 DocSeqNo,CONVERT(DATETIME,a.DocDate) DocDate ,CONVERT(DATETIME,a.DueDate) DocDueDate,
						ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) 
						Paid,'
						if(@IsFc=1)
							set @Sql=@Sql+'ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) Paidfc,'
						if(@inclfrmdoc=1)
							set @Sql=@Sql+''''','
							
						set @Sql=@Sql+'a.CurrencyID,c.Name'+@CustomQuery3
						
						set @Sql=@Sql+',a.[ExchangeRate],
						a.BILLNO,Convert(DATETIME, a.Billdate) as BillDate, a.CommonNarration,NULL, NULL, 
						NULL,NULL 
						FROM INV_docdetails a  with(nolock)
						left join INV_docdetails lnk with(nolock) on lnk.LinkedinvDocDetailsid=a.invDocDetailsid
						left join COM_Currency c with(nolock) on c.CurrencyID=a.CurrencyID
						join COM_DocCCData b with(nolock) on b.invDocDetailsid=a.invDocDetailsid
						join COM_DocNumData d with(nolock) on d.invDocDetailsid=a.invDocDetailsid
						'+@CustomQuery1+'
		 				WHERE a.statusid =369 and  a.DebitAccount='+convert(nvarchar,@AccountID)
						set @Sql=@Sql+' and a.costcenterID in('+@NonAccdocs+')'
						set @Sql=@Sql+@Where

						set @Sql=@Sql+' Group By a.StatusID,a.CostCenterID, a.DocAbbr,a.DocPrefix,a.Docnumber,a.DocDate,a.DueDate , a.VoucherNO,a.[ExchangeRate], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration,a.CostCenterID  
						'+@CustomQuery2+',a.CurrencyID,c.Name
						having abs(sum('+@PrefValue+')) >ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) 
						
						order by DocDate,DocNo'
					END
					ELSE
						set @Sql=@Sql+'order by B.DocDate,DocNo'
				END
				ELSE
					set @Sql=@Sql+'order by B.DocDate,DocNo'
					
				print @Sql
				exec(@Sql)
				
				Select 1 where 1=2
			END
		END
		
		if(@IsCredit=0 or @inclDBCR=1)
		BEGIN
		
			IF(@VoucherNo<>'')
			BEGIN
				set @Sql='SELECT 0 NonAc,abs(sum(case when DocType in(40,42) then B.VatAdvance else 0 end)) VatAdvance,B.StatusID,a.CostCenterID CostCenterID, DocAbbr,DocPrefix,Docnumber,  DocNo, abs(sum(AdjAmount)) Amount,abs(sum(B.AmountFC)) AmountFC,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo in('''+@VoucherNo+''') )),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				Paid,'
				
				if(@IsFc=1)
					set @Sql=@Sql+'ISNULL((SELECT abs(SUM(SQ.amountfc)) FROM COM_Billwise SQ with(nolock) WHERE SQ.AccountID='+convert(nvarchar,@AccountID)+' and   SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo in('''+@VoucherNo+'''))),0) 
					+ISNULL((SELECT abs(SUM(SQ.amountfc)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
					Paidfc,'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+'FromDocNo,'
				set @Sql=@Sql+'[AdjCurrID],c.Name'+@CustomQuery3
				
				set @Sql=@Sql+',max(case when  IsNewReference=1 then [AdjExchRT] else 0 end) [AdjExchRT]
				,a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber,
				Convert(DATETIME,a.ChequeDate) as ChequeDate,Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_Billwise B with(nolock) 
				join (select CostCenterID, DocAbbr,DocPrefix,Docnumber,VoucherNo,DocSeqNo,min(AccDocDetailsID) AccDocDetailsID,min(INVDocDetailsID) INVDocDetailsID,min(BILLNO) BILLNO ,min(Convert(DATETIME, Billdate)) BillDate, min(CommonNarration) CommonNarration,min(ChequeBankName) ChequeBankName, min(ChequeNumber) ChequeNumber, 
				min(Convert(DATETIME,ChequeDate)) ChequeDate,min(statusid) statusid,
				min(Convert(DATETIME,ChequeMaturityDate)) ChequeMaturityDate 
				from acc_docdetails with(nolock)
				where CreditAccount='+convert(nvarchar,@AccountID)+'
				group by VoucherNo,DocSeqNo,CostCenterID, DocAbbr,DocPrefix,Docnumber
				) as a on B.DocNo=a.VoucherNo and (B.DocSeqNo=a.DocSeqNo  or a.INVDocDetailsID>0)				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID  
				'+@CustomQuery1+'
				WHERE  a.statusid in ('
			 	if(@inclUnapp=1)
			 		set @Sql=@Sql+'369,441,371'
			 	else
			 		set @Sql=@Sql+'369'
			 	if(@inclPDCS=1)	
			 		set @Sql=@Sql+',370'	
			 	set @Sql=@Sql+')   and AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount <0'

				set @Sql=@Sql+@Where

				set @Sql=@Sql+'Group By B.StatusID,DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name'+@CustomQuery2
				set @Sql=@Sql+', a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,a.CostCenterID, DocAbbr,DocPrefix,Docnumber,  
				  a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+',FromDocNo'
					
				set @Sql=@Sql+' having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo in('''+@VoucherNo+'''))),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+' or FromDocNo in('''+@VoucherNo+''')'
				if(@NonAccdocs is not null and @NonAccdocs<>'')
				BEGIN
					set @PrefValue=''
					select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='NetFld'  
					if(@PrefValue<>'')
					BEGIN
						set @Sql=@Sql+' UNION 
						SELECT 1 NonAc,0 VatAdvance,a.StatusID,a.CostCenterID CostCenterID, a.DocAbbr,a.DocPrefix,a.Docnumber,  a.VoucherNO, abs(sum('+@PrefValue+')) Amount,abs(sum('+@PrefValue+')) AmountFC,1 DocSeqNo,CONVERT(DATETIME,a.DocDate) DocDate ,CONVERT(DATETIME,a.DueDate) DocDueDate,
						ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) 
						Paid,'
						if(@IsFc=1)
							set @Sql=@Sql+'ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) paidfc,'
						if(@inclfrmdoc=1)
							set @Sql=@Sql+''''','
							
						set @Sql=@Sql+'a.CurrencyID,c.Name'+@CustomQuery3
						
						set @Sql=@Sql+',a.[ExchangeRate],
						a.BILLNO,Convert(DATETIME, a.Billdate) as BillDate, a.CommonNarration,NULL, NULL, 
						NULL,NULL 
						FROM INV_docdetails a  with(nolock)
						left join INV_docdetails lnk with(nolock) on lnk.LinkedinvDocDetailsid=a.invDocDetailsid
						left join COM_Currency c with(nolock) on c.CurrencyID=a.CurrencyID
						join COM_DocCCData b with(nolock) on b.invDocDetailsid=a.invDocDetailsid
						join COM_DocNumData d with(nolock) on d.invDocDetailsid=a.invDocDetailsid
						'+@CustomQuery1+'
		 				WHERE a.statusid =369 and  a.CreditAccount='+convert(nvarchar,@AccountID)
						set @Sql=@Sql+' and a.costcenterID in('+@NonAccdocs+')'
						set @Sql=@Sql+@Where

						set @Sql=@Sql+' Group By a.StatusID,a.CostCenterID, a.DocAbbr,a.DocPrefix,a.Docnumber,a.DocDate,a.DueDate , a.VoucherNO,a.[ExchangeRate], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration,a.CostCenterID 
						'+@CustomQuery2+',a.CurrencyID,c.Name
						having abs(sum('+@PrefValue+')) >ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) 
						
						order by DocDate,DocNo'
					END
					ELSE
						set @Sql=@Sql+'order by B.DocDate,DocNo'
				END
				ELSE
					set @Sql=@Sql+'order by B.DocDate,DocNo'
				
					print @Sql
				exec(@Sql)

				SELECT [BillwiseID]
     			  ,[DocNo]
				  ,b.[DocSeqNo]
				  ,[AccountID]
				  ,[AdjAmount]
				  ,[AdjCurrID]
				  ,[AdjExchRT] 
				  ,[DocType]
				  ,[IsNewReference]
				  ,[RefDocNo]
				  ,[RefDocSeqNo] 
				  ,[RefBillWiseID]
				  ,[DiscAccountID]
				  ,[DiscAmount]
				  ,[DiscCurrID]
				  ,[DiscExchRT]
				  ,[Narration]
				  ,[IsDocPDC],abs(B.VatAdvance) VatAdvance,b.AmountFC,a.CostCenterID,case when d.InvDocDetailsID is null then a.DocID else d.DocID end as DocID,
				CONVERT(DATETIME,b.DocDate) DocDate,CONVERT(DATETIME,DocDueDate) DocDueDate,CONVERT(DATETIME,RefDocDate) RefDocDate,CONVERT(DATETIME,RefDocDueDate) RefDocDueDate
				,c.Name	from COM_Billwise b  WITH(NOLOCK)
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo)
				left join INV_DocDetails d  WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID
				left join COM_Currency c WITH(NOLOCK) on c.CurrencyID=b.AdjCurrID
		 		where RefDocNo=@VoucherNo and RefDocSeqNo=@DocSeqNo
			 and [AccountID]=@AccountID
			END
			ELSE
			BEGIN
				set @Sql='SELECT 0 NonAc,abs(sum(case when DocType in(40,42) then B.VatAdvance else 0 end)) VatAdvance,B.StatusID,a.CostCenterID CostCenterID, DocAbbr,DocPrefix,Docnumber,  DocNo, abs(sum(AdjAmount)) Amount,abs(sum(B.AmountFC)) AmountFC,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				Paid,'
				
				if(@IsFc=1)
					set @Sql=@Sql+'ISNULL((SELECT abs(SUM(SQ.amountfc)) FROM COM_Billwise SQ with(nolock) WHERE SQ.AccountID='+convert(nvarchar,@AccountID)+' and   SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
					+ISNULL((SELECT abs(SUM(SQ.amountfc)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
					Paidfc,'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+'FromDocNo,'
				set @Sql=@Sql+'[AdjCurrID],c.Name'+@CustomQuery3
				
				set @Sql=@Sql+',max(case when  IsNewReference=1 then [AdjExchRT] else 0 end) [AdjExchRT]
				,a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber, 
				Convert(DATETIME,a.ChequeDate) as ChequeDate,Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_Billwise B  with(nolock)
				join (select VoucherNo,CostCenterID, DocAbbr,DocPrefix,Docnumber,DocSeqNo,min(AccDocDetailsID) AccDocDetailsID,min(INVDocDetailsID) INVDocDetailsID,min(BILLNO) BILLNO ,min(Convert(DATETIME, Billdate)) BillDate, min(CommonNarration) CommonNarration,min(ChequeBankName) ChequeBankName, min(ChequeNumber) ChequeNumber, 
				min(Convert(DATETIME,ChequeDate)) ChequeDate,min(statusid) statusid,
				min(Convert(DATETIME,ChequeMaturityDate)) ChequeMaturityDate 
				from acc_docdetails with(nolock)
				where CreditAccount='+convert(nvarchar,@AccountID)+'
				group by VoucherNo,DocSeqNo,CostCenterID, DocAbbr,DocPrefix,Docnumber
				) as a on B.DocNo=a.VoucherNo and (B.DocSeqNo=a.DocSeqNo  or a.INVDocDetailsID>0)				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				'+@CustomQuery1+'
		 		WHERE a.statusid  in ('
			 	if(@inclUnapp=1)
			 		set @Sql=@Sql+'369,441,371'
			 	else
			 		set @Sql=@Sql+'369'
			 	if(@inclPDCS=1)	
			 		set @Sql=@Sql+',370'	
			 	set @Sql=@Sql+')   and  AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount <0'

				set @Sql=@Sql+@Where


				set @Sql=@Sql+'Group By B.StatusID,DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name'+@CustomQuery2
				set @Sql=@Sql+',a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName, a.ChequeNumber, a.ChequeDate,a.CostCenterID, DocAbbr,DocPrefix,Docnumber,  a.ChequeMaturityDate 
				'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+',FromDocNo'
					
				set @Sql=@Sql+' having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				'
				if(@inclfrmdoc=1)
					set @Sql=@Sql+' or FromDocNo in('''+@VoucherNo+''')'
				if(@NonAccdocs is not null and @NonAccdocs<>'')
				BEGIN
					set @PrefValue=''
					select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='NetFld'  
					if(@PrefValue<>'')
					BEGIN
						set @Sql=@Sql+' UNION  
						SELECT 1 NonAc,0 VatAdvance,a.StatusID,a.CostCenterID CostCenterID, a.DocAbbr,a.DocPrefix,a.Docnumber,  a.VoucherNO, abs(sum('+@PrefValue+')) Amount,abs(sum('+@PrefValue+')) AmountFC,1 DocSeqNo,CONVERT(DATETIME,a.DocDate) DocDate ,CONVERT(DATETIME,a.DueDate) DocDueDate,
						ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) 
						Paid,'
						if(@IsFc=1)
							set @Sql=@Sql+'ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) paidfc,'
						if(@inclfrmdoc=1)
							set @Sql=@Sql+''''','
							
						set @Sql=@Sql+'a.CurrencyID,c.Name'+@CustomQuery3
						
						set @Sql=@Sql+',a.[ExchangeRate],
						a.BILLNO,Convert(DATETIME, a.Billdate) as BillDate, a.CommonNarration,NULL, NULL, 
						NULL,NULL 
						FROM INV_docdetails a  with(nolock)
						left join INV_docdetails lnk with(nolock) on lnk.LinkedinvDocDetailsid=a.invDocDetailsid
						left join COM_Currency c with(nolock) on c.CurrencyID=a.CurrencyID
						join COM_DocCCData b with(nolock) on b.invDocDetailsid=a.invDocDetailsid
						join COM_DocNumData d with(nolock) on d.invDocDetailsid=a.invDocDetailsid
						'+@CustomQuery1+'
		 				WHERE a.statusid =369 and  a.CreditAccount='+convert(nvarchar,@AccountID)
						set @Sql=@Sql+' and a.costcenterID in('+@NonAccdocs+')'
						set @Sql=@Sql+@Where

						set @Sql=@Sql+' Group By a.StatusID,a.CostCenterID, a.DocAbbr,a.DocPrefix,a.Docnumber,a.DocDate,a.DueDate , a.VoucherNO,a.[ExchangeRate], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration,a.CostCenterID    
						'+@CustomQuery2+',a.CurrencyID,c.Name
						having abs(sum('+@PrefValue+')) >ISNULL((SELECT abs(SUM(SQ.Amount)) FROM COM_BillWiseNonAcc SQ with(nolock) WHERE  SQ.RefDocNo=a.voucherno ),0) 
						
						order by DocDate,DocNo'
					END
					ELSE
						set @Sql=@Sql+'order by B.DocDate,DocNo'
				END
				ELSE
					set @Sql=@Sql+'order by B.DocDate,DocNo'
				
				print @Sql	
				exec(@Sql)
				
				Select 1 where 1=2
			END
		END
		
		SELECT a.FeatureID CostCenterID,Name UserColumnName,Name,'DIM' UserColumnType, g.ColumnWidth, g.ColumnOrder, 'False' IsEditable                        
		FROM ADM_Features a WITH(NOLOCK)
		join ADM_GridViewColumns g WITH(NOLOCK) on a.FeatureID=g.CostCenterColID
		join adm_gridview gr WITH(NOLOCK) on gr.GridViewID=g.GridViewID and gr.costcenterid=99
		WHERE  IsEnabled=1  and a.FeatureID>50000
		union
		select a.CostCenterColID,isnull(lr.ResourceData,UserColumnName) UserColumnName, SyscolumnName Name, UserColumnType, g.ColumnWidth, g.ColumnOrder, A.IsEditable                        
		from adm_costcenterdef a WITH(NOLOCK) 
		join ADM_GridViewColumns g WITH(NOLOCK) on a.CostCenterColID=g.CostCenterColID
		join adm_gridview gr WITH(NOLOCK) on gr.GridViewID=g.GridViewID and gr.costcenterid=99  
		left join COM_LanguageResources lr WITH(NOLOCK) on  lr.ResourceID= a.ResourceID and lr.LanguageID=1                    
		where a.CostCenterID=99                     
		order by g.ColumnOrder                         		
		if(@AccXml is not null and @AccXml<>'')
		BEGIN
			select distinct AccountID,AccountName,@AccountID SelectedAcc,@DocSeqNo SelSeq from ACC_Accounts a WITH(NOLOCK)
			join @XML.nodes('/XML/Row') as Data(X) on X.value('@AccountID','INT')=a.AccountID
			where IsBillwise=1
		END
		ELSE if(@getAmt=1)
		BEGIN
			select @NonAccdocs=AccountName from ACC_Accounts a WITH(NOLOCK)
			where AccountID=@AccountID
			
			Select @NonAccdocs AccountName,SUM(AdjAmount)AdjAmount,SUM(AmountFC)AmountFC,max(AdjCurrID)AdjCurrID,max(AdjExchRT)AdjExchRT,Convert(datetime,max(Docdate)) Docdate FROM COM_Billwise B  with(nolock)
			Where AccountID=@AccountID and docno=@VoucherNo
		END	
		ELSE		
			Select 1 where 1=2
			
		if(@IsInv=1)
		BEGIN	
			Select RefDocNo,RefDocSeqNo,IsNewReference,AmountFC,Narration FROM COM_Billwise B  with(nolock)
			Where AccountID=@AccountID and docno=@VoucherNo
		END
		ELSE
			Select 1 where 1=2
			
		if(@IsInv=0 and exists(select [PrefValue] from [COM_DOCUMENTPREFERENCES] WITH(NOLOCK)
			where [CostCenterID]=	@CostCenterID and [PrefName]='ShowNewReference' and [PrefValue]='true'))  
		BEGIN
			set @Sql='SELECT  case when d.InvDocDetailsID is null then a.DocID else d.DocID end as DocID,a.CostCenterID,DocNo, abs(sum(AdjAmount)) Amount,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
			ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+'  and  SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
			+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+'  and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
			Paid
			FROM COM_Billwise B  with(nolock)
			inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo and (B.DocSeqNo=temp.DocSeqNo or temp.DocSeqNo=0))
			left join INV_DocDetails d WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID
			WHERE a.statusid =369  and  AccountID='+convert(nvarchar,@AccountID)  
			if(@IsCredit=1)
				set @Sql=@Sql+'and AdjAmount <0 '
			else
				set @Sql=@Sql+'and AdjAmount >0 '
			set @Sql=@Sql+@Where
			set @Sql=@Sql+'
			Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,d.DocID,a.DocID,a.CostCenterID,d.InvDocDetailsID
			having abs(sum(AdjAmount)) >
			ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)
			
			if(@inclfrmdoc=1)
				set @Sql=@Sql+' and SQ.fromDocNo  not in('''+@VoucherNo+''')'
			
			set @Sql=@Sql+' and  SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
			+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+convert(nvarchar,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
			order by B.DocDate,DocNo'
			print @Sql
			exec(@Sql)
		END
		ELSE if(@IsInv=1 and @LinkedVchrs<>'' and exists(select [PrefValue] from [COM_DOCUMENTPREFERENCES] WITH(NOLOCK) 
			where [CostCenterID]=	@CostCenterID and [PrefName]='AutoAdjReptsOrds' and [PrefValue]='true'))  
		BEGIN
			declare @tabvchrs table(ID INT IDENTITY(1,1) PRIMARY KEY,vchrs nvarchar(200),typ int)
			
			insert into @tabvchrs(vchrs)
			exec SPSplitString @LinkedVchrs,','  
			
			update @tabvchrs
			set typ=1
			
			set @cnt=1
			while exists(select vchrs from @tabvchrs where typ=@cnt)
			BEGIN
				insert into @tabvchrs
				select b.voucherno,@cnt+1 from INV_DocDetails a WITH(NOLOCK)
				join INV_DocDetails b WITH(NOLOCK) on a.linkedInvDocdetailsid=b.InvDocdetailsid
				join @tabvchrs c on a.VoucherNo=c.vchrs 
				where c.typ=@cnt and a.linkedInvDocdetailsid>0
				
				set @cnt=@cnt+1
			END
			
			select a.docno,a.DocSeqNo,isnull(sum(a.amount),0) amount from COM_BillWiseNonAcc a WITH(NOLOCK)
			join @tabvchrs b on a.refdocno=b.vchrs
			group by a.docno,a.DocSeqNo
			
		END
SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
 
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
