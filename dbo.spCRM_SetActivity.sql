USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetActivity]
	@ActivityTypeID [int],
	@ScheduleID [int] = 0,
	@CCID [int] = 0,
	@STATUS [int],
	@SUBJECT [nvarchar](300) = NULL,
	@PRIORITY [int] = 0,
	@LOCATION [nvarchar](300) = NULL,
	@IsAllDayActivity [bit] = 0,
	@CUSTOMERID [nvarchar](300) = NULL,
	@CUSTOMERSELECTED [int] = NULL,
	@CUSTOMERTYPE [nvarchar](300) = NULL,
	@REMARKS [nvarchar](max) = NULL,
	@STARTDATE [datetime] = NULL,
	@ENDDATE [datetime] = NULL,
	@CLOSEDATE [datetime] = NULL,
	@CLOSETIME [nvarchar](300) = NULL,
	@STARTTIME [nvarchar](300) = NULL,
	@ENDTIME [nvarchar](300) = NULL,
	@IsReschedule [int] = NULL,
	@AssignedUser [int] = NULL,
	@EXTRAFIELDSQUERY [nvarchar](max) = NULL,
	@AttachmentData [nvarchar](max) = null,
	@ACTIVIYID [int] = 0,
	@SchID [int] = 0,
	@FreqType [int] = 0,
	@FreqInterval [int] = 0,
	@FreqSubdayType [int] = 0,
	@FreqSubdayInterval [int] = 0,
	@FreqRelativeInterval [int] = 0,
	@FreqRecurrenceFactor [int] = 0,
	@FirstPostingDate [nvarchar](100) = null,
	@RStartingTime [nvarchar](100) = null,
	@REndDate [nvarchar](100) = null,
	@REndingTime [nvarchar](100) = null,
	@ContactID [int] = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON 
BEGIN TRANSACTION
BEGIN TRY
	IF @CCID=-100
	SET @CCID=1000

	Declare @NID INT , @Tempactid INT,@SQL NVARCHAR(MAX),@PrefValue NVARCHAR(500)
	set @NID=0
	select @NID=NodeID from CRM_Activities with(nolock) WHERE ACTIVITYID=@ACTIVIYID
	
	IF @IsReschedule<>-1
	BEGIN 
		UPDATE CRM_Activities SET StatusID=413,IsReschedule='true',ActualCloseDate=CONVERT(FLOAT,@CLOSEDATE),ActualCloseTime=@CLOSETIME,Remarks=@REMARKS
		WHERE ACTIVITYID=@ACTIVIYID

		set @Tempactid=@ACTIVIYID
		SET @ACTIVIYID=0
		SET @STATUS=414
	END
   
	IF @AssignedUser IS NULL OR @AssignedUser=0
		SET @AssignedUser=@UserID
	
	select @PrefValue = Value from COM_CostCenterPreferences WITH(nolock)  where CostCenterID=1000 and  Name = 'DonotOverlapActivities'
	if(@PrefValue is not null and @PrefValue='true')
	BEGIN
		SET @SQL='if exists(SELECT ActivityID FROM CRM_Activities with(nolock) 
		WHERE ( '''+convert(nvarchar,CAST(CONVERT(DATE,@STARTDATE) AS DATETIME)+CAST(CONVERT(TIME,CONVERT(DATETIME,@STARTTIME)) AS DATETIME))+''' between CONVERT(datetime, CAST(CONVERT(DATE,CONVERT(DATETIME,StartDate)) AS DATETIME)+CAST(Dateadd(SECOND,1,CONVERT(TIME,StartTime)) AS DATETIME)) and CONVERT(datetime, CAST(CONVERT(DATE,CONVERT(DATETIME,EndDate)) AS DATETIME)+CAST(Dateadd(SECOND,-1,CONVERT(TIME,EndTime)) AS DATETIME))      
		or '''+convert(nvarchar,CAST(CONVERT(DATE,@ENDDATE) AS DATETIME)+CAST(CONVERT(TIME,CONVERT(DATETIME,@ENDTIME)) AS DATETIME))+''' between CONVERT(datetime, CAST(CONVERT(DATE,CONVERT(DATETIME,StartDate)) AS DATETIME)+CAST(Dateadd(SECOND,1,CONVERT(TIME,StartTime)) AS DATETIME)) and CONVERT(datetime, CAST(CONVERT(DATE,CONVERT(DATETIME,EndDate)) AS DATETIME)+CAST(Dateadd(SECOND,-1,CONVERT(TIME,EndTime)) AS DATETIME))
		or CONVERT(datetime, CAST(CONVERT(DATE,CONVERT(DATETIME,StartDate)) AS DATETIME)+CAST( Dateadd(SECOND,1,CONVERT(TIME,StartTime)) AS DATETIME)) between '''+convert(nvarchar,CAST(CONVERT(DATE,@STARTDATE) AS DATETIME)+CAST(CONVERT(TIME,CONVERT(DATETIME,@STARTTIME)) AS DATETIME))+''' and '''+convert(nvarchar,CAST(CONVERT(DATE,@ENDDATE) AS DATETIME)+CAST(CONVERT(TIME,CONVERT(DATETIME,@ENDTIME)) AS DATETIME))+''' 
 		or CONVERT(datetime, CAST(CONVERT(DATE,CONVERT(DATETIME,EndDate)) AS DATETIME)+CAST(Dateadd(SECOND,-1,CONVERT(TIME,EndTime)) AS DATETIME)) between '''+convert(nvarchar,CAST(CONVERT(DATE,@STARTDATE) AS DATETIME)+CAST(CONVERT(TIME,CONVERT(DATETIME,@STARTTIME)) AS DATETIME))+''' and '''+convert(nvarchar,CAST(CONVERT(DATE,@ENDDATE) AS DATETIME)+CAST(CONVERT(TIME,CONVERT(DATETIME,@ENDTIME)) AS DATETIME))+'''   )             
		AND CostCenterID = '+convert(nvarchar,@CCID)
		
		select @PrefValue = Value from COM_CostCenterPreferences WITH(nolock)  where CostCenterID=1000 and  Name = 'DayViewRepeatOn'
		if(@PrefValue is not null and @PrefValue<>'' and @PrefValue<>'0')
		begin
			SET @PrefValue='CCNID'+CONVERT(NVARCHAR,(CONVERT(INT,@PrefValue)-50000))+'='
			
			IF(Charindex(@PrefValue,@EXTRAFIELDSQUERY) >0 AND ABS(Charindex(',',@EXTRAFIELDSQUERY,Charindex(@PrefValue,@EXTRAFIELDSQUERY))-Charindex(@PrefValue,@EXTRAFIELDSQUERY))<>1)
			BEGIN
				SELECT @PrefValue=Substring(@EXTRAFIELDSQUERY,Charindex(@PrefValue,@EXTRAFIELDSQUERY),ABS(Charindex(',',@EXTRAFIELDSQUERY,Charindex(@PrefValue,@EXTRAFIELDSQUERY))-Charindex(@PrefValue,@EXTRAFIELDSQUERY)))
			END
			ELSE IF(Charindex(@PrefValue,@EXTRAFIELDSQUERY) >0)
				SELECT @PrefValue=@EXTRAFIELDSQUERY
			--ELSE
			--	RAISERROR('Select Day ViewRepeat On Dimension',16,1)
			--if(@PrefValue is not null and @PrefValue<>'')
			--	set @SQL= @SQL+' and '+@PrefValue
		END
		
		set @SQL= @SQL+' and ActivityID<>'+convert(nvarchar,@ACTIVIYID )+')
		RAISERROR(''-582'',16,1)'		 		

		print @SQL
		exec(@SQL)
	END	
	
	IF @ACTIVIYID=0
	BEGIN
		INSERT INTO CRM_Activities(ActivityTypeID, ScheduleID, CostCenterID, NodeID, StatusID, [Subject], Priority,Location, IsAllDayActivity, CustomerID, Remarks, 
		ActualCloseDate,ActualCloseTime, StartDate,EndDate,StartTime,EndTime, CompanyGUID, [GUID],  CreatedBy, CreatedDate,CustomerType,AssignUserID)
		VALUES (@ActivityTypeID,@ScheduleID,@CCID,@NID,@STATUS,@SUBJECT,@PRIORITY,@LOCATION,@IsAllDayActivity,@CUSTOMERID,@REMARKS
		,CONVERT(FLOAT,@CLOSEDATE),@CLOSETIME,CONVERT(FLOAT,@STARTDATE),CONVERT(FLOAT,@ENDDATE),@STARTTIME,@ENDTIME,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),@CUSTOMERTYPE,@AssignedUser)
		
		set @ACTIVIYID=scope_identity()  
		 
		if(@SchID>0 and not exists (select ScheduleID from com_schedules with(nolock) where ScheduleID=@SchID))
		begin
			INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,FreqRelativeInterval,FreqRecurrenceFactor,
			StartDate,EndDate,StartTime,EndTime,CompanyGUID,[GUID],CreatedBy,CreatedDate)
			values('Recurrence',1,@FreqType,@FreqInterval,@FreqSubdayType,@FreqSubdayInterval,@FreqRelativeInterval,@FreqRecurrenceFactor,
			@FirstPostingDate,@REndDate,@RStartingTime,@REndingTime,@CompanyGUID,newid(),@UserName,convert(float,getdate()))
			set @SchID=SCOPE_IDENTITY();
			update CRM_Activities set ScheduleID=@SchID where ActivityID=@ACTIVIYID
		 end
		 else if(@SchID>0 and exists (select ScheduleID from com_schedules with(nolock) where ScheduleID=@SchID))
		 	update CRM_Activities set ScheduleID=@SchID where ActivityID=@ACTIVIYID 
		   
		  EXEC spCOM_SetNotifEvent -1002,@CCID,@NID,@CompanyGUID,@UserName,@UserID,-1,144,@ACTIVIYID
	END
	ELSE
	BEGIN				
		UPDATE CRM_Activities SET ActivityTypeID=@ActivityTypeID, ScheduleID=@ScheduleID,   StatusID=@STATUS, [Subject]=@SUBJECT
					, Priority=@PRIORITY, ActualCloseDate=CONVERT(FLOAT,@CLOSEDATE),ActualCloseTime=@CLOSETIME ,
					Location=@LOCATION, IsAllDayActivity=@IsAllDayActivity,  CustomerType=@CUSTOMERTYPE,AssignUserID=@AssignedUser,
					CustomerID=@CUSTOMERID, Remarks=@REMARKS,   StartDate=CONVERT(FLOAT,@STARTDATE)
					,EndDate=CONVERT(FLOAT,@ENDDATE),StartTime=@STARTTIME,EndTime=@ENDTIME, CompanyGUID=@CompanyGUID, [GUID]=NEWID()
		WHERE ACTIVITYID=@ACTIVIYID
				
		declare @NodeID INT
		select @NodeID=NodeID from CRM_Activities with(nolock)  WHERE ACTIVITYID=@ACTIVIYID

		IF @STATUS=413
			EXEC spCOM_SetNotifEvent -1004,@CCID,@NID,@CompanyGUID,@UserName,@UserID,-1,144,@ACTIVIYID
		ELSE				
			EXEC spCOM_SetNotifEvent -1003,@CCID,@NodeID,@CompanyGUID,@UserName,@UserID,-1,144,@ACTIVIYID
	END

	IF @IsReschedule<>-1
	BEGIN 
		UPDATE CRM_ActivityStatusLog SET ActivityID = @ACTIVIYID WHERE ACTIVITYID=@Tempactid
	END

	
	IF(@ContactID <>'' or @ContactID is not null )
		update CRM_Activities set ContactID=@ContactID where ActivityID=@ACTIVIYID 
	IF @CCID=1000
		UPDATE CRM_Activities SET ACCOUNTID=@CUSTOMERSELECTED WHERE ACTIVITYID=@ACTIVIYID
			
	if(@IsReschedule<>-1)
	begin
		insert into CRM_Assignment ([CCID],[CCNODEID],[TeamNodeID],[IsTeam],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate]
		,[ModifiedBy],[ModifiedDate],[UserID],[IsGroup],[IsRole],IsFromActivity)
		SELECT [CCID],[CCNODEID],[TeamNodeID],[IsTeam],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate]
		,[ModifiedBy],[ModifiedDate],[UserID],[IsGroup],[IsRole],@ACTIVIYID
		 FROM [CRM_Assignment] with(nolock) where IsFromActivity = @Tempactid
	end
	
	IF(@EXTRAFIELDSQUERY IS NOT NULL AND @EXTRAFIELDSQUERY<>'')
	BEGIN
		SET @SQL=' UPDATE CRM_Activities SET '+@EXTRAFIELDSQUERY+' WHERE ACTIVITYID='+CONVERT(NVARCHAR(50),@ACTIVIYID)
		EXEC(@SQL)
	END		
	
	--Inserts Multiple Attachments  
	DECLARE @Dt FLOAT
	SET @Dt=CONVERT(FLOAT,GETDATE())

	IF (@AttachmentData IS NOT NULL AND @AttachmentData <> '')
	exec [spCOM_SetAttachments] @ACTIVIYID,144,@AttachmentData,@UserName,@Dt

	/*
	IF (@AttachmentData IS NOT NULL AND @AttachmentData <> '')  
	BEGIN  
		declare @AttachXml xml
		set @AttachXml=@AttachmentData 
		INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate)  
		SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
		X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),144,144,@ACTIVIYID,  
		X.value('@GUID','NVARCHAR(50)'),@UserName,CONVERT(float,getdate())  
		FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

		--If Action is MODIFY then update Attachments  
		UPDATE COM_Files  
		SET FilePath=X.value('@FilePath','NVARCHAR(500)'),  
		ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),  
		RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),  
		FileExtension=X.value('@FileExtension','NVARCHAR(50)'),  
		FileDescription=X.value('@FileDescription','NVARCHAR(500)'),  
		IsProductImage=X.value('@IsProductImage','bit'),        
		[GUID]=X.value('@GUID','NVARCHAR(50)'),  
		ModifiedBy=@UserName,  
		ModifiedDate=CONVERT(float,getdate())  
		FROM COM_Files C with(nolock)  
		INNER JOIN @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)    
		ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID  
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  

		--If Action is DELETE then delete Attachments  
		DELETE FROM COM_Files  
		WHERE FileID IN(SELECT X.value('@AttachmentID','INT')  
		FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
	END   
	*/

COMMIT TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN 1
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  IF ISNUMERIC(ERROR_MESSAGE())<>1
	SELECT ERROR_MESSAGE() ErrorMessage
 ELSE
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
