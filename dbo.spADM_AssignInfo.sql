USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_AssignInfo]
	@LocationWhere [nvarchar](max) = null,
	@DivisionWhere [nvarchar](max) = null,
	@UserID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @SQL nvarchar(max),@Where nvarchar(max),@ShowTeam BIT

	set @Where=''
	if @LocationWhere is not null and @LocationWhere!=''
		set @Where=' and R.RoleID!=1 and R.RoleID IN (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=6 and CostCenterID=50002 and NodeID in ('+@LocationWhere+'))'
	if @DivisionWhere is not null and @DivisionWhere!=''
		set @Where=@Where+' and R.RoleID!=1 and R.RoleID IN (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=6 and CostCenterID=50001 and NodeID in ('+@DivisionWhere+'))'
	
	--Groups
	SELECT GID,GroupName FROM COM_Groups WITH(NOLOCK)
	Group By GID,GroupName
	HAVING GroupName IS NOT NULL
	ORDER BY GroupName
	   
	--Roles
	SET @SQL='SELECT RoleID, Name FROM ADM_PRoles R WITH(NOLOCK) WHERE StatusID=434'
	if @Where!=''
		SET @SQL=@SQL+@Where
	SET @SQL=@SQL+' ORDER BY Name'
	EXEC sp_executesql @SQL
	
	if exists(select * from adm_globalpreferences WITH(NOLOCK) where name='Showonlyteam' and value='true')
		set @ShowTeam=1
	else	
		set @ShowTeam=0
	
	--Getting All Users
	SET @SQL=''
	if(@ShowTeam=1)
	BEGIN
		SET @SQL='declare @cnt int,@newcnt int
		declare @tab table(userid int,ischecked bit)
		insert into @tab
		select ParentNodeID,0 from COM_CostCenterCostCenterMap WITH(nolock)
		where CostCenterID=-7 and nodeid='+convert(nvarchar(max),@UserID)+' and PARENTcostcenterid=7
		select @cnt=count(*) from @tab
		while(@cnt>0)
		BEGIN
			insert into @tab
			select ParentNodeID,0 from COM_CostCenterCostCenterMap a WITH(nolock)
			join @tab b on  a.nodeid=b.userid	
			where ParentCostCenterID=7 and ischecked=0 and costcenterid=-7
			and ParentNodeID not in(select userid from @tab)
			
			select @cnt=count(*) from @tab where ischecked=0	
			update @tab
			set ischecked=1	
		END
		
		if exists(select * from adm_globalpreferences WITH(NOLOCK) where name=''AllifTeamNotMap'' and value=''true'')
		and not exists(select * from @tab)		
		BEGIN
			 SELECT distinct U.UserID,U.UserName FROM ADM_Users U WITH(NOLOCK)
			 inner join ADM_UserRoleMap R WITH(NOLOCK) ON U.UserID=R.UserId
			 WHERE U.StatusID=1'+@Where+'
			 ORDER BY U.UserName
		END
		ELSE
		BEGIN
			 SELECT distinct U.UserID,U.UserName FROM ADM_Users U WITH(NOLOCK)
			 join @tab t on t.userid=U.UserID
			 inner join ADM_UserRoleMap R WITH(NOLOCK) ON U.UserID=R.UserId
			 WHERE U.StatusID=1'+@Where+'
			 UNION 
			 SELECT U.UserID,U.UserName FROM ADM_Users U WITH(NOLOCK)
			 WHERE U.UserID='+convert(nvarchar(max),@UserID)+'
			 ORDER BY UserName
		END
	
		'
	END
	ELSE
	BEGIN
		SET @SQL=@SQL+' SELECT distinct U.UserID,U.UserName FROM ADM_Users U WITH(NOLOCK)
			inner join ADM_UserRoleMap R WITH(NOLOCK) ON U.UserID=R.UserId
			WHERE U.StatusID=1'+@Where+'
			ORDER BY U.UserName'
	END	
	
	EXEC sp_executesql @SQL
GO
