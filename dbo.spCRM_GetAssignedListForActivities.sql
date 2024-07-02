USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetAssignedListForActivities]
	@CCID [int] = 0,
	@CCNODEID [int] = 0,
	@ActivityID [bigint] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	 DECLARE @ASSIGNEDLIST NVARCHAR(MAX)
	 DECLARE @TABLE TABLE(ID INT IDENTITY(1,1),ANODEID INT,USERID INT,IsRole bit,IsGroup bit,IsTeam INT, IsFromActivity bigint)
	 if(@ActivityID>0)
		 INSERT INTO @TABLE
		 SELECT TEAMNODEID,USERID,IsGroup,IsRole,IsTeam, isFromActivity FROM CRM_Assignment WITH(NOLOCK) WHERE CCID=@CCID 
		 AND CCNODEID=@CCNODEID and IsFromActivity=@ActivityID
	else
		 INSERT INTO @TABLE
		 SELECT TEAMNODEID,USERID,IsGroup,IsRole,IsTeam, isFromActivity FROM CRM_Assignment WITH(NOLOCK) WHERE CCID=@CCID 
		 AND CCNODEID=@CCNODEID and IsFromActivity is not null order by IsFromActivity
		 
	 DECLARE @ActTABLE TABLE(ID INT IDENTITY(1,1), IsFromActivity bigint, AssignDate float, UserData nvarchar(300),GroupData nvarchar(300), TeamData nvarchar(300), RoleData nvarchar(300))
	 if(@ActivityID>0)
		 INSERT INTO @ActTABLE (IsFromActivity, AssignDate)
		 SELECT  distinct(isFromActivity), CreatedDate FROM CRM_Assignment WITH(NOLOCK) 
		 WHERE CCID=@CCID AND CCNODEID=@CCNODEID and IsFromActivity=@ActivityID 
	else
		 INSERT INTO @ActTABLE (IsFromActivity, AssignDate)
		 SELECT  distinct(isFromActivity), CreatedDate FROM CRM_Assignment WITH(NOLOCK) 
		 WHERE CCID=@CCID AND CCNODEID=@CCNODEID and IsFromActivity is not null   order by createddate 
	
	 declare @ai int, @acnt int, @actid bigint
	 set @ai=1
	 select @acnt=COUNT(*) from @ActTABLE
	 while @ai<=@acnt
	 begin
		DECLARE @COUNT INT,@I INT,@ISTEAM INT,@ISROLE INT,@ISGROUP INT,@UserDATA NVARCHAR(300),@TeamDATA NVARCHAR(300),@RoleDATA NVARCHAR(300),
		@GroupDATA NVARCHAR(300),@TOUSER NVARCHAR(300),@DATE DATETIME
		SELECT @I=1,@COUNT=COUNT(*) FROM @TABLE
		SET @UserDATA=''
		SET @TeamDATA=''
		SET @RoleDATA=''
		SET @GroupDATA=''
		select @actid=isfromactivity from @ActTABLE where ID=@ai
		WHILE @I<=@COUNT
		BEGIN
			if(@actid= (select isfromactivity from @TABLE where ID=@I))
			begin
			--select * from @TABLE where ID=@I
			SELECT @ISTEAM=IsTeam,@ISROLE=IsRole,@ISGROUP=IsGroup FROM @TABLE WHERE ID=@I
		
			IF @ISTEAM=0 AND @ISROLE=0 AND @ISGROUP=0 
			BEGIN
				SELECT 	@UserDATA=@UserDATA + UserName +',' FROM ADM_Users WITH(NOLOCK) WHERE UserID =(
				SELECT USERID FROM @TABLE WHERE ID=@I)
				--select @UserDATA
			END
			ELSE IF @ISTEAM=1
			BEGIN 
				SELECT 	@TeamDATA=@TeamDATA+ TEAMNAME +'-[Team] ,' FROM CRM_TEAMS WITH(NOLOCK) WHERE TeamID =(
				SELECT ANODEID FROM @TABLE WHERE ID=@I)
			END	
			ELSE IF @ISGROUP=1
			BEGIN
				SELECT  @GroupDATA=@GroupDATA+GROUPNAME +'-[Group] ,' FROM COM_Groups WITH(NOLOCK) WHERE GROUPNAME<>'' and GID =(
				SELECT ANODEID FROM @TABLE WHERE ID=@I)
			END	
			ELSE IF @ISROLE=1
			BEGIN 
				SELECT  @RoleDATA=@RoleDATA+NAME +'-[Role] ,' FROM ADM_PROLES WITH(NOLOCK) WHERE ROLEID =(
				SELECT ANODEID FROM @TABLE WHERE ID=@I)
			END	
				SET @I=@I+1	
			end
			else
				SET @I=@I+1	
		END		
		
		set @ai=@ai+1
	 	if len(@GroupDATA)>0
 			set @GroupDATA=substring(@GroupDATA,1,len(@GroupDATA)-1)
 		if len(@UserDATA)>0
 			set @UserDATA=substring(@UserDATA,1,len(@UserDATA)-1)
 		if len(@RoleDATA)>0
 			set @RoleDATA=substring(@RoleDATA,1,len(@RoleDATA)-1)
 		if len(@TeamDATA)>0
 			set @TeamDATA=substring(@TeamDATA,1,len(@TeamDATA)-1) 
			update @ActTABLE set  GroupDATA=@GroupData, UserDATA=@UserData, RoleDATA=@RoleData, TeamDATA =@TeamData 
			 where IsFromActivity=@actid
		 
		END 
		select *, convert(datetime,assigndate) ActAssignDate from @ActTABLE
END


GO
