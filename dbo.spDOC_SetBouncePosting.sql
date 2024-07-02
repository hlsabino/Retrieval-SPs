USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetBouncePosting]
	@CostCenterID [int],
	@DocID [int],
	@DocDate [datetime],
	@DueDate [datetime] = NULL,
	@BillNo [nvarchar](500),
	@InvDocXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@LocationID [int],
	@DivisionID [int],
	@WID [int],
	@RoleID [int],
	@SCCID [int],
	@SDocType [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100) , @DocIDChild INT  ,@Dt float
DECLARE @PrefValue NVARCHAR(100),@DocPrefix nvarchar(200),@DocNumber NVARCHAR(500)  
    
BEGIN TRY      
SET NOCOUNT ON;    
 DECLARE @VoucherNo NVARCHAR(500),@temp varchar(100),@StatusID INT ,@DocumentType INT ,@AccDocDetailsID INT 
DECLARE @amt float,@accid INT,@IsNewReference bit,@RefDocNo nvarchar(200), @RefDocSeqNo int,@RefDocDate FLOAT,@RefDueDate FLOAT   
DECLARE	@return_value int
   SET @Dt=convert(float,getdate())--Setting Current Date  
	
	 
			  UPDATE Acc_Docdetails
			  SET StatusID = 429
			  WHERE CostCenterID = @SCCID  AND DocID = @DocID
		  
		 
		SELECT @DocPrefix  = DocPrefix,@AccDocDetailsID=AccDocDetailsID
		,@RefDocNo = VoucherNo ,  @RefDocDate = DocDate , @RefDueDate =  DueDate
		 FROM ACC_DocDetails with(nolock) 
		where CostCenterID = @SCCID AND DocID = @DocID
		
		 
		if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef  WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix)    
		begin    
				
			select @DocNumber=prefvalue from com_documentpreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and prefname='StartNoForNewPrefix'
			and prefvalue is not null and prefvalue<>'' and prefvalue<>'0' and isnumeric(prefvalue)=1
			if(@DocNumber is null)
				set @DocNumber='1'
		END
		ELSE
		BEGIN
				declare @Length int,@t int
				SELECT  @DocNumber=convert(nvarchar,ISNULL(CurrentCodeNumber,0)+1),@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK) --AS CurrentCodeNumber    
				WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix    
				if(len(@DocNumber)<@Length)    
				begin    
					set @t=1    
					set @temp=''    
					while(@t<=(@Length-len(@DocNumber)))    
					begin        
						set @temp=@temp+'0'        
						set @t=@t+1    
					end    
					SET @DocNumber=@temp+@DocNumber
				end    
							
		END
		
EXEC	@return_value = [dbo].spDOC_SetTempAccDocument
		@CostCenterID = @CostCenterID,
		@DocID = 0,
		@DocPrefix = @DocPrefix,
		@DocNumber =@DocNumber, 
		@DocDate = @DocDate,
		@DueDate = @DueDate,
		@BillNo = @BillNo,
		@InvDocXML = @InvDocXML,
		@NotesXML = @NotesXML,
		@AttachmentsXML = @AttachmentsXML,
		@ActivityXML = N'',
		@IsImport = 0,
		@LocationID = @LocationID,
		@DivisionID = @DivisionID,
		@WID = @WID,
		@RoleID = @RoleID,
		@RefCCID = 400,
		@RefNodeid = @AccDocDetailsID ,
		@CompanyGUID = @CompanyGUID,
		@UserName = @UserName,
		@UserID = @UserID,
		@LangID = @LangID
 
		SET	@DocIDChild = @return_value
 
	 	if(@return_value <  0)
		BEGIN
				  ROLLBACK TRANSACTION 
				  RETURN -101
		END
	 
	   Declare @ChildRefDocNo nvarchar(200)
	   
		SELECT @VoucherNo  = VoucherNo  , @AccDocDetailsID = AccDocDetailsID , @amt = Amount , 
		@DocumentType = DocumentType  FROM ACC_DocDetails with(nolock) 
		where docid = @DocIDChild and CostCenterID  = @CostCenterID
		
		if(@DocumentType = 18)
		BEGIN 
			SELECT  @accid = CreditAccount FROM ACC_DocDetails  with(nolock)
			where docid = @DocIDChild and CostCenterID  = @CostCenterID
		END
		ELSE
		BEGIN 
			SELECT  @accid = DebitAccount FROM ACC_DocDetails  with(nolock)
			where docid = @DocIDChild and CostCenterID  = @CostCenterID
		END
		
		
		
		-- select @accid 'ACCID' , @VoucherNo 'VOUCHERNO' ,@AccDocDetailsID ,@DocumentType, 'Details of New doc which will be generated after bounce '
		-- Details of New doc which will be generated after bounce 
		
		 
		 --select @RefDocNo  'REF', @RefDocDate ,@RefDueDate , @SCCID  'CC' , @DocID 'DOCID','DETAILS OF EXISTING DOC WHICH IS BEING BOUNCED'
		 --- DETAILS OF EXISTING DOC WHICH IS BEING BOUNCED
	
	 IF EXISTS(SELECT  AccountID FROM ACC_Accounts with(nolock) WHERE IsBillwise=1 AND  AccountID=@accid)  
     BEGIN  
			--if(@RefDocDate is null)  
			  set @IsNewReference=1  
			 --else  
			 -- set @IsNewReference=0  

	 	
			SELECT  @ChildRefDocNo =  DocNo   FROM COM_Billwise with(nolock)  WHERE RefDocNo = @RefDocNo
			
			if(@ChildRefDocNo is not null or @ChildRefDocNo <> '')
			BEGIN
	 			update COM_Billwise 
	 			set IsNewReference=1,RefDocNo=null,RefDocSeqNo=null,RefDocDate=null,RefDocDueDate=null
	 			WHERE RefDocNo=@RefDocNo
			END 
			  
			 SELECT  @RefDocSeqNo = DOCSEQNO FROM COM_Billwise with(nolock) WHERE  DocNo = @VoucherNo
			  
			update COM_Billwise 
   			set IsNewReference=0,RefDocNo=@VoucherNo,RefDocSeqNo=@RefDocSeqNo,RefDocDate=@RefDocDate,RefDocDueDate=@RefDueDate
 			WHERE DocNo=@RefDocNo
		   
     END
     
     select @PrefValue=value from adm_globalpreferences with(nolock) where name='enableChequeReturnHistory'
	 if( @PrefValue is not null and @PrefValue='true')
	 begin
		declare @DocCC nvarchar(max),@Sql nvarchar(max)
		set @DocCC=''
		select @DocCC =@DocCC +','+a.name from sys.columns a with(nolock)
		join sys.tables b with(nolock) on a.object_id=b.object_id
		join sys.columns c with(nolock) on c.name like 'dcCCNID%'
		join sys.tables d with(nolock) on c.object_id=d.object_id
		where b.name='COM_ChequeReturn' and d.name='COM_DocCCData'
		and a.name like 'dcCCNID%' and a.name=c.name
		
		set @Sql='insert into COM_ChequeReturn(DocNo,DocSeqNo,AccountID,AdjAmount,AdjCurrID,AdjExchRT,AmountFC,
		DocDate,DocDueDate,DocType,IsNewReference,Narration,IsDocPDC,CompanyGUID,GUID,CreatedBy,CreatedDate'+@DocCC+')
		select VoucherNo,DocSeqNo,case when (IsNegative is null or IsNegative=0) and DocumentType in(14,15,23) THEN DebitAccount 
									   when (IsNegative is null or IsNegative=0) and DocumentType in(18,19,22) THEN CreditAccount 
									   when IsNegative is not null and IsNegative=1 and DocumentType in(14,15,23) THEN CreditAccount
									   when IsNegative is not null and IsNegative=1 and DocumentType in(18,19,22) THEN  DebitAccount end 
		,case when (IsNegative is null or IsNegative=0) and DocumentType in(14,15,23) THEN Amount 
									   when (IsNegative is null or IsNegative=0) and DocumentType in(18,19,22) THEN (Amount*-1) 
									   when IsNegative is not null and IsNegative=1 and DocumentType in(14,15,23) THEN (Amount*-1)
									   when IsNegative is not null and IsNegative=1 and DocumentType in(18,19,22) THEN  Amount end,CurrencyID,ExchangeRate,AmountFC,DocDate,DueDate,DocumentType,1,'''',0
									   ,'''+convert(nvarchar(max),@CompanyGUID)+''',newid(),'''+convert(nvarchar(max),@UserName)+''',convert(float,getdate())
		'+@DocCC+'
		from ACC_DocDetails a WITH(nolock)
		join dbo.COM_DocCCData b WITH(nolock) on a.AccDocDetailsID=b.AccDocDetailsID
		where docid ='+convert(nvarchar(max),@DocID )
		exec(@Sql)
	 end

COMMIT TRANSACTION     
    
 --SELECT * FROM ACC_DocDetails WITH(nolock) WHERE DocID=@DocIDChild 
   
	 
  select @temp=ResourceData from COM_Status S with(nolock)
 join COM_LanguageResources R with(nolock) on R.ResourceID=S.ResourceID and R.LanguageID=@LangID
 where S.StatusID=429
 
 
SELECT    ErrorMessage + '   ' + isnull(@RefDocNo,'voucherempty') +' ['+@temp+']'     as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=105 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
 
RETURN @DocID      
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
    
 ROLLBACK TRANSACTION    
 SET NOCOUNT OFF      
 RETURN -999       
END CATCH
GO
