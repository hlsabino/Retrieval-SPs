USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_DeleteCampaigns]
	@CampaignID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted INT,@lft INT,@rgt INT,@Width INT

		--SP Required Parameters Check
		if(@CampaignID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,88,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		IF EXISTS(SELECT [Name] FROM CRM_Campaigns with(nolock) WHERE CampaignID=@CampaignID AND CampaignID=1)
		BEGIN
			RAISERROR('-115',16,1)
		END

		--ondelete External function
		IF (@CampaignID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=88 and Mode=8
			if(@tablename<>'')
				exec @tablename 88,@CampaignID,'',1,@LangID	
		END	
		
		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM CRM_Campaigns WITH(NOLOCK) WHERE CampaignID=@CampaignID
		
		---Delete from Extended Table
     	DELETE FROM CRM_CampaignsExtended WHERE CampaignID in
		(select CampaignID from CRM_Campaigns with(nolock) WHERE lft >= @lft AND rgt <= @rgt)

		--Delete from main table
		DELETE FROM CRM_Campaigns WHERE lft >= @lft AND rgt <= @rgt

		SET @RowsDeleted=@@rowcount

		--Update left and right extent to set the tree
		UPDATE CRM_Campaigns SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE CRM_Campaigns SET lft = lft - @Width WHERE lft > @rgt;
		
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
