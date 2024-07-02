USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_CreateCostCenterMenu]
	@CostCenterID [int],
	@CostCenterName [nvarchar](300),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@CompanyGUID [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
		
	DECLARE @RESOURCEID BIGINT,@CurrentResourceID BIGINT,@Name NVARCHAR(200),@DATA NVARCHAR(200)
	DECLARE @RIBBONID INT,@GROUPID INT,@GROUPORDER INT,@FEATUREACTIONID INT,@GROUPRESID BIGINT
	
	SELECT @CurrentResourceID=MAX(ResourceID) FROM [COM_LanguageResources]	

	EXEC	[spCOM_SetInsertResourceData] @CostCenterName,@CostCenterName,@CostCenterName,@UserName,5,@RESOURCEID --FOR TREE BIGIMAGE
	
	SET @Name=@CostCenterName+' New'	
	EXEC	[spCOM_SetInsertResourceData] @Name,'New',@CostCenterName,@UserName,1,@RESOURCEID

	SET @Name=@CostCenterName+' New'	
	SET @DATA='New '+@CostCenterName	
	EXEC	[spCOM_SetInsertResourceData] @Name,@DATA,@CostCenterName,@UserName,1,@RESOURCEID

	SET @Name=@CostCenterName+' New'	
	EXEC	[spCOM_SetInsertResourceData] @Name,'New',@CostCenterName,@UserName,1,@RESOURCEID
	
	SET @DATA='Create New '+@CostCenterName
	EXEC	[spCOM_SetInsertResourceData] @Name,@DATA,@CostCenterName,@UserName,1,@RESOURCEID

	SET @Name=@CostCenterName+' Preferences'	
	EXEC	[spCOM_SetInsertResourceData] @Name,'Preferences',@CostCenterName,@UserName,1,@RESOURCEID

	SET @Name=@CostCenterName+' Preferences'	
	EXEC	[spCOM_SetInsertResourceData] @Name,@Name,@CostCenterName,@UserName,2,@RESOURCEID

	SET @Name=@CostCenterName+' Preferences'
	SET @DATA='Add / Edit '+@CostCenterName+' Preferences'		
	EXEC	[spCOM_SetInsertResourceData] @Name,@DATA,@CostCenterName,@UserName,1,@RESOURCEID

	SET @Name=@CostCenterName+' Customize'	
	EXEC	[spCOM_SetInsertResourceData] @Name,'Customize',@CostCenterName,@UserName,1,@RESOURCEID

	SET @Name=@CostCenterName+' Customize'
	SET @DATA='Customize '+@CostCenterName		
	EXEC	[spCOM_SetInsertResourceData] @Name,@DATA,@CostCenterName,@UserName,1,@RESOURCEID	

	SET @Name=@CostCenterName+' Customize'	
	EXEC	[spCOM_SetInsertResourceData] @Name,'Customize',@CostCenterName,@UserName,1,@RESOURCEID

	SET @Name=@CostCenterName+' Customize'
	SET @DATA='Customize '+@CostCenterName		
	EXEC	[spCOM_SetInsertResourceData] @Name,@DATA,@CostCenterName,@UserName,1,@RESOURCEID	

	SET @GROUPRESID=@CurrentResourceID+1
		SELECT @RIBBONID=ISNULL(MAX(RibbonViewID),0)+1 FROM [ADM_RibbonView]

 
	SELECT @FEATUREACTIONID=ISNULL(FeatureActionID,1) from ADM_FEATUREACTION WHERE FeatureID=@CostCenterID AND FeatureActionTypeID=2
 	INSERT INTO [ADM_RibbonView]
				(	
					 [RibbonViewID],[TabID],[GroupID],[TabName],[TabResourceID],[GroupName] ,[GroupResourceID],[TabOrder] ,[GroupOrder],[FeatureID]
					,[FeatureActionID],[FeatureActionResourceID] ,[FeatureActionName] ,[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType]
					,[ImagePath],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID]
					,[UserName],[CompanyGUID] ,[GUID],[Description],[CreatedBy],[CreatedDate]        
				) 
	select
					 @RIBBONID,[TabID],[GroupID] ,[TabName],[TabResourceID],[GroupName],[GroupResourceID],[TabOrder],[GroupOrder]
					,@CostCenterID,@FEATUREACTIONID,@CurrentResourceID+2,@CostCenterName,1,@CostCenterName,@CurrentResourceID+3,0
					,'CC_icon_4.png',@CurrentResourceID+4,@CostCenterName,'CC_icon_4.png',@CurrentResourceID+5,@CostCenterName,[RoleID],@UserID
					,@UserName,@CompanyGUID,NEWID(),@CostCenterName,@UserName  ,CONVERT(FLOAT,GETDATE())
				from [ADM_RibbonView]	where ribbonviewid=213

				 

--	SELECT @RIBBONID=ISNULL(MAX(RibbonViewID),0)+1 FROM [ADM_RibbonView] 
--	SELECT @FEATUREACTIONID=ISNULL(FeatureActionID,1) from ADM_FEATUREACTION WHERE FeatureID=@CostCenterID AND FeatureActionTypeID=1	
--	SET @CurrentResourceID=@CurrentResourceID+5
--
--	INSERT INTO [ADM_RibbonView]--FOR NEW FEATURE
--				(	
--					 [RibbonViewID],[TabID],[GroupID],[TabName],[TabResourceID],[GroupName] ,[GroupResourceID],[TabOrder] ,[GroupOrder],[FeatureID]
--					,[FeatureActionID],[FeatureActionResourceID] ,[FeatureActionName] ,[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType]
--					,[ImagePath],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID]
--					,[UserName],[CompanyGUID] ,[GUID],[Description],[CreatedBy],[CreatedDate]        
--				)
--			VALUES
--				(
--					 @RIBBONID,5,@GROUPID ,'CosCenter',139,@CostCenterName,@GROUPRESID,5,@GROUPORDER
--					,@CostCenterID,@FEATUREACTIONID,@CurrentResourceID+1,@CostCenterName+' NEW',1,@CostCenterName+' NEW',@CurrentResourceID+2,0
--					,'SmallIcon.png',@CurrentResourceID+3,@CostCenterName+' NEW','SmallIcon.png',@CurrentResourceID+4,@CostCenterName+' NEW',1,@UserID
--					,@UserName,@CompanyGUID,NEWID(),@CostCenterName,@UserName  ,CONVERT(FLOAT,GETDATE())
--				)
--
--	SELECT @RIBBONID=ISNULL(MAX(RibbonViewID),0)+1 FROM [ADM_RibbonView] 
--	SELECT @FEATUREACTIONID=ISNULL(FeatureActionID,1) from ADM_FEATUREACTION WHERE FeatureID=@CostCenterID AND FeatureActionTypeID=30	
--	SET @CurrentResourceID=@CurrentResourceID+4
--
--	INSERT INTO [ADM_RibbonView]--FOR PREFERENCE FEATURE
--				(	
--					 [RibbonViewID],[TabID],[GroupID],[TabName],[TabResourceID],[GroupName] ,[GroupResourceID],[TabOrder] ,[GroupOrder],[FeatureID]
--					,[FeatureActionID],[FeatureActionResourceID] ,[FeatureActionName] ,[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType]
--					,[ImagePath],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID]
--					,[UserName],[CompanyGUID] ,[GUID],[Description],[CreatedBy],[CreatedDate]        
--				)
--			VALUES
--				(
--					 @RIBBONID,5,@GROUPID ,'CosCenter',139,@CostCenterName,@GROUPRESID,5,@GROUPORDER
--					,@CostCenterID,@FEATUREACTIONID,@CurrentResourceID+1,@CostCenterName+' Preferences',1,@CostCenterName+' Preferences',@CurrentResourceID+2,0
--					,'SmallIcon.png',@CurrentResourceID+3,@CostCenterName+' Preferences','SmallIcon.png',@CurrentResourceID+4,@CostCenterName+' Preferences',1,@UserID
--					,@UserName,@CompanyGUID,NEWID(),@CostCenterName,@UserName  ,CONVERT(FLOAT,GETDATE())
--				)
--
--	SELECT @RIBBONID=ISNULL(MAX(RibbonViewID),0)+1 FROM [ADM_RibbonView] 
--	SELECT @FEATUREACTIONID=ISNULL(FeatureActionID,1) from ADM_FEATUREACTION WHERE FeatureID=@CostCenterID AND FeatureActionTypeID=1	
--	SET @CurrentResourceID=@CurrentResourceID+4
--
--	INSERT INTO [ADM_RibbonView]--FOR CUSTOMIZE FEATURE
--				(	
--					 [RibbonViewID],[TabID],[GroupID],[TabName],[TabResourceID],[GroupName] ,[GroupResourceID],[TabOrder] ,[GroupOrder],[FeatureID]
--					,[FeatureActionID],[FeatureActionResourceID] ,[FeatureActionName] ,[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType]
--					,[ImagePath],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID]
--					,[UserName],[CompanyGUID] ,[GUID],[Description],[CreatedBy],[CreatedDate]        
--				)
--			VALUES
--				(
--					 @RIBBONID,5,@GROUPID ,'CosCenter',139,@CostCenterName,@GROUPRESID,5,@GROUPORDER
--					,@CostCenterID,@FEATUREACTIONID,@CurrentResourceID+1,@CostCenterName+' Customize',1,@CostCenterName+' Customize',@CurrentResourceID+2,0
--					,'SmallIcon.png',@CurrentResourceID+3,@CostCenterName+' Customize','SmallIcon.png',@CurrentResourceID+4,@CostCenterName+' Customize',1,@UserID
--					,@UserName,@CompanyGUID,NEWID(),@CostCenterName,@UserName  ,CONVERT(FLOAT,GETDATE())
--				)



COMMIT TRANSACTION
END TRY
BEGIN CATCH
ROLLBACK TRANSACTION
SELECT 'ERROR OCCURED'
SELECT ERROR_MESSAGE()
END CATCH

 

 


  

GO
