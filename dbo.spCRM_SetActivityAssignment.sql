USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetActivityAssignment]
	@CCID [int] = 0,
	@CCNODEID [bigint] = 0,
	@TeamNodeID [bigint] = 0,
	@USERID [bigint] = 0,
	@IsTeam [bit] = 0,
	@UsersList [nvarchar](max) = null,
	@RolesList [nvarchar](max) = null,
	@GroupsList [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@LangID [int] = 1,
	@ActivityID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;   
	DECLARE @ID BIGINT , @IsRole BIT=0, @IsGroup BIT=0 ,@I INT,@COUNT INT ,@USER INT 

	DELETE FROM [CRM_Assignment] WHERE ISFROMACTIVITY=@ActivityID
	IF @@ERROR<>0 BEGIN  ROLLBACK TRANSACTION   RETURN -100 END
	CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),VALUE NVARCHAR(50))
 
	INSERT INTO  #TBLTEMP	
	EXEC SPSPLITSTRING @UsersList,','
	--ASSIGNED USERS
	SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP

	WHILE @I<=@COUNT
	BEGIN
		SELECT @USER=VALUE FROM #TBLTEMP WHERE ID=@I

		INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup,ISFROMACTIVITY)
		VALUES(@CCID,@CCNODEID,0,@USER,0,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),0,0,@ActivityID)

		SET @ID=SCOPE_IDENTITY()

		INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY)
		VALUES(@ID,@CCID,@CCNODEID,0,@USER,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,0,0,@ActivityID)  

		SET @I=@I+1
	END
	
	TRUNCATE TABLE #TBLTEMP
	INSERT INTO  #TBLTEMP	
	EXEC SPSPLITSTRING @RolesList,','
	--ASSIGNED ROLES
	SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP

	WHILE @I<=@COUNT
	BEGIN
		SELECT @USER=VALUE FROM #TBLTEMP WHERE ID=@I
		
		INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup,ISFROMACTIVITY)
		VALUES(@CCID,@CCNODEID,@USER,0,0,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),1,0,@ActivityID)
		
		SET @ID=SCOPE_IDENTITY()

		INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY)
		VALUES(@ID,@CCID,@CCNODEID,@USER,0,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,1,0,@ActivityID)  

		SET @I=@I+1
	END

	TRUNCATE TABLE #TBLTEMP
	INSERT INTO  #TBLTEMP	
	EXEC SPSPLITSTRING @GroupsList,','
	--ASSIGNED GROUPS
	SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP

	WHILE @I<=@COUNT
	BEGIN
		SELECT @USER=VALUE FROM #TBLTEMP WHERE ID=@I

		INSERT INTO  [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup,ISFROMACTIVITY)
		VALUES(@CCID,@CCNODEID,@USER,0,0,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),0,1,@ActivityID)
		SET @ID=SCOPE_IDENTITY()

		INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY)
		VALUES(@ID,@CCID,@CCNODEID,@USER,0,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,0,1,@ActivityID)  

		SET @I=@I+1
	END

	IF @TeamNodeID>0
	BEGIN	
		INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],IsRole,IsGroup,ISFROMACTIVITY)
		VALUES(@CCID,@CCNODEID,@TeamNodeID,@USERID,@IsTeam,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),@IsRole,@IsGroup,@ActivityID)
		
		SET @ID=SCOPE_IDENTITY()

		INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY)
		VALUES(@ID,@CCID,@CCNODEID,@TeamNodeID,@USERID,@IsTeam,CONVERT(FLOAT,GETDATE()),@UserName,@CompanyGUID,@IsRole,@IsGroup,@ActivityID)        
	END
	
	--Added preference based Assign all activities to lead owner
	DECLARE @AssignActivitytoOwner bit, @leaduserid bigint, @LeadUsername nvarchar(100), @ActUsername nvarchar(100)
	if(@CCID=86 and @CCNODEID>0 AND @ActivityID>1)
	BEGIN
		SELECT @AssignActivitytoOwner=value FROM COM_CostCenterPreferences  WITH(nolock) 
		WHERE COSTCENTERID=@CCID and  Name='Assignallactivitiestoowner' 
		if(@AssignActivitytoOwner=1)
		begin
			select @LeadUsername=CreatedBy from crm_leads where LeadID=@CCNODEID
			select @ActUsername=CreatedBy from CRM_Activities where ActivityID=@ActivityID
			if (lower(@LeadUsername)<>lower(@ActUsername) and lower(@LeadUsername)<>'admin')
			BEGIN
				select @leaduserid=userid from ADM_Users with(nolock) where lower(UserName)=LOWER(@LeadUsername)
				if not exists (select * from CRM_Assignment with(nolock) where [CCID]=@CCID AND CCNODEID=@CCNODEID 
				AND UserID=@leaduserid AND ISFROMACTIVITY=@ActivityID and IsRole=0 and IsGroup=0) 
				BEGIN
					INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup,ISFROMACTIVITY)
					VALUES(@CCID,@CCNODEID,0,@leaduserid,0,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),0,0,@ActivityID)
					
					SET @ID=SCOPE_IDENTITY() 
					
					INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY)
					VALUES(@ID,@CCID,@CCNODEID,0,@leaduserid,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,0,0,@ActivityID)  
				END
			END
		end

		SELECT @AssignActivitytoOwner=Value FROM COM_CostCenterPreferences  WITH(nolock) 
		WHERE COSTCENTERID=@CCID and  Name='Assignactivitieswhileassigning'  
		if(@AssignActivitytoOwner=1)
		begin
			DECLARE @TAB TABLE (ID INT IDENTITY(1,1),AssignmentID BIGINT)
			INSERT INTO @TAB
			SELECT AssignmentID
			FROM CRM_Assignment with(nolock)
			where [CCID]=@CCID AND CCNODEID=@CCNODEID AND ISFROMACTIVITY=0
			ORDER BY AssignmentID

			DECLARE @AssignmentID BIGINT
			SELECT @I=1,@COUNT=COUNT(*) FROM @TAB

			WHILE @I<=@COUNT
			BEGIN
			SELECT @AssignmentID=AssignmentID FROM @TAB WHERE ID=@I
				IF NOT EXISTS (SELECT [TeamNodeID],USERID,[IsTeam],IsRole,IsGroup
				FROM CRM_Assignment with(nolock)
				where [CCID]=@CCID AND CCNODEID=@CCNODEID AND ISFROMACTIVITY=0 AND AssignmentID=@AssignmentID
				INTERSECT
				SELECT [TeamNodeID],USERID,[IsTeam],IsRole,IsGroup
				FROM CRM_Assignment with(nolock)
				where [CCID]=@CCID AND CCNODEID=@CCNODEID AND ISFROMACTIVITY=@ActivityID)
				BEGIN
					INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup,ISFROMACTIVITY)
					SELECT [CCID],CCNODEID,[TeamNodeID],USERID,[IsTeam],[CompanyGUID],NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),IsRole,IsGroup,@ActivityID
					FROM CRM_Assignment with(nolock)
					where AssignmentID=@AssignmentID

					SET @ID=SCOPE_IDENTITY() 

					INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY)
					SELECT @ID,[CCID],CCNODEID,[TeamNodeID],USERID,[IsTeam],CONVERT(FLOAT,GETDATE()),@UserName,[CompanyGUID],IsRole,IsGroup,@ActivityID
					FROM CRM_Assignment with(nolock)
					where AssignmentID=@AssignmentID
				END
				SET @I=@I+1
			END
		end 
	END

	--Added preference based Assign all activities to case assigned user
	if(@CCID=73 and @CCNODEID>0 AND @ActivityID>1)
	BEGIN 
		SELECT @AssignActivitytoOwner=value FROM COM_CostCenterPreferences WITH(nolock) 
		WHERE COSTCENTERID=@CCID and Name='Assignallactivitiestoowner' 
		if(@AssignActivitytoOwner=1)
		begin   
			if not exists (select isfromactivity from [CRM_Assignment] WITH(nolock) where isfromactivity=@ActivityID and CCID=@CCID AND CCNODEID=@CCNODEID )
			begin
				INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup,ISFROMACTIVITY)
				SELECT CCID,CCNODEID,TEAMNODEID,USERID,ISTEAM,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),0,0,@ActivityID
				from CRM_Assignment WITH(nolock) where CCID=@CCID AND CCNODEID=@CCNODEID and (isfromactivity=0 or isfromactivity is null)
			end
		end 
	END

COMMIT TRANSACTION  
SET NOCOUNT OFF; 
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
  WHERE ErrorNumber=100 AND LanguageID=@LangID    

RETURN 1 
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
