USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_SetReportMap]
	@Type [int],
	@ReportID [int],
	@MapXML [nvarchar](max),
	@RowColumnMapXML [nvarchar](max) = null,
	@DocMapXML [nvarchar](max) = null,
	@APIMapXML [nvarchar](max) = null,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section
	DECLARE @Dt float,@XML xml
	
	IF @Type=0
	BEGIN
		set @XML=@MapXML
		set @Dt=CONVERT(float,getdate())
		
		delete from ADM_ReportsMap where ParentReportID=@ReportID
		
		insert into ADM_ReportsMap(Sno,ParentReportID,ChildReportID
			,ShowTitle,ReportTitle
			,ShowColumns,ShowTotals
			,MapXML
			,CreatedBy,CreatedDate)
		select X.value('@Sno','int'),@ReportID,X.value('@ReportID','INT') 
			,X.value('@ShowTitle','bit'),X.value('@ReportTitle','nvarchar(500)')
			,X.value('@ShowColumns','bit'),X.value('@ShowTotals','bit')
			,X.value('@MapXML','nvarchar(max)')
			,@UserName,@Dt
		from @XML.nodes('/XML/Row') as Data(X)
		
		update ADM_RevenUReports
		set RowColumnReportsMap=@RowColumnMapXML,DocMapXML=@DocMapXML
		where ReportID=@ReportID
		
		EXEC [dbo].[spDOC_SetAPIFieldsMapping]
			@CostCenterID = 50,
			@DocumentFieldsXml= @APIMapXML,
			@UserName = @UserName,
			@UserID =1,
			@LangID =@LangID
	END
	ELSE IF @Type=1
	BEGIN
		select M.*,R.ReportName,R.ReportDefnXML,R.StaticReportType
		from ADM_ReportsMap M with(nolock) 
		inner join ADM_RevenUReports R with(nolock) on M.ChildReportID=R.ReportID
		where ParentReportID=@ReportID
		order by Sno
		
		select RowColumnReportsMap ,DocMapXML 
		FROM ADM_RevenUReports with(nolock)
		where ReportID=@ReportID
		
		select DocumentName,CostCenterID from ADM_DocumentTypes WITH(NOLOCK)
		
		select * from COM_APIFieldsMapping WITH(NOLOCK)
		WHERE CostCenterID=50 AND Mode=@ReportID
		
	END
	ELSE IF @Type=2
	BEGIN
		select R.ReportDefnXML,R.StaticReportType
		from ADM_RevenUReports R with(nolock)
		where ReportID=@ReportID
	END
	ELSE IF @Type=3
	BEGIN
		select Sno,R.ReportName,R.ReportDefnXML,R.ReportID
		from ADM_ReportsMap M with(nolock) 
		inner join ADM_RevenUReports R with(nolock) on M.ChildReportID=R.ReportID
		where ParentReportID=@ReportID
		order by Sno		
	END
	ELSE IF @Type=4
	BEGIN
		set @Dt=CONVERT(float,getdate())
		set @MapXML='WEBLAND_'+@MapXML
		if @ReportID=0
		begin
			if exists (select Name from COM_Config with(nolock) where Name=@MapXML)
				RAISERROR('-112',16,1)
			insert into COM_Config(Name,Value)
			values(@MapXML,@RowColumnMapXML)
			SET @ReportID=SCOPE_IDENTITY()
		end
		else
		begin
			update COM_Config
			set Value=@RowColumnMapXML
			where ID=@ReportID
		end

		DECLARE @TblApp AS TABLE(R INT NOT NULL DEFAULT(0))
		insert into @TblApp(R)
		EXEC [SPSplitString] @DocMapXML,','

		declare @RID int

		select @RID=M.RoleID from ADM_Assign M with(nolock) 
		join @TblApp T on M.RoleID=T.R
		where CostCenterID=1 AND NodeID!=@ReportID
		if(@RID is not null)
		begin
			set @MapXML=''
			select @MapXML='Role "'+Name+'" already assigned' from ADM_PRoles with(nolock) where RoleID=@RID
			RAISERROR(@MapXML,16,1)
		end
		
		DELETE FROM ADM_Assign 
		WHERE CostCenterID=1 AND NodeID=@ReportID

		INSERT INTO ADM_Assign(CostCenterID,NodeID,GroupID,RoleID,UserID,CreatedBy,CreatedDate)
		SELECT 1,@ReportID,0,R,0,@UserName,@Dt
		FROM @TblApp
	END
		
COMMIT TRANSACTION  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;  
RETURN @ReportID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		IF isnumeric(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
			WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		ELSE
			SELECT ERROR_MESSAGE() ErrorMessage
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
