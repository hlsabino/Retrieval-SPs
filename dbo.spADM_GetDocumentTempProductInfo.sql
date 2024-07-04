USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDocumentTempProductInfo]
	@DocumentID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
   
BEGIN TRY    
SET NOCOUNT ON;  
   
		 -- Get Temp Product Info details
		SELECT  C.TempProductColID,C.UserColumnName,C.SysColumnName,C.UserColumnType,C.ColumnDataType,
		C.RowNo,C.ColumnNo,C.ColumnSpan, isnull(C.SectionSeqNumber,0) SectionSeqNumber,        
		C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,     C.IsDefault,         
		C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID, C.RowNo, C.ColumnNo,C.TextFormat
		from com_doctempproductdef C
		WHERE C.CostCenterID  =  @DocumentID       --   and isvisible=1
		AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)    
		ORDER BY  C.RowNo,C.ColumnNo  
  
	   
SET NOCOUNT OFF;   
RETURN @DocumentID
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END  
  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  
  
  
GO
