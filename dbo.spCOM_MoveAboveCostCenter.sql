USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_MoveAboveCostCenter]
	@CostCenterId [int],
	@NodeID [bigint],
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
		IF @CostCenterID=0 OR @NodeID=0 OR @SelectedNodeID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User access check 
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterId,5)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
	
		--To get costcenter table name
		SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId

		SET @strNodeID=convert(nvarchar,@NodeID)  
		SET @strSelectedNodeID=convert(nvarchar,@SelectedNodeID)  
		
		SET @SQL='
		DECLARE @lft BIGINT,@rgt BIGINT,@Width INT,@Selectedlft BIGINT,@Selectedrgt BIGINT,@SelectedDepth INT,@Depth INT,@ParentID BIGINT  
		DECLARE @Temp TABLE (ID BIGINT) 
		DECLARE @HasAccess bit,@SelectedIsGroup BIT
		
		--Fetch left, right extent of Node along with width.  
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
		FROM '+@Table+' WITH(NOLOCK) WHERE NodeID='+@strNodeID+'    

		--Fetch left, right extent of selectedNode.  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
		FROM ['+@Table+'] WITH(NOLOCK) WHERE NodeID='+@strSelectedNodeID+'   


		IF(@Selectedlft BETWEEN @lft AND @rgt)
		BEGIN
			RAISERROR(''-109'',16,1)
		END

		--GETTING THE CHILDS OF PRODUCTS 
		INSERT INTO @Temp  
		SELECT NodeID FROM ['+@Table+'] WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  


		
		IF(@lft>@Selectedlft) --IF MOVE TO UP  
		BEGIN   
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE '+@Table+'  SET lft=lft+@Width+1 WHERE lft>=@Selectedlft and rgt<@lft  
					UPDATE '+@Table+'  SET rgt=rgt+@Width+1 WHERE lft>=@Selectedlft and rgt<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE '+@Table+'  SET rgt=@Selectedlft-@lft+rgt,lft=@Selectedlft-@lft+lft					
					WHERE NodeID in (SELECT ID FROM @Temp)  
 
		END  
		ELSE  --IF MOVE DOWN 
		BEGIN  
 
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND PRODUCT
					UPDATE '+@Table+'  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedrgt  
					UPDATE '+@Table+'  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedrgt  

					set @Width=@Selectedrgt-@Width
					
					--ADJUST LEFT,RIGHTS AND DEPTH OF THE PRODUCT AND CHILDS
					UPDATE '+@Table+'  SET  rgt=@Selectedrgt-1+rgt-@rgt,lft=@Selectedrgt-1+lft-@rgt
					WHERE NodeID in (SELECT ID from @Temp)  
 
		END   '

		 
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
