USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetTeamScreenDetails]
	@TeamID [int] = 0,
	@Userid [int],
	@Langid [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

SELECT * FROM COM_STATUS WITH(NOLOCK) WHERE FeatureID=91
if(@TeamID=0)
begin
	select * FROM ADM_USERS WITH(NOLOCK)  
end
else
begin
		select UserID,UserName FROM ADM_USERS WITH(NOLOCK) where userid not in (select userid from CRM_Teams WITH(NOLOCK) where teamid
		IN (SELECT TEAMID FROM CRM_Teams WHERE NodeID=@TeamID) and isOwner=1)
		
		select UserID,UserName FROM ADM_USERS WITH(NOLOCK) where userid  not in (select userid from CRM_Teams WITH(NOLOCK) where teamid	IN 
		(SELECT TEAMID FROM CRM_Teams WHERE NodeID=@TeamID) and isOwner=0) 

		select UserID,UserName FROM ADM_USERS WITH(NOLOCK) where userid  in (select userid from CRM_Teams WITH(NOLOCK) where teamid
			IN (SELECT TEAMID FROM CRM_Teams WHERE NodeID=@TeamID) and isOwner=1)
			
		select UserID,UserName FROM ADM_USERS WITH(NOLOCK) where userid   in (select userid from CRM_Teams WITH(NOLOCK)where teamid	
		IN (SELECT TEAMID FROM CRM_Teams WHERE NodeID=@TeamID) and isOwner=0)
		
		
		select * from CRM_Teams WITH(NOLOCK) where teamid	
		IN (SELECT TEAMID FROM CRM_Teams WHERE NodeID=@TeamID) 
end


SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
