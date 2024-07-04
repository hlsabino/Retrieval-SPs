USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetPrintLayout]
	@DocumentID [bigint],
	@DocType [bigint],
	@LayoutID [bigint],
	@RoleID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
SET NOCOUNT ON;
   
	--Declaration Section
	DECLARE @HasAccess BIT

--	--User access check 
--	SET @HasAccess=dbo.fnCOM_IsUserActionAllowed(@UserID,39,27)
--
--	IF @HasAccess=0
--	BEGIN
--		RAISERROR('-105',16,1)
--	END

	--Getting Print Layouts
	IF @LayoutID=0
	BEGIN
		SELECT * FROM ADM_DocPrintLayouts WITH(NOLOCK)
		WHERE DocumentID=@DocumentID AND DocType=@DocType
			AND (
				@RoleID=1 
				OR 
					DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap 
						where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups where UserID=@UserID or RoleID=@RoleID))
				)
		ORDER BY IsDefault DESC
		
		
		SELECT MapID,DocPrintLayoutID,PrintOtherVPT FROM ADM_DocPrintLayoutsMap WITH(NOLOCK) WHERE PrintOtherVPT IS NOT NULL AND DocPrintLayoutID IN (
			SELECT DocPrintLayoutID FROM ADM_DocPrintLayouts WITH(NOLOCK)
			WHERE DocumentID=@DocumentID AND DocType=@DocType
			AND (
				@RoleID=1 
				OR 
					DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap 
						where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups where UserID=@UserID or RoleID=@RoleID))
				)
			)
		ORDER BY DocPrintLayoutID,MapID
	END
	ELSE
	BEGIN
	
		SELECT * FROM ADM_DocPrintLayouts WITH(NOLOCK)
		WHERE DocPrintLayoutID=@LayoutID
		
		--SELECT *,0 MapID FROM ADM_DocPrintLayouts WITH(NOLOCK)
		--WHERE DocPrintLayoutID=@LayoutID
		--UNION
		--SELECT P.*,T.MapID FROM ADM_DocPrintLayouts P INNER JOIN 
		--	(SELECT MapID,DocPrintLayoutID,PrintOtherVPT FROM ADM_DocPrintLayoutsMap WITH(NOLOCK) WHERE DocPrintLayoutID=@LayoutID AND PrintOtherVPT IS NOT NULL) AS T ON T.PrintOtherVPT=P.DocPrintLayoutID
		--ORDER BY MapID
		
		--SELECT * 
		--FROM ADM_DocPrintLayouts WITH(NOLOCK) M INNER JOIN ADM_DocPrintLayoutsMap ON 
		--WHERE DocPrintLayoutID IN (SELECT PrintOtherVPT FROM ADM_DocPrintLayoutsMap WITH(NOLOCK) WHERE DocPrintLayoutID=@LayoutID)		
	END

SET NOCOUNT OFF;   
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

SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
