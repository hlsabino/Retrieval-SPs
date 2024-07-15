USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SyncData]
	@Type [int],
	@CCID [int],
	@MaxID [int],
	@ModDate [float],
	@CopyCall [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY
SET NOCOUNT ON
	
	declare @Tbl as table(ID INT)
	declare @SQL nvarchar(max)
	
	if @Type=100 --CostCenterDef
	begin
		--ADM_FinancialYears
		--ADM_GlobalPreferences
		--ADM_QueryDefn
		--ADM_RevenUReports
		
		if @CCID=1
		begin
			select 'ADM_CostCenterDef' TableName,1 HasIdentity,0 IgnoreFirstColumn
			select top 1000 * from ADM_CostCenterDef with(nolock) where CostCenterColID>@MaxID order by CostCenterColID
		end
		else if @CCID=2
		begin
			select 'ADM_CostCenterTab' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_TabGridCustomize' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			select * from ADM_CostCenterTab with(nolock)
			select * from COM_TabGridCustomize with(nolock)
		end
		else if @CCID=3
		begin
			select 'ADM_DocBarcodeLayouts' TableName,1 HasIdentity,0 IgnoreFirstColumn
			select top 10 * from ADM_DocBarcodeLayouts with(nolock) where BarcodeLayoutID>@MaxID order by BarcodeLayoutID
		end
		else if @CCID=4
		begin
			insert into @Tbl
			select top 5 DocPrintLayoutID from ADM_DocPrintLayouts with(nolock) where DocPrintLayoutID>@MaxID order by DocPrintLayoutID
			
			select 'ADM_DocPrintLayouts' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_DocPrintLayoutsMap' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select E.* from ADM_DocPrintLayouts  E with(nolock) 
			inner join @Tbl T ON E.DocPrintLayoutID=T.ID
			order by T.ID
			
			select E.* from ADM_DocPrintLayoutsMap E with(nolock) 
			inner join @Tbl T ON E.DocPrintLayoutID=T.ID
			order by T.ID
		end
		else if @CCID=5
		begin
			select 'ADM_DocumentTypes' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'ADM_DocumentDef' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_DocumentViewDef' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_DocViewUserRoleMap' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_DocumentReportDef' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_DocumentReports' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_DocReportUserroleMap' TableName,1 HasIdentity,0 IgnoreFirstColumn union all ---
			select 'ADM_DocFunctions' TableName,1 HasIdentity,0 IgnoreFirstColumn					
			
			select E.* from ADM_DocumentTypes  E with(nolock) 
			--inner join @Tbl T ON E.DocumentTypeID=T.ID
			--order by T.ID
			
			select E.* from ADM_DocumentDef E with(nolock)
			--inner join @Tbl T ON E.DocumentTypeID=T.ID
			--order by T.ID
			
			select E.* from ADM_DocumentViewDef E with(nolock)
			select E.* from ADM_DocViewUserRoleMap E with(nolock)
			
			select E.* from ADM_DocumentReportDef E with(nolock)
			select E.* from ADM_DocumentReports E with(nolock)
			select E.* from ADM_DocReportUserroleMap E with(nolock)
			select E.* from ADM_DocFunctions E with(nolock)


		end
		else if @CCID=6
		begin
			select 'ADM_Users' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'PACT2C.dbo.ADM_Users' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'PACT2C.dbo.ADM_UserCompanyMap' TableName,1 HasIdentity,1 IgnoreFirstColumn
			union all
			select 'COM_CostCenterCostCenterMap' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_PRoles' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'COM_Groups' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			union all
			select 'ADM_UserRoleMap' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_UserRoleGroups' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select E.* from ADM_Users E with(nolock) where UserID>@MaxID
			select E.* from PACT2C.dbo.ADM_Users E with(nolock) where UserID>@ModDate
			select E.* from PACT2C.dbo.ADM_UserCompanyMap E with(nolock) 
				where UserID in (select E.UserID from PACT2C.dbo.ADM_Users E with(nolock) where UserID>@ModDate)
				and CompanyID IN (select CompanyID from PACT2C.dbo.ADM_Company with(nolock) where DBName=db_name())
			select E.* from COM_CostCenterCostCenterMap E with(nolock) where ParentCostCenterID=7 or CostCenterID=7
			select E.* from ADM_PRoles E with(nolock)
			select E.* from COM_Groups E with(nolock)
			select E.* from ADM_UserRoleMap E with(nolock)
			select E.* from ADM_UserRoleGroups E with(nolock)			
		end
		else if @CCID=7
		begin
			insert into @Tbl
			select top 30 FeatureID from ADM_Features with(nolock) where FeatureID>@MaxID order by FeatureID
			
			select 'ADM_Features' TableName,0 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_FeatureAction' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_FeatureActionRoleMap' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			union all
			select 'ADM_FeatureTypeValues' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select E.* from ADM_Features  E with(nolock) 
			inner join @Tbl T ON E.FeatureID=T.ID
			order by T.ID
			
			select E.* from ADM_FeatureAction E with(nolock)
			inner join @Tbl T ON E.FeatureID=T.ID
			order by T.ID
			
			select E.* from ADM_FeatureActionRoleMap E with(nolock)
			inner join (select E.FeatureActionID ID from ADM_FeatureAction E with(nolock)
			inner join @Tbl T ON E.FeatureID=T.ID) AS T ON E.FeatureActionID=T.ID
			order by T.ID
			
			select E.* from ADM_FeatureTypeValues E with(nolock)
			inner join @Tbl T ON E.FeatureID=T.ID
			order by T.ID
		end
		else if @CCID=8
		begin
			insert into @Tbl
			select GridViewID from ADM_GridView with(nolock) where GridViewID>@MaxID order by GridViewID
			
			select 'ADM_GridView' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_GridViewColumns' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			union all
			select 'ADM_GridContextMenu' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select E.* from ADM_GridView  E with(nolock) 
			inner join @Tbl T ON E.GridViewID=T.ID
			order by T.ID
			
			select E.* from ADM_GridViewColumns E with(nolock)
			inner join @Tbl T ON E.GridViewID=T.ID
			order by T.ID
			
			select E.* from ADM_GridContextMenu E with(nolock)
			inner join @Tbl T ON E.GridViewID=T.ID
			order by T.ID
		end
		else if @CCID=9
		begin
			select 'ADM_ListView' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_ListViewColumns' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select E.* from ADM_ListView E with(nolock)
			order by ListViewID
			
			select E.* from ADM_ListViewColumns E with(nolock)
			order by ListViewID
		end
		else if @CCID=10
		begin
			select 'ADM_QuickViewDefn' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_QuickViewDefnUserMap' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			union all
			select 'ADM_RibbonView' TableName,0 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_QueryDefn' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select E.* from ADM_QuickViewDefn E with(nolock) order by QuickViewID
			select E.* from ADM_QuickViewDefnUserMap E with(nolock)
			select E.* from ADM_RibbonView E with(nolock) order by RibbonViewID
			select E.* from ADM_QueryDefn E with(nolock)
		end
		else if @CCID=11
		begin
			insert into @Tbl
			select top 20 ReportID from ADM_RevenUReports with(nolock) where ReportID>@MaxID order by ReportID
			
			select 'ADM_RevenUReports' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_ReportsMap' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			union all
			select 'ADM_ReportsUserMap' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select E.* from ADM_RevenUReports E with(nolock) 
			inner join @Tbl T ON E.ReportID=T.ID
			order by T.ID
			
			select E.* from ADM_ReportsMap E with(nolock)
			inner join @Tbl T ON E.ParentReportID=T.ID
			order by T.ID
			
			select E.* from ADM_ReportsUserMap E with(nolock)
			inner join @Tbl T ON E.ReportID=T.ID
			order by T.ID
		end
		else if @CCID=12
		begin
			select 'COM_CCPricesDefn' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'COM_CCTaxesDefn' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'COM_CCPriceTaxCCDefn' TableName,0 HasIdentity,0 IgnoreFirstColumn
			
			select * from COM_CCPricesDefn with(nolock)
			select * from COM_CCTaxesDefn with(nolock)
			select * from COM_CCPriceTaxCCDefn with(nolock)
		end
		else if @CCID=13
		begin
			select 'COM_CCPrices' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			select top 1000 * from COM_CCPrices with(nolock) where PriceCCID>@MaxID order by PriceCCID
		end
		else if @CCID=14
		begin
			select 'COM_CCTaxes' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			select top 1000 * from COM_CCTaxes with(nolock) where CCTaxID>@MaxID order by CCTaxID
		end
		else if @CCID=15
		begin
			select 'ADM_GlobalPreferences' TableName,1 HasIdentity,1 IgnoreFirstColumn---
			union all
			select 'COM_CostCenterPreferences' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_FinancialYears' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			union all
			select 'ADM_HijriCalender' TableName,0 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'ADM_CrossDimension' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			if @CopyCall=1
				select * from ADM_GlobalPreferences with(nolock) where Name not in ('GSTVersion','VATVersion')
			else
				select * from ADM_GlobalPreferences with(nolock) where Name not in ('UseGlobalPrefForFileUploadPath','File Upload Path','ftpuserid','ftppassword','isSftp','ftpport','IsOffline','OnlineDataBase','OfflineGUID','GSTVersion','VATVersion')
				
			select * from COM_CostCenterPreferences with(nolock)
			select * from ADM_FinancialYears with(nolock)
			select * from ADM_HijriCalender with(nolock)
			select * from ADM_CrossDimension with(nolock)
		end
		else if @CCID=16
		begin
			select 'COM_LanguageResources' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			select top 2500 LanguageResourceID,ResourceID,ResourceName,LanguageID,LanguageName,ResourceData,'ADM' CreatedBy,1 CreatedDate,'G' [GUID] from COM_LanguageResources with(nolock) 
			where LanguageResourceID>@MaxID order by LanguageResourceID
		end
		else if @CCID=17
		begin
			select 'COM_UOM' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_Currency' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_ExchangeRates' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_PaymentModes' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'Com_CurrencyDenominations' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_Files' TableName,1 HasIdentity,0 IgnoreFirstColumn
			select * from COM_UOM with(nolock)
			select * from COM_Currency with(nolock)
			select * from COM_ExchangeRates with(nolock)
			select * from COM_PaymentModes with(nolock)
			select * from Com_CurrencyDenominations with(nolock)
			SELECT * FROM COM_Files E WITH(NOLOCK) WHERE FeatureID=12
		end
		else if @CCID=18
		begin
			select 'COM_BudgetDef' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_BudgetDefDims' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_BudgetAlloc' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_BudgetDimRelations' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select * from COM_BudgetDef with(nolock)
			select * from COM_BudgetDefDims with(nolock)
			select * from COM_BudgetAlloc with(nolock)
			select * from COM_BudgetDimRelations with(nolock)
		end
		else if @CCID=19
		begin
			select 'COM_LookupTypes' TableName,0 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_Lookup' TableName,1 HasIdentity,0 IgnoreFirstColumn
			select * from COM_LookupTypes with(nolock)
			select * from COM_Lookup with(nolock)
		end
		else if @CCID=20
		begin
			select 'ADM_DashBoard' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'ADM_DashBoardUserRoleMap' TableName,1 HasIdentity,1 IgnoreFirstColumn union all---
			select 'COM_Favourite' TableName,1 HasIdentity,1 IgnoreFirstColumn union all---

			select 'ADM_DocumentBudgets' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_WorkFlow' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_WorkFlowDef' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_PoleDisplay' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'ADM_PoleDisplayGrid' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_PoleDisplayRegisters' TableName,1 HasIdentity,0 IgnoreFirstColumn
			
			select * from ADM_DashBoard with(nolock)
			select * from ADM_DashBoardUserRoleMap with(nolock)
			select * from COM_Favourite with(nolock)
			
			select * from ADM_DocumentBudgets with(nolock)
			select * from COM_WorkFlow with(nolock)
			select * from COM_WorkFlowDef with(nolock)
			select * from ADM_PoleDisplay with(nolock)
			select * from ADM_PoleDisplayGrid with(nolock)
			select * from ADM_PoleDisplayRegisters with(nolock)
		end
		else if @CCID=21
		begin
			select 'COM_DocumentPreferences' TableName,1 HasIdentity,0 IgnoreFirstColumn --,1 InsertAllColumns
			select top 1000 * from COM_DocumentPreferences with(nolock) where DocumentPrefID>@MaxID order by DocumentPrefID
		end
		else if @CCID=22
		begin
			insert into @Tbl
			select top 10 DocumentLinkDefID from COM_DocumentLinkDef with(nolock) where DocumentLinkDefID>@MaxID order by DocumentLinkDefID
			
			select 'COM_DocumentLinkDef' TableName,1 HasIdentity,0 IgnoreFirstColumn
			union all
			select 'COM_DocumentLinkDetails' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select E.* from COM_DocumentLinkDef E with(nolock) 
			inner join @Tbl T ON E.DocumentLinkDefID=T.ID
			order by T.ID
			
			select E.* from COM_DocumentLinkDetails E with(nolock) 
			inner join @Tbl T ON E.DocumentLinkDefID=T.ID
			order by T.ID
		end
		else if @CCID=23
		begin
			select 'ADM_SchemesDiscounts' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'ADM_SchemeProducts' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'Acc_PaymentDiscountProfile' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'Acc_PaymentDiscountTerms' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_DocumentBudgets' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_DocumentDynamicMapping' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select * from ADM_SchemesDiscounts with(nolock)
			select * from ADM_SchemeProducts with(nolock)
			select * from Acc_PaymentDiscountProfile with(nolock) 
			select * from Acc_PaymentDiscountTerms with(nolock)
			
			select * from ADM_DocumentBudgets with(nolock)
			select * from COM_DocumentDynamicMapping with(nolock)
		end
		else if @CCID=24
		begin
			--select 'COM_CostCenterCodeDef' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_DocPrefix' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_CCParentCodeDef' TableName,1 HasIdentity,0 IgnoreFirstColumn
			
			--select * from COM_CostCenterCodeDef with(nolock)
			select * from COM_DocPrefix with(nolock)
			select * from COM_CCParentCodeDef with(nolock)
		end
		else if @CCID=25
		begin
			select 'COM_DimensionMappings' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_DimensionLinkDetails' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'Com_CopyDocumentDetails' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select * from COM_DimensionMappings with(nolock)
			select * from COM_DimensionLinkDetails with(nolock)
			select * from Com_CopyDocumentDetails with(nolock)
		end
		else if @CCID=26
		begin
			select 'COM_NotifTemplate' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_NotifTemplateAction' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_NotifTemplateUserMap' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_Schedules' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_CCSchedules' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			--select 'COM_SchEvents' TableName,0 HasIdentity,1 IgnoreFirstColumn union all
			select 'COM_UserSchedules' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			select * from COM_NotifTemplate with(nolock)
			select * from COM_NotifTemplateAction with(nolock)
			select * from COM_NotifTemplateUserMap with(nolock)
			
			select * from COM_Schedules with(nolock)
			select * from COM_CCSchedules with(nolock)
			select * from COM_UserSchedules with(nolock)
		end
		else if @CCID=27
		begin
			select 'ADM_BulkEditTemplate' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'ADM_PrintFormates' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'COM_DocumentBulkMapping' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'INV_MatrixDef' TableName,1 HasIdentity,0 IgnoreFirstColumn union all---
			select 'ADM_Assign' TableName,0 HasIdentity,0 IgnoreFirstColumn union all
			select 'COM_DocTempProductDef' TableName,1 HasIdentity,0 IgnoreFirstColumn union all
			select 'ACC_ReportTemplate' TableName,1 HasIdentity,0 IgnoreFirstColumn---
			
			
			select * from ADM_BulkEditTemplate with(nolock)
			select * from ADM_PrintFormates with(nolock)
			select * from COM_DocumentBulkMapping with(nolock)
			select * from INV_MatrixDef with(nolock)
			select * from ADM_Assign with(nolock)
			select * from COM_DocTempProductDef with(nolock)
			select * from ACC_ReportTemplate with(nolock)
		end
	end
	else if @Type=102 --CostCenterDef  - Modified Defn
	begin
		--ADM_FinancialYears
		--ADM_GlobalPreferences
		--ADM_QueryDefn
		--ADM_RevenUReports
		select @SQL='select top '+convert(nvarchar,ChunkSize)+' * from '+TableName+' with(nolock) where '+PrimaryKey+'<=@MaxID and ModifiedDate>@ModDate order by ModifiedDate'
		from ADM_SynSettings with(nolock) where ID=@CCID
		print(@SQL)
		EXEC sp_executesql @SQL,N'@MaxID INT,@ModDate float',@MaxID,@ModDate
		--,@ModDate float ,@ModDate
		
		--select top 1000 * from ADM_CostCenterDef with(nolock) where ModifiedDate>@ModDate and CostCenterColID<=@MaxID order by ModifiedDate
	end
	else if @Type=103 --CostCenterDef  - NEW
	begin
		--ADM_FinancialYears
		--ADM_GlobalPreferences
		--ADM_QueryDefn
		--ADM_RevenUReports
		select @SQL='select top '+convert(nvarchar,ChunkSize)+' * from '+TableName+' with(nolock) where '+PrimaryKey+'>@MaxID order by '+PrimaryKey
		from ADM_SynSettings with(nolock) where ID=@CCID
		print(@SQL)
		EXEC sp_executesql @SQL,N'@MaxID INT',@MaxID
	end
	else if @Type=104
	begin
		select max(ID) ID from PACT2C.dbo.ADM_Scripts with(nolock) where convert(int,replace(Version,'.',''))<=@CCID
	end
	else if @Type=105
	begin
		select top 1 * from PACT2C.dbo.ADM_Scripts with(nolock) where ID>@MaxID
	end
	else if @CCID=2--Account
	begin
		if @Type=1 --Offline
			insert into @Tbl
			select OffLineID from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID=2 and OnlineID=0 order by OffLineID desc
			--select AccountID from Acc_Accounts with(nolock) where AccountID<-10000 order by AccountID desc
		else if @Type=2--Online
			insert into @Tbl
			select TOP 20 AccountID from Acc_Accounts with(nolock) where AccountID>@MaxID order by AccountID
		else if @Type=3 --Online Modified
			insert into @Tbl
			select TOP 20 AccountID from Acc_Accounts with(nolock) where ModifiedDate>@ModDate and AccountID<=@MaxID order by ModifiedDate
			--select TOP 20 AccountID from Acc_Accounts with(nolock) where ModifiedDate>=@ModDate and AccountID!=@MaxID  order by ModifiedDate
		
		select 'ACC_Accounts' TableName,1 HasIdentity,0 IgnoreFirstColumn,'AccountID' [Key],NULL CostCenterKey
		union all
		select 'ACC_AccountsExtended',0,0,'AccountID' [Key],NULL CostCenterKey
		union all
		select 'COM_Notes',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_Files',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_CCCCDATA',1,1,'NodeID' [Key],'CostCenterID' CostCenterKey
		union all
		select 'COM_Address',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_Contacts',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_ContactsExtended',0,0,'ContactID' [Key],null CostCenterKey
		union all
		select 'COM_CostCenterCostCenterMap',1,1,'ParentNodeID' [Key],'ParentCostCenterID' CostCenterKey
		union all
		select 'COM_CostCenterCostCenterMap',1,1,'NodeID' [Key],'CostCenterID' CostCenterKey
		union all
		select 'Acc_CreditDebitAmount',1,1,'AccountID' [Key],NULL CostCenterKey
		
		select E.* from Acc_Accounts  E with(nolock) 
		inner join @Tbl T ON E.AccountID=T.ID
		order by AccountID
			
		select E.* from ACC_AccountsExtended E with(nolock) 
		inner join @Tbl T ON E.AccountID=T.ID
		order by T.ID
		
		--Getting Contacts
		--EXEC [spCom_GetFeatureWiseContacts] 2,@AccountID,2,1,1
		  
		--Getting Notes
		SELECT E.*
		FROM COM_Notes E WITH(NOLOCK) 
		inner join @Tbl T ON E.FeaturePK=T.ID
		WHERE FeatureID=2
		order by T.ID

		--Getting Files
		SELECT E.* FROM  COM_Files E WITH(NOLOCK) 
		inner join @Tbl T ON E.FeaturePK=T.ID
		WHERE FeatureID=2
		order by T.ID
		
		SELECT E.* FROM COM_CCCCDATA E WITH(NOLOCK) 
		inner join @Tbl T ON E.NodeID=T.ID
		WHERE CostCenterID=2
		order by T.ID
	
		--Getting ADDRESS 
		select E.* from COM_Address E WITH(NOLOCK) 
		inner join @Tbl T ON E.FeaturePK=T.ID
		WHERE FeatureID=2
				
		--Getting Contacts
		select E.* from COM_Contacts E WITH(NOLOCK) 
		inner join @Tbl T ON E.FeaturePK=T.ID
		WHERE FeatureID=2
		
		select E.* from COM_ContactsExtended E WITH(NOLOCK) 
		inner join COM_Contacts C WITH(NOLOCK) ON E.ContactID=C.ContactID
		inner join @Tbl T ON C.FeaturePK=T.ID
		WHERE FeatureID=2

		--Assign
		select E.* from COM_CostCenterCostCenterMap E WITH(NOLOCK) 
		inner join @Tbl T ON E.ParentNodeID=T.ID
		WHERE ParentCostCenterID=2
		
		--Map
		select E.* from COM_CostCenterCostCenterMap E WITH(NOLOCK) 
		inner join @Tbl T ON E.NodeID=T.ID
		WHERE CostCenterID=2
		
		select E.* from Acc_CreditDebitAmount E WITH(NOLOCK) 
		inner join @Tbl T ON E.AccountID=T.ID
	 
/*		--Getting Schemes
		SELECT a.[SchemeID],[SchemeName],[SchemeCode],a.[ProductID],c.ProductName,[SchemeTypeID],[SchemeTypeName]
		FROM  INV_Schemes a WITH(NOLOCK) 
		join INV_CostCenterSchemes b on a.SchemeID=b.SchemeID and b.CostCenterID=2 and b.NodeID=@AccountID
		join INV_Product c on a.ProductID=c.ProductID
		
		declare @rptid INT, @tempsql nvarchar(500)
		select @rptid=CONVERT(INT,value) from ADM_GlobalPreferences where Name='Report Template Dimension'
		if(@rptid>0)
		begin
			set @tempsql= 'select NodeID, Name, Code from '+(select tablename from ADM_Features  where FeatureID=@rptid)+'' 
			exec (@tempsql) 
			select TemplateNodeID , [AccountID],[DrNodeID],[CrNodeID],[CreatedBy],[CreatedDate],
			CONVERT(datetime, RTDate) AS [RTDate] from ACC_ReportTemplate where AccountID=@AccountID
			select a.accountid, a.accountcode, a.accountname,a.depth, a.lft, a.rgt, a.parentid, r.templatenodeid   from ACC_Accounts a
			left join  ACC_ReportTemplate r on r.accountid=a.accountid
			where a.IsGroup=1 order by lft
		end*/
	
	end
	else if @CCID=3 --Product
	begin
		if @Type=1 --Offline
			insert into @Tbl
			select OffLineID from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID=3 and OnlineID=0 order by OffLineID desc
		else if @Type=2--Online
			insert into @Tbl
			select TOP 20 ProductID from INV_Product with(nolock) where ProductID>@MaxID order by ProductID
		else if @Type=3 --Online Modified
			insert into @Tbl
			select TOP 20 ProductID from INV_Product with(nolock) where ModifiedDate>@ModDate and ProductID<=@MaxID order by ModifiedDate
		
		--select TOP 20 ModifiedDate,@ModDate,convert(datetime,ModifiedDate),convert(datetime,@ModDate),convert(datetime,42226.9424350694),convert(datetime,42226.9424350694)  
		--from INV_Product with(nolock) where ModifiedDate>@ModDate and ProductID<=@MaxID 
		
		select 'INV_Product' TableName,1 HasIdentity,0 IgnoreFirstColumn,'ProductID' [Key],NULL CostCenterKey
		union all
		select 'INV_ProductExtended',0,0,'ProductID' [Key],NULL CostCenterKey
		union all
		select 'COM_Notes',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_Files',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_CCCCDATA',1,1,'NodeID' [Key],'CostCenterID' CostCenterKey
		union all
		select 'COM_Contacts',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_ContactsExtended',0,0,'ContactID' [Key],null CostCenterKey
		union all
		select 'COM_CostCenterCostCenterMap',1,1,'ParentNodeID' [Key],'ParentCostCenterID' CostCenterKey
		union all
		select 'COM_CostCenterCostCenterMap',1,1,'NodeID' [Key],'CostCenterID' CostCenterKey
		union all
		select 'INV_ProductVendors',1,1,'ProductID' [Key],NULL CostCenterKey
		union all
		select 'INV_ProductBarcode',1,1,'ProductID' [Key],NULL CostCenterKey
		union all
		select 'INV_ProductSubstitutes',1,1,'ProductID' [Key],NULL CostCenterKey
		union all
		select 'INV_ProductBundles',1,1,'ParentProductID' [Key],NULL CostCenterKey
		union all
		select 'COM_HistoryDetails',1,1,'NodeID' [Key],'CostCenterID' CostCenterKey
		
		select E.* from INV_Product E with(nolock) 
		inner join @Tbl T ON E.ProductID=T.ID
		order by ProductID		
		
		select E.* from INV_ProductExtended E with(nolock) 
		inner join @Tbl T ON E.ProductID=T.ID
		order by T.ID
		
		--Getting Notes
		SELECT E.*
		FROM COM_Notes E WITH(NOLOCK) 
		inner join @Tbl T ON E.FeaturePK=T.ID
		WHERE FeatureID=3
		order by T.ID

		--Getting Files
		SELECT E.* FROM  COM_Files E WITH(NOLOCK) 
		inner join @Tbl T ON E.FeaturePK=T.ID
		WHERE FeatureID=3
		order by T.ID
		
		SELECT E.* FROM COM_CCCCDATA E WITH(NOLOCK) 
		inner join @Tbl T ON E.NodeID=T.ID
		WHERE CostCenterID=3
		order by T.ID
			
		--Getting Contacts
		select E.* from COM_Contacts E WITH(NOLOCK) 
		inner join @Tbl T ON E.FeaturePK=T.ID
		WHERE FeatureID=3
		
		select E.* from COM_ContactsExtended E WITH(NOLOCK) 
		inner join COM_Contacts C WITH(NOLOCK) ON E.ContactID=C.ContactID
		inner join @Tbl T ON C.FeaturePK=T.ID
		WHERE FeatureID=3

		--Assign
		select E.* from COM_CostCenterCostCenterMap E WITH(NOLOCK) 
		inner join @Tbl T ON E.ParentNodeID=T.ID
		WHERE ParentCostCenterID=3
		
		--Map
		select E.* from COM_CostCenterCostCenterMap E WITH(NOLOCK) 
		inner join @Tbl T ON E.NodeID=T.ID
		WHERE CostCenterID=3
		
		--Getting Vendors info
		SELECT V.* FROM INV_ProductVendors V WITH(NOLOCK) 
		inner join @Tbl T ON V.ProductID=T.ID
		
		SELECT B.* FROM inv_productbarcode B WITH(NOLOCK) 
		inner join @Tbl T ON B.ProductID=T.ID and B.UNITID=0
		
		--product substitutes
		SELECT E.* FROM INV_ProductSubstitutes E WITH(NOLOCK) 
		inner join @Tbl T ON E.ProductID=T.ID
		
		SELECT E.* FROM INV_ProductBundles E WITH(NOLOCK) 
		inner join @Tbl T ON E.ParentProductID=T.ID
		
		SELECT E.* FROM COM_HistoryDetails E WITH(NOLOCK) 
		inner join @Tbl T ON E.NodeID=T.ID
		where E.CostCenterID=3
		
/*		
		--Getting ProductSerialization
		SELECT * FROM INV_Product WITH(NOLOCK)    
	    WHERE ProductID=@ProductID AND [ProductTypeID]=2	
	    
	    
	    
*/
	end
	else if @CCID=16 --Batch
	begin
		if @Type=1 --Offline
			insert into @Tbl
			select OffLineID from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID=16 and OnlineID=0 order by OffLineID desc
		else if @Type=2--Online
			insert into @Tbl
			select TOP 20 BatchID from INV_Batches with(nolock) where BatchID>@MaxID order by BatchID
		else if @Type=3 --Online Modified
			insert into @Tbl
			select TOP 20 BatchID from INV_Batches with(nolock) where ModifiedDate>@ModDate and BatchID<=@MaxID order by ModifiedDate
		
		select 'INV_Batches' TableName,1 HasIdentity,0 IgnoreFirstColumn,'BatchID' [Key],NULL CostCenterKey
		
		select E.* from INV_Batches E with(nolock) 
		inner join @Tbl T ON E.BatchID=T.ID
		order by BatchID
	end
	else if @CCID>50000
	begin
		create table #TblIds(ID INT)
		declare @CCTable nvarchar(20)
		select @CCTable=TableName from adm_features with(nolock) where FeatureID=@CCID

		if @Type=1 --Offline
			set @SQL='select OffLineID from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID='+convert(nvarchar,@CCID)+' and OnlineID=0 order by OffLineID desc'
		else if @Type=2 --Online
			set @SQL='select TOP 20 NodeID from '+@CCTable+' with(nolock) where NodeID>'+convert(nvarchar,@MaxID)+' order by NodeID'
		else if @Type=3 --Online Modified
			set @SQL='select TOP 20 NodeID from '+@CCTable+' with(nolock) where ModifiedDate>@ModDate and NodeID<='+convert(nvarchar,@MaxID)+' order by ModifiedDate'
		
		--print(@SQL)
		insert into #TblIds
		exec sp_executesql @SQL,N'@ModDate float',@ModDate
		--exec(@SQL)
		
		select @CCTable TableName,1 HasIdentity,0 IgnoreFirstColumn,'NodeID' [Key],NULL CostCenterKey
		union all
		select 'COM_Notes',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_Files',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_CCCCDATA',1,1,'NodeID' [Key],'CostCenterID' CostCenterKey
		union all
		select 'COM_Address',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_Contacts',1,1,'FeaturePK' [Key],'FeatureID' CostCenterKey
		union all
		select 'COM_ContactsExtended',0,0,'ContactID' [Key],null CostCenterKey
		union all
		select 'COM_CostCenterCostCenterMap',1,1,'ParentNodeID' [Key],'ParentCostCenterID' CostCenterKey
		union all
		select 'COM_CostCenterCostCenterMap',1,1,'NodeID' [Key],'CostCenterID' CostCenterKey
		union all
		select 'com_docbridge',1,1,'NodeID' [Key],'CostCenterID' CostCenterKey

		set @SQL='select TOP 20 E.* from '+@CCTable+' E with(nolock) inner join #TblIds T on E.NodeID=T.ID order by E.NodeID'
		exec(@SQL)

		--Getting Notes
		SELECT  E.* FROM COM_Notes E WITH(NOLOCK) 
		inner join #TblIds T ON E.FeaturePK=T.ID
		WHERE FeatureID=@CCID
		order by T.ID

		--Getting Files
		SELECT E.* FROM  COM_Files E WITH(NOLOCK) 
		inner join #TblIds T ON E.FeaturePK=T.ID
		WHERE FeatureID=@CCID
		order by T.ID
		
		SELECT E.* FROM COM_CCCCDATA E WITH(NOLOCK) 
		inner join #TblIds T ON E.NodeID=T.ID
		WHERE CostCenterID=@CCID
		order by T.ID
	
		--Getting ADDRESS 
		select E.* from COM_Address E WITH(NOLOCK) 
		inner join #TblIds T ON E.FeaturePK=T.ID
		WHERE FeatureID=@CCID
				
		--Getting Contacts
		select E.* from COM_Contacts E WITH(NOLOCK) 
		inner join #TblIds T ON E.FeaturePK=T.ID
		WHERE FeatureID=@CCID
		
		select E.* from COM_ContactsExtended E WITH(NOLOCK) 
		inner join COM_Contacts C WITH(NOLOCK) ON E.ContactID=C.ContactID
		inner join #TblIds T ON C.FeaturePK=T.ID
		WHERE FeatureID=@CCID

		--Assign
		select E.* from COM_CostCenterCostCenterMap E WITH(NOLOCK) 
		inner join #TblIds T ON E.ParentNodeID=T.ID
		WHERE ParentCostCenterID=@CCID
		
		--Map
		select E.* from COM_CostCenterCostCenterMap E WITH(NOLOCK) 
		inner join #TblIds T ON E.NodeID=T.ID
		WHERE CostCenterID=@CCID and ParentCostCenterID!=@CCID --and ParentNodeID!=NodeID
		
		select E.* from com_docbridge E WITH(NOLOCK) 
		inner join #TblIds T ON E.NodeID=T.ID
		WHERE CostCenterID=@CCID
		
		--SELECT DISTINCT S.SubstituteGroupID,S.SubstituteGroupName,
 	--	P.ProductName, P.ProductID,P.ProductCode
		--FROM INV_ProductSubstitutes S WITH(NOLOCK)   
		--INNER JOIN INV_Product P WITH(NOLOCK) on S.ProductID=P.ProductID
		--WHERE S.SubstituteGroupID  IN (SELECT SubstituteGroupID FROM INV_ProductSubstitutes WHERE PRODUCTID in (@ProductID))
		--and S.ProductID<>@ProductID

		----Getting Vendors info
		--SELECT V.ProductVendorID,V.AccountID,V.Priority,V.LeadTime,A.AccountCode,A.AccountName,B.Barcode , V.MinOrderQty
		--FROM INV_ProductVendors V
		--INNER JOIN ACC_Accounts A ON A.AccountID=V.AccountID
		--left JOIN inv_productbarcode B ON V.AccountID=B.VenderID and B.ProductID=@ProductID and B.UNITID=0
		--WHERE V.ProductID=@ProductID
		
		DROP TABLE #TblIds
		
	end
	else if @CCID=40000
	begin
		declare @TblDocID as Table(ID INT,CostCenterID int,VoucherNo nvarchar(50))
		declare @TblAudit as Table(ID INT,ModDate float)
		if @Type=1
		begin
		
			/*insert into @Tbl
			select E.InvDocDetailsID from INV_DocDetails E with(nolock) 
			inner join COM_DocID D with(nolock) ON D.DocNo=E.VoucherNo and D.OfflineStatus=0 and D.ID<0
			
			insert into @TblDocID
			select E.DocID,CostCenterID,VoucherNo from INV_DocDetails E with(nolock) 
			inner join COM_DocID D with(nolock) ON D.DocNo=E.VoucherNo and D.OfflineStatus=0 and D.ID<0
			group by E.DocID,CostCenterID,VoucherNo*/
			
			insert into @Tbl
			select E.InvDocDetailsID from INV_DocDetails E with(nolock) 
			inner join COM_DocID D with(nolock) ON D.ID=E.DocID and D.OfflineStatus=0 and D.ID<0
			
			insert into @TblDocID
			select E.DocID,CostCenterID,VoucherNo from INV_DocDetails E with(nolock) 
			inner join COM_DocID D with(nolock) ON D.ID=E.DocID and D.OfflineStatus=0 and D.ID<0
			group by E.DocID,CostCenterID,VoucherNo
			
		
			select E.* from INV_DocDetails E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			order by DocAbbr,DocPrefix,DocNumber,InvDocDetailsID Desc
			
			select E.* from ACC_DocDetails E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from COM_DocCCData E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from COM_DocNumData E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from COM_DocTextData E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from COM_BillWise E with(nolock) inner join @TblDocID T ON T.VoucherNo=E.DocNo
			
			select E.* from COM_Approvals E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CCID and T.ID=E.CCNodeID
			
			select E.* from COM_Files E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.FeatureID and T.ID=E.FeaturePK
			
			select E.* from COM_Notes E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.FeatureID and T.ID=E.FeaturePK
			
			select E.* from COM_DocPrints E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.NodeID
			
			select E.* from INV_DocDetails_History_ATUser E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.DocType and T.ID=E.DocID					

			select E.* from COM_DocPayTerms E with(nolock) inner join @TblDocID T ON T.VoucherNo=E.VoucherNo
			
			select E.* from COM_PosPayModes E with(nolock) inner join @TblDocID T ON T.ID=E.DocID
			
			select E.* from COM_DocDenominations E with(nolock) inner join @TblDocID T ON T.ID=E.DocID
			
			--Address Data
			
			
			--AUDIT DATA
			insert into @TblAudit
			select InvDocDetailsID,ModifiedDate from INV_DocDetails_History E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.DocID
			select E.* from INV_DocDetails_History E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.DocID			
			select E.* from COM_DocCCData_History E with(nolock) inner join @TblAudit T ON T.ID=E.InvDocDetailsID and T.ModDate=E.ModifiedDate
			select E.* from COM_DocNumData_History E with(nolock) inner join @TblAudit T ON T.ID=E.InvDocDetailsID and T.ModDate=E.ModifiedDate
			select E.* from COM_DocTextData_History E with(nolock) inner join @TblAudit T ON T.ID=E.InvDocDetailsID and T.ModDate=E.ModifiedDate
		end
		else
		begin
		
			insert into @Tbl
			select E.AccDocDetailsID from ACC_DocDetails E with(nolock) 
			inner join COM_DocID D with(nolock) ON D.ID=E.DocID and D.OfflineStatus=0 and D.ID<0
			where InvDocDetailsID is null
			
			insert into @TblDocID
			select E.DocID,CostCenterID,VoucherNo from ACC_DocDetails E with(nolock)
			inner join COM_DocID D with(nolock) ON D.ID=E.DocID and D.OfflineStatus=0 and D.ID<0
			where InvDocDetailsID is null
			group by E.DocID,CostCenterID,VoucherNo

			select E.* from ACC_DocDetails E with(nolock) inner join @Tbl T ON T.ID=E.AccDocDetailsID
			order by DocAbbr,DocPrefix,DocNumber,AccDocDetailsID Desc
			
			select E.* from COM_DocCCData E with(nolock) inner join @Tbl T ON T.ID=E.AccDocDetailsID
			
			select E.* from COM_DocNumData E with(nolock) inner join @Tbl T ON T.ID=E.AccDocDetailsID
			
			select E.* from COM_DocTextData E with(nolock) inner join @Tbl T ON T.ID=E.AccDocDetailsID
			
			select E.* from COM_BillWise E with(nolock) inner join @TblDocID T ON T.VoucherNo=E.DocNo
			
			select E.* from COM_Approvals E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CCID and T.ID=E.CCNodeID
			
			select E.* from COM_Files E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.FeatureID and T.ID=E.FeaturePK
			
			select E.* from COM_Notes E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.FeatureID and T.ID=E.FeaturePK
			
			select E.* from COM_DocPrints E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.NodeID
			
			select E.* from ACC_DocDetails_History_ATUser E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.DocType and T.ID=E.DocID
			
			select E.* from COM_DocDenominations E with(nolock) inner join @TblDocID T ON T.ID=E.DocID
			--Address Data
			
			
			--AUDIT DATA
			insert into @TblAudit
			select AccDocDetailsID,ModifiedDate from ACC_DocDetails_History E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.DocID
			select E.* from ACC_DocDetails_History E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.DocID			
			select E.* from COM_DocCCData_History E with(nolock) inner join @TblAudit T ON T.ID=E.AccDocDetailsID and T.ModDate=E.ModifiedDate
			select E.* from COM_DocNumData_History E with(nolock) inner join @TblAudit T ON T.ID=E.AccDocDetailsID and T.ModDate=E.ModifiedDate
			select E.* from COM_DocTextData_History E with(nolock) inner join @TblAudit T ON T.ID=E.AccDocDetailsID and T.ModDate=E.ModifiedDate
		end
	end
	else if @CCID>40000 and @CCID<50000
	begin
		if @Type=1
		begin
			select 'COM_DocID' TableName,1 HasIdentity,0 IgnoreFirstColumn,'ID' [Key],NULL CostCenterKey
			union all
			select 'INV_DocDetails' TableName,1 HasIdentity,0 IgnoreFirstColumn,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'ACC_DocDetails',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocCCData',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocNumData',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocTextData',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_Approvals',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_Files',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_Notes',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocPayTerms',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_PosPayModes',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocDenominations',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'INV_BinDetails',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'INV_SerialStockProduct',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'INV_DocExtraDetails',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocQtyAdjustments',1,0,'InvDocDetailsID' [Key],NULL CostCenterKey
			
			
			if @CopyCall=0
				set @SQL='select top 5 E.DocID,CostCenterID,VoucherNo from INV_DocDetails E with(nolock) 
			where E.CostCenterID='+convert(nvarchar,@CCID)+' and E.DocID>'+convert(nvarchar,@MaxID)+'
			group by E.DocID,CostCenterID,VoucherNo
			order by E.DocID'
			else
				set @SQL='select top 5 E.DocID,CostCenterID,VoucherNo from INV_DocDetails E with(nolock) 
			join COM_DocCCData dcc with(nolock) on E.InvDocDetailsID=dcc.InvDocDetailsID
			where E.CostCenterID='+convert(nvarchar,@CCID)+' and E.DocID>'+convert(nvarchar,@MaxID)+' and dcc.dcCCNID2='+convert(nvarchar,@CopyCall)+'
			group by E.DocID,CostCenterID,VoucherNo
			order by E.DocID'
			
			insert into @TblDocID
			exec(@SQL)
			
			insert into @Tbl
			select E.InvDocDetailsID from INV_DocDetails E with(nolock) 
			join @TblDocID T on T.ID=E.DocID
			order by E.InvDocDetailsID
			
		
			select E.* from COM_DocID E with(nolock) inner join @TblDocID T ON T.ID=E.ID
			order by T.ID
			
			select E.* from INV_DocDetails E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			order by DocID,InvDocDetailsID
			
			select E.* from ACC_DocDetails E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from COM_DocCCData E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from COM_DocNumData E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from COM_DocTextData E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			/*select E.* from COM_BillWise E with(nolock) inner join @TblDocID T ON T.VoucherNo=E.DocNo*/
			
			select E.* from COM_Approvals E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CCID and T.ID=E.CCNodeID
			
			select E.* from COM_Files E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.FeatureID and T.ID=E.FeaturePK
			
			select E.* from COM_Notes E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.FeatureID and T.ID=E.FeaturePK
			
			/*select E.* from COM_DocPrints E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.NodeID
			
			select E.* from INV_DocDetails_History_ATUser E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.DocType and T.ID=E.DocID					*/

			select E.* from COM_DocPayTerms E with(nolock) inner join @TblDocID T ON T.VoucherNo=E.VoucherNo
			
			select E.* from COM_PosPayModes E with(nolock) inner join @TblDocID T ON T.ID=E.DocID
			
			select E.* from COM_DocDenominations E with(nolock) inner join @TblDocID T ON T.ID=E.DocID
			
			select E.* from INV_BinDetails E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from INV_SerialStockProduct E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from INV_DocExtraDetails E with(nolock) inner join @Tbl T ON T.ID=E.InvDocDetailsID
			
			select E.* from COM_DocQtyAdjustments E with(nolock) inner join @TblDocID T ON T.ID=E.DocID

			
			--AUDIT DATA
			/*insert into @TblAudit
			select InvDocDetailsID,ModifiedDate from INV_DocDetails_History E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.DocID
			select E.* from INV_DocDetails_History E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.DocID			
			select E.* from COM_DocCCData_History E with(nolock) inner join @TblAudit T ON T.ID=E.InvDocDetailsID and T.ModDate=E.ModifiedDate
			select E.* from COM_DocNumData_History E with(nolock) inner join @TblAudit T ON T.ID=E.InvDocDetailsID and T.ModDate=E.ModifiedDate
			select E.* from COM_DocTextData_History E with(nolock) inner join @TblAudit T ON T.ID=E.InvDocDetailsID and T.ModDate=E.ModifiedDate*/
		end
		else
		begin
			select 'COM_DocID' TableName,1 HasIdentity,0 IgnoreFirstColumn,'ID' [Key],NULL CostCenterKey
			union all
			select 'ACC_DocDetails',1,0,'AccDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocCCData',1,0,'AccDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocNumData',1,0,'AccDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocTextData',1,0,'AccDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_Approvals',1,0,'AccDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_Files',1,0,'AccDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_Notes',1,0,'AccDocDetailsID' [Key],NULL CostCenterKey
			union all
			select 'COM_DocDenominations',1,0,'AccDocDetailsID' [Key],NULL CostCenterKey
			
			if @CopyCall=0
				set @SQL='select top 5 E.DocID,CostCenterID,VoucherNo from ACC_DocDetails E with(nolock) 
			where E.CostCenterID='+convert(nvarchar,@CCID)+' and E.DocID>'+convert(nvarchar,@MaxID)+'
			group by E.DocID,CostCenterID,VoucherNo
			order by E.DocID'
			else
				set @SQL='select top 5 E.DocID,CostCenterID,VoucherNo from ACC_DocDetails E with(nolock) 
			join COM_DocCCData dcc with(nolock) on E.AccDocDetailsID=dcc.AccDocDetailsID
			where E.CostCenterID='+convert(nvarchar,@CCID)+' and E.DocID>'+convert(nvarchar,@MaxID)+' and dcc.dcCCNID2='+convert(nvarchar,@CopyCall)+'
			group by E.DocID,CostCenterID,VoucherNo
			order by E.DocID'
			
			insert into @TblDocID
			exec(@SQL)
			
			insert into @Tbl
			select E.AccDocDetailsID from ACC_DocDetails E with(nolock) 
			join @TblDocID T on T.ID=E.DocID
			order by E.AccDocDetailsID
		
			select E.* from COM_DocID E with(nolock) inner join @TblDocID T ON T.ID=E.ID
			order by T.ID
			
			select E.* from ACC_DocDetails E with(nolock) inner join @Tbl T ON T.ID=E.AccDocDetailsID
			order by DocID,AccDocDetailsID
			
			select E.* from COM_DocCCData E with(nolock) inner join @Tbl T ON T.ID=E.AccDocDetailsID
			
			select E.* from COM_DocNumData E with(nolock) inner join @Tbl T ON T.ID=E.AccDocDetailsID
			
			select E.* from COM_DocTextData E with(nolock) inner join @Tbl T ON T.ID=E.AccDocDetailsID
			
			/*select E.* from COM_BillWise E with(nolock) inner join @TblDocID T ON T.VoucherNo=E.DocNo*/
			
			select E.* from COM_Approvals E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CCID and T.ID=E.CCNodeID
			
			select E.* from COM_Files E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.FeatureID and T.ID=E.FeaturePK
			
			select E.* from COM_Notes E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.FeatureID and T.ID=E.FeaturePK
			
			/*select E.* from COM_DocPrints E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.NodeID
			
			select E.* from ACC_DocDetails_History_ATUser E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.DocType and T.ID=E.DocID*/
			
			select E.* from COM_DocDenominations E with(nolock) inner join @TblDocID T ON T.ID=E.DocID
			--Address Data
			
			/*
			--AUDIT DATA
			insert into @TblAudit
			select AccDocDetailsID,ModifiedDate from ACC_DocDetails_History E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.DocID
			select E.* from ACC_DocDetails_History E with(nolock) inner join @TblDocID T ON T.CostCenterID=E.CostCenterID and T.ID=E.DocID			
			select E.* from COM_DocCCData_History E with(nolock) inner join @TblAudit T ON T.ID=E.AccDocDetailsID and T.ModDate=E.ModifiedDate
			select E.* from COM_DocNumData_History E with(nolock) inner join @TblAudit T ON T.ID=E.AccDocDetailsID and T.ModDate=E.ModifiedDate
			select E.* from COM_DocTextData_History E with(nolock) inner join @TblAudit T ON T.ID=E.AccDocDetailsID and T.ModDate=E.ModifiedDate*/
		end
	end
	
	

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
