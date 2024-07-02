USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_CheckDuplicateName]
	@CostCenterID [int],
	@NodeID [int],
	@Name [nvarchar](200),
	@AccountType [int],
	@IsGroup [bit],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON; 
		
	--Declaration Section  
	DECLARE @IsDuplicateNameAllowed BIT,@IsIgnoreSpace BIT,@Error INT

	--GETTING PREFERENCE 
	IF ((@CostCenterID=2 OR @CostCenterID=3) AND @IsGroup=1)
		SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=@CostCenterID and  Name='DuplicateGroupNameAllowed'  
	ELSE
		SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=@CostCenterID and  Name='DuplicateNameAllowed'  
	SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=@CostCenterID and  Name='IgnoreSpaces'  
  

	IF @CostCenterID=2
	BEGIN
		DECLARE @AccountTypeAllowDuplicate NVARCHAR(300),@AccountTypeChar NVARCHAR(5)
		SELECT @AccountTypeAllowDuplicate=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='AccountTypeAllowDuplicate'

		--If Duplicate code allowed then check for AccountType
		SET @AccountTypeChar='~'+CONVERT(nvarchar,@AccountType)+'~'

		IF @IsDuplicateNameAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
		BEGIN  
			IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
			BEGIN  
				IF @NodeID=0  
				BEGIN
					IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE Isgroup=@IsGroup and replace(AccountName,' ','')=replace(@Name,' ',''))
						SET @Error=-108--RAISERROR('-108',16,1)  
				END  
				ELSE  
				BEGIN  
					IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE Isgroup=@IsGroup and replace(AccountName,' ','')=replace(@Name,' ','') AND AccountID <> @NodeID)  
						SET @Error=-108
				END  
			END  
			ELSE  
			BEGIN  
				IF @NodeID=0  
				BEGIN  
					IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE Isgroup=@IsGroup and AccountName=@Name)  
						SET @Error=-108
				END  
				ELSE  
				BEGIN  
					IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE Isgroup=@IsGroup and AccountName=@Name AND AccountID <> @NodeID)  
						SET @Error=-108
				END  
			END
		END
	END
	ELSE IF @CostCenterID=3
	BEGIN		
		IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
		BEGIN  
			IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
			BEGIN  
				IF @NodeID=0  
				BEGIN
					IF EXISTS (SELECT ProductID FROM INV_Product WITH(nolock) WHERE Isgroup=@IsGroup and replace(ProductName,' ','')=replace(@Name,' ',''))
						SET @Error=-114--RAISERROR('-108',16,1)
     
				END  
				ELSE  
				BEGIN  
					IF EXISTS (SELECT ProductID FROM INV_Product WITH(nolock) WHERE Isgroup=@IsGroup and replace(ProductName,' ','')=replace(@Name,' ','') AND ProductID <> @NodeID)  
						SET @Error=-114
				END  
			END  
			ELSE  
			BEGIN  
				IF @NodeID=0  
				BEGIN  
					IF EXISTS (SELECT ProductID FROM INV_Product WITH(nolock) WHERE Isgroup=@IsGroup and ProductName=@Name)  
						SET @Error=-114
				END  
				ELSE  
				BEGIN  
					IF EXISTS (SELECT ProductID FROM INV_Product WITH(nolock) WHERE Isgroup=@IsGroup and ProductName=@Name AND ProductID <> @NodeID)  
						SET @Error=-114
				END  
			END
		END
	END
	ELSE
	BEGIN
		DECLARE @Table NVARCHAR(50)
		DECLARE @tempCode NVARCHAR(200),@DUPLICATECODE NVARCHAR(300),@DUPNODENO INT

		SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId 

		--DUPLICATE NAME CHECK  
		SET @tempCode=' @DUPNODENO INT OUTPUT,@Name nvarchar(500)'   
		IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
		BEGIN  
			IF @NodeID=0  
			BEGIN  												
				IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
				begin
					if(@CostCenterID=89)
						SET @DUPLICATECODE=' select @DUPNODENO=OpportunityID  from '+@Table+' WITH(NOLOCK) WHERE (replace(Company,'' '','''')=replace(@Name,'' '','''') OR replace(Code,'' '','''')=replace(@Name,'' '',''''))'    
					else if(@CostCenterID=83)
						SET @DUPLICATECODE=' select @DUPNODENO=CustomerID  from '+@Table+' WITH(NOLOCK) WHERE replace(CustomerName,'' '','''')=replace(@Name,'' '','''')'    
					else if (@CostCenterID=65)
						SET @DUPLICATECODE=' select @DUPNODENO=ContactID  from '+@Table+' WITH(NOLOCK) WHERE (replace(ContactName,'' '','''')=replace(@Name,'' '','''')	OR replace(FirstName,'' '','''')=replace(@Name,'' '','''') OR replace(MiddleName,'' '','''')=replace(@Name,'' '','''') OR replace(LastName,'' '','''')=replace(@Name,'' '',''''))'    
					else
						SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WITH(NOLOCK) WHERE replace(NAME,'' '','''')=replace(@Name,'' '','''')'    
				end
				ELSE
				begin
					if(@CostCenterID=89)
						SET @DUPLICATECODE=' select @DUPNODENO=OpportunityID  from '+@Table+' WITH(NOLOCK) WHERE (Company=@Name OR Code=@Name)'    
					else if(@CostCenterID=83)
						SET @DUPLICATECODE=' select @DUPNODENO=CustomerID  from '+@Table+' WITH(NOLOCK) WHERE CustomerName=@Name'    
					else if (@CostCenterID=65)
						SET @DUPLICATECODE=' select @DUPNODENO=ContactID  from '+@Table+' WITH(NOLOCK) WHERE (ContactName=@Name	OR FirstName=@Name OR MiddleName=@Name OR LastName=@Name)'    
					else
						SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WITH(NOLOCK) WHERE NAME=@Name'    
				end
			END  
			ELSE  
			BEGIN   
			
				IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1
				begin
					if(@CostCenterID=89)
						SET @DUPLICATECODE=' select @DUPNODENO=OpportunityID  from '+@Table+' WITH(NOLOCK) WHERE (replace(Company,'' '','''')=replace(@Name,'' '','''') OR replace(Code,'' '','''')=replace(@Name,'' '','''')) AND OpportunityID!='+CONVERT(VARCHAR,@NodeID)   
					else if(@CostCenterID=83)
						SET @DUPLICATECODE=' select @DUPNODENO=CustomerID  from '+@Table+' WITH(NOLOCK) WHERE replace(CustomerName,'' '','''')=replace(@Name,'' '','''') AND CustomerID!='+CONVERT(VARCHAR,@NodeID)
					else if (@CostCenterID=65)
						SET @DUPLICATECODE=' select @DUPNODENO=ContactID  from '+@Table+' WITH(NOLOCK) WHERE (replace(ContactName,'' '','''')=replace(@Name,'' '','''')	OR replace(FirstName,'' '','''')=replace(@Name,'' '','''') OR replace(MiddleName,'' '','''')=replace(@Name,'' '','''') OR replace(LastName,'' '','''')=replace(@Name,'' '','''')) AND ContactID!='+CONVERT(VARCHAR,@NodeID)
					else
						SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WITH(NOLOCK) WHERE replace(NAME,'' '','''')=replace(@Name,'' '','''') AND NodeID!='+CONVERT(VARCHAR,@NodeID)   
				end
				ELSE
				begin
					if(@CostCenterID=89)
						SET @DUPLICATECODE=' select @DUPNODENO=OpportunityID  from '+@Table+' WITH(NOLOCK) WHERE (Company=@Name OR Code=@Name) AND OpportunityID!='+CONVERT(VARCHAR,@NodeID)   
					else if(@CostCenterID=83)
						SET @DUPLICATECODE=' select @DUPNODENO=CustomerID  from '+@Table+' WITH(NOLOCK) WHERE CustomerName=@Name AND CustomerID!='+CONVERT(VARCHAR,@NodeID)   
					else if (@CostCenterID=65)
						SET @DUPLICATECODE=' select @DUPNODENO=ContactID  from '+@Table+' WITH(NOLOCK) WHERE (ContactName=@Name	OR FirstName=@Name OR MiddleName=@Name OR LastName=@Name) AND ContactID!='+CONVERT(VARCHAR,@NodeID)   
					else
						SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WITH(NOLOCK) WHERE NAME=@Name AND NodeID!='+CONVERT(VARCHAR,@NodeID)   
				end	
			END  
			print @DUPLICATECODE
			EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT ,@Name 
			IF @DUPNODENO >0  
			BEGIN  
				RAISERROR('-112',16,1)  
			END  
		END 
  
	END

SET NOCOUNT OFF;

IF @Error IS NOT NULL
	SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
	FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=@Error AND LanguageID=@LangID
else
	select '' ErrorMessage

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		 SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		 FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
