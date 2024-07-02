USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_MoveServiceContract]
	@SvcContractID [bigint],
	@SelectedNodeID [bigint],
	@UserID [bigint],
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
		IF(@SvcContractID < 0 or @SelectedNodeID < 0)     
		RAISERROR('-100',16,1)   
  
  	if (@SvcContractID <> 0)
		BEGIN
			--Fetch left, right extent of Node along with width.  
			SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
			FROM CRM_ServiceContract WITH(NOLOCK) WHERE SvcContractID=@SvcContractID  

			--Fetch left, right extent of selectedNode.  
			SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
			FROM CRM_ServiceContract WITH(NOLOCK) WHERE SvcContractID=@SelectedNodeID  

			IF(@Selectedlft BETWEEN @lft AND @rgt)
			BEGIN
				RAISERROR('-109',16,1)
			END

		--GETTING THE CHILDS OF Lead 
			INSERT INTO @Temp  
			SELECT @SvcContractID FROM CRM_ServiceContract WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  
		 
			IF(@lft>@Selectedlft) --IF MOVE TO UP  
			BEGIN  
			 
					IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
					BEGIN  
			 
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND Lead
						UPDATE CRM_ServiceContract  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft and rgt<@lft  
						UPDATE CRM_ServiceContract  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE Lead AND CHILDS
						UPDATE CRM_ServiceContract  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt- @lft+@Selectedlft+1,lft=lft- @lft+@Selectedlft+1  
						WHERE SvcContractID in (SELECT ID FROM @Temp)  

						--SET PARENT AS SELECTED NODE IF IT IS GROUP
						UPDATE CRM_ServiceContract  SET ParentID=@SelectedNodeID  
						WHERE SvcContractID=@SvcContractID

					END  
					ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS Lead  
					BEGIN   
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND Lead
						UPDATE CRM_ServiceContract  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft+1 and rgt<@lft  
						UPDATE CRM_ServiceContract  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE Lead AND CHILDS
						UPDATE CRM_ServiceContract  SET Depth=Depth -@Depth+@SelectedDepth,rgt=rgt- @lft+@Selectedrgt+1,lft=lft- @lft+@Selectedrgt+1  
						WHERE SvcContractID in (SELECT ID FROM @Temp)  

						--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
						UPDATE CRM_ServiceContract  SET ParentID=@SelectedNodeID  
						WHERE SvcContractID=@SvcContractID  
					END  
			END  
			ELSE  --IF MOVE DOWN 
			BEGIN  
					IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
					BEGIN  
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND Lead
						UPDATE CRM_ServiceContract  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft  
						UPDATE CRM_ServiceContract  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE Lead AND CHILDS
						UPDATE CRM_ServiceContract  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt+(@Selectedlft-@Width)-@lft,lft=lft+(@Selectedlft-@Width)-@lft  
						WHERE SvcContractID in (SELECT ID FROM @Temp)  

						--SET PARENT AS SELECTED NODE IF IT IS GROUP
						UPDATE CRM_ServiceContract  SET ParentID=@SelectedNodeID  
						WHERE SvcContractID=@SvcContractID  
					END  
					ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS Lead  
					BEGIN   
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND Lead
						UPDATE CRM_ServiceContract  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft+1  
						UPDATE CRM_ServiceContract  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE Asset AND CHILDS
						UPDATE CRM_ServiceContract  SET  Depth=Depth -@Depth+@SelectedDepth , rgt=rgt+(@Selectedlft-@Width)-@lft+1,lft=lft+(@Selectedlft-@Width)-@lft+1  
						WHERE SvcContractID in (SELECT ID from @Temp)  

						--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
						UPDATE CRM_ServiceContract  SET ParentID=@SelectedNodeID  
						WHERE SvcContractID=@SvcContractID
					END   
			END  
		END
		ELSE
		BEGIN
			RAISERROR('-348',16,1)
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
