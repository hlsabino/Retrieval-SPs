USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetNextPreviousRecords]
	@CostCenterID [int],
	@SeqNo [int] = null,
	@Next [bit] = Null,
	@ControlType [int],
	@UserID [nvarchar](200) = Null,
	@LocationWhere [nvarchar](max) = NULL,
	@DivisionWhere [nvarchar](max) = NULL,
	@RecordType [int] = -1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON;    
	  
	CREATE TABLE #TblUsers(iUserID int)
	declare @Dimensionlist nvarchar(max),@IsUserWiseExists bit

	SELECT @Dimensionlist=isnull(VALUE,0) FROM ADM_GLOBALPREFERENCES with(nolock) WHERE NAME='Dimension List'

	INSERT INTO #TblUsers
	exec spsplitstring @Dimensionlist,','

	set @IsUserWiseExists=0

	IF(EXISTS(SELECT * FROM #TblUsers WHERE iUserID=@CostCenterID)) --CHECK FOR USER WISE 
	SET @IsUserWiseExists=1

	
	declare @UserSql nvarchar(4000)
	Declare @TotalRecords int 
	DECLARE @COUNT INT
	DECLARE @SQL Nvarchar(MAX),@PrimaryColumn varchar(MAX),@TableName Nvarchar(MAX), @Join nvarchar(max)
	Declare @ViewWhereCond Nvarchar(4000)
	set @Join=''
	SET @ViewWhereCond=''
	
	declare @uid nvarchar(20)
	select @uid = userid from adm_users with(nolock) where username=@UserID
		
	IF @CostCenterID=2 --ACCOUNT
	BEGIN
		SET @TableName='Acc_Accounts A'
		SET @PrimaryColumn='A.AccountID'
		
		IF @IsUserWiseExists=1 and @uid<>1 --IF IT IS USERWISE TRUE THEN ONLY ADD THE CONDITION
		begin
			SET @ViewWhereCond='  and (a.Createdby in (SELECT USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE USERID in
			(select nodeid from dbo.COM_CostCenterCostCenterMap with(nolock) where 
			Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='+@uid+') or 
			userid = '+@uid+') or A.AccountID =CCMU.ParentNodeID))' 
			SET @Join =' LEFT JOIN  COM_CostCenterCostCenterMap CCMU with(nolock) on CCMU.ParentCostCenterID = 2 and CCMU.CostCenterID=7 and CCMU.NodeID in ('+@uid+') '
		end
		if @ControlType=1
			set @ViewWhereCond=@ViewWhereCond+' and (a.AccountTypeID!=6 and a.AccountTypeID!=7)'
		else if @ControlType=2
		begin
			TRUNCATE TABLE #TblUsers
			SELECT @Dimensionlist=isnull(VALUE,0) FROM ADM_GLOBALPREFERENCES with(nolock) WHERE NAME='DebtorsControlGroup'

			INSERT INTO #TblUsers
			exec spsplitstring @Dimensionlist,','
	
			select @ViewWhereCond=@ViewWhereCond+' and a.AccountTypeID=7 and (a.lft between '+convert(nvarchar,lft)+' and '+convert(nvarchar,rgt)+')' from acc_accounts with(nolock)
			where AccountID=(select TOP 1 iUserID from #TblUsers with(nolock))
		end
		else if @ControlType=3
		begin
			TRUNCATE TABLE #TblUsers
			SELECT @Dimensionlist=isnull(VALUE,0) FROM ADM_GLOBALPREFERENCES with(nolock) WHERE NAME='DebtorsControlGroup'

			INSERT INTO #TblUsers
			exec spsplitstring @Dimensionlist,','
	
			select @ViewWhereCond=@ViewWhereCond+' and a.AccountTypeID=6 and (a.lft between '+convert(nvarchar,lft)+' and '+convert(nvarchar,rgt)+')' from acc_accounts with(nolock)
			where AccountID=(select TOP 1 iUserID from #TblUsers with(nolock))
		end
	END 
	ELSE IF @CostCenterID=3 --PRODUCT
	BEGIN
		SET @TableName='INV_PRODUCT A'
		SET @PrimaryColumn='A.PRODUCTID'

		IF @IsUserWiseExists=1 and @uid<>1--IF IT IS USERWISE TRUE THEN ONLY ADD THE CONDITION
			SET @ViewWhereCond=' and A.CREATEDBY ='''+@UserID+''' '	
	 
	END 
	ELSE IF @CostCenterID=86 --LEAD
	BEGIN

		SET @TableName='CRM_LEADS A'
		SET @PrimaryColumn='A.LEADID' 

		IF @IsUserWiseExists=1 --IF IT IS USERWISE TRUE THEN ONLY ADD THE CONDITION
		BEGIN
			declare @DonotDisplayOwner bit 

			select @DonotDisplayOwner=convert(bit,Value) from com_costcenterpreferences with(nolock) where costcenterid=86 and name='DonotDisplayOwner'

			SET @Join = '  LEFT JOIN (select test.LeadID,Grp.lft,Grp.rgt from
			(select ASS.CCNODEID LeadID from CRM_Assignment ASS with(nolock) where ISFROMACTIVITY=0 and ASS.CCID='+convert(varchar,@CostCenterID)+'  AND IsTeam=0   and UserID in (select UserID from @TABLE)
			union
			select ASSS.CCNODEID from CRM_Assignment ASSS with(nolock) where ISFROMACTIVITY=0 and ASSS.CCID='+convert(varchar,@CostCenterID)+' AND ASSS.ISGROUP=1 AND ASSS.teamnodeid IN   (SELECT GID FROM COM_GROUPS R with(nolock) inner join @TABLE T on R.UserID=T.USERID )
			union
			select ASROLE.CCNODEID from CRM_Assignment ASROLE with(nolock) where ISFROMACTIVITY=0 and ASROLE.CCID='+convert(varchar,@CostCenterID)+' AND ASROLE.IsRole=1 AND ASROLE.teamnodeid   IN (SELECT ROLEID FROM ADM_UserRoleMap R with(nolock) inner join @TABLE T on R.UserID=T.USERID) 
			union
			select ASTEAM.CCNODEID from CRM_Assignment ASTEAM with(nolock) where ISFROMACTIVITY=0 and ASTEAM.CCID='+convert(varchar,@CostCenterID)+' AND ASTEAM.IsTeam=1 AND ASTEAM.teamnodeid IN   (SELECT teamid FROM crm_teams R with(nolock)inner join @TABLE T on R.UserID=T.USERID  WHERE  isowner=0 )  
			)  as test 
			join  '+Replace(@TableName,' A','')+' Grp on test.LeadID=Grp.'+REPLACE(@PrimaryColumn,'A.','')+' and Grp.'+REPLACE(@PrimaryColumn,'A.','')+'<>1 ) as  TBL on (a.lft between TBL.lft and TBL.rgt) '

			if @DonotDisplayOwner=1
				set @ViewWhereCond=' AND (A.lft=1 OR (('''+@uid+'''=1 or (a.Createdby in (SELECT USERNAME FROM @TABLE)) OR TBL.LeadID Is not null))
				AND ((dbo.fnGet_GetAssignedListForFeatures(86,A.LeadID)='''' AND A.CREATEDBY IN (SELECT USERNAME FROM @TABLE)) OR TBL.LeadID Is not null)   '
			ELSE
				set @ViewWhereCond=' AND (A.lft=1 OR ('''+@uid+'''=1 or (a.Createdby in (SELECT USERNAME FROM @TABLE)) OR TBL.LeadID Is not null))'
		END  
	END
	ELSE IF @CostCenterID=88 --LEAD
	BEGIN

		SET @TableName='CRM_Campaigns A'
		SET @PrimaryColumn='A.CAMPAIGNID'  

	END
	ELSE IF @CostCenterID=89 --OPPORTUNITY
	BEGIN

		SET @TableName='CRM_Opportunities A'
		SET @PrimaryColumn='A.OpportunityID'
		IF @IsUserWiseExists=1 --IF IT IS USERWISE TRUE THEN ONLY ADD THE CONDITION
		BEGIN	
			SET @ViewWhereCond='   AND 
			('''+@uid+'''=1 or
			(A.CreatedBy in ( select UserName from adm_users with(nolock) where UserID='+@uid+') or           
			'''+@uid+''' in ( select UserID from CRM_Assignment with(nolock) where CCID=89 and CCNODEID=A.OpportunityID and IsTeam=0 )' +           
			' or  '''+@uid+''' in ( select  UserID from COM_GROUPS with(nolock) where   GROUPNAME<>'''' AND GID  IN
			(select teamnodeid from CRM_Assignment with(nolock) where CCID=89 and CCNODEID=A.OpportunityID and ISGROUP=1) ) OR
			'''+@uid+''' in ( select  UserID from ADM_UserRoleMap with(nolock) where ROLEID IN
			(select teamnodeid from CRM_Assignment with(nolock) where CCID=89 and CCNODEID=A.OpportunityID and ISROLE=1) )
			or '''+@uid+''' in          
			(select userid from crm_teams with(nolock) where isowner=0 and  teamid in          
			( select teamnodeid from CRM_Assignment with(nolock) where CCID=89 and CCNODEID=A.OpportunityID and IsTeam=1)) ) 
			'       
			SET @ViewWhereCond = @ViewWhereCond + ' )'        
		END 
	END
	ELSE --DIMENSIONS
	BEGIN
		SELECT @TableName=TableName from adm_features with(nolock) where featureid=@CostCenterID		 
		set @TableName=@TableName +' A'
		SET @PrimaryColumn='A.NodeID  '
		IF @IsUserWiseExists=1 and @uid<>1
			SET @ViewWhereCond='  and A.CREATEDBY ='''+@UserID+''' '			 
	END 
		  
	if(@CostCenterID=3 or @CostCenterID>50000 )  and @LocationWhere<>'0'
	set @ViewWhereCond=@ViewWhereCond+' and ( '+@PrimaryColumn+' in (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock)           
	where ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+' and CostCenterID=50002 and (NodeID in ('+@LocationWhere+' ))))   '    

	IF(@IsUserWiseExists=1 and @CostCenterID <>2)
		set @SQL=' DECLARE @TABLE TABLE(USERNAME NVARCHAR(300),USERID INT) 
 			INSERT INTO @TABLE
 			EXEC spCOM_GetUserHierarchy '+@uid+','+convert(varchar,@CostCenterID)+','+convert(varchar,@CostCenterID)+' '
	ELSE 
		SET @SQL=''
	

	IF(@Next=0)
	BEGIN 
		SET @SQL = @SQL +' Select top 1 '+@PrimaryColumn+',A.IsGroup from '+@TableName + '  '+ @Join+'   WHERE  '+@PrimaryColumn+'>0 and A.lft>1 and A.lft<(SELECT LFT FROM '+@TableName+' where '+@PrimaryColumn+'='+ convert(Nvarchar(200),@SeqNo)+')' + @ViewWhereCond;
		if(@RecordType!=-1)
			SET @SQL = @SQL + ' and A.IsGroup='+convert(nvarchar,@RecordType)
		SET @SQL = @SQL + ' order by A.LFT desc  '
		EXEC(@SQL)
	END
	ELSE
	BEGIN 
		SET @SQL = @SQL +' Select top 1  '+@PrimaryColumn+',A.IsGroup from '+@TableName + '   '+ @Join+'    WHERE '+@PrimaryColumn+'>0 and  A.lft>1 and A.lft>(SELECT LFT FROM '+@TableName+' where '+@PrimaryColumn+'='+ convert(Nvarchar(200),@SeqNo)+')'+ @ViewWhereCond
		if(@RecordType!=-1)
			SET @SQL = @SQL + ' and A.IsGroup='+convert(nvarchar,@RecordType)
		SET @SQL = @SQL + ' order by A.LFT '
		EXEC(@SQL)  
	END
	print(@SQL)

	--SELECT ISNULL(@SeqNo,0)
    
SET NOCOUNT OFF;     
RETURN 1
END TRY
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT 'ERROR' 
		END   
   
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH
GO
