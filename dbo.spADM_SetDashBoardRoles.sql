USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDashBoardRoles]
	@Type [int],
	@ID [bigint] = 0,
	@Groups [nvarchar](max),
	@Roles [nvarchar](max),
	@Users [nvarchar](max),
	@Default [bit],
	@LocationWhere [nvarchar](max) = null,
	@DivisionWhere [nvarchar](max) = null,
	@CompanyGUID [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON
	
	declare @DT Float
	DECLARE @TblApp AS TABLE(G BIGINT NOT NULL DEFAULT(0),R BIGINT NOT NULL DEFAULT(0),U BIGINT NOT NULL DEFAULT(0) )

	set @DT=convert(Float,getdate())
	IF @Type=1--TO GET MAP INFORMATION
	BEGIN	
		--Groups,Roles,Users
		EXEC spADM_AssignInfo @LocationWhere,@DivisionWhere,@UserID
		
		SELECT UserID,RoleID,GroupID, IsDefault FROM ADM_DashBoardUserRoleMap WITH(NOLOCK) WHERE DashBoardID=@ID 
	END
	ELSE IF @Type=2
	BEGIN
	    DELETE FROM ADM_DashBoardUserRoleMap WHERE DashBoardID=@ID
	
		INSERT INTO @TblApp(G)
		EXEC [SPSplitString] @Groups,','

		INSERT INTO @TblApp(R)
		EXEC [SPSplitString] @Roles,','

		INSERT INTO @TblApp(U)
		EXEC [SPSplitString] @Users,','

		SELECT *,@UserName,@Dt FROM @TblApp
		
			--if(@Default=1)
			--	update ADM_DashBoardUserRoleMap set IsDefault=0 where
			--	DashBoardID<>@ID and (RoleID in (select R from @TblApp)
			--	Or UserID in (Select U from @TblApp) or GroupID in (Select G from @TblApp))
		

		INSERT INTO ADM_DashBoardUserRoleMap(DashBoardID,GroupID,RoleID,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,IsDefault)
		SELECT @ID,G,R,U,@CompanyGUID,newid(),@UserID,@DT,@Default
		FROM @TblApp
		ORDER BY U,R,G 

	END
	
COMMIT TRANSACTION
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID 
RETURN @ID
END TRY
BEGIN CATCH  
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
