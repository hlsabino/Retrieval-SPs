USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetInvite]
	@CCID [int] = 0,
	@CCNODEID [int] = 0,
	@TeamNodeID [int] = 0,
	@USERID [int] = 0,
	@IsTeam [bit] = 0,
	@UsersList [nvarchar](max) = null,
	@RolesList [nvarchar](max) = null,
	@GroupsList [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@LangID [int] = 1,
	@InviteComments [nvarchar](max)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;   


	DECLARE @ID INT , @IsRole BIT=0, @IsGroup BIT=0 ,@I INT,@COUNT INT ,@USER INT ,@ActivityID INT
	
	DECLARE @SQL NVARCHAR(MAX),@COLS NVARCHAR(MAX)=''
	select @COLS=@COLS+','+name
	from sys.columns WITH(NOLOCK)
	where object_id=object_id('CRM_Activities') and (name LIKE 'Alpha%' OR name LIKE 'CCNID%')
	
	if( @CCNODEID>0)
	BEGIN
		if exists(select InviteRefActID  from CRM_Activities with(nolock) where InviteRefActID=@CCNODEID)
		begin 
			delete from CRM_Assignment where IsFromActivity in (select activityid from CRM_Activities with(nolock) where statusid=7 and InviteRefActID=@CCNODEID)
			delete from CRM_Activities where statusid=7 and InviteRefActID=@CCNODEID 
		end 
					
		SET @SQL='INSERT INTO  CRM_Activities
		(ActivityTypeID, ScheduleID, CostCenterID, NodeID, StatusID, Subject, Priority
		, PctComplete, Location, IsAllDayActivity, ActualCloseDate, ActualCloseTime, CustomerID
		, Remarks, AssignUserID, AssignRoleID, AssignGroupID, CompanyGUID, GUID, Description
		, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, StartDate, EndDate, StartTime, EndTime
		, AccountID, RefNo, CustomerType, InviteComments, InviteStatus'+@COLS+')
		SELECT 
		 ActivityTypeID, ScheduleID, CostCenterID, NodeID, 7, Subject, Priority, PctComplete  
		, Location, IsAllDayActivity, ActualCloseDate, ActualCloseTime, CustomerID, Remarks, AssignUserID, AssignRoleID, AssignGroupID
		, CompanyGUID, GUID, Description, '''+@UserName+''', CONVERT(FLOAT,GETDATE()), '''', NULL, StartDate, EndDate, StartTime, EndTime
		, AccountID, RefNo, CustomerType,'''+@InviteComments+''','''''+@COLS+'  
		FROM CRM_ACTIVITIES with(nolock) WHERE ACTIVITYID='+CONVERT(NVARCHAR,@CCNODEID)+'
		set @ActivityID=scope_identity()'
		EXEC sp_executesql @SQL,N'@ActivityID INT OUTPUT',@ActivityID OUTPUT		 
		
	END

	declare @CostCenterID INT, @NodeID INT
	select @CostCenterID=costcenterid, @NodeID = nodeid from CRM_ACTIVITIES with(nolock) WHERE ACTIVITYID= @ActivityID

  	EXEC [spCRM_SetActivityAssignment] @CostCenterID,@NodeID,@TeamNodeID,@USERID,@IsTeam,@UsersList,@RolesList,@GroupsList,@CompanyGUID,
						@UserName,@LangID,@ActivityID
	
	create table #temp (id int identity(1,1),AssignmentID INT, ActivityID INT, UserID INT)
	insert into #temp
	select AssignmentID, IsFromActivity, UserID from CRM_Assignment with(nolock) where IsFromActivity=@ActivityID
	declare @acnt int, @cnt int, @AssignmentID INT, @tempActID INT, @tempUId INT
	set @acnt=1
	select @cnt=COUNT(*) from #temp with(nolock)
	while @acnt<=@cnt
	begin
	
		set @tempActID=0
		select @AssignmentID=assignmentid,@tempUId=UserID  from #temp with(nolock) where id=@acnt
		
		if not exists( select assignmentid from CRM_Assignment with(nolock) where UserID=@tempUId and IsFromActivity in 
		(select activityid from CRM_Activities with(nolock) where InviteRefActID=@CCNODEID))
		begin 
			SET @SQL='INSERT INTO  CRM_Activities
			(ActivityTypeID, ScheduleID, CostCenterID, NodeID, StatusID, Subject, Priority
			, PctComplete, Location, IsAllDayActivity, ActualCloseDate, ActualCloseTime, CustomerID
			, Remarks, AssignUserID, AssignRoleID, AssignGroupID, CompanyGUID, GUID, Description
			, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, StartDate, EndDate, StartTime, EndTime
			, AccountID, RefNo, CustomerType, InviteComments, InviteStatus, InviteRefActID'+@COLS+')
			SELECT 
			 ActivityTypeID, ScheduleID, CostCenterID, NodeID, 7, Subject, Priority, PctComplete  
			, Location, IsAllDayActivity, ActualCloseDate, ActualCloseTime, CustomerID, Remarks, AssignUserID, AssignRoleID, AssignGroupID
			, CompanyGUID, GUID, Description, '''+@UserName+''', CONVERT(FLOAT,GETDATE()), '''', NULL, StartDate, EndDate, StartTime, EndTime
			, AccountID, RefNo, CustomerType, InviteComments, InviteStatus,'+CONVERT(NVARCHAR,@CCNODEID)+@COLS+'   
			FROM CRM_ACTIVITIES with(nolock) WHERE ACTIVITYID='+CONVERT(NVARCHAR,@ActivityID)+' 
			set @tempActID=scope_identity()'
			EXEC sp_executesql @SQL,N'@tempActID INT OUTPUT',@tempActID OUTPUT 
			
			update CRM_Assignment set IsFromActivity=@tempActID where AssignmentID=@AssignmentID 
		end
		else 
		begin
			delete from CRM_Assignment where AssignmentID=@AssignmentID
		end
		set @acnt=@acnt+1
	end 
	delete from CRM_Activities where ActivityID =@ActivityID
						
						
COMMIT TRANSACTION  
SET NOCOUNT OFF; 
RETURN @ActivityID 
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
