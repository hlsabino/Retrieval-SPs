USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetGlobalPreferences]
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY
SET NOCOUNT ON
	DECLARE @SQL NVARCHAR(MAX)
		--Getting Global Preferences.
	SELECT  L.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText],PrefValueType
		FROM ADM_GlobalPreferences P WITH(NOLOCK) 	 
		LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=P.ResourceID  and LanguageID=@LangID
	where Name not in ('LWEmailXml')

	SELECT FEATUREID,Name,TableName FROM ADM_FEATURES WITH(NOLOCK) WHERE IsEnabled=1 AND ALLOWCUSTOMIZATION=1 AND 
	(FEATUREID > 50000 OR FEATUREID IN (2,3,51,57,58,300,65,71,76,72,80,84,81,86,83,88,78,73,89,82,16,92,93))

    select * from [ADM_HijriCalender] WITH(NOLOCK)
    
    SELECT  GlobalPrefID,P.PrefValueType,CASE WHEN L.ResourceData IS NULL THEN P.Name ELSE L.ResourceData END [Text],DefaultValue,Value,P.Name [DBText],P.PreferenceTypeName [Group],PrefRowOrder,PrefColOrder,Version
	FROM ADM_GlobalPreferences P WITH(NOLOCK)                 
	LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=P.ResourceID  and LanguageID=@LangID       
	ORDER BY P.PrefValueType  DESC
	
	SELECT Name ,FeatureId,TableName FROM Adm_Features with(nolock) WHERE IsEnabled=1 AND FeatureID>=50001 ORDER BY FeatureID
        
    SELECT CostCenterID,DocumentName,CASE WHEN IsInventory=1 THEN 'True' ELSE 'False' END IsInventory,DocumentType FROM ADM_DocumentTypes with(nolock) ORDER BY DocumentName
   
    SELECT CostCenterID,DocumentName,IsInventory,DocumentType FROM ADM_DocumentTypes WITH(NOLOCK) ORDER BY DocumentName
   
    SELECT a.CostCenterColID,b.ResourceData,a.SysColumnName from ADM_CostCenterDef a  WITH(NOLOCK)
	JOIN COM_LanguageResources b WITH(NOLOCK) ON a.ResourceID=b.ResourceID
	WHERE CostCenterID=3 and b.LanguageID=@LangID AND IsColumnInUse=1
	
	SELECT StatusID,Status from COM_Status WITH(NOLOCK) WHERE CostCenterID = 50051--8 Table
	
	if exists(select name from sys.tables with(nolock) where name='COM_CC50054') and 
	exists(select name from sys.tables with(nolock) where name='COM_CC50052')
	begin
		SET @SQL='SELECT a.GradeID,CONVERT(DATETIME,a.PayrollDate) as PayrollDate, a.Type,a.SNo,a.ComponentID,b.Name as ComponentName
		FROM COM_CC50054 a WITH(NOLOCK)
		JOIN COM_CC50052 b WITH(NOLOCK) on b.NodeID=a.ComponentID
		WHERE Type IN(3,4) AND GradeID=1 
		AND PayrollDate=(SELECT MAX(PayrollDate) FROM COM_CC50054 WITH(NOLOCK) WHERE GradeID=1)'
		EXEC (@SQL)
	end 
	else 
		select 1 where 1<>1
		
	SELECT UserColumnName CostCenterName,CONVERT(NVARCHAR,(50000+CONVERT(INT,REPLACE(SysColumnName,'CCNID','')))) CostCenterID 
	FROM Adm_CostCenterDef WITH(NOLOCK) 
	WHERE CostCenterId=50051 AND IscolumnInUse=1 AND SysColumnName LIKE 'CCNID%' 
	ORDER BY UserColumnName
		

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
