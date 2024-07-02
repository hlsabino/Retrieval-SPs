USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocumentDefine]
	@COSTCENTERID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY                
SET NOCOUNT ON;              
 
	SELECT SysColumnName,(SELECT TOP 1 ResourceData FROM COM_LanguageResources with(nolock) WHERE LanguageID=@LangID AND ResourceID=C.ResourceID) ResourceData
	FROM ADM_CostCenterDef C with(nolock)
	WHERE CostCenterID=3 AND (SysColumnName LIKE 'PurchaseRate%' OR SysColumnName LIKE 'SellingRate%' 
		OR SysColumnName LIKE 'ReorderLevel%' OR SysColumnName LIKE 'ReorderQty%')
	ORDER BY SysColumnName
	
	SELECT PrefName,PrefValue,l.ResourceData 
	FROM COM_DocumentPreferences a with(nolock)
	left join com_languageresources l WITH(NOLOCK) on a.resourceid=l.resourceid and l.languageid=@LangID
	WHERE CostCenterID=@CostCenterID AND 
	PrefName IN ('PriceChartMapping','OnPosted','AutoCode','GenerateSeq','Inactiveonsuspend','EnableUniqueDocument','FieldCalculator','CalcFieldsDynamic' ,'CalcFooterField','FieldCalculatorTextFields'
	,'EnableAssetSerialNo','AssetBasedOn','PostAsset','ResetFields','DimTransferSrc','DimTransferDim','AssetShiftDate','IsBudgetDocument','BudgetMapFields')
	
	select  L.ResourceData FIELDNAME, a.CostCenterColID COSTCENTERCOLID, a.SysTableName 
	from adm_costcenterdef a WITH(NOLOCK)
	join com_languageresources l WITH(NOLOCK) on a.resourceid=l.resourceid and l.languageid=1
	where CostCenterID=3 and IsColumnInUse=1 
	
	--Getting Documents.        
	SELECT D.DocumentTypeID,D.CostCenterID,D.DocumentType,D.DocumentAbbr,D.DocumentName,D.IsUserDefined,D.IsInventory      
	FROM ADM_DocumentTypes D WITH(NOLOCK)        
	ORDER BY D.DocumentType Asc      
	
	--Getting Unique Document Defn
	SELECT UniqueDocumentDefn FROM ADM_DocumentTypes with(nolock) WHERE CostCenterID=@CostCenterID
	
	select  L.ResourceData FIELDNAME, a.CostCenterColID COSTCENTERCOLID, a.SysColumnName,d.[CostCenterColIDBase] 
	from adm_costcenterdef a WITH(NOLOCK)
	join com_languageresources l WITH(NOLOCK) on a.resourceid=l.resourceid and l.languageid=1
	left join COM_DocumentBatchLinkDetails d WITH(NOLOCK) on a.CostCenterColID=d.[BatchColID] and d.CostCenterID=@COSTCENTERID
	where ((a.CostCenterID=16 and (IsColumnInUse=1  or iscolumnuserdefined=0)
	and  CostCenterColID >1572 and  CostCenterColID not in(1548,1552,1553,1554,1557,1559,1560,1561,1562,1564,1567,1568,1567,
		1568,1573,1574,1575,1576,1577,1578,1579,1580,1585,1583,1586,1587,1570,1571,53693)) or CostCenterColID between 1101  and 1250 or CostCenterColID between 1261  and 1310)
	
	select CostCenterColID from ADM_DocumentDef with(nolock) 	    
	where [CostCenterID]=@CostCenterID and ShowinCalc =1
	
	select * FROM COM_DocumentBatchLinkDetails with(nolock)
	where LinkDimCCID<>16 and LinkDimCCID<>72 and [CostCenterID]=@CostCenterID

	select * FROM COM_DocumentBatchLinkDetails with(nolock)
	where LinkDimCCID<>16 and LinkDimCCID=72 and [CostCenterID]=@CostCenterID
	
	select * FROM [ADM_DocumentMap] with(nolock)
	where [CostCenterID]=@CostCenterID

	--10 -- DOWN PAYMENT MAP
	select  L.ResourceData as FieldName, a.CostCenterColID, a.SysColumnName
	from adm_costcenterdef a WITH(NOLOCK)
	join com_languageresources l WITH(NOLOCK) on a.resourceid=l.resourceid and l.languageid=1
	where a.CostCenterID=@CostCenterID AND a.IsColumnInUse=1 AND a.SysColumnName LIKE 'dcNUM%'
	
	--11 -- GETTTING ALL USED NUMERIC COLUMNS
	SELECT Name as SysColumnName From Sys.columns where object_id=OBJECT_ID('COM_DocNUMData') AND Name LIKE 'dcNUM%' ORDER BY Name


SET NOCOUNT OFF;              
RETURN 1              
END TRY              
BEGIN CATCH                
	--Return exception info [Message,Number,ProcedureName,LineNumber]                
	IF ERROR_NUMBER()=50000              
	BEGIN              
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID              
	END              
	ELSE              
	BEGIN              
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine              
		FROM COM_ErrorMessages WITH(NOLOCK) 
		WHERE ErrorNumber=-999 AND LanguageID=@LangID              
	END              
SET NOCOUNT OFF                
RETURN -999                 
END CATCH

GO
