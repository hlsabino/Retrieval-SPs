USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_SetMRPII]
	@DocDate [datetime],
	@IntXML [nvarchar](max),
	@MpoXML [nvarchar](max),
	@RMXML [nvarchar](max),
	@MacXML [nvarchar](max) = null,
	@Procxml [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@RoleID [int],
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section
	DECLARE @Dt float,@varxml xml,@SQL nvarchar(max),@return_value int,@RefID int,@RefNodeID int,@vno nvarchar(max)
	declare @ddxml nvarchar(max),@bxml nvarchar(max),@ddID INT,@Prefix nvarchar(200),@AUTOCCID INT,@DetIDS nvarchar(max),@CCStatusID int,@TEmpWid INT   
	
			
		if(@IntXML<>'')
		begin			
			set @varxml=@IntXML
			
			set @AUTOCCID=0			
			SELECT @AUTOCCID=X.value('@CCID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output
			
			
			set @SQL='<XML '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'></XML>'
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'1',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = N'',      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = 0,      
			  @DivisionID = 0 ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 0,    
			  @RefNodeid  = 0,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID  
			  
			  if(@return_value>0)			  
				select @RefNodeID=InvDocdetailsID,@vno=voucherno from Inv_Docdetails WITH(NOLOCK)
				where Docid=@return_value							  
			  else
				return -999	
			    
		END	
		
		if(@MpoXML<>'')
		begin			
			set @varxml=@MpoXML
			
			set @AUTOCCID=0			
			SELECT @AUTOCCID=X.value('@CCID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output
			
			
			set @SQL='<XML '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'></XML>'
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'1',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = N'',      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = 0,      
			  @DivisionID = 0 ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @RefNodeID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID  
			  
			  if(@return_value>0)
			  BEGIN
				set @RefID=@return_value
				select @RefNodeID=InvDocdetailsID from Inv_Docdetails WITH(NOLOCK)
				where Docid=@return_value
				update b
				set dcalpha4=@vno
				from Inv_Docdetails a WITH(NOLOCK)
				join com_doctextdata b WITH(NOLOCK) on a.InvDocdetailsID=b.InvDocdetailsID
				where Docid=@return_value		
			  END	
			  else
				return -999	
		END	
		
		if(@RMXML<>'')
		begin			
			set @varxml=@RMXML
			
			set @AUTOCCID=0			
			SELECT @AUTOCCID=X.value('@CCID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output
			
			
			set @SQL='<XML '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'></XML>'
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'1',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = N'',      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = 0,      
			  @DivisionID = 0 ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			 @RefCCID = 300,    
			  @RefNodeid  = @RefNodeID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    
			  
			  if(@return_value>0)
			  BEGIN
					update a
					set  LinkedInvDocDetailsID=c.InvDocDetailsID
					from Inv_Docdetails a WITH(NOLOCK)
					join COM_DocTextData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
					join Inv_Docdetails c WITH(NOLOCK) on c.ProductID=b.dcAlpha1
					where a.Docid=@return_value and c.Docid=@RefID and b.dcAlpha1 is not null and isnumeric(b.dcAlpha1)=1
			  END
			  ELSE
				return -999
		END	
		
		if(@MacXML<>'')
		begin			
			set @varxml=@MacXML
			
			set @AUTOCCID=0			
			SELECT @AUTOCCID=X.value('@CCID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output
			
			
			set @SQL='<XML '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'></XML>'
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'1',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = N'',      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = 0,      
			  @DivisionID = 0 ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @RefNodeID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID  
			  
			  if(@return_value>0)
			  BEGIN
					update a
					set  LinkedInvDocDetailsID=c.InvDocDetailsID
					from Inv_Docdetails a WITH(NOLOCK)
					join COM_DocTextData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
					join Inv_Docdetails c WITH(NOLOCK) on c.ProductID=b.dcAlpha1
					where a.Docid=@return_value and c.Docid=@RefID and b.dcAlpha1 is not null and isnumeric(b.dcAlpha1)=1
			  END
			  ELSE
				return -999  
		END	
		
		if(@Procxml<>'')
		begin			
			set @varxml=@Procxml
			
			set @AUTOCCID=0			
			SELECT @AUTOCCID=X.value('@CCID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output
			
			
			set @SQL='<XML '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'></XML>'
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'1',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = N'',      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = 0,      
			  @DivisionID = 0 ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @RefNodeID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    
			  
			  if(@return_value>0)
			  BEGIN
					update a
					set  LinkedInvDocDetailsID=c.InvDocDetailsID
					from Inv_Docdetails a WITH(NOLOCK)
					join COM_DocTextData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
					join Inv_Docdetails c WITH(NOLOCK) on c.ProductID=b.dcAlpha1
					where a.Docid=@return_value and c.Docid=@RefID and b.dcAlpha1 is not null and isnumeric(b.dcAlpha1)=1
			  END
			  ELSE
				return -999
		END	
		
COMMIT TRANSACTION  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH  
if(@return_value=-999)
	return @return_value
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		IF isnumeric(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
			WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		ELSE
			SELECT ERROR_MESSAGE() ErrorMessage
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
