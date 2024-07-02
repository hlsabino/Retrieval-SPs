USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenterPreferences]
	@PreferenceXml [nvarchar](max) = '',
	@CostCenterID [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		
		--Declaration Section
		DECLARE @DATA XML,@TempGuid NVARCHAR(50),@HasAccess BIT,@COUNT INT,@I INT,@KEY NVARCHAR(500),@VALUE NVARCHAR(MAX)
		declare @tempvalue nvarchar(MAX),@TableName nvarchar(50)
		DECLARE @TEMP TABLE (ID INT IDENTITY(1,1),[KEY] NVARCHAR(500),[VALUE] NVARCHAR(MAX))
		DECLARE	@CCID INT,@ColID INT, @Rid INT,@TabID INT,@CostCenterName nvarchar(100),@cnt int,@icnt int
		declare @bindim nvarchar(50),@ParentCostCenterSysName nvarchar(50),@ParentCCDefaultColID INT
		declare @tab table (id int identity(1,1),val int)
	
		--SP Required Parameters Check
		IF @PreferenceXml='' OR @CostCenterID=0
		BEGIN
			RAISERROR('-100',16,1)
		END
 
		if(@CostCenterID<>153)
		BEGIN
			--User acces check 
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,30)
		 
			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END		
		END
		
		SET @DATA=@PreferenceXml
		
		if(@CostCenterID=3)
		begin
			select @VALUE =VALUE from COM_CostCenterPreferences with(nolock)
			where [Name]='BinsDimension' and CostCenterID=@CostCenterID
		
			select @bindim=X.value('@Value','nvarchar(max)') FROM @DATA.nodes('/XML/Row') as DATA(X) where X.value('@Name','nvarchar(300)')='BinsDimension'
			if @bindim is not null and @bindim!='' and isnumeric(@bindim)=1 and convert(int,@bindim)>50000 and @VALUE!=@bindim
			begin
				select @ParentCostCenterSysName=ParentCostCenterSysName,@ParentCCDefaultColID=ParentCCDefaultColID from adm_costcenterdef with(nolock) 
				where CostCenterID=40001 and ParentCostCenterID=@bindim
				
				update adm_costcenterdef set IsForeignKey=1,ParentCostCenterID=@bindim,ParentCostCenterColID=0,ParentCostCenterSysName=@ParentCostCenterSysName
					,ParentCostCenterColSysName='NodeID',ParentCCDefaultColID=@ParentCCDefaultColID
				where costcentercolid=181
				
				select @TabID=CCTabID from ADM_CostCenterTab with(nolock) 
				where CostCenterID=@bindim and CCTabName='General' 
				
				update ADM_CostCenterTab
				set IsVisible=1
				where CCTabID=@TabID
				
				update ADM_CostCenterDef
				set UserColumnName='Length',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=0, UserDefaultValue='',
						IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
						dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=22
				where CostCenterID=@bindim and SysColumnName='ccalpha47'

				update ADM_CostCenterDef
				set UserColumnName='Width',UserColumnType='NUMERIC',ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='',
						IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
						dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=23
				where CostCenterID=@bindim and SysColumnName='ccalpha48'
				
				update ADM_CostCenterDef
				set UserColumnName='Height',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=0, UserDefaultValue='',
						IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
						dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=24
				where CostCenterID=@bindim and SysColumnName='ccalpha49'

				update ADM_CostCenterDef
				set UserColumnName='Volume',UserColumnType='NUMERIC',ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='',
						IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
						dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=25
				where CostCenterID=@bindim and SysColumnName='ccalpha50'

				update COM_LanguageResources
				set ResourceData='Length'
				from ADM_CostCenterDef
				where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@bindim and SysColumnName='ccalpha47'
				
				update COM_LanguageResources
				set ResourceData='Width'
				from ADM_CostCenterDef
				where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@bindim and SysColumnName='ccalpha48'
				
				update COM_LanguageResources
				set ResourceData='Height'
				from ADM_CostCenterDef
				where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@bindim and SysColumnName='ccalpha49'

				update COM_LanguageResources
				set ResourceData='Volume'
				from ADM_CostCenterDef
				where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@bindim and SysColumnName='ccalpha50'
				
			end
			
			select @VALUE =VALUE from COM_CostCenterPreferences with(nolock)
			where [Name]='PrDimWiseFields' and CostCenterID=@CostCenterID
		
			select @TempVALUE=X.value('@Value','nvarchar(max)') FROM @DATA.nodes('/XML/Row') as DATA(X) where X.value('@Name','nvarchar(300)')='PrDimWiseFields'
			if @TempVALUE is not null and @TempVALUE!='' and @VALUE!=@TempVALUE
			begin
					insert into @tab  
					exec SPSplitString @TempVALUE,';'  
					
					select @cnt=max(ID),@icnt=min(ID) from @tab
					set @icnt=@icnt-1
					while @icnt<@cnt
					begin
						set @icnt=@icnt+1
						
						Select @CCID=val from @tab where ID=@icnt
						if(@CCID>50000)
						BEGIN
							set @CCID=@CCID-50000						
							if not exists(select * from sys.columns where Object_id	=Object_id('ADM_TypeRestrictions') and name='DcCCNID'+convert(nvarchar(max),@CCID))
							BEGIN
								set @TempVALUE='alter table ADM_TypeRestrictions add DcCCNID'+convert(nvarchar(max),@CCID)+' INT'
								exec(@TempVALUE)
							END
						END
						ELSE
						BEGIN
							if not exists(select * from sys.columns where Object_id	=Object_id('ADM_TypeRestrictions') and name='GroupID')
							BEGIN
								set @TempVALUE='alter table ADM_TypeRestrictions add GroupID INT'
								exec(@TempVALUE)
							END
						END	
					END	
			END
		end
		else if(@CostCenterID=16)
		begin
			SELECT @tempvalue=X.value('@Value','nvarchar(max)')
			FROM @DATA.nodes('/XML/Row') as DATA(X)
			where X.value('@Name','nvarchar(300)')='ConsolidatedBatches'
			
			select @VALUE =VALUE from COM_CostCenterPreferences with(nolock)
			where [Name]='ConsolidatedBatches' and CostCenterID=@CostCenterID
					
			if(@tempvalue!=@VALUE and exists(select InvDocDetailsID from INV_BatchDetails with(nolock) where VoucherType=-1 ))
			begin
				RAISERROR('-352',16,1)
			end			
		end
		else if(@CostCenterID=72)
		begin
			SELECT @tempvalue=X.value('@Value','nvarchar(max)')
			FROM @DATA.nodes('/XML/Row') as DATA(X)
			where X.value('@Name','nvarchar(50)')='AssetLocationDim'
			if @tempvalue!='' and @tempvalue is not null
				set @CCID=convert(int,@tempvalue)
			else
				set @CCID=0
				
			if @CCID>50000--To update label
			begin
				update COM_LanguageResources
				set ResourceData=F.Name from adm_costcenterdef C with(nolock)
				inner join COM_LanguageResources R with(nolock) on C.ResourceID=R.ResourceID
				inner join adm_features F with(nolock) on F.FeatureID=C.CostCenterID
				where C.CostCenterID=72 and C.costcentercolid=25472 and R.LanguageID=1
			end
				
			update adm_costcenterdef 
			set ColumnCostCenterID=@CCID,ColumnCCListViewTypeID=1,
			ParentCostCenterID=@CCID,ParentCostCenterSysName=T.ParentCostCenterSysName,
			ParentCostCenterColSysName=T.ParentCostCenterColSysName,ParentCCDefaultColID=T.ParentCCDefaultColID
			from adm_costcenterdef C WITH(NOLOCK)
			,(select top 1 ParentCostCenterSysName,ParentCostCenterColSysName,ParentCCDefaultColID from adm_costcenterdef with(nolock) where costcenterid=40001 and SysTableName='COM_DocCCData' and ColumnCOstCenterID=@CCID) T
			where C.costcenterid=72 and C.costcentercolid=25472
			
			--select * from adm_costcenterdef 
			--where costcenterid=72 and costcentercolid=25472
			
			SELECT @tempvalue=X.value('@Value','nvarchar(max)')
			FROM @DATA.nodes('/XML/Row') as DATA(X)
			where X.value('@Name','nvarchar(50)')='AssetOwner'
			if @tempvalue!='' and @tempvalue is not null
				set @CCID=convert(int,@tempvalue)
			else
				set @CCID=0
			update adm_costcenterdef 
			set ColumnCostCenterID=@CCID,ColumnCCListViewTypeID=1,
			ParentCostCenterID=@CCID,ParentCostCenterSysName=T.ParentCostCenterSysName,
			ParentCostCenterColSysName=T.ParentCostCenterColSysName,ParentCCDefaultColID=T.ParentCCDefaultColID
			from adm_costcenterdef C
			left join (select top 1 ColumnCOstCenterID,ParentCostCenterSysName,ParentCostCenterColSysName,ParentCCDefaultColID from adm_costcenterdef with(nolock) where costcenterid=40001 and SysTableName='COM_DocCCData' and ColumnCOstCenterID=@CCID and @CCID>0) T on T.ColumnCOstCenterID=@CCID
			where C.costcenterid=72 and C.costcentercolid=25467
						
			--select * from adm_costcenterdef where costcenterid=40001 and SysTableName='COM_DocCCData' and ColumnCOstCenterID=@tempvalue
		end
		else if(@CostCenterID=76)
		begin
			
			SELECT @tempvalue=X.value('@Value','nvarchar(max)')
			FROM @DATA.nodes('/XML/Row') as DATA(X)
			where X.value('@Name','nvarchar(50)')='StageDimension'
	
			select @VALUE =VALUE from COM_CostCenterPreferences with(nolock)
			where [Name]='StageDimension' and CostCenterID=@CostCenterID
					
			if(@VALUE is not null and @VALUE<>'' and @tempvalue!=@VALUE and exists(select StageID from PRD_BOMStages WITH(NOLOCK) where StageID>1))
			begin
				RAISERROR('Stage dimension can not be modified, because stages mapped in BOM.',16,1)
			end
			
			--MachineDimension
			SELECT @tempvalue=X.value('@Value','nvarchar(max)')
			FROM @DATA.nodes('/XML/Row') as DATA(X)
			where X.value('@Name','nvarchar(50)')='MachineDimension'
	
			select @VALUE=VALUE from COM_CostCenterPreferences with(nolock)
			where [Name]='MachineDimension' and CostCenterID=@CostCenterID
					
			if(@tempvalue!=@VALUE and ISNUMERIC(@tempvalue)=1)
			begin
				set @CCID=CONVERT(INT,@tempvalue) 
				
				if(@CCID>50000)
				begin
					select @TabID=CCTabID from ADM_CostCenterTab with(nolock) where CostCenterID=@CCID and CCTabName='General' 
					--Cost/Hr 
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha47'
								 
					update  COM_LanguageResources set ResourceData='Cost/Hr', ResourceName='Cost/Hr' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Cost/Hr', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=0, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					--Usage (Hr/Day) 
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha48'
					 
					update  COM_LanguageResources set ResourceData='Usage (Hr/Day)', ResourceName='Usage (Hr/Day)' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Usage (Hr/Day)', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=0, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					--Capacity 
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha49'

					update  COM_LanguageResources set ResourceData='Capacity', ResourceName='Capacity' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Capacity', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=0, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					--Efficiency 
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha50'

					update  COM_LanguageResources set ResourceData='Efficiency', ResourceName='Efficiency' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Efficiency', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=0, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID
					
					select @TableName =TableName from ADM_Features WITH(NOLOCK) where FeatureID=@CCID
					if not exists (select Name from sys.columns where Name='ccAlpha47' and object_id=object_id(@TableName))
					begin
						set @tempvalue='alter table '+@TableName+' add ccAlpha47 float'
						Exec sp_executesql @tempvalue
					END
					if not exists (select Name from sys.columns where Name='ccAlpha48' and object_id=object_id(@TableName))
					begin
						set @tempvalue='alter table '+@TableName+' add ccAlpha48 float'
						Exec sp_executesql @tempvalue
					END
					if not exists (select Name from sys.columns where Name='ccAlpha49' and object_id=object_id(@TableName))
					begin
						set @tempvalue='alter table '+@TableName+' add ccAlpha49 float'
						Exec sp_executesql @tempvalue
					END
					if not exists (select Name from sys.columns where Name='ccAlpha50' and object_id=object_id(@TableName))
					begin
						set @tempvalue='alter table '+@TableName+' add ccAlpha50 float'
						Exec sp_executesql @tempvalue
					END
				end
			end
			
			--JobDimension
			SELECT @tempvalue=X.value('@Value','nvarchar(max)')
			FROM @DATA.nodes('/XML/Row') as DATA(X)
			where X.value('@Name','nvarchar(50)')='JobDimension'
	
			select @VALUE=VALUE from COM_CostCenterPreferences with(nolock)
			where [Name]='JobDimension' and CostCenterID=@CostCenterID
				
			if(@tempvalue!=@VALUE and ISNUMERIC(@tempvalue)=1)
			begin
				set @CCID=CONVERT(INT,@tempvalue) 
				
				if(@CCID>50000)
				begin
					--select @CCID
					
					declare @FID INT, @FAID INT
					select @FAID=featureactionid from ADM_RibbonView WITH(NOLOCK) where FeatureID=@tempvalue
					update ADM_RibbonView set FeatureActionID=@FAID, FeatureID=@tempvalue
					where DrpName='Jobs' and TabID=4 and GroupID=32
				
					select @TabID=CCTabID from ADM_CostCenterTab with(nolock) where CostCenterID=@CCID and CCTabName='General'
										
					--Finished Product					
					set @ColID=null
					select @ColID=CostCenterColID, @Rid=resourceid,@CostCenterName=CostCenterName from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ProductID' and SysTableName='COM_CCCCDATA'

					update  COM_LanguageResources set ResourceData='Finished Product', ResourceName='Finished Product' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Finished Product', UserColumnType='LISTBOX', ColumnDataType='', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=0, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID
					
					--Job Size
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha50'
					
					update COM_LanguageResources set ResourceData='Job Size', ResourceName='Job Size' where ResourceID=@Rid 
					
					update ADM_CostCenterDef set UserColumnName='Job Size', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='0',
					SectionID=@TabID, RowNo=0, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					--Start Date
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha49'
					 
					update  COM_LanguageResources set ResourceData='Start Date', ResourceName='Start Date' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Start Date', UserColumnType='DATE', ColumnDataType='DATE', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=0, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					--End Date
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha48'
					 
					update  COM_LanguageResources set ResourceData='End Date', ResourceName='End Date' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='End Date', UserColumnType='DATE', ColumnDataType='DATE', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=0, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha47'
					 
					update  COM_LanguageResources set ResourceData='Mfg Date', ResourceName='Mfg Date' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Mfg Date', UserColumnType='DATE', ColumnDataType='DATE', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=1, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					--End Date
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha46'
					 
					update  COM_LanguageResources set ResourceData='Expiry Date', ResourceName='Expiry Date' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Expiry Date', UserColumnType='DATE', ColumnDataType='DATE', SectionSeqNumber=0, 
					SectionID=@TabID, RowNo=1, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID
					
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha45'
					 
					update  COM_LanguageResources set ResourceData='Retest Date', ResourceName='Retest Date' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Retest Date', UserColumnType='DATE', ColumnDataType='DATE', SectionSeqNumber=0, 
					IsVisible=0,SectionID=@TabID, RowNo=1, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID
			
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha44'
					 
					update  COM_LanguageResources set ResourceData='MRP Rate', ResourceName='MRP Rate' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='MRP Rate', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='0',
					IsVisible=0,SectionID=@TabID, RowNo=0, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID
					
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha43'
					 
					update  COM_LanguageResources set ResourceData='Retail Rate', ResourceName='Retail Rate' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Retail Rate', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='0',
					IsVisible=0,SectionID=@TabID, RowNo=0, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha42'
					 
					update  COM_LanguageResources set ResourceData='Stockist Rate', ResourceName='Stockist Rate' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Stockist Rate', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='0',
					IsVisible=0,SectionID=@TabID, RowNo=0, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha41'
					 
					update  COM_LanguageResources set ResourceData='Units', ResourceName='Units' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Units', UserColumnType='COMBOBOX', ColumnDataType='STRING', SectionSeqNumber=0, UserDefaultValue='QTY',
					UserProbableValues='QTY;BOM',IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID
					
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha40'
					 
					update  COM_LanguageResources set ResourceData='Pre Expiry Days', ResourceName='Pre Expiry Days' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Pre Expiry Days', UserColumnType='NUMERIC', ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='0',
					IsVisible=0,SectionID=@TabID, RowNo=0, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='' where CostCenterColID=@ColID and CostCenterID=@CCID

					update ADM_CostCenterTab
					set IsVisible=0
					where CostCenterID=@CCID
					and CCTabName in('Address','Contacts','Assign')
					
					update ADM_CostCenterDef
					set IsVisible=0
					where costcenterid=@CCID and SysColumnName in('CreditDays','CreditLimit','PurchaseAccount','SalesAccount','DebitDays','DebitLimit')
					
					select @Rid=ResourceID from COM_Status WITH(NOLOCK) where CostCenterID=@CCID and [Status]='Active'
					update COM_LanguageResources set ResourceData='In Process'
					where ResourceID=@Rid
					
					select @Rid=ResourceID from COM_Status WITH(NOLOCK) where CostCenterID=@CCID and [Status]='In Active'
					update COM_LanguageResources set ResourceData='Completed'
					where ResourceID=@Rid
					
					update COM_Status 
					set CostCenterID=@CCID
					where statusid=461
					
					--Reports Update
					declare @JobVal nvarchar(max),@JobCC int,@SQL nvarchar(max),@Tempsql nvarchar(max)
					select @JobVal=VALUE
					from COM_CostCenterPreferences with(nolock) where [Name]='JobDimension' and CostCenterID=76
					if @JobVal is not null and isnumeric(@JobVal)=1
					begin
						set @JobCC=convert(int,@JobVal)

						update ADM_RevenUReports
						set [TreeXML]='<Tree><CCID>'+@JobVal+'</CCID></Tree>'
						where ([StaticReportType]>=172 and [StaticReportType]<=175) or ReportID=184

						set @Tempsql='dcCCNID'+convert(nvarchar,(@JobCC-50000))

						set @SQL=null
						select @SQL='<Field>-'+convert(nvarchar,costcentercolid)+'</Field><SelectedField>'+convert(nvarchar,ParentCCDefaultColID)+'</SelectedField>'
						from adm_costcenterdef with(nolock) where costcenterid=40001 and SysColumnName=@Tempsql

						if @SQL is not null
						begin
							update ADM_RevenUReports
							set ReportDefnXML=replace(convert(nvarchar(max),ReportDefnXML),'<Field>-7009</Field><SelectedField>2615</SelectedField>',@SQL)
							where (ReportID>=176 and ReportID<=179)
							
							update ADM_RevenUReports
							set ReportDefnXML=replace(convert(nvarchar(max),ReportDefnXML),'<TreeFilter><FilterDef><CCID>300</CCID><IsDefaultCC>0</IsDefaultCC><HideInReport>1</HideInReport><DefaultValues>40998</DefaultValues></FilterDef></TreeFilter>'
							,'<TreeFilter><FilterDef><CCID>300</CCID><GridViewID>0</GridViewID><IsDefaultCC>0</IsDefaultCC><HideInReport>1</HideInReport><DefaultValues>40998</DefaultValues></FilterDef>
							<FilterDef><CCID>'+@JobVal+'</CCID><GridViewID>0</GridViewID><IsDefaultCC>1</IsDefaultCC><DefaultValues></DefaultValues></FilterDef>
							</TreeFilter>')
							where ReportID=176
							
							update ADM_RevenUReports
							set ReportDefnXML=replace(convert(nvarchar(max),ReportDefnXML),'<TreeFilter><FilterDef><CCID>300</CCID><IsDefaultCC>0</IsDefaultCC><HideInReport>1</HideInReport><DefaultValues>40999</DefaultValues></FilterDef></TreeFilter>'
							,'<TreeFilter><FilterDef><CCID>300</CCID><GridViewID>0</GridViewID><IsDefaultCC>0</IsDefaultCC><HideInReport>1</HideInReport><DefaultValues>40999</DefaultValues></FilterDef>
							<FilterDef><CCID>'+@JobVal+'</CCID><GridViewID>0</GridViewID><IsDefaultCC>1</IsDefaultCC><DefaultValues></DefaultValues></FilterDef>
							</TreeFilter>')
							where ReportID=177
							
							update ADM_RevenUReports
							set ReportDefnXML=replace(convert(nvarchar(max),ReportDefnXML),'<TreeFilter><FilterDef><CCID>300</CCID><GridViewID>0</GridViewID><IsDefaultCC>1</IsDefaultCC><HideInReport>1</HideInReport><DefaultValues>40995,40996,40998,40999</DefaultValues></FilterDef></TreeFilter>'
							,'<TreeFilter><FilterDef><CCID>300</CCID><GridViewID>0</GridViewID><IsDefaultCC>0</IsDefaultCC><HideInReport>1</HideInReport><DefaultValues>40995,40996,40998,40999</DefaultValues></FilterDef>
							<FilterDef><CCID>'+@JobVal+'</CCID><GridViewID>0</GridViewID><IsDefaultCC>1</IsDefaultCC><DefaultValues></DefaultValues></FilterDef>
							</TreeFilter>')
							where ReportID=184
						end
					end
					
				end
				ELSE
				BEGIN
					update ADM_RibbonView set FeatureActionID=327, FeatureID=50001
					where DrpName='Jobs' and TabID=4 and GroupID=32
				END
			end
		end
		
		--UPDATE ADM_CostCenterPreferences    	
		SET @I=1

		INSERT INTO @TEMP ([KEY],[VALUE])
		SELECT X.value('@Name','nvarchar(300)'),X.value('@Value','nvarchar(max)')
		FROM @DATA.nodes('/XML/Row') as DATA(X)


		
		if(@CostCenterID>50000 and @CostCenterID<=50050 and exists (select top 1 Value from @TEMP where [Key]='CreateUserOnDim' and Value='True'))
		begin			
			SELECT @TableName=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterID
			if not exists (select Name from sys.columns where Name='UserNameAlpha' and object_id=object_id(@TableName))
			begin
				select @CostCenterName=CostCenterName from [adm_costcenterdef] with(nolock) where CostCenterID=@CostCenterID
			
				select @colid=max([CostCenterColID]) from [adm_costcenterdef] with(nolock)
				select @rid=max(ResourceID) from [com_languageresources] with(nolock)

				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
				VALUES(@rid+1,'User Name',1,'English','User Name','448BFA36',NULL,'ADMIN',4,NULL,NULL,'')

				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
				VALUES(@rid+1,'User Name',2,'Arabic','User Name','448BFA36',NULL,'ADMIN',4,NULL,NULL,'')

				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
				VALUES(@rid+2,'Password',1,'English','Password','448BFA36',NULL,'ADMIN',4,NULL,NULL,'')

				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
				VALUES(@rid+2,'Password',2,'Arabic','Password','448BFA36',NULL,'ADMIN',4,NULL,NULL,'')

				set identity_insert [adm_costcenterdef] ON
				INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat])
				VALUES(@CostCenterID,@colid+1,@rid+1,@CostCenterName,@TableName,'User Name','UserNameAlpha',NULL,'TEXT','TEXT',NULL,NULL,0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'693E656C-CD0D-486D-AFAC-FC36CBFFAF0D','A5203D77-8DD2-499D-8BB7-9495333DC917',NULL,'Admin',4,NULL,NULL,0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL)

				INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat])
				VALUES(@CostCenterID,@colid+2,@rid+2,@CostCenterName,@TableName,'Password','PasswordAlpha',NULL,'PASS','PASS',NULL,NULL,0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'693E656C-CD0D-486D-AFAC-FC36CBFFAF0D','A5203D77-8DD2-499D-8BB7-9495333DC917',NULL,'Admin',4,NULL,NULL,0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL)
				set identity_insert [adm_costcenterdef] OFF

				select @cnt=max(RowNo) from [adm_costcenterdef] with(nolock) where CostCenterID=@CostCenterID
				update [adm_costcenterdef] set SectionID=null,RowNo=@cnt+1,ColumnNo=0,IsMandatory=1 where CostCenterColID=@colid+1
				update [adm_costcenterdef] set SectionID=null,RowNo=@cnt+1,ColumnNo=1,IsMandatory=1 where CostCenterColID=@colid+2

			--	select * from adm_costcenterdef where CostCenterID=50001 order by [CostCenterColID] desc


				SET @SQL='ALTER TABLE '+@TableName+' ADD UserNameAlpha NVARCHAR(100),PasswordAlpha NVARCHAR(100)'
				EXEC (@SQL)
			END
		end

		 
		SELECT @COUNT=COUNT(*) FROM @TEMP
 
		WHILE @I<=@COUNT
		BEGIN
				
			SELECT @KEY=[KEY],@VALUE=[VALUE] FROM @TEMP WHERE ID=@I
			
			if(@CostCenterID =3 and @KEY='ConsolidatedBins' and @VALUE='false'
			and exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='ConsolidatedBins' and costcenterid=3 and Value='true')
			and exists(select InvDocDetailsID from INV_BinDetails with(nolock)
			where VoucherType=-1 and IsQtyIgnored=0 and (RefInvDocDetailsID is null or RefInvDocDetailsID=0)))
			BEGIN
				RAISERROR('-559',16,1)
			END
			
			if(@CostCenterID =3 and @KEY='BinsDimension' 
			and exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='BinsDimension' and costcenterid=3 and ISNUMERIC(Value)=1 and CONVERT(INT,Value)>50000)
			and exists(select InvDocDetailsID from INV_BinDetails with(nolock))
			and @VALUE!=(select Value from [COM_CostCenterPreferences] with(nolock)
			where Name='BinsDimension' and costcenterid=3))
			BEGIN
				RAISERROR('-560',16,1)
			END
			
			if(@CostCenterID =93 and @KEY='UnitLinkDimension' 
			and @VALUE IS NOT NULL AND @VALUE<>'' and ISNUMERIC(@VALUE)=1 AND CONVERT(INT,@VALUE)>50000
			and exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='UnitLinkDimension' and costcenterid=@CostCenterID and ISNUMERIC(Value)=1 and CONVERT(INT,Value)>50000)
			and @VALUE!=(select Value from [COM_CostCenterPreferences] with(nolock)
			where Name='UnitLinkDimension' and costcenterid=@CostCenterID))
			BEGIN
				SELECT @CostCenterName=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=CONVERT(INT,@VALUE)
				IF @CostCenterName IS NOT NULL AND @CostCenterName<>''
				BEGIN
					if exists (select Name from sys.columns where Name='Code' and object_id=object_id(@CostCenterName))
					begin
						SET @SQL='ALTER TABLE '+@CostCenterName+' ALTER COLUMN Code NVARCHAR(MAX)'
						EXEC (@SQL)
					END
					if exists (select Name from sys.columns where Name='Name' and object_id=object_id(@CostCenterName))
					begin
						SET @SQL='ALTER TABLE '+@CostCenterName+' ALTER COLUMN Name NVARCHAR(MAX)'
						EXEC (@SQL)
					END
					if exists (select Name from sys.columns where Name='AliasName' and object_id=object_id(@CostCenterName))
					begin
						SET @SQL='ALTER TABLE '+@CostCenterName+' ALTER COLUMN AliasName NVARCHAR(MAX)'
						EXEC (@SQL)
					END
				END
			END
			
			UPDATE COM_CostCenterPreferences 
			SET [Value]=@VALUE,
				[ModifiedBy]=@UserName,
				[ModifiedDate]=convert(float,getdate())
			WHERE [Name]=@KEY AND CostCenterID=@CostCenterID
		
			SET @I=@I+1
			
		END
		
		if(@CostCenterID=92)
		begin
			declare @Dim nvarchar(max)
			set @Dim=null
			select @Dim=Value from com_costcenterpreferences with(nolock) where costcenterid=92 and Name='Landlord'
			if(@Dim is not null and @Dim!='' and isnumeric(@Dim)=1)
			begin
				select @ParentCostCenterSysName=ParentCostCenterSysName,@ParentCCDefaultColID=ParentCCDefaultColID
				from adm_costcenterdef C WITH(NOLOCK) where CostcenterID=40001 and SysColumnName='dcCCNID'+convert(nvarchar,(@Dim-50000))
				
				update adm_costcenterdef
				set ColumnCostCenterID=@Dim,IsForeignKey=1,ParentCostCenterID=@Dim,ParentCostCenterSysName=@ParentCostCenterSysName
				,ParentCostCenterColSysName='NodeID',ParentCCDefaultColID=@ParentCCDefaultColID
				where SysColumnName='LandlordID' and CostCenterID in (92,93,95,103,104,129)
			end
			set @Dim=null
			select @Dim=Value from com_costcenterpreferences with(nolock) where costcenterid=92 and Name='Accountant'
			if(@Dim is not null and @Dim!='' and isnumeric(@Dim)=1)
			begin
				select @ParentCostCenterSysName=ParentCostCenterSysName,@ParentCCDefaultColID=ParentCCDefaultColID
				from adm_costcenterdef C WITH(NOLOCK) where CostcenterID=40001 and SysColumnName='dcCCNID'+convert(nvarchar,(@Dim-50000))
				
				update adm_costcenterdef
				set ColumnCostCenterID=@Dim,IsForeignKey=1,ParentCostCenterID=@Dim,ParentCostCenterSysName=@ParentCostCenterSysName
				,ParentCostCenterColSysName='NodeID',ParentCCDefaultColID=@ParentCCDefaultColID
				where SysColumnName='AccountantID' and CostCenterID in (92,93,95,103,104,129)
			end
			set @Dim=null
			select @Dim=Value from com_costcenterpreferences with(nolock) where costcenterid=92 and Name='Salesman'
			if(@Dim is not null and @Dim!='' and isnumeric(@Dim)=1)
			begin
				select @ParentCostCenterSysName=ParentCostCenterSysName,@ParentCCDefaultColID=ParentCCDefaultColID
				from adm_costcenterdef C WITH(NOLOCK) where CostcenterID=40001 and SysColumnName='dcCCNID'+convert(nvarchar,(@Dim-50000))
				
				update adm_costcenterdef
				set ColumnCostCenterID=@Dim,IsForeignKey=1,ParentCostCenterID=@Dim,ParentCostCenterSysName=@ParentCostCenterSysName
				,ParentCostCenterColSysName='NodeID',ParentCCDefaultColID=@ParentCCDefaultColID
				where SysColumnName='SalesmanID' and CostCenterID in (92,93,95,103,104,129)
			end
		end
		
		
	  --select * from ADM_CostCenterDef where CostCenterID=@CCID
COMMIT TRANSACTION  
--rollback  TRANSACTION  
SELECT * FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID   
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
		if isnumeric(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		ELSE
			SELECT ERROR_MESSAGE() ErrorMessage,50000 ErrorNumber
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
