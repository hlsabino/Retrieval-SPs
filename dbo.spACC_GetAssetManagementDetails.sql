USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetAssetManagementDetails]
	@AssetManagementID [int] = 0,
	@UserID [int],
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    
	
	declare @SQL nvarchar(max),@AssetLocDim nvarchar(20),@AssetOwnerDim nvarchar(20)
	
	if @AssetManagementID!=0
	begin
		select @AssetLocDim=TableName from adm_features with(nolock) where FeatureID IN (select Value from com_costcenterpreferences with(nolock) where costcenterid=72 and Name='AssetLocationDim')
		select @AssetOwnerDim=TableName from adm_features with(nolock) where FeatureID IN (select Value from com_costcenterpreferences with(nolock) where costcenterid=72 and Name='AssetOwner')
	end
	
   --select * from ACC_Assets   
    select AssetClassID,AssetClassName from ACC_AssetClass with(nolock)
    
    --Preferences Unused Table
    select 1 Unused where 1!=1
    
    select * from ACC_DeprBook with(nolock)
    
     --Unused
    if @AssetManagementID!=0 and @AssetOwnerDim!='' and @AssetOwnerDim is not null
	begin
		set @SQL='select H.HistoryID,L.Code,L.Name,H.HistoryNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,H.Remarks
		from COM_HistoryDetails H with(nolock) 
		inner join '+@AssetOwnerDim+' L with(nolock) on L.NodeID=H.HistoryNodeID
		where H.CostCenterID=72 and H.NodeID='+convert(nvarchar,@AssetManagementID)+' and H.HistoryCCID=2
		order by FromDate,H.HistoryID'
		exec(@SQL)
	end
	else
	begin
		select 1 OwnerHistory where 1!=1
	end
    
    select top(1) A.AssetID,A.[Description],   
     A.AssetCode,   
     A.AssetName,  
     A.StatusID,  
     A.SerialNo,   
     A.DeprBookGroupID,  
     A.ClassID,    
     A.LocationID,  
     A.EmployeeID,  
     case when (A.AssignedDate is null or A.AssignedDate=0) then null else (convert(datetime,A.AssignedDate)) end AssignedDate,   
     A.PostingGroupID,   
     A.EstimateLife,   
     A.SalvageValueType,  
     A.SalvageValueName,  
     A.SalvageValue,   
     A.IsComponent,  
     A.ParentAssetID,   
     A.PurchaseInvoiceNo,   
     A.SupplierAccountID,   
     A.AssetDepreciationJV ,  
     A.PurchaseValue,   
     case when (A.PurchaseDate is null or A.PurchaseDate=0) then null else (convert(datetime,A.PurchaseDate)) end PurchaseDate,   
     A.DeprStartValue,   
	 case when (A.DeprStartDate is null or A.DeprStartDate=0) then null else (convert(datetime,A.DeprStartDate)) end DeprStartDate,   
     case when (A.DeprEndDate is null or A.DeprEndDate=0) then null else (convert(datetime,A.DeprEndDate)) end  DeprEndDate,   
     case when (A.OriginalDeprStartDate is null or A.OriginalDeprStartDate=0) then null else (convert(datetime,A.OriginalDeprStartDate)) end OriginalDeprStartDate,
     A.AssetNetValue,   
     A.CalcDate,   
     A.WarrantyNo,   
     case when (A.WarrantyExpiryDate is null or A.WarrantyExpiryDate=0) then null else (convert(datetime,A.WarrantyExpiryDate))end WarrantyExpiryDate,   
     A.IsMainCovered,   
     A.MainVendorAccID,   
     case when (A.NextServiceDate is null or A.NextServiceDate=0) then null else (convert(datetime,A.NextServiceDate))  end NextServiceDate,   
     case when (A.MaintStartDate is null or A.MaintStartDate=0) then null else (convert(datetime,A.MaintStartDate)) end MaintStartDate,   
     case when (A.MaintExpiryDate is null or A.MaintExpiryDate=0) then null else (convert(datetime,A.MaintExpiryDate)) end MaintExpiryDate,   
     A.IsInsCovered,   
     A.InsVendorAccID,   
     A.InsPolicyNo,   
     A.InsType,   
     case when (A.InsEffectiveDate is null or A.InsEffectiveDate=0) then null else (convert(datetime,A.InsEffectiveDate)) end InsEffectiveDate,  
     case when (A.InsExpiryDate is null or A.InsExpiryDate=0) then null else (convert(datetime,A.InsExpiryDate)) end InsExpiryDate,  
     A.PreviousDepreciation,   
     A.InsPremium,   
     A.PolicyCoverage,   
     A.InsNarration,   
     A.Period,    
     A.AssetDisposalJV,   
     A.DepreciationMethod,   
     A.AveragingMethod,A.GUID, ISNULL(A.CCID,0) AssetDimID,ISNULL(A.CCNodeID,0) AssetDimNodeID,A.ParentID,
     A.IsDeprSchedule,ACC_AssetChanges.AssetNewValue as CurrentValue ,
     A.DeprBookID,
     A.PONo,case when (A.PODate is null or A.PODate=0) then null else (convert(datetime,A.PODate)) end PODate,
     A.GRNNo,case when (A.GRNDate is null or A.GRNDate=0) then null else (convert(datetime,A.GRNDate)) end GRNDate,
     A.CapitalizationNo,case when (A.CapitalizationDate is null or A.CapitalizationDate=0) then null else (convert(datetime,A.CapitalizationDate)) end CapitalizationDate,
     A.TotalQtyPurchase,A.UOM,A.IncludeSalvageInDepr,
     A.AcqnCostACCID,A.AccumDeprACCID,A.AcqnCostDispACCID,A.AccumDeprDispACCID,
	 A.GainsDispACCID,A.LossDispACCID,A.MaintExpenseACCID,A.DeprExpenseACCID,
	 A.CodePrefix,A.CodeNumber,A.Depth,A.WorkFlowID,A.WorkFlowLevel
     from ACC_Assets A with(nolock)
     LEFT JOIN ACC_AssetChanges with(nolock) on A.AssetID=ACC_AssetChanges.AssetID  
     where A.AssetID=@AssetManagementID 
     order by ACC_AssetChanges.AssetChangeID desc  
    
    --Asset Location Name
	if @AssetManagementID!=0
	begin
		declare @AssLocation INT,@AssEmp INT,@AssetLoc nvarchar(200),@AssetOwner nvarchar(200)
		select @AssLocation=LocationID,@AssEmp=EmployeeID from ACC_Assets with(nolock) where AssetID=@AssetManagementID 
		if @AssetLocDim!='' and @AssetLocDim is not null
		begin
			set @SQL='select @Name=Name from '+@AssetLocDim +' with(nolock) where NodeID='+convert(nvarchar,isnull(@AssLocation,0))
			EXEC sp_executesql @SQL,N'@Name nvarchar(200) OUTPUT',@AssetLoc OUTPUT
		end
		
		if @AssetOwnerDim!='' and @AssetOwnerDim is not null
		begin
			set @SQL='select @Name=Name from '+@AssetOwnerDim +' with(nolock) where NodeID='+convert(nvarchar,isnull(@AssEmp,0))
			EXEC sp_executesql @SQL,N'@Name nvarchar(200) OUTPUT',@AssetOwner OUTPUT
		end

		select @AssetLoc AssetLocation,@AssetOwner AssetOwner
	end
	else
		select 1 AssetLocation where 1!=1
    
   
   -- select A.*,convert(datetime,A.ChangeDate) as Date,L.Name as Location  from ACC_AssetChanges A,COM_Location L where A.AssetID=@AssetManagementID and convert(nvarchar(50),A.LocationID)=L.Code    
      
	select A.*,convert(datetime,A.ChangeDate) as Date,convert(datetime,A.CreatedDate) as CreatedDt  from ACC_AssetChanges A with(nolock) 
	where A.AssetID=@AssetManagementID order by A.ChangeDate
      
	if @AssetManagementID!=0 and @AssetLocDim is not null and @AssetLocDim!=''
	begin
		set @SQL='select H.HistoryID,L.Code,L.Name,H.HistoryNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,H.Remarks
		from COM_HistoryDetails H with(nolock) 
		inner join '+@AssetLocDim+' L with(nolock) on L.NodeID=H.HistoryNodeID
		where H.CostCenterID=72 and H.NodeID='+convert(nvarchar,@AssetManagementID)+' and H.HistoryCCID=1
		order by FromDate,H.HistoryID'
		exec(@SQL)
	end
	else
	begin
		select 1 LocationHistory where 1!=1
	end
      
    select top(1) convert(datetime,ACC_Assets.DeprStartDate) as DepStartDate,ACC_AssetChanges.AssetNewValue ,ACC_AssetChanges.AssetChangeID  
    from ACC_Assets with(nolock) 
    LEFT JOIN ACC_AssetChanges with(nolock) on ACC_Assets.AssetID=ACC_AssetChanges.AssetID   
    where ACC_Assets.AssetID=@AssetManagementID order by ACC_AssetChanges.AssetChangeID desc  
      
    SELECT D.CostCenterID,L.ResourceData  
   FROM ADM_DocumentTypes D WITH(NOLOCK)  
   INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID  
   LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID   
   WHERE D.DocumentType=17  
   ORDER BY L.ResourceData   
  
	--Depreciation Values     
	SELECT   dep.DPScheduleID ScheduleID,  CONVERT(DATETIME, dep.DeprStartDate ) AS FromDate  
	,CONVERT(DATETIME, dep.DeprEndDate ) AS ToDate  
	, dep.PurchaseValue   
	, dep.DepAmount AS DeprAmt   
	, dep.AccDepreciation AS accmDepr   
	, dep.AssetNetValue AS NetValue  
	,dep.DocID   
	,dep.VoucherNo   
	,dep.DocDate   
	,dep.ActualDeprAmt
	, Sts.status StatusID   
	,dep.CreatedBy   
	,dep.CreatedDate   
	,dep.ModifiedBy   
	,dep.ModifiedDate
	,accdoc.CostCenterID CostCenterID  
	,accdoc.DocPrefix  DocPrefix  
	,accdoc.DocNumber  DocNumber  
	, ADF.DocumentName DocumentName   
	FROM  [ACC_AssetDepSchedule] dep with(nolock)   
	LEFT JOIN Com_Status Sts with(nolock) on  Sts.StatusID =  dep.StatusID    
	LEFT JOIN acc_docdetails accdoc with(nolock) on dep.docid = accdoc.docid  and accdoc.docseqno = 1   
	LEFT join ADM_DocumentTypes ADF with(nolock) on accdoc.CostCenterID = ADF.CostCenterID    
	where dep.AssetID=@AssetManagementID  order by CONVERT(DATETIME, dep.DeprStartDate ) asc   
  
	--History Details
	select H.HistoryID,H.HistoryCCID CCID,H.HistoryNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,H.Remarks
	from COM_HistoryDetails H with(nolock) 
	where H.CostCenterID=72 and H.NodeID=@AssetManagementID and H.HistoryCCID>50000
	order by FromDate,H.HistoryID

	SELECT  DepreciationMethodID, Name  FROM ACC_DepreciationMethods with(nolock)

	select *,case when [Date] is null then null else convert(datetime,[Date]) end as Datee,  
		case when NextServiceDate is null then null else convert(datetime,NextServiceDate) end as MaintenanceNextServiceDate,  
		case when StartDate is null then null else convert(datetime,StartDate) end as InsuranceStartDate,  
		case when EndDate is null then null else convert(datetime,EndDate) end as InsuranceEndDate  
	from ACC_AssetsHistory with(nolock) where AssetManagementID=@AssetManagementID  
   
	--Getting Notes  
	SELECT  NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate,   
	ModifiedBy, ModifiedDate, CostCenterID  
	FROM   COM_Notes WITH(NOLOCK)   
	WHERE FeatureID=72 and  FeaturePK=@AssetManagementID  

	--Getting Files  
	SELECT CONVERT(DATETIME,CreatedDate) CreatedDate,* FROM  COM_Files WITH(NOLOCK)   
	WHERE FeatureID=72 and  FeaturePK=@AssetManagementID  

	--Extra Fields  
	SELECT * FROM  ACC_AssetsExtended WITH(NOLOCK)   
	WHERE AssetID=@AssetManagementID  
	

	--Getting CostCenterMap  
	SELECT * FROM COM_CCCCDATA with(nolock)
	WHERE NodeID = @AssetManagementID AND CostCenterID  = 72  

	
	Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM ACC_Assets WITH(NOLOCK) where AssetID=@AssetManagementID
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
       print 'StatusID'
	   print @StatusID
	   print '@Level'
	   print @Level
	    print  @Userlevel
		print '@WID'
		print @WID
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
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=72
			AND CCNodeID=@AssetManagementID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
		end
		
		end 
      
   
SET NOCOUNT OFF;    
RETURN @AssetManagementID    
END TRY    
BEGIN CATCH      
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
