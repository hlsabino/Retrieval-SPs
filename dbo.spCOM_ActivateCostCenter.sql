USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_ActivateCostCenter]
	@FeatureID [int],
	@Name [nvarchar](300),
	@RibbonGroup [nvarchar](100),
	@Options [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		 
		--Declaration Section 
		DECLARE @HasAccess bit,@ColumnName VARCHAR(200),@SQL NVARCHAR(MAX),@GridViewID INT,@PrevName nvarchar(max),@ActualName nvarchar(max),@TableName varchar(100),@XML xml,@XML2 xml

		DECLARE @RTId INT,@RGId INT,@RCnt INT,@GResId INT
		
					
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,8,1)
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END	 
		
		SELECT Top 1 @ActualName=Isnull(NAME,'') FROM ADM_FEATURES WITH(NOLOCK) WHERE Name=@Name AND FeatureID>50000 AND FeatureID<60000 AND FeatureID<>@FeatureID
		IF Isnull(@ActualName,'')<>''
		BEGIN
			RAISERROR('-112',16,1)
		END

		SELECT @TableName=TableName,@PrevName=NAME FROM ADM_FEATURES WITH(NOLOCK) WHERE FeatureID=@FeatureID 

		IF(SELECT COUNT(*) FROM ADM_FEATURES WITH(NOLOCK) WHERE FeatureID=@FeatureID AND IsEnabled=0)>0
		BEGIN--ACTIVATE COSTCENTER TO MENU
			--CREATE COSCENTER IN MENU			
			EXEC spCOM_CreateCostCenterMenu @FeatureID,@Name,@UserName ,@UserID,@CompanyGUID
			
			UPDATE ADM_FEATURES SET NAME=@Name,IsEnabled=1,ISUSERDEFINED=0 WHERE FeatureID=@FeatureID
			
			insert into ADM_FeatureActionRoleMap(RoleID,FeatureActionID,Status,CreatedBy,CreatedDate)  
			SELECT 1,b.FeatureActionID,1,@UserName,CONVERT(float,getdate()) FROM ADM_FEATURES a WITH(NOLOCK)
			join adm_featureaction b WITH(NOLOCK) on a.featureid=b.featureid
			left join adm_featureactionRoleMap m WITH(NOLOCK) on m.featureactionid=b.featureactionid and m.roleid=1
			WHERE  a.featureid=@FeatureID  and FeatureActiontypeid<>213 and m.Roleid is null
			and b.Name<>'Dont Allow to Edit InActive Nodes'
		END
		ELSE--FOR UPDATING FEATURENAME
		BEGIN
			UPDATE ADM_FEATURES SET NAME=@Name WHERE FeatureID=@FeatureID
			
			UPDATE  [COM_LanguageResources] set ResourceName=replace(ResourceName,@PrevName,@Name)
									,ResourceData=replace(ResourceData,@PrevName,@Name) 
			WHERE    (RESOURCEID IN (SELECT FEATUREACTIONRESOURCEID FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE FEATUREID=@FeatureID)
				   OR RESOURCEID IN (SELECT ScreenResourceID FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE FEATUREID=@FeatureID)
				   OR RESOURCEID IN (SELECT ToolTipTitleResourceID FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE FEATUREID=@FeatureID)
				   OR RESOURCEID IN (SELECT GroupResourceID FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE FEATUREID=@FeatureID)
				   OR RESOURCEID IN (SELECT ToolTipDescResourceID FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE FEATUREID=@FeatureID))
			
			--update ADM_RIBBONVIEW set SCREENNAME=replace(SCREENNAME,@PrevName,@Name) WHERE FEATUREID=@FeatureID

			IF(@FeatureID=50001)
				SELECT @RTId=TabID,@RGId=GroupID,@GResId=GroupResourceID FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE FEATUREID=@FeatureID AND FeatureActionID=326
			ELSE
				SELECT @RTId=TabID,@RGId=GroupID,@GResId=GroupResourceID FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE FEATUREID=@FeatureID 

			SELECT @RCnt=COUNT(RibbonViewID) FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE TabID=@RTId AND GroupName=@RibbonGroup
			IF(@RCnt=0)
			BEGIN
				SELECT @RGId=MAX(GroupID)+1 FROM ADM_RIBBONVIEW WITH(NOLOCK)
				
				SELECT @GResId=MAX(ResourceID)+1 FROM COM_LanguageResources WITH(NOLOCK)
				INSERT INTO COM_LanguageResources
				SELECT @GResId,@RibbonGroup,1,'English',@RibbonGroup,NULL,NULL,NULL,NULL,NULL,NULL,'Others'
			END
			ELSE
			BEGIN
				SELECT @RGId=GroupID,@GResId=GroupResourceID FROM ADM_RIBBONVIEW WITH(NOLOCK) WHERE TabID=@RTId AND GroupName=@RibbonGroup
			END

			update ADM_RIBBONVIEW set SCREENNAME=replace(SCREENNAME,@PrevName,@Name),GroupID=@RGId,GroupName=@RibbonGroup,GroupResourceID=@GResId 
			WHERE FEATUREID=@FeatureID and TabID=7
			AND NOT (TabID=7 AND FeatureID=50001 AND FeatureActionID<>326)
		END
		
		UPDATE ADM_GridView SET ViewName=@Name WHERE FeatureID=@FeatureID AND CostCenterID=@FeatureID
		
		UPDATE [COM_LanguageResources] set ResourceName=replace(ResourceName,@PrevName,@Name)
								,ResourceData=replace(ResourceData,@PrevName,@Name) 
		WHERE RESOURCEID IN (SELECT RESOURCEID FROM ADM_FEATUREACTION WITH(NOLOCK) WHERE FEATUREID=@FeatureID)
		
		UPDATE [COM_LanguageResources] set ResourceData=@Name
		WHERE RESOURCEID in (SELECT RESOURCEID FROM ADM_FEATURES WITH(NOLOCK) WHERE FeatureID=@FeatureID)
		
		UPDATE [COM_LanguageResources] set ResourceData=@Name
		WHERE RESOURCEID in (SELECT RESOURCEID FROM ADM_GridView WITH(NOLOCK) WHERE FeatureID=@FeatureID)
		
		UPDATE ADM_ListView SET ListViewName=REPLACE(ListViewName,@PrevName,@Name) WHERE FeatureID=@FeatureID AND CostCenterID=@FeatureID
		SET @SQL='UPDATE '+@TableName+' SET CODE='''+@Name+''' , NAME='''+@Name+''' WHERE PARENTID=0 or nodeid=1'
		EXEC(@SQL)
		
		SET @XML=@Options
		
		update ADM_CostCenterTab 
		set IsVisible=isnull((SELECT X.value('@Assign','int') FROM @XML.nodes('/Options/Tabs') as Data(X)),1)
		where CostCenterID=@FeatureID and IsTabUserDefined=0 and CCTabName='Assign'
		
		update ADM_CostCenterTab 
		set IsVisible=isnull((SELECT X.value('@Contacts','int') FROM @XML.nodes('/Options/Tabs') as Data(X)),1)
		where CostCenterID=@FeatureID and IsTabUserDefined=0 and CCTabName='Contacts'
		
		update ADM_CostCenterTab 
		set IsVisible=isnull((SELECT X.value('@Address','int') FROM @XML.nodes('/Options/Tabs') as Data(X)),1)
		where CostCenterID=@FeatureID and IsTabUserDefined=0 and CCTabName='Address'
		
		update ADM_CostCenterTab 
		set IsVisible=isnull((SELECT X.value('@Notes','int') FROM @XML.nodes('/Options/Tabs') as Data(X)),1)
		where CostCenterID=@FeatureID and IsTabUserDefined=0 and CCTabName='Notes'
		
		update ADM_CostCenterTab 
		set IsVisible=isnull((SELECT X.value('@Attachments','int') FROM @XML.nodes('/Options/Tabs') as Data(X)),1)
		where CostCenterID=@FeatureID and IsTabUserDefined=0 and CCTabName='Attachments'
		
		update ADM_CostCenterTab 
		set IsVisible=isnull((SELECT X.value('@General','int') FROM @XML.nodes('/Options/Tabs') as Data(X)),1)
		where CostCenterID=@FeatureID and IsTabUserDefined=0 and CCTabName='General'
		
		UPDATE ADM_CostCenterDef SET CostCenterName=@Name
		WHERE CostCenterID=@FeatureID

		if(isnull((SELECT X.value('@Type','int') FROM @XML.nodes('/Options') as Data(X)),1)=1)
		begin
			update ADM_CostCenterDef 
			set IsVisible=0
			where CostCenterID=@FeatureID and SysColumnName IN ('CreditDays','CreditLimit','PurchaseAccount','SalesAccount'
			,'DebitDays','DebitLimit')
			
			select @SQL=Value from COM_CostCenterPreferences with(nolock) where CostCenterID=@FeatureID and Name='ImageDimensions'
			SET @XML2=@SQL
			set @SQL='RowSpan="'+isnull((SELECT X.value('@RowSpan','nvarchar(20)') FROM @XML2.nodes('/XML') as Data(X)),'1')+'"'
			set @SQL+=' ColumnSpan="'+isnull((SELECT X.value('@ColumnSpan','nvarchar(20)') FROM @XML2.nodes('/XML') as Data(X)),'1')+'"'			
			set @SQL+=' ShowImage="'+isnull((SELECT X.value('@Image','nvarchar(20)') FROM @XML.nodes('/Options/Tabs') as Data(X)),'1')+'"'
			set @SQL='<XML '+@SQL+'/>'			
			update COM_CostCenterPreferences
			set Value=@SQL
			where CostCenterID=@FeatureID and Name='ImageDimensions'
		end
		else
		begin
			update ADM_CostCenterDef 
			set IsVisible=1
			where CostCenterID=@FeatureID and SysColumnName IN ('CreditDays','CreditLimit','PurchaseAccount','SalesAccount'
			,'DebitDays','DebitLimit')
		end	

		IF(isnull((SELECT X.value('@Image','int') FROM @XML.nodes('/Options/Tabs') as Data(X)),1)=1 AND @FeatureID>50000)
		BEGIN
			declare @ColID bigint,@TabID BIGINT,@CostCenterName NVARCHAR(500),@SysTableName NVARCHAR(500),@RESOURCEMAX INT
			

			IF NOT EXISTS(SELECT * FROM ADM_CostCenterTab with(nolock) WHERE CostCenterID=@FeatureID AND CCTabName='IMAGE')
			BEGIN
				select @TabID=max(CCTabID)+1 from ADM_CostCenterTab WITH(NOLOCK)

				set identity_insert ADM_CostCenterTab ON
				EXEC	[spCOM_SetInsertResourceData] 'Image','Image',@CostCenterName,'ADMIN',1,@RESOURCEMAX output
				INSERT INTO [ADM_CostCenterTab]([CCTabID],[CCTabName],[CostCenterID],[ResourceID],[TabOrder],[IsVisible],[IsTabUserDefined],[GroupOrder],[GroupVisible])
				VALUES(@TabID,'Image',@FeatureID,@RESOURCEMAX,11,1,0,0,1)
				set identity_insert ADM_CostCenterTab OFF
			END

			IF NOT EXISTS(select [CostCenterID] from [adm_Costcenterdef] with(nolock) where CostCenterID=@FeatureID and [SysColumnName] IN('IMG_2','IMG_3','IMG_4','IMG_5'))
			BEGIN
				select @ColID=max(CostCenterColID)+1 from adm_costcenterdef WITH(NOLOCK)
				SELECT @CostCenterName=CostCenterName,@SysTableName=SysTableName FROM adm_costcenterdef WITH(NOLOCK) WHERE CostCenterID=@FeatureID AND SysColumnName='CODE'
				select @TabID=CCTabID from ADM_CostCenterTab WITH(NOLOCK) WHERE CostCenterID=@FeatureID AND CCTabName='IMAGE'

			set identity_insert adm_Costcenterdef on
			EXEC	[spCOM_SetInsertResourceData] 'HeaderImage1','Header Image 1',@CostCenterName,'ADMIN',1,@RESOURCEMAX output
			INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat])
			VALUES(@FeatureID,@ColID,@RESOURCEMAX,@CostCenterName,@SysTableName,'HeaderImage1','IMG_2',NULL,'IMAGE','IMAGE',NULL,NULL,0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,10,@TabID,NULL,0,0,NULL,1
			,NULL,'693E656C-CD0D-486D-AFAC-FC36CBFFAF0D','A5203D77-8DD2-499D-8BB7-9495333DC917',NULL,'Admin',4,NULL,NULL,0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL)

			EXEC	[spCOM_SetInsertResourceData] 'HeaderImage2','Header Image 2',@CostCenterName,'ADMIN',1,@RESOURCEMAX output
			INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat])
			VALUES
			(@FeatureID,@ColID+1,@RESOURCEMAX,@CostCenterName,@SysTableName,'HeaderImage2','IMG_3',NULL,'IMAGE','IMAGE',NULL,NULL,0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,11,@TabID,NULL,0,1,NULL,1
			,NULL,'693E656C-CD0D-486D-AFAC-FC36CBFFAF0D','A5203D77-8DD2-499D-8BB7-9495333DC917',NULL,'Admin',4,NULL,NULL,0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL)

			EXEC	[spCOM_SetInsertResourceData] 'FooterImage1','Footer Image 1',@CostCenterName,'ADMIN',1,@RESOURCEMAX output
			INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat])
			VALUES
			(@FeatureID,@ColID+2,@RESOURCEMAX,@CostCenterName,@SysTableName,'FooterImage1','IMG_4',NULL,'IMAGE','IMAGE',NULL,NULL,0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,10,@TabID,NULL,1,0,NULL,1
			,NULL,'693E656C-CD0D-486D-AFAC-FC36CBFFAF0D','A5203D77-8DD2-499D-8BB7-9495333DC917',NULL,'Admin',4,NULL,NULL,0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL)

			EXEC	[spCOM_SetInsertResourceData] 'FooterImage2','Footer Image 2',@CostCenterName,'ADMIN',1,@RESOURCEMAX output
			INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat])
			VALUES
			(@FeatureID,@ColID+3,@RESOURCEMAX,@CostCenterName,@SysTableName,'FooterImage2','IMG_5',NULL,'IMAGE','IMAGE',NULL,NULL,0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,11,@TabID,NULL,1,1,NULL,1
			,NULL,'693E656C-CD0D-486D-AFAC-FC36CBFFAF0D','A5203D77-8DD2-499D-8BB7-9495333DC917',NULL,'Admin',4,NULL,NULL,0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL)

			set identity_insert adm_Costcenterdef off
		END

		END

		update ADM_CostCenterTab 
		set IsVisible=isnull((SELECT X.value('@Image','int') FROM @XML.nodes('/Options/Tabs') as Data(X)),1)
		where CostCenterID=@FeatureID and IsTabUserDefined=0 and CCTabName='Image'
		
		--Add Column		
		SET @SQL='
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_CCCCData''))
		BEGIN
			ALTER TABLE [COM_CCCCData] ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT default(1) not null			
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_CCCCDataHistory''))
		BEGIN
			ALTER TABLE [COM_CCCCDataHistory] ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT default(1) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_DocCCData''))
		BEGIN
			ALTER TABLE [COM_DocCCData] ADD [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT default(1) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_DocCCData_History''))
		BEGIN
			ALTER TABLE [COM_DocCCData_History] ADD [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_CCPrices''))
		BEGIN
			ALTER TABLE COM_CCPrices ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(0) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_CCTaxes''))
		BEGIN
			ALTER TABLE COM_CCTaxes ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(0) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_BudgetAlloc''))
		BEGIN
			ALTER TABLE COM_BudgetAlloc ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_BudgetAlloc_history''))
		BEGIN
			ALTER TABLE COM_BudgetAlloc_history ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''ADM_SchemesDiscounts''))
		BEGIN
			ALTER TABLE ADM_SchemesDiscounts ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_Billwise''))
		BEGIN
			ALTER TABLE COM_Billwise ADD [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_BillwiseHistory''))
		BEGIN
			ALTER TABLE COM_BillwiseHistory ADD [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_DimensionMappings''))
		BEGIN
			ALTER TABLE COM_DimensionMappings add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT not null default(1)
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''ADM_DimensionWiseLockData''))
		BEGIN
			ALTER TABLE ADM_DimensionWiseLockData add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_ChequeReturn''))
		BEGIN
			ALTER TABLE COM_ChequeReturn add [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_LCBills''))
		BEGIN
			ALTER TABLE COM_LCBills add [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_Activities''))
		BEGIN
			ALTER TABLE CRM_Activities add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_Address''))
		BEGIN
			ALTER TABLE COM_Address add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
		END
		IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_Address_History''))
		BEGIN
			ALTER TABLE COM_Address_History add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
		END
		'		
		
		IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='PAY_EmpDetail')
		BEGIN
			SET @SQL=@SQL+' IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''PAY_EmpDetail''))
							BEGIN
								ALTER TABLE PAY_EmpDetail add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''PAY_EmpDetail_History''))
							BEGIN
								ALTER TABLE PAY_EmpDetail_History add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							'
		END	
		
		IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='CRM_Campaigns')
		BEGIN
			SET @SQL=@SQL+' IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_CampaignApprovals''))
							BEGIN
								ALTER TABLE CRM_CampaignApprovals add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_CampaignDemoKit''))
							BEGIN
								ALTER TABLE CRM_CampaignDemoKit add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_CampaignInvites''))
							BEGIN
								ALTER TABLE CRM_CampaignInvites add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_CampaignOrganization''))
							BEGIN
								ALTER TABLE CRM_CampaignOrganization add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_CampaignProducts''))
							BEGIN
								ALTER TABLE CRM_CampaignProducts add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_CampaignResponse''))
							BEGIN
								ALTER TABLE CRM_CampaignResponse add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_CampaignSpeakers''))
							BEGIN
								ALTER TABLE CRM_CampaignSpeakers add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_Feedback''))
							BEGIN
								ALTER TABLE CRM_Feedback add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							IF NOT EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''CRM_ProductMapping''))
							BEGIN
								ALTER TABLE CRM_ProductMapping add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
							END
							'
		END	
		
	DECLARE @Dt float
		SET @Dt=convert(float,getdate())--Setting Current Date
		--Inserts Multiple Attachments      
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')      
  BEGIN      
   SET @XML=@AttachmentsXML      
      
   INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,      
   FileExtension,FileDescription,IsProductImage,AllowInPrint,FeatureID,FeaturePK,      
   GUID,CreatedBy,CreatedDate,RowSeqNo,ColName,IsDefaultImage,ValidTill,RefNo,IsSign,status,DocNo,Remarks,Type,RefNum)      
   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),      
   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),X.value('@AllowInPrint','bit'),@FeatureID,-500,      
   X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt,X.value('@RowSeqNo','int'),X.value('@ColName','NVARCHAR(100)'),X.value('@IsDefaultImage','smallint')      
   ,convert(float,X.value('@Validtill','Datetime')),X.value('@RefNo','NVARCHAR(max)'),ISNULL(X.value('@IsSign','bit'),0),X.value('@stat','int')
   ,X.value('@DocNo','NVARCHAR(max)'),X.value('@Remarks','NVARCHAR(max)'),X.value('@Type','INT'),X.value('@RefNo','NVARCHAR(max)')
   FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)        
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'      
      
   --If Action is MODIFY then update Attachments      
   UPDATE COM_Files      
   SET FilePath=X.value('@FilePath','NVARCHAR(500)'),      
    ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),      
    RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),      
    FileExtension=X.value('@FileExtension','NVARCHAR(50)'),      
    FileDescription=X.value('@FileDescription','NVARCHAR(500)'),      
    IsProductImage=X.value('@IsProductImage','bit'),
    AllowInPrint=X.value('@AllowInPrint','bit'),
	IsDefaultImage=X.value('@IsDefaultImage','smallint'),
    GUID=X.value('@GUID','NVARCHAR(50)'),      
    ModifiedBy=@UserName,      
    ModifiedDate=@Dt   
    ,ValidTill=convert(float,X.value('@Validtill','Datetime'))   
	,IsSign=ISNULL(X.value('@IsSign','bit'),0)
	,status=X.value('@stat','int')
	,DocNo=X.value('@DocNo','NVARCHAR(max)')
	,Remarks=X.value('@Remarks','NVARCHAR(max)')
	,Type=X.value('@Type','INT')
	,RefNum=X.value('@RefNo','NVARCHAR(max)')
   FROM COM_Files C  with(nolock)      
   INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X)        
   ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID      
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'      
      
   --If Action is DELETE then delete Attachments      
   DELETE FROM COM_Files      
   WHERE FileID IN(SELECT X.value('@AttachmentID','INT')      
    FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)      
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE') 
    
    	print @AttachmentsXML
		UPDATE COM_Files
		SET ValidTill=convert(float,X.value('@Validtill','Datetime'))						
			,RefNum=X.value('@RefNo','NVARCHAR(max)'),Remarks=X.value('@Remarks','NVARCHAR(max)')
			,RowSeqNo=X.value('@RowSeqNo','int')
			,status=X.value('@stat','int')
		FROM COM_Files C with(nolock)
		INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X) 	
		ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFYText'
		     
  END  


	--EXEC sp_executesql @SQL
	--SET @SQL='
	--	IF EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_CCCCData''))
	--	BEGIN
	--		ALTER TABLE [COM_CCCCData] WITH CHECK ADD  CONSTRAINT [FK_COM_CCCCData_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] FOREIGN KEY([CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+']) REFERENCES [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] ([NodeID])
	--		ALTER TABLE [COM_CCCCData] CHECK CONSTRAINT [FK_COM_CCCCData_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+']
	--	END
	--	IF EXISTS(SELECT 1 FROM Sys.Columns WHERE Name=N''CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+''' AND Object_ID=Object_ID(N''COM_DocCCData''))
	--	BEGIN
	--		ALTER TABLE [COM_DocCCData] WITH CHECK ADD  CONSTRAINT [FK_COM_DocCCData_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] FOREIGN KEY([dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+']) REFERENCES [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] ([NodeID])
	--		ALTER TABLE [COM_DocCCData] CHECK CONSTRAINT [FK_COM_DocCCData_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+']
	--	END'
	--	EXEC sp_executesql @SQL
		
		--select * from ADM_CostCenterDef where CostCenterID=@FeatureID
	--	select * from ADM_CostCenterTab where CostCenterID=@FeatureID and IsTabUserDefined=0 
  
DECLARE @FTableName varchar(100);  
DECLARE @UpdateSql varchar(100); 
	 SELECT @FTableName=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@FeatureID  
    if ISNULL(col_length(@FTableName,'WorkFlowID'),0)=0  
    Begin  
	   set @UpdateSql=''  
	   set @UpdateSql='Alter Table '+ @FTableName+' Add WorkFlowID int NULL'  
	   exec (@UpdateSql)   
  End  
    if ISNULL(col_length(@FTableName,'WorkFlowLevel'),0)=0  
    Begin   
	   set @UpdateSql=''  
	   set @UpdateSql='Alter Table  '+ @FTableName+' Add WorkFlowLevel int NULL'   
	   PRINT @UpdateSql  
	   exec (@UpdateSql)   
    End   
			
COMMIT TRANSACTION
SELECT * FROM ADM_FEATURES WITH(NOLOCK) WHERE FeatureID=@FeatureID       
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;  
RETURN 1  
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM ADM_COStCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID=31    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
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
