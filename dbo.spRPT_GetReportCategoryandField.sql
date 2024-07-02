USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetReportCategoryandField]
	@Category [int] = 0,
	@Field [int] = 0,
	@Type [int] = 0,
	@Letter [nvarchar](max) = null,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON


	SELECT CostCenterID,DocumentType,IsInventory FROM ADM_DocumentTypes WITH(NOLOCK)

	SELECT F.FeatureID, F.TableName, P.PK
	FROM ADM_Features AS F WITH(NOLOCK) LEFT OUTER JOIN
          (SELECT OBJECT_NAME(ic.object_id) AS TableName, COL_NAME(ic.object_id, ic.column_id) AS PK
            FROM sys.indexes AS i INNER JOIN
                 sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
            WHERE (i.is_primary_key = 1)) AS P ON P.TableName = F.TableName
	UNION ALL	
	SELECT -F.FeatureID,F.TableName, P.PK
	FROM ADM_Features F WITH(NOLOCK)
	 LEFT OUTER JOIN
          (SELECT OBJECT_NAME(ic.object_id) AS TableName, COL_NAME(ic.object_id, ic.column_id) AS PK
            FROM sys.indexes AS i INNER JOIN
                 sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
            WHERE (i.is_primary_key = 1)) AS P ON P.TableName = F.TableName
            
	WHERE IsEnabled = 1 AND IsUserDefined=0 AND FeatureID>40000 AND FeatureID<50000
	ORDER BY FeatureID

	SELECT FK_Table=UPPER(FK.TABLE_NAME), FK_Column=UPPER(CU.COLUMN_NAME), PK_Table=UPPER(PK.TABLE_NAME), PK_Column=UPPER(PT.COLUMN_NAME)--,Constraint_Name = C.CONSTRAINT_NAME
	FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS C
	INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS FK ON C.CONSTRAINT_NAME = FK.CONSTRAINT_NAME  INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS PK ON C.UNIQUE_CONSTRAINT_NAME = PK.CONSTRAINT_NAME  INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU ON C.CONSTRAINT_NAME = CU.CONSTRAINT_NAME   INNER JOIN (SELECT i1.TABLE_NAME, i2.COLUMN_NAME
	FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS i1  INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE i2 ON i1.CONSTRAINT_NAME = i2.CONSTRAINT_NAME  WHERE i1.CONSTRAINT_TYPE = 'PRIMARY KEY') PT ON PT.TABLE_NAME = PK.TABLE_NAME
	UNION 
	SELECT 'PRD_BILLOFMATERIALEXTENDED','BOMID','PRD_BILLOFMATERIAL','BOMID'
	UNION 
	SELECT 'CRM_ActivityLog','ActivityID','CRM_Activities','ActivityID'
	
	--Status Field Info
	SELECT TOP 1 R.ResourceData UserColumnName ,C.CostCenterID,C.CostCenterName,C.SysTableName,C.SysColumnName,C.CostCenterColID,upper(C.ColumnDataType) ColumnDataType,
	C.IsForeignKey,C.ParentCostCenterID,
	C.ParentCostCenterSysName,C.ParentCostCenterColSysName,C.ParentCCDefaultColID,C.ColumnCostCenterID
	FROM ADM_CostCenterDef C WITH(NOLOCK),COM_LanguageResources R WITH(NOLOCK)
	WHERE C.CostCenterColID=22872 AND C.CostCenterID=113
		AND C.ResourceID=R.ResourceID AND R.LanguageID=@LangID 
		
	--Dimensions List
	--SELECT FeatureID, Name FROM ADM_Features WITH(NOLOCK)
	--WHERE (IsEnabled = 1) OR (FeatureID between 40001 and 50000) --(FeatureID >= 50001) AND (IsEnabled = 1) OR (FeatureID < 50001) 
	--UNION ALL
	--SELECT -FeatureID,'All'+ Name FROM ADM_Features WITH(NOLOCK)
	--WHERE IsEnabled = 1 AND IsUserDefined=0 AND FeatureID>40000 AND FeatureID<50000
	--ORDER BY Name
	SELECT FeatureID,CASE CL.LANGUAGEID WHEN 1 THEN AF.NAME WHEN 2 THEN CL.RESOURCEDATA  END Name FROM ADM_Features AF WITH(NOLOCK),COM_LANGUAGERESOURCES CL WITH(NOLOCK)
	WHERE AF.RESOURCEID=CL.RESOURCEID AND CL.LANGUAGEID=@LangID  AND AF.FeatureID NOT IN(265,40095) AND  ((AF.IsEnabled = 1) OR (AF.FeatureID between 40001 and 50000))
	UNION ALL
	SELECT -FeatureID,CASE CL.LANGUAGEID WHEN 1 THEN 'All'+ CL.RESOURCEDATA WHEN 2 THEN N'???? '+ CL.RESOURCEDATA  END Name FROM ADM_Features AF WITH(NOLOCK),COM_LANGUAGERESOURCES CL WITH(NOLOCK)
	WHERE AF.RESOURCEID=CL.RESOURCEID  AND CL.LANGUAGEID=@LangID AND AF.FeatureID NOT IN(265,40095) AND  AF.IsEnabled = 1 AND AF.IsUserDefined=0 AND AF.FeatureID>40000 AND AF.FeatureID<50000 
	ORDER BY NAME
	
	SELECT NodeID,LookupName FROM COM_LookupTypes with(nolock) ORDER BY LookupName
	 

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
