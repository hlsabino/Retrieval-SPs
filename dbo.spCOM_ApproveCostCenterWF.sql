USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_ApproveCostCenterWF]
	@CostCenterID [int],
	@NodeID [int],
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@UserName [nvarchar](50),
	@Remarks [nvarchar](max) = NULL,
	@IsReject [bit],
	@StatusID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY                                
SET NOCOUNT ON;
	declare @oldStatusID int,@SQL nvarchar(max)
	set @oldStatusID=@StatusID
	declare @level int,@maxLevel int,@AppStatus int,@ApprovalID INT

	select @ApprovalID=max(ApprovalID) from COM_CCWorkFlow with(nolock) where CostCenterID=@CostCenterID and NodeID=@NodeID			

	if @ApprovalID is not null
	begin
		declare @tempLevel int,@WID int
		select @WID=WorkflowID,@tempLevel=WorkFlowLevel,@AppStatus=StatusID from COM_CCWorkFlow WITH(NOLOCK) 
		where ApprovalID=@ApprovalID

		--if(@WorkFlow is not null and @WorkFlow='NO')  
		--BEGIN
		--	set @level=@tempLevel
		--	set @StatusID=@oldStatus     
		--END
		--ELSE
		BEGIN	
			SELECT @level=LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
			where WorkFlowID=@WID and  UserID =@UserID    

			if(@level is null)    
				SELECT @level=LevelID FROM [COM_WorkFlow] WITH(NOLOCK)    
					where WorkFlowID=@WID and  RoleID =@RoleID    
		    
			if(@level is null)     
				SELECT @level=LevelID FROM [COM_WorkFlow] WITH(NOLOCK)   
					where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID)    
		    
			if(@level is null)
				SELECT @level=LevelID FROM [COM_WorkFlow] WITH(NOLOCK)   
					where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where RoleID =@RoleID) 
		   
			select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK)  where WorkFlowID=@WID  
			
			if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
			begin
			
				IF(@CostCenterID=50051 AND @level>1)
				BEGIN
					if(@IsReject=1)
					begin
						--set @level=@maxLevel
						set @AppStatus=1003
						set @StatusID=1003
					end
					ELSE
					BEGIN
						set @AppStatus=1002
						set @StatusID=1002
					END
				END
				ELSE
				BEGIN
					IF(@level>1)
					BEGIN
						set @AppStatus=1002
						set @StatusID=1002
					END
					ELSE
					BEGIN
						set @AppStatus=1001
						set @StatusID=1001
					END
				END
			end	
			else
			begin
				if(@IsReject=1)
				begin
					set @level=@maxLevel
					set @AppStatus=1003
					set @StatusID=1003
				end
				else
				begin
					set @level=@maxLevel
					select @StatusID=StatusID from COM_Status with(nolock) where CostCenterID=@CostCenterID and [Status]='Active'
					set @AppStatus=@StatusID
				end
			end

			INSERT INTO COM_CCWorkFlow(CostCenterID,NodeID,WorkflowID,WorkFlowLevel,StatusID,UserID,Remarks,CreatedBy,CreatedDate)
			VALUES(@CostCenterID,@NodeID,@WID,@level,@AppStatus,@UserID,@Remarks,@UserName,convert(float,getdate()))
		END 
	end
	select @oldStatusID,@StatusID
	if @oldStatusID!=@StatusID
	begin
		if @CostCenterID=2
			update ACC_Accounts set StatusID=@StatusID where AccountID=@NodeID
		else if @CostCenterID=3
			update INV_Product set StatusID=@StatusID where ProductID=@NodeID
		else if @CostCenterID=76
		begin
			set @SQL='update PRD_BillOfMaterial set StatusID='+convert(nvarchar,@StatusID)+' where BOMID='+convert(nvarchar,@NodeID)
			exec(@SQL)
		end
		else if @CostCenterID=93
		begin
			set @SQL='update [REN_Units] set [Status]='+convert(nvarchar,@StatusID) + 'where UnitID= '+convert(nvarchar,@NodeID)
			exec(@SQL)
		end
		else if @CostCenterID=94
		begin
			set @SQL='update [REN_Tenant] set StatusID=' +convert(nvarchar,@StatusID) + 'where TenantID= '+convert(nvarchar,@NodeID)
			exec(@SQL)
		end
		else if @CostCenterID=92
		begin
			set @SQL='update [REN_Property] set StatusID=' +convert(nvarchar,@StatusID) +'where Nodeid= '+convert(nvarchar,@NodeID)
		    exec(@SQL)
		end		
		else if ((@CostCenterID>=50001 and @CostCenterID<=50054) or  @CostCenterID=50170)
		begin
			select @SQL='update '+TableName+' set StatusID='+convert(nvarchar,@StatusID)+' where NodeID='+convert(nvarchar,@NodeID)
			from ADM_Features with(nolock) where FeatureID=@CostCenterID
			exec(@SQL)
		end
		
		if @StatusID=1001 OR @StatusID=1002 OR @StatusID=1003 --UnApp,Approved,Rejected
			EXEC spCOM_SetNotifEvent @StatusID,@CostCenterID,@NodeID,'CompanyGUID',@UserName,@UserID,@RoleID
		else
			EXEC spCOM_SetNotifEvent -2000,@CostCenterID,@NodeID,'CompanyGUID',@UserName,@UserID,@RoleID
	end

COMMIT TRANSACTION                               
--ROLLBACK TRANSACTION                               
SET NOCOUNT OFF;                              
RETURN @StatusID
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
ROLLBACK TRANSACTION                              
SET NOCOUNT OFF                                
RETURN -999                       
END CATCH   


----spCOM_ApproveCostCenterWF 
-- 50051
-- ,746
-- ,33
-- ,126
-- ,'adhi2'
-- ,'appprr l3'
-- ,False
-- ,1001
-- ,1
GO
