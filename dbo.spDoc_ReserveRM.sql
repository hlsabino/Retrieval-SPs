USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_ReserveRM]
	@InvIDFld [nvarchar](10),
	@CCID [int],
	@DocID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](500),
	@RoleID [int],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	
	declare @DeleteDocID INT,@DELETECCID INT,@return_value int,@sql nvarchar(max)
	

	
	declare @totalPreviousPayRcts INT,@I int,@CNT int,@DocIDValue INT,@RcptCCID INT,@DocXml nvarchar(max),@dbAcc INT,@CrAcc INT,@amt float,@DocDate datetime,@perday float,@invdetid INT,@mntdif int,@ii int,@stat int
	declare @Prefix nvarchar(200),@LinkedQty float,@Qty float,@seq int,@refID int
	declare  @tblRows TABLE (ID int identity(1,1),DOCDetID INT,qty float,linkedQty float)
	
	select @refID=i.InvDocDetailsID from INV_DocDetails i with(nolock)  		
	where i.DOCID=@Docid 
		 
	set @sql='select RM.InvDocDetailsID,I.Quantity,RM.Quantity-isnull((select SUM(LinkedFieldValue) from  INV_DocDetails with(nolock)  where LinkedInvDocDetailsID=RM.InvDocDetailsID),0)
	from INV_DocDetails i with(nolock)  		
	join com_docTextdata t with(nolock) on t.InvDocDetailsID=i.InvDocDetailsID
	join INV_DocDetails RM with(nolock) on t.'+@InvIDFld+'=RM.InvDocDetailsID		
	where i.DOCID='+convert(nvarchar(max),@Docid) +'
	and isnumeric('+@InvIDFld+')=1'
	
	insert into @tblRows
	exec(@sql)
	set @seq=0
	set @I=0		
	select @CNT=count(*) from @tblRows
	set @DocXml='' 
	
	WHILE(@I < @CNT)      
	BEGIN      
		SET @I =@I+1  
		
		select @invdetid=DOCDetID,@Qty=qty ,@LinkedQty=linkedQty from @tblRows where ID=@I
	
		set @Qty=@Qty-@LinkedQty
	
		if(@Qty>0)
		BEGIN
			set @seq=@seq+1
			
			select @DocXml=@DocXml+'<Row><Transactions  DocDetailsID="0"  DocSeqNo="'+convert(nvarchar,@seq)+'"  LinkedInvDocDetailsID= "'+convert(nvarchar,@invdetid)+'"  LinkedFieldName= "Quantity" ProductID="'+convert(nvarchar,i.Productid)+'" CurrencyID="1" ExchangeRate="1" Unit="'+convert(nvarchar,i.Unit)+'" UOMConversion="1"  UOMConvertedQty="'+convert(nvarchar,@Qty)+'" CreditAccount="'+convert(nvarchar,i.CreditAccount)+'" DebitAccount ="'+convert(nvarchar,i.DebitAccount)+'"  Quantity="'+convert(nvarchar,@Qty)+'" CommonNarration=""   CanRecur="0"  Rate="'+convert(nvarchar,i.Rate)+'"  Gross="'+convert(nvarchar,i.Gross)+'"  LineNarration="" ></Transactions>  <Numeric Query="" /> <Alpha  Query="" /> <CostCenters  /> <EXTRAXML/> <AccountsXML></AccountsXML> </Row>'
			from INV_DocDetails i with(nolock)  
			where i.InvDocDetailsID=@invdetid	
		END
	END	
	
	if(@DocXml<>'')
	BEGIN		
		SELECT @DocIDValue=0       
		set @Prefix=''
		EXEC [sp_GetDocPrefix] @DocXml,@DocDate,@CCID,@Prefix   output
		 	 
		EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			@CostCenterID = @CCID,      
			@DocID = @DocIDValue,      
			@DocPrefix = @Prefix,      
			@DocNumber =1,            
			@DocDate = @DocDate,      
			@DueDate = NULL,      
			@BillNo = '',      
			@InvDocXML = @DocXml,   
			@BillWiseXML = N'',        
			@NotesXML = N'',      
			@AttachmentsXML = N'',      
			@ActivityXML  = N'',     
			@IsImport = 0,      
			@LocationID = 0,      
			@DivisionID = 0,      
			@WID = 0,      
			@RoleID = @RoleID,    
			@DocAddress  = N'', 
			@RefCCID = 300,    
			@RefNodeid = @refID ,    
			@CompanyGUID = @CompanyGUID,      
			@UserName = @UserName,      
			@UserID = @UserID,      
			@LangID = @LangID      
			
			if(@return_value>0)
			BEGIN
				set @sql='update a set '
				select @sql =@sql +a.name+'=b.'+a.name+',' from sys.columns a
				join sys.tables b on a.object_id=b.object_id
				where b.name='COM_DocCCData' and a.name like 'dcCCNID%'
				set @sql=substring(@sql,0,len(@sql))
				
				set @sql =@sql+' from  INV_DocDetails i with(nolock)  
				join [COM_DocCCData] a with(nolock) on a.InvDocDetailsID=i.InvDocDetailsID
				join INV_DocDetails li with(nolock)  on li.InvDocDetailsID=i.LinkedInvDocDetailsID
				join [COM_DocCCData] b with(nolock) on b.InvDocDetailsID=li.InvDocDetailsID
				where i.DOCID='+convert(nvarchar(max),@return_value)	
				
				exec(@sql)
			END		
	END	
		
END 

GO
