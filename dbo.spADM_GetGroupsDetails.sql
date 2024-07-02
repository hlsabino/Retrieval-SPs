USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetGroupsDetails]
	@GID [nvarchar](300) = null,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
if(@GID='')
BEGIN
RAISERROR(-100,16,1)
END
ELSE
BEGIN
	-- exec [SPADM_GetGroupsDetails] '1',1
	create table #tbltemp(GID int)

	insert into #tbltemp
	exec spsplitstring @GID ,','

	SELECT * FROM COM_GROUPS WHERE GID 
		in (select GID from #tbltemp)
END

	RETURN 1


GO
