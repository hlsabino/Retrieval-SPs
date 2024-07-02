USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SPInsertDocumentatCostCenterDef]
	@CostCenterId [int] = 0,
	@COSTCENTERNAME [nvarchar](300) = NULL,
	@DocumentType [int] = 0,
	@UserName [nvarchar](300)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
 DECLARE @sec int,@i int,@COUNT int,@TableName nvarchar(300),@ColumnName nvarchar(300),@RESOURCEMAX INT,@Table varchar(max),@CreatedDt float
Declare @ISUserDefinedCOl bit,@CCID INT,@CostCenterColID INT,@RID INT,@IsColumnInUse bit
set @CreatedDt=convert(float,getdate()) 

			set @CCID=(SELECT TOP 1 COSTCENTERID FROM ADM_DOCUMENTTYPES WHERE  DOCUMENTTYPE=@DocumentType)
			--Inserting feature actions to the costcenter--  
			EXEC spCOM_SetCostCenterLanguageData 'Create',@COSTCENTERNAME,@UserName,@RESOURCEMAX output --IINSERT INTO RESOURCE TABLE
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy,GridShortCut)    
			VALUES('Create',@CostCenterId,@RESOURCEMAX,1,1,1,@CreatedDt,@UserName,'Ctrl + N')   

			EXEC spCOM_SetCostCenterLanguageData 'Read',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Read',@CostCenterId,@RESOURCEMAX,2,1,1,@CreatedDt,@UserName) 
 
			EXEC spCOM_SetCostCenterLanguageData 'Edit',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy,GridShortCut)    
			VALUES('Edit',@CostCenterId,@RESOURCEMAX,3,1,1,@CreatedDt,@UserName,'Ctrl + E')  			
		 
			EXEC spCOM_SetCostCenterLanguageData 'Delete',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy,GridShortCut)    
			VALUES('Delete',@CostCenterId,@RESOURCEMAX,4,1,1,@CreatedDt,@UserName,'Ctrl + D') 			
 
			EXEC spCOM_SetCostCenterLanguageData 'Print',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Print',@CostCenterId,@RESOURCEMAX,5,1,1,@CreatedDt,@UserName) 				
 
			EXEC spCOM_SetCostCenterLanguageData 'Copy',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Copy',@CostCenterId,@RESOURCEMAX,6,1,1,@CreatedDt,@UserName) 
	 
			EXEC spCOM_SetCostCenterLanguageData 'Recur',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Recur',@CostCenterId,@RESOURCEMAX,7,1,1,@CreatedDt,@UserName) 				
		 
			EXEC spCOM_SetCostCenterLanguageData 'Notes',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Notes',@CostCenterId,@RESOURCEMAX,8,1,1,@CreatedDt,@UserName) 
		 
			EXEC spCOM_SetCostCenterLanguageData 'Attach',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Attach',@CostCenterId,@RESOURCEMAX,9,1,1,@CreatedDt,@UserName) 				


			EXEC spCOM_SetCostCenterLanguageData 'Customize',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Customize',@CostCenterId,@RESOURCEMAX,10,1,1,@CreatedDt,@UserName) 

			EXEC spCOM_SetCostCenterLanguageData 'Save&Print',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Save&Print',@CostCenterId,@RESOURCEMAX,11,1,1,@CreatedDt,@UserName) 		
			
			EXEC spCOM_SetCostCenterLanguageData 'Email',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Email',@CostCenterId,@RESOURCEMAX,47,1,1,@CreatedDt,@UserName) 				

			EXEC spCOM_SetCostCenterLanguageData 'SMS',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('SMS',@CostCenterId,@RESOURCEMAX,48,1,1,@CreatedDt,@UserName) 				

			EXEC spCOM_SetCostCenterLanguageData 'PriceChart',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('PriceChart',@CostCenterId,@RESOURCEMAX,142,1,1,@CreatedDt,@UserName) 				

			EXEC spCOM_SetCostCenterLanguageData 'Suspend',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Suspend',@CostCenterId,@RESOURCEMAX,141,1,1,@CreatedDt,@UserName) 				
		
		-------
			EXEC spCOM_SetCostCenterLanguageData 'JV',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('JV',@CostCenterId,@RESOURCEMAX,516,1,1,@CreatedDt,@UserName) 

			EXEC spCOM_SetCostCenterLanguageData 'Draft',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Draft',@CostCenterId,@RESOURCEMAX,517,1,1,@CreatedDt,@UserName)

			EXEC spCOM_SetCostCenterLanguageData 'AssignVPT',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('AssignVPT',@CostCenterId,@RESOURCEMAX,675,1,1,@CreatedDt,@UserName)

			EXEC spCOM_SetCostCenterLanguageData 'ContinuousPrint',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('ContinuousPrint',@CostCenterId,@RESOURCEMAX,514,1,1,@CreatedDt,@UserName)

			EXEC spCOM_SetCostCenterLanguageData 'AssignUsers',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('AssignUsers',@CostCenterId,@RESOURCEMAX,515,1,1,@CreatedDt,@UserName)

			EXEC spCOM_SetCostCenterLanguageData 'HoldDoc',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('HoldDoc',@CostCenterId,@RESOURCEMAX,518,1,1,@CreatedDt,@UserName)

		-------

			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Revise',@CostCenterId,81477,146,1,1,@CreatedDt,@UserName) 				
			
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Export',@CostCenterId,NULL,148,1,1,@CreatedDt,@UserName) 				
			
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Post Billwise',@CostCenterId,NULL,173,1,1,@CreatedDt,@UserName) 				
			
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Edit Rejected Documents',@CostCenterId,NULL,174,1,1,@CreatedDt,@UserName) 				
			
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Post Cancelled Documents',@CostCenterId,NULL,175,1,1,@CreatedDt,@UserName) 				
			
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Edit Printed Documents',@CostCenterId,NULL,190,1,1,@CreatedDt,@UserName) 				
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Print/Export Approved',72790,@CostCenterId,204,1,NULL,NULL,1,4003,'ADMIN')
				
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Print/Export Un-Approved',72791,@CostCenterId,205,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Print/Export Rejected',72793,@CostCenterId,207,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Approve',72792,@CostCenterId,206,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Import',72794,@CostCenterId,218,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Edit Approved Docs',NULL,@CostCenterId,433,1,NULL,NULL,1,4003,'ADMIN')

			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Edit Posted Docs',NULL,@CostCenterId,401,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Skip Document Number',NULL,@CostCenterId,671,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Do not allow past dated transaction',NULL,@CostCenterId,672,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Do not allow future dated transaction',NULL,@CostCenterId,673,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Duplicate',NULL,@CostCenterId,674,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Next',NULL,@CostCenterId,501,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Previous',NULL,@CostCenterId,502,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('LoadDocument',NULL,@CostCenterId,503,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('History',NULL,@CostCenterId,504,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('DocumentHistory',NULL,@CostCenterId,505,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('ReviseHistory',NULL,@CostCenterId,506,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Withdraw',NULL,@CostCenterId,462,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('ReEvaluate',NULL,@CostCenterId,509,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('ReEvaluatePriceChart',NULL,@CostCenterId,510,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('ReEvaluateTaxChart',NULL,@CostCenterId,511,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('Only Assigned Documents',NULL,@CostCenterId,221,1,NULL,NULL,1,4003,'ADMIN')
			
			INSERT INTO [adm_featureaction] ([Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES('User-Wise DocumentsDocuments',NULL,@CostCenterId,137,1,NULL,NULL,1,4003,'ADMIN')

	
			if(@DocumentType in(1,2,4,25,26,27,34))
			BEGIN
					INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
					VALUES('Save&Barcode',@CostCenterId,NULL,116,1,1,@CreatedDt,@UserName) 
					
					INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
					VALUES('BarcodePrint',@CostCenterId,NULL,117,1,1,@CreatedDt,@UserName)					
			END
			
			 INSERT INTO [ADM_FeatureActionRoleMap]([RoleID],[FeatureActionID],[Status],[CreatedBy],[CreatedDate])
			 SELECT 1,[FeatureActionID],1,@UserName,@CreatedDt FROM ADM_FeatureAction WITH(NOLOCK) 
			 WHERE FEATUREID=@CostCenterId and FeatureActionTypeID not in(673,672,221,137)
			

CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),COLID INT,SYSCOLUMN NVARCHAR(300),RID INT)
INSERT INTO #TBLTEMP
	SELECT COSTCENTERCOLID,SysTableName,ResourceID FROM adm_costCenterDef WHERE costCenteriD =@CCID
SELECT @COUNT=COUNT(*) FROM #TBLTEMP
set @i=1
while(@i<=@COUNT)
begin
		SELECT @ColumnName=SysColumnName,@ISUserDefinedCOl=IsColumnUserDefined FROM adm_costCenterDef WHERE 
		COSTCENTERCOLID=(SELECT COLID FROM #TBLTEMP WHERE ID=@i)
		 SELECT @RID=RID FROM #TBLTEMP WHERE ID=@i
		
			if(@ColumnName like 'dcCalcNumFC%')
			begin
				select @RESOURCEMAX=ResourceID from ADM_CostCenterDef where CostCenterID=@CostCenterId and SysColumnName='dcNum'+replace(@ColumnName,'dcCalcNumFC','')
			end
			else if(@ColumnName like 'dcCalcNum%')
			begin
				select @RESOURCEMAX=ResourceID from ADM_CostCenterDef where CostCenterID=@CostCenterId and SysColumnName='dcNum'+replace(@ColumnName,'dcCalcNum','')
			end
			else if(@ColumnName like 'dcCurrID%')
			begin
				select @RESOURCEMAX=ResourceID from ADM_CostCenterDef where CostCenterID=@CostCenterId and SysColumnName='dcNum'+replace(@ColumnName,'dcCurrID','')
			end
			else if(@ColumnName like 'dcExchRT%')
			begin
				select @RESOURCEMAX=ResourceID from ADM_CostCenterDef where CostCenterID=@CostCenterId and SysColumnName='dcNum'+replace(@ColumnName,'dcExchRT','')
			end
			else 
			begin 
				if(@ISUserDefinedCOl=0)
					select @ColumnName=ResourceData from COM_LanguageResources where ResourceID=@RID and LanguageID=1
				EXEC spCOM_SetCostCenterLanguageData @ColumnName,@CostCenterName,@UserName,@RESOURCEMAX output
			end
			
			if(@ISUserDefinedCOl=0)
				set @IsColumnInUse=1
			else
				set @IsColumnInUse=0	
			--Insert Name Code definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(IsColumnInUse,CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ColumnDataType,ResourceID,SectionID,SectionName,SectionSeqNumber,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,ColumnCCListViewTypeID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate,RowNo,ColumnNo,ColumnSpan,TextFormat,UIwidth,IsForeignKey,ParentCostCenterID,ParentCostCenterColID,IsValidReportBuilderCol,ParentCostCenterSysName,ParentCostCenterColSysName,ParentCCDefaultColID)    
			SELECT @IsColumnInUse,@CostCenterId,@COSTCENTERNAME,SysTableName,case when IsColumnUserDefined=1 then SysColumnName else
			UserColumnName end,SysColumnName,UserColumnType,ColumnDataType,@RESOURCEMAX,SectionID,SectionName,SectionSeqNumber,ColumnOrder,1,IsColumnUserDefined,ColumnCostCenterID,ColumnCCListViewTypeID,IsMandatory,IsEditable,CompanyGUID,newid(),@UserName,@CreatedDt,RowNo,ColumnNo,ColumnSpan,TextFormat,UIwidth,IsForeignKey,ParentCostCenterID,ParentCostCenterColID,IsValidReportBuilderCol,ParentCostCenterSysName,ParentCostCenterColSysName,ParentCCDefaultColID FROM ADM_CostCenterDef
			WHERE COSTCENTERCOLID=(SELECT COLID FROM #TBLTEMP WHERE ID=@i)
				
			set @CostCenterColID=@@IDENTITY
			
			if(@ISUserDefinedCOl=0)
			begin
				 	
						if exists( select DocumentDefID from ADM_DocumentDef where COSTCENTERCOLID=(SELECT COLID FROM #TBLTEMP WHERE ID=@i) and CostCenterID=@CCID)
						begin
					 
					INSERT INTO [ADM_DocumentDef]              
					  ([DocumentTypeID]              
					  ,[CostCenterID]             
					  ,[CostCenterColID]              
					  ,[DebitAccount]              
					  ,[CreditAccount]              
					  ,[Formula]              
					  ,[PostingType]              
					  ,[RoundOff]              
					  ,[RoundOffLineWise]              
					  ,[IsRoundOffEnabled]              
					  ,[IsDrAccountDisplayed]           
					  ,[IsCrAccountDisplayed]              
					  ,[IsDistributionEnabled]              
					  ,[DistributionColID]              
					  ,[IsCalculate]              
					  ,[CompanyGUID]              
					  ,[GUID]              
					  ,[CreatedBy]              
					  ,[CreatedDate])              
				   select (select DocumentTypeID FROM ADM_DOCUMENTTYPES WHERE  CostCenterID=@CostCenterId)
					  ,@CostCenterId              
					  ,@CostCenterColID              
					  ,[DebitAccount]              
					  ,[CreditAccount]              
					  ,[Formula]              
					  ,[PostingType]              
					  ,[RoundOff]              
					  ,[RoundOffLineWise]              
					  ,[IsRoundOffEnabled]              
					  ,[IsDrAccountDisplayed]           
					  ,[IsCrAccountDisplayed]              
					  ,[IsDistributionEnabled]              
					  ,[DistributionColID]              
					  ,[IsCalculate]              
					  ,[CompanyGUID]             
					  ,newid()               
					  ,@UserName              
					  ,convert(float,getdate()) from  ADM_DocumentDef where COSTCENTERCOLID=(SELECT COLID FROM #TBLTEMP WHERE ID=@i) and CostCenterID=@CCID
				end
		end
		 

		set @i=@i+1
 
end


DROP TABLE #TBLTEMP

COMMIT TRANSACTION
GO
