USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetLevel]
	@LevelId [int] = null,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    IF(@LevelId=0)
	BEGIN
	SELECT distinct LevelName , LevelID from COM_WorkFlow 
	END
	ELSE
	BEGIN
	SELECT * FROM COM_WorkFlow WHERE LevelID=@LevelId
	END
END
GO
