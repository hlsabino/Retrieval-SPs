USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_OpeningDownPayment]
	@VoucherNo [nvarchar](200),
	@CostCenterID [int],
	@DocID [bigint],
	@InvDocDetID [bigint],
	@crAcc [bigint],
	@DrAcc [bigint],
	@DocDate [datetime],
	@PostCredit [bit],
	@LocationID [int],
	@DivisionID [int],
	@CompanyGUID [nvarchar](200),
	@UserName [nvarchar](500),
	@RoleID [bigint],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN  
   
declare @DocIDValue BIGINT,@CCID INT,@DocXml nvarchar(max),@amt float,@sql nvarchar(max)
declare @return_value int,@Prefix nvarchar(200)

	select @amt=isnull(sum(a.Gross),0)
	from  Inv_docDetails a with(nolock)   
	where CostCenterID=@CostCenterID and  DocID=@DocID 

	insert into COM_BillWiseNonAcc(DocNo,DocSeqNo,Amount,AccountID,RefDocNO)
	SELECT @VoucherNo,1,@amt, @CrAcc,''

	if(@amt is not null and @amt>0)
	BEGIN 
		set @CCID=40016
		SELECT @DocIDValue=0
		
		select @DocIDValue=DOCID from acc_docdetails WITH(NOLOCK)
		where refccid=300 and refnodeid=@DocID and CostCenterID = @CCID 

		set @Prefix=''
		EXEC [sp_GetDocPrefix] '',@DocDate,@CCID,@Prefix output,@InvDocDetID,0,0,0,1
			
		set @DocXml='<DocumentXML><Row><AccountsXML></AccountsXML><Transactions DocSeqNo="1" DocDetailsID="0" LinkedInvDocDetailsID="" LinkedFieldName="" DebitAccount="'+Convert(nvarchar(max),@DrAcc)+'" CreditAccount="-100" Amount="'+Convert(nvarchar(max),@amt)+'" AmtFc="'+Convert(nvarchar(max),@amt)+'" CurrencyID="1" ExchangeRate="1" LineNarration="" ChequeNumber=""  ></Transactions><Numeric Query="" ></Numeric><Alpha Query="" ></Alpha><CostCenters Query="" ></CostCenters><EXTRAXML>'
		if exists(select * from ACC_Accounts WITH(NOLOCK) where AccountID=@DrAcc and IsBillwise=1)
		BEGIN
			set @DocXml=@DocXml+'<BillWise> <Row DocSeqNo="1" AccountID="'+Convert(nvarchar(max),@DrAcc)+'" AmountFC="'+Convert(nvarchar(max),@amt)+'" AdjAmount="'+Convert(nvarchar(max),@amt)+'" AdjCurrID="1" AdjExchRT="1" IsNewReference="1" Narration="" IsDocPDC="0"  ></Row> </BillWise>'
		END
		set @DocXml=@DocXml+'</EXTRAXML></Row>'
		if(@PostCredit=1)
		BEGIN
			set @DocXml=@DocXml+'<Row><AccountsXML></AccountsXML><Transactions DocSeqNo="2" DocDetailsID="0" LinkedInvDocDetailsID="" LinkedFieldName="" DebitAccount="-100" CreditAccount="'+Convert(nvarchar(max),@crAcc)+'" Amount="'+Convert(nvarchar(max),@amt)+'" AmtFc="'+Convert(nvarchar(max),@amt)+'" CurrencyID="1" ExchangeRate="1" LineNarration="" ChequeNumber=""  ></Transactions><Numeric Query="" ></Numeric><Alpha Query="" ></Alpha><CostCenters Query="" ></CostCenters><EXTRAXML>'		
			if exists(select * from ACC_Accounts WITH(NOLOCK) where AccountID=@crAcc and IsBillwise=1)
			BEGIN
				set @DocXml=@DocXml+'<BillWise> <Row DocSeqNo="2" AccountID="'+Convert(nvarchar(max),@crAcc)+'" AmountFC="-'+Convert(nvarchar(max),@amt)+'" AdjAmount="-'+Convert(nvarchar(max),@amt)+'" AdjCurrID="1" AdjExchRT="1" IsNewReference="1" Narration="" IsDocPDC="0"  ></Row> </BillWise>'
			END	
			set @DocXml=@DocXml+'</EXTRAXML></Row>'
		END	
		set @DocXml=@DocXml+'</DocumentXML>'
		
			EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
				@CostCenterID =@CCID ,      
				@DocID = @DocIDValue,      
				@DocPrefix = @Prefix,      
				@DocNumber =N'',
				@DocDate = @DocDate,      
				@DueDate = NULL,      
				@BillNo = NULL,      
				@InvDocXML = @DocXml,      
				@NotesXML = N'',      
				@AttachmentsXML = N'',      
				@ActivityXML  = N'',     
				@IsImport = 0,      
				@LocationID = @LocationID,      
				@DivisionID = @DivisionID,      
				@WID = 0,      
				@RoleID = @RoleID,      
				@RefCCID = 300,    
				@RefNodeid = @DocID ,    
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
		
		set @sql=@sql+' from acc_docdetails i
		join com_docccdata a on i.accdocdetailsID=a.accdocdetailsID
		join com_docccdata b on b.invdocdetailsID='+Convert(nvarchar(max),@InvDocDetID)+'
		where i.CostCenterID ='+Convert(nvarchar(max),@CCID)+'  and i.docid='+Convert(nvarchar(max),@return_value)
		 print @sql
		 exec(@sql)
		 		
	END               
END   
  
  
GO
