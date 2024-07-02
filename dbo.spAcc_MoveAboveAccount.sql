﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAcc_MoveAboveAccount]
	@AccountID [bigint],
	@SelectedNodeID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
SET NOCOUNT ON  
BEGIN TRY  
		--Declaration Section
		DECLARE @HasAccess BIT

		--SP Required Parameters Check
		IF @AccountID=0 OR @SelectedNodeID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User access check 
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,5)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
	
	
		DECLARE @lft BIGINT,@rgt BIGINT,@Width INT,@Selectedlft BIGINT,@Selectedrgt BIGINT,@SelectedDepth INT,@Depth INT,@ParentID BIGINT  
		DECLARE @Temp TABLE (ID BIGINT) 
		DECLARE @SelectedIsGroup BIT
		
		--Fetch left, right extent of Node along with width.  
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
		FROM [ACC_Accounts] WITH(NOLOCK) WHERE AccountID=@AccountID   

		--Fetch left, right extent of selectedNode.  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
		FROM [ACC_Accounts] WITH(NOLOCK) WHERE AccountID=@SelectedNodeID     


		IF(@Selectedlft BETWEEN @lft AND @rgt)
		BEGIN
			RAISERROR('-109',16,1)
		END

		--GETTING THE CHILDS OF PRODUCTS 
		INSERT INTO @Temp  
		SELECT AccountID FROM [ACC_Accounts] WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  


		
		IF(@lft>@Selectedlft) --IF MOVE TO UP  
		BEGIN   
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE [ACC_Accounts]  SET lft=lft+@Width+1 WHERE lft>=@Selectedlft and rgt<@lft  
					UPDATE [ACC_Accounts]  SET rgt=rgt+@Width+1 WHERE lft>=@Selectedlft and rgt<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE [ACC_Accounts]  SET rgt=@Selectedlft-@lft+rgt,lft=@Selectedlft-@lft+lft					
					WHERE AccountID in (SELECT ID FROM @Temp)  
 
		END  
		ELSE  --IF MOVE DOWN 
		BEGIN  
 
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE [ACC_Accounts]  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedrgt  
					UPDATE [ACC_Accounts]  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedrgt  

					set @Width=@Selectedrgt-@Width
					
					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE [ACC_Accounts]  SET  rgt=@Selectedrgt-1+rgt-@rgt,lft=@Selectedrgt-1+lft-@rgt
					WHERE AccountID in (SELECT ID from @Temp)  
 
		END   

  
COMMIT TRANSACTION 
SET NOCOUNT OFF;   
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=101 AND LanguageID=@LangID
RETURN 1
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  
		IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
