USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetAddressData]
	@AddressID [bigint] = 0,
	@CostcenterID [int],
	@LocalRef [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
	 SET NOCOUNT ON;  

	SELECT * FROM COM_Address WITH(NOLOCK)
	WHERE ADDRESSID = @AddressID  
	
	select a.costcentercolid,b.syscolumnname from adm_costcenterdef a with(nolock)
	join adm_costcenterdef b with(nolock) on b.costcentercolid=a.linkdata
	where a.costcenterid= @CostcenterID and a.localreference=@LocalRef
	union
	select a.costcentercolid,replace(a.syscolumnname,'dc','') from adm_costcenterdef a with(nolock)
	where a.costcenterid= @CostcenterID and a.localreference=@LocalRef and a.syscolumnname like 'dcCCNID%'
	 
	SET NOCOUNT OFF;
	 
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName,
		ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH  
  
GO
