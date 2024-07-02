USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_MoveAccount]
	@AccountID [int],
	@SelectedNodeID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON; 
 
		--Declaration Section  
		DECLARE @lft INT,@rgt INT,@Width INT,@Selectedlft INT,@Selectedrgt INT,@SelectedDepth INT,@Depth INT,@ParentID INT  
		DECLARE @Temp TABLE (ID INT)
		DECLARE @TypeAccount INT, @TypeSelected INT,@nodeparentid INT
		DECLARE @HasAccess BIT,@SelectedIsGroup BIT
		
		--Check if Selected NodeID Root NodeID
		if @SelectedNodeID=1 AND NOT EXISTS (select Value from COM_CostCenterPreferences with(nolock) where FeatureID=2 and Name='AllowChildAtRoot' and Value='True')
		BEGIN
			RAISERROR('-226',16,1)
		END
		--IF(@SelectedNodeID=1)
		--BEGIN
		--	RAISERROR('-226',16,1)
		--END

		--Check for manadatory paramters  
		IF(@AccountID=0 OR @SelectedNodeID=0)
		BEGIN  
			RAISERROR('-100',16,1)   
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,5)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		SELECT @TypeAccount =AccountTypeID,@nodeparentid=ParentID from acc_Accounts with(nolock) where accountid=@AccountID
		SELECT @TypeSelected =AccountTypeID from acc_Accounts with(nolock) where accountid=@SelectedNodeID

		if (@SelectedNodeID<>1 and @nodeparentid<>1)
		begin
			if((@TypeAccount in (1,2,7,10,13,3,6,14) and  @TypeSelected in (4,8,11,5,9,12)) or (@TypeSelected in (1,2,7,10,13,3,6,14) and  @TypeAccount  in (4,8,11,5,9,12)))
			begin
				RAISERROR('-348',16,1)
			end
		end
		 
			--Fetch left, right extent of Node along with width.  
			SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
			FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=@AccountID  

			--Fetch left, right extent of selectedNode.  
			SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
			FROM [ACC_Accounts] WITH(NOLOCK) WHERE AccountID=@SelectedNodeID  
			--select @lft,@Selectedlft,@Selectedrgt, @SelectedNodeID
			IF(@Selectedlft BETWEEN @lft AND @rgt)
			BEGIN
				RAISERROR('-109',16,1)
			END

		--GETTING THE CHILDS OF PRODUCTS 
			INSERT INTO @Temp  
			SELECT AccountID FROM [ACC_Accounts] WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  
		
			IF(@lft>@Selectedlft) --IF MOVE TO UP  
			BEGIN  
					IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
					BEGIN  
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
						UPDATE ACC_Accounts  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft and rgt<@lft  
						UPDATE ACC_Accounts  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
						UPDATE ACC_Accounts  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt- @lft+@Selectedlft+1,lft=lft- @lft+@Selectedlft+1  
						WHERE AccountID in (SELECT ID FROM @Temp)  

						--SET PARENT AS SELECTED NODE IF IT IS GROUP
						UPDATE ACC_Accounts  SET ParentID=@SelectedNodeID  
						WHERE AccountID=@AccountID  

					END  
					ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS PRODUCT  
					BEGIN   
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
						UPDATE ACC_Accounts  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft+1 and rgt<@lft  
						UPDATE ACC_Accounts  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
						UPDATE ACC_Accounts  SET Depth=Depth -@Depth+@SelectedDepth,rgt=rgt- @lft+@Selectedrgt+1,lft=lft- @lft+@Selectedrgt+1  
						WHERE AccountID in (SELECT ID FROM @Temp)  

						--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
						UPDATE ACC_Accounts  SET ParentID=@ParentID  
						WHERE AccountID=@AccountID  
					END  
			END  
			ELSE  --IF MOVE DOWN 
			BEGIN  
					IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
					BEGIN  
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
						UPDATE ACC_Accounts  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft  
						UPDATE ACC_Accounts  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
						UPDATE ACC_Accounts  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt+(@Selectedlft-@Width)-@lft,lft=lft+(@Selectedlft-@Width)-@lft  
						WHERE AccountID in (SELECT ID FROM @Temp)  

						--SET PARENT AS SELECTED NODE IF IT IS GROUP
						UPDATE ACC_Accounts  SET ParentID=@SelectedNodeID  
						WHERE AccountID=@AccountID  
					END  
					ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS PRODUCT  
					BEGIN   
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
						UPDATE ACC_Accounts  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft+1  
						UPDATE ACC_Accounts  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
						UPDATE ACC_Accounts  SET  Depth=Depth -@Depth+@SelectedDepth , rgt=rgt+(@Selectedlft-@Width)-@lft+1,lft=lft+(@Selectedlft-@Width)-@lft+1  
						WHERE AccountID in (SELECT ID from @Temp)  

						--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
						UPDATE ACC_Accounts  SET ParentID=@ParentID  
						WHERE AccountID=@AccountID  
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
