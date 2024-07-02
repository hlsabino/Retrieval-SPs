USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SpADM_AddColumn]
	@CostCenterID [int],
	@ColumnCostCenterID [int] = 0,
	@ColumnName [nvarchar](32) = '',
	@CostCenterColID [int] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN


	declare @DbIndex INT,@colsql NVARCHAR(max),@tablename NVARCHAR(50),@CCTableName  NVARCHAR(50)
	DECLARE @FNAME NVARCHAR(500),@RESDATA NVARCHAR(500),@ResID INT

	SELECT @FNAME=Name,@CCTableName=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@ColumnCostCenterID
	SELECT @ResID=MAX([ResourceID])+1 FROM [com_languageresources] WITH(NOLOCK)
			
	if(@ColumnCostCenterID>50000)
	BEGIN
		set @ColumnName='CCNID'++convert(nvarchar,(@ColumnCostCenterID-50000))
		INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
		VALUES (@ResID, @ColumnName,1,'English',@ColumnName ,'')
		INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
		VALUES (@ResID, @ColumnName,2,'Arabic', @ColumnName+'_AR','')
		if @CostCenterID=110
		begin
			set @tablename='COM_ADDRESS'
			INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate
			,[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[IsUnique],[IsnoTab])
			SELECT @CostCenterID,@ResID,'ADDRESS',@tablename,@ColumnName,@ColumnName,NULL,'LISTBOX','LISTBOX','','',0,0,1,1,0,1,0,0,@ColumnCostCenterID,1,NULL,0,NULL,0,
			NULL,NULL,0,0,NULL,1,NULL,'COMPANYGUID',NEWID(),NULL,'ADMIN',4,NULL,NULL,1,@ColumnCostCenterID,0,1,@CCTableName,'NodeID',(select TOP 1 CostCenterColID from adm_costcenterdef with(nolock) where costcenterid=@ColumnCostCenterID and syscolumnname='NAME'),0,0
			FROM ADM_Features F WITH(NOLOCK) 			
			WHERE FeatureID=@CostCenterID 
			SET @CostCenterColID=SCOPE_IDENTITY()	
			
			if not exists (select Name from sys.columns where Name=@ColumnName and object_id=object_id(@tablename))
			begin
				set @colsql='alter table '+@tablename+' add '+@ColumnName+' INT not null default(1)'
				exec(@colsql)
				set @colsql='alter table '+@tablename+'_History add '+@ColumnName+' INT not null default(1)'
				exec(@colsql)
			end
		end
		else
		begin
			INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate
			,[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[IsUnique],[IsnoTab])
			SELECT @CostCenterID,@ResID,Name,'COM_CCCCData',@ColumnName,@ColumnName,NULL,'LISTBOX','LISTBOX','','',0,0,1,1,0,1,0,0,@ColumnCostCenterID,1,NULL,0,NULL,0,
			NULL,NULL,0,0,NULL,1,NULL,'COMPANYGUID',NEWID(),NULL,'ADMIN',4,NULL,NULL,1,@ColumnCostCenterID,0,1,@CCTableName,'NodeID',(select TOP 1 CostCenterColID from adm_costcenterdef with(nolock) where costcenterid=@ColumnCostCenterID and syscolumnname='NAME'),0,0
			FROM ADM_Features F WITH(NOLOCK) 			
			WHERE FeatureID=@CostCenterID 
			SET @CostCenterColID=SCOPE_IDENTITY()
		end
	END
	ELSE
	BEGIN
			
		SET @DbIndex=1		
		WHILE (1=1)
		BEGIN
			IF EXISTS (SELECT * FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME LIKE '%Alpha'+CONVERT(NVARCHAR,@DbIndex))
				SET @DbIndex=@DbIndex+1
			ELSE
				BREAK
		END
		
		if (@ColumnName is null or @ColumnName='')
			set @ColumnName='Alpha'+convert(nvarchar,@DbIndex)

		if(@CostCenterID=2)
		BEGIN
			set @tablename='ACC_AccountsExtended'
			set @ColumnName='ac'+@ColumnName	
		END	
		else  if(@CostCenterID=3)
		BEGIN
			set @tablename='INV_ProductExtended'	
			set @ColumnName='pt'+@ColumnName		
		END	
		else if(@CostCenterID=92)
			set @tablename='REN_PropertyExtended'
		else    if(@CostCenterID=93)
			set @tablename='REN_UnitsExtended'
		else  if(@CostCenterID=94)
			set @tablename='REN_TenantExtended'
		else if(@CostCenterID in (95,104))
			set @tablename='REN_ContractExtended'
		else  if(@CostCenterID in(103,129))
			set @tablename='REN_QuotationExtended'
		else  if(@CostCenterID=83)
		BEGIN
			set @tablename='CRM_CustomerExtended'	
			set @ColumnName='cu'+@ColumnName		
		END	
		else  if(@CostCenterID=86)
		BEGIN
			set @tablename='CRM_LeadsExtended'	
			set @ColumnName='LD'+@ColumnName		
		END	
		else  if(@CostCenterID=88)
		BEGIN
			set @tablename='CRM_CampaignsExtended'	
			set @ColumnName='ca'+@ColumnName		
		END	
		else  if(@CostCenterID=89)
		BEGIN
			set @tablename='CRM_OpportunitiesExtended'	
			set @ColumnName='op'+@ColumnName		
		END	
		else  if(@CostCenterID=65)
		BEGIN
			set @tablename='COM_ContactsExtended'	
			set @ColumnName='ac'+@ColumnName		
		END	
		else  if(@CostCenterID >50000)	
		begin			  					
			select @tablename=TableName from adm_features with(nolock) where featureid=@CostCenterID
			set @ColumnName='cc'+@ColumnName	
		end
					
		if not exists(SELECT * FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME=@ColumnName)
		begin	
			select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)

			INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
			VALUES (@ResID, @ColumnName,1,'English', @ColumnName,'')
			INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
			VALUES (@ResID, @ColumnName,2,'Arabic', @ColumnName,'')
			
			INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
			SELECT @CostCenterID,@ResID,Name,@tablename,@ColumnName,@ColumnName,NULL,'TEXT','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,49,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL
			FROM ADM_features with(nolock) WHERE FeatureID=@CostCenterID
			SET @CostCenterColID=SCOPE_IDENTITY()
		END
		else
		begin
			SELECT @CostCenterColID=CostCenterColID FROM ADM_CostCenterDef with(nolock) 
			WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME=@ColumnName
		end
				
		if not exists (select Name from sys.columns where Name=@ColumnName and object_id=object_id(@tablename))
		begin
			set @colsql='alter table '+@tablename+' add '+@ColumnName+' nvarchar(max)'
			exec(@colsql)
			
			if exists(select name from sys.tables where name=@tablename+'_History')
			BEGIN
				set @colsql='alter table '+@tablename+'_History add '+@ColumnName+' nvarchar(max)'
				exec(@colsql)
			END	
			else if exists(select name from sys.tables where name=@tablename+'History')
			BEGIN
				set @colsql='alter table '+@tablename+'History add '+@ColumnName+' nvarchar(max)'
				exec(@colsql)
			END	
		end
	END		
END
GO
