USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetAndDeleteDistCosts]
	@ProfileID [bigint] = 0,
	@Type [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY    
SET NOCOUNT ON;  

if(@Type=2)
begin	
	select * from Adm_MapCosts a with(nolock)
end
else if(@Type=3)
begin
BEGIN TRANSACTION
	delete from Adm_DistributeCosts where ProfileID=@ProfileID
COMMIT TRANSACTION
end
else
begin
	if(@ProfileID=0)
	begin
	   select distinct ProfileID,[ProfileName] from Adm_DistributeCosts with(nolock)	  
	end
	Else
	begin
	   select * from Adm_DistributeCosts a with(nolock) where ProfileID=@ProfileID
	end
end
  
SET NOCOUNT OFF;
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
  WHERE ErrorNumber=102 AND LanguageID=@LangID    
RETURN 1  
END TRY  
BEGIN CATCH       
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999  AND LanguageID=@LangID 
  END  
 ROLLBACK TRANSACTION
SET NOCOUNT OFF    
RETURN -999     
END CATCH 




 
  
  
  
  
  
  
GO
