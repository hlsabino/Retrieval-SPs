﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DeleteGroup]
	@GID [bigint] = null,
	@IsGroup [bit] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION

begin
	IF @GID=0  
	BEGIN
	RAISERROR(-100,16,1)
	END
	ELSE 
	BEGIN
	if(@IsGroup=1)
		DELETE FROM COM_Groups WHERE GID = (SELECT GID FROM COM_GROUPS WHERE NODEID=@GID)
	ELSE
		DELETE FROM COM_Groups WHERE NODEID=@GID
	END
	
end
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=102 AND LanguageID=@LangID
	
COMMIT TRANSACTION

RETURN 1
GO