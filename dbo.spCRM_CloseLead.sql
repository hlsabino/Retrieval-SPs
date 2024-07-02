USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_CloseLead]
	@LeadID [int],
	@CCID [int],
	@Date [datetime],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;    
 
	if(@CCID=86)
		update crm_leads set closedate=convert(float,@Date), StatusID=416 where LeadID=@LeadID
	else if (@CCID=73)
	begin
		declare @SID INT,@CompanyGUID nvarchar(50),@UserName nvarchar(50)
		select @SID=convert(INT,isnull(Value,0)) FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=73 and  Name='DefaultCloseStatus'  
		select @CompanyGUID=CompanyGUID from crm_cases WITH(nolock) where caseid=@LeadID
		select @UserName=UserName from adm_users WITH(nolock) where userid=@UserID
		EXEC spCOM_SetNotifEvent -1015,73,@LeadID,@CompanyGUID,@UserName,@UserID,-1 
		if(@SID is not null)
			UPDATE CRM_Cases SET closedate=convert(float,@Date), StatusID=@SID,CloseBy=@UserName where CaseID=@LeadID 
		else
			update crm_cases set closedate=convert(float,@Date), StatusID=1001,CloseBy=@UserName where CaseID=@LeadID
	end
 
COMMIT TRANSACTION    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;     
RETURN @LeadID
END TRY
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
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
