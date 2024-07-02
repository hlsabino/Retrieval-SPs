USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_ReleaseRM]
	@ResCCID [int],
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
	
	declare @DeleteDocID INT,@DELETECCID INT,@return_value int,@sql nvarchar(max),@jobccid int,@bomccid int,@Stgccid int,@jobid int,@bomid int,@Stgid int
	declare @totalPreviousPayRcts INT,@I int,@CNT int,@DocIDValue INT,@RcptCCID INT,@DocXml nvarchar(max),@dbAcc INT,@CrAcc INT,@amt float,@DocDate datetime
	declare @Prefix nvarchar(200),@LinkedQty float,@Qty float,@seq int,@prdid int,@iI int,@iCNT int,@penQty float,@remQty float,@refID int,@invdetid int
	declare  @tblRows TABLE (ID int identity(1,1),MPOID INT,DOCDetID INT,PrdID INT,qty float,job int,bom int,Stg int)
	declare  @tblResRows TABLE (ID int identity(1,1),DOCDetID INT,qty float)
	
	select @jobccid=value from com_costcenterpreferences WITH(NOLOCK)
	where costcenterid=76 and name='JobDimension' and value<>'' and isnumeric(value)=1
	
	select @bomccid=value from com_costcenterpreferences WITH(NOLOCK)
	where costcenterid=76 and name='BomDimension' and value<>'' and isnumeric(value)=1
	select @Stgccid=value from com_costcenterpreferences WITH(NOLOCK)
	where costcenterid=76 and name='StageDimension' and value<>'' and isnumeric(value)=1
	
		 
	select @refID=i.InvDocDetailsID from INV_DocDetails i with(nolock)  		
	where i.DOCID=@Docid 
	
	if(@jobccid>50000)
		set @sql=@sql+' and j.type=15 '	

		 
	set @sql='select j.InvDocDetailsID,i.InvDocDetailsID,I.ProductID,I.Quantity'
	
	if(@jobccid>50000)
		set @sql=@sql+' ,t.dcccnid'+convert(nvarchar(max),(@jobccid-50000))
	else
		set @sql=@sql+' ,0'	
	
	if(@bomccid>50000)
		set @sql=@sql+' ,t.dcccnid'+convert(nvarchar(max),(@bomccid-50000))
	else
		set @sql=@sql+' ,0'	
	if(@Stgccid>50000)
		set @sql=@sql+' ,t.dcccnid'+convert(nvarchar(max),(@Stgccid-50000))
	else
		set @sql=@sql+' ,0'	
	
	set @sql=@sql+' from INV_DocDetails i with(nolock)  		
	join com_docccdata t with(nolock) on t.InvDocDetailsID=i.InvDocDetailsID'
	
	if(@jobccid>50000)
		set @sql=@sql+' join INV_DocextraDetails j with(nolock) on t.dcccnid'+convert(nvarchar(max),(@jobccid-50000))+'=j.LabID	 '
	
	set @sql=@sql+' where i.DOCID= '+convert(nvarchar(max),@Docid) 
	
	if(@jobccid>50000)
		set @sql=@sql+' and j.type=15 '	
	
	insert into @tblRows
	exec(@sql)
	set @seq=0
	set @I=0		
	select @CNT=count(*) from @tblRows
	set @DocXml='' 
	WHILE(@I < @CNT)      
	BEGIN      
		SET @I =@I+1  
		 
		select @invdetid=MPOID,@Qty=qty ,@jobid=job,@bomid=bom,@Stgid=Stg,@prdid=PrdID from @tblRows where ID=@I
		
		
		set @sql='select i.InvDocDetailsID,i.Quantity-isnull((select SUM(LinkedFieldValue) from  INV_DocDetails with(nolock)  where costCenterID='+convert(nvarchar(max),@CCID)+' and LinkedInvDocDetailsID=i.InvDocDetailsID),0)
		from INV_DocDetails i with(nolock)  		
		join com_docccdata t with(nolock) on t.InvDocDetailsID=i.InvDocDetailsID			
		where i.costCenterID='+convert(nvarchar(max),@ResCCID) +' and i.LinkedInvDocDetailsID='+convert(nvarchar(max),@invdetid) +' and i.ProductID='+convert(nvarchar(max),@prdid)
		
		if(@bomccid>50000)
			set @sql=@sql+' and t.dcccnid'+convert(nvarchar(max),(@bomccid-50000))+'='+convert(nvarchar(max),@bomid)
	
		if(@Stgccid>50000)
			set @sql=@sql+' and t.dcccnid'+convert(nvarchar(max),(@Stgccid-50000))+'='+convert(nvarchar(max),@Stgid)
		
		
		set @sql=@sql+'UNION ALL select r.InvDocDetailsID,r.Quantity-isnull((select SUM(LinkedFieldValue) from  INV_DocDetails with(nolock)  where costCenterID='+convert(nvarchar(max),@CCID)+' and LinkedInvDocDetailsID=r.InvDocDetailsID),0)
		from INV_DocDetails i with(nolock)  
		join INV_DocDetails r with(nolock)  on r.LinkedInvDocDetailsID=i.InvDocDetailsID		
		join com_docccdata t with(nolock) on t.InvDocDetailsID=i.InvDocDetailsID			
		where r.costCenterID='+convert(nvarchar(max),@ResCCID) +' and i.LinkedInvDocDetailsID='+convert(nvarchar(max),@invdetid) +' and r.ProductID='+convert(nvarchar(max),@prdid)
		
		if(@bomccid>50000)
			set @sql=@sql+' and t.dcccnid'+convert(nvarchar(max),(@bomccid-50000))+'='+convert(nvarchar(max),@bomid)
	
		if(@Stgccid>50000)
			set @sql=@sql+' and t.dcccnid'+convert(nvarchar(max),(@Stgccid-50000))+'='+convert(nvarchar(max),@Stgid)
		
		delete from @tblResRows
		print @sql
		insert into @tblResRows
		exec(@sql)	
		
		select @iI=min(ID),@iCNT=max(ID) from @tblResRows
		
		set @remQty=@Qty
		
		WHILE(@remQty>0 and @iI <= @iCNT)
		BEGIN    			 
			select @invdetid=DOCDetID,@penQty=qty from @tblResRows where ID=@iI
			
			if(@penQty>@remQty)
			BEGIN
				set @Qty=@remQty
				set @remQty=0
			END	
			ELSE
			BEGIN
				set @Qty=@penQty
				set @remQty=@remQty-@penQty
			END
			
			if(@Qty>0)
			BEGIN
				set @seq=@seq+1
				
				select @DocXml=@DocXml+'<Row><Transactions  DocDetailsID="0"  DocSeqNo="'+convert(nvarchar,@seq)+'"  LinkedInvDocDetailsID= "'+convert(nvarchar,@invdetid)+'"  LinkedFieldName= "Quantity" ProductID="'+convert(nvarchar,i.Productid)+'" CurrencyID="1" ExchangeRate="1" Unit="'+convert(nvarchar,i.Unit)+'" UOMConversion="1"  UOMConvertedQty="'+convert(nvarchar,@Qty)+'" CreditAccount="'+convert(nvarchar,i.CreditAccount)+'" DebitAccount ="'+convert(nvarchar,i.DebitAccount)+'"  Quantity="'+convert(nvarchar,@Qty)+'" CommonNarration=""   CanRecur="0"  Rate="'+convert(nvarchar,i.Rate)+'"  Gross="'+convert(nvarchar,i.Gross)+'"  LineNarration="" ></Transactions>  <Numeric Query="" /> <Alpha  Query="" /> <CostCenters  /> <EXTRAXML/> <AccountsXML></AccountsXML> </Row>'
				from INV_DocDetails i with(nolock)  
				where i.InvDocDetailsID=@invdetid	
			END
			
			SET @iI =@iI+1  
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
