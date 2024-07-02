USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetNotifEvent]
	@ActionType [int],
	@CostCenterID [int],
	@NodeID [int],
	@CompanyGUID [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@SUBCostCenterID [int] = 0,
	@SUBNodeID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	
	--Insert Notifications
	DECLARE @NotifGUID NVARCHAR(50),@Dt FLOAT,@IsEmailBasedOnDim BIT,@IsEmailBasedOnField BIT,@EmailBasedOn NVARCHAR(MAX)
	,@IsSMSBasedOnDim BIT,@IsSMSBasedOnField BIT,@SMSBasedOn NVARCHAR(MAX),@WID int,@IsInventory bit
	DECLARE @TblDim AS TABLE(ID INT,NotifType int)
	DECLARE @TblField AS TABLE(TXT NVARCHAR(MAX),NotifType int)
	DECLARE @TblTemplates AS TABLE(ID INT PRIMARY KEY,GUID nvarchar(max),IsApproveButton bit)
	DECLARE @WorkflowID bigint,@WorkflowLevel int
	SET @Dt=CONVERT(FLOAT,GETDATE())
	SET @NotifGUID=newid()	
	SET @IsEmailBasedOnDim=0
	SET @IsEmailBasedOnField=0
	SET @IsSMSBasedOnDim=0
	SET @IsSMSBasedOnField=0
	
	if @NodeID=0 OR (SELECT COUNT(*) FROM ADM_GlobalPreferences WITH(nolock) WHERE (Name='EnableEmail' or Name='EnableSMS' or Name='EnablePushNotifications') AND Value='Yes')=0
		return
		
	IF @RoleID=-1
		SELECT @RoleID=RoleID FROM ADM_UserRoleMap with(nolock) where UserID=@UserID
	
	IF(@ActionType = 371 or @ActionType = 372 or @ActionType = 441 or  @ActionType = 369)
	BEGIN
		IF(@CostCenterID=95 or @CostCenterID=104 or @CostCenterID=103 or @CostCenterID=129 ) 
		BEGIN
			select @WorkflowID = WorkFlowID, @WorkflowLevel = WorkFlowLevel from Ren_Contract with(nolock) where ContractID = @NodeID
		END 
		ELSE IF(@CostCenterID>40000 and @CostCenterID<50000) 
		BEGIN
			IF((SELECT isInventory from ADM_DOCUMENTTYPES with(nolock) where CostCenterid=@CostCenterID)=1) --INVENTORY DOCUMENTS
			BEGIN
				select @WorkflowID = WorkFlowID, @WorkflowLevel = WorkFlowLevel from inv_docdetails with(nolock) where DocID = @NodeID
			END
			ELSE
			BEGIN
				select @WorkflowID = WorkFlowID, @WorkflowLevel = WorkFlowLevel from acc_docdetails with(nolock) where DocID = @NodeID
			END
		END
	END

	if @CostCenterID>40000 and @CostCenterID<50000
	begin
		select @IsInventory=IsInventory from adm_documentTypes with(nolock) WHERE CostCenterID=@CostCenterID
		select @EmailBasedOn=PrefValue FROM COM_DocumentPreferences with(nolock) WHERE CostCenterID=@CostCenterID AND PrefName='EmailBasedOnDimension'
		select @SMSBasedOn=PrefValue FROM COM_DocumentPreferences with(nolock) WHERE CostCenterID=@CostCenterID AND PrefName='SMSBasedOnDimension'
		if @EmailBasedOn IS NOT NULL AND @EmailBasedOn!=''
		begin
			if isnumeric(@EmailBasedOn)=1 and convert(int,@EmailBasedOn)>50000
			begin
				set @IsEmailBasedOnDim=1
				set @EmailBasedOn='dcCCNID'+convert(nvarchar,(convert(int,@EmailBasedOn)-50000))
				if(@IsInventory=1)
					set @EmailBasedOn='select distinct '+@EmailBasedOn+',1 FROM INV_DocDetails D with(nolock) inner join com_DocCCData dcc with(nolock) on dcc.invdocdetailsID=D.invdocdetailsID'
				else
					set @EmailBasedOn='select distinct '+@EmailBasedOn+',1 FROM ACC_DocDetails D with(nolock) inner join com_DocCCData dcc with(nolock) on dcc.accdocdetailsID=D.accdocdetailsID'
				 set @EmailBasedOn=@EmailBasedOn+' where D.CostCenterID='+convert(nvarchar,@CostCenterID)+' and D.DocID='+convert(nvarchar,@NodeID)

				INSERT INTO @TblDim
				EXEC(@EmailBasedOn)
			end
			else 
			begin
				set @IsEmailBasedOnField=1				
				if(@IsInventory=1)
					set @EmailBasedOn='select distinct '+@EmailBasedOn+',1 FROM INV_DocDetails D with(nolock) inner join com_DocTextData txt with(nolock) on txt.invdocdetailsID=D.invdocdetailsID'
				else
					set @EmailBasedOn='select distinct '+@EmailBasedOn+',1 FROM ACC_DocDetails D with(nolock) inner join com_DocTextData txt with(nolock) on txt.accdocdetailsID=D.accdocdetailsID'
				 set @EmailBasedOn=@EmailBasedOn+' where D.CostCenterID='+convert(nvarchar,@CostCenterID)+' and D.DocID='+convert(nvarchar,@NodeID)
				 
				INSERT INTO @TblField
				EXEC(@EmailBasedOn)
			end
		end
		if @SMSBasedOn IS NOT NULL AND @SMSBasedOn!=''
		begin
			if isnumeric(@SMSBasedOn)=1 and convert(int,@SMSBasedOn)>50000
			begin
				set @IsSMSBasedOnDim=1
				set @SMSBasedOn='dcCCNID'+convert(nvarchar,(convert(int,@SMSBasedOn)-50000))
				if(@IsInventory=1)
					set @SMSBasedOn='select distinct '+@SMSBasedOn+',2 FROM INV_DocDetails D with(nolock) inner join com_DocCCData dcc with(nolock) on dcc.invdocdetailsID=D.invdocdetailsID'
				else
					set @SMSBasedOn='select distinct '+@SMSBasedOn+',2 FROM ACC_DocDetails D with(nolock) inner join com_DocCCData dcc with(nolock) on dcc.accdocdetailsID=D.accdocdetailsID'
				 set @SMSBasedOn=@SMSBasedOn+' where D.CostCenterID='+convert(nvarchar,@CostCenterID)+' and D.DocID='+convert(nvarchar,@NodeID)

				INSERT INTO @TblDim
				EXEC(@SMSBasedOn)
			end
			else 
			begin
				set @IsSMSBasedOnField=1				
				if(@IsInventory=1)
					set @SMSBasedOn='select distinct '+@SMSBasedOn+',2 FROM INV_DocDetails D with(nolock) inner join com_DocTextData txt with(nolock) on txt.invdocdetailsID=D.invdocdetailsID'
				else
					set @SMSBasedOn='select distinct '+@SMSBasedOn+',2 FROM ACC_DocDetails D with(nolock) inner join com_DocTextData txt with(nolock) on txt.accdocdetailsID=D.accdocdetailsID'
				 set @SMSBasedOn=@SMSBasedOn+' where D.CostCenterID='+convert(nvarchar,@CostCenterID)+' and D.DocID='+convert(nvarchar,@NodeID)
				 
				INSERT INTO @TblField
				EXEC(@SMSBasedOn)
			end
		end
	end
	else
	begin
		select @EmailBasedOn=Value FROM COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID AND Name='EmailBasedOn'
		if @EmailBasedOn IS NOT NULL AND @EmailBasedOn!=''
		begin			
			if @EmailBasedOn like 'CCNID%'
			begin
				set @IsEmailBasedOnDim=1
				set @EmailBasedOn='select distinct '+@EmailBasedOn+',0 FROM COM_CCCCData with(nolock)
				where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+convert(nvarchar,@NodeID)
				INSERT INTO @TblDim
				EXEC(@EmailBasedOn)
			end
			else if @EmailBasedOn='AccountTypeID'
			begin
				set @IsEmailBasedOnDim=1
				INSERT INTO @TblDim
				select AccountTypeID,0 from ACC_Accounts with(nolock) where AccountID=@NodeID
			end
			else if @EmailBasedOn='ProductTypeID'
			begin
				set @IsEmailBasedOnDim=1
				INSERT INTO @TblDim
				select ProductTypeID,0 from INV_Product with(nolock) where ProductID=@NodeID
			end
			else			
			begin
				set @IsEmailBasedOnField=1				
				if @CostCenterID=2
					set @EmailBasedOn='select '+@EmailBasedOn+',0 FROM ACC_Accounts A with(nolock)
					inner join ACC_AccountsExtended E with(nolock) on A.AccountID=E.AccountID'
				else if @CostCenterID=3
					set @EmailBasedOn='select '+@EmailBasedOn+',0 FROM INV_Product A with(nolock)
					inner join INV_ProductExtended E with(nolock) on A.ProductID=E.ProductID'
				else if @CostCenterID>50000
					set @EmailBasedOn='select '+@EmailBasedOn+',0 FROM '+(select TableName from adm_features with(nolock) where FeatureID=2)+' with(nolock)'
				 
				INSERT INTO @TblField
				EXEC(@EmailBasedOn)
			end
		end
		set @IsSMSBasedOnDim=@IsEmailBasedOnDim
		set @IsSMSBasedOnField=@IsEmailBasedOnField
	end
	
	--EMAIL
	IF (SELECT COUNT(*) FROM ADM_GlobalPreferences WITH(nolock) WHERE Name='EnableEmail' AND Value='Yes')>0
	BEGIN

		insert into @TblTemplates
		SELECT distinct N.TemplateID,newid(),IsApproveButton
		FROM COM_NotifTemplate N WITH(NOLOCK)
		INNER JOIN COM_NotifTemplateAction NA WITH(NOLOCK) ON NA.TemplateID=N.TemplateID AND NA.ActionID=@ActionType
		WHERE N.TemplateType=1 AND CostCenterID=@CostCenterID AND StatusID=383
		AND N.TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)
			WHERE UserID=@UserID OR RoleID=@RoleID OR GroupID IN (select GID from COM_Groups WITH(nolock) where UserID=@UserID or RoleID=@RoleID))
		AND (@IsEmailBasedOnDim=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblDim T ON T.ID=A.BasedOnDimension and (T.NotifType=0 or T.NotifType=1)))
		AND (@IsEmailBasedOnField=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblField T ON T.TXT=A.BasedOnField and (T.NotifType=0 or T.NotifType=1)))
		

		IF @CompanyGUID='DELETE_EMAIL'
		BEGIN
			SELECT N.*
			FROM COM_NotifTemplate N WITH(NOLOCK)
			JOIN @TblTemplates T on T.ID=N.TemplateID
		END
		ELSE
		BEGIN
		select 1
			INSERT INTO COM_SchEvents(CostCenterID,NodeID,WorkflowID,WorkflowLevel,TemplateID,StatusID,EventTime,ScheduleID,StartFlag,StartDate,EndDate,CompanyGUID,GUID,CreatedBy,CreatedDate,SUBCostCenterID,SUBNodeID)
			SELECT @CostCenterID,@NodeID,@WorkflowID,@WorkflowLevel,N.TemplateID,1,@Dt,0,0,@Dt,@Dt,@CompanyGUID,T.GUID,@UserName,@Dt,@SUBCostCenterID,@SUBNodeID
			FROM COM_NotifTemplate N WITH(NOLOCK)
			JOIN @TblTemplates T on T.ID=N.TemplateID
			
			if @CostCenterID>40000 and @CostCenterID<50000
			begin
				if @IsInventory=1
					select @WID=max(WorkFlowID) from INV_DocDetails with(nolock) where CostCenterID=@CostCenterID and DocID=@NodeID and WorkFlowID>0 
				else
					select @WID=max(WorkFlowID) from ACC_DocDetails with(nolock) where CostCenterID=@CostCenterID and DocID=@NodeID and WorkFlowID>0 

				if @WID>0
					insert into COM_EmailApproval(GUID,StatusID,CostCenterID,DocID,WID,CreatedDate,UserID,UserName,RoleID)
					select GUID,1,@CostCenterID,@NodeID,@WID,@Dt,@UserID,@UserName,@RoleID from @TblTemplates
					where IsApproveButton=1
						
				/*if @IsInventory=1
					select @WID=max(WorkFlowID),@WLevel=max(WorkFlowLevel) from INV_DocDetails with(nolock)
					where CostCenterID=@CostCenterID and DocID=@NodeID and WorkFlowID>0 
				else
					select @WID=max(WorkFlowID),@WLevel=max(WorkFlowLevel) from ACC_DocDetails with(nolock)
					where CostCenterID=@CostCenterID and DocID=@NodeID and WorkFlowID>0 
				
				if @WID>0 and exists (select top 1 * from @TblTemplates where IsApproveButton=1)
				begin
					if exists (select IsLineWise from COM_WorkFlowDef with(nolock) where @WID=WorkFlowDefID and IsLineWise=1)
					begin
						if @IsInventory=1
							insert into COM_EmailApproval(GUID,StatusID,CostCenterID,DocID,DocDetailsID,WID,WLevel,CreatedDate)
							select T.GUID,1,@CostCenterID,@NodeID,InvDocDetailsID,@WID,WorkFlowLevel,@Dt 
							from INV_DocDetails D with(nolock),@TblTemplates T
							where D.CostCenterID=@CostCenterID and D.DocID=@NodeID and WorkFlowLevel=@WLevel and T.IsApproveButton=1
						else
							select T.GUID,1,@CostCenterID,@NodeID,InvDocDetailsID,@WID,WorkFlowLevel,@Dt 
							from ACC_DocDetails D with(nolock),@TblTemplates T
							where D.CostCenterID=@CostCenterID and D.DocID=@NodeID and WorkFlowLevel=@WLevel and T.IsApproveButton=1
					end
					else
					begin
						insert into COM_EmailApproval(GUID,StatusID,CostCenterID,DocID,DocDetailsID,WID,WLevel,CreatedDate)
						select GUID,1,@CostCenterID,@NodeID,0,@WID,@WLevel,@Dt from @TblTemplates
						where IsApproveButton=1
					end
				end*/
			end
		END
	END
		
	--SMS
	IF (SELECT COUNT(*) FROM ADM_GlobalPreferences WITH(nolock) WHERE Name='EnableSMS' AND Value='Yes')>0
	BEGIN
		IF @CompanyGUID='DELETE_EMAIL'
		BEGIN
			SELECT N.*
			FROM COM_NotifTemplate N WITH(NOLOCK)
			INNER JOIN COM_NotifTemplateAction NA WITH(NOLOCK) ON NA.TemplateID=N.TemplateID AND NA.ActionID=@ActionType
			WHERE N.TemplateType=2 AND CostCenterID=@CostCenterID AND StatusID=383
			AND N.TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)
				WHERE UserID=@UserID OR RoleID=@RoleID OR GroupID IN (select GID from COM_Groups WITH(nolock) where UserID=@UserID or RoleID=@RoleID))
			AND (@IsSMSBasedOnDim=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblDim T ON T.ID=A.BasedOnDimension and (T.NotifType=0 or T.NotifType=2)))
			AND (@IsSMSBasedOnField=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblField T ON T.TXT=A.BasedOnField and (T.NotifType=0 or T.NotifType=2)))

		END
		ELSE
		BEGIN
			INSERT INTO COM_SchEvents(CostCenterID,NodeID,WorkflowID,WorkflowLevel,TemplateID,StatusID,EventTime,ScheduleID,StartFlag,StartDate,EndDate,CompanyGUID,GUID,CreatedBy,CreatedDate,SUBCostCenterID,SUBNodeID)
			SELECT @CostCenterID,@NodeID,@WorkflowID,@WorkflowLevel,N.TemplateID,1,@Dt,0,0,@Dt,@Dt,@CompanyGUID,@NotifGUID,@UserName,@Dt,@SUBCostCenterID,@SUBNodeID
			FROM COM_NotifTemplate N WITH(NOLOCK)
			INNER JOIN COM_NotifTemplateAction NA WITH(NOLOCK) ON NA.TemplateID=N.TemplateID AND NA.ActionID=@ActionType
			WHERE N.TemplateType=2 AND CostCenterID=@CostCenterID AND StatusID=383
			AND N.TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)
				WHERE UserID=@UserID OR RoleID=@RoleID OR GroupID IN (select GID from COM_Groups WITH(nolock) where UserID=@UserID or RoleID=@RoleID))
			AND (@IsSMSBasedOnDim=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblDim T ON T.ID=A.BasedOnDimension and (T.NotifType=0 or T.NotifType=2)))
			AND (@IsSMSBasedOnField=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblField T ON T.TXT=A.BasedOnField and (T.NotifType=0 or T.NotifType=2)))
		END
	END

	--Push Notifications
	IF (SELECT COUNT(*) FROM ADM_GlobalPreferences WITH(nolock) WHERE Name='EnablePushNotifications' AND Value='Yes')>0
	BEGIN
		IF @CompanyGUID='DELETE_EMAIL'
		BEGIN
			SELECT N.*
			FROM COM_NotifTemplate N WITH(NOLOCK)
			INNER JOIN COM_NotifTemplateAction NA WITH(NOLOCK) ON NA.TemplateID=N.TemplateID AND NA.ActionID=@ActionType
			WHERE N.TemplateType=3 AND CostCenterID=@CostCenterID AND StatusID=383
			AND N.TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)
				WHERE UserID=@UserID OR RoleID=@RoleID OR GroupID IN (select GID from COM_Groups WITH(nolock) where UserID=@UserID or RoleID=@RoleID))
			AND (@IsSMSBasedOnDim=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblDim T ON T.ID=A.BasedOnDimension and (T.NotifType=0 or T.NotifType=3)))
			AND (@IsSMSBasedOnField=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblField T ON T.TXT=A.BasedOnField and (T.NotifType=0 or T.NotifType=3)))

		END
		ELSE
		BEGIN

			IF @WorkflowLevel IS NOT NULL
			BEGIN
				UPDATE COM_SchEvents SET StatusID = 3 WHERE COSTCENTERID = @CostCenterID AND NodeID = @NodeID AND WorkflowID = @WorkflowID AND WorkflowLevel < @WorkflowLevel AND StatusID = 1
			END

			INSERT INTO COM_SchEvents(CostCenterID,NodeID,WorkflowID,WorkflowLevel,TemplateID,StatusID,EventTime,ScheduleID,StartFlag,StartDate,EndDate,CompanyGUID,GUID,CreatedBy,CreatedDate,SUBCostCenterID,SUBNodeID)
			SELECT @CostCenterID,@NodeID,@WorkflowID,@WorkflowLevel,N.TemplateID,1,@Dt,0,0,@Dt,@Dt,@CompanyGUID,@NotifGUID,@UserName,@Dt,@SUBCostCenterID,@SUBNodeID
			FROM COM_NotifTemplate N WITH(NOLOCK)
			INNER JOIN COM_NotifTemplateAction NA WITH(NOLOCK) ON NA.TemplateID=N.TemplateID AND NA.ActionID=@ActionType
			WHERE N.TemplateType=3 AND CostCenterID=@CostCenterID AND StatusID=383
			AND N.TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)
				WHERE UserID=@UserID OR RoleID=@RoleID OR GroupID IN (select GID from COM_Groups WITH(nolock) where UserID=@UserID or RoleID=@RoleID))
			AND (@IsSMSBasedOnDim=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblDim T ON T.ID=A.BasedOnDimension and (T.NotifType=0 or T.NotifType=3)))
			AND (@IsSMSBasedOnField=0 OR N.IgnoreBasedOn=1 OR N.TemplateID IN (select NotificationID from COM_NotifTemplateUserMap A with(nolock) inner join @TblField T ON T.TXT=A.BasedOnField and (T.NotifType=0 or T.NotifType=3)))
		END
	END
END

GO
