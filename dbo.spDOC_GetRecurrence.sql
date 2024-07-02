USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetRecurrence]
	@NodeID [bigint] = 0,
	@CostCenterID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	DECLARE @ScheduleID BIGINT
	SET @ScheduleID=0
	--SP Required Parameters Check
	--IF (@AccountID < 1)
	--BEGIN
		--RAISERROR('-100',16,1)
	--END

	--Groups
	SELECT GID,GroupName FROM COM_Groups WITH(NOLOCK)
	Group By GID,GroupName
	HAVING GroupName IS NOT NULL
	ORDER BY GroupName

	--Roles
	SELECT RoleID, Name FROM ADM_PRoles WITH(NOLOCK)
	WHERE StatusID=434
	ORDER BY Name

	--Getting All Users
	SELECT UserID,UserName FROM ADM_Users WITH(NOLOCK)
	WHERE StatusID=1 and IsUserDeleted=0
	ORDER BY UserName 

	
	SELECT @ScheduleID=ScheduleID FROM COM_CCSchedules WITH(NOLOCK)
	WHERE CostCenterID=@CostCenterID AND NodeID=@NodeID
	
	IF @ScheduleID>0
	BEGIN
		SELECT *,CONVERT(DATETIME, StartDate) CStartDate,CONVERT(DATETIME, EndDate) CEndDate FROM COM_Schedules WITH(NOLOCK) WHERE ScheduleID=@ScheduleID

		SELECT UserID,RoleID,GroupID FROM COM_UserSchedules WITH(NOLOCK) WHERE ScheduleID=@ScheduleID
	END

 SET NOCOUNT OFF;
RETURN @ScheduleID
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
