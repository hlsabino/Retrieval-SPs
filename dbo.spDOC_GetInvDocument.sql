USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetInvDocument]
	@CostCenterID [int],
	@DocPrefix [nvarchar](50),
	@DocNumber [nvarchar](500),
	@IsPrevNext [int],
	@DocID [int],
	@LockWhere [nvarchar](max) = '',
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY   
SET NOCOUNT ON  
  
	--Declaration Section  
	DECLARE @HasAccess bit,@VoucherNo NVARCHAR(100),@DocDate float,@doctype int,@sql nvarchar(max),@UserWise bit,@AssignWise bit,@isLinewise bit,@CrdtDate float,@OffLineStatus int
	Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@DimensionWise bit,@isPrinted bit,@InvDocDetID INT,@tabName nvarchar(100)
	Declare @PrefValue nvarchar(50),@Dimesion int,@CrAccID INT,@WHERE nvarchar(500),@DbAccID INT,@Type int,@escDays int,@EditPostedDoc BIT,@EditApprovedDoc BIT,@EditRejectedDoc bit
	Declare @docPref table(name nvarchar(100),value nvarchar(100))
	DECLARE @DAllowLockData BIT,@AllowLockData BIT,@IsLock bit,@CreatedDate datetime,@DLockCC int,@LockCCValues nvarchar(max),@dim INT,@LockedBY nvarchar(max),@guid nvarchar(max),@DisRej bit
	
	--SP Required Parameters Check  
	IF (@CostCenterID < 1)  
	BEGIN  
		RAISERROR('-100',16,1)  
	END  
    
  
	--User acces check  
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)  

	IF @HasAccess=0  
	BEGIN  
		RAISERROR('-105',16,1)  
	END  
	
	insert into @docPref
	SELECT Name,Value FROM ADM_GlobalPreferences WITH(NOLOCK)  
	WHERE Name in('DimensionwiseDocuments','CanApproveFunction','EditApprovedDocuments','ShowLinkedDocEdit','enableChequeReturnHistory','DocSave','AutoProduceDoc','ShowAttachmentExtraFieldsInDocuments')
	
	if(@DocID>0)
	BEGIN
		SELECT @InvDocDetID=InvDocDetailsID,@VoucherNo=VoucherNo,@DocDate=DocDate,@doctype=Documenttype,@DbAccID=DebitAccount,
		@StatusID=StatusID,@Level=WorkFlowLevel,@WID=WorkflowID,@CrAccID=CreditAccount,@CrdtDate=CreatedDate
		,@DocPrefix=DocPrefix, @DocNumber=DocNumber,@CreatedDate=CONVERT(float,CreatedDate)  FROM [Inv_DocDetails] WITH(NOLOCK)   
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID
	END
	ELSE
	BEGIN
		SET @UserWise=dbo.fnCOM_HasAccess(@RoleID,43,137)
		IF(@UserWise=0)
			SET @UserWise=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,137)
			
		SET @DimensionWise=dbo.fnCOM_HasAccess(@RoleID,43,145) 
		SET @AssignWise=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,221) 

		if(@DimensionWise=1)
		BEGIN
		   set @Dimesion=0    

			SELECT @PrefValue=Value FROM @docPref  WHERE Name='DimensionwiseDocuments'  
			if(@PrefValue is not null and @PrefValue<>'')    
			begin    		
				begin try    
					select @Dimesion=convert(INT,@PrefValue)    
				end try    
				begin catch    
					set @Dimesion=0    
				end catch 		
			END
			
			if(@Dimesion>50000)
			BEGIN
				set @sql='select @DimensionWise=IsColumninUse from ADM_CostCenterDef WITH(NOLOCK)  where CostCenterID='+convert(nvarchar,@CostCenterID)+' and SysColumnName=''dcccnid'+Convert(nvarchar,(@Dimesion-50000))+''''
				EXEC sp_executesql @sql,N'@DimensionWise BIT OUTPUT',@DimensionWise output
			END
		END
		IF (@UserWise=1 or @AssignWise=1 or @DimensionWise=1)
		BEGIN   
	  
			set @sql='if exists(SELECT DocID FROM [Inv_DocDetails] a WITH(NOLOCK)   
			join COM_DocCCData b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID'
		
			if(@DimensionWise=1 and @Dimesion>50000)
			BEGIN
				
				set @sql=@sql+' JOIN  COM_CostCenterCostCenterMap CCM WITH(NOLOCK) ON  parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+'  
				and CCM.costcenterid='+convert(nvarchar,@Dimesion)  

				select @tabName=TableName from adm_features WITH(NOLOCK) where FeatureID=@Dimesion
				
				 set @sql=@sql+' join '+@tabName+' DCCMj with(nolock) on  CCM.NodeID= DCCMj.NodeID 
								 join '+@tabName+' DCG   with(nolock) on  DCG.lft between   DCCMj.lft and  DCCMj.rgt and DCG.NodeID=b.DcccNID'+convert(nvarchar,(@Dimesion-50000))
			END                                  
			set @sql=@sql+' WHERE a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND DocPrefix='''+@DocPrefix+''' AND convert(INT,DocNumber)'
			
			if(@IsPrevNext=0)
				set @sql=@sql+' = '
			else  if(@IsPrevNext=1) 
				set @sql=@sql+' <= '
			else  if(@IsPrevNext=2) 
				set @sql=@sql+' >= '	
			set @sql=@sql+@DocNumber
			
			if(@AssignWise=1)		
				set @sql=@sql+' and a.Docid in (SELECT NodeID FROM ADM_Assign WITH(NOLOCK) 
					WHERE CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND UserID='+convert(nvarchar,@UserID)+')'
			
			if(@UserWise=1)		
				set @sql=@sql+' and a.CreatedBy in (select username from ADM_Users  WITH(NOLOCK) 
				where UserID='+convert(nvarchar,@UserID)+' or  UserID in (select NodeID from COM_CostCenterCostCenterMap WITH(NOLOCK)   
				where parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+'  
				and costcenterid=7))  '
			
			set @sql=@sql+') BEGIN  
			SELECT @DocNumber=DocNumber FROM [Inv_DocDetails] a WITH(NOLOCK) 
			join COM_DocCCData b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID '
		
			if(@DimensionWise=1 and @Dimesion>50000)
			BEGIN
				
				set @sql=@sql+' JOIN  COM_CostCenterCostCenterMap CCM WITH(NOLOCK) ON  parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+'  
				and CCM.costcenterid='+convert(nvarchar,@Dimesion)  

				
				 set @sql=@sql+' join '+@tabName+' DCCMj with(nolock) on  CCM.NodeID= DCCMj.NodeID 
								 join '+@tabName+' DCG   with(nolock) on  DCG.lft between   DCCMj.lft and  DCCMj.rgt and DCG.NodeID=b.DcccNID'+convert(nvarchar,(@Dimesion-50000))
			END  
			set @sql=@sql+' WHERE a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND DocPrefix='''+@DocPrefix+''' AND convert(INT,DocNumber)' 
			
			if(@IsPrevNext=0)
				set @sql=@sql+' = '
			else  if(@IsPrevNext=1) 
				set @sql=@sql+' <= '
			else  if(@IsPrevNext=2) 
				set @sql=@sql+' >= '	
			
			set @sql=@sql+@DocNumber
			
			if(@AssignWise=1)		
				set @sql=@sql+' and a.Docid in (SELECT NodeID FROM ADM_Assign WITH(NOLOCK) 
					WHERE CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND UserID='+convert(nvarchar,@UserID)+')'
			
			if(@UserWise=1)	
				 set @sql=@sql+'  and a.CreatedBy in (select username from ADM_Users   WITH(NOLOCK) 
				 where UserID='+convert(nvarchar,@UserID)+' or  UserID in (select NodeID from COM_CostCenterCostCenterMap  WITH(NOLOCK)  
				 where parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+'  
				 and costcenterid=7))  '
			 	
			set @sql=@sql+' ORDER BY convert(INT,DocNumber)       '
			if(@IsPrevNext=2) 
				set @sql=@sql+' desc '	
			 set @sql=@sql+' END  
				ELSE  
				begin     
				  set @DocNumber=''notexists''
				end '
			print @sql
			
			EXEC sp_executesql @sql,N'@DocNumber nvarchar(200) OUTPUT',@DocNumber output
			
			if(@DocNumber='notexists')
			BEGIN
				SET NOCOUNT OFF;  
				RETURN 1  
			END    

	   END
	  
	  
		set @DocID=0   
		SELECT @InvDocDetID=InvDocDetailsID,@VoucherNo=VoucherNo,@DocID=DocID,@CrdtDate=CreatedDate,@DocDate=DocDate,@doctype=Documenttype, @DbAccID=DebitAccount, 
		@StatusID=StatusID,@Level=WorkFlowLevel,@WID=WorkflowID,@CrAccID=CreditAccount,@CreatedDate=CONVERT(float,CreatedDate)  FROM [Inv_DocDetails] WITH(NOLOCK)   
		WHERE CostCenterID=@CostCenterID AND DocPrefix=@DocPrefix AND DocNumber=@DocNumber  
    
		if(@DocID is null or @DocID=0)
		begin     
			SET NOCOUNT OFF;  
			RETURN 1  
		end  
	END	

   insert into @docPref
   SELECT PrefName,PrefValue  FROM [COM_DocumentPreferences]  WITH(NOLOCK) 
   WHERE CostCenterID=@CostCenterID AND PrefName in('AuditTrial','Activities','TempInfo','UseQtyAdjustment','DocQtyAdjustment'
   ,'Notes','Attachments','AllowAdjToDownPmt','Autopostdocument','Enable Payment Terms','EnableRevision','PostVoucherDocument','OverrideLock'
   ,'CopyPaymentTerms','Lock Data Between','NoWorkflowPostedDocs','PrimaryAddress','ShippingAddress','BillingAddress','ShowLinkStatus','UseasAssemble/DisAssembly','LockCostCenters','LockCostCenterNodes')
   
   set @EditPostedDoc=0
   set @EditApprovedDoc=0
   set @EditRejectedDoc=0
   
   if exists(select WorkFlowID from COM_WorkFlowDef WITH(NOLOCK) where CostCenterID=@CostCenterID and IsLineWise=1)
	BEGIN
		if exists(select WorkflowID FROM [Inv_DocDetails] WITH(NOLOCK)   
		WHERE CostCenterID=@CostCenterID AND docid= @DocID and WorkflowID>0) 
		BEGIN
			set @isLinewise=1
			if exists(select value from @docPref where name='NoWorkflowPostedDocs' and value='true')
			or exists(select value from @docPref where name='EditApprovedDocuments' and value='true')
			or dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,401) =1
				set @EditPostedDoc=1
				
			if dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,433) =1
				set @EditApprovedDoc=1
			if dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,174) =1
				set @EditRejectedDoc=1
		END	
		else
			set @isLinewise=0
	END	
	else
		set @isLinewise=0
		
		set @PrefValue=''
		select @PrefValue=value from @docPref where name='CanApproveFunction'
   
   
   select @LockedBY=LockedBY,@OffLineStatus=OffLineStatus,@guid=guid from COM_DocID WITH(NOLOCK) where DocNo=@VoucherNo and ID=@DocID  

		   --GETTING DOCUMENT DETAILS  
		   SELECT a.InvDocDetailsID AS DocDetailsID,a.[AccDocDetailsID],a.VoucherNO
			 ,a.[DocID]  
			 ,a.[CostCenterID]  			 
			 ,a.[DocumentType]  
			 ,a.[VersionNo]  
			 ,a.[DocAbbr]  
			 ,a.[DocPrefix]  
			 ,a.[DocNumber]  
			 ,convert(nvarchar,CONVERT(DATETIME,a.[DocDate]),100) AS DocDate  
			 ,convert(nvarchar,CONVERT(DATETIME,a.[DueDate]),100) AS DueDate  
			 ,a.[StatusID]  
			 ,a.[BillNo]  
		     ,convert(nvarchar,CONVERT(DATETIME,a.BILLDATE),100) AS BillDate  
			 ,a.[LinkedInvDocDetailsID]  
			 ,a.LinkedFieldName  
			 ,a.LinkedFieldValue  
			 ,a.[CommonNarration]  
			 ,a.LineNarration  
			 ,a.[DebitAccount]  
			 ,a.[CreditAccount]  
			 ,a.[DocSeqNo]  
			 ,a.[ProductID],p.ProductTypeID,p.ProductCode,p.ProductName,p.QtyAdjustType,p.IsPacking,p.IsBillOfEntry,isnull(p.BinWise,0) BinWise,p.Volume,p.Weight,p.Wastage
			 ,isnull(p.MaxTolerancePer,0) ToleranceLimitsPercentage,isnull(p.MaxToleranceVal,0)  ToleranceLimitsValue   
			 ,a.[Quantity]  
			 ,a.Unit,u.UnitName  
			 ,a.[HoldQuantity],a.[ReserveQuantity]  
			 ,a.[ReleaseQuantity]  
			 ,a.[IsQtyIgnored]  
			 ,a.[IsQtyFreeOffer]  
			 ,a.[Rate]  
			 ,a.[AverageRate]  
			 ,a.[Gross]  
			 ,a.[StockValue]  
			 ,a.[CurrencyID]  
			 ,a.[ExchangeRate]  			
			 ,@guid [GUID],A.CreatedBy  
			 ,CONVERT(DATETIME,A.[CreatedDate]) AS CreatedDate  
			 ,A.[ModifiedBy],A.WorkflowID  
			 ,CONVERT(DATETIME,A.[ModifiedDate]) AS ModifiedDate  
		   ,UOMConversion  ,CanRecur
		   ,UOMConvertedQty,grossfc,DynamicInvDocDetailsID,VoucherType,convert(datetime,a.ActDocDate) ActDocDate, 
			RefNo,RefCCID,RefNodeid,LinkStatusID ,LinkStatusRemarks,ParentSchemeID,A.WorkFlowLevel
			,case when @isLinewise=1 and @PrefValue='true' THEN dbo.fnExt_CanApprove(a.InvDocDetailsID,a.CostCenterID,A.WorkflowID,A.WorkFlowLevel,a.StatusID ,a.CreatedDate,@UserID,@RoleID) 
			when @isLinewise=1 and @doctype >= 51 AND @doctype <= 199 AND @doctype != 64 then dbo.fnPay_CanApprove(a.InvDocDetailsID,a.DocumentType,@UserName,a.CostCenterID,A.WorkflowID,A.WorkFlowLevel,a.StatusID ,a.CreatedDate,@UserID,@RoleID)
			WHEN @isLinewise=1 THEN dbo.fnRPT_CanApprove(a.CostCenterID,A.WorkflowID,A.WorkFlowLevel,a.StatusID ,a.CreatedDate,@UserID,@RoleID) 
			ELSE 0 end as CanApprove
			,case when @isLinewise=1 THEN dbo.fnDoc_CanEdit(a.InvDocDetailsID,a.DocumentType,@UserName,a.CostCenterID,A.WorkflowID,A.WorkFlowLevel,a.StatusID,a.CreatedDate ,@UserID,@RoleID,@EditPostedDoc,@EditApprovedDoc,@EditRejectedDoc) 
			ELSE 1 end as CanEdit
			FROM  [INV_DocDetails] a WITH(NOLOCK)  
			join dbo.INV_Product p WITH(NOLOCK) on  a.ProductID=p.ProductID  
			left join COM_UOM u WITH(NOLOCK) on u.UOMID=a.Unit  
			WHERE a.CostCenterID=@CostCenterID AND DocID=@DocID  
			order by a.DocSeqNo,a.VoucherType,a.dynamicinvdocdetailsid
    
	   IF(@doctype=62 OR @doctype=58)
	   BEGIN
			EXEC spPAY_GetEditableLeaveDetails @CostCenterID,@DocID,@doctype
	   END
	   
	   --GETTING DOCUMENT EXTRA COSTCENTER FEILD DETAILS  
	   SELECT A.* FROM  [COM_DocCCData] A WITH(NOLOCK)  
	   join [INV_DocDetails] D WITH(NOLOCK) on A.InvDocDetailsID=D.InvDocDetailsID     
	   WHERE CostCenterID=@CostCenterID AND DocID=@DocID  
	   order by D.DocSeqNo,D.VoucherType  ,d.dynamicinvdocdetailsid
	     
	   --GETTING DOCUMENT EXTRA NUMERIC FEILD DETAILS  
	   SELECT A.* FROM [COM_DocNumData] A WITH(NOLOCK)  
	   join [INV_DocDetails] D WITH(NOLOCK) on A.InvDocDetailsID=D.InvDocDetailsID     
	   WHERE CostCenterID=@CostCenterID AND DocID=@DocID  
	   order by D.DocSeqNo,D.VoucherType  ,d.dynamicinvdocdetailsid
	  
	   --GETTING DOCUMENT EXTRA TEXT FEILD DETAILS  
	   SELECT A.* FROM [COM_DocTextData] A WITH(NOLOCK)  
	   join [INV_DocDetails] D WITH(NOLOCK) on A.InvDocDetailsID=D.InvDocDetailsID     
	   WHERE CostCenterID=@CostCenterID AND DocID=@DocID  
	   order by D.DocSeqNo,D.VoucherType ,d.dynamicinvdocdetailsid 
  
    
	    --GETTING SerialStock  
		SELECT [SerialProductID]  
      ,A.[InvDocDetailsID]  
      ,A.[ProductID]  
      ,[SerialNumber]  
      ,[StockCode]  
      ,A.[Quantity]  
      ,A.[StatusID]  
      ,[SerialGUID]  
      ,[IsIssue]  
      ,[IsAvailable]  
      ,a.[RefInvDocDetailsID]  
      ,[Narration] FROM INV_SerialStockProduct A WITH(NOLOCK)  
   join [INV_DocDetails] D WITH(NOLOCK) on A.InvDocDetailsID=D.InvDocDetailsID      
   WHERE CostCenterID=@CostCenterID AND DocID=@DocID   
   
	SELECT @PrefValue=Value FROM @docPref  WHERE Name='DocSave'  
	if(@PrefValue is not null and @PrefValue='true')    
	begin 
			SELECT a.[BatchID]  
		  ,a.[InvDocDetailsID]  
		  ,a.UOMConvertedQty [Quantity]  
		  ,a.BatchHold [HoldQuantity]  
		  ,a.[ReleaseQuantity]  		 
		  ,a.[VoucherType]  		 
		  ,a.[RefInvDocDetailsID], b.[BatchNumber],CONVERT(datetime,b.[MfgDate]) MfgDate  
		 ,CONVERT(datetime,b.[ExpiryDate]) ExpiryDate  
		 ,b.[MRPRate]  
		 ,b.[RetailRate]  
		 ,b.[StockistRate],DynamicInvDocDetailsID,LinkedInvDocDetailsID FROM [INV_DocDetails] a WITH(NOLOCK)   
		join INV_Batches b WITH(NOLOCK) on a.BatchID=b.BatchID  		
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID 
		and a.BatchID>1
	END
	ELSE
	BEGIN
		SELECT [BatchDetailsID]  
		  ,a.[BatchID]  
		  ,a.[InvDocDetailsID]  
		  ,a.[Quantity]  
		  ,a.[HoldQuantity]  
		  ,a.[ReleaseQuantity]  
		  ,[ExecutedQuantity]  
		  ,a.[VoucherType]  		   
		  ,a.[RefInvDocDetailsID], b.[BatchNumber],CONVERT(datetime,b.[MfgDate]) MfgDate  
		 ,CONVERT(datetime,b.[ExpiryDate]) ExpiryDate  
		 ,b.[MRPRate]  
		 ,b.[RetailRate]  
		 ,b.[StockistRate] FROM INV_BatchDetails a WITH(NOLOCK)   
		join INV_Batches b WITH(NOLOCK) on a.BatchID=b.BatchID  
		join [INV_DocDetails] D WITH(NOLOCK) on A.InvDocDetailsId=D.InvDocDetailsID       
		WHERE CostCenterID=@CostCenterID AND DocID=@DocID   
	END
	
	if(@WID is null)
		select @InvDocDetID=InvDocDetailsID,@WID=WorkflowID,@Level=WorkFlowLevel from INV_DocDetails with(nolock)
		where DocID=@DocID and WorkflowID>0
		
		if(@WID is not null and @WID>0)  
		BEGIN 
		
			if (@doctype >= 51 AND @doctype <= 199 AND @doctype != 64) --IS PAYROLL DOCUMENT
			BEGIN
				--Check Whether the User Level is Payroll Employee Report Manager Level or Not
				SET @Userlevel=dbo.fnExt_GetRptMgrUserLevel(@InvDocDetID,@WID,@Level,@UserName,@RoleID)
			END
			
			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]   WITH(NOLOCK)   
				where WorkFlowID=@WID and  UserID =@UserID and LevelID>=@Level
				order by LevelID desc

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID and LevelID>=@Level
				order by LevelID desc

			if(@Userlevel is null )       
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID and LevelID>=@Level
				order by LevelID desc

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID and LevelID>=@Level
				order by LevelID desc
						
			if(@Userlevel is null )  	
				SELECT @Type=type FROM [COM_WorkFlow] WITH(NOLOCK) where WorkFlowID=@WID
		end 
     
		if(@StatusID<>369  and @WID>0)  
		begin    
		
			if(@Userlevel is not null and  @Level is not null and @Userlevel>@level)  
			begin
				if(@Type=1 or @Level+1=@Userlevel)
					set @canApprove=1   
				ELSE
				BEGIN
					if exists(select EscDays  from [COM_WorkFlow] a WITH(NOLOCK) 
						join COM_WorkFlowDef b with(nolock) on a.WorkFlowID=b.WorkFlowID
						where b.CostCenterID=@CostCenterID and a.LevelID=b.LevelID and  IsEnabled=1 and a.workflowid=@WID and ApprovalMandatory=1 and a.LevelID<@Userlevel and a.LevelID>@Level)
						set @canApprove=0
					ELSE
					BEGIN	
						select @escDays=isnull(sum(escdays),0) from (select max(escdays) escdays  from [COM_WorkFlow] a WITH(NOLOCK) 
						join COM_WorkFlowDef b with(nolock) on a.WorkFlowID=b.WorkFlowID
						where b.CostCenterID=@CostCenterID and a.LevelID=b.LevelID and  IsEnabled=1 and a.workflowid=@WID and a.LevelID<@Userlevel and a.LevelID>@Level
						group by a.LevelID) as t
						 
						set @CreatedDate=dateadd("d",@escDays,@CreatedDate)
						
						select @escDays=isnull(sum(escdays),0) from (select max(eschours) escdays  from [COM_WorkFlow] a WITH(NOLOCK) 
						join COM_WorkFlowDef b with(nolock) on a.WorkFlowID=b.WorkFlowID
						where b.CostCenterID=@CostCenterID and a.LevelID=b.LevelID and  IsEnabled=1 and a.workflowid=@WID and a.LevelID<@Userlevel and a.LevelID>@Level
						group by a.LevelID) as t
						
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
			
		
		set @PrefValue=''
		select @PrefValue=value from @docPref where name='CanApproveFunction'
		
		iF(@WID>0 and @PrefValue='true')
		BEGIN
			select @canApprove=dbo.fnExt_CanApprove(@InvDocDetID,@CostCenterID,@WID,@Level,@StatusID ,@CrdtDate,@UserID,@RoleID)
		END
		
				
		set @canEdit=1  
     
		if((@StatusID=369 or @StatusID=441 or @StatusID=371) and @WID>0)   
		begin  
			if(@Userlevel is null )  
			BEGIN
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]   WITH(NOLOCK)   
				where WorkFlowID=@WID and  UserID =@UserID
				order by LevelID
				
				if(@Userlevel is null )  
					SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]  WITH(NOLOCK)    
					where WorkFlowID=@WID and  RoleID =@RoleID
					order by LevelID

				if(@Userlevel is null )       
					SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.UserID=@UserID and WorkFlowID=@WID
					order by LevelID

				if(@Userlevel is null )  
					SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.RoleID =@RoleID and WorkFlowID=@WID
					order by LevelID
			END
			
			if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=0   
			end    
		end   	 
		
		if(@Userlevel is null and @WID>0 )  
		BEGIN
				SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]   WITH(NOLOCK)   
				where WorkFlowID=@WID and  UserID =@UserID
				order by LevelID
				
				if(@Userlevel is null )  
					SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow]  WITH(NOLOCK)    
					where WorkFlowID=@WID and  RoleID =@RoleID
					order by LevelID

				if(@Userlevel is null )       
					SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.UserID=@UserID and WorkFlowID=@WID
					order by LevelID

				if(@Userlevel is null )  
					SELECT @Userlevel=LevelID,@Type=type,@DisRej=DisableReject FROM [COM_WorkFlow] W WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.RoleID =@RoleID and WorkFlowID=@WID
					order by LevelID
		END
  
		--Getting Status
		SELECT @WHERE=R.ResourceData from COM_Status S WITH(NOLOCK)  
		JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID     
		where StatusID=@StatusID
		
		--Getting DocumentLinkDefID 
		set @WID=0		
		IF exists (SELECT Value  FROM @docPref  
		WHERE Name='ShowLinkedDocEdit' and Value='true')
			select @WID=DocumentLinkDefID from COM_DocumentLinkDef a WITH(NOLOCK)
			join [INV_DocDetails]  b WITH(NOLOCK) on a.CostCenterIDBase=b.CostCenterID
			join [INV_DocDetails]  c WITH(NOLOCK) on c.InvDocDetailsID=b.LinkedInvDocDetailsID and a.CostCenterIDLinked=c.CostCenterID
			where b.LinkedInvDocDetailsID is not null and b.LinkedInvDocDetailsID>0
			and b.docid=@DocID
		
		if exists(select DocID from INV_DocDetails_History_ATUser	WITH(NOLOCK) where DocID=@DocID and ActionTypeID=2 and ActionType='Print')
			set @isPrinted=1
		ELSE
			set @isPrinted=0
		
		if exists(SELECT Value FROM @docPref where Name='OverrideLock' and Value<>'true')
			SELECT @AllowLockData=Value FROM ADM_GlobalPreferences WITH(NOLOCK)  
			WHERE Name='Lock Data Between'
		
		SELECT @DAllowLockData=Value FROM @docPref
		WHERE Name='Lock Data Between'
		
		set @DLockCC=0	
		SELECT @DLockCC=CONVERT(INT,Value) FROM @docPref 
		where Name='LockCostCenters' and isnumeric(Value)=1
		
		declare @tble table(NIDs INT)  
		
		if(@DAllowLockData=1 and @DLockCC>50000)
		BEGIN
			SELECT @LockCCValues=Value FROM @docPref WHERE Name='LockCostCenterNodes'
			
			insert into @tble				
			exec SPSplitString @LockCCValues,',' 
			
			set @sql ='select @dim=dcCCNID'+CONVERT(NVARCHAR,(@DLockCC-50000))+' from INV_DocDetails a WITH(NOLOCK)
					join COM_DocCCData b WITH(NOLOCK) on a.INVDocDetailsID=b.INVDocDetailsID
				   where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)
							   
				   EXEC sp_executesql @sql,N'@dim INT OUTPUT',@dim output
		END	
			
		IF exists(select LockID from ADM_LockedDates WITH(NOLOCK) where isEnable=1 
		and ((@AllowLockData=1 and @DocDate between FromDate and ToDate and CostCenterID=0)
		or (@DAllowLockData=1 and @DocDate between FromDate and ToDate and CostCenterID=@CostCenterID and @DLockCC=0)
		or (@DAllowLockData=1 and @DocDate between FromDate and ToDate and CostCenterID=@CostCenterID and @DLockCC>50000
		and exists(select NIDs From @tble where NIDs=@dim))))
			set @IsLock=1	
		ELSE
			set @IsLock=0
		
		  if(dbo.fnCOM_HasAccess(@RoleID,43,193)=0 and @LockWhere <>'')
		  BEGIN
			  if(@LockWhere like '<XML%')
			  BEGIN
					declare @xml xml
					set @xml=@LockWhere					
					select @LockWhere=isnull(X.value('@where','nvarchar(max)'),''),@LockCCValues=isnull(X.value('@join','nvarchar(max)'),'')
					from @xml.nodes('/XML') as Data(X)    		         
		
			  		set @sql ='if exists (select a.CostCenterID from INV_DocDetails a WITH(NOLOCK)
						join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
						join ADM_DimensionWiseLockData c  WITH(NOLOCK) on a.DocDate between c.fromdate and c.todate and c.isEnable=1 '+@LockCCValues+'
						where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
							set @IsLock=1 '

			  END
			  ELSE
			  BEGIN
				  set @sql ='if exists (select a.CostCenterID from INV_DocDetails a WITH(NOLOCK)
						join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
						join ADM_DimensionWiseLockData c  WITH(NOLOCK) on a.DocDate between c.fromdate and c.todate and c.isEnable=1
						where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
							set @IsLock=1 '
			  END				 
			print @sql
			  EXEC sp_executesql @sql,N'@IsLock BIT OUTPUT',@IsLock output
		  END
		
				
		select @canApprove canapprove,@canEdit CanEdit,@WHERE 'Status',@WID LinkDefID,@isPrinted IsPrinted,@IsLock IsLock,@Userlevel userlevel,@level Wlevel,@Type WType,@LockedBY LockedBY,@OffLineStatus OffLineStatus,@DisRej DisableReject--6


		IF exists (SELECT Value  FROM @docPref 
		WHERE Name='Notes' and Value='true')
		BEGIN
		   --GETTING NOTES  
		   SELECT [NoteID],[Note],[CostCenterID],CreatedBy,Convert(DateTime,CreatedDate) CreatedDate,ModifiedBy,CONVERT(DATETIME,ModifiedDate) ModifiedDate FROM COM_Notes WITH(NOLOCK)      
		   WHERE FeatureID=@CostCenterID AND FeaturePK=@DocID   
		END
		ELSE
			SELECT 1 WHERE 1<>1
		
		IF exists (SELECT Value  FROM @docPref  
		WHERE Name='Attachments' and Value='true')
		BEGIN
			--GETTING ATTACHMENTS BASED ON GLOBALPREFERENCE
			IF exists (SELECT Value  FROM @docPref  WHERE Name='ShowAttachmentExtraFieldsInDocuments' and Value='true')
				EXEC [spCOM_GetAttachments] @CostCenterID,@DocID,@UserID
			ELSE
			BEGIN
			   --GETTING ATTACHMENTS  
			   SELECT [FileID],[FilePath],[ActualFileName],[RelativeFileName],[FileExtension],[IsProductImage],AllowInPrint,RowSeqNo,ColName,IsDefaultImage  
				,LocationID,[FileDescription],[CostCenterID],GUID,CreatedBy,CONVERT(DATETIME,CreatedDate) CreatedDate,CONVERT(DATETIME,ValidTill) ValidTill,RefNo,status FROM  COM_Files WITH(NOLOCK)   
			   WHERE FeatureID=@CostCenterID AND FeaturePK=@DocID   
			END
		END
		ELSE
			SELECT 1 WHERE 1<>1

        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='Activities' and Value='true')
		BEGIN 
			IF EXISTS (SELECT CostCenterID FROM CRM_Activities WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND NodeID=@DocID)
				EXEC spCRM_GetFeatureByActvities @DocID,@CostCenterID,'',@UserID,@LangID  
			ELSE
				SELECT 1 WHERE 1<>1 
		END
		ELSE
			SELECT 1 WHERE 1<>1
		   

		IF exists (SELECT Value  FROM @docPref  
		WHERE Name in('PrimaryAddress','ShippingAddress','BillingAddress') and Value='true')
		BEGIN 
			SELECT a.addressid,A.[InvDocDetailsID]  
			,[AddressHistoryID],[AddressTypeID] 
			FROM COM_DocAddressData A WITH(NOLOCK)  			
			WHERE DocID=@DocID  
						
			SELECT FEATUREPK,AddressName,Address1,Phone1,AddressID,AddressTypeID,0 
			,ContactPerson,Address2,Address3,State,Zip,City
			FROM COM_Address WITH(NOLOCK) 
			WHERE FEATUREID = 2 AND FEATUREPK in(@CrAccID,@DbAccID)
			UNION
			SELECT FEATUREPK,AddressName,Address1,Phone1,a.AddressID,a.AddressTypeID,a.AddressHistoryID 
			,ContactPerson,Address2,Address3,State,Zip,City
			FROM COM_Address_History a WITH(NOLOCK) 
			join COM_DocAddressData b WITH(NOLOCK) on a.AddressHistoryID=b.AddressHistoryID
			WHERE FEATUREID = 2 AND FEATUREPK in(@CrAccID,@DbAccID)			
			and  b.DocID=@DocID and a.AddressID not in (SELECT AddressID FROM COM_Address WITH(NOLOCK) 
			WHERE FEATUREID = 2 AND FEATUREPK in(@CrAccID,@DbAccID))
			
		END
		ELSE
		BEGIN
			SELECT 1 WHERE 1<>1
			SELECT 1 WHERE 1<>1
		END
		
        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='TempInfo' and Value='true')
		BEGIN 
			SELECT [InvTempInfoID]  
			  ,a.[InvDocDetailsID]  
			  ,[ProductCode]  
			  ,[PurchasePrice] FROM [INV_TempInfo] A WITH(NOLOCK)  
			join [INV_DocDetails] D WITH(NOLOCK) on A.InvDocDetailsId=D.InvDocDetailsID       
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID   
		END
		ELSE
			SELECT 1 WHERE 1<>1
     
        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='PostVoucherDocument' and Value is not null and Value<>'' and isnumeric(Value)=1 and convert(int,Value)>40000)
		BEGIN 
			select AccDocDetailsID,DocID,DocPrefix,DocNumber,DebitAccount,CreditAccount,Amount from acc_docdetails WITH(NOLOCK)  
			where refccid=300 and refnodeid=@DocID  and costcenterid=(SELECT Value  FROM @docPref  
			WHERE Name='PostVoucherDocument')
		END
		ELSE
			SELECT 1 WHERE 1<>1
		
		
        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='EnableRevision' and Value='true')
		BEGIN 
			select distinct Versionno from [INV_DocDetails_History] WITH(NOLOCK)  
			where DocID=@DocID  
		END
		ELSE
			SELECT 1 WHERE 1<>1
		     
		
		     
        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='Enable Payment Terms' and Value='true')
		or exists (SELECT Value  FROM @docPref  
		WHERE Name='CopyPaymentTerms' and Value='true')
		BEGIN 
			select  [VoucherNo]  
			,[AccountID]  
			,[Amount],AmountFC
			,[days]  
			,convert(datetime,[DueDate]) as [DueDate]  
			,[Percentage]  
			,[Remarts],Period,BasedOn,convert(datetime,BaseDate) as BaseDate,a.ProfileID,b.ProfileName,a.dimccid,a.dimNodeid,DateNo,Remarks1
			from [COM_DocPayTerms] a WITH(NOLOCK)  
			left join Acc_PaymentDiscountProfile b WITH(NOLOCK) on a.ProfileID=b.ProfileID
			where voucherno=@VoucherNo  
			order by DocPaytermID
	   END
		ELSE
			SELECT 1 WHERE 1<>1
	   	
		if(@doctype=35)  
		begin  
			IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='CRM_Cases')
			BEGIN
				SET @SQL='select c.CaseID,CaseNumber,Convert(datetime,CreateDate) CaseDate,R.ResourceData Status,ContractLineID,AssignedTo,userName AccountName, convert(datetime,StartDate) StartDate,convert(datetime,EndDate) EndDate,StartTime,EndTime,a.Remarks 
				FROM CRM_Cases c WITH(NOLOCK)  
				JOIN CRM_Activities a WITH(NOLOCK) on c.CaseID=a.NodeID and a.CostCenterID=73  
				left join COM_Status S WITH(NOLOCK)  on a.StatusID=s.StatusID  
				left join adm_users u WITH(NOLOCK)  on u.UserID=c.AssignedTo  
				LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID='+CONVERT(NVARCHAR,@LangID)+'     
				WHERE SvcContractID='+CONVERT(NVARCHAR,@DocID)  
				EXEC (@SQL)
			END	
			ELSE
				SELECT 1 WHERE 1<>1
				
			select CON.*,C1.Name as SalutationName,C1.NodeID as Salutation , C2.Name as Role,S.Status ,doc.CreditAccount CustomerID, acc.AccountName Customer from com_contacts CON WITH(NOLOCK) 
			left join com_lookup C1 WITH(NOLOCK) on CON.SalutationID=C1.NodeID and C1.lookuptype =20  
			left join com_lookup C2 WITH(NOLOCK) on CON.RoleLookUpID=C1.NodeID
			left join Com_Status S WITH(NOLOCK) on CON.StatusID=S.StatusID
			left join com_lookup Sal WITH(NOLOCK) on  Sal.nodeid = CON.SalutationID
			left join inv_docdetails doc WITH(NOLOCK) on CON.featurepk = doc.Docid and doc.costcenterid = @CostCenterID
			left join acc_accounts acc WITH(NOLOCK) on doc.CreditAccount = acc.accountid 
			where CON.featureid=@CostCenterID and CON.featurepk=@DocID
						
		end  
		ELSE if(@doctype=38 or @doctype=39)
		BEGIN
			SELECT  [Type],[Amount],[DBColumnName],[CardNo],[CardName],ApprovalCode,convert(datetime,ExpDate) [ExpDate],VoucherNodeID,Currency,ExchangeRate,AmountFC,BankName,CardType FROM COM_PosPayModes  WITH(NOLOCK)  where DocID=@DocID
			SELECT  [CurrencyID],[Notes],[NotesTender],[Change],[ChangeTender] FROm COM_DocDenominations WITH(NOLOCK)  where DocID=@DocID
		END
		ELSE IF (@doctype=202)
		BEGIN
		  SET @SQL='select distinct b.DocID,b.InvDocDetailsID DocDetailsID,convert(datetime,b.docdate) StartDate,convert(datetime,b.docdate) EndDate,StartTime,EndTime,R.ResourceData Status,AssignUserID AssignedTo,userName AccountName,a.Remarks,c.CostCenterID,b.RefNodeID   
		  from INV_DocDetails c WITH(NOLOCK)   
		  join INV_DocDetails b WITH(NOLOCK) on c.InvDocDetailsId=b.refnodeid and b.refccid=300      
		  JOIN CRM_Activities a WITH(NOLOCK) on b.DocID=a.NodeID 
		  left join COM_Status S WITH(NOLOCK)  on a.StatusID=s.StatusID    
		  left join adm_users u WITH(NOLOCK)  on u.UserID=a.AssignUserID    
		  LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID='+CONVERT(NVARCHAR,@LangID)+'       
		  WHERE c.DocID='+CONVERT(NVARCHAR,@DocID) +'  and c.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)  
		EXEC (@SQL)  
		SELECT 1 WHERE 1<>1  
		END
		else  
		begin  
			SELECT 1 WHERE 1<>1
			SELECT 1 WHERE 1<>1
		end    
 		
 		
        IF exists (SELECT Value  FROM @docPref  
		WHERE Name='Autopostdocument' and Value is not null and Value<>'' and isnumeric(Value)=1
		and convert(int,Value)>40000)
		or (@doctype=33 and exists (SELECT Value  FROM @docPref  
		WHERE Name='AutoProduceDoc' and Value is not null and Value<>'' and isnumeric(Value)=1
		and convert(int,Value)>40000))
		BEGIN 
			select distinct b.costcenterid,b.DocID,b.DocPrefix,b.DocNumber,b.DebitAccount,b.CreditAccount,b.voucherno from INV_DocDetails a WITH(NOLOCK) 
			join INV_DocDetails b WITH(NOLOCK) on A.InvDocDetailsId=b.refnodeid and b.refccid=300
			where a.CostCenterID=@CostCenterID AND a.DocID=@DocID 
		END	
		ELSE
			SELECT 1 WHERE 1<>1
		
		--Getting Executed Qty
		set @WHERE=NULL
		select @WHERE=lastvaluevouchers from adm_costcenterdef  WITH(NOLOCK) 
		where costcenterid=@CostCenterID and  linkdata=50455 and LocalReference=79  
		if(@WHERE is not null or exists (SELECT Value  FROM @docPref  
		WHERE Name='ShowLinkStatus' and Value='true'))
		BEGIN
			declare @table table(CCID int)
			if(@WHERE is not null and @WHERE<>'')      
				insert into @table  
				exec SPSplitString @WHERE,','  
			ELSE
				insert into @table  
				select CostcenterID from adm_documenttypes with(nolock)
			
			select a.InvDocDetailsID,a.Quantity,a.VoucherType,isnull(sum(isnull(y.LinkedFieldValue,0)),0) as ExecutedQty 	
			FROM  [INV_DocDetails] a WITH(NOLOCK) 
			left JOIN [INV_DocDetails] y WITH(NOLOCK) on y.LinkedInvDocDetailsID=a.InvDocDetailsID and y.StatusID<>376
			left join @table b on y.CostCenterID=b.CCID
			WHERE a.CostCenterID=@CostCenterID AND a.DocID=@DocID  
			and (y.LinkedFieldName is null or y.LinkedFieldName='Quantity')
			and (y.StatusID is null or y.StatusID<>376)
			and (y.CostCenterID is null or y.CostCenterID=b.CCID)
			group by a.InvDocDetailsID,a.Quantity,a.VoucherType
		END
		ELSE
			SELECT 1 WHERE 1<>1
			
		if(@doctype=30 and exists (SELECT Value  FROM @docPref  
		WHERE Name='UseasAssemble/DisAssembly' and Value='true'))
		BEGIN
			select pb.ProductID,case when p.kitsize is not null and p.kitsize>1 THEN pb.Quantity/p.kitsize ELSE pb.Quantity end Quantity,pb.ParentProductID
			 from   [INV_DocDetails] a WITH(NOLOCK)  
			join INV_ProductBundles pb WITH(NOLOCK) on a.ProductID=pb.parentproductid
			join inv_product p on pb.parentproductid=p.ProductID
			WHERE a.CostCenterID=@CostCenterID AND a.DocID=@DocID
		END	
		ELSE
			SELECT 1 WHERE 1<>1	
		
		if exists (SELECT Value  FROM @docPref  
		WHERE Name in ('UseQtyAdjustment','DocQtyAdjustment') and Value='true')
		BEGIN	
			select a.*
			from COM_DocQtyAdjustments a WITH(NOLOCK)  
			WHERE a.DocID=@DocID
		END	
		ELSE
			SELECT 1 WHERE 1<>1	
			
		select a.InvDocDetailsID,a.BinID,a.Quantity,a.Remarks,a.RefInvDocDetailsID
		from   INV_BinDetails a WITH(NOLOCK)  
		join INV_DocDetails b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
		WHERE b.CostCenterID=@CostCenterID AND b.DocID=@DocID
		
		IF exists (SELECT Value  FROM @docPref  
		WHERE Name='enableChequeReturnHistory' and Value='true')
		BEGIN 	 
			SELECT [DocNo],[DocSeqNo],[AccountID],[AdjAmount],[AdjCurrID],[AdjExchRT]
			,[IsNewReference],[RefDocNo],[RefDocSeqNo],convert(datetime,RefDocDate) RefDocDate,convert(datetime,RefDocDueDate) RefDocDueDate
			,[Narration],[AmountFC],IsDocPDC FROM COM_ChequeReturn WITH(NOLOCK)
			WHERE DocNo=@VoucherNo
		END
		ELSE
			SELECT 1 WHERE 1<>1
			
		--Workflow Details
		--@isLinewise
		SELECT @WID=WorkflowID FROM [Inv_DocDetails] WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND DocID=@DocID		
		IF @isLinewise!=1 and @WID is not null and @WID>0
		begin
			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=@CostCenterID AND CCNodeID=@DocID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
			--select @WID WID,W.levelID,W.LevelName
			--from COM_WorkFlowDef A WITH(nolock)
			--inner join COM_WorkFlow W with(nolock) on W.WorkFlowID=a.WorkFlowID and W.LevelID=A.LevelID
			--where A.CostCenterID=@CostCenterID and W.WorkFlowID=@WID
			--group by W.levelID,W.LevelName
		end
		else
		begin
			select 1 WF where 1!=1
			select 1 WFL where 1!=1
		end
		
		select a.*,c.UnitName from INV_DocExtraDetails a
		join INV_DocDetails b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
		left join COM_UOM c WITH(NOLOCK) on c.UOMID=a.Unit
		WHERE b.CostCenterID=@CostCenterID AND b.DocID=@DocID
		
		IF exists (SELECT Value  FROM @docPref  
		WHERE Name='AllowAdjToDownPmt' and Value='true') or @doctype=38
		BEGIN 	 
			SELECT * FROM COM_BillWiseNonAcc WITH(NOLOCK)
			WHERE DocNo=@VoucherNo and refdocno<>''
		END
		ELSE
			SELECT 1 WHERE 1<>1
		
		select CostCenterID, DocumentType, DocumentTypeID, PrefName, PrefValue , PrefDefalutValue 
		from COM_DocumentPreferences with (nolock) where CostCenterID=40220 and PrefName = 'BidQuotationDocument'
		
		--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA    
		IF exists (SELECT Value  FROM @docPref  
		WHERE Name='AuditTrial' and Value='true')
		BEGIN        
			INSERT INTO INV_DocDetails_History_ATUser(DocType,DocID,VoucherNo,ActionType,ActionTypeID,UserID,CreatedBy,CreatedDate)  
			VALUES(@CostCenterID,@DocID,@VoucherNo,'View',1,@UserID,@UserName,CONVERT(FLOAT,GETDATE()))        
		END  
PRINT @doctype
SET NOCOUNT OFF;  
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
