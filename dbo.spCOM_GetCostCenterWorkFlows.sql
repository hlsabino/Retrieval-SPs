USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCostCenterWorkFlows]
	@CostCenterId [int] = null,
	@UserID [int],
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

	--SP Required Parameters Check
	IF (@CostCenterId < 1)
	BEGIN
		RAISERROR('-100',16,1)
	END

	SELECT  [WorkFlowDefID],[Action],[Expression],[WorkFlowID],[IsEnabled],LevelID,isinventory,OnReject,IsLineWise,IsExpressionLineWise,UserWise,FieldWidth,Convert(DateTime,WEFDate) as WEFDate,Convert(DateTime,TillDate) as TillDate	 
	FROM COM_WorkFlowDef a WITH(nolock)
	join (select WorkFlowID WID,WorkFlowName WName from COM_WorkFlow with(nolock) group by WorkFlowID,WorkFlowName) W on W.WID=WorkFlowID
	left join adm_documentTypes b on a.CostCenterID=b.CostCenterID
	WHERE a.CostCenterID=@CostCenterId
	order by WName,LevelID
	
	if(@CostCenterId>40000 and @CostCenterId<50000)
	begin
		SELECT  C.CostCenterColID,R.ResourceData,C.SysColumnName,IsTransfer
		FROM ADM_CostCenterDef C WITH(NOLOCK)  
		LEFT JOIN COM_LanguageResources R ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
		WHERE C.CostCenterID = @CostCenterId AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND 
		C.SysColumnName NOT LIKE '%dcCalcNum%'  AND C.SysColumnName NOT LIKE '%dcExchRT%' AND 
		C.SysColumnName NOT LIKE '%dcCurrID%' AND C.SysColumnName <> 'UOMConversion'   AND C.SysColumnName <> 'UOMConvertedQty'        
	end
	else
	begin
		SELECT  C.CostCenterColID,replace(R.ResourceData,' ','') ResourceData,C.SysColumnName
		FROM ADM_CostCenterDef C WITH(NOLOCK)  
		INNER JOIN COM_LanguageResources R ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
		WHERE C.CostCenterID = @CostCenterId AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)
		ORDER BY ResourceData
	end
 
	SELECT  isinventory	 FROM adm_documentTypes WITH(nolock) 
	where CostCenterID=@CostCenterId

COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
