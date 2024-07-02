USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetVoucherIdByVoucherNo]
	@DocumentID [int],
	@VoucherNo [nvarchar](max),
	@IsInventoryDoc [bit] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section
		DECLARE @VoucherID INT
		
		SET @VoucherID=0
		IF @DocumentID=84
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=SvcContractID FROM CRM_ServiceContract WITH(NOLOCK)
			WHERE DocID='''+@VoucherNo+''''
			
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		else IF @DocumentID=86
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=LEADID FROM CRM_LEADS WITH(NOLOCK)
			WHERE CODE='''+@VoucherNo+''''
			
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		else IF @DocumentID=89
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=OPPORTUNITYID FROM CRM_OPPORTUNITIES WITH(NOLOCK)
			WHERE CODE='''+@VoucherNo+''''
			
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		else IF @DocumentID=73
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=CASEID FROM CRM_CASES WITH(NOLOCK)
			WHERE CASENUMBER='''+@VoucherNo+''''
			
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		ELSE IF @DocumentID=78
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=MFGOrderID FROM PRD_MFGOrder WITH(NOLOCK)
			WHERE OrderNumber='''+@VoucherNo+''''
			
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		ELSE IF @DocumentID=88
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=CAMPAIGNID FROM CRM_Campaigns WITH(NOLOCK)
			WHERE CODE='''+@VoucherNo+''''
			
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		else IF @DocumentID=95 OR @DocumentID=104
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=ContractID FROM REN_Contract WITH(NOLOCK)
			WHERE RefContractID=0 AND SNO='+@VoucherNo+' AND CostCenterID='+CONVERT(NVARCHAR,@DocumentID)
			print @VoucherNo
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		else IF @DocumentID=103 OR @DocumentID=129
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=QuotationID FROM REN_Quotation WITH(NOLOCK)
			WHERE SNO='+@VoucherNo+' AND StatusID!=430 AND CostCenterID='+CONVERT(NVARCHAR,@DocumentID)
			
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		ELSE IF @DocumentID=76
		BEGIN
			SET @VoucherNo='SELECT TOP 1 @VoucherID=BOMID FROM PRD_BillOfMaterial WITH(NOLOCK)
			WHERE BOMCode='''+@VoucherNo+''''
			
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		ELSE IF @DocumentID>50000
		BEGIN
			select @VoucherNo='select @VoucherID=NodeID from '+TableName+' with(nolock) where Code='''+@VoucherNo+'''' from ADM_Features with(Nolock) where FeatureID=@DocumentID
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		ELSE IF @DocumentID=2
		BEGIN
			select @VoucherNo='select @VoucherID=AccountID from '+TableName+' with(nolock) where AccountCode='''+@VoucherNo+'''' from ADM_Features with(Nolock) where FeatureID=@DocumentID
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		ELSE IF @DocumentID=3
		BEGIN
			select @VoucherNo='select @VoucherID=ProductID from '+TableName+' with(nolock) where ProductCode='''+@VoucherNo+'''' from ADM_Features with(Nolock) where FeatureID=@DocumentID
			EXEC sp_executesql @VoucherNo,N'@VoucherID INT OUTPUT',@VoucherID OUTPUT
		END
		ELSE
		BEGIN
			IF @IsInventoryDoc=1
			BEGIN
				SELECT TOP 1 @VoucherID=DocID FROM INV_DocDetails WITH(NOLOCK)
				WHERE CostCenterID=@DocumentID AND substring(VoucherNo, len(DocAbbr)+2,len(VoucherNo))=@VoucherNo
			END
			ELSE
			BEGIN
				SELECT TOP 1 @VoucherID=DocID FROM ACC_DocDetails WITH(NOLOCK)
				WHERE CostCenterID=@DocumentID AND substring(VoucherNo, len(DocAbbr)+2,len(VoucherNo))=@VoucherNo
			END
		END

		IF @VoucherID=0
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-118 AND LanguageID=@LangID
		END
		
		--print(@VoucherID)

SET NOCOUNT OFF;   
RETURN @VoucherID
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
