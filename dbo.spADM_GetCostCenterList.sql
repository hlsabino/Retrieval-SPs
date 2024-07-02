USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterList]
	@CostCenterID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;


	--Getting Features.
	SELECT FEATUREID,Name,TableName FROM ADM_FEATURES WITH(NOLOCK) WHERE IsEnabled=1 AND ALLOWCUSTOMIZATION=1 AND 
	(FEATUREID > 50000 OR FEATUREID IN (2,3,51,57,58,61,145,59,300,65,71,76,72,80,84,81,86,83,88,
	1000,78,73,89,82,16,92,93,101,164,95,495,94,113,103,104,129,106))
	union
	SELECT FEATUREID,Name,TableName FROM ADM_FEATURES WITH(NOLOCK) WHERE FeatureID=12
	order by Name
	
	SELECT ListViewID,ListViewTypeID,CostCenterID,ListViewName from ADM_ListView WITH(NOLOCK)
	
	Select Name ,FeatureId,TableName from adm_features WITH(NOLOCK) where IsEnabled=1 and ( featureid> 50000 or Featureid in (92,93,94))
	order by Name, featureid
	 
	
	IF(@CostCenterID!=0)
	BEGIN
		if(@CostCenterID=3 OR @CostCenterID=92 OR @CostCenterID=93 OR @CostCenterID=94 OR @CostCenterID=86)

		begin
			SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,
			D.RowNo, D.ColumnNo, D.ColumnSpan,D.IsColumnUserDefined
			FROM ADM_COSTCENTERDEF D WITH(NOLOCK) 
			LEFT JOIN COM_LANGUAGERESOURCES R WITH(NOLOCK) ON R.ResourceID=D.ResourceID and R.languageid=@LangID
			WHERE CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1  
			order by d.sectionseqnumber 
		end
		else
		begin
		
			SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,
			D.RowNo, D.ColumnNo, D.ColumnSpan,D.IsColumnUserDefined
			FROM ADM_COSTCENTERDEF D WITH(NOLOCK) 
			LEFT JOIN COM_LANGUAGERESOURCES R WITH(NOLOCK) ON R.ResourceID=D.ResourceID and R.languageid=@LangID
			WHERE CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 and SectionID is NULL 
			order by d.sectionseqnumber 
		end
	END
	
	select Accountid,AccountCode,AccountName from Acc_Accounts  WITH(NOLOCK) where Accounttypeid=7
	
	select UserColumnName CostCenterName,CONVERT(NVARCHAR,(50000+CONVERT(INT,REPLACE(SysColumnName,'CCNID','')))) CostCenterID 
	from Adm_CostCenterDef with(nolock) where CostCenterId=50051 and IscolumnInUse=1 and SysColumnName like 'CCNID%' order by UserColumnName
 
--	SELECT ROLEID,NAME FROM ADM_PRoles WITH(NOLOCK)
--	SELECT * FROM ADM_Users WITH(NOLOCK)
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
