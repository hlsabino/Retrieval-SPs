USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_AllDataDelete]
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
	----------------------------------------
	CREATE TABLE #x (drop_script NVARCHAR(MAX),create_script NVARCHAR(MAX))
	DECLARE @drop   NVARCHAR(MAX) = N'',@create NVARCHAR(MAX) = N''

	SELECT @drop += N' ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) + ' DROP CONSTRAINT ' + QUOTENAME(fk.name)
	FROM sys.foreign_keys AS fk
	INNER JOIN sys.tables AS ct ON fk.parent_object_id = ct.[object_id]
	INNER JOIN sys.schemas AS cs ON ct.[schema_id] = cs.[schema_id]

	INSERT #x(drop_script) 
	SELECT @drop

	SELECT @create += N' ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) + case when fk.is_not_trusted = 0 then ' WITH CHECK ' ELSE ' WITH NOCHECK ' END
	+ ' ADD CONSTRAINT ' + QUOTENAME(fk.name) + ' FOREIGN KEY (' + STUFF((SELECT ',' + QUOTENAME(c.name)
	FROM sys.columns AS c 
	INNER JOIN sys.foreign_key_columns AS fkc ON fkc.parent_column_id = c.column_id AND fkc.parent_object_id = c.[object_id]
	WHERE fkc.constraint_object_id = fk.[object_id]
	ORDER BY fkc.constraint_column_id 
	FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') + ') REFERENCES ' + QUOTENAME(rs.name) + '.' + QUOTENAME(rt.name) + '(' + STUFF((SELECT ',' + QUOTENAME(c.name)
	FROM sys.columns AS c 
	INNER JOIN sys.foreign_key_columns AS fkc ON fkc.referenced_column_id = c.column_id AND fkc.referenced_object_id = c.[object_id]
	WHERE fkc.constraint_object_id = fk.[object_id]
	ORDER BY fkc.constraint_column_id 
	FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') + ')'

	FROM sys.foreign_keys AS fk
	INNER JOIN sys.tables AS rt ON fk.referenced_object_id = rt.[object_id]
	INNER JOIN sys.schemas AS rs ON rt.[schema_id] = rs.[schema_id]
	INNER JOIN sys.tables AS ct ON fk.parent_object_id = ct.[object_id]
	INNER JOIN sys.schemas AS cs ON ct.[schema_id] = cs.[schema_id]
	WHERE rt.is_ms_shipped = 0 AND ct.is_ms_shipped = 0

	UPDATE #x 
	SET create_script = @create

	EXEC sp_executesql @drop
	----------------------------------------


	exec sp_MSforeachtable
	@command1='TRUNCATE TABLE ?',
	@whereand=' and object_id IN(Select object_Id from sys.Tables where Name IN(
	''Com_CurrencyDenominations'',''COM_BudgetAlloc'',''COM_BudgetDimRelations'',''COM_BudgetDefDims'',''COM_BillwiseHistory'',''COM_DocNumData_History'',
	''COM_DocTextData_History'',''COM_DocCCData_History'',''COM_DocNumData'',''COM_DocTextData'',''COM_DocCCData'',''COM_CCCCData'',''COM_Billwise'',
	''COM_BillWiseNonAcc'',''COM_ChequeReturn'',''COM_ContactsExtended'',''COM_DocAddressData'',''COM_PosPayModes'',''COM_DocDraft'',''COM_DocPayTerms'',
	''COM_DocQtyAdjustments'',''COM_HistoryDetails_History'',''COM_HistoryDetails'',''COM_LCBills'',''COM_Notes'',''COM_Files'',''COM_DocID'',''COM_DocDenominations'',
	''INV_BinDetails'',''INV_DocExtraDetails'',''INV_SerialStockProduct'',''INV_TempInfo'',''ACC_DocDetails_History'',''ACC_DocDetails_History_ATUser'',''INV_DocDetails_History'',
	''INV_DocDetails_History_ATUser'',''INV_BatchDetails'',''INV_Batches'',''INV_LinkedProducts'',''INV_MatrixDef'',''INV_MRP'',''INV_ProductBarcode'',''INV_ProductBinRules'',
	''INV_ProductBins'',''INV_ProductBundles'',''INV_ProductExtendedHistory'',''INV_ProductHistory'',''INV_ProductSubstitutes'',''INV_ProductTestcases'',''INV_ProductVendors'',
	''COM_Address'',''COM_Address_History'',''COM_CCPARENTCODEDEF'',''COM_CCSCHEDULES'',''COM_Schedules'',''COM_SchEvents'',''COM_CCPRICES'',''ACC_AssetChanges'',
	''ACC_AssetDeprSchTemp'',''ACC_AssetDeprDocDetails'',''ACC_AssetClass'',''ACC_AssetsHistory'',''ACC_ChequeBooks'',''ACC_ChequeCancelled'',''Acc_CreditDebitAmount'',
	''ACC_DeprBook'',''Acc_PaymentDiscountTerms'',''Acc_PaymentDiscountProfile'',''ACC_PostingGroup'',''ACC_ReportTemplate'',''ACC_AccountsHistory'',
	''CRM_Activities''))'

	--''ACC_DepreciationMethods'',

	exec sp_MSforeachtable
	@command1='TRUNCATE TABLE ?',
	@whereand=' and object_id IN(Select object_Id from sys.Tables where Name IN(
	''PRD_BOMResources'',''PRD_BOMProducts'',''PRD_BOMStages'',''PRD_Expenses'',''PRD_JobOuputProducts'',''PRD_MFGDocRef'',
	''PRD_MFGOrderExtd'',''PRD_MFGOrderBOMs'',''PRD_MFGOrderWOs'',''PRD_MOWODetails'',''PRD_ProductionMethod'',''PRD_SFReportDocs'',''PRD_SFReportProducts'',
	''PRD_SFReportRMs'',''PRD_BatchGroup'',
	''PAY_DocNumData'',''PAY_DocNumData_History'',''PAY_EmpAccountsLinking'',''PAY_EmployeeLeaveDetails'',''PAY_EmpMonthlyAdjustments'',''PAY_EmpMonthlyArrears'',
	''PAY_EmpMonthlyDues'',''PAY_PayrollPT'',''PAY_EmpPay'',''PAY_EmpDetail'',''PAY_EmpTaxDeclaration'',''PAY_EmpTaxHRAInfo'',''PAY_YearwiseTaxAmountLimit'',
	''PAY_EmpTaxComputation'',''PAY_FinalSettlement''))'

	exec sp_MSforeachtable
	@command1='TRUNCATE TABLE ?',
	@whereand=' and object_id IN(Select object_Id from sys.Tables where Name IN(
	''REN_CollectionHistory'',''REN_ContractDocMapping'',''REN_ContractExtended_History'',''REN_ContractParticulars_History'',''REN_ContractParticularsDetail'',
	''REN_ContractParticulars'',''REN_ContractPayTerms_History'',''REN_ContractPayTerms'',''REN_Particulars'',''REN_PropertyShareHolder'',''REN_PropertyUnits'',
	''REN_QuotationExtended'',''REN_QuotationParticulars'',''REN_QuotationPayTerms'',''REN_TenantExtendedHistory'',''REN_TenantHistory'',''REN_TerminationParticulars'',
	''Ren_UnitRate'',''REN_UnitsExtendedHistory'',''REN_UnitsHistory'',
	''CRM_CampaignInvites'',''CRM_LeadCVRDetails'',''CRM_CampaignOrganization'',''CRM_CampaignActivities'',''CRM_ServiceContractExtd'',''CRM_ContractLines'',
	''CRM_CampaignProducts'',''CRM_Feedback'',''CRM_CaseSvcTypeMap'',''CRM_Assignment'',''CRM_Activities'',''CRM_FollowUpCustomization'',''CRM_AssignmentHistory'',
	''CRM_ServiceTypes'',''CRM_ServiceReasons'',''CRM_ContractTemplate'',''CRM_CampaignSpeakers'',''CRM_CampaignApprovals'',''CRM_CampaignStaff'',''CRM_ProductMapping'',
	''CRM_CampaignResponse'',''CRM_OpportunityDocMap'',''CRM_CampaignDemoKit''))'

	exec sp_MSforeachtable
	@command1='TRUNCATE TABLE ?',
	@whereand=' and object_id IN(Select object_Id from sys.Tables where Name IN(
	''ACC_DocDetails'',''INV_DocDetails'',''REN_Quotation'',''ACC_AssetDepSchedule'',''COM_Contacts'',''COM_BRSTemplate'',''COM_BiddingDocs''))'
	
	DELETE FROM COM_BudgetDef WHERE BudgetDefID>1
	DBCC CHECKIDENT(COM_BudgetDef,RESEED,1)  

	--PRODUCTION  
	IF  EXISTS (select name from sys.tables where name='PRD_BillOfMaterial')  
	BEGIN  
		SET @SQL='
		Delete from PRD_BillOfMaterialExtended where BOMID>1  
		Delete from PRD_ResourceExtended WHERE ResourceID>2  
		
		DELETE FROM PRD_Batch WHERE PRDBatchID>1 
		 
		UPDATE PRD_Batch SET RGT=2  
		DBCC CHECKIDENT(PRD_Batch,RESEED,1)  
   
		DELETE FROM PRD_BatchProcess WHERE BatchProcessID>1  
		UPDATE PRD_BatchProcess SET RGT=2  
   
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
		SET @SQL='
		
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
		SET @SQL='
			Delete from REN_ContractExtended where NodeID>1  
			DELETE FROM REN_PropertyExtended WHERE NodeID>1  
			Delete from  REN_TenantExtended WHERE TenantID>1  
			Delete from REN_UnitsExtended where UnitID>1  
	
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
		SET @SQL='
			Delete from CRM_CasesExtended WHERE CaseID>1  
			Delete from CRM_LeadsExtended WHERE LeadID>1  
			Delete from CRM_CampaignsExtended WHERE CampaignID>3  
			Delete from CRM_CustomerExtended WHERE CustomerID>1  
			Delete from CRM_OpportunitiesExtended WHERE OpportunityID>1  
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
	  
	Delete from INV_ProductExtended where productid>1  
   
	Delete From INV_Product where PRODUCTID >1  
	UPDATE INV_Product SET lft=2,RGT=3 WHERE PRODUCTID=0  
	UPDATE INV_Product SET lft=1,RGT=4 WHERE PRODUCTID=1  
	DBCC CHECKIDENT(INV_Product,RESEED,1)  
   
	DELETE FROM COM_UOM WHERE UOMID>1  
	DBCC CHECKIDENT(COM_UOM,RESEED,1)  
  
	--DIMENSION TABLES  
   
	Delete From COM_CCPRICESDEFN where ProfileID>0  
	UPDATE COM_CCPRICESDEFN SET RGT=2  
	DBCC CHECKIDENT(COM_CCPRICESDEFN,RESEED,0)   
   
	DELETE FROM COM_CCPRICETAXCCDEFN WHERE ProfileID>0   
	DELETE FROM COM_CCTAXES WHERE ProfileID>0   
	
	Delete From COM_CCTAXESDEFN where ProfileID>0  
	UPDATE COM_CCTAXESDEFN SET RGT=2  
	DBCC CHECKIDENT(COM_CCTAXESDEFN,RESEED,0)   
 
	DECLARE @tab TABLE (ID INT IDENTITY(1,1),FeatureID INT,TableName NVARCHAR(32))
	INSERT INTO @tab 
	SELECT FeatureID,TableName FROM ADM_FEATURES with(nolock) 
	where FeatureID >50000 and FeatureID NOT IN (50052,50054,50058,50059,50060,50061,50062,50063,50064,50065,50066,50067,50070,50071,50072)
	DECLARE @I INT,@CNT INT, @CCID INT,@CCNAME NVARCHAR(50),@STRQRY NVARCHAR(MAX)  
	SELECT @I=1,@CNT=COUNT(*) FROM @tab   
	WHILE(@I<=@CNT)  
	BEGIN  
		select @CCID=FeatureID,@CCNAME=TableName from @tab where ID=@I 
		SET @STRQRY='if exists (select name from sys.tables where name='''+@CCNAME+''')  
		begin  
			DELETE FROM ' + @CCNAME+' WHERE NODEID>2
			UPDATE ' + @CCNAME+' SET lft=2,RGT=3 WHERE NODEID=1
			UPDATE ' + @CCNAME+' SET lft=1,RGT=4 WHERE NODEID=2
			DBCC CHECKIDENT('+ @CCNAME+',RESEED,2)  
		end '
		EXEC (@STRQRY)   
		SET @I=@I+1   
	END  

	--ACCOUNT TABLES  
	
	Delete From ACC_AssetsExtended where AssetID>1  

	Delete From ACC_Assets where AssetID>1  
	DBCC CHECKIDENT(ACC_Assets,RESEED,1)   
   
	Delete from ACC_AccountsExtended where AccountID>40  
   
	Delete From ACC_Accounts where AccountID>40  
	Exec spCOM_SetTreeStructure 2  
	DBCC CHECKIDENT(ACC_Accounts,RESEED,40)   
  
	DELETE FROM COM_CostCenterCodeDef WHERE ISNULL(CODEPREFIX,'')<>'' 
	UPDATE COM_CostCenterCodeDef SET CurrentCodeNumber=0,CodeNumberLength=1 WHERE ISNULL(CODEPREFIX,'')=''  
   
	UPDATE ADM_DocumentDef SET DebitAccount=NULL WHERE DebitAccount>0  
	UPDATE ADM_DocumentDef SET CreditAccount=NULL WHERE CreditAccount>0  
   
	UPDATE ADM_CostCenterDef SET UserDefaultValue=NULL where [ColumnCostCenterID]>0 and [ColumnCostCenterID]<>44  
	and UserDefaultValue is not null and isnumeric(UserDefaultValue)=1 and convert(int,UserDefaultValue)>0   

	EXEC sp_executesql @create;
	DROP TABLE #x 

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
