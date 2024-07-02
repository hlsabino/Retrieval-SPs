USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetCRMAssignment]
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
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;     
 DECLARE @ID BIGINT , @IsRole BIT=0, @IsGroup BIT=0 ,@I INT,@COUNT INT ,@USER INT   
 DECLARE @UID INT,@UNM NVARCHAR(50),@VID INT
 declare @Assignactivitieswhileassigning bit, @ActivityID bigint,@ai int,@acnt int  
  
 DELETE FROM [CRM_Assignment]   
 WHERE [CCID]=@CCID AND [CCNODEID]=@CCNODEID AND (ISFROMACTIVITY=0 OR ISFROMACTIVITY IS NULL)  
  
 IF @@ERROR<>0 BEGIN  ROLLBACK TRANSACTION   RETURN -100 END  
 CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1) PRIMARY KEY,VALUE NVARCHAR(50),IsNew BIT)  
  
 INSERT INTO  #TBLTEMP (VALUE)  
 EXEC SPSPLITSTRING @UsersList,','  
 --ASSIGNED USERS  
 SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP WITH(NOLOCK)  
  
 WHILE @I<=@COUNT  
 BEGIN  
  SELECT @USER=VALUE FROM #TBLTEMP WITH(NOLOCK) WHERE ID=@I  
    
  INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup)  
  VALUES(@CCID,@CCNODEID,0,@USER,0,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),0,0)  
    
  SET @ID=SCOPE_IDENTITY()  
  
  INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup)  
  VALUES(@ID,@CCID,@CCNODEID,0,@USER,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,0,0)  
  
  SET @UID=(SELECT USERID FROM ADM_USERS WHERE USERNAME=@UserName)
  SET @UNM=(SELECT USERNAME FROM ADM_USERS WHERE USERID=@USER)
  INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
  VALUES(@ID,@CCID,@CCNODEID,0,@UID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,0,0,0,@USER,@UNM,'','Assign')    
  
  SET @I=@I+1  
 END  
      
 TRUNCATE TABLE #TBLTEMP  
 INSERT INTO  #TBLTEMP (VALUE)   
 EXEC SPSPLITSTRING @RolesList,','  
 --ASSIGNED ROLES  
 SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP WITH(NOLOCK)  
  
 WHILE @I<=@COUNT  
 BEGIN  
  SELECT @USER=VALUE,@VID=VALUE FROM #TBLTEMP WITH(NOLOCK) WHERE ID=@I  
  
  INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup)  
  VALUES(@CCID,@CCNODEID,@USER,0,0,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),1,0)  
  
  SET @ID=SCOPE_IDENTITY()  
  
  INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup)  
  VALUES(@ID,@CCID,@CCNODEID,@USER,0,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,1,0)  
  
  SET @UID=(SELECT USERID FROM ADM_USERS WHERE USERNAME=@UserName)
  SET @UNM=(SELECT USERNAME FROM ADM_USERS WHERE USERID=@USER)
  INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
  VALUES(@ID,@CCID,@CCNODEID,0,@UID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,@VID,0,0,@USER,@UNM,'','Assign')  
  
  SET @I=@I+1  
 END  
  
 TRUNCATE TABLE #TBLTEMP  
 INSERT INTO  #TBLTEMP (VALUE)   
 EXEC SPSPLITSTRING @GroupsList,','  
 --ASSIGNED GROUPS  
 SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP WITH(NOLOCK)  
  
 WHILE @I<=@COUNT  
 BEGIN  
  SELECT @USER=VALUE,@VID=VALUE FROM #TBLTEMP WITH(NOLOCK) WHERE ID=@I  
  
  INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup)  
  VALUES(@CCID,@CCNODEID,@USER,0,0,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),0,1)  
  
  SET @ID=SCOPE_IDENTITY()  
  
  INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup)  
  VALUES(@ID,@CCID,@CCNODEID,@USER,0,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,0,1) 
  
 SET @UID=(SELECT USERID FROM ADM_USERS WHERE USERNAME=@UserName)
 SET @UNM=(SELECT USERNAME FROM ADM_USERS WHERE USERID=@USER)
 INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
 VALUES(@ID,@CCID,@CCNODEID,0,@UID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,0,@VID,0,@USER,@UNM,'','Assign')    
  
  SET @I=@I+1  
 END  
  
 IF @TeamNodeID>0  
 BEGIN    
  INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],IsRole,IsGroup)  
  VALUES(@CCID,@CCNODEID,@TeamNodeID,@USERID,@IsTeam,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),@IsRole,@IsGroup)  
  
  SET @ID=SCOPE_IDENTITY()  
  
  INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup)  
  VALUES(@ID,@CCID,@CCNODEID,@TeamNodeID,@USERID,@IsTeam,CONVERT(FLOAT,GETDATE()),@UserName,@CompanyGUID,@IsRole,@IsGroup) 
  
  SET @UID=(SELECT USERID FROM ADM_USERS WHERE USERNAME=@UserName)
  SET @UNM=(SELECT USERNAME FROM ADM_USERS WHERE USERID=@USER)
  INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
  VALUES(@ID,@CCID,@CCNODEID,@TeamNodeID,@UID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,@IsRole,@IsGroup,0,@USER,@UNM,'','Assign')                
 END  
  
 --IF IT IS ASSIGNING FROM CRMCUSTOMERS THEN ASSIGN CONTACTS ALSO AGAINST THAT CUSTOMER  
 IF @CCID=83  
 BEGIN  
  IF(EXISTS(SELECT * FROM COM_CONTACTS WITH(nolock) WHERE FEATUREID=83 AND FEATUREPK=@CCNODEID))  
  BEGIN  
  
   DELETE FROM [CRM_Assignment] WHERE [CCID]=65 AND [CCNODEID] IN (  
   SELECT CONTACTID FROM COM_CONTACTS WITH(nolock) WHERE FEATUREID=83 AND FEATUREPK=@CCNODEID)  
   IF @@ERROR<>0 BEGIN  ROLLBACK TRANSACTION   RETURN -100 END  
  
   TRUNCATE TABLE #TBLTEMP  
  
   INSERT INTO #TBLTEMP (VALUE)  
   SELECT ISNULL(CONTACTID,0) FROM COM_CONTACTS WITH(nolock) WHERE FEATUREID=83 AND FEATUREPK=@CCNODEID  
  
   SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP WITH(NOLOCK)  
  
   WHILE @I<=@COUNT  
   BEGIN  
    SELECT @USER=VALUE FROM #TBLTEMP WITH(NOLOCK) WHERE ID=@I  
      
    INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],IsRole,IsGroup)  
    SELECT 65,@USER,[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],IsRole,IsGroup   
    FROM [CRM_Assignment] WITH(nolock)   
    WHERE [CCID]=83 AND [CCNODEID]=@CCNODEID  
  
    INSERT INTO [CRM_AssignmentHistory]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup)  
    SELECT [AssignmentID],65,@USER,[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup   
    FROM [CRM_Assignment]  WITH(nolock)  
    WHERE [CCID]=65 AND [CCNODEID]=@USER  
    
	INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
	 SELECT [AssignmentID],65,@USER,[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup   ,0,
	USERID,@UserName,'','Assign'
	FROM [CRM_Assignment]  WITH(nolock)  
    WHERE [CCID]=65 AND [CCNODEID]=@USER 
             
    SET @I=@I+1  
   END       
  END  
 END  
 ELSE IF @CCID=86--IF IT IS LEAD  
 BEGIN   
  UPDATE CRM_LEADS SET StatusID=419 where Leadid=@CCNodeID   
  --Added by pranathi  
  SELECT @Assignactivitieswhileassigning=Value FROM COM_CostCenterPreferences  WITH(nolock)   
  WHERE COSTCENTERID=@CCID and  Name='Assignactivitieswhileassigning'    
    
  if (@Assignactivitieswhileassigning=1)  
  BEGIN  
   declare  @t as table (id int identity(1,1), ActivityID bigint)  
   insert into @t  
   select ActivityID from crm_activities WITH(nolock) where costcenterid=@CCID and nodeid=@CCNodeid  
   select @ai=1,@acnt= count(*) from @t  
   while @ai<=@acnt  
   begin  
    select @ActivityID=ActivityID from @t where id=@ai  
    if(@ActivityID>0)  
     EXEC [spCRM_SetActivityAssignment] @CCID,@CCNODEID,@TeamNodeID,@USERID,@IsTeam,@UsersList,@RolesList,@GroupsList,@CompanyGUID,@UserName,@LangID,@ActivityID  
    set @ai=@ai+1  
   END  
  END   
 END  
 ELSE IF @CCID=73--IF IT IS Cases  
 BEGIN   
    
  UPDATE [CRM_Cases] SET ASSIGNEDDATE=CONVERT(FLOAT,GETDATE()) WHERE CASEID=@CCNodeID and ASSIGNEDDATE is null  
    
  --Need status id for case  
  declare @SID bigint, @Actstatus int  
  select @SID=convert(bigint,isnull(Value,0)) FROM COM_CostCenterPreferences WITH(nolock)   
  WHERE COSTCENTERID=@CCID and  Name='DefaultAssignStatus'    
    
  SELECT @Assignactivitieswhileassigning=Value FROM COM_CostCenterPreferences WITH(nolock)   
  WHERE COSTCENTERID=@CCID and  Name='Assignactivitieswhileassigning'    
   
  if(@SID is not null)  
   UPDATE CRM_Cases SET StatusID=@SID where Caseid=@CCNodeID   
  --Added by pranathi  
  if (@Assignactivitieswhileassigning=1)  
  BEGIN  
   declare  @tblAssignment as table (id int identity(1,1),ccid bigint, ccnodeid bigint, TeamNodeID bigint, IsTeam bit,  
   userid int, isGroup bit, IsRole bit, ActivityID bigint)  
     
   insert into @tblAssignment (ccid,ccnodeid,teamnodeid,isteam,userid,isgroup,isrole,ActivityID)  
   select ccid,ccnodeid,teamnodeid,isteam,userid,isgroup,isrole,IsFromActivity   
   from crm_assignment WITH(nolock)  
   where [CCID]=@CCID AND [CCNODEID]=@CCNODEID AND (ISFROMACTIVITY=0 OR ISFROMACTIVITY IS NULL)  
  
   declare  @tbl as table (id int identity(1,1), ActivityID bigint, Actstatus int)   
   insert into @tbl  
   select distinct ActivityID ,Statusid from crm_activities WITH(nolock)   
   where costcenterid=@CCID and nodeid=@CCNodeid  
     
   select @ai=1,@acnt= count(*) from @tbl  
   
   while @ai<=@acnt  
   BEGIN  
    select @ActivityID= ActivityID,@Actstatus=Actstatus from @tbl where id=@ai   
  
    if @ActivityID>0 and not exists (select isfromactivity from crm_assignment WITH(nolock) where isfromactivity=@ActivityID)   
    begin   
     EXEC [spCRM_SetActivityAssignment] @CCID,@CCNODEID,@TeamNodeID,@USERID,@IsTeam,@UsersList,@RolesList,@GroupsList,@CompanyGUID,@UserName,@LangID,@ActivityID  
    end  
    --Check for open activities  
    if @Actstatus=412 or @Actstatus=414 AND @ActivityID>0  
    begin   
     INSERT INTO  #TBLTEMP (VALUE)   
     EXEC SPSPLITSTRING @UsersList,','  
     SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP WITH(NOLOCK)  
     WHILE @I<=@COUNT  
     BEGIN  
      SELECT @USER=VALUE FROM #TBLTEMP WITH(NOLOCK) WHERE ID=@I  
      IF  @USER>0 AND EXISTS (SELECT USERID FROM CRM_ASSIGNMENT with(nolock) WHERE ISFROMACTIVITY=@ActivityID AND USERID IN   
      (SELECT USERID FROM @tblAssignment))  
      BEGIN  
       delete from CRM_ASSIGNMENT where ISFROMACTIVITY=@ActivityID  
       and userid in (SELECT USERID FROM @tblAssignment)  
          
       INSERT INTO [CRM_Assignment]([CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CompanyGUID],[GUID] ,[CreatedBy],[CreatedDate],IsRole,IsGroup,ISFROMACTIVITY)  
       VALUES(@CCID,@CCNODEID,0,@USER,0,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE()),0,0,@ActivityID)  
      END  
      set @I=@I+1  
     END   
    end   
    set @ai=@ai+1  
   END  
  END     
 END  
   
 --set notification  
 EXEC spCOM_SetNotifEvent -1000,@CCID,@CCNODEID,@CompanyGUID,@UserName,@UserID,-1  
   
COMMIT TRANSACTION    
SET NOCOUNT OFF;   
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
