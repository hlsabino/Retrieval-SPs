USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_MoveCostCenter]
	@CostCenterId [int],
	@NodeID [bigint],
	@SelectedNodeID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
SET NOCOUNT ON  
BEGIN TRY  
		--Declaration Section
		DECLARE @HasAccess BIT,@Table nvarchar(50),@SQL nvarchar(max),@strNodeID nvarchar(50),@PK nvarchar(50),@strSelectedNodeID nvarchar(50)  
		DECLARE @TypeAccount bigint, @TypeSelected bigint,@nodeparentid bigint
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
		
		IF @CostCenterID=0
		BEGIN
			SELECT @TypeAccount =AccountTypeID,@nodeparentid=ParentID from acc_Accounts with(nolock) where accountid=@NodeID
			SELECT @TypeSelected =AccountTypeID from acc_Accounts with(nolock) where accountid=@SelectedNodeID

			if (@SelectedNodeID<>1 and @nodeparentid<>1)
			begin
				if((@TypeAccount in (1,2,7,10,13,3,6,14) and  @TypeSelected in (4,8,11,5,9,12)) or (@TypeSelected in (1,2,7,10,13,3,6,14) and  @TypeAccount  in (4,8,11,5,9,12)))
				begin
					RAISERROR('-348',16,1)
				end
			end
		END
		select @PK=PrimaryKey,@Table=TableName from adm_Features with(nolock) where FeatureID=@CostCenterId
		if @CostCenterId=40
		begin
			set @PK='ProfileID'
			set @Table='COM_CCPricesDefn'
		end
		else if @CostCenterId=45
		begin
			set @PK='ProfileID'
			set @Table='COM_CCTaxesDefn'
		end
		
		SET @strNodeID=convert(nvarchar,@NodeID)  
		SET @strSelectedNodeID=convert(nvarchar,@SelectedNodeID)  
		
		SET @SQL='
		DECLARE @lft BIGINT,@rgt BIGINT,@Width INT,@Selectedlft BIGINT,@Selectedrgt BIGINT,@SelectedDepth INT,@Depth INT,@ParentID BIGINT  
		DECLARE @Temp TABLE (ID BIGINT) 
		DECLARE @HasAccess bit,@SelectedIsGroup BIT
		
		--Fetch left, right extent of Node along with width.  
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
		FROM '+@Table+' WITH(NOLOCK) WHERE '+@PK+'='+@strNodeID+'    

		--Fetch left, right extent of selectedNode.  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
		FROM ['+@Table+'] WITH(NOLOCK) WHERE '+@PK+'='+@strSelectedNodeID+'   

		IF(@Selectedlft BETWEEN @lft AND @rgt)
		BEGIN
			RAISERROR(''-109'',16,1)
		END

		--GETTING THE CHILDS  
		INSERT INTO @Temp  
		SELECT '+@PK+' FROM ['+@Table+'] WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  

		IF(@lft>@Selectedlft) --IF MOVE TO UP  
		BEGIN  
				IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
				BEGIN  
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE 
					UPDATE '+@Table+'  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft and rgt<@lft  
					UPDATE '+@Table+'  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE CHILDS
					UPDATE '+@Table+'  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt- @lft+@Selectedlft+1,lft=lft- @lft+@Selectedlft+1  
					WHERE '+@PK+' in (SELECT ID FROM @Temp)  

					--SET PARENT AS SELECTED NODE IF IT IS GROUP
					UPDATE '+@Table+'  SET ParentID='+@strSelectedNodeID+'   
					WHERE '+@PK+'='+@strNodeID+'    

				END  
				ELSE IF(@SelectedIsGroup = 0)--SELECTED Node   
				BEGIN   

					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE 
					UPDATE '+@Table+'  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft+1 and rgt<@lft  
					UPDATE '+@Table+'  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE CHILDS
					UPDATE '+@Table+'  SET Depth=Depth -@Depth+@SelectedDepth,rgt=rgt- @lft+@Selectedrgt+1,lft=lft- @lft+@Selectedrgt+1  
					WHERE '+@PK+' in (SELECT ID FROM @Temp)  


					--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
					UPDATE '+@Table+'  SET ParentID=@ParentID  
					WHERE '+@PK+'='+@strNodeID+'    

				END  
		END  
		ELSE  --IF MOVE DOWN 
		BEGIN  
				IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
				BEGIN  
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE 
					UPDATE '+@Table+'  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft  
					UPDATE '+@Table+'  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE CHILDS
					UPDATE '+@Table+'  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt+(@Selectedlft-@Width)-@lft,lft=lft+(@Selectedlft-@Width)-@lft  
					WHERE '+@PK+' in (SELECT ID FROM @Temp)  

					--SET PARENT AS SELECTED NODE IF IT IS GROUP
					UPDATE '+@Table+'  SET ParentID='+@strSelectedNodeID+'   
					WHERE '+@PK+'='+@strNodeID+'    

				END  
				ELSE IF(@SelectedIsGroup = 0)--SELECTED Node  
				BEGIN
					--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE 
					UPDATE '+@Table+'  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft+1  
					UPDATE '+@Table+'  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

					--ADJUST LEFT,RIGHTS AND DEPTH OF THE CHILDS
					UPDATE '+@Table+'  SET  Depth=Depth -@Depth+@SelectedDepth , rgt=rgt+(@Selectedlft-@Width)-@lft+1,lft=lft+(@Selectedlft-@Width)-@lft+1  
					WHERE '+@PK+' in (SELECT ID from @Temp)  

					--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
					UPDATE '+@Table+'  SET ParentID=@ParentID  
					WHERE '+@PK+'='+@strNodeID+'    
				END   
		END   '

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
