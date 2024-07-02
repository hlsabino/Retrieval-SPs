USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_CheckDuplicate]
	@AccountID [bigint]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @IsDuplicateNameAllowed bit,@IsDuplicateCodeAllowed bit,@IsIgnoreSpace bit,@AccountTypeAllowDuplicate NVARCHAR(300),@AccountTypeChar NVARCHAR(5)
  DECLARE @AccountCode nvarchar(200),  @AccountName nvarchar(500),@AccountTypeID int
  
  	SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateCodeAllowed'  
	SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateNameAllowed'  
	SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=2 and  Name='IgnoreSpaces'  
	SELECT @AccountTypeAllowDuplicate=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='AccountTypeAllowDuplicate'

  
	select @AccountCode=[AccountCode],@AccountName=AccountName,@AccountTypeID=AccountTypeID
	FROM ACC_Accounts WITH(nolock) WHERE AccountID=@AccountID
  
	--If Duplicate code allowed then check for AccountType
	SET @AccountTypeChar='~'+CONVERT(nvarchar,@AccountTypeID)+'~'


	--DUPLICATE CODE CHECK  
	IF @IsDuplicateCodeAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
	BEGIN
		IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE [AccountCode]=@AccountCode AND AccountID <> @AccountID)  
		RAISERROR('-116',16,1)  
	END


	--DUPLICATE CHECK  
	IF @IsDuplicateNameAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
	BEGIN  
		IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
		BEGIN 
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE replace(AccountName,' ','')=replace(@AccountName,' ','') AND AccountID <> @AccountID)  
				RAISERROR('-108',16,1)       
			
		END  
		ELSE  
		BEGIN
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE AccountName=@AccountName AND AccountID <> @AccountID)  
				RAISERROR('-108',16,1)  
		END
	END  

  
GO
