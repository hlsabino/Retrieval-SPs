USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_DeleteContact]
	@DetailContactID [bigint] = 0,
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted bigint,@lft bigint,@rgt bigint,@Width bigint

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,65,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		--	IF EXISTS(SELECT  ContactID FROM COM_CONTACTS with(nolock) WHERE  ContactID=4173 AND ParentID=0)
		--BEGIN
		--	RAISERROR('-115',16,1)
		--END
			--SP Required Parameters Check
		if(@DetailContactID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END


		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM COM_CONTACTS WITH(NOLOCK) WHERE ContactID=@DetailContactID
		
		--Delete from Costcenter Map table	
		Delete from COM_CCCCData where CostCenterid=65 and nodeid=@DetailContactID

		--Delete from Extended Table
		delete from COM_ContactsExtended where ContactID=@DetailContactID
		--Delete from main table
		delete from COM_CONTACTS	where ContactID=@DetailContactID

		SET @RowsDeleted=@@rowcount 

	 
	 	--Update left and right extent to set the tree
		UPDATE COM_CONTACTS SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE COM_CONTACTS SET lft = lft - @Width WHERE lft > @rgt;
	
		if exists (select ConvertFromLeadID from COM_CONTACTS where ContactID=@DetailContactID)
		BEGIN
			DECLARE @LEADID BIGINT
			SELECT @LEADID=ISNULL(ConvertFromLeadID,0) from COM_CONTACTS where ContactID=@DetailContactID
			IF(@LEADID>0)
				update CRM_Leads set contactid=0 where LeadID =@LEADID
		END	
		delete from COM_CONTACTS	where ContactID=@DetailContactID
		

		SET @RowsDeleted=@@rowcount
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
