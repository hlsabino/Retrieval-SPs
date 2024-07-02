USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetMatrixData]
	@MATRIXID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
  
		if(@MATRIXID=0)
		BEGIN
			SELECT DISTINCT PROFILEID AttributeGroupID, PROFILENAME AttributeGroupName FROM INV_MatrixDef WITH(NOLOCK)
			UNION
			SELECT -100, 'New'
		END	
		ELSE
			--Getting INV_AttributeMatrixDef.
			SELECT M.*,A.NAME Attributes
			FROM INV_MatrixDef M WITH(NOLOCK)
			LEFT JOIN adm_features A WITH(NOLOCK) ON A.FEATUREID=M.ATTRIBUTEID
			WHERE ProfileID=@MATRIXID
		
		select BarcodeLayoutID, Name from ADM_DocBarcodeLayouts  WITH(NOLOCK) where costcenterid=17
			 
			 
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
