USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetPostingDetails]
	@CostCenterID [int] = 95,
	@PropertyID [int],
	@UnitID [int],
	@TenantID [int],
	@RentAccID [int],
	@ContractID [int] = 0,
	@Mode [int],
	@VatNode [int],
	@depCCID [int],
	@invccid [int],
	@IsApp [bit],
	@MultiIDS [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION                        
BEGIN TRY                         
SET NOCOUNT ON                        
                        
	declare @RenewRefID INT,@PropertyNodeID INT,@UnitNodeID INT,@TenantNodeID INT,@PRODUCTID INT,@RentAccBillwise BIT,@unitDim int,@PostIncome bit
	declare @PickAcc nvarchar(50),@penAccID INT,@VatAccID INT,@PendingVchrs nvarchar(max),@AdvReceivableCloseAccID INT,@AdvReceivableBillwise BIT,@disFld nvarchar(10)
	declare @dimCid int,@colnames nvarchar(max) ,@isvat bit,@Sql nvarchar(max)  ,@table nvarchar(50),@depdim int
	Exec @PropertyNodeID=[dbo].[spREN_GetDimensionNodeID]
			 @NodeID  =@PropertyID,      
			 @CostcenterID = 92,   
			 @UserID =@UserID,      
			 @LangID =@LangID
			
	if(@UnitID>0)
	BEGIN		
		Exec @UnitNodeID=[dbo].[spREN_GetDimensionNodeID]
				 @NodeID  =@UnitID,      
				 @CostcenterID = 93,   
				 @UserID =@UserID,      
				 @LangID =@LangID 
	END
	ELSE			 		 
		set @UnitNodeID=1
	
	if(@TenantID>0)
	BEGIN	
		Exec @TenantNodeID=[dbo].[spREN_GetDimensionNodeID]
				 @NodeID  =@TenantID,      
				 @CostcenterID = 94,   
				 @UserID =@UserID,      
				 @LangID =@LangID 	
	END
	ELSE
		set @TenantNodeID=1
		
	exec [spDOC_GetNode] 3,'CONTRACT',0,0,1,'GUID','Admin',1,1,@PRODUCTID output
	
	SET @PickAcc=1
	
	if(@ContractID>0 and @Mode in(1,2))
	BEGIN
		select @PickAcc=ISNULL(Value,1) from COM_CostCenterPreferences WITH(nolock)  
		where CostCenterID=@CostCenterID and Name='PickACC'
				
		set @penAccID=0
		if(@PickAcc=1)
			select @penAccID=isnull(PenaltyAccountID,0)  from REN_Property p with(NOLOCK)
			join REN_Contract c with(NOLOCK) on p.NodeID=c.PropertyID
			where c.ContractID=@ContractID
		else
			select @penAccID=isnull(PenaltyAccountID,0)  from REN_Units u with(NOLOCK)
			join REN_Contract c with(NOLOCK) on u.UnitID=c.UnitID
			where c.ContractID=	@ContractID
	END
	
	set @VatAccID=0
	if(@VatNode>0)
	BEGIN
		
		SELECT  @VatAccID=CreditAccountID FROM REN_Particulars a WITH(NOLOCK)
		where UnitID = @UnitID and ParticularID=@VatNode
		
		if(@VatAccID=0)
			SELECT  @VatAccID=CreditAccountID FROM REN_Particulars a WITH(NOLOCK)			
			where PropertyID = @PropertyID and UnitID =0 and ParticularID=@VatNode			
	END
	
	if(@CostCenterID=129)
	BEGIN
		select @PickAcc=ISNULL(Value,1) from COM_CostCenterPreferences WITH(nolock)  
		where CostCenterID=95 and Name='PickACC'
		
		set @AdvReceivableCloseAccID=0
		if(@PickAcc=1)
			select @AdvReceivableCloseAccID=isnull(AdvReceivableCloseAccID,0)  from REN_Property with(NOLOCK)
			where NodeID=@PropertyID
		else
			select @AdvReceivableCloseAccID=isnull(AdvReceivableCloseAccID,0)  from REN_Units with(NOLOCK)
			where UnitID=@UnitID
		
		SELECT @AdvReceivableBillwise=IsBillwise from ACC_Accounts WITH(NOLOCK) WHERE AccountID=@AdvReceivableCloseAccID
	END
	
	SELECT @RentAccBillwise=IsBillwise from ACC_Accounts WITH(NOLOCK) WHERE AccountID=@RentAccID
	SELECT @PostIncome=PostIncome from Ren_units WITH(NOLOCK) WHERE UnitID=@UnitID

	select @RentAccBillwise IsBillwise,@PRODUCTID PRODUCTID,@PropertyNodeID PropertyID,@UnitNodeID UnitID,@TenantNodeID TenantID,@penAccID PenAccID
	,@AdvReceivableCloseAccID AdvReceivableCloseAccID,@AdvReceivableBillwise AdvReceivableBillwise,@VatAccID VatAccID,@PostIncome PostIncome

	if(@ContractID>0 and @Mode>0)
	BEGIN
		declare @Dimesion int,@where nvarchar(max),@cntNodeID int
		SELECT @RenewRefID=RenewRefID,@cntNodeID=CCNodeID FROM REN_CONTRACT WITH(NOLOCK)                       
		where ContractID = @ContractID
		set @Dimesion=0
		set @where=''
		select @Dimesion = Value from COM_CostCenterPreferences with(nolock)
		where CostCenterID= 95  and  Name = 'LinkDocument' and Value is not null and ISNUMERIC(Value)=1
		
		if(@Dimesion>0)
		BEGIn	
			set @where=' and Dcccnid'+convert(nvarchar(max),(@Dimesion-50000))+'='+convert(nvarchar(max),@cntNodeID)
		END
		
		declare @tab table(ID INT)
		declare @tabvchrs table(vno nvarchar(200))

		while(@RenewRefID>0)
		BEGIN
			insert into @tab
			SELECT  CP.NodeID  
			
			FROM REN_ContractParticulars  CP WITH(NOLOCK)   
			LEFT JOIN REN_CONTRACT CNT WITH(NOLOCK) ON CP.CONTRACTID = CNT.CONTRACTID 
			LEFT JOIN REN_Particulars PART WITH(NOLOCK) ON CP.CCNODEID = PART.ParticularID  and  PART.PropertyID = CNT.PropertyID AND PART.UNITID = CNT.UnitID
			LEFT JOIN REN_Particulars PARTP WITH(NOLOCK) ON CP.CCNODEID = PARTP.ParticularID  and  PARTP.PropertyID = CNT.PropertyID AND PARTP.UNITID = 0
			where  CP.ContractID = @RenewRefID and 
			((PART.Refund is not null and PART.Refund =1) or (PARTP.Refund is not null and PARTP.Refund =1) )
			
			if exists(select isnull(RenewRefID,0) from REN_Contract		
			where ContractID=@RenewRefID)
				select @RenewRefID=isnull(RenewRefID,0) from REN_Contract		
				where ContractID=@RenewRefID
			ELSE
				set @RenewRefID=0
		END 

		select * from @tab a
		join REN_ContractParticulars  CP WITH(NOLOCK)   on a.id=cp.NodeID
		
		if exists(select * FROM COM_CostCenterPreferences WITH(NOLOCK)                       
		where COSTCENTERID = 95 and name='DiscountPosting' and value='true')
		BEGIN
			select @disFld=value FROM COM_CostCenterPreferences WITH(NOLOCK)                       
			where COSTCENTERID = 95 and name='Discountfield' and value is not null and value<>''
		END
		
		if exists(select ContractID FROM REN_CONTRACT WITH(NOLOCK)                       
		where RefContractID = @ContractID)
		BEGIN
		
			Select @unitDim=convert(int,value) from COM_CostCenterPreferences WITH(NOLOCK)
			where name = 'LinkDocument' AND COSTCENTERID = 93 and isnumeric(value)=1
			
			 set @PendingVchrs='SELECT a.docid,convert(datetime,docdate) docdate,amount,Type,b.DebitAccount,b.CreditAccount,dcccnid'+convert(nvarchar(max),(@unitDim-50000))+' unitNodeID '
			 if(@disFld is not null and @disFld<>'')
					set @PendingVchrs=@PendingVchrs +','+@disFld+' Disc'
			set @PendingVchrs=@PendingVchrs +'
			 FROM REN_CONTRACTDOCMAPPING a WITH(NOLOCK)
			join acc_docdetails b WITH(NOLOCK) on a.docid=b.docid
			join com_docccdata c on c.accdocdetailsID=b.accdocdetailsID '
			 if(@disFld is not null and @disFld<>'')
					set @PendingVchrs=@PendingVchrs +' join com_docnumdata d on d.accdocdetailsID=b.accdocdetailsID '
			set @PendingVchrs=@PendingVchrs +'
			where doctype=5 and contractid='+convert(nvarchar(max),@ContractID) 
			print @PendingVchrs
			exec(@PendingVchrs)
		END
		ELSE
		BEGIN			
			set @PendingVchrs='SELECT a.docid,convert(datetime,docdate) docdate,amount,Type,b.DebitAccount,b.CreditAccount '
			 if(@disFld is not null and @disFld<>'')
					set @PendingVchrs=@PendingVchrs +','+@disFld+' Disc'
			set @PendingVchrs=@PendingVchrs +' FROM REN_CONTRACTDOCMAPPING a WITH(NOLOCK)
			join acc_docdetails b WITH(NOLOCK) on a.docid=b.docid '
			 if(@disFld is not null and @disFld<>'')
					set @PendingVchrs=@PendingVchrs +' join com_docnumdata d on d.accdocdetailsID=b.accdocdetailsID '					
			set @PendingVchrs=@PendingVchrs +'  where doctype=5 and contractid='+convert(nvarchar(max),@ContractID) 
			exec(@PendingVchrs)
		END
		
		if exists(select * from adm_globalpreferences with(nolock) where name ='VATVersion')	 
			set @isvat=1
		else
			set @isvat=0
		
		set @dimCid=0
		select @dimCid=Value from COM_CostCenterPreferences WITH(NOLOCK)
		where Name='DimensionWiseContract' and costcenterid=95 and Value is not null and Value<>'' and ISNUMERIC(value)=1
		
		set @colnames=''
		SELECT @colnames=@colnames+',a.'+SYSCOLUMNNAME	FROM ADM_CostCenterDef with(nolock) 
		WHERE COSTCENTERID=95  and SYSCOLUMNNAME like 'CCNID%'
		and SysTableName='REN_ContractParticulars'
	
		SET  @Sql='SELECT  ParticularID,CreditAccountID,DebitAccountID,isnull(DiscountAmount,0) DiscountAmount,DiscountPercentage,dr.AccountName DrAccName,cr.AccountName CrAccName,Vat ,Months,TypeID'
		if(@isvat=1)
			SET  @Sql  = @Sql + ',Tx.Name TaxCategory,a.TaxCategoryID,SPT.Name SPTypeName,a.SPType,a.VatType'
		else
			SET  @Sql = @Sql + ',NULL TaxCategory,NULL TaxCategoryID,NULL SPTypeName,NULL SPType,NULL VatType'

		if (@dimCid>50000)
			set @Sql=@Sql+' ,Dim.Name Dimname'
		ELSE
			set @Sql=@Sql+' ,'''' Dimname'	
		
		SET  @Sql  = @Sql +@colnames+ ',DimNodeID,PercType
		FROM REN_Particulars a WITH(NOLOCK)
		left join ACC_Accounts dr WITH(NOLOCK) on a.DebitAccountID=dr.AccountID
		left join ACC_Accounts cr WITH(NOLOCK) on a.CreditAccountID=cr.AccountID '
		if(@isvat=1)                   
			SET  @Sql  = @Sql + ' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=a.TaxCategoryID  LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=a.SPType '
		
		if (@dimCid>50000)
		BEGIN
			select @table=tablename from adm_features with(NOLOCK) where featureid=@dimCid
			set @Sql=@Sql+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=a.DimNodeID '			
		END
		set @Sql=@Sql+' where TypeID in(4,5,6) and UnitID =0 and PropertyID = '+convert(nvarchar(max),@PropertyID)
		exec(@Sql)
		
		
		SET  @Sql='SELECT distinct ParticularID,CreditAccountID,DebitAccountID,isnull(DiscountAmount,0) DiscountAmount,DiscountPercentage,dr.AccountName DrAccName,cr.AccountName CrAccName,Vat ,Months,TypeID'
		
		if(@isvat=1)
			SET  @Sql  = @Sql + ',Tx.Name TaxCategory,a.TaxCategoryID,SPT.Name SPTypeName,a.SPType,a.VatType'
		else
			SET  @Sql = @Sql + ',NULL TaxCategory,NULL TaxCategoryID,NULL SPTypeName,NULL SPType,NULL VatType'

		if (@dimCid>50000)
			set @Sql=@Sql+' ,Dim.Name Dimname'
		ELSE
			set @Sql=@Sql+' ,'''' Dimname'	
		
		SET  @Sql  = @Sql +@colnames+ ',DimNodeID,PercType FROM REN_Particulars a WITH(NOLOCK)
		left join ACC_Accounts dr WITH(NOLOCK) on a.DebitAccountID=dr.AccountID
		left join ACC_Accounts cr WITH(NOLOCK) on a.CreditAccountID=cr.AccountID'
			if(@isvat=1)                   
			SET  @Sql  = @Sql + ' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=a.TaxCategoryID  LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=a.SPType '
		
		if (@dimCid>50000)
		BEGIN
			select @table=tablename from adm_features with(NOLOCK) where featureid=@dimCid
			set @Sql=@Sql+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=a.DimNodeID '			
		END
		set @Sql=@Sql+'  where TypeID in(4,5,6) and '
		if(@MultiIDS!='')
			set @Sql=@Sql+'UnitID in('+@MultiIDS+')'
		ELSE	
			set @Sql=@Sql+'UnitID ='+convert(nvarchar(max),@UnitID)
		print @Sql
		exec(@Sql)  
		
		if (@where<>'')
		BEGIN
			set @depdim=0
			select @depdim=Value from adm_globalpreferences WITH(NOLOCK)
			where Name='DepositLinkDimension' and Value is not null and Value<>'' and ISNUMERIC(value)=1
		
			set @Sql='SELECT D.AccDocDetailsID,D.RefCCID,D.RefNodeid,StatusID,VoucherNo,Amount,ChequeNumber,CONVERT(datetime,ChequeDate) ChequeDate,DocID,ChequeBankName,CommonNarration Narration
			,CreditAccount,DebitAccount,CommonNarration,CurrencyID,ExchangeRate,CONVERT(datetime,ChequeMaturityDate) ChequeMaturityDate
			,case when d.statusid=429 then dbo.[fnDoc_GetPendingAmount](VoucherNo) else 0 end PendingAmount  '
			
			if(@depdim>0)
				set @Sql=@Sql+',Dcccnid'+convert(nvarchar(max),(@depdim-50000))
				
			set @Sql=@Sql+'
			FROM ACC_DocDetails D with(nolock)  
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID 
			WHERE StatusID in(369,370,429)  and CreditAccount='+convert(nvarchar(max),@RentAccID)+@where
			exec(@Sql)
			
			select 1  where 1<>1
		END
		ELSE
		BEGIN
			select VoucherNo,CommonNarration,Amount,ChequeNumber,CONVERT(datetime,ChequeDate) ChequeDate,dbo.[fnDoc_GetPendingAmount](VoucherNo) PendingAmount 
			from ACC_DocDetails WITH(NOLOCK)
			where RefCCID=@CostCenterID and RefNodeid=@ContractID and StatusID=429
			
			set @PendingVchrs=''
			
			select @PendingVchrs=@PendingVchrs+dbo.[fnDoc_GetPendingVouchers](VoucherNo) 
			from ACC_DocDetails WITH(NOLOCK)
			where RefCCID=@CostCenterID and RefNodeid=@ContractID and StatusID=429
			
			insert into @tabvchrs
			exec SPSplitString @PendingVchrs,','
			
			select StatusID,VoucherNo,Amount,ChequeNumber,CONVERT(datetime,ChequeDate) ChequeDate,DocID,ChequeBankName,CommonNarration Narration
			,CreditAccount,DebitAccount,CommonNarration,CurrencyID,ExchangeRate,CONVERT(datetime,ChequeMaturityDate) ChequeMaturityDate
			,b.*
			from ACC_DocDetails a WITH(NOLOCK)
			join com_docccdata  b WITH(NOLOCK) on a.ACCDocDetailsid=b.ACCDocDetailsid
			where StatusID in(369,370) and VoucherNo in(select vno from @tabvchrs)	
		END
		
		if(@invccid>0)
		BEGIN
			set @depCCID=@depCCID-50000
			
			set @PendingVchrs='SELECT dcccnid'+convert(nvarchar,@depCCID)+' PartID'
			if(@unitDim is not null and @unitDim>50000)
				set @PendingVchrs=@PendingVchrs+',dcccnid'+convert(nvarchar,(@unitDim-50000))+' UnitID'
			set @PendingVchrs=@PendingVchrs+',sum(gross) TotInv
			FROM INV_DocDetails a with(nolock)
			join com_docccdata b on a.INVDocDetailsid=b.INVDocDetailsid
			where dynamicINVDocDetailsid is null and a.StatusID<>376 and costcenterid='+convert(nvarchar,@invccid)+' and refccid='+convert(nvarchar,@CostCenterID)+' and refnodeid='+convert(nvarchar,@ContractID)+'
			group by dcccnid'+convert(nvarchar,@depCCID)
			if(@unitDim is not null and @unitDim>50000)
				set @PendingVchrs=@PendingVchrs+',dcccnid'+convert(nvarchar,(@unitDim-50000))
			print @PendingVchrs
			exec(@PendingVchrs)
		END
		ELSE
			Select 1 Where 1<>1
			
		if(@IsApp=1)
		BEGIN
			select Reason,SRTAmount,RefundAmt,PDCRefund,Penalty,Amt,TermRemarks,SecurityDeposit,convert(datetime,TerminationPostingDate) TPD,TermPayMode,TermChequeNo,convert(datetime,TermChequeDate) TermChequeDate 
			,InputVAT,OutputVAT
			from REN_Contract WITH(NOLOCK)
			where ContractID=@ContractID
			
			select b.AccountName CrAccName,c.AccountName DrAccName,a.* from REN_TerminationParticulars a WITH(NOLOCK)
			left join acc_accounts b WITH(NOLOCK) on a.CreditAccID=b.AccountID
			left join acc_accounts c WITH(NOLOCK) on a.DebitAccID=c.AccountID
			where ContractID=@ContractID
		END	
		else
		BEGIN
			Select 1 Where 1<>1
			Select 1 Where 1<>1
		END

		
		if (@where<>'' and  exists (select Value from COM_CostCenterPreferences with(nolock) where CostCenterID= 95  and name ='TenantRecievableAmount' and Value='True'))
		begin
		
			declare @amt float		 

			
			set @Sql='select @amt=sum(DebitAmount-CreditAmount) from (
			SELECT D.Amount DebitAmount,0  CreditAmount
			FROM ACC_DocDetails D with(nolock)  
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID 
			WHERE D.DocumentType not in(14,19 ) and statusid=369 and DebitAccount=@RentAccID
			'+@where+'
			union all
			SELECT 0 DebitAmount,D.Amount  CreditAmount
			FROM ACC_DocDetails D with(nolock)  
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID 
			WHERE D.DocumentType not in(14,19 ) and statusid=369 and CreditAccount=@RentAccID
			'+@where+'
			union all
			SELECT D.Amount DebitAmount,0  CreditAmount
			FROM ACC_DocDetails D with(nolock)  
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.INVDocDetailsID=D.INVDocDetailsID 
			WHERE D.DocumentType not in(14,19 ) and statusid=369 and DebitAccount=@RentAccID
			'+@where+'
			union all
			SELECT 0 DebitAmount,D.Amount  CreditAmount
			FROM ACC_DocDetails D with(nolock)  
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.INVDocDetailsID=D.INVDocDetailsID 
			WHERE D.DocumentType not in(14,19 ) and statusid=369 and CreditAccount=@RentAccID
			'+@where+') as t'
			--print @Sql
			exec Sp_executesql @Sql,N'@RentAccID int,@amt float OUTPUT',@RentAccID,@amt OUTPUT
			select Isnull(@amt,0) as NetRecievableAmount
		end
    END
                     
COMMIT TRANSACTION                        
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine                        
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID                        
 END                        
ROLLBACK TRANSACTION                        
SET NOCOUNT OFF                          
RETURN -999                           
END CATCH
GO
