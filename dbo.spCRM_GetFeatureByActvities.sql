USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetFeatureByActvities]
	@NodeID [int] = 0,
	@CostCenterID [int] = 0,
	@UserID [nvarchar](300) = NULL,
	@Userseqno [nvarchar](300) = NULL,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY   
SET NOCOUNT ON  
DECLARE @SQL NVARCHAR(MAX),@WHERE NVARCHAR(MAX), @PRIMARYKEY NVARCHAR(200) ,@tablejoin nvarchar(300),@SelectedColumn nvarchar(300)
 Declare @CustomQuery1 nvarchar(max),@FeatureName nvarchar(100),@CustomQuery2 nvarchar(max),@CustomQuery3 nvarchar(max),@i int ,@CNT int,
@Table nvarchar(100),@TabRef nvarchar(3),@CCID int
 
    
SET @tablejoin=''
SET @PRIMARYKEY  = ''
SET @SelectedColumn=''
 
 IF(@CostCenterID=89) 
 BEGIN
	 SET @tablejoin='LEFT OUTER JOIN CRM_Opportunities   AS O with(nolock) ON O.OpportunityID = A.NodeID AND A.CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)
	 SET @PRIMARYKEY  = 'OpportunityID'
	 SET @SelectedColumn='O.Code DocNo,'
 END
 ELSE IF(@CostCenterID=86) 
 BEGIN
	SET @tablejoin='LEFT OUTER JOIN  CRM_LEADS  AS O with(nolock) ON O.LEADID = A.NodeID AND A.CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)
	SET @PRIMARYKEY  = 'LeadID'
	SET @SelectedColumn='O.Code DocNo,'
 END
 ELSE IF(@CostCenterID=88 OR @CostCenterID=128) 
 BEGIN
	SET @tablejoin='LEFT OUTER JOIN CRM_Campaigns   AS O with(nolock) ON O.Campaignid = A.NodeID AND A.CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)
	SET @PRIMARYKEY  = 'Campaignid'
	SET @SelectedColumn='O.Code DocNo,'
 END
 ELSE IF(@CostCenterID=73) 
 BEGIN
	SET @tablejoin='LEFT OUTER JOIN CRM_Cases   AS O with(nolock) ON O.CaseID = A.NodeID AND A.CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)
	SET @PRIMARYKEY  = 'CaseID'
	SET @SelectedColumn='O.CaseNumber DocNo,'
 END
 ELSE IF(@CostCenterID=83) 
 BEGIN
	SET @tablejoin='LEFT OUTER JOIN CRM_CUSTOMER   AS O with(nolock) ON O.CustomerID = A.NodeID AND A.CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)
	SET @PRIMARYKEY  = 'CustomerID'
	SET @SelectedColumn='O.CustomerCode DocNo,'
 END
 ELSE IF(@CostCenterID=65) 
 BEGIN
	SET @tablejoin='LEFT OUTER JOIN  Com_Contacts   AS O with(nolock) ON O.ContactID = A.NodeID AND A.CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)
	SET @PRIMARYKEY  = 'ContactID'
	SET @SelectedColumn='O.FirstName DocNo, '
 END

 ELSE IF(@CostCenterID=95) 
 BEGIN
	SET @tablejoin='LEFT OUTER JOIN  Ren_Contract AS O  with(nolock) ON O.ContractID = A.NodeID AND A.CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)
	SET @PRIMARYKEY  = 'ContractID'
	SET @SelectedColumn='O.ContractNumber DocNo,'
 END 
 ELSE IF(@CostCenterID=2) 
 BEGIN
	SET @tablejoin='LEFT OUTER JOIN  Acc_accounts AS O with(nolock)  ON O.AccountID = A.NodeID AND A.CostCenterID= 2'
	SET @PRIMARYKEY  = 'AccountID'
	SET @SelectedColumn='O.AccountCode DocNo,'
 END 
 ELSE IF(@CostCenterID>40000 and @CostCenterID<50000) 
 BEGIN
	DECLARE @InventoryTable nvarchar(300)
	IF((SELECT isInventory from ADM_DOCUMENTTYPES with(nolock) where CostCenterid=@CostCenterID)=1) --INVENTORY DOCUMENTS
	BEGIN
		set @InventoryTable='INV_DOCDETAILS'
	END
	ELSE
		SET @InventoryTable='ACC_DOCDETAILS'
		
	SET @tablejoin=' LEFT OUTER JOIN  ( select top 1 * from '+@InventoryTable+' with(nolock) where DOCID='+CONVERT(VARCHAR,@NodeID)+' and  CostCenterID='+CONVERT(VARCHAR,@CostCenterID)+') AS O  ON O.DOCID = A.NodeID AND A.CostCenterID= '+CONVERT(VARCHAR,@CostCenterID)
	SET @tablejoin =@tablejoin  + ' LEFT JOIN  ADM_DocumentTypes AS D ON O.costcenterid = D.costcenterid '
	SET @PRIMARYKEY  = 'DOCID'
	SET @SelectedColumn='O.VoucherNo DocNo,D.DocumentName, O.DocPrefix, O.DocNumber,'
 END
set @CustomQuery1=''
set @CustomQuery3=' '
SET @CustomQuery2=' '

 IF @CostCenterID>0 --BIND EXTRA CC FIELDS DATA
 BEGIN
		
		create table #CustomTable(ID int identity(1,1),CostCenterID int)
		insert into #CustomTable(CostCenterID)
		select ColumnCostCenterID from adm_CostCenterDef WITH(NOLOCK) where CostCenterID=144 AND LOCALREFERENCE=@CostCenterID 
		and SystableName='CRM_Activities' and ColumnCostCenterID>50000

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
 
 
 SET @SQL='  
	SELECT  '+@SelectedColumn+'  A.ActivityID, 
	CONVERT(datetime, A.ActStartDate) AS StartDateTime,   CONVERT(datetime, A.ActEndDate) AS EndDateTime, TotalDuration,  
	convert(datetime,(select max(startdate)  from CRM_ActivityLog WITH(NOLOCK) where ActivityID=A.ActivityID)) LastStartDate ,
	dbo.[fnGet_GetContactPersonForCalendar] (A.CostCenterID,A.NodeID,A.ContactID) CRMContactPerson,
	A.ActivityTypeID, Isnull(A.ScheduleID,0) as ScheduleID, A.CostCenterID, A.NodeID, A.StatusID AS ActStatus, A.Subject AS ActSubject, A.Priority,   
	A.PctComplete, A.Location, A.IsAllDayActivity,  CONVERT(datetime, A.ActualCloseDate) AS ActualCloseDate, A.ActualCloseTime, A.CustomerID,   
	A.Remarks, A.AssignUserID, A.AssignRoleID, A.AssignGroupID,CONVERT(datetime, A.StartDate) AS ActStartDate,   
	CONVERT(datetime, A.EndDate) AS ActEndDate,  A.StartTime AS ActStartTime, A.EndTime AS ActEndTime, S.ScheduleID AS Expr10, S.Name, S.StatusID AS Expr11, S.FreqType, S.FreqInterval,   
	S.FreqSubdayType, S.FreqSubdayInterval, S.FreqRelativeInterval, S.FreqRecurrenceFactor, CONVERT(datetime, S.StartDate) AS CStartDate,   
	CONVERT(datetime, S.EndDate) AS CEndDate, CONVERT(datetime, S.StartTime) AS StartTime, CONVERT(datetime, S.EndTime) AS EndTime,  
	S.Message,case when A.ActivityTypeID=1 then ''AppointmentRegular''   
	when A.ActivityTypeID=2 then ''TaskRegular''   
	when A.ActivityTypeID=3 then ''ApptRecurring''   
	when A.ActivityTypeID=4 then ''TaskRecur'' end as Activity,A.AccountID,A.CustomerType,[Alpha1],[Alpha2],[Alpha3],[Alpha4],[Alpha5],[Alpha6],[Alpha7],[Alpha8],[Alpha9],[Alpha10],[Alpha11],[Alpha12],[Alpha13],[Alpha14][Alpha15],[Alpha16],[Alpha17]  
	,[Alpha18],[Alpha19],[Alpha20],[Alpha21],[Alpha22],[Alpha23],[Alpha24],[Alpha25],[Alpha26],[Alpha27],[Alpha28],[Alpha29],[Alpha30],[Alpha31]  
	,[Alpha32],[Alpha33],[Alpha34],[Alpha35],[Alpha36],[Alpha37],[Alpha38],[Alpha39],[Alpha40],[Alpha41],[Alpha42]  
	,[Alpha43],[Alpha44],[Alpha45],[Alpha46],[Alpha47],[Alpha48],[Alpha49],[Alpha50] , isnull(A.ContactID,0) ContactID, A.CreatedBy UserName, convert(datetime,a.CreatedDate) CreatedDate,A.IsReschedule,
	(SELECT USERNAME FROM ADM_USERs WHERE USERID=A.ASSIGNUSERID) AssignUser
	 '+@CustomQuery2+' '+@CustomQuery3+'
	
	FROM         CRM_Activities AS A  
	'+@tablejoin+'  '+@CustomQuery1+' LEFT OUTER JOIN  
	COM_Schedules AS S ON S.ScheduleID = A.ScheduleID LEFT OUTER JOIN  
	COM_CCSchedules AS CS ON CS.ScheduleID = A.ScheduleID '  
 
 
 SET @WHERE=''
--bind status
IF @CostCenterID<>-100
BEGIN
 SET @WHERE=' WHERE  (A.CostCenterID = '+CONVERT(VARCHAR,@CostCenterID)+')  and A.nodeid='+CONVERT(VARCHAR,@NodeID)+''    
	 IF(@CostCenterID not between 40000 and 50000)
	  BEGIN	
		SET  @WHERE=@WHERE+ ' AND (A.CREATEDBY in 
	  (select UserName from dbo.adm_users where userid in (select nodeid from dbo.COM_CostCenterCostCenterMap where 
		  Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='+CONVERT(NVARCHAR(40),@UserSeqno)+' 
		  UNION SELECT '+CONVERT(NVARCHAR(40),@UserSeqno)+')   '  
		SET  @WHERE=@WHERE + ' OR A.ASSIGNUSERID='+CONVERT(NVARCHAR(40),@UserSeqno)+' ) OR ('''+convert(varchar,@UserSeqno)+'''=1  or             
		 '''+convert(varchar,@UserSeqno)+''' in ( select UserID from CRM_Assignment where CCID='+CONVERT(VARCHAR,@CostCenterID)+'   
		 AND IsFromActivity=A.ActivityID and IsTeam=0 )' +             
		  ' or  '''+convert(varchar,@UserSeqno)+''' in ( select  UserID from COM_GROUPS where   GROUPNAME<>'''' AND GID  IN  
		  (select teamnodeid from CRM_Assignment where CCID='+CONVERT(VARCHAR,@CostCenterID)+' and   IsFromActivity=A.ActivityID AND ISGROUP=1) ) OR  
		  '''+convert(varchar,@UserSeqno)+''' in ( select  UserID from ADM_UserRoleMap where ROLEID IN  
		  (select teamnodeid from CRM_Assignment where CCID='+CONVERT(VARCHAR,@CostCenterID)+' and   IsFromActivity=A.ActivityID and ISROLE=1) )  
		 or '''+convert(varchar,@UserSeqno)+''' in            
		 (select userid from crm_teams where isowner=0 and  teamid in            
		 ( select teamnodeid from CRM_Assignment where CCID='+CONVERT(VARCHAR,@CostCenterID)+' and  IsFromActivity=A.ActivityID and IsTeam=1)) ) )         
		 '
	END	       
END 
if(@WHERE<>'')
set @WHERE=@WHERE +' and a.statusid<>7'
else
set @WHERE=' WHERE a.statusid<>7 '
SET @SQL=@SQL+ ' ' + @WHERE   + '  order by A.StartDate,  A.StartTime   '
print @SQL
EXEC (@SQL) 
  
  --[spCRM_GetActvities] 0,95,0,0,'admin',1   
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
