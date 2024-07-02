USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_MoveAfterProduct]
	@ProductID [bigint],
	@SelectedNodeID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
SET NOCOUNT ON  
BEGIN TRY  
		--Declaration Section
		DECLARE @HasAccess BIT

		--SP Required Parameters Check
		IF @ProductID=0 OR @SelectedNodeID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User access check 
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,5)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
	
		
		DECLARE @lft BIGINT,@rgt BIGINT,@Width INT,@Selectedlft BIGINT,@Selectedrgt BIGINT,@SelectedDepth INT,@Depth INT,@ParentID BIGINT  
		DECLARE @Temp TABLE (ID BIGINT) 
		DECLARE @SelectedIsGroup BIT
		
		--Fetch left, right extent of Node along with width.  
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
		FROM INV_Product WITH(NOLOCK) WHERE ProductID =@ProductID   

		--Fetch left, right extent of selectedNode.  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
		FROM [INV_Product] WITH(NOLOCK) WHERE ProductID =@SelectedNodeID     


		IF(@Selectedlft BETWEEN @lft AND @rgt)
		BEGIN
			RAISERROR('-109',16,1)
		END

		--GETTING THE CHILDS OF PRODUCTS 
		INSERT INTO @Temp  
		SELECT ProductID  FROM [INV_Product] WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  


		
		IF(@lft>@Selectedlft) --IF MOVE TO UP  
		BEGIN   
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE INV_Product  SET lft=lft+@Width+1 WHERE lft>@Selectedrgt and rgt<@lft  
					UPDATE INV_Product  SET rgt=rgt+@Width+1 WHERE lft>@Selectedrgt and rgt<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE INV_Product  SET rgt=@Selectedrgt+1-@lft+rgt,lft=@Selectedrgt+1-@lft+lft					
					WHERE ProductID  in (SELECT ID FROM @Temp)  
 
		END  
		ELSE  --IF MOVE DOWN 
		BEGIN  
 
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE INV_Product  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedrgt  
					UPDATE INV_Product  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedrgt  

					set @Width=@Selectedrgt-@Width
					
					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE INV_Product  SET  rgt=@Width-@lft+rgt,lft=@Width-@lft+lft
					WHERE ProductID  in (SELECT ID from @Temp)  
 
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
