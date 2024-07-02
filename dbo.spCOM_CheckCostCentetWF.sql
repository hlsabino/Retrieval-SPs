USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_CheckCostCentetWF]
	@CostCenterID [int],
	@NodeID [int],
	@WID [int] = 0,
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@UserName [nvarchar](50),
	@StatusID [int] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @oldStatusID int
	set @oldStatusID=@StatusID
	declare @level int,@maxLevel int,@AppStatus int,@ApprovalID INT

	if(@WID>0)
	begin
		set @level=(SELECT  top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
		where WorkFlowID=@WID and  UserID =@UserID)

		if(@level is null )
			set @level=(SELECT top 1 LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)  
			where WorkFlowID=@WID and  RoleID =@RoleID)

		if(@level is null ) 
			set @level=(SELECT top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID))

		if(@level is null )
			set @level=( SELECT top 1  LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) 
			where RoleID =@RoleID))

		select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK)  where WorkFlowID=@WID  
		select @level,@maxLevel
		if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
		begin
			IF(@CostCenterID=50051 AND @level>1)
			BEGIN
				set @AppStatus=1002
				set @StatusID=1002
			END
			ELSE
			BEGIN
				set @AppStatus=1001
				set @StatusID=1001
			END


		end	
		else
		begin
			set @StatusID=@oldStatusID
			set @AppStatus=@StatusID
		end
		
		select @ApprovalID=max(ApprovalID) from COM_CCWorkFlow with(nolock) where CostCenterID=@CostCenterID and NodeID=@NodeID			
		if @ApprovalID is null or not exists(select WorkflowID from COM_CCWorkFlow WITH(NOLOCK) 
			where ApprovalID=@ApprovalID and WorkflowID=@WID and StatusID=@AppStatus and UserID=@UserID)
		begin
			INSERT INTO COM_CCWorkFlow(CostCenterID,NodeID,WorkflowID,WorkFlowLevel,StatusID,UserID,Remarks,CreatedBy,CreatedDate)
			VALUES(@CostCenterID,@NodeID,@WID,@level,@AppStatus,@UserID,'WorkFlow',@UserName,convert(float,getdate()))
		end
	end
/*	else if(@NodeID>0)--Edit
	begin
		select @ApprovalID=max(ApprovalID) from COM_CCWorkFlow with(nolock) where CostCenterID=@CostCenterID and NodeID=@NodeID			

		if @ApprovalID is not null
		begin
			declare @tempLevel int
			select @WID=WorkflowID,@tempLevel=WorkFlowLevel,@AppStatus=StatusID from COM_CCWorkFlow WITH(NOLOCK) 
			where ApprovalID=@ApprovalID

			--if(@WorkFlow is not null and @WorkFlow='NO')  
			--BEGIN
			--	set @level=@tempLevel
			--	set @StatusID=@oldStatus     
			--END
			--ELSE
			BEGIN	
				set @level=(SELECT LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
				where WorkFlowID=@WID and  UserID =@UserID)    
			    
				if(@level is null)    
					set @level=(SELECT LevelID FROM [COM_WorkFlow] WITH(NOLOCK)    
						where WorkFlowID=@WID and  RoleID =@RoleID)    
			    
				if(@level is null)     
					set @level=(SELECT LevelID FROM [COM_WorkFlow] WITH(NOLOCK)   
						where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID))    
			    
				if(@level is null)
					set @level=( SELECT LevelID FROM [COM_WorkFlow] WITH(NOLOCK)   
						where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where RoleID =@RoleID)) 
			   
				select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK)  where WorkFlowID=@WID  
				
				if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
				begin
					set @AppStatus=1001
					set @StatusID=1001
				end	
				else
				begin
					set @level=@maxLevel
					select @StatusID=StatusID from COM_Status with(nolock) where CostCenterID=@CostCenterID and [Status]='Active'
					set @AppStatus=1002
				end

				INSERT INTO COM_CCWorkFlow(CostCenterID,NodeID,WorkflowID,WorkFlowLevel,StatusID,UserID,Remarks,CreatedBy,CreatedDate)
				VALUES(@CostCenterID,@NodeID,@WID,@level,@AppStatus,@UserID,'WorkFlow',@UserName,convert(float,getdate()))
			END 
		end
	end*/
	
	declare @SQL nvarchar(max)
	if @oldStatusID!=@StatusID
	begin
		if @CostCenterID=2
			update ACC_Accounts set StatusID=@StatusID where AccountID=@NodeID
		else if @CostCenterID=3
			update INV_Product set StatusID=@StatusID where ProductID=@NodeID
		else if @CostCenterID=76
		begin
			SET @SQL='update PRD_BillOfMaterial set StatusID='+convert(nvarchar,@StatusID)+' where BOMID='+convert(nvarchar,@NodeID)
			exec(@SQL)
		end
		else if @CostCenterID=93
		begin
			SET @SQL='update [REN_Units] set [Status]='+convert(nvarchar,@StatusID)+' where UnitID='+convert(nvarchar,@NodeID)
			exec(@SQL)
		end
		else if @CostCenterID=94
		begin
			SET @SQL='update [REN_Tenant] set StatusID='+convert(nvarchar,@StatusID)+' where TenantID='+convert(nvarchar,@NodeID)
			exec(@SQL)
		end
		else if @CostCenterID=92
		begin
			SET @SQL='update [REN_Property] set StatusID='+convert(nvarchar,@StatusID)+' where NOdeid='+convert(nvarchar,@NodeID)
			exec(@SQL)
		end
		else if @CostCenterID>=50001 
		begin
			select @SQL='update '+TableName+' set StatusID='+convert(nvarchar,@StatusID)+' where NodeID='+convert(nvarchar,@NodeID)
			from ADM_Features with(nolock) where FeatureID=@CostCenterID
			exec(@SQL)
		end
		
		if @StatusID=1001 OR @StatusID=1002 OR @StatusID=1003 --UnApp,Rejected
			EXEC spCOM_SetNotifEvent @StatusID,@CostCenterID,@NodeID,'CompanyGUID',@UserName,@UserID,@RoleID
		else
			EXEC spCOM_SetNotifEvent -2000,@CostCenterID,@NodeID,'CompanyGUID',@UserName,@UserID,@RoleID
		
		IF EXISTS (SELECT * FROM COM_DocBridge WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND NodeID=@NodeID)
		BEGIN
			SELECT @CostCenterID=RefDimensionID,@NodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK) 
			WHERE CostCenterID=@CostCenterID AND NodeID=@NodeID
			
			if @CostCenterID>=50001
			begin
				IF(@StatusID<>1001 AND @StatusID<>1002 AND @StatusID<>1003)
					select @StatusID=StatusID from COM_Status with(nolock) where CostCenterID=@CostCenterID and [Status]='Active'
				select @SQL='update '+TableName+' set StatusID='+convert(nvarchar,@StatusID)+' where NodeID='+convert(nvarchar,@NodeID)
				from ADM_Features with(nolock) where FeatureID=@CostCenterID
				exec(@SQL)
			end
		END 
		
	end
--SELECT @StatusID

----EXEC [spCOM_CheckCostCentetWF] 50051,683,37,1,1,'admin',0
GO
