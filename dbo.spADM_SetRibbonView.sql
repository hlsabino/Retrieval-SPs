USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetRibbonView]
	@TabID [int],
	@GroupID [int],
	@FeatureID [int],
	@FeatureActionID [int],
	@TabName [varchar](200),
	@GroupName [varchar](200),
	@FeatureName [varchar](200),
	@ScreenName [varchar](200),
	@ToolTipTitle [varchar](200),
	@ToolTipDesc [varchar](200),
	@taborder [int],
	@GroupOrder [int],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1,
	@IMAGEPATH [nvarchar](300) = NULL,
	@DrpID [int] = NULL
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
		 
		 
		declare @TabResID bigint,@GroupResiD bigint,@FeatureResourceID BIGINT,@SCRESID BIGINT,@TTRESID BIGINT,@TTDESRESID BIGINT,@RIBBONID bigint
		  
		IF(@TabID=0)--CREATE NEW TAB
		begin
			--EXEC	[spCOM_SetInsertResourceData] @TabName,@TabName,@TabName,@UserName,1,@TabResID OUTPUT 
			  EXEC spCOM_SetCostCenterLanguageData @TabName,@TabName,@UserName,@TabResID OUTPUT

		SELECT @TabID=Max(TabID) FROM [ADM_RibbonView] WITH (NOLOCK) WHERE TABID=@TabID
		select @taborder=Max(taborder)+1 FROM [ADM_RibbonView] WITH (NOLOCK)   
		end
		ELSE
			SELECT @TabResID=TabResourceID,@taborder=TabOrder,@TabName=TabName FROM [ADM_RibbonView] WITH (NOLOCK) WHERE TABID=@TabID


		IF(@GroupID=0)--CREATE NEW GROUP
		begin
		--EXEC	[spCOM_SetInsertResourceData] @GroupName,@GroupName,@GroupName,@UserName,1,@GroupResiD OUTPUT
		 EXEC spCOM_SetCostCenterLanguageData @GroupName,@GroupName,@UserName,@GroupResiD OUTPUT

		SELECT @GroupID=Max(GroupID)+1 FROM [ADM_RibbonView] WITH (NOLOCK) --WHERE TABID=@TabID
		select @GroupOrder=Max(GroupOrder)+1 FROM [ADM_RibbonView] WITH (NOLOCK)  where  TABID=@TabID
		end
		ELSE
			SELECT @GroupResiD=GroupResourceID,@GroupOrder=GroupOrder,@GroupName=GroupName FROM [ADM_RibbonView] WITH (NOLOCK) WHERE GroupID=@GroupID and TABID=@TabID


		if(@DrpID IS NOT NULL AND @DrpID>0 AND @TabID>0 AND @GroupID>0)
		BEGIN
		
			SELECT @TabResID=TabResourceID,@taborder=TabOrder,@TabName=TabName,@GroupResiD=GroupResourceID,@GroupOrder=GroupOrder,@GroupName=GroupName
			FROM [ADM_RibbonView] WITH (NOLOCK) WHERE GroupID=@GroupID and TABID=@TabID AND DrpID=@DrpID
		END
 
		--EXEC	[spCOM_SetInsertResourceData] @FeatureName,@FeatureName,@FeatureName,@UserName,1,@FeatureResourceID OUTPUT
		--EXEC	[spCOM_SetInsertResourceData] @ScreenName,@ScreenName,@ScreenName,@UserName,1,@SCRESID OUTPUT
		--EXEC	[spCOM_SetInsertResourceData] @ToolTipTitle,@ToolTipTitle,@ToolTipTitle,@UserName,1,@TTRESID OUTPUT
		--EXEC	[spCOM_SetInsertResourceData] @ToolTipDesc,@ToolTipDesc,@ToolTipDesc,@UserName,1,@TTDESRESID OUTPUT

		EXEC	spCOM_SetCostCenterLanguageData @FeatureName,@FeatureName,@UserName,@FeatureResourceID OUTPUT
		EXEC	spCOM_SetCostCenterLanguageData @ScreenName,@ScreenName,@UserName, @SCRESID OUTPUT
		EXEC	spCOM_SetCostCenterLanguageData @ToolTipTitle,@ToolTipTitle,@UserName,@TTRESID OUTPUT
		EXEC	spCOM_SetCostCenterLanguageData @ToolTipDesc,@ToolTipDesc,@UserName, @TTDESRESID OUTPUT
		 
		

		SELECT @RIBBONID=ISNULL(MAX(RibbonViewID),0)+1 FROM [ADM_RibbonView]

		
		IF ( @DrpID IS NULL OR @DrpID = '')
		SET @DrpID = @FeatureResourceID
		
		
		INSERT INTO [ADM_RibbonView]
						(	
							 [RibbonViewID],[TabID],[GroupID],[TabName],[TabResourceID],[GroupName] ,[GroupResourceID],[TabOrder] ,[GroupOrder],[FeatureID]
							,[FeatureActionID],[FeatureActionResourceID] ,[FeatureActionName] ,[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType]
							,[ImagePath],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID]
							,[UserName],[CompanyGUID] ,[GUID],[Description],[CreatedBy],[CreatedDate],DrpID  , ColumnOrder  , DrpName , DrpResourceID      
						)
					VALUES
						(
							 @RIBBONID,@TabID,@GroupID ,@TabName,@TabResID,@GroupName,@GroupResiD,@taborder,@GroupOrder
							,@FeatureID,@FeatureActionID,@FeatureResourceID,@FeatureName,1,@ScreenName,@SCRESID,0
							,@IMAGEPATH,@TTRESID,@ToolTipTitle,@IMAGEPATH,@TTDESRESID,@ToolTipDesc,1,1
							,@UserName,@CompanyGUID,NEWID(),@FeatureName,@UserName  ,CONVERT(FLOAT,GETDATE()),@DrpID,0 , @FeatureName, @FeatureResourceID 
						)
	--Inserting feature actions to the ROLE--  
	IF(EXISTS(SELECT * FROM ADM_FEATUREACTION WHERE  FeatureActionID=@FeatureActionID))
		if (select count(*) from ADM_FeatureActionRoleMap where FeatureActionID=@FeatureActionID)=0
			INSERT INTO [ADM_FeatureActionRoleMap]([RoleID],[FeatureActionID],[Status],[CreatedBy],[CreatedDate])
			 VALUES( 1,@FeatureActionID,1,@UserName,CONVERT(FLOAT,GETDATE()))
COMMIT TRANSACTION
END TRY
BEGIN CATCH
ROLLBACK TRANSACTION
SELECT 'ERROR OCCURED'
SELECT ERROR_MESSAGE()
END CATCH










GO
