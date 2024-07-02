USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_GetFeatureWiseCalendar]
	@ReportType [int] = 0,
	@Location [int] = 0,
	@FromDate [datetime],
	@ToDate [datetime],
	@Feature [bigint] = 0,
	@Account [bigint] = 0,
	@Customer [bigint] = 0,
	@CreatedUser [nvarchar](300) = null,
	@AssignedUser [nvarchar](300) = null,
	@Status [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET ARITHABORT ON    
     
   create  table #tblActivities  ( ID INT IDENTITY(1,1),ActivityID BIGINT NULL , Code NVARCHAR(100) NULL,
   Subject NVARCHAR(100) NULL,ActivitySubject NVARCHAR(100) NULL,StartDate Datetime NULL,EndDate Datetime NULL,
   StartTime NVARCHAR(100) ,EndTime NVARCHAR(100),Status NVARCHAR(100),ActivityType NVARCHAR(100),CreatedBy NVARCHAR(100),AssignedUsers nvarchar(max))    
            
   DECLARE @TBLNAME NVARCHAR(50) ,@COLUMNS NVARCHAR (MAX)   ,@stract nvarchar(max),@SQL NVARCHAR(MAX),@WHERE NVARCHAR(MAX),@PRIMARYKEY NVARCHAR(300)
   
		IF @Feature=86
		BEGIN
			SET @TBLNAME='CRM_LEADS'
			SET @PRIMARYKEY  = 'LEADID'
			SET @COLUMNS=' O.CODE CODE,O.SUBJECT Subject'
		END
		ELSE IF @Feature=89
		BEGIN
			SET @TBLNAME='CRM_Opportunities'
			SET @PRIMARYKEY  = 'OpportunityID'
			SET @COLUMNS=' O.CODE CODE,O.SUBJECT Subject'
		END
		ELSE IF @Feature=95
		BEGIN
			SET @TBLNAME='Ren_Contract'
			SET @PRIMARYKEY  = 'ContractID'
			SET @COLUMNS=' O.ContractPrefix CODE,O.ContractDate Subject'
		END
		ELSE IF @Feature=65
		BEGIN
			SET @TBLNAME='Com_Contacts'
			SET @PRIMARYKEY  = 'ContactID'
			SET @COLUMNS=' O.ContactId CODE,O.FirstName Subject'
		END
		ELSE IF @Feature=83
		BEGIN
			SET @TBLNAME='CRM_Customer'
			SET @PRIMARYKEY  = 'CustomerID'
			SET @COLUMNS=' O.CustomerCode CODE,O.CustomerName Subject'
		END
		ELSE IF @Feature=73
		BEGIN
			SET @TBLNAME='CRM_CASES'
			SET @PRIMARYKEY  = 'CASEID'
			SET @COLUMNS=' O.CASEID CODE,O.CASENUMBER Subject'
		END
		
		 SET @SQL='   
			insert into #tblActivities
			SELECT    activityid, '+@COLUMNS+',
			A.Subject AS ActivitySubject,CONVERT(datetime, A.StartDate) AS StartDate,   
			CONVERT(datetime, A.EndDate) AS EndDate,  A.StartTime AS StartTime, A.EndTime AS EndTime,ST.STATUS,
			case when A.ActivityTypeID=1 then ''AppointmentRegular''   
			when A.ActivityTypeID=2 then ''TaskRegular''   
			when A.ActivityTypeID=3 then ''ApptRecurring''   
			when A.ActivityTypeID=4 then ''TaskRecur'' end as ActivityType,  A.CreatedBy ,''''

			FROM         CRM_Activities AS A with(nolock) INNER JOIN  
			'+@TBLNAME+' AS O with(nolock) ON O.'+@PRIMARYKEY+' = A.NodeID AND A.CostCenterID = '+CONVERT(VARCHAR,@Feature)+'  LEFT JOIN COM_STATUS ST with(nolock) ON ST.STATUSID=A.STATUSID '   

			SET @WHERE=' WHERE  (A.CostCenterID = '+CONVERT(VARCHAR,@Feature)+') '     
			
			IF @Feature=86 OR @Feature=89
			BEGIN    
				IF @Account<>'' AND @Account IS NOT NULL and @Account<>0
					SET  @WHERE=@WHERE+ ' AND  (O.MODE=2 AND O.SELECTEDMODEID='''+CONVERT(VARCHAR,@Account)+''')' 
					
				IF @Customer<>'' AND @Customer IS NOT NULL and @Customer<>0
				SET  @WHERE=@WHERE+ ' AND (O.MODE=3 AND O.SELECTEDMODEID='''+CONVERT(VARCHAR,@Customer)+''')' 
		    END	
		    ELSE IF @Feature=73
		    BEGIN
				IF @Customer<>'' AND @Customer IS NOT NULL and @Customer<>0
				SET  @WHERE=@WHERE+ ' AND   O.CUSTOMERID='''+CONVERT(VARCHAR,@Customer)+''' ' 
		    END 

		--BUILD WHERE CONDITION
		IF @CreatedUser<>'' AND @CreatedUser IS NOT NULL and @CreatedUser<>'0'
		SET  @WHERE=@WHERE+ ' AND A.CREATEDBY='''+CONVERT(VARCHAR,@CreatedUser)+'''' 
		
		
		IF @ReportType=146 -- IF REPORT TYPE IS MONTHLY
		BEGIN
			IF @FromDate<>'' AND @FromDate IS NOT NULL  
			BEGIN
			SET  @WHERE=@WHERE+ ' AND (A.StartDate between '''+convert(nvarchar,CONVERT(FLOAT,@FromDate))+''' and '''+convert(nvarchar,CONVERT(FLOAT,@ToDate))+''' OR  A.ENDDATE between '''+convert(nvarchar,CONVERT(FLOAT,@FromDate))+''' and '''+convert(nvarchar,CONVERT(FLOAT,@ToDate))+''' )' 
			END
		END
		ELSE IF @ReportType=148 -- IF REPORT TYPE IS DAILY
		BEGIN
			IF @ToDate<>'' AND @ToDate IS NOT NULL  
			BEGIN
			SET  @WHERE=@WHERE+ ' AND (A.StartDate between '''+convert(nvarchar,CONVERT(FLOAT,@ToDate))+''' and '''+convert(nvarchar,CONVERT(FLOAT,@ToDate))+''' OR  A.ENDDATE between '''+convert(nvarchar,CONVERT(FLOAT,@ToDate))+''' and '''+convert(nvarchar,CONVERT(FLOAT,@ToDate))+''' )' 
			END
		END
	    ELSE IF @ReportType=149 -- IF REPORT TYPE IS WEKLY
		BEGIN
			IF @ToDate<>'' AND @ToDate IS NOT NULL  
			BEGIN
			 SET  @WHERE=@WHERE+ ' AND (A.StartDate between '''+convert(nvarchar,CONVERT(FLOAT,@FromDate))+''' and '''+convert(nvarchar,CONVERT(FLOAT,@ToDate))+''' OR  A.ENDDATE between '''+convert(nvarchar,CONVERT(FLOAT,@FromDate))+''' and '''+convert(nvarchar,CONVERT(FLOAT,@ToDate))+''' )' 
			END
		END
		
		IF @AssignedUser<>'' AND @AssignedUser is not null and @AssignedUser<>'0'  --ASSIGNED FILTER
		BEGIN
			DECLARE @UserSeqno INT
			SELECT @UserSeqno=UserID FROM ADM_USERS WITH(NOLOCK) WHERE UserName=@AssignedUser
			SET  @WHERE=@WHERE + ' AND ('''+convert(varchar,@UserSeqno)+'''=1  or             
			'''+convert(varchar,@UserSeqno)+''' in ( select UserID from CRM_Assignment with(nolock) where CCID='+CONVERT(VARCHAR,@Feature)+' and CCNODEID=O.'+@PRIMARYKEY+'   
			AND IsFromActivity=A.ActivityID and IsTeam=0 )' +             
			' or  '''+convert(varchar,@UserSeqno)+''' in ( select  UserID from COM_GROUPS with(nolock) where   GROUPNAME<>'''' AND GID  IN  
			(select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(VARCHAR,@Feature)+' and CCNODEID=O.'+@PRIMARYKEY+' and IsFromActivity=A.ActivityID AND ISGROUP=1) ) OR  
			'''+convert(varchar,@UserSeqno)+''' in ( select  UserID from ADM_UserRoleMap with(nolock) where ROLEID IN  
			(select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(VARCHAR,@Feature)+' and CCNODEID=O.'+@PRIMARYKEY+' and IsFromActivity=A.ActivityID and ISROLE=1) )  
			or '''+convert(varchar,@UserSeqno)+''' in            
			(select userid from crm_teams with(nolock) where isowner=0 and  teamid in            
			( select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(VARCHAR,@Feature)+' and CCNODEID=O.'+@PRIMARYKEY+' and IsFromActivity=A.ActivityID and IsTeam=1)) )         
			'   
		END	
		
		 IF @Status<>'' AND @Status<>0 AND  @Status<>-100  --STATUS FILTER
		 BEGIN
			SET  @WHERE=@WHERE+ ' AND (A.STATUSID='+CONVERT(VARCHAR,@Status)+') '  
		 END  

		IF @Location<>'' AND @Location<>0 AND  @Location<>-100  --LOCATION FILTER
		 BEGIN
			SET  @WHERE=@WHERE+ ' AND (A.ccnid2='+CONVERT(VARCHAR,@Location)+') '  
		 END  
		 
		SET @SQL=@SQL+ ' ' + @WHERE   + '  order by A.StartDate, substring(A.StartTime,Len(A.StartTime) -1 ,Len(A.StartTime)), A.StartTime   '
		print @SQL
		exec (@SQL)     
   
   DECLARE @COUNT INT,@I INT,@ActivityID int
   SELECT @COUNT=COUNT(*),@I=1 FROM #tblActivities
   CREATE TABLE #TBLUSERS (ASSIGNED NVARCHAR(MAX))
   WHILE @I<=@COUNT
   BEGIN
	   SELECT @ActivityID=ActivityID FROM #tblActivities WHERE ID=@I
	   IF @ActivityID IS NOT NULL
	   BEGIN
			INSERT INTO #TBLUSERS
			EXEC spCRM_GetActivityAssignedList @ActivityID,@UserID,@LangID
			UPDATE  #tblActivities SET AssignedUsers=(SELECT Assigned FROM #TBLUSERS) WHERE ActivityID=@ActivityID
			TRUNCATE TABLE #TBLUSERS
	   END
	   
   SET @I=@I+1
   END
  
  SELECT Code,Subject,ActivitySubject,StartDate,EndDate,StartTime,EndTime,Status,ActivityType,CreatedBy,AssignedUsers  from #tblActivities  
  drop table #tblActivities
IF @@ERROR<>0 BEGIN RETURN -103 END    
 --[spRpt_GetFeatureWiseCalendar] 146
 --,'0'
 --,'7/29/2012 12:00:00 AM'
 --,'8/29/2013 12:00:00 AM'
 --,'86'
 --,'0'
 --,'0'
 --,'0'
 --,'0'
 --,'0'
 --,1
 --,1
RETURN 1    
 

GO
