USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_SetActivityStatusLog]
	@ActivityID [int],
	@NodeID [int],
	@Date [datetime],
	@status [int],
	@Reason [nvarchar](max),
	@Longitude [nvarchar](200),
	@Latitude [nvarchar](200),
	@Address1 [nvarchar](256),
	@Address2 [nvarchar](256),
	@City [nvarchar](64),
	@State [nvarchar](64),
	@Country [nvarchar](64),
	@PinCode [nvarchar](32),
	@CompanyGUID [nvarchar](max),
	@CostCenterID [int],
	@UserID [int],
	@UserName [nvarchar](300),
	@RoleID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON 
BEGIN TRANSACTION
BEGIN TRY
		if(@Status=13)
		Begin
			update CRM_Activities set statusid=@status where ActivityID=@ActivityID
		End
		if(@Status in (14,9,12,15,413))
		Begin
			EXEC spCOM_SetNotifEvent @status,@CostCenterID,@NodeID,@CompanyGUID,@UserName,@UserID,@RoleID
		End
		insert into CRM_ActivityStatusLog(ActivityID,CostCenterID,NodeID,Date,Remarks,Status,Longitude,Latitude,Address1
		,Address2,City,State,Country,PinCode)
		Values(@ActivityID,@CostCenterID,@NodeID,convert(float,@Date),@Reason,@Status,@Longitude,@Latitude,@Address1,@Address2,@City,@State
		,@Country,@PinCode)
		
COMMIT TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @ActivityID
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
