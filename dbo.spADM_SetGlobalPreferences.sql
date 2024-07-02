USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetGlobalPreferences]
	@PreferenceXml [nvarchar](max) = '',
	@FinancialYearsXml [nvarchar](max) = NULL,
	@CrossDimensionXml [nvarchar](max) = NULL,
	@QtyAdjustmentXml [nvarchar](max) = NULL,
	@LockedDatesXml [nvarchar](max) = NULL,
	@RegisterPreferenceXML [nvarchar](max) = NULL,
	@LWEmailXML [nvarchar](max) = NULL,
	@DSCGridXML [nvarchar](max) = NULL,
	@BRSLockedDatesXml [nvarchar](max) = NULL,
	@PenaltyDocXml [nvarchar](max) = NULL,
	@CostCenterID [int],
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
	DECLARE @DATA XML,@TempGuid NVARCHAR(max),@HasAccess BIT,@COUNT INT,@I INT,@KEY NVARCHAR(500),@VALUE NVARCHAR(MAX)    
	declare @ColID INT, @Rid INT, @CCID int,@TabID int,@SQL nvarchar(MAX),@TblName nvarchar(50),@PMDim INT,@ProjMDim INT
	declare @r int, @c int, @cnt int, @icnt int
	DECLARE @TEMP TABLE (ID INT IDENTITY(1,1),[KEY] NVARCHAR(500),[VALUE] NVARCHAR(MAX))    
    declare @tab table (id int identity(1,1),val int)
	
	--SP Required Parameters Check    
	IF @PreferenceXml=''    
	BEGIN    
		RAISERROR('-100',16,1)    
	END    

	--User acces check     
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,10,3)    

	IF @HasAccess=0    
	BEGIN    
		RAISERROR('-105',16,1)    
	END      

	delete from ADM_GlobalPreferences_History where convert(float,GUID)<convert(float,dateadd(year,-1,getdate()))

	INSERT INTO ADM_GlobalPreferences_History(GlobalPrefID,ResourceID,Name,Value,DefaultValue,[GUID],[Description],CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
	SELECT GlobalPrefID,ResourceID,Name,Value,DefaultValue,convert(varchar(30),convert(float,getdate()),2),[Description],CreatedBy,CreatedDate,ModifiedBy,ModifiedDate 
	FROM ADM_GlobalPreferences with(nolock)

	SET @DATA=@PreferenceXml    

	INSERT INTO @TEMP ([KEY],[VALUE])    
	SELECT X.value('@Name','nvarchar(300)'),X.value('@Value','nvarchar(max)')    
	FROM @DATA.nodes('/XML/Row') as DATA(X)    

	SELECT @I=1,@COUNT=COUNT(*) FROM @TEMP    

	WHILE @I<=@COUNT    
	BEGIN          

	SELECT @KEY=[KEY],@VALUE=[VALUE]  FROM @TEMP WHERE ID=@I    
           
	if (@KEY='Intermediate PDC' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))    
	begin    
		if exists(select DocID from ACC_DocDetails with(nolock) where DocumentType in(19,14) and StatusID in(369,429))    
		begin    
			RAISERROR('-372',16,1)                  
		end    
	end	
	else if(@KEY='EnableAttachments' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			update [com_documentpreferences]
			set prefValue=@VALUE
			where prefname='Attachments'
	END
	else if(@KEY='EnableActivities' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			update [com_documentpreferences]
			set prefValue=@VALUE
			where prefname='Activities'
	END
	else if(@KEY='Enablechequehold' and @VALUE!=(select top 1  [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			if not exists(select * from sys.columns 
			where name ='HoldStatus' and object_id=object_id('ACC_DocDetails'))
			BEGIN
				alter table ACC_DocDetails add HoldStatus TinyINT
				alter table ACC_DocDetails add HoldTillDate Float
				
				alter table ACC_DocDetails_History add HoldStatus TinyINT
				alter table ACC_DocDetails_History add HoldTillDate Float
				select @Rid=MAX(ResourceID) from COM_LanguageResources WiTH(NOLOCK)
				
				set @Rid=@Rid+1

				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
				VALUES(@Rid,'HoldTillDate',1,'English','HoldTill','A18AA097-DF5D-41CD-9AFF-22C66D20097A',NULL,'ADMIN',4.072966253163580e+004,NULL,NULL,'')

				INSERT [dbo].[ADM_CostCenterDef] ([CostCenterID], [ResourceID], [CostCenterName], [SysTableName], [UserColumnName], [SysColumnName], [ColumnTypeSeqNumber], [UserColumnType], [ColumnDataType], [UserDefaultValue], [UserProbableValues], [ColumnOrder], [IsMandatory], [IsEditable], [IsVisible], [IsCostCenterUserDefined], [IsColumnUserDefined], [IsCCDeleted], [IsColumnDeleted], [ColumnCostCenterID], [ColumnCCListViewTypeID], [FetchMaxRows], [IsColumnGroup], [ColumnGroupNumber], [SectionSeqNumber], [SectionID], [SectionName], [RowNo], [ColumnNo], [ColumnSpan], [IsColumnInUse], [UIWidth], [CompanyGUID], [GUID], [Description], [CreatedBy], [CreatedDate], [ModifiedBy], [ModifiedDate], [IsUnique], [IsForeignKey], [ParentCostCenterID], [ParentCostCenterColID], [IsValidReportBuilderCol], [ParentCostCenterSysName], [ParentCostCenterColSysName], [ParentCCDefaultColID], [LinkData], [LocalReference], [Decimal], [TextFormat], [Filter], [IsRepeat], [LastValueVouchers], [IsnoTab], [dependancy], [dependanton], [IsTransfer], [DbFilter], [CrFilter], [ShowInQuickAdd], [QuickAddOrder], [Calculate], [Cformula], [IsReEvaluate], [IgnoreChar], [WaterMark])
				VALUES (400, @Rid, N'Documents', N'Acc_DocDetails', N'HoldTill', N'HoldTillDate', NULL, N'DATE', N'DATE', NULL, NULL, 8, 1, 1, 1, 1, 0, 0, 0, 11, 1, NULL, 0, NULL, 10, 550, NULL, 8, 3, 1, 1, NULL, N'6711ABED-2B8C-4289-8FE5-E1FC04529975', N'700B4CF7-6194-4B3A-A7A2-7C6310F8CEAF', NULL, N'Admin', 4, NULL, NULL, 0, 0, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, 0, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL)
				
				set @Rid=@Rid+1

				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
				VALUES(@Rid,'HoldStatus',1,'English','HoldStatus','A18AA097-DF5D-41CD-9AFF-22C66D20097A',NULL,'ADMIN',4.072966253163580e+004,NULL,NULL,'')

				INSERT [dbo].[ADM_CostCenterDef] ([CostCenterID], [ResourceID], [CostCenterName], [SysTableName], [UserColumnName], [SysColumnName], [ColumnTypeSeqNumber], [UserColumnType], [ColumnDataType], [UserDefaultValue], [UserProbableValues], [ColumnOrder], [IsMandatory], [IsEditable], [IsVisible], [IsCostCenterUserDefined], [IsColumnUserDefined], [IsCCDeleted], [IsColumnDeleted], [ColumnCostCenterID], [ColumnCCListViewTypeID], [FetchMaxRows], [IsColumnGroup], [ColumnGroupNumber], [SectionSeqNumber], [SectionID], [SectionName], [RowNo], [ColumnNo], [ColumnSpan], [IsColumnInUse], [UIWidth], [CompanyGUID], [GUID], [Description], [CreatedBy], [CreatedDate], [ModifiedBy], [ModifiedDate], [IsUnique], [IsForeignKey], [ParentCostCenterID], [ParentCostCenterColID], [IsValidReportBuilderCol], [ParentCostCenterSysName], [ParentCostCenterColSysName], [ParentCCDefaultColID], [LinkData], [LocalReference], [Decimal], [TextFormat], [Filter], [IsRepeat], [LastValueVouchers], [IsnoTab], [dependancy], [dependanton], [IsTransfer], [DbFilter], [CrFilter], [ShowInQuickAdd], [QuickAddOrder], [Calculate], [Cformula], [IsReEvaluate], [IgnoreChar], [WaterMark])
				VALUES (400, @Rid, N'Documents', N'Acc_DocDetails', N'HoldStatus', N'HoldStatus', NULL, N'INT', N'INT', NULL, NULL, 8, 1, 1, 1, 1, 0, 0, 0, 11, 1, NULL, 0, NULL, 10, 550, NULL, 8, 3, 1, 1, NULL, N'6711ABED-2B8C-4289-8FE5-E1FC04529975', N'700B4CF7-6194-4B3A-A7A2-7C6310F8CEAF', NULL, N'Admin', 4, NULL, NULL, 0, 0, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, 0, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL)

			END
	END
	else if(@KEY='EnableNotes' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			update [com_documentpreferences]
			set prefValue=@VALUE
			where prefname='Notes'
	END
	else if(@KEY='Registers' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			update ADM_CostCenterDef
			set UserColumnName='Device Name'
			where CostCenterID=@VALUE and SysColumnName='AliasName'
			
			update COM_LanguageResources
			set ResourceData='Device Name'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='AliasName'
	END
	else if(@KEY='EPOS' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			update ADM_CostCenterDef
			set UserColumnName='Device Name'
			where CostCenterID=@VALUE and SysColumnName='AliasName'
			
			update COM_LanguageResources
			set ResourceData='Device Name'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='AliasName'
	END
	else if(@KEY='SmartCard' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			update ADM_CostCenterDef
			set UserColumnName='Device Name'
			where CostCenterID=@VALUE and SysColumnName='AliasName'
			
			update COM_LanguageResources
			set ResourceData='Device Name'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='AliasName'
	END
	else if(@KEY='ProjectManagementDimension' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			if exists(select DocID from INV_DocDetails with(nolock)where documenttype=45)
			begin    
			 RAISERROR('-543',16,1)                  
			end 
			
			set @ProjMDim=@VALUE	
	END
	else if(@KEY in('PMLevel1Dimension','PMLevel2Dimension','PMLevel3Dimension','PMTaskDimension') and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN	
			
			select @TempGuid=Name from adm_features WITH(NOLOCK) where featureid=@VALUE
			
			update ADM_CostCenterDef
			set UserColumnName=@TempGuid,ColumnCostCenterID=@VALUE,columncclistviewtypeid=1,Iscolumninuse=1,isvisible=1,UserColumnType='LISTBOX',sectionid=3,SectionSeqNumber=4
			from adm_documenttypes b WITH(NOLOCK)
			where ADM_CostCenterDef.CostCenterid=b.CostCenterid and documenttype=45 and syscolumnname='dcCCNid'+convert(nvarchar(max),(convert(INT,@VALUE)-50000))
						
			update COM_LanguageResources
			set ResourceData=@TempGuid
			from ADM_CostCenterDef a WITH(NOLOCK)
			join adm_documenttypes b WITH(NOLOCK) on a.CostCenterid=b.CostCenterid
			where COM_LanguageResources.ResourceID=a.ResourceID and  documenttype=45 and syscolumnname='dcCCNid'+convert(nvarchar(max),(convert(INT,@VALUE)-50000))
	END
	else if(@KEY='DimensionwiseCurrency' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN	
			if exists(select DocID from ACC_DocDetails with(nolock))
			begin    
			 RAISERROR('-543',16,1)                  
			end 
			
			if exists(select DocID from INV_DocDetails with(nolock))
			begin    
			 RAISERROR('-543',16,1)                  
			end 
			
			if exists(select CurrencyID from COM_ExchangeRates with(nolock))
			begin    
			 RAISERROR('-544',16,1)                  
			end 
			
			
			if not exists(select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='Acc_docdetails' and a.name='AmountBC')
			BEGIN
				alter table COM_Billwise add AmountBC Float
				alter table Acc_docdetails add AmountBC Float
				alter table INV_docdetails add StockValueBC Float
				
				alter table COM_Billwise add ExhgRtBC Float
				alter table Acc_docdetails add ExhgRtBC Float
				alter table INV_docdetails add ExhgRtBC Float
			END
		
	END else if(@KEY='BillwiseCurrency' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN 
			if not exists(select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_Billwise' and a.name='AmountFC')
				alter table COM_Billwise add AmountFC Float
	END
	else if(@KEY='BaseCurrency' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN	
			if exists(select DocID from ACC_DocDetails with(nolock))
			begin    
			 RAISERROR('-545',16,1)                  
			end 
			
			if exists(select DocID from INV_DocDetails with(nolock))
			begin    
			 RAISERROR('-545',16,1)                  
			end 
	END		
  	ELSE if(@KEY='PosShifts' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			select @TabID=CCTabID from ADM_CostCenterTab with(nolock) 
			where CostCenterID=@VALUE and CCTabName='General'
			
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha49')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha49',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha50')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha50',@ColID OUTPUT
				
			update ADM_CostCenterDef
			set UserColumnName='Start Time',UserColumnType='TIME', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=25
			where CostCenterID=@VALUE and SysColumnName='ccAlpha49'
			
			update ADM_CostCenterDef
			set UserColumnName='END Time',UserColumnType='TIME', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=26
			where CostCenterID=@VALUE and SysColumnName='ccAlpha50'
			
			update COM_LanguageResources
			set ResourceData='Start Time'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccAlpha49'
			
			update COM_LanguageResources
			set ResourceData='END Time'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccAlpha50'
			
			update ADM_CostCenterTab
			set IsVisible=1
			where CCTabID=@TabID
					
	END 
	ELSE if(@KEY='Maintain Dimensionwise AverageRate' and isnumeric(@VALUE)=1 and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
		set @PMDim=@VALUE	
		set @PMDim=@PMDim-50000
		
		if not exists(select * from sys.columns where Object_id	=Object_id('INV_ProductAvgRate') and name='DcCCNID'+convert(nvarchar(max),@PMDim))
		BEGIN
			set @SQL='alter table INV_ProductAvgRate add DcCCNID'+convert(nvarchar(max),@PMDim)+' INT'
			exec(@SQL)
		END	
	END
	ELSE if(@KEY='DistributeCostDims' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
		delete from @tab
		insert into @tab  
		exec SPSplitString @VALUE,','  
		
		
		select @cnt=max(ID),@icnt=min(ID) from @tab
		set @icnt=@icnt-1
		while @icnt<@cnt
		begin
			set @icnt=@icnt+1
			
			Select @PMDim=val from @tab where ID=@icnt
			set @PMDim=@PMDim-50000
			
			if not exists(select * from sys.columns where Object_id	=Object_id('Adm_DistributeCosts') and name='DcCCNID'+convert(nvarchar(max),@PMDim))
			BEGIN
				set @SQL='alter table Adm_DistributeCosts add DcCCNID'+convert(nvarchar(max),@PMDim)+' INT'
				exec(@SQL)
			END
		END	
		update adm_costcenterdef
		set isvisible=1
		where costcenterid=2 and syscolumnname='DistCost'
	END
	ELSE if(@KEY='CostBasedONDims' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
		delete from @tab
		insert into @tab  
		exec SPSplitString @VALUE,','  
		
		select @cnt=max(ID),@icnt=min(ID) from @tab
		set @icnt=@icnt-1
		while @icnt<@cnt
		begin
			set @icnt=@icnt+1
			
			Select @PMDim=val from @tab where ID=@icnt
			if(@PMDim>50000)
			BEGIN
				set @PMDim=@PMDim-50000
				
				if not exists(select * from sys.columns where Object_id	=Object_id('Adm_MapCosts') and name='DcCCNID'+convert(nvarchar(max),@PMDim))
				BEGIN
					set @SQL='alter table Adm_MapCosts add DcCCNID'+convert(nvarchar(max),@PMDim)+' INT'
					exec(@SQL)
				END
			END	
		END	
		update adm_costcenterdef
		set isvisible=1
		where costcenterid=2 and syscolumnname='DistCost'
	END
	ELSE if(@KEY='ToCrossDimensions' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
		delete from @tab
		insert into @tab  
		exec SPSplitString @VALUE,','  
		
		select @cnt=max(ID),@icnt=min(ID) from @tab
		set @icnt=@icnt-1
		while @icnt<@cnt
		begin
			set @icnt=@icnt+1
			
			Select @PMDim=val from @tab where ID=@icnt
			if(@PMDim>50000)
			BEGIN
				set @PMDim=@PMDim-50000
				
				if not exists(select * from sys.columns where Object_id	=Object_id('ADM_CrossDimension') and name='DcCCNID'+convert(nvarchar(max),@PMDim))
				BEGIN
					set @SQL='alter table ADM_CrossDimension add DcCCNID'+convert(nvarchar(max),@PMDim)+' INT'
					exec(@SQL)
				END
			END	
		END			
	END
	ELSE if(@KEY='Location AverageRate' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
		if not exists(select * from sys.columns where Object_id	=Object_id('INV_ProductAvgRate') and name='DcCCNID2')
			alter table INV_ProductAvgRate add DcCCNID2 INT
	END
	ELSE if(@KEY='Division AverageRate' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
		if not exists(select * from sys.columns where Object_id	=Object_id('INV_ProductAvgRate') and name='DcCCNID1')
			alter table INV_ProductAvgRate add DcCCNID1 INT	
	END
	ELSE if(@KEY='PosCoupons' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			select @TabID=CCTabID from ADM_CostCenterTab with(nolock) 
			where CostCenterID=@VALUE and CCTabName='General'

			update ADM_CostCenterDef
			set UserDefaultValue='476'
			where CostCenterID=@VALUE and SysColumnName='StatusID'
			
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha42')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha42',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha43')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha43',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha44')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha44',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha45')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha45',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha46')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha46',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha47')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha47',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha49')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha49',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha50')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha50',@ColID OUTPUT
				
			update ADM_CostCenterDef
			set UserColumnName='Available Amount',UserColumnType='NUMERIC',ColumnDataType='FLOAT', SectionSeqNumber=1, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=25
			where CostCenterID=@VALUE and SysColumnName='ccalpha49'
			
			update ADM_CostCenterDef
			set UserColumnName='Actual Amount',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=26
			where CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update COM_LanguageResources
			set ResourceData='Available Amount'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha49'
			
			update COM_LanguageResources
			set ResourceData='Actual Amount'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
					
			update ADM_CostCenterDef
			set UserColumnName='WEF',UserColumnType='DATE',ColumnDataType='String', SectionSeqNumber=4, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=3, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=27
			where CostCenterID=@VALUE and SysColumnName='ccalpha45'
			
			update ADM_CostCenterDef
			set UserColumnName='Till Date',UserColumnType='DATE',ColumnDataType='String',SectionSeqNumber=5, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=3, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=28
			where CostCenterID=@VALUE and SysColumnName='ccalpha47'
			
			update COM_LanguageResources
			set ResourceData='WEF'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha45'
			
			update COM_LanguageResources
			set ResourceData='Till Date'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha47'

			update ADM_CostCenterDef
			set UserColumnName='Partial',UserColumnType='COMBOBOX',ColumnDataType='String', SectionSeqNumber=3, UserDefaultValue='',UserProbableValues='YES;NO',
					IsVisible=1,SectionID=@TabID, RowNo=3, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=27
			where CostCenterID=@VALUE and SysColumnName='ccalpha46'
			
			update COM_LanguageResources
			set ResourceData='Partial'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha46'
			
			
			update ADM_CostCenterDef
			set UserColumnName='Type',UserColumnType='COMBOBOX',ColumnDataType='String', SectionSeqNumber=2, UserDefaultValue='',UserProbableValues='Sales Return;Gift Voucher',
					IsVisible=1,SectionID=@TabID, RowNo=3, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=27
			where CostCenterID=@VALUE and SysColumnName='ccalpha44'
			
			update COM_LanguageResources
			set ResourceData='Type'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha44'

			update ADM_CostCenterDef
			set UserColumnName='Percentage',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=7, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=29
			where CostCenterID=@VALUE and SysColumnName='ccalpha43'
			
			update COM_LanguageResources
			set ResourceData='Percentage'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha43'

			
			update ADM_CostCenterDef
			set UserColumnName='Min Amount',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=8, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=29
			where CostCenterID=@VALUE and SysColumnName='ccalpha42'
			
			update COM_LanguageResources
			set ResourceData='Min Amount'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha42'
					
			
			
			update com_status
			set costcenterid=@VALUE,Featureid=@VALUE
			where statusid=476
			update ADM_CostCenterTab
			set IsVisible=1
			where CCTabID=@TabID
					
	END 
	ELSE if(@KEY='Loyalty' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			select @TabID=CCTabID from ADM_CostCenterTab with(nolock) 
			where CostCenterID=@VALUE and CCTabName='General'
			
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha47')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha47',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha48')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha48',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha49')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha49',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha50')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha50',@ColID OUTPUT
			
			update ADM_CostCenterDef
			set UserColumnName='WEF',UserColumnType='DATE',ColumnDataType='DATE', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=23
			where CostCenterID=@VALUE and SysColumnName='ccalpha47'
			
			update ADM_CostCenterDef
			set UserColumnName='Till date',UserColumnType='DATE',ColumnDataType='DATE',SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=24
			where CostCenterID=@VALUE and SysColumnName='ccalpha48'
			
			update COM_LanguageResources
			set ResourceData='WEF'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha47'
			
			update COM_LanguageResources
			set ResourceData='Till date'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha48'


			update ADM_CostCenterDef
			set UserColumnName='Billing Amount',UserColumnType='NUMERIC',ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=25
			where CostCenterID=@VALUE and SysColumnName='ccalpha49'
			
			update ADM_CostCenterDef
			set UserColumnName='Points',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=26
			where CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update COM_LanguageResources
			set ResourceData='Billing Amount'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha49'
			
			update COM_LanguageResources
			set ResourceData='Points'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update ADM_CostCenterTab
			set IsVisible=1
			where CCTabID=@TabID
					
	END 
	ELSE if(@KEY='PackDimension' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			select @TabID=CCTabID from ADM_CostCenterTab with(nolock) 
			where CostCenterID=@VALUE and CCTabName='General'
			
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha46')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha46',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha47')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha47',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha48')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha48',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha49')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha49',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha50')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha50',@ColID OUTPUT
				
			update ADM_CostCenterDef
			set UserColumnName='Length',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=22
			where CostCenterID=@VALUE and SysColumnName='ccalpha46'

			update ADM_CostCenterDef
			set UserColumnName='Width',UserColumnType='NUMERIC',ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=23
			where CostCenterID=@VALUE and SysColumnName='ccalpha47'
			
			update ADM_CostCenterDef
			set UserColumnName='Height',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=24
			where CostCenterID=@VALUE and SysColumnName='ccalpha48'

			update ADM_CostCenterDef
			set UserColumnName='Volume',UserColumnType='NUMERIC',ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=3, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=25
			where CostCenterID=@VALUE and SysColumnName='ccalpha49'
			
			update ADM_CostCenterDef
			set UserColumnName='Weight',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=3, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=26
			where CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update COM_LanguageResources
			set ResourceData='Length'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha46'
			
			update COM_LanguageResources
			set ResourceData='Width'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha47'
			
			update COM_LanguageResources
			set ResourceData='Height'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha48'

			update COM_LanguageResources
			set ResourceData='Volume'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha49'
			
			update COM_LanguageResources
			set ResourceData='Weight'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update ADM_CostCenterTab
			set IsVisible=1
			where CCTabID=@TabID
					
	END 
    ELSE if (@KEY='Report Template Dimension' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))    
    BEGIN    
		if exists(select TemplateNodeID from ACC_ReportTemplate with(nolock))
		BEGIN    
		 RAISERROR('-512',16,1)                  
		END    
		else
		BEGIN
			if @KEY='Report Template Dimension'
			BEGIN
				if(@VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY) and ISNUMERIC(@VALUE)=1 and @VALUE>50000 )
				begin
					set @CCID=@VALUE
					select @TabID=CCTabID from ADM_CostCenterTab with(nolock) where CostCenterID=@CCID and CCTabName='General'
					
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha40')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha40',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha41')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha41',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha42')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha42',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha43')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha43',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha44')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha44',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha45')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha45',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha46')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha46',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha47')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha47',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha48')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha48',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha49')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha49',@ColID OUTPUT
					if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha50')
						exec [SpADM_AddColumn] @VALUE,0,'Alpha50',@ColID OUTPUT
				
					--For Formula field					
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha50'

					update  COM_LanguageResources set ResourceData='Formula', ResourceName='Formula' where ResourceID=@Rid 

					update ADM_CostCenterDef set UserColumnName='Formula', UserColumnType='TEXTAREA', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=0, ColumnSpan=4,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=25 where CostCenterColID=@ColID

					--For Show Total field
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha49'
					update  COM_LanguageResources set ResourceData='Show Totals', ResourceName='Show Totals' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Show Totals', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='True',
					UserProbableValues='True;False;At End',IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=5 where CostCenterColID=@ColID
					--For Show Total Caption
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha46'
					update  COM_LanguageResources set ResourceData='Total Caption', ResourceName='Total Caption' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Total Caption', UserColumnType='TEXT', ColumnDataType='TEXT', SectionSeqNumber=0, UserDefaultValue='TOTAL',
					UserProbableValues='',IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=6 where CostCenterColID=@ColID

					--Positive Number
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha45'
					update  COM_LanguageResources set ResourceData='Positive Number', ResourceName='Positive Number' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Positive Number', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='',
					UserProbableValues=';-;+;Cr;Dr;(123)',IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=7 where CostCenterColID=@ColID					
					--Negative Number
					---123;123;(123);Cr;Dr;-/+;Cr/Dr;+/-;Dr/Cr
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha48'
					update  COM_LanguageResources set ResourceData='Negative Number', ResourceName='Negative Number' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Negative Number', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='-',
					UserProbableValues=';-;+;Cr;Dr;(123)',IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=8 where CostCenterColID=@ColID

					--For Show Bold
					select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha47'
					update  COM_LanguageResources set ResourceData='Show Bold', ResourceName='Show Bold' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Show Bold', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='False',
					UserProbableValues='True;False',IsVisible=1,SectionID=@TabID, RowNo=1, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=9 where CostCenterColID=@ColID
					
					--Opening Balance
					select Top 1 @ColID=CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha44'
					update  COM_LanguageResources set ResourceData='Opening Balance', ResourceName='Opening Balance' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Opening Balance', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='False',
					UserProbableValues='False;Show Opening;Show Closing',IsVisible=1,SectionID=@TabID, RowNo=1, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=10 where CostCenterColID=@ColID						
					
					--Show Details
					select Top 1 @ColID=CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha43'
					update  COM_LanguageResources set ResourceData='Show Details', ResourceName='Show Details' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Show Details', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='False',
					UserProbableValues='True;False',IsVisible=1,SectionID=@TabID, RowNo=1, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=11 where CostCenterColID=@ColID
					
					--Total Background
					select Top 1 @ColID=CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha42'
					update  COM_LanguageResources set ResourceData='Total Background', ResourceName='Total Background' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Total Background', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='No',
					UserProbableValues='Yes;No',IsVisible=1,SectionID=@TabID, RowNo=1, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=26 where CostCenterColID=@ColID	
					
					--Total Border
					select Top 1 @ColID=CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha41'
					update  COM_LanguageResources set ResourceData='Total Border', ResourceName='Total Border' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Total Border', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='None',
					UserProbableValues='None;All Borders;Bottom Border;Up Border;Double Border Bottom;Top and Bottom Border;Top and Double Bottom Border;Thick Box Border;Thick Bottom Border;Double Top and Double Bottom Border',IsVisible=1,SectionID=@TabID, RowNo=1, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=27 where CostCenterColID=@ColID	
					
					--Total Border apply to row
					select Top 1 @ColID=CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
					CostCenterID=@CCID and SysColumnName='ccAlpha40'
					update  COM_LanguageResources set ResourceData='Total Border apply to row', ResourceName='Total Border apply to row' where ResourceID=@Rid 
					update ADM_CostCenterDef set UserColumnName='Total Border apply to row', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='No',
					UserProbableValues='Yes;No',IsVisible=1,SectionID=@TabID, RowNo=1, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=28 where CostCenterColID=@ColID
					
					update ADM_CostCenterDef
					set IsVisible=0
					where costcenterid=@CCID and SysColumnName in('CreditDays','CreditLimit','PurchaseAccount','SalesAccount','DebitDays','DebitLimit')

					update ADM_CostCenterTab
					set IsVisible=0
					where CostCenterID=@CCID
					and CCTabName in('Address','Contacts','Assign','Notes','Attachments') 
				end
			END
		END
   END
   ELSE if (@KEY='POSItemCodeDimension' and ISNUMERIC(@VALUE)=1 and @VALUE>50000 and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))    
   BEGIN
		set @SQL=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY)
		if(ISNUMERIC(@SQL)=1 and convert(int,@SQL)>50000)
		begin
			 select 'Item Code Dimension Not Allowed To Change' ErrorMessage, -512 ErrorNumber
			 
			 ROLLBACK TRANSACTION    
			 SET NOCOUNT OFF      
			 RETURN -999  
		 end
		
		set @CCID=@VALUE

		select @TblName=TableName from Adm_Features with(nolock) where FeatureID=@CCID

		select @TabID=CCTabID from ADM_CostCenterTab with(nolock) where CostCenterID=@CCID and CCTabName='General'
		
		set @SQL=''
		select @SQL=@SQL+'
		ALTER TABLE ['+@TblName+'] DROP CONSTRAINT ['+o.name+'] ' from 
		sys.tables t
		inner join sys.Columns c on c.object_id=t.object_id
		inner join sys.objects o on t.object_id=o.parent_object_id and c.default_object_id=o.object_id
		where o.type='d' and t.name=@TblName
		and (c.name='CodeNumber' or c.name='GroupSeqNoLength')
		EXEC(@SQL)
		
		SET @SQL=''
		SELECT @SQL=@SQL+','+a.name
		FROM sys.columns a
		WHERE a.object_id= object_id(@TblName) and a.name LIKE 'ccAlpha%'
	
		set @SQL='ALTER TABLE ['+@TblName+'] DROP COLUMN AliasName,CreditDays,CreditLimit,PurchaseAccount,SalesAccount
  ,DebitDays,DebitLimit,CodePrefix,CurrencyID,CompanyGUID,[GUID],[Description],CreatedBy,CreatedDate,CodeNumber,GroupSeqNoLength'+@SQL
		EXEC(@SQL)
		
		set @SQL='ALTER TABLE ['+@TblName+'] ADD ProductID INT default(1) not null
		,DealerPrice float default(0) not null
		,RetailPrice float default(0) not null
		,EAN Nvarchar(100)
		,CCNodeID INT  default(1) not null
		,InvDocDetailsID INT
		,MRP Float
		,ProductType nvarchar(100)						
		,AvgPrice float
		,ImageName nvarchar(200) '
		EXEC(@SQL)
		
		select Top 1 @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) 
		where CostCenterID=@CCID and SysColumnName='CreditDays'
		update  COM_LanguageResources set ResourceData='Dealer Price', ResourceName='DealerPrice' where ResourceID=@Rid 
		update ADM_CostCenterDef set UserColumnName='Dealer Price',SysColumnName='DealerPrice',ShowInQuickAdd=1 where CostCenterColID=@ColID
		
		select Top 1 @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) 
		where CostCenterID=@CCID and SysColumnName='CreditLimit'
		update  COM_LanguageResources set ResourceData='Retail Price', ResourceName='RetailPrice' where ResourceID=@Rid 
		update ADM_CostCenterDef set UserColumnName='Retail Price',SysColumnName='RetailPrice',ShowInQuickAdd=1 where CostCenterColID=@ColID
		
		select Top 1 @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) 
		where CostCenterID=@CCID and SysColumnName='PurchaseAccount'
		update  COM_LanguageResources set ResourceData='Product', ResourceName='Product' where ResourceID=@Rid 
		update ADM_CostCenterDef set UserColumnName='Product',SysColumnName='ProductID',ShowInQuickAdd=1
		,ColumnCostCenterID=3,ColumnCCListViewTypeID=10,ParentCostCenterSysName='INV_Product',ParentCostCenterColSysName='ProductID'
		,ParentCCDefaultColID=262
		where CostCenterColID=@ColID
		
		select Top 1 @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) 
		where CostCenterID=@CCID and SysColumnName='DebitDays'
		update  COM_LanguageResources set ResourceData='EAN', ResourceName='EAN' where ResourceID=@Rid 
		update ADM_CostCenterDef set UserColumnName='EAN',SysColumnName='EAN',ShowInQuickAdd=1 where CostCenterColID=@ColID
		
		select Top 1 @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) 
		where CostCenterID=@CCID and SysColumnName='DebitLimit'
		update  COM_LanguageResources set ResourceData='CCNodeID', ResourceName='CCNodeID' where ResourceID=@Rid 
		update ADM_CostCenterDef set UserColumnName='CCNodeID',SysColumnName='CCNodeID',ShowInQuickAdd=1 where CostCenterColID=@ColID

		
		delete from COM_LanguageResources where ResourceID IN (
		select ResourceID from ADM_CostCenterDef with(nolock) where CostCenterID=@CCID and (SysColumnName like 'ccAlpha%' or SysColumnName like 'CCNID%'))
				
		delete from ADM_CostCenterDef where CostCenterID=@CCID and (SysColumnName like 'ccAlpha%' or SysColumnName like 'CCNID%')
		
		delete from COM_LanguageResources where ResourceID IN (
		select ResourceID from ADM_CostCenterDef with(nolock) where CostCenterID=@CCID and SysColumnName IN ('CurrencyID','AliasName','GroupSeqNoLength','SalesAccount'))
				
		delete from ADM_CostCenterDef where CostCenterID=@CCID and SysColumnName IN ('CurrencyID','AliasName','GroupSeqNoLength','SalesAccount')

		update ADM_CostCenterTab
		set IsVisible=0
		where CostCenterID=@CCID
		and CCTabName in('Address','Contacts','Assign','Notes','Attachments') 
		
		select @Rid=MAX(ResourceID) from COM_LanguageResources where ResourceID<500000
		select @colID=MAX([CostCenterColID]) from [ADM_CostCenterDef] where [CostCenterColID]<500000

		set @Rid=@Rid+1
		set @colID=@colID+1
		
		INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
		VALUES(@Rid,' MRP ',1,'English','MRP ','')

		INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
		VALUES(@Rid+1,' ProductType ',1,'English','ProductType ','')
		
		INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
		VALUES(@Rid+4,' AvgPrice ',1,'English','AvgPrice','')

		INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
		VALUES(@Rid+5,' QOH ',1,'English','QOH','')

		set identity_insert [ADM_CostCenterDef] on
		INSERT INTO [ADM_CostCenterDef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])
		VALUES(@CCID,@colID,@Rid,'Stock code',@TblName,'MRP','MRP ',NULL,'Text','String',NULL,NULL,4,0,0,1,1,0,0,0,0,0,NULL,0,NULL,0,0,NULL,0,0,0,1,NULL,'CompanyGUID','7492-4901-9327-5D8BF0866CFB',NULL,'ADMIN',4.089669224699074e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,1)
		
		INSERT INTO [ADM_CostCenterDef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])
		VALUES(@CCID,@colID+1,@Rid+1,'Stock code',@TblName,'ProductType','ProductType ',NULL,'Text','String',NULL,NULL,4,0,0,1,1,0,0,0,0,0,NULL,0,NULL,0,0,NULL,0,0,0,1,NULL,'CompanyGUID','7492-4901-9327-5D8BF0866CFB',NULL,'ADMIN',4.089669224699074e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,1)
	
		INSERT INTO [ADM_CostCenterDef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])
		VALUES(@CCID,@colID+4,@Rid+4,'Stock code',@TblName,'AvgPrice','AvgPrice ',NULL,'Text','String',NULL,NULL,4,0,0,1,1,0,0,0,0,0,NULL,0,NULL,0,0,NULL,0,0,0,1,NULL,'CompanyGUID','7492-4901-9327-5D8BF0866CFB',NULL,'ADMIN',4.089669224699074e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,1)
		
		INSERT INTO [ADM_CostCenterDef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])
		VALUES(@CCID,@colID+5,@Rid+5,'Stock code',@TblName,'StockQOH','StockQOH',NULL,'Text','String',NULL,NULL,4,0,0,1,1,0,0,0,0,0,NULL,0,NULL,0,0,NULL,0,0,0,1,NULL,'CompanyGUID','7492-4901-9327-5D8BF0866CFB',NULL,'ADMIN',4.089669224699074e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,1)
	
		set identity_insert [ADM_CostCenterDef] oFF
   END
   ELSE if(@KEY='DimensionwiseBins' and ISNUMERIC(@VALUE)=1 and CONVERT(INT,@VALUE)>50000 and @VALUE!=(select [Value] from  ADM_GlobalPreferences WHERE [Name]=@KEY))
   BEGIN
			select @TabID=CCTabID from ADM_CostCenterTab with(nolock) 
			where CostCenterID=@VALUE and CCTabName='General'		
			
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha50')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha50',@ColID OUTPUT
				
			update ADM_CostCenterDef
			set UserColumnName='Bin Wise',UserColumnType='COMBOBOX',ColumnDataType='String',SectionSeqNumber=0, UserDefaultValue='YES',UserProbableValues='YES;NO'
					,IsVisible=1,SectionID=@TabID, RowNo=2, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=26
			where CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update COM_LanguageResources
			set ResourceData='Bin Wise'
			from ADM_CostCenterDef with(nolock)
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update ADM_CostCenterTab
			set IsVisible=1
			where CCTabID=@TabID
					
	END	
	ELSE if(@KEY='TestCaseDimension' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
			select @TabID=CCTabID from ADM_CostCenterTab with(nolock) 
			where CostCenterID=@VALUE and CCTabName='General'
			
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha46')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha46',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha47')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha47',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha48')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha48',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha49')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha49',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@VALUE and SysColumnName='ccAlpha50')
				exec [SpADM_AddColumn] @VALUE,0,'Alpha50',@ColID OUTPUT
						
			update ADM_CostCenterDef
			set UserColumnName='Test Type',UserColumnType='COMBOBOX',ColumnDataType='String',SectionSeqNumber=0, UserDefaultValue='Numeric',UserProbableValues='Numeric;Visual'
					,IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=24
			where CostCenterID=@VALUE and SysColumnName='ccalpha46'
			
			update ADM_CostCenterDef
			set UserColumnName='Probable Values',UserColumnType='TEXT',ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=25
			where CostCenterID=@VALUE and SysColumnName='ccalpha47'
			
			update ADM_CostCenterDef
			set UserColumnName='Variance',UserColumnType='NUMERIC',ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=1, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=28
			where CostCenterID=@VALUE and SysColumnName='ccalpha48'
			
			update ADM_CostCenterDef
			set UserColumnName='Min',UserColumnType='NUMERIC',ColumnDataType='FLOAT', SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=2, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=26
			where CostCenterID=@VALUE and SysColumnName='ccalpha49'
			
			update ADM_CostCenterDef
			set UserColumnName='Max',UserColumnType='NUMERIC',ColumnDataType='FLOAT',SectionSeqNumber=0, UserDefaultValue='',
					IsVisible=1,SectionID=@TabID, RowNo=0, ColumnNo=3, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
					dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=27
			where CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update COM_LanguageResources
			set ResourceData='Test Type'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha46'
			
			update COM_LanguageResources
			set ResourceData='Probable Values[Use ;]'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha47'
			
			update COM_LanguageResources
			set ResourceData='Variance'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha48'
			
			update COM_LanguageResources
			set ResourceData='Min'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha49'
			
			update COM_LanguageResources
			set ResourceData='Max'
			from ADM_CostCenterDef
			where COM_LanguageResources.ResourceID=ADM_CostCenterDef.ResourceID and CostCenterID=@VALUE and SysColumnName='ccalpha50'
			
			update ADM_CostCenterTab
			set IsVisible=1
			where CCTabID=@TabID
					
	END
	ELSE if(@KEY='IsControlAccounts' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	BEGIN
		if exists (select RibbonViewID from ADM_RibbonView with(nolock) where RibbonViewID=34)
		begin
			if @VALUE='True'
			begin
				SET IDENTITY_INSERT [adm_featureaction] ON
				INSERT INTO [adm_featureaction] ([FeatureActionID],[Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
				VALUES(88,'Accounts Receivable',null,2,218,1,NULL,'Accounts Receivable',1,4,'Admin')

				INSERT INTO [adm_featureaction] ([FeatureActionID],[Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
				VALUES(89,'Accounts Payable',null,2,219,1,NULL,'Accounts Payable',1,4,'Admin')
				SET IDENTITY_INSERT [adm_featureaction] OFF

				insert into adm_featureactionrolemap(RoleID,FeatureActionID,Status,CreatedBy,CreatedDate)
				select RoleID,88,1,'admin',1 from adm_featureactionrolemap where FeatureActionID=2
				union all
				select RoleID,89,1,'admin',1 from adm_featureactionrolemap where FeatureActionID=2
			end
			else
			begin
				delete from adm_featureactionrolemap where FeatureActionID=88 or FeatureActionID=89
				delete from adm_featureaction where FeatureID=2 and (FeatureActionID=88 or FeatureActionID=89)
			end
		end
		else if @VALUE='True'
		begin
			SELECT @Rid=MAX([ResourceID])+1 FROM [Com_LanguageResources] WITH(NOLOCK)

			INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
			VALUES(@Rid,'Accounts Receivable',1,'English','Accounts Receivable','GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,'Receivable') 
			INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
			VALUES(@Rid,'Accounts Receivable',2,'Arabic','Accounts Receivable','GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,'Receivable') 

			INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
			VALUES(@Rid+1,'Accounts Payable',1,'English','Accounts Payable','GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,'Payable') 
			INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
			VALUES(@Rid+1,'Accounts Payable',2,'Arabic','Accounts Payable','GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,'Payable') 

			SET IDENTITY_INSERT [adm_featureaction] ON
			INSERT INTO [adm_featureaction] ([FeatureActionID],[Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES(88,'Accounts Receivable',null,2,218,1,NULL,'Accounts Receivable',1,4,'Admin')

			INSERT INTO [adm_featureaction] ([FeatureActionID],[Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES(89,'Accounts Payable',null,2,219,1,NULL,'Accounts Payable',1,4,'Admin')
			SET IDENTITY_INSERT [adm_featureaction] OFF

			insert into adm_featureactionrolemap(RoleID,FeatureActionID,Status,CreatedBy,CreatedDate)
			select RoleID,88,1,'admin',1 from adm_featureactionrolemap where FeatureActionID=2
			union all
			select RoleID,89,1,'admin',1 from adm_featureactionrolemap where FeatureActionID=2

			INSERT INTO [ADM_RibbonView] ([RibbonViewID],[TabID],[GroupID],[DrpID],[TabName],[GroupName],[DrpName],[TabResourceID],[GroupResourceID],[DrpResourceID],[TabOrder],[GroupOrder],[FeatureID],[FeatureActionID],[FeatureActionResourceID],[FeatureActionName],[TabKeyTip],[GroupKeyTip],[DrpKeyTip],[ButtonKeyTip],[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType],[ImagePath],[DrpImage],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID],[UserName],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DisplayName],[DisplayNameResourceID],[ColumnOrder],[ShowInWeb],[IsMobile],[AppPath],[ShowInMobile],[Version])
			VALUES(34,2,4,NULL,'Accounting','Chart Of Accounts','Accounts Receivable',32,65753,NULL,2,2,2,88,@Rid,'Accounts Receivable','D',NULL,NULL,'T',1,'Accounts Receivable',@Rid,1,'Accounts.png','Accounts.png',@Rid,'Accounts Receivable','Accounts.png',@Rid,'Accounts Receivable',1,1,'Admin','CompanyGUID','96095B791CA3','Accounts Receivable','Admin',4,NULL,NULL,'Accounts Receivable',@Rid,0,1,0,NULL,0,NULL)
			INSERT INTO [ADM_RibbonView] ([RibbonViewID],[TabID],[GroupID],[DrpID],[TabName],[GroupName],[DrpName],[TabResourceID],[GroupResourceID],[DrpResourceID],[TabOrder],[GroupOrder],[FeatureID],[FeatureActionID],[FeatureActionResourceID],[FeatureActionName],[TabKeyTip],[GroupKeyTip],[DrpKeyTip],[ButtonKeyTip],[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType],[ImagePath],[DrpImage],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID],[UserName],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DisplayName],[DisplayNameResourceID],[ColumnOrder],[ShowInWeb],[IsMobile],[AppPath],[ShowInMobile],[Version])
			VALUES(35,2,4,NULL,'Accounting','Chart Of Accounts','Accounts Payable',32,65753,NULL,2,3,2,89,@Rid+1,'Accounts Payable','D',NULL,NULL,'T',1,'Accounts Payable',@Rid+1,1,'Accounting.png','Accounting.png',@Rid+1,'Accounts Payable','Accounting.png',@Rid+1,'Accounts Payable',1,1,'Admin','CompanyGUID','096C213AE760','Accounts Payable','Admin',4,NULL,NULL,'Accounts Payable',@Rid+1,0,1,0,NULL,0,NULL)
		end
		
		if exists (select RibbonViewID from ADM_RibbonView with(nolock) where RibbonViewID=36)
		begin
			if @VALUE='True'
			begin
				SET IDENTITY_INSERT [adm_featureaction] ON
				INSERT INTO [adm_featureaction] ([FeatureActionID],[Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
				VALUES(155,'Sub Ledger',null,50,206,1,NULL,'Sub Ledger',1,4,'Admin')
				SET IDENTITY_INSERT [adm_featureaction] OFF

				insert into adm_featureactionrolemap(RoleID,FeatureActionID,Status,CreatedBy,CreatedDate)
				select RoleID,155,1,'admin',1 from adm_featureactionrolemap where FeatureActionID=1627
			end
			else
			begin
				delete from adm_featureactionrolemap where FeatureActionID=155
				delete from adm_featureaction where FeatureActionID=155
			end
		end
		else if @VALUE='True'
		begin
			SELECT @Rid=MAX([ResourceID])+1 FROM [Com_LanguageResources] WITH(NOLOCK)

			INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
			VALUES(@Rid,'Sub Ledger',1,'English','Sub Ledger','GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,'Receivable') 
			INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
			VALUES(@Rid,'Sub Ledger',2,'Arabic','Sub Ledger','GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,'Receivable') 

			SET IDENTITY_INSERT [adm_featureaction] ON
			INSERT INTO [adm_featureaction] ([FeatureActionID],[Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
			VALUES(155,'Sub Ledger',null,50,206,1,NULL,'Sub Ledger',1,4,'Admin')
			SET IDENTITY_INSERT [adm_featureaction] OFF

			insert into adm_featureactionrolemap(RoleID,FeatureActionID,Status,CreatedBy,CreatedDate)
			select RoleID,155,1,'admin',1 from adm_featureactionrolemap where FeatureActionID=1627

			INSERT INTO [ADM_RibbonView] ([RibbonViewID],[TabID],[GroupID],[DrpID],[TabName],[GroupName],[DrpName],[TabResourceID],[GroupResourceID],[DrpResourceID],[TabOrder],[GroupOrder],[FeatureID],[FeatureActionID],[FeatureActionResourceID],[FeatureActionName],[TabKeyTip],[GroupKeyTip],[DrpKeyTip],[ButtonKeyTip],[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType],[ImagePath],[DrpImage],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID],[UserName],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DisplayName],[DisplayNameResourceID],[ColumnOrder],[ShowInWeb],[IsMobile],[AppPath],[ShowInMobile],[Version])
			VALUES(36,2,26,111,'Accounting','Reports','',32,112096,16839,2,6,50,155,@Rid,'Sub Ledger','v','c',NULL,'1',1,'Sub Ledger',@Rid,1,'RPT_Pur_customerwise_report.png','RPT_Pur_customerwise_report.png',@Rid,'Sub Ledger','RPT_Pur_customerwise_report.png',@Rid,'Sub Ledger',1,1,'admin','CompanyGUID','09171FF5-4D7B-4946-AD0A-641520672AA3','Sub Ledger','admin',4,NULL,NULL,NULL,NULL,0,1,1,NULL,1,NULL)
		end
		
		 if @VALUE='True'
		 BEGIN
			 if not exists(select * from sys.columns where object_ID=object_ID('ACC_Accounts') and name='IsDrCr')
				alter table ACC_Accounts add IsDrCr BIT
		 END
		 else
		 begin
			if (select Count(*) from ACC_DocDetails with(nolock))>2
				RAISERROR('-222',16,1)
		 end
					
	END
	ELSE if(@KEY='PayrollProduct')
	BEGIN
		
		update Adm_CostCenterDef 
		Set UserDefaultValue=ISNULL(@VALUE,'') Where (CostCenterID between 40051 And 40063) And SysColumnName='ProductID' And isnull(userdefaultvalue,'')<>ISNULL(@VALUE,'')
		
		update Adm_CostCenterDef 
		Set UserDefaultValue=ISNULL(@VALUE,'') Where (CostCenterID between 40065 And 40091) And SysColumnName='ProductID' And isnull(userdefaultvalue,'')<>ISNULL(@VALUE,'')
	END
	ELSE if(@KEY='PayrollDefaultDrAccount')
	BEGIN
		if(ISNULL(@VALUE,0)>0)
		BEGIN
			update Adm_CostCenterDef 
			Set UserDefaultValue=ISNULL(@VALUE,'') Where (CostCenterID between 40051 And 40063) And SysColumnName='DebitAccount' And isnull(userdefaultvalue,'')<>ISNULL(@VALUE,'')
		
			update Adm_CostCenterDef 
			Set UserDefaultValue=ISNULL(@VALUE,'') Where (CostCenterID between 40065 And 40102) And SysColumnName='DebitAccount' And isnull(userdefaultvalue,'')<>ISNULL(@VALUE,'')
		END
	END
	ELSE if(@KEY='PayrollDefaultCrAccount')
	BEGIN
		if(ISNULL(@VALUE,0)>0)
		BEGIN
			update Adm_CostCenterDef 
			Set UserDefaultValue=ISNULL(@VALUE,'') Where (CostCenterID between 40051 And 40063) And SysColumnName='CreditAccount' And isnull(userdefaultvalue,'')<>ISNULL(@VALUE,'')
		
			update Adm_CostCenterDef 
			Set UserDefaultValue=ISNULL(@VALUE,'') Where (CostCenterID between 40065 And 40102) And SysColumnName='CreditAccount' And isnull(userdefaultvalue,'')<>ISNULL(@VALUE,'')
		END
	END
	ELSE if(@KEY='UseDailyAttRates')
	BEGIN
		if @VALUE='True'
		BEGIN
			Update ADM_CostCenterDef SET IsVisible=1
			WHERE CostCenterID=40067 AND LocalReference=79 AND LinkData=(Select CostCenterColID FROM ADM_CostCenterDef WHERE CostCenterID=79 AND SysColumnName='PayOTRate')
		END
		ELSE
		BEGIN
			Update ADM_CostCenterDef SET IsVisible=0
			WHERE CostCenterID=40067 AND LocalReference=79 AND LinkData=(Select CostCenterColID FROM ADM_CostCenterDef WHERE CostCenterID=79 AND SysColumnName='PayOTRate')
		END
	END
	else if(@KEY='LWAccPeriod' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	begin
		if @VALUE='True'
		begin
			
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=50002 and SysColumnName='ccAlpha41')
				exec [SpADM_AddColumn] 50002,0,'Alpha41',@ColID OUTPUT
			if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=50002 and SysColumnName='ccAlpha42')
				exec [SpADM_AddColumn] 50002,0,'Alpha42',@ColID OUTPUT
				
			--For Accounting Date			
			select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
			CostCenterID=50002 and SysColumnName='ccAlpha42'

			update  COM_LanguageResources set ResourceData='Accounting Date', ResourceName='Accounting Date' where ResourceID=@Rid 
			update ADM_CostCenterDef set UserColumnName='Accounting Date', UserColumnType='DATE', ColumnDataType='DATE', SectionSeqNumber=0, UserDefaultValue='',
			IsVisible=1,SectionID=null, RowNo=12, ColumnNo=0, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
			dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=25 where CostCenterColID=@ColID

			--For Start Month
			select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
			CostCenterID=50002 and SysColumnName='ccAlpha41'
			update  COM_LanguageResources set ResourceData='Accounting Period Start Month', ResourceName='Accounting Period Start Month' where ResourceID=@Rid 
			update ADM_CostCenterDef set UserColumnName='Accounting Period Start Month', UserColumnType='COMBOBOX', ColumnDataType='String', SectionSeqNumber=0, UserDefaultValue='1',
			UserProbableValues='',IsVisible=1,SectionID=null, RowNo=12, ColumnNo=1, ColumnSpan=1,IsColumnDeleted=0,IsColumnInUse=1, LinkData=0, LocalReference=0, TextFormat=0, 
			dependancy=0, dependanton=0, cformula='',ShowInQuickAdd=1,QuickAddOrder=26 where CostCenterColID=@ColID
		end
		else
		begin
			select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
			CostCenterID=50002 and SysColumnName='ccAlpha42'
			update ADM_CostCenterDef set IsColumnInUse=0 where CostCenterColID=@ColID

			select Top 1  @ColID =CostCenterColID, @Rid=resourceid from ADM_CostCenterDef with(nolock) where 
			CostCenterID=50002 and SysColumnName='ccAlpha41'
			update ADM_CostCenterDef set IsColumnInUse=0 where CostCenterColID=@ColID
		end
	end
	else if(@KEY='DepositLinkDimension' and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	begin
		if(@VALUE is not null and @VALUE <>'' and isnumeric(@VALUE)=1 and convert(int,@VALUE)>50000)
		begin
			UPDATE ADM_CostCenterDef SET ParentCostCenterID=FeatureID,ParentCostCenterSysName=TableName,ParentCostCenterColSysName=PrimaryKey,ParentCCDefaultColID=(SELECT TOP 1 CostCenterColID FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=FeatureID AND SysColumnName='Name')
			FROM ADM_Features WITH(NOLOCK)  
			WHERE FeatureID=@VALUE AND CostCenterID in (95,103,104,129) 
			and (SysTableName like '%Particulars' or  SysTableName like '%PayTerms')
			and (SysColumnName='CCNodeID' or SysColumnName='Particular' ) 
		end 
	end  
    else if((@KEY='Blockuserafterattempts' or @KEY='Blockuserforminutes' or @KEY='RestrictedAcessDimension') and @VALUE!=(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]=@KEY))
	begin
		if(isnumeric(@VALUE)=1)
		begin
			if(@KEY='Blockuserafterattempts')
				update PACT2C.dbo.ADM_Company set BlockCount=convert(int,@VALUE) where DBName=DB_Name()
			else if(@KEY='Blockuserforminutes')
				update PACT2C.dbo.ADM_Company set BlockMinutes=convert(int,@VALUE) where DBName=DB_Name()
			else if(@KEY='RestrictedAcessDimension')
				update PACT2C.dbo.ADM_Company set RestrictedDim=convert(int,@VALUE) where DBName=DB_Name()
		end
	end
	
	UPDATE ADM_GlobalPreferences     
	SET [Value]=@VALUE,    
	[ModifiedBy]=@UserName,    
	[ModifiedDate]=convert(float,getdate())    
	WHERE [Name]=@KEY    
	SET @I=@I+1    
       
  END

	if(@ProjMDim is not null and @ProjMDim>0)
	BEGIN	
			SET @I=0
			WHILE (@I<26)
			BEGIN
				SET @I=@I+1 
				SET @KEY='Alpha42'+CONVERT(NVARCHAR,@I)   
				if not exists (select * from ADM_CostCenterDef with(nolock) where CostCenterID=@ProjMDim and SysColumnName='cc'+@KEY)
					exec [SpADM_AddColumn] @ProjMDim,0,@KEY,@ColID OUTPUT
			END
			
			update ADM_CostCenterDef
			set UserColumnName='Project name',ColumnCostCenterID=@ProjMDim,columncclistviewtypeid=2,Iscolumninuse=1,isvisible=1,UserColumnType='LISTBOX',sectionid=2,sectionName='Project'
			from adm_documenttypes b WITH(NOLOCK)
			where ADM_CostCenterDef.CostCenterid=b.CostCenterid and documenttype=45 and syscolumnname='dcalpha10'
						
			update COM_LanguageResources
			set ResourceData='Project name'
			from ADM_CostCenterDef a WITH(NOLOCK)
			join adm_documenttypes b WITH(NOLOCK) on a.CostCenterid=b.CostCenterid
			where COM_LanguageResources.ResourceID=a.ResourceID and documenttype=45 and syscolumnname='dcalpha10'
			
			Update com_documentpreferences
			set prefvalue=@ProjMDim
			where documenttype=45 and prefname='DocumentLinkDimension'
			
			Update com_documentpreferences
			set prefvalue='true'
			where documenttype=45 and prefname='GenerateSeq'
			
			update com_costcenterpreferences
			set value='true'
			where costcenterid=@ProjMDim and name ='DefaultCollapse'

			select @ColID=cctabid from adm_costcentertab WITH(NOLOCK)
			where costcenterid=@ProjMDim and cctabname='General'
			
			update adm_costcentertab
			set isvisible=1
			where cctabid=@ColID
			
			update adm_costcenterdef 
			set isvisible=0
			where costcenterid=@ProjMDim and sectionid=@ColID
			and syscolumnname like 'dcalpha%' and iscolumninuse=1	
			
			update b 
			set usercolumnname=a.usercolumnname,iscolumninuse=1,isvisible=1,usercolumntype=a.usercolumntype,sectionid=@ColID
			from adm_costcenterdef a WITH(NOLOCK)
			join adm_costcenterdef b WITH(NOLOCK) on a.syscolumnname=replace(b.syscolumnname,'ccAlpha','dcalpha')
			where a.costcenterid=40045 and b.costcenterid=@ProjMDim
			and a.syscolumnname like 'dcalpha%' and a.iscolumninuse=1	
			and b.syscolumnname in('ccAlpha12','ccAlpha13','ccAlpha14','ccAlpha18','ccAlpha19','ccAlpha20','ccAlpha21')

			update b 
			set usercolumnname=a.usercolumnname,iscolumninuse=1,isvisible=1,usercolumntype='TEXT',sectionid=@ColID,IsEditable=0
			from adm_costcenterdef a WITH(NOLOCK)
			join adm_costcenterdef b WITH(NOLOCK) on a.syscolumnname=replace(b.syscolumnname,'ccAlpha','dcalpha')
			where a.costcenterid=40045 and b.costcenterid=@ProjMDim
			and a.syscolumnname like 'dcalpha%' and a.iscolumninuse=1	
			and b.syscolumnname in('ccAlpha15','ccAlpha16','ccAlpha17','ccAlpha22','ccAlpha23','ccAlpha24')

			update adm_costcenterdef 
			set usercolumnname=b.name,iscolumninuse=1,isvisible=1,sectionid=@ColID
			from adm_globalpreferences a WITH(NOLOCK)			
			join adm_features b WITH(NOLOCK) on a.value=b.featureid
			where adm_costcenterdef.costcenterid=@ProjMDim
			and a.name in('PMLevel1Dimension','PMLevel2Dimension','PMLevel3Dimension','PMTaskDimension') and isnumeric(value)=1
			and Columncostcenterid=a.value 
			
			update com_languageresources 
			set resourcedata=usercolumnname
			from adm_costcenterdef a WITH(NOLOCK)			
			where com_languageresources.resourceid=a.resourceid and a.costcenterid=@ProjMDim
			and (a.syscolumnname like 'ccalpha%' or a.syscolumnname like 'ccnid%') and a.iscolumninuse=1	
			
			
			declare @TBLcols table(ID int identity(1,1),Colid INT)
			insert into @TBLcols
			select CostcenterCOlid from adm_costcenterdef WITH(NOLOCK)
			where costcenterid=@ProjMDim and iscolumninuse=1 and 	sectionid=@ColID and IsVisible=1	
			
			set @r=0
			set @c=0
			
			set @icnt=0
			set @cnt=(select count(*) from @TBLcols)
			while @icnt<@cnt
			begin
				set @icnt=@icnt+1  
				
				Select @Colid=Colid from @TBLcols where ID=@icnt
				
				if(@c>3)
				begin
					set @r=@r+1
					set @c=0
				end
				  	  
				update adm_costcenterdef set COLUMNSPAN=1,RowNo=@r, ColumnNo=@c 
				where costcentercolid=@Colid 
				
				set @c=@c+1				
			end
			
			update [COM_Status]
			set costcenterid=14,featureid=14
			where costcenterid=@ProjMDim and featureid=@ProjMDim

			update [COM_Status]
			set costcenterid=@ProjMDim,featureid=@ProjMDim
			where Statusid in(472,473,474,475)
			
			update ADM_FeatureAction
			set FeatureID=@ProjMDim
			where FeatureActionID=149
			
	END
	
	
  if exists(select value from adm_globalpreferences with(nolock) where name='POSEnable' and value='True') and not exists(select name from sys.columns where name='PosSessionID' and object_id IN (select object_id from sys.objects where name='COM_DocID'))
  begin
	alter table COM_DocID add PosSessionID INT not null default(0)
  end

	IF @CostCenterID=10 AND @FinancialYearsXml<>'' AND @FinancialYearsXml IS NOT NULL    
	BEGIN    
		DELETE FROM ADM_FinancialYears where InvClose=0
		SET @DATA=@FinancialYearsXml    
		   
		INSERT INTO ADM_FinancialYears (FromDate,ToDate,AccountID,LocationID,CompanyGUID,GUID,CreatedBy,CreatedDate)    
		SELECT  CONVERT(FLOAT,X.value('@FromDate','DATETIME')),CONVERT(FLOAT,X.value('@ToDate','DATETIME'))
		,X.value('@AccountID','INT'),isnull(X.value('@LocationID','INT'),1)
		,@CompanyGUID,@GUID,@UserName,CONVERT(FLOAT,getdate())    
		FROM @DATA.nodes('/FinancialYears/Row') as DATA(X)    
	END
	IF @CostCenterID=10 AND @LockedDatesXml<>'' AND @LockedDatesXml IS NOT NULL    
	BEGIN    
		DELETE FROM ADM_LockedDates WHERE CostCenterID=0
		SET @DATA=@LockedDatesXml    
		   
		INSERT INTO ADM_LockedDates (FromDate,ToDate,isEnable,CostCenterID)    
		SELECT  CONVERT(FLOAT,X.value('@FromDate','DATETIME')),    
		 CONVERT(FLOAT,X.value('@ToDate','DATETIME')),    
		X.value('@isEnable','BIT'),0
		FROM @DATA.nodes('/LockedDates/Row') as DATA(X)    
	END
	IF @CostCenterID=10 AND @BRSLockedDatesXml<>'' AND @BRSLockedDatesXml IS NOT NULL    
	BEGIN    
		DELETE FROM ADM_BRSLockedDates
		SET @DATA=@BRSLockedDatesXml    
		   
		INSERT INTO ADM_BRSLockedDates (FromDate,ToDate,isEnable,AccountID)    
		SELECT  CONVERT(FLOAT,X.value('@FromDate','DATETIME')),    
		 CONVERT(FLOAT,X.value('@ToDate','DATETIME')),    
		X.value('@isEnable','BIT'),X.value('@AccountID','INT')
		FROM @DATA.nodes('/BRSLockedDates/Row') as DATA(X)    
	END
	IF @CostCenterID=10 AND @RegisterPreferenceXML<>'' AND @RegisterPreferenceXML IS NOT NULL    
	BEGIN    
		DELETE FROM ADM_RegisterPreferences 
		SET @DATA=@RegisterPreferenceXML    
		   
		INSERT INTO ADM_RegisterPreferences (RegisterID,RightPanelWidth,RowSize,CostCenterID,TouchScreen,ButtonHeight,ButtonWidth,LevelProfile,PaymentModes,ActionHeight,ActionWidth)    
		SELECT X.value('@RegisterID','INT'),    
		X.value('@RightPanelWidth','INT'),
		X.value('@RowSize','INT'),    
		X.value('@CostCenterID','INT'),
		X.value('@TouchScreen','BIT'),
		X.value('@Height','INT'),
		X.value('@Width','INT'),
		X.value('@LevelProfile','INT'),
		X.value('@PaymentModes','NVARCHAR(MAX)'),
		X.value('@ActionHeight','INT'),
		X.value('@ActionWidth','INT')
		FROM @DATA.nodes('/RegisterPreferences/Row') as DATA(X)    
	END
	if @CostCenterID=10 and @CrossDimensionXml<>'' and @CrossDimensionXml is not null
	BEGIN
		DELETE FROM ADM_CrossDimension 
		
		
		set @VALUE=''
		select @VALUE=@VALUE+','+name from sys.columns
		where object_id=object_id('ADM_CrossDimension')
		and name like 'Dcccnid%'
		order by name
		
		set @Sql='INSERT INTO ADM_CrossDimension
           ([Dimension],[DimIn],[DimFor],[Document],[DrAccount],[CrAccount],[CompanyGUID],[GUID],
           [CreatedBy],[CreatedDate]'+@VALUE+')
			SELECT
           X.value(''@Dimension'',''INT''),X.value(''@DimIn'',''INT''),X.value(''@DimFor'',''INT''),
           X.value(''@Document'',''INT''),X.value(''@DrAccount'',''INT''),X.value(''@CrAccount'',''INT''),
           @CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,getdate())'
		select @Sql=@Sql+',X.value(''@'+name+''',''INT'')' from sys.columns
		where object_id=object_id('ADM_CrossDimension')
		and name like 'Dcccnid%'
		order by name
		
		set @Sql=@Sql+'FROM @DATA.nodes(''/CrossDimension/Row'') as DATA(X)   '
			
		SET @DATA=@CrossDimensionXml    
	print @Sql
		EXEC sp_executesql @sql,N'@DATA xml,@CompanyGUID NVARCHAR(50),@UserName NVARCHAR(50)',@DATA,@CompanyGUID,@UserName
		
	END
	else if(@CostCenterID=10 and @CrossDimensionXml='')
		delete from ADM_CrossDimension 
		
	if @CostCenterID=10 and @QtyAdjustmentXml<>'' and @QtyAdjustmentXml is not null
	BEGIN
		update ADM_CostCenterDef
		set IsColumnInUse=0
		where CostCenterID=403
		    
		SET @DATA=@QtyAdjustmentXml    
 
 
		update ADM_CostCenterDef
		set IsColumnInUse=1,Cformula= X.value('@Formula','nvarchar(500)')
		,UserColumnName= X.value('@FieldName','nvarchar(50)'),UserDefaultValue= X.value('@DefaultValue','nvarchar(50)')
		,IsMandatory= X.value('@Validate','smallint')
		,Decimal= X.value('@Decimal','INT')
		,LocalReference= X.value('@LocalRef','INT'),LinkData= X.value('@LinkData','INT')
		from @DATA.nodes('/QtyAdjustmentFields/Row') as DATA(X) 
		where CostCenterID=403 and SysColumnName= X.value('@SyscolumnName','nvarchar(50)')
		
		update COM_LanguageResources
		set ResourceData= X.value('@FieldName','nvarchar(50)')
		from @DATA.nodes('/QtyAdjustmentFields/Row') as DATA(X) 
		join ADM_CostCenterDef a with(nolock) on a.SysColumnName= X.value('@SyscolumnName','nvarchar(50)')
		where CostCenterID=403 and COM_LanguageResources.ResourceID=a.ResourceID and LanguageID=@LangID
		  
	END
	else if(@CostCenterID=10 and @QtyAdjustmentXml='')
	BEGIN
		update ADM_CostCenterDef
		set IsColumnInUse=0
		where CostCenterID=403 	
	END
		
    IF @CostCenterID=10 AND @PenaltyDocXml<>'' AND @PenaltyDocXml IS NOT NULL    
	BEGIN    
		DELETE FROM ADM_PenaltyDoc WHERE CostCenterID=10
		SET @DATA=@PenaltyDocXml    
		   
		INSERT INTO ADM_PenaltyDoc (TypeID,Type,AccountID,ProductID,CostCenterID)    
		SELECT  X.value('@TypeID','INT'), X.value('@Type','nvarchar(50)'), X.value('@AccountID','INT'),X.value('@ProductID','INT')  ,10
		FROM @DATA.nodes('/PenaltyDoc/Row') as DATA(X)    
	END
    if @LWEmailXML is not null
		update ADM_GLOBALPREFERENCES set Value=@LWEmailXML where Name='LWEmailXml'


	if @DSCGridXML IS NOT NULL AND @DSCGridXML<>''
		update ADM_GLOBALPREFERENCES set Value=@DSCGridXML where Name='DigitalSignGridData'

	declare @AuditTrial bit
	set @AuditTrial=(select value from adm_globalpreferences with(nolock) where name='AllowAuditTrialinAllDocs') 
	if(@AuditTrial=1)
	BEGIN
		update Com_DocumentPreferences set prefvalue='True' WHERE prefname='AuditTrial' 
	END		
	else
	BEGIN
		update Com_DocumentPreferences set prefvalue='False' WHERE prefname='AuditTrial' 
	END		

--ROLLBACK TRANSACTION
COMMIT TRANSACTION

SELECT * FROM ADM_GlobalPreferences WITH(NOLOCK)     
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
