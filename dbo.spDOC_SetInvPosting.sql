USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetInvPosting]
	@CostCenterID [int],
	@DocID [int],
	@DocDate [datetime],
	@DueDate [datetime] = NULL,
	@BillNo [nvarchar](500),
	@InvDocXML [nvarchar](max),
	@BillWiseXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@ActivityXML [nvarchar](max),
	@IsImport [bit],
	@LocationID [int],
	@DivisionID [int],
	@WID [int],
	@CCID [int],
	@sysinfo [nvarchar](max),
	@AP [varchar](10),
	@RoleID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100) , @DocIDChild INT,@ActXml nvarchar(max)

    
BEGIN TRY      
SET NOCOUNT ON;    
 DECLARE @VoucherNo NVARCHAR(500),@temp varchar(100),@StatusID INT ,@XML xml,@Prefix NVARCHAR(500),@tempDOc INT,@Length int,@DocNumber nvarchar(50)
 DECLARE	@return_value int,  @CNT INT ,  @ICNT INT ,@AA XML , @DocXml nvarchar(max) ,@PrefValue nvarchar(50),@t int
 
 	if exists(SELECT prefValue FROM com_documentpreferences a with(nolock)  	
 	where costcenterid=@CCID and prefName='RfqServerDate' and prefValue='true')
 		set @DocDate=convert(date,getdate())
 		
	SET @XML= @InvDocXML  
	declare @prds table(prdID INT)
	  
	declare @tblListEnq TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX) )    
	INSERT INTO @tblListEnq  
	SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML'))    
	from @XML.nodes('/Enquiries/ROWS') as Data(X)  

	 
	SELECT @CNT = COUNT(ID) FROM @tblListEnq

	SET @ICNT = 0
	declare  @CAccTable table(ID INT)
	WHILE(@ICNT < @CNT)
	BEGIN
		SET @ICNT =@ICNT+1
	
		SELECT @AA = TRANSXML  FROM @tblListEnq WHERE  ID = @ICNT
		 
	 	 
		Set @DocXml = convert(nvarchar(max), @AA)
		delete from @prds
		insert into @prds
		SELECT X.value('@ProductID','INT')      
		from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)
				
		set @Prefix=''
		EXEC [sp_GetDocPrefix] @DocXml,@DocDate,@CostCenterID,@Prefix   output
			set @DocXml=Replace(@DocXml,'<RowHead/>','')
			set @DocXml=Replace(@DocXml,'<DocumentXML>','')
			set @DocXml=Replace(@DocXml,'</DocumentXML>','')
		
		if NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND CodePrefix=@Prefix)      
		begin      
			if exists(SELECT prefValue FROM com_documentpreferences with(nolock) where 
			costcenterid=@CostCenterID and prefName='StartNoForNewPrefix' and isnumeric(prefValue )=1 and convert(INT,prefValue )>0)
				SELECT @DocNumber=prefValue FROM com_documentpreferences with(nolock)  where costcenterid=@CostCenterID and prefName='StartNoForNewPrefix'
		end      
		ELSE
		BEGIN
				SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK)
				WHERE CostCenterID=@CostCenterID
			 	 
				if(len(@tempDOc)<@Length)    
				begin    
					set @t=1    
					set @temp=''    
					while(@t<=(@Length-len(@tempDOc)))    
					begin        
					set @temp=@temp+'0'        
						set @t=@t+1    
					end    
					SET @DocNumber=@temp+cast(@tempDOc as varchar)    
				end    
				ELSE    
					SET @DocNumber=@tempDOc 
		END
		
			set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
		
			EXEC	@return_value = [dbo].[spDOC_SetTempInvDoc]
					@CostCenterID = @CostCenterID,
					@DocID = 0,
					@DocPrefix = @Prefix,
					@DocNumber =@DocNumber, 
					@DocDate = @DocDate,
					@DueDate = @DueDate,
					@BillNo = @BillNo,
					@InvDocXML = @DocXml,
					@BillWiseXML = @BillWiseXML,
					@NotesXML = @NotesXML,
					@AttachmentsXML = @AttachmentsXML,
					@ActivityXML=@ActivityXML,
					@IsImport = 0,
					@LocationID = @LocationID,
					@DivisionID = @DivisionID,
					@WID = @WID,
					@RoleID = @RoleID,
					@DocAddress ='',  
					@RefCCID =0,
					@RefNodeid  =0,
					@CompanyGUID = @CompanyGUID,
					@UserName = @UserName,
					@UserID = @UserID,
					@LangID = @LangID

			SELECT	@DocIDChild = @return_value
  
	 	if(@return_value <  0)
		BEGIN
				  ROLLBACK TRANSACTION 
				  RETURN -101
		END
		Else
		BEGIN
			set @PrefValue=''  
			select @PrefValue=PrefValue from COM_DocumentPreferences  with(nolock)   
			where CostCenterID=@CostCenterID and PrefName='AutoAttachment'    
			if(@PrefValue='true')  
			begin 
				
				insert into COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,FeatureID,FeaturePK,CompanyGUID,GUID,CreatedBy,CreatedDate)
				select FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,@CostCenterID,@DocIDChild,@CompanyGUID,GUID,@UserName,CONVERT(float,getdate())
				from COM_Files a WITH(NOLOCK)
				join @prds b on a.FeaturePK=b.prdID
				where IsProductImage=0 and FeatureID=3
				      
			END
		END
		
 
   END
COMMIT TRANSACTION     
--rollback TRANSACTION
    
   
SELECT @VoucherNo=VoucherNo ,@StatusID = statusid   FROM INV_DocDetails WITH(nolock) WHERE DocID=@DocIDChild  
	 
  select @temp=ResourceData from COM_Status S WITH(nolock)
 join COM_LanguageResources R WITH(nolock) on R.ResourceID=S.ResourceID and R.LanguageID=@LangID
 where S.StatusID=@StatusID
 
 
SELECT    ErrorMessage + '   ' + isnull(@VoucherNo,'voucherempty') +' ['+@temp+']'     as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=105 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
 
RETURN @DocIDChild      
END TRY      
BEGIN CATCH     
    if(@return_value=-999)
    return -999  
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
