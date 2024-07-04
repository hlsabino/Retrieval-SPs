USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetAccountDetails]
	@AccountID [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit,@PayHasAccess bit,@RecHasAccess bit

		--SP Required Parameters Check
		IF (@AccountID < 1 and @AccountID>-10000)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,2)
		SET @PayHasAccess=dbo.fnCOM_HasAccess(@RoleID,2,218)
		SET @RecHasAccess=dbo.fnCOM_HasAccess(@RoleID,2,219)

		IF @HasAccess=0 and @PayHasAccess=0 and @RecHasAccess=0
		BEGIN
			
			RAISERROR('-105',16,1)
		END

		--Getting data from Accounts main table
		SELECT * FROM ACC_Accounts WITH(NOLOCK) 	
		WHERE AccountID=@AccountID
		
		--Getting data from Accounts extended table
		SELECT * FROM  ACC_AccountsExtended WITH(NOLOCK) 
		WHERE AccountID=@AccountID

		--Getting Contacts
		EXEC [spCom_GetFeatureWiseContacts] 2,@AccountID,2,1,1
		  
		--Getting Notes
		SELECT     NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate, 
		ModifiedBy, convert(datetime,ModifiedDate) as  ModifiedDate, CostCenterID
		FROM         COM_Notes WITH(NOLOCK) 
		WHERE FeatureID=2 and  FeaturePK=@AccountID

		--Getting Files
		EXEC [spCOM_GetAttachments] 2,@AccountID,@UserID

		--Getting CostCenterMap
		SELECT * FROM COM_CCCCDATA WITH(NOLOCK) 
		WHERE NodeID = @AccountID AND CostCenterID  = 2 

		--Getting Schemes
		SELECT 1 SchemesTableDeleted where 1!=1

		--Getting ADDRESS 
		EXEC spCom_GetAddress 2,@AccountID,1,1
		--Getting Contacts
		
		EXEC [spCom_GetFeatureWiseContacts] 2,@AccountID,1,1,1

		EXEC [spCOM_GetCCCCMapDetails] 2,@AccountID,@LangID
		 
		select AccountCode,AccountName from Acc_Accounts with(nolock) where 
		AccountID in (select ParentID from Acc_Accounts with(nolock) where AccountID=@AccountID)
		
		DECLARE @CDSQL NVARCHAR(MAX),@CID INT
		SELECT @CID=ISNULL(CONVERT(INT,[Value]),0) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE [Name]='DimWiseCreditDebit'
		
		--TO GET Credit & Debit TAB Details by Khaja
		SET @CDSQL='SELECT CDA.*,L.Name Location,D.Name Division,CDA.CurrencyID,c.Name Currency'
		if (@CID>0)
			SET @CDSQL=@CDSQL+',CC.Name Dimension'	
		SET @CDSQL=@CDSQL+' FROM Acc_CreditDebitAmount CDA WITH(NOLOCK)
		LEFT JOIN COM_Location L WITH(NOLOCK) ON CDA.LocationID=L.NodeID
		LEFT JOIN COM_Currency c WITH(NOLOCK) ON CDA.CurrencyID=c.CurrencyID
		LEFT JOIN COM_Division D WITH(NOLOCK) ON CDA.DivisionID=D.NodeID'
		if (@CID>0)
			SET @CDSQL=@CDSQL+' LEFT JOIN '+(SELECT TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CID)+' CC WITH(NOLOCK) ON CDA.DimensionID=CC.NodeID'
		SET @CDSQL=@CDSQL+' WHERE AccountID ='+CONVERT(VARCHAR,@AccountID)
		--print(@CDSQL)
		EXEC (@CDSQL)
		 
		 --CCmap display data 
		CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),COSTCENTERID INT,NODEID INT)
		CREATE TABLE #TBLTEMP1 (CostCenterId INT,CostCenterName nvarchar(max),NodeID INT,[Value] NVARCHAR(300),Code nvarchar(300)) 
		INSERT INTO #TBLTEMP
		SELECT CostCenterID,NODEID  FROM COM_CostCenterCostCenterMap with(nolock) WHERE ParentCostCenterID=2 AND ParentNodeID=@AccountID
		DECLARE @COUNT INT,@I INT,@TABLENAME NVARCHAR(300),@SQL NVARCHAR(MAX),@CCID INT,@NODEID INT,@FEATURENAME NVARCHAR(300), @IsGroup bit
		SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP with(nolock)
		WHILE @I<=@COUNT
		BEGIN
			SELECT @NODEID=NODEID,@CCID=CostCenterId FROM #TBLTEMP with(nolock) WHERE ID=@I
			SELECT @FEATURENAME=NAME,@TABLENAME=TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID =@CCID 
			--IF @CCID>50000
			if(@CCID=7)
				SET @SQL='if exists (select UserID FROM '+@TABLENAME +' with(nolock) 
				    WHERE UserID='+CONVERT(VARCHAR,@NODEID) +')
					INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',UserID NODEID,UserName NAME, UserName FROM '+@TABLENAME +' with(nolock) 
					WHERE UserID='+CONVERT(VARCHAR,@NODEID) +'' 
			else 
				SET @SQL='if exists (select NodeID FROM '+@TABLENAME +' with(nolock) 
					WHERE NODEID='+CONVERT(VARCHAR,@NODEID) +' and IsGroup=0)
					INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +' with(nolock) 
					WHERE NODEID='+CONVERT(VARCHAR,@NODEID) +'
					else
					INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +' with(nolock) 
					WHERE ParentID='+CONVERT(VARCHAR,@NODEID)  
			print(@SQL)
			EXEC (@SQL)
			SET @I=@I+1
		END
		
		SELECT * FROM #TBLTEMP1 with(nolock)
		DROP TABLE #TBLTEMP1
		DROP TABLE #TBLTEMP 
		
		 
		--WorkFlow
		EXEC spCOM_CheckCostCentetWFApprove 2,@AccountID,@UserID,@RoleID
		
		declare @rptid INT, @tempsql nvarchar(500)
		select @rptid=CONVERT(INT,value) from ADM_GlobalPreferences WITH(NOLOCK) where Name='Report Template Dimension'
		if(@rptid>0)
		begin
			set @tempsql= 'select NodeID, Name, Code from '+(select tablename from ADM_Features with(nolock)  where FeatureID=@rptid)+'  with(nolock)' 
			exec (@tempsql) 
			
			select TemplateNodeID , [AccountID],[DrNodeID],[CrNodeID],[CreatedBy],[CreatedDate],
			CONVERT(datetime, RTDate) AS [RTDate],isnull(RTGroup,'') RTGroup
			from ACC_ReportTemplate with(nolock)
			where AccountID=@AccountID
			order by RTGroup,RTDate
		
			select a.accountid, a.accountcode, a.accountname,a.depth, a.lft, a.rgt, a.parentid, r.templatenodeid   
			from ACC_Accounts a with(nolock)
			left join  ACC_ReportTemplate r with(nolock) on r.accountid=a.accountid
			where a.IsGroup=1 
			order by lft
		end
		else
		begin
			select 1 'NoRT1' where 1!=1 
			select 1 'NoRT2' where 1!=1 
			select 1 'NoRT3' where 1!=1 
		end
		
		--History Details
		select H.HistoryID,H.HistoryCCID CCID,H.HistoryNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,H.Remarks
		from COM_HistoryDetails H with(nolock) 
		where H.CostCenterID=2 and H.NodeID=@AccountID and H.HistoryCCID>0
		order by FromDate,H.HistoryID
		
		--Status Details
		select StatusMapID,CostCenterID,[Status],convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate
		from [COM_CostCenterStatusMap] with(nolock)
		where CostCenterID=2 and NodeID=@AccountID
		order by FromDate,ToDate


		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM ACC_Accounts WITH(NOLOCK) where AccountID=@AccountID
		
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
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=2 AND CCNodeID=@AccountID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		
		end 
     

SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
