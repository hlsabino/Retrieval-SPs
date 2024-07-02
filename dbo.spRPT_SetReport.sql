USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_SetReport]
	@ReportID [bigint],
	@ReportName [nvarchar](500),
	@Description [nvarchar](max) = null,
	@ReportTypeID [int],
	@ReportTypeName [nvarchar](500),
	@IsUserDefined [bit],
	@ReportDefnXML [nvarchar](max),
	@CustomPreferences [nvarchar](max),
	@SelectedNodeID [bigint],
	@IsGroup [bit],
	@StatusID [int],
	@StaticReportType [int],
	@TreeXML [nvarchar](max) = NULL,
	@DefaultPreferences [nvarchar](max) = NULL,
	@ReportBody [nvarchar](max) = NULL,
	@ReportHeader [nvarchar](max) = NULL,
	@PageHeader [nvarchar](max) = NULL,
	@PageFooter [nvarchar](max) = NULL,
	@ReportFooter [nvarchar](max) = NULL,
	@FormulaFieldsXML [nvarchar](max) = NULL,
	@KPIXML [nvarchar](max) = NULL,
	@QUERY [nvarchar](max) = NULL,
	@MatrixXML [nvarchar](max) = NULL,
	@DashKPIXML [nvarchar](max) = NULL,
	@SaveAsReportID [bigint] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section
	DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50),@HasAccess bit,@IsDuplicateNameAllowed bit,@IsAccountCodeAutoGen bit
	DECLARE @UpdateSql nvarchar(max),@ParentCode nvarchar(200),@CCCCCData XML,@IsIgnoreSpace bit
	DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint
	DECLARE @SelectedIsGroup bit

	SET @Dt=convert(float,getdate())--Setting Current Date

	IF @SaveAsReportID=0
	BEGIN
		IF @ReportID=0--------START INSERT RECORD-----------
		BEGIN--CREATE REPORT--
				
				IF EXISTS (SELECT ReportID FROM [ADM_RevenUReports] WITH(nolock) WHERE ReportID>0 AND ReportName=@ReportName) 
				BEGIN  
					RAISERROR('-112',16,1)  
				END
				
				if @SelectedNodeID=0
					set @SelectedNodeID=1

				--To Set Left,Right And Depth of Record
				SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
				from [ADM_RevenUReports] with(NOLOCK) where ReportID=@SelectedNodeID

				--IF No Record Selected or Record Doesn't Exist
				IF(@SelectedIsGroup is null) 
					select @SelectedNodeID=ReportID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
					from [ADM_RevenUReports] with(NOLOCK) where ParentID =0
							
				IF(@SelectedIsGroup = 1)--Adding Node Under the Group
				BEGIN
						UPDATE [ADM_RevenUReports] SET rgt = rgt + 2 WHERE rgt > @Selectedlft;
						UPDATE [ADM_RevenUReports] SET lft = lft + 2 WHERE lft > @Selectedlft;
						SET @lft =  @Selectedlft + 1
						SET @rgt =	@Selectedlft + 2
						SET @ParentID = @SelectedNodeID
						SET @Depth = @Depth + 1
				END
				ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level
				BEGIN
						UPDATE [ADM_RevenUReports] SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
						UPDATE [ADM_RevenUReports] SET lft = lft + 2 WHERE lft > @Selectedrgt;
						SET @lft =  @Selectedrgt + 1
						SET @rgt =	@Selectedrgt + 2 
				END
				ELSE  --Adding Root
				BEGIN
						SET @lft =  1
						SET @rgt =	2 
						SET @Depth = 0
						SET @ParentID =0
						SET @IsGroup=1
				END
				
				-- Insert statements for procedure here
				INSERT INTO [ADM_RevenUReports]
							(ReportName,Description,
							ReportTypeID ,
							ReportTypeName,
							IsUserDefined,
							ReportDefnXML,
							CustomPreferences,
							IsEnabled,
							[IsGroup],[StatusID],[Depth],[ParentID],[lft],[rgt],
							StaticReportType,TreeXML,DefaultPreferences,
							ReportBody,ReportHeader,PageHeader,PageFooter,ReportFooter,KPIXML,QUERY,MatrixXML,DashKPIXML,FormulaFields,
							[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
							VALUES
							(@ReportName,@Description,
							@ReportTypeID,
							@ReportTypeName,
							@IsUserDefined,
							@ReportDefnXML,
							@CustomPreferences,
							1,
							@IsGroup,@StatusID,@Depth,@ParentID,@lft,@rgt,
							@StaticReportType,@TreeXML,@DefaultPreferences,
							@ReportBody,@ReportHeader,@PageHeader,@PageFooter,@ReportFooter,@KPIXML,@QUERY,@MatrixXML,@DashKPIXML,@FormulaFieldsXML,
							@CompanyGUID,newid(),@UserName,@Dt)

				--To get inserted record primary key
				SET @ReportID=SCOPE_IDENTITY()

				INSERT INTO ADM_ReportsUserMap(UserID,RoleID,GroupID,ReportID,CreatedBy,CreatedDate,ActionType)
				VALUES(@UserID,0,0,@ReportID,@UserName,@Dt,1)
				
				INSERT INTO ADM_ReportsUserMap(UserID,RoleID,GroupID,ReportID,CreatedBy,CreatedDate,ActionType)
				VALUES(@UserID,0,0,@ReportID,@UserName,@Dt,2)
				
				INSERT INTO ADM_ReportsUserMap(UserID,RoleID,GroupID,ReportID,CreatedBy,CreatedDate,ActionType)
				VALUES(@UserID,0,0,@ReportID,@UserName,@Dt,3)
				
				INSERT INTO ADM_ReportsUserMap(UserID,RoleID,GroupID,ReportID,CreatedBy,CreatedDate,ActionType)
				VALUES(@UserID,0,0,@ReportID,@UserName,@Dt,4)
		END--------END INSERT RECORD-----------
		ELSE--------START UPDATE RECORD-----------
		BEGIN	
				IF EXISTS (SELECT ReportID FROM [ADM_RevenUReports] WITH(nolock) WHERE ReportName=@ReportName AND ReportID>0 AND ReportID<>@ReportID) 
				BEGIN  
					RAISERROR('-112',16,1)  
				END 

				UPDATE [ADM_RevenUReports]
				   SET ReportName = @ReportName,[Description]=@Description
					  --,ReportTypeID = @ReportTypeID
					  ,ReportTypeName = @ReportTypeName
					  --,IsUserDefined = @IsUserDefined
					  ,ReportDefnXML=@ReportDefnXML
					  ,CustomPreferences=@CustomPreferences
					  --,[IsGroup] = @IsGroup		
					  ,[StatusID] = @StatusID
					  ,ReportBody=@ReportBody,ReportHeader=@ReportHeader,PageHeader=@PageHeader
					  ,PageFooter=@PageFooter,ReportFooter=@ReportFooter,KPIXML=@KPIXML,QUERY=@QUERY
					  ,MatrixXML=@MatrixXML,DashKPIXML=@DashKPIXML,FormulaFields=@FormulaFieldsXML
					  ,[GUID] =  newid()
					  ,[ModifiedBy] = @UserName
					  ,[ModifiedDate] = @Dt
				 WHERE ReportID=@ReportID      
					 
		END
	END
	ELSE
	BEGIN

		UPDATE [ADM_RevenUReports]
		   SET [Description]=@Description--ReportName = @ReportName
			  --,ReportTypeID = @ReportTypeID
			  --,ReportTypeName = @ReportTypeName
			  --,IsUserDefined = @IsUserDefined
			  ,ReportDefnXML=@ReportDefnXML
			  ,CustomPreferences=@CustomPreferences
			  --,[IsGroup] = @IsGroup		
			  --,[StatusID] = @StatusID	
			  ,ReportBody=@ReportBody,ReportHeader=@ReportHeader,PageHeader=@PageHeader
			  ,PageFooter=@PageFooter,ReportFooter=@ReportFooter,KPIXML=@KPIXML,QUERY=@QUERY
			  ,MatrixXML=@MatrixXML,DashKPIXML=@DashKPIXML,FormulaFields=@FormulaFieldsXML
			  ,[GUID] =  newid()
			  ,[ModifiedBy] = @UserName
			  ,[ModifiedDate] = @Dt
		 WHERE ReportID=@SaveAsReportID     
	
		SET @ReportID=@SaveAsReportID
	END
	
COMMIT TRANSACTION  
SELECT * FROM [ADM_RevenUReports] WITH(nolock) WHERE ReportID=@ReportID
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;  
RETURN @ReportID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM [ADM_RevenUReports] WITH(nolock) WHERE ReportID=@ReportID
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
