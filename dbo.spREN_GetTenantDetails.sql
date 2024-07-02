USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetTenantDetails]
	@TenantID [int] = 0,
	@UserID [int],
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
		
	SELECT * FROM REN_Tenant  WITH(NOLOCK) 
	WHERE TenantID=@TenantID
	
	--Getting data from Tenant extended table
	SELECT * FROM  REN_TenantExtended WITH(NOLOCK) 
	WHERE TenantID=@TenantID

	SELECT * FROM COM_CCCCDATA  WITH(NOLOCK)
	WHERE NodeID = @TenantID AND CostCenterID  = 94 
	
	SELECT * FROM COM_Notes WITH(NOLOCK)   
	WHERE FeatureID = 94 AND FeaturePK  = @TenantID
	
	EXEC [spCOM_GetAttachments] 94,@TenantID,@UserID
	
	--WorkFlow
	--EXEC spCOM_CheckCostCentetWFApprove 94,@TenantID,@UserID,@RoleID
	print 'UserID'
	print @UserID
	print '@RoleID'
	print @RoleID

	SELECT 1 WHERE 1<>1
	
	IF(EXISTS(SELECT * FROM CRM_Activities WHERE CostCenterID=94 AND NodeID=@TenantID))
		EXEC spCRM_GetFeatureByActvities @TenantID,94,'',@UserID,@LangID  
	ELSE
		SELECT 1 WHERE 1<>1

	--8 Getting Contacts  
	EXEC [spCom_GetFeatureWiseContacts] 94,@TenantID,2,1,1

	--9 Getting Contacts  
	EXEC [spCom_GetFeatureWiseContacts] 94,@TenantID,1,1,1
	
	-- GET CCCCC MAP DATA
	EXEC [spCOM_GetCCCCMapDetails] 94,@TenantID,@LangID
	
	--GET ALERTS DATA
	SELECT A.*,isnull(F.ActualFileName,'') ActualFileName,F.FileID AttachmentID,F.GUID FROM COM_ALERTS A WITH(NOLOCK) 
	Left join COM_FILES F WITH(NOLOCK) on F.FileID=A.AttachmentID
	WHERE A.FeatureID = 94 AND A.FeaturePK  = @TenantID
	
	--GET ALERTS DATA
	SELECT AlertID,AlertMessage,FeatureID,FeaturePK,convert(varchar,convert(datetime,fromdate),106)+' '+convert(varchar,convert(datetime,fromdate),108) FromDate,
	convert(varchar,convert(datetime,todate),106)+' '+convert(varchar,convert(datetime,todate),108) ToDate,StatusID,
	convert(datetime,CreatedDate) CreatedDate,convert(datetime,ModifiedDate) ModifiedDate,CreatedBy,ModifiedBy FROM COM_ALERTS WITH(NOLOCK)  
	WHERE FeatureID=94 AND FeaturePK=@TenantID
	
	--GET ARTIFACTS DATA
	SELECT * FROM COM_ARTIFACTS WITH(NOLOCK)   
	WHERE FeatureID = 94 AND FeaturePK  = @TenantID


	Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM REN_Tenant WITH(NOLOCK) where TenantID=@TenantID
		if(@WID is not null and @WID>0)  
		BEGIN  
			SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and  UserID =@UserID

			if(@Userlevel is null)  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID

			if(@Userlevel is null)       
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID

			if(@Userlevel is null)  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID
			
			if(@Userlevel is null )  	
				SELECT @Type=[type] FROM [COM_WorkFlow] WITH(NOLOCK) where WorkFlowID=@WID


		set @canEdit=1  
		print '@StatusID'
		print @StatusID
		if(@StatusID =1002)  
		begin  
			if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=0   
			end    
		end
		ELSE if(@StatusID=1003)
		BEGIN
		    if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=1
			end
			ELSE
				set @canEdit=0
		END
			print '@Userlevel'
			print @Userlevel
		if(@StatusID=1001 or @StatusID=1002)  
		begin    
			if(@Userlevel is not null and  @Level is not null and @Userlevel>@level)  
			begin
				if(@Type=1 or @Level+1=@Userlevel)
					set @canApprove=1   
				ELSE
				BEGIN
					if exists(select EscDays FROM [COM_WorkFlow]
					where workflowid=@WID and ApprovalMandatory=1 and LevelID<@Userlevel and LevelID>@Level)
						set @canApprove=0
					ELSE
					BEGIN	
						select @escDays=sum(escdays) from (select max(escdays) escdays from [COM_WorkFlow] WITH(NOLOCK) 
						where workflowid=@WID and LevelID<@Userlevel and LevelID>@Level
						group by LevelID) as t
						 
						set @CreatedDate=dateadd("d",@escDays,@CreatedDate)
						
						select @escDays=sum(escdays) from (select max(eschours) escdays from [COM_WorkFlow] WITH(NOLOCK) 
						where workflowid=@WID and LevelID<@Userlevel and LevelID>@Level
						group by LevelID) as t
						
						set @CreatedDate=dateadd("HH",@escDays,@CreatedDate)
						
						if (@CreatedDate<getdate())
							set @canApprove=1   
						ELSE
							set @canApprove=0
					END	
				END	
			end   
			--else if(@Userlevel is not null and  @Level is not null and @Level=@Userlevel and @StatusID=1001)  
			--begin
			--	set @canApprove=1  
			--end
			else  
				set @canApprove= 0   
		end  		
		else  
			set @canApprove= 0   

		IF @WID is not null and @WID>0
		begin

			
			select @canEdit canEdit,@canApprove canApprove

			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U 
			with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=94
			AND CCNodeID=@TenantID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		
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
