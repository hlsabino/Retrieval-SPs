USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteDocumentDimensionData]
	@FLAG [int],
	@USERID [int] = 1,
	@LANGID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;   
IF(@FLAG=100)--ALL MASTERS AND TRANSACTIONS  
BEGIN  

DECLARE @SQL NVARCHAR(MAX)  
 ----TRANSACTION TABLES  
 --TRUNCATE TABLE A_BOM_IMPORT  
 TRUNCATE TABLE Com_CurrencyDenominations  
 TRUNCATE TABLE COM_BudgetAlloc  
 TRUNCATE TABLE COM_BudgetDimRelations  
 TRUNCATE TABLE COM_BudgetDefDims  
 --TRUNCATE TABLE COM_BudgetDef  
 DELETE FROM COM_BudgetDef  
 DBCC CHECKIDENT(COM_BudgetDef,RESEED,0)  
    
 TRUNCATE TABLE COM_BillwiseHistory  
 
 TRUNCATE TABLE COM_DocNumData_History  
 TRUNCATE TABLE COM_DocTextData_History  
 TRUNCATE TABLE COM_DocCCData_History  

 TRUNCATE TABLE COM_DocNumData  
 TRUNCATE TABLE COM_DocTextData  
 TRUNCATE TABLE COM_DocCCData  
 TRUNCATE TABLE COM_CCCCData  
 TRUNCATE TABLE COM_Billwise   
 TRUNCATE TABLE COM_BillWiseNonAcc   
 TRUNCATE TABLE COM_ChequeReturn   
 TRUNCATE TABLE COM_ContactsExtended  
 TRUNCATE TABLE COM_DocAddressData  
 TRUNCATE TABLE COM_PosPayModes   
 TRUNCATE TABLE COM_DocDraft  
 TRUNCATE TABLE COM_DocPayTerms  
 TRUNCATE TABLE COM_DocQtyAdjustments  
 TRUNCATE TABLE COM_HistoryDetails_History  
 TRUNCATE TABLE COM_HistoryDetails  
 TRUNCATE TABLE COM_LCBills  
 TRUNCATE TABLE COM_Notes   
 TRUNCATE TABLE COM_Files   
 TRUNCATE TABLE COM_DocID  
 TRUNCATE TABLE COM_DocDenominations  
 
  IF  EXISTS (select name from sys.tables where name='CRM_Activities')  
 BEGIN  
  
  SET @SQL='TRUNCATE TABLE CRM_Activities'  
  EXEC(@SQL)  
 END  
 TRUNCATE TABLE INV_BinDetails   
 TRUNCATE TABLE INV_DocExtraDetails  
 TRUNCATE TABLE INV_SerialStockProduct  
 TRUNCATE TABLE INV_TempInfo  
   
 Truncate Table ACC_DocDetails_History  
 Truncate Table ACC_DocDetails_History_ATUser  
 --Truncate Table ACC_DocDetails  
 DELETE FROM ACC_DocDetails  
 DBCC CHECKIDENT(ACC_DocDetails,RESEED,0)  
   
 Truncate Table INV_DocDetails_History  
 Truncate Table INV_DocDetails_History_ATUser   
 --TRUNCATE TABLE INV_DocDetails  
 DELETE FROM INV_DocDetails  
 DBCC CHECKIDENT(INV_DocDetails,RESEED,0)  
   
--PRODUCTION  
IF  EXISTS (select name from sys.tables where name='PRD_BillOfMaterial')  
 BEGIN  
  
  SET @SQL='Delete from PRD_BillOfMaterialExtended where BOMID>1  
 TRUNCATE TABLE PRD_BOMResources  
 TRUNCATE TABLE PRD_BOMProducts  
 TRUNCATE TABLE PRD_BOMStages  
 TRUNCATE TABLE PRD_Expenses  
 TRUNCATE TABLE PRD_JobOuputProducts  
 TRUNCATE TABLE PRD_MFGDocRef  
 TRUNCATE TABLE PRD_MFGOrderExtd  
 TRUNCATE TABLE PRD_MFGOrderBOMs  
 TRUNCATE TABLE PRD_MFGOrderWOs  
 TRUNCATE TABLE PRD_MOWODetails  
 TRUNCATE TABLE PRD_ProductionMethod  
 Delete from PRD_ResourceExtended WHERE ResourceID>2  
 TRUNCATE TABLE PRD_SFReportDocs  
 TRUNCATE TABLE PRD_SFReportProducts  
 TRUNCATE TABLE PRD_SFReportRMs  
 TRUNCATE TABLE PRD_BatchGroup  
   
 DELETE FROM PRD_Batch WHERE PRDBatchID>1  
 UPDATE PRD_Batch SET RGT=2  
 DBCC CHECKIDENT(PRD_Batch,RESEED,1)  
   
 DELETE FROM PRD_BatchProcess WHERE BatchProcessID>1  
 UPDATE PRD_BatchProcess SET RGT=2  
 --DBCC CHECKIDENT(PRD_BatchProcess,RESEED,1)  
   
 DECLARE @MAXVALUE INT  
 DELETE FROM PRD_BillOfMaterial WHERE BOMID in (select BOMID FROM PRD_BillOfMaterial with(nolock) WHERE BOMCode<>''BOMCode'')  
 UPDATE PRD_BillOfMaterial SET RGT=2  
 SELECT @MAXVALUE=BOMID FROM PRD_BillOfMaterial with(nolock) WHERE BOMCode=''BOMCode'' 
 DBCC CHECKIDENT(PRD_BillOfMaterial,RESEED,@MAXVALUE)    
   
 DELETE FROM PRD_MFGOrder WHERE MFGOrderID>1  
 UPDATE PRD_MFGOrder SET RGT=2  
 DBCC CHECKIDENT(PRD_MFGOrder,RESEED,1)   
   
 DELETE FROM PRD_Resources WHERE ResourceID>2  
 UPDATE PRD_Resources SET RGT=2  
 DBCC CHECKIDENT(PRD_Resources,RESEED,2)   
   
 DELETE FROM PRD_ShortFallReport WHERE SFReportID>1  
 UPDATE PRD_ShortFallReport SET RGT=2  
 DBCC CHECKIDENT(PRD_ShortFallReport,RESEED,1)'   
  
  EXEC(@SQL)  
 END 
--PAYROLL  
 IF  EXISTS (select name from sys.tables where name='PAY_EmpDetail')  
 BEGIN  
  
  SET @SQL='TRUNCATE TABLE PAY_DocNumData
  TRUNCATE TABLE PAY_DocNumData_History
  TRUNCATE TABLE PAY_EmpAccountsLinking  
 TRUNCATE TABLE PAY_EmployeeLeaveDetails  
 TRUNCATE TABLE PAY_EmpMonthlyAdjustments  
 TRUNCATE TABLE PAY_EmpMonthlyArrears  
 TRUNCATE TABLE PAY_EmpMonthlyDues  
 TRUNCATE TABLE PAY_PayrollPT  
 TRUNCATE TABLE PAY_EmpPay  
 TRUNCATE TABLE PAY_EmpDetail  
 TRUNCATE TABLE PAY_EmpTaxDeclaration  
 TRUNCATE TABLE PAY_EmpTaxHRAInfo  
 TRUNCATE TABLE PAY_YearwiseTaxAmountLimit  
 TRUNCATE TABLE PAY_EmpTaxComputation  
 TRUNCATE TABLE PAY_FinalSettlement  
   
 DELETE FROM COM_CC50052 WHERE NODEID>17  
 UPDATE COM_CC50052 SET LFT=1,RGT=34 WHERE NODEID=1  
 UPDATE COM_CC50052 SET LFT=2,RGT=3 WHERE NODEID=2  
 UPDATE COM_CC50052 SET LFT=4,RGT=5 WHERE NODEID=3  
 UPDATE COM_CC50052 SET LFT=6,RGT=7 WHERE NODEID=4  
 UPDATE COM_CC50052 SET LFT=8,RGT=9 WHERE NODEID=5  
 UPDATE COM_CC50052 SET LFT=10,RGT=33 WHERE NODEID=6  
 UPDATE COM_CC50052 SET LFT=11,RGT=12 WHERE NODEID=7  
 UPDATE COM_CC50052 SET LFT=13,RGT=14 WHERE NODEID=8  
 UPDATE COM_CC50052 SET LFT=15,RGT=16 WHERE NODEID=9  
 UPDATE COM_CC50052 SET LFT=17,RGT=18 WHERE NODEID=10  
 UPDATE COM_CC50052 SET LFT=19,RGT=20 WHERE NODEID=11  
 UPDATE COM_CC50052 SET LFT=21,RGT=22 WHERE NODEID=12  
 UPDATE COM_CC50052 SET LFT=23,RGT=24 WHERE NODEID=13  
 UPDATE COM_CC50052 SET LFT=25,RGT=26 WHERE NODEID=14  
 UPDATE COM_CC50052 SET LFT=27,RGT=28 WHERE NODEID=15  
 UPDATE COM_CC50052 SET LFT=29,RGT=30 WHERE NODEID=16  
 UPDATE COM_CC50052 SET LFT=31,RGT=32 WHERE NODEID=17  
 DBCC CHECKIDENT(COM_CC50052,RESEED,17)'   
  
  EXEC(@SQL)  
 END   
   

--RENTAL  
  IF  EXISTS (select name from sys.tables where name='REN_Contract')  
 BEGIN  
  
  SET @SQL='TRUNCATE TABLE REN_CollectionHistory  
 TRUNCATE TABLE REN_ContractDocMapping  
 TRUNCATE TABLE REN_ContractExtended_History  
 Delete from REN_ContractExtended where NodeID>1  
 TRUNCATE TABLE REN_ContractParticulars_History  
 TRUNCATE TABLE REN_ContractParticularsDetail  
 TRUNCATE TABLE REN_ContractParticulars  
 TRUNCATE TABLE REN_ContractPayTerms_History  
 TRUNCATE TABLE REN_ContractPayTerms  
 TRUNCATE TABLE REN_Particulars  
 DELETE FROM REN_PropertyExtended WHERE NodeID>1  
 TRUNCATE TABLE REN_PropertyShareHolder  
 TRUNCATE TABLE REN_PropertyUnits  
 TRUNCATE TABLE REN_QuotationExtended  
 TRUNCATE TABLE REN_QuotationParticulars  
 TRUNCATE TABLE REN_QuotationPayTerms  
 --TRUNCATE TABLE REN_Quotation  
 DELETE FROM REN_Quotation  
 DBCC CHECKIDENT(REN_Quotation,RESEED,0)  
   
 Delete from  REN_TenantExtended WHERE TenantID>1  
 TRUNCATE TABLE REN_TenantExtendedHistory  
 TRUNCATE TABLE REN_TenantHistory  
 TRUNCATE TABLE REN_TerminationParticulars  
 TRUNCATE TABLE Ren_UnitRate  
 Delete from REN_UnitsExtended where UnitID>1  
 TRUNCATE TABLE REN_UnitsExtendedHistory  
 TRUNCATE TABLE REN_UnitsHistory  
   
 DELETE FROM REN_Contract WHERE ContractID>1  
 UPDATE REN_Contract SET LFT=1,RGT=2 WHERE ContractID=1  
 DBCC CHECKIDENT(REN_Contract,RESEED,1)  
   
 DELETE FROM REN_Contract_History WHERE ContractHistoryID>1  
 UPDATE REN_Contract_History SET LFT=1,RGT=2 WHERE ContractHistoryID=1  
 DBCC CHECKIDENT(REN_Contract_History,RESEED,1)  
   
 DELETE FROM REN_Property WHERE NodeID>1  
 UPDATE REN_Property SET LFT=1,RGT=2 WHERE NodeID=1  
 DBCC CHECKIDENT(REN_Property,RESEED,1)  
   
 DELETE FROM REN_Tenant WHERE TenantID>1  
 UPDATE REN_Tenant SET LFT=1,RGT=2 WHERE TenantID=1  
 DBCC CHECKIDENT(REN_Tenant,RESEED,1)  
   
 DELETE FROM REN_Units WHERE UnitID>1  
 UPDATE REN_Units SET LFT=1,RGT=2 WHERE UnitID=1  
 DBCC CHECKIDENT(REN_Units,RESEED,1)'   
  
  EXEC(@SQL)  
 END   
   
--CRM  
  IF  EXISTS (select name from sys.tables where name='CRM_Leads')  
 BEGIN  
  
  SET @SQL='Truncate Table CRM_CampaignInvites  
 Truncate Table CRM_LeadCVRDetails  
 Truncate Table CRM_CampaignOrganization  
 Truncate Table CRM_CampaignActivities  
 Truncate Table CRM_ServiceContractExtd  
 Truncate Table CRM_ContractLines  
 Truncate Table CRM_CampaignProducts  
 Truncate Table CRM_Feedback  
 Truncate Table CRM_CaseSvcTypeMap  
 Truncate Table CRM_Assignment  
 Delete from CRM_CasesExtended WHERE CaseID>1  
 Truncate Table CRM_Activities  
 Truncate Table CRM_FollowUpCustomization  
 Truncate Table CRM_AssignmentHistory  
 Delete from CRM_LeadsExtended WHERE LeadID>1  
 Truncate Table CRM_ServiceTypes  
 Truncate Table CRM_ServiceReasons  
 Truncate Table CRM_ContractTemplate  
 Truncate Table CRM_CampaignSpeakers  
 Truncate Table CRM_CampaignApprovals  
 Truncate Table CRM_CampaignStaff  
 Truncate Table CRM_ProductMapping  
 Delete from CRM_CampaignsExtended WHERE CampaignID>3  
 Truncate Table CRM_CampaignResponse  
 Delete from CRM_CustomerExtended WHERE CustomerID>1  
 Truncate Table CRM_OpportunityDocMap  
 Delete from CRM_OpportunitiesExtended WHERE OpportunityID>1  
 Truncate Table CRM_CampaignDemoKit  
   
 DELETE FROM CRM_ServiceContract WHERE SvcContractID>1  
 UPDATE CRM_ServiceContract SET RGT=2 WHERE SvcContractID=1  
 DBCC CHECKIDENT(CRM_ServiceContract,RESEED,1)  
   
 DELETE FROM CRM_Campaigns WHERE CampaignID>3  
 UPDATE CRM_Campaigns SET LFT=1,RGT=6 WHERE CampaignID=1  
 UPDATE CRM_Campaigns SET LFT=4,RGT=5 WHERE CampaignID=2  
 UPDATE CRM_Campaigns SET LFT=2,RGT=3 WHERE CampaignID=3  
 DBCC CHECKIDENT(CRM_Campaigns,RESEED,3)  
   
 DELETE FROM CRM_Teams WHERE NodeID>1  
 UPDATE CRM_Teams SET LFT=1,RGT=2 WHERE NodeID=1  
 DBCC CHECKIDENT(CRM_Teams,RESEED,1)  
   
 DELETE FROM CRM_Cases WHERE CaseID>1  
 UPDATE CRM_Cases SET LFT=1,RGT=2 WHERE CaseID=1  
 DBCC CHECKIDENT(CRM_Cases,RESEED,1)  
   
 DELETE FROM CRM_Opportunities WHERE OpportunityID>1  
 UPDATE CRM_Opportunities SET RGT=2 WHERE OpportunityID=1  
 DBCC CHECKIDENT(CRM_Opportunities,RESEED,1)  
   
 DELETE FROM CRM_Contacts WHERE ContactID>1  
 UPDATE CRM_Contacts SET lft=2,RGT=3 WHERE ContactID=1  
 DBCC CHECKIDENT(CRM_Contacts,RESEED,1)  
   
 DELETE FROM CRM_Customer WHERE CustomerID>1  
 UPDATE CRM_Customer SET RGT=2 WHERE CustomerID=1  
 DBCC CHECKIDENT(CRM_Customer,RESEED,1)
 
 DELETE FROM CRM_Leads WHERE LeadID>1  
 UPDATE CRM_Leads SET RGT=2 WHERE LeadID=1  
 DBCC CHECKIDENT(CRM_Leads,RESEED,1)  '   
  
  EXEC(@SQL)  
 END   
  
--PRODUCT  
 Truncate Table INV_BatchDetails   
 Truncate Table INV_Batches  
 Truncate Table INV_LinkedProducts  
 Truncate Table INV_MatrixDef  
 Truncate Table INV_MRP  
 Truncate Table INV_ProductBarcode  
 Truncate Table INV_ProductBinRules  
 Truncate Table INV_ProductBins  
 Truncate Table INV_ProductBundles  
 --Truncate Table INV_ProductExtended   
 Delete from INV_ProductExtended where productid>1  
   
 Truncate Table INV_ProductExtendedHistory  
 Truncate Table INV_ProductHistory  
 Truncate Table INV_ProductSubstitutes  
 Truncate Table INV_ProductTestcases  
 Truncate Table INV_ProductVendors  
 --Truncate Table INV_ValuationMethods  
 Delete From INV_Product where PRODUCTID >1  
 UPDATE INV_Product SET lft=2,RGT=3 WHERE PRODUCTID=0  
 UPDATE INV_Product SET lft=1,RGT=4 WHERE PRODUCTID=1  
 DBCC CHECKIDENT(INV_Product,RESEED,1)  
   
 DELETE FROM COM_UOM WHERE UOMID>1  
 DBCC CHECKIDENT(COM_UOM,RESEED,1)  
  
--DIMENSION TABLES  
 TRUNCATE TABLE COM_Address  
 TRUNCATE TABLE COM_Address_History  
 --TRUNCATE TABLE COM_CCGROUPSERIES  
 TRUNCATE TABLE COM_CCPARENTCODEDEF  
   
 Delete From COM_CCPRICESDEFN where ProfileID>0  
 UPDATE COM_CCPRICESDEFN SET RGT=2  
 DBCC CHECKIDENT(COM_CCPRICESDEFN,RESEED,0)   
   
 DELETE FROM COM_CCPRICETAXCCDEFN WHERE ProfileID>0   
 DELETE FROM COM_CCTAXES WHERE ProfileID>0   
 --TRUNCATE TABLE COM_CCWORKFLOW  
 TRUNCATE TABLE COM_CCSCHEDULES  
 TRUNCATE TABLE COM_Schedules  
 TRUNCATE TABLE COM_SchEvents  
 TRUNCATE TABLE COM_CCPRICES  
   
 Delete From COM_CCTAXESDEFN where ProfileID>0  
 UPDATE COM_CCTAXESDEFN SET RGT=2  
 DBCC CHECKIDENT(COM_CCTAXESDEFN,RESEED,0)   
 
 DECLARE @tab TABLE (ID INT IDENTITY(1,1),FeatureID INT,TableName NVARCHAR(32))
 INSERT INTO @tab 
  SELECT FeatureID,TableName FROM ADM_FEATURES with(nolock) 
  where FeatureID >50000 and FeatureID NOT IN (50052,50058,50059,50060,50061,50062,50063,50064,50065,50066,50067,50070,50071,50072)
 DECLARE @I INT,@CNT INT, @CCID INT,@CCNAME NVARCHAR(50),@STRQRY NVARCHAR(MAX)  
 SELECT @I=1,@CNT=COUNT(*) FROM @tab   
 WHILE(@I<=@CNT)  
 BEGIN  
  
   select @CCID=FeatureID,@CCNAME=TableName from @tab where ID=@I 
   
   IF(@CCID=50054)  
   BEGIN  
    SET @STRQRY='if exists (select name from sys.tables where name='''+@CCNAME+''')  
   begin  
	DELETE FROM ' + CONVERT(VARCHAR,@CCNAME)+'  
    DBCC CHECKIDENT('+ @CCNAME+',RESEED,0)
   end ' 
    EXEC (@STRQRY)    
   END  
   ELSE  
   BEGIN  
   SET @STRQRY='if exists (select name from sys.tables where name='''+@CCNAME+''')  
   begin  
    DELETE FROM ' + @CCNAME+' WHERE NODEID>2
    UPDATE ' + @CCNAME+' SET lft=2,RGT=3 WHERE NODEID=1
    UPDATE ' + @CCNAME+' SET lft=1,RGT=4 WHERE NODEID=2
    DBCC CHECKIDENT('+ @CCNAME+',RESEED,2)  
   end '
   EXEC (@STRQRY)   
   END  
   
 SET @I=@I+1   
 END  

--ACCOUNT TABLES  
 Truncate Table ACC_AssetChanges  
 Truncate Table ACC_AssetDeprSchTemp  
 Truncate Table ACC_AssetDeprDocDetails  
 --Truncate Table ACC_AssetDepSchedule  
 Delete From ACC_AssetDepSchedule  
 DBCC CHECKIDENT(ACC_AssetDepSchedule,RESEED,0)   
   
 Truncate Table ACC_AssetClass  
 Delete From ACC_AssetsExtended where AssetID>1  
 Truncate Table ACC_AssetsHistory  
 Delete From ACC_Assets where AssetID>1  
 DBCC CHECKIDENT(ACC_Assets,RESEED,1)   
 --Truncate Table ACC_Assets  
   
 Truncate Table ACC_ChequeBooks  
 Truncate Table ACC_ChequeCancelled  
 Truncate Table Acc_CreditDebitAmount  
 --Truncate Table ACC_DepreciationMethods  
 Truncate Table ACC_DeprBook  
 Truncate Table Acc_PaymentDiscountTerms  
 Truncate Table Acc_PaymentDiscountProfile  
 Truncate Table ACC_PostingGroup  
 Truncate Table ACC_ReportTemplate  
 --Truncate Table ACC_AccountsExtended  
 Delete from ACC_AccountsExtended where AccountID>40  
 Truncate Table ACC_AccountsHistory  
   
 Delete From ACC_Accounts where AccountID>40  
 Exec spCOM_SetTreeStructure 2  
 DBCC CHECKIDENT(ACC_Accounts,RESEED,40)   
  
 DELETE FROM COM_Contacts  
 DBCC CHECKIDENT(COM_Contacts,RESEED,0)  
   
 DELETE FROM COM_CostCenterCodeDef WHERE ISNULL(CODEPREFIX,'')<>''  UPDATE COM_CostCenterCodeDef SET CurrentCodeNumber=0,CodeNumberLength=1 WHERE ISNULL(CODEPREFIX,'')=''  
   
 UPDATE ADM_DocumentDef SET DebitAccount=NULL WHERE DebitAccount>0  
 UPDATE ADM_DocumentDef SET CreditAccount=NULL WHERE CreditAccount>0  
   
 UPDATE ADM_CostCenterDef SET UserDefaultValue=NULL where [ColumnCostCenterID]>0 and [ColumnCostCenterID]<>44  
 and UserDefaultValue is not null and isnumeric(UserDefaultValue)=1 and convert(int,UserDefaultValue)>0   
END  
  
COMMIT TRANSACTION           
SET NOCOUNT OFF;    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=102 AND LanguageID=1    
RETURN 1  
END TRY  
BEGIN CATCH   
 SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
 FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  
GO
