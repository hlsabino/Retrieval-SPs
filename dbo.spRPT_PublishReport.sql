USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_PublishReport]
	@flg [bit] = 0,
	@FeatureID [int],
	@Module [int] = 0,
	@ModuleText [nvarchar](300) = 0,
	@SelectedDrpID [int] = 0,
	@SelectedDrpTEXT [nvarchar](300) = 0,
	@ReportID [bigint] = 0,
	@ReportName [nvarchar](300) = 0,
	@UnpublishReport [bit] = 0,
	@MobileReports [int] = 0,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section
	DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50)  
	declare @TabID int,
			@GroupID int,
			@FeatureActionID int,
			@TabName varchar(200),
			@GroupName varchar(200),
			@FeatureName varchar(200),
			@ScreenName VARCHAR(200),@DrpID INT,@ribbonviewid int,@Image nvarchar(100)
	SET @Dt=convert(float,getdate())--Setting Current Date
	
	IF @flg=1
	BEGIN
		SET @Module=6 
	END
	
	SELECT @TabID=@Module,@TabName=TABNAME FROM ADM_RibbonView WITH(NOLOCK) WHERE TabID=@Module 
	
	IF @SelectedDrpID>0
	BEGIN
		 SELECT @GroupID=isnull(GroupID,0),@GroupName=GROUPNAME FROM ADM_RibbonView WITH(NOLOCK) WHERE TabID=@Module 
		 AND DRPID=@SelectedDrpID  
	END
	ELSE IF @SelectedDrpID=-100 AND @flg=0
	 BEGIN 
		  SET @GroupName='Custom Reports' 
		  SELECT @GroupID=isnull(GroupID,0) FROM ADM_RibbonView WITH(NOLOCK) WHERE TabID=@Module 
		  AND GROUPNAME=@GroupName  
	 END
	 ELSE
	 begin
		  SET @GroupName=@ModuleText 
		  SELECT @GroupID=isnull(GroupID,0) FROM ADM_RibbonView WITH(NOLOCK) WHERE TabID=@Module 
		  AND GROUPNAME=@GroupName  
	 end
	
	 
	 --ADM_BULK_EDIT.png
	 
	IF @UnpublishReport=0
	BEGIN
	BEGIN TRANSACTION
		if @FeatureID=494
			set @Image='ADM_BULK_EDIT.png'
		else
			set @Image='REP_List-of-reports.png'
		
		IF @SelectedDrpID=-100 
			set @DrpID=NULL    
		ELSE
			SET @DrpID=@SelectedDrpID
		IF @GroupID IS NULL OR @GroupID=''
			SET @GroupID=0
			
		DELETE FROM ADM_RibbonView WHERE FEATUREID=@FeatureID AND FEATUREACTIONID=@ReportID  	 
		
		exec  [spADM_SetRibbonView] @TabID,@GroupID,@FeatureID,@ReportID,'',@GroupName,@ReportName,@ReportName,@ReportName,
			 @ReportName,0,0,'CompanyGUID','GUID','admin',1,1,@Image,@DrpID 
		
		--Added parameter for display @ Mobile application 
		update adm_ribbonview set ismobile=@MobileReports where tabid=@TabID and Featureid=@FeatureID and FEATUREACTIONID=@ReportID 
		--select * from adm_ribbonview where FeatureID=494
	COMMIT TRANSACTION 
	END
	ELSE
	BEGIN
	BEGIN TRANSACTION
		DELETE FROM ADM_RibbonView WHERE FEATUREID=@FeatureID AND FEATUREACTIONID=@ReportID 
	COMMIT TRANSACTION 
	END
	   
--rollback transaction
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=104 AND LanguageID=@LangID  
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
	 
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
