USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetWorkFlowScreenDetails]
	@LocationWhere [nvarchar](max) = null,
	@DivisionWhere [nvarchar](max) = null,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1,
	@IsCRM [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;
   declare @SQL nvarchar(max),@Where nvarchar(max)
   declare @PopulateonlyAssignedUsers bit
   
   if(@IsCRM=1)
		SELECT @PopulateonlyAssignedUsers=Value FROM COM_CostCenterPreferences WITH(nolock) 
		WHERE COSTCENTERID=1000 and  Name='PopulateonlyAssignedUsers'  
	else
		set @PopulateonlyAssignedUsers=0
		
	/*--Getting All Roles
	select RoleID,Name from ADM_PRoles WITH(NOLOCK) WHERE ISROLEDELETED=0 order by name
	
 	--Getting All Users
 	if (@IsCRM=0 or @UserID=1)
		select UserID,UserName from ADM_Users WITH(NOLOCK) WHERE ISUSERDELETED=0 AND StatusID=1 order by UserName
	else    
	begin
		if(@PopulateonlyAssignedUsers=1)
			select UserID,UserName from ADM_Users WITH(NOLOCK) where 
			UserID in (select nodeid  from COM_CostCenterCostCenterMap with(nolock) where parentcostcenterid=7 and parentnodeid=@UserID and costcenterid=7)
			or userid=@UserID AND StatusID=1 order by UserName
		else
			select UserID,UserName from ADM_Users WITH(NOLOCK) WHERE ISUSERDELETED=0 AND StatusID=1 order by UserName
	 end*/
	 
	set @Where=''
	if @LocationWhere is not null and @LocationWhere!=''
		set @Where=' and R.RoleID!=1 and R.RoleID IN (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=6 and CostCenterID=50002 and NodeID in ('+@LocationWhere+'))'
	if @DivisionWhere is not null and @DivisionWhere!=''
		set @Where=@Where+' and R.RoleID!=1 and R.RoleID IN (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=6 and CostCenterID=50001 and NodeID in ('+@DivisionWhere+'))'

	--Roles
	if (@IsCRM=1 AND @PopulateonlyAssignedUsers=1 AND @UserID<>1)
 	BEGIN
		SET @SQL='SELECT R.RoleID, R.Name FROM ADM_PRoles R WITH(NOLOCK) 
		WHERE R.RoleID IN (select UR.RoleID  from COM_CostCenterCostCenterMap CCM with(nolock) 
		inner join ADM_UserRoleMap UR WITH(NOLOCK) ON CCM.nodeid=UR.UserId
		where CCM.parentcostcenterid=7 and CCM.parentnodeid='+CONVERT(NVARCHAR,@UserID)+' and CCM.costcenterid=7) 
		AND R.StatusID=434'
		if @Where!=''
			SET @SQL=@SQL+@Where
		SET @SQL=@SQL+' ORDER BY Name'
		EXEC(@SQL)
	END
	else    
	begin
		SET @SQL='SELECT RoleID, Name FROM ADM_PRoles R WITH(NOLOCK) 
		WHERE StatusID=434'
		if @Where!=''
			SET @SQL=@SQL+@Where
		SET @SQL=@SQL+' ORDER BY Name'
		EXEC(@SQL)
	end
	
 	--Getting All Users
 	if (@IsCRM=1 AND @PopulateonlyAssignedUsers=1 AND @UserID<>1)
 	BEGIN
 		SET @SQL='SELECT DISTINCT U.UserID,U.UserName,U.FirstName FROM ADM_Users U WITH(NOLOCK)
		inner join ADM_UserRoleMap R WITH(NOLOCK) ON U.UserID=R.UserId
		WHERE U.UserID in (select nodeid  from COM_CostCenterCostCenterMap CCM with(nolock) where CCM.parentcostcenterid=7 and CCM.parentnodeid='+CONVERT(NVARCHAR,@UserID)+' and CCM.costcenterid=7)
		or u.userid='+CONVERT(NVARCHAR,@UserID)+' AND U.StatusID=1'+@Where+'
		ORDER BY U.UserName'
		EXEC(@SQL)
	END
	else    
	begin
		SET @SQL='SELECT DISTINCT U.UserID,U.UserName,U.FirstName FROM ADM_Users U WITH(NOLOCK)
		inner join ADM_UserRoleMap R WITH(NOLOCK) ON U.UserID=R.UserId
		WHERE U.StatusID=1'+@Where+'
		ORDER BY U.UserName'
		EXEC(@SQL)
	 end

	--Getting All Groups
	select distinct GID GroupID,GroupName from COM_Groups with(nolock) Where IsGroup=1 AND NodeID<>1 
	order by GroupName
	
	--getting Worflow list
	declare @Tbl as table(WorkFlowID INT,WorkFlowName nvarchar(max))
	if @UserID=1
		insert into @Tbl
		select  distinct WorkFlowID,WorkFlowName from COM_WorkFlow with(nolock)
	else
	insert into @Tbl
	SELECT M.NodeID,R.WorkFlowName FROM ADM_Assign M with(nolock) inner join (select  distinct WorkFlowID,WorkFlowName from COM_WorkFlow with(nolock)) R on R.WorkFlowID=M.NodeID 
	WHERE M.CostCenterID=100 and (UserID=@UserID OR RoleID=@RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID))

	select  distinct WorkFlowID,WorkFlowName from @Tbl order by WorkFlowName
	
	SELECT FeatureID,Name FROM ADM_Features with(nolock)
	WHERE ((IsEnabled=1  and FeatureID>50000 ) or (FeatureID between 40000 and 50000  )
	or FeatureID IN (2,3,73,76,72,83,86,89,92,93,94,95,103,104,129)) and (@RoleID=1 or @UserID=1 or FeatureID IN( select FA.FeatureID from adm_featureactionrolemap FAR with(nolock)
			inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
			where FAR.RoleID=@RoleID and (FA.FeatureActionTypeID=2 or FA.FeatureActionTypeID=3) 
			))
	order by Name
	
	select  distinct W.LevelID,W.LevelName,W.WorkFlowID 
	from COM_WorkFlow W with(nolock)
	inner join @Tbl T on T.WorkFlowID=W.WorkFlowID
	
 
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
