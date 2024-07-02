USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_MoveDashBoard]
	@DashBoardID [bigint],
	@SelectedNodeID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
SET NOCOUNT ON  
BEGIN TRY  
		--Declaration Section
		DECLARE @HasAccess BIT,@Table nvarchar(50),@SQL nvarchar(max),@strNodeID nvarchar(50),@strSelectedNodeID nvarchar(50)  

		--SP Required Parameters Check
		IF @DashBoardID=0 OR @SelectedNodeID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User access check 
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,117,5)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		 
		--To get costcenter table name
		SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=117 
		 
		SET @strSelectedNodeID=convert(nvarchar,@SelectedNodeID)  
		
		 
		DECLARE @lft BIGINT,@rgt BIGINT,@Width INT,@Selectedlft BIGINT,@Selectedrgt BIGINT,@SelectedDepth INT,@Depth INT,@ParentID BIGINT  
		DECLARE @Temp TABLE (ID BIGINT) 
		DECLARE @SelectedIsGroup BIT
		
		--Fetch left, right extent of Node along with width.  
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
		FROM ADM_DashBoard WITH(NOLOCK) WHERE DashBoardID=@DashBoardID

		--Fetch left, right extent of selectedNode.  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
		FROM ADM_DashBoard WITH(NOLOCK) WHERE DashBoardID=@SelectedNodeID


		IF(@Selectedlft BETWEEN @lft AND @rgt)
		BEGIN
			RAISERROR('-109',16,1)
		END

		--GETTING THE CHILDS OF PRODUCTS 
		INSERT INTO @Temp  
		SELECT NodeID FROM ADM_DashBoard WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  


		
		IF(@lft>@Selectedlft) --IF MOVE TO UP  
		BEGIN  
				IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
				BEGIN  
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE ADM_DashBoard  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft and rgt<@lft  
					UPDATE ADM_DashBoard  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE ADM_DashBoard  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt- @lft+@Selectedlft+1,lft=lft- @lft+@Selectedlft+1  
					WHERE NodeID in (SELECT ID FROM @Temp)  

					--SET PARENT AS SELECTED NODE IF IT IS GROUP
					UPDATE ADM_DashBoard  SET ParentID=@SelectedNodeID
					WHERE DASHBOARDID=@DashBoardID   

				END  
				ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS PRODUCT  
				BEGIN   

					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE ADM_DashBoard  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft+1 and rgt<@lft  
					UPDATE ADM_DashBoard  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE ADM_DashBoard  SET Depth=Depth -@Depth+@SelectedDepth,rgt=rgt- @lft+@Selectedrgt+1,lft=lft- @lft+@Selectedrgt+1  
					WHERE NodeID in (SELECT ID FROM @Temp)  


					--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
					UPDATE ADM_DashBoard  SET ParentID=@ParentID  
					WHERE DASHBOARDID=@DashBoardID   

				END  
		END  
		ELSE  --IF MOVE DOWN 
		BEGIN  

				IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
				BEGIN  

					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE ADM_DashBoard  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft  
					UPDATE ADM_DashBoard  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE ADM_DashBoard  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt+(@Selectedlft-@Width)-@lft,lft=lft+(@Selectedlft-@Width)-@lft  
					WHERE NodeID in (SELECT ID FROM @Temp)  

					--SET PARENT AS SELECTED NODE IF IT IS GROUP
					UPDATE ADM_DashBoard  SET ParentID=@SelectedNodeID 
					WHERE DASHBOARDID=@DashBoardID   

				END  
				ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS PRODUCT  
				BEGIN   

					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE ADM_DashBoard  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft+1  
					UPDATE ADM_DashBoard  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE ADM_DashBoard  SET  Depth=Depth -@Depth+@SelectedDepth , rgt=rgt+(@Selectedlft-@Width)-@lft+1,lft=lft+(@Selectedlft-@Width)-@lft+1  
					WHERE DASHBOARDID in (SELECT ID from @Temp)  


					--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
					UPDATE ADM_DashBoard  SET ParentID=@ParentID  
					WHERE DASHBOARDID=@DashBoardID   

				END   

		END    

		 print @SQL
		EXEC(@SQL)  
  
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
