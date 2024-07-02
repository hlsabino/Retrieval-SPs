USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_AssignReport]
	@CallType [int],
	@Action [int],
	@ReportID [bigint],
	@Groups [nvarchar](max),
	@Roles [nvarchar](max),
	@Users [nvarchar](max),
	@LocationWhere [nvarchar](max) = null,
	@DivisionWhere [nvarchar](max) = null,
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON; 
 
	--Declaration Section  
	DECLARE @HasAccess BIT,@Dt FLOAT
	DECLARE @TblApp AS TABLE(G BIGINT NOT NULL DEFAULT(0),R BIGINT NOT NULL DEFAULT(0),U BIGINT NOT NULL DEFAULT(0))

	SET @Dt=CONVERT(FLOAT,GETDATE())

	--Check for manadatory paramters  
	IF(@ReportID < 0)     
	RAISERROR('-100',16,1)   

	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,200,7)
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END

	IF @CallType=1--TO GET USERS INFORMATION
	BEGIN
		--Groups,Roles,Users
		EXEC spADM_AssignInfo @LocationWhere,@DivisionWhere,@UserID

		SELECT UserID,RoleID,GroupID,0 IsParent FROM ADM_ReportsUserMap WITH(NOLOCK)
		WHERE ReportID=@ReportID AND ActionType=@Action
		union all
		select UserID,RoleID,GroupID,1 IsParent  FROM ADM_ReportsUserMap WITH(NOLOCK) WHERE reportid in
		(select parentid from adm_revenureports  WITH(NOLOCK)  where reportid=@ReportID) AND ActionType=@Action

	END
	ELSE IF @CallType=2
	BEGIN
		DELETE FROM ADM_ReportsUserMap WHERE ReportID=@ReportID AND ActionType=@Action
	
		INSERT INTO @TblApp(G)
		EXEC [SPSplitString] @Groups,','

		INSERT INTO @TblApp(R)
		EXEC [SPSplitString] @Roles,','

		INSERT INTO @TblApp(U)
		EXEC [SPSplitString] @Users,','

		SELECT *,@UserName,@Dt FROM @TblApp

		INSERT INTO ADM_ReportsUserMap(ReportID,GroupID,RoleID,UserID,CreatedBy,CreatedDate,ActionType)
		SELECT @ReportID,G,R,U,@UserName,@Dt,@Action
		FROM @TblApp
		ORDER BY U,R,G
		
		SELECT @ReportID,G,R,U,@UserName,@Dt,@Action
		FROM @TblApp
		ORDER BY U,R,G
	END
	ELSE IF @CallType=3--TO GET MAP INFORMATION
	BEGIN	
		SELECT UserID,RoleID,GroupID,0 IsParent FROM ADM_ReportsUserMap WITH(NOLOCK)
		WHERE ReportID=@ReportID AND ActionType=@Action
		union all
		select UserID,RoleID,GroupID,1 IsParent FROM ADM_ReportsUserMap WITH(NOLOCK) WHERE reportid in
		(select parentid from adm_revenureports WITH(NOLOCK) where reportid=@ReportID) AND ActionType=@Action
	END
	ELSE IF @CallType=4--TO GET ALL MAP INFORMATION
	BEGIN	
		SELECT UserID,RoleID,GroupID,0 IsParent,ActionType FROM ADM_ReportsUserMap WITH(NOLOCK)
		WHERE ReportID=@ReportID --AND ActionType=@Action
		union all
		select UserID,RoleID,GroupID,1 IsParent,ActionType FROM ADM_ReportsUserMap WITH(NOLOCK) WHERE reportid in
		(select parentid from adm_revenureports WITH(NOLOCK) where reportid=@ReportID) --AND ActionType=@Action
		order by RoleID,UserID,GroupID
	END
	ELSE IF @CallType=5
	BEGIN
		DELETE FROM ADM_ReportsUserMap WHERE ReportID=@ReportID
		declare @XML xml
		set @XML=@Groups
		
		INSERT INTO ADM_ReportsUserMap(ReportID,GroupID,RoleID,UserID,CreatedBy,CreatedDate,ActionType)
		select @ReportID,0,0,X.value('@ID','int'),@UserName,@Dt,X.value('@A','int')
		from @XML.nodes('/RPTXML/U') as Data(X)
		union all
		select @ReportID,0,X.value('@ID','int'),0,@UserName,@Dt,X.value('@A','int')
		from @XML.nodes('/RPTXML/R') as Data(X)
		union all
		select @ReportID,X.value('@ID','int'),0,0,@UserName,@Dt,X.value('@A','int')
		from @XML.nodes('/RPTXML/G') as Data(X)
	END
  
COMMIT TRANSACTION
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		 SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		 FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
