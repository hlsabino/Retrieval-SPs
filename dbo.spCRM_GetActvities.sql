USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetActvities]
	@NodeID [int] = 0,
	@CostCenterID [int] = 0,
	@Status [int] = 0,
	@Type [int] = 0,
	@ActID [int] = 0,
	@UserID [nvarchar](300) = NULL,
	@Userseqno [nvarchar](300) = NULL,
	@Date [datetime] = NULL,
	@FrDate [datetime] = null,
	@ToDate [datetime] = null,
	@Subject [nvarchar](max),
	@LangID [int] = 1,
	@roleid [nvarchar](300),
	@DimWhere [nvarchar](max),
	@IsInvite [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY   
SET NOCOUNT ON  
DECLARE @SQL NVARCHAR(MAX),@WHERE NVARCHAR(MAX), @tablejoin nvarchar(300),@SelectedColumn nvarchar(MAX)
 Declare @CustomQuery1 nvarchar(max),@FeatureName nvarchar(100),@CustomQuery2 nvarchar(max),@CustomQuery3 nvarchar(max),@i int ,@CNT int,
@Table nvarchar(100),@TabRef nvarchar(5),@CCID int,@prefVal nvarchar(10)

select @prefVal=value from [com_Costcenterpreferences] with(nolock) where CostCenterID=1000 and Name='EnableStart'

if(@CostCenterID=-100 and @ActID>0)
	select @CostCenterID=costcenterid from CRM_Activities where ActivityID=@ActID  
    
SET @tablejoin=''

IF EXISTS (SELECT Value from  COM_CostCenterPreferences with(nolock) 
WHERE CostCenterID=@CostCenterID AND Name='DayViewRepeatOn' AND Value IS NOT NULL AND Value<>'' AND Value<>'0')
BEGIN
	SELECT @SQL='UPDATE CRM_Activities SET CCNID'+CONVERT(NVARCHAR,(CONVERT(INT,Value)-50000))+'=1 WHERE CCNID'+CONVERT(NVARCHAR,(CONVERT(INT,Value)-50000))+'=0' 
	from  COM_CostCenterPreferences with(nolock) 
	WHERE CostCenterID=@CostCenterID AND Name='DayViewRepeatOn' AND Value IS NOT NULL AND Value<>'' AND Value<>'0'
	EXEC (@SQL)
	SET @SQL=''
END

 IF(@CostCenterID>40000 and @CostCenterID<50000) 
 BEGIN
	DECLARE @InventoryTable nvarchar(300)
	IF((SELECT isInventory from ADM_DOCUMENTTYPES with(nolock) where CostCenterid=@CostCenterID)=1) --INVENTORY DOCUMENTS
	BEGIN
		set @InventoryTable='INV_DOCDETAILS'
	END
	ELSE
		SET @InventoryTable='ACC_DOCDETAILS'
		
	SET @tablejoin='LEFT JOIN  (SELECT DISTINCT DOCID,CostCenterID,VoucherNo,DocPrefix,DocNumber FROM '+@InventoryTable+' with(nolock) WHERE CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)+')  AS O  ON O.DOCID = A.NodeID '
	SET @tablejoin =@tablejoin  + ' LEFT JOIN  ADM_DocumentTypes AS D with(nolock) ON O.CostCenterID = D.CostCenterID '

	SET @SelectedColumn='O.VoucherNo DocNo,D.DocumentName, O.DocPrefix, O.DocNumber,'
 END
 ELSE
 BEGIN
	SET @SelectedColumn='CASE'+(select DISTINCT ' WHEN A.CostCenterID='+CONVERT(NVARCHAR,f.featureid)+' THEN (SELECT CONVERT(NVARCHAR(MAX),O.'+(CASE WHEN f.featureid=2 THEN 'AccountCode' WHEN f.featureid=73 THEN 'CaseNumber' WHEN f.featureid=83 THEN 'CustomerCode' WHEN f.featureid in (65,94) THEN 'FirstName' WHEN f.featureid=122 THEN 'ServiceTicketID' WHEN f.featureid=128 THEN 'Customer' WHEN f.featureid=95 THEN 'ContractNumber' ELSE 'Code' END)+') FROM '+f.TableName+' O WITH(NOLOCK) WHERE O.'+f.PrimaryKey+'=A.NodeID)' 
	from adm_features f with(nolock) where f.PrimaryKey IS NOT NULL AND f.featureid in (select distinct costcenterid FROM CRM_Activities AS A with(nolock)) 
	FOR XML PATH(''))+'
	WHEN A.CostCenterID BETWEEN 40000 AND 50000 THEN (SELECT DocNo FROM COM_DocID WITH(NOLOCK) WHERE ID=A.NodeID) ELSE '''' END DocNo,'
 END
 
 IF(@SelectedColumn IS NULL)
	SET @SelectedColumn=''
	
set @CustomQuery1=''
set @CustomQuery3=' '
SET @CustomQuery2=' '

 IF @CostCenterID>0 OR @CostCenterID=-100 --BIND EXTRA CC FIELDS DATA
 BEGIN
		
		create table #CustomTable(ID int identity(1,1),CostCenterID int)
		
		IF(@CostCenterID=-100)
		begin		
			insert into #CustomTable(CostCenterID)		
			select ColumnCostCenterID from adm_CostCenterDef WITH(NOLOCK) 
			where CostCenterID=144 AND ISCOLUMNINUSE=1
			and SystableName='CRM_Activities' and ColumnCostCenterID>50000
		end	
		ELSE
		begin
			insert into #CustomTable(CostCenterID)		
			select ColumnCostCenterID from adm_CostCenterDef WITH(NOLOCK) 
			where CostCenterID=144 AND LOCALREFERENCE=@CostCenterID AND ISCOLUMNINUSE=1
			and SystableName='CRM_Activities' and ColumnCostCenterID>50000	
		end	

		set @i=1
		set @CustomQuery1=''
		set @CustomQuery3=', '
		SET @CustomQuery2=', '
		select @CNT=count(id) from #CustomTable
		while (@i<=	@CNT)
		begin
		
			select @CCID=CostCenterID from #CustomTable where ID=@i
	 
			select @Table=TableName,@FeatureName=FeatureID from adm_features WITH(NOLOCK) where FeatureID = @CCID
			set @TabRef='A'+CONVERT(nvarchar,@i)
			set @CCID=@CCID-50000
	    	 
			if(@CCID>0)
			begin
				set @CustomQuery1=@CustomQuery1+' left join '+@Table+' '+@TabRef+' WITH(NOLOCK) on '+@TabRef+'.NodeID=A.CCNID'+CONVERT(nvarchar,@CCID)
				set @CustomQuery3=@CustomQuery3+' '+@TabRef+'.Name as CCNID'+CONVERT(nvarchar,@CCID)+','
				SET @CustomQuery2=@CustomQuery2+'CCNID'+CONVERT(nvarchar,@CCID)+' as CCNID'+CONVERT(nvarchar,@CCID)+'_Key ,'
			end
			set @i=@i+1
		end
		
		if(len(@CustomQuery3)>0)
		begin
			set @CustomQuery3=SUBSTRING(@CustomQuery3,1,LEN(@CustomQuery3)-1)
		end 
		if(len(@CustomQuery2)>0)
		begin
			set @CustomQuery2=SUBSTRING(@CustomQuery2,1,LEN(@CustomQuery2)-1)
		end
	  
		drop table #CustomTable
 END
 
 SET @SQL=''
select @SQL=@SQL+',A.'+name 
from sys.columns WITH(NOLOCK)
where object_id=object_id('CRM_Activities') and name LIKE 'Alpha%'
 
 SET @SQL='  
	SELECT  '+@SelectedColumn+'  A.ActivityID,CONVERT(datetime, A.ActStartDate) AS StartDateTime,CONVERT(datetime, A.ActEndDate) AS EndDateTime,TotalDuration, 
	convert(datetime,(select max(startdate)  from CRM_ActivityLog WITH(NOLOCK) where ActivityID=A.ActivityID)) LastStartDate ,
	dbo.[fnGet_GetContactPersonForCalendar] (A.CostCenterID,A.NodeID,A.ContactID) CRMContactPerson,
	case when a.CostCenterID between 40000 and 50000 then (select Prefvalue from [com_documentpreferences] WITH(NOLOCK) where Prefname=''EnableStart'' and [CostCenterID]=a.CostCenterID) else '''+@prefVal+''' end as PrefVal,
	A.ActivityTypeID, Isnull(A.ScheduleID,0) as ScheduleID, A.CostCenterID, A.NodeID, A.StatusID AS ActStatus, A.Subject AS ActSubject, A.Priority,   
	A.PctComplete, A.Location, A.IsAllDayActivity,  CONVERT(datetime, A.ActualCloseDate) AS ActualCloseDate, A.ActualCloseTime, A.CustomerID,   
	A.Remarks, A.AssignUserID, A.AssignRoleID, A.AssignGroupID,CONVERT(datetime, A.StartDate) AS ActStartDate,  dbo.fnGet_GetAssignedListForActivity (A.ActivityID,1) AssignedList,
	CONVERT(datetime, A.EndDate) AS ActEndDate,  A.StartTime AS ActStartTime, A.EndTime AS ActEndTime, S.ScheduleID AS Expr10, S.Name, S.StatusID AS Expr11, S.FreqType, S.FreqInterval,   
	S.FreqSubdayType, S.FreqSubdayInterval, S.FreqRelativeInterval, S.FreqRecurrenceFactor, CONVERT(datetime, S.StartDate) AS CStartDate,   
	CONVERT(datetime, S.EndDate) AS CEndDate, CONVERT(datetime, S.StartTime) AS StartTime, CONVERT(datetime, S.EndTime) AS EndTime,  
	S.Message,case when A.ActivityTypeID=1 then ''AppointmentRegular''   
	when A.ActivityTypeID=2 then ''TaskRegular''   
	when A.ActivityTypeID=3 then ''ApptRecurring''   
	when A.ActivityTypeID=4 then ''TaskRecur'' end as Activity,A.AccountID,A.CustomerType,A.ContactID, A.CreatedBy UserName '+@SQL
	if(@IsInvite=1)
		set @SQL=@SQL+ ', convert(datetime, A.CreatedDate) CreatedDate, A.InviteComments, A.InviteStatus ' +@CustomQuery2+' '+@CustomQuery3+' '
	else
		set @SQL=@SQL+  @CustomQuery2+' '+@CustomQuery3+' '
		
	set @SQL=@SQL+  '
	FROM CRM_Activities AS A with(nolock)
	'+@tablejoin+'  '+@CustomQuery1+' LEFT OUTER JOIN  
	COM_Schedules AS S with(nolock) ON S.ScheduleID = A.ScheduleID LEFT OUTER JOIN  
	COM_CCSchedules AS CS with(nolock) ON CS.ScheduleID = A.ScheduleID '  
 
 
 SET @WHERE=''
if(@DimWhere is not null and @DimWhere<>'')
BEGIN
	SET  @WHERE=' WHERE '+@DimWhere
END
ELSE IF @CostCenterID<>-100--bind status
BEGIN
 SET @WHERE=' WHERE  (A.CostCenterID = '+CONVERT(VARCHAR,@CostCenterID)+') '   
  
	IF @UserID<>'' AND @UserID<>'0'   
	BEGIN  
		 IF @Type<>'' AND @Type<>0 AND  @Type NOT IN (-400,-500) -- EXCLUDE FOR -400 AND -500 BECOZ TO GET ONLY PARTICULAR USER
		 BEGIN
			SET  @WHERE=@WHERE+ 'AND (A.CREATEDBY in 
		  (select UserName from adm_users with(nolock) where userid in (select nodeid from COM_CostCenterCostCenterMap with(nolock) where 
			  Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='+CONVERT(NVARCHAR(40),@UserSeqno)+' 
			  UNION SELECT '+CONVERT(NVARCHAR(40),@UserSeqno)+')   '  
			SET  @WHERE=@WHERE + ' OR A.ASSIGNUSERID='+CONVERT(NVARCHAR(40),@UserSeqno)+' ) OR ('''+convert(varchar,@UserSeqno)+'''=1  or             
			 '''+convert(varchar,@UserSeqno)+''' in ( select UserID from CRM_Assignment with(nolock) where CCID='+CONVERT(VARCHAR,@CostCenterID)+'   
			 AND IsFromActivity=A.ActivityID and IsTeam=0 )' +             
			  ' or  '''+convert(varchar,@UserSeqno)+''' in ( select  UserID from COM_GROUPS with(nolock) where   GROUPNAME<>'''' AND GID  IN  
			  (select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(VARCHAR,@CostCenterID)+' and   IsFromActivity=A.ActivityID AND ISGROUP=1) ) OR  
			  '''+convert(varchar,@UserSeqno)+''' in ( select  UserID from ADM_UserRoleMap with(nolock) where ROLEID IN  
			  (select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(VARCHAR,@CostCenterID)+' and   IsFromActivity=A.ActivityID and ISROLE=1) )  
			 or '''+convert(varchar,@UserSeqno)+''' in            
			 (select userid from crm_teams with(nolock) where isowner=0 and  teamid in            
			 ( select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(VARCHAR,@CostCenterID)+' and  IsFromActivity=A.ActivityID and IsTeam=1)) ) )         
			 '     
		END
	 
	IF @Type<>'' AND @Type<>0 AND  @Type in (-200,-600) -- for all appointments/Assigned Appointments
	BEGIN
	IF @Userseqno<>1 --EXCLUDE FOR  ADMIN
	BEGIN
		 IF(LEN(@WHERE)>0)
			SET  @WHERE=@WHERE+ ' AND A.ActivityTypeID in (1,3)' 
		ELSE
			SET  @WHERE=@WHERE+ ' WHERE A.ActivityTypeID in (1,3)' 	
	END
	END
	ELSE  IF @Type<>'' AND @Type<>0 AND  @Type in (-300,-700) -- for all TASKS/assinged tasks
	BEGIN
	IF @Userseqno<>1 --EXCLUDE FOR  ADMIN
	BEGIN
	 IF(LEN(@WHERE)>0)
		SET  @WHERE=@WHERE+ ' AND A.ActivityTypeID in (4,2)' 
	ELSE
		SET  @WHERE=@WHERE+ ' WHERE A.ActivityTypeID in (4,2)' 
	END
	END
	ELSE  IF @Type<>'' AND @Type<>0 AND  @Type IN (-400,-500)  -- FOR My Appointments, My tasks 
	BEGIN
	 IF @Userseqno<>1 --EXCLUDE FOR  ADMIN
	 BEGIN
		 IF(LEN(@WHERE)>0)
			SET  @WHERE=@WHERE+ ' AND A.CREATEDBY='''+CONVERT(VARCHAR,@UserID)+'''' 
		ELSE
			SET  @WHERE=@WHERE+ ' WHERE A.CREATEDBY='''+CONVERT(VARCHAR,@UserID)+'''' 
			
		 IF @Type<>'' AND @Type<>0 AND  @Type=-400
		  SET  @WHERE=@WHERE+ ' AND A.ActivityTypeID in (1,3)' 
		 ELSE  IF @Type<>'' AND @Type<>0 AND  @Type=-500
			
		  SET  @WHERE=@WHERE+ ' AND A.ActivityTypeID in (4,2)'  	
			
	 END
	END 
		 
	END  

END
ELSE IF @CostCenterID=-100
 BEGIN 
	IF @Userseqno<>1   AND  @Type NOT IN (-400,-500) --EXCLUDE FOR  ADMIN
		SET  @WHERE=@WHERE + ' WHERE   ('''+convert(varchar,@UserSeqno)+'''=1  OR A.ASSIGNUSERID='+CONVERT(NVARCHAR(40),@UserSeqno)+' or  A.CREATEDBY='''+CONVERT(VARCHAR,@UserID)+''' OR   
		a.Createdby in (select UserName from adm_users with(nolock) where userid in
	   (select nodeid from COM_CostCenterCostCenterMap with(nolock) where Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='''+convert(varchar,@UserSeqno)+'''
	   UNION SELECT '''+convert(varchar,@UserSeqno)+'''))  OR	           
	   '''+convert(varchar,@UserSeqno)+''' in ( select UserID from CRM_Assignment with(nolock) where   IsFromActivity=A.ActivityID  and ccid=a.costcenterid and ccnodeid=a.nodeid  and IsTeam=0 )' +             
	   ' or  '''+convert(varchar,@UserSeqno)+''' in ( select  UserID from COM_GROUPS with(nolock) where   GROUPNAME<>'''' AND GID  IN  
	   (select teamnodeid from CRM_Assignment with(nolock) where     IsFromActivity=A.ActivityID  and ccid=a.costcenterid and ccnodeid=a.nodeid  AND ISGROUP=1) ) OR  
		'''+convert(varchar,@UserSeqno)+''' in ( select  UserID from ADM_UserRoleMap with(nolock) where ROLEID IN  
		(select teamnodeid from CRM_Assignment with(nolock) where    IsFromActivity=A.ActivityID  and ccid=a.costcenterid and ccnodeid=a.nodeid  and ISROLE=1) )  
		or '''+convert(varchar,@UserSeqno)+''' in (select userid from crm_teams with(nolock) where isowner=0 and  teamid in            
		( select teamnodeid from CRM_Assignment with(nolock) where IsFromActivity=A.ActivityID  and ccid=a.costcenterid and ccnodeid=a.nodeid  and IsTeam=1)) ) '
		    
	IF @Type<>'' AND @Type<>0 AND  @Type in (-200,-600) -- for all appointments/Assigned Appointments
	BEGIN
		IF @Userseqno<>1 --EXCLUDE FOR  ADMIN
		BEGIN
			 IF(LEN(@WHERE)>0)
				SET  @WHERE=@WHERE+ ' AND A.ActivityTypeID in (1,3)' 
			ELSE
				SET  @WHERE=@WHERE+ ' WHERE A.ActivityTypeID in (1,3)' 	
		END
	END
	ELSE  IF @Type<>'' AND @Type<>0 AND  @Type in (-300,-700) -- for all TASKS/assinged tasks
	BEGIN
		IF @Userseqno<>1 --EXCLUDE FOR  ADMIN
		BEGIN
			 IF(LEN(@WHERE)>0)
				SET  @WHERE=@WHERE+ ' AND A.ActivityTypeID in (4,2)' 
			ELSE
				SET  @WHERE=@WHERE+ ' WHERE A.ActivityTypeID in (4,2)' 
		END
		END
	ELSE  IF @Type<>'' AND @Type<>0 AND  @Type IN (-400,-500)  -- FOR My Appointments, My tasks 
	BEGIN
	 IF @Userseqno<>1 --EXCLUDE FOR  ADMIN
	 BEGIN
		 IF(LEN(@WHERE)>0)
			SET  @WHERE=@WHERE+ ' AND A.CREATEDBY='''+CONVERT(VARCHAR,@UserID)+'''' 
		ELSE
			SET  @WHERE=@WHERE+ ' WHERE A.CREATEDBY='''+CONVERT(VARCHAR,@UserID)+'''' 
			
		 IF @Type<>'' AND @Type<>0 AND  @Type=-400
		  SET  @WHERE=@WHERE+ ' AND A.ActivityTypeID in (1,3)' 
		 ELSE  IF @Type<>'' AND @Type<>0 AND  @Type=-500
			
		  SET  @WHERE=@WHERE+ ' AND A.ActivityTypeID in (4,2)'  
		 
	 END
	END 
	
END

IF @Subject<>'' 
BEGIN
	if len(@WHERE)>0
		SET  @WHERE=@WHERE+ ' and A.Subject like ''%'+@Subject+'%''  '  
	ELSE
		SET  @WHERE=  ' WHERE A.Subject like ''%'+@Subject+'%'' '  
END  
 

IF @Status<>'' AND @Status<>0 AND  @Status=-101 
BEGIN
	if len(@WHERE)>0
		SET  @WHERE=@WHERE+ ' and (A.STATUSID in (412,414)) '  
	ELSE
		SET  @WHERE=  ' WHERE (A.STATUSID in (412,414)) '  
END  
else IF @Status<>'' AND @Status<>0 AND  @Status<>-100 
BEGIN
	if len(@WHERE)>0
		SET  @WHERE=@WHERE+ ' and (A.STATUSID='+CONVERT(VARCHAR,@Status)+') '  
	ELSE
		SET  @WHERE=  ' WHERE (A.STATUSID='+CONVERT(VARCHAR,@Status)+') '  
END   
IF @FrDate is not null and  LEN(@FrDate)>0 and @ToDate is not null and  len(@ToDate)>0
BEGIN
declare @F float, @T float
 set @F=cast(floor(convert(float,@FrDate)) as float)
  set @T=cast(floor(convert(float,@ToDate)) as float)

	IF(LEN(@WHERE)>0)
		SET  @WHERE=@WHERE+ ' and CAST(FLOOR(CAST(A.StartDate AS FLOAT)) AS DATETIME) between '+convert(nvarchar,@F)+' and '+convert(nvarchar,@T)+''
	ELSE 
		SET  @WHERE=@WHERE+ ' WHERE CAST(FLOOR(CAST(A.StartDate AS FLOAT)) AS DATETIME) between '+convert(nvarchar,@F)+' and '+convert(nvarchar,@T)+''
	 
END 
ELSE 
IF LEN(@Date)>0 AND @Date<>'1900-01-01 00:00:00.000' AND @IsInvite=0
BEGIN
	 IF(LEN(@WHERE)>0)
		SET  @WHERE=@WHERE+ ' AND MONTH('''+CONVERT(NVARCHAR(300),@Date)+''')=MONTH(CONVERT(datetime, A.StartDate))
							  AND YEAR('''+CONVERT(NVARCHAR(300),@Date)+''')=YEAR(CONVERT(datetime, A.StartDate))'
	ELSE 
	   SET  @WHERE='  WHERE MONTH('''+CONVERT(NVARCHAR(300),@Date)+''')=MONTH(CONVERT(datetime, A.StartDate))
					  AND YEAR('''+CONVERT(NVARCHAR(300),@Date)+''')=YEAR(CONVERT(datetime, A.StartDate))'   	
END	 
if(len(@WHERE)>0 and @IsInvite=0)
	set @WHERE=@WHERE + ' and a.StatusID<>7  '
else  if(len(@WHERE)>0 and @IsInvite=1)
	set @WHERE=@WHERE + ' and a.StatusID=7 and len(a.InviteStatus)=0 and A.StartDate >= '+Convert(nvarchar(50),convert(float,@Date))+' and a.inviterefactid>0 '
else  if(len(@WHERE)=0 and @IsInvite=1)
	set @WHERE=  + ' where a.StatusID=7 and len(a.InviteStatus)=0 and A.StartDate >= '+Convert(nvarchar(50),convert(float,@Date))+' and a.inviterefactid>0 ' 
SET @SQL=@SQL+ ' ' + @WHERE   + '  order by A.StartDate,  A.StartTime'
print @SQL  
EXEC (@SQL) 
  
	SELECT TEAMNODEID,USERID,IsGroup,IsRole,IsTeam, ISFROMACTIVITY FROM CRM_Assignment CA WITH(NOLOCK) 
	JOIN CRM_ACTIVITIES A WITH(NOLOCK) ON CA.ISFROMACTIVITY=A.ACTIVITYID AND CA.CCID=A.COSTCENTERID AND CA.CCNODEID=A.NodeID
	WHERE ISFROMACTIVITY>0 AND  MONTH(CONVERT(NVARCHAR(300),@Date))=MONTH(CONVERT(datetime, StartDate))
	UNION ALL
	SELECT 0,ASSIGNUSERID USERID,0,0,0, ActivityID FROM crm_activities A WITH(NOLOCK)  
	WHERE MONTH(CONVERT(NVARCHAR(300),@Date))=MONTH(CONVERT(datetime, StartDate))
	and ActivityID not in (SELECT ISFROMACTIVITY FROM CRM_Assignment WITH(NOLOCK)  WHERE ISFROMACTIVITY>0 AND CCID=1000) 
	GROUP BY ASSIGNUSERID, ActivityID
  --[spCRM_GetActvities] 0,95,0,0,'admin',1 
  
	if exists(select [Value] from adm_globalPreferences WITH(NOLOCK)
	where [Name]='ShowActivityinCalendar' and [Value]='true')
	BEGIN
		set @Table=''
		select @Table=b.tablename,@CNT=featureid from adm_globalPreferences a WITH(NOLOCK)
		join adm_features b WITH(NOLOCK) on a.value=b.featureid
		where a.[Name]='ProjectManagementDimension' and isnumeric([Value])=1 
		iF(@Table<>'')
		BEGIN
		
		set @SQL='select  A.NodeID,A.Code,A.Name,A.StatusID,ccalpha15 startdate,ccalpha16 enddate,'+convert(nvarchar,@CNT)+' ccid
		FROM '+@Table+' A WITH(NOLOCK)  
		left join (select DCM.DcccNID'+convert(nvarchar,(@CNT-50000))+' PID,INVE.RefID,INVE.TYPE RefType from COM_DoCCCData DCM WITH(NOLOCK) 
		JOIN Inv_docdetails INV WITH(NOLOCK) ON DCM.InvdocdetailsID=INV.InvdocdetailsID
		JOIN Inv_docextradetails INVE WITH(NOLOCK) ON INVE.InvdocdetailsID=INV.InvdocdetailsID
		where inv.Documenttype=45 and INVE.TYPE in(6,7,8)) as t on PID=A.NodeID  
		WHERE ((RefID='+@Userseqno+' and RefType=8) OR (RefID='+@roleid+' and RefType=7)
		or (RefType=6 and RefID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID='+@Userseqno+' or G.RoleID='+@roleid+')))
		and isdate(ccalpha16)=1 and  isdate(ccalpha15)=1'
		print @SQL
		exec(@SQL)
		END
	END
    
  
COMMIT TRANSACTION  
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
