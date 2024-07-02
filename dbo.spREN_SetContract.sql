USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SetContract]
	@ContractID [int],
	@ContractPrefix [nvarchar](50),
	@ContractNumber [int],
	@ContractDate [datetime],
	@LinkedQuotationID [int],
	@StatusID [int] = 0,
	@SelectedNodeID [int],
	@IsGroup [bit] = 0,
	@PropertyID [int] = 0,
	@UnitID [int] = 0,
	@MultiUnitIds [nvarchar](max),
	@MultiUnitName [nvarchar](max) = NULL,
	@TenantID [int] = 0,
	@RentRecID [int] = 0,
	@Purpose [nvarchar](500) = NULL,
	@StartDate [datetime],
	@EndDate [datetime],
	@ContractXML [nvarchar](max) = NULL,
	@PayTermsXML [nvarchar](max) = NULL,
	@RcptXML [nvarchar](max) = NULL,
	@PDRcptXML [nvarchar](max) = NULL,
	@ComRcptXML [nvarchar](max) = NULL,
	@SIVXML [nvarchar](max) = NULL,
	@RentRcptXML [nvarchar](max) = NULL,
	@ContractLocationID [int],
	@ContractDivisionID [int],
	@CustomFieldsQuery [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@TermsConditions [nvarchar](max) = NULL,
	@Narration [nvarchar](500),
	@CostCenterID [int],
	@AttachmentsXML [nvarchar](max),
	@ActivityXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@ExtraXML [nvarchar](max) = null,
	@basedon [nvarchar](50),
	@RenewRefID [int],
	@WID [int],
	@Refno [int],
	@IsOpening [bit],
	@parContractID [int],
	@IsExtended [bit],
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@LockDims [nvarchar](max) = '',
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION          
DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE int,@fldsno int
BEGIN TRY            
SET NOCOUNT ON;         
        
	DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50),@HasAccess bit,@IsDuplicateNameAllowed bit,@IsAccountCodeAutoGen bit          
	DECLARE @UpdateSql nvarchar(max),@ParentCode nvarchar(200),@CCCCCData XML,@IsIgnoreSpace bit          
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT          
	DECLARE @SelectedIsGroup bit,@SNO INT,@Prefix NVARCHAR(500),@RenewSno nvarchar(max),@Pos int
	declare @CNT INT ,  @ICNT INT  ,@level int,@maxLevel int,@Occurrence int,@SinglePDC bit,@InclPostingDate bit
	DECLARE @DDValue DateTime,@DDXML nvarchar(max),@ScheduleID INT,@typ int       
	DECLARE @return_value int,@unitGUId  NVARCHAR(max),@incMontEnd bit,@singleinv bit      
	DECLARE @AccountType xml,@AccValue nvarchar(100),@Documents xml,@DocIDValue nvarchar(100),@TempDocIDValue nvarchar(100)   
	declare @tempxml xml,@tempAmt Float,@tempSno int  ,@ServiceType nvarchar(max)  
	DECLARE @DELETEDOCID INT,@DELETECCID INT,@DELETEISACC BIT,@ind int,@indcnt int,@SYSCOL nvarchar(max) ,@ServiceTypeVal INT
	DECLARE @AUDITSTATUS NVARCHAR(50),@PrefValue NVARCHAR(500),@Dimesion INT ,@ServiceUnitDims INT  
	SET @AUDITSTATUS= 'EDIT'   
	
	if exists(select * from com_costcenterpreferences where costcenterid=95 and name ='PostIncomeMonthEnd' and value='true') 
		set @incMontEnd=1
	else
		set @incMontEnd=0
	if exists(select * from com_costcenterpreferences where costcenterid=95 and name ='SingleInvoice' and value='true') 
		set @singleinv=1
	else
		set @singleinv=0
			
    declare @cpref nvarchar(200) ,@CCStatusID int   
    
	select  @PrefValue = Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 and  Name = 'StopContifnotrefund'
	set @ServiceUnitDims=0
	select  @ServiceType = Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 and  Name = 'ServiceUnitTypes'
	select  @ServiceUnitDims = Value from COM_CostCenterPreferences   WITH(nolock) 
	 where CostCenterID=95 and  Name = 'ServiceUnitDims' and Value<>'' and isnumeric(Value)=1
	
	set @ServiceTypeVal=0
	if(@ServiceUnitDims>0 )
	BEGIN
		set @SYSCOL='CCNID'+convert(nvarchar(50),(@ServiceUnitDims-50000))+'='
		set @ind=Charindex(@SYSCOL,@CustomCostCenterFieldsQuery)

		if(@ind>0)
		BEGIN
			set @ind=Charindex('=',@CustomCostCenterFieldsQuery, Charindex(@SYSCOL,@CustomCostCenterFieldsQuery,0))
			set @indcnt=Charindex(',',@CustomCostCenterFieldsQuery, Charindex(@SYSCOL,@CustomCostCenterFieldsQuery,0)) 
			set @indcnt=@indcnt-@ind-1
			if(@ind>0 and @indcnt>0)				 
			BEGIN
				set @ServiceTypeVal= Substring(@CustomCostCenterFieldsQuery,@ind+1,@indcnt) 
			END	
		END
	END					
	
	SET @Dt=convert(float,getdate())--Setting Current Date        
	
	declare @tble table(NIDs INT)  
	insert into @tble				
	exec SPSplitString @ServiceType,','  
		
	if not (@ServiceTypeVal>0 and exists(select * from @tble where NIDs=@ServiceTypeVal))
	BEGIN
		if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'')
		BEGIN                  
			set @DDXML ='if exists(SELECT t.ContractID     FROM '
			
			if(@PrefValue is not null and @PrefValue='true')
				set @DDXML =@DDXML+' (select a.RefContractID,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when a.RefContractID='+convert(nvarchar,@RenewRefID)+' then a.enddate 
				when  b.contractid is null and a.statusid in(426,427,440,466) then 73048
				when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate 
					when a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a WITH(nolock)  
				left join ren_contract b WITH(nolock) on a.contractid=b.renewrefid and b.statusid<>451
				where a.statusid<>451) as t  '
			else
				set @DDXML =@DDXML+' (select a.RefContractID,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate when  a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a WITH(NOLOCK)) as t '
			
			if(@ServiceUnitDims>0 and @ServiceType is not null and @ServiceType<>'')
					set @DDXML =@DDXML+' join COM_ccccdata u with(nolock) on u.NodeID=t.contractid '
			
			set @DDXML =@DDXML+' WHERE ( '''+convert(nvarchar,@StartDate)+'''   between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)      
			or       '''+convert(nvarchar,@EndDate)+'''  between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)
	 		or	CONVERT(datetime, StartDate) between '''+convert(nvarchar,@StartDate)+''' and  '''+convert(nvarchar,@EndDate)+''' 
	 		or CONVERT(datetime, EndDate) between '''+convert(nvarchar,@StartDate)+''' and  '''+convert(nvarchar,@EndDate)+'''  )             
			AND t.UnitID in('+@MultiUnitIDs+') and    t.StatusID not in(477,451) '
			
			if(@ServiceUnitDims>0 and @ServiceType is not null and @ServiceType<>'')
					set @DDXML =@DDXML+' and u.CostCenterID=95 and u.CCNID'+convert(nvarchar(max),(@ServiceUnitDims-50000))+' not in('+@ServiceType+')'
			
			if(@ContractID>0)
				set @DDXML =@DDXML+' and t.ContractID<>'+convert(nvarchar,@ContractID)+' and t.RefContractID<>'+convert(nvarchar,@ContractID)
			set @DDXML =@DDXML+') RAISERROR(''-520'',16,1)'		 
		END
		ELSE
		BEGIN
			set @DDXML='if exists(SELECT t.ContractID FROM '
			
			if(@PrefValue is not null and @PrefValue='true')
				set @DDXML =@DDXML+' (select a.RefContractID,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when a.contractid='+convert(nvarchar,@RenewRefID)+' then a.enddate
				 when  b.contractid is null and a.statusid in(426,427) then 73048
					when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate 
					when a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a WITH(nolock)
				left join ren_contract b WITH(nolock) on a.contractid=b.renewrefid and b.statusid<>451
				where a.statusid<>451) as t  '
			else
				set @DDXML =@DDXML+' (select a.RefContractID,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate when  a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a WITH(NOLOCK)) as t '
			
			if(@ServiceUnitDims>0 and @ServiceType is not null and @ServiceType<>'')
					set @DDXML =@DDXML+' join COM_ccccdata u with(nolock) on u.NodeID=t.contractid '
		
			set @DDXML =@DDXML+' WHERE ( '''+convert(nvarchar,@StartDate)+'''   between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)      
			or       '''+convert(nvarchar,@EndDate)+'''  between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)
			or	CONVERT(datetime, StartDate) between '''+convert(nvarchar,@StartDate)+''' and  '''+convert(nvarchar,@EndDate)+''' 
	 		or CONVERT(datetime, EndDate) between '''+convert(nvarchar,@StartDate)+''' and  '''+convert(nvarchar,@EndDate)+'''   )             
			AND t.UnitID = '+convert(nvarchar,@UnitID)+' and    t.StatusID <> 477   and    t.StatusID <> 451   '
			
			if(@ServiceUnitDims>0 and @ServiceType is not null and @ServiceType<>'')
					set @DDXML =@DDXML+' and u.CostCenterID=95 and u.CCNID'+convert(nvarchar(max),(@ServiceUnitDims-50000))+' not in('+@ServiceType+')'
		
			set @DDXML =@DDXML+' and t.ContractID<>'+convert(nvarchar,@ContractID )+')
			RAISERROR(''-520'',16,1)'		 		
		END
		
		if(@CostCenterID=95)
		BEGIN
			EXEC sp_executesql @DDXML
			if exists(select * from COM_CostCenterPreferences WITh(NOLOCK)
			where CostCenterID=129 and Name='Validatetillclosedate' and Value='true')
			BEGIN
				set @DDXML='if exists(select QuotationID
				from (SELECT QuotationID,UnitID,StartDate,case when StatusID =467 then EndDate else VacancyDate end as EndDate from REN_Quotation with(nolock)
				where UnitID = '+convert(nvarchar,@UnitID)+' and costcenterid=129 and StatusID in(467,471,440,466)) as t
				WHERE ( '''+convert(nvarchar,@StartDate)+'''   between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)      
				or       '''+convert(nvarchar,@EndDate)+'''  between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)
				or	CONVERT(datetime, StartDate) between '''+convert(nvarchar,@StartDate)+''' and  '''+convert(nvarchar,@EndDate)+''' 
	 			or CONVERT(datetime, EndDate) between '''+convert(nvarchar,@StartDate)+''' and  '''+convert(nvarchar,@EndDate)+'''   )             				
				and QuotationID<>'+convert(nvarchar,@LinkedQuotationID )+')
				RAISERROR(''-520'',16,1)'	
			END
			ELSE
			BEGIN			
				set @DDXML='if exists(SELECT QuotationID from REN_Quotation with(nolock)                      
				WHERE ( '''+convert(nvarchar,@StartDate)+'''   between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)      
				or       '''+convert(nvarchar,@EndDate)+'''  between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)
				or	CONVERT(datetime, StartDate) between '''+convert(nvarchar,@StartDate)+''' and  '''+convert(nvarchar,@EndDate)+''' 
	 			or CONVERT(datetime, EndDate) between '''+convert(nvarchar,@StartDate)+''' and  '''+convert(nvarchar,@EndDate)+'''   )             
				AND UnitID = '+convert(nvarchar,@UnitID)+' and StatusID in(467,440,466) and costcenterid=129
				and QuotationID<>'+convert(nvarchar,@LinkedQuotationID )+')
				RAISERROR(''-520'',16,1)'	
			END
			EXEC sp_executesql @DDXML
			
			
			SET @XML= @ExtraXML    
			set @HasAccess=0
			select @HasAccess=isnull(X.value('@ValidatePurchase','BIT'),0)
			FROM @XML.nodes('/XML') as Data(X)     
				          
			if(@HasAccess=1 and not exists(select * from ren_contract a WITH(nolock)
			where costcenterid=104 and PropertyID=@PropertyID and CONVERT(FLOAT,@StartDate) between StartDate and EndDate
			and a.statusid in(426,427)))
			BEGIN
				RAISERROR('-584',16,1)
			END
			
			if(@LinkedQuotationID>0)
			BEGIN
				update REN_Quotation 
				set StatusID =468 
				where QuotationID=@LinkedQuotationID
			END
		END
	END
	
  	select  @PrefValue = Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=@CostCenterID and  Name = 'LinkDocument'   

    --User acces check FOR Notes      
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')      
	BEGIN      
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,95,8)      

		IF @HasAccess=0      
		BEGIN      
			RAISERROR('-105',16,1)      
		END      
	END      

	--User acces check FOR Attachments      
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')      
	BEGIN      
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,12)      

		IF @HasAccess=0      
		BEGIN      
			RAISERROR('-105',16,1)      
		END      
	END      
   
	if(@MultiUnitIds is not null and @MultiUnitIds<>'' and @MultiUnitName is not null and @MultiUnitName<>'' )
	BEGIN    
        set @UnitID=0
		if(@ContractID>0 and exists (select UnitID from REN_Units with(nolock) where ContractID=@ContractID))
		BEGIN
			 select @UnitID=UnitID,@unitGUId=GUID from REN_Units with(nolock) where ContractID=@ContractID	
		END
		else
			set @unitGUId=Newid()
		
		EXEC @return_value = [dbo].[spREN_SetUnits]  
		  @UNITID = @UNITID,  
		  @PROPERTYID = @PropertyID,  
		  @CODE = @MultiUnitName,  
		  @NAME = @MultiUnitName,   
		  @STATUSID = 424,  
		  @IsGroup = 0,  
		  @SelectedNodeID = 1,  
		   
		  @DETAILSXML = '',  
		  @StaticFieldsQuery = '',
		  @CustomCostCenterFieldsQuery = '',  
		  @CustomCCQuery = '',  
		     
		  @AttachmentsXML = '', 
		  @UnitRateXML = '',         
		  @CompanyGUID = @CompanyGUID,  
		  @IsFromContract=1,
		  @GUID =@unitGUId,  
		  @UserName = @UserName,  
		  @UserID = @UserID,  
		  @LangId = @LangID  
		 
		if(@return_value>0)
		begin
			set @UnitID=@return_value
			
			DECLARE @SQL NVARCHAR(MAX)
			SET @SQL='DECLARE @UNITTYPEID INT,@ANNAULRENT FLOAT
			SELECT @UNITTYPEID=MAX(NODEID),@ANNAULRENT=SUM(AnnualRent) FROM REN_Units with(nolock) where UNITID IN ('+@MultiUnitIds+')
			UPDATE REN_Units SET NODEID=@UNITTYPEID ,AnnualRent=@ANNAULRENT WHERE UnitID='+CONVERT(NVARCHAR,@UnitID)
			EXEC sp_executesql @SQL
			
			SET @SQL=''
			select @SQL=@SQL+',DEST.'+name+'=SRC.'+name 
			from sys.columns WITH(NOLOCK)
			where object_id=object_id('COM_CCCCData') and name LIKE 'CCNID%'
			
			
			SET @SQL='UPDATE DEST
			   SET ModifiedBy='''+@UserName+''''+@SQL+'
			FROM COM_CCCCData SRC WITH(NOLOCK),COM_CCCCData DEST WITH(NOLOCK)
			WHERE SRC.CostCenterID=93 AND SRC.NodeID IN ('+@MultiUnitIds+')
			AND DEST.CostCenterID=93 AND DEST.NodeID='+CONVERT(NVARCHAR,@UnitID)
			EXEC sp_executesql @SQL
			
			SET @SQL=''
			select @SQL=@SQL+',DEST.'+name+'=SRC.'+name 
			from sys.columns WITH(NOLOCK)
			where object_id=object_id('REN_UnitsExtended') and name LIKE 'Alpha%'
			
			SET @SQL='UPDATE DEST
			SET ModifiedBy='''+@UserName+''''+@SQL+'
			FROM REN_UnitsExtended SRC WITH(NOLOCK),REN_UnitsExtended DEST WITH(NOLOCK)
			WHERE SRC.UnitID IN ('+@MultiUnitIds+') AND DEST.UnitID='+CONVERT(NVARCHAR,@UnitID)
			EXEC sp_executesql @SQL
			
			
			SET @SQL=''
			select @SQL=@SQL+',DEST.'+name+'=SRC.'+name 
			from sys.columns WITH(NOLOCK)
			where object_id=object_id('REN_Units') and name in('RentalIncomeAccountID','AdvanceRentAccountID','ComPer','LLComsAccID','RentalReceivableAccountID')
			
			SET @SQL='UPDATE DEST
			SET ModifiedBy='''+@UserName+''''+@SQL+'
			FROM REN_Units SRC WITH(NOLOCK),REN_Units DEST WITH(NOLOCK)
			WHERE SRC.UnitID IN ('+@MultiUnitIds+') AND DEST.UnitID='+CONVERT(NVARCHAR,@UnitID)
			EXEC sp_executesql @SQL
		end
	END
	
	
	if(@WID>0)
	begin
		set @level=(SELECT  top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
		where WorkFlowID=@WID and  UserID =@UserID)

		if(@level is null )
			set @level=(SELECT top 1 LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)  
			where WorkFlowID=@WID and  RoleID =@RoleID)

		if(@level is null ) 
			set @level=(SELECT top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID))

		if(@level is null )
			set @level=( SELECT top 1  LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) 
			where RoleID =@RoleID))

		select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK)  where WorkFlowID=@WID  
		
		if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
		begin			
		    --set @StatusID=466
			set @StatusID=440
		END
	END
      
	IF @ContractID=0          
	BEGIN         
		SET @AUDITSTATUS = 'ADD'  
	          
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth          
		from [REN_Contract] with(NOLOCK) where ContractID=@SelectedNodeID          
	           
		select @SNO=ISNULL(max(SNO),0)+1 from [REN_Contract] (holdlock) 
		WHERE CostCenterID=@CostCenterID and parentContractID=@parContractID
		
		if(@RenewRefID is not null and @RenewRefID>0)
		BEGIN
			select @RenewSno=RenewSno from [REN_Contract] WITH(NOLOCK)
			WHERE ContractID=@RenewRefID
			
			SET @Pos=CHARINDEX('/',@RenewSno,1) 
			
			if(@Pos>0)
			BEGIN
				set @fldsno=substring(@RenewSno,@Pos+1,len(@RenewSno))
				set @fldsno=@fldsno+1
				set @RenewSno=substring(@RenewSno,0,@Pos)+'/'+convert(nvarchar(max),@fldsno)
			END	
			else
				set @RenewSno=@RenewSno+'/1'
		END
		else
			set @RenewSno=@SNO
			
		if (select count(*) from ren_contract with(nolock) where propertyid=@PropertyID and CostCenterID=@CostCenterID and contractnumber=@ContractNumber)>0
		begin
			select @ContractNumber=ISNULL(max(ContractNumber),0)+1 from ren_contract with(nolock)
			where propertyid=@PropertyID and CostCenterID=@CostCenterID
		end
  
		--IF No Record Selected or Record Doesn't Exist          
		if(@SelectedIsGroup is null)           
			select @SelectedNodeID=ContractID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth          
			from [REN_Contract] with(NOLOCK) where ParentID =0          
        
        if(@SelectedIsGroup is null and exists (select * from [REN_Contract] with(NOLOCK) where CostCenterID=@CostCenterID))   
			select top 1 @SelectedNodeID=ParentID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth          
			from [REN_Contract] with(NOLOCK) where CostCenterID=@CostCenterID
			order by sno desc
			         
		if(@SelectedIsGroup = 1)--Adding Node Under the Group          
		BEGIN          
			UPDATE REN_Contract SET rgt = rgt + 2 WHERE rgt > @Selectedlft;          
			UPDATE REN_Contract SET lft = lft + 2 WHERE lft > @Selectedlft;          
			set @lft =  @Selectedlft + 1          
			set @rgt = @Selectedlft + 2          
			set @ParentID = @SelectedNodeID          
			set @Depth = @Depth + 1          
		END          
		else if(@SelectedIsGroup = 0)--Adding Node at Same level          
		BEGIN          
			UPDATE REN_Contract SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;          
			UPDATE REN_Contract SET lft = lft + 2 WHERE lft > @Selectedrgt;          
			set @lft =  @Selectedrgt + 1          
			set @rgt = @Selectedrgt + 2           
		END          
		else  --Adding Root          
		BEGIN          
			set @lft =  1          
			set @rgt = 2           
			set @Depth = 0          
			set @ParentID =0          
			set @IsGroup=0          
		END          
       
		set @return_value = 1     
		set @Dimesion = 0   
        
		if(@PrefValue is not null and @PrefValue<>'' and  @CostCenterID in(95,104))      
		begin    
			set @Dimesion=0      
			begin try      
				select @Dimesion=convert(INT,@PrefValue)      
			end try      
			begin catch      
				set @Dimesion=0      
			end catch      
			if(@Dimesion>0)      
			begin      
				select @CCStatusID =statusid from com_status with(nolock) where costcenterid=@Dimesion and [status] = 'Active'    
				select @cpref = name from [REN_property] with(nolock) where nodeid  =  @ContractPrefix   
				set @cpref =  @cpref +  '-'+ convert(nvarchar, @ContractNumber)  
				set @Prefix=@SNO
				
				if(@parContractID>0)
				BEGIN
					select @Prefix=convert(nvarchar(max),sno)+'/'+convert(nvarchar(max),@SNO),@cpref=convert(nvarchar(max),sno)+'/'+@cpref
					from ren_contract WITH(NOLOCK) where contractid=@parContractID
				END	
					
				EXEC @return_value = [dbo].[spCOM_SetCostCenter]    
				@NodeID = 0,@SelectedNodeID = 0,@IsGroup = @IsGroup,    
				@Code = @Prefix,    
				@Name = @cpref,    
				@AliasName=@cpref,    
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,    
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,    
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,    
				@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,
				@RoleID=1,@UserID=1, @CheckLink = 0    
			end      
		end       
      
		--INSERT CONTRACT      
		INSERT INTO  [REN_Contract]        
			  ([ContractPrefix],SNO,RenewSno,QuotationID        
			  ,[ContractDate]        
			  ,[ContractNumber]        
			  ,[StatusID]        
			  ,[PropertyID]        
			  ,[UnitID]        
			  ,[TenantID]        
			  ,[RentAccID]        
			  ,[Purpose]        
			  ,[StartDate]        
			  ,[EndDate]          
			  ,[Depth]        
			  ,[ParentID]        
			  ,[lft]        
			  ,[rgt]        
			  ,[IsGroup]        
			  ,[CompanyGUID]        
			  ,[GUID]        
			  ,[CreatedBy]        
			  ,[CreatedDate]       
			  ,[LocationID]      
			  ,[DivisionID]        
			  ,[TermsConditions] 
			  ,Narration    
			  ,[CostCenterID],CCNodeID,CCID,VacancyDate,BasedOn,RenewRefID
			  ,WorkFlowID,WorkFlowLevel,AgeOfRenewal,Refno,parentContractID,IsExtended
			  ,IsOpening,SysInfo,AP)
		VALUES(@ContractPrefix,  @SNO,@RenewSno,@LinkedQuotationID,     
				CONVERT(FLOAT,@ContractDate),        
				@ContractNumber,        
				@StatusID,        
				@PropertyID,        
				@UnitID,        
				@TenantID,        
				@RentRecID,       
				@Purpose,        
				CONVERT(FLOAT,@StartDate),        
				CONVERT(FLOAT,@EndDate), 
				@Depth,      
				@SelectedNodeID,      
				@lft,      
				@rgt,      
				@IsGroup,        
				@CompanyGUID,          
				newid(),          
				@UserName,          
				@Dt,      
				@ContractLocationID,      
				@ContractDivisionID,      
				@TermsConditions, 
				@Narration,    
				@CostCenterID ,isnull( @return_value ,0) ,@Dimesion, CONVERT(FLOAT,@EndDate),@basedon,@RenewRefID
				,@WID,@level,0,@Refno,@parContractID,@IsExtended
				,@IsOpening,@SysInfo,@AP)        
		IF @@ERROR<>0 BEGIN ROLLBACK TRANSACTION RETURN -101 END        
			set @ContractID=SCOPE_IDENTITY()        
		
		IF @parContractID IS NOT NULL AND @parContractID>0
		BEGIN
			UPDATE [REN_Contract] SET NoOfContratcs=(SELECT count(*) FROM [REN_Contract] WITH(NOLOCK) WHERE parentContractID=@parContractID)
			WHERE ContractID=@parContractID
		END
		
		IF @RenewRefID IS NOT NULL AND @RenewRefID>0
		BEGIN
			UPDATE [REN_Contract] SET AgeOfRenewal=(SELECT isnull(AgeOfRenewal,0)+1 FROM [REN_Contract] WITH(NOLOCK) WHERE ContractID=@RenewRefID)
			WHERE ContractID=@ContractID
		END
		
		INSERT INTO REN_ContractExtended([NodeID],[CreatedBy],[CreatedDate])        
		VALUES(@ContractID, @UserName, @Dt)        

		INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])      
		VALUES(@CostCenterID,@ContractID,newid(),  @UserName, @Dt)      
       
	END -- END CREATE        
	ELSE --UPDATE
	BEGIN
		if(@WID=0)
		BEGIN      
			set @TempDocIDValue=0
			select @SNO=SNO,@TempDocIDValue=isnull(WorkFlowID,0),@level=WorkFlowLevel from [REN_Contract] with(nolock) WHERE ContractID =  @ContractID			
		END
		ELSE
		BEGIN
			select @SNO=SNO from [REN_Contract] with(nolock) WHERE ContractID =  @ContractID
			set @TempDocIDValue=@WID
		END	
		
		
		UPDATE  [REN_Contract]      
		SET [ContractDate] =  CONVERT(FLOAT,@ContractDate) 
			,QuotationID=@LinkedQuotationID
			,[StatusID] = @StatusID      
			,[PropertyID] = @PropertyID      
			,[UnitID] = @UnitID      
			,[TenantID] = @TenantID      
			,[RentAccID] = @RentRecID       
			,[Purpose] = @Purpose      
			,[StartDate] = CONVERT(FLOAT,@StartDate)      
			,[EndDate] = CONVERT(FLOAT,@EndDate)     
			,[CompanyGUID] = @CompanyGUID      
			,[GUID] = @GUID      
			,[ModifiedBy] = @UserName      
			,[ModifiedDate] =@Dt 
			,[LocationID] = @ContractLocationID      
			,[DivisionID] =@ContractDivisionID      
			,[TermsConditions] =@TermsConditions 
			,[Narration] = @Narration 
			,VacancyDate= CONVERT(FLOAT,@EndDate)
			,BasedOn=@basedon   
			,WorkFlowID=@TempDocIDValue,WorkFlowLevel=@level
			,IsExtended=@IsExtended
			,IsOpening=@IsOpening
			,SysInfo=@SysInfo
			,AP=@AP			
		WHERE ContractID =  @ContractID      
      
		if(@PrefValue is not null and @PrefValue<>''  and @CostCenterID in(95,104) )      
		begin     
			set @Dimesion=0      
			begin try      
				select @Dimesion=convert(INT,@PrefValue)      
			end try      
			begin catch      
				set @Dimesion=0       
			end catch      
		      
			declare @NID INT, @CCIDAcc INT    
		     
			select @NID =isnull(CCNodeID,0), @CCIDAcc=CCID  from Ren_Contract with(nolock) where ContractID=@ContractID             
	  
			if(@Dimesion>0)    
			begin  
				declare @Gid nvarchar(50)=''
				IF(@NID>1)
				BEGIN
					declare @Table nvarchar(100), @NodeidXML nvarchar(max)     
					select @Table=Tablename from adm_features with(nolock) where featureid=@Dimesion    
					declare @str nvarchar(max)     
					set @str='@Gid nvarchar(50) output'     
					set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' with(nolock) where NodeID='+convert(nvarchar,@NID)+')'    

					exec sp_executesql @NodeidXML, @str, @Gid OUTPUT     
				END
				ELSE
					SET @NID=0
					
				select  @CCStatusID =statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active'    
				select @cpref = name from [REN_property] with(nolock) where nodeid  =   @ContractPrefix  
				set @cpref =  @cpref + '-'+ convert(nvarchar, @ContractNumber)  
				
				set @Prefix=@SNO
				
				if(@parContractID>0)
				BEGIN
					select @Prefix=convert(nvarchar(max),sno)+'/'+convert(nvarchar(max),@SNO),@cpref=convert(nvarchar(max),sno)+'/'+@cpref
					from ren_contract WITH(NOLOCK) where contractid=@parContractID
				END	
				
				EXEC @return_value = [dbo].[spCOM_SetCostCenter]    
				@NodeID = @NID,
				@SelectedNodeID = 1,
				@IsGroup = @IsGroup,    
				@Code = @Prefix,    
				@Name = @cpref,    
				@AliasName=@cpref,    
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,    
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML='',    
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=null,@NotesXML=NULL,    
				@CostCenterID = @Dimesion,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName=@UserName,@RoleID=1,@UserID=1 , @CheckLink = 0     

				Update Ren_Contract set CCID=@Dimesion, CCNodeID=@return_value where ContractID=@ContractID          
				
			END    
		END       
	END--UPDATE
	
	IF(@ContractXML IS NOT NULL AND @ContractXML<>'')        
	BEGIN        
		SET @XML= @ContractXML          

		DELETE FROM [REN_ContractParticulars] WHERE CONTRACTID = @ContractID        

		INSERT INTO [REN_ContractParticulars]        
				([ContractID]        
				,[CCID]        
				,[CCNodeID]        
				,[CreditAccID]        
				,[ChequeNo]        
				,[ChequeDate]        
				,[PayeeBank]        
				,[DebitAccID]   
				,[RentAmount]    
				,[Discount]         
				,[Amount]        
				,[Sno]      
				,[IsRecurr],Narration ,VatPer,VatAmount         
				,[CompanyGUID]        
				,[GUID]        
				,[CreatedBy]        
				,[CreatedDate],TasjeelAmount,Detailsxml,AdvanceAccountID,InclChkGen,VatType,TaxCategoryID
				,RecurInvoice,PostDebit,TaxableAmt,NonTaxAmount,Sqft,Rate,LocationID,SPType,DimNodeID,SalesManID,NetAmount,
				UnitsXml)   
		SELECT @ContractID , X.value('@CCID','INT'),         
				X.value('@CCNodeID','INT'),          
				X.value('@CreditAccID','INT'),         
				X.value('@ChequeNo','NVARCHAR(200)'),        
				CONVERT(float,X.value('@ChequeDate','Datetime')),        
				X.value('@PayeeBank','nvarchar(500)'),        
				X.value('@DebitAccID','INT'),    
				X.value('@RentAmount','float'),    
				X.value('@Discount','float'),       
				X.value('@Amount','float'),        
				X.value('@SNO','int'),      
				ISNULL(X.value('@IsRecurr','bit'),0),  X.value('@Narration','nvarchar(max)'), 
				X.value('@VatPer','float'),
				X.value('@VatAmount','float'),    
				@CompanyGUID,          
				newid(),          
				@UserName,          
				@Dt,X.value('@TasjeelAmount','float'),convert(nvarchar(max), X.query('XML'))  ,         
				X.value('@AdvanceAccountID','INT'), X.value('@InclChkGen','INT')
				, X.value('@VatType','Nvarchar(50)'),X.value('@TaxCategoryID','INT')
				, X.value('@Recur','BIT'),X.value('@PostDebit','bit'),X.value('@TaxableAmt','float'),X.value('@NonTaxAmount','float')
				, X.value('@Sqft','float'),X.value('@Rate','float'),        
				X.value('@LocationID','INT'),X.value('@SPType','INT')
				,X.value('@DimNodeID','INT'),X.value('@SalesManID','INT')
				,X.value('@NetAmount','float')
				,convert(nvarchar(max), X.query('UnitsXML')) 
		FROM @XML.nodes('/ContractXML/Rows/Row') as Data(X) 
		
		set @SQL=''
		select @SQL=X.value('@UpdateQuery','Nvarchar(max)')from @XML.nodes('/ContractXML') as data(X)    
		
		if(@SQL!='')
		BEGIN			
			set @SQL='update [REN_ContractParticulars] set '+@SQL+'ContractID=ContractID 
			from @XML.nodes(''/ContractXML/Rows/Row'') as data(X)     
			where [ContractID]='+convert(nvarchar(max),@ContractID)+' and [CCNodeID]=X.value(''@CCNodeID'',''INT'')'
			
			exec sp_executesql @SQL,N'@XML xml',@XML
		END
		
	END        

	IF(@PayTermsXML IS NOT NULL AND @PayTermsXML<>'')        
	BEGIN        
		SET @XML= @PayTermsXML          

		DELETE FROM [REN_ContractPayTerms] WHERE CONTRACTID = @ContractID        

		INSERT INTO  [REN_ContractPayTerms]        
				([ContractID]        
				,[ChequeNo]        
				,[ChequeDate]        
				,[CustomerBank]        
				,[DebitAccID]        
				,[Amount],RentAmount       
				,[SNO]       
				,[Narration]      
				,[CompanyGUID]        
				,[GUID]        
				,[CreatedBy]        
				,[CreatedDate],Period,PostingDate,LocationID,Particular,TillDate,FromDate,DimNodeID,SalesManID,VatType )  
		SELECT @ContractID  ,        
				X.value('@ChequeNo','NVARCHAR(200)'),        
				Convert(float,X.value('@ChequeDate','Datetime')),        
				X.value('@CustomerBank','nvarchar(500)'),        
				X.value('@DebitAccID','INT'),        
				X.value('@Amount','float'), X.value('@RentAmount','float'),       
				X.value('@SNO','int'),      
				X.value('@Narration','nvarchar(MAX)'),      
				@CompanyGUID,          
				newid(),          
				@UserName,          
				@Dt         , X.value('@Period','INT'),
				Convert(float,X.value('@PostingDate','Datetime')),        
				X.value('@LocationID','INT'),        
				X.value('@Particular','INT'),Convert(float,X.value('@TillDate','Datetime')),Convert(float,X.value('@FromDate','Datetime'))
				,X.value('@DimNodeID','INT'),X.value('@SalesManID','INT'),X.value('@VatType','nvarchar(20)')
		FROM @XML.nodes('/PayTermXML/Rows/Row') as Data(X)    
		
		set @SQL=''
		select @SQL=X.value('@UpdateQuery','Nvarchar(max)')from @XML.nodes('/PayTermXML') as data(X)    
		if(@SQL!='')
		BEGIN
			set @SQL='update [REN_ContractPayTerms] set '+@SQL+'ContractID=ContractID 
			from @XML.nodes(''/PayTermXML/Rows/Row'') as data(X)     
			where [ContractID]='+convert(nvarchar(max),@ContractID)+' and [SNO]=X.value(''@SNO'',''INT'')'
			exec sp_executesql @SQL,N'@XML xml',@XML
		END      
	END    
	
	declare @tabPart table(id int identity(1,1),NodeID INT,PartXML nvarchar(max),typ int)
	insert into @tabPart
	select NodeID,Detailsxml,1 from [REN_ContractParticulars] WITH(NOLOCK)       
	where CONTRACTID = @ContractID and Detailsxml is not null
	
	insert into @tabPart
	select NodeID,UnitsXml,2 from [REN_ContractParticulars] WITH(NOLOCK)       
	where CONTRACTID = @ContractID and UnitsXml is not null and UnitsXml<>''
	
	Delete from REN_ContractParticularsDetail where ContractID=@ContractID and Costcenterid=@CostCenterID
	
	SELECT @ICNT = 0,@CNT = COUNT(ID) FROM @tabPart            
	WHILE(@ICNT < @CNT)      
	BEGIN      
		SET @ICNT =@ICNT+1 
		SELECT @DDXML = PartXML,@ParentID=NodeID,@typ=typ   FROM @tabPart WHERE  ID = @ICNT 

		SET @XML= @DDXML 
		if(@DDXML like '%UnitsRow%')
			INSERT INTO  REN_ContractParticularsDetail
			([ContractID],ParticularNodeID,Type,FromDate,ToDate,Unit,Period,Amount,Rate,CostCenterID,Discount,ActAmount,Distribute,Narration
			,Fld1 ,Fld2 ,Fld3 ,Fld4 ,Fld5 ,Fld6 ,Fld7 ,Fld8 ,Fld9 ,Fld10,ProposedRent,ProposedDisc,ProposedAmount,BaseRent,PrevRent)  
			SELECT @ContractID,@ParentID,@typ,Convert(float,X.value('@FromDate','Datetime')),        
			Convert(float,X.value('@ToDate','Datetime')),        
			X.value('@Unit','INT'),        
			X.value('@Period','INT'),        
			X.value('@Amount','float'),
			ISNULL(X.value('@Rate','float'),0),
			@CostCenterID,
			ISNULL(X.value('@Discount','float'),0),
			ISNULL(X.value('@ActAmount','float'),0),
			X.value('@Distribute','INT'),      
			X.value('@Narration','nvarchar(MAX)')
			,X.value('@Fld1','nvarchar(MAX)')
			,X.value('@Fld2','nvarchar(MAX)') ,X.value('@Fld3','nvarchar(MAX)') ,X.value('@Fld4','nvarchar(MAX)') ,X.value('@Fld5','nvarchar(MAX)') ,X.value('@Fld6','nvarchar(MAX)') ,X.value('@Fld7','nvarchar(MAX)') ,X.value('@Fld8','nvarchar(MAX)') ,X.value('@Fld9','nvarchar(MAX)') ,X.value('@Fld10','nvarchar(MAX)')
			,ISNULL(X.value('@ProposedRent','float'),0),ISNULL(X.value('@ProposedDisc','float'),0),ISNULL(X.value('@ProposedAmount','float'),0),ISNULL(X.value('@BaseRent','float'),0),ISNULL(X.value('@PrevRent','float'),0)			
			FROM @XML.nodes('/XML/UnitsRow/Row') as Data(X) 
		ELSE if(@DDXML like '%UnitsXML%')
			INSERT INTO  REN_ContractParticularsDetail
			([ContractID],ParticularNodeID,Type,FromDate,ToDate,Unit,Period,Amount,Rate,CostCenterID,Discount,ActAmount,Distribute,Narration
			,Fld1 ,Fld2 ,Fld3 ,Fld4 ,Fld5 ,Fld6 ,Fld7 ,Fld8 ,Fld9 ,Fld10,ProposedRent,ProposedDisc,ProposedAmount,BaseRent,PrevRent)  
			SELECT @ContractID,@ParentID,@typ,Convert(float,X.value('@FromDate','Datetime')),        
			Convert(float,X.value('@ToDate','Datetime')),        
			X.value('@Unit','INT'),        
			X.value('@Period','INT'),        
			X.value('@Amount','float'),
			ISNULL(X.value('@Rate','float'),0),
			@CostCenterID,
			ISNULL(X.value('@Discount','float'),0),
			ISNULL(X.value('@ActAmount','float'),0),
			X.value('@Distribute','INT'),      
			X.value('@Narration','nvarchar(MAX)')
			,X.value('@Fld1','nvarchar(MAX)')
			,X.value('@Fld2','nvarchar(MAX)') ,X.value('@Fld3','nvarchar(MAX)') ,X.value('@Fld4','nvarchar(MAX)') ,X.value('@Fld5','nvarchar(MAX)') ,X.value('@Fld6','nvarchar(MAX)') ,X.value('@Fld7','nvarchar(MAX)') ,X.value('@Fld8','nvarchar(MAX)') ,X.value('@Fld9','nvarchar(MAX)') ,X.value('@Fld10','nvarchar(MAX)')
			,ISNULL(X.value('@ProposedRent','float'),0),ISNULL(X.value('@ProposedDisc','float'),0),ISNULL(X.value('@ProposedAmount','float'),0),ISNULL(X.value('@BaseRent','float'),0),ISNULL(X.value('@PrevRent','float'),0)			

			FROM @XML.nodes('/UnitsXML/Row') as Data(X)   	
		ELSE
			INSERT INTO  REN_ContractParticularsDetail
			([ContractID],ParticularNodeID,Type,FromDate,ToDate,Unit,Period,Amount,Rate,CostCenterID,Discount,ActAmount,Distribute,Narration
			,Fld1 ,Fld2 ,Fld3 ,Fld4 ,Fld5 ,Fld6 ,Fld7 ,Fld8 ,Fld9 ,Fld10,ProposedRent,ProposedDisc,ProposedAmount,BaseRent,PrevRent)  
			SELECT @ContractID,@ParentID,@typ,Convert(float,X.value('@FromDate','Datetime')),        
			Convert(float,X.value('@ToDate','Datetime')),        
			X.value('@Unit','INT'),        
			X.value('@Period','INT'),        
			X.value('@Amount','float'),
			ISNULL(X.value('@Rate','float'),0),
			@CostCenterID,
			ISNULL(X.value('@Discount','float'),0),
			ISNULL(X.value('@ActAmount','float'),0),
			X.value('@Distribute','INT'),      
			X.value('@Narration','nvarchar(MAX)')
			,X.value('@Fld1','nvarchar(MAX)')
			,X.value('@Fld2','nvarchar(MAX)') ,X.value('@Fld3','nvarchar(MAX)') ,X.value('@Fld4','nvarchar(MAX)') ,X.value('@Fld5','nvarchar(MAX)') ,X.value('@Fld6','nvarchar(MAX)') ,X.value('@Fld7','nvarchar(MAX)') ,X.value('@Fld8','nvarchar(MAX)') ,X.value('@Fld9','nvarchar(MAX)') ,X.value('@Fld10','nvarchar(MAX)')
			,ISNULL(X.value('@ProposedRent','float'),0),ISNULL(X.value('@ProposedDisc','float'),0),ISNULL(X.value('@ProposedAmount','float'),0),ISNULL(X.value('@BaseRent','float'),0),ISNULL(X.value('@PrevRent','float'),0)			
			FROM @XML.nodes('/XML/Row') as Data(X)   
	END

	--Inserts Multiple Notes      
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')      
	BEGIN      
		SET @XML=@NotesXML      

		--If Action is NEW then insert new Notes      
		INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,         
		GUID,CreatedBy,CreatedDate)      
		SELECT 95,95,@ContractID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~',''),  
		newid(),@UserName,@Dt      
		FROM @XML.nodes('/NotesXML/Row') as Data(X)      
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'      

		--If Action is MODIFY then update Notes      
		UPDATE COM_Notes      
		SET Note=Replace(X.value('@Note','NVARCHAR(MAX)'),'@~',''),  
		GUID=newid(),      
		ModifiedBy=@UserName,      
		ModifiedDate=@Dt      
		FROM COM_Notes C with(nolock)      
		INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)        
		ON convert(INT,X.value('@NoteID','INT'))=C.NoteID      
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'      

		--If Action is DELETE then delete Notes      
		DELETE FROM COM_Notes      
		WHERE NoteID IN(SELECT X.value('@NoteID','INT')      
		FROM @XML.nodes('/NotesXML/Row') as Data(X)      
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')      

	END      
      
	--Inserts Multiple Attachments      
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
		exec [spCOM_SetAttachments] @ContractID,@CostCenterID,@AttachmentsXML,@UserName,@Dt     
	
      
	if(@ActivityXml<>'')      
		exec spCom_SetActivitiesAndSchedules @ActivityXml,95,@ContractID,@CompanyGUID,@Guid,@UserName,@dt,@LangID     
  
  
	SET @XML= @ExtraXML          
	
	select @UpdateSql='update REN_Contract SET '+X.value('@StFldsUQ','NVARCHAR(max)')
	+' WHERE ContractID ='+convert(nvarchar,@ContractID)
	FROM @XML.nodes('/XML') as Data(X)      
          
	exec(@UpdateSql) 
	
	
	set @UpdateSql='update COM_CCCCDATA SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',
	[ModifiedDate] =' + convert(nvarchar(max),@Dt) +' WHERE NodeID ='+convert(nvarchar(max),@ContractID) + ' AND CostCenterID ='+convert(nvarchar(max),@CostCenterID)       
          
	exec(@UpdateSql)     

	Declare @TEMPxmlParent NvarChar(MAX);
	SELECT @TEMPxmlParent=CONVERT(NVARCHAR(MAX), X.query('DimensionXML'))
	from @XML.nodes('/XML') as Data(X)

	
	IF  (@TEMPxmlParent IS NOT NULL AND @TEMPxmlParent <> '') 
	BEGIN
		set @TEMPxmlParent=replace(@TEMPxmlParent,'DimensionXML','XML')
		 EXEC [spCOM_SetCCCCMap] 95,@ContractID,@TEMPxmlParent,@UserName,@LangID
	END
    
    if(@LockDims is not null and @LockDims<>'')
	BEGIN
		set @UpdateSql=' if exists(select a.ContractID from REN_Contract a WITH(NOLOCK)
		join COM_CCCCData b WITH(NOLOCK) on a.ContractID=b.NodeID and a.CostCenterID=b.CostCenterID
		join ADM_DimensionWiseLockData c WITH(NOLOCK) on a.ContractDate between c.fromdate and c.todate and c.isEnable=1 
		where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' and a.ContractID='+convert(nvarchar,@ContractID)+' '+@LockDims
		+') RAISERROR(''-125'',16,1) '
		
		EXEC sp_executesql @UpdateSql
	END
	
  
    DECLARE @AuditTrial BIT        
	SET @AuditTrial=0        
	SELECT @AuditTrial= CONVERT(BIT,VALUE)  FROM [COM_COSTCENTERPreferences] with(nolock)     
	WHERE CostCenterID=95  AND NAME='AllowAudit'   
	IF (@AuditTrial=1)      
	BEGIN 	
		--INSERT INTO HISTROY   
		EXEC [spCOM_SaveHistory]  
			@CostCenterID =@CostCenterID,    
			@NodeID =@ContractID,
			@HistoryStatus =@AUDITSTATUS,
			@UserName=@UserName,
			@DT=@DT  
	END
    --------------------------  POSTINGS --------------------------      
       
    
         
	Declare @RcptCCID INT,@ComRcptCCID INT,@SIVCCID INT,@RentRcptCCID INT     
	Declare @BnkRcpt INT  , @PDRcpt INT , @CommRcpt INT , @SalesInv INT, @RentRcpt INT      
	DECLARE  @StatusValue int ,@IsRes bit    
	DECLARE @AA XML  , @DateXML XML        
	DECLARE @DocXml nvarchar(max) ,@ActXml nvarchar(max)         
	
	set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'    
				
	--SELECT @StatusValue = isnull(VALUE,369) FROM COM_COSTCENTERPREFERENCES    
	--WHERE COSTCENTERID = 95 AND NAME = 'PostDocStatus'    

	IF(@CostCenterID = 95)    
	BEGIN    
        
        
	IF(@SIVXML is not null and @SIVXML<>'') 
	BEGIN
		if exists(select MapID from REN_ContractDocMapping DM WITH(NOLOCK)
		join COM_CCSchedules a WITH(NOLOCK) on DM.CostCenterID=a.CostCenterID
		join COM_SchEvents b WITH(NOLOCK) on a.ScheduleID=b.ScheduleID
		where a.NodeID=DM.DocID and DM.ContractID = @ContractID and b.statusid=2
		and (DM.TYPE = 1 OR DM.TYPE IS NULL) and (DM.isaccdoc = 0 OR DM.IsAccDoc  IS NULL ))
		 RAISERROR('-101',16,1)
	
		 
		if(@IsOpening=1)
		BEGIN
				set @DocIDValue=0
				
				select @DocIDValue=isnull(DocID,0) from [REN_ContractDocMapping] WITH(NOLOCK)
				where ContractID=@ContractID and ContractCCID=95 and Type=1 and DocType=4
				
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractOpeningDoc' 
				
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @SIVXML,@ContractDate,@RcptCCID,@Prefix   output
				
				EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
				@CostCenterID = @RcptCCID,      
				@DocID = @DocIDValue,      
				@DocPrefix = @Prefix,      
				@DocNumber =1,      
				@DocDate = @ContractDate,      
				@DueDate = NULL,      
				@BillNo = @SNO,      
				@InvDocXML = @SIVXML,      
				@NotesXML = N'',      
				@AttachmentsXML = N'',      
				@ActivityXML  = @ActXml, 
				@IsImport = 0,      
				@LocationID = @ContractLocationID,      
				@DivisionID = @ContractDivisionID,      
				@WID = 0,      
				@RoleID = @RoleID,      
				@RefCCID = 95,    
				@RefNodeid = @ContractID ,    
				@CompanyGUID = @CompanyGUID,      
				@UserName = @UserName,      
				@UserID = @UserID,      
				@LangID = @LangID      

				IF(@DocIDValue = 0 )    
				BEGIN    
					INSERT INTO [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID)      
					VALUES(@ContractID,1,1,@return_value,@RcptCCID,1,4,95)      
				END
		END
		ELSE	     
		BEGIN      
			select @ParentID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
			where CostCenterID=95 and Name='ContractSalesInvoice'      
			SET @XML = @SIVXML    

			declare  @tblExistingSIVXML TABLE (ID int identity(1,1),DOCID INT,DimID INT,ccid int)           
			declare @totalPreviousSIVXML INT,@BillWiseXMl Nvarchar(max),@Dim INT
			insert into @tblExistingSIVXML     
			select DOCID,DimID,CostCenterID from  [REN_ContractDocMapping] with(nolock)   
			where contractid=@ContractID and Doctype =4 AND ContractCCID= 95    

			select @totalPreviousSIVXML=COUNT(id) from @tblExistingSIVXML     

			CREATE TABLE #tblListSIVTemp(ID int identity(1,1),TRANSXML NVARCHAR(MAX) ,Documents NVARCHAR(MAX),Recurxml NVARCHAR(MAX),DimID INT)
			INSERT INTO #tblListSIVTemp        
			SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML')),CONVERT(NVARCHAR(MAX),X.query('Documents')),CONVERT(NVARCHAR(MAX),X.query('recurXML'))
			,X.value ('@DimID', 'INT')
			from @XML.nodes('/SIV//ROWS') as Data(X)        

			SELECT @CNT = COUNT(ID) FROM #tblListSIVTemp      

			SET @ICNT = 0      
			WHILE(@ICNT < @CNT)      
			BEGIN      
				SET @ICNT =@ICNT+1      

				SELECT @AA = TRANSXML , @Documents = Documents ,@Dim=DimID   FROM #tblListSIVTemp WHERE  ID = @ICNT      

				Set @DocXml = convert(nvarchar(max), @AA)      

				SELECT   @tempSno =  X.value ('@CONTRACTSNO', 'int'),@RcptCCID =  ISNULL(X.value ('@CostCenterid', 'int'),@ParentID)
				from @Documents.nodes('/Documents') as Data(X)     

				SET @DocIDValue=0    
				if(@Dim>0)
				BEGIN
					SELECT   @DocIDValue = DOCID from @tblExistingSIVXML where DimID=@Dim and ccid= @RcptCCID  
					if(@DocIDValue>0)
						delete from @tblExistingSIVXML where DimID=@Dim and DOCID=@DocIDValue
				END	
				ELSE if(@singleinv=1)
				BEGIN
					SELECT @DocIDValue = DOCID from @tblExistingSIVXML where ccid= @RcptCCID  
					order by id desc
				END
				ELSE	
					SELECT   @DocIDValue = DOCID from @tblExistingSIVXML where ID=@ICNT    

				SET @DocIDValue = ISNULL(@DocIDValue,0)    
				if exists(SELECT IsBillwise FROM ACC_Accounts with(nolock) WHERE AccountID=@RentRecID and IsBillwise=1)    
				begin    
					IF EXISTS(select Value from ADM_GLOBALPREFERENCES with(nolock) where NAME  = 'On')    
					BEGIN    
						set @tempxml=@DocXml    
						set @tempAmt=0
						select @tempAmt=isnull(sum(X.value('@Amount',' float')),0)
						from @tempxml.nodes('/DocumentXML/Row/AccountsXML/Accounts') as Data(X)
						where X.value('@DebitAccount',' int')=@RentRecID
						if(@tempAmt>0)
						BEGIN
							set @BillWiseXMl='<BillWise> <Row DocSeqNo="1" AccountID="'+convert(nvarchar,@RentRecID)+'" AmountFC="'+CONVERT(nvarchar,@tempAmt)+'" AdjAmount="'+CONVERT(nvarchar,@tempAmt)+'" 
							AdjCurrID="1" AdjExchRT="1" IsNewReference="1" Narration="" IsDocPDC="0" ></Row></BillWise>'    
						END
						ELSE
							set @BillWiseXMl=''
					END    
					ELSE    
					BEGIN    
						set @BillWiseXMl=''    
					END    
				end    
				else    
				begin    
					set @BillWiseXMl=''    
				end 

				set @Prefix=''
				EXEC [sp_GetDocPrefix] @DocXml,@ContractDate,@RcptCCID,@Prefix   output

				set @DocXml=Replace(@DocXml,'<RowHead/>','')
				set @DocXml=Replace(@DocXml,'<DocumentXML/>','')
				set @DocXml=Replace(@DocXml,'</DocumentXML>','')
				set @DocXml=Replace(@DocXml,'<DocumentXML>','')
				set @return_value=0
				if(@DocXml<>'')
				BEGIN
					
					if(@singleinv=1 and @DocIDValue>0 and (@Dim is null or @Dim<5000))
						delete from @tblExistingSIVXML where DOCID=@DocIDValue
	
					EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
					@CostCenterID = @RcptCCID,      
					@DocID = @DocIDValue,      
					@DocPrefix = @Prefix,      
					@DocNumber = N'',      
					@DocDate = @ContractDate,      
					@DueDate = NULL,      
					@BillNo = @SNO,      
					@InvDocXML =@DocXml,      
					@BillWiseXML = @BillWiseXMl,      
					@NotesXML = N'',      
					@AttachmentsXML = N'',     
					@ActivityXML  = @ActXml,     
					@IsImport = 0,      
					@LocationID = @ContractLocationID,      
					@DivisionID = @ContractDivisionID,      
					@WID = 0,      
					@RoleID = @RoleID,      
					@DocAddress = N'',      
					@RefCCID = 95,    
					@RefNodeid  = @ContractID,    
					@CompanyGUID = @CompanyGUID,      
					@UserName = @UserName,      
					@UserID = @UserID,      
					@LangID = @LangID       
				END
				SET @SalesInv  = @return_value      

				set @Documents=null
				SELECT @Documents = Recurxml FROM #tblListSIVTemp WHERE  ID = @ICNT  
				
				set @Occurrence=0
				SELECT  @Occurrence=count(X.value ('@Date', 'Datetime' ))
				from @Documents.nodes('/recurXML/Row') as Data(X)
				if(@Occurrence>0 and @return_value>0)
				BEGIN		 
					set @ScheduleID=0
					select @ScheduleID=ScheduleID from COM_CCSchedules WITH(NOLOCK)
					where CostCenterID=@RcptCCID and NodeID=@SalesInv
					if(@ScheduleID=0)
					BEGIN
						INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
						FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,Occurrence,RecurAutoPost,
						CompanyGUID,GUID,CreatedBy,CreatedDate)
						VALUES('Contract',1,0,0,0,0,0,0,@StartDate,@EndDate,@Occurrence,0,
								@CompanyGUID,NEWID(),@UserName,@Dt)
						SET @ScheduleID=SCOPE_IDENTITY()  

						INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
						VALUES(@RcptCCID,@SalesInv,@ScheduleID,@UserName,@Dt)
						
						INSERT INTO COM_UserSchedules(ScheduleID,GroupID,RoleID,UserID,CreatedBy,CreatedDate)
						values(@ScheduleID,0,0,@UserID,@UserName,@Dt)
					END
					ELSE
					BEGIN
						update COM_Schedules
						set StartDate=@StartDate,EndDate=@EndDate,Occurrence=@Occurrence
						where ScheduleID=@ScheduleID
					END
					
					delete from COM_SchEvents
					where ScheduleID=@ScheduleID
					
					INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate,
					SubCostCenterID,NODEID,AttachmentID)
					select @ScheduleID,CONVERT(FLOAT,X.value ('@Date', 'Datetime' )),'Contract',1,0,CONVERT(FLOAT,X.value ('@Date', 'Datetime' )),CONVERT(FLOAT,X.value ('@Date', 'Datetime' )),
					@CompanyGUID,NEWID(),@UserName,@DT,@ParentID,@SNO,X.value ('@Seq', 'INT' )
					from @Documents.nodes('/recurXML/Row') as Data(X)	
				END
				ELSE 
				BEGIN
					set @ScheduleID=0
					select @ScheduleID=ScheduleID from COM_CCSchedules WITH(NOLOCK)
					where CostCenterID=@RcptCCID and NodeID=@SalesInv
					
					if(@ScheduleID>0)
					BEGIN
						delete from COM_CCSchedules
						where ScheduleID=@ScheduleID
						
						delete from COM_UserSchedules
						where ScheduleID=@ScheduleID
						
						delete from COM_SchEvents
						where ScheduleID=@ScheduleID
						
						delete from COM_Schedules
						where ScheduleID=@ScheduleID
					END
				END

				IF(@DocIDValue = 0 )    
				BEGIN
					if(@SalesInv>0)
					BEGIN
						INSERT INTO [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID,DimID)
						values(@ContractID,1,@tempSno,@SalesInv,@RcptCCID,0,4,95,@Dim)
					END	
				END      
				else    
				begin    
					update [REN_ContractDocMapping]    
					set [Sno]= @tempSno
					where [ContractID]=@ContractID and DocID=@DocIDValue    
				end
			END    
	       
			if(@Dim>0 or @singleinv=1)
			BEGIN
				declare @temptab table(id int)
				
				insert into @temptab(id)
				select DOCID FROM @tblExistingSIVXML
				
				delete from @tblExistingSIVXML
				
				insert into @tblExistingSIVXML(docid)
				select id FROM @temptab
					 
				select @totalPreviousSIVXML=max(id),@CNT=min(id) from @tblExistingSIVXML     
				set @CNT=@CNT-1
			END	
		
			IF(@totalPreviousSIVXML > @CNT)    
			BEGIN    
				WHILE(@CNT <  @totalPreviousSIVXML)    
				BEGIN    

					SET @CNT = @CNT+1    
					SELECT @DELETEDOCID = DOCID FROM @tblExistingSIVXML WHERE ID = @CNT    
					
					set @DELETECCID=0
					
					SELECT @DELETECCID = COSTCENTERID FROM dbo.INV_DocDetails   with(nolock)    
					WHERE DOCID = @DELETEDOCID    
					if(@DELETECCID>0)
					BEGIN
						EXEC @return_value = [spDOC_DeleteInvDocument]      
						@CostCenterID = @DELETECCID,      
						@DocPrefix = '',      
						@DocNumber = '',  
						@DOCID = @DELETEDOCID,
						@SysInfo =@SysInfo, 
						@AP =@AP,
						@UserID = 1,      
						@UserName = @UserName,      
						@LangID = 1,
						@RoleID=1
					END
					
					DELETE FROM REN_ContractDocMapping 
					WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DELETEDOCID and DOCTYPE =4 AND ContractCCID = 95    
					
					set @ScheduleID=0
					select @ScheduleID=ScheduleID from COM_CCSchedules WITH(NOLOCK)
					where CostCenterID=@DELETECCID and NodeID=@DELETEDOCID
					
					if(@ScheduleID>0)
					BEGIN
						delete from COM_CCSchedules
						where ScheduleID=@ScheduleID
						
						delete from COM_UserSchedules
						where ScheduleID=@ScheduleID
						
						delete from COM_SchEvents
						where ScheduleID=@ScheduleID
						
						delete from COM_Schedules
						where ScheduleID=@ScheduleID
					END
				END
			END 
		END       
    END
  
    
     		
	IF(@RcptXML is not null and @RcptXML<>'')      
	BEGIN      

		SET @XML = @RcptXML    

		CREATE TABLE #tblListReceiptXML(ID int identity(1,1),TRANSXML NVARCHAR(MAX)  , AccountType NVARCHAR(100) ,Documents NVARCHAR(200) )          
		INSERT INTO #tblListReceiptXML        
		SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML'))   ,  CONVERT(NVARCHAR(MAX),  X.query('AccountType')), CONVERT(NVARCHAR(200), X.query('Documents') )                 
		from @XML.nodes('/ReceiptXML/ROWS') as Data(X)        

		SELECT @AA = TRANSXML , @AccountType = AccountType , @Documents = Documents  FROM #tblListReceiptXML WHERE  ID = 1      

		SELECT   @AccValue =  X.value ('@DD', 'NVARCHAR(100)' ) ,@IsRes=X.value('@IsRes', 'BIT' )            
		from @AccountType.nodes('/AccountType') as Data(X)     

		if not(@IsRes is not null and @IsRes=1 and @LinkedQuotationID is not null and @LinkedQuotationID>0)
		BEGIN
			set @DocIDValue=0    

			select @DocIDValue=DOCID from  [REN_ContractDocMapping] with(nolock) 
			where contractid=@ContractID and Doctype =1 AND ContractCCID = 95    

			IF(@AccValue = 'BANK')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractPostDatedReceipt'      
			END    
			ELSE  IF(@AccValue = 'Rct')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractBankReceipt'      
			END  
			ELSE  IF(@AccValue = 'CASH')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractCashReceipt'      
			END    
			ELSE  IF(@AccValue = 'JV')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractJVReceipt'      
			END    

			set @DELETECCID=0    
			IF(@DocIDValue>0)    
			BEGIN    
				SELECT  @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails  with(nolock)     
				WHERE DOCID = @DocIDValue    
			END     
			if(@DocIDValue>0 AND @DELETECCID <> 0 and @RcptCCID<>@DELETECCID)    
			begin    
				EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
				@CostCenterID = @DELETECCID,      
				@DocPrefix = '',      
				@DocNumber = '',  
				@DOCID = @DocIDValue,
				@SysInfo =@SysInfo, 
				@AP =@AP,
				@UserID = 1,      
				@UserName = @UserName,      
				@LangID = 1,
				@RoleID=1

				DELETE FROM REN_ContractDocMapping 
				WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DocIDValue and DOCTYPE =1 AND ContractCCID = 95    

				set @DocIDValue=0       
			end    

			SET @DocXml = convert(nvarchar(max), @AA)      
			SET @DocIDValue = ISNULL(@DocIDValue,0)    
			if(@DocIDValue = '')    
			set @DocIDValue=0    
			SET @ICNT = 0      
			WHILE(@ICNT =0)      
			BEGIN      
				SET @ICNT =@ICNT+1      

				set @TempDocIDValue =0
				SELECT   @TempDocIDValue =  X.value('@DocID', 'NVARCHAR(100)'),@DDValue=ISNULL(X.value('@DDate', 'DateTime'),@ContractDate)
				from @Documents.nodes('/Documents') as Data(X)     
				set @BillWiseXMl='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
				if(@TempDocIDValue is not null and @TempDocIDValue<>'' and convert(INT,@TempDocIDValue)>0 and @TempDocIDValue= @DocIDValue)
				BEGIN
					set @tempxml=@DocXml    					
					select @tempAmt=sum(X.value ('@Amount', 'FLOAT'))
					from @tempxml.nodes('/DocumentXML/Row/Transactions') as Data(X)  
										 
					if ((select isnull(sum(Amount),0) from Acc_docdetails with(nolock) where  DOCID=@DocIDValue 
					 and StatusID in(369,429) and DocumentType=19)=@tempAmt)
						continue;
						
					
					if exists(select DOCID from Acc_docdetails with(nolock) 
					where  DOCID=@DocIDValue and Amount=@tempAmt and CreditAccount=@lft)
					BEGIN
						set @BillWiseXMl='<XML DontChangeBillwise="1" SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
					END		
				END 
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @DocXml,@DDValue,@RcptCCID,@Prefix   output

				EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
				@CostCenterID = @RcptCCID,      
				@DocID = @DocIDValue,      
				@DocPrefix = @Prefix,      
				@DocNumber =1,      
				@DocDate = @DDValue,      
				@DueDate = NULL,      
				@BillNo = @SNO,      
				@InvDocXML = @DocXml,      
				@NotesXML = N'',      
				@AttachmentsXML = N'',      
				@ActivityXML  = @BillWiseXMl,     
				@IsImport = 0,      
				@LocationID = @ContractLocationID,      
				@DivisionID = @ContractDivisionID,      
				@WID = 0,      
				@RoleID = @RoleID,      
				@RefCCID = 95,    
				@RefNodeid = @ContractID ,    
				@CompanyGUID = @CompanyGUID,      
				@UserName = @UserName,      
				@UserID = @UserID,      
				@LangID = @LangID      

				SET @BnkRcpt  = @return_value 
				
				IF(@DocIDValue = 0 )    
				BEGIN    
					INSERT INTO [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID)      
					VALUES(@ContractID,2,1,@BnkRcpt,@RcptCCID,1,1,95)      
				END     
			END
		END	
		DROP TABLE #tblListReceiptXML    
	END      

        
    declare  @tblExistingPDRcptXML TABLE (ID int identity(1,1),DOCID INT,ccid INT,postingdate float)           
    insert into @tblExistingPDRcptXML     
    select DOCID,CostCenterID,postingdate from  [REN_ContractDocMapping] with(nolock)   
    where contractid=@ContractID and Doctype =2 AND ContractCCID = 95 
    order by sno   
    
    if exists(select * from sys.columns
	where object_id('REN_ContractDocMapping')=object_id and name='IsFreezed')
	BEGIN
		delete from @tblExistingSIVXML
		
		SET @SQL=' select DOCID from  [REN_ContractDocMapping] with(nolock)   
		where contractid='+convert(NVARCHAR(MAX),@ContractID)+' and Doctype =2 AND ContractCCID = 95  AND IsFreezed=1'
		
		insert into @tblExistingSIVXML(DOCID)
		exec(@SQL)
		
		delete from @tblExistingPDRcptXML
		where DOCID in(select DOCID from @tblExistingSIVXML)
	END
	
    declare @totalPreviousPDRcptXML INT    
    select @CNT=0,@totalPreviousPDRcptXML=COUNT(id) from @tblExistingPDRcptXML     
   
	IF(@PDRcptXML is not null and @PDRcptXML<>'')      
	BEGIN      
		
		if exists(select * from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='SinglePDC' and value='true')
			set @SinglePDC	=1
		else
			set @SinglePDC	=0	
			
	   	if exists(select * from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='InclPostingDate' and value='true')
			set @InclPostingDate	=1
		else
			set @InclPostingDate	=0	

		DECLARE @MPSNO NVARCHAR(MAX)       

		SET @XML =   @PDRcptXML       
		CREATE TABLE #tblListPDR(ID int identity(1,1),TRANSXML NVARCHAR(MAX) , DateXML NVARCHAR(MAX), AccountType NVARCHAR(100) ,Documents NVARCHAR(200) )          
		INSERT INTO #tblListPDR        
		SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML')) ,  CONVERT(NVARCHAR(MAX),  X.query('ChequeDocDate')) ,  CONVERT(NVARCHAR(MAX),  X.query('AccountType')) ,  CONVERT(NVARCHAR(200),  X.query('Documents'))                  
		from @XML.nodes('/PDR/ROWS') as Data(X)        

		SELECT @ICNT = 0,@CNT = COUNT(ID) FROM #tblListPDR      
   
		WHILE(@ICNT < @CNT)      
		BEGIN      
			SET @ICNT =@ICNT+1      

			SELECT @AA = TRANSXML , @DateXML = DateXML , @AccountType = AccountType , @Documents = Documents  
			FROM #tblListPDR WHERE  ID = @ICNT      

			SELECT   @AccValue =  X.value ('@DD', 'NVARCHAR(100)' )            
			from @AccountType.nodes('/AccountType') as Data(X)      

			set @DocIDValue=0    
			SELECT @DocIDValue = DOCID   FROM @tblExistingPDRcptXML WHERE  ID = @ICNT     

			SET @DocIDValue = ISNULL(@DocIDValue,0)    
          
			IF(@AccValue = 'BANK')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractPostDatedReceipt'      
			END 
			ELSE  IF(@AccValue = 'Rct')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractBankReceipt'      
			END    
			ELSE  IF(@AccValue = 'CASH')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractCashReceipt'      
			END    
			ELSE  IF(@AccValue = 'JV')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractJVReceipt'      
			END
			ELSE  IF(@AccValue = 'OPB')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=95 and Name='ContractOpeningDoc'      
			END    

			Set @DocXml = convert(nvarchar(max), @AA)      

			set @DELETECCID=0    
			
			if(@SinglePDC	=0)
			BEGIN
				IF(@DocIDValue>0)    
				BEGIN    
					SELECT  @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails  with(nolock)     
					WHERE DOCID = @DocIDValue    
				END 
				    
				if(@DocIDValue >0 AND @DELETECCID <> 0 and @RcptCCID<>@DELETECCID)    
				begin   
					EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
					@CostCenterID = @DELETECCID,      
					@DocPrefix = '',      
					@DocNumber = '',  
					@DOCID = @DocIDValue,  
					@SysInfo =@SysInfo, 
					@AP =@AP,    
					@UserID = 1,      
					@UserName =@UserName,      
					@LangID = 1,
					@RoleID=1

					DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DocIDValue and DOCTYPE =2 AND ContractCCID = 95    

					set @DocIDValue=0       
				end    
			END
			
			
			set @TempDocIDValue =0
			SELECT   @TempDocIDValue =  X.value ('@DocID', 'NVARCHAR(100)'),@DDValue=ISNULL(X.value ('@DDate', 'DateTime'),@ContractDate)            
			from @Documents.nodes('/Documents') as Data(X)  
			   
			set @BillWiseXMl='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
			if(@TempDocIDValue is not null and @TempDocIDValue<>'' and convert(INT,@TempDocIDValue)>0 and @TempDocIDValue= @DocIDValue)
			BEGIN
				set @tempxml=@DocXml    
				select @tempAmt=sum(X.value ('@Amount', 'FLOAT')),@lft =max(X.value ('@CreditAccount', 'INT'))
				from @tempxml.nodes('/DocumentXML/Row/Transactions') as Data(X) 
				
				if ((select isnull(sum(Amount),0) from Acc_docdetails with(nolock) where  DOCID=@DocIDValue 
				and ((StatusID in(369,429) and DocumentType=19) or (OpPdcStatus in(369,429) and DocumentType=16)))=@tempAmt)
					continue;
					
				if exists(select DOCID from Acc_docdetails with(nolock) 
				where  DOCID=@DocIDValue and Amount=@tempAmt and CreditAccount=@lft)
				BEGIN
					set @BillWiseXMl='<XML DontChangeBillwise="1" SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
				END	
			END 
			
			if(@SinglePDC=1)
			BEGIN
				select @DocIDValue=0
				
				iF(@InclPostingDate=1)
					select @DocIDValue=isnull(DOCID ,0)  FROM @tblExistingPDRcptXML WHERE ccid=@RcptCCID and postingdate=convert(float,@DDValue)
				else
					select @DocIDValue=isnull(DOCID ,0)   FROM @tblExistingPDRcptXML WHERE ccid=@RcptCCID 
				 
				
				
				delete from @tblExistingPDRcptXML
				where DOCID=@DocIDValue
			END
			 
			
			if(@DocXml<>'')
			BEGIN
				if(@DocIDValue=-2)
				BEGIN
					set @DocIDValue=0
					set @TempDocIDValue=-2
				END	
					
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @DocXml,@DDValue,@RcptCCID,@Prefix   output

				EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
				@CostCenterID = @RcptCCID,      
				@DocID = @DocIDValue,      
				@DocPrefix =@Prefix,      
				@DocNumber =1,      
				@DocDate = @DDValue,				        
				@DueDate = NULL,      
				@BillNo = @SNO,      
				@InvDocXML = @DocXml,      
				@NotesXML = N'',      
				@AttachmentsXML = N'',      
				@ActivityXML  = @BillWiseXMl,     
				@IsImport = 0,      
				@LocationID = @ContractLocationID,      
				@DivisionID = @ContractDivisionID,      
				@WID = 0,      
				@RoleID = @RoleID,      
				@RefCCID = 95,    
				@RefNodeid = @ContractID ,    
				@CompanyGUID = @CompanyGUID,      
				@UserName = @UserName,      
				@UserID = @UserID,      
				@LangID = @LangID      

				SET @PDRcpt  = @return_value      
	         
				set @XML = @AA 
				
				
				IF(@DocIDValue = 0 )    
				BEGIN    
					if(@TempDocIDValue=-2)
						update [REN_ContractDocMapping]
						set DocID=@PDRcpt
						where [ContractID]=@ContractID  and [Sno]=@ICNT +1 and [Type]=2 and DocType=2
					else
					BEGIN
						IF(@AccValue = 'OPB')
							INSERT INTO  [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID)      
							values(@ContractID,2,@ICNT,@PDRcpt,@RcptCCID,1,2,95  )        
						ELSE
							INSERT INTO  [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID,postingdate)      
							values(@ContractID,2,@ICNT +1,@PDRcpt,@RcptCCID,1,2,95 ,convert(float,@DDValue) )        
					END	
				END   
				ELSE if(@DocIDValue =-2)
					update [REN_ContractDocMapping]
					set DocID=@PDRcpt
					where [ContractID]=@ContractID  and [Sno]=@ICNT +1 and [Type]=2 and DocType=2
			END
			else
			BEGIN
				IF(@DocIDValue = 0 )    
				BEGIN    
					INSERT INTO  [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID)      
					values(@ContractID,2,@ICNT +1,-2,@RcptCCID,1,2,95  )        
				END  
				else if(@DocIDValue >0)
				BEGIN 
						EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
						@CostCenterID = @DELETECCID,      
						@DocPrefix = '',      
						@DocNumber = '',  
						@DOCID = @DocIDValue,  
						@SysInfo =@SysInfo, 
						@AP =@AP,    
						@UserID = 1,      
						@UserName = @UserName,      
						@LangID = 1,
						@RoleID=1

						update [REN_ContractDocMapping]
						set DocID=-2
						where [ContractID]=@ContractID  and [Sno]=@ICNT +1 and [Type]=2 and DocType=2
						
						set @DocIDValue=0  
				END	
			END	
		END
		
		if(@SinglePDC=1)
		BEGIN
			delete from @tblExistingSIVXML
			
			insert into @tblExistingSIVXML(docid)
			select DOCID FROM @tblExistingPDRcptXML
			
			delete from @tblExistingPDRcptXML
			
			insert into @tblExistingPDRcptXML(docid)
			select DOCID FROM @tblExistingSIVXML
			
			select @CNT=min(ID),@totalPreviousPDRcptXML=max(ID) FROM @tblExistingPDRcptXML	
			set @CNT=@CNT-1	
		END
	END
	
	  
      
   IF(@totalPreviousPDRcptXML > @CNT)    
   BEGIN           
	  WHILE(@CNT <  @totalPreviousPDRcptXML)    
	  BEGIN    
	          
	   SET @CNT = @CNT+1    
	   SELECT @DELETEDOCID = DOCID FROM @tblExistingPDRcptXML WHERE ID = @CNT    
	       
	   SELECT  @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails with(nolock)      
	   WHERE DOCID = @DELETEDOCID    
	      
		 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
		@CostCenterID = @DELETECCID,      
		@DocPrefix = '',      
		@DocNumber = '',  
		@DOCID = @DELETEDOCID,  
		@SysInfo =@SysInfo, 
		@AP =@AP,    
		@UserID = 1,      
		@UserName = @UserName,      
		@LangID = 1,
		@RoleID=1
	           
		 DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DELETEDOCID and DOCTYPE =2 AND ContractCCID = 95    
	         
		END    
   END  
     
   SELECT @CNT=0    
        
   IF(@ComRcptXML is not null and @ComRcptXML<>'')      
   BEGIN      
      
  SET @XML =   @ComRcptXML       
        
  declare  @tblExistingComRcptXML TABLE (ID int identity(1,1),DOCID INT)           
  insert into @tblExistingComRcptXML     
  select DOCID from  [REN_ContractDocMapping]   with(nolock) 
  where contractid=@ContractID and Doctype =3 AND ContractCCID = 95    
  declare @totalPreviousComRcptXML INT    
  select @totalPreviousComRcptXML=COUNT(id) from @tblExistingComRcptXML     
      
      
  CREATE TABLE #tblListCOM(ID int identity(1,1),TRANSXML NVARCHAR(MAX) , DateXML NVARCHAR(MAX) , AccountType NVARCHAR(100),Documents NVARCHAR(200) )            
  INSERT INTO #tblListCOM        
  SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML')) ,  CONVERT(NVARCHAR(MAX),  X.query('ChequeDocDate'))  ,  CONVERT(NVARCHAR(MAX),  X.query('AccountType'))  ,  CONVERT(NVARCHAR(200),  X.query('Documents'))                    
  from @XML.nodes('/PARTICULARS//ROWS') as Data(X)        
    
  SELECT @CNT = COUNT(ID) FROM #tblListCOM      
    
  SET @ICNT = 0      
   WHILE(@ICNT < @CNT)      
   BEGIN      
   SET @ICNT =@ICNT+1      
    
   SELECT @AA = TRANSXML , @DateXML = DateXML, @AccountType = AccountType  , @Documents = Documents   FROM #tblListCOM WHERE  ID = @ICNT      
    
   Set @DocXml = convert(nvarchar(max), @AA)      
    
   --Set @DDXML = convert(nvarchar(max), @DateXML)      
    
    
   SELECT   @DocIDValue=0    
   SELECT   @DocIDValue = DOCID from @tblExistingComRcptXML where ID=@ICNT    
    
   SET @DocIDValue = ISNULL(@DocIDValue,0)    
    
   SELECT   @AccValue =  X.value ('@DD', 'NVARCHAR(100)' )            
   from @AccountType.nodes('/AccountType') as Data(X)      
       
   IF(@AccValue = 'BANK')    
   BEGIN    
    declare @prefVal nvarchar(50)    
    set @prefVal=''    
    select @prefVal=Value from COM_CostCenterPreferences WITH(nolock)      
    where CostCenterID=95 and Name='ParticularsPDC'      
    if(@prefVal <>'' and @prefVal='True')    
    begin    
     select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
     where CostCenterID=95 and Name='ContractPostDatedReceipt'      
    end    
    else    
    begin    
     select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
     where CostCenterID=95 and Name='ContractBankReceipt'      
    end     
   END    
   ELSE     
   BEGIN    
    select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
    where CostCenterID=95 and Name='ContractCashReceipt'      
   END    
       
       
	set @DELETECCID=0    
	IF(@DocIDValue>0)    
	BEGIN    
		SELECT  @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails with(nolock)      
		WHERE DOCID = @DocIDValue    
	END  
	  
	if(@DocIDValue>0 AND @DELETECCID <> 0 and @RcptCCID<>@DELETECCID)    
	begin    
		EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
		@CostCenterID = @DELETECCID,      
		@DocPrefix = '',      
		@DocNumber = '',  
		@DOCID = @DocIDValue,  
		@SysInfo =@SysInfo, 
		@AP =@AP,    
		@UserID = 1,      
		@UserName = @UserName,      
		@LangID = 1,
		@RoleID=1

		DELETE FROM REN_ContractDocMapping 
		WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DocIDValue and DOCTYPE =3 AND ContractCCID = 95    

		set @DocIDValue=0       
	end    
    
	set @Prefix=''
	EXEC [sp_GetDocPrefix] @DocXml,@ContractDate,@RcptCCID,@Prefix   output

	EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
	@CostCenterID = @RcptCCID,      
	@DocID = @DocIDValue,      
	@DocPrefix = @Prefix,      
	@DocNumber =1,      
	@DocDate = @ContractDate,        
	@DueDate = NULL,      
	@BillNo = @SNO,      
	@InvDocXML = @DocXml,      
	@NotesXML = N'',      
	@AttachmentsXML = N'',     
	@ActivityXML  = @ActXml,      
	@IsImport = 0,      
	@LocationID = @ContractLocationID,      
	@DivisionID = @ContractDivisionID,      
	@WID = 0,      
	@RoleID = @RoleID,      
	@RefCCID = 95,    
	@RefNodeid = @ContractID ,    
	@CompanyGUID = @CompanyGUID,      
	@UserName = @UserName,      
	@UserID = @UserID,      
	@LangID = @LangID      
         
    SET @CommRcpt  = @return_value      
    
    set @XML = @AA      
         
	IF(@DocIDValue = 0 )    
	BEGIN    
		INSERT INTO [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID    )      
		SELECT  @ContractID,1,X.value('@CONTRACTSNO','int'),@CommRcpt,@RcptCCID,1,3,95        
		FROM @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)      
	END      
END      
       
    IF(@totalPreviousComRcptXML > @CNT)    
    BEGIN    
		WHILE(@CNT <  @totalPreviousComRcptXML)    
		BEGIN    
			SET @CNT = @CNT+1    
			SELECT @DELETEDOCID = DOCID FROM @tblExistingComRcptXML WHERE ID = @CNT    

			SELECT @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails with(nolock)   
			WHERE DOCID = @DELETEDOCID    

			EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
			@CostCenterID = @DELETECCID,      
			@DocPrefix = '',      
			@DocNumber = '',  
			@DOCID = @DELETEDOCID,
			@SysInfo =@SysInfo, 
			@AP =@AP,
			@UserID = 1,      
			@UserName = @UserName,      
			@LangID = 1,
			@RoleID=1

			DELETE FROM REN_ContractDocMapping 
			WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DELETEDOCID and DOCTYPE =3 AND ContractCCID = 95    
		END    
    END    
END      
         
       
      
	IF(@RentRcptXML is not null and @RentRcptXML<>'')      
	BEGIN   
		select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
		where CostCenterID=95 and Name='ContractRentReceipt'      
		SET @XML =   @RentRcptXML       
	   
		declare  @tblExistingRcs TABLE (ID int identity(1,1),DOCID INT)           
		insert into @tblExistingRcs     
		select DOCID from  [REN_ContractDocMapping]  with(nolock)  
		where contractid=@ContractID and DOCTYPE =5 AND ContractCCID = 95    
		declare @totalPreviousRcts INT    
		select @totalPreviousRcts=COUNT(id) from @tblExistingRcs     
       
  CREATE TABLE #tblList(ID int identity(1,1),TRANSXML NVARCHAR(MAX) , DateXML NVARCHAR(MAX))           
  INSERT INTO #tblList        
  SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML') ) ,  CONVERT(NVARCHAR(MAX),  X.query('ChequeDocDate'))          
  from @XML.nodes('/RENTRCT/ROWS') as Data(X)        
       
  SELECT @CNT = COUNT(ID) FROM #tblList      
   SET @ICNT = 0      
  WHILE(@ICNT < @CNT)      
  BEGIN      
   SET @ICNT =@ICNT+1      
       
   SELECT @AA = TRANSXML , @DateXML = DateXML  FROM #tblList WHERE  ID = @ICNT      
       
   if( @totalPreviousRcts>=@ICNT)    
   begin    
  SELECT @DocIDValue = DOCID   FROM @tblExistingRcs WHERE  ID = @ICNT      
   end    
   else    
   begin    
  SELECT @DocIDValue=0    
   end    
   --Set @DDXML = convert(nvarchar(max), @DateXML)      
        
   SELECT   @DDValue =  X.value ('@DD', 'Datetime' )            
   from @DateXML.nodes('/ChequeDocDate') as Data(X)      
   
   if(@incMontEnd=1)
   BEGIN
		if(month(@EndDate)=month(@DDValue) and  year(@EndDate)=year(@DDValue))	
			 set @DDValue=@EndDate
		else
			 set @DDValue=  convert(float,dateadd(d,-1,dateadd(m,datediff(m,0,@DDValue)+1,0)))  
   END
   
   Set @DocXml = convert(nvarchar(max), @AA) 
   set @Prefix=''
   EXEC [sp_GetDocPrefix] @DocXml,@DDValue,@RcptCCID,@Prefix   output
     
   EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
    @CostCenterID = @RcptCCID,      
    @DocID = @DocIDValue,       
    @DocPrefix = @Prefix,      
    @DocNumber =1,      
   -- @DocDate = @ContractDate,       
    @DocDate = @DDValue,       
    @DueDate = NULL,      
    @BillNo = @SNO,      
    @InvDocXML = @DocXml,       
    @NotesXML = N'',      
    @AttachmentsXML = N'',     
    @ActivityXML  = @ActXml,      
    @IsImport = 0,      
    @LocationID = @ContractLocationID,      
    @DivisionID = @ContractDivisionID,      
    @WID = 0,      
    @RoleID = @RoleID,      
    @RefCCID = 95,    
    @RefNodeid = @ContractID ,    
    @CompanyGUID = @CompanyGUID,      
    @UserName = @UserName,      
    @UserID = @UserID,      
    @LangID = @LangID      

		SET @RentRcpt  = @return_value      

		set @XML = @AA      
        
        SELECT @type=ISNULL(X.value('@NodeID','int'),1),@fldsno=X.value('@CONTRACTSNO','int')
		FROM @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)  
		
		IF(@DocIDValue = 0 )    
		BEGIN    
			INSERT INTO [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID)              
			values(@ContractID,@type,@fldsno,@RentRcpt,@RcptCCID,1,5,95)			       
		END    
		ELSE
		BEGIN
			update [REN_ContractDocMapping]
			set [Type]=@type,[Sno]=@fldsno
			where [ContractID]=@ContractID and DocID=@DocIDValue
		END
	END      
       
   IF(@totalPreviousRcts > @CNT)    
   BEGIN    
          
    WHILE(@CNT <  @totalPreviousRcts)    
    BEGIN    
         
  SET @CNT = @CNT+1    
  SELECT @DELETEDOCID = DOCID FROM @tblExistingRcs WHERE ID = @CNT    
      
  SELECT @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails    with(nolock)   
  WHERE DOCID = @DELETEDOCID    
        if @DELETEDOCID is not null
		begin
			EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
		   @CostCenterID = @DELETECCID,      
		   @DocPrefix = '',      
		   @DocNumber = '',  
		   @DOCID = @DELETEDOCID,
		   @SysInfo =@SysInfo, 
		   @AP =@AP,      
		   @UserID = 1,      
		   @UserName = @UserName,      
		   @LangID = 1,
		   @RoleID=1
		end
          
    DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DELETEDOCID and DOCTYPE =5 AND ContractCCID= 95     
        
   END    
   END    
       
 END   
 
     
    END     
    ELSE  IF (@CostCenterID = 104)    
    BEGIN    
        
     IF(@SIVXML is not null and @SIVXML<>'')      
   BEGIN      
  select @ParentID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
  where CostCenterID=104 and Name='PurchasePInvoice'      
  SET @XML = @SIVXML    
         
  declare  @tblExistingPIVXML TABLE (ID int identity(1,1),DOCID INT)           
  insert into @tblExistingPIVXML     
  select DOCID from  [REN_ContractDocMapping] with(nolock)   
  where contractid=@ContractID and Doctype =4 AND ContractCCID = 104    
  declare @totalPreviousPIVXML INT    
  select @totalPreviousPIVXML=COUNT(id) from @tblExistingPIVXML     
   
   CREATE TABLE #tblListPIVTemp(ID int identity(1,1),TRANSXML NVARCHAR(MAX) ,Documents NVARCHAR(200),Recurxml NVARCHAR(MAX))            
   INSERT INTO #tblListPIVTemp        
   SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML'))   ,  CONVERT(NVARCHAR(200),X.query('Documents')),CONVERT(NVARCHAR(MAX),X.query('recurXML')) 
   from @XML.nodes('/PIV//ROWS') as Data(X)        
       
   SELECT @CNT = COUNT(ID) FROM #tblListPIVTemp      
        
   SET @ICNT = 0      
   WHILE(@ICNT < @CNT)      
   BEGIN      
   SET @ICNT =@ICNT+1      
         
   SELECT @AA = TRANSXML , @Documents = Documents    FROM #tblListPIVTemp WHERE  ID = @ICNT      
        
   Set @DocXml = convert(nvarchar(max), @AA)      
        
         
   SELECT   @tempSno =  X.value ('@CONTRACTSNO', 'int' ),@RcptCCID =  ISNULL(X.value ('@CostCenterid', 'int'),@ParentID)            
   from @Documents.nodes('/Documents') as Data(X)      
   
   		SELECT   @DocIDValue=0    
		SELECT   @DocIDValue = DOCID from @tblExistingPIVXML where ID=@ICNT   
    
   SET @DocIDValue = ISNULL(@DocIDValue,0)    
       
   if exists(SELECT IsBillwise FROM ACC_Accounts with(nolock) WHERE AccountID=@RentRecID and IsBillwise=1)    
  begin    
   IF EXISTS(select Value from ADM_GLOBALPREFERENCES with(nolock) where NAME  = 'On')    
   BEGIN    
       
    SET @tempxml =''    
    SET @tempAmt = 0    
    set @tempxml=@DocXml
    
    select @tempAmt=sum(X.value('@Amount',' float'))
	from @tempxml.nodes('/DocumentXML/Row/AccountsXML/Accounts') as Data(X)            
    
    set @BillWiseXMl='<BillWise> <Row DocSeqNo="1" AccountID="'+convert(nvarchar,@RentRecID)+'" AmountFC="-'+CONVERT(nvarchar,@tempAmt)+'" AdjAmount="-'+CONVERT(nvarchar,@tempAmt)+'" AdjCurrID="1" AdjExchRT="1" IsNewReference="1" Narration="" IsDocPDC="0"
  
 ></Row></BillWise>'    
   END    
   ELSE    
   BEGIN    
    set @BillWiseXMl=''    
   END    
  end    
  else    
  begin    
   set @BillWiseXMl=''    
  end    
         set @Prefix=''
     EXEC [sp_GetDocPrefix] @DocXml,@ContractDate,@RcptCCID,@Prefix   output
   
   	set @DocXml=Replace(@DocXml,'<RowHead/>','')
	set @DocXml=Replace(@DocXml,'</DocumentXML>','')
	set @DocXml=Replace(@DocXml,'<DocumentXML>','')

    EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
  @CostCenterID = @RcptCCID,      
  @DocID = @DocIDValue,      
  @DocPrefix = @Prefix,      
  @DocNumber = N'',      
  @DocDate = @ContractDate,      
  @DueDate = NULL,      
  @BillNo = @SNO,      
  @InvDocXML =@DocXml,      
  @BillWiseXML = @BillWiseXMl,      
  @NotesXML = N'',      
  @AttachmentsXML = N'',    
  @ActivityXML = @ActXml,       
  @IsImport = 0,      
  @LocationID = @ContractLocationID,      
  @DivisionID = @ContractDivisionID,    
  @WID = 0,      
  @RoleID = @RoleID,      
  @DocAddress = N'',      
  @RefCCID = 104,    
  @RefNodeid  = @ContractID,    
  @CompanyGUID = @CompanyGUID,      
  @UserName = @UserName,      
  @UserID = @UserID,      
  @LangID = @LangID       
      
   SET @SalesInv  = @return_value      
      
   
		set @Documents=null
		SELECT @Documents = Recurxml    FROM #tblListPIVTemp WHERE  ID = @ICNT  
		
		set @Occurrence=0
		SELECT  @Occurrence=count(X.value ('@Date', 'Datetime' ))
		from @Documents.nodes('/recurXML/Row') as Data(X)
		if(@Occurrence>0)
		BEGIN		 
			set @ScheduleID=0
			select @ScheduleID=ScheduleID from COM_CCSchedules WITH(NOLOCK)
			where CostCenterID=@RcptCCID and NodeID=@SalesInv
			if(@ScheduleID=0)
			BEGIN
				INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
				FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,Occurrence,RecurAutoPost,
				CompanyGUID,GUID,CreatedBy,CreatedDate)
				VALUES('Purchase Contract',1,0,0,0,0,0,0,@StartDate,@EndDate,@Occurrence,0,
						@CompanyGUID,NEWID(),@UserName,@Dt)
				SET @ScheduleID=SCOPE_IDENTITY()  

				INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
				VALUES(@RcptCCID,@SalesInv,@ScheduleID,@UserName,@Dt)
				
				INSERT INTO COM_UserSchedules(ScheduleID,GroupID,RoleID,UserID,CreatedBy,CreatedDate)
				values(@ScheduleID,0,0,@UserID,@UserName,@Dt)	
			END
			ELSE
			BEGIN
				update COM_Schedules
				set StartDate=@StartDate,EndDate=@EndDate,Occurrence=@Occurrence
				where ScheduleID=@ScheduleID
			END
			
			delete from COM_SchEvents
			where ScheduleID=@ScheduleID
			
			INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate,
			SubCostCenterID,NODEID,AttachmentID)
			select @ScheduleID,CONVERT(FLOAT,X.value ('@Date', 'Datetime' )),'Purchase Contract',1,0,CONVERT(FLOAT,X.value ('@Date', 'Datetime' )),CONVERT(FLOAT,X.value ('@Date', 'Datetime' )),
			@CompanyGUID,NEWID(),@UserName,@DT,@ParentID,@SNO,X.value ('@Seq', 'INT' )
			from @Documents.nodes('/recurXML/Row') as Data(X)
			
		END
  set @XML = @AA      
         
   --UPDATE INV_DocDetails    
   --  SET StatusID = @StatusValue    
   --  WHERE DOCID = @return_value    
         
  IF(@DocIDValue = 0 )    
  BEGIN    
    INSERT INTO  [REN_ContractDocMapping]      
      ([ContractID]      
      ,[Type]      
      ,[Sno]      
      ,DocID      
      ,COSTCENTERID    
      ,IsAccDoc     
      ,DocType     
      ,ContractCCID    
      )
      values(@ContractID,1,@tempSno,@SalesInv,@RcptCCID,0,4,104)
     
   END     
    else    
   begin    
   update [REN_ContractDocMapping]    
   set [Sno]=@tempSno    
    where [ContractID]=@ContractID and DocID=@DocIDValue    
   end         
       
       
   END    
       
   IF(@totalPreviousPIVXML > @CNT)    
    BEGIN    
           
  WHILE(@CNT <  @totalPreviousPIVXML)    
  BEGIN    
          
   SET @CNT = @CNT+1    
   SELECT @DELETEDOCID = DOCID FROM @tblExistingPIVXML WHERE ID = @CNT    
       
   SELECT  @DELETECCID = COSTCENTERID FROM dbo.INV_DocDetails   with(nolock)    
   WHERE DOCID = @DELETEDOCID    
         
     EXEC @return_value = [spDOC_DeleteInvDocument]      
    @CostCenterID = @DELETECCID,      
    @DocPrefix = '',      
    @DocNumber = '',  
    @DOCID = @DELETEDOCID,  
    @SysInfo =@SysInfo, 
	@AP =@AP,    
    @UserID = 1,      
    @UserName = @UserName,      
    @LangID = 1,
    @RoleID=1
           
     DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DELETEDOCID and DOCTYPE =4 AND ContractCCID = 104    
       
       set @ScheduleID=0
			select @ScheduleID=ScheduleID from COM_CCSchedules WITH(NOLOCK)
			where CostCenterID=@DELETECCID and NodeID=@DELETEDOCID
			
			if(@ScheduleID>0)
			BEGIN
				delete from COM_CCSchedules
				where ScheduleID=@ScheduleID
				
				delete from COM_UserSchedules
				where ScheduleID=@ScheduleID
				
				delete from COM_SchEvents
				where ScheduleID=@ScheduleID
				
				delete from COM_Schedules
				where ScheduleID=@ScheduleID
			END  
    END    
    END    
  END       
      
	IF(@PDRcptXML is not null and @PDRcptXML<>'')      
	BEGIN      

		set @MPSNO = 0    

		SET @XML =   @PDRcptXML       
		CREATE TABLE #tblListPDP(ID int identity(1,1),TRANSXML NVARCHAR(MAX) , DateXML NVARCHAR(MAX), AccountType NVARCHAR(100) ,Documents NVARCHAR(200) )          
		INSERT INTO #tblListPDP        
		SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML')) ,  CONVERT(NVARCHAR(MAX),  X.query('ChequeDocDate')) ,  CONVERT(NVARCHAR(MAX),  X.query('AccountType')) ,  CONVERT(NVARCHAR(200),  X.query('Documents'))                  
		from @XML.nodes('/PDPayment/ROWS') as Data(X)        

		DECLARE  @tblExistingPDPayXML TABLE (ID int identity(1,1),DOCID INT)           
		INSERT INTO @tblExistingPDPayXML     
		SELECT DOCID from  [REN_ContractDocMapping]  with(nolock)  
		WHERE contractid=@ContractID and Doctype =2 AND ContractCCID = 104 
		order by sno
		   
		DECLARE @totalPreviousPDPayXML INT    
		SELECT @totalPreviousPDPayXML=COUNT(id) from @tblExistingPDPayXML     

		SELECT @CNT = COUNT(ID) FROM #tblListPDP      

		SET @ICNT = 0      
		WHILE(@ICNT < @CNT)      
		BEGIN      
			SET @ICNT =@ICNT+1      

			SELECT @AA = TRANSXML , @DateXML = DateXML , @AccountType = AccountType , @Documents = Documents  FROM #tblListPDP WHERE  ID = @ICNT      

			SELECT   @AccValue =  X.value('@DD', 'NVARCHAR(100)' )            
			from @AccountType.nodes('/AccountType') as Data(X)      

			set @DocIDValue=0    
			SELECT @DocIDValue = DOCID   FROM @tblExistingPDPayXML WHERE  ID = @ICNT     

			SET @DocIDValue = ISNULL(@DocIDValue,0)    

			IF(@AccValue = 'BANK')    
			BEGIN    
				SELECT @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				WHERE CostCenterID=104 and Name='PurchasePostDatedPayment'      
			END    
			ELSE  IF(@AccValue = 'CASH')    
			BEGIN    
				SELECT @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				WHERE CostCenterID=104 and Name='PurchaseCashReceipt'       
			END    
			ELSE  IF(@AccValue = 'JV')    
			BEGIN    
				select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
				where CostCenterID=104 and Name='PurchaseJVReceipt'      
			END    

			Set @DocXml = convert(nvarchar(max), @AA)      

		

			set @DELETECCID=0    
			IF(@DocIDValue>0)    
			BEGIN    
				SELECT  @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails   with(nolock)    
				WHERE DOCID = @DocIDValue  
				if(@DELETECCID=0)
				BEGIN
					DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DocIDValue and DOCTYPE =2 AND ContractCCID = 104
					set @DocIDValue=0        
				END	
			END     
			if(@DocIDValue>0 AND @DELETECCID <> 0 and @RcptCCID<>@DELETECCID)    
			begin    				        
				EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
				@CostCenterID = @DELETECCID,      
				@DocPrefix = '',      
				@DocNumber = '',  
				@DOCID = @DocIDValue,
				@SysInfo =@SysInfo, 
				@AP =@AP,
				@UserID = 1,      
				@UserName = @UserName,      
				@LangID = 1,
				@RoleID=1

				DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DocIDValue and DOCTYPE =2 AND ContractCCID = 104    

				set @DocIDValue=0       
			end  

			set @TempDocIDValue =0
			SELECT   @TempDocIDValue =  X.value('@DocID', 'NVARCHAR(100)' )            
			from @Documents.nodes('/Documents') as Data(X)      

			if(@TempDocIDValue is not null and @TempDocIDValue<>'' and convert(INT,@TempDocIDValue)>0 and @TempDocIDValue= @DocIDValue)
			BEGIN

				set @tempxml=@DocXml    
				select @tempAmt=X.value ('@Amount', 'FLOAT' )            
				from @tempxml.nodes('/DocumentXML/Row/Transactions') as Data(X)  

				if exists(select DOCID from Acc_docdetails with(nolock) where  DOCID=@DocIDValue and Amount=@tempAmt and StatusID=369 and DocumentType=14)
				continue;
			END 

			set @Prefix=''
			EXEC [sp_GetDocPrefix] @DocXml,@ContractDate,@RcptCCID,@Prefix   output

			EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
			@CostCenterID = @RcptCCID,      
			@DocID = @DocIDValue,      
			@DocPrefix = @Prefix,      
			@DocNumber =1,      
			@DocDate = @ContractDate,      
			--@DocDate = @DDValue,      
			@DueDate = NULL,      
			@BillNo = @SNO,      
			@InvDocXML = @DocXml,      
			@NotesXML = N'',      
			@AttachmentsXML = N'',    
			@ActivityXML  = @ActXml,       
			@IsImport = 0,      
			@LocationID = @ContractLocationID,      
			@DivisionID = @ContractDivisionID,      
			@WID = 0,      
			@RoleID = @RoleID,      
			@RefCCID = 104,    
			@RefNodeid = @ContractID ,    
			@CompanyGUID = @CompanyGUID,      
			@UserName = @UserName,      
			@UserID = @UserID,      
			@LangID = @LangID      

			SET @PDRcpt  = @return_value      

			--    UPDATE ACC_DOCDETAILS    
			--SET StatusID = @StatusValue    
			--WHERE DOCID = @return_value    

			set @XML = @AA      

			IF(@DocIDValue = 0 )    
			BEGIN    
				INSERT INTO  [REN_ContractDocMapping]([ContractID]      
				,[Type],[Sno],DocID,CostcenterID,IsAccDoc    
				,DocType, ContractCCID )
				values(@ContractID,2,@ICNT ,         
				@PDRcpt,@RcptCCID,1,2 ,104) 
			END 
			ELSE
			BEGIN
				update [REN_ContractDocMapping]
				set [Sno]=@ICNT 
				where [ContractID]=@ContractID and DocID=@DocIDValue
			END   

		END      

		IF(@totalPreviousPDPayXML > @CNT)    
		BEGIN    

			WHILE(@CNT <  @totalPreviousPDPayXML)    
			BEGIN    

				SET @CNT = @CNT+1    
				SELECT @DELETEDOCID = DOCID FROM @tblExistingPDPayXML WHERE ID = @CNT    

				SELECT  @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails  with(nolock)     
				WHERE DOCID = @DELETEDOCID    

				EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
				@CostCenterID = @DELETECCID,      
				@DocPrefix = '',      
				@DocNumber = '',  
				@DOCID = @DELETEDOCID,
				@SysInfo =@SysInfo, 
				@AP =@AP,      
				@UserID = 1,      
				@UserName = @UserName,      
				@LangID = 1,
				@RoleID=1

				DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DELETEDOCID and DOCTYPE =2 AND ContractCCID = 104    

			END    
		END    

	END      
        
   IF(@ComRcptXML is not null and @ComRcptXML<>'')      
   BEGIN      
      
    SET @XML =   @ComRcptXML       
           
    declare  @tblExistingComPayXML TABLE (ID int identity(1,1),DOCID INT)           
    insert into @tblExistingComPayXML     
    select DOCID from  [REN_ContractDocMapping]  with(nolock)  
    where contractid=@ContractID and Doctype =3 AND ContractCCID = 104    
    declare @totalPreviousComPayXML INT    
   select @totalPreviousComPayXML=COUNT(id) from @tblExistingComPayXML     
          
          
   CREATE TABLE #tblListPayCOM(ID int identity(1,1),TRANSXML NVARCHAR(MAX) , DateXML NVARCHAR(MAX) , AccountType NVARCHAR(100),Documents NVARCHAR(200) )            
   INSERT INTO #tblListPayCOM        
   SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML')) ,  CONVERT(NVARCHAR(MAX),  X.query('ChequeDocDate'))  ,  CONVERT(NVARCHAR(MAX),  X.query('AccountType'))  ,  CONVERT(NVARCHAR(200),  X.query('Documents'))                    
   from @XML.nodes('/PARTICULARS//ROWS') as Data(X)        
       
   SELECT @CNT = COUNT(ID) FROM #tblListPayCOM      
        
   SET @ICNT = 0      
   WHILE(@ICNT < @CNT)      
   BEGIN      
   SET @ICNT =@ICNT+1      
         
   SELECT @AA = TRANSXML , @DateXML = DateXML, @AccountType = AccountType  , @Documents = Documents   FROM #tblListPayCOM WHERE  ID = @ICNT      
         
   Set @DocXml = convert(nvarchar(max), @AA)      
         
   --Set @DDXML = convert(nvarchar(max), @DateXML)      
         
       
   SELECT   @DocIDValue =  X.value ('@DocID', 'NVARCHAR(100)' )            
   from @Documents.nodes('/Documents') as Data(X)      
       
   SET @DocIDValue = ISNULL(@DocIDValue,0)    
      
           
   SELECT   @AccValue =  X.value ('@DD', 'NVARCHAR(100)' )            
   from @AccountType.nodes('/AccountType') as Data(X)      
       
   IF(@AccValue = 'BANK')    
   BEGIN    
       
  set @prefVal=''    
  select @prefVal=Value from COM_CostCenterPreferences WITH(nolock)      
  where CostCenterID=104 and Name='PurchaseParticularsPDC'      
  IF(@prefVal <>'' and @prefVal='True')    
  BEGIN    
   select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
   where CostCenterID=104 and Name='PurchasePostDatedPayment'      
  END    
  ELSE    
  BEGIN    
   select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
   where CostCenterID=104 and Name='PurchaseBankPayment'      
  END     
   END    
   ELSE     
   BEGIN    
  select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
  where CostCenterID=104 and Name='PurchaseCashReceipt'      
   END    
       
        set @Prefix=''
     EXEC [sp_GetDocPrefix] @DocXml,@ContractDate,@RcptCCID,@Prefix   output
   
    EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
    @CostCenterID = @RcptCCID,      
    @DocID = @DocIDValue,      
    @DocPrefix = @Prefix,      
    @DocNumber =1,      
    @DocDate = @ContractDate,      
    --@DocDate = @DDValue,      
    @DueDate = NULL,      
    @BillNo = @SNO,      
    @InvDocXML = @DocXml,      
    @NotesXML = N'',      
    @AttachmentsXML = N'',      
    @ActivityXML  = @ActXml,     
    @IsImport = 0,      
    @LocationID = @ContractLocationID,      
    @DivisionID = @ContractDivisionID,      
    @WID = 0,      
    @RoleID = @RoleID,      
    @RefCCID = 104,    
    @RefNodeid = @ContractID ,    
    @CompanyGUID = @CompanyGUID,      
    @UserName = @UserName,      
    @UserID = @UserID,      
    @LangID = @LangID      
      
    SET @CommRcpt  = @return_value      
           
  --    UPDATE ACC_DOCDETAILS    
  --SET StatusID = @StatusValue    
  --WHERE DOCID = @return_value    
         
    set @XML = @AA      
         
  IF(@DocIDValue = 0 )    
  BEGIN    
     INSERT INTO  [REN_ContractDocMapping]      
     ([ContractID]      
     ,[Type]      
     ,[Sno]      
     ,DocID      
     ,CostcenterID      
     ,IsAccDoc      
     ,DocType    
     ,ContractCCID    
     )      
                    
     SELECT  @ContractID  ,        
    1,        
     X.value('@CONTRACTSNO','int'),         
    @CommRcpt,          
    @RcptCCID,      
    1,3,104        
     FROM @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)      
    END      
   END      
       
    IF(@totalPreviousComPayXML > @CNT)    
    BEGIN    
           
  WHILE(@CNT <  @totalPreviousComPayXML)    
  BEGIN    
          
   SET @CNT = @CNT+1    
   SELECT @DELETEDOCID = DOCID FROM @tblExistingComPayXML WHERE ID = @CNT    
       
   SELECT  @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails   with(nolock)    
   WHERE DOCID = @DELETEDOCID    
         
     EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
    @CostCenterID = @DELETECCID,      
    @DocPrefix = '',      
    @DocNumber = '',  
    @DOCID = @DELETEDOCID,
    @SysInfo =@SysInfo, 
	@AP =@AP,
    @UserID = 1,      
    @UserName = @UserName,      
    @LangID = 1,
    @RoleID=1
           
     DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DELETEDOCID and DOCTYPE =3 AND ContractCCID = 104    
         
    END    
    END    
   END      
       
      
      
  IF(@RentRcptXML is not null and @RentRcptXML<>'')      
   BEGIN      
        
 select @RcptCCID=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
 where CostCenterID=104 and Name='PurchaseBankPayment'      
 SET @XML =   @RentRcptXML       
       
 declare  @tblExistingPayRcs TABLE (ID int identity(1,1),DOCID INT)           
 insert into @tblExistingPayRcs     
 select DOCID from  [REN_ContractDocMapping]  with(nolock)  
 where contractid=@ContractID and DOCTYPE =5 AND ContractCCID = 104    
 declare @totalPreviousPayRcts INT    
 select @totalPreviousPayRcts=COUNT(id) from @tblExistingPayRcs     
       
  CREATE TABLE #tblPayList(ID int identity(1,1),TRANSXML NVARCHAR(MAX) , DateXML NVARCHAR(MAX))           
  INSERT INTO #tblPayList        
  SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML') ) ,  CONVERT(NVARCHAR(MAX),  X.query('ChequeDocDate'))          
  from @XML.nodes('/RENTRCT/ROWS') as Data(X)        
       
  SELECT @CNT = COUNT(ID) FROM #tblPayList      
   SET @ICNT = 0      
  WHILE(@ICNT < @CNT)      
  BEGIN      
   SET @ICNT =@ICNT+1      
       
   SELECT @AA = TRANSXML , @DateXML = DateXML  FROM #tblPayList WHERE  ID = @ICNT      
       
   if( @totalPreviousPayRcts>=@ICNT)    
   begin    
  SELECT @DocIDValue = DOCID   FROM @tblExistingPayRcs WHERE  ID = @ICNT      
   end    
   else    
   begin    
  SELECT @DocIDValue=0    
   end    
   --Set @DDXML = convert(nvarchar(max), @DateXML)      
        
   SELECT   @DDValue =  X.value ('@DD', 'NVARCHAR(MAX)' )            
   from @DateXML.nodes('/ChequeDocDate') as Data(X)      
     
         
   Set @DocXml = convert(nvarchar(max), @AA)     
   
         set @Prefix=''
     EXEC [sp_GetDocPrefix] @DocXml,@DDValue,@RcptCCID,@Prefix   output
   
   EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
    @CostCenterID = @RcptCCID,      
    @DocID = @DocIDValue,      
    @DocPrefix = @Prefix,      
    @DocNumber =1,      
   -- @DocDate = @ContractDate,       
    @DocDate = @DDValue,      
    @DueDate = NULL,      
    @BillNo = @SNO,      
    @InvDocXML = @DocXml,      
    @NotesXML = N'',      
    @AttachmentsXML = N'',      
    @ActivityXML  =@ActXml,     
    @IsImport = 0,      
    @LocationID = @ContractLocationID,      
    @DivisionID = @ContractDivisionID,      
    @WID = 0,      
    @RoleID = @RoleID,      
    @RefCCID = 104,    
    @RefNodeid = @ContractID ,    
    @CompanyGUID = @CompanyGUID,      
    @UserName = @UserName,      
    @UserID = @UserID,      
    @LangID = @LangID      
   
         
       SET @RentRcpt  = @return_value      
      
    --UPDATE ACC_DOCDETAILS    
    --SET StatusID = @StatusValue    
    --WHERE DOCID = @return_value    
        
       set @XML = @AA      
        
      IF(@DocIDValue = 0 )    
    BEGIN    
  INSERT INTO  [REN_ContractDocMapping]      
     ([ContractID]      
     ,[Type]      
     ,[Sno]      
     ,DocID      
     ,CostcenterID      
     ,IsAccDoc    
     ,DocType      
     , ContractCCID    
     )      
                   
     SELECT  @ContractID  ,        
     X.value('@NodeID','int'),         
     X.value('@CONTRACTSNO','int'),         
    @RentRcpt,          
    @RcptCCID,      
    1,5 , 104        
     FROM @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)        
       END    
      
   END      
       
   IF(@totalPreviousPayRcts > @CNT)    
   BEGIN    
          
    WHILE(@CNT <  @totalPreviousPayRcts)    
    BEGIN    
         
  SET @CNT = @CNT+1    
  SELECT @DELETEDOCID = DOCID FROM @tblExistingPayRcs WHERE ID = @CNT    
      
  SELECT  @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails   with(nolock)    
  WHERE DOCID = @DELETEDOCID    
        
    EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
   @CostCenterID = @DELETECCID,      
   @DocPrefix = '',      
   @DocNumber = '',  
   @DOCID = @DELETEDOCID,
   @SysInfo =@SysInfo, 
   @AP =@AP,      
   @UserID = 1,      
   @UserName = @UserName,      
   @LangID = 1,
   @RoleID=1
          
    DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  AND DOCID =  @DELETEDOCID and DOCTYPE =5 AND ContractCCID= 104     
        
   END    
   END    
       
 END        
         
    END    
      
   -------------------------- END POSTINGS -----------------------      
     
    set @UpdateSql='update [REN_ContractExtended] SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',
	[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@ContractID)      
	exec(@UpdateSql)      

	set @UpdateSql='update COM_CCCCDATA SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',
	[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID ='+convert(nvarchar,@ContractID) + ' AND CostCenterID = 95'       	  
	exec(@UpdateSql)        
	
	if(@AUDITSTATUS= 'EDIT')
	BEGIN
			UPDATE b
			SET CreatedBy=c.CreatedBy,CreatedDate=c.CreatedDate,ModifiedBy=c.ModifiedBy,ModifiedDate=c.ModifiedDate
			from ACC_DOCDETAILS b with(nolock) 
			join REN_Contract C with(nolock) on C.ContractID=@ContractID
			where b.RefCCID= @CostCenterID and b.RefNodeid=@ContractID	
			
			UPDATE b
			SET CreatedBy=c.CreatedBy,CreatedDate=c.CreatedDate,ModifiedBy=c.ModifiedBy,ModifiedDate=c.ModifiedDate
			from INV_DOCDETAILS b with(nolock) 
			join REN_Contract C with(nolock) on C.ContractID=@ContractID
			where b.RefCCID= @CostCenterID and b.RefNodeid=@ContractID			
	END
     
     
	IF  (@CostCenterID in(95,104) )
	BEGIN
		DECLARE @CCNODEIDCONT INT   

		SELECT @CCNODEIDCONT = CCNODEID  ,@Dimesion = CCID FROM REN_CONTRACT  with(nolock)
		WHERE CONTRACTID = @ContractID  
		
		IF(@Dimesion IS NOT NULL AND @Dimesion <> '' AND  @Dimesion  > 50000)  
		BEGIN  
			DECLARE @CCMapSql nvarchar(max)    

			set @CCMapSql='update COM_CCCCDATA      
			SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+'  WHERE NodeID = '+convert(nvarchar,@ContractID) + ' AND CostCenterID = 95'     
			EXEC (@CCMapSql)
			
			set @CCMapSql=' UPDATE a    
			SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+' 
			from COM_DOCCCDATA a with(nolock) 
			join ACC_DOCDETAILS b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID
			where b.RefCCID=95 and b.RefNodeid='+convert(nvarchar,@ContractID)+ '
			
			UPDATE a    
			SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+' 
			from COM_DOCCCDATA a with(nolock) 
			join INV_DOCDETAILS b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID
			where b.RefCCID=95 and b.RefNodeid='+convert(nvarchar,@ContractID)  
			EXEC (@CCMapSql)   
			
			set @CCMapSql=' UPDATE a    
			SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+' 
			from COM_DOCCCDATA_history a with(nolock) 
			join ACC_DOCDETAILS b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID
			where b.RefCCID=95 and b.RefNodeid='+convert(nvarchar,@ContractID)+ '
			
			UPDATE a    
			SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+' 
			from COM_DOCCCDATA_history a with(nolock) 
			join INV_DOCDETAILS b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID
			where b.RefCCID=95 and b.RefNodeid='+convert(nvarchar,@ContractID)  
			EXEC (@CCMapSql)   
			
			set @CCMapSql=' UPDATE a
			SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+'  
			from COM_Billwise a with(nolock) 
			join ACC_DOCDETAILS b with(nolock)  on a. DocNo=b.VoucherNo
			where b.RefCCID=95 and b.RefNodeid='+convert(nvarchar,@ContractID) 
			EXEC (@CCMapSql)   
			 
			Exec [spDOC_SetLinkDimension]
					@InvDocDetailsID=@ContractID, 
					@Costcenterid=@CostCenterID,         
					@DimCCID=@Dimesion,
					@DimNodeID=@CCNODEIDCONT,
					@UserID=@UserID,    
					@LangID=@LangID    
			
		END 
		
		
		if(@WID>0)
		BEGIN	 
			
			SET @XML= @ExtraXML    
			set @HasAccess=0
			select @HasAccess=isnull(X.value('@IsFromApprove','BIT'),0),@UpdateSql=isnull(X.value('@L1Remarks','nvarchar(max)'),'')
			FROM @XML.nodes('/XML') as Data(X)      		          
			
			if(@HasAccess!=1)
			BEGIN
				INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID   
				  ,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)      
				VALUES(@COSTCENTERID,@ContractID,@StatusID,@DT,@UpdateSql,@UserID
				  ,@CompanyGUID,newid(),@UserName,@DT,isnull(@level,0),0)
				  
				EXEC spCOM_SetNotifEvent 371,@CostCenterID,@ContractID,@CompanyGUID,@UserName,@UserID,@RoleID  
			END
			
		    if(@StatusID not in(426,427))
			BEGIN
				update INV_DOCDETAILS
				set StatusID=371
				FROM INV_DOCDETAILS a WITH(NOLOCK)
				join REN_CONTRACTDOCMAPPING b WITH(NOLOCK) on a.DocID=b.DocID 
				WHERE CONTRACTID = @ContractID  AND ISACCDOC = 0 and RefNodeID = @ContractID    
						
				update ACC_DOCDETAILS
				set StatusID=371
				FROM ACC_DOCDETAILS b WITH(NOLOCK)
				join INV_DOCDETAILS a WITH(NOLOCK) on b.INVDOCDETAILSID=a.INVDOCDETAILSID
				join REN_CONTRACTDOCMAPPING c WITH(NOLOCK) on a.DocID=c.DocID 
				WHERE CONTRACTID = @ContractID  AND ISACCDOC = 0 and a.RefNodeid = @ContractID    

				update ACC_DOCDETAILS
				set StatusID=371
				FROM ACC_DOCDETAILS a WITH(NOLOCK)
				join REN_CONTRACTDOCMAPPING b WITH(NOLOCK) on a.DocID=b.DocID 
				WHERE CONTRACTID = @ContractID AND ISACCDOC = 1  and RefNodeID = @ContractID
				and not (StatusID in(369,429) and DocumentType in(14,19))
			END	
		END	
		
		if(@CostCenterID =95)
		BEGIN
			Exec @Selectedlft=[dbo].[spREN_GetDimensionNodeID]
					 @NodeID  =@UnitID,      
					 @CostcenterID = 93,   
					 @UserID =@UserID,      
					 @LangID =@LangID,
					 @Dimesion=@lft output
		 
			Exec @Selectedrgt=[dbo].[spREN_GetDimensionNodeID]
					 @NodeID  =@TenantID,      
					 @CostcenterID = 94,   
					 @UserID =@UserID,      
					 @LangID =@LangID,	
					 @Dimesion=@rgt output 
					 
			if not exists(select * from COM_CostCenterCostCenterMap a WITH(NOLOCK)
			 where ParentCostCenterID=@rgt and ParentNodeID=@Selectedrgt
			 and CostCenterID=@lft and NodeID=@Selectedlft)
			BEGIN 
				INSERT INTO  COM_CostCenterCostCenterMap (ParentCostCenterID,ParentNodeID,CostCenterID,
				NodeID,GUID,CreatedBy,CreatedDate)
				values( @rgt ,@Selectedrgt,@lft,@Selectedlft,newid(),@UserName,@Dt)
				INSERT INTO  COM_CostCenterCostCenterMap (ParentCostCenterID,ParentNodeID,CostCenterID,
				NodeID,GUID,CreatedBy,CreatedDate)
				values( 94 ,@TenantID,@lft,@Selectedlft,newid(),@UserName,@Dt)
			END 
		
			delete from [REN_Contract] where RefContractID=@ContractID
			if(@MultiUnitIds is not null and @MultiUnitIds<>'' )
			BEGIN         
				update REN_Units
				set ContractID=@ContractID
				where UnitID=@UnitID

				declare @ChildUnits table(UnitID INT)  
				insert into @ChildUnits  
				exec SPSplitString @MultiUnitIds,','

				INSERT INTO  [REN_Contract] ([ContractPrefix],SNO,[ContractDate]        
					,[ContractNumber],[StatusID],[PropertyID],[UnitID],[TenantID],[RentAccID],[IncomeAccID]        
					,[Purpose],[StartDate],[EndDate],[ExtendTill],[TotalAmount],[NonRecurAmount],[RecurAmount]        
					,[Depth],[ParentID],[lft],[rgt],[IsGroup],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate]       
					,[LocationID],[DivisionID],[CurrencyID],[TermsConditions],[SalesmanID],[AccountantID],[LandlordID]    
					,Narration,[CostCenterID],CCNodeID,CCID,VacancyDate,BasedOn,RefContractID,RenewRefID,NoOfUnits)
				select [ContractPrefix],SNO,[ContractDate]        
					,[ContractNumber],[StatusID],[PropertyID],b.UnitID,[TenantID],[RentAccID],[IncomeAccID]        
					,[Purpose],[StartDate],[EndDate],[ExtendTill],[TotalAmount],[NonRecurAmount],[RecurAmount]        
					,[Depth],[ParentID],[lft],[rgt],[IsGroup],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate]       
					,[LocationID],[DivisionID],[CurrencyID],[TermsConditions],[SalesmanID],[AccountantID],[LandlordID]    
					,Narration,[CostCenterID],CCNodeID,CCID,VacancyDate,BasedOn,@ContractID,RenewRefID,1 
				FROM [REN_Contract] a with(nolock),@ChildUnits b
				where ContractID=@ContractID
				
				UPDATE REN_Contract SET NoOfUnits=(SELECT COUNT(*) FROM @ChildUnits) WHERE ContractID=@ContractID
				
				select @PrefValue = Value from COM_CostCenterPreferences with(nolock)
				where CostCenterID= 93  and  Name = 'LinkDocument'
				
				set @Dimesion=0

				if(@PrefValue is not null and @PrefValue<>'')
				begin
					begin try
						select @Dimesion=convert(INT,@PrefValue)
					end try
					begin catch
						set @Dimesion=0
					end catch
				END	
				if(@Dimesion>0)
				begin
					Declare @TabName nvarchar(max)     
				 
					select @TabName = TableName  from adm_features with(nolock) where FeatureID=@Dimesion     
					    
					set @CCMapSql=' SELECT @CCNODEIDCONT = NODEID FROM ' + @TabName +'  with(nolock) where   Name = N'''+@MultiUnitName+''''  
				     				 
					EXEC sp_executesql @CCMapSql,N'@CCNODEIDCONT INT OUTPUT', @CCNODEIDCONT OUTPUT  
					
					set @CCMapSql='update COM_CCCCDATA      
					SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+'  WHERE NodeID = '+convert(nvarchar,@ContractID) + ' AND CostCenterID = 95'     
					EXEC (@CCMapSql)
				
					set @CCMapSql=' UPDATE a    
					SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+' 
					from COM_DOCCCDATA a with(nolock) 
					join ACC_DOCDETAILS b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID
					where a.DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'=1 and b.RefCCID=95 and b.RefNodeid='+convert(nvarchar,@ContractID)+ '
					
					UPDATE a    
					SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+' 
					from COM_DOCCCDATA a with(nolock) 
					join INV_DOCDETAILS b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID
					where  a.DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'=1 and b.RefCCID=95 and b.RefNodeid='+convert(nvarchar,@ContractID)  
					EXEC (@CCMapSql)   
					
					set @CCMapSql=' UPDATE a
					SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+'  
					from COM_Billwise a with(nolock) 
					join ACC_DOCDETAILS b with(nolock)  on a. DocNo=b.VoucherNo
					where  a.DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'=1 and b.RefCCID=95 and b.RefNodeid='+convert(nvarchar,@ContractID)
					
					EXEC (@CCMapSql)
					
					if(@LinkedQuotationID>0)
					BEGIN
						set @CCMapSql=' UPDATE a    
						SET DCCCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@CCNODEIDCONT)+' 
						from COM_DOCCCDATA a with(nolock) 
						join ACC_DOCDETAILS b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID
						where b.RefCCID=129 and b.RefNodeid='+convert(nvarchar,@LinkedQuotationID)
						EXEC (@CCMapSql)  
					END	  
				END 
			END 
		END
	END
	--Insert Notifications    
	DECLARE @ActionType INT    
	IF @AUDITSTATUS='ADD'    
		SET @ActionType=1    
	ELSE    
		SET @ActionType=3     
      
	EXEC spCOM_SetNotifEvent @ActionType,@CostCenterID,@ContractID,@CompanyGUID,@UserName,@UserID,@RoleID  
	
	IF(@AUDITSTATUS = 'ADD')
	BEGIN
		select @PrefValue = Value from COM_CostCenterPreferences WITH(nolock)  
		where CostCenterID=95 and  Name = 'CallExternalFunction'  
		
		IF(@PrefValue ='True')
		BEGIN
			EXEC spREN_ExternalFunction 95,@ContractID
		END
	END
	
	if exists(select Value from COM_CostCenterPreferences WITH(nolock)  
		where CostCenterID=95 and  Name = 'UseExternal'  and Value='true')	
		EXEC [spEXT_RentalPostings] @ContractID,@sno,@CompanyGUID,@UserName,@RoleID,@UserID,@LangID

	--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode @CostCenterID,@ContractID,@UserID,@LangID
	end
	
	
COMMIT TRANSACTION
	--rollback TRANSACTION       
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)         
	WHERE ErrorNumber=100 AND LanguageID=@LangID        
	SET NOCOUNT OFF;         
	         
	RETURN @ContractID            
END TRY            
BEGIN CATCH      
	if(@return_value is null or  @return_value<>-999)       
	BEGIN            
		IF ERROR_NUMBER()=50000        
		BEGIN 
			IF ISNUMERIC(ERROR_MESSAGE())<>1			
				SELECT ERROR_MESSAGE() ErrorMessage,ERROR_NUMBER() ErrorNumber
			ELSE  
				SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)         
				WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
		END        
		ELSE IF ERROR_NUMBER()=547        
		BEGIN        
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
			FROM COM_ErrorMessages WITH(nolock)        
			WHERE ErrorNumber=-110 AND LanguageID=@LangID        
		END        
		ELSE IF ERROR_NUMBER()=2627        
		BEGIN        
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
			FROM COM_ErrorMessages WITH(nolock)        
			WHERE ErrorNumber=-116 AND LanguageID=@LangID        
		END        
		ELSE        
		BEGIN        
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine        
			FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
		END         
		if(@return_value is null or  @return_value<>-999)     
			ROLLBACK TRANSACTION      
	END        
	SET NOCOUNT OFF            
	RETURN -999
END CATCH     


GO
