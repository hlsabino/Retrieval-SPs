USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetUnitDetails]
	@UnitID [int] = 0,
	@UserID [int],
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
    
BEGIN TRY     
SET NOCOUNT ON   
	
	declare @dimCid int,@table nvarchar(50)
	set @dimCid=0
	select @dimCid=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where Name='DimensionWiseContract' and costcenterid=95 and Value is not null and Value<>'' and ISNUMERIC(value)=1
      
	declare @T1 nvarchar(100),@T2 nvarchar(100),@Sql nvarchar(max)    
	
	SELECT @Sql=b.Name FROM REN_UNITS a WITH(NOLOCK) 
	join COM_Lookup b WITH(NOLOCK) on a.unitstatus=b.NodeID
	WHERE LookupType=46   and UNITID=@UNITID

	SELECT *,[Status] StatusID,@Sql UnitStatusName FROM REN_UNITS WITH(NOLOCK) WHERE UNITID=@UNITID    

	set @T1=(select TableName from adm_features WITH(NOLOCK) where featureid=(select value from ADM_GlobalPreferences WITH(NOLOCK) where Name='DepositLinkDimension'))    
	set @T2=(select TableName from adm_features WITH(NOLOCK) where featureid=(select value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='UnitLinkDimension'))    
	DECLARE @DATA NVARCHAR(MAX)    
	SET @DATA='    
	select REN_Particulars.*'
	
	if exists(select * from adm_globalpreferences WITH(NOLOCK) where name ='VATVersion')
		SET @DATA=@DATA+',Tx.Name TaxCategory,SPT.Name SPTypeName'
	else
		SET @DATA=@DATA+','''' TaxCategory,'''' SPTypeName'
	
	if (@dimCid>50000)
		set @DATA=@DATA+' ,Dim.Name Dimname'
	ELSE
		set @DATA=@DATA+' ,'''' Dimname'
		
	SET @DATA=@DATA+',Bnk.ACCOUNTNAME BankAccount,A.ACCOUNTNAME A,B.ACCOUNTNAME B,Ad.ACCOUNTNAME AdvanceAccountName,'+@T1+'.NAME from REN_Particulars WITH(NOLOCK)    
	JOIN ren_units u  WITH(NOLOCK) on  REN_Particulars.unitid=u.unitid and REN_Particulars.propertyid=u.propertyid
	LEFT JOIN ACC_ACCOUNTS A WITH(NOLOCK) ON A.AccountID=REN_Particulars.CreditAccountID    
	LEFT JOIN ACC_ACCOUNTS B WITH(NOLOCK) ON B.AccountID=REN_Particulars.DebitAccountID 
	LEFT JOIN ACC_ACCOUNTS Bnk WITH(NOLOCK) ON Bnk.AccountID=REN_Particulars.BankAccountID          
	LEFT JOIN ACC_ACCOUNTS Ad WITH(NOLOCK) ON Ad.AccountID=REN_Particulars.AdvanceAccountID '
	
	if (@dimCid>50000)
	BEGIN
		select @table=tablename from adm_features with(NOLOCK) where featureid=@dimCid
		set @DATA=@DATA+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=REN_Particulars.DimNodeID '			
	END
	
	if exists(select * from adm_globalpreferences
		where name ='VATVersion')	 
		SET @DATA=@DATA+' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=REN_Particulars.TaxCategoryID     LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=REN_Particulars.SPType    '
	
	SET @DATA=@DATA+' LEFT JOIN '+@T1+'  WITH(NOLOCK) ON '+@T1+'.NodeID=REN_Particulars.ParticularID    
	where REN_Particulars.UNITID='+CONVERT(VARCHAR,@UNITID)   
	SET  @DATA = @DATA + ' order by '+@T1+'.Code'	    
	print @DATA
	EXEC (@DATA)    

	SELECT * FROM REN_UnitsExtended WITH(NOLOCK) WHERE UnitID=@UNITID    

	SELECT TNT.FirstName Tenant,CONVERT(DATETIME, RN.StartDate) AS StartDate, CONVERT(DATETIME, RN.EndDate) AS EndDate,RN.TenantID
	FROM  REN_Contract AS RN WITH(NOLOCK)
	LEFT JOIN REN_Tenant AS TNT WITH(NOLOCK) ON TNT.TenantID = RN.TenantID    
	WHERE RN.UnitID=@UNITID  AND RN.COSTCENTERID = 95 AND  RN.statusid <>477 
	order by RN.EndDate desc
   
	--Getting CostCenterMap    
	SELECT * FROM COM_CCCCDATA  WITH(NOLOCK)   
	WHERE NodeID = @UNITID AND CostCenterID  = 93     
	
	SELECT * FROM COM_Notes WITH(NOLOCK)   
	WHERE FeatureID = 93 AND FeaturePK  = @UNITID
	
	EXEC [spCOM_GetAttachments] 93,@UNITID,@UserID

	SELECT UnitRateID,UnitID , Amount ,Discount , AnnualRent, CONVERT(NVARCHAR(12), CONVERT(DATETIME,WithEffectFrom)) AS WithEffectFrom  
	FROM Ren_UnitRate WITH(NOLOCK)
	WHERE UnitID = @UNITID  
	
	--WorkFlow
	--EXEC spCOM_CheckCostCentetWFApprove 93,@UNITID,@UserID,@RoleID  
	
	--History Details
	select H.HistoryID,H.HistoryCCID CCID,H.HistoryNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,H.Remarks
	from COM_HistoryDetails H with(nolock) 
	where H.CostCenterID=93 and H.NodeID=@UNITID --and H.HistoryCCID>50000
	order by FromDate,H.HistoryID


		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=Status,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM REN_UNITS WITH(NOLOCK) where UnitID=@UnitID
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
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=93
			AND CCNodeID=@UnitID AND A.USERID=U.USERID
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
		FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=-999 AND LanguageID=@LangID    
	END    
    
SET NOCOUNT OFF      
RETURN -999       
END CATCH
GO
