USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetUOMDetails]
	@UOMID [int],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON;    
		--Declaration Section  
		DECLARE @Dt FLOAT
		DECLARE @TempGuid NVARCHAR(50) 
		
		IF(@UOMID = 0)--Getting all Unit of Measures  
		BEGIN
			SELECT DISTINCT BaseID,BaseName,UOMID             
			FROM COM_UOM WITH(NOLOCK)   where unitid=1 
				SELECT DISTINCT BaseID,BaseName,UOMID             
			FROM COM_UOM WITH(NOLOCK)     
		END
		ELSE
		BEGIN
			SELECT UOMID,UnitName,Conversion,BaseName,BaseID,UNITID          
			FROM COM_UOM WITH(NOLOCK) 
			WHERE UOMID = @UOMID
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
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine  
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
		END  
   
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH   
  
GO
