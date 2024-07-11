USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetProperty]
	@PropertyID [int] = 0,
	@ContractType [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
        
BEGIN TRY         
SET NOCOUNT ON        
    
   	declare @dimCid int,@table nvarchar(50)
	set @dimCid=0
	select @dimCid=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where Name='DimensionWiseContract' and costcenterid=95 and Value is not null and Value<>'' and ISNUMERIC(value)=1
     
	select * from REN_Property WITH(NOLOCK) where  IsGroup=1        
	    
	--GET ALERTS DATA
	SELECT A.AlertID,A.AlertMessage,A.FeatureID,A.FeaturePK,convert(varchar,convert(datetime,A.fromdate),106)+' '+convert(varchar,convert(datetime,A.fromdate),108) FromDate,
	convert(varchar,convert(datetime,A.todate),106)+' '+convert(varchar,convert(datetime,A.todate),108) ToDate,A.StatusID,
	convert(datetime,A.CreatedDate) CreatedDate,convert(datetime,A.ModifiedDate) ModifiedDate,A.CreatedBy,A.ModifiedBy,
	isnull(F.ActualFileName,'') ActualFileName,F.FileID AttachmentID,F.GUID FROM COM_ALERTS A WITH(NOLOCK)  
	Left join COM_FILES F WITH(NOLOCK) on F.FileID=A.AttachmentID 
	WHERE A.FeatureID=92 AND A.FeaturePK=@PropertyID       
	    
	select *,convert(datetime,BondDate) as BD from REN_Property WITH(NOLOCK) where NodeID=@PropertyID        
	      
	select sh.*,a.AccountName from  REN_PropertyShareHolder sh WITH(NOLOCK)
	left join ACC_Accounts a with(nolock) on sh.account=a.AccountID
	where propertyid=@PropertyID
	           
	declare @T1 nvarchar(100),@T2 nvarchar(100),@Sql nvarchar(max) ,@T3 nvarchar(100)       
	    
	set @T1=(select TableName from adm_features WITH(NOLOCK) where featureid=(select value from ADM_GlobalPreferences WITH(NOLOCK) where Name='DepositLinkDimension'))        
	set @T2=(select TableName from adm_features WITH(NOLOCK) where featureid=(select value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='UnitLinkDimension'))        
	set @T3=(select TableName from adm_features WITH(NOLOCK) where featureid=(select value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='PropertyParking'))        
	
	DECLARE @DATA NVARCHAR(MAX)    
	IF(@ContractType =0)
	BEGIN    
		SET @DATA='        
		select REN_Particulars.*'
		
		if exists(select * from adm_globalpreferences WITH(NOLOCK)
			where name ='VATVersion')
			SET @DATA=@DATA+',Tx.Name TaxCategory,SPT.Name SPTypeName'
		else
			SET @DATA=@DATA+','''' TaxCategory,'''' SPTypeName'
		
		if (@dimCid>50000)
			set @DATA=@DATA+' ,Dim.Name Dimname'
		ELSE
			set @DATA=@DATA+' ,'''' Dimname'	
			
		SET @DATA=@DATA+',Bnk.ACCOUNTNAME BankAccount,A.ACCOUNTNAME A,B.ACCOUNTNAME B,Ad.ACCOUNTNAME AdvanceAccountName,'+@T1+'.NAME from REN_Particulars WITH(NOLOCK)        
		LEFT JOIN ACC_ACCOUNTS A WITH(NOLOCK) ON A.AccountID=REN_Particulars.CreditAccountID        
		LEFT JOIN ACC_ACCOUNTS B WITH(NOLOCK) ON B.AccountID=REN_Particulars.DebitAccountID
		LEFT JOIN ACC_ACCOUNTS Bnk WITH(NOLOCK) ON Bnk.AccountID=REN_Particulars.BankAccountID        
		LEFT JOIN ACC_ACCOUNTS Ad WITH(NOLOCK) ON Ad.AccountID=REN_Particulars.AdvanceAccountID'
		
		if (@dimCid>50000)
		BEGIN
			select @table=tablename from adm_features with(NOLOCK) where featureid=@dimCid
			set @DATA=@DATA+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=REN_Particulars.DimNodeID '			
		END

		if exists(select * from adm_globalpreferences WITH(NOLOCK)
			where name ='VATVersion')	 
			SET @DATA=@DATA+' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=REN_Particulars.TaxCategoryID   LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=REN_Particulars.SPType      '
		
		SET @DATA=@DATA+' LEFT JOIN '+@T1+' ON '+@T1+'.NodeID=REN_Particulars.ParticularID        
		where PropertyID='+CONVERT(VARCHAR,@PropertyID)+' and Unitid= 0 ' 
		SET  @DATA = @DATA + ' order by '+@T1+'.Code'	        
	END 
	ELSE
	BEGIN
		SET @DATA='        
		select REN_Particulars.*'
		
		if exists(select * from adm_globalpreferences WITH(NOLOCK)
			where name ='VATVersion')
			SET @DATA=@DATA+',Tx.Name TaxCategory,SPT.Name SPTypeName'
		else
			SET @DATA=@DATA+','''' TaxCategory,'''' SPTypeName'
			
		SET @DATA=@DATA+',Bnk.ACCOUNTNAME BankAccount,A.ACCOUNTNAME A,B.ACCOUNTNAME B,Ad.ACCOUNTNAME AdvanceAccountName,'+@T1+'.NAME from REN_Particulars WITH(NOLOCK)        
		LEFT JOIN ACC_ACCOUNTS A WITH(NOLOCK) ON A.AccountID=REN_Particulars.CreditAccountID        
		LEFT JOIN ACC_ACCOUNTS B WITH(NOLOCK) ON B.AccountID=REN_Particulars.DebitAccountID
		LEFT JOIN ACC_ACCOUNTS Bnk WITH(NOLOCK) ON Bnk.AccountID=REN_Particulars.BankAccountID        
		LEFT JOIN ACC_ACCOUNTS Ad WITH(NOLOCK) ON Ad.AccountID=REN_Particulars.AdvanceAccountID'
		
		if exists(select * from adm_globalpreferences WITH(NOLOCK)
			where name ='VATVersion')	 
			SET @DATA=@DATA+' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=REN_Particulars.TaxCategoryID  LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=REN_Particulars.SPType      '
		
		SET @DATA=@DATA+' LEFT JOIN '+@T1+' ON '+@T1+'.NodeID=REN_Particulars.ParticularID        
		where PropertyID='+CONVERT(VARCHAR,@PropertyID)+' and Unitid= 0  AND ContractType = ' +CONVERT(VARCHAR,@ContractType)   
		SET  @DATA = @DATA + ' order by '+@T1+'.Code'	    
	END
	print @DATA
	EXEC (@DATA)        
          
	select * from REN_PropertyUnits WITH(NOLOCK) where PropertyID=@PropertyID        

	set @Sql ='select NodeID,Name as Type from '+@T3+' WITH(NOLOCK)'             
	exec (@Sql)       
	    
	set @Sql ='select NodeID,Name as Type from '+@T2+' WITH(NOLOCK)'             
	exec (@Sql)        
	    
	--Getting data from Opportunities extended table        
	SELECT * FROM  REN_PropertyExtended WITH(NOLOCK)         
	WHERE NodeID=@PropertyID        
	      
	SELECT * FROM ADM_PropertyUserRoleMap  WITH(NOLOCK)      
	WHERE PropertyID = @PropertyID        
	      
	-- GETTING COSTCENTER DATA         
	SELECT * FROM  COM_CCCCDATA WITH(NOLOCK)         
	WHERE NodeID=@PropertyID and CostCenterID = 92         
	          
	SELECT * FROM COM_Notes WITH(NOLOCK)   
	WHERE FeatureID = 92 AND FeaturePK  = @PropertyID
	
	EXEC [spCOM_GetAttachments] 92,@PropertyID,@UserID
	
	--WorkFlow
	--EXEC spCOM_CheckCostCentetWFApprove 92,@PropertyID,@UserID,@RoleID
	
		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM REN_Property WITH(NOLOCK) where NodeID=@PropertyID
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
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=92
			AND CCNodeID=@PropertyID AND A.USERID=U.USERID
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
