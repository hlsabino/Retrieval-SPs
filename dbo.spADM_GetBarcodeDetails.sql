USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetBarcodeDetails]
	@Type [int],
	@ID [bigint],
	@IsSalePrint [bit],
	@RoleID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
     
BEGIN TRY      
SET NOCOUNT ON;    
       
IF @Type=0
BEGIN
	--Docs
	SELECT CostCenterID,DocumentName,DocumentType FROM ADM_DocumentTypes with(nolock) Where IsInventory=1
	UNION ALL
	SELECT FeatureID,Name,0 FROM ADM_Features with(nolock) WHERE (FeatureID>50000 and IsEnabled=1 ) or FeatureID IN (72)
	order by DocumentName
END
ELSE IF @Type=1
BEGIN
	SELECT BarCodeLayoutID,Name,IsDefault
	FROM ADM_DocBarcodeLayouts WITH(NOLOCK)
	WHERE CostCenterID=@ID
	ORDER BY Name	
	
	--Qty Numeric Fields
	SELECT C.CostCenterColID,R.ResourceData Name,C.SysColumnName
	FROM ADM_CostCenterDef C WITH(NOLOCK) LEFT JOIN 
	COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
	WHERE C.CostCenterID=@ID  AND IsColumnInUse = 1 AND (SysColumnName LIKE 'dcNum%')
		
END
ELSE IF @Type=2
BEGIN
	SELECT *
	FROM ADM_DocBarcodeLayouts WITH(NOLOCK)
	WHERE BarCodeLayoutID=@ID
END
ELSE IF @Type=3
BEGIN
	SELECT *
	FROM ADM_DocBarcodeLayouts WITH(NOLOCK)
	WHERE CostCenterID=@ID
	ORDER BY IsDefault DESC	
END
ELSE IF @Type=4
BEGIN
	SELECT *
	FROM ADM_DocBarcodeLayouts WITH(NOLOCK)
	WHERE CostCenterID=@ID and IsSalePrint=@IsSalePrint
	AND (@RoleID=1 OR (BarCodeLayoutID IN (select NodeID from ADM_Assign WITH(NOLOCK)
						where CostCenterID=105 and UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))))
				
	ORDER BY IsDefault DESC	
END
ELSE IF @Type=5
BEGIN
	SELECT top 1 *
	FROM ADM_DocBarcodeLayouts WITH(NOLOCK)
	WHERE CostCenterID=@ID and IsSalePrint=@IsSalePrint
	AND (@RoleID=1 OR (BarCodeLayoutID IN (select NodeID from ADM_Assign WITH(NOLOCK)
						where CostCenterID=105 and UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))))
				
	ORDER BY IsDefault DESC	
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
 FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
   
SET NOCOUNT OFF      
RETURN -999       
END CATCH      
GO
