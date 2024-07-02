USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDashBoard]
	@Type [int],
	@DashBoardID [int],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

if @Type=1
begin
	select R.ReportName as Report,DB.* from ADM_DashBoard DB with(nolock)
	LEFT JOIN ADM_REVENUREPORTS R with(nolock) on DB.ReportID=R.ReportID where DashBoardID=@DashBoardID
	order by DB.RowNo,DB.ColNo
	
	--select * from ADM_DashBoardUserRoleMap with(nolock) where DashBoardID=@DashBoardID
end
else if @Type=2
begin	
	select N.DashBoardID,N.DashBoardName,isnull(isnull(GP.DashBoardName,G.DashBoardName),(select DashBoardName from ADM_DashBoard with(nolock) where NodeID=1)) GroupName
	,isnull(isnull(GP.lft,G.lft),1) lft
	from ADM_DashBoard N with(nolock) 
	left join ADM_DashBoard G with(nolock) on N.ParentID=G.DashBoardID
	left join ADM_DashBoard GP with(nolock) on GP.IsGroup=1 AND N.ParentID=GP.NodeID
	where N.DashBoardID IN (
	select DashBoardID from ADM_DashBoard with(nolock) 
	 where IsGroup=0 and (ParentID=0 or  (@RoleID=1 or createdby=@UserID  
	   or (DashBoardID IN  
	(
	(SELECT DashBoardID FROM ADM_DashBoardUserRoleMap with(nolock) WHERE UserID=@UserID OR RoleID=@RoleID   
		or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID))
	union
	SELECT SR.DashBoardID FROM ADM_DashBoardUserRoleMap M with(nolock) 
	inner join ADM_DashBoard D with(nolock) on D.DashBoardID=M.DashBoardID and D.IsGroup=1
	inner join ADM_DashBoard SR with(nolock) on SR.lft between D.lft and D.rgt and SR.DashBoardID>0
	WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
	)))))
	group by N.DashBoardID,N.DashBoardName,G.DashBoardName,G.lft,N.lft,GP.lft,GP.DashBoardName
	order by lft,N.lft
end
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
