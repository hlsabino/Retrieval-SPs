USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetLeadQuick]
	@LeadID [int] = 0,
	@LeadCode [nvarchar](200),
	@Company [nvarchar](200),
	@StaticFieldsQuery [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@ActivityXml [nvarchar](max) = null,
	@Details [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@RoleID [int],
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON 
BEGIN TRANSACTION
BEGIN TRY
  
	DECLARE @UpdateSql nvarchar(max),@Dt FLOAT, @TempGuid nvarchar(50),@HasAccess bit,@ActionType INT
 
	IF EXISTS(SELECT LeadID FROM CRM_Leads WITH(NOLOCK) WHERE LeadID=@LeadID AND ParentID=0)  
	BEGIN  
		RAISERROR('-123',16,1)  
	END  
	
	SET @ActionType=3
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,86,3)  

	IF @HasAccess=0  
	BEGIN  
		RAISERROR('-105',16,1)  
	END  
	
	SELECT @TempGuid=[GUID] from CRM_Leads WITH(NOLOCK) WHERE LeadID=@LeadID
	IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
	BEGIN    
	   RAISERROR('-101',16,1)   
	END 

	SET @Dt=convert(float,getdate())--Setting Current Date  

	UPDATE CRM_Leads SET [Code]=@LeadCode
	,[Company]=@Company
	,[GUID] = @Guid
	,[ModifiedBy] = @UserName
	,[ModifiedDate] = @Dt
	WHERE LeadID = @LeadID

	--Update Main Table
	IF(@StaticFieldsQuery IS NOT NULL AND @StaticFieldsQuery <> '')
	BEGIN
		set @UpdateSql='update CRM_Leads SET '+@StaticFieldsQuery+'[GUID]= NEWID(), [ModifiedBy] ='''+ @UserName
		+''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE LeadID='+convert(NVARCHAR,@LeadID)
		exec(@UpdateSql)
	END
	
	--Update CostCenter Extra Fields	
    set @UpdateSql='update COM_CCCCDATA SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName
	+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID = '+convert(nvarchar,@LeadID) + ' AND CostCenterID = 86' 
     exec(@UpdateSql)  

	--Update Extra fields
	set @UpdateSql='update [CRM_LeadsExtended] SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName
	+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE LeadID='+convert(nvarchar,@LeadID)
	exec(@UpdateSql)
	
	--Series Check
	declare @retSeries INT
	EXEC @retSeries=spCOM_ValidateCodeSeries 86,@LeadID,@LangId
	if @retSeries>0
	begin
		ROLLBACK TRANSACTION
		SET NOCOUNT OFF  
		RETURN -999
	end
	 
	--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=86 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 86,@LeadID,@UserID,@LangID
	end  
	 
	if( @Details is not null and @Details<>'')
	begin
		set @UpdateSql='Update CRM_CONTACTS set '+@Details+' where  Featureid=86 and FeaturePK='+convert(nvarchar,@LeadID)+''
		exec (@UpdateSql)  
	end
	
	if(@Company<>'')
		update CRM_CONTACTS set company=@Company where Featureid=86 and FeaturePK=@LeadID
		
	if @ActivityXml is not null and @ActivityXml!=''
		exec spCom_SetActivitiesAndSchedules @ActivityXml,86,@LeadID,@CompanyGUID,@Guid,@UserName,@dt,@LangID 

	--Insert Notifications
	EXEC spCOM_SetNotifEvent @ActionType,86,@LeadID,@CompanyGUID,@UserName,@UserID,@RoleID

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
