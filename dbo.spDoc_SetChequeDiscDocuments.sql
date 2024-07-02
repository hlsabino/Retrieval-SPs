USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetChequeDiscDocuments]
	@PDRcptXML [nvarchar](max) = NULL,
	@DocDate [datetime],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
DECLARE  @CNT INT ,  @ICNT INT  , @StatusValue int,@Prefix nvarchar(500),@Action int,@PrefValue nvarchar(50)
Declare @tempdr INT,@tempbid INT,@Adb INT
BEGIN TRY    
SET NOCOUNT ON;   
select @PrefValue=value from adm_globalpreferences with(nolock) where name='Intermediate PDC'
 IF(@PDRcptXML is not null and @PDRcptXML<>'')  
  BEGIN  
    DECLARE  @XML xml,@LocationID INT,@prefVal nvarchar(50)   
	DECLARE @DDValue nvarchar(max) , @DDXML nvarchar(max)   
	 DECLARE @return_value int,@accID INT  
     DECLARE   @AccountType xml, @AccValue nvarchar(100) , @Documents xml , @DocIDValue nvarchar(100) ,@CostcenterID INT , @PostCCID INT
 	
	DECLARE @AA XML  , @DateXML XML   
	DECLARE @DocXml nvarchar(max)     
	   set @LocationID=0
	   select @prefVal =value from ADM_GlobalPreferences with(nolock)
	   where name='EnableLocationWise'
	   
	  SET @XML =   @PDRcptXML   
	 DECLARE  @tblListPDR TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX)  ,Documents NVARCHAR(200) )      
	 INSERT INTO @tblListPDR    
	 SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML')) ,   CONVERT(NVARCHAR(200),  X.query('Documents'))              
	 from @XML.nodes('/PDR/ROWS') as Data(X)    
	   
	 SELECT @CNT = COUNT(ID) FROM @tblListPDR  
	  
	 SET @ICNT = 0  
	 WHILE(@ICNT < @CNT)  
	 BEGIN  
		SET @ICNT =@ICNT+1  

		SELECT @AA = TRANSXML ,  @Documents = Documents  FROM @tblListPDR WHERE  ID = @ICNT  
		 
		SELECT  @Action=ISNULL(X.value ('@Action', 'INT'),0),@accID=ISNULL(X.value ('@AccID', 'BIGINT'),0),  @DocIDValue =  ISNULL(X.value ('@DocID', 'NVARCHAR(100)'),0), @CostcenterID = ISNULL(X.value ('@CostcenterID', 'INT'),0)
		FROM @Documents.nodes('/Documents') as Data(X)  
		
		if(@Action=0)
		BEGIN	 
			SELECT @PostCCID = isnull(OnDiscount,0)  from ADM_DOCUMENTTYPES WITH(nolock)  
			WHERE CostCenterID= @CostcenterID  
			
			if(@prefVal is not null and @prefVal='true')
				select @LocationID=ISNULL(X.value('@dcCCNID2','INT'),1) 
				 from @AA.nodes('/DocumentXML/Row/CostCenters') as Data(X)
			
			Set @DocXml = convert(nvarchar(max), @AA)  
			IF(@PostCCID <> 0)
			BEGIN
				UPDATE ACC_DOCDETAILS
				SET STATUSID = 439 ,IsDiscounted=1
				WHERE ACCDOCDETAILSID=@accID
			
				select @Adb=ISNULL(X.value('@DebitAccount','INT'),1) 
				 from @AA.nodes('/DocumentXML/Row/Transactions') as Data(X)
			
				select @tempdr=DebitAccount,@tempbid=BankAccountID from ACC_DocDetails with(nolock) 
				where AccDocDetailsID=@accID

				if(@PrefValue='true' and @Adb<>@tempbid)
				begin					
						if exists(select accounttypeid from ACC_Accounts with(nolock) where AccountID=@Adb and accounttypeid in(2,3))
						begin
							set @tempbid=@Adb
							select @tempdr=PDCReceivableAccount from ACC_Accounts with(nolock) where AccountID=@Adb
							 IF(@tempdr is null or @tempdr <=1)
								RAISERROR('-365',16,1)									
							UPDATE ACC_DocDetails 
							SET DebitAccount = @tempdr ,BankAccountID=@tempbid
							where AccDocDetailsID=@accID 
						end
				END
				ELSE if(@PrefValue<>'true' and @Adb<>@tempdr)
				begin																		
						UPDATE ACC_DocDetails 
						SET DebitAccount = @Adb ,BankAccountID=0
						where AccDocDetailsID=@accID 
						
				END 		
							
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @DocXml,@DocDate,@PostCCID,@Prefix   output

				EXEC @return_value = [dbo].spDOC_SetTempAccDocument  
				@CostCenterID = @PostCCID,  
				@DocID = 0,  
				@DocPrefix = @Prefix,  
				@DocNumber =1,  
				@DocDate = @DocDate,  			
				@DueDate = NULL,  
				@BillNo = N'',  
				@InvDocXML = @DocXml,  
				@NotesXML = N'',  
				@AttachmentsXML = N'',  
				@ActivityXML  = N'', 
				@IsImport = 0,  
				@LocationID = @LocationID,  
				@DivisionID = 1,  
				@WID = 0,  
				@RoleID = @RoleID,  
				@RefCCID = 109,
				@RefNodeid = @accID ,
				@CompanyGUID = @CompanyGUID,  
				@UserName = @UserName,  
				@UserID = @UserID,  
				@LangID = @LangID  
			END
			ELSE 
			 BEGIN
				  RAISERROR('-378',16,1)     
			 END 
		END	 
		ELSE if(@Action=1)
		BEGIN
					DECLARE @DELDocid INT  ,@DELETECCID int
					
					UPDATE ACC_DOCDETAILS
					SET STATUSID = 370 ,IsDiscounted=0
					WHERE ACCDOCDETAILSID=@accID
					
					SELECT @DELDocid = DOCID, @DELETECCID = COSTCENTERID FROM ACC_DocDetails with(nolock)   
					where RefCCID = 109 and RefNodeid=@accID	
						    
					 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
					 @CostCenterID = @DELETECCID,  
					 @DocPrefix = '',  
					 @DocNumber = '',  
					 @DocID=@DELDocid,
					 @UserID = @UserID,  
					 @UserName = @UserName,  
					 @LangID = @LangID,
					 @RoleID=@RoleID
		END
	  END  
	 END  
	 
COMMIT TRANSACTION  
     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;     
       
RETURN @return_value  
END TRY  
BEGIN CATCH
if(@return_value=-999)
	return -999
 IF ERROR_NUMBER()=50000  
 BEGIN  
	IF (ERROR_MESSAGE() LIKE '-378' )     
	BEGIN      
		SELECT ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
		WHERE ErrorNumber=-378 AND LanguageID=@LangID      
	END 
	ELSE   
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
