USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetQuotation]
	@QuotationID [int] = 0,
	@RoleID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
                        
BEGIN TRY                         
SET NOCOUNT ON 

	declare @ccid int,@ContractExists bit,@dimCid int,@table nvarchar(100),@colnames NVARCHAR(MAX),@bankid int
	Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
	DECLARE @Status NVARCHAR(MAX),@sql NVARCHAR(MAX),@PROPERTYID INT , @UnitID INT,@AQueue BIT,@PLEOnReject BIT

	set @ContractExists=0            
	SELECT @ccid=CostCenterID,@PROPERTYID = PropertyID,@UnitID = UNITID
	,@StatusID=StatusID, @WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
	 FROM  REN_Quotation WITH(NOLOCK) where QuotationID = @QuotationID
	
	SELECT @bankid=BankAccount FROM REN_Property WITH(NOLOCK) where NodeID=@PROPERTYID

 
	select @dimCid=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where Name='DimensionWiseContract' and costcenterid=95 and Value is not null and Value<>'' and ISNUMERIC(value)=1

	if exists(SELECT ContractID FROM  REN_Contract WITH(NOLOCK) where QuotationID = @QuotationID)
		set @ContractExists=1
	else if(@ccid=103 and exists(SELECT QuotationID FROM  REN_Quotation WITH(NOLOCK) where LinkedQuotationID = @QuotationID))
		set @ContractExists=1	

	if(@WID is not null and @WID>0)  
		BEGIN  
			SELECT @Userlevel=LevelID,@Type=type,@AQueue=AllowQueue FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and  UserID =@UserID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=type,@AQueue=AllowQueue FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID

			if(@Userlevel is null )       
				SELECT @Userlevel=LevelID,@Type=type,@AQueue=AllowQueue FROM [COM_WorkFlow] W WITH(NOLOCK)
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
       
		if(@StatusID in(467,468,466,426))  
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
  
		if(@StatusID in(440,466))  
		begin    
			if(@Userlevel is not null and  @Level is not null and @Userlevel>@level)  
			begin
				if(@Type=1 or @Level+1=@Userlevel)
					set @canApprove=1   
				ELSE
				BEGIN
					if exists(select EscDays FROM [COM_WorkFlow] WITH(NOLOCK)
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
	
	
	SELECT @Status='['+CS.[Status]+']' FROM REN_Contract RC WITH(NOLOCK) 
	JOIN COM_Status CS WITH(NOLOCK) ON CS.StatusID=RC.StatusID
	WHERE RC.QuotationID= @QuotationID  
	
	SELECT @Status='['+CS.[Status]+']'+ISNULL(@Status,'') FROM REN_Quotation RQ WITH(NOLOCK) 
	JOIN COM_Status CS WITH(NOLOCK) ON CS.StatusID=RQ.StatusID
	WHERE RQ.QuotationID= @QuotationID 
			
	SELECT QuotationID ContractID, Prefix ContractPrefix, convert(datetime,Date) ContractDate,Number ContractNumber, StatusID, PropertyID, UnitID, TenantID, RentAccID,                      
	IncomeAccID, Purpose, convert(datetime,StartDate) StartDate,  convert(datetime,ExtendTill) ExtndTill,convert(datetime, EndDate) EndDate, TotalAmount, NonRecurAmount, RecurAmount,  [GUID], LocationID , DivisionID , CurrencyID ,TermsConditions , SalesmanID , AccountantID,LandlordID , Narration,
	BasedOn,SNO,@ContractExists ContractExists,RefQuotation,multiName,CostCenterID,LinkedQuotationID QuotationID
	,@canEdit canEdit,@canApprove canApprove,WorkFlowID,WorkFlowLevel,@Userlevel Userlevel,NoOfUnits,RecurDuration,@Status [Status]
	,convert(datetime,ExpectedEndDate) ExpectedEndDate,GracePeriod,@AQueue AllowQueue,@PLEOnReject PrevLvlOnReject,@bankid bankid
	,ProposedRent ,ProposedDisc ,ProposedAfterDisc ,ProposedDiscPer ,Variance 
	
	 FROM  REN_Quotation WITH(NOLOCK) where QuotationID = @QuotationID
     
     set @colnames=''
	SELECT @colnames=@colnames+',CP.'+SYSCOLUMNNAME	FROM ADM_CostCenterDef with(nolock) 
	WHERE COSTCENTERID=@ccid  and SYSCOLUMNNAME like 'CCNID%'
	and SysTableName='REN_QuotationParticulars'
     
     set @sql='SELECT    DISTINCT  CP.NodeID, CP.QuotationID ContractID, CP.CCID, CP.CCNodeID, CP.CreditAccID, CP.ChequeNo, convert(datetime,CP.ChequeDate) ChequeDate, CP.PayeeBank,                      
	CP.DebitAccID, CP.RentAmount RentAmount, CP.Discount DiscountAmount, CP.Amount, UNT.RENT RENTAMT , CASE WHEN UNT.DISCOUNTPERCENTAGE = -100 THEN UNT.DISCOUNTAMOUNT ELSE (UNT.RENT  * UNT.DISCOUNTPERCENTAGE) / 100 END  DICOUNT                         
	,CP.SPType,CP.TaxableAmt,CP.RecurInvoice,CP.InclChkGen,CP.VatPer,CP.VatAmount, ACC.ACCOUNTNAME CREDITNAME , ACCD.ACCOUNTNAME  DEBITNAME ,CP.IsRecurr ,PARTP.Refund  ,PART.Refund UnitRefund , Sts.Status StatusID'
		
	if exists(select * from adm_globalpreferences
	where name ='VATVersion')					
		set @sql=@sql+' ,Tx.Name TaxCategory,SPT.Name SPTypeName'
	ELSE
		set @sql=@sql+' ,'''' TaxCategory,'''' SPTypeName'

	if (@dimCid>50000)
		set @sql=@sql+' ,Dim.Name Dimname'
	ELSE
		set @sql=@sql+' ,'''' Dimname'
	
	set @sql=@sql+',CP.TaxCategoryID,CP.VatType, Doc.VoucherNo ,Doc.DocPrefix DocPrefix ,Doc.DocNumber DocNumber , doc.CostCenterID                       
	CostCenterID, ADF.DocumentName DocumentName ,Doc.DocID DocID , Doc.StatusID  DocStatusID,CP.Narration,cp.Detailsxml,CP.Sqft,CP.Rate                 
	,cp.UnitsXml,cp.LocationID,loc.name locname,cp.DimNodeID,CP.NetAmount,PARTP.Display  ,PART.Display UnitDisplay,PARTP.PostDebit PropPostDebit ,PART.PostDebit UnitPostDebit'
	
	set @sql=@sql+@colnames+' FROM REN_QuotationParticulars  CP WITH(NOLOCK)
	LEFT JOIN REN_Quotation CNT WITH(NOLOCK) ON CP.QuotationID = CNT.QuotationID  
	LEFT JOIN Com_location Loc WITH(NOLOCK) ON Loc.NodeID = CP.LocationID  
	LEFT JOIN REN_UNITS UNT WITH(NOLOCK) ON CNT.UNITID = UNT.UNITID                          
	LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.CreditAccID                         
	LEFT JOIN ACC_Accounts ACCD WITH(NOLOCK) ON ACCD.ACCOUNTID = CP.DebitAccID                         
	LEFT JOIN REN_Particulars PART WITH(NOLOCK) ON CP.CCNODEID = PART.ParticularID  and  PART.PropertyID = '+convert(nvarchar(max),@PROPERTYID)+' AND PART.UNITID ='+convert(nvarchar(max), @UnitID)+'
	LEFT JOIN REN_Particulars PARTP WITH(NOLOCK) ON CP.CCNODEID = PARTP.ParticularID  and  PARTP.PropertyID =  '+convert(nvarchar(max),@PROPERTYID)+' AND PARTP.UNITID = 0 '
	if (@dimCid>50000)
    BEGIN
		select @table=tablename from adm_features with(NOLOCK) where featureid=@dimCid
		set @sql=@sql+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=cp.DimNodeID '
    END

	set @sql=@sql+'LEFT JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON CP.QuotationID = CDM.ContractID AND CP.SNO = CDM.SNO  and CDM.isaccdoc = 0   AND CDM.ContractCCID = '+convert(nvarchar(max),@ccid)
	
    if exists(select * from adm_globalpreferences
	where name ='VATVersion')					
		set @sql=@sql+' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=CP.TaxCategoryID  LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=CP.SPType '
    
   
	set @sql=@sql+' LEFT JOIN Inv_DocDetails Doc WITH(NOLOCK) on  CDM.DocID =  Doc.DocID                         
	left join ADM_DocumentTypes ADF WITH(NOLOCK) on Doc.CostCenterID = ADF.CostCenterID                  
	LEFT JOIN Com_Status Sts WITH(NOLOCK) on  Sts.StatusID =  Doc.StatusID                      
	where  CP.QuotationID ='+convert(nvarchar(max),@QuotationID) +' --and CDM.TYPE = 1 and CDM.isaccdoc = 0           
	and (CDM.TYPE = 1 OR CDM.TYPE IS NULL) and (CDM.isaccdoc = 0 OR CDM.IsAccDoc  IS NULL )'
	
	exec(@sql)
	
	set @colnames=''
	SELECT @colnames=@colnames+',CP.'+SYSCOLUMNNAME	FROM ADM_CostCenterDef with(nolock) 
	WHERE COSTCENTERID=@ccid  and SYSCOLUMNNAME like 'CCNID%'
	and SysTableName='REN_quotationPayTerms'
	
	if(@ccid=129)
		set @sql='SELECT DISTINCT CDM.SNO,CP.Particular, CP.NodeID,CP.ChequeNo, Convert(datetime,CP.ChequeDate) ChequeDate , CP.CustomerBank, CP.DebitAccID, CP.Amount ,  
		period,ACC.AccountName DebitAccName , CP.Narration , Sts.Status StatusID   , Doc.VoucherNo ,Doc.DocPrefix DocPrefix ,Doc.DocNumber DocNumber , doc.CostCenterID                       
		CostCenterID,  ADF.DocumentName DocumentName,Doc.DocID DocID , Doc.StatusID   DocStatusID,Doc.DocumentType  DocumentType,DimNodeID '+@colnames+'
		FROM REN_quotationPayTerms CP WITH(NOLOCK)  
		LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.DebitAccID                         
		LEFT JOIN REN_ContractDocMapping CDM WITH(NOLOCK) ON CP.QuotationID = CDM.ContractID AND CP.SNO = CDM.SNO  and CDM.ContractCCID =   129                 
		LEFT JOIN Acc_DocDetails Doc WITH(NOLOCK) on  CDM.DocID =  Doc.DocID                         
		LEFT join ADM_DocumentTypes ADF WITH(NOLOCK) on Doc.CostCenterID = ADF.CostCenterID                        
		LEFT JOIN Com_Status Sts WITH(NOLOCK) on Sts.StatusID =  Doc.StatusID                         
		where CP.QuotationID = '+convert(nvarchar(max),@QuotationID) +'
		order by CDM.SNO'    
	ELSE
		set @sql='SELECT DISTINCT  CP.NodeID,CP.Particular,  CP.ChequeNo, Convert(datetime,CP.ChequeDate) ChequeDate , CP.CustomerBank, CP.DebitAccID, CP.Amount,                 
		CP.SNO,period,ACC.AccountName DebitAccName , CP.Narration , ''''  StatusID   , '''' VoucherNo ,''''  DocPrefix ,''''  DocNumber , 0 CostCenterID,  ''''  DocumentName,0 DocID,DimNodeID '+@colnames+'                        
		FROM REN_quotationPayTerms CP WITH(NOLOCK)                       
		LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.DebitAccID                         
		where CP.QuotationID = '+convert(nvarchar(max),@QuotationID) +' --and CDM.TYPE = 2   
		order by CP.SNO'                  
    exec(@sql)
           
	--Getting data from Contract extended table                    
	SELECT * FROM  REN_QuotationExtended WITH(NOLOCK)                     
	WHERE QuotationID=@QuotationID                    
	
	-- GETTING COSTCENTER DATA
	if(@ccid=95)
	BEGIN
		SELECT * FROM  COM_CCCCDATA WITH(NOLOCK)                     
		WHERE NodeID=@QuotationID and CostCenterID = 103
	END
	ELSE
	BEGIN
		SELECT * FROM  COM_CCCCDATA WITH(NOLOCK)                     
		WHERE NodeID=@QuotationID and CostCenterID = @ccid  
	END
	
	EXEC [spCOM_GetAttachments] @ccid,@QuotationID,@UserID

	
	SELECT     NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate, 
	ModifiedBy, ModifiedDate, CostCenterID
	FROM COM_Notes WITH(NOLOCK) 
	WHERE FeatureID=@ccid and  FeaturePK=@QuotationID
	
	select 1 where 1<>1
	
	if exists(SELECT *	FROM  REN_Quotation WITH(NOLOCK) where RefQuotation = @QuotationID)
		SELECT UnitID,multiName uname
		FROM  REN_Quotation WITH(NOLOCK) where RefQuotation = @QuotationID or QuotationID = @QuotationID
	else
		select 1 where 1<>1
	
	select 1 where 1<>1
	 
	IF @WID is not null and @WID>0
	begin
			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=@ccid AND CCNodeID=@QuotationID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName
	end  
                     
                        
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
