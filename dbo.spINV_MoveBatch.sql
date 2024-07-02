USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_MoveBatch]
	@BatchID [bigint],
	@SelectedNodeID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON; 
 
		--Declaration Section  
		DECLARE @lft BIGINT,@rgt BIGINT,@Width INT,@Selectedlft BIGINT,@Selectedrgt BIGINT,@SelectedDepth INT,@Depth INT,@ParentID BIGINT  
		DECLARE @Temp TABLE (ID BIGINT) 
		DECLARE @HasAccess bit,@SelectedIsGroup BIT

		--Check for manadatory paramters  
		IF(@BatchID < 0 or @SelectedNodeID < 0)     
		RAISERROR('-100',16,1)   

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,16,5)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

  
		--Fetch left, right extent of Node along with width.  
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
		FROM INV_Batches WITH(NOLOCK) WHERE BatchID=@BatchID  

		--Fetch left, right extent of selectedNode.  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
		FROM [INV_Batches] WITH(NOLOCK) WHERE BatchID=@SelectedNodeID  


		IF(@Selectedlft BETWEEN @lft AND @rgt)
		BEGIN
			RAISERROR('-109',16,1)
		END

		--GETTING THE CHILDS OF PRODUCTS 
		INSERT INTO @Temp  
		SELECT BatchID FROM [INV_Batches] WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  


		
		IF(@lft>@Selectedlft) --IF MOVE TO UP  
		BEGIN  
				IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
				BEGIN  
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE INV_Batches  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft and rgt<@lft  
					UPDATE INV_Batches  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE INV_Batches  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt- @lft+@Selectedlft+1,lft=lft- @lft+@Selectedlft+1  
					WHERE BatchID in (SELECT ID FROM @Temp)  

					--SET PARENT AS SELECTED NODE IF IT IS GROUP
					UPDATE INV_Batches  SET ParentID=@SelectedNodeID  
					WHERE BatchID=@BatchID  

				END  
				ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS PRODUCT  
				BEGIN   

					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE INV_Batches  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft+1 and rgt<@lft  
					UPDATE INV_Batches  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE INV_Batches  SET Depth=Depth -@Depth+@SelectedDepth,rgt=rgt- @lft+@Selectedrgt+1,lft=lft- @lft+@Selectedrgt+1  
					WHERE BatchID in (SELECT ID FROM @Temp)  


					--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
					UPDATE INV_Batches  SET ParentID=@ParentID  
					WHERE BatchID=@BatchID  

				END  
		END  
		ELSE  --IF MOVE DOWN 
		BEGIN  

				IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
				BEGIN  

					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE INV_Batches  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft  
					UPDATE INV_Batches  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE INV_Batches  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt+(@Selectedlft-@Width)-@lft,lft=lft+(@Selectedlft-@Width)-@lft  
					WHERE BatchID in (SELECT ID FROM @Temp)  

					--SET PARENT AS SELECTED NODE IF IT IS GROUP
					UPDATE INV_Batches  SET ParentID=@SelectedNodeID  
					WHERE BatchID=@BatchID  

				END  
				ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS PRODUCT  
				BEGIN   

					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE INV_Batches  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft+1  
					UPDATE INV_Batches  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE INV_Batches  SET  Depth=Depth -@Depth+@SelectedDepth , rgt=rgt+(@Selectedlft-@Width)-@lft+1,lft=lft+(@Selectedlft-@Width)-@lft+1  
					WHERE BatchID in (SELECT ID from @Temp)  


					--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
					UPDATE INV_Batches  SET ParentID=@ParentID  
					WHERE BatchID=@BatchID  

				END   

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
		 SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		 FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
