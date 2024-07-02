USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetCustomerDetails]
	@CustomerID [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON


		 create table #tblUsers(username nvarchar(100))
		insert into #tblUsers
		exec [spADM_GetUserNamebyOwner] @UserID 
		
		--Declaration Section
		DECLARE @HasAccess bit

		--SP Required Parameters Check
		IF (@CustomerID < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END


		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,2)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		--Getting the main data from customers table
	    SELECT * FROM  CRM_Customer WITH(NOLOCK) 
		WHERE CustomerID=@CustomerID

		--Getting data from Customers extended table
		SELECT * FROM  CRM_CustomerExtended WITH(NOLOCK) 
		WHERE CustomerID=@CustomerID

		--Getting Contacts
		EXEC [spCom_GetFeatureWiseContacts] 83,@CustomerID,3,1,1

		--Getting Notes
		SELECT     NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate, 
		ModifiedBy, ModifiedDate, CostCenterID
		FROM         COM_Notes WITH(NOLOCK) 
		WHERE FeatureID=83 and  FeaturePK=@CustomerID
			
	 
		--Getting ADDRESS 
		EXEC spCom_GetAddress 83,@CustomerID,1,1

		--Getting Contacts
		EXEC [spCom_GetFeatureWiseContacts] 83,@CustomerID,1,1,1				 
		
		--Getting Files
		EXEC [spCOM_GetAttachments] 83,@CustomerID,@UserID

			--Getting CostCenterMap
		SELECT * FROM  COM_CCCCData WITH(NOLOCK) 
		WHERE NodeID=@CustomerID and CostCenterID=83

			
		IF(EXISTS(SELECT * FROM CRM_Activities WHERE CostCenterID=83 AND NodeID=@CustomerID))
			EXEC spCRM_GetFeatureByActvities @CustomerID,83,'',@UserID,@LangID  
		ELSE
			SELECT 1 WHERE 1<>1
				 
			select C.CaseID,C.CaseNumber,C.CustomerID,CC.CustomerName,C.ProductID,P.ProductName, CONVERT(datetime,C.CreatedDate) as CreatedDate,C.ParentID from crm_cases C
			left join crm_customer CC on CC.CustomerID = C.CustomerID
			left join INV_Product P on P.ProductID = C.ProductID
			where C.CustomerID=@CustomerID

		  	EXEC [spCOM_GetCCCCMapDetails] 83,@CustomerID,@LangID
		  	SELECT ConvertFromCustomerID FROM Acc_Accounts WITH(nolock) WHERE ConvertFromCustomerID=@CustomerID 		  	
		  	
		--CCmap display data 
		CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),COSTCENTERID INT,NODEID INT)
		CREATE TABLE #TBLTEMP1 (CostCenterId INT,CostCenterName nvarchar(max),NodeID INT,[Value] NVARCHAR(300),Code NVARCHAR(300))
		INSERT INTO #TBLTEMP
		SELECT CostCenterID,NODEID  FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=83 AND ParentNodeID=@CustomerID
		DECLARE @COUNT INT,@I INT,@TABLENAME NVARCHAR(300),@SQL NVARCHAR(MAX),@CCID INT,@NODEID INT,@FEATURENAME NVARCHAR(300), @IsGroup bit
		SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP
		WHILE @I<=@COUNT
		BEGIN
			SELECT @NODEID=NODEID,@CCID=CostCenterId FROM #TBLTEMP WHERE ID=@I
			SELECT @FEATURENAME=NAME,@TABLENAME=TABLENAME FROM ADM_FEATURES WHERE FEATUREID =@CCID
			 
				--IF @CCID>50000
				SET @SQL='if exists (select NodeID FROM '+@TABLENAME +' 
					     WHERE NODEID='+CONVERT(VARCHAR,@NODEID) +' and IsGroup=0)
							INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +' 
									 WHERE NODEID='+CONVERT(VARCHAR,@NODEID) +'
					     else
							INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +' 
									 WHERE ParentID='+CONVERT(VARCHAR,@NODEID) 
					     
			-- print(@SQL)
			 EXEC (@SQL)
			SET @I=@I+1
		END
		
		SELECT * FROM #TBLTEMP1
		DROP TABLE #TBLTEMP1
		DROP TABLE #TBLTEMP
		
		SELECT ConvertFromCustomerID FROM COM_Contacts C WITH(NOLOCK)
		LEFT JOIN Acc_Accounts A WITH(nolock) ON A.AccountID=C.FeaturePK
		WHERE C.FeatureID=2 AND ConvertFromCustomerID=@CustomerID

		SELECT ConvertFromCustomerID FROM COM_Address AD WITH(NOLOCK)
		LEFT JOIN Acc_Accounts A WITH(nolock) ON A.AccountID=AD.FeaturePK
		WHERE AD.FeatureID=2 AND ConvertFromCustomerID=@CustomerID

		SELECT ConvertFromCustomerID FROM COM_CostCenterCostCenterMap CCM WITH(NOLOCK)
		LEFT JOIN Acc_Accounts A WITH(nolock) ON A.AccountID=CCM.ParentNodeID
		WHERE CCM.ParentCostCenterID=2 AND ConvertFromCustomerID=@CustomerID


			
	Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM CRM_Customer WITH(NOLOCK) where CustomerID=@CustomerID
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
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=83
			AND CCNodeID=@CustomerID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		
		end 
		  
COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN @CustomerID
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
