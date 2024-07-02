USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetContract]
	@ContractID [int] = 0,
	@ContractPref [nvarchar](100) = NULL,
	@ContractNo [int] = 0,
	@CostCenterID [int] = 0,
	@RoleID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY                         
SET NOCOUNT ON 
                       
    declare @RenewRefID INT,@LinkedQuotationID INT,@isContractRenewed BIT,@PROPERTYID INT , @UnitID INT,@IVAR BIT,@Uname nvarchar(max),@sivccid int,@ProfileID int,@bankid int
    Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime,@IsRecurPosted bit,@isopening int
    
	declare @stat int,@table nvarchar(50),@sql nvarchar(max),@dimCid int,@salsDimID int,@colnames nvarchar(max),@AQueue BIT,@PLEOnReject BIT,@DisableReject bit
	set @DisableReject=0
	set @stat=0
	set @dimCid=0
	set @sivccid=0
	set @salsDimID=0
	
	if exists(select Value from COM_CostCenterPreferences WITH(NOLOCK)
	where Name='LineWiseSalesman' and Value='true')
	BEGIN
		select  @salsDimID=Value from COM_CostCenterPreferences WITH(NOLOCK)
		where Name='Salesman' and costcenterid=92 and Value is not null and Value<>''
		and ISNUMERIC(value)=1
	END
   
	select @stat=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where Name='PostDocStatus' and Value is not null and Value<>'' and ISNUMERIC(value)=1
    
	select @dimCid=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where Name='DimensionWiseContract' and costcenterid=95 and Value is not null and Value<>'' and ISNUMERIC(value)=1
    
    if(@CostCenterID=95)
		select @sivccid=Value from COM_CostCenterPreferences WITH(NOLOCK)
		where Name='ContractSalesInvoice' and costcenterid=95 and Value is not null and Value<>'' and ISNUMERIC(value)=1
    ELSE
		select @sivccid=Value from COM_CostCenterPreferences WITH(NOLOCK)
		where Name='PurchasePInvoice' and costcenterid=@CostCenterID and Value is not null and Value<>'' and ISNUMERIC(value)=1
                  
	IF(@ContractID = 0)                        
	BEGIN                        
		IF(@ContractPref is not null  and @ContractPref <> ''  AND  @ContractNo > 0)                        
			SELECT @ContractID = ContractID FROM  REN_CONTRACT WITH(NOLOCK) WHERE ContractPrefix  = @ContractPref AND ContractNumber = @ContractNo                        
	END 
	
	 
	SET @IVAR  = 0 
	IF NOT EXISTS(SELECT STATUS FROM [adm_featureactionrolemap] WITH(NOLOCK)     WHERE  FEATUREACTIONID = 3764 AND ROLEID=@RoleID)
	BEGIN
		IF   EXISTS( SELECT STATUSID FROM INV_DOCDETAILS  WITH(NOLOCK)   WHERE DOCID IN (SELECT DOCID FROM REN_CONTRACTDOCMAPPING WITH(NOLOCK) WHERE CONTRACTID = @ContractID AND ISACCDOC = 0   ) AND STATUSID = 371)
			SET @IVAR = 1 
		ELSE IF EXISTS( SELECT STATUSID FROM ACC_DOCDETAILS  WITH(NOLOCK)    WHERE DOCID IN (SELECT DOCID FROM REN_CONTRACTDOCMAPPING WITH(NOLOCK) WHERE CONTRACTID = @ContractID AND ISACCDOC = 1   ) AND STATUSID = 371)
			SET @IVAR = 1 
	END
	              
	set @isContractRenewed=0
	if exists(select ContractID FROM REN_CONTRACT WITH(NOLOCK) WHERE RenewRefID=@ContractID and StatusID<>451)
		set @isContractRenewed=1  
		                    
    SELECT @PROPERTYID = PropertyID,@StatusID=StatusID,@isopening=isopening, @UnitID = UNITID,@RenewRefID=RenewRefID,@LinkedQuotationID=QuotationID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
    FROM REN_CONTRACT WITH(NOLOCK) where ContractID = @ContractID
	
	SELECT @bankid=BankAccount FROM REN_Property WITH(NOLOCK) where NodeID=@PROPERTYID
	
		if(@WID is not null and @WID>0)  
		BEGIN 
			if exists(SELECT LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
					where WorkFlowID=@WID and LevelID<=@Level and FinancePost=1)
						set @DisableReject=1
						 
			SELECT @Userlevel=LevelID,@Type=type,@AQueue=AllowQueue FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and  UserID =@UserID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=type,@AQueue=AllowQueue  FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID

			if(@Userlevel is null )       
				SELECT @Userlevel=LevelID,@Type=type,@AQueue=AllowQueue  FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=type,@AQueue=AllowQueue FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID
			
			if(@Userlevel is null )  	
				SELECT @Type=type FROM [COM_WorkFlow] WITH(NOLOCK) where WorkFlowID=@WID
				
				select @PLEOnReject=PrevLvlOnReject FROM [COM_WorkFlow] W WITH(NOLOCK)
				where WorkFlowID=@WID and LevelID=@Level
		end 
     
		set @canEdit=1  
       
		if(@StatusID in(426,427,466))  
		begin  
			if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=0   
			end    
		end
		ELSE if(@StatusID=470)
		BEGIN
		    if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=1
			end
			ELSE
				set @canEdit=0
		END
     
  
		if(@StatusID not in(426,427,470,428,477,450))  
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
			
	if exists(select MapID from REN_ContractDocMapping DM WITH(NOLOCK)
		join COM_CCSchedules a WITH(NOLOCK) on DM.CostCenterID=a.CostCenterID
		join COM_SchEvents b WITH(NOLOCK) on a.ScheduleID=b.ScheduleID
		where a.NodeID=DM.DocID and DM.ContractID = @ContractID and b.statusid=2
		and (DM.TYPE = 1 OR DM.TYPE IS NULL) and (DM.isaccdoc = 0 OR DM.IsAccDoc  IS NULL ))
		 set @IsRecurPosted= 1
	ELSE
		 set @IsRecurPosted= 0
	
	DECLARE @Status NVARCHAR(MAX)
	
	SELECT @Status='['+CS.[Status]+']' FROM REN_Contract RC WITH(NOLOCK) 
	JOIN COM_Status CS WITH(NOLOCK) ON CS.StatusID=RC.StatusID
	WHERE RC.RenewRefID= @ContractID and RC.CostCenterid =  @CostCenterID  and RC.StatusID<>451
	
	SELECT @Status='['+CS.[Status]+']'+ISNULL(@Status,'') FROM REN_Contract RC WITH(NOLOCK) 
	JOIN COM_Status CS WITH(NOLOCK) ON CS.StatusID=RC.StatusID
	WHERE RC.ContractID= @ContractID and RC.CostCenterid =  @CostCenterID  
	
	SELECT     @IsRecurPosted IsRecurPosted,@isContractRenewed isContractRenewed,@IVAR IsApprove,ContractID, ContractPrefix, convert(datetime,ContractDate) ContractDate, ContractNumber, StatusID, PropertyID, UnitID, TenantID, RentAccID,                      
	IncomeAccID, Purpose, convert(datetime,StartDate) StartDate, convert(datetime, EndDate) EndDate, TotalAmount, NonRecurAmount, RecurAmount,  [GUID], LocationID , DivisionID , CurrencyID ,TermsConditions , SalesmanID , AccountantID,LandlordID , Narration,
	convert(datetime,TerminationDate) TerminationDate,convert(datetime,ExtendTill) ExtndTill ,convert(datetime,VacancyDate) VacancyDate ,BasedOn,QuotationID,
	ISNULL((SELECT TOP 1 Q.CostCenterID FROM REN_Quotation Q WITH(NOLOCK) WHERE Q.QuotationID=C.QuotationID),0) QuotationCCID,
	SNO ,(SELECT MAX(SNO) + 1 FROM REN_Contract) AS NEWSNO,RenewRefID,IsExtended,RentAmt,PendFinalSettl
	,@canEdit canEdit,@canApprove canApprove,WorkFlowID,WorkFlowLevel,@Userlevel userlevel,@DisableReject DisableReject,NoOfUnits,AgeOfRenewal,RecurDuration,Refno,parentContractID,@Status [Status]
	,convert(datetime,ExpectedEndDate) ExpectedEndDate,GracePeriod,IsOpening,wfaction,RenewSno,@AQueue AllowQueue,@PLEOnReject PrevLvlOnReject,WorkFlowQueue,convert(datetime,FitmentDate) FitmentDate,FMTAfterEndDate,convert(datetime,RefundDate) RefundDate
	,ProposedRent ,ProposedDisc,ProposedAfterDisc,ProposedDailyRent,ProposedDiscPer,Variance,InvType,@bankid bankid
	FROM REN_Contract C WITH(NOLOCK) 
	where ContractID = @ContractID and CostCenterid =    @CostCenterID                 
    
    
    set @colnames=''
	SELECT @colnames=@colnames+',CP.'+SYSCOLUMNNAME	FROM ADM_CostCenterDef with(nolock) 
	WHERE COSTCENTERID=@CostCenterID  and SYSCOLUMNNAME like 'CCNID%'
	and SysTableName='REN_ContractParticulars'

                      
	set @sql='SELECT    DISTINCT  CP.NodeID, CP.ContractID, CP.CCID, CP.CCNodeID, CP.CreditAccID, CP.ChequeNo, convert(datetime,CP.ChequeDate) ChequeDate, CP.PayeeBank,                      
	CP.DebitAccID, CP.RentAmount RentAmount,CP.TasjeelAmount, CP.Discount DiscountAmount, CP.Amount, UNT.RENT RENTAMT , CASE WHEN UNT.DISCOUNTPERCENTAGE = -100 THEN UNT.DISCOUNTAMOUNT ELSE (UNT.RENT  * UNT.DISCOUNTPERCENTAGE) / 100 END  DICOUNT,   CP.GUID                         
	,cp.UnitsXml,CP.SPType,TaxableAmt,NonTaxAmount,CP.RecurInvoice,CP.PostDebit,CP.InclChkGen,CP.VatPer,CP.VatAmount, ACC.ACCOUNTNAME CREDITNAME , ACCD.ACCOUNTNAME  DEBITNAME ,CP.IsRecurr ,PARTP.Refund  ,PART.Refund UnitRefund , Sts.Status StatusID'
		
	if exists(select * from adm_globalpreferences
	where name ='VATVersion')					
		set @sql=@sql+' ,Tx.Name TaxCategory,SPT.Name SPTypeName'
	ELSE
		set @sql=@sql+' ,'''' TaxCategory,'''' SPTypeName'
		
	set @sql=@sql+',CP.TaxCategoryID,CP.VatType, Doc.VoucherNo ,Doc.DocPrefix DocPrefix ,Doc.DocNumber DocNumber , doc.CostCenterID                       
	CostCenterID, ADF.DocumentName DocumentName ,Doc.DocID DocID , Doc.StatusID  DocStatusID,CP.Narration,cp.Detailsxml,cp.AdvanceAccountID,CP.Sqft,CP.Rate                 
	,cp.LocationID,loc.name locname,PARTP.Display  ,PART.Display UnitDisplay
	,PARTP.Months  ,PART.Months UnitMonths,PARTP.DiscountPercentage  ,PART.DiscountPercentage UnitDiscountPercentage
	
	,cp.DimNodeID,cp.SalesManID,CP.NetAmount'
	
	if (@dimCid>50000)
		set @sql=@sql+' ,Dim.Name Dimname'
	ELSE
		set @sql=@sql+' ,'''' Dimname'
	
	if (@salsDimID>50000)
		set @sql=@sql+' ,SalesDim.Name SalesManname'
	ELSE
		set @sql=@sql+' ,'''' SalesManname'

	set @sql=@sql+@colnames+' FROM REN_ContractParticulars  CP WITH(NOLOCK)
	LEFT JOIN REN_CONTRACT CNT WITH(NOLOCK) ON CP.CONTRACTID = CNT.CONTRACTID  
	LEFT JOIN Com_location Loc WITH(NOLOCK) ON Loc.NodeID = CP.LocationID  
	LEFT JOIN REN_UNITS UNT WITH(NOLOCK) ON CNT.UNITID = UNT.UNITID                          
	LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.CreditAccID                         
	LEFT JOIN ACC_Accounts ACCD WITH(NOLOCK) ON ACCD.ACCOUNTID = CP.DebitAccID                         
	LEFT JOIN REN_Particulars PART WITH(NOLOCK) ON CP.CCNODEID = PART.ParticularID  and  PART.PropertyID = '+convert(nvarchar(max),@PROPERTYID)+' AND PART.UNITID ='+convert(nvarchar(max), @UnitID)+'
	LEFT JOIN REN_Particulars PARTP WITH(NOLOCK) ON CP.CCNODEID = PARTP.ParticularID  and  PARTP.PropertyID =  '+convert(nvarchar(max),@PROPERTYID)+' AND PARTP.UNITID = 0 '
	
	if (@salsDimID>50000)
    BEGIN
		select @table=tablename from adm_features with(NOLOCK) where featureid=@salsDimID
		set @sql=@sql+' LEFT JOIN '+@table+' SalesDim WITH(NOLOCK) ON SalesDim.NodeID=cp.SalesManID '
	END
	
	if (@dimCid>50000)
    BEGIN
		select @table=tablename from adm_features with(NOLOCK) where featureid=@dimCid
		set @sql=@sql+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=cp.DimNodeID '
	    set @sql=@sql+'LEFT JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON CP.ContractID = CDM.ContractID 
	    AND CP.DimNodeID = CDM.DimID and CDM.Costcenterid = '+convert(nvarchar(max),@sivccid) +'  and CDM.isaccdoc = 0   AND CDM.ContractCCID = '+convert(nvarchar(max),@CostCenterID)
    END
    else
		set @sql=@sql+'LEFT JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON CP.ContractID = CDM.ContractID AND CP.SNO = CDM.SNO  and CDM.isaccdoc = 0  and CDM.Costcenterid = '+convert(nvarchar(max),@sivccid) +'  AND CDM.ContractCCID = '+convert(nvarchar(max),@CostCenterID)
	
    if exists(select * from adm_globalpreferences
	where name ='VATVersion')					
		set @sql=@sql+' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=CP.TaxCategoryID  LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=CP.SPType '
    
   
	set @sql=@sql+' LEFT JOIN Inv_DocDetails Doc WITH(NOLOCK) on  CDM.DocID =  Doc.DocID                         
	left join ADM_DocumentTypes ADF WITH(NOLOCK) on Doc.CostCenterID = ADF.CostCenterID                  
	LEFT JOIN Com_Status Sts WITH(NOLOCK) on  Sts.StatusID =  Doc.StatusID                      
	where  CP.ContractID ='+convert(nvarchar(max),@ContractID) +' --and CDM.TYPE = 1 and CDM.isaccdoc = 0           
	
	and (CDM.TYPE = 1 OR CDM.TYPE IS NULL) and (CDM.isaccdoc = 0 OR CDM.IsAccDoc  IS NULL )'
	
	exec(@sql)
	
	
	set @colnames=''
	SELECT @colnames=@colnames+',CP.'+SYSCOLUMNNAME	FROM ADM_CostCenterDef with(nolock) 
	WHERE COSTCENTERID=@CostCenterID  and SYSCOLUMNNAME like 'CCNID%'
	and SysTableName='REN_ContractPayTerms'

	if exists(select * from sys.columns
	where object_id('REN_ContractDocMapping')=object_id and name='IsFreezed')
	BEGIN
		set @sql=' SELECT   DISTINCT Doc.AccDocDetailsid,IsFreezed,CP.SNO, CP.NodeID, CP.ContractID, CP.ChequeNo, Convert(datetime,CP.ChequeDate) ChequeDate , CP.CustomerBank, CP.DebitAccID, CP.Amount ,  CP.GUID ,                      
		Period,ACC.AccountName DebitAccName , CP.Narration , Sts.Status StatusID   , Doc.VoucherNo ,Doc.DocPrefix DocPrefix ,Doc.DocNumber DocNumber , doc.CostCenterID CostCenterID,cp.Particular
		, Convert(datetime,CP.FromDate) FromDate, Convert(datetime,CP.TillDate) TillDate,  ADF.DocumentName DocumentName,Doc.OpPdcStatus,Doc.DocID DocID , Doc.StatusID   DocStatusID,Doc.DocumentType  DocumentType,Doc.BillDate BillNo,Convert(datetime,Doc.DocDate) PostingDate,RentAmount,cp.LocationID,loc.name locname,
		VatType ,DimNodeID,SalesManID'+@colnames+'
		FROM         REN_ContractPayTerms CP WITH(NOLOCK)
		JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.DebitAccID
		left JOIN Com_location Loc WITH(NOLOCK) ON Loc.NodeID = CP.LocationID
		JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON CP.ContractID = CDM.ContractID 
		JOIN Acc_DocDetails Doc WITH(NOLOCK) on  CDM.DocID =  Doc.DocID 
		join ADM_DocumentTypes ADF WITH(NOLOCK) on Doc.CostCenterID = ADF.CostCenterID                        
		JOIN Com_Status Sts WITH(NOLOCK) on  Sts.StatusID =  Doc.StatusID                         
		where CP.ContractID = '+convert(NVARCHAR(MAX),@ContractID)+' and CDM.ContractCCID =   '+convert(NVARCHAR(MAX),@CostCenterID)+' 
		and ((IsFreezed=0 and CDM.TYPE = 2  and CDM.docTYPE = 2 
		and (Doc.debitaccount=CP.DebitAccID or Doc.BankAccountID=CP.DebitAccID) and Doc.amount=CP.amount and Doc.ChequeNumber=CP.ChequeNo)
		or (IsFreezed=1 and (CDM.TYPE = 2  OR    CDM.TYPE  IS NULL) AND CP.SNO = CDM.SNO))
		order by IsFreezed,CP.SNO,Doc.AccDocDetailsid '
		print @sql
		exec(@sql)
	END
	else if @isopening<>1 and exists(select Value from COM_CostCenterPreferences WITH(NOLOCK)
	where CostCenterID=95 and CostCenterID=@CostCenterID and Name='SinglePDC' and Value ='true' )
	BEGIN
		set @sql='SELECT   DISTINCT Doc.AccDocDetailsid,CP.SNO, CP.NodeID, CP.ContractID, CP.ChequeNo, Convert(datetime,CP.ChequeDate) ChequeDate , CP.CustomerBank, CP.DebitAccID, CP.Amount ,  CP.GUID ,                      
		Period,ACC.AccountName DebitAccName , CP.Narration , Sts.Status StatusID   , Doc.VoucherNo ,Doc.DocPrefix DocPrefix ,Doc.DocNumber DocNumber , doc.CostCenterID CostCenterID,cp.Particular
		, Convert(datetime,CP.FromDate) FromDate, Convert(datetime,CP.TillDate) TillDate,  ADF.DocumentName DocumentName,Doc.OpPdcStatus,Doc.DocID DocID , Doc.StatusID   DocStatusID,Doc.DocumentType  DocumentType,Doc.BillDate BillNo,Convert(datetime,Doc.DocDate) PostingDate,RentAmount,cp.LocationID,loc.name locname,
		VatType ,DimNodeID,SalesManID'+@colnames+'
		FROM         REN_ContractPayTerms CP WITH(NOLOCK)
		JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.DebitAccID
		left JOIN Com_location Loc WITH(NOLOCK) ON Loc.NodeID = CP.LocationID
		JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON CP.ContractID = CDM.ContractID 
		JOIN Acc_DocDetails Doc WITH(NOLOCK) on  CDM.DocID =  Doc.DocID 
		join ADM_DocumentTypes ADF WITH(NOLOCK) on Doc.CostCenterID = ADF.CostCenterID                        
		JOIN Com_Status Sts WITH(NOLOCK) on  Sts.StatusID =  Doc.StatusID                         
		where CP.ContractID = '+convert(NVARCHAR(MAX),@ContractID)+'     and CDM.TYPE = 2  and CDM.docTYPE = 2 and CDM.ContractCCID =   '+convert(NVARCHAR(MAX),@CostCenterID)+'   
		and (Doc.debitaccount=CP.DebitAccID or Doc.BankAccountID=CP.DebitAccID) and Doc.amount=CP.amount and Doc.ChequeNumber=CP.ChequeNo
		order by CP.SNO ,Doc.AccDocDetailsid'
		exec(@sql)
	END
	ELSE
	BEGIN
		set @sql='SELECT   DISTINCT ISNULL(CDM.SNO,CP.SNO) SNO, CP.NodeID, CP.ContractID, CP.ChequeNo, Convert(datetime,CP.ChequeDate) ChequeDate , CP.CustomerBank, CP.DebitAccID, CP.Amount ,  CP.GUID ,                      
		Period,ACC.AccountName DebitAccName , CP.Narration , Sts.Status StatusID   , Doc.VoucherNo ,Doc.DocPrefix DocPrefix ,Doc.DocNumber DocNumber , doc.CostCenterID CostCenterID,cp.Particular
		, Convert(datetime,CP.FromDate) FromDate, Convert(datetime,CP.TillDate) TillDate,  ADF.DocumentName DocumentName,Doc.OpPdcStatus,Doc.DocID DocID ,case when Doc.documenttype=16 then DOC.OpPdcStatus else Doc.StatusID  end DocStatusID,Doc.DocumentType  DocumentType,Doc.BillDate BillNo,Convert(datetime,Doc.DocDate) PostingDate,RentAmount,cp.LocationID,loc.name locname
		,VatType ,DimNodeID,SalesManID'+@colnames+'
		FROM         REN_ContractPayTerms CP WITH(NOLOCK)
		LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.DebitAccID
		LEFT JOIN Com_location Loc WITH(NOLOCK) ON Loc.NodeID = CP.LocationID
		LEFT JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON CP.ContractID = CDM.ContractID AND CP.SNO = CDM.SNO  and CDM.ContractCCID = '+convert(NVARCHAR(MAX),@CostCenterID)+'                
		LEFT JOIN Acc_DocDetails Doc WITH(NOLOCK) on  CDM.DocID =  Doc.DocID                         
		LEFT join ADM_DocumentTypes ADF WITH(NOLOCK) on Doc.CostCenterID = ADF.CostCenterID                        
		LEFT JOIN Com_Status Sts WITH(NOLOCK) on  Sts.StatusID =  Doc.StatusID                         
		where CP.ContractID = '+convert(NVARCHAR(MAX),@ContractID)+' --and CDM.TYPE = 2                        
		and (CDM.TYPE = 2  OR    CDM.TYPE  IS NULL )        
		order by SNO '
		exec(@sql)
	END  


	--Getting data from Contract extended table                    
	SELECT * FROM  REN_ContractExtended WITH(NOLOCK)                     
	WHERE NodeID=@ContractID                    

	-- GETTING COSTCENTER DATA                     
	SELECT * FROM  COM_CCCCDATA WITH(NOLOCK)                     
	WHERE NodeID=@ContractID and CostCenterID = @CostCenterID                     
	
	EXEC [spCOM_GetAttachments] @CostCenterID,@ContractID,@UserID
	      
	--Getting Notes
	SELECT     NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate, 
	ModifiedBy,  convert(datetime,ModifiedDate) ModifiedDate, CostCenterID
	FROM         COM_Notes WITH(NOLOCK) 
	WHERE FeatureID=95 and  FeaturePK=@ContractID
	
	if exists(select Value from COM_CostCenterPreferences WITH(NOLOCK) where CostCenterID=95 and Name ='EnableActivities' and Value='true')
	BEGIN
	
		IF(EXISTS(SELECT CostCenterID FROM CRM_Activities WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND NodeID=@ContractID))
			EXEC spCRM_GetFeatureByActvities @ContractID,@CostCenterID,'',@UserID,@LangID  
		ELSE
			SELECT 1 WHERE 1<>1 
				
		--SELECT     L.CONTRACTID as LeadID, A.ActivityID, A.ActivityTypeID, A.ScheduleID, A.CostCenterID, A.NodeID, A.StatusID AS ActStatus, A.Subject AS ActSubject, A.Priority, 
		--A.PctComplete, A.Location, A.IsAllDayActivity,  CONVERT(datetime, A.ActualCloseDate) AS ActualCloseDate, A.ActualCloseTime, A.CustomerID, 
		--A.Remarks, A.AssignUserID, A.AssignRoleID, A.AssignGroupID,CONVERT(datetime, A.StartDate) AS ActStartDate, 
		--CONVERT(datetime, A.EndDate) AS ActEndDate,  A.StartTime AS ActStartTime, A.EndTime AS ActEndTime, S.ScheduleID AS Expr10, S.Name, S.StatusID AS Expr11, S.FreqType, S.FreqInterval, 
		--S.FreqSubdayType, S.FreqSubdayInterval, S.FreqRelativeInterval, S.FreqRecurrenceFactor, CONVERT(datetime, S.StartDate) AS CStartDate, 
		--CONVERT(datetime, S.EndDate) AS CEndDate, CONVERT(datetime, S.StartTime) AS StartTime, CONVERT(datetime, S.EndTime) AS EndTime, 
		--S.Message,case when A.ActivityTypeID=1 then 'AppointmentRegular' 
		--when A.ActivityTypeID=2 then 'TaskRegular' 
		--when A.ActivityTypeID=3 then 'ApptRecurring' 
		--when A.ActivityTypeID=4 then 'TaskRecur' end as Activity ,[Alpha1],[Alpha2],[Alpha3],[Alpha4],[Alpha5],[Alpha6],[Alpha7],[Alpha8],[Alpha9],[Alpha10],[Alpha11],[Alpha12],[Alpha13],[Alpha14][Alpha15],[Alpha16],[Alpha17]
		--,[Alpha18],[Alpha19],[Alpha20],[Alpha21],[Alpha22],[Alpha23],[Alpha24],[Alpha25],[Alpha26],[Alpha27],[Alpha28],[Alpha29],[Alpha30],[Alpha31]
		--,[Alpha32],[Alpha33],[Alpha34],[Alpha35],[Alpha36],[Alpha37],[Alpha38],[Alpha39],[Alpha40],[Alpha41],[Alpha42]
		--,[Alpha43],[Alpha44],[Alpha45],[Alpha46],[Alpha47],[Alpha48],[Alpha49],[Alpha50]
		--FROM         CRM_Activities AS A WITH(NOLOCK) LEFT OUTER JOIN
		--REN_CONTRACT AS L WITH(NOLOCK) ON L.CONTRACTID = A.NodeID AND A.CostCenterID = 95 LEFT OUTER JOIN
		--COM_Schedules AS S WITH(NOLOCK) ON S.ScheduleID = A.ScheduleID LEFT OUTER JOIN
		--COM_CCSchedules AS CS WITH(NOLOCK) ON CS.ScheduleID = A.ScheduleID
		--WHERE     (L.CONTRACTID =  @ContractID)
	END
	ELSE
		select 1 where 1<>1
	select @Uname=Name from REN_Units WITH(NOLOCK)	where UnitID=@UnitID
	
	select UnitID,@Uname uname from REN_Contract WITH(NOLOCK)	
	where refcontractid=@ContractID

	if(@stat>50000)
	BEGIN
		select @table=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@stat
		set @sql='select a.DOCID,b.dcCCNID'+convert(nvarchar,(@stat-50000))+' ID,c.Name from ACC_DocDetails a WITH(NOLOCK)
		join COM_DocCCData b WITH(NOLOCK)on a.AccDocDetailsID=b.AccDocDetailsID
		join '+@table+' c WITH(NOLOCK) on b.dcCCNID'+convert(nvarchar,(@stat-50000))+'=c.NOdeID
		JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON  a.DOCID=CDM.docid 
		where a.refccid='+convert(nvarchar,@CostCenterID)+' and a.RefNOdeID = CDM.ContractID  and  a.RefNOdeID='+convert(nvarchar,@ContractID)+' and CDM.TYPE = 2 
		UNION ALL
		select a.DOCID,b.dcCCNID'+convert(nvarchar,(@stat-50000))+' ID,c.Name from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData b WITH(NOLOCK)on a.INVDocDetailsID=b.INVDocDetailsID
		join '+@table+' c WITH(NOLOCK) on b.dcCCNID'+convert(nvarchar,(@stat-50000))+'=c.NOdeID
		JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON  a.DOCID=CDM.docid 
		where a.refccid='+convert(nvarchar,@CostCenterID)+' and a.RefNOdeID = CDM.ContractID and  a.RefNOdeID='+convert(nvarchar,@ContractID)+'  and CDM.TYPE = 1 '
		print @sql
		exec(@sql)	
	END
	ELSE
		select 1 where 1<>1

	if (@dimCid>50000 or @salsDimID>50000)
    BEGIN
		
		
		set @sql=' select cp.DimNodeID,cp.SalesManID '
		if (@dimCid>50000)		
			set @sql=@sql+' ,Dim.Name Dimname '
		else
			set @sql=@sql+','''' Dimname'
		
		if (@salsDimID>50000)		
			set @sql=@sql+' ,SalesDim.Name SalesManname '
		else
			set @sql=@sql+','''' SalesManname'
				
	 	
		set @sql=@sql+' FROM    REN_ContractPayTerms CP WITH(NOLOCK) '
		if(@dimCid>0)
		BEGIN
			select @table=tablename from adm_features with(NOLOCK) where featureid=@dimCid			
			set @sql=@sql+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=cp.DimNodeID '			
		END	
		
		if(@salsDimID>0)
		BEGIN
			select @table=tablename from adm_features with(NOLOCK) where featureid=@salsDimID
			set @sql=@sql+' LEFT JOIN '+@table+' SalesDim WITH(NOLOCK) ON SalesDim.NodeID=cp.SalesManID '
		END
		
		set @sql=@sql+' where CP.ContractID = '+convert(nvarchar(max),@ContractID)
		
		exec(@sql)
    END
    else
		select 1 where 1<>1
		 
	IF @WID is not null and @WID>0
	begin
			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=@CostCenterID AND CCNodeID=@ContractID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
	end
	else
	BEGIN
		select 1 where 1<>1
		select 1 where 1<>1
	END	
	
	if exists(select * from COM_DocFlow WITH(NOLOCK) where RefCCID=95 and RefNodeID=@ContractID)
	BEGIN
		set @ProfileID=0	 
		select @ProfileID=Value from COM_CostCenterPreferences WITH(NOLOCK)
		where Name='TermProfile' and CostCenterID=95 and Value is not null and Value<>'' and isnumeric(Value)=1
		if(@ProfileID>0)
		BEGIN		
			exec [spDOC_GetDocFlow] @ProfileID =@ProfileID,
									@RefCCID =95,
									@RefNodeID=@ContractID,	
									@LangID=@LangID
		 END 
		 else
			BEGIN
				select 1 where 1<>1
			END	 
    END
	 else
			BEGIN
				select 1 where 1<>1
			END	
	EXEC [spCOM_GetCCCCMapDetails] 95,@ContractID,@LangID
                 
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
