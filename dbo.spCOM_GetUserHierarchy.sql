USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetUserHierarchy]
	@UserID [int] = 1,
	@FEATURE [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @USERNAME NVARCHAR(300),@SQL NVARCHAR(MAX)
		SELECT @USERNAME=UserName FROM ADM_Users WITH(NOLOCK) WHERE UserID=@UserID
		CREATE TABLE #TABLES(ID INT IDENTITY(1,1),USERNAME NVARCHAR(300),USERID INT)
		--GET ASSIGNED USERS BY GROUP OWNER
		INSERT INTO #TABLES
		select UserName,UserID from dbo.adm_users WITH(NOLOCK) where userid in (select nodeid from dbo.COM_CostCenterCostCenterMap WITH(NOLOCK) where 
		Parentcostcenterid=7 and costcenterid=7 and ParentNodeid=@UserID) 
		union 
		select UserName,UserID from adm_users WITH(NOLOCK) where Userid=@UserID
		
		IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='CRM_Assignment')
		BEGIN
			--GET ASSIGNED USERS
			SET @SQL='INSERT INTO #TABLES
			SELECT USERNAME,UserID FROM ADM_Users WITH(NOLOCK) WHERE UserID IN (
			SELECT   UserID from CRM_Assignment with(nolock) where CCID='+CONVERT(NVARCHAR,@FEATURE)+'  and IsTeam=0
			AND UserID='+CONVERT(NVARCHAR,@UserID)+')' --and CCNODEID=A.LeadID'

			EXEC (@SQL)

			--GET GROUP USERS
			SET @SQL='INSERT INTO #TABLES
			SELECT USERNAME,UserID FROM ADM_Users WITH(NOLOCK) WHERE UserID IN 
			( select UserID from COM_GROUPS with(nolock) where   GROUPNAME<>'''' AND UserID='+CONVERT(NVARCHAR,@UserID)+' AND GID  IN    
			(select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(NVARCHAR,@FEATURE)+' and ISGROUP=1) )' 

			EXEC (@SQL)

			--GET ROLES USERS
			SET @SQL='INSERT INTO #TABLES
			SELECT USERNAME,UserID FROM ADM_Users WITH(NOLOCK) WHERE UserID IN (
			select  UserID from ADM_UserRoleMap with(nolock) where ROLEID IN    
			(select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(NVARCHAR,@FEATURE)+' AND UserID='+CONVERT(NVARCHAR,@UserID)+' and ISROLE=1) )'

			EXEC (@SQL)
			--GET TEAM USERS
			SET @SQL='INSERT INTO #TABLES
			SELECT USERNAME,UserID FROM ADM_Users WITH(NOLOCK) WHERE UserID IN
			(select userid from crm_teams with(nolock) where isowner=0 and  teamid in              
			( select teamnodeid from CRM_Assignment with(nolock) where CCID='+CONVERT(NVARCHAR,@FEATURE)+' AND UserID='+CONVERT(NVARCHAR,@UserID)+' and IsTeam=1))'  

			EXEC (@SQL)
				
	   		 --GET  GROUP OWNER BY ASSIGNED USER
			SET @SQL='INSERT INTO #TABLES
	   		SELECT USERNAME,UserID FROM ADM_Users WITH(NOLOCK) WHERE UserID IN(
			 select UserID from CRM_Assignment with(nolock) where CCID='+CONVERT(NVARCHAR,@FEATURE)+'
			AND USERID IN ( 
			select nodeid from dbo.COM_CostCenterCostCenterMap with(nolock) where 
		   Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='+CONVERT(NVARCHAR,@UserID)+'))'
			
			EXEC (@SQL)
		END
		-- TO GET SUB CHILD ITEMS  FROM CHILD ITEMS
		/*    A
			  |	
			|   |	
			B   C
		
		TO GET 'B' USERS AND 'C' USERS   
		*/
		CREATE TABLE #TblUsers(iUserID int)
		CREATE TABLE #TblQueue(iUserID int)
		Create TABLE #TblTemp (ID int identity(1,1), iUserID int)
		declare @i int
		declare @iTemp int
		declare @iTempUserID int
		declare @QueueLen int
		declare @DUSERID int
		
		SET @DUSERID=@UserID
		SET @QueueLen=1

		INSERT INTO #TblQueue 
		select @DUSERID

		WHILE @QueueLen<>0
		BEGIN

		SET @DUSERID=(select top 1 iUserID from #TblQueue WITH(NOLOCK))
		INSERT INTO #TblUsers
		SELECT @DUSERID

		delete from #TblQueue where iUserID=@DUSERID

		INSERT INTO #TblTemp(iUserID)
		select nodeid from dbo.COM_CostCenterCostCenterMap WITH(NOLOCK) where 
		 Parentcostcenterid=7 and costcenterid=7 and ParentNodeid=@DUSERID
 
 		SET @i=(select count(ID) from #TblTemp WITH(NOLOCK))
 		 
		WHILE @i<>0
		BEGIN 
		SET @iTempUserID=(select iUserID from #TblTemp WITH(NOLOCK) WHERE ID=@i)
		SET @iTemp=(select count(*) from #TblQueue WITH(NOLOCK) where iUserID=@iTempUserID)
		IF @iTemp = 0
		BEGIN
			SET @iTemp=(select count(*) from #TblUsers WITH(NOLOCK) where iUserID=@iTempUserID) 
			IF @iTemp = 0
			BEGIN
				INSERT INTO #TblQueue
				SELECT @iTempUserID
			END
		END
		SET @i=@i-1
		END
		TRUNCATE TABLE #TblTemp
		SET @QueueLen=(select count(*) from #TblQueue WITH(NOLOCK))
		END
		
		INSERT INTO #TABLES
		SELECT USERNAME,UserID FROM ADM_Users WITH(NOLOCK) WHERE UserID IN (
		select iUserID from #TblUsers WITH(NOLOCK) WHERE UserID<>@UserID)    
		
		 
		SELECT DISTINCT USERNAME,UserID FROM  #TABLES WITH(NOLOCK)
		
		DROP TABLE #TABLES
		DROP TABLE #TblUsers
		DROP TABLE #TblQueue
		DROP TABLE #TblTemp


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

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
