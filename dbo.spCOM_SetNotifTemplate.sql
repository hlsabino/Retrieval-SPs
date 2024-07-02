USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetNotifTemplate]
	@TemplateID [int],
	@TemplateName [nvarchar](100),
	@TemplateType [int],
	@StatusID [int],
	@From [nvarchar](max) = NULL,
	@DisplayName [nvarchar](max) = NULL,
	@To [nvarchar](max),
	@CC [nvarchar](max) = NULL,
	@BCC [nvarchar](max) = NULL,
	@IgnoreMailsTo [nvarchar](max) = NULL,
	@AttachmentType [nvarchar](50) = NULL,
	@AttachmentID [int],
	@Subject [nvarchar](max) = NULL,
	@Body [nvarchar](max) = NULL,
	@Query [nvarchar](max),
	@FieldsXML [nvarchar](max),
	@IgnoreBasedOn [bit],
	@Locations [nvarchar](max) = NULL,
	@CostCenterID [int],
	@ReportID [int],
	@SendReportAs [int],
	@Actions [nvarchar](200),
	@UIXML [nvarchar](max),
	@IsApproveButton [bit],
	@ScheduleID [int],
	@ScheduleName [nvarchar](100) = NULL,
	@ScheduleStatusID [int],
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
	@UserWiseDimsCond [nvarchar](6) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@TemplateAttachmentsXML [nvarchar](max) = null,
	@MapColumn [nvarchar](50) = null,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION          
BEGIN TRY          
SET NOCOUNT ON;         
 --Declaration Section        
 DECLARE @HasAccess BIT,@Dt FLOAT,@XML XML,@AttachXml XML    
      
 SET @Dt=CONVERT(FLOAT,GETDATE())    
    
 IF EXISTS (SELECT TemplateID FROM COM_NotifTemplate WITH(NOLOCK) WHERE TemplateName=@TemplateName AND TemplateID<>@TemplateID)    
 BEGIN      
  RAISERROR('-112',16,1)      
 END      
        
 IF @TemplateID=0    
 BEGIN    
   
    INSERT INTO COM_NotifTemplate    
   (TemplateName,TemplateType,StatusID    
   ,[From],DisplayName,[To],CC,BCC,IgnoreMailsTo,AttachmentType,AttachmentID    
   ,[Subject],Body,ExtendedQuery,FieldsXML,CostCenterID,ReportID,SendReportAs,MapColumn,IgnoreBasedOn,UserWiseDims,UserWiseDimsCond,UIXML,IsApproveButton  
   ,CompanyGUID    
   ,[GUID]    
   ,CreatedBy    
   ,CreatedDate)    
  VALUES    
   (@TemplateName,@TemplateType,@StatusID    
   ,@From,@DisplayName,@To,@CC,@BCC,@IgnoreMailsTo,@AttachmentType,@AttachmentID    
   ,@Subject,@Body,@Query,@FieldsXML,@CostCenterID,@ReportID,@SendReportAs,@MapColumn,@IgnoreBasedOn,@Message,@UserWiseDimsCond,@UIXML,@IsApproveButton  
   ,@CompanyGUID    
   ,newid()    
   ,@UserName    
   ,@Dt)          
        
  --To get inserted record primary key        
  SET @TemplateID=SCOPE_IDENTITY()    
  IF @CostCenterID=50    
  BEGIN    
       
   INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,    
     FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,[Message],    
     CompanyGUID,[GUID],CreatedBy,CreatedDate)    
   VALUES(@ScheduleName,@ScheduleStatusID,@FreqType,@FreqInterval,@FreqSubdayType,@FreqSubdayInterval,    
     @FreqRelativeInterval,@FreqRecurrenceFactor,@StartDate,@EndDate,@StartTime,@EndTime,@Message,    
     @CompanyGUID,NEWID(),@UserName,@Dt)    
   SET @ScheduleID=SCOPE_IDENTITY()    
    
   IF @TemplateType=1    
    INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)    
    VALUES(47,@TemplateID,@ScheduleID,@UserName,@Dt)    
   ELSE    
    INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)    
    VALUES(48,@TemplateID,@ScheduleID,@UserName,@Dt)    
  END    
 END    
 ELSE    
 BEGIN    
  
  UPDATE COM_NotifTemplate    
  SET TemplateName=@TemplateName,StatusID=@StatusID,[From]=@From,DisplayName=@DisplayName, [To]=@To, CC=@CC, BCC=@BCC, IgnoreMailsTo=@IgnoreMailsTo, AttachmentType=@AttachmentType,AttachmentID=@AttachmentID,    
   [Subject]=@Subject,Body=@Body,ExtendedQuery=@Query,FieldsXML=@FieldsXML,CostCenterID=@CostCenterID,ReportID=@ReportID,SendReportAs=@SendReportAs,MapColumn=@MapColumn,IgnoreBasedOn=@IgnoreBasedOn,  
   UserWiseDims=@Message,UserWiseDimsCond=@UserWiseDimsCond,UIXML=@UIXML,IsApproveButton=@IsApproveButton,[GUID]=newid(),ModifiedBy=@UserName,ModifiedDate=@Dt  
  WHERE TemplateID=@TemplateID    
      
 IF @CostCenterID=50    
 BEGIN  
  --Check and delete old schedule changed  
  if (select count(*) from COM_Schedules with(nolock) WHERE ScheduleID=@ScheduleID and (FreqType!=@FreqType or FreqInterval!=@FreqInterval or FreqSubdayType!=@FreqSubdayType  
  or FreqSubdayInterval!=@FreqSubdayInterval or FreqRelativeInterval!=@FreqRelativeInterval or FreqRecurrenceFactor!=@FreqRecurrenceFactor  
  or StartDate!=@StartDate or EndDate!=@EndDate or StartTime!=@StartTime or EndTime!=@EndTime))>0  
  begin  
   delete from com_schevents where ScheduleID=@ScheduleID and StatusID=1 and FailureCount<5  
  end  
    
  UPDATE COM_Schedules    
  SET StatusID=@ScheduleStatusID,FreqType=@FreqType,FreqInterval=@FreqInterval,FreqSubdayType=@FreqSubdayType,    
  FreqSubdayInterval=@FreqSubdayInterval,FreqRelativeInterval=@FreqRelativeInterval,    
  FreqRecurrenceFactor=@FreqRecurrenceFactor,StartDate=@StartDate,EndDate=@EndDate,    
  StartTime=@StartTime,EndTime=@EndTime,[Message]=@Message,    
  [GUID]=NEWID(),[ModifiedBy] = @UserName,[ModifiedDate] = CONVERT(FLOAT,GETDATE())     
  WHERE ScheduleID=@ScheduleID  
  
 END    
      
  DELETE FROM COM_NotifTemplateAction WHERE TemplateID=@TemplateID    
 END    
  
  
  --Attachments
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')      
  BEGIN      
   SET @XML=@AttachmentsXML      
      
   INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,      
   FileExtension,FileDescription,IsProductImage,AllowInPrint,FeatureID,FeaturePK,      
   GUID,CreatedBy,CreatedDate,RowSeqNo,ColName,IsDefaultImage,ValidTill,RefNo)      
   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),      
   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),X.value('@AllowInPrint','bit'),
   X.value('@CostCenterID','int'),
   @TemplateID,      
   X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt,X.value('@RowSeqNo','int'),X.value('@ColName','NVARCHAR(100)'),X.value('@IsDefaultImage','smallint')      
   ,convert(float,X.value('@Validtill','Datetime')),X.value('@RefNo','NVARCHAR(200)')
   FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)        
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'      
  END      
       
  --

  -- Template Attachements
	IF (@TemplateAttachmentsXML IS NOT NULL AND @TemplateAttachmentsXML <> '' AND @TemplateType=1)  
	BEGIN  
			set @AttachXml=@TemplateAttachmentsXML 
			
			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
			FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate,ColName)  
			SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
			X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),47,47,@TemplateID,  
			X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt,'TemplateAttach'  
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
			FROM COM_Files C WITH(NOLOCK)  
			INNER JOIN @AttachXml.nodes('/AttachmentsXML/Row') as Data(X) ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID  
			WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  

			--If Action is DELETE then delete Attachments  
			DELETE FROM COM_Files  
			WHERE FileID IN(SELECT X.value('@AttachmentID','INT')  
			FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)  
			WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
	END 
	--
          
 IF @Actions<>''    
 BEGIN    
  SET @XML=@Actions    
  INSERT INTO COM_NotifTemplateAction(TemplateID,ActionID)    
  select @TemplateID,X.value('@ActionID','INT')    
  FROM @XML.nodes('/XML/R') as Data(X)     
 END  
   
 if exists (select value from adm_globalpreferences with(nolock) where Name='LWEmailSMS' and Value='True')  
 begin  
   
 if @TemplateType=1  
  set @TemplateType=-47  
 else if @TemplateType=2  
  set @TemplateType=-48  
 else  
  set @TemplateType=0  
 delete from ADM_Assign where CostCenterID=@TemplateType and NodeID=@TemplateID  
 if @Locations is not null and @Locations!=''  
 begin  
  declare @TblLoc as table(LID int)  
  insert into @TblLoc  
  EXEC SPSplitString @Locations,','  
  insert into ADM_Assign(CostCenterID,NodeID,UserID,RoleID,GroupID,CreatedBy,CreatedDate)  
  select @TemplateType,@TemplateID,0,0,LID,'SYS',1  
  from @TblLoc  
 end  
 end  
  
COMMIT TRANSACTION      
--ROLLBACK TRANSACTION    
--SELECT * FROM COM_NotifTemplate WITH(nolock) WHERE TemplateID=@TemplateID         
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID      
SET NOCOUNT OFF;          
RETURN  @TemplateID        
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
