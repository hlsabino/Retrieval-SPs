USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SPCRM_GetSuppliersByCRMProducts]
	@CostCenterID [int],
	@NodeID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

	BEGIN TRY	
	SET NOCOUNT ON; 
		BEGIN
			DECLARE @LinkCostCenterID BIGINT,@CHILDCCID INT,@SQL NVARCHAR(MAX),@COLUMN NVARCHAR(300)
			SET @LinkCostCenterID=0
			
			IF @CostCenterID=86 
				SET @CHILDCCID=115 --LEAD PRODUCTS
			ELSE IF @CostCenterID=89 
				SET @CHILDCCID=154 -- OPPORTUNTIY PRODUCTS
				
			SELECT @LinkCostCenterID=isnull([Value],0) FROM COM_CostCenterPreferences WITH(NOLOCK) 
			WHERE FeatureID=@CostCenterID AND [Name]='AutoPupulateSuppliers'
			IF @LinkCostCenterID>0  
			BEGIN
					
					IF EXISTS( SELECT * FROM ADM_CostCenterDef C WITH(NOLOCK) WHERE C.CostCenterID = @CHILDCCID and C.IsColumnUserDefined=1 and C.IsVisible=1
					AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)
					AND C.ColumnCostCenterID=@LinkCostCenterID )
					BEGIN
						SET @COLUMN=@LinkCostCenterID-50000
						
						IF @COLUMN IS NULL OR @COLUMN=''
							SET @COLUMN='1'
						SET @SQL=''
						SET @SQL='SELECT CCNID'+CONVERT(NVARCHAR(300),@COLUMN)+','+CONVERT(nvarchar(300),@LinkCostCenterID)+' MapCCID	from CRM_ProductMapping L WITH(NOLOCK) WHERE 	
							  L.CCNodeID =  '+CONVERT(NVARCHAR(300),@NodeID)+' and L.CostCenterID='+CONVERT(NVARCHAR(300),@CostCenterID)+''
						PRINT @SQL		  
						EXEC (@SQL)	
					END
					 
					 
			END
		END
		

SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
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
