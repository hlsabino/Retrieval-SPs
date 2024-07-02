USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetBOMDetails]
	@BOMID [int] = 0,
	@UserID [int],
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		SELECT *,convert(datetime,BOMDate) as 'Date' 
		FROM PRD_BillOfMaterial WITH(NOLOCK) 	
		WHERE BOMID=@BOMID

		SELECT BP.*,P.ProductName,P.ProductCOde,U.BaseName, U.UnitName UOM,P.StatusID
		FROM  [PRD_BOMProducts] BP with(nolock) 
		join INV_Product P with(nolock) on BP.ProductID=P.ProductID
		left join COM_UOM U WITH(NOLOCK) on BP.UOMID=U.UOMID
		WHERE BP.BOMID=@BOMID and BP.ProductUse=1 
		
		SELECT BE.*,c.AccountName CRAccountName,d.AccountName DRAccountName 
		FROM  [PRD_Expenses] BE with(nolock)
		left join Acc_Accounts c WITH(NOLOCK) on BE.CreditAccountID=c.AccountID	
		left join Acc_Accounts d WITH(NOLOCK) on BE.DebitAccountID=d.AccountID	
		WHERE BE.BOMID=@BOMID
		
		--SELECT BR.*,M.ResourceName,M.CreditAccount,M.DebitAccount
		--FROM  [PRD_BOMResources] BR  with(nolock)
		--join PRD_Resources M WITH(NOLOCK) on BR.ResourceID=M.ResourceID				
		--WHERE BR.BOMID=@BOMID		
		declare @MachineDim nvarchar(max)
		select @MachineDim=Value from COM_CostCenterPreferences with(nolock) where Name='MachineDimension'
		if(LEN(@MachineDim)>0 and ISNUMERIC(@MachineDim)=1 and convert(int,@MachineDim)>50000)
		begin
			select @MachineDim=TableName from ADM_Features with(nolock) where FeatureID=convert(int,@MachineDim)
			set @MachineDim='SELECT BR.*,D.Name ResourceName,d.purchaseaccount DebitAccount,d.salesaccount CreditAccount
			FROM  [PRD_BOMResources] BR with(nolock)
			INNER JOIN '+@MachineDim+' D with(nolock) ON BR.ResourceID=D.NodeID
			WHERE BR.BOMID='+convert(nvarchar,@BOMID)			
			EXEC sp_executesql @MachineDim
		end
		else
		begin
			SELECT BR.*,'' ResourceName
			FROM  [PRD_BOMResources] BR  with(nolock)
			WHERE BR.BOMID=@BOMID
		end
		
		
		select * from PRD_BillOfMaterial with(nolock) where isgroup=1

		SELECT BP.*,P.ProductName ,U.BaseName,U.UnitName,P.ProductCode,P.StatusID,BS.lft 
		FROM  [PRD_BOMProducts] BP with(nolock)
		join INV_Product P WITH(NOLOCK) on BP.ProductID=P.ProductID 
		join PRD_BOMStages BS with(nolock) on BS.BOMID=BP.BOMID AND BS.StageID=BP.StageID 
		left join COM_UOM U WITH(NOLOCK) on BP.UOMID=U.UOMID
		WHERE BP.BOMID=@BOMID and BP.ProductUse=2

		--Getting data from BOM extended table
		SELECT * FROM  PRD_BillOfMaterialExtended WITH(NOLOCK) 
		WHERE BOMID=@BOMID
		
		SELECT * FROM COM_CCCCDATA  with(nolock)
		WHERE NodeID = @BOMID AND CostCenterID=76 

		select * from PRD_ProductionMethod with(nolock)
		where BOMID=@BOMID and MOID is null order by SequenceNo
		
		declare @StageDim nvarchar(max)
		select @StageDim=Value from COM_CostCenterPreferences with(nolock) where Name='StageDimension'
		if(LEN(@StageDim)>0 and ISNUMERIC(@StageDim)=1 and convert(int,@StageDim)>50000)
		begin
			select @StageDim=TableName from ADM_Features with(nolock) where FeatureID=convert(int,@StageDim)
			set @StageDim='SELECT S.*,D.Code,D.Name FROM PRD_BOMStages S with(nolock)
			INNER JOIN '+@StageDim+' D with(nolock) ON S.StageNodeID=D.NodeID
			WHERE BOMID='+convert(nvarchar,@BOMID)+' ORDER BY S.lft'
			print(@StageDim)
			EXEC sp_executesql @StageDim
		end
		else
		begin
			SELECT * FROM PRD_BOMStages with(nolock)
			WHERE BOMID=@BOMID
			ORDER BY lft
		end
		
		--WorkFlow
		EXEC spCOM_CheckCostCentetWFApprove 76,@BOMID,@UserID,@RoleID

	----11,12 -- GETTING WORKFLOWS
	--DECLARE @WID INT
	--IF(@BOMID>0)
	--BEGIN
	--	SELECT @WID= WorkflowID From COM_CCWorkFlow WITH(NOLOCK) where CostCenterID=76 and NodeID=@BOMID
	--	IF(@WID is not null and @WID>0)
	--	BEGIN
	--		SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
	--		(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
	--		A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
	--		FROM COM_CCWorkFlow A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
	--		WHERE S.StatusID=A.StatusID AND A.CostCenterID=76 AND A.NodeID=@BOMID AND A.USERID=U.USERID
	--		ORDER BY A.CreatedDate
			
	--		select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
	--		where WorkFlowID=@WID
	--		group by levelID,LevelName	
	--	END
	--	ELSE
	--	BEGIN
	--		select 1 WF where 1!=1
	--		select 1 WFL where 1!=1
	--	END
	--END
		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM PRD_BillOfMaterial WITH(NOLOCK) where BOMID=@BOMID
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
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=76
			AND CCNodeID=@BOMID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
		
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		
		end 
		else
		BEGIN
		select 1 WF where 1!=1
	    select 1 WFL where 1!=1
		END
	
	--Attachments -13
	EXEC [spCOM_GetAttachments] 76,@BOMID,@UserID

		
SET NOCOUNT OFF
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

SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
