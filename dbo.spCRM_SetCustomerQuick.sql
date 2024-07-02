USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetCustomerQuick]
	@CustomerID [int],
	@CustomerCode [nvarchar](200),
	@CustomerName [nvarchar](500),
	@StatusID [int],
	@CodePrefix [nvarchar](200),
	@CodeNumber [int],
	@StaticFieldsQuery [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@Description [nvarchar](500),
	@UserName [nvarchar](50),
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  DECLARE @Dt float,@TempGuid nvarchar(50),@HasAccess bit
  DECLARE @IsDuplicateNameAllowed bit,@IsAccountCodeAutoGen bit,@IsDuplicateCodeAllowed BIT,@IsIgnoreSpace bit  
    declare @isparentcode bit ,@HistoryStatus NVARCHAR(300)
  
  
  if(@CustomerID=0)
		set @HistoryStatus='Add'
	else
		set @HistoryStatus='Update'
		
  --User acces check FOR ACCOUNTS  
  IF @CustomerID=0  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,1)  
  END  
  ELSE  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,3)  
  END  
  
  IF @HasAccess=0  
  BEGIN  
   RAISERROR('-105',16,1)  
  END  
 
  --GETTING PREFERENCE  
  
  SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=83 and  Name='DuplicateNameAllowed'  
  SELECT @IsAccountCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=83 and  Name='CodeAutoGen'  
  SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=83 and  Name='IgnoreSpaces'  
  select @isparentcode=IsParentCodeInherited  from COM_CostCenterCodeDef where CostCenterID=83
  
   --DUPLICATE CODE CHECK  
   
		
		IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0
		BEGIN
			IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
			BEGIN  
				IF @CustomerID=0  
				BEGIN  
				 IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE replace(CustomerName,' ','')=replace(@CustomerName,' ',''))  
				  RAISERROR('-108',16,1)  
				END  
				ELSE  
				BEGIN  
				 IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE replace(CustomerName,' ','')=replace(@CustomerName,' ','') AND CustomerID <> @CustomerID)  
				  RAISERROR('-108',16,1)       
				END  
			END  
			ELSE  
			BEGIN
				IF @CustomerID=0
				BEGIN
					IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE CustomerName=@CustomerName)
					BEGIN
						RAISERROR('-345',16,1)
					END
				END
				ELSE
				BEGIN
					IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE CustomerName=@CustomerName AND CustomerID <> @CustomerID)
					BEGIN
						RAISERROR('-345',16,1)
					END
				END
			END
		END 
		 
		IF @IsAccountCodeAutoGen IS NOT NULL AND @IsAccountCodeAutoGen=0
		BEGIN
			IF @CustomerID=0
			BEGIN
				IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE CustomerCode=@CustomerCode)
				BEGIN
					RAISERROR('-116',16,1)
				END
			END
			ELSE
			BEGIN
				IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE CustomerCode=@CustomerCode AND CustomerID <> @CustomerID)
				BEGIN
					RAISERROR('-116',16,1)
				END
			END
		END
  
  
  SET @Dt=convert(float,getdate())--Setting Current Date  
  
  	--CODE COMMENTED BY ADIL
  	/*	if(@isparentcode=1)
		begin
			if(@CodeNumber=0)
			begin
				set @CustomerCode=@CodePrefix
			end
			else
			begin
				set @CustomerCode=@CodePrefix+convert(nvarchar,@CodeNumber)
			end	
		end*/
  
  

 			SELECT @TempGuid=[GUID] from [CRM_Customer]  WITH(NOLOCK) 
			WHERE CustomerID=@CustomerID
  
   IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
   BEGIN    
       RAISERROR('-101',16,1)   
   END    
   
   
	 --Delete mapping if any
	 DELETE FROM  COM_CCCCData WHERE NodeID=@CustomerID and CostCenterID=83

	-- Handling of CostCenter Costcenters Extrafields Table
 	INSERT INTO COM_CCCCData ([NodeID],CostCenterID, [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
	 VALUES(@CustomerID,83, @UserName, @Dt, @CompanyGUID,newid())
	 
   
	DECLARE @SQL NVARCHAR(MAX)
   	--Update Main Table
	IF(@StaticFieldsQuery IS NOT NULL AND @StaticFieldsQuery <> '')
	BEGIN
		set @SQL='update [CRM_Customer]
		SET '+@StaticFieldsQuery+'[GUID]= NEWID(), [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE CustomerID='+convert(NVARCHAR,@CustomerID)
		exec(@SQL)
	END
	
	--Update Extended
	IF(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <> '')
	BEGIN
		set @SQL='update CRM_CustomerExtended
		SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE CustomerID='+convert(NVARCHAR,@CustomerID)
		exec(@SQL)
	END

	--Update CostCenter Extra Fields
	set @SQL='update COM_CCCCDATA
	SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
	WHERE NodeID='+convert(nvarchar,@CustomerID) + ' AND COSTCENTERID = 83 '
	exec(@SQL)
 
	--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=83 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 83,@CustomerID,1,@LangID
	end	
  --SETTING ACCOUNT CODE EQUALS AccountID IF EMPTY  
  IF(@CustomerCode IS NULL OR @CustomerCode='')  
  BEGIN  
   UPDATE  CRM_Customer  
   SET CustomerCode = @CustomerCode  
   WHERE CustomerID=@CustomerID        
  END  
      
COMMIT TRANSACTION    
 SELECT * FROM [CRM_Customer] WITH(nolock) WHERE CustomerID=@CustomerID  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @CustomerID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
 	SELECT * FROM [CRM_Customer] WITH(nolock) WHERE CustomerID=@CustomerID  
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
