USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetRecurrence]
	@CostCenterID [int],
	@NodeID [int],
	@ScheduleID [int],
	@ScheduleName [nvarchar](100),
	@StatusID [int],
	@FreqType [int],
	@FreqInterval [int],
	@FreqSubdayType [int],
	@FreqSubdayInterval [int],
	@FreqRelativeInterval [int],
	@FreqRecurrenceFactor [int],
	@StartDate [nvarchar](20) = NULL,
	@EndDate [nvarchar](20) = NULL,
	@StartTime [nvarchar](20) = NULL,
	@EndTime [nvarchar](20) = NULL,
	@Message [nvarchar](max) = NULL,
	@Gropus [nvarchar](max),
	@Roles [nvarchar](max),
	@Users [nvarchar](max),
	@Occurrence [int] = 0,
	@RecurAutoPost [int] = 1,
	@RecurMethod [tinyint],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
	--Declaration Section    
	DECLARE @HasAccess BIT,@Dt FLOAT
	DECLARE @TblApp AS TABLE(G INT NOT NULL DEFAULT(0),R INT NOT NULL DEFAULT(0),U INT NOT NULL DEFAULT(0))
	
	SET @Dt=CONVERT(FLOAT,GETDATE())

	--IF EXISTS (SELECT ScheduleID FROM COM_Schedules WITH(NOLOCK) WHERE ScheduleName=@ScheduleName AND ScheduleID<>@ScheduleID)
	--BEGIN  
		--RAISERROR('-112',16,1)  
	--END
    
	IF @ScheduleID=0
	BEGIN	
		INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
				FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,Message,Occurrence,RecurAutoPost,RecurMethod,
				CompanyGUID,GUID,CreatedBy,CreatedDate)
		VALUES(@ScheduleName,@StatusID,@FreqType,@FreqInterval,@FreqSubdayType,@FreqSubdayInterval,
				@FreqRelativeInterval,@FreqRecurrenceFactor,@StartDate,@EndDate,@StartTime,@EndTime,@Message,@Occurrence,@RecurAutoPost,@RecurMethod,
				@CompanyGUID,NEWID(),@UserName,@Dt)
		SET @ScheduleID=SCOPE_IDENTITY()  

		INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
		VALUES(@CostCenterID,@NodeID,@ScheduleID,@UserName,@Dt)
	END
	ELSE
	BEGIN
		IF (SELECT COUNT(*) FROM COM_SchEvents with(nolock) WHERE ScheduleID=@ScheduleID AND StatusID=2)>0
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-386 AND LanguageID=@LangID    
			ROLLBACK TRANSACTION    
			SET NOCOUNT OFF   
			RETURN -1
		END
		
		DELETE FROM COM_SchEvents WHERE ScheduleID=@ScheduleID
		
		UPDATE COM_Schedules
		SET StatusID=@StatusID,FreqType=@FreqType,FreqInterval=@FreqInterval,FreqSubdayType=@FreqSubdayType,
			FreqSubdayInterval=@FreqSubdayInterval,FreqRelativeInterval=@FreqRelativeInterval,
			FreqRecurrenceFactor=@FreqRecurrenceFactor,StartDate=@StartDate,EndDate=@EndDate,
			StartTime=@StartTime,EndTime=@EndTime,Message=@Message,Occurrence=@Occurrence,RecurAutoPost=@RecurAutoPost,RecurMethod=@RecurMethod,
			GUID=NEWID(),[ModifiedBy] = @UserName,[ModifiedDate] = CONVERT(FLOAT,GETDATE()) 
		WHERE ScheduleID=@ScheduleID
	END
	
	if (@RecurAutoPost=0 and exists(select * from ACC_DocDetails WITH(NOLOCK)
	where CostCenterID=@CostCenterID and DocID=@NodeID and StatusID=369))
	BEGIN
		update a
		set PostRecurWithApproval=0
		from ACC_DocDetails a WITH(NOLOCK)
		where CostCenterID=@CostCenterID and DocID=@NodeID
	END
	
	DELETE FROM COM_UserSchedules WHERE ScheduleID=@ScheduleID
	
	INSERT INTO @TblApp(G)
	EXEC [SPSplitString] @Gropus,','

	INSERT INTO @TblApp(R)
	EXEC [SPSplitString] @Roles,','

	INSERT INTO @TblApp(U)
	EXEC [SPSplitString] @Users,','

	INSERT INTO COM_UserSchedules(ScheduleID,GroupID,RoleID,UserID
		,CreatedBy,CreatedDate)
	SELECT @ScheduleID,G,R,U,@UserName,@Dt
	FROM @TblApp
	ORDER BY U,R,G

COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
--SELECT * FROM COM_NotifTemplate WITH(nolock) WHERE ScheduleID=@ScheduleID     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;      
RETURN  @ScheduleID    
END TRY    
BEGIN CATCH      
	--Return exception info [Message,Number,ProcedureName,LineNumber]      
	IF ERROR_NUMBER()=50000    
	BEGIN    
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
