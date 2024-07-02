USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocumentDetailsByVoucherNo]
	@VoucherNo [nvarchar](100),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section
		DECLARE @HasAccess BIT,@RowsCount BIGINT
		

		SET @RowsCount=0
		
		SELECT     TOP (1) 1 AS IsINV, ADM_DocumentTypes.DocumentName, D.DocID, D.CostCenterID, D.DocumentType, D.DocumentType, D.VoucherType, 
                      D.VoucherNo, D.VersionNo, D.DocAbbr, D.DocPrefix, D.DocNumber, D.DocDate,Convert(datetime,D.DocDate) as DATE
FROM         INV_DocDetails AS D WITH (NOLOCK) INNER JOIN
                      ADM_DocumentTypes WITH (NOLOCK) ON D.CostCenterID = ADM_DocumentTypes.CostCenterID
		WHERE VoucherNo =@VoucherNo
		SET @RowsCount=@@rowcount

		IF @RowsCount=0
		BEGIN
			SELECT     TOP (1) 1 AS IsINV, ADM_DocumentTypes.DocumentName, D.DocID, D.CostCenterID, D.DocumentType, D.DocumentType,0 VoucherType, 
                      D.VoucherNo, D.VersionNo, D.DocAbbr, D.DocPrefix, D.DocNumber, D.DocDate,Convert(datetime,D.DocDate) as DATE
FROM         ACC_DocDetails AS D WITH (NOLOCK) INNER JOIN
                      ADM_DocumentTypes WITH (NOLOCK) ON D.CostCenterID = ADM_DocumentTypes.CostCenterID

			WHERE VoucherNo =@VoucherNo
			SET @RowsCount=@@rowcount
		END
		
 
SET NOCOUNT OFF;   
RETURN @RowsCount
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
