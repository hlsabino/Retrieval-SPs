USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetProductsExtraNumericFields]
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
        
BEGIN TRY        
SET NOCOUNT ON;      
 
  --Getting Costcenter Fields        
  SELECT  C.CostCenterColID,R.ResourceData,C.SysColumnName,C.ColumnDataType
   FROM ADM_CostCenterDef C WITH(NOLOCK)      
  LEFT JOIN COM_LanguageResources R ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID      
  WHERE C.CostCenterID = 3       
   AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)      
  ORDER BY C.SectionID,C.SectionSeqNumber      
         
  
   select d.CostCenterID CCID,l.ResourceData
  from ADM_DocumentTypes d 
 left join ADM_RibbonView rib on rib.FeatureID=d.CostCenterID  
 left join COM_LanguageResources l on l.ResourceID=rib.ScreenResourceID and l.LanguageID=@LangID
 where DocumentType in (2,25,26,27)
      
 
       
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
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine      
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
  END      
      
SET NOCOUNT OFF        
RETURN -999         
END CATCH      








GO
