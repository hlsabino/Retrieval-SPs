USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteUserDefinedViews]
	@FeatureID [int],
	@VIEWSEQNO [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;

	--Declaration Section
	DECLARE @HasAccess BIT,@IsUserdefined BIT,@RowsDeleted INT

	--User access check  
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,4)

	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END 
	
	IF @FeatureID=26 --FOR GRIDVIEW DEFINATION
	BEGIN
		IF ((SELECT COUNT(*) FROM ADM_GridView WHERE IsUserDefined=0 AND GridViewID=@VIEWSEQNO)>0)
		RAISERROR('-119',16,1)

		DELETE FROM ADM_GridViewColumns WHERE GridViewID=@VIEWSEQNO	
		DELETE FROM ADM_GridView WHERE GridViewID=@VIEWSEQNO
		SET @RowsDeleted=@@ROWCOUNT						
	END
	ELSE IF @FeatureID=27 --FOR LISTVIEW DEFINATION
	BEGIN
		IF ((SELECT COUNT(*) FROM ADM_ListView WHERE IsUserDefined=0  AND ListViewID IN  --CHECK FOR INBUILT LISTVIEWS
			(SELECT LISTVIEWID FROM ADM_ListView WHERE ListViewTypeID =@VIEWSEQNO)) >0)
		RAISERROR('-119',16,1)

		DELETE FROM ADM_ListViewColumns WHERE  ListViewID IN (SELECT LISTVIEWID FROM ADM_ListView WHERE ListViewTypeID =@VIEWSEQNO)
		DELETE FROM ADM_ListView WHERE ListViewID IN (SELECT LISTVIEWID FROM ADM_ListView WHERE ListViewTypeID =@VIEWSEQNO)
		SET @RowsDeleted=@@ROWCOUNT					
	END 
	ELSE IF @FeatureID=28 --FOR QUICK VIEWS
	BEGIN
		DELETE FROM ADM_QuickViewDefnUserMap WHERE QID=@VIEWSEQNO
		DELETE FROM ADM_QuickViewDefn WHERE QID=@VIEWSEQNO
		SET @RowsDeleted=@@ROWCOUNT
	END 

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
