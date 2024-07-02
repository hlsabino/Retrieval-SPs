USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetOnlineStorePreferences]
	@mode [int],
	@PrefXML [nvarchar](max) = '',
	@Xml [nvarchar](max) = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
      
	--Declaration Section    
	DECLARE @DATA XML,@Sno int,@Type int,@Rows int,@Height Float,@Header nvarchar(max),@Cols int,@i int,@cnt int,@Val nvarchar(max),@oldVal nvarchar(max),@CCID  int,@TabID bigint,@FeatName nvarchar(max),@Row int,@col int
	declare @sql nvarchar(max),@TblName nvarchar(200),@COLID BIGINT,@RID BIGINT,@COLUMNNAME nvarchar(max)
	
	
	
	
	if(@mode=1)
	BEGIN  
		SET @DATA=@PrefXML
		
		
		
		
		 select @Val=X.value('@Value','Nvarchar(max)') from  @DATA.nodes('/XML/Row') as DATA(X)   
		 where X.value('@Name','Nvarchar(max)')='OnlineLevel1Dim'
		
		if (ISNUMERIC(@Val)=1 and @Val>50000 and @Val!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]='OnlineLevel1Dim'))    
		BEGIN
			select @oldVal=[Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]='OnlineLevel1Dim'
			if(ISNUMERIC(@oldVal)=1 and convert(int,@oldVal)>50000)
			begin
				 select 'Level1 Dimension Not Allowed To Change' ErrorMessage, -512 ErrorNumber
				 
				 ROLLBACK TRANSACTION    
				 SET NOCOUNT OFF      
				 RETURN -999  
			 end
			
			set @CCID=@Val

			select @TblName=TableName,@FeatName=Name from Adm_Features with(nolock) where FeatureID=@CCID

			select @TabID=CCTabID from ADM_CostCenterTab with(nolock) where CostCenterID=@CCID and CCTabName='General'
			
			SELECT @RID=MAX(RESOURCEID) FROM COM_LanguageResources with(nolock)			
			SELECT @COLID=MAX(CostCenterColID) FROM ADM_CostCenterDef with(nolock)
			
			select @Row=max(RowNo) from ADM_CostCenterDef with(nolock) where CostCenterID=@CCID and Sectionid=@TabID
			
			select @col=max(ColumnNo) from ADM_CostCenterDef with(nolock) where CostCenterID=@CCID and Sectionid=@TabID and RowNo=@Row

			
			set identity_insert adm_Costcenterdef on	
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END	 
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Short Description'
			
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ccAlpha501',@COLUMNNAME,NULL,'TEXT','TEXTAREA','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID',newid(),NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
				
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Full Description'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ccAlpha502',@COLUMNNAME,NULL,'TEXT','TEXTAREA','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Badge Text'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ccAlpha503',@COLUMNNAME,NULL,'TEXT','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Badge Style'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ccAlpha504',@COLUMNNAME,NULL,'COLOR','COLOR','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Publish'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ccAlpha505',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Show on home page'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ccAlpha506',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Include in Top menu'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ccAlpha507',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)

		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Default View Mode'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ccAlpha508',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','Grid;List',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
	
	
	
		
			set identity_insert adm_Costcenterdef off
			
			set @sql='ALTER table '+@TblName+' add ccAlpha501 nvarchar(max),ccAlpha502 nvarchar(max),ccAlpha503 nvarchar(max),ccAlpha504 nvarchar(max),ccAlpha505 nvarchar(max),ccAlpha506 nvarchar(max),ccAlpha507 nvarchar(max),ccAlpha508 nvarchar(max)'
			
			exec(@sql)
		END	
		
		if not exists(select * from sys.columns where object_id=object_id('Inv_productExtended') and name='ptAlpha501')
		BEGIN
			
			set @CCID=3

			select @FeatName=Name from Adm_Features with(nolock) where FeatureID=@CCID
			
			set @TblName='INV_ProductExtended'

			EXEC [spCOM_SetInsertResourceData] 'OnlineStore','OnlineStore','OnlineStore',1,1,@RID OUTPUT    

			SELECT @Row = ISNULL(MAX(TABORDER),0) +1 FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID = @CCID
		
			INSERT INTO ADM_CostCenterTab(CCTabName,CostCenterID,ResourceID,TabOrder,IsVisible,IsTabUserDefined, GroupOrder,GroupVisible)
			VALUES ('OnlineStore',@CCID,@RID, @Row,1, 1, @Row,1)
	
			set @TabID=SCOPE_IDENTITY()
			
			
			SELECT @RID=MAX(RESOURCEID) FROM COM_LanguageResources with(nolock)			
			SELECT @COLID=MAX(CostCenterColID) FROM ADM_CostCenterDef with(nolock)
			
			set @Row=0
			set @col=0
			
			set identity_insert adm_Costcenterdef on	
			
			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Short Description'
			
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha501',@COLUMNNAME,NULL,'TEXTAREA','TEXTAREA','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID',newid(),NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
				
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Full Description'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha502',@COLUMNNAME,NULL,'TEXTAREA','TEXTAREA','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Badge Text'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha503',@COLUMNNAME,NULL,'TEXT','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Badge Style'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha504',@COLUMNNAME,NULL,'COLOR','COLOR','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Publish'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha505',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='SKU'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha506',@COLUMNNAME,NULL,'TEXTAREA','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
	
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='GTIN'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha507',@COLUMNNAME,NULL,'TEXTAREA','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
	
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Manufactureres Part Number'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha508',@COLUMNNAME,NULL,'TEXT','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Customs Tariff Number'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha509',@COLUMNNAME,NULL,'TEXT','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
	
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Require other products'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha510',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Auto add Mandatory linked Products'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha511',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Available start date'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha512',@COLUMNNAME,NULL,'DATE','DATE','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Available end date'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha513',@COLUMNNAME,NULL,'DATE','DATE','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
		
			EXEC [spCOM_SetInsertResourceData] 'Online Pricing','Online Pricing','Online Pricing',1,1,@RID OUTPUT    

			SELECT @Row = ISNULL(MAX(TABORDER),0) +1 FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID = @CCID
		
			INSERT INTO ADM_CostCenterTab(CCTabName,CostCenterID,ResourceID,TabOrder,IsVisible,IsTabUserDefined, GroupOrder,GroupVisible)
			VALUES ('Online Pricing',@CCID,@RID, @Row,1, 1, @Row,1)
	
			set @TabID=SCOPE_IDENTITY()
			
			set @Row=0
			set @col=0
			
			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Price'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha514',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Discount'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha515',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Discounted Price'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha516',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)

			set @col=@col+1
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Disable buy button'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha517',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Disable wishlish button'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha518',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Available for pre-order'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha519',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Call for price'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha520',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			
			EXEC [spCOM_SetInsertResourceData] 'Shipping','Shipping','Shipping',1,1,@RID OUTPUT    

			SELECT @Row = ISNULL(MAX(TABORDER),0) +1 FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID = @CCID
		
			INSERT INTO ADM_CostCenterTab(CCTabName,CostCenterID,ResourceID,TabOrder,IsVisible,IsTabUserDefined, GroupOrder,GroupVisible)
			VALUES ('Shipping',@CCID,@RID, @Row,1, 1, @Row,1)
	
			set @TabID=SCOPE_IDENTITY()
			
			set @Row=0
			set @col=0
				
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Shipping enabled'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha521',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Free Shipping'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha522',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Ship separately'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha523',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Delivery days'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha528',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)

			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Weight'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha524',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)

			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Length'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha525',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)

			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Width'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha526',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Height'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha527',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)

			EXEC [spCOM_SetInsertResourceData] 'Online Inventory','Online Inventory','Online Inventory',1,1,@RID OUTPUT    

			SELECT @Row = ISNULL(MAX(TABORDER),0) +1 FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID = @CCID
		
			INSERT INTO ADM_CostCenterTab(CCTabName,CostCenterID,ResourceID,TabOrder,IsVisible,IsTabUserDefined, GroupOrder,GroupVisible)
			VALUES ('Online Inventory',@CCID,@RID, @Row,1, 1, @Row,1)
	
			set @TabID=SCOPE_IDENTITY()
			
			set @Row=0
			set @col=0
			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Current Stock'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha529',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Display Stock Quantity'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha530',@COLUMNNAME,NULL,'COMBOBOX','COMBOBOX','','YES;NO',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Minimun cart qty'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha531',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Maximun cart qty'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha532',@COLUMNNAME,NULL,'NUMERIC','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			
			set identity_insert adm_Costcenterdef off
			
			set @sql='ALTER table '+@TblName+' add ptAlpha501 nvarchar(max),ptAlpha502 nvarchar(max),ptAlpha503 nvarchar(max),ptAlpha504 nvarchar(max),ptAlpha505 nvarchar(max),ptAlpha506 nvarchar(max),ptAlpha507 nvarchar(max),ptAlpha508 nvarchar(max),ptAlpha509 nvarchar(max),ptAlpha510 nvarchar(max)
												  ,ptAlpha511 nvarchar(max),ptAlpha512 nvarchar(max),ptAlpha513 nvarchar(max),ptAlpha514 nvarchar(max),ptAlpha515 nvarchar(max),ptAlpha516 nvarchar(max),ptAlpha517 nvarchar(max),ptAlpha518 nvarchar(max),ptAlpha519 nvarchar(max),ptAlpha520 nvarchar(max)
												  ,ptAlpha521 nvarchar(max),ptAlpha522 nvarchar(max),ptAlpha523 nvarchar(max),ptAlpha524 nvarchar(max),ptAlpha525 nvarchar(max),ptAlpha526 nvarchar(max),ptAlpha527 nvarchar(max),ptAlpha528 nvarchar(max),ptAlpha529 nvarchar(max),ptAlpha530 nvarchar(max),ptAlpha531 nvarchar(max),ptAlpha532 nvarchar(max)'
			
			exec(@sql)
		END	

		if not exists(select * from sys.columns where object_id=object_id('Inv_productExtended') and name='ptAlpha533')
		BEGIN
			
			update ADM_CostCenterTab
			set IsVisible=1
			where CostCenterID=3 and CCTabName='Specifications'
			
			set @CCID=3

			select @FeatName=Name from Adm_Features with(nolock) where FeatureID=@CCID
			
			set @TblName='INV_ProductExtended'
			select @TabID=CCTabID from ADM_CostCenterTab WITH(NOLOCK) where CCTabName='OnlineStore' and costcenterid=3
			
			SELECT @RID=MAX(RESOURCEID) FROM COM_LanguageResources with(nolock)			
			SELECT @COLID=MAX(CostCenterColID) FROM ADM_CostCenterDef with(nolock)
			
			
			select @Row=max(RowNo) from ADM_CostCenterDef with(nolock) where CostCenterID=@CCID and Sectionid=@TabID
			
			select @col=max(ColumnNo) from ADM_CostCenterDef with(nolock) where CostCenterID=@CCID and Sectionid=@TabID and RowNo=@Row
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END	
						
			set identity_insert adm_Costcenterdef on	
			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Search ON'
			
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])

			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha533',@COLUMNNAME,NULL,'TEXTAREA','TEXTAREA','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'OnlineStore',@Row,@col,1,1,NULL,'CompanyGUID',newid(),NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			set identity_insert adm_Costcenterdef off
			
			set @sql='ALTER table '+@TblName+' add ptAlpha533 nvarchar(max)'
			
			exec(@sql)
				
		END

		if not exists(select * from sys.columns where object_id=object_id('Inv_productExtended') and name='ptAlpha534')
		BEGIN
			set @CCID=3

			select @FeatName=Name from Adm_Features with(nolock) where FeatureID=@CCID
			
			set @TblName='INV_ProductExtended'
			select @TabID=CCTabID from ADM_CostCenterTab WITH(NOLOCK) where CCTabName='OnlineStore' and costcenterid=3
			
			SELECT @RID=MAX(RESOURCEID) FROM COM_LanguageResources with(nolock)			
			SELECT @COLID=MAX(CostCenterColID) FROM ADM_CostCenterDef with(nolock)
			
			
			select @Row=max(RowNo) from ADM_CostCenterDef with(nolock) where CostCenterID=@CCID and Sectionid=@TabID
			
			select @col=max(ColumnNo) from ADM_CostCenterDef with(nolock) where CostCenterID=@CCID and Sectionid=@TabID and RowNo=@Row
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END	
						
			set identity_insert adm_Costcenterdef on	
			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Badge Text 1'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha534',@COLUMNNAME,NULL,'TEXT','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Badge Style 1'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha535',@COLUMNNAME,NULL,'COLOR','COLOR','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
			
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END
			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Badge Text 2'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha536',@COLUMNNAME,NULL,'TEXT','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set @col=@col+1
			if(@col>3)
			BEGIN
				set @col=0
				set @Row=@Row+1
			END			
			set @COLID=@COLID+1
			set @RID=@RID+1
			set @COLUMNNAME='Badge Style 2'
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
			VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
			
			INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
			VALUES(@CCID,@COLID,@RID,@FeatName,@TblName,'ptAlpha537',@COLUMNNAME,NULL,'COLOR','COLOR','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,@TabID,'General',@Row,@col,1,1,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
		
			set identity_insert adm_Costcenterdef off
			
			set @sql='ALTER table '+@TblName+' add ptAlpha534 nvarchar(max),ptAlpha535 nvarchar(max),ptAlpha536 nvarchar(max),ptAlpha537 nvarchar(max)'
			
			exec(@sql)
				
		END
		
		set @Val=''
		set @oldVal=''
		 select @Val=X.value('@Value','Nvarchar(max)') from  @DATA.nodes('/XML/Row') as DATA(X)   
		 where X.value('@Name','Nvarchar(max)')='OnlineSearchFields'
		
		 select @oldVal=[Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]='OnlineSearchFields'
		if(@Val<>'' and @oldVal<>@Val)
		BEGIN
			 select @Val=X.value('@Value','Nvarchar(max)') from  @DATA.nodes('/XML/Row') as DATA(X)   
			where X.value('@Name','Nvarchar(max)')='OnlineSearchFieldsQuery'
		
				set @sql= N'update INV_ProductExtended
				set ptAlpha533=ser
				from (select p.Productid id,'+@Val+' ser from INV_Product p WITH(NOLOCK)
				join INV_ProductExtended e WITH(NOLOCK) on p.Productid=e.Productid
				) as t
				where Productid=id'
				exec(@sql)
				
			IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[TRG_SetOnlineSearchField]'))
				DROP TRIGGER [dbo].TRG_SetOnlineSearchField
			set @sql= N' 
			CREATE TRIGGER [dbo].TRG_SetOnlineSearchField on INV_ProductExtended
			after update
			as
			BEGIN
				declare @productID BIGINT
				select @productID=productID from inserted
				
				update INV_ProductExtended
				set ptAlpha533=ser
				from (select p.Productid id,'+@Val+' ser from INV_Product p WITH(NOLOCK)
				join INV_ProductExtended e WITH(NOLOCK) on p.Productid=e.Productid
				where p.Productid=@Productid ) as t
				where Productid=id
			END'	
			exec(@sql)

			
		END
		
		
		 update a
		 set Value=X.value('@Value','Nvarchar(max)')
		 from ADM_GlobalPreferences a
		 join @DATA.nodes('/XML/Row') as DATA(X)   on a.Name=X.value('@Name','Nvarchar(max)')
		 
		 delete from ADM_OnlineProfile
		 
		declare @tab table(id int identity(1,1),Sno int,Type int,Rows int,Height Float,Header nvarchar(max),Cols int,dataxml nvarchar(max))
		SET @DATA=@Xml
		insert into @tab
		SELECT  X.value('@Sno','INT'),isnull(X.value('@Type','INT'),1),X.value('@Rows','INT'),X.value('@Height','INT')
		,X.value('@Header','Nvarchar(max)'),X.value('@Cols','int'), CONVERT(NVARCHAR(MAX),X.query('SubProd'))
		FROM @DATA.nodes('/XML/Row') as DATA(X)    
						
		set @i=0
		select @cnt=count(id) from @tab
		WHILE(@i<@cnt)
		BEGIN
			set @i=@i+1
			select @Sno =Sno ,@Type=Type,@Rows =Rows ,@Height =Height ,@Header =Header ,@Cols=Cols,@DATA=dataxml from @tab where id=@i
			
			
			INSERT INTO ADM_OnlineProfile(Sno ,Type ,Rows ,Height ,Header ,Cols,DisplayOrder,CCID,NodeID,Text,FileName,ActualFileName,CompanyGUID,GUID,CreatedBy,CreatedDate)
			SELECT  @Sno ,@Type ,@Rows ,@Height ,@Header ,@Cols,
			isnull(X.value('@DisplayOrder','INT'),1),X.value('@CCID','INT'),X.value('@NodeID','BIGINT')
			,X.value('@Text','Nvarchar(max)'),X.value('@FileName','Nvarchar(max)'),X.value('@ActualFileName','Nvarchar(max)'),@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate())
			FROM @DATA.nodes('/SubProd/Row') as DATA(X)    
			
			
		END
		
	END
	else if(@mode=2)
	BEGIN 
		select * from ADM_OnlineProfile WITH(NOLOCK)		
	END
	
--ROLLBACK TRANSACTION
COMMIT TRANSACTION

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID       
SET NOCOUNT OFF;      
RETURN 1      
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT * FROM ADM_GlobalPreferences WITH(NOLOCK)     
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
