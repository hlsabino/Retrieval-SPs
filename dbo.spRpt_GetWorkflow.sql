USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_GetWorkflow]
	@docid [bigint],
	@ccid [int],
	@invid [bigint],
	@QtnIDs [nvarchar](max),
	@UserID [int] = 0,
	@RoleID [bigint] = 0,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY   
SET NOCOUNT ON 

		declare @Userlevel int,@WID int,@Level int,@StatusID int,@canApprove int,@canPost int,@maxLevel int,@Appall int,@sql nvarchar(max)
	
		select @WID=WorkflowID from inv_docdetails WITH(NOLOCK)
		Where invdocdetailsid=@invid
		
		select @Level=Workflowlevel,@StatusID=Statusid from com_approvals WITH(NOLOCK)
		where ccid=@ccid and ccnodeid=-@docid
		order by ApprovalID
		
		if(@StatusID=372)
			set @Level=null
		 
		SELECT @Userlevel=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
		where WorkFlowID=@WID and  UserID =@UserID
		order by LevelID
		
		if(@Userlevel is null )  
			SELECT @Userlevel=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
			where WorkFlowID=@WID and  RoleID =@RoleID
			order by LevelID

		if(@Userlevel is null )       
			SELECT @Userlevel=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
			JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
			where g.UserID=@UserID and WorkFlowID=@WID
			order by LevelID

		if(@Userlevel is null )  
			SELECT @Userlevel=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
			JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
			where g.RoleID =@RoleID and WorkFlowID=@WID
			order by LevelID
		
		if(@Level is null and @Userlevel=1)
			set @canApprove=1   
		else if(@WID>0 and @Userlevel is not null and  @Level is not null and @Level+1=@Userlevel)  
			set @canApprove=1   
		else
			set @canApprove=0	
		
		select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK) where WorkFlowID=@WID
		
		if(@Userlevel=1 and @StatusID=369)
			set @canPost=1
		else
			set @canPost=0	
		
		set @sql='if exists(select statusid from INV_DocDetails WITH(NOLOCK) where Docid in('+@QtnIDs+') 
					and (statusid<>441 or WorkFlowLevel<>'+convert(nvarchar,@Userlevel)+')) set @appall=1 ELSE set @appall=0 '
		EXEC sp_executesql @sql,N'@appall int OUTPUT',@Appall output	
		
		if(@Userlevel=1)
			set @Appall=0
			
		SELECT @canApprove canApprove,@Userlevel userlevel,@WID WorkFlowID,@canPost canPost,@maxLevel maxLevel,@Appall Appall,@StatusID StatusID

SET NOCOUNT OFF;  
RETURN @canApprove  
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
