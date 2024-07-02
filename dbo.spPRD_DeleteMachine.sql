USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_DeleteMachine]
	@ResourceID [int] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted INT,@lft INT,@rgt INT,@Width INT

		--SP Required Parameters Check
		if(@ResourceID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		IF EXISTS(SELECT ResourceName FROM PRD_Resources WHERE ResourceID=@ResourceID AND ResourceID=1)
		BEGIN
			RAISERROR('-115',16,1)
		END
		
		declare @Tbl as table(id int identity(1,1),ResourceID INT)
		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM PRD_Resources WITH(NOLOCK) WHERE ResourceID=@ResourceID
		
		if exists(SELECT * FROM PRD_Resources WITH(NOLOCK) WHERE ResourceID=@ResourceID and IsGroup=1)
		BEGIN
			insert into @Tbl(ResourceID)
			select ResourceID from PRD_Resources with(nolock) WHERE lft >= @lft AND rgt <= @rgt
		END
		else
			insert into @Tbl(ResourceID)values(@ResourceID)

			--Delete from exteneded table
		DELETE a FROM PRD_ResourceExtended a with(nolock)
		join @Tbl b on a.ResourceID=b.ResourceID

		--Delete from main table
		DELETE a FROM PRD_Resources a with(nolock)
		join @Tbl b on a.ResourceID=b.ResourceID

		SET @RowsDeleted=@@rowcount


		--Delete from Contacts
		DELETE a FROM  COM_Contacts a with(nolock)
		join @Tbl b on a.FeaturePK=b.ResourceID
		WHERE a.FeatureID=71 

		--Delete from Notes
		DELETE a FROM  COM_Notes a with(nolock)
		join @Tbl b on a.FeaturePK=b.ResourceID
		WHERE a.FeatureID=71 

		--Delete from Files
		DELETE a FROM  COM_Files  a with(nolock)
		join @Tbl b on a.FeaturePK=b.ResourceID
		WHERE a.FeatureID=71 

	

		--Update left and right extent to set the tree
		UPDATE PRD_Resources SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE PRD_Resources SET lft = lft - @Width WHERE lft > @rgt;
	

COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN @RowsDeleted
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
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
