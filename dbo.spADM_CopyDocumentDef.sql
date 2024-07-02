USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_CopyDocumentDef]
	@DocumentTypeID [int],
	@ColIDs [nvarchar](max),
	@DocumentsList [nvarchar](max),
	@ReportsList [nvarchar](max),
	@isLink [bit],
	@CopyActions [bit],
	@CopyLayout [bit],
	@UserName [nvarchar](200),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION                
BEGIN TRY                
SET NOCOUNT ON;              
    --Declaration Section              
	DECLARE @SQL NVARCHAR(MAX)
	DECLARE @HasAccess BIT,@DocumentID int,@DocumentColID INT,@I int, @Cnt int,@AllowDDHistory BIT,@CostCenterID INT,@CostCenterColID INT,@ColI int, @ColCnt int
	SELECT @CostCenterID=CostCenterID FROM ADM_DocumentTypes WITH(NOLOCK) WHERE DocumentTypeID=@DocumentTypeID
	declare @TblCols as Table(ID int identity(1,1),ColID INT)
	
  	DECLARE @DT float
	set @DT=CONVERT(float,getdate())
	
	insert into @TblCols(ColID)
	exec SPSplitString @ColIDs,','	
	
	if(SELECT Value FROM ADM_GlobalPreferences with(nolock) WHERE Name='DocumentDesignerHistory')='TRUE'
		set @AllowDDHistory=1
	else
		set @AllowDDHistory=0
			
	create table #TAB(ID INT IDENTITY(1,1),DocumentID NVARCHAR(10),IsCopied BIT DEFAULT(0))
	
	INSERT INTO #TAB (DocumentID)
	exec SPSplitString @DocumentsList,','  
	
	if(@CopyActions=1 or @CopyLayout=1)
	BEGIN
		SELECT @I=1,@Cnt=COUNT(*) FROM #TAB with(nolock)
		WHILE @I<=@Cnt              
		BEGIN   
			SELECT @DocumentID=CONVERT(INT,DocumentID) FROM #TAB with(nolock) WHERE ID=@I
			
			if(@CopyLayout=1)
			BEGIN
				UPDATE DST SET 
				SectionID=SRC.SectionID,SectionName=SRC.SectionName,SectionSeqNumber=SRC.SectionSeqNumber
				,RowNo=SRC.RowNo,ColumnNo=SRC.ColumnNo,ColumnSpan=SRC.ColumnSpan,UIWidth=SRC.UIWidth
				FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
				JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName
				WHERE SRC.CostCenterID=@CostCenterID AND   DST.CostCenterID=@DocumentID
				AND DST.IsColumnInUse=1 AND SRC.IsColumnInUse=1
			END	
			
			if(@CopyActions=1)
			BEGIN
				update com_documentpreferences
				set prefvalue=(select prefvalue from com_documentpreferences WITH(NOLOCK) where PrefName= 'RightButtons' and costcenterid=@CostCenterID)
				where CostCenterID=@DocumentID and PrefName= 'RightButtons'
				
				update com_documentpreferences
				set prefvalue=(select prefvalue from com_documentpreferences WITH(NOLOCK) where PrefName='LeftButtons' and costcenterid=@CostCenterID)
				where CostCenterID=@DocumentID and PrefName= 'LeftButtons'
			END
			
			SET @I=@I+1   
		END
	END
	
	SELECT @ColI=1,@ColCnt=COUNT(*) FROM @TblCols
	WHILE @ColI<=@ColCnt              
	BEGIN
		SELECT @CostCenterColID=ColID FROM @TblCols WHERE ID=@ColI

		SELECT @I=1,@Cnt=COUNT(*) FROM #TAB with(nolock)
		WHILE @I<=@Cnt              
		BEGIN   
			SELECT @DocumentID=CONVERT(INT,DocumentID) FROM #TAB with(nolock) WHERE ID=@I
			--User access check               
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@DocumentID,10)
			
			IF @HasAccess<>0              
			BEGIN			
					
				IF NOT EXISTS(SELECT * FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
				JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName AND DST.CostCenterID=@DocumentID
				WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID)
				BEGIN
				
					DECLARE @RID INT
					SELECT @RID=MAX(ResourceID)+1 FROM COM_LanguageResources WITH(NOLOCK) WHERE ResourceID<500000

					INSERT INTO [COM_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID]
					,[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
					SELECT @RID,SRC.SysColumnName,1,'English',SRC.UserColumnName,NEWID(),NULL,SRC.CreatedBy,CONVERT(FLOAT,GetDate()),NULL,NULL,
					(SELECT TOP 1 CostCenterName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@DocumentID)
					FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
					LEFT JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName AND DST.CostCenterID=@DocumentID
					WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID
						
						
					INSERT INTO [COM_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID]
					,[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
					SELECT @RID,SRC.SysColumnName,2,'Arabic',SRC.UserColumnName,NEWID(),NULL,SRC.CreatedBy,CONVERT(FLOAT,GetDate()),NULL,NULL,
					(SELECT TOP 1 CostCenterName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@DocumentID)
					FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
					LEFT JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName AND DST.CostCenterID=@DocumentID
					WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID
				
					DECLARE @strColIDs NVARCHAR(MAX)
					set @SQL=''
					set @strColIDs=''

					IF EXISTS(SELECT SysColumnName FROM ADM_CostCenterDef WHERE CostCenterID=@CostCenterID AND CostCenterColID=@CostCenterColID AND SysColumnName LIKE 'dcNUM%')
					BEGIN
						SET @SQL='SELECT @strColIDs=STUFF((SELECT '',''+CONVERT(NVARCHAR,CostCenterColID) FROM ADM_CostCenterDef WITH(NOLOCK)  
						WHERE CostCenterID=a.CostCenterID
						AND (SysColumnName LIKE ''dcNUM''+REPLACE(a.SysColumnName,''dcNUM'','''')
						OR SysColumnName LIKE ''dcCalcNum''+REPLACE(a.SysColumnName,''dcNUM'','''')
						OR SysColumnName LIKE ''dcCalcNumFC''+REPLACE(a.SysColumnName,''dcNUM'','''')
						OR SysColumnName LIKE ''dcExchRT'' +REPLACE(a.SysColumnName,''dcNUM'','''')
						OR SysColumnName LIKE ''dcCurrID''+REPLACE(a.SysColumnName,''dcNUM'','''') 
						OR SysColumnName=a.SysColumnName)
						FOR XML PATH('''')),1,1,'''')

						FROM ADM_CostCenterDef a WITH(NOLOCK)
						WHERE CostCenterID='+convert(nvarchar,@CostCenterID)+' AND CostCenterColID='+convert(nvarchar,@CostCenterColID)
						Exec sp_executesql @SQL,N'@strColIDs NVARCHAR(MAX) OUTPUT ',@strColIDs OUTPUT
					END
					ELSE
					SET @strColIDs=@CostCenterColID

					set @SQL='
					INSERT INTO [ADM_CostCenterDef] 
				    (CostCenterID
					,ResourceID
					,CostCenterName
				    ,SysTableName
				    ,UserColumnName
				    ,SysColumnName
					,UserColumnType
					,ColumnDataType
					,UserDefaultValue
					,UserProbableValues
					,ColumnOrder
					,IsMandatory
					,IsEditable
					,IsVisible
					,IsColumnUserDefined
					,ColumnCostCenterID
					,ColumnCCListViewTypeID
					,FetchMaxRows
					,SectionSeqNumber
					,SectionID
					,SectionName
					,RowNo
					,ColumnNo
					,ColumnSpan
					,IsColumnInUse
					,UIWidth
					,CompanyGUID
					,[GUID]
					,CreatedBy
					,CreatedDate
					,ModifiedBy
					,ModifiedDate
					,IsUnique
					,IsForeignKey
					,ParentCostCenterID
					,ParentCostCenterColID
					,ParentCostCenterSysName
					,ParentCostCenterColSysName
					,ParentCCDefaultColID
					,LinkData
					,LocalReference
					,[Decimal]
					,TextFormat
					,Filter
					,IsRepeat
					,LastValueVouchers
					,IsnoTab
					,dependancy
					,dependanton
					,IsTransfer
					,DbFilter
					,CrFilter
					,ShowInQuickAdd
					,QuickAddOrder
					,Calculate
					,Cformula
					,IsReEvaluate)
				 	SELECT '+convert(nvarchar,@DocumentID)+'
				    ,'+convert(nvarchar,@RID)+'
				    ,(SELECT TOP 1 CostCenterName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID='+convert(nvarchar,@DocumentID)+')
				    ,(SELECT SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND CostCenterColID='+convert(nvarchar,@CostCenterColID)+' )
				    ,SRC.UserColumnName
				    ,SRC.SysColumnName
					,SRC.UserColumnType
					,SRC.ColumnDataType
					,SRC.UserDefaultValue
					,SRC.UserProbableValues
					,SRC.ColumnOrder
					,SRC.IsMandatory
					,SRC.IsEditable
					,SRC.IsVisible
					,SRC.IsColumnUserDefined
					,SRC.ColumnCostCenterID
					,SRC.ColumnCCListViewTypeID
					,SRC.FetchMaxRows
					,SRC.SectionSeqNumber
					,SRC.SectionID
					,SRC.SectionName
					,SRC.RowNo
					,SRC.ColumnNo
					,SRC.ColumnSpan
					,SRC.IsColumnInUse
					,SRC.UIWidth
					,SRC.CompanyGUID
					,NEWID()
					,SRC.CreatedBy
					,SRC.CreatedDate
					,'''+convert(nvarchar,@UserName)+'''
					,'''+convert(nvarchar,@DT)+'''
					,SRC.IsUnique
					,SRC.IsForeignKey
					,SRC.ParentCostCenterID
					,SRC.ParentCostCenterColID
					,SRC.ParentCostCenterSysName
					,SRC.ParentCostCenterColSysName
					,SRC.ParentCCDefaultColID
					,SRC.LinkData
					,SRC.LocalReference
					,SRC.[Decimal]
					,SRC.TextFormat
					,SRC.Filter
					,SRC.IsRepeat
					,SRC.LastValueVouchers
					,SRC.IsnoTab
					,SRC.dependancy
					,SRC.dependanton
					,SRC.IsTransfer
					,SRC.DbFilter
					,SRC.CrFilter
					,SRC.ShowInQuickAdd
					,SRC.QuickAddOrder
					,SRC.Calculate
					,SRC.Cformula
					,SRC.IsReEvaluate
					FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
					LEFT JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName AND DST.CostCenterID='+convert(nvarchar,@DocumentID)+' 
					WHERE SRC.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND SRC.CostCenterColID IN('+@strColIDs+')'
					Exec sp_executesql @SQL

				END
				
				IF EXISTS (SELECT * FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
				JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName AND DST.CostCenterID=@DocumentID
				WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID AND (DST.IsColumnInUse=0 or DST.IsColumnUserDefined=0))
				BEGIN
					if(@AllowDDHistory=1 and (select COUNT(*) from ADM_CostCenterDef_History with(nolock) where CostCenterID=@DocumentID)=0)
					begin
						insert into ADM_CostCenterDef_History
						select * from ADM_CostCenterDef_History with(nolock) where CostCenterID=@DocumentID
					end
					
					UPDATE DST SET DST.UserColumnName=SRC.UserColumnName
					,DST.UserColumnType=SRC.UserColumnType
					,DST.UserDefaultValue=SRC.UserDefaultValue
					,DST.UserProbableValues=SRC.UserProbableValues
					,DST.IsMandatory=SRC.IsMandatory
					,DST.IsEditable=SRC.IsEditable
					,DST.IsVisible=SRC.IsVisible
					,DST.ColumnCostCenterID=SRC.ColumnCostCenterID
					,DST.ColumnCCListViewTypeID=SRC.ColumnCCListViewTypeID
					,DST.FetchMaxRows=SRC.FetchMaxRows
					,DST.SectionSeqNumber=SRC.SectionSeqNumber
					,DST.SectionID=SRC.SectionID
					,DST.SectionName=SRC.SectionName
					,DST.RowNo=SRC.RowNo
					,DST.ColumnNo=SRC.ColumnNo
					,DST.ColumnSpan=SRC.ColumnSpan
					,DST.IsColumnInUse=SRC.IsColumnInUse
					,DST.UIWidth=SRC.UIWidth
					,DST.ModifiedBy=@UserName
					,DST.ModifiedDate=@DT
					,DST.IsUnique=SRC.IsUnique
					,DST.IsForeignKey=SRC.IsForeignKey
					,DST.ParentCostCenterID=SRC.ParentCostCenterID
					,DST.ParentCostCenterColID=SRC.ParentCostCenterColID
					,DST.ParentCostCenterSysName=SRC.ParentCostCenterSysName
					,DST.ParentCostCenterColSysName=SRC.ParentCostCenterColSysName
					,DST.ParentCCDefaultColID=SRC.ParentCCDefaultColID
					,DST.LinkData=SRC.LinkData
					,DST.LocalReference=SRC.LocalReference
					,DST.[Decimal]=SRC.[Decimal]
					,DST.TextFormat=SRC.TextFormat
					,DST.Filter=SRC.Filter
					,DST.IsRepeat=SRC.IsRepeat
					,DST.LastValueVouchers=SRC.LastValueVouchers
					,DST.IsnoTab=SRC.IsnoTab
					,DST.dependancy=SRC.dependancy
					,DST.dependanton=SRC.dependanton
					,DST.IsTransfer=SRC.IsTransfer
					,DST.DbFilter=SRC.DbFilter
					,DST.CrFilter=SRC.CrFilter
					,DST.ShowInQuickAdd=SRC.ShowInQuickAdd
					,DST.QuickAddOrder=SRC.QuickAddOrder
					,DST.Calculate=SRC.Calculate
					,DST.Cformula=SRC.Cformula
					,DST.IsReEvaluate=SRC.IsReEvaluate
					FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
					JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName AND DST.CostCenterID=@DocumentID
					WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID
					
					if exists(select * FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
					join ADM_DocumentDef srcdf with(nolock) on SRC.CostCenterColID=srcdf.CostCenterColID
					WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID)
					BEGIN
					
						if exists(select * FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
						join ADM_DocumentDef srcdf with(nolock) on SRC.CostCenterColID=srcdf.CostCenterColID
						JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName 
						join ADM_DocumentDef DSTdf on DST.CostCenterColID=DSTdf.CostCenterColID
						WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID AND DST.CostCenterID=@DocumentID)
						BEGIN
							 UPDATE DSTdf set              
								 [DebitAccount] = srcdf.DebitAccount              
								 ,[CreditAccount] = srcdf.CreditAccount              
								 ,[Formula] = srcdf.Formula              
								 ,[PostingType] = srcdf.PostingType              
								 ,[RoundOff] = srcdf.RoundOff              
								 ,[IsRoundOffEnabled] = srcdf.IsRoundOffEnabled              
								 ,Distributeon=srcdf.Distributeon              
								 ,[IsDrAccountDisplayed] = srcdf.IsDrAccountDisplayed              
								 ,[IsCrAccountDisplayed] = srcdf.IsCrAccountDisplayed              
								 ,[IsDistributionEnabled] = srcdf.IsDistributionEnabled              
								 ,[DistributionColID] =srcdf.DistributionColID                
								 ,IsCalculate=srcdf.IsCalculate   
								   ,CrRefID=srcdf.CrRefID, CrRefColID=srcdf.CrRefColID , DrRefID =srcdf.DrRefID,DrRefColID =srcdf.DrRefColID
								   ,EvaluateAfter=srcdf.EvaluateAfter
								   ,RoundOffLineWise=srcdf.RoundOffLineWise
								   ,showbodytotal=isnull(srcdf.showbodytotal,1)
								   ,basedonXMl=srcdf.basedonXMl,Posting=srcdf.Posting						
							FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
							join ADM_DocumentDef srcdf with(nolock) on SRC.CostCenterColID=srcdf.CostCenterColID
							JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName 
							join ADM_DocumentDef DSTdf on DST.CostCenterColID=DSTdf.CostCenterColID
							WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID AND DST.CostCenterID=@DocumentID
						END
						ELSE
						BEGIN
							INSERT INTO [ADM_DocumentDef]              
							  ([DocumentTypeID]              
							  ,[CostCenterID]             
							  ,[CostCenterColID]              
							  ,[DebitAccount]              
							  ,[CreditAccount]              
							  ,[Formula]              
							  ,[PostingType]              
							  ,[RoundOff]              
							  ,Distributeon              
							  ,[IsRoundOffEnabled]              
							  ,[IsDrAccountDisplayed]           
							  ,[IsCrAccountDisplayed]              
							  ,[IsDistributionEnabled]              
							  ,[DistributionColID]              
							  ,[IsCalculate]              
							  ,[CompanyGUID]              
							  ,[GUID]              
							  ,[CreatedBy]              
							  ,[CreatedDate]
								,CrRefID
								,CrRefColID
								,DrRefID
								,DrRefColID,showbodytotal,EvaluateAfter,basedonXMl,Posting,RoundOffLineWise)
								select DSTdf.[DocumentTypeID]              
							  ,DSTdf.[CostCenterID]             
							  ,DST.[CostCenterColID]              
							  ,srcdf.[DebitAccount]              
							  ,srcdf.[CreditAccount]              
							  ,srcdf.[Formula]              
							  ,srcdf.[PostingType]              
							  ,srcdf.[RoundOff]              
							  ,srcdf.Distributeon              
							  ,srcdf.[IsRoundOffEnabled]              
							  ,srcdf.[IsDrAccountDisplayed]           
							  ,srcdf.[IsCrAccountDisplayed]              
							  ,srcdf.[IsDistributionEnabled]              
							  ,srcdf.[DistributionColID]              
							  ,srcdf.[IsCalculate]              
							  ,srcdf.[CompanyGUID]              
							  ,newid()
							  ,DST.[CreatedBy]              
							  ,DST.[CreatedDate]
								,srcdf.CrRefID
								,srcdf.CrRefColID
								,srcdf.DrRefID
								,srcdf.DrRefColID,srcdf.showbodytotal,srcdf.EvaluateAfter,srcdf.basedonXMl,srcdf.Posting,srcdf.RoundOffLineWise
										FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
							join ADM_DocumentDef srcdf with(nolock) on SRC.CostCenterColID=srcdf.CostCenterColID
							JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName 
							join ADM_DocumentTypes DSTdf on DST.CostCenterID=DSTdf.CostCenterID
							WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID AND DST.CostCenterID=@DocumentID
			
						
						END
					END
					UPDATE DSLR SET DSLR.ResourceData= SRLR.ResourceData
					FROM  ADM_CostCenterDef SRC WITH(NOLOCK)
					JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName AND DST.CostCenterID=@DocumentID
					JOIN COM_LanguageResources SRLR WITH(NOLOCK) ON SRLR.ResourceID=SRC.ResourceID
					JOIN COM_LanguageResources DSLR WITH(NOLOCK) ON DSLR.ResourceID=DST.ResourceID
					WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID
					
					UPDATE ADM_DocumentTypes SET [GUID]=NEWID()where CostCenterID=@DocumentID 
					
					SELECT @DocumentColID=DST.CostCenterColID FROM ADM_CostCenterDef SRC WITH(NOLOCK)
					JOIN ADM_CostCenterDef DST WITH(NOLOCK) ON DST.SysColumnName= SRC.SysColumnName AND DST.CostCenterID=@DocumentID
					WHERE SRC.CostCenterID=@CostCenterID AND SRC.CostCenterColID=@CostCenterColID
						
					IF(@AllowDDHistory=1)
					BEGIN
						INSERT INTO ADM_CostCenterDef_History
						SELECT * FROM  ADM_CostCenterDef DST WITH(NOLOCK) 
						WHERE CostCenterColID=@DocumentColID AND CostCenterID=@DocumentID
					END
					
					UPDATE #TAB SET IsCopied=1 WHERE ID=@I
					
					IF (@isLink=1)
					BEGIN
						IF EXISTS (SELECT * FROM [COM_DocumentLinkDef] WITH(NOLOCK) WHERE CostCenterIDBase=@CostCenterID AND CostCenterIDLinked=@DocumentID)
						BEGIN
							IF EXISTS (SELECT * FROM COM_DocumentLinkDetails WITH(NOLOCK) WHERE CostCenterColIDBase=@CostCenterColID 
							AND DocumentLinkDefID IN (SELECT DocumentLinkDefID FROM [COM_DocumentLinkDef] WITH(NOLOCK) WHERE CostCenterIDBase=@CostCenterID AND CostCenterIDLinked=@DocumentID))
							BEGIN 
								UPDATE COM_DocumentLinkDetails SET CostCenterColIDLinked=@DocumentColID
								WHERE CostCenterColIDBase=@CostCenterColID AND DocumentLinkDefID IN (SELECT DocumentLinkDefID FROM [COM_DocumentLinkDef] WITH(NOLOCK) WHERE CostCenterIDBase=@CostCenterID AND CostCenterIDLinked=@DocumentID)
							END
							ELSE
							BEGIN
								INSERT INTO [COM_DocumentLinkDetails]([DocumentLinkDeFID],[CostCenterColIDBase],[CostCenterColIDLinked],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[View],[UpdateSource],[CalcValue])
								VALUES ((SELECT DocumentLinkDefID FROM [COM_DocumentLinkDef] WITH(NOLOCK) WHERE CostCenterIDBase=@CostCenterID AND CostCenterIDLinked=@DocumentID)
								,@CostCenterColID,@DocumentColID,'admin',NEWID(),'COPY DEF',@UserName,CONVERT(FLOAT,GETDATE()),@UserName,CONVERT(FLOAT,GETDATE()),0,0,0)
							END
						END
						
						IF EXISTS (SELECT * FROM [COM_DocumentLinkDef] WITH(NOLOCK) WHERE CostCenterIDBase=@DocumentID AND CostCenterIDLinked=@CostCenterID)
						BEGIN
							IF EXISTS (SELECT * FROM COM_DocumentLinkDetails WITH(NOLOCK) WHERE CostCenterColIDBase=@DocumentColID 
							AND DocumentLinkDefID IN (SELECT DocumentLinkDefID FROM [COM_DocumentLinkDef] WITH(NOLOCK) WHERE CostCenterIDBase=@DocumentID AND CostCenterIDLinked=@CostCenterID))
							BEGIN 
								UPDATE COM_DocumentLinkDetails SET CostCenterColIDLinked=@CostCenterColID
								WHERE CostCenterColIDBase=@DocumentColID AND DocumentLinkDefID IN (SELECT DocumentLinkDefID FROM [COM_DocumentLinkDef] WITH(NOLOCK) WHERE CostCenterIDBase=@DocumentID AND CostCenterIDLinked=@CostCenterID)
							END
							ELSE
							BEGIN
								INSERT INTO [COM_DocumentLinkDetails]([DocumentLinkDeFID],[CostCenterColIDBase],[CostCenterColIDLinked],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[View],[UpdateSource],[CalcValue])
								VALUES ((SELECT DocumentLinkDefID FROM [COM_DocumentLinkDef] WITH(NOLOCK) WHERE CostCenterIDBase=@DocumentID AND CostCenterIDLinked=@CostCenterID)
								,@DocumentColID,@CostCenterColID,'admin',NEWID(),'COPY DEF',@UserName,CONVERT(FLOAT,GETDATE()),@UserName,CONVERT(FLOAT,GETDATE()),0,0,0)
							END
						END
					 
					END
				END
			END 
			SET @I=@I+1   
		END   
		SET @ColI=@ColI+1   
	END 	
	
	declare @SysTbl nvarchar(50),@Caption nvarchar(max),@ColDef nvarchar(max),@ID nvarchar(50),@DataType nvarchar(max)
	truncate table #TAB
	
	INSERT INTO #TAB (DocumentID)
	exec SPSplitString @ReportsList,','

	set @ColDef=''
	SET @ColI=1
	WHILE @ColI<=@ColCnt              
	BEGIN
		SELECT @CostCenterColID=ColID FROM @TblCols WHERE ID=@ColI
		select @DataType=ColumnDataType from adm_costcenterdef with(nolock) where costcentercolid=@CostCenterColID

		set @ID='C'+lower(replace(convert(nvarchar(50),newid()),'-',''))
		
		set @ColDef=@ColDef+'<ColumnDef>'
		set @ColDef=@ColDef+'<Identity>'
		set @ColDef=@ColDef+'<ID>'+@ID+'</ID>'
		set @ColDef=@ColDef+'<Sequence>100</Sequence>'
		select @ColDef=@ColDef+'<Caption>'+replace(replace(replace(UserColumnName,'<','&lt;'),'>','&gt;'),'&','&amp;')+'</Caption>'
		+'<Category>'+convert(nvarchar,CostCenterID)+'</Category>'
		+'<Field>'+convert(nvarchar,CostCenterColID)+'</Field>'
		+'<SelectedField>'+case when IsForeignKey=1 then convert(nvarchar,isnull(ParentCCDefaultColID,0)) else '0' end+'</SelectedField>'
		+'<Type>'+ColumnDataType+'</Type>'
		from adm_costcenterdef 
		where costcentercolid=@CostCenterColID
		set @ColDef=@ColDef+'</Identity>'
		
		set @ColDef=@ColDef+'<Width>120</Width>'
		
		set @ColDef=@ColDef+'<HeaderAppearance>'
		set @ColDef=@ColDef+'<Alignment>Center</Alignment>'
		set @ColDef=@ColDef+'<Font>Calibri</Font><FontSize>12</FontSize><FontBold>True</FontBold>'
		set @ColDef=@ColDef+'</HeaderAppearance>'
		
		set @ColDef=@ColDef+'<DataAppearance>'
		set @ColDef=@ColDef+'<Alignment>'+case when @DataType='Float' then 'Right' else 'Left' end+'</Alignment>'
		set @ColDef=@ColDef+'<Font>Calibri</Font><FontSize>13</FontSize>'
		set @ColDef=@ColDef+'</DataAppearance>'
		
		set @ColDef=@ColDef+'<Format>'
		if @DataType='Float'
			set @ColDef=@ColDef+'<Decimals>-1</Decimals><Commas>-1</Commas>'
		else if @DataType='DATE'
			set @ColDef=@ColDef+'<DateType>dd/MM/yyyy</DateType>'
		set @ColDef=@ColDef+'</Format>'
		
		set @ColDef=@ColDef+'</ColumnDef>'
		
		SET @ColI=@ColI+1   
	END 

	SELECT @I=1,@Cnt=COUNT(*) FROM #TAB with(nolock)
	WHILE @I<=@Cnt              
	BEGIN   
		SELECT @DocumentID=CONVERT(INT,DocumentID) FROM #TAB with(nolock) WHERE ID=@I

		update adm_revenureports
		set ReportDefnXML=stuff(ReportDefnXML,len(ReportDefnXML)+2-CHARINDEX(reverse('</ColumnDef>'),reverse(ReportDefnXML)),0,@ColDef)
		where ReportID=@DocumentID

		SET @I=@I+1   
		--select @ColDef
		--print(@ColDef)
	END

	/*
	select ReportDefnXML,CHARINDEX('</ColumnDef>',ReportDefnXML,len(ReportDefnXML))  
--,substring(reverse(ReportDefnXML),0,CHARINDEX(reverse('</ColumnDef>'),reverse(ReportDefnXML)))
--,len(ReportDefnXML)+2-CHARINDEX(reverse('</ColumnDef>'),reverse(ReportDefnXML))
,stuff(ReportDefnXML
	,len(ReportDefnXML)+2-CHARINDEX(reverse('</ColumnDef>'),reverse(ReportDefnXML))
	,0,'<NEW></NEW>')

from adm_revenureports where ReportID=10686
*/
/*
      <ColumnDef>
        <Identity>
          <ID>C971c7c9b4abe4e14944bb7f67e329586</ID>
          <Sequence>6</Sequence>
          <Caption>Facility</Caption>
          <Category>40018</Category>
          <Field>6496</Field>
          <SelectedField>3021</SelectedField>
          <Type></Type>
        </Identity>
        <Width>120</Width>
        <HeaderAppearance>
          <Alignment>Center</Alignment>
          <Font>Calibri</Font>
          <FontSize>12</FontSize>
          <FontBold>True</FontBold>
        </HeaderAppearance>
        <DataAppearance>
          <Alignment>Left</Alignment>
          <Font>Calibri</Font>
          <FontSize>13</FontSize>
        </DataAppearance>
        <Format></Format>
      </ColumnDef>
*/

COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
WHERE ErrorNumber=100 AND LanguageID=@LangID              
SET NOCOUNT OFF;                
RETURN @CostCenterID                
END TRY                
BEGIN CATCH                
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000              
 BEGIN
	 if(ERROR_MESSAGE() like '-153%')
     begin    
		SELECT ErrorMessage+'"'+substring(ERROR_MESSAGE(),5,len(ERROR_MESSAGE()))+'"' ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
		WHERE ErrorNumber=-153 AND LanguageID=@LangID              	
	 end    
	else
	begin
		SELECT * FROM ADM_CostCenterDef WITH(nolock) WHERE CostCenterID=@CostCenterID              
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID              
	end
 END              
 ELSE IF ERROR_NUMBER()=547              
 BEGIN              
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)              
  WHERE ErrorNumber=-110 AND LanguageID=@LangID              
 END              
 ELSE IF ERROR_NUMBER()=2627              
 BEGIN              
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)              
  WHERE ErrorNumber=-116 AND LanguageID=@LangID              
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
