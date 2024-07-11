USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetEmailSMS]
	@GetType [int],
	@ID [int],
	@Param1 [nvarchar](max),
	@RoleID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON;    
declare @XML xml,@SQL NVARCHAR(MAX)  
  
IF @GetType=0    
BEGIN    
 SELECT StatusID,(SELECT TOP (1) ResourceData FROM COM_LanguageResources WITH(NOLOCK) WHERE (ResourceID = S.ResourceID) AND LanguageID =@LangID ) AS ResourceData    
 FROM COM_Status AS S WITH(NOLOCK) WHERE (CostCenterID = 47)    
   
 DECLARE @TAB TABLE (ID INT IDENTITY(1,1),CostCenterID INT,Cnt INT)  
   
 IF(@Param1<>'' AND @Param1='SMS')  
  INSERT INTO @TAB  
  SELECT CostCenterID,COUNT(*) FROM COM_NotifTemplate WITH(NOLOCK) WHERE TemplateType=2  
  GROUP BY CostCenterID  
 ELSE IF(@Param1<>'' AND @Param1='Email')  
  INSERT INTO @TAB  
  SELECT CostCenterID,COUNT(*) FROM COM_NotifTemplate WITH(NOLOCK) WHERE TemplateType=1  
  GROUP BY CostCenterID  
   
 SELECT F.FeatureID,F.Name,ISNULL(T.Cnt,0) Cnt FROM ADM_Features F WITH(NOLOCK)    
 LEFT JOIN @TAB T ON T.CostCenterID=F.FeatureID  
 WHERE F.IsEnabled=1 OR (F.IsEnabled=0 AND (F.FeatureID > 40000) AND (F.FeatureID < 50000))  
 --WHERE FeatureID IN (2,50,95) OR ((FeatureID > 40000) AND (FeatureID < 50000))--(IsEnabled = 1) AND (AllowCustomization = 1 OR (FeatureID > 40000) AND (FeatureID < 50000))    
 ORDER BY F.Name  
  
 SELECT * FROM COM_NotifTemplate WITH(NOLOCK) WHERE TemplateID=@ID    
  
 SELECT ActionID FROM COM_NotifTemplateAction WITH(NOLOCK) WHERE TemplateID=@ID    
  
 --Report Schedule Info    
 DECLARE @ScheduleID INT    
 SELECT @ScheduleID=ScheduleID FROM COM_CCSchedules WITH(NOLOCK)    
 WHERE (CostCenterID=47 OR CostCenterID=48) AND NodeID=@ID    
 IF @ScheduleID>0    
  SELECT *,CONVERT(DATETIME, StartDate) CStartDate,CONVERT(DATETIME, EndDate) CEndDate FROM COM_Schedules WITH(NOLOCK) WHERE ScheduleID=@ScheduleID    
 ELSE    
  SELECT 1 ScheduleID WHERE 1<>1  
  
 if exists (select value from adm_globalpreferences with(nolock) where Name='LWEmailSMS' and Value='True')  
 begin  
  select @XML=convert(xml,value)   
  from [adm_globalpreferences] where name='LWEmailXml'  
  
  select L.NodeID,L.Code,L.Name  
  from @XML.nodes('/XML/Row') as Data(X)    
  inner join COM_Location L with(nolock) on L.NodeID=X.value('@LID','INT')  
  order by Name  
    
  if @Param1='SMS'  
   select GroupID AssLocs from ADM_Assign with(nolock) where CostCenterID=-48 and NodeID=@ID  
  else  
   select GroupID AssLocs from ADM_Assign with(nolock) where CostCenterID=-47 and NodeID=@ID  
 end  
 else  
 begin  
  SELECT 1 Locations WHERE 1<>1  
  select 1 AssLocs where 1!=1  
 end  
   
 select FeatureID,Name from adm_features with(nolock) where FeatureID IN (  
  select CostCenterID from COM_CostCenterCostCenterMap with(nolock)  
  where ParentCostCenterID=7 and CostCenterID>50000  
  group by CostCenterID)  
 order by Name 
 
 if @Param1='SMS'
 select * from Com_Files Where FeatureID =48 and FeaturePK=@ID 
 else
 select * from Com_Files Where FeatureID =47 and FeaturePK=@ID 
 
END    
ELSE IF @GetType=1    
BEGIN    
     
 IF @ID=50    
 BEGIN    
  SELECT ReportID,ReportName FROM ADM_RevenUReports WITH(NOLOCK)     
  WHERE ReportID>0 AND IsGroup=0    
  ORDER BY ReportName    
     
  --Groups    
  SELECT GID SysColumnName,GroupName ResourceData FROM COM_Groups WITH(NOLOCK)    
  Group By GID,GroupName    
  HAVING GroupName IS NOT NULL    
  ORDER BY GroupName    
        
  --Roles    
  SELECT RoleID SysColumnName, Name ResourceData FROM ADM_PRoles WITH(NOLOCK)    
  WHERE StatusID=434 AND IsRoleDeleted=0    
  ORDER BY Name    
  
  --Getting All Users    
  SELECT UserID SysColumnName,UserName ResourceData FROM ADM_Users WITH(NOLOCK)    
  WHERE StatusID=1    
  ORDER BY UserName     
    
  SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,     
  C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues --,LVC.CostCenterColID  
  FROM ADM_CostCenterDef C WITH(NOLOCK)  
  LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
  LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID   
  WHERE C.IsColumnInUse=1 and C.CostCenterID=4  
 END    
 ELSE    
 BEGIN    
  EXEC spDOC_GetDocPrintFields @ID,@UserID,@LangID    
     
  --Groups    
  SELECT GID SysColumnName,GroupName ResourceData FROM COM_Groups WITH(NOLOCK)    
  Group By GID,GroupName    
  HAVING GroupName IS NOT NULL    
  ORDER BY GroupName    
        
  --Roles    
  SELECT RoleID SysColumnName, Name ResourceData FROM ADM_PRoles WITH(NOLOCK)    
  WHERE StatusID=434 AND IsRoleDeleted=0    
  ORDER BY Name    
  
  --Getting All Users    
  SELECT UserID SysColumnName,UserName ResourceData FROM ADM_Users WITH(NOLOCK)    
  WHERE StatusID=1    
  ORDER BY UserName     
    
  select Name,value  from com_costcenterpreferences with(nolock) where CostCenterID=76 and Name='JobDimension'     
  IF(@ID = 95)
  BEGIN
	  SET @SQL='SELECT FeatureActionTypeID,Name FROM ADM_FeatureAction WITH(NOLOCK)    
	  WHERE FeatureID = '+CONVERT(NVARCHAR,@ID)+' AND FeatureActionTypeID IN (1,3,4,150,161,163)'    
  END
  ELSE
  BEGIN	
	  SET @SQL='SELECT FeatureActionTypeID,Name FROM ADM_FeatureAction WITH(NOLOCK)    
	  WHERE FeatureID = '+CONVERT(NVARCHAR,@ID)+' AND FeatureActionTypeID IN (1,3,4)'  
  END 
    
  IF EXISTS (SELECT GSTType FROM INV_GSTMapping WITH(NOLOCK)  
  WHERE CostCenterID=@ID  
  GROUP BY GSTType  
  HAVING GSTType='EINV')  
  BEGIN  
   SET @SQL=@SQL+'  
   UNION  
   SELECT 2001,''IRN''  
   UNION  
   SELECT 2002,''CancelIRN''  
   UNION  
   SELECT 2003,''EWB''  
   UNION  
   SELECT 2004,''CancelEWB'''  
  END  
  ELSE IF EXISTS (SELECT GSTType FROM INV_GSTMapping WITH(NOLOCK)  
  WHERE CostCenterID=@ID  
  GROUP BY GSTType  
  HAVING GSTType='EWB')  
  BEGIN  
   SET @SQL=@SQL+'  
   UNION  
   SELECT 2003,''EWB''  
   UNION  
   SELECT 2004,''CancelEWB'''  
  END  
    
  EXEC(@SQL)  
    
  SELECT DocPrintLayoutID,Name     
  FROM ADM_DocPrintLayouts WITH(NOLOCK)    
  WHERE DocumentID=@ID-- AND DocType=@DocType    
  AND (    
   @RoleID=1     
   OR     
    DocPrintLayoutID IN (select DocPrintLayoutID from ADM_DocPrintLayoutsMap     
     where UserID=@UserID OR RoleID=@RoleID or GroupID IN (select GID from COM_Groups where UserID=@UserID or RoleID=@RoleID))    
   )    
  ORDER BY [Name] ASC    
    
  --Add select before table "--Getting Groups,Roles, All Users  "  
   
 END    
END    
ELSE IF @GetType=2    
BEGIN    
 SELECT * FROM COM_NotifTemplate WITH(NOLOCK) WHERE TemplateID=@ID    
END    
ELSE IF @GetType=3--Update notification event status    
BEGIN    
       
  
 UPDATE COM_SchEvents  
 SET FailureCount=FailureCount+1,[Message]=@Param1  
 WHERE SchEventID=@ID    
  
      
END    
ELSE IF @GetType=4--Get notification events    
BEGIN  
 if len(@Param1)>0 and exists (select value from adm_globalpreferences with(nolock) where Name='LWEmailSMS' and Value='True')  
 and exists (select value from adm_globalpreferences with(nolock) where Name='EnableLocationWise' and Value='True')  
 begin  
  declare @TblTemplate as table(TID int)  
  declare @Tbl as table(LID int)  
  insert into @Tbl  
  exec SPSplitString @Param1,','  
  
  insert into @TblTemplate  
  select NodeID from @Tbl T join ADM_Assign L with(nolock) on L.GroupID=T.LID  
  where L.CostCenterID in (-47,-48)  
   
  SELECT E.SchEventID EventID,E.CostCenterID,E.NodeID,E.GUID EventGUID,E.SubCostCenterID,E.SubNodeID,E.TemplateID,N.TemplateType,E.OtherDocsNos,E.FilterXML,  
  N.[From] collate database_default as [From],N.DisplayName,N.[To] collate database_default as [To],N.CC,N.BCC,N.IgnoreMailsTo,N.AttachmentType,N.AttachmentID,N.Subject collate database_default as [Subject],N.Body collate database_default as [Body],N.Query,N.ExtendedQuery,N.FieldsXML,N.UIXML,N.SendReportAs,N.MapColumn,N.UserWiseDims,N.UserWiseDimsCond  
  ,U.Email1 Login_Email1,U.UserName Login_UserName,U.FirstName Login_FirstName,U.MiddleName Login_MiddleName,U.LastName Login_LastName ,e.TempTemplateID 
  FROM COM_NotifTemplate N WITH(nolock)    
  INNER JOIN COM_SchEvents E WITH(nolock) ON N.TemplateID=E.TemplateID  
  inner join @TblTemplate TL on TL.TID=N.TemplateID  
  LEFT JOIn ADM_Users U with(nolock) ON U.UserName=E.CreatedBy  
  WHERE E.StatusID=1 AND E.ScheduleID=0 AND E.FailureCount<5  
  UNION ALL   
  SELECT E.SchEventID EventID,N.CostCenterID,N.ReportID NodeID,E.GUID EventGUID,E.SubCostCenterID,E.SubNodeID,N.TemplateID,N.TemplateType,E.OtherDocsNos,E.FilterXML,  
  N.[From],N.DisplayName,N.[To],N.CC,N.BCC,N.IgnoreMailsTo,N.AttachmentType,N.AttachmentID,N.Subject,N.Body,N.Query,N.ExtendedQuery,N.FieldsXML,N.UIXML,N.SendReportAs,N.MapColumn,N.UserWiseDims,N.UserWiseDimsCond  
  ,U.Email1 Login_Email1,U.UserName Login_UserName,U.FirstName Login_FirstName,U.MiddleName Login_MiddleName,U.LastName Login_LastName ,e.TempTemplateID 
  FROM COM_SchEvents E WITH(nolock)    
  INNER JOIN COM_CCSchedules CCS WITH(nolock) ON E.ScheduleID=CCS.ScheduleID AND (CCS.CostCenterID=47 OR CCS.CostCenterID=48)    
  INNER JOIN COM_NotifTemplate N WITH(nolock) ON N.TemplateID=CCS.NodeID AND (CCS.CostCenterID=47 OR CCS.CostCenterID=48)  
  inner join @TblTemplate TL on TL.TID=N.TemplateID  
  LEFT JOIn ADM_Users U with(nolock) ON U.UserName=E.CreatedBy  
  WHERE E.StatusID=1 AND N.StatusID!=384 AND E.EventTime<=CONVERT(FLOAT,getdate()) AND E.FailureCount<5  
  UNION ALL  
  SELECT E.SchEventID EventID,E.CostCenterID,E.NodeID,E.GUID EventGUID,E.SubCostCenterID,E.SubNodeID,E.TemplateID,E.TemplateType,E.OtherDocsNos,E.FilterXML,  
  E.[From],E.DisplayName,E.[To],E.CC,E.BCC,N.IgnoreMailsTo,E.AttachmentType,E.AttachmentID,E.Subject,E.Body,N.Query Query,N.ExtendedQuery ExtendedQuery,N.FieldsXML,N.UIXML,0 SendReportAs,N.MapColumn,N.UserWiseDims,N.UserWiseDimsCond  
  ,U.Email1 Login_Email1,U.UserName Login_UserName,U.FirstName Login_FirstName,U.MiddleName Login_MiddleName,U.LastName Login_LastName ,e.TempTemplateID 
  FROM COM_SchEvents E WITH(nolock)  
  inner join @Tbl TL on TL.LID=E.LocationID  
  LEFT JOIn ADM_Users U with(nolock) ON U.UserName=E.CreatedBy  
  LEFT JOIn COM_NotifTemplate N with(nolock) ON N.TemplateID=E.TempTemplateID  
  WHERE E.StatusID=1 AND E.ScheduleID=0 AND E.TemplateID=0 AND E.FailureCount<5  
    ORDER BY EventID  
      
    select @XML=convert(xml,value)   
  from [adm_globalpreferences] where name='LWEmailXml'  
  
  select X.value('@LID','INT') LID,X.value('@DName','nvarchar(200)') DName,X.value('@Email','nvarchar(200)') Email,X.value('@Pwd','nvarchar(200)') Pwd  
  ,X.value('@Host','nvarchar(200)') Host,X.value('@Port','nvarchar(200)') Port,X.value('@UseSSL','nvarchar(200)') UseSSL  
  ,X.value('@HostUrl','nvarchar(max)') HostUrl,X.value('@SMSNewline','nvarchar(100)') SMSNewline,X.value('@SMSSuccessReponse','nvarchar(max)') SMSSuccessReponse  
  from @XML.nodes('/XML/Row') as Data(X)    
  inner join @Tbl T on T.LID=X.value('@LID','INT')  
 end  
 else  
 begin  
  SELECT E.SchEventID EventID,E.CostCenterID,E.NodeID,E.GUID EventGUID,E.SubCostCenterID,E.SubNodeID,E.TemplateID,N.TemplateType,E.OtherDocsNos,E.FilterXML,  
  N.[From] collate database_default as [From],N.DisplayName,N.[To] collate database_default as [To],N.CC,N.BCC,N.IgnoreMailsTo,N.AttachmentType,N.AttachmentID,N.Subject collate database_default as [Subject],N.Body collate database_default as [Body],N.Query,N.ExtendedQuery,N.FieldsXML,N.UIXML,N.SendReportAs,N.MapColumn,N.UserWiseDims,N.UserWiseDimsCond  
  ,U.Email1 Login_Email1,U.UserName Login_UserName,U.FirstName Login_FirstName,U.MiddleName Login_MiddleName,U.LastName Login_LastName ,e.TempTemplateID 
  FROM COM_NotifTemplate N WITH(nolock)    
  INNER JOIN COM_SchEvents E WITH(nolock) ON N.TemplateID=E.TemplateID  
  LEFT JOIn ADM_Users U with(nolock) ON U.UserName=E.CreatedBy  
  WHERE E.StatusID=1 AND E.ScheduleID=0 AND E.FailureCount<5  
  UNION ALL   
  SELECT E.SchEventID EventID,N.CostCenterID,N.ReportID NodeID,E.GUID EventGUID,E.SubCostCenterID,E.SubNodeID,N.TemplateID,N.TemplateType,E.OtherDocsNos,E.FilterXML,  
  N.[From],N.DisplayName,N.[To],N.CC,N.BCC,N.IgnoreMailsTo,N.AttachmentType,N.AttachmentID,N.Subject,N.Body,N.Query,N.ExtendedQuery,N.FieldsXML,N.UIXML,N.SendReportAs,N.MapColumn,N.UserWiseDims,N.UserWiseDimsCond  
  ,U.Email1 Login_Email1,U.UserName Login_UserName,U.FirstName Login_FirstName,U.MiddleName Login_MiddleName,U.LastName Login_LastName  ,e.TempTemplateID
  FROM COM_SchEvents E WITH(nolock)    
  INNER JOIN COM_CCSchedules CCS WITH(nolock) ON E.ScheduleID=CCS.ScheduleID AND (CCS.CostCenterID=47 OR CCS.CostCenterID=48)    
  INNER JOIN COM_NotifTemplate N WITH(nolock) ON N.TemplateID=CCS.NodeID AND (CCS.CostCenterID=47 OR CCS.CostCenterID=48)    
  LEFT JOIn ADM_Users U with(nolock) ON U.UserName=E.CreatedBy  
  WHERE E.StatusID=1 AND N.StatusID!=384 AND E.EventTime<=CONVERT(FLOAT,getdate()) AND E.FailureCount<5  
  UNION ALL  
  SELECT E.SchEventID EventID,E.CostCenterID,E.NodeID,E.GUID EventGUID,E.SubCostCenterID,E.SubNodeID,E.TemplateID,E.TemplateType,E.OtherDocsNos,E.FilterXML,  
  E.[From],E.DisplayName,E.[To],E.CC,E.BCC,N.IgnoreMailsTo,E.AttachmentType,E.AttachmentID,E.Subject,E.Body,N.Query Query,N.ExtendedQuery ExtendedQuery,N.FieldsXML,N.UIXML,0 SendReportAs,0 MapColumn,N.UserWiseDims,N.UserWiseDimsCond  
  ,U.Email1 Login_Email1,U.UserName Login_UserName,U.FirstName Login_FirstName,U.MiddleName Login_MiddleName,U.LastName Login_LastName  ,e.TempTemplateID
  FROM COM_SchEvents E WITH(nolock)  
  LEFT JOIn ADM_Users U with(nolock) ON U.UserName=E.CreatedBy  
  LEFT JOIn COM_NotifTemplate N with(nolock) ON N.TemplateID=E.TempTemplateID  
  WHERE E.StatusID=1 AND E.ScheduleID=0 AND E.TemplateID=0 AND E.FailureCount<5  
    ORDER BY EventID  
   end  
  
END    
ELSE IF @GetType=5--Get notifications for the document(for save as)  
BEGIN    
 SELECT TemplateID,TemplateName FROM COM_NotifTemplate WITH(NOLOCK)   
 WHERE CostCenterID=@ID AND TemplateType=@Param1  
END  
ELSE IF @GetType=6--Get email notifications for the document  
BEGIN    
 SELECT T.TemplateID,T.TemplateName,isnull((select top 1 GroupID from ADM_Assign where NodeID=T.TemplateID and CostCenterID=-(46+@Param1)),0) LocationID FROM COM_NotifTemplate T WITH(NOLOCK)  
 WHERE T.CostCenterID=@ID AND T.StatusID!=384 AND T.TemplateType=@Param1  
  AND T.TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)  
   WHERE UserID=@UserID OR RoleID=@RoleID OR GroupID IN (select GID from COM_Groups WITH(nolock) where UserID=@UserID or RoleID=@RoleID))  
END  
ELSE IF @GetType=7--Get email notifications for the report  
BEGIN    
 declare @DATA xml,@Type int,@ReportID INT  
 set @DATA=@Param1  
 SELECT @Type=X.value('@Type','int'),@ReportID=X.value('@ReportID','INT') from @DATA.nodes('XML') as DATA(X)  
 SELECT TemplateID,TemplateName FROM COM_NotifTemplate WITH(NOLOCK)   
 WHERE CostCenterID=@ID AND TemplateType=@Type and ReportID=@ReportID  
  AND TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)  
   WHERE UserID=@UserID OR RoleID=@RoleID OR GroupID IN (select GID from COM_Groups WITH(nolock) where UserID=@UserID or RoleID=@RoleID))  
END  
ELSE IF @GetType=8--Get email locations  
BEGIN    
 select @XML=convert(xml,value)   
 from [adm_globalpreferences] where name='LWEmailXml'  
  
 select L.NodeID,L.Code,L.Name  
 from @XML.nodes('/XML/Row') as Data(X)    
 inner join COM_Location L with(nolock) on L.NodeID=X.value('@LID','INT')  
 order by Name  
END  
ELSE IF @GetType=9  
BEGIN  
 if @Param1='1'  
 begin  
  select Email1 ToAdd from com_address with(nolock) where FeatureID=2 and FeaturePK=@ID and Email1 is not null and Email1!=''  
  union  
  select Email2 from com_address with(nolock) where FeatureID=2 and FeaturePK=@ID and Email2 is not null and Email2!=''  
  union  
  select Email1 from com_contacts with(nolock) where FeatureID=2 and FeaturePK=@ID and Email1 is not null and Email1!=''  
  union  
  select Email2 from com_contacts with(nolock) where FeatureID=2 and FeaturePK=@ID and Email2 is not null and Email2!=''  
  order by ToAdd  
 end  
 else  
 begin  
  select Phone1 ToAdd from com_address with(nolock) where FeatureID=2 and FeaturePK=@ID and Phone1 is not null and Phone1!=''  
  union  
  select Phone2 from com_address with(nolock) where FeatureID=2 and FeaturePK=@ID and Phone2 is not null and Phone2!=''  
  union  
  select Phone1 from com_contacts with(nolock) where FeatureID=2 and FeaturePK=@ID and Phone1 is not null and Phone1!=''  
  union  
  select Phone2 from com_contacts with(nolock) where FeatureID=2 and FeaturePK=@ID and Phone2 is not null and Phone2!=''  
  order by ToAdd  
 end  
END  
ELSE IF @GetType=10  
BEGIN  
 set @SQL='update COM_SchEvents set StatusID=3,ModifiedDate=convert(float,getdate()),ModifiedBy='+convert(nvarchar,@UserID)+'  
 where SchEventID in ('+@Param1+')  
  
 select 1 Saved'  
 exec(@SQL)  
END  
  
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
    
  
SET NOCOUNT OFF      
RETURN -999       
END CATCH  

 
GO
