USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetUserRetrictTypes]
	@UserID [bigint] = 0,
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON
			
	--Declaration Section
	DECLARE @HasAccess BIT

	 
	 -- Getting Types of Accounts & Products
	select AccountType as Type, AccountTypeID as FeatureTypeID, 2 as FeatureID 
	from acc_accounttypes with(nolock)
	union
	select ProductType as Type, ProductTypeID as FeatureTypeID, 3 as FeatureID from INV_ProductTypes with(nolock)

	 
		select * from ADM_FeatureTypeValues with(nolock) where roleid=@RoleID
	 
		select * from ADM_FeatureTypeValues with(nolock) where Userid=@UserID

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
