USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_PostIncomeforCaseUnits]
	@Date [datetime],
	@DocumentXML [nvarchar](max),
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
select 1
SET NOCOUNT ON;   
  
	DECLARE @return_value INT,@Prefix nvarchar(200),@XML xml,@AA nvarchar(max),@Vno nvarchar(200),@CostCenterID INT,@ContractID INT,@CCID int
	declare @ICNT int,@CNT int,@DocID INT,@ActXml nvarchar(max)         
	
	set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
	
	set @CostCenterID=0
	select @CostCenterID=Value from com_costcenterpreferences
	where costcenterid = 95 and Name  = 'CashCollectionJV'
	and ISNUMERIC(Value)=1
	
	if(@CostCenterID<40000)
		set @CostCenterID=40017
	
	set @XML=@DocumentXML
	
	declare @tblList TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX),cntrctid INT,ccid int)
	INSERT INTO @tblList        
	SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML') ) , X.value ('@ContractID', 'INT' ) , X.value ('@CostcenterID', 'INT' ) 
	from @XML.nodes('/RENTRCT/ROWS') as Data(X)        

	SELECT @CNT = COUNT(ID) FROM @tblList      
	SET @ICNT = 0      
	WHILE(@ICNT < @CNT)      
	BEGIN      
		SET @ICNT =@ICNT+1      

		SELECT @AA = TRANSXML , @ContractID = cntrctid,@CCID=isnull(ccid,0)  FROM @tblList WHERE  ID = @ICNT      
		
		if(@CCID is not null and @CCID>0)
			set @CostCenterID=@CCID
		set @Prefix=''
		EXEC [sp_GetDocPrefix] '',@Date,@CostCenterID,@Prefix   output,@ContractID,0,0,95

	 
	  EXEC @return_value = [dbo].spDOC_SetTempAccDocument      
		   @CostCenterID = @CostCenterID,      
		   @DocID = 0,      
		   @DocPrefix = @Prefix,      
		   @DocNumber =1,      
		   @DocDate = @Date,      
		   @DueDate = NULL,      
		   @BillNo = '',      
		   @InvDocXML = @AA,      
		   @NotesXML = N'',      
		   @AttachmentsXML = N'',      
		   @ActivityXML  = @ActXml,     
		   @IsImport = 0,      
		   @LocationID = 0,      
		   @DivisionID = 0,      
		   @WID = 0,      
		   @RoleID = @RoleID,      
		   @RefCCID = 0,    
		   @RefNodeid = 0 ,    
		   @CompanyGUID = @CompanyGUID,      
		   @UserName = @UserName,      
		   @UserID = @UserID,      
		   @LangID = @LangID  
		
		if(@return_value>0)
		BEGIN
			select  @Vno=VOUCHERNO,@DocID=docid  from ACC_DocDetails 
			where DocID =  @return_value
			
			INSERT INTO  [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID      
			,IsAccDoc,DocType, ContractCCID,ReceiveDate,jvvoucherno)
			values(@ContractID,20,1,@DocID,@CostCenterID,1,20,95,convert(float,@Date),@Vno)
		END	
	END	
 			
COMMIT TRANSACTION     
   
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;   
   
RETURN @return_value      
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
