USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDocumentDef]
	@DocumentTypeID [int],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		  --Declaration Section
		DECLARE @CostCenterID int

		--SP Required Parameters Check
		IF @DocumentTypeID=0
		BEGIN
			RAISERROR('-100',16,1)
		END

		--GETTING DOCUMENT INFO
		SELECT @CostCenterID=CostCenterID FROM 
		ADM_DocumentTypes WHERE DocumentTypeID=@DocumentTypeID


		--Getting Costcenter Fields  
		SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,
				C.UserDefaultValue,C.UserProbableValues,C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,
				C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName,C.SectionSeqNumber,
				DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,
				DD.IsRoundOffEnabled,DD.IsDrAccountDisplayed,DD.IsCrAccountDisplayed,DD.IsDistributionEnabled,DD.DistributionColID
		FROM ADM_CostCenterDef C WITH(NOLOCK)
		LEFT JOIN COM_LanguageResources R ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
		LEFT JOIN ADM_DocumentDef DD ON DD.CostCenterColID=C.CostCenterColID 
		WHERE C.CostCenterID = @CostCenterID 
			AND C.IsColumnUserDefined=1 AND C.IsColumnInUse=1
		ORDER BY C.SysColumnName

 

		--GETTING DOCUMENT INFO
		SELECT D.DocumentTypeID ,D.DocumentType,D.DocumentAbbr,D.DocumentName,S.Status,D.ConvertAs,D.Bounce,D.Series FROM 
		ADM_DocumentTypes D,COM_Status S WHERE  D.StatusID=S.StatusID and D.CostCenterID=@CostCenterID

		SELECT FEATUREID,Name,TableName FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE FEATUREID >50000 and ISEnabled=1
	
 

COMMIT TRANSACTION 
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
