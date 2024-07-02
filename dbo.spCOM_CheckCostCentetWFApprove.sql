USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_CheckCostCentetWFApprove]
	@CostCenterID [int],
	@NodeID [bigint],
	@UserID [int] = 0,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @WID INT,@level int,@maxLevel int,@WFStatus int,@ApprovalID bigint,@userlevel int,@Type int
		,@canEdit bit,@canApprove bit,@ActiveStatus int,@escDays int,@CreatedDate datetime

	set @canEdit=1
	set @canApprove=0
	
	if @CostCenterID=16
		set @ActiveStatus=1
	else
		select @ActiveStatus=StatusID from COM_Status with(nolock) where CostCenterID=@CostCenterID and [Status]='Active'


	-- select * from COM_CCWorkFlow with(nolock) where CostCenterID=@CostCenterID and NodeID=@NodeID

	select @ApprovalID=max(ApprovalID) from COM_CCWorkFlow with(nolock) where CostCenterID=@CostCenterID and NodeID=@NodeID
	
	if @ApprovalID is not null
	begin
		select @WID=WorkflowID,@Level=WorkFlowLevel,@WFStatus=StatusID,@CreatedDate=convert(datetime,CreatedDate) from COM_CCWorkFlow WITH(NOLOCK) 
		where ApprovalID=@ApprovalID
	
		SELECT @Userlevel=LevelID,@Type=type FROM [COM_WorkFlow]   WITH(NOLOCK)   
		where WorkFlowID=@WID and  UserID =@UserID

		if(@Userlevel is null )  
			SELECT @Userlevel=LevelID,@Type=type FROM [COM_WorkFlow]  WITH(NOLOCK)    
			where WorkFlowID=@WID and  RoleID =@RoleID

		if(@Userlevel is null )       
			SELECT @Userlevel=LevelID,@Type=type FROM [COM_WorkFlow] W WITH(NOLOCK)
			JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
			where g.UserID=@UserID and WorkFlowID=@WID

		if(@Userlevel is null )  
			SELECT @Userlevel=LevelID,@Type=type FROM [COM_WorkFlow] W WITH(NOLOCK)
			JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
			where g.RoleID =@RoleID and WorkFlowID=@WID
			
		/*if(@StatusID=369 or @StatusID=441 or @StatusID=371)  
		begin  
			if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
				set @canEdit=0   
		end*/
		if @WFStatus=1003 and @Userlevel=@level
			set @canApprove=1
		else if(@WFStatus!=@ActiveStatus)  
		begin    
			if(@Userlevel is not null and  @Level is not null and @Userlevel>@level)  
			begin
				IF(@Type=1 or @Level+1=@Userlevel)
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
		end  
	end
	
	select @canApprove canapprove,@canEdit CanEdit
GO
