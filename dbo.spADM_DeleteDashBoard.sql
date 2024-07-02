USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteDashBoard]
	@DashBoardID [bigint] = 0,
	@ForceDelete [bit] = 0,
	@UserID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	declare @DashName nvarchar(50), @lft bigint, @rgt bigint, @IsGroup bit
	select @DashName=DashBoardName, @lft=lft, @rgt=rgt, @IsGroup=IsGroup from ADM_DashBoard with(nolock) where DashBoardID=@DashBoardID
	
	declare @Tbl as table(id int identity(1,1),DashBoardID bigint)
	insert into @Tbl
	select DashBoardID from ADM_DashBoard with(nolock) WHERE lft >= @lft AND rgt <= @rgt
	
	if @ForceDelete=0 and exists(select * from ADM_DashBoardUserRoleMap M with(nolock) join @Tbl T on M.DashBoardID=T.DashBoardID and UserID!=@UserID)
	begin
		SELECT 'Dashboard assigned to users. Still do you want to delete?' ErrorMessage,-101 ErrorNumber
		ROLLBACK TRANSACTION
		return -101
	end
	
	delete from com_languageresources where ResourceName=@DashName and Feature='DASHBOARD'

	delete  from ADM_RibbonView where FeatureID=499 and  featureactionid in (select DashBoardID from @Tbl) 
				
	delete  from ADM_DashBoardUserRoleMap where DashBoardID  in (select DashBoardID from @Tbl)
		
	delete  from ADM_DashBoard where DashBoardID  in (select DashBoardID from @Tbl)

COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
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
