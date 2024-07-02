USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_PostReturnRM]
	@IssXML [nvarchar](max),
	@ExpXML [nvarchar](max),
	@ResXML [nvarchar](max),
	@prefix [nvarchar](200),
	@Docno [nvarchar](500),
	@date [datetime],
	@WONO [nvarchar](500),
	@IsRec [bit],
	@LocationID [int],
	@DivisionID [int],
	@MFGOrderID [int],
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
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  Declare  @ExpCCID INT,@RcrsCCID INT,@RcvCCID INT,@return_value int,@PrefValue nvarchar(200),@ActXml nvarchar(max)
  
    set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'

    if(@ResXML is not null and @ResXML<>'')
  begin
		select @RcrsCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)
		where CostCenterID=78 and Name='ResourcesJV'
	
		EXEC	@return_value = [dbo].[spDOC_SettempAccDocument]
		@CostCenterID = @RcrsCCID,
		@DocID = 0,
		@DocPrefix = N'',
		@DocNumber = N'',
		@DocDate = @date,
		@DueDate = NULL,
		@BillNo = N'',
		@InvDocXML = @ResXML,
		@NotesXML = N'',
		@AttachmentsXML = N'',
		@ActivityXML = @ActXml,
		@IsImport = 0,
		@LocationID = @LocationID,
		@DivisionID = @DivisionID,
		@WID = 0,
		@RoleID = @RoleID,
		@RefCCID =78,
		@RefNodeid  =@MFGOrderID,
		@CompanyGUID = @CompanyGUID,
		@UserName = @UserName,
		@UserID = @UserID,
		@LangID = @LangID
		INSERT INTO [PRD_MFGDocRef]([MFGOrderID],[AccDocID],[InvDocID])
		values(@MFGOrderID,@return_value,NULL)
     
  end
  
  if(@ExpXML is not null and @ExpXML<>'')
  begin
		select @ExpCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)
		where CostCenterID=78 and Name='ExpensesJV'
	
		EXEC	@return_value = [dbo].[spDOC_SettempAccDocument]
		@CostCenterID = @ExpCCID,
		@DocID = 0,
		@DocPrefix = N'',
		@DocNumber = N'',
		@DocDate = @date,
		@DueDate = NULL,
		@BillNo = N'',
		@InvDocXML = @ExpXML,
		@NotesXML = N'',
		@AttachmentsXML = N'',
		@ActivityXML = @ActXml,
		@IsImport = 0,
		@LocationID = @LocationID,
		@DivisionID = @DivisionID,
		@WID = 0,
		@RoleID = @RoleID,
		@RefCCID =78,
		@RefNodeid  =@MFGOrderID,
		@CompanyGUID = @CompanyGUID,
		@UserName = @UserName,
		@UserID = @UserID,
		@LangID = @LangID
		INSERT INTO [PRD_MFGDocRef]([MFGOrderID],[AccDocID],[InvDocID])
		values(@MFGOrderID,@return_value,NULL)
  end
  
  set @return_value=0
  if(@IssXML is not null and @IssXML<>'')
  begin
		if(@IsRec=1)
			select @RcvCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)
			where CostCenterID=78 and Name='DocRCT'
		ELSE
			select @RcvCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)
			where CostCenterID=78 and Name='DocReturn'

	
	  EXEC	@return_value = [dbo].[spDOC_SetTempInvDoc]
			@CostCenterID = @RcvCCID,
			@DocID = 0,
			@DocPrefix = @prefix,
			@DocNumber =@Docno,
			@DocDate = @date,
			@DueDate = NULL,
			@BillNo = @wono,
			@InvDocXML = @IssXML,
			@BillWiseXML = N'',
			@NotesXML = N'',
			@AttachmentsXML = N'',
			@ActivityXML = @ActXml,
			@IsImport = 0,
			@LocationID = @LocationID,
			@DivisionID = @DivisionID ,
			@WID = 0,
			@RoleID = @RoleID,
			@DocAddress = N'',
			@RefCCID =78,
			@RefNodeid  =@MFGOrderID,
			@CompanyGUID = @CompanyGUID,
			@UserName = @UserName,
			@UserID = @UserID,
			@LangID = @LangID 
			
			INSERT INTO [PRD_MFGDocRef]([MFGOrderID],[AccDocID],[InvDocID])
			values(@MFGOrderID,NULL,@return_value)
  end
  
  
	
COMMIT TRANSACTION
SET NOCOUNT OFF;    
RETURN @return_value  
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
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
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH
GO
