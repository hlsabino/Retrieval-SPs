USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_DeleteReport]
	@ReportID [bigint] = 0,
	@ForceDelete [bit] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
		DECLARE @RowsDeleted bigint,@lft bigint,@rgt bigint,@DashName nvarchar(max)

		--SP Required Parameters Check
		IF(@ReportID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		IF NOT EXISTS (SELECT ReportID FROM ADM_RevenUReports with(nolock) WHERE ReportID=@ReportID AND IsUserDefined=0)
		BEGIN
			--Fetch left, right extent of Node along with width.
			SELECT @lft = lft, @rgt = rgt
			FROM ADM_RevenUReports WITH(NOLOCK) WHERE ReportID=@ReportID
			
			declare @Tbl as table(id int identity(1,1),ReportID bigint)
			insert into @Tbl
			select ReportID from ADM_RevenUReports with(nolock) WHERE lft >= @lft AND rgt <= @rgt 
			
			select @DashName=DashBoardName 
			from ADM_DashBoard D with(nolock) join @Tbl T on D.reportid=T.reportid where TypeID=1 or TypeID=2
			if @DashName is not null
			begin
				SELECT 'Report can not be deleted, Used in dashboard - '+@DashName ErrorMessage,-102 ErrorNumber
				ROLLBACK TRANSACTION
				return -102
			end

			if @ForceDelete=0 and exists(select * from ADM_ReportsUserMap M with(nolock) join @Tbl T on M.reportid=T.reportid where ActionType=1 and UserID!=@UserID)
			begin
				SELECT 'Report assigned to users. Still do you want to delete report?' ErrorMessage,-101 ErrorNumber
				ROLLBACK TRANSACTION
				return -101
			end
				
			DELETE FROM ADM_ReportsUserMap WHERE ReportID IN (SELECT REPORTID FROM @Tbl)
			
			DELETE FROM ADM_ReportsMap 
			WHERE ParentReportID  IN (SELECT REPORTID FROM @Tbl) OR ChildReportID IN (SELECT REPORTID FROM @Tbl)	
		
			DELETE FROM ADM_RevenUReports WHERE ReportID  IN (SELECT REPORTID FROM @Tbl)
			SET @RowsDeleted=@@rowcount

			--Update left and right extent to set the tree
			UPDATE ADM_RevenUReports SET rgt = rgt - 2 WHERE rgt > @rgt;
			UPDATE ADM_RevenUReports SET lft = lft - 2 WHERE lft > @rgt;

			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
			WHERE ErrorNumber=102 AND LanguageID=@LangID
		END
		ELSE
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
			WHERE ErrorNumber=-200 AND LanguageID=@LangID
		END

COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SET NOCOUNT OFF;  
RETURN @RowsDeleted
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
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
