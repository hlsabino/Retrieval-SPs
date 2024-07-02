USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRen_MoveTenant]
	@TenantID [bigint],
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
		DECLARE @HasAccess BIT,@SelectedIsGroup BIT

		--Check for manadatory paramters  
		IF(@TenantID=0 OR @SelectedNodeID=0)
		BEGIN  
			RAISERROR('-100',16,1)   
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,94,5)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		 
		if (@TenantID <> 0)
		BEGIN
			--Fetch left, right extent of Node along with width.  
			SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft,@Depth=Depth  
			FROM Ren_Tenant WITH(NOLOCK) WHERE TenantID=@TenantID  

			--Fetch left, right extent of selectedNode.  
			SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@SelectedDepth=Depth  
			FROM Ren_Tenant WITH(NOLOCK) WHERE TenantID=@SelectedNodeID  

			IF(@Selectedlft BETWEEN @lft AND @rgt)
			BEGIN
				RAISERROR('-109',16,1)
			END

		--GETTING THE CHILDS OF Lead 
			INSERT INTO @Temp  
			SELECT TenantID FROM Ren_Tenant WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  
		
			IF(@lft>@Selectedlft) --IF MOVE TO UP  
			BEGIN  
					IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
					BEGIN  
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND Lead
						UPDATE Ren_Tenant  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft and rgt<@lft  
						UPDATE Ren_Tenant  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE Lead AND CHILDS
						UPDATE Ren_Tenant  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt- @lft+@Selectedlft+1,lft=lft- @lft+@Selectedlft+1  
						WHERE TenantID in (SELECT ID FROM @Temp)  

						--SET PARENT AS SELECTED NODE IF IT IS GROUP
						UPDATE Ren_Tenant  SET ParentID=@SelectedNodeID  
						WHERE TenantID=@TenantID  

					END  
					ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS Lead  
					BEGIN   
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND Lead
						UPDATE Ren_Tenant  SET rgt=rgt+@Width+1 WHERE rgt>@Selectedlft+1 and rgt<@lft  
						UPDATE Ren_Tenant  SET lft=lft+@Width+1 WHERE lft>@Selectedlft and lft<@lft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE Lead AND CHILDS
						UPDATE Ren_Tenant  SET Depth=Depth -@Depth+@SelectedDepth,rgt=rgt- @lft+@Selectedrgt+1,lft=lft- @lft+@Selectedrgt+1  
						WHERE TenantID in (SELECT ID FROM @Temp)  

						--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
						UPDATE Ren_Tenant  SET ParentID=@SelectedNodeID  
						WHERE TenantID=@TenantID  
					END  
			END  
			ELSE  --IF MOVE DOWN 
			BEGIN  
					IF(@SelectedIsGroup = 1)--SELECTED Node IS GROUP  
					BEGIN  
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND Lead
						UPDATE Ren_Tenant  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft  
						UPDATE Ren_Tenant  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE Lead AND CHILDS
						UPDATE Ren_Tenant  SET  Depth=Depth -@Depth+@SelectedDepth +1, rgt=rgt+(@Selectedlft-@Width)-@lft,lft=lft+(@Selectedlft-@Width)-@lft  
						WHERE TenantID in (SELECT ID FROM @Temp)  

						--SET PARENT AS SELECTED NODE IF IT IS GROUP
						UPDATE Ren_Tenant  SET ParentID=@SelectedNodeID  
						WHERE TenantID=@TenantID  
					END  
					ELSE IF(@SelectedIsGroup = 0)--SELECTED Node IS Lead  
					BEGIN   
						--ADJUST LEFT AND RIGHTS OF THE TREE BETWEEN SELECTED NODE AND Lead
						UPDATE Ren_Tenant  SET rgt=rgt-@Width-1 WHERE rgt>@rgt and rgt<=@Selectedlft+1  
						UPDATE Ren_Tenant  SET lft=lft-@Width-1 WHERE lft>@rgt and lft<=@Selectedlft  

						--ADJUST LEFT,RIGHTS AND DEPTH OF THE Asset AND CHILDS
						UPDATE Ren_Tenant  SET  Depth=Depth -@Depth+@SelectedDepth , rgt=rgt+(@Selectedlft-@Width)-@lft+1,lft=lft+(@Selectedlft-@Width)-@lft+1  
						WHERE TenantID in (SELECT ID from @Temp)  

						--SET PARENTID OF SELECTED NODE IF IT IS NOT GROUP
						UPDATE Ren_Tenant  SET ParentID=@SelectedNodeID  
						WHERE TenantID=@TenantID  
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
