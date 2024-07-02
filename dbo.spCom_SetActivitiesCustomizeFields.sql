USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_SetActivitiesCustomizeFields]
	@ccid [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
 
declare @I int, @CNT INT ,@RID BIGINT, @COLID BIGINT,@COLUMNNAME NVARCHAR(300), 
@ParentCCID int,@ParentCCDefaultCCID int,@ParentCCSysNAme nvarchar(300)
SET @ParentCCID=50001
SELECT @RID=MAX(RESOURCEID) FROM COM_LanguageResources WHERE ResourceID>500000
SELECT @COLID=MAX(CostCenterColID) FROM ADM_CostCenterDef WHERE CostCenterColID>500000
SET @I=1
SET @CNT=50
WHILE @I<=@CNT
BEGIN 

 
	set @COLID=@COLID+1
	set @RID=@RID+1
	  
	SET @COLUMNNAME='Alpha'+Convert(nvarchar,@I) 
	set @COLID=@COLID+1
	set @RID=@RID+1
	INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,'df',NULL,'ADMIN',4.071672172287809e+004,NULL,NULL,NULL) 
	set identity_insert adm_Costcenterdef on
	INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
	VALUES(144,@COLID,@RID,'Activities','CRM_Activities',@COLUMNNAME,@COLUMNNAME,NULL,'TEXT',NULL,'','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,87,NULL,NULL,NULL,NULL,0,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4.074156179903550e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
	set identity_insert adm_Costcenterdef off
	
	set @I=@I+1 
end 

SET @I=1
SET @CNT=50
set @COLUMNNAME=''
SELECT @RID=MAX(RESOURCEID) FROM COM_LanguageResources WHERE ResourceID>500000
SELECT @COLID=MAX(CostCenterColID) FROM ADM_CostCenterDef WHERE CostCenterColID>500000
WHILE @I<=@CNT
BEGIN 


	set @COLID=@COLID+1
	set @RID=@RID+1
	SET @COLUMNNAME='CCNID'+Convert(nvarchar,@I) 
	SELECT @ParentCCDefaultCCID=ParentCCDefaultColID,@ParentCCSysNAme=ParentCostCenterSysName 
FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50001  and syscolumnname=@COLUMNNAME

	INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,'df',NULL,'ADMIN',4.071672172287809e+004,NULL,NULL,NULL) 
	set identity_insert adm_Costcenterdef on
	INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],
	[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
	VALUES(144,@COLID,@RID,'Activities','CRM_Activities',@COLUMNNAME,@COLUMNNAME,NULL,'TEXT',NULL,'','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,NULL,87,NULL,NULL,NULL,NULL,0,NULL,'CompanyGUID','D536EA3F-93FE-4DF4-A8A6-99C20F096EC8',NULL,'ADMIN',4.074156179903550e+004,NULL,NULL,NULL,1,@ParentCCID,0,1,@ParentCCSysNAme,'NodeID',@ParentCCDefaultCCID,NULL,@ccid,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
	set identity_insert adm_Costcenterdef off
	 
	
	set @I=@I+1
	SET @ParentCCID=@ParentCCID+1
end 


COMMIT TRANSACTION    
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
	SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine  
	FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH   
GO
