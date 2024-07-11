USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetContacts]
	@NodeID [bigint] = 0,
	@CustomerID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

	 
	SELECT c.*, l.name as Salutation FROM  CRM_Contacts c WITH(NOLOCK) 
		left join com_lookup l on l.Nodeid=c.SalutationID 
	where C.FeatureID=@NodeID
	
	select CON.*,C1.Name as Salutation,C2.Name as Role,S.Status  from COM_Contacts CON
	left join com_lookup C1 on CON.SalutationID=C1.NodeID
	left join com_lookup C2 on CON.RoleLookUpID=C1.NodeID
	left join Com_Status S on CON.StatusID=S.StatusID
	where CON.featureid=83 and CON.featurepk=@CustomerID
	
	
		

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
