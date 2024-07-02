USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDocuments]
	@COSTCENTERID [bigint],
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON;      
         
      
 --User access check       
  SELECT  DocumentPrefID,P.PrefValueType,L.ResourceData [Text],PrefDefalutValue,PrefDefalutValue Value,P.PrefName [DBText],P.PreferenceTypeName [Group],PrefRowOrder,PrefColOrder      
 FROM COM_DocumentPreferences P WITH(NOLOCK)         
 INNER JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID  and LanguageID=@LangID  AND PreferenceTypeName='Common'      
 AND DocumentTypeID=1      
 --Getting all Documents      
 IF(@COSTCENTERID = 109)
 BEGIN
  SELECT D.DocumentTypeID,D.IsUserDefined,D.CostCenterID,D.DocumentType,D.DocumentAbbr,D.DocumentName,D.IsUserDefined,L.ResourceData    ,D.ConvertAs ConvertAs , D.Bounce Bounce , D.OnDiscount OnDiscount   
 FROM ADM_DocumentTypes D WITH(NOLOCK)      
 INNER JOIN ADM_RibbonView R WITH(NOLOCK) ON R.FeatureID=D.CostCenterID      
 LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
    WHERE D.DOCUMENTTYPE = 19       
 ORDER BY D.DocumentName,D.DocumentType,D.IsUserDefined Asc 
 END
 ELSE
 BEGIN
 SELECT D.DocumentTypeID,D.IsUserDefined,D.CostCenterID,D.DocumentType,D.DocumentAbbr,D.DocumentName,D.IsUserDefined,L.ResourceData    ,D.ConvertAs ConvertAs , D.Bounce Bounce   , D.OnDiscount OnDiscount  
 FROM ADM_DocumentTypes D WITH(NOLOCK)      
 INNER JOIN ADM_RibbonView R WITH(NOLOCK) ON R.FeatureID=D.CostCenterID      
 LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
    WHERE D.IsUserDefined=0        
 ORDER BY D.DocumentName,D.DocumentType,D.IsUserDefined Asc 
 END        
 --Getting AccountTypes      
 SELECT ACCOUNTTYPEID,ACCOUNTTYPE FROM ACC_ACCOUNTTYPES WITH(NOLOCK) WHERE STATUS='Active' ORDER BY ACCOUNTTYPE      
 --GET RIBBON MENU DATA      
 SELECT R.FeatureID,L.ResourceData as ResourceData  FROM ADM_RIBBONVIEW R   WITH(NOLOCK)   
 LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=R.DisplaynameResourceID AND L.LanguageID=@LangID  
 where FeatureID in(select costcenterid from dbo.ADM_DOCUMENTTYPES with(nolock)
 where CostCenterID>40000 and CostCenterID<50000 and IsUserDefined=0 )  
 order by L.ResourceData,FeatureID  
      
 --Getting Documents.        
 SELECT D.DocumentTypeID,D.CostCenterID,D.DocumentType,D.DocumentAbbr,D.DocumentName,D.IsUserDefined,D.IsInventory      
 FROM ADM_DocumentTypes D WITH(NOLOCK)        
 ORDER BY D.DocumentName,D.DocumentType Asc        
  
 --GET COSTCENTERS  
 SELECT FEATUREID,NAME,'/' 'Link/Delink' ,5 'ColumnWidth' FROM ADM_FEATURES WITH(NOLOCK)       
 WHERE (FEATUREID > 50000  and ISEnabled=1 ) or FEATUREID=61 or FEATUREID=65 or FEATUREID=83 or FEATUREID=7
  
 --Get ListViews      
 SELECT ListViewID,ListViewTypeID,CostCenterID,ListViewName from ADM_ListView WITH(NOLOCK) order by ListViewName
      
 SELECT CostCenterID,DocumentName from ADM_DocumentTypes  WITH(NOLOCK)      
 union
 select FeatureID,Name from [ADM_Features]  WITH(NOLOCK)
 where  FeatureID in(158,76)
 order by DocumentName
 
 SELECT a.CostCenterID,CostCenterColID,l.ResourceData,IsColumnUserDefined from ADM_CostCenterDef a WITH(NOLOCK)      
 JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=a.ResourceID  and LanguageID=@LangID      
 JOIN ADM_DocumentTypes d  WITH(NOLOCK) ON a.CostCenterID=d.CostCenterID      
 where ((IsColumnInUse=1 and SysColumnName like 'dcNum%') or (IsColumnUserDefined=0 and (SysColumnName='Quantity' or SysColumnName='Rate' or  SysColumnName='Gross')))      
 and SectionID=3 and a.CostCenterID between 40000 and 50000 and  IsInventory=1      
    
 -- list of feilds    
SELECT CDF.COSTCENTERID COSTCENTERID, CDF.COSTCENTERCOLID, R.RESOURCEDATA  CCFIELDNAME,CDF.SysColumnName,CDF.ColumnCostCenterID  FROM ADM_COSTCENTERDEF  CDF WITH(NOLOCK)   
JOIN COM_LANGUAGERESOURCES R WITH(NOLOCK) ON CDF.RESOURCEID = R.RESOURCEID  AND R.LANGUAGEID = @LangID   
WHERE (CDF.IsColumnUserDefined=0  or CDF.IsColumnInUse=1) and CostCenterID not between 40000 and 50000    
ORDER BY CDF.COSTCENTERID    
  
 --list of Location  
  -- select * from COM_Location where nodeid in (select nodeid from COM_CostCenterCostCenterMap where ParentNodeid in  
  --@RoleID and ParentCostCenterID=6 and CostCenterID=50002)  
  
  select l.* from COM_Location l with(nolock)
  join COM_Location g with(nolock) on l.lft between g.lft and g.rgt   
  where   g.NodeID in (select NodeID from COM_CostCenterCostCenterMap  WITH(NOLOCK)
  where CostCenterID=50002 and ParentCostCenterID=6 and ParentNodeID=@RoleID)  
  
 --list of DOCUMENT Status  
 select StatusID,Status from COM_Status WITH(NOLOCK) where CostCenterID=400 and FeatureID=400  
  
 --Getting Status of Respective CostCenter  
 select S.Status,A.StatusID from ADM_DocumentTypes A WITH(NOLOCK),COM_STATUS S WITH(NOLOCK) where A.CostCenterID=@COSTCENTERID and A.StatusID=S.StatusID  
  
 --Getting BankPayments  
 select CostCenterID,DocumentName from ADM_DocumentTypes WITH(NOLOCK) where DocumentType=15  order by DocumentName
  
 --Getting BankReceipts   
 select CostCenterID,DocumentName from ADM_DocumentTypes WITH(NOLOCK) where DocumentType=18    order by DocumentName
  
 --Getting the Value of PDC from ADM_GlobalPreferences  
 select * from ADM_GlobalPreferences WITH(NOLOCK) where ResourceID=37009 and GlobalPrefID=94  
    
 -- Getting the Active List of Currencies  
 SELECT     CurrencyID, Name FROM COM_Currency WITH(NOLOCK)  WHERE (StatusID <> 'false') OR  (StatusID IS NULL)      order by Name
   
 --Getting Details of All Documents from Adm_CostCenterDef  
 select distinct A.CostCenterID,A.CostCenterColID,A.CostCenterName,C.ResourceData as SysColumnName,SysColumnName  syscol
 from ADM_CostCenterDef A  WITH(NOLOCK)
 join Com_LanguageResources C WITH(NOLOCK) on C.ResourceID=A.ResourceID and languageid=@LangID
 where  (IsColumnUserDefined=0  or IsColumnInUse=1) and  
  SysColumnName NOT LIKE '%dcCurrID%' and SysColumnName NOT LIKE '%dcExchRT%' and  SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName <> 'UOMConversion'   AND SysColumnName <> 'UOMConvertedQty'   
  and CostCenterID between 40000 and 50000   
union  
select -1 CostCenterID,-1 CostCenterColID,'' CostCenterName,'' as SysColumnName,''  
union    
select -2 CostCenterID,-2 CostCenterColID,'' CostCenterName,'Doc SerialNo' as SysColumnName    ,''
union    
select -3 CostCenterID,-3 CostCenterColID,'' CostCenterName,'Doc Prefix' as SysColumnName,''
union    
select -4 CostCenterID,-4 CostCenterColID,'' CostCenterName,'SeqNo' as SysColumnName    ,''
union    
select -5 CostCenterID,-5 CostCenterColID,'' CostCenterName,'BOE' as SysColumnName    ,''
union
 select distinct A.CostCenterID,A.CostCenterColID*-1,A.CostCenterName,'TO' +C.ResourceData as SysColumnName,'TO' +SysColumnName  syscol
 from ADM_CostCenterDef A  WITH(NOLOCK)
 join Com_LanguageResources C WITH(NOLOCK) on C.ResourceID=A.ResourceID and languageid=1
 where  (IsColumnUserDefined=0  or IsColumnInUse=1) and  
  SysColumnName NOT LIKE '%dcCurrID%' and SysColumnName NOT LIKE '%dcExchRT%' and  SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName <> 'UOMConversion'   AND SysColumnName <> 'UOMConvertedQty'   
  and CostCenterID between 40000 and 50000 and IsTransfer>0 
	order by CostCenterID,SysColumnName
  
 --Document Prefix  
 SELECT C.CostCenterColID, F.Name + ' - ' + C.SysColumnName AS Name,'/' 'Link/Delink' ,5 'ColumnWidth', C.CostCenterID  
FROM ADM_CostCenterDef AS C WITH(NOLOCK) INNER JOIN  
  ADM_Features AS F WITH(NOLOCK) ON C.CostCenterID = F.FeatureID  
WHERE (C.SysColumnName = N'Code' OR C.SysColumnName = N'Name') AND (C.CostCenterID > 50000) AND (F.IsEnabled = 1)  
  
  
--To Get Available Budgets  
SELECT BudgetDefID,BudgetName FROM COM_BudgetDef WITH(NOLOCK) WHERE StatusID=1 AND IsGroup=0  order by BudgetName

--To Get LookupTypes
SELECT NodeID,LookupName FROM COM_LookupTypes WITH(NOLOCK) ORDER BY LookupName  
  
  --To Get Views
  select CostCenterID,ViewName,GridViewID ViewID from ADM_GridView WITH(NOLOCK)
  
  --To Get Views
  select ProfileID,ProfileName from Acc_PaymentDiscountProfile with(nolock)
	
		select distinct ProfileID,ProfileName from COM_DimensionMappings WITH(NOLOCK)
 
  
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
