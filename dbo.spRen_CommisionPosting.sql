USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRen_CommisionPosting]
	@accID [bigint],
	@CostCenterID [int],
	@DocID [bigint],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN  
   
declare @totalPreviousPayRcts bigint,@I int,@CNT int,@DocIDValue BIGINT,@CCID INT,@DocXml nvarchar(max),@dbAcc BIGINT,@CrAcc BIGINT,@amt float,@DocDate datetime,@CP nvarchar(max),@CA nvarchar(max),@sql nvarchar(max)
declare @return_value int,@Prefix nvarchar(200),@RoleID bigint,@UserName nvarchar(500),@CompanyGUID nvarchar(50),@start datetime,@end datetime,@days int,@VatAmt float,@loc bigint,@invID bigint,@vno nvarchar(max),@documenttype int
declare @lldim nvarchar(50),@MPDim  nvarchar(50),@MPDimVal  nvarchar(50),@lltabname nvarchar(50),@UFtabname nvarchar(50),@CPFld nvarchar(50),@UfDim nvarchar(50),@PrdID int,@PartDim nvarchar(50),@PartDimVal int,@VatAcc int,@seqNo int

set @lldim=0
select @lldim=value from com_costcenterpreferences WITH(NOLOCK)
WHere costcenterid=92 and name ='Landlord' and value is not null and value<>'' and isnumeric(value)=1

set @MPDim=0
select @MPDim=value from com_costcenterpreferences WITH(NOLOCK)
WHere costcenterid=92 and name ='ManagePropDim' and value is not null and value<>'' and isnumeric(value)=1

set @MPDimVal=0
select @MPDimVal=value from com_costcenterpreferences WITH(NOLOCK)
WHere costcenterid=92 and name ='ManagePropVal' and value is not null and value<>'' and isnumeric(value)=1

set @CPFld=''
select @CPFld=value from com_costcenterpreferences WITH(NOLOCK)
WHere costcenterid=92 and name ='LLComsPer' and value is not null and value<>''

set @UfDim=''
select @UfDim=value from com_costcenterpreferences WITH(NOLOCK)
WHere costcenterid=93 and name ='LinkDocument' and value is not null and value<>'' and isnumeric(value)=1

set @PartDim=0
select @PartDim=value from adm_globalpreferences WITH(NOLOCK)
WHere name ='DepositLinkDimension' and value is not null and value<>'' and isnumeric(value)=1

set @VatAcc=0
select @VatAcc=value from com_costcenterpreferences WITH(NOLOCK)
WHere name ='VatAccountID' and value is not null and value<>'' and isnumeric(value)=1



exec [spDOC_GetNode] @PartDim,'Rent',0,0,1,'GUID','Admin',1,1,@PartDimVal output
	
select @lltabname=tablename from adm_features WITH(NOLOCK) where featureid=@lldim
select @UFtabname=tablename from adm_features WITH(NOLOCK) where featureid=@UfDim

set @sql='select @amt=a.Amount,@dbAcc=AdvanceRentAccountID,@CrAcc=RentalIncomeAccountID,@CP=u.ComPer,@CA=u.LLComsAccID,@DocDate=DocDate
,@seqNo=a.DocSeqNo
,@vno=a.Voucherno,@documenttype=a.DocumentType
from  Acc_docDetails a with(nolock)    
join com_docCCdata CC with(nolock) on CC.accdocdetailsID=a.accdocdetailsID
join '+@UFtabname+' uf WITH(NOLOCK) on cc.dcccnid'+Convert(nvarchar(max),(@UfDim-50000))+'=uf.nodeid
join Ren_units u WITH(NOLOCK) on uf.nodeid=u.ccnodeid
join com_ccccdata ucc WITH(NOLOCK) on ucc.costcenterid=93 and ucc.nodeid=u.unitid
join '+@lltabname+' ll WITH(NOLOCK) on u.LandlordID=ll.nodeid
where a.accdocdetailsID='+Convert(nvarchar(max),@accID)+'
  and ucc.ccnid'+Convert(nvarchar(max),(@MPDim-50000))+'='+Convert(nvarchar(max),@MPDimVal)+' and CC.dcccnid'+Convert(nvarchar(max),(@PartDim-50000))+'='+Convert(nvarchar(max),@PartDimVal)
 print @sql
exec SP_ExecuteSql  @sql,N'@amt float OUTPUT,@dbAcc BIGINT OUTPUT,@CrAcc BIGINT OUTPUT,@CP nvarchar(max) OUTPUT,@CA BIGINT OUTPUT,@DocDate datetime OUTPUT,@seqNo INT OUTPUT,@CompanyGUID nvarchar(max) OUTPUT,@vno nvarchar(max) OUTPUT,@documenttype int OUTPUT',@amt OUTPUT,@dbAcc OUTPUT,@CrAcc OUTPUT,@CP OUTPUT,@CA OUTPUT,@DocDate OUTPUT,@seqNo OUTPUT,@CompanyGUID OUTPUT,@vno OUTPUT,@documenttype OUTPUT

select @CompanyGUID=CompanyGUID from com_docid
where id= @DocID

if(@amt is not null and @amt>0)
BEGIN 
		if(@documenttype=19)
		BEGIN
			select @DocDate=b.DocDate from  Acc_docDetails a with(nolock) 
			join ADM_DocumentTypes c on a.CostCenterID=c.CostCenterID
			join Acc_docDetails b with(nolock) on a.AccDocDetailsID=b.RefNodeid			
			where a.CostCenterID=@CostCenterID and a.DOCID=@DocID and a.AccDocDetailsID=@accID
			 and b.RefCCID=400 and b.CostCenterID=c.ConvertAs
		END
		
		exec [spDOC_GetNode] 3,'CONTRACT',0,0,1,'GUID','Admin',1,1,@PrdID output

		select @RoleID=RoleID,@UserName=UserName from adm_userrolemap WITH(NOLOCK)  
		where userid=@UserID  
	
		set @CCID=0
		select @CCID=value from com_costcenterpreferences WITH(NOLOCK)
		WHere costcenterid=92 and name ='LLPostDoc' and value is not null and value<>'' and isnumeric(value)=1

		SELECT @DocIDValue=0
		
		select @DocIDValue=DOCID from inv_docdetails	WITH(NOLOCK)
		where refnodeid=@accID and CostCenterID = @CCID 
		
		if(@DocIDValue=0)
		BEGIN
			select @DocIDValue=DOCID from inv_docdetails	WITH(NOLOCK)
			where RefNo=@vno and Description=@seqNo and CostCenterID = @CCID 
		END
		
		set @Prefix=''
		EXEC [sp_GetDocPrefix] '',@DocDate,@CCID,@Prefix output

		set @DocXml='<Row><Transactions  DocDetailsID="0"  DocSeqNo="1"  LinkedInvDocDetailsID= ""  LinkedFieldName= "" ProductID="'+Convert(nvarchar(max),@PrdID)+'" CurrencyID="1" ExchangeRate="1" Unit="1" UOMConversion="1" CreditAccount="'+convert(nvarchar,@CrAcc)+'" DebitAccount ="'+convert(nvarchar,@dbAcc)+'"  Quantity="1" CommonNarration=""   CanRecur="0"  Rate="'+convert(nvarchar,@amt)+'"  Gross="'+convert(nvarchar,@amt)+'"  LineNarration="" ></Transactions>  <Numeric Query=" dcNum51='+convert(nvarchar,@amt)+',dcCalcNum51='+convert(nvarchar,@amt)+',dcCalcNum52=0,dcNum52=0,dcNum60=0,dcCalcNum60=0,dcNum53=0,dcCalcNum53=0,dcNum61=0,dcCalcNum61=0," /> <Alpha  Query="dcAlpha153='''',dcAlpha152=''Service''," /> <CostCenters  /> <EXTRAXML/> <AccountsXML><Accounts CreditAccount="'+convert(nvarchar,@CrAcc)+'"  DebitAccount="'+convert(nvarchar,@dbAcc)+'" Amount="'+convert(nvarchar,@amt)+'" AmtFc="'+convert(nvarchar,@amt)+'"  CurrencyID="1" ExchangeRate="1"  ></Accounts></AccountsXML> </Row>'
       
		EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @CCID,      
			  @DocID = @DocIDValue,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = '',      
			  @InvDocXML =@DocXml,      
			  @BillWiseXML = N'',      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = '',       
			  @IsImport = 0,      
			  @LocationID = 0,      
			  @DivisionID = 0 ,      
			  @WID = 0,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 400,    
			  @RefNodeid  = @accID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID 
		
		if(@return_value=-999)
			return @return_value
			
		set  @sql='update a set '
		
		select @sql=@sql+name+'=b.'+name+',' from sys.columns
		where object_id=object_id('com_docccdata')			
		and name like 'dcCCNID%'
		set @sql=Substring(@sql,0,len(@sql))
		
		set @sql=@sql+' from inv_docdetails i
		join com_docccdata a on i.invdocdetailsID=a.invdocdetailsID
		join com_docccdata b on b.accdocdetailsID='+Convert(nvarchar(max),@accID)+'
		where i.CostCenterID ='+Convert(nvarchar(max),@CCID)+'  and i.docid='+Convert(nvarchar(max),@return_value)
		 print @sql
		 exec(@sql)
		 
		update inv_docdetails	
		set RefNo=@vno,Description=@seqNo
		where CostCenterID = @CCID and docid=@return_value
			
		set @CCID=0	
		select @CCID=value from com_costcenterpreferences WITH(NOLOCK)
		WHere costcenterid=92 and name ='ServiceINVDOC' and value is not null and value<>'' and isnumeric(value)=1
			
		if(@CCID>0 and isnumeric(@CP)=1)
		BEGIN
			
			set @amt=(@amt*@CP)/100
			set @VatAmt=round((@amt*5)/100,2)
			set @amt=round(@amt,2)
			
			set @dbAcc=@CrAcc
			if(isnumeric(@CA)=1 and @CA>1)
				set @CrAcc=convert(bigint,@CA)
			else
			BEGIN
				raiserror('Define Commission Account',16,1)
			END
			
			if not (isnumeric(@VatAcc)=1 and @VatAcc>1)
			BEGIN
				raiserror('Define Vat Account',16,1)
			END
			
			set @DocIDValue=0
			select @DocIDValue=DOCID from inv_docdetails	WITH(NOLOCK)
			where refnodeid=@accID and CostCenterID = @CCID 
			
			if(@DocIDValue=0)
			BEGIN
				select @DocIDValue=DOCID from inv_docdetails	WITH(NOLOCK)
				where RefNo=@vno and Description=@seqNo and CostCenterID = @CCID 
			END
					
			set @DocXml='<Row><Transactions  DocDetailsID="0"  DocSeqNo="1"  LinkedInvDocDetailsID= ""  LinkedFieldName= "" ProductID="'+Convert(nvarchar(max),@PrdID)+'" CurrencyID="1" ExchangeRate="1" Unit="1" UOMConversion="1" CreditAccount="'+convert(nvarchar,@CrAcc)+'" DebitAccount ="'+convert(nvarchar,@dbAcc)+'"  Quantity="1" CommonNarration=""   CanRecur="0"  Rate="'+convert(nvarchar,@amt)+'"  Gross="'+convert(nvarchar,@amt)+'"  LineNarration="" ></Transactions>  <Numeric Query=" dcNum51='+convert(nvarchar,@amt)+',dcCalcNum51='+convert(nvarchar,@amt)+',dcCalcNum52=5,dcNum52=5,dcNum60=5,dcCalcNum60=5,dcNum53='+convert(nvarchar,@VatAmt)+',dcCalcNum53='+convert(nvarchar,@VatAmt)+',dcNum61='+convert(nvarchar,@VatAmt)+',dcCalcNum61='+convert(nvarchar,@VatAmt)+'," /> <Alpha  Query="dcAlpha153='''',dcAlpha152=''Service''," /> <CostCenters  /> <EXTRAXML/> <AccountsXML><Accounts CreditAccount="'+convert(nvarchar,@CrAcc)+'"  DebitAccount="'+convert(nvarchar,@dbAcc)+'" Amount="'+convert(nvarchar,@amt)+'" AmtFc="'+convert(nvarchar,@amt)+'"  CurrencyID="1" ExchangeRate="1"  ></Accounts>'

			if(@VatAmt>0)
				set @DocXml=@DocXml+'<Accounts CreditAccount="'+convert(nvarchar,@VatAcc)+'"  DebitAccount="'+convert(nvarchar,@dbAcc)+'" Amount="'+convert(nvarchar,@VatAmt)+'" AmtFc="'+convert(nvarchar,@VatAmt)+'"  CurrencyID="1" ExchangeRate="1"  ></Accounts>'
			
			set @DocXml=@DocXml+'</AccountsXML> </Row>'
       
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @CCID,      
			  @DocID = @DocIDValue,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = '',      
			  @InvDocXML =@DocXml,      
			  @BillWiseXML = N'',      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = '',       
			  @IsImport = 0,      
			  @LocationID = 0,      
			  @DivisionID = 0 ,      
			  @WID = 0,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 400,    
			  @RefNodeid  = @accID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID 	
				  
			if(@return_value=-999)
				return @return_value		  
		
			set  @sql='update a	set '			
			select @sql=@sql+name+'=b.'+name+',' from sys.columns
			where object_id=object_id('com_docccdata')			
			and name like 'dcCCNID%'
			set @sql=Substring(@sql,0,len(@sql))
			
			set @sql=@sql+' from inv_docdetails i
			join com_docccdata a on i.invdocdetailsID=a.invdocdetailsID
			join com_docccdata b on b.accdocdetailsID='+Convert(nvarchar(max),@accID)+'
			where i.CostCenterID ='+Convert(nvarchar(max),@CCID)+'  and i.docid='+Convert(nvarchar(max),@return_value)
			exec(@sql)
			
			update inv_docdetails	
			set RefNo=@vno,Description=@seqNo
			where CostCenterID = @CCID and docid=@return_value
        END
	END  
	ELSE
	BEGIN
		select @RoleID=RoleID,@UserName=UserName from adm_userrolemap WITH(NOLOCK)  
		where userid=@UserID  
		
		set @CCID=0
		select @CCID=value from com_costcenterpreferences WITH(NOLOCK)
		WHere costcenterid=92 and name ='LLPostDoc' and value is not null and value<>'' and isnumeric(value)=1

		SELECT @DocIDValue=0
		
		select @DocIDValue=DOCID from inv_docdetails	WITH(NOLOCK)
		where refccid=400 and refnodeid=@accID and CostCenterID = @CCID 
		
		if(@DocIDValue=0)
		BEGIN
			select @DocIDValue=DOCID from inv_docdetails	WITH(NOLOCK)
			where refccid=400 and RefNo=@vno and Description=@seqNo and CostCenterID = @CCID 
		END
		
		if(@DocIDValue>0)
		BEGIN
			EXEC @return_value = [spDOC_DeleteInvDocument]      
			@CostCenterID = @CCID,      
			@DocPrefix = '',      
			@DocNumber = '',  
			@DOCID = @DocIDValue,  
			@SysInfo ='CommissionDelete', 
			@AP ='CommissionDelete',    
			@UserID = 1,      
			@UserName = @UserName,      
			@LangID = 1,
			@RoleID=1
		END
		
		set @CCID=0
		select @CCID=value from com_costcenterpreferences WITH(NOLOCK)
		WHere costcenterid=92 and name ='ServiceINVDOC' and value is not null and value<>'' and isnumeric(value)=1

		SELECT @DocIDValue=0
		
		select @DocIDValue=DOCID from inv_docdetails	WITH(NOLOCK)
		where refnodeid=@accID and CostCenterID = @CCID 
		
		if(@DocIDValue=0)
		BEGIN
			select @DocIDValue=DOCID from inv_docdetails	WITH(NOLOCK)
			where RefNo=@vno and Description=@seqNo and CostCenterID = @CCID 
		END
		
		if(@DocIDValue>0)
		BEGIN
			EXEC @return_value = [spDOC_DeleteInvDocument]      
			@CostCenterID = @CCID,      
			@DocPrefix = '',      
			@DocNumber = '',  
			@DOCID = @DocIDValue,  
			@SysInfo ='CommissionDelete', 
			@AP ='CommissionDelete',    
			@UserID = 1,      
			@UserName = @UserName,      
			@LangID = 1,
			@RoleID=1
		END
	END          
END   
  
  
GO
