USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_CloseReservation]
	@QuotationID [int],
	@VacancyDate [datetime],
	@PostPDRecieptXML [nvarchar](max),
	@ContractLocationID [int],
	@ContractDivisionID [int],
	@RoleID [int] = 0,
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY      
	SET NOCOUNT ON; 
	declare @DT float
	set @DT=CONVERT(float,getdate()) 
	
	UPDATE REN_Quotation SET StatusID=471,VacancyDate=CONVERT(FLOAT,@VacancyDate),
	ModifiedBy=@UserName,ModifiedDate=@DT
	WHERE QuotationID=@QuotationID
	
	
	
	DECLARE @AuditTrial BIT        
	SET @AuditTrial=0        
	SELECT @AuditTrial= CONVERT(BIT,VALUE)  FROM [COM_COSTCENTERPreferences] with(nolock)     
	WHERE CostCenterID=95  AND NAME='AllowAudit'   
	IF (@AuditTrial=1)      
	BEGIN 		
		--INSERT INTO HISTROY   
		EXEC [spCOM_SaveHistory]  
			@CostCenterID =129,    
			@NodeID =@QuotationID,
			@HistoryStatus ='Close',
			@UserName=@UserName,
			@DT=@DT   
	END
		  
	if(@PostPDRecieptXML<>'')
	BEGIN
		declare @DocPrefix nvarchar(200),@XML xml,@CNT int,@i int,@AA nvarchar(max),@DocXML XML
		declare @AccValue nvarchar(100),@RcptCCID int,@SNO INT,@return_value int,@ActXml nvarchar(max)         
	
		set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'   
		
		select @SNO=SNO from REN_Quotation WITH(NOLOCK) WHERE QuotationID = @QuotationID
		
		SET @XML=@PostPDRecieptXML       
		declare  @tblListPDR TABLE(ID int identity(1,1),TRANSXML NVARCHAR(MAX),Documents NVARCHAR(200) )          
		
		INSERT INTO @tblListPDR        
		SELECT  CONVERT(NVARCHAR(MAX),X.query('DocumentXML')),CONVERT(NVARCHAR(200),X.query('Documents'))                  
		from @XML.nodes('/PDR/ROWS') as Data(X)        

		SELECT @CNT = COUNT(ID) FROM @tblListPDR      
		SET @I = 0      
		WHILE(@I < @CNT)      
		BEGIN      
			SET @I =@I+1  
			SELECT @AA = TRANSXML,@DocXML = Documents  FROM @tblListPDR WHERE  ID = @I      

			SELECT @AccValue =  X.value ('@DD', 'NVARCHAR(100)' )
			from @DocXML.nodes('/Documents') as Data(X)      
			
			IF(@AccValue = 'BANK')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractPostDatedReceipt'      
			END    
			ELSE  IF(@AccValue = 'CASH')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractCashReceipt'      
			END    
			ELSE  IF(@AccValue = 'JV')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractJVReceipt'      
			END 
			
			set @DocPrefix=''
			EXEC [sp_GetDocPrefix] @AA,@VacancyDate,@RcptCCID,@DocPrefix output

			EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
				   @CostCenterID = @RcptCCID,      
				   @DocID = 0,      
				   @DocPrefix =@DocPrefix,      
				   @DocNumber =1,      
				   @DocDate = @VacancyDate,     
				   @DueDate = NULL,      
				   @BillNo = @SNO,      
				   @InvDocXML = @AA,      
				   @NotesXML = N'',      
				   @AttachmentsXML = N'',      
				   @ActivityXML  = @ActXml,     
				   @IsImport = 0,      
				   @LocationID = @ContractLocationID,      
				   @DivisionID = @ContractDivisionID,      
				   @WID = 0,      
				   @RoleID = @RoleID,      
				   @RefCCID = 129,    
				   @RefNodeid = @QuotationID ,    
				   @CompanyGUID = @CompanyGUID,      
				   @UserName = @UserName,      
				   @UserID = @UserID,      
				   @LangID = @LangID      

			 INSERT INTO [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID)      
			 values(@QuotationID,101,@I,@return_value,@RcptCCID,1,4,129)        

		END
	END	
	
	COMMIT TRANSACTION     
   
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID  
	SET NOCOUNT OFF;   
	   
	RETURN @QuotationID      
END TRY      
BEGIN CATCH 
if(@return_value is null or  @return_value<>-999)   
BEGIN        
IF ERROR_NUMBER()=50000  
 BEGIN  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=2627  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-116 AND LanguageID=@LangID  
 END  
 ELSE  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END   
 ROLLBACK TRANSACTION    
 END
 SET NOCOUNT OFF      
 RETURN -999       
  
  
END CATCH
GO
