USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SetUnitQuick]
	@UNITID [int] = 0,
	@PROPERTYID [int] = 0,
	@CODE [nvarchar](300) = NULL,
	@NAME [nvarchar](300) = NULL,
	@STATUSID [int] = 0,
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@UserName [nvarchar](50),
	@WID [int] = 0,
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
	--Declaration Section  
	DECLARE @Dt float,@TempGuid nvarchar(50),@HasAccess bit
	 
	--User access check 
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,93,3)
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END
  
	SET @Dt=convert(float,getdate())--Setting Current Date  
  

    SELECT @TempGuid=[GUID] from [REN_Units] WITH(NOLOCK) WHERE UnitID=@UNITID
    
    --CHECK WORKFLOW
	SELECT @STATUSID=[Status] from [REN_Units] with(nolock) where UnitID=@UNITID
	EXEC spCOM_CheckCostCentetWF 93,@UNITID,@WID,@RoleID,@UserID,@UserName,@STATUSID output
  
	IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
	BEGIN    
	   RAISERROR('-101',16,1)   
	END    
	ELSE    
	BEGIN
		UPDATE [REN_Units]
		SET [PropertyID] = @PROPERTYID
		,[Code] =  @CODE
		,[Name] = @NAME
		,[Status] = @STATUSID				 
		,[CompanyGUID] = @CompanyGUID
		,[GUID] = @Guid
		,[ModifiedBy] = @UserName
		,[ModifiedDate] =@Dt
		WHERE UnitID=@UNITID
	END  
	
	--INSERT INTO HISTROY   
	EXEC [spCOM_SaveHistory]  
		@CostCenterID =93,    
		@NodeID =@UNITID,
		@HistoryStatus ='Update',
		@UserName=@UserName,
		@Dt=@Dt
  
COMMIT TRANSACTION    
 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @UNITID
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
