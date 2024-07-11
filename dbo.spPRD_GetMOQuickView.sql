USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetMOQuickView]
	@MFGOrderID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY    
SET NOCOUNT ON;  
  
   	
	select distinct WONumber,MFGOrderWOID,w.DocID,VoucherNo+' ('+CONVERT(nvarchar, w.Quantity)+')' VoucherNo
	,DocPrefix Prefix,DocNumber,CostCenterID CCID,l.ResourceData
	from (SELECT W.WONumber,W.MFGOrderWOID,W.DocID,W.Quantity
	FROM  [PRD_MFGOrderWOs] W WITH(NOLOCK)
	left join [PRD_MFGOrderBOMs] M WITH(NOLOCK) on M.MFGOrderBOMID=W.MFGOrderBOMID
	WHERE  M.MFGOrderID=@MFGOrderID)
	as w left join INV_DocDetails d on d.DocID=w.DocID
	left join ADM_RibbonView r on r.FeatureID=d.CostCenterID
	left join COM_LanguageResources l on l.ResourceID=r.ScreenResourceID and LanguageID=@LangID
  
	
	SELECT distinct w.WONumber,w.MFGOrderWOID,w.DocID,
	VoucherNo+' ('+CONVERT(nvarchar, w.RCTQuantity)+')' VoucherNo
	,DocPrefix Prefix,DocNumber,CostCenterID CCID,l.ResourceData
	from (SELECT Wo.WONumber,Wo.MFGOrderWOID,W.DocID,RCTQuantity
	FROM  [PRD_MOWODetails] W WITH(NOLOCK)
	left join [PRD_MFGOrderWOs] Wo WITH(NOLOCK) on Wo.MFGOrderWOID=W.MFGOrderWOID
	left join [PRD_MFGOrderBOMs] M WITH(NOLOCK) on M.MFGOrderBOMID=Wo.MFGOrderBOMID	
	WHERE W.DocID is not null and W.DocID>0 and M.MFGOrderID=@MFGOrderID)as w 
	left join INV_DocDetails d on d.DocID=w.DocID
	left join ADM_RibbonView r on r.FeatureID=d.CostCenterID
	left join COM_LanguageResources l on l.ResourceID=r.ScreenResourceID and LanguageID=@LangID
	order by w.MFGOrderWOID
	
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
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
