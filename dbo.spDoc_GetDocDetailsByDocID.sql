USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetDocDetailsByDocID]
	@DocID [bigint],
	@CostCenterID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
 
		--SP Required Parameters Check
		IF (@DocID=0 or @CostCenterID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END
		if exists(select COstcenterid from adm_documentTypes WITH(NOLOCK) where COstcenterid=@CostCenterID and isinventory=1)
		begin
			select distinct DocPrefix Prefix,DocNumber,CostCenterID CCID,l.ResourceData,DisplayName,DocNumber DocNoStr
			from	 INV_DocDetails d WITH(NOLOCK) 
			left join ADM_RibbonView r WITH(NOLOCK) on r.FeatureID=d.CostCenterID
			left join COM_LanguageResources l WITH(NOLOCK) on l.ResourceID=r.ScreenResourceID and LanguageID=@LangID
			where DocID=@DocID and COstcenterid=@CostCenterID
		end
		else
		begin
			select distinct DocPrefix Prefix,DocNumber,CostCenterID CCID,l.ResourceData,DisplayName,DocNumber DocNoStr
			from	 ACC_DocDetails d WITH(NOLOCK)
			left join ADM_RibbonView r WITH(NOLOCK)on r.FeatureID=d.CostCenterID
			left join COM_LanguageResources l WITH(NOLOCK) on l.ResourceID=r.ScreenResourceID and LanguageID=@LangID
			where DocID=@DocID and COstcenterid=@CostCenterID
		end

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
