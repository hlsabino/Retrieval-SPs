USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCostCenterDetails]
	@CostCenterID [int] = 0,
	@NodeID [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1,
	@CallType [int] = NULL,
	@AssignedDim [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  
	--Declaration Section  
	DECLARE @HasAccess BIT,@Table nvarchar(50),@SQL nvarchar(max)   

	IF(@CallType=1)  
	BEGIN
		SELECT a.*,b.GroupName as RibbonGroupName,b.TabID as RibbonTabID,FeatureActionID FROM ADM_FEATURES a with(nolock) 
		LEFT JOIN ADM_RibbonView b WITH(NOLOCK) on b.FeatureID=a.FeatureID
		WHERE a.FEATUREID>=50000

		select * from COM_Files WITH(NOLOCK)  WHERE FEATUREID>=50000 and FeaturePK = -500

	END 	  
	ELSE IF(@CallType=2)  
	BEGIN
		IF @AssignedDim=0
			SELECT @SQL='SELECT CC.ParentCostCenterID CCID,'''+max(F.Name)+''' DimName,D.NodeID,D.Name Value 
			from COM_CostCenterCostCenterMap CC with(nolock) 
			INNER JOIN '+F.TableName+' D with(nolock) ON D.NodeID=ParentNodeID
			WHERE CC.CostCenterID='+CONVERT(nvarchar,@CostCenterId)+' AND CC.NodeID='+CONVERT(nvarchar,@NodeID)+' AND CC.ParentCostCenterID='+CONVERT(nvarchar,cc.ParentCostCenterID)
			FROM COM_CostCenterCostCenterMap CC with(nolock) 
			INNER JOIN ADM_Features F with(nolock) ON CC.ParentCostCenterID=F.FeatureID
			WHERE CC.CostCenterID=@CostCenterId AND CC.NodeID=@NodeID
			GROUP BY CC.ParentCostCenterID,F.TableName
		ELSE
			SELECT @SQL='SELECT CC.ParentCostCenterID CCID,'''+max(F.Name)+''' DimName,D.NodeID,D.Name Value 
			from COM_CostCenterCostCenterMap CC with(nolock) 
			INNER JOIN '+F.TableName+' D with(nolock) ON D.NodeID=ParentNodeID
			WHERE CC.CostCenterID='+CONVERT(nvarchar,@CostCenterId)+' AND CC.NodeID='+CONVERT(nvarchar,@NodeID)+' AND CC.ParentCostCenterID='+CONVERT(nvarchar,cc.ParentCostCenterID)
			FROM COM_CostCenterCostCenterMap CC with(nolock) 
			INNER JOIN ADM_Features F with(nolock) ON CC.ParentCostCenterID=F.FeatureID
			WHERE CC.CostCenterID=@CostCenterId AND CC.NodeID=@NodeID AND CC.ParentCostCenterID=@AssignedDim
			GROUP BY CC.ParentCostCenterID,F.TableName 
		exec sp_executesql @SQL
	END
	ELSE  
	BEGIN  
  
		--SP Required Parameters Check  
		IF @CostCenterID=0 --OR @NodeID=0  
		BEGIN  
			RAISERROR('-100',16,1)  
		END  
  
		--User access check   
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)  

		IF @HasAccess=0  
		BEGIN  
		RAISERROR('-105',16,1)  
		END  

		--To get costcenter table name  
		SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId  
		if(@CostCenterID=94)
			SET @SQL='SELECT * FROM '+@Table+' WITH(nolock) WHERE TenantID='+convert(nvarchar,@NodeID)    
		else
			SET @SQL='SELECT * FROM '+@Table+' WITH(nolock) WHERE NodeID='+convert(nvarchar,@NodeID)    
		exec sp_executesql @SQL

		--Getting Contacts    
		EXEC [spCom_GetFeatureWiseContacts] @CostCenterID,@NodeID,2,1,1 

		--Getting Notes  
		SELECT NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate, 
			ModifiedBy, ModifiedDate, CostCenterID,Progress FROM  COM_Notes WITH(NOLOCK)   
		WHERE FeatureID=@CostCenterID and  FeaturePK=@NodeID  

		--Getting Files  
		EXEC [spCOM_GetAttachments] @CostCenterID,@NodeID,@UserID

		--Getting Contacts  
		EXEC [spCom_GetFeatureWiseContacts] @CostCenterID,@NodeID,1,1,1

		--Getting Custom CostCenter Extra fields  
		--   SELECT * FROM COM_CCCCData WHERE CostCenterID=@CostCenterId AND NODEID=@NodeID  
		EXEC [spCOM_GetCCCCMapDetails] @CostCenterId,@NodeID,@LangID
		
		--Getting ADDRESS 
		EXEC spCom_GetAddress @CostCenterId,@NodeID,1,1

		SELECT * FROM COM_CCCCData WITH(NOLOCK)
		WHERE CostCenterID=@CostCenterId AND NODEID=@NodeID  

		if(@CostCenterId=94)
		begin
			set @SQL='select TenantCode Code,FirstName Name from '+@Table+' WITH(nolock) WHERE TenantID in 
			(select ParentID from '+@Table+' with(nolock) where TenantID= '+convert(nvarchar,@NodeID)+')'
		end
		else
		begin
			set @SQL='select Code,Name from '+@Table+' WITH(nolock) WHERE NodeID in 
			(select ParentID from '+@Table+' with(nolock) where NodeID= '+convert(nvarchar,@NodeID)+')'
		end
		exec sp_executesql @SQL
		 
		SELECT ConvertedCRMProduct FROM INV_PRODUCT WITH(nolock) WHERE ConvertedCRMProduct=@NodeID

		 --CCmap display data 
		CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),COSTCENTERID INT,NODEID INT)
		CREATE TABLE #TBLTEMP1 (CostCenterId INT,CostCenterName nvarchar(max),NodeID INT,[Value] NVARCHAR(300), Code nvarchar(300))
		INSERT INTO #TBLTEMP
		SELECT CostCenterID,NODEID  FROM COM_CostCenterCostCenterMap with(nolock) WHERE ParentCostCenterID=@CostCenterId AND ParentNodeID=@NodeID
		DECLARE @COUNT INT,@I INT,@TABLENAME NVARCHAR(300), @CCID INT,@ccNODEID INT,@FEATURENAME NVARCHAR(300), @IsGroup bit
		SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP
		WHILE @I<=@COUNT
		BEGIN
			SELECT @ccNODEID=NODEID,@CCID=COSTCENTERID FROM #TBLTEMP WHERE ID=@I
			SELECT @FEATURENAME=NAME,@TABLENAME=TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID =@CCID
			 
			IF @CCID=7
			BEGIN
				SET @SQL='INSERT INTO #TBLTEMP1 
				SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',UserID,UserName,UserName FROM '+@TABLENAME +'  with(nolock)
						WHERE UserID='+CONVERT(VARCHAR,@ccNODEID) 
			END
			ELSE IF @CCID=6
			BEGIN
				SET @SQL='INSERT INTO #TBLTEMP1 
				SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',RoleID,Name,Name FROM '+@TABLENAME +'  with(nolock)
						WHERE RoleID='+CONVERT(VARCHAR,@ccNODEID) 
			END
			ELSE IF @CCID=8
			BEGIN
				SET @SQL='INSERT INTO #TBLTEMP1 SELECT Top 1 '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',CostCenterID NODEID,CostCenterName NAME,CostCenterName Code FROM '+@TABLENAME +'  with(nolock)
						WHERE CostCenterID='+CONVERT(VARCHAR,@ccNODEID) 
			END
			ELSE IF @CCID=300
			BEGIN
				SET @SQL='INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',CostCenterID NODEID,DOCUMENTNAME NAME,DOCUMENTABBR Code FROM '+@TABLENAME +'  with(nolock)
						WHERE CostCenterID='+CONVERT(VARCHAR,@ccNODEID) 
			END
			ELSE
			BEGIN
				SET @SQL='if exists (select NodeID FROM '+@TABLENAME +' 
					 WHERE NODEID='+CONVERT(VARCHAR,@ccNODEID) +' and IsGroup=0)
						INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +'  with(nolock)
						WHERE NODEID='+CONVERT(VARCHAR,@ccNODEID) +'
					 else
						INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +'  with(nolock)
						WHERE ParentID='+CONVERT(VARCHAR,@ccNODEID) 
			END
			exec sp_executesql @SQL
			SET @I=@I+1
		END

		SELECT * FROM #TBLTEMP1
		DROP TABLE #TBLTEMP1
		DROP TABLE #TBLTEMP
		
		--WorkFlow
		EXEC spCOM_CheckCostCentetWFApprove @CostCenterID,@NodeID,@UserID,@RoleID

		if exists(select isnull(value,0) from COM_CostCenterPreferences with(nolock) 
		where CostCenterID=76 and Name='JobDimension' and ISNUMERIC(value)=1 and Value=@CostCenterID)
		BEGIN
			declare @StageDim nvarchar(max),@dim nvarchar(max)
			select @StageDim=Value from COM_CostCenterPreferences with(nolock) where Name='StageDimension' 
			set @dim=''
			select @dim=TableName from COM_CostCenterPreferences a with(nolock) 
			join ADM_Features f  with(nolock) on a.Value=f.FeatureID
			where a.Name='JobFilterDim' and isnumeric(a.Value)=1 and convert(INT,a.Value)>50000

			if(LEN(@StageDim)>0 and ISNUMERIC(@StageDim)=1 and convert(int,@StageDim)>50000)
			begin
				select @StageDim=TableName from ADM_Features with(nolock) where FeatureID=convert(int,@StageDim)
			
				SET @SQL='select st.name,st.NodeID, j.BomID, bom.BOMName,j.ProductID,p.ProductName,j.IsBom,
				j.Qty, isnull(J.UOMID,1) UOMID, u.UnitName,J.StatusID,j.DimID,Remarks'
				if(@dim<>'')
					SET @SQL=@SQL+',Dt.Name DimName '
				SET @SQL=@SQL+' from PRD_JobOuputProducts j with(nolock)
				left join PRD_BillOfMaterial bom with(nolock) on j.BomID=bom.BOMID
				join INV_Product p with(nolock) on j.ProductID=p.ProductID			
				left join COM_UOM u with(nolock) on isnull(j.UOMID,1)=u.UOMID				
				left join PRD_BOMStages bs with(nolock) on bs.StageID=J.StageID
				left join '+@StageDim+' st with(nolock) on bs.StageNodeID=st.NodeID '
				
				if(@dim<>'')
					SET @SQL=@SQL+' left join '+@dim+' dt with(nolock) on j.DimID=dt.NodeID '
					
				SET @SQL=@SQL+' where j.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+ 'and j.NodeID='++CONVERT(NVARCHAR,@NodeID)
				exec sp_executesql @SQL
			END
			ELSE
			BEGIN
				select j.BomID, bom.BOMName,j.ProductID,p.ProductName,j.IsBom,
				j.Qty, isnull(J.UOMID,1) UOMID, u.UnitName,j.StatusID,Remarks
				from PRD_JobOuputProducts j with(nolock)
				left join PRD_BillOfMaterial bom with(nolock) on j.BomID=bom.BOMID
				join INV_Product p with(nolock) on j.ProductID=p.ProductID			
				left join COM_UOM u with(nolock) on isnull(j.UOMID,1)=u.UOMID			
				where j.CostCenterID=@CostCenterID and j.NodeID=@NodeID
			END
		END
		ELSE
			SELECT 1 'BomID' where 1!=1
			
		declare @rptid INT, @tempsql nvarchar(500)
		select @rptid=CONVERT(INT,value) from ADM_GlobalPreferences with(nolock) where Name='Report Template Dimension'
		if(@rptid=@CostCenterID)
			select * from ACC_ReportTemplate with(nolock) where drnodeid =@NodeID or crnodeid=@NodeID or templatenodeid =@NodeID
		else
			select '' ACC_ReportTemplate where 1!=1
			
		--History Details
		select H.HistoryID,H.HistoryCCID CCID,H.HistoryNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,H.Remarks
		from COM_HistoryDetails H with(nolock) 
		where H.CostCenterID=@CostCenterID and H.NodeID=@NodeID and (H.HistoryCCID>50000 or H.HistoryCCID in(2,3))
		order by FromDate,H.HistoryID	
	
		--Status Details
		select StatusMapID,CostCenterID,[Status],convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate
		from [COM_CostCenterStatusMap] with(nolock)
		where CostCenterID=@CostCenterID and NodeID=@NodeID
		order by FromDate,ToDate

		----16,17 -- GETTING WORKFLOWS
		 --if(@CostCenterID>50000 AND @CostCenterID<=50008)
		 if(@CostCenterID>50000)
		 BEGIN
		 declare @TableName1 varchar(200)
		select @TableName1 = TableName from ADM_Features  WITH(NOLOCK) where FeatureID=@CostCenterID
		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		declare @sqlSelect nvarchar(max)		
		
		--SELECT @StatusID=StatusID,@WID=WFID,@Level=WFLevel,@CreatedDate=CONVERT(datetime,createdDate)
		--FROM COM_Division WITH(NOLOCK) where  NodeId=@NodeID

		

		set @sqlSelect=' SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM  '+@TableName1+' WITH(NOLOCK) where  NodeId='+ convert(nvarchar,@NodeID) +' '
			print (@sqlSelect)
				EXEC sp_executesql @sqlSelect,N'@StatusID int output,@WID int output,@Level int output,@CreatedDate datetime output',@StatusID output, @WID output,@Level output,@CreatedDate  output
		 --exec(@sqlSelect)
		
		if(@WID is not null and @WID>0)  
		BEGIN  
			SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and  UserID =@UserID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID

			if(@Userlevel is null )       
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID
			
			if(@Userlevel is null )  	
				SELECT @Type=[type] FROM [COM_WorkFlow] WITH(NOLOCK) where WorkFlowID=@WID
		end 
     
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
			else  
				set @canApprove= 0   
		end  
		else  
			set @canApprove= 0   

		IF @WID is not null and @WID>0
		begin
				
			
			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=@CostCenterID AND CCNodeID=@NodeID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName

			select @canEdit canEdit,@canApprove canApprove
		end

	ELSE

		BEGIN
		  
			select 1 WF where 1!=1
			select 1 WFL where 1!=1
			 select 0 canEdit,0 canApprove
		END
		 END
		 ELSE
		 BEGIN
			 select 1 WF where 1!=1
			 select 1 WFL where 1!=1
			 select 0 canEdit,0 canApprove
		 END


		
		--DECLARE @WID INT
		--SELECT @WID= WorkflowID From COM_CCWorkFlow WITH(NOLOCK) where CostCenterID=@CostCenterID and NodeID=@NodeID
		--IF(@WID is not null and @WID>0)
		--BEGIN
		--	SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
		--	(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
		--	A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
		--	FROM COM_CCWorkFlow A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
		--	WHERE S.StatusID=A.StatusID AND A.CostCenterID=@CostCenterID AND A.NodeID=@NodeID AND A.USERID=U.USERID
		--	ORDER BY A.CreatedDate
			
		--	select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
		--	where WorkFlowID=@WID
		--	group by levelID,LevelName	
		--END
		--ELSE
		--BEGIN
		--	select 1 WF where 1!=1
		--	select 1 WFL where 1!=1
		--END

	END  
  
SET NOCOUNT OFF;  
RETURN 1  
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
SET NOCOUNT OFF    
RETURN -999     
END CATCH



GO
