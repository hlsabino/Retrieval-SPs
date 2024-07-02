USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_CreateCostCenter]
	@FeatureName [nvarchar](32),
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
		
	DECLARE @SQL NVARCHAR(MAX),@FeatureID INT=0
	
	SELECT @FeatureID=MAX(FeatureID) FROM ADM_Features WITH(NOLOCK) 
	WHERE FeatureID BETWEEN 50009 AND 50050
	
	IF @FeatureID IS NULL OR @FeatureID<>50050 
	BEGIN
		IF @FeatureID IS NULL
			SET @FeatureID=50009
		ELSE
			SET @FeatureID=@FeatureID+1
	END
	ELSE
	BEGIN
		SELECT @FeatureID=MAX(FeatureID) FROM ADM_Features WITH(NOLOCK) 
		WHERE FeatureID BETWEEN 51000 AND 59999
		
		IF @FeatureID IS NULL
			SET @FeatureID=51000
		ELSE
			SET @FeatureID=@FeatureID+1
	END
	
	SET @SQL='CREATE TABLE [dbo].[COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'](
[NodeID] [INT] IDENTITY(1000,1) NOT NULL,
[Code] [nvarchar](500) NULL,
[Name] [nvarchar](500) NULL,
[AliasName] [nvarchar](500) NULL,
[StatusID] [int] NOT NULL,
[Depth] [int] NOT NULL,
[ParentID] [INT] NOT NULL,
[lft] [INT] NOT NULL,
[rgt] [INT] NOT NULL,
[IsGroup] [bit] NOT NULL,
[CreditDays] [int] NOT NULL,
[CreditLimit] [float] NOT NULL,
[PurchaseAccount] [int] NOT NULL,
[SalesAccount] [int] NOT NULL,
[CompanyGUID] [nvarchar](50) NOT NULL,
[GUID] [varchar](50) NOT NULL,
[Description] [nvarchar](500) NULL,
[CreatedBy] [nvarchar](50) NOT NULL,
[CreatedDate] [float] NOT NULL,
[ModifiedBy] [nvarchar](50) NULL,
[ModifiedDate] [float] NULL,
[DebitDays] [int] NULL,
[DebitLimit] [float] NULL,
[CodePrefix] [nvarchar](100) NULL,
[CodeNumber] [INT] NULL DEFAULT ((0)),
[GroupSeqNoLength] [int] NOT NULL DEFAULT ((0)),
[CurrencyID] [int] NULL,
[WorkFlowID] [int] NULL,
[WorkFlowLevel] [int] NULL,
 CONSTRAINT [PK_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] PRIMARY KEY CLUSTERED 
(
	[NodeID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]'
	EXEC sp_executesql @SQL
	
	DECLARE @Rid INT,@ID INT
	SELECT @Rid=MAX([ResourceID])+1 FROM [Com_LanguageResources] WITH(NOLOCK)

	--FEATURE
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid,@FeatureName,1,'English',@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid,@FeatureName,2,'Arabic',@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [ADM_Features]([FeatureID],[ParentFeatureID],[Name],[SysName],[ResourceID],[FeatureTypeID],[FeatureTypeName],[IsEnabled],[IsUserDefined],[FeatureTypeResourceID],[Description],[ApplicationID],[StatusID],[CreatedDate],[CreatedBy],[TableName],[AllowCustomization],[PrimaryKey])
	VALUES(@FeatureID,1,@FeatureName,'Dimension - '+CONVERT(NVARCHAR,@FeatureID-50000),@Rid,1,'Dimension - '+CONVERT(NVARCHAR,@FeatureID-50000),1,1,NULL,@FeatureName,1,1,CONVERT(FLOAT,GETDATE()),'ADMIN','COM_CC'+CONVERT(NVARCHAR,@FeatureID),1,'NodeID')

	--FeatureAction
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+1,'Create '+@FeatureName,1,'English','Create '+@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+2,'Read '+@FeatureName,1,'English','Read '+@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+3,'Edit '+@FeatureName,1,'English','Edit '+@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+4,'Delete '+@FeatureName,1,'English','Delete '+@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+5,'Move '+@FeatureName,1,'English','Move '+@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+6,'Transfer '+@FeatureName,1,'English','Transfer '+@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+7,'Map '+@FeatureName,1,'English','Map '+@FeatureName,NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+8,'Create '+@FeatureName+' Group',1,'English','Create Group',NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	SELECT @ID=MAX([FeatureActionID]) FROM [ADM_FeatureAction] WITH(NOLOCK)

	SET IDENTITY_INSERT [ADM_FeatureAction] ON

	INSERT INTO [ADM_FeatureAction]([FeatureActionID],[Name],[ResourceID],[FeatureID],[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy])
	SELECT @ID+ROW_NUMBER() OVER ( ORDER BY [FeatureActionTypeID]),[Name],
	CASE WHEN [FeatureActionTypeID]<=7 THEN @Rid+[FeatureActionTypeID] WHEN [FeatureActionTypeID]=21 THEN @Rid+8 ELSE [ResourceID] END
	,@FeatureID,[FeatureActionTypeID],[ApplicationID],[GridShortCut],[Description],[Status],[CreatedDate],[CreatedBy] 
	FROM [ADM_FeatureAction] WITH(NOLOCK)
	WHERE FeatureID=50001

	SET IDENTITY_INSERT [ADM_FeatureAction] OFF

	INSERT INTO [ADM_FeatureActionRoleMap]([RoleID],[FeatureActionID],[Description],[Status],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])
	SELECT 1,FA.[FeatureActionID],NULL,1,'Admin',CONVERT(FLOAT,GETDATE()),NULL,NULL
	FROM [ADM_FeatureAction] FA WITH(NOLOCK)
	JOIN [ADM_FeatureAction] FAL WITH(NOLOCK) ON FAL.Name=FA.Name AND FAL.FeatureID=50001
	JOIN [ADM_FeatureActionRoleMap] FAR WITH(NOLOCK) ON FAL.[FeatureActionID]=FAR.[FeatureActionID] AND FAR.[RoleID]=1
	WHERE FA.FeatureID=@FeatureID and FA.Name<>'Dont Allow to Edit InActive Nodes'

	--RIBBON
	SET @Rid=@Rid+8

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+2,@FeatureName,1,'English',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+2,@FeatureName,2,'Arabic',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+3,@FeatureName,1,'English',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+3,@FeatureName,2,'Arabic',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+4,@FeatureName,1,'English',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+4,@FeatureName,2,'Arabic',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+5,@FeatureName,1,'English',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+5,@FeatureName,2,'Arabic',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+6,@FeatureName,1,'English',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid+6,@FeatureName,2,'Arabic',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [ADM_RibbonView]([RibbonViewID],[TabID],[GroupID],[DrpID],[TabName],[GroupName],[DrpName],[TabResourceID],[GroupResourceID],[DrpResourceID],[TabOrder],[GroupOrder],[FeatureID],[FeatureActionID],[FeatureActionResourceID],[FeatureActionName],[TabKeyTip],[GroupKeyTip],[DrpKeyTip],[ButtonKeyTip],[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType],[ImagePath],[DrpImage],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID],[UserName],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DisplayName],[DisplayNameResourceID],[ColumnOrder],[ShowInWeb],[IsMobile],[AppPath],[ShowInMobile],[Version],[IsOffLine],WebIcon,LicSIMPLE)
	SELECT (SELECT MAX([RibbonViewID])+1 FROM [ADM_RibbonView] WITH(NOLOCK)),7,[GroupID],[DrpID],[TabName],[GroupName],@FeatureName,[TabResourceID],[GroupResourceID],[DrpResourceID],[TabOrder],[GroupOrder],@FeatureID,@ID+2,@Rid+2,@FeatureName,[TabKeyTip],[GroupKeyTip],[DrpKeyTip],[ButtonKeyTip],[IsEnabled],@FeatureName,@Rid+3,0,'CC_icon_4.png','CC_icon_4.png',@Rid+4,@FeatureName,'CC_icon_4.png',@Rid+5,@FeatureName,[RoleID],[UserID],[UserName],[CompanyGUID],NEWID(),@FeatureName,[CreatedBy],CONVERT(FLOAT,GETDATE()),NULL,NULL,@FeatureName,@Rid+6,[ColumnOrder],[ShowInWeb],[IsMobile],[AppPath],[ShowInMobile],[Version],[IsOffLine],WebIcon,LicSIMPLE
	FROM [ADM_RibbonView] WITH(NOLOCK) WHERE [RibbonViewID]=213

	--STATUS
	DECLARE @StatusID INT
	SELECT @StatusID=MAX(StatusID)+1 FROM [COM_Status] WITH(NOLOCK)

	SET IDENTITY_INSERT [COM_Status] ON

	INSERT INTO [COM_Status]([StatusID],[CostCenterID],[FeatureID],[Status],[ResourceID],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])
	VALUES(@StatusID,@FeatureID,@FeatureID,'Active',177,0,'CompanyGUID',NEWID(),@FeatureName,'Admin',convert(float,getdate()),NULL,NULL)

	INSERT INTO [COM_Status]([StatusID],[CostCenterID],[FeatureID],[Status],[ResourceID],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])
	VALUES(@StatusID+1,@FeatureID,@FeatureID,'In Active',178,0,'CompanyGUID',NEWID(),@FeatureName,'Admin',convert(float,getdate()),NULL,NULL)

	SET IDENTITY_INSERT [COM_Status] OFF

	--CostCenter Definition
	DECLARE @CostCenterColID INT
	SELECT @CostCenterColID=MAX(CostCenterColID)+1 FROM [adm_costcenterdef] WITH(NOLOCK)

	SET @Rid=@Rid+7

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid,'Code',1,'English','Code','AAC365BB-14C1-4C44-9CB7-E8B16771666B',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid,'Code',2,'Arabic','?????','AAC365BB-14C1-4C44-9CB7-E8B16771666B',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+1,'Name',1,'English','Name','129416ED-81D7-4BB7-95B9-47C4DFFC841E',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+1,'Name',2,'Arabic','?????','129416ED-81D7-4BB7-95B9-47C4DFFC841E',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+2,'Status',1,'English','Status','476A5A75-31B9-4C6D-8B6A-9E8EB9FB02A6',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+2,'Status',2,'Arabic','?????','476A5A75-31B9-4C6D-8B6A-9E8EB9FB02A6',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+3,'Group',1,'English','Group','A3EAD8BD-1653-431C-B0B3-9911E2154DF3',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+3,'Group',2,'Arabic','????????','A3EAD8BD-1653-431C-B0B3-9911E2154DF3',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+4,'CreditDays',1,'English','Credit Days','AB484A6E-4424-4088-85A3-20BB2225F10A',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+4,'CreditDays',2,'Arabic','???? ????????','AB484A6E-4424-4088-85A3-20BB2225F10A',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+5,'CreditLimit',1,'English','Credit Limit','FCE60F19-3B0C-4F63-83F6-3A0AE2DFE6EF',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+5,'CreditLimit',2,'Arabic','???? ?????????','FCE60F19-3B0C-4F63-83F6-3A0AE2DFE6EF',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+6,'PurchaseAccount',1,'English','Purchase Account','BFBB126E-CD3C-4154-B310-DA8D89231761',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+6,'PurchaseAccount',2,'Arabic','???? ??????','BFBB126E-CD3C-4154-B310-DA8D89231761',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+7,'SalesAccount',1,'English','Sales Account','EF7C3CC9-F8C1-4D09-A18E-CE783066E110',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+7,'SalesAccount',2,'Arabic','???? ?????','EF7C3CC9-F8C1-4D09-A18E-CE783066E110',NULL,'ADMIN',4.076467854000771e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+8,'DebitDays',1,'English','Debit Days','7EC93F40-74A4-458F-95DD-0EA4CC2FE7EE',NULL,'admin',4.081849413854167e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+8,'DebitDays',2,'Arabic','??? ?????','7EC93F40-74A4-458F-95DD-0EA4CC2FE7EE',NULL,'admin',4.081849413854167e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+9,'DebitLimit',1,'English','Debit Limit','F2F87047-1F34-4537-A0B6-CE762478972F',NULL,'admin',4.081849413873457e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+9,'DebitLimit',2,'Arabic','?? ?????','F2F87047-1F34-4537-A0B6-CE762478972F',NULL,'admin',4.081849413873457e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+10,'AliasName',1,'English','Alias Name','E3B45D14-280D-489D-AD4A-7BA5C2088F4F',NULL,'ADMIN',4.073353878070987e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+10,'AliasName',2,'Arabic','??? ??????','E3B45D14-280D-489D-AD4A-7BA5C2088F4F',NULL,'ADMIN',4.073353878070987e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+11,'GroupSeqNoLength',1,'English','Group Sequence no length','66E98DF9-185E-4567-A2E2-0BF7497E3D4C',NULL,'ADMIN',4.073374614907408e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+11,'GroupSeqNoLength',2,'Arabic','??? ????? ????????','66E98DF9-185E-4567-A2E2-0BF7497E3D4C',NULL,'ADMIN',4.073374614907408e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+12,'Group Name',1,'English','Group Name','2C15CAE9-EE71-4BBA-9F7A-4C11D10B3170',NULL,'ADMIN',4.073155694641203e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+12,'Group Name',2,'Arabic','??? ????????','2C15CAE9-EE71-4BBA-9F7A-4C11D10B3170',NULL,'ADMIN',4.073155694641203e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+13,'CreatedBy',1,'English','CreatedBy','448BFA36-79E0-4ADF-8C30-AF8A947E86D6',NULL,'ADMIN',4.107153771902006e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+13,'CreatedBy',2,'Arabic','???? ?? ????','448BFA36-79E0-4ADF-8C30-AF8A947E86D6',NULL,'ADMIN',4.107153771902006e+004,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+14,'Currency',1,'English','Currency','52525',NULL,'admin',4.022000000000000e+003,NULL,NULL,@FeatureName)
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])VALUES(@Rid+14,'Currency',2,'Arabic','??????','52525',NULL,'admin',4.022000000000000e+003,NULL,NULL,@FeatureName)
	SET IDENTITY_INSERT [ADM_CostCenterDef] ON

	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID,@Rid,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'Code','Code',NULL,'CODE',NULL,NULL,NULL,1,0,1,1,0,0,0,0,0,0,NULL,0,NULL,1,NULL,NULL,0,0,2,1,NULL,'CompanyGUID','64A3D1F9-AFF1-44DF-908A-0BD9A8138243',NULL,'ADMIN',4.076467853962191e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,1,0,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+1,@Rid+1,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'Name','Name',NULL,'TEXT',NULL,NULL,NULL,3,1,1,1,0,0,0,0,0,0,NULL,0,NULL,3,NULL,NULL,1,0,3,1,NULL,'CompanyGUID','EAFE947B-6E88-46B9-B0BA-897271F1DA26',NULL,'ADMIN',4.076467853962191e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,1,1,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+2,@Rid+2,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'Status','StatusID',NULL,'COMBOBOX',NULL,@StatusID,NULL,5,0,1,1,0,0,0,0,113,0,NULL,0,NULL,5,NULL,NULL,3,0,2,1,NULL,'CompanyGUID','C612D2A7-6B60-4FAE-8BA7-62B04507D26B',NULL,'ADMIN',4.076467853962191e+004,NULL,NULL,NULL,1,113,0,1,'COM_Status','StatusID',22872,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,1,3,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+3,@Rid+3,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'Group','IsGroup',NULL,'LISTBOX','LISTBOX',NULL,NULL,2,1,1,1,0,0,0,0,@FeatureID,2,NULL,0,NULL,2,NULL,NULL,0,2,1,1,NULL,'CompanyGUID','BC4FB01F-6FB7-48B7-88DB-4B06750A6332',NULL,'ADMIN',4.076467853962191e+004,NULL,NULL,NULL,1,@FeatureID,0,1,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'NodeID',@CostCenterColID+1,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,1,4,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+4,@Rid+4,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'CreditDays','CreditDays',NULL,'Float','Float','0',NULL,8,0,1,1,0,0,0,0,0,0,NULL,0,NULL,8,NULL,NULL,4,0,1,1,NULL,'CompanyGUID','41B94310-EE2A-44FA-A155-B9F9641C9260',NULL,'ADMIN',4.076467853962191e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+5,@Rid+5,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'CreditLimit','CreditLimit',NULL,'Float','Float','0.0',NULL,7,0,1,1,0,0,0,0,0,0,NULL,0,NULL,7,NULL,NULL,4,1,1,1,NULL,'CompanyGUID','57A1A268-354A-46F4-9327-F173D18594E6',NULL,'ADMIN',4.076467853962191e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+6,@Rid+6,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'PurchaseAccount','PurchaseAccount',NULL,'LISTBOX',NULL,'2',NULL,6,0,1,1,0,0,0,0,2,2,NULL,0,NULL,6,NULL,NULL,3,2,2,1,NULL,'CompanyGUID','1A3E50AD-D67A-4A90-A308-2A35693E2068',NULL,'ADMIN',4.076467853962191e+004,NULL,NULL,NULL,1,2,0,1,'ACC_Accounts','AccountID',239,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+7,@Rid+7,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'SalesAccount','SalesAccount',NULL,'LISTBOX',NULL,'3',NULL,9,0,1,1,0,0,0,0,2,2,NULL,0,NULL,9,NULL,NULL,4,2,2,1,NULL,'CompanyGUID','C9E608EB-3737-4DCD-86D6-ED2A73FBD485',NULL,'ADMIN',4.076467853962191e+004,NULL,NULL,NULL,1,2,0,1,'ACC_Accounts','AccountID',239,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+8,@Rid+8,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'DebitDays','DebitDays',NULL,'Float','Float','0',NULL,11,0,1,1,0,0,0,0,0,0,NULL,0,NULL,11,NULL,NULL,5,0,1,1,NULL,'CompanyGUID','6D31DC2D-351E-439D-8B5C-A095E125F068',NULL,'admin',4.081849413854167e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+9,@Rid+9,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'DebitLimit','DebitLimit',NULL,'Float','Float','0.0',NULL,10,0,1,1,0,0,0,0,0,0,NULL,0,NULL,10,NULL,NULL,5,1,1,1,NULL,'CompanyGUID','FC442A86-472C-4D88-B6A1-A63DF4E0C431',NULL,'admin',4.081849413892747e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+10,@Rid+10,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'Alias Name','AliasName',NULL,NULL,NULL,NULL,NULL,4,0,1,1,1,0,0,0,0,0,NULL,0,NULL,4,NULL,NULL,2,0,3,1,NULL,'F9D7F28C-97BF-4C30-95A6-26FA76B88915','3DE435C1-6EE4-4797-A544-BCA50A8A599D',NULL,'Admin',4.073665758000000e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+11,@Rid+11,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'GroupSeqNoLength','GroupSeqNoLength',NULL,'NUMERIC','INT','0',NULL,2,0,1,1,0,0,0,0,0,0,NULL,0,NULL,28,NULL,NULL,8,3,1,1,NULL,'BEE3907C-6942-4173-A199-C500822DCCEC','73B45B4D-6A15-454C-8834-D33E0BD20BC8',NULL,'Admin',4.073353878070987e+004,NULL,NULL,NULL,1,301,0,1,'ACC_AccountTypes','AccountTypeID',22870,NULL,NULL,NULL,0,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,1,5,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+12,@Rid+12,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'GroupName','ParentID',NULL,NULL,NULL,NULL,NULL,6,0,1,0,1,0,0,0,0,0,NULL,0,NULL,NULL,NULL,NULL,3,0,1,1,NULL,'11EE07A5-EFFF-455B-A95A-23E4CE3BE3AF','CCD92216-00B2-4EDE-85A2-51C7C1A55B14',NULL,'Admin',4.073665758479938e+004,NULL,NULL,NULL,1,@FeatureID,0,1,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'NodeID',@CostCenterColID+1,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+13,@Rid+13,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'CreatedBy','CreatedBy',NULL,'TEXT','String','','',42,0,1,0,0,0,0,0,0,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'CompanyGUID','E2A0101B-9AE3-4061-ACCB-55F8EB5BEE0F',NULL,'ADMIN',4.074074000416667e+004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+14,@Rid+14,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'CurrencyID','CurrencyID',NULL,'LISTBOX','INT',NULL,NULL,10,0,1,1,0,0,0,0,12,1,NULL,0,NULL,10,NULL,NULL,4,3,1,1,NULL,'FA722FBF-1F6A-47BA-9A85-E8C7EC9F2787','85678E42-3126-4E80-8FDC-37E970AC7F26',NULL,'Admin',4.073353878070987e+004,NULL,NULL,NULL,0,12,0,1,'COM_Currency','CurrencyID',172,NULL,NULL,NULL,0,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+17,147,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'DimensionImage','DimensionImage',NULL,NULL,'IMAGE',NULL,NULL,0,0,1,0,0,0,0,0,0,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'693E656C-CD0D-486D-AFAC-FC36CBFFAF0D','A5203D77-8DD2-499D-8BB7-9495333DC917',NULL,'Admin',4.000000000000000e+000,NULL,NULL,0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+18,34074,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'Assigned','',NULL,'STRING','STRING',NULL,NULL,0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'ASSIGN_GUID','ASSIGN_GUID',NULL,'Admin',4.000000000000000e+000,NULL,NULL,0,1,8,0,1,'COM_CostCenterCostCenterMap','CCCCMapID',50002,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL)
	INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])VALUES(@FeatureID,@CostCenterColID+19,5077,@FeatureName,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'GroupName','ParentID',NULL,NULL,NULL,NULL,NULL,6,0,1,0,1,0,0,0,0,0,NULL,0,NULL,NULL,NULL,NULL,3,0,1,1,NULL,'11EE07A5-EFFF-455B-A95A-23E4CE3BE3AF','CCD92216-00B2-4EDE-85A2-51C7C1A55B14',NULL,'Admin',4.073665758479938e+004,NULL,NULL,NULL,1,@FeatureID,0,1,'COM_CC'+CONVERT(NVARCHAR,@FeatureID),'NodeID',@CostCenterColID,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,1)

	SET IDENTITY_INSERT [ADM_CostCenterDef] OFF

	--TABS
	SELECT @ID=MAX([CCTabID]) FROM [ADM_CostCenterTab] WITH(NOLOCK)

	SET IDENTITY_INSERT [ADM_CostCenterTab] ON

	INSERT INTO [ADM_CostCenterTab]([CCTabID],[CCTabName],[CostCenterID],[ResourceID],[TabOrder],[IsVisible],[IsTabUserDefined],[GroupOrder],[GroupVisible])
	SELECT @ID+ROW_NUMBER() OVER ( ORDER BY [CCTabID]),[CCTabName],@FeatureID,[ResourceID],[TabOrder],1,[IsTabUserDefined],[GroupOrder],1 
	FROM [ADM_CostCenterTab] WITH(NOLOCK) WHERE [CostCenterID]=50001

	SET IDENTITY_INSERT [ADM_CostCenterTab] OFF

	--GRID VIEW
	SELECT @ID=MAX([GridViewID])+1 FROM [ADM_GridView] WITH(NOLOCK) 

	SET @Rid=@Rid+15

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid,@FeatureName,1,'English',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
	VALUES(@Rid,@FeatureName,2,'Arabic',@FeatureName,'GUID',NULL,'Admin',convert(float,getdate()),NULL,NULL,@FeatureName) 

	SET IDENTITY_INSERT [ADM_GridView] ON

	INSERT INTO [ADM_GridView]([GridViewID],[FeatureID],[CostCenterID],[ViewName],[ResourceID],[SearchFilter],[RoleID],[UserID],[IsViewRoleDefault],[IsViewUserDefault],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FilterXml],[ChunkCount],[DefaultColID],[DefaultFilterID],[DefaultSearchListviews],[DefaultListViewID])
	VALUES(@ID,@FeatureID,@FeatureID,@FeatureName,@Rid,'',1,1,1,0,0,'CompanyGUID',NEWID(),NULL,'Admin',convert(float,getdate()),NULL,NULL,'<FilterXMl></FilterXMl>',1000,0,0,'',0)

	SET IDENTITY_INSERT [ADM_GridView] OFF

	INSERT INTO [ADM_GridViewColumns]([GridViewID],[CostCenterColID],[ColumnResourceID],[ColumnFilter],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[ColumnType])
	VALUES(@ID,@CostCenterColID,NULL,NULL,0,200,NULL,'Admin',convert(float,getdate()),NULL,NULL,1)
	INSERT INTO [ADM_GridViewColumns]([GridViewID],[CostCenterColID],[ColumnResourceID],[ColumnFilter],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[ColumnType])
	VALUES(@ID,@CostCenterColID+1,NULL,NULL,1,200,NULL,'Admin',convert(float,getdate()),NULL,NULL,1)

	DECLARE @GridContextMenuID INT
	SELECT @GridContextMenuID=MAX([GridContextMenuID]) FROM [ADM_GridContextMenu] WITH(NOLOCK)

	SET IDENTITY_INSERT [ADM_GridContextMenu] ON

	INSERT INTO [ADM_GridContextMenu]([GridContextMenuID],[GridViewID],[GridViewColumnID],[FeatureActionID],[MenuOrder],[RoleID],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])
	SELECT @GridContextMenuID+ROW_NUMBER() OVER ( ORDER BY GCM.[MenuOrder]),@ID,GCM.[GridViewColumnID],FAL.[FeatureActionID],GCM.[MenuOrder],GCM.[RoleID],GCM.[CompanyGUID],GCM.[GUID],GCM.[Description],GCM.[CreatedBy],GCM.[CreatedDate],GCM.[ModifiedBy],GCM.[ModifiedDate] 
	FROM [ADM_GridContextMenu] GCM WITH(NOLOCK)
	JOIN [ADM_GridView] GV WITH(NOLOCK) ON  GV.[GridViewID]=GCM.[GridViewID] AND GV.[FeatureID]=50001
	JOIN [ADM_FeatureAction] FA WITH(NOLOCK) ON FA.[FeatureActionID]=GCM.[FeatureActionID]
	JOIN [ADM_FeatureAction] FAL WITH(NOLOCK) ON FAL.[Name]=FA.[Name] AND FAL.[FeatureID]=@FeatureID
	WHERE GCM.[RoleID]=1

	SET IDENTITY_INSERT [ADM_GridContextMenu] OFF          

	--LISTVIEW
	SELECT @ID=MAX([ListViewID])+1 FROM [ADM_ListView] WITH(NOLOCK)

	SET IDENTITY_INSERT [ADM_ListView] ON

	INSERT INTO [ADM_ListView]([ListViewID],[ListViewName],[CostCenterID],[FeatureID],[ListViewTypeID],[SearchFilter],[FilterXML],[RoleID],[UserID],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[SearchOption],[SearchOldValue],[GroupSearchFilter],[GroupFilterXML])
	VALUES(@ID,@FeatureName,@FeatureID,@FeatureID,1,' a.IsGroup=0 ','<FilterXMl></FilterXMl>',1,1,0,NEWID(),NEWID(),@FeatureName,'Admin',convert(float,getdate()),NULL,NULL,1,NULL,NULL,NULL)

	INSERT INTO [ADM_ListView]([ListViewID],[ListViewName],[CostCenterID],[FeatureID],[ListViewTypeID],[SearchFilter],[FilterXML],[RoleID],[UserID],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[SearchOption],[SearchOldValue],[GroupSearchFilter],[GroupFilterXML])
	VALUES(@ID+1,@FeatureName+' Group',@FeatureID,@FeatureID,2,'a.IsGroup=1','<FilterXMl></FilterXMl>',1,1,0,NEWID(),NEWID(),@FeatureName+'Group','Admin',convert(float,getdate()),NULL,NULL,1,NULL,NULL,NULL)

	INSERT INTO [ADM_ListView]([ListViewID],[ListViewName],[CostCenterID],[FeatureID],[ListViewTypeID],[SearchFilter],[FilterXML],[RoleID],[UserID],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[SearchOption],[SearchOldValue],[GroupSearchFilter],[GroupFilterXML])
	VALUES(@ID+2,'All '+@FeatureName,@FeatureID,@FeatureID,3,'','<FilterXMl></FilterXMl>',1,1,0,NEWID(),NEWID(),'All '+@FeatureName,'Admin',convert(float,getdate()),NULL,NULL,1,NULL,NULL,NULL)

	SET IDENTITY_INSERT [ADM_ListView] OFF

	INSERT INTO [ADM_ListViewColumns]([ListViewID],[CostCenterColID],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DocumentsList],[IsParent],[ColumnType])
	VALUES(@ID,@CostCenterColID+1,0,200,NULL,'Admin',convert(float,getdate()),NULL,NULL,NULL,0,1)

	INSERT INTO [ADM_ListViewColumns]([ListViewID],[CostCenterColID],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DocumentsList],[IsParent],[ColumnType])
	VALUES(@ID,@CostCenterColID,1,200,NULL,'Admin',convert(float,getdate()),NULL,NULL,NULL,0,1)

	INSERT INTO [ADM_ListViewColumns]([ListViewID],[CostCenterColID],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DocumentsList],[IsParent],[ColumnType])
	VALUES(@ID+1,@CostCenterColID+1,0,200,NULL,'Admin',convert(float,getdate()),NULL,NULL,NULL,0,1)

	INSERT INTO [ADM_ListViewColumns]([ListViewID],[CostCenterColID],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DocumentsList],[IsParent],[ColumnType])
	VALUES(@ID+1,@CostCenterColID,1,200,NULL,'Admin',convert(float,getdate()),NULL,NULL,NULL,0,1)

	INSERT INTO [ADM_ListViewColumns]([ListViewID],[CostCenterColID],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DocumentsList],[IsParent],[ColumnType])
	VALUES(@ID+2,@CostCenterColID+1,0,200,NULL,'Admin',convert(float,getdate()),NULL,NULL,NULL,0,1)

	INSERT INTO [ADM_ListViewColumns]([ListViewID],[CostCenterColID],[ColumnOrder],[ColumnWidth],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DocumentsList],[IsParent],[ColumnType])
	VALUES(@ID+2,@CostCenterColID,1,200,NULL,'Admin',convert(float,getdate()),NULL,NULL,NULL,0,1)
	           
	--QUICKVIEW
	SELECT @ID=MAX([QID])+1 FROM [ADM_QuickViewDefn] WITH(NOLOCK)

	INSERT INTO [ADM_QuickViewDefn]([QID],[QName],[CostCenterID],[CostCenterColID],[ColumnOrder],[LastPRateDocs],[LastSRateDocs],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[Param1])
	VALUES(@ID,'DEFUALT VIEW',@FeatureID,@CostCenterColID,0,'','','CompanyGUID',NEWID(),NULL,'Admin',convert(float,getdate()),0)

	INSERT INTO [ADM_QuickViewDefn]([QID],[QName],[CostCenterID],[CostCenterColID],[ColumnOrder],[LastPRateDocs],[LastSRateDocs],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[Param1])
	VALUES(@ID,'DEFUALT VIEW',@FeatureID,@CostCenterColID+1,1,'','','CompanyGUID',NEWID(),NULL,'Admin',convert(float,getdate()),0)

	INSERT INTO [ADM_QuickViewDefnUserMap]([QID],[ShowCCID],[UserID],[RoleID],[GroupID])
	VALUES(@ID,@FeatureID,0,1,0)

	--PREFRENCES
	INSERT INTO [COM_CostCenterPreferences] ([CostCenterID],[FeatureID],[ResourceID],[Name],[Value],[DefaultValue],[ProbableValues],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])
	SELECT @FeatureID,@FeatureID,[ResourceID],[Name],[DefaultValue],[DefaultValue],[ProbableValues],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate] 
	FROM [COM_CostCenterPreferences] WITH(NOLOCK) 
	WHERE [CostCenterID]=50001
	
	SET @Rid=@Rid+1

	INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
	VALUES (@Rid, 'dcCCNID'+convert(nvarchar,(@FeatureID-50000)),1,'English',@FeatureName ,'')
	INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
	VALUES (@Rid, 'dcCCNID'+convert(nvarchar,(@FeatureID-50000)),2,'Arabic', @FeatureName,'')
	
	INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate
	,IsUnique,[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID])
	SELECT CostCenterID,@Rid,DocumentName,'COM_DocCCData',@FeatureName,'dcCCNID'+convert(nvarchar,(@FeatureID-50000)),NULL,'LISTBOX','LISTBOX','','',0,0,1,1,0,1,0,0,@FeatureID,1,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL
	,0,1,@FeatureID,0,1,'COM_CC'+convert(nvarchar,@FeatureID),'NodeID',(SELECT TOP 1 CostCenterColID FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@FeatureID AND SysColumnName='Name')
	FROM ADM_DocumentTypes with(nolock) WHERE CostCenterID=40001
	
--INSERTS
SET @SQL='SET IDENTITY_INSERT [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] ON
INSERT INTO [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] ([NodeID],[Code],[Name],[AliasName],[StatusID],[Depth],[ParentID],[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[PurchaseAccount],[SalesAccount],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DebitDays],[DebitLimit],[CodePrefix],[CodeNumber],[GroupSeqNoLength],[CurrencyID])VALUES(0,'''+@FeatureName+''','''+@FeatureName+''','''+@FeatureName+''','+CONVERT(NVARCHAR,@StatusID)+',0,0,0,0,1,0,0.000000000000000e+000,0,0,''GUID'',''GUID'',NULL,''ADMIN'',2.200000000000000e+001,NULL,NULL,0,0.000000000000000e+000,NULL,0,0,NULL)
INSERT INTO [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] ([NodeID],[Code],[Name],[AliasName],[StatusID],[Depth],[ParentID],[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[PurchaseAccount],[SalesAccount],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DebitDays],[DebitLimit],[CodePrefix],[CodeNumber],[GroupSeqNoLength],[CurrencyID])VALUES(1,'''+@FeatureName+''','''+@FeatureName+''','''+@FeatureName+''','+CONVERT(NVARCHAR,@StatusID)+',1,2,2,3,0,0,0.000000000000000e+000,0,0,''GUID'',''GUID'',NULL,''ADMIN'',2.200000000000000e+001,NULL,NULL,0,0.000000000000000e+000,NULL,0,0,NULL)
INSERT INTO [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] ([NodeID],[Code],[Name],[AliasName],[StatusID],[Depth],[ParentID],[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[PurchaseAccount],[SalesAccount],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DebitDays],[DebitLimit],[CodePrefix],[CodeNumber],[GroupSeqNoLength],[CurrencyID])VALUES(2,'''+@FeatureName+''','''+@FeatureName+''','''+@FeatureName+''','+CONVERT(NVARCHAR,@StatusID)+',0,0,1,4,1,0,0.000000000000000e+000,0,0,''GUID'',''GUID'',NULL,''admin'',2.200000000000000e+001,NULL,NULL,0,0.000000000000000e+000,NULL,0,0,NULL)
SET IDENTITY_INSERT [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] OFF

INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
select '+CONVERT(NVARCHAR,@FeatureID)+',NodeID,''admin'',1,''COMPANYGUID'',''GUID'' from COM_CC'+CONVERT(NVARCHAR,@FeatureID)+' with(nolock) WHERE NODEID>0'
	EXEC sp_executesql @SQL
	
	SET @SQL='ALTER TABLE [COM_CCCCData] ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT default(1) not null
ALTER TABLE [COM_CCCCDataHistory] ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT default(1) not null

ALTER TABLE [COM_CCCCData] WITH CHECK ADD  CONSTRAINT [FK_COM_CCCCData_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] FOREIGN KEY([CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+']) REFERENCES [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] ([NodeID])
ALTER TABLE [COM_CCCCData] CHECK CONSTRAINT [FK_COM_CCCCData_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+']

ALTER TABLE [COM_DocCCData] ADD [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT default(1) not null
ALTER TABLE [COM_DocCCData] WITH CHECK ADD  CONSTRAINT [FK_COM_DocCCData_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] FOREIGN KEY([dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+']) REFERENCES [COM_CC'+CONVERT(NVARCHAR,@FeatureID)+'] ([NodeID])
ALTER TABLE [COM_DocCCData] CHECK CONSTRAINT [FK_COM_DocCCData_COM_CC'+CONVERT(NVARCHAR,@FeatureID)+']

ALTER TABLE [COM_DocCCData_History] ADD [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null

ALTER TABLE COM_CCPrices ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(0) not null
ALTER TABLE COM_CCTaxes ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(0) not null
ALTER TABLE COM_BudgetAlloc ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
ALTER TABLE COM_BudgetAlloc_history ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
ALTER TABLE ADM_SchemesDiscounts ADD [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null

ALTER TABLE COM_Billwise ADD [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null
ALTER TABLE COM_BillwiseHistory ADD [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT  default(1) not null

ALTER TABLE COM_DimensionMappings add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT not null default(1)

ALTER TABLE ADM_DimensionWiseLockData add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE COM_ChequeReturn add [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE COM_LCBills add [dcCCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_Activities add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE COM_Address add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE COM_Address_History add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
'
	IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='PAY_EmpDetail')
	BEGIN
		SET @SQL=@SQL+' ALTER TABLE PAY_EmpDetail add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
						'
	END	

	IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='PAY_EmpDetail_History')
	BEGIN
		SET @SQL=@SQL+' ALTER TABLE PAY_EmpDetail_History add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
		'
	END	

	
	IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='CRM_Campaigns')
	BEGIN
		SET @SQL=@SQL+' ALTER TABLE CRM_CampaignApprovals add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_CampaignDemoKit add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_CampaignInvites add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_CampaignOrganization add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_CampaignProducts add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_CampaignResponse add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_CampaignSpeakers add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_Feedback add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
ALTER TABLE CRM_ProductMapping add [CCNID'+CONVERT(NVARCHAR,@FeatureID-50000)+'] INT
		'
	END	
		
	EXEC sp_executesql @SQL 
	
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
