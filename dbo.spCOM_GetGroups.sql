USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetGroups]
	@GID [int] = null,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
begin transaction

if(@GID=0)
begin
	SELECT DISTINCT GID, GroupName
	FROM  COM_Groups WHERE ISGROUP=1 AND NodeID<>1
end
else
begin
SELECT * 
	FROM  COM_Groups where GID=@GID
end




commit transaction

	RETURN
GO
