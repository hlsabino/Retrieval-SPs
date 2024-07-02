USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_SetActivitiesAndSchedules]
	@ActivityXml [nvarchar](max),
	@CostCenterID [bigint],
	@NodeID [bigint],
	@CompanyGUID [nvarchar](max),
	@GUID [nvarchar](max),
	@UserName [nvarchar](300),
	@dt [float],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON 
BEGIN TRANSACTION
BEGIN TRY
	
	declare @LocalXml XML, @ScheduleID int, @ActivityID int,@TeamNodeID BIGINT=0,@USERID BIGINT=0,@IsTeam BIT=0,  
	@UsersList nvarchar(max)=null, @RolesList nvarchar(max)=null, @AttacthList nvarchar(max)=null,  @AttachXml XML, 
	@GroupsList nvarchar(max)=null, @MaxCount int ,@Count int,@IsEdited int, @stract nvarchar(max), @isRecur bit,@EXTRAFIELDSDATA NVARCHAR(MAX),
	@UpdateSQL NVARCHAR(MAX),@ContactID bigint,@strsch nvarchar(max)

	DECLARE @tblActivities TABLE (rowno int,ActivityID bigint,ActivityTypeID int,ScheduleID int,CostCenterID int,NodeID int,
	Status	int,Subject	nvarchar(MAX),Priority	int,PctComplete	float,Location	nvarchar(max),IsAllDayActivity	bit,
	ActualCloseDate	float,ActualCloseTime varchar(30),CustomerID	nvarchar(max),Remarks	nvarchar(MAX),AssignUserID	bigint,
	AssignRoleID bigint,AssignGroupID bigint,ActStartDate float,ActEndDate float,ActStartTime DateTime,ActEndTime DateTime, 
	Name nvarchar(200),StatusID	int,FreqType int,FreqInterval int,FreqSubdayType int,FreqSubdayInterval int,FreqRelativeInterval int,
	FreqRecurrenceFactor int,StartDate nvarchar(30),EndDate	nvarchar(30),AttachmentXML nvarchar(max),StartTime	nvarchar(30),
	EndTime	nvarchar(30),Message	nvarchar(MAX),isRecur bit,USERLIST NVARCHAR(MAX),USERID NVARCHAR(MAX),ROLELIST NVARCHAR(MAX),
	GROUPLIST NVARCHAR(MAX),TEAMNODEID NVARCHAR(MAX),ISTEAM NVARCHAR(MAX),EXTRAFIELDSDATA NVARCHAR(MAX),isEdited int,SchID bigint ,
	ContactID bigint)

	set @LocalXml=@ActivityXml

	insert into  @tblActivities(rowno ,ActivityID,ActivityTypeID,ScheduleID,CostCenterID,NodeID,
	StatusID,[Subject],Priority,PctComplete,Location,IsAllDayActivity,
	ActualCloseDate	,ActualCloseTime,CustomerID	,Remarks,AssignUserID,
	AssignRoleID,AssignGroupID,ActStartDate,ActEndDate,ActStartTime,ActEndTime,Name,[Status],
	FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval	,FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,
	EndTime,[Message],isRecur,USERLIST ,USERID ,ROLELIST,GROUPLIST,TEAMNODEID,ISTEAM,EXTRAFIELDSDATA,isEdited,SchID,AttachmentXML,ContactID)
	(select  ROW_NUMBER() over (order by (select 1)) ,
				X.value('@ActivityID','int'),
				X.value('@ActivityTypeID','int'),
				X.value('@ScheduleID','int'),
				@CostCenterID,
				@NodeID,
				X.value('@StatusID','int'),
				X.value('@Subject','nvarchar(max)'),
				X.value('@Priority','int'),
				X.value('@PctComplete','int'),
				X.value('@Location','nvarchar(max)'),
				X.value('@IsAllDayActivity','int'),
				convert(float,X.value('@ActualCloseDate','datetime')),
				X.value('@ActualCloseTime','varchar(20)'),
				X.value('@CustomerID','nvarchar(100)'),
				X.value('@Remarks','nvarchar(max)'),
				X.value('@AssignUserID','nvarchar(100)'),
				X.value('@AssignRoleID','nvarchar(100)'),
				X.value('@AssignGroupID','nvarchar(100)'),
				Convert (float,X.value('@ActStartDate','DateTime')),
				Convert (float,X.value('@ActEndDate','DateTime')),
				X.value('@ActStartTime','DateTime'),
				X.value('@ActEndTime','DateTime'),
				'Document',
				1,
				X.value('@FreqType','int'),
				X.value('@FreqInterval','int'),
				X.value('@FreqSubdayType','int'),
				X.value('@FreqSubdayInterval','int'),
				X.value('@FreqRelativeInterval','int'),
				X.value('@FreqRecurrenceFactor','int'),
				X.value('@CStartDate','nvarchar(100)'),
				X.value('@CEndDate','nvarchar(100)'),
				X.value('@StartTime','nvarchar(100)'),
				X.value('@EndTime','nvarchar(100)'),
				X.value('@Message','nvarchar(100)') ,
				X.value('@isRecu','bit') ,
				X.value('@UsersXML','nvarchar(MAX)') ,
				X.value('@UserID','nvarchar(MAX)') ,
				X.value('@RolesXML','nvarchar(MAX)') ,
				X.value('@GroupXML','nvarchar(MAX)') ,
				X.value('@TeamNodeID','nvarchar(MAX)') ,
				X.value('@isTeam','nvarchar(MAX)') ,	X.value('@ExtraUserDefinedFields','nvarchar(MAX)') ,
				X.value('@isEdited','int') ,X.value('@SchID','int') ,X.value('@AttachmentXML','nvarchar(MAX)'),X.value('@ContactID','bigint')
				FROM @LocalXml.nodes('/ScheduleActivityXml/Row') as Data(X) 
				where  X.value('@rowno','int')=0) 
					
	select  @stract =coalesce(@stract , '  ' , ' ')+ Convert(varchar(50), ActivityID)+','  ,@strsch=coalesce(@strsch,'','')+convert(varchar(50), ScheduleID)+', '  
	from CRM_Activities where CostCenterID =@CostCenterID and NodeID =@NodeID AND CREATEDBY=@UserName and   ActivityID not in 
	(select X.value('@ActivityID','int')  FROM @LocalXml.nodes('/ScheduleActivityXml/Row') as Data(X)  where  X.value('@rowno','int')=0  )

	set @stract=SUBSTRING(@stract,1,LEN(@stract)-1) 
	set @strsch=SUBSTRING(@strsch,1,LEN(@strsch)-1) 

	DECLARE @TList TABLE (Data varchar(max))   
	insert into @TList( Data) 
	exec [SPSplitString] @stract,',' 

	delete from CRM_Activities where  ActivityID in (select Convert(int,Data)from  @TList )
	delete from @TList

	delete from CRM_Activities where  ActivityID in (select X.value('@ActivityID','int')  FROM @LocalXml.nodes('/ScheduleActivityXml/DeleteRow') as Data(X) )

	insert into @TList( Data) 
	exec [SPSplitString] @strsch,',' 
	delete from COM_Schedules where  ScheduleID in (select Convert(int,Data)from  @TList )
	delete from COM_CCSchedules  where  ScheduleID in (select Convert(int,Data)from  @TList )

	select @Count=1,@MaxCount=Count(*) from @tblActivities 
	while(@Count<=@MaxCount)
	begin
		select @AttacthList=AttachmentXML, @ActivityID=ActivityID,@TeamNodeID=TeamNodeID,@USERID=USERID,@IsTeam=IsTeam,  
		@UsersList=USERLIST,@RolesList=ROLELIST,@EXTRAFIELDSDATA=EXTRAFIELDSDATA,
		@GroupsList=GROUPLIST,@IsEdited=isEdited, @isRecur=isRecur,@ScheduleID = ScheduleID
		from  @tblActivities  where rowno=@Count

		IF @IsEdited=0
		begin
			set @Count=@Count+1
			DELETE FROM [CRM_Assignment] WHERE IsFromActivity=@ActivityID

			EXEC [spCRM_SetActivityAssignment] @CostCenterID,@NodeID,@TeamNodeID,@USERID,@IsTeam,@UsersList,@RolesList,@GroupsList,@CompanyGUID,@UserName,@LangID,@ActivityID
			continue
		end
					
		update CRM_Activities set ActivityTypeID=A.ActivityTypeID, ScheduleID=@ScheduleID, CostCenterID=A.CostCenterID, NodeID=A.NodeID, 
		StatusID=A.StatusID, [Subject]=A.[Subject], Priority=A.Priority,PctComplete=A.PctComplete, 
		Location=A.Location, IsAllDayActivity=A.IsAllDayActivity, ActualCloseDate=(case when Convert(float,A.ActualCloseDate)=0 then null else Convert(float,A.ActualCloseDate) end ), 
		ActualCloseTime=A.ActualCloseTime,  CustomerID=A.CustomerID, Remarks=A.Remarks,AssignUserID=A.AssignUserID, 
		AssignRoleID=A.AssignRoleID, AssignGroupID=A.AssignGroupID,StartDate=A.ActStartDate,EndDate=A.ActEndDate,StartTime=A.ActStartTime,
		EndTime=A.ActEndTime,CompanyGUID=@CompanyGUID, [GUID]=@GUID,ModifiedBy=@UserName,ModifiedDate=@Dt,ContactID=A.ContactID
		from  CRM_Activities C WITH(NOLOCK),@tblActivities A
		where C.ActivityID=A.ActivityID and A.ActivityID<>0 and C.ActivityID=@ActivityID
		 
		IF @IsEdited=1
		BEGIN
			--Insert Notifications 
			IF EXISTS(SELECT * FROM CRM_Activities WITH(NOLOCK) WHERE StatusID=413 AND ActivityID=@ActivityID)
			   EXEC spCOM_SetNotifEvent -1004,@CostCenterID,@NodeID,@CompanyGUID,@UserName,@UserID,-1,144,@ActivityID
			ELSE
				EXEC spCOM_SetNotifEvent -1003,@CostCenterID,@NodeID,@CompanyGUID,@UserName,@UserID,-1,144,@ActivityID
	    END
	    
		if(@EXTRAFIELDSDATA is not null and @EXTRAFIELDSDATA <> '')		
		begin				
			set @UpdateSQL=' UPDATE CRM_Activities SET '+@EXTRAFIELDSDATA+' WHERE ActivityID='+CONVERT(NVARCHAR(50),@ActivityID)
			EXEC (@UpdateSQL)
		end
		
		DELETE FROM [CRM_Assignment] WHERE IsFromActivity=@ActivityID

		EXEC [spCRM_SetActivityAssignment] @CostCenterID,@NodeID,@TeamNodeID,@USERID,@IsTeam,@UsersList,@RolesList,@GroupsList,@CompanyGUID,@UserName,@LangID,@ActivityID
						
		--Inserts Multiple Attachments  
		IF (@AttacthList IS NOT NULL AND @AttacthList <> '')  
		BEGIN  
			set @AttachXml=@AttacthList 
			
			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
			FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate,IsSign)  
			SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
			X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),144,144,@ActivityID,  
			X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt,X.value('@IsSign','BIT')
			FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)    
			WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

			--If Action is MODIFY then update Attachments  
			UPDATE COM_Files SET FilePath=X.value('@FilePath','NVARCHAR(500)'),  
			ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),  
			RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),  
			FileExtension=X.value('@FileExtension','NVARCHAR(50)'),  
			FileDescription=X.value('@FileDescription','NVARCHAR(500)'),  
			IsProductImage=X.value('@IsProductImage','bit'),        
			[GUID]=X.value('@GUID','NVARCHAR(50)'),  
			ModifiedBy=@UserName,  
			ModifiedDate=@Dt  
			,IsSign=X.value('@IsSign','BIT')
			FROM COM_Files C WITH(NOLOCK)  
			INNER JOIN @AttachXml.nodes('/AttachmentsXML/Row') as Data(X) ON convert(bigint,X.value('@AttachmentID','bigint'))=C.FileID  
			WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  

			--If Action is DELETE then delete Attachments  
			DELETE FROM COM_Files  
			WHERE FileID IN(SELECT X.value('@AttachmentID','bigint')  
			FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)  
			WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
		END  
						 	
		set @Count=@Count+1
	end	  
 
	update CRM_Activities set ActivityTypeID=A.ActivityTypeID, ScheduleID=@ScheduleID, CostCenterID=A.CostCenterID, NodeID=A.NodeID, 
	StatusID=A.StatusID, [Subject]=A.[Subject], Priority=A.Priority, PctComplete=A.PctComplete, 
	Location=A.Location, IsAllDayActivity=A.IsAllDayActivity, ActualCloseDate=(case when Convert(float,A.ActualCloseDate)=0 then null else Convert(float,A.ActualCloseDate) end ), 
	ActualCloseTime=A.ActualCloseTime,  CustomerID=A.CustomerID, Remarks=A.Remarks,  AssignUserID=A.AssignUserID, 
	AssignRoleID=A.AssignRoleID, AssignGroupID=A.AssignGroupID,StartDate=A.ActStartDate,EndDate=A.ActEndDate,StartTime=A.ActStartTime,
	EndTime=A.ActEndTime, CompanyGUID=@CompanyGUID, [GUID]=@GUID ,  ModifiedBy=@UserName ,CONTACTID=A.ContactID, ModifiedDate=@Dt 
	from  CRM_Activities C WITH(NOLOCK),@tblActivities A
	where C.ActivityID=A.ActivityID and A.ActivityID<>0 and A.rowno=0

	delete from @tblActivities

	insert into  @tblActivities(rowno,ActivityID,ActivityTypeID,ScheduleID,CostCenterID,NodeID,
	StatusID ,[Subject],Priority,PctComplete,Location,IsAllDayActivity,
	ActualCloseDate,ActualCloseTime,CustomerID,Remarks,AssignUserID,
	AssignRoleID,AssignGroupID,ActStartDate,ActEndDate,ActStartTime,ActEndTime,Name,[Status],
	FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,
	EndTime,[Message],isRecur,USERLIST,USERID ,ROLELIST,GROUPLIST,TEAMNODEID,ISTEAM,EXTRAFIELDSDATA,SchID,AttachmentXML,ContactID)
	select X.value('@rowno','int'),
	X.value('@ActivityID','int'),
	X.value('@ActivityTypeID','int'),
	X.value('@ScheduleID','int'),
	@CostCenterID,
	@NodeID,
	X.value('@StatusID','int'),
	X.value('@Subject','nvarchar(max)'),
	X.value('@Priority','int'),
	X.value('@PctComplete','int'),
	X.value('@Location','nvarchar(max)'),
	X.value('@IsAllDayActivity','int'),
	Convert (float,X.value('@ActualCloseDate','datetime')),
	X.value('@ActualCloseTime','nvarchar(100)'),
	X.value('@CustomerID','nvarchar(100)'),
	X.value('@Remarks','nvarchar(max)'),
	Convert(bigint,  X.value('@AssignUserID','bigint')),
	Convert(bigint,  X.value('@AssignRoleID','bigint')),
	Convert(bigint,  X.value('@AssignGroupID','bigint')),
	Convert (float,X.value('@ActStartDate','DateTime')),
	Convert (float,X.value('@ActEndDate','DateTime')),
	X.value('@ActStartTime','DateTime'),
	X.value('@ActEndTime','DateTime'),
	'Document',
	1,
	X.value('@FreqType','int'),
	X.value('@FreqInterval','int'),
	X.value('@FreqSubdayType','int'),
	X.value('@FreqSubdayInterval','int'),
	X.value('@FreqRelativeInterval','int'),
	X.value('@FreqRecurrenceFactor','int'),
	X.value('@CStartDate','nvarchar(100)'),
	X.value('@CEndDate','nvarchar(100)'),
	X.value('@StartTime','nvarchar(100)'),
	X.value('@EndTime','nvarchar(100)'),
	X.value('@Message','nvarchar(100)') ,
	X.value('@isRecu','bit'),
	X.value('@UsersXML','nvarchar(MAX)') ,
	X.value('@UserID','nvarchar(MAX)') ,
	X.value('@RolesXML','nvarchar(MAX)') ,
	X.value('@GroupXML','nvarchar(MAX)') ,
	X.value('@TeamNodeID','nvarchar(MAX)') ,
	X.value('@isTeam','nvarchar(MAX)') ,	X.value('@ExtraUserDefinedFields','nvarchar(MAX)') ,
	X.value('@SchID','Int') ,X.value('@AttachmentXML','nvarchar(MAX)'),X.value('@ContactID','bigint')
	FROM @LocalXml.nodes('/ScheduleActivityXml/Row') as Data(X)  where  X.value('@rowno','int')>0
				 
	--ADDED ON AUG 21 2013
	DECLARE @TBLSCH TABLE(ID INT IDENTITY(1,1),SCHID INT)
	DECLARE @SCHID INT
	
	INSERT INTO @TBLSCH
	SELECT DISTINCT X.value('@SchID','Int')  FROM @LocalXml.nodes('/ScheduleActivityXml/Row') as Data(X)  
	where  X.value('@rowno','int')>0 AND X.value('@SchID','int')<0

	SELECT @Count=1,@MaxCount=COUNT(*) FROM  @TBLSCH
	WHILE (@Count<=@MaxCount)
	BEGIN
		SELECT @SCHID=SchID FROM @TBLSCH WHERE ID=@Count
		
		INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,FreqRelativeInterval,
		FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,[Message],CompanyGUID,[GUID],CreatedBy,CreatedDate)
		select Name,[Status],FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,FreqRelativeInterval,
		FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,[Message],@CompanyGUID,@GUID,@UserName,convert(float,getdate())
		from @tblActivities
		where SCHID=@SCHID
		
		set @ScheduleID=SCOPE_IDENTITY();
					
		INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
		VALUES(@CostCenterID,@NodeID,@ScheduleID,@UserName,@Dt) 
		 
		UPDATE @tblActivities SET SCHID=@ScheduleID 
		WHERE SCHID=@SCHID
				 
		set @Count=@Count+1
	END 
					
	select @Count=1,@MaxCount=Count(*) from @tblActivities
	while(@Count<=@MaxCount)
	begin	 
		select @AttacthList=AttachmentXML,@ActivityID=ActivityID,@ScheduleID=SCHID,@TeamNodeID =TeamNodeID,@USERID=USERID,@IsTeam =IsTeam,  
		@UsersList=USERLIST, @RolesList=ROLELIST,@GroupsList=GROUPLIST, @EXTRAFIELDSDATA=EXTRAFIELDSDATA,@isRecur=isRecur
		from  @tblActivities where rowno=@Count
					  
		INSERT INTO CRM_Activities (ActivityTypeID,ScheduleID,CostCenterID,NodeID,StatusID,[Subject],Priority,PctComplete, 
		Location,IsAllDayActivity,ActualCloseDate,ActualCloseTime, CustomerID, Remarks,AssignUserID,AssignRoleID, 
		AssignGroupID,StartDate,EndDate,StartTime,EndTime,CompanyGUID,[GUID],[Description],CreatedBy,CreatedDate,ContactID)
		select ActivityTypeID,@ScheduleID,@CostCenterID,@NodeID,StatusID,[Subject],Priority,PctComplete, 
		Location,IsAllDayActivity,Convert(float,ActualCloseDate),ActualCloseTime,CustomerID,Remarks,AssignUserID,AssignRoleID,
		AssignGroupID,ActStartDate,ActEndDate,ActStartTime,ActEndTime,@CompanyGUID,@GUID,null,@UserName,convert(float,getdate()),ContactID
		from @tblActivities where rowno=@Count
		SET @ActivityID=SCOPE_IDENTITY()
			
		--Insert Notifications
		EXEC spCOM_SetNotifEvent -1002,@CostCenterID,@NodeID,@CompanyGUID,@UserName,@UserID,-1,144,@ActivityID
		if(@EXTRAFIELDSDATA is not null and @EXTRAFIELDSDATA <> '')		
		begin						
			set @UpdateSQL=' UPDATE CRM_Activities SET '+@EXTRAFIELDSDATA+' WHERE ActivityID='+CONVERT(NVARCHAR(50),@ActivityID)
			EXEC (@UpdateSQL)
		end
	 	EXEC [spCRM_SetActivityAssignment] @CostCenterID,@NodeID,@TeamNodeID,@USERID,@IsTeam,@UsersList,@RolesList,@GroupsList,@CompanyGUID,@UserName,@LangID,@ActivityID
						 
		 --Inserts Multiple Attachments  
		IF (@AttacthList IS NOT NULL AND @AttacthList <> '')  
		BEGIN  
			set @AttachXml=@AttacthList
		
			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
			FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate)  
			SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
			X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),144,144,@ActivityID,  
			X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  
			FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)    
			WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

			--If Action is MODIFY then update Attachments  
			UPDATE COM_Files SET FilePath=X.value('@FilePath','NVARCHAR(500)'),  
			ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),  
			RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),  
			FileExtension=X.value('@FileExtension','NVARCHAR(50)'),  
			FileDescription=X.value('@FileDescription','NVARCHAR(500)'),  
			IsProductImage=X.value('@IsProductImage','bit'),        
			[GUID]=X.value('@GUID','NVARCHAR(50)'),  
			ModifiedBy=@UserName,  
			ModifiedDate=@Dt  
			FROM COM_Files C with(nolock)   
			INNER JOIN @AttachXml.nodes('/AttachmentsXML/Row') as Data(X) ON convert(bigint,X.value('@AttachmentID','bigint'))=C.FileID  
			WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  

			--If Action is DELETE then delete Attachments  
			DELETE FROM COM_Files  
			WHERE FileID IN(SELECT X.value('@AttachmentID','bigint')  
			FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)  
			WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
		END  
					
		set @Count=@Count+1
	end	 
			 
	IF @CostCenterID=128 --if activities are creating from events tab(CAMPAIGN) then change costcenter to its parent 
	BEGIN	
		--EXEC spCOM_SetActivityLinkingData  88 ,@NodeID
		SELECT @UpdateSQL=REFNO FROM CRM_Activities with(nolock) WHERE CostCenterID=88 AND NodeID=@NodeID
		IF(LEN(@UpdateSQL)=0)
			SELECT @UpdateSQL=Code FROM CRM_Campaigns with(nolock) WHERE CampaignID=@NodeID
		UPDATE CRM_Activities SET RefNo=@UpdateSQL WHERE CostCenterID=128 AND NodeID=@NodeID
	END
	ELSE
		EXEC spCOM_SetActivityLinkingData  @CostCenterID ,@NodeID					  
					
COMMIT TRANSACTION
--select * from CRM_Activities where CostCenterID=86 and NodeID=@NodeID
--rollback TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @ActivityID
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=2627  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-116 AND LanguageID=@LangID  
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
