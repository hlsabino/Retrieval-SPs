USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetTempInvDoc]
	@CostCenterID [int],
	@DocID [int],
	@DocPrefix [nvarchar](50),
	@DocNumber [nvarchar](500),
	@DocDate [datetime],
	@DueDate [datetime] = NULL,
	@BillNo [nvarchar](500),
	@InvDocXML [nvarchar](max),
	@BillWiseXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@ActivityXML [nvarchar](max),
	@IsImport [bit],
	@LocationID [int],
	@DivisionID [int],
	@WID [int],
	@RoleID [int],
	@DocAddress [nvarchar](max) = null,
	@RefCCID [int],
	@RefNodeid [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1,
	@IsOffline [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY        
SET NOCOUNT ON;  

	--Declaration Section      
	DECLARE @QUERYTEST NVARCHAR(100),@TYPE NVARCHAR(100),@Guid nvarchar(50),@ISSerial  BIT,@IsBatChes BIT,@IsDynamic BIT,@IStempINFO BIT,@UNIQUECNT int
	
	DECLARE  @tempDOc INT,@HasAccess int,@ACCOUNT1 INT,@ACCOUNT2 INT,@ACCOUNT1Name nvarchar(500),@ACCOUNT2Name nvarchar(500),@DDocDate DateTime      
	DECLARE @Dt float,@XML XML,@DocumentTypeID INT ,@DocumentType INT,@DocAbbr nvarchar(50),@ProductName nvarchar(500),@ProductID INT,@AP varchar(10)        
	DECLARE @InvDocDetailsID INT,@I int,@Cnt int,@SQL NVARCHAR(MAX),@VoucherNo NVARCHAR(500),@ProductType int,@VoucherType int,@BILLDate FLOAT      
	DECLARE @TRANSXML XML,@NUMXML XML,@CCXML XML,@TEXTXML XML,@EXTRAXML XML,@PromXML nvarchar(max),@AccountsXML XML,@VersionNo INT ,@vno nvarchar(max) ,@tVersionNo INT  
	DECLARE @Length int,@temp Nvarchar(100),@t int ,@DocOrder int,@IsRevision BIT  ,@ind int,@indcnt int,@SECTIONID INT,@holseq int,@DocCC nvarchar(max)
	DECLARE @return_value int,@TEMPxml NVARCHAR(max),@TEMPxmlParent NVARCHAR(max),@PrefValue NVARCHAR(500),@LinkedID INT,@oldStatus int,@ImpDocID INT,@frdate datetime,@toDate datetime,@varxml xml
	declare @level int,@maxLevel int,@StatusID int,@ReviseReason  nvarchar(max) ,@Iscode INT,@QtyAdjustments XML,@DocExtraXML XML,@BinsXML XML,@TEmpWid INT,@DeprXML nvarchar(max)
	declare @TotLinkedQty float,@CheckHold bit,@AppRejDate datetime,@Remarks nvarchar(max),@Series int,@prefixCCID INT,@DUP_VoucherNo NVARCHAR(max)   
	declare @DetailIDs nvarchar(max),@HistoryStatus nvarchar(50),@DUPLICATECODE  NVARCHAR(MAX),@IsLockedPosting BIT,@BinDimesion INT,@BinDimesionNodeID INT
	DECLARE @PrefValueDoc BIT , @hideBillNo BIT   ,@QtyFin FLOAT , @QthChld FLOAT,@Dimesion INT,@DimesionNodeID INT,@cctablename nvarchar(50),@bi int,@bcnt int
	DECLARE @ConsolidatedBatches nvarchar(50),@Tot float,@BatchID INT,@OldBatchID INT,@NID INT,@DLockCC INT,@DLockCCValues NVARCHAR(max),@LockCC INT,@LockCCValues NVARCHAR(max)
	declare @loc int,@div int,@dim int,@IsQtyIgnored BIT,@WHERE nvarchar(max),@tempProd INT,@CCGuid nvarchar(100),@LineWiseApproval bit,@sysinfo nvarchar(max)
	declare @ddxml nvarchar(max),@bxml nvarchar(max),@ddID INT,@Prefix nvarchar(200),@AUTOCCID INT,@DetIDS nvarchar(max),@CCStatusID int,@TempDocDate DATETIME,@tempLevel INT   
	DECLARE @EMPYEAR NVARCHAR(20),@EMPCODE INT,@DocGrade INT,@RefBatchID INT,@batchCol nvarchar(100),@CC nvarchar(max),@Columnname nvarchar(100),@fromvno nvarchar(200)
	DECLARE @EMPID INT,@LEAVETYPE INT,@FromDate DATETIME,@TDate DATETIME,@DocLoc INT,@actDocDate INT,@AssignLeaves float,@LeaveYear varchar(5),@LoctID INT,@DailyattendanceDate1 datetime,@ActXml nvarchar(max),@Regime NVARCHAR(10)
	
	declare @Codetemp table (prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200),IsManualCode bit)
	declare @tblBILL TABLE(ID int identity(1,1),AccountID BIGINT, Amount FLOAT, DocNo NVARCHAR(500),AccName nvarchar(max),AdjCurrID INT,AdjExchRT FLOAT)        
	declare @caseTab table(id int identity(1,1),CaseID INT,StartDate DATETIME,StartTime NVARCHAR(20),EndDate  DATETIME,EndTime  NVARCHAR(20),AssignedTo INT,Remarks NVARCHAR(MAX),SERIALNUMBER NVARCHAR(MAX))
	declare @CustomerName nvarchar(500),@CaseNumber nvarchar(500),@SERIALNUMBER nvarchar(500),@CaseID INT,@Assignedto INT,@CaseDate float
	declare @LockCrAcc INT,@LockDrAcc INT,@AccLockDate DATETIME,@AccType nvarchar(max),@CAccountTypeID INT,@DAccountTypeID INT,@IsUniqueDoc BIT,@UniqueDefn NVARCHAR(MAX),@UniqueQuery NVARCHAR(MAX),@UniqueCount INT,@SYSCOL NVARCHAR(50)
	declare @TblUnique TABLE(ID INT IDENTITY(1,1),UsedColumn nvarchar(100))
	DECLARE @AuditTrial BIT, @QTYADJ NVARCHAR(MAX),@QTYADJSQ NVARCHAR(MAX)
	--Loading Global Preferences
	DECLARE @TblPref AS TABLE(Name nvarchar(100),Value nvarchar(max),IsGlobal BIT)
	INSERT INTO @TblPref
	SELECT Name,Value,1 FROM ADM_GlobalPreferences with(nolock)
	WHERE Name IN ('LockTransactionAccountType','Lock Data Between','LockCostCenterNodes','LockCostCenters'
	,'ShowProdCodeinErrMsg','NetFld','DimensionwiseBins','ConsiderHoldAndReserveAsIssued','SkipNegonReserve','ConsiderExpectedAsReceived','DW Batches','LW Batches','Maintain Dimensionwise Batches','DoNotAllowFutureDateDays','NoFuturetransaction','PosCoupons','EnableLocationWise','Location Stock','Check for -Ve Stock','NegatvieSotckSysDate','DontSaveReOrderLevelExceeds','Maintain Dimensionwise stock','Dontallowreceiptafterissue'
	,'LoyaltyOn','GBudgetUnapprove','ConsiderUnAppInHold','ReportDims','HoldResCancelledDocs','LW SNOS','DW SNOS','GNegativeUnapprove','DocDateasPostedDate','UseDimWiseLock','Nobackdatedtransaction','POSItemCodeDimension','EnableSerialProducts','EnableBatchProducts','EnableDynamicProducts','EnableDivisionWise','Division Stock','DimensionwiseCurrency','BaseCurrency','DecimalsinAmount','DoNotAllowPastDateDays','NoPasttransaction')
	 
	--Loading Document Preferences	
	INSERT INTO @TblPref
	SELECT PrefName,PrefValue,0 FROM COM_DocumentPreferences with(nolock)
	WHERE CostCenterID=@CostCenterID and PrefName IN ('DocumentLinkDimension','AllowDuplicate','ApprOnComparitiveAnalysis','AutoCode','BillwisePosting','Lock Data Between','EnableAssetSerialNo','UseasGiftVoucher'
	,'UseAsDownPmt','DocwiseSNo','PrepaymentDoc','Paypercent','ValueType','onsystemdate','Billlanding','SameserialNo','Enabletolerance','DontSaveCompleteLinked','DisableQtyCheck','AllowMultipleLinking','VendorBasedBillNo','BillNoDocs','Hide_Billno','DuplicateProductClubBins','LockCostCenterNodes','LockCostCenters','DocQtyAdjustment'
	,'PostRevisOnSysDate','RevisPrefix','ConsBatch','VatAdvanceDoc','PostAsset','DimTransferSrc','IsBudgetDocument','UseQtyAdjustment','UpdateDueDate','UpdateLinkQty','UpdateLinkValue','UpdateJustReference','ExecReq','LinkForward','AuditTrial','EnableRevision','Autopostdocument','CrossDimDocument','CrossDimField','OverrideLock','Checkallproducts','ShortageDOC','ExcessDOC'
	,'ResRMDOc','ReleaseRMDOc','UseasOpeningDownPayment','CreditSupplierDownPayment','ResRMINVID','ReserveRM','EnablePromotions','BOEInv','UseAsOrder','BinvInv','OnPosted','samebatchtoall','DocDateasPostedDate','GenerateSeq','EnableUniqueDocument','backTrackDocs','BackTrack','AssignVendors','DoNotEmailOrSMSUn-ApprovedDocuments','DumpStockCodes','DonotupdateInventory','DonotupdateAccounts','TempInfo','DonotAllowtoLinkPostdatedDocuments')
			
	set @batchCol=''
	if exists(select Value from @TblPref where IsGlobal=0 and Name='samebatchtoall' and Value='true')
	BEGIN
		select @batchCol=SysColumnName from ADM_CostCenterDef with(nolock)
		where CostCenterID=@CostCenterID and ColumnCostCenterID=16 and SysColumnName like 'dcalpha%'
	END
	
	set @DocCC=''
	select @DocCC =@DocCC +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData' and a.name like 'dcCCNID%'
	
	if(@IsImport=1)
	BEGIN
		set @CC='update Com_Billwise set '
		select @CC =@CC +a.name+'=a.'+a.name+',' from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='COM_DocCCData' and a.name like 'dcCCNID%'
		set @CC=substring(@CC,0,len(@CC))+' from [COM_DocCCData] a with(nolock) '
		
		 if(@BillWiseXML <>'')      
		 BEGIN      
			SET @XML=@BillWiseXML
			INSERT INTO @tblBILL      
			SELECT case when ISNUMERIC(X.value('@AccountID','nvarchar(500)'))=1 THEN ISNULL( X.value('@AccountID','BIGINT'),0)
			  else 0 end       
			,X.value('@AdjAmount','float')       
			,X.value('@RefDocNo','varchar(50)')
			,X.value('@AccountID','nvarchar(500)')
			,ISNULL(X.value('@AdjCurrID','INT'),1)
			,ISNULL(X.value('@AdjExchRT','float'),1) 
			from @XML.nodes('/BillWise/Row') as Data(X)      
		end
	END
	ELSE
	BEGIN
	
		set @CC=''
		select @CC =@CC +a.name+',' from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='COM_DocCCData' and a.name like 'dcCCNID%'
		set @CC=substring(@CC,0,len(@CC))
	END
	
	 if(@DocID=0 and exists(select value from @TblPref where IsGlobal=0 and Name='onsystemdate' and Value='true'))
			set @DocDate=CONVERT(datetime,floor(convert(float,getdate())))
	 
	 set @PrefValue=''
	 select @PrefValue=Value from @TblPref where IsGlobal=1 and  Name='NoFuturetransaction'    
	 if(@PrefValue='true')
	 BEGIN
		set @ind=0
		select @ind=isnull(Value,0) from @TblPref where IsGlobal=1 and  Name='DoNotAllowFutureDateDays'
		and  isnumeric(Value)=1

		if(CONVERT(float,@DocDate)>FLOOR(CONVERT(float,GETDATE()))+@ind)
			RAISERROR('-530',16,1)  
	 END
	 
	 set @PrefValue=''
	 select @PrefValue=Value from @TblPref where IsGlobal=1 and  Name='NoPasttransaction'    
	 if(@PrefValue='true')
	 BEGIN
		set @ind=0
		select @ind=isnull(Value,0) from @TblPref where IsGlobal=1 and  Name='DoNotAllowPastDateDays'
		and  isnumeric(Value)=1
		
		if(CONVERT(float,@DocDate)<FLOOR(CONVERT(float,GETDATE()))-@ind)
			RAISERROR('-531',16,1) 
	 END
	 
	 set @PrefValue=''
	 select @PrefValue=Value from @TblPref where IsGlobal=1 and  Name='Nobackdatedtransaction'    
	 if(@PrefValue='true' and @DocID=0)
	 BEGIN
		if exists(select CostCenterID from INV_DocDetails WITH(NOLOCK) where CostCenterID=@CostCenterID and DocDate>CONVERT(float,@DocDate))
			RAISERROR('-531',16,1)  
	 END
	 
	 SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,673)
	 if(@HasAccess=1)
	 BEGIN
		SELECT @tempProd=FeatureActionID FROM ADM_FeatureAction WITH(nolock)
		WHERE  FeatureID=@CostCenterID AND FeatureActionTypeID=673
		
		set @ind=0
		SELECT @ind=CONVERT(int,Description) FROM ADM_FeatureActionRoleMap WITH(nolock)
		WHERE RoleID=@RoleID AND FeatureActionID=@tempProd and ISNUMERIC(Description)=1

		if(CONVERT(float,@DocDate)>FLOOR(CONVERT(float,GETDATE()))+@ind)
			RAISERROR('-530',16,1)  
	 END
	 
	 SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,672)
	 if(@HasAccess=1)
	 BEGIN
		SELECT @tempProd=FeatureActionID FROM ADM_FeatureAction WITH(nolock)
		WHERE  FeatureID=@CostCenterID AND FeatureActionTypeID=672
		
		set @ind=0
		SELECT @ind=CONVERT(int,Description) FROM ADM_FeatureActionRoleMap WITH(nolock)
		WHERE RoleID=@RoleID AND FeatureActionID=@tempProd and ISNUMERIC(Description)=1

		if(CONVERT(float,@DocDate)<FLOOR(CONVERT(float,GETDATE()))-@ind)
			RAISERROR('-531',16,1) 
	 END

	 
	 set @LineWiseApproval=0
	 set @IsLockedPosting=0	
	 set @tempProd=0
	 select @PrefValue=Value from com_costcenterpreferences WITH(NOLOCK)   
	 where costcenterid=3 and name='TempPartProduct' and isnumeric(Value)=1 

	 if(@PrefValue is not null and @PrefValue<>'' and @PrefValue<>'0')
		set @tempProd=convert(INT,@PrefValue)
	 
	SELECT @IsUniqueDoc=(case when Value='True' then 1 else 0 end) FROM @TblPref where IsGlobal=0 and  Name='EnableUniqueDocument'
	SELECT @ISSerial=(case when Value='True' then 1 else 0 end) FROM @TblPref where IsGlobal=1 and  Name='EnableSerialProducts'
	SELECT @IsBatChes=(case when Value='True' then 1 else 0 end) FROM @TblPref where IsGlobal=1 and  Name='EnableBatchProducts'
	SELECT @IsDynamic=(case when Value='True' then 1 else 0 end) FROM @TblPref where IsGlobal=1 and  Name='EnableDynamicProducts'
	SELECT @IStempINFO=(case when Value='True' then 1 else 0 end) FROM @TblPref where IsGlobal=0 and  Name='TempInfo'

	if (dbo.fnCOM_HasAccess(@RoleID,43,193)=0 and exists(select Value from @TblPref where IsGlobal=0 and  Name='DonotupdateAccounts' and Value='false'))
	BEGIN
		SELECT @AccType=Value FROM @TblPref WHERE Name='LockTransactionAccountType'  
	 
		declare @table table(TypeID nvarchar(50))  
		insert into @table  
		exec SPSplitString @AccType,','  

		declare @AcctypesTable table (ID INT identity(1,1),AccountTypeID INT,AccountDate datetime)  
		insert into @AcctypesTable   
		select reverse(parsename(replace(reverse(TypeID),'~','.'),1)) as [AccountTypeID],  
		 convert(datetime,reverse(parsename(replace(reverse(TypeID),'~','.'),2))) as [Date] from @table  
    END
     
	select @PrefValue=''	
	select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='DocumentLinkDimension'    

	if(@PrefValue is not null and @PrefValue<>'' and ISNUMERIC(@PrefValue)=1)
	begin
		set @Dimesion=0
		begin try
			select @Dimesion=convert(INT,@PrefValue)
		end try
		begin catch
			set @Dimesion=0
		end catch
	END
	
	if(@DocNumber is null or @DocNumber='') 
		set @DocNumber='1'    
	
	SELECT @Series=Series,@DocumentTypeID=DocumentTypeID,@DocumentType=DocumentType,@DocAbbr=DocumentAbbr,@DocOrder=DocOrder
		,@UniqueDefn=UniqueDocumentDefn,@UniqueQuery=UniqueDocumentQuery,@CCGuid=GUID
	FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID   
	
    if @IsUniqueDoc=1
    begin
		set @XML=@UniqueDefn
		declare @UsedColumns nvarchar(max)
		select @UsedColumns=@XML.value('(XML/UsedColumns)[1]','NVARCHAR(MAX)')
		
		INSERT INTO @TblUnique
		exec SPSplitString @UsedColumns,','
				
		select @UniqueCount=COUNT(*) from @TblUnique
    end

	SET @Dt=convert(float,getdate())--Setting Current Date
	set @StatusID=369    
	if(@DocumentType=31)
		set @StatusID=443
	
	SET @XML=@ActivityXML	
	set @PrefValue=''
	
	--Pos Session Check
	declare @PosSessionID INT

	SELECT @Guid=X.value('@CCGuid','nvarchar(100)'),@PrefValue=X.value('@Guid','nvarchar(100)'),@ImpDocID=X.value('@ImpDocID','INT')
	,@bxml=X.value('@UniquNo','nvarchar(max)'),@DUPLICATECODE=X.value('@CheckStock','nvarchar(max)')    
	,@frdate=X.value('@FinancialSartDate','Datetime')   ,@toDate=X.value('@FinancialEndDate','Datetime')
	,@PosSessionID=X.value('@PosSessionID','INT'),@PrefValueDoc=isnull(X.value('@GenratePrefix','bit'),0)
	,@AP=X.value('@AP','varchar(10)')
	from @XML.nodes('/XML') as Data(X)
	if(@AP is null)
		set @AP=''
	
	if(@PosSessionID is not null)
	begin
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,43,464)
		if(@HasAccess=0)
		BEGIN
			if not exists(select POSLoginHistoryID from POS_loginHistory with(nolock) where POSLoginHistoryID=@PosSessionID and IsUserClose=0)
				RAISERROR('-152',16,1)	
			
			if(@DocID > 0 and not exists (select * from COM_DocID with(nolock) where ID=@DocID AND  PosSessionID=@PosSessionID) )
				RAISERROR('-531',16,1)
		END			
	end
	
	if(@Guid!=@CCGuid)
    BEGIN
		RAISERROR('-513',16,1)  
    END
    
	if(@DocID=0)
	BEGIN
		set @HistoryStatus='Add'
		if(@PrefValueDoc is not null and @PrefValueDoc=1)
		BEGIN
			EXEC [sp_GetDocPrefix] @InvDocXML,@DocDate,@CostCenterID,@DocPrefix output,0,0,0
			
			set @tempDOc=''
			SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1) FROM COM_CostCenterCodeDef WITH(NOLOCK)--AS CurrentCodeNumber
			WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix
			
			if(@tempDOc='')
				set @DocNumber='1'  
			ELSE if(len(@tempDOc)<@Length)    
			begin    
				set @t=1    
				set @temp=''    
				while(@t<=(@Length-len(@tempDOc)))    
				begin        
				set @temp=@temp+'0'        
					set @t=@t+1    
				end    
				SET @DocNumber=@temp+cast(@tempDOc as varchar)    
			end    
			ELSE    
				SET @DocNumber=@tempDOc  
	
		END	
	END	
	else
	BEGIN
		set @HistoryStatus='Update'
		
		SELECT  top 1 @InvDocDetailsID=INVDocDetailsID,@oldStatus=StatusID,@TEmpWid=WorkflowID,@tempLevel=WorkFlowLevel,@VoucherNo=VoucherNo,@DocNumber=DocNumber,@DocPrefix=DocPrefix,
		@TempDocDate=DocDate,@VersionNo=VersionNo
		FROM INV_DocDetails WITH(NOLOCK) WHERE DocID=@DocID
		
		select @CCGuid=GUID from COM_DocID WITH(NOLOCK) WHERE ID=@DocID
		
		if(@PrefValue <>'' and @CCGuid!=@PrefValue)
		BEGIN
			RAISERROR('-101',16,1)  
		END
		
		update D
		set D.LockedBY=null
		FROM COM_DocID D WITH(NOLOCK)
		where D.ID=@DocID
	END

	IF(@DocNumber is not null AND @DocNumber!='' AND CONVERT(BIGINT,@DocNumber)>2147483647)
	BEGIN
		raiserror('DocNumber Cannot be more than 2147483647',16,1)
	END
	
	--do not check -ve stock
	if(@DUPLICATECODE is not null and @DUPLICATECODE='false')
		delete from @TblPref where IsGlobal=1 and Name='Check for -Ve Stock'
	
	if(@WID is not null and @WID>0)    
	begin
		if(@DocID>0 and @tempLevel is not null and @oldStatus not in (369,372))
		BEGIN
			set @level=null
			if (@DocumentType >= 51 AND @DocumentType <= 199 AND @DocumentType != 64) --IS PAYROLL DOCUMENT
			BEGIN
				
			--Check Whether the User Level is Payroll Employee Report Manager Level or Not
				SET @level=dbo.fnExt_GetRptMgrUserLevel(@InvDocDetailsID,@WID,@tempLevel,@UserName,@RoleID)
				set @InvDocDetailsID=0
			END
			if(@level is null)  
				SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
				where WorkFlowID=@WID and UserID =@UserID and LevelID>@tempLevel
				order by LevelID desc
				
			if(@level is null)  
				SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and RoleID =@RoleID and LevelID>@tempLevel
				order by LevelID desc
				
			if(@level is null)       
				SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID and LevelID>@tempLevel
				order by LevelID desc
				
			if(@level is null)  
				SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID and LevelID>@tempLevel
				order by LevelID desc
			
			if(@level is null)
			BEGIN
				SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
				where WorkFlowID=@WID and UserID =@UserID and LevelID>=@tempLevel
				order by LevelID desc
				
				if(@level is null)  
					SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
					where WorkFlowID=@WID and RoleID =@RoleID and LevelID>=@tempLevel
					order by LevelID desc
					
				if(@level is null)       
					SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.UserID=@UserID and WorkFlowID=@WID and LevelID>=@tempLevel
					order by LevelID desc
					
				if(@level is null)  
					SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
					JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					where g.RoleID =@RoleID and WorkFlowID=@WID and LevelID>=@tempLevel
					order by LevelID desc
			END
		END
		
		if(@DocID=0 or @level is null or @oldStatus in (369,372))
		BEGIN
			
			SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and UserID =@UserID
			order by LevelID desc
			
			if(@level is null)  
				SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and RoleID =@RoleID
				order by LevelID desc
				
			if(@level is null)       
				SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID
				order by LevelID desc
				
			if(@level is null)  
				SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID
				order by LevelID desc
		END	
			
		select @maxLevel=max(a.LevelID) from COM_WorkFlow  a WITH(NOLOCK) 
		left join COM_WorkFlowDef b with(nolock) on a.WorkFlowID=b.WorkFlowID and IsEnabled=0 and a.LevelID=b.LevelID and CostCenterID=@CostCenterID		
		where a.WorkFlowID=@WID and b.WorkFlowID is null

		if(@level is not null and  @maxLevel is not null and @maxLevel>@level)    
		begin    
			SET @XML=@ActivityXML

			SELECT @AppRejDate=X.value('@AppRejDate','Datetime')   
			from @XML.nodes('/XML') as Data(X)    

			if(@AppRejDate is not null)
				set @StatusID=441
			else	
				set @StatusID=371    
		end     
	end    

  
	
	if(@DocumentType=1 or @DocumentType=39 or @DocumentType=27 or @DocumentType=26 or @DocumentType=25 or @DocumentType=2  or @DocumentType=34 or @DocumentType=6 or @DocumentType=3 or @DocumentType=4 or @DocumentType=13)      
		set @VoucherType=1
	else if(@DocumentType=11 or @DocumentType=38 or @DocumentType=50 or @DocumentType=7 or @DocumentType=9 or @DocumentType=24 or @DocumentType=33 or @DocumentType=10 or @DocumentType=8 or @DocumentType=12)      
		set @VoucherType=-1      
	else      
		set @VoucherType=0      
	
	set @PrefValue =null
	select @PrefValue=Value from @TblPref where IsGlobal=1 and Name='Check for -Ve Stock'    
	if(@PrefValue is not null and @PrefValue='true')
	BEGIN
		select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='DonotupdateInventory'    
		if(@PrefValue is not null and @PrefValue='false')
		BEGIN
			if(@DocID>0 and (@VoucherType=1 or @DocumentType=30 or @DocumentType=5))
			BEGIN
				select @PrefValueDoc=Value from @TblPref where IsGlobal=1 and  Name='ConsiderUnAppInHold'    
		
				EXEC @return_value = [spDOC_Validate]      
					@InvDocXML =@InvDocXML, 
					@DocID =@DocID,
					@DocDate =@DocDate,
					@IsDel=0,
					@ActivityXML=@ActivityXML,
					@docType=@DocumentType,
					@ConsiderUnAppInHold=@PrefValueDoc,
					@UserName =@UserName,
					@LangID =@LangID
			END	
		END		
	END
	
	set @PrefValue =null
	select @PrefValue=Value from @TblPref where IsGlobal=1 and Name='Check for -Ve Stock'    

	if((@PrefValue is not null and @PrefValue='true' and (@VoucherType=-1 or @DocumentType=30 or @DocumentType=5) ) or @DocumentType=31)
	BEGIN
		set @loc=0
		set @div=0
		set @dim=0
		
		set @PrefValue='' 
		select @PrefValue= Value from @TblPref where IsGlobal=1 and Name='EnableLocationWise'        
		if(@PrefValue='True')
		begin         
			set @PrefValue=''      
			select @PrefValue= Value from @TblPref where IsGlobal=1 and Name='Location Stock'        
			if(@PrefValue='True')      
			begin      
				set @loc=1
			end       
		end   
		
		set @PrefValue='' 
		select @PrefValue= Value from @TblPref where IsGlobal=1 and Name='EnableDivisionWise'        
		if(@PrefValue='True')
		begin         
			set @PrefValue=''      
			select @PrefValue= Value from @TblPref where IsGlobal=1 and Name='Division Stock'        
			if(@PrefValue='True')      
			begin 
				set @div=1			  
			end       
		end  	     
	           
		set @PrefValue=''      
		select @PrefValue= isnull(Value,'') from @TblPref where IsGlobal=1 and Name='Maintain Dimensionwise stock'        

		if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)        
		begin 					 
			if(convert(INT,@PrefValue)=50001)
				set @dim=1
			else if(convert(INT,@PrefValue)=50002)
				set @dim=2
			else if(convert(INT,@PrefValue)>50002)			
				set @dim=convert(INT,@PrefValue)-50000 
		end 
	END	

IF(@InvDocXML IS NOT NULL AND @InvDocXML<>'')      
BEGIN
	SET @XML=@ActivityXML   

	set @IsRevision=0
	set @CheckHold=0      
    set @CCStatusID=0  
	SELECT @IsRevision=X.value('@IsRevision','BIT')  , @ReviseReason=X.value('@ReviseReason','NVARCHAR(MAX)') 
		   ,@AppRejDate=X.value('@AppRejDate','DateTime'),@CheckHold=X.value('@HoldCheck','BIT'),@DetailIDs=X.value('@DetailIds','nvarchar(max)'),@PrefValue=X.value('@status','nvarchar(100)')  
		  ,@CCStatusID=X.value('@SaveUnapproved','int'),@sysinfo=X.value('@SysInfo','nvarchar(max)'),@LineWiseApproval=isnull(X.value('@LineWiseApproval','BIT'),0)
	from @XML.nodes('/XML') as Data(X)   
    
    
    if(@CCStatusID=1)--budget crossed save as unapproved
		set @StatusID=371 
		
	if(@IsRevision=1 and @DocID>0 and exists(select value from @TblPref where IsGlobal=0 and Name='PostRevisOnSysDate' and Value='true'))
		set @DocDate=CONVERT(datetime,floor(convert(float,getdate())))	
    
    if exists(select Value from @TblPref where IsGlobal=1 and  Name='UseDimWiseLock' and Value ='true')
	BEGIN
		set @WHERE=''
		set @DUPLICATECODE=''
		select @WHERE=isnull(X.value('@LockDims','nvarchar(max)'),''),@DUPLICATECODE=isnull(X.value('@LockDimsjoin','nvarchar(max)'),'')
		from @XML.nodes('/XML') as Data(X)    		         
		if(@WHERE<>'')
		BEGIN
			set @SQL=' if exists(select FromDate from ADM_DimensionWiseLockData c WITH(NOLOCK) '+@DUPLICATECODE+'
			where '+convert(nvarchar,CONVERT(float,@DocDate))+' between FromDate and ToDate and c.isEnable=1 '+@WHERE
			+') RAISERROR(''-125'',16,1) '
			print @SQL
			exec(@SQL)
		END
	END
    
    if exists( select X.value('@LockedPosting','BIT') from @XML.nodes('/XML') as Data(X)  
			where X.value('@LockedPosting','BIT')  is not null and X.value('@LockedPosting','BIT')=1)
	BEGIN
				
					EXEC @return_value = spDOC_SuspendInvDocument        
				 @CostCenterID = @CostCenterID, 
				 @DocID=@DocID,
				 @DocPrefix = '',  
				 @DocNumber = '', 
				 @Remarks=N'', 
				 @UserID = @UserID,  
				 @UserName = @UserName,
				 @RoleID=@RoleID,
				 @LangID = @LangID  
				 
				if(@return_value=1)
					set @DocID=0
				else
					return -999;
				
				
				set @IsLockedPosting=1
				set @DocDate=@AppRejDate	
				
	END
        
	declare @tblIDsList table(Id INT)  
	insert into @tblIDsList  
	exec SPSplitString @DetailIDs,'~'        
	
	if(@PrefValue='SaveonHold')  
	begin  
		set @StatusID=438    
	end  
 
	IF(@RefCCID=95)
	BEGIN
		IF EXISTS (SELECT [STATUS] FROM [adm_featureactionrolemap] WITH(NOLOCK) WHERE ROLEID=@RoleID AND FEATUREACTIONID=3764)
		BEGIN 
			set @StatusID=371 
		END
	END
  
	IF (@IsRevision=1 and @DocID>0 and not exists(select DocID from [INV_DocDetails_History] WITH(NOLOCK) where DocID=@DocID))  
	BEGIN    
	 EXEC @return_value = [spDOC_SaveHistory]      
			@DocID =@DocID ,
			@HistoryStatus='ADD',
			@Ininv =1,
			@ReviseReason ='',
			@LangID =@LangID,
			@CCID=@CostCenterID
	END 

	declare @bb nvarchar(max)
	set @bb=convert(varchar,CHAR(17))
	
    declare @tblList table(ID int identity(1,1),TransactionRows nvarchar(max))  
	insert into @tblList  
	exec SPSplitString @InvDocXML,@bb
    
    
	--Set loop initialization varaibles      
	SELECT @I=1, @Cnt=count(*) FROM @tblList       
     
	DECLARE @DAllowLockData BIT,@AllowLockData BIT ,@IsLock bit    
	
	SELECT @AllowLockData=CONVERT(BIT,Value) FROM @TblPref WHERE  IsGlobal=1 and Name='Lock Data Between'    	
	SELECT @DAllowLockData=CONVERT(BIT,Value) FROM @TblPref where IsGlobal=0 and  Name='Lock Data Between'
	
	set @IsLock=0	

	if((@AllowLockData=1 or @DAllowLockData=1) and dbo.fnCOM_HasAccess(@RoleID,43,193)=0)
	BEGIN
		IF exists(select LockID from ADM_LockedDates WITH(NOLOCK) where isEnable=1 
		and ((@AllowLockData=1 and CONVERT(float,@DocDate) between FromDate and ToDate and CostCenterID=0)
		or (@DAllowLockData=1 and CONVERT(float,@DocDate) between FromDate and ToDate and CostCenterID=@CostCenterID)))
			set @IsLock=1
			
		IF (@AllowLockData=1 and @IsLock=1 and  (SELECT Value FROM @TblPref where IsGlobal=0 and  Name='OverrideLock')<>'true')
		BEGIN	
			SELECT @LockCC=CONVERT(INT,Value) FROM @TblPref WHERE  IsGlobal=1 and Name='LockCostCenters' and isnumeric(Value)=1

			if(@LockCC is null or @LockCC=0)
				RAISERROR('-125',16,1)      			
		END
		
		
		IF (@DAllowLockData=1 and @IsLock=1)
		BEGIN
			SELECT @DLockCC=CONVERT(INT,Value) FROM @TblPref where IsGlobal=0 and  Name='LockCostCenters' and isnumeric(Value)=1
		
			if(@DLockCC is null or @DLockCC=0)
				RAISERROR('-125',16,1)      			
		END
	END
	
	IF(@DocID=0)      
	BEGIN      
		SET @VersionNo=0
		set @DimesionNodeID=0
		
		
		IF(@Series is not null and @Series>40000)
			set @prefixCCID=@Series
		ELSE
			set @prefixCCID=@CostCenterID
		
		if(@IsImport=1 and @ImpDocID is not null and @ImpDocID>0)
		BEGIN
			SELECT  top 1 @DocID=DocID,@VoucherNo=VoucherNo,@DocNumber=DocNumber,@DocPrefix=DocPrefix,@VersionNo=VersionNo
			 FROM INV_DocDetails WITH(NOLOCK) WHERE DocID=@ImpDocID
			 select @Guid=GUID from COM_DocID WITH(NOLOCK) WHERE ID=@ImpDocID
		END
		ELSE
		BEGIN		
			if(@IsImport=1 and @ImpDocID is not null)
			BEGIN
				exec sp_GetDocPrefix @InvDocXML,@DocDate,@CostCenterID,@DocPrefix OUTPUT
			END
			set @Guid=NEWID()
			
			DECLARE @StartNewNo NVARCHAR(500)
			if NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef WITH(NOLOCK) WHERE CostCenterID=@prefixCCID AND CodePrefix=@DocPrefix)      
			begin 
				
				IF(@DocNumber='1' and @RefNodeid>0)
				BEGIN
					Select @StartNewNo=PrefValue From COM_DocumentPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND PrefName='StartNoForNewPrefix'
					IF(@StartNewNo IS NOT NULL AND @StartNewNo<>'' AND @StartNewNo<>'0')
						SET @DocNumber=@StartNewNo
				END

				IF(@DocNumber is not null AND @DocNumber!='' AND CONVERT(BIGINT,@DocNumber)>2147483647)
				BEGIN
					raiserror('DocNumber Cannot be more than 2147483647',16,1)
				END
			     
				INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)
				VALUES(@prefixCCID,@prefixCCID,@DocPrefix,CONVERT(INT,@DocNumber),1,CONVERT(INT,@DocNumber),len(@DocNumber),Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)      
				SET @tempDOc=CONVERT(INT,@DocNumber)+1
				SET @Length=len(@DocNumber)
			end      
			ELSE
			BEGIN
				SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK)
				WHERE CostCenterID=@prefixCCID AND CodePrefix=@DocPrefix
			 	
		 		if(@DocNumber='1' and @RefCCID>0 and @RefCCID<>300)
					set  @DocNumber=@tempDOc
				else if(@DocNumber='' and @RefCCID>0 and @RefCCID=300)
					set  @DocNumber=@tempDOc		
				
				IF(@DocNumber is not null AND @DocNumber!='' AND CONVERT(BIGINT,@DocNumber)>2147483647)
				BEGIN
					raiserror('DocNumber Cannot be more than 2147483647',16,1)
				END

				IF(CONVERT(INT,@DocNumber)>=@tempDOc)      
				BEGIN      
					SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,43,138)
					
					if(@HasAccess=0)
						SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,671)
					
					IF @HasAccess=0
					BEGIN
						if(len(@tempDOc)<@Length)    
						begin    
							set @t=1    
							set @temp=''    
							while(@t<=(@Length-len(@tempDOc)))    
							begin        
							set @temp=@temp+'0'        
								set @t=@t+1    
							end    
							SET @DocNumber=@temp+cast(@tempDOc as varchar)    
						end    
						ELSE    
							SET @DocNumber=@tempDOc    
							
						UPDATE T SET T.CurrentCodeNumber=@DocNumber
						FROM COM_CostCenterCodeDef T WITH(NOLOCK)    
						WHERE T.CostCenterID=@prefixCCID AND T.CodePrefix=@DocPrefix 
					END
					ELSE
					BEGIN
						UPDATE T SET T.CurrentCodeNumber=@DocNumber
						FROM COM_CostCenterCodeDef T WITH(NOLOCK)           
						WHERE T.CostCenterID=@prefixCCID AND T.CodePrefix=@DocPrefix      
					END	
				END
			END 
			
			IF(@DocNumber is not null AND @DocNumber!='' AND CONVERT(BIGINT,@DocNumber)>2147483647)
			BEGIN
				raiserror('DocNumber Cannot be more than 2147483647',16,1)
			END  
			   
			IF EXISTS(SELECT DocID FROM INV_DocDetails a WITH(NOLOCK) 
			LEFT JOIN  ADM_DocumentTypes b WITH(NOLOCK) on a.CostCenterID=b.CostCenterID
			WHERE (b.Series=@prefixCCID or a.CostCenterID=@prefixCCID) AND DocPrefix=@DocPrefix AND CONVERT(BIGINT,DocNumber)=CONVERT(INT,@DocNumber))
			BEGIN 
				set @PrefValue=''  
				select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='SameserialNo'
			     
				if ((@IsImport=1 or @PrefValue='true')and @ImpDocID is null)
					RAISERROR('-122',16,1)      

				if(len(@tempDOc)<@Length)      
				begin      
					set @t=1      
					set @temp=''      
					while(@t<=(@Length-len(@tempDOc)))      
					begin          
						set @temp=@temp+'0'          
						set @t=@t+1      
					end      
					SET @DocNumber=@temp+cast(@tempDOc as varchar)      
				end      
				ELSE      
					SET @DocNumber=@tempDOc

				UPDATE T SET T.CurrentCodeNumber=@DocNumber  
				FROM COM_CostCenterCodeDef T WITH(NOLOCK)   
				WHERE T.CostCenterID=@prefixCCID AND T.CodePrefix=@DocPrefix      
			END      

			SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')

			if(@IsRevision=1)  
			begin    
				if exists(select value from @TblPref where IsGlobal=0 and Name='RevisPrefix' and Value is not null and Value<>'')
					select @VoucherNo=@VoucherNo+'/'+value+convert(nvarchar, @VersionNo  ) from @TblPref where IsGlobal=0 and Name='RevisPrefix' 					
				ELSE
					set	@VoucherNo=@VoucherNo+'/'+convert(nvarchar, @VersionNo  )
			end
			
			--To Get Auto generate DocID
			while exists (select DocNo from COM_DocID with(nolock) where DocNo=@VoucherNo)
			begin			
				SET @DocNumber=@DocNumber+1
				SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
			end	
			
			if @PosSessionID is not null
			begin
				INSERT INTO COM_DocID(DocNo,PosSessionID,[CompanyGUID],[GUID],SysInfo)
				VALUES(@VoucherNo,@PosSessionID,@CompanyGUID,@guid,@SysInfo)
				SET @DocID=@@IDENTITY
			end
			else
			begin
				INSERT INTO COM_DocID(DocNo,[CompanyGUID],[GUID],SysInfo)
				VALUES(@VoucherNo,@CompanyGUID,@guid,@SysInfo)
				SET @DocID=@@IDENTITY
			end
		END	
		
		set @PrefValue=''
		set @CCStatusID=0
		SELECT @CCStatusID=isnull(X.value('@ScheduleID','INT'),0),@PrefValue=X.value('@SchGUID','nvarchar(max)')
		from @XML.nodes('/XML') as Data(X)
		if(@CCStatusID>0)
		BEGIN
			if(@PrefValue <>'')
			BEGIN
				select @CCGuid=GUID from COM_SchEvents WITH(NOLOCK) where SCHEVENTID=@CCStatusID	
				
				 if(@CCGuid!=@PrefValue)
					RAISERROR('-101',16,1)  
			END
			
			UPDATE T SET T.STATUSID=2,T.PostedVoucherNo=@VoucherNo,T.GUID=newid()
			FROM COM_SchEvents T WITH(NOLOCK)
			WHERE T.SCHEVENTID=@CCStatusID
		END
	END      
	ELSE      
	BEGIN      
		
		set @Guid=NEWID()
		
		update D
		set D.GUID= @guid,D.SysInfo =@SysInfo ,D.[CompanyGUID]=@CompanyGUID
		FROM COM_DocID D WITH(NOLOCK)
		where D.ID=@DocID
		
		if(@WID=0 and @TEmpWid>0)
		begin
			set @WID=@TEmpWid 
			
			set @PrefValue=''
		    SELECT @PrefValue=X.value('@WorkFlow','nvarchar(100)')   
		    from @XML.nodes('/XML') as Data(X)     
		    if(@PrefValue is not null and @PrefValue='NO')  
		    BEGIN
				set @level=@tempLevel
				set @StatusID=@oldStatus 
			END
			ELSE
			BEGIN			
				SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
				where WorkFlowID=@WID and  UserID =@UserID
				order by LevelID
				
				if(@level is null )  
					SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
					where WorkFlowID=@WID and  RoleID =@RoleID
					order by LevelID
					
				if(@level is null )       
					 SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
					 JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					 where g.UserID=@UserID and WorkFlowID=@WID
					 order by LevelID
					 
				if(@level is null )  
					 SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
					 JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
					 where g.RoleID =@RoleID and WorkFlowID=@WID
					 order by LevelID
			END		
		end 

		if @VoucherNo is not null
		begin  
			set @fromvno=''
			if @HistoryStatus='Update' and exists(select name from sys.columns where name='FromDocNo' and object_id=object_id('COM_Billwise'))
			BEGIN
				set @Sql=' select @fromvno=FromDocNo from COM_Billwise with(nolock) where DocNo='''+@VoucherNo+''' and FromDocNo is not null and FromDocNo<>'''''
				EXEC sp_executesql @Sql,N'@fromvno nvarchar(200) output',@fromvno output
			END	
			
			DELETE FROM [COM_Billwise]      
			WHERE [DocNo]=@VoucherNo
			
			delete from COM_BillWiseNonAcc
			where DocNo=@VoucherNo
 
			DELETE FROM COM_ChequeReturn
			WHERE [DocNo]=@VoucherNo AND DocSeqNo=1   

			DELETE FROM COM_LCBills      
			WHERE [DocNo]=@VoucherNo AND DocSeqNo=1   
			
			if(@Dimesion>50000)    
			begin
				set @DimesionNodeID=0	
				set @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
				select @cctablename=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@Dimesion
				set @DUPLICATECODE='select @NodeID=NodeID from '+@cctablename+' WITH(NOLOCK) where Name in('''+@vno+''''	

				set @tVersionNo=@VersionNo
				if(@VersionNo>=1)  
				begin
					if exists(select value from @TblPref where IsGlobal=0 and Name='RevisPrefix' and Value is not null and Value<>'')
						select @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+Value+convert(nvarchar,@VersionNo)
						from @TblPref where IsGlobal=0 and Name='RevisPrefix' 					
					ELSE
						set	@vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+convert(nvarchar,@VersionNo)

				set @DUPLICATECODE=@DUPLICATECODE + ','''+@vno+''''
				end

				set @DUPLICATECODE=@DUPLICATECODE+')'			
				EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@DimesionNodeID output
			end 
			
			if(@IsRevision=1)  
			begin  
			
				set @VersionNo=@VersionNo+1 				
				    
				if exists(select value from @TblPref where IsGlobal=0 and Name='RevisPrefix' and Value is not null and Value<>'')
					select @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+Value+convert(nvarchar,@VersionNo)
					from @TblPref where IsGlobal=0 and Name='RevisPrefix' 					
				ELSE
					set	@vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+convert(nvarchar,@VersionNo)
				 
				
			    update T set T.RefDocNo=@vno
				FROM com_billwise T WITH(NOLOCK)
			    where T.RefDocNo=@VoucherNo
				
				update T set T.RefDocNo=@vno
				FROM COM_BillWiseNonAcc T WITH(NOLOCK)
			    where T.RefDocNo=@VoucherNo

				set @VoucherNo=@vno
				--Update Voucher No While Revision
				--update COM_DocID set DocNo=@VoucherNo where ID=@DocID
				update INV_DocDetails
				set RefNo=@VoucherNo
				from (select a.InvDocDetailsID id from INV_DocDetails a WITH(NOLOCK)
				join INV_DocDetails b WITH(NOLOCK)on a.LinkedInvDocDetailsID=b.InvDocDetailsID
				where b.CostCenterID=@CostCenterID and b.DocID=@DocID) as t
				where InvDocDetailsID=t.id
				
			end
		end  
		else  
		begin  
			set @DimesionNodeID=0
			
			SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK)      
			WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix      

			SET @DocNumber=@tempDOc      

			UPDATE T SET T.CurrentCodeNumber=@DocNumber
			FROM COM_CostCenterCodeDef T WITH(NOLOCK)
			WHERE T.CostCenterID=@CostCenterID AND T.CodePrefix=@DocPrefix      

			SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')     
			set @VersionNo=0   
		end    
		   
		set @PrefValue=''  
		select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='DontSaveCompleteLinked'    
		if(@PrefValue='true')  
		begin  
			if exists (SELECT a.InvDocDetailsID from INV_DocDetails a  WITH(NOLOCK)   
			join dbo.INV_Product p  WITH(NOLOCK) on p.ProductID=a.ProductID  
			join INV_DocDetails B WITH(NOLOCK) on a.InvDocDetailsID =b.LinkedInvDocDetailsID    
			where a.CostCenterid=@CostCenterID and a.DocID=@DocID and p.ProductTypeID<>8)
			begin  
				if not exists(SELECT a.InvDocDetailsID, a.Quantity-isnull(sum(b.LinkedFieldValue),0)  
				from INV_DocDetails a WITH(NOLOCK)   
				join dbo.INV_Product p WITH(NOLOCK) on p.ProductID=a.ProductID  
				left join INV_DocDetails B WITH(NOLOCK) on a.InvDocDetailsID =b.LinkedInvDocDetailsID    
				where a.CostCenterid=@CostCenterID and a.DocID =@DocID and p.ProductTypeID<>8  
				group by a.InvDocDetailsID,a.Quantity
				having a.Quantity-isnull(sum(b.LinkedFieldValue),0)<>0)
				begin  
					RAISERROR('-351',16,1)   
				end  
			end  
		end
		
		DECLARE @TblDeleteRows AS Table(idid INT identity(1,1),ID INT,DynamicType INT,Linkid INT,batch INT,Qtyign bit)
		
		INSERT INTO @TblDeleteRows(ID,DynamicType,Linkid,batch,Qtyign)
		SELECT InvDocDetailsID,0,LinkedInvDocDetailsID,BatchID,IsQtyIgnored FROM INV_DocDetails WITH(NOLOCK)
		WHERE DocID=@DocID and (DynamicInvDocDetailsID is null or DynamicInvDocDetailsID=0 or DynamicInvDocDetailsID=-1)  
		AND InvDocDetailsID NOT IN (SELECT ID from @tblIDsList)
				
		if(@IsDynamic=1)
		BEGIN			
			INSERT INTO @TblDeleteRows(ID,DynamicType,batch,Qtyign)
			SELECT InvDocDetailsID,1,BatchID,IsQtyIgnored FROM INV_DocDetails WITH(NOLOCK)   
			join  @TblDeleteRows on DynamicInvDocDetailsID=ID
			where DynamicInvDocDetailsID is not null  
		END
		
		if exists(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='IsBudgetDocument' and Value='1')		
		BEGIN
			INSERT INTO @TblDeleteRows(ID,DynamicType)
			SELECT b.InvDocDetailsID,0 FROM INV_DocDetails a WITH(NOLOCK)    
			join INV_DocDetails b WITH(NOLOCK) on a.InvDocDetailsID=b.refNodeID
			where a.DocID =@DocID AND a.InvDocDetailsID NOT IN (SELECT ID from @tblIDsList)
			and b.refccid=300
		END
				
		if exists(select ID from @TblDeleteRows)
		BEGIN
			
			if exists(SELECT ID from @tblIDsList a
			join INV_DocDetails b WITH(NOLOCK) on b.InvDocDetailsID=a.ID
			where DocID<>@DocID)
				RAISERROR('-101',16,1)  
			
			delete from @caseTab
			
			if (@Dimesion>0 and exists(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='GenerateSeq' and Value='true'))
			BEGIN
				set @DetIDS=''
				select @DetIDS=@DetIDS+CONVERT(nvarchar,ID)+',' from @TblDeleteRows
				set @DetIDS=@DetIDS+'-1'				
				set @SQL='select dcCCNID'+convert(nvarchar,(@Dimesion-50000))+' FROM COM_DocCCData WITH(NOLOCK) 
				where InvDocDetailsID in('+@DetIDS+')'
				
				INSERT INTO @caseTab(CaseID)
				exec(@SQL)					
			END	
			
			--ondelete External function
			set @cctablename=''
			select @cctablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=8
			if(@cctablename<>'')
			BEGIN
				set @DetIDS=''
				select @DetIDS=@DetIDS+CONVERT(nvarchar,ID)+',' from @TblDeleteRows
				set @DetIDS=@DetIDS+'-1'
				exec @cctablename @CostCenterID,@DocID,@DetIDS,@UserID,@LangID
			END
			
			--DELETE DOCUMENT EXTRA COSTCENTER FEILD DETAILS
			DELETE T FROM COM_DocCCData t WITH(NOLOCK)
			join @TblDeleteRows a on t.InvDocDetailsID=a.ID		

			--DELETE DOCUMENT EXTRA NUMERIC FEILD DETAILS      
			DELETE T FROM [COM_DocNumData] t WITH(NOLOCK)
			join @TblDeleteRows a on t.InvDocDetailsID=a.ID
			
			--DELETE DOCUMENT EXTRA NUMERIC FEILD DETAILS      
			if(@CostCenterID=40054)
			BEGIN	
				set @sql='DELETE T FROM PAY_DocNumData t WITH(NOLOCK)
					join [INV_DocDetails] a WITH(NOLOCK) on t.InvDocDetailsID=a.InvDocDetailsID
					WHERE a.CostCenterID='+convert(nvarchar(Max),@CostCenterID)+' AND a.DocID= '+convert(nvarchar(Max),@DocID)+
					' and a.InvDocDetailsID not in('+replace(@DetailIDs,'~',',')+')'
					Exec(@sql)
			END

			--start Deleting Unnecessary Cross Dimension already Mapped  Data added by khasim
		Declare @TEMPxmlCross NVARCHAR(MAX),@varnodexml XML,@varparentxml XML,@Crossindex INT,@CrossCCID INT ,@crossddID INT,@isDelnode INT, @Crossnodecount INT,@TEMPCrossxml Nvarchar(max)
			select @CrossCCID = convert(INT,Value) from @TblPref where IsGlobal=0 and  Name='CrossDimDocument' 
			IF @CrossCCID > 0
			begin
			    SELECT @TEMPxmlCross = CONVERT(NVARCHAR(MAX), X.query('CrossDimXMLNODES'))
			from @XML.nodes('/XML') as Data(X)
				set @varparentxml = @TEMPxmlCross
				Set @Crossindex = 1;
			
				Set @Crossnodecount = @varparentxml.value('count(/CrossDimXMLNODES/CrossDimXML)','INT');
				while @Crossindex <= @Crossnodecount
				begin 
					set @TEMPCrossxml = ''
					SELECT @TEMPCrossxml = CONVERT(NVARCHAR(MAX),@varparentxml.query('(/CrossDimXMLNODES/CrossDimXML[position()=sql:variable("@Crossindex")])[1]'))

					if(@TEMPCrossxml<>'')
					begin
							set @varnodexml = @TEMPCrossxml
							set @crossddID =0
							SELECT @crossddID =X.value('@DocID','INT')
							from @varnodexml.nodes('/CrossDimXML') as Data(X)
			
							set @isDelnode=0
							SELECT @isDelnode=ISNULL(X.value('@IsDelete','int'),0)
							from @varnodexml.nodes('/CrossDimXML') as Data(X)

							if(@isDelnode>0)
							BEGIN
								EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]  
									 @CostCenterID = @CrossCCID,  
									 @DocPrefix = '',  
									 @DocNumber = '',
									 @DocID=@crossddID,
									 @UserID = 1,  
									 @UserName = @UserName,  
									 @LangID = @LangID,
									 @RoleID=1
							END
					end
					Set @Crossindex = @Crossindex + 1;
				end
			end
			-- end 

			
			--DELETE DOCUMENT EXTRA TEXT FEILD DETAILS      
			DELETE T FROM [COM_DocTextData] T WITH(NOLOCK)
			join @TblDeleteRows a on t.InvDocDetailsID=a.ID

			--DELETE Accounts DocDetails      
			DELETE T FROM [ACC_DocDetails] T WITH(NOLOCK)
			join @TblDeleteRows a on t.InvDocDetailsID=a.ID 
			
			--to delete stock codes
			if exists(select Value from @TblPref where IsGlobal=0 and  Name='DumpStockCodes' and Value='true')    
			BEGIN
				set @cctablename=''
				select @cctablename=b.TableName from @TblPref a
				join ADM_Features b WITH(NOLOCK) on a.Value=b.FeatureID
				where IsGlobal=1 and a.Name='POSItemCodeDimension'
				
				if(@cctablename<>'')
				BEGIN
					set @DetIDS=''
					select @DetIDS=@DetIDS+CONVERT(nvarchar,ID)+',' from @TblDeleteRows
					set @DetIDS=@DetIDS+'-1'
									
					set @SQL='delete FROM '+@cctablename+' 
					where InvDocDetailsID in('+@DetIDS+')'
					exec(@SQL)
				END	
			END
			
			if(@ISSerial=1)
			BEGIN	
				if exists(select [InvDocDetailsID] from [INV_SerialStockProduct] T WITH(NOLOCK)
				join @TblDeleteRows a on t.InvDocDetailsID=a.ID)
				BEGIN
					if(@VoucherType=1)
					BEGIN
						if exists(select [SerialNumber]  from [INV_SerialStockProduct] T WITH(NOLOCK)
						join @TblDeleteRows a on t.[RefInvDocDetailsID]=a.ID)
						BEGIN
							RAISERROR('-508',16,1)
						END
					END
					ELSE if(@VoucherType=-1)
					BEGIN
						 UPDATE [INV_SerialStockProduct]      
						 SET [StatusID]=157      
						 ,IsAvailable=1 
						  from ( select [SerialNumber] sno ,SerialGUID sguid,[RefInvDocDetailsID] refinvID,[ProductID] PID from [INV_SerialStockProduct] T WITH(NOLOCK)
							join @TblDeleteRows a on t.InvDocDetailsID=a.ID) as t
						  where [ProductID]=PID and [SerialNumber]=sno and SerialGUID=sguid and [InvDocDetailsID]=refinvID
					END						
				END
			END
					
			delete T from [INV_SerialStockProduct] T WITH(NOLOCK)
			join @TblDeleteRows a on t.InvDocDetailsID=a.ID 
			
			if(@IStempINFO=1)
			BEGIN
				DELETE T FROM INV_TempInfo  T WITH(NOLOCK)
				join @TblDeleteRows a on t.InvDocDetailsID=a.ID 
			END
			
			if exists(select Value from @TblPref where IsGlobal=0 and  Name='UseQtyAdjustment' and Value='true')
			BEGIN	
				DELETE T FROM COM_DocQtyAdjustments T WITH(NOLOCK)
				join @TblDeleteRows a on t.InvDocDetailsID=a.ID
			END
			

			DELETE T FROM INV_BinDetails T WITH(NOLOCK)
			join @TblDeleteRows a on t.InvDocDetailsID=a.ID
			

			if exists(select LinkedInvDocDetailsID from [INV_DocDetails] T WITH(NOLOCK)
			join @TblDeleteRows a on t.LinkedInvDocDetailsID=a.ID )    
			begin       
				RAISERROR('-127',16,1)    
			end
			
			if exists(select a.ID from @TblDeleteRows a 
			join [INV_DocExtraDetails] b with(nolock)  on a.ID=b.RefID
			WHERE b.Type=1)
			begin	
					select @ProductName=c.Voucherno from @TblDeleteRows a 
					join [INV_DocExtraDetails] b with(nolock)  on a.ID=b.RefID
					join [INV_DocDetails] c with(nolock)  on b.InvDocDetailsID=c.InvDocDetailsID
					WHERE b.Type=1
					
					RAISERROR('-566',16,1)
			end
			
			select @bi=MIN(id),@bcnt=MAX(id) FROM @caseTab
			
			WHILE(@bi <= @bcnt)
			BEGIN
				SELECT @CaseID=CaseID FROM @caseTab WHERE id=@bi
				
				EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
					@CostCenterID = @Dimesion,
					@NodeID = @CaseID,
					@RoleID=1,
					@UserID = 1,
					@LangID = 1
				
				SET @bi=@bi+1
			END
			
			
			if(@DocumentType=55)
			BEGIN
				insert into @caseTab(CaseID,AssignedTo)
				select distinct DocID,CostCenterID from [INV_DocDetails] T WITH(NOLOCK)
				join @TblDeleteRows a on t.RefNodeid=a.ID 
				where T.RefCCID=300
				
				select @bi=MIN(id),@bcnt=MAX(id) FROM @caseTab
				
				WHILE(@bi <= @bcnt)
				BEGIN
					
					 select @CaseID=CaseID,@BatchID=AssignedTo from @caseTab WHERE id=@bi
						    
					 EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]  
					 @CostCenterID =@BatchID,  
					 @DocPrefix = '',  
					 @DocNumber = '',
					 @DocID=@CaseID,
					 @UserID = @UserID,  
					 @UserName = @UserName,  
					 @LangID = @LangID,
					 @RoleID=@RoleID
					
					SET @bi=@bi+1
				END
			END

			DELETE T FROM [INV_DocDetails] T WITH(NOLOCK)
			join @TblDeleteRows a on t.InvDocDetailsID=a.ID	
			
			if(@IsBatChes=1)
			BEGIN				
				IF (@VoucherType=1)
				BEGIN
					
					select @bi=0,@bcnt=COUNT(idid) from @TblDeleteRows
					while(@bi<@bcnt)		
					BEGIN  		
						set @bi=@bi+1
						set @BatchID=0
						
						SELECT  @BatchID=batch,@InvDocDetailsID=ID	from @TblDeleteRows 
						where idid=@bi and batch>1 and Qtyign=0
						
						if(@BatchID is not null and @BatchID>1)
						BEGIN
							select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
							where Name='AllowNegativebatches' and costcenterid=16  

							if(@ConsolidatedBatches is null or @ConsolidatedBatches ='false')
							BEGIN
								select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
								where Name='ConsolidatedBatches' and costcenterid=16  

								if(@ConsolidatedBatches is not null and @ConsolidatedBatches ='False')  
								begin     
									set @Tot=isnull((SELECT sum(BD.ReleaseQuantity)    
									FROM [INV_DocDetails] AS BD WITH(NOLOCK)                 
									where vouchertype=1 and IsQtyIgnored=0  and batchid=@BatchID and [InvDocDetailsID]=@InvDocDetailsID),0)  

									set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
									FROM [INV_DocDetails] AS BD  with(nolock)                  
									where vouchertype=-1 and statusid in(369,371,441) and IsQtyIgnored=0  and batchid=@BatchID and RefInvDocDetailsID=@InvDocDetailsID),0)   
								end  
								else  
								begin  
									set @Tot=isnull((SELECT sum(BD.ReleaseQuantity)    
									FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
									where vouchertype=1 and statusid =369 and IsQtyIgnored=0  and batchid=@BatchID),0)  

									set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
									FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
									where vouchertype=-1 and statusid in(369,371,441) and IsQtyIgnored=0  and batchid=@BatchID),0)
								end  
								
								if(@Tot<-0.001)   
								begin  
									RAISERROR('-502',16,1)      
								end  
							END 
						END	
					END
				END  
			END
			
			if exists(select Value from @TblPref where IsGlobal=0 and  Name='BackTrack' and Value='True')
			BEGIN
				
				update a
				set LinkedFieldValue=LinkedFieldValue+b.[Quantity]
				from INV_DocDetails a WITH(NOLOCK)    
				join INV_DocExtraDetails b WITH(NOLOCK) on a.InvDocDetailsID=b.[RefID]
				join @TblDeleteRows c on b.InvDocDetailsID=c.ID
				where b.type=10 
				
				select @bi=MIN(id),@bcnt=MAX(id) FROM @TblDeleteRows
					
				WHILE(@bi <= @bcnt)
				BEGIN
					set @PrefValue=''			
					select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='backTrackDocs'
					if(@PrefValue='')
					BEGIN
						select @LinkedID=Linkid from @TblDeleteRows where ID=@bi
						
						SELECT @QtyFin=isnull(sum(Quantity),0) FROM INV_DocDetails a WITH(NOLOCK)    
						WHERE  LinkedInvDocDetailsID=@LinkedID and Costcenterid=@CostCenterID
			  
						update INV_DocDetails    
						set LinkedFieldValue=Quantity-@QtyFin
						where InvDocDetailsID=@LinkedID  
					END					
					select @bi=MIN(id) from @TblDeleteRows where ID>@bi
					if(@bi is null)
						break;
				END
			END
		END
		
		DELETE T FROM INV_DocExtraDetails T WITH(NOLOCK)
		join @TblDeleteRows a on t.InvDocDetailsID=a.ID
		
		
		DELETE T FROM [ACC_DocDetails] T WITH(NOLOCK)
		join @tblIDsList a on t.InvDocDetailsID=a.ID
		
		if exists(select Value from @TblPref where IsGlobal=0 and  Name='UseQtyAdjustment' and Value='true')
		BEGIN	
			DELETE T FROM COM_DocQtyAdjustments T WITH(NOLOCK)
			join @tblIDsList a on t.InvDocDetailsID=a.ID
		END
		
		DELETE T FROM INV_DocExtraDetails T WITH(NOLOCK)
		join @tblIDsList a on t.InvDocDetailsID=a.ID
		where t.type not in(10,15)
		
		DELETE T FROM INV_BinDetails T WITH(NOLOCK)
		join @tblIDsList a on t.InvDocDetailsID=a.ID
		
		if(@IStempINFO=1)
		BEGIN
			DELETE T FROM INV_TempInfo  T WITH(NOLOCK)
			join @tblIDsList a on t.InvDocDetailsID=a.ID 
		END
		
		
	END  
	
	Declare @TEMPUNIQUE TABLE(ID INT identity(1,1), SYSCOLUMNNAME NVARCHAR(50),USERCOLUMNNAME NVARCHAR(50) , SECTIONID INT )
	declare @Create bit
	INSERT INTO @TEMPUNIQUE     
	SELECT CC.SYSCOLUMNNAME,R.RESOURCEDATA,CC.SECTIONID FROM ADM_COSTCENTERDEF CC WITH(NOLOCK)
	JOIN COM_LANGUAGERESOURCES R WITH(NOLOCK) ON CC.RESOURCEID = R.RESOURCEID    
	WHERE CC.COSTCENTERID=@CostCenterID AND CC.ISUNIQUE=1    

	SELECT @UNIQUECNT = COUNT(ID) FROM @TEMPUNIQUE    
      
	WHILE(@I<@Cnt)        
	BEGIN      
		SET @I=@I+1    
	    
		SELECT  @xml=CONVERT(NVARCHAR(MAX),TransactionRows) FROM @tblList  WHERE ID=@I        
	  
		SELECT @TRANSXML=CONVERT(NVARCHAR(MAX), X.query('Transactions')),@NUMXML=CONVERT(NVARCHAR(MAX),X.query('Numeric')),@QtyAdjustments=CONVERT(NVARCHAR(MAX),X.query('QtyAdjustments')),@DocExtraXML=CONVERT(NVARCHAR(MAX),X.query('DocExtraXML')),
			@CCXML=CONVERT(NVARCHAR(MAX),X.query('CostCenters')),@TEXTXML=CONVERT(NVARCHAR(MAX),X.query('Alpha')),@EXTRAXML=CONVERT(NVARCHAR(MAX),X.query('EXTRAXML')),@BinsXML=CONVERT(NVARCHAR(MAX),X.query('BinsXML')),
			@DeprXML=CONVERT(NVARCHAR(MAX),X.query('DeprXML')),@AccountsXML=CONVERT(NVARCHAR(MAX),X.query('AccountsXML')),@PromXML=CONVERT(NVARCHAR(MAX),X.query('DynPromXML')) from @xml.nodes('/Row') as Data(X) 
		
		
		if(@IsImport=1)
		BEGIN
			select @ProductName=ISNULL(X.value('@ProductID','nvarchar(500)') ,0),@Iscode=ISNULL(X.value('@IsProductCode','INT') ,0)      ,@BILLDate=CONVERT(FLOAT,X.value('@BillDate','datetime'))      
					,@IsQtyIgnored=isnull(X.value('@IsQtyIgnored','bit'),1),@holseq =ISNULL(X.value('@DocSeqNo','INT') ,0)
					,@Create=isnull(X.value('@Create','bit'),1)
			from @TRANSXML.nodes('/Transactions') as Data(X)       
			
			if(@Iscode=2 and isnumeric(@ProductName)=1)
				set @ProductID=@ProductName
			ELSE	
				exec [spDOC_GetNode] 3,@ProductName,@Iscode,@DocumentType,@Create,@CompanyGUID,@UserName,@UserID,@LangID,@ProductID output
		
			select @ACCOUNT1Name=X.value('@DebitAccount','nvarchar(500)'),@Iscode=ISNULL(X.value('@DrAccCode','INT') ,0)      
			from @TRANSXML.nodes('/Transactions') as Data(X)

		    if(@Iscode=2 and isnumeric(@ACCOUNT1Name)=1)
				set @ACCOUNT1=@ACCOUNT1Name
			ELSE	
				exec [spDOC_GetNode] 2,@ACCOUNT1Name,@Iscode,@DocumentType,@Create,@CompanyGUID,@UserName,@UserID,@LangID,@ACCOUNT1 output
			
			select @ACCOUNT2Name=X.value('@CreditAccount','nvarchar(500)'),@Iscode=ISNULL(X.value('@CrAccCode','INT') ,0)             
			from @TRANSXML.nodes('/Transactions') as Data(X)
			
		    if(@Iscode=2 and isnumeric(@ACCOUNT2Name)=1)
				set @ACCOUNT2=@ACCOUNT2Name
			ELSE	
				exec [spDOC_GetNode] 2,@ACCOUNT2Name,@Iscode,@DocumentType,@Create,@CompanyGUID,@UserName,@UserID,@LangID,@ACCOUNT2 output
			set @InvDocDetailsID=0
			
			set @ActDocDate=CONVERT(int,@DocDate)
			
			update @tblBILL 
			set  AccountID=@ACCOUNT1
			where AccName=@ACCOUNT1Name
			
			update @tblBILL 
			set  AccountID=@ACCOUNT2
			where AccName=@ACCOUNT2Name
					 
		END
		ELSE
		BEGIN
			set @TEmpWid=null
			SELECT @InvDocDetailsID=X.value('@DocDetailsID','INT'),@BILLDate=CONVERT(FLOAT,X.value('@BillDate','datetime'))      
			,@TEmpWid=X.value('@WorkFlowID','int')		,@IsQtyIgnored=isnull(X.value('@IsQtyIgnored','bit'),1),@ACCOUNT1=ISNULL(X.value('@DebitAccount','INT'),1),@ACCOUNT2=ISNULL(X.value('@CreditAccount','INT') ,1)       
			,@ProductID =ISNULL(X.value('@ProductID','INT') ,0),@LinkedID=ISNULL(X.value('@LinkedInvDocDetailsID','INT') ,1)
			,@Remarks=X.value('@AppRemarks','nvarchar(max)'),@holseq =ISNULL(X.value('@DocSeqNo','INT') ,0)
			,@ActDocDate=isnull(CONVERT(int, X.value('@ActDocDate','Datetime')),CONVERT(int,@DocDate))
			from @TRANSXML.nodes('/Transactions') as Data(X)   
			
			if(@IsLockedPosting=1)
				set @InvDocDetailsID=0
			
			if(@LineWiseApproval=1)
			BEGIN	
				if exists(SELECT Value FROM @TblPref where IsGlobal=0 and Name='PostAsset' and Value='true')
				 or (@DocumentType=5 and convert(int,(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='DimTransferSrc'))>0
				 or exists (SELECT Value FROM @TblPref where IsGlobal=0 and  Name='IsBudgetDocument' and Value='1')
				 )
				BEGIN
					if(@InvDocDetailsID=0)
						set @oldStatus=0
					else
						select @oldStatus=StatusID from INV_DocDetails WITH(NOLOCK) where InvDocDetailsID=@InvDocDetailsID
				END		
					
				if(@TEmpWid is not null and @TEmpWid>0)
				begin
					set @level=null
					set @tempLevel=null
					set  @WID=@TEmpWid
					
					if(@InvDocDetailsID>0 or @InvDocDetailsID<-10000)
						select @tempLevel=WorkFlowLevel,@oldStatus=StatusID from INV_DocDetails WITH(NOLOCK) where InvDocDetailsID=@InvDocDetailsID
				
					if((@InvDocDetailsID>0 or @InvDocDetailsID<-10000) and @tempLevel is not null and @oldStatus not in(369,372))
					BEGIN
						set @level=null
						if (@DocumentType >= 51 AND @DocumentType <= 199 AND @DocumentType != 64) --IS PAYROLL DOCUMENT
						BEGIN
							
						--Check Whether the User Level is Payroll Employee Report Manager Level or Not
							SET @level=dbo.fnExt_GetRptMgrUserLevel(@InvDocDetailsID,@WID,@tempLevel,@UserName,@RoleID)							
						END
						
						if(@level is null)  
							SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
							where WorkFlowID=@WID and UserID =@UserID and LevelID>@tempLevel
							order by LevelID desc

						if(@level is null)  
							SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
							where WorkFlowID=@WID and RoleID =@RoleID and LevelID>@tempLevel
							order by LevelID desc

						if(@level is null)       
							SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
							JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
							where g.UserID=@UserID and WorkFlowID=@WID and LevelID>@tempLevel
							order by LevelID desc

						if(@level is null)  
							SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
							JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
							where g.RoleID =@RoleID and WorkFlowID=@WID and LevelID>@tempLevel
							order by LevelID desc
						
						select @level,@tempLevel,@WID
						
						if(@level is null) 
						BEGIN	
							SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
							where WorkFlowID=@WID and UserID =@UserID and LevelID>=@tempLevel
							order by LevelID desc

							if(@level is null)  
								SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
								where WorkFlowID=@WID and RoleID =@RoleID and LevelID>=@tempLevel
								order by LevelID desc

							if(@level is null)       
								SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
								JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
								where g.UserID=@UserID and WorkFlowID=@WID and LevelID>=@tempLevel
								order by LevelID desc

							if(@level is null)  
								SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
								JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
								where g.RoleID =@RoleID and WorkFlowID=@WID and LevelID>=@tempLevel
								order by LevelID desc
						END
					END
					
					if(@DocID=0 or @level is null or @oldStatus in (369,372))
					BEGIN						
						SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
						where WorkFlowID=@WID and UserID =@UserID
						order by LevelID desc

						if(@level is null)  
							SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
							where WorkFlowID=@WID and RoleID =@RoleID
							order by LevelID desc

						if(@level is null)       
							SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
							JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
							where g.UserID=@UserID and WorkFlowID=@WID
							order by LevelID desc

						if(@level is null)  
							SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
							JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
							where g.RoleID =@RoleID and WorkFlowID=@WID
							order by LevelID desc
					END
					
					select @maxLevel=max(a.LevelID) from COM_WorkFlow  a WITH(NOLOCK) 
					left join COM_WorkFlowDef b with(nolock) on a.WorkFlowID=b.WorkFlowID and IsEnabled=0 and a.LevelID=b.LevelID and CostCenterID=@CostCenterID		
					where a.WorkFlowID=@WID and b.WorkFlowID is null
				
					if(@level is not null and  @maxLevel is not null and @maxLevel>@level)    
					begin    
						if(@AppRejDate is not null)
							set @StatusID=441
						else	
							set @StatusID=371    
					end
					else
						set @StatusID=369
				end
				ELSE IF(@TEmpWid is not null and @TEmpWid=-1)    
				begin
					SELECT @WID=WorkflowID,@level=WorkFlowLevel,@StatusID=StatusID from INV_DocDetails WITH(NOLOCK)   
					where InvDocDetailsID=@InvDocDetailsID
				END
				ELSE IF(@TEmpWid is not null and @TEmpWid=-2)    
				begin
					SELECT @WID=WorkflowID,@tempLevel=WorkFlowLevel from INV_DocDetails WITH(NOLOCK)   
					where InvDocDetailsID=@InvDocDetailsID
					
					set @StatusID=372
					
					SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
					where WorkFlowID=@WID and UserID =@UserID and LevelID>@tempLevel
					order by LevelID desc

					if(@level is null)  
						SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
						where WorkFlowID=@WID and RoleID =@RoleID and LevelID>@tempLevel
						order by LevelID desc

					if(@level is null)       
						SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
						JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
						where g.UserID=@UserID and WorkFlowID=@WID and LevelID>@tempLevel
						order by LevelID desc

					if(@level is null)  
						SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
						JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
						where g.RoleID =@RoleID and WorkFlowID=@WID and LevelID>@tempLevel
						order by LevelID desc
					
				END
				ELSE IF(@TEmpWid is not null and @TEmpWid=0)
				begin
					SET @StatusID=369
					SELECT @WID=WorkflowID from INV_DocDetails WITH(NOLOCK)   
					where InvDocDetailsID=@InvDocDetailsID
					
					if(@WID>0)
					BEGIN
						SELECT @level=LevelID FROM [COM_WorkFlow]   WITH(NOLOCK)   
						where WorkFlowID=@WID and UserID =@UserID
						order by LevelID

						if(@level is null)  
							SELECT @level=LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)    
							where WorkFlowID=@WID and RoleID =@RoleID
							order by LevelID

						if(@level is null)       
							SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
							JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
							where g.UserID=@UserID and WorkFlowID=@WID
							order by LevelID

						if(@level is null)  
							SELECT @level=LevelID FROM [COM_WorkFlow] W WITH(NOLOCK)
							JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
							where g.RoleID =@RoleID and WorkFlowID=@WID
							order by LevelID
					END
				END 		
			END	 
		END
		
			
		SELECT @productType=ProductTypeID FROM INV_Product a WITH(NOLOCK)    
		WHERE  ProductID=@ProductID  
		
		if(@DocumentType=38)
		 select @VoucherType=isnull(X.value('@VoucherType','int'),-1) from @TRANSXML.nodes('/Transactions') as Data(X)     	
		else if(@DocumentType in(30,5))
		 select @VoucherType=isnull(X.value('@VoucherType','int'),0) from @TRANSXML.nodes('/Transactions') as Data(X)     
		
		declare @tble table(NIDs INT)  
	  
		IF (@AllowLockData=1 AND @IsLock=1 and @LockCC>50000)
		BEGIN	
				SELECT @LockCCValues=Value FROM @TblPref WHERE IsGlobal=1 and  Name='LockCostCenterNodes'
				if(@LockCCValues<>'')
				BEGIN
					SET @NID=0
					
					 set @SYSCOL='dcCCNID'+CONVERT(NVARCHAR,(@LockCC-50000))+'='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
					 if(@ind>0)
					 BEGIN
						 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @NID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
					 END
					 
					insert into @tble				
					exec SPSplitString @LockCCValues,','  
					if exists(select NIDs from @tble where NIDs=@NID)
						RAISERROR('-125',16,1)
				END
		END
	
		IF (@DAllowLockData=1 AND @IsLock=1 and @DLockCC>50000)
		BEGIN				
				SELECT @DLockCCValues=Value FROM @TblPref where IsGlobal=0 and  Name='LockCostCenterNodes'
				if(@DLockCCValues<>'')
				BEGIN
					SET @NID=0
					 set @SYSCOL='dcCCNID'+CONVERT(NVARCHAR,(@DLockCC-50000))+'='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
					 if(@ind>0)
					 BEGIN
						 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @NID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
					 END	

					DELETE FROM @tble
					insert into @tble				
					exec SPSplitString @DLockCCValues,','  
					if exists(select NIDs from @tble where NIDs=@NID)
						RAISERROR('-125',16,1)   			
				END	
		END
  
		set @PrefValue=''      
		select @PrefValue= isnull(Value,'') from @TblPref where IsGlobal=1 and  Name='Dontallowreceiptafterissue'        

		if(@PrefValue is not null and @PrefValue='true' and @IsQtyIgnored=0 and @VoucherType=1 and exists(select InvDocDetailsID from [INV_DocDetails] WITH(NOLOCK) 
		where convert(datetime,DocDate)>=@DocDate and VoucherType=-1 
		and ProductID=@ProductID and IsQtyIgnored=0 ))
		BEGIN
			if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
				select @ProductName=ProductCode+'-'+ProductName from Inv_product with(NOLOCK) where ProductID=(Select X.value('@ProductID','INT') from @TRANSXML.nodes('/Transactions') as Data(X) ) 
			else
				select @ProductName=ProductName from Inv_product with(NOLOCK) where ProductID=(Select X.value('@ProductID','INT') from @TRANSXML.nodes('/Transactions') as Data(X) ) 
			RAISERROR('-406',16,1)
		END

		if(@DocumentType=35)
		BEGIN	
			Declare @StartDate DATETIME,@EndDate DateTime,@SerialNo nvarchar(max)
			Select @StartDate=X.value('@dcAlpha3','DateTime') ,
			       @EndDate=X.value('@dcAlpha4','DateTime'),
			       @SerialNo=X.value('@dcAlpha6','nvarchar(max)')
			from @TEXTXML.nodes('/Alpha') as Data(X)  
			if(@SerialNo is not null and 	@SerialNo <>'')
			BEGIN		    
				if exists( SELECT VoucherNo FROM INV_DocDetails D WITH(NOLOCK)
				INNER JOIN [COM_DocTextData] DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				WHERE  DocumentType=35 and dcAlpha6= @SerialNo   and dcAlpha1=10003 and 
				dcAlpha3 is not null and dcAlpha3<>'' and dcAlpha4 is not null and dcAlpha4<>''
				and D.InvDocDetailsID<>@InvDocDetailsID
				and ( @StartDate   between CONVERT(datetime, dcAlpha3) and CONVERT(datetime, dcAlpha4)    
				or       @EndDate   between CONVERT(datetime, dcAlpha3) and CONVERT(datetime, dcAlpha4)
				or CONVERT(datetime, dcAlpha3) between @StartDate and @EndDate)    )
				BEGIN
					SELECT @ProductName= VoucherNo
					FROM INV_DocDetails D WITH(NOLOCK)    
					INNER JOIN [COM_DocTextData] DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID 
					WHERE  DocumentType=35 and dcAlpha6= @SerialNo   and dcAlpha1=10003 and 
					  dcAlpha3 is not null and dcAlpha3<>'' and dcAlpha4 is not null and dcAlpha4<>''
					   and D.InvDocDetailsID<>@InvDocDetailsID
					 and ( @StartDate   between CONVERT(datetime, dcAlpha3) and CONVERT(datetime, dcAlpha4)    
					 or       @EndDate   between CONVERT(datetime, dcAlpha3) and CONVERT(datetime, dcAlpha4)
					  or CONVERT(datetime, dcAlpha3) between @StartDate and @EndDate)
					set @ProductName=@ProductName+' , Serial No.'+@SerialNo
					RAISERROR('-387',16,1)
			   END
		   END       
		END
		--For Daily attendance 
		IF (@DocumentType=67 AND @InvDocDetailsID=0)
		BEGIN
			DECLARE @DateQuery nvarchar(30),@EMPLOYEEID INT,@EXSTNRMLHRS DECIMAL(9,2),@NORMALHRS DECIMAL(9,2),@CURRNRMLHRS DECIMAL(9,2),@CURRDOCNRMLHRS DECIMAL(9,2)
			
			set @SYSCOL='dcCCNID51='
			set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
			if(@ind>0)
			Begin
				set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
				set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
				set @indcnt=@indcnt-@ind-1
				if(@ind>0 and @indcnt>0)				 
					set @EMPLOYEEID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
			End
			
	  		SET @SYSCOL='dcAlpha1='
			set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
			if(@ind>0)
			Begin
				set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
				set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
				set @indcnt=@indcnt-@ind-1
				if(@ind>0 and @indcnt>0)				 
					set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
			End
			
			set @DailyattendanceDate1=replace(replace(@DateQuery,'N''',''),'''','')
					/*
					--CHECKING THE DOCUMENT IS LOCKED OR NOT
					SELECT  @LoctID=ISNULL(CCNID2,1) FROM COM_CCCCDATA WHERE COSTCENTERID=50051 AND NODEID=@EMPLOYEEID
					IF ((SELECT COUNT(*)  FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID 
							WHERE ID.COSTCENTERID=40077 AND ISNULL(TD.DCALPHA5,'')='LOCKED' AND CC.dcCCNID2=@LoctID	AND ISDATE(TD.DCALPHA2)=1 AND ISDATE(TD.DCALPHA3)=1 AND CONVERT(DATETIME,@DailyattendanceDate1) BETWEEN CONVERT(DATETIME,TD.DCALPHA2) AND CONVERT(DATETIME,TD.DCALPHA3)))>0
					BEGIN
						RAISERROR('-125',16,1) 
					END
					--NORMAL WORKING HOURS FOR SPECIFIED EMPLOYEE
					SELECT @NORMALHRS=ISNULL(TD.dcAlpha1,0) FROM INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK) WHERE ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND DC.INVDOCDETAILSID=TD.INVDOCDETAILSID 
						   AND DC.DCCCNID51=@EMPLOYEEID AND ID.COSTCENTERID=40066 AND ID.STATUSID NOT IN  (372,376) AND ISDATE(TD.dcAlpha6)=1  AND CONVERT(DATETIME,TD.dcAlpha6)<= CONVERT(DATETIME,@DailyattendanceDate1) ORDER BY CONVERT(DATETIME,TD.dcAlpha6) DESC  
					IF(ISNULL(@NORMALHRS,0)<=0)
					BEGIN
					--IF NODATE FOUND THEN RETRIEVING NORMAL WORKING HOURS OF DEFAULT EMPLOYEE
						SELECT  @NORMALHRS=ISNULL(TD.dcAlpha1,0) FROM INV_DOCDETAILS ID WITH(NOLOCK),COM_DocCCData DC WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK) WHERE ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND DC.INVDOCDETAILSID=TD.INVDOCDETAILSID 
								AND ISNULL(DC.DCCCNID51,1)=1 AND ID.COSTCENTERID=40066 AND ID.STATUSID NOT IN  (372,376) AND ISDATE(TD.dcAlpha6)=1  AND CONVERT(DATETIME,TD.dcAlpha6)<= CONVERT(DATETIME,@DailyattendanceDate1) ORDER BY CONVERT(DATETIME,TD.dcAlpha6) DESC  
					END
					
					--RETRIEVING EXISTING WORKED NORMAL HOURS FOR SPECIFIED EMPLOYEE EXCEPT CURRENT DOCUMENT
					SELECT @EXSTNRMLHRS=SUM(ISNULL(DN.DCNUM2,0)) FROM INV_DOCDETAILS ID WITH(NOLOCK),COM_DOCNUMDATA DN WITH(NOLOCK),COM_DOCCCDATA DC WITH(NOLOCK),COM_DOCTEXTDATA TD WITH(NOLOCK) WHERE ID.INVDOCDETAILSID=DN.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID 
						   AND ID.COSTCENTERID=40067 AND DC.DCCCNID51=@EMPLOYEEID AND ID.DOCID<>@DocID AND ISDATE(TD.DCALPHA1)=1 AND CONVERT(DATETIME,TD.dcAlpha1)= CONVERT(DATETIME,@DailyattendanceDate1)
					
					--RETRIEVING CURRENT DOCUMENT NORMAL HOURS FOR SPECIFIED EMPLOYEE
					SELECT @CURRDOCNRMLHRS=SUM(ISNULL(DN.DCNUM2,0)) FROM INV_DOCDETAILS ID WITH(NOLOCK),COM_DOCNUMDATA DN WITH(NOLOCK),COM_DOCCCDATA DC WITH(NOLOCK),COM_DOCTEXTDATA TD WITH(NOLOCK) WHERE ID.INVDOCDETAILSID=DN.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID 
						   AND ID.COSTCENTERID=40067 AND DC.DCCCNID51=@EMPLOYEEID AND ID.DOCID=@DocID AND ISDATE(TD.DCALPHA1)=1 AND CONVERT(DATETIME,TD.dcAlpha1)= CONVERT(DATETIME,@DailyattendanceDate1)
					--RETRIEVING CURRENT ROW NORMAL HOURS
					 SET @SYSCOL='dcNum2='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML))
					 if(@ind>0)
					 BEGIN
						 set @ind=Charindex('=',convert(nvarchar(max),@NUMXML), Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@NUMXML), Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @CURRNRMLHRS=Substring(convert(nvarchar(max),@NUMXML),@ind+1,@indcnt)  
					 END
					SET @EXSTNRMLHRS=ISNULL(@EXSTNRMLHRS,0)+ISNULL(@CURRNRMLHRS,0)+ISNULL(@CURRDOCNRMLHRS,0)
										
	  		--	   	IF((SELECT COUNT(*) FROM  Com_DocTextData TD WITH(NOLOCK),Inv_DocDetails ID  WITH(NOLOCK),COM_DOCCCDATA DC WITH(NOLOCK) WHERE TD.InvDocDetailsID=ID.InvDocDetailsID AND DC.InvDocDetailsID=ID.InvDocDetailsID  AND TD.InvDocDetailsID=DC.InvDocDetailsID 
	  		--			AND DC.DCCCNID51=@EMPLOYEEID AND @EXSTNRMLHRS>@NORMALHRS AND ID.DOCID<>@DocID AND ISDATE(td.dcalpha1)=1  
	  		--			AND convert(datetime,td.dcalpha1)=convert(datetime,@DailyattendanceDate1))>0)
					--BEGIN
					--	RAISERROR('-551',16,1) 
					--END
					
					*/
		END
		--
		--For Form 12BA 
		IF ((@DocumentType=61 or @DocumentType=74 or @DocumentType=75 or @DocumentType=76 or @DocumentType=77 or @DocumentType=78) AND @InvDocDetailsID=0)
		BEGIN
			--DECLARE @EMPYEAR NVARCHAR(20),@EMPCODE INT
			IF (@DocumentType=76 or @DocumentType=78)
			BEGIN
				set	@SYSCOL='dcCCNID51='
				set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
				IF(@ind>0)
				BEGIN
					set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
					set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
					set @indcnt=@indcnt-@ind-1
					if(@ind>0 and @indcnt>0)				 
						set @EMPCODE=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
				End
			END
			IF (@DocumentType=61 or @DocumentType=75)
			BEGIN
				set	@SYSCOL='dcCCNID53='
				set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
				IF(@ind>0)
				BEGIN
					set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
					set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
					set @indcnt=@indcnt-@ind-1
					if(@ind>0 and @indcnt>0)				 
						set @DocGrade=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
				End
			END
			IF (@DocumentType=77)
			BEGIN
				set	@SYSCOL='dcCCNID2='
				set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
				IF(@ind>0)
				BEGIN
					set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
					set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
					set @indcnt=@indcnt-@ind-1
					if(@ind>0 and @indcnt>0)				 
						set @DocLoc=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
				End
			END
			
	  		SET @SYSCOL='dcAlpha1='
			set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
			if(@ind>0)
			Begin
				set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
				set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
				set @indcnt=@indcnt-@ind-1
				if(@ind>0 and @indcnt>0)				 
					set @EMPYEAR=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
			End
					set @EMPYEAR=replace(replace(@EMPYEAR,'N''',''),'''','')
					
					IF (@DocumentType=74)
					BEGIN
						SET @SYSCOL='dcAlpha10='
						set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
						if(@ind>0)
						Begin
							set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
							set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
							set @indcnt=@indcnt-@ind-1
							if(@ind>0 and @indcnt>0)				 
								set @regime=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
						End
						set @regime=replace(replace(@regime,'N''',''),'''','')

	  			   		IF((SELECT COUNT(*) FROM Inv_DocDetails ID WITH(NOLOCK)
	  			   		JOIN Com_DocTextData TD WITH(NOLOCK) ON TD.InvDocDetailsID=ID.InvDocDetailsID AND TD.dcAlpha1=@EMPYEAR AND TD.dcAlpha10=@regime
	  					WHERE ID.COSTCENTERID=40074 AND ID.DOCID<>@DocID)>0)
						BEGIN
							RAISERROR('-143',16,1) 
						END
					END
					ELSE IF (@DocumentType=76 OR @DocumentType=78)
					BEGIN
						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM Inv_DocDetails ID WITH(NOLOCK)
	  			   		JOIN Com_DocTextData TD  WITH(NOLOCK) ON TD.InvDocDetailsID=ID.InvDocDetailsID AND TD.dcAlpha1='''+@EMPYEAR+'''
	  			   		JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON DC.InvDocDetailsID=ID.InvDocDetailsID AND DC.DCCCNID51='+CONVERT(NVARCHAR,@EMPCODE)+' 
	  					WHERE ID.DocumentType='+CONVERT(NVARCHAR,@DocumentType)+' AND ID.DOCID<>'+CONVERT(NVARCHAR,@DocID)
	  					EXEC sp_executesql @SQL,N'@ind INT OUTPUT',@ind OUTPUT 
	  					
	  			   		IF(@ind>0)
						BEGIN
							RAISERROR('-143',16,1) 
						END
					END
					ELSE IF (@DocumentType=61)
					BEGIN
	  			   		set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM Inv_DocDetails ID WITH(NOLOCK)
	  			   		JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON DC.InvDocDetailsID=ID.InvDocDetailsID AND DC.DCCCNID53='+CONVERT(NVARCHAR,@DocGrade)+' 
	  					WHERE ID.DocumentType='+CONVERT(NVARCHAR,@DocumentType)+' AND STATUSID=369 AND ID.DOCID<>'+CONVERT(NVARCHAR,@DocID)
	  					EXEC sp_executesql @SQL,N'@ind INT OUTPUT',@ind OUTPUT 
	  					
	  			   		IF(@ind>0)
						BEGIN
							RAISERROR('-143',16,1) 
						END
					END
		END
		
		IF (@DocumentType=62 AND @InvDocDetailsID=0)
		BEGIN
			set @SYSCOL='dcCCNID51='
			set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
			if(@ind>0)
			Begin
				set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
				set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
				set @indcnt=@indcnt-@ind-1
				if(@ind>0 and @indcnt>0)				 
				set @EMPID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
			End
			
	  			 SET @SYSCOL='dcAlpha4='
				 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
				 if(@ind>0)
				 Begin
					 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
				 End
						set @FromDate=replace(replace(@DateQuery,'N''',''),'''','')
						
				 SET @SYSCOL='dcAlpha5='
				 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
				 if(@ind>0)
				 Begin
					 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
				 End
				set @TDate=replace(replace(@DateQuery,'N''',''),'''','')
				
				set @ind=0
				SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
				JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
				JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
				WHERE TD.tCostCenterID=40072 AND ID.StatusID NOT IN (372,376)
				AND LEN(TD.dcAlpha2)<=15 AND LEN(TD.dcAlpha3)<=15 AND ISDATE(TD.dcAlpha2)=1  AND ISDATE(TD.dcAlpha3)=1 AND ISDATE(TD.dcAlpha1)=1 AND  
				(CONVERT(DATETIME,dcAlpha2) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
				or CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1))) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
				or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1)))
				or CONVERT(DATETIME,@TDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1))))'
				EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 

				IF(@ind>0)
				BEGIN
					RAISERROR('-551',16,1)  
				END
		END
		--
		--APPLY VACATION VALIDATION
		IF (@DocumentType=72 AND @InvDocDetailsID=0)
		BEGIN
				set @SYSCOL='dcCCNID51='
				set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
				if(@ind>0)
				Begin
				 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
				 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
				 set @indcnt=@indcnt-@ind-1
				 if(@ind>0 and @indcnt>0)				 
					set @EMPID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
				End
			
	  			 SET @SYSCOL='dcAlpha2='
				 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
				 if(@ind>0)
				 Begin
					 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
				 End
						set @FromDate=replace(replace(@DateQuery,'N''',''),'''','')
						
				 SET @SYSCOL='dcAlpha3='
				 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
				 if(@ind>0)
				 Begin
					 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
				 End
						set @TDate=replace(replace(@DateQuery,'N''',''),'''','')
				
				if(@RefNodeid=0)
				BEGIN		
				set @ind=0
				SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
				JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
				JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
				WHERE TD.tDocumentType=62 AND ID.StatusID NOT IN (372,376)
				AND ISDATE(TD.dcAlpha4)=1  AND ISDATE(TD.dcAlpha5)=1 AND
				( CONVERT(DATETIME,dcAlpha4) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
				or CONVERT(DATETIME,dcAlpha5) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
				or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5)
				or CONVERT(DATETIME,@TDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5))'
				EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 

				IF(@ind>0)
				BEGIN
					set @ind=0
					SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
					JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
					JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
					WHERE TD.tCostCenterID=40073 AND ID.StatusID NOT IN (372,376)
					AND ISDATE(TD.dcAlpha2)=1  AND ISDATE(TD.dcAlpha3)=1 AND ISNULL(TD.DCALPHA4,'''')<>''Yes'' AND 
					( CONVERT(DATETIME,dcAlpha2) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
					or CONVERT(DATETIME,dcAlpha3) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
					or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DATETIME,dcAlpha3)
					or CONVERT(DATETIME,@TDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DATETIME,dcAlpha3))'
					EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 

					IF(@ind>0)
					BEGIN
						RAISERROR('-551',16,1)  
					END 
				END
				END
				
				set @ind=0
				SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
				JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
				JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
				WHERE TD.tCostCenterID=40072 AND ID.StatusID NOT IN (372,376) AND ID.DOCID<>'+convert(nvarchar,@DOCID)+' 
				AND LEN(TD.dcAlpha2)<=15 AND LEN(TD.dcAlpha3)<=15 AND ISDATE(TD.dcAlpha2)=1  AND ISDATE(TD.dcAlpha3)=1 AND ISDATE(TD.dcAlpha1)=1 AND
			    ( CONVERT(DATETIME,dcAlpha2) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
				or CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1))) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
				or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1)))
				or CONVERT(DATETIME,@TDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1))))'
				EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 
				
				IF(@ind>0)
				BEGIN
					RAISERROR('-551',16,1)  
				END
		END
		--
		--COMPENSATORY LEAVES DATA VALIDATION
		IF (@DocumentType=59 AND @InvDocDetailsID=0)
		BEGIN
				 
				 set @SYSCOL='dcCCNID51='
				 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
				 if(@ind>0)
				 Begin
					 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @EMPID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
				 End
				 
	  			 SET @SYSCOL='dcAlpha1='
				 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
				 if(@ind>0)
				 Begin
					 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
				 End
				 
				 set @FromDate=replace(replace(@DateQuery,'N''',''),'''','')
				
				 set @ind=0
				 SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
				 JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
				 JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON ID.InvDocDetailsID=CC.InvDocDetailsID AND CC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
				 WHERE  TD.tCostCenterID=40054 AND ISDATE(DCALPHA17)=1 AND ISDATE(DCALPHA18)=1 AND CONVERT(DATETIME,@FROMDATE) between CONVERT(DATETIME,DCALPHA17) and CONVERT(DATETIME,DCALPHA18)'
				 EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@ind INT OUTPUT',@FROMDATE,@ind OUTPUT 
				
		   		 IF(@ind>0)
				 BEGIN
					RAISERROR('-562',16,1)
				 END
				  
				set @ind=0
				SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
				JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
				JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
				WHERE TD.tCostCenterID=40072 AND ID.StatusID NOT IN (372,376) 
				AND ISDATE(TD.dcAlpha2)=1  AND ISDATE(TD.dcAlpha3)=1 
				AND CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DATETIME,dcAlpha3)'
				EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@ind INT OUTPUT',@FROMDATE,@ind OUTPUT 

				IF(@ind>0)
				BEGIN
					RAISERROR('-551',16,1)  
				END
		END
		--
		
		
		if(@CheckHold=1)
		begin
			declare @hld float,@QOH float,@HOLDQTY float,@RESERVEQTY float
			select @hld=ISNULL(X.value('@HoldQuantity','float'),0),@ProductID =ISNULL(X.value('@ProductID','INT') ,0)					   
			from @TRANSXML.nodes('/Transactions') as Data(X) 
			 
			set @WHERE=''
			select @PrefValue=Value from @TblPref where IsGlobal=1 and  Name='EnableLocationWise'        

			if(@PrefValue='True')        
			begin        
				set @PrefValue=''      
				select @PrefValue=Value from @TblPref where IsGlobal=1 and  Name='Location Stock'        
				if(@PrefValue='True')      
				begin      
					select @NID=ISNULL(X.value('@dcCCNID2','INT'),1) 
					from @CCXML.nodes('/CostCenters') as Data(X)      
					set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@NID)        
				end
			end	

			set @PrefValue=''      
			select @PrefValue= isnull(Value,'') from @TblPref where IsGlobal=1 and  Name='Maintain Dimensionwise stock'        

			if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)=50002)        
			begin        
				select @NID=ISNULL(X.value('@dcCCNID2','INT'),1) 
				from @CCXML.nodes('/CostCenters') as Data(X)      	          
				set @WHERE =@WHERE+' and dcCCNID2='+CONVERT(nvarchar,@NID)        
			end 
		
			set @DUPLICATECODE='declare @tab table(DetID INT) 
						declare @tabids table(id INT identity(1,1),DetID INT) 

						declare @DocDetailsID nvarchar(max) ,@sql nvarchar(max) ,@i int,@cnt int,@ID INT
						set @DocDetailsID='''+convert(nvarchar,@InvDocDetailsID)+'''

						insert into @tab(DetID)values('+convert(nvarchar,@InvDocDetailsID)+')

						set @sql=''SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK)         
							WHERE LinkedInvDocDetailsID in(''+@DocDetailsID+'')''

						insert into @tabids
						exec(@sql)
						if('+convert(nvarchar,@InvDocDetailsID)+'>0)
						BEGIN
							while(exists (select DetID from @tabids))
							begin       	       
								insert into @tab(DetID)
								select DetID from @tabids	
								
								set @DocDetailsID=''''
								select @i=min(id),@cnt=max(id) from @tabids
								set @i=@i-1
								while(@i<@cnt)
								begin
									set @i=@i+1
									select @ID=DetID from @tabids where id=@i
									set @DocDetailsID=@DocDetailsID+convert(nvarchar,@ID)
									if(@i<>@cnt)
										set @DocDetailsID=@DocDetailsID+'',''
								end
								delete from @tabids
								
								set @sql=''SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK)         
								WHERE VoucherType<>1 and LinkedInvDocDetailsID in(''+@DocDetailsID+'')''
								insert into @tabids
								exec(@sql)
							end    
						END
						set @QOH=(SELECT isnull(sum(Quantity*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)      
					INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID      
					WHERE D.ProductID='+convert(nvarchar,@ProductID)+' AND IsQtyIgnored=0 '+@WHERE+'
					and D.INVDocDetailsID not in(select DetID from @tab) and (VoucherType=-1 or VoucherType=1)) 
							set @HOLDQTY=( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from 
					(SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.Quantity else l.ReserveQuantity end),0) release
					FROM INV_DocDetails D WITH(NOLOCK)    
					INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID 
					left join INV_DocDetails l  WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					WHERE D.ProductID='+convert(nvarchar,@ProductID)+' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) 
					and D.INVDocDetailsID not in(select DetID from @tab)  and D.VoucherType=-1 '+@WHERE+'
					group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp)
					
							set @RESERVEQTY=( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from 
					(SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.Quantity else l.ReserveQuantity end),0) release
					FROM INV_DocDetails D WITH(NOLOCK)    
					INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID 
					left join INV_DocDetails l  WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					WHERE D.ProductID='+convert(nvarchar,@ProductID)+' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) 
					and D.INVDocDetailsID not in(select DetID from @tab)  and D.VoucherType=-1 '+@WHERE+'
					group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp)' 

			EXEC sp_executesql @DUPLICATECODE, N'@QOH float OUTPUT,@HOLDQTY float OUTPUT,@RESERVEQTY float OUTPUT',@QOH  OUTPUT,@HOLDQTY  OUTPUT,@RESERVEQTY  OUTPUT      
			if(@hld>(@QOH-@HOLDQTY-@RESERVEQTY) and @ProductID>0 and @hld>0)
			begin
				if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
					select @ProductName=ProductCode+'-'+ProductName from inv_product WITH(NOLOCK) where ProductID=@ProductID
				ELSE
					select @ProductName=ProductName from inv_product WITH(NOLOCK) where ProductID=@ProductID
				RAISERROR('-380',16,1)
			end
	
		end
      
		select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='DisableQtyCheck'      
		if(@PrefValue is not null and @PrefValue='False' )       	
			select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='UpdateJustReference'      

        if(@PrefValue is not null and @PrefValue='False')       
		BEGIN
			Declare  @CurrCnt FLOAT , @INVDOCID INT ,@LinkCostCenterID INT,@fldName nvarchar(200),@tolPer float,@tolVal float
			 
			SELECT @INVDOCID = X.value('@LinkedInvDocDetailsID','INT') , @CurrCnt = isnull(X.value('@LinkedFieldValue','float'),0)   , @fldName = X.value('@LinkedFieldName','nvarchar(200)')          
			FROM @TRANSXML.nodes('/Transactions') as Data(X)   
			   
			IF (@INVDOCID IS NOT NULL AND @INVDOCID > 0 AND @CurrCnt IS NOT NULL AND @CurrCnt > 0)
			BEGIN				 
				SELECT @LinkCostCenterID=CostCenterID,@tolPer=isnull(p.MaxTolerancePer,0),@tolVal=isnull(p.MaxToleranceVal,0)   
				from INV_DOCDETAILS a with(nolock)				
				join dbo.INV_Product p WITH(NOLOCK) on  a.ProductID=p.ProductID    
				WHERE a.InvDocDetailsID = @INVDOCID
				 
				SELECT @fldName=SysColumnName,@DUP_VoucherNo=LinkedVouchers from ADM_CostCenterDef a with(nolock)
				join [COM_DocumentLinkDef] b with(nolock) on b.CostCenterColIDLinked=a.CostCenterColID
				where  CostCenterIDBase=@CostCenterID and CostCenterIDLinked=@LinkCostCenterID
				
				set @SQL='select @QtyFin = '+@fldName+' from INV_DOCDETAILS a with(nolock)
				join COM_DocNumData d WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID
				WHERE a.InvDocDetailsID = '+convert(nvarchar,@INVDOCID)
				EXEC sp_executesql @SQL,N'@QtyFin Float OUTPUT',@QtyFin OUTPUT    
								
				select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='Enabletolerance'      
				if(@PrefValue is not null and @PrefValue='True')
				BEGIN
					if(@tolPer>0)
						set @QtyFin=@QtyFin+ ((@QtyFin*@tolPer)/100)
					else if(@tolVal>0)
						set @QtyFin=@QtyFin+ @tolVal
				END
				
				-- Total Quantity 
				set @SQL='SELECT @QthChld =  ISNULL(SUM(LinkedFieldValue),0)  FROM INV_DOCDETAILS WITH(NOLOCK) 
				WHERE LINKEDINVDOCDETAILSID = '+convert(nvarchar,@INVDOCID)+' AND INVDOCDETAILSID <>  '+convert(nvarchar,@InvDocDetailsID)+' and StatusID<>376 '
				
				set @PrefValue=''
				select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)
				where CostCenterID=@LinkCostCenterID and PrefName='AllowMultipleLinking'  
				
				if(@PrefValue is not null and @PrefValue='True') --FOr Linking Multiple        
				BEGIN    				 
					if(@DUP_VoucherNo is not null and @DUP_VoucherNo <>'')					
						  SET @DUP_VoucherNo = @DUP_VoucherNo +','+convert(nvarchar(5),@CostCenterID)   					 
					 ELSE
						SET @DUP_VoucherNo = convert(nvarchar(5),@CostCenterID)       
				
					SET @SQL=@SQL+' and CostCenterid  in ('+@DUP_VoucherNo  +')'
				END    
				
				EXEC sp_executesql @SQL,N'@QthChld Float OUTPUT',@QthChld OUTPUT    
				
				set @QtyFin= @QtyFin-ISNULL(@QthChld,0) - ISNULL(@CurrCnt,0)
				
				select @QtyFin=@QtyFin+isnull(sum(Quantity),0) from INV_DocExtraDetails WITH(NOLOCK) 
				where type=10 and InvDocDetailsID=@InvDocDetailsID		
				
				IF(@QtyFin<-0.001)  
				BEGIN  
				select @InvDocDetailsID,@QtyFin
			
					RAISERROR('-377',16,1)      
				END 
			END   
		 END  
   
		IF(@TEXTXML IS NOT NULL AND CONVERT(NVARCHAR(MAX),@TEXTXML)<>'' and @UNIQUECNT>0)      
		BEGIN     
        
		DECLARE @iUNIQ INT,  @QRYUNIQ NVARCHAR(MAX)
		DECLARE @tempCode NVARCHAR(200),@DUPNODENO NVARCHAR(200)    
		   
		SET  @iUNIQ = 0 
		WHILE (@iUNIQ < @UNIQUECNT )    
		BEGIN     
			SET @iUNIQ = @iUNIQ + 1     
			SELECT @SYSCOL = SYSCOLUMNNAME  ,@TYPE = USERCOLUMNNAME  , @SECTIONID = SECTIONID  FROM @TEMPUNIQUE WHERE ID =  @iUNIQ     
	        
	        set @DUPNODENO=''
			IF(@SYSCOL LIKE '%dcAlpha%')    
			BEGIN    				    				   
				continue;   
			END     
			ELSE IF(@SYSCOL LIKE '%dcCCNID%')     
			BEGIN    
				   				
				SET @cctablename = 'COM_DOCCCDATA' 
				 set @ind=Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML))
				 if(@ind>0)
				 BEGIN
					 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @DUPNODENO=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
				 END	
				   
			END     
			ELSE IF(@SYSCOL LIKE '%dcNum%')     
			BEGIN  
				SET @cctablename = 'COM_DOCNUMDATA'    
				 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML))
				 if(@ind>0)
				 BEGIN
					 set @ind=Charindex('=',convert(nvarchar(max),@NUMXML), Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@NUMXML), Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @DUPNODENO=Substring(convert(nvarchar(max),@NUMXML),@ind+1,@indcnt)  
				 END
			END     
	          
			 
	     
			--sectionid = 3 for linewise    
			if(@DUPNODENO is not null and @DUPNODENO<>'')
			BEGIN     
				SET @tempCode ='@QUERYTEST  NVARCHAR(100) OUTPUT'    
				SET @DUPLICATECODE =  ' IF EXISTS (SELECT DOCEXT.INVDOCDETAILSID    FROM '+ @cctablename +' DOCEXT with(nolock)
				JOIN INV_DOCDETAILS INV with(nolock) ON DOCEXT.INVDOCDETAILSID=INV.INVDOCDETAILSID WHERE  INV.StatusID<>376 AND '
				IF(@SECTIONID = 3)
					set @DUPLICATECODE = @DUPLICATECODE+' INV.INVDOCDETAILSID <> '+ CONVERT(NVARCHAR(50),@InvDocDetailsID) +' AND '
				else
					set @DUPLICATECODE = @DUPLICATECODE+' INV.DOCID <> '+ CONVERT(NVARCHAR(50),@DocID) +' AND '

				SET @DUPLICATECODE = @DUPLICATECODE+ '    
				INV.COSTCENTERID =  '+ CONVERT(NVARCHAR(50), @CostCenterID) +' and '+ @SYSCOL+' = '''+ @DUPNODENO +''')     
				BEGIN     
				SET @QUERYTEST = (SELECT  TOP 1 INV.VOUCHERNO FROM '+ @cctablename +' DOCEXT with(nolock)
				JOIN INV_DOCDETAILS INV with(nolock) ON DOCEXT.INVDOCDETAILSID = INV.INVDOCDETAILSID WHERE  '
				IF(@SECTIONID = 3)
					set @DUPLICATECODE = @DUPLICATECODE+' INV.INVDOCDETAILSID <> '+ CONVERT(NVARCHAR(50),@InvDocDetailsID) +' AND '
				else
					set @DUPLICATECODE = @DUPLICATECODE+' INV.DOCID <> '+ CONVERT(NVARCHAR(50),@DocID) +' AND '

				SET @DUPLICATECODE = @DUPLICATECODE+ '  INV.COSTCENTERID =  '+     
				CONVERT(NVARCHAR(50), @CostCenterID) +' and '+ @SYSCOL+' = '''+ @DUPNODENO +''')         
				END  '    
		         
			   EXEC sp_executesql @DUPLICATECODE ,@tempCode ,@QUERYTEST OUTPUT    
		          
				IF(@QUERYTEST IS NOT NULL)    
				BEGIN    
					IF(@SECTIONID = 3)    
						RAISERROR('-346',16,1)    
					ELSE    
						RAISERROR('-347',16,1)     
				END
			END	       
		END     		
	END
     
		--CHECKING UNIQUE DOCUMENT
		if @IsUniqueDoc=1
		BEGIN		
		DECLARE @UI INT,@Val NVARCHAR(MAX)		
		SET @SQL=@UniqueQuery
		SET @UI=1
		while(@UI<=@UniqueCount)
		BEGIN
			SELECT @SYSCOL=UsedColumn FROM @TblUnique WHERE ID=@UI
			
			IF @SYSCOL like 'dcCCNID%'
			BEGIN		
				set @ind=Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML))
				if(@ind>0)
				BEGIN
					set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @Val=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
				END	
				SET @SQL=replace(@SQL,'@@'+@SYSCOL+'@@',ISNULL(@Val,'1'))
			END
			ELSE
			BEGIN
				SET @DUPLICATECODE  = 'SELECT  @DUPNODENO = X.value(''@'+@SYSCOL +''',''nvarchar(max)'')      
				from @TRANSXML.nodes(''/Transactions'') as Data(X)'      
			
				EXEC sp_executesql @DUPLICATECODE,N'@TRANSXML XML,@DUPNODENO nvarchar(200) OUTPUT',@TRANSXML,@Val OUTPUT    
				SET @SQL=replace(@SQL,'@@'+@SYSCOL+'@@',ISNULL(@Val,'1'))
			END
			SET @UI=@UI+1
		END
		SET @SQL='SELECT @VoucherNo=VoucherNo '+@SQL+' AND D.DocID!='+CONVERT(NVARCHAR,@DocID)		
		exec sp_executesql @SQL,N'@VoucherNo NVARCHAR(100) OUTPUT',@DUP_VoucherNo OUTPUT		  		
		IF @DUP_VoucherNo IS NOT NULL
		BEGIN
			SET @VoucherNo=@DUP_VoucherNo
			RAISERROR('-378',16,1)  
		END
    END
    	   

	SELECT @PrefValueDoc=CONVERT(BIT,Value) from @TblPref where IsGlobal=0 and  Name='VendorBasedBillNo'
	SELECT @hideBillNo=CONVERT(BIT,Value) FROM @TblPref where IsGlobal=0 and  Name='Hide_Billno'  
  
	IF(@PrefValueDoc > 0 and ( @hideBillNo  is null or @hideBillNo = 0) and @BillNo IS NOT NULL AND @BillNo <> '' )  
	BEGIN  
		set @PrefValue=''
		SELECT @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='BillNoDocs'
		if(@PrefValue is null or @PrefValue='')
			set @PrefValue=convert(nvarchar,@CostCenterID)
			
		SET @SQL='
		IF(@VoucherType=1)
		BEGIN   
			if exists (SELECT   [BillNo]   FROM [INV_DocDetails] WITH(NOLOCK) WHERE   [CostCenterID] in('+@PrefValue+') and 
			CreditAccount = @ACCOUNT2  and  DocID<>@DocID  and  [BillNo] = @BillNo and convert(datetime,DocDate) between @frdate and @toDate and StatusID<>376)
			begin
				SELECT @ProductName = ACCOUNTNAME FROM ACC_ACCOUNTS WITH(NOLOCK) WHERE ACCOUNTID = @ACCOUNT2  
				RAISERROR(''-374'',16,1)      
			end
		END   
		ELSE  
		BEGIN   
			if exists (SELECT   [BillNo]   FROM [INV_DocDetails] WITH(NOLOCK) WHERE  [CostCenterID] in('+@PrefValue+') and 
			DebitAccount = @ACCOUNT1  and  DocID<>@DocID  and  [BillNo] = @BillNo  and convert(datetime,DocDate) between @frdate and @toDate and StatusID<>376 )
			BEGIN 				
					SELECT @ProductName = ACCOUNTNAME FROM ACC_ACCOUNTS WITH(NOLOCK) WHERE ACCOUNTID = @ACCOUNT1  
					RAISERROR(''-375'',16,1)  				
			END   			
		END '
		print @SQL
		exec sp_executesql @SQL,N'@VoucherType INT,@ACCOUNT2 INT,@ACCOUNT1 INT,@frdate datetime,@toDate datetime,@DocID INT,@BillNo  NVARCHAR(500),@ProductName nvarchar(500) output',@VoucherType,@ACCOUNT2,@ACCOUNT1,@frdate,@toDate,@DocID,@BillNo,@ProductName OUTPUT	
		
		   
	END 
	
	if(@IsBatChes=1 and (@InvDocDetailsID>0 or @InvDocDetailsID<-10000 )and @IsQtyIgnored=0 and 	@VoucherType=1 and @batchCol='')
       BEGIN 
			set @OldBatchID=1
			select @OldBatchID=BatchID  FROM [INV_DocDetails] WITH(NOLOCK) WHERE InvDocDetailsID=@InvDocDetailsID
			
		   --validate if batch changed
		   set @BatchID=1
		   select @BatchID=isnull(X.value('@BatchID','INT'),1)
		   from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X) 			
			if(@OldBatchID>1 and @OldBatchID<>@BatchID and @ProductType=5)
			BEGIN  		
				 	
				select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
				where Name='AllowNegativebatches' and costcenterid=16  

				if(@ConsolidatedBatches is null or @ConsolidatedBatches ='false')
				BEGIN
					select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
					where Name='ConsolidatedBatches' and costcenterid=16  

					if(@ConsolidatedBatches is not null and @ConsolidatedBatches ='False')  
					begin     
						set @Tot=0
						
						set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
						FROM [INV_DocDetails] AS BD  with(nolock)                  
						where vouchertype=-1 and IsQtyIgnored=0  and batchid=@OldBatchID and RefInvDocDetailsID=@InvDocDetailsID),0)   
					end  
					else  
					begin  
						set @Tot=isnull((SELECT sum(BD.ReleaseQuantity)    
						FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
						where vouchertype=1 and IsQtyIgnored=0  and batchid=@OldBatchID and InvDocDetailsID<>@InvDocDetailsID),0)  

						set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
						FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
						where vouchertype=-1 and IsQtyIgnored=0  and batchid=@OldBatchID),0)
					end  
					
					if(@Tot<-0.001)   
					begin  
						RAISERROR('-502',16,1)      
					end  
				END 
			END
		END
			
			if (exists(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='ApprOnComparitiveAnalysis' and value='true')
			and @oldStatus<>369 and @StatusID=369)
			   set @StatusID=441
			   
			IF(@InvDocDetailsID=0)      
			BEGIN    
			

				if(@ACCOUNT1 is null)    
					set @ACCOUNT1=1    
				if(@ACCOUNT2 is null)    
					set @ACCOUNT2=1      	      

				INSERT INTO [INV_DocDetails]      
				([AccDocDetailsID]      
				,[DocID]      
				,[CostCenterID] 
				,[DocumentType],DocOrder,ActDocDate
				,[VoucherType]      
				,[VoucherNo]      
				,[VersionNo]      
				,[DocAbbr]      
				,[DocPrefix]      
				,[DocNumber]      
				,[DocDate]      
				,[DueDate]      
				,[StatusID]      
				,[BillNo]      
				,BillDate      
				,[LinkedInvDocDetailsID]      
				,[LinkedFieldName]      
				,[LinkedFieldValue]      
				,[CommonNarration]      
				,LineNarration      
				,[DebitAccount]      
				,[CreditAccount]      
				,[DocSeqNo]      
				,[ProductID]      
				,[Quantity]      
				,[Unit]      
				,[HoldQuantity]    
				,[ReserveQuantity]     
				,[ReleaseQuantity]    
				,[IsQtyIgnored]      
				,[IsQtyFreeOffer]      
				,[Rate]      
				,[AverageRate]      
				,[Gross]      
				,[StockValue]      
				,[CurrencyID]      
				,[ExchangeRate]     
				,[GrossFC]    
				,[StockValueFC]       				     
				,[CreatedBy]      
				,[CreatedDate],ModifiedBy,ModifiedDate,UOMConversion,CanRecur,DynamicInvDocDetailsID
				,UOMConvertedQty,WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID,RefNodeid,ParentSchemeID,RefNo,Net,Account1,AP)    
				SELECT X.value('@AccDocDetailsID','INT')      
				, @DocID      
				, @CostCenterID    				   
				, case when @DocumentType=38 and X.value('@VoucherType','int') is not null then 39 else @DocumentType end
				, ISNULL(X.value('@DocOrder','float'),@DocOrder)
				, @ActDocDate
				, case when @DocumentType in(5,30,54) then X.value('@VoucherType','int')
					   when @DocumentType=38 and X.value('@VoucherType','int') is not null then 1 else  @VoucherType end
				, @VoucherNo    
				, @VersionNo    
				, @DocAbbr    
				, @DocPrefix      
				, @DocNumber      
				, CONVERT(FLOAT,@DocDate)
				, case when  X.value('@DueDate','Datetime') is not null THEN CONVERT(float, X.value('@DueDate','Datetime')) else   CONVERT(FLOAT,@DueDate)       end                   
				, @StatusID  
				, Case WHEN  X.value('@BillNo','NVarChar(500)') is not null THEN X.value('@BillNo','NVarChar(500)') ELSE @BillNo  END    
				, @BILLDate      
				, X.value('@LinkedInvDocDetailsID','INT')      
				, X.value('@LinkedFieldName','nvarchar(200)')      
				, X.value('@LinkedFieldValue','float')      
				, X.value('@CommonNarration','nvarchar(max)')      
				, X.value('@LineNarration','nvarchar(max)')      
				, @ACCOUNT1      
				, @ACCOUNT2      
				, X.value('@DocSeqNo','int')      
				, @ProductID      
				, X.value('@Quantity','float')      
				, ISNULL( X.value('@Unit','INT'),(select UOMID from inv_product WITH(NOLOCK)  where productid=@ProductID))
				, ISNULL( X.value('@HoldQuantity','float'),0)     
				, ISNULL( X.value('@ReserveQuantity','float'),0)      
				, 0 --Release Qyt            
				, ISNULL(X.value('@IsQtyIgnored','bit'),0)      
				, ISNULL(X.value('@IsQtyFreeOffer','INT'),0)      
				, X.value('@Rate',' float')      
				, ISNULL(X.value('@AverageRate','float'),0)      
				, ( X.value('@Gross',' float') * ISNULL(X.value('@ExchangeRate','float'),1) )     
				, ISNULL(X.value('@StockValue','float'),0)      
				, ISNULL(X.value('@CurrencyID','int'),1)      
				, ISNULL(X.value('@ExchangeRate','float'),1)    
				, X.value('@Gross',' float')    
				, ISNULL(X.value('@StockValueFC','float'),ISNULL(X.value('@StockValue','float'),0))       				
				, @UserName      
				, @Dt  , @UserName      
				, @Dt      
				, X.value('@UOMConversion','float'),X.value('@CanRecur','BIT'),X.value('@DynamicInvDocDetailsID','INT')
				, X.value('@UOMConvertedQty','float')             
				, @WID,@StatusID,@level,@RefCCID,@RefNodeid, X.value('@ParentSchemeID','nvarchar(500)')
				, X.value('@RefNO','nvarchar(200)'),X.value('@Net','float')
				, case when @DocumentType in(1,39,27,26,25,2,34,6,3,4,13,41,42) then @ACCOUNT2 else @ACCOUNT1 end
				,@AP
				from @TRANSXML.nodes('/Transactions') as Data(X)      

				SET @InvDocDetailsID=@@IDENTITY  

				INSERT INTO [COM_DocCCData] ([InvDocDetailsID])     
				values(@InvDocDetailsID)
				
				if(@CostCenterID=40054)
				BEGIN
					set @sql='INSERT INTO [PAY_DocNumData] ([InvDocDetailsID])     
							values('+convert(nvarchar(max),@InvDocDetailsID)+')'
					exec(@sql)
				END
				ELSE
				BEGIN
					INSERT INTO [COM_DocNumData] ([InvDocDetailsID])     
					values(@InvDocDetailsID)
				END
				
				INSERT INTO [COM_DocTextData] ([InvDocDetailsID])     
				values(@InvDocDetailsID)
				
				if(@DocumentType=56)
				BEGIN
					set @DUPLICATECODE=''
					select @DUPLICATECODE=@DUPLICATECODE+a.name+'=0,' from sys.columns a
					join sys.tables b on a.object_id=b.object_id
					where b.name='COM_DocNumData'  and a.name like 'dcExchRT%'
					
					set @DUPLICATECODE=substring(@DUPLICATECODE,0,len(@DUPLICATECODE))
					if(LEN(@DUPLICATECODE)>0)
						set @DUPLICATECODE='Update [COM_DocNumData] set '+@DUPLICATECODE+'   where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
					exec(@DUPLICATECODE)
				END

			DECLARE @TSQL NVARCHAR(MAX)
			
			if(@IsImport=1)      
			begin
				
				declare @linkRefNo nvarchar(max),@LCCID INT,@LFName NVARCHAR(100),@LRSNo INT,@LFVal FLOAT,@linkDType INT
				SET @LFName='Quantity'
				SET @LRSNo=0

				Select @linkRefNo= X.value('@LinkingRefNo',' nvarchar(max)'),@LRSNo= ISNULL(X.value('@LinkingRefNoSNo','INT'),0)  
				from @TRANSXML.nodes('/Transactions') as Data(X)
				
				----------
				SELECT @LCCID=CostCenterID,@linkDType=DocumentType FROM [INV_DocDetails] with(nolock) WHERE voucherNo  = @linkRefNo
				SELECT @LFName=SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterID 
								AND CostCenterColID=(Select CostCenterColIDBase FROM COM_DocumentLinkDef WITH(NOLOCK) WHERE CostCenterIDBase=@CostCenterID AND CostCenterIDLinked=@LCCID )

				----------
				
				 if(@linkRefNo is not null and exists(select InvDocDetailsID FROM [INV_DocDetails] with(nolock) 
				 WHERE   voucherNo  = @linkRefNo AND ProductID =  @ProductID ))
				 BEGIN
					IF(@LFName IS NOT NULL AND @LFName='Gross')
					BEGIN
						SELECT @LinkedID=IDD1.InvDocDetailsID FROM [INV_DocDetails] IDD1 with(nolock)
						left join [INV_DocDetails] IDD2 with(nolock) ON IDD2.LinkedInvDocDetailsID =IDD1.InvDocDetailsID
						WHERE   IDD1.voucherNo  = @linkRefNo AND IDD1.ProductID = @ProductID AND IDD1.DocSeqNo=@LRSNo
						group by IDD1.InvDocDetailsID
						having sum(IDD1.Gross)>=(isnull(sum(IDD2.LinkedFieldValue),0)+(SELECT IDD3.Gross FROM [INV_DocDetails] IDD3 with(nolock) WHERE IDD3.InvDocDetailsID=@InvDocDetailsID ))
					END
					ELSE IF(@LFName IS NOT NULL AND @LFName LIKE 'dcNum%')
					BEGIN
						SET @SQL='SELECT @LinkedID=IDD1.InvDocDetailsID FROM [INV_DocDetails] IDD1 with(nolock)
						LEFT JOIN COM_DocNumData IDD1N WITH(NOLOCK) ON IDD1.InvDocDetailsID=IDD1N.InvDocDetailsID
						left join [INV_DocDetails] IDD2 with(nolock) ON IDD2.LinkedInvDocDetailsID =IDD1.InvDocDetailsID
						WHERE   IDD1.voucherNo  = '''+@linkRefNo+''' AND IDD1.ProductID = '+convert(nvarchar,@ProductID)+' AND IDD1.DocSeqNo='+convert(nvarchar,@LRSNo)+'
						group by IDD1.InvDocDetailsID
						having sum(IDD1N.'+@LFName+')>=(isnull(sum(IDD2.LinkedFieldValue),0)+(SELECT IDD3N.'+@LFName+' FROM [INV_DocDetails] IDD3 with(nolock) 
																								LEFT JOIN COM_DocNumData IDD3N WITH(NOLOCK) ON IDD3.InvDocDetailsID=IDD3N.InvDocDetailsID
																								WHERE IDD3.InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)+' ))'
						exec sp_executesql @SQL,N'@LinkedID INT OUTPUT',@LinkedID OUTPUT	
					END
					ELSE
					BEGIN
						if @linkDType=5
							SELECT @LinkedID=IDD1.InvDocDetailsID FROM [INV_DocDetails] IDD1 with(nolock)
							left join [INV_DocDetails] IDD2 with(nolock) ON IDD2.LinkedInvDocDetailsID =IDD1.InvDocDetailsID
							WHERE   IDD1.voucherNo  = @linkRefNo AND IDD1.ProductID = @ProductID AND IDD1.VoucherType=-1
							group by IDD1.InvDocDetailsID
							having sum(IDD1.Quantity)>=(isnull(sum(IDD2.LinkedFieldValue),0)+(SELECT IDD3.Quantity FROM [INV_DocDetails] IDD3 with(nolock) WHERE IDD3.InvDocDetailsID=@InvDocDetailsID ))
						else
						Begin
							if(@LRSNo is Not Null AND @LRSNo>0)
							BEGIN
							IF((SELECT PrefValue FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@LCCID AND PrefName='AllowMultipleLinking')='true')
								SELECT @LinkedID=IDD1.InvDocDetailsID FROM [INV_DocDetails] IDD1 with(nolock)
								left join [INV_DocDetails] IDD2 with(nolock) ON IDD2.LinkedInvDocDetailsID =IDD1.InvDocDetailsID
								WHERE   IDD1.voucherNo  = @linkRefNo AND IDD1.ProductID = @ProductID AND IDD1.DocSeqNo=@LRSNo
								group by IDD1.InvDocDetailsID
							ELSE
								SELECT @LinkedID=IDD1.InvDocDetailsID FROM [INV_DocDetails] IDD1 with(nolock)
								left join [INV_DocDetails] IDD2 with(nolock) ON IDD2.LinkedInvDocDetailsID =IDD1.InvDocDetailsID
								WHERE   IDD1.voucherNo  = @linkRefNo AND IDD1.ProductID = @ProductID AND IDD1.DocSeqNo=@LRSNo
								group by IDD1.InvDocDetailsID
								having sum(IDD1.Quantity)>=(isnull(sum(IDD2.LinkedFieldValue),0)+(SELECT IDD3.Quantity 
								FROM [INV_DocDetails] IDD3 with(nolock) WHERE IDD3.InvDocDetailsID=@InvDocDetailsID ))
							END
							Else
							BEGIN
							IF((SELECT PrefValue FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@LCCID AND PrefName='AllowMultipleLinking')='true')
								SELECT @LinkedID=IDD1.InvDocDetailsID FROM [INV_DocDetails] IDD1 with(nolock)
								left join [INV_DocDetails] IDD2 with(nolock) ON IDD2.LinkedInvDocDetailsID =IDD1.InvDocDetailsID
								WHERE   IDD1.voucherNo  = @linkRefNo AND IDD1.ProductID = @ProductID
								group by IDD1.InvDocDetailsID
							ELSE
								SELECT @LinkedID=IDD1.InvDocDetailsID FROM [INV_DocDetails] IDD1 with(nolock)
								left join [INV_DocDetails] IDD2 with(nolock) ON IDD2.LinkedInvDocDetailsID =IDD1.InvDocDetailsID
								WHERE   IDD1.voucherNo  = @linkRefNo AND IDD1.ProductID = @ProductID
								group by IDD1.InvDocDetailsID
								having sum(IDD1.Quantity)>=(isnull(sum(IDD2.LinkedFieldValue),0)+(SELECT IDD3.Quantity FROM [INV_DocDetails] IDD3 with(nolock) WHERE IDD3.InvDocDetailsID=@InvDocDetailsID ))
							END
						END					
					END

					if(@LinkedID is null)
						SELECT @LinkedID=InvDocDetailsID FROM [INV_DocDetails] with(nolock) 
						WHERE   voucherNo  = @linkRefNo AND ProductID =  @ProductID
					
					IF(@LFName IS NOT NULL AND @LFName='Gross')
					BEGIN
						update T set T.LinkedInvDocDetailsID=@LinkedID,T.LinkedFieldName='Gross',
						T.LinkedFieldValue=Gross,T.RefNo=@linkRefNo
						FROM INV_DocDetails T WITH(NOLOCK)
						Where T.InvDocDetailsID=@InvDocDetailsID	
					END
					ELSE IF(@LFName IS NOT NULL AND @LFName LIKE 'dcNum%')
					BEGIN
						SET @SQL='update INV_DocDetails 
						set LinkedInvDocDetailsID='+CONVERT(NVARCHAR,@LinkedID)+',LinkedFieldName='''+@LFName+''',
						LinkedFieldValue='+@LFName+',RefNo='''+@linkRefNo+'''
						FROM INV_DocDetails a 
						LEFT JOIN COM_DocNumData b on b.InvDocDetailsID=a.InvDocDetailsID
						Where a.InvDocDetailsID='+CONVERT(NVARCHAR,@InvDocDetailsID)
						--print @SQL
						SET @TSQL=@SQL
						--EXEC(@SQL)
					END
					ELSE
					BEGIN
						update T set T.LinkedInvDocDetailsID=@LinkedID,T.LinkedFieldName='Quantity',
						T.LinkedFieldValue=Quantity,T.RefNo=@linkRefNo
						FROM INV_DocDetails T WITH(NOLOCK)
						Where T.InvDocDetailsID=@InvDocDetailsID				
					END
				 END
				
				 set @linkRefNo=''
				 set @PrefValue=''
				 Select @linkRefNo= isnull(X.value('@BinCode',' nvarchar(max)'),''),@PrefValue= isnull(X.value('@BinName',' nvarchar(max)'),'')
				 from @TRANSXML.nodes('/Transactions') as Data(X)
			
				 if(@linkRefNo<>'' or @PrefValue<>'')
				 BEGIN
						if(@PrefValue<>'')
						BEGIN
							set @Iscode=0
							set @linkRefNo=@PrefValue
						END 
						else
							set @Iscode=1
						set @PrefValue=''
						select @PrefValue=value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
						and  name='BinsDimension'  
						set @BinDimesion=0 
						if(@PrefValue<>'')
						begin    		
							begin try    
								select @BinDimesion=convert(INT,@PrefValue)    
							end try    
							begin catch    
								set @BinDimesion=0    
							end catch 		
						END 
						
						if(@BinDimesion>50000)
						BEGIN
							exec [spDOC_GetNode] @BinDimesion,@linkRefNo,@Iscode,@DocumentType,1,@CompanyGUID,@UserName,@UserID,@LangID,@BinDimesionNodeID output
					 
							insert into INV_BinDetails(InvDocDetailsID,BinID,Quantity,VoucherType,IsQtyIgnored)
							select InvDocDetailsID,@BinDimesionNodeID,UOMConvertedQty,VoucherType,IsQtyIgnored
							from [INV_DocDetails] WITH(NoLock)
							where InvDocDetailsID=@InvDocDetailsID 
							
						END
				 END
				 
				set @PrefValue=''
				select @PrefValue=PrefValue from COM_DocumentPreferences  WITH(NOLOCK)       
				where CostCenterID=@CostCenterID and PrefName='DuplicateProductClubBins'      
	  
				if(@PrefValue='true')       
				begin 					
					set @PrefValue=''
					select @PrefValue=value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
					and  name='BinsDimension'  
					set @BinDimesion=0 
					if(@PrefValue<>'')
					begin    		
						begin try    
							select @BinDimesion=convert(INT,@PrefValue)    
						end try    
						begin catch    
							set @BinDimesion=0    
						end catch 		
					END 
					
					if(@BinDimesion>50000)
					BEGIN		
						set @DUPLICATECODE='select @BinDimesionNodeID=dcCCNID'+convert(nvarchar,(@BinDimesion-50000))+' from [COM_DocCCData] with(nolock) where [InvDocDetailsID]='+convert(nvarchar,@InvDocDetailsID)
						EXEC sp_executesql @DUPLICATECODE,N'@BinDimesionNodeID INT OUTPUT',@BinDimesionNodeID output
						if(@BinDimesionNodeID>1)
						BEGIN
							set @CaseID=0
							set @NID=0
							select @CaseID=Value  from @TblPref where IsGlobal=1 and Name ='DimensionwiseBins' and isnumeric(Value)=1
							if(@CaseID>50000)
							BEGIN   
							   set @DUPLICATECODE='select @NID=dcCCNID'+convert(nvarchar,(@CaseID-50000))+' from [COM_DocCCData] with(nolock) where [InvDocDetailsID]='+convert(nvarchar,@InvDocDetailsID)
								EXEC sp_executesql @DUPLICATECODE,N'@NID INT OUTPUT',@NID output
							END 
							  
							IF not exists(select BinNodeID from INV_ProductBins with(nolock) where NodeID=@ProductID and BinDimension=@BinDimesion and BinNodeID=@BinDimesionNodeID )
							BEGIN
								INSERT INTO [INV_ProductBins]([CostcenterID],[NodeID],[BinDimension]
									,[BinNodeID],[IsDefault],[CreatedBy],[CreatedDate],DimCCID,DimNodeID)
								values(3,@ProductID,@BinDimesion,@BinDimesionNodeID,1,@UserName, @Dt,@CaseID,@NID)
							END
							
							if (@CaseID>50000)
							BEGIN
								Update T set T.IsDefault=0 
								FROM [INV_ProductBins] T WITH(NOLOCK)
								where T.NodeID=@ProductID and T.CostcenterID=3 
								and T.DimNodeID=@NID
								
								Update  T set T.IsDefault=1
								 FROM INV_ProductBins T WITH(NOLOCK)
								where T.NodeID=@ProductID and T.CostcenterID=3 
								and T.DimNodeID=@NID and T.BinNodeID=@BinDimesionNodeID
							END
						END	
						END
					END 
				END
			END      
			ELSE      
			BEGIN  
				set @CaseID=0
				select @CaseID= ProductID from [INV_DocDetails] WITH(NoLock)
				where LinkedInvDocDetailsID=@InvDocDetailsID 
				if(@CaseID>0 and @CaseID<>@ProductID)
				BEGIN
					if exists(select PrefValue from COM_DocumentPreferences with(nolock)
					where CostCenterID in (select CostCenterID from [INV_DocDetails] WITH(NoLock)
					where LinkedInvDocDetailsID=@InvDocDetailsID) and PrefName='SnoBasedLinking' and PrefValue<>'true')
					BEGIN
						if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
							select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@CaseID
						ELSE
							select @ProductName=ProductName from Inv_product with(NOLOCK) 
							where ProductID=@CaseID

						RAISERROR('-521',16,1)     
					END	
				END
				
				--ASSIGN LEAVES DATA VALIDATION
				--IF (@DocumentType=81 and @DocID>0)
				--BEGIN
				--	set @SYSCOL='dcAlpha2'
				--	 SET @tempCode='@DUPNODENO nvarchar(max) OUTPUT '     
				--	 SET @DUPLICATECODE  = 'SELECT   @DUPNODENO ='+@SYSCOL +'     
				--	                        from COM_DOCTEXTDATA WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)     
				--	 EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT 
				--	 set @LeaveYear=@DUPNODENO
					 
				--	 IF((SELECT COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
				--	     WHERE ID.StatusID NOT IN (372,376) AND ID.CostCenterID=40081  AND  ID.DOCID<>@DocID AND TD.DCALPHA2=@LeaveYear)>0)
				--	 BEGIN
				--		RAISERROR('-143',16,1)  
				--	 END
				--END
				
				--Topup Leaves
				IF (@DocumentType=60 and @DocID>0)
				BEGIN
					 DECLARE @LVTYPE FLOAT
					 set @SYSCOL='dcAlpha3'
					 SET @tempCode='@DUPNODENO nvarchar(max) OUTPUT '     
					 SET @DUPLICATECODE  = 'SELECT   @DUPNODENO ='+@SYSCOL +'     
					                        from COM_DOCTEXTDATA WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)     
					 EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT 
					 set @FromDate=convert(datetime,@DUPNODENO)
							
					 set @SYSCOL='dcAlpha4'
					 SET @tempCode='@DUPNODENO nvarchar(max) OUTPUT '     
					 SET @DUPLICATECODE  = 'SELECT   @DUPNODENO ='+@SYSCOL +'     
						                    from COM_DOCTEXTDATA WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)     
					 EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT 
					 set @TDate=convert(datetime,@DUPNODENO)
							
					 set @SYSCOL='dcCCNID51='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
					 if(@ind>0)
					 Begin
						 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @EMPID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
					 End
					 
					 
					 --FOR EXISTING LEAVETYPE FROM DOCUMENT
					 set @SYSCOL='dcCCNID52'
					 SET @tempCode='@DUPNODENO nvarchar(max) OUTPUT '     
					 SET @DUPLICATECODE  = 'SELECT   @DUPNODENO ='+@SYSCOL +'     
						                    from COM_DOCCCDATA WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)     
					 EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT 
					 set @LVTYPE=convert(INT,@DUPNODENO)
					 --FOR NEW LEAVETYPE FROM XML					 
					 set @SYSCOL='dcCCNID52='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
					 if(@ind>0)
					 Begin
						 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @LEAVETYPE=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
					 End
					 
					 IF(@LEAVETYPE<>@LVTYPE)
					 BEGIN
						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
						JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
						JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
						WHERE TD.tDocumentType=62 AND ID.StatusID NOT IN (372,376) AND DC.dcCCNID52='+convert(nvarchar,@LVTYPE)+' 
						AND ISDATE(TD.dcAlpha4)=1 AND CONVERT(DATETIME,TD.dcAlpha4) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)'
						EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 

						IF(@ind>0)
						BEGIN
							RAISERROR('-350',16,1)  
					 	 END
					 END
					--
					 --FOR LEAVES ASSIGNED
					 SET @SYSCOL='dcNum3='
					 SET @ind=Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML))
					 IF(@ind>0)
					 BEGIN
						 set @ind=Charindex('=',convert(nvarchar(max),@NUMXML), Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@NUMXML), Charindex(@SYSCOL,convert(nvarchar(max),@NUMXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @AssignLeaves=Substring(convert(nvarchar(max),@NUMXML),@ind+1,@indcnt)  
					 END
					    ----FOR START DATE AND END DATE OF LEAVE YEAR	
						Declare @AppliedDays float,@CurrYearLeavestaken float,@NOOFHOLIDAYS float,@WEEKLYOFFCOUNT float,@ExstAppliedEncashdays float,@ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME
						DECLARE @SysDateTime FLOAT
						SET @SysDateTime=CONVERT(FLOAT,GETDATE())
						EXEC spPAY_EXTGetLeaveyearDates @FromDate,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
						EXEC spPAY_GetCurrYearLeavesInfo @ALStartMonthYear,@ALEndMonthYear,@EMPID,@LEAVETYPE,@Userid,@Langid,@SysDateTime,0,@CurrYearLeavestaken OUTPUT,@NOOFHOLIDAYS OUTPUT,@WEEKLYOFFCOUNT OUTPUT,@ExstAppliedEncashdays OUTPUT
						SET @AppliedDays=ISNULL(@CurrYearLeavestaken,0)+ISNULL(@ExstAppliedEncashdays,0)
						IF(ISNULL(@AppliedDays,0)>ISNULL(@AssignLeaves,0))
						BEGIN
							RAISERROR('-350',16,1) 
						END
				END
				--
				--APPLY LEAVES DATA VALIDATION
				IF (@DocumentType=62 and @DocID>0)
				BEGIN
					 set @SYSCOL='dcCCNID51='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
					 if(@ind>0)
					 Begin
						 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @EMPID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
					 End
			
	  				 SET @SYSCOL='dcAlpha4='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
					 if(@ind>0)
					 Begin
						 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
					 End
							set @FromDate=replace(replace(@DateQuery,'N''',''),'''','')
							
							
					 SET @SYSCOL='dcAlpha5='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
					 if(@ind>0)
					 Begin
						 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
					 End
					set @TDate=replace(replace(@DateQuery,'N''',''),'''','')
					 
					set @ind=0
					SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
					JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
					JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
					WHERE TD.tCostCenterID=40072 AND ID.StatusID NOT IN (372,376)
					AND ISDATE(TD.dcAlpha2)=1  AND ISDATE(TD.dcAlpha3)=1 AND ISDATE(TD.dcAlpha1)=1 AND 
				    ( CONVERT(DATETIME,dcAlpha2) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
					or CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1))) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
					or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1)))
					or CONVERT(DATETIME,@TDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1))))'
					EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 

					IF(@ind>0)
					BEGIN
						RAISERROR('-551',16,1)  
					END
				END
				--
				--APPLY VACATION VALIDATION
				IF (@DocumentType=72 and @DocID>0)
				BEGIN
					 set @SYSCOL='dcCCNID51='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
					if(@ind>0)
					Begin
					 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @EMPID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
					End
					
	  				 SET @SYSCOL='dcAlpha2='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
					 if(@ind>0)
					 Begin
						 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
					 End
							set @FromDate=replace(replace(@DateQuery,'N''',''),'''','')
							
					 SET @SYSCOL='dcAlpha3='
					 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
					 if(@ind>0)
					 Begin
						 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
					 End
					set @TDate=replace(replace(@DateQuery,'N''',''),'''','')
					
					if(@RefNodeid=0)
					BEGIN		
						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
						JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
						JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
						WHERE TD.tDocumentType=62 AND ID.StatusID NOT IN (372,376)
						AND ISDATE(TD.dcAlpha4)=1  AND ISDATE(TD.dcAlpha5)=1  AND 
						( CONVERT(DATETIME,dcAlpha4) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
						or CONVERT(DATETIME,dcAlpha5) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
						or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5)
						or CONVERT(DATETIME,@TDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5))'
						EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 

						IF(@ind>0)
						BEGIN
							set @ind=0
							SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
							JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
							JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
							WHERE TD.tCostCenterID=40073 AND ID.StatusID NOT IN (372,376)
							AND ISDATE(TD.dcAlpha2)=1  AND ISDATE(TD.dcAlpha3)=1 AND ISNULL(TD.DCALPHA4,'''')<>''Yes'' AND 
							( CONVERT(DATETIME,dcAlpha2) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
							or CONVERT(DATETIME,dcAlpha3) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
							or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DATETIME,dcAlpha3)
							or CONVERT(DATETIME,@TDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DATETIME,dcAlpha3))'
							EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 

							IF(@ind>0)
							BEGIN
								RAISERROR('-551',16,1)  
							END
						END
					END
					
					set @ind=0
					SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
					JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
					JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
					WHERE TD.tCostCenterID=40072 AND ID.StatusID NOT IN (372,376) AND ID.DOCID<>'+convert(nvarchar,@DocID)+'  
					AND ISDATE(TD.dcAlpha2)=1  AND ISDATE(TD.dcAlpha3)=1 AND ISDATE(TD.dcAlpha1)=1  AND
				    ( CONVERT(DATETIME,dcAlpha2) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
					or CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1))) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@TDate)
					or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1)))
					or CONVERT(DATETIME,@TDate) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DateTime,DATEADD(D,-1,CONVERT(DateTime,dcAlpha1))))'
					EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@TDate DATETIME,@ind INT OUTPUT',@FROMDATE,@TDate,@ind OUTPUT 

					IF(@ind>0)
					BEGIN
						RAISERROR('-551',16,1)  
					END
				END
				--
				--COMPENSATORY LEAVES DATA VALIDATION
				IF (@DocumentType=59 AND @DocID>0)
				BEGIN
						 set @SYSCOL='dcCCNID51='
						 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
						 if(@ind>0)
						 Begin
							 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
							 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
							 set @indcnt=@indcnt-@ind-1
							 if(@ind>0 and @indcnt>0)				 
								set @EMPID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
						 End
					
	  					 SET @SYSCOL='dcAlpha1='
						 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
						 if(@ind>0)
						 Begin
							 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
							 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
							 set @indcnt=@indcnt-@ind-1
							 if(@ind>0 and @indcnt>0)				 
								set @DateQuery=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
						 End
						set @FromDate=replace(replace(@DateQuery,'N''',''),'''','')
							
						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
						JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
						JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
						WHERE TD.tCostCenterID=40054 AND ISDATE(DCALPHA17)=1 AND ISDATE(DCALPHA18)=1 
						AND CONVERT(DATETIME,@FROMDATE) between CONVERT(DATETIME,DCALPHA17) and CONVERT(DATETIME,DCALPHA18)'
						EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@ind INT OUTPUT',@FROMDATE,@ind OUTPUT 

						IF(@ind>0)
						BEGIN
							RAISERROR('-562',16,1)
						END 
						
						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM INV_DOCDETAILS ID WITH(NOLOCK) 
						JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.InvDocDetailsID=TD.InvDocDetailsID	
						JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.InvDocDetailsID=DC.InvDocDetailsID AND DC.DCCCNID51='+convert(nvarchar,@EMPID)+' 
						WHERE TD.tCostCenterID=40072 AND ID.StatusID NOT IN (372,376) AND ISDATE(dcAlpha2)=1 AND ISDATE(dcAlpha3)=1 
						AND CONVERT(DATETIME,@FROMDATE) between CONVERT(DATETIME,dcAlpha2) and CONVERT(DATETIME,dcAlpha3)'
						EXEC sp_executesql @SQL,N'@FROMDATE DATETIME,@ind INT OUTPUT',@FROMDATE,@ind OUTPUT 

						IF(@ind>0)
						BEGIN
							RAISERROR('-551',16,1)  
						END
				END				
				--
				--For Form 12BA 
				IF ((@DocumentType=61 or @DocumentType=67 or @DocumentType=74 or @DocumentType=75 or @DocumentType=76 or @DocumentType=77 or @DocumentType=78) AND @DocID>0)
				BEGIN
				
					IF (@DocumentType=76 or @DocumentType=78)
					BEGIN
							SET @SYSCOL='dcCCNID51='
								 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
								 IF(@ind>0)
								 BEGIN
									 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
									 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
									 set @indcnt=@indcnt-@ind-1
									 if(@ind>0 and @indcnt>0)				 
										set @EMPCODE=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
								 End
					END	
					IF (@DocumentType=61 or @DocumentType=75)
					BEGIN
						set	@SYSCOL='dcCCNID53='
						 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
						 IF(@ind>0)
						 BEGIN
							 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
							 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
							 set @indcnt=@indcnt-@ind-1
							 if(@ind>0 and @indcnt>0)				 
								set @DocGrade=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
						 End
					END
					IF (@DocumentType=77)
					BEGIN
						set	@SYSCOL='dcCCNID2='
							 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
							 IF(@ind>0)
							 BEGIN
								 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
								 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
								 set @indcnt=@indcnt-@ind-1
								 if(@ind>0 and @indcnt>0)				 
									set @DocLoc=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
							 End
					END
	  			
	  				SET @SYSCOL='dcAlpha1='
					
					set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
					if(@ind>0)
					Begin
						 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
							set @EMPYEAR=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
					End
					
					set @EMPYEAR=replace(replace(@EMPYEAR,'N''',''),'''','')
					IF (@DocumentType=76)
					BEGIN
						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM Inv_DocDetails ID  WITH(NOLOCK) 
		   				JOIN Com_DocTextData TD WITH(NOLOCK) ON TD.InvDocDetailsID=ID.InvDocDetailsID
		   				JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON DC.InvDocDetailsID=ID.InvDocDetailsID AND DC.DCCCNID51='+CONVERT(NVARCHAR,@EMPCODE)+' 
						WHERE TD.tCOSTCENTERID=40076 AND TD.dcAlpha1='''+@EMPYEAR+''' AND ID.DOCID<>'+CONVERT(NVARCHAR,@DOCID)
						EXEC sp_executesql @SQL,N'@ind INT OUTPUT',@ind OUTPUT
						
		   				IF(@ind>0)
						BEGIN
							RAISERROR('-143',16,1) 
						END
					END
					ELSE IF (@DocumentType=74)
					BEGIN
						SET @SYSCOL='dcAlpha10='
					
						set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML))
						if(@ind>0)
						Begin
							 set @ind=Charindex('=',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0))
							 set @indcnt=Charindex(',',convert(nvarchar(max),@TEXTXML), Charindex(@SYSCOL,convert(nvarchar(max),@TEXTXML),0)) 
							 set @indcnt=@indcnt-@ind-1
							 if(@ind>0 and @indcnt>0)				 
								set @Regime=Substring(convert(nvarchar(max),@TEXTXML),@ind+1,@indcnt)  
						End
					
						set @Regime=replace(replace(@Regime,'N''',''),'''','')

						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM Inv_DocDetails ID  WITH(NOLOCK) 
		   				JOIN Com_DocTextData TD WITH(NOLOCK) ON TD.InvDocDetailsID=ID.InvDocDetailsID
		   				WHERE TD.tCOSTCENTERID=40074 AND TD.dcAlpha1='''+@EMPYEAR+''' AND TD.dcAlpha10='''+@Regime+''' AND ID.DOCID<>'+CONVERT(NVARCHAR,@DOCID)
						EXEC sp_executesql @SQL,N'@ind INT OUTPUT',@ind OUTPUT
						
		   				IF(@ind>0)
						BEGIN
							RAISERROR('-143',16,1) 
						END
					END
					ELSE IF (@DocumentType=78)
					BEGIN
						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM Inv_DocDetails ID  WITH(NOLOCK) 
		   				JOIN Com_DocTextData TD WITH(NOLOCK) ON TD.InvDocDetailsID=ID.InvDocDetailsID
		   				JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON DC.InvDocDetailsID=ID.InvDocDetailsID AND DC.DCCCNID51='+CONVERT(NVARCHAR,@EMPCODE)+' 
						WHERE TD.tCOSTCENTERID=40078 AND TD.dcAlpha1='''+@EMPYEAR+''' AND ID.DOCID<>'+CONVERT(NVARCHAR,@DOCID)
						EXEC sp_executesql @SQL,N'@ind INT OUTPUT',@ind OUTPUT
						
		   				IF(@ind>0)
		   				BEGIN
							RAISERROR('-143',16,1) 
						END
					END
					ELSE IF (@DocumentType=61)
					BEGIN
						set @ind=0
						SET @SQL='SELECT @ind=COUNT(*) FROM Inv_DocDetails ID  WITH(NOLOCK) 
		   				JOIN Com_DocTextData TD WITH(NOLOCK) ON TD.InvDocDetailsID=ID.InvDocDetailsID
		   				JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON DC.InvDocDetailsID=ID.InvDocDetailsID AND DC.DCCCNID53='+CONVERT(NVARCHAR,@DocGrade)+' 
						WHERE TD.tCOSTCENTERID=40061 AND ID.DOCID<>'+CONVERT(NVARCHAR,@DOCID)
						EXEC sp_executesql @SQL,N'@ind INT OUTPUT',@ind OUTPUT
						
		   				IF(@ind>0)
		   				BEGIN
							RAISERROR('-143',16,1) 
						END
					END
				END
				--
				if not exists (select Value from @TblPref where IsGlobal=0 and  Name='LinkForward' and Value='true')
				BEGIN
				
					select @QtyFin=X.value('@Quantity','float')  from @TRANSXML.nodes('/Transactions') as Data(X)   

					set @DUPLICATECODE='select @TotLinkedQty=isnull(SUM(LinkedFieldValue),0) from [INV_DocDetails] WITH(NoLock)
					where LinkedInvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)+' and LinkedFieldName=''Quantity'''
					
					if exists (select Value from @TblPref where IsGlobal=0 and  Name='AllowMultipleLinking' and Value='true')
					BEGIN
						set @WHERE=''
						select @WHERE=@WHERE+','+[LinkedVouchers],@CaseID=[CostCenterIDBase]    FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
						where [CostCenterIDLinked]=@CostCenterID and    [LinkedVouchers] is not null and [LinkedVouchers]<>'' 
						set @DUPLICATECODE=@DUPLICATECODE+' and costcenterid in('+convert(nvarchar,@CaseID)+@WHERE+')'
					END
					
					set @WHERE=''
					select @WHERE=@WHERE+','+convert(nvarchar,[CostCenterIDBase])
					FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
					join com_documentpreferences b WITH(NOLOCK) on a.[CostCenterIDBase]=b.CostCenterID
					where [CostCenterIDLinked]=@CostCenterID and b.prefname='DisableQtyCheck' and prefvalue='true'
					
					if(@WHERE<>'')
					BEGIN						
						set @DUPLICATECODE=@DUPLICATECODE+' and costcenterid not in('+Substring(@WHERE,2,len(@WHERE))+')'
					END
					
					set @WHERE=''
					select @WHERE=@WHERE+','+convert(nvarchar,[CostCenterIDBase])
					FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
					join com_documentpreferences b WITH(NOLOCK) on a.[CostCenterIDBase]=b.CostCenterID
					where [CostCenterIDLinked]=@CostCenterID and b.prefname='Enabletolerance' and prefvalue='true'
					
					if(@WHERE<>'')
					BEGIN												
						SELECT @tolPer=isnull(p.MaxTolerancePer,0),@tolVal=isnull(p.MaxToleranceVal,0)   
						from dbo.INV_Product p WITH(NOLOCK) 
						WHERE  p.ProductID=@ProductID
						
						if(@tolPer>0)
							set @QtyFin=@QtyFin+ ((@QtyFin*@tolPer)/100)
						else if(@tolVal>0)
							set @QtyFin=@QtyFin+ @tolVal
						
					END
										
					print @DUPLICATECODE
					exec sp_executesql @DUPLICATECODE,N'@TotLinkedQty float OUTPUT',@TotLinkedQty OUTPUT		  		
					
					if(@TotLinkedQty>0 and (@QtyFin-@TotLinkedQty)<-0.001)
					BEGIN  
						if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
							select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID
						ELSE
							select @ProductName=ProductName from Inv_product with(NOLOCK) 
							where ProductID=@ProductID

						RAISERROR('-509',16,1)      
					END

					set @QtyFin=0
					set @TotLinkedQty=0
					select @QtyFin=X.value('@Gross','float')  from @TRANSXML.nodes('/Transactions') as Data(X)   


					set @DUPLICATECODE='select @TotLinkedQty=isnull(SUM(LinkedFieldValue),0) from [INV_DocDetails] WITH(NoLock)
					where LinkedInvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)+' and LinkedFieldName=''Gross'''
					
					if exists (select Value from @TblPref where IsGlobal=0 and  Name='AllowMultipleLinking' and Value='true')
					BEGIN
						set @WHERE=''
						select @WHERE=@WHERE+','+[LinkedVouchers],@CaseID=[CostCenterIDBase]    FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
						where [CostCenterIDLinked]=@CostCenterID and    [LinkedVouchers] is not null and [LinkedVouchers]<>'' 
						set @DUPLICATECODE=@DUPLICATECODE+' and costcenterid in('+convert(nvarchar,@CaseID)+@WHERE+')'
					END
					
					set @WHERE=''
					select @WHERE=@WHERE+','+convert(nvarchar,[CostCenterIDBase])
					FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
					join com_documentpreferences b WITH(NOLOCK) on a.[CostCenterIDBase]=b.CostCenterID
					where [CostCenterIDLinked]=@CostCenterID and b.prefname='DisableQtyCheck' and prefvalue='true'
					
					if(@WHERE<>'')
					BEGIN						
						set @DUPLICATECODE=@DUPLICATECODE+' and costcenterid not in('+Substring(@WHERE,2,len(@WHERE))+')'
					END
										
					print @DUPLICATECODE
					exec sp_executesql @DUPLICATECODE,N'@TotLinkedQty float OUTPUT',@TotLinkedQty OUTPUT		  		
					
				    if(@TotLinkedQty>0 and @QtyFin>0 and  @QtyFin<@TotLinkedQty)
					BEGIN  
						if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
							select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=(Select X.value('@ProductID','INT') from @TRANSXML.nodes('/Transactions') as Data(X) ) 
						ELSE
							select @ProductName=ProductName from Inv_product with(NOLOCK) 
							where ProductID=(Select X.value('@ProductID','INT') from @TRANSXML.nodes('/Transactions') as Data(X) ) 

						RAISERROR('-510',16,1)      
					END
				END

				UPDATE [INV_DocDetails]      
				SET    AccDocDetailsID=X.value('@AccDocDetailsID','INT')      
				,VersionNo=@VersionNo    
				,VoucherNo=@VoucherNo  
				,DocDate= CONVERT(FLOAT,@DocDate)               
				,DueDate=  case when  X.value('@DueDate','Datetime') is not null THEN CONVERT(float, X.value('@DueDate','Datetime')) else   CONVERT(FLOAT,@DueDate)       end          
				,StatusID= @StatusID        
				,ActDocDate=@ActDocDate
				,BillNo=Case WHEN  X.value('@BillNo','NVarChar(500)') is not null THEN X.value('@BillNo','NVarChar(500)') ELSE @BillNo  END        
				,BillDate=CONVERT(FLOAT,X.value('@BillDate','datetime'))      
				,LinkedInvDocDetailsID= X.value('@LinkedInvDocDetailsID','INT')      
				,LinkedFieldName=X.value('@LinkedFieldName','nvarchar(200)')      
				,LinkedFieldValue= X.value('@LinkedFieldValue','float')      
				,CommonNarration= X.value('@CommonNarration','nvarchar(max)')      
				,LineNarration= X.value('@LineNarration','nvarchar(max)')      
				,DebitAccount=ISNULL( X.value('@DebitAccount','INT'),1)      
				,CreditAccount= ISNULL(X.value('@CreditAccount','INT'),1)      
				,DocSeqNo= X.value('@DocSeqNo','int')      
				,ProductID= X.value('@ProductID','INT')      
				,Quantity= X.value('@Quantity','float')      
				,Unit= X.value('@Unit','INT')      
				,HoldQuantity=ISNULL( X.value('@HoldQuantity','float'),0)      
				,ReserveQuantity=ISNULL( X.value('@ReserveQuantity','float'),0)              
				,IsQtyIgnored= ISNULL(X.value('@IsQtyIgnored','bit'),0)      
				,IsQtyFreeOffer= ISNULL(X.value('@IsQtyFreeOffer','INT'),0)      
				,Rate= X.value('@Rate',' float')      
				,AverageRate= ISNULL(X.value('@AverageRate','float'),0)      
				,Gross= (X.value('@Gross',' float') * ISNULL(X.value('@ExchangeRate','float'),1) )     
				,GrossFC=   X.value('@Gross',' float')     
				,StockValue= ISNULL(X.value('@StockValue','float'),0)      
				,CurrencyID=ISNULL(X.value('@CurrencyID','int'),1)      
				,ExchangeRate= ISNULL(X.value('@ExchangeRate','float'),1)      
				,StockValueFC=ISNULL(X.value('@StockValueFC','float'),ISNULL(X.value('@StockValue','float'),0))    	
				,DocOrder =ISNULL(X.value('@DocOrder','float'),@DocOrder)			
				,ModifiedBy= @UserName      
				,ModifiedDate= @Dt      
				,UOMConversion  = X.value('@UOMConversion','float')       
				,UOMConvertedQty =X.value('@UOMConvertedQty','float')             
				,WorkflowID=@WID    
				,WorkFlowStatus =@StatusID    
				,WorkFlowLevel=@level    
				,RefCCID=@RefCCID,RefNodeid=@RefNodeid 
				,vouchertype= case when @DocumentType in (5,30,54) then X.value('@VoucherType','int') 
								   when @DocumentType=38 and X.value('@VoucherType','int') is not null then 1 else  @VoucherType end 
				,ParentSchemeID= X.value('@ParentSchemeID','nvarchar(500)')
				,RefNO= X.value('@RefNO','nvarchar(200)')
				,[BatchID]=1
				,BatchHold =NULL
				,ReleaseQuantity =0
				,RefInvDocDetailsID=NULL				
				,CanRecur=X.value('@CanRecur','BIT')
				,Net=X.value('@Net','FLOAT')
				,Account1=case when @DocumentType in(1,39,27,26,25,2,34,6,3,4,13,41,42) then @ACCOUNT2 else @ACCOUNT1 end
				,AP=@AP
				from @TRANSXML.nodes('/Transactions') as Data(X)      
				WHERE InvDocDetailsID=@InvDocDetailsID      


			END      
	
	  set @DUPLICATECODE=''
      SELECT @DUPLICATECODE=X.value('@Query',' nvarchar(max)')
      from @NUMXML.nodes('/Numeric') as Data(X)              
	  if(@DUPLICATECODE<>'')
	  BEGIN
			set @DUPLICATECODE= rtrim(@DUPLICATECODE)
			set @DUPLICATECODE=substring(@DUPLICATECODE,0,len(@DUPLICATECODE)- charindex(',',reverse(@DUPLICATECODE))+1)
			if(@CostCenterID=40054)
				set @DUPLICATECODE='Update [PAY_DocNumData] set '+@DUPLICATECODE+'   where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			ELSE
				set @DUPLICATECODE='Update [COM_DocNumData] set '+@DUPLICATECODE+'   where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			print @DUPLICATECODE
			exec(@DUPLICATECODE)
	  END	

	  IF(@TSQL IS NOT NULL AND LEN(@TSQL)>0)
		EXEC(@TSQL)

	  set @DUPLICATECODE=''
      SELECT @DUPLICATECODE=X.value('@Query',' nvarchar(max)')
      from @TEXTXML.nodes('/Alpha') as Data(X)              
	  if(@DUPLICATECODE<>'')
	  BEGIN
			set @DUPLICATECODE= rtrim(@DUPLICATECODE)
			set @DUPLICATECODE=substring(@DUPLICATECODE,0,len(@DUPLICATECODE)- charindex(',',reverse(@DUPLICATECODE))+1)
			set @DUPLICATECODE=replace(@DUPLICATECODE,'@~','
')      
			set @DUPLICATECODE='Update [COM_DocTextData] set '+@DUPLICATECODE+'   where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			--print @DUPLICATECODE
			exec(@DUPLICATECODE)
	  END	
	  
	  if(@IsImport=1 and @ImpDocID is not null and @bxml<>'')
	  BEGIN
			set @DUPLICATECODE='Update [COM_DocTextData] set dcalpha1='''+@bxml+'''   where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)			
			exec(@DUPLICATECODE)
	  END
	  
	  
	  if(@IsImport=0 and @batchCol<>'')
	  BEGIN
		set @RefBatchID=0
		set @DUPLICATECODE='select @RefBatchID='+@batchCol+' from COM_DocTextData WITH(NOLOCK)
			where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)+' and isnumeric('+@batchCol+')=1 '
			
			EXEC sp_executesql @DUPLICATECODE, N'@RefBatchID INT OUTPUT',@RefBatchID OUTPUT 
			
			if((@RefBatchID is null or @RefBatchID=0) and @IsQtyIgnored=0 and @ProductType=5)
			BEGIN
				SET @XML=@ActivityXML
				SELECT @PrefValueDoc=isnull(X.value('@IgnoreBatches','INT'),0)
				from @XML.nodes('/XML') as Data(X)    
			
				if(@PrefValueDoc<>1)
				BEGIN				
					set @PrefValueDoc=0
					select @PrefValueDoc=isnull(X.value('@IgnoreBatches','INT'),0),@QtyFin=X.value('@Quantity','float')  
					from @TRANSXML.nodes('/Transactions') as Data(X)  
					if(@PrefValueDoc<>1 and @QtyFin>0)
					BEGIN 
						RAISERROR('-561',16,1)    	
					END
				END
			END	
	   END	
	   
	  Update [COM_DocNumData] 
	  set Remarks=X.query('XML')
	  from @NUMXML.nodes('/Numeric') as Data(X)      
      WHERE InvDocDetailsID=@InvDocDetailsID
     
      
	  set @DUPLICATECODE=''
      SELECT @DUPLICATECODE=X.value('@Query',' nvarchar(max)')
      from @CCXML.nodes('/CostCenters') as Data(X)              
	  if(@DUPLICATECODE<>'')
	  BEGIN
			set @DUPLICATECODE= rtrim(@DUPLICATECODE)
			set @DUPLICATECODE=substring(@DUPLICATECODE,0,len(@DUPLICATECODE)- charindex(',',reverse(@DUPLICATECODE))+1)

			set @DUPLICATECODE='Update [COM_DocCCData] set '+@DUPLICATECODE+' where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			exec(@DUPLICATECODE)
	  END
	  
	  
	  IF(@UNIQUECNT>0)      
	  BEGIN  
		SET  @iUNIQ = 0 
		SET @cctablename = 'COM_DOCTEXTDATA'
		WHILE (@iUNIQ < @UNIQUECNT )    
		BEGIN     
			SET @iUNIQ = @iUNIQ + 1     
			SELECT @SYSCOL = SYSCOLUMNNAME  ,@TYPE = USERCOLUMNNAME  , @SECTIONID = SECTIONID  FROM @TEMPUNIQUE WHERE ID =  @iUNIQ     
	        
	        set @DUPNODENO=''
			IF(@SYSCOL LIKE '%dcAlpha%')    
			BEGIN    
				SET @tempCode='@DUPNODENO nvarchar(max) OUTPUT '     
				SET @DUPLICATECODE  = 'SELECT   @DUPNODENO ='+@SYSCOL +'     
				from COM_DOCTEXTDATA WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)     
				EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT 
			END     
			ELSE    			    
				 continue;  			
	          
			--sectionid = 3 for linewise    
			if(@DUPNODENO is not null and @DUPNODENO<>'')
			BEGIN     
				SET @tempCode ='@QUERYTEST  NVARCHAR(100) OUTPUT'    
				SET @DUPLICATECODE =  ' IF EXISTS (SELECT DOCEXT.INVDOCDETAILSID    FROM '+ @cctablename +' DOCEXT with(nolock)
				JOIN INV_DOCDETAILS INV with(nolock) ON DOCEXT.INVDOCDETAILSID=INV.INVDOCDETAILSID WHERE INV.StatusID<>376 AND  '
				IF(@SECTIONID = 3)
					set @DUPLICATECODE = @DUPLICATECODE+' INV.INVDOCDETAILSID <> '+ CONVERT(NVARCHAR(50),@InvDocDetailsID) +' AND '
				else
					set @DUPLICATECODE = @DUPLICATECODE+' INV.DOCID <> '+ CONVERT(NVARCHAR(50),@DocID) +' AND '

				SET @DUPLICATECODE = @DUPLICATECODE+ '    
				INV.COSTCENTERID =  '+ CONVERT(NVARCHAR(50), @CostCenterID) +' and '+ @SYSCOL+' = '''+ @DUPNODENO +''')     
				BEGIN     
				SET @QUERYTEST = (SELECT  TOP 1 INV.VOUCHERNO FROM '+ @cctablename +' DOCEXT with(nolock)
				JOIN INV_DOCDETAILS INV with(nolock) ON DOCEXT.INVDOCDETAILSID = INV.INVDOCDETAILSID WHERE  '
				IF(@SECTIONID = 3)
					set @DUPLICATECODE = @DUPLICATECODE+' INV.INVDOCDETAILSID <> '+ CONVERT(NVARCHAR(50),@InvDocDetailsID) +' AND '
				else
					set @DUPLICATECODE = @DUPLICATECODE+' INV.DOCID <> '+ CONVERT(NVARCHAR(50),@DocID) +' AND '

				SET @DUPLICATECODE = @DUPLICATECODE+ '  INV.COSTCENTERID =  '+     
				CONVERT(NVARCHAR(50), @CostCenterID) +' and '+ @SYSCOL+' = '''+ @DUPNODENO +''')         
				END  '    
		         
			   EXEC sp_executesql @DUPLICATECODE ,@tempCode ,@QUERYTEST OUTPUT    
		          
				IF(@QUERYTEST IS NOT NULL)    
				BEGIN    
					IF(@SECTIONID = 3)    
						RAISERROR('-346',16,1)    
					ELSE    
						RAISERROR('-347',16,1)     
				END
			END	       
		END     		
	END
	  
		if(@LineWiseApproval=1 and (@AppRejDate is not null or @WID<>0) and @TEmpWid<>-1 and @level is not null)
		begin
			INSERT INTO COM_Approvals    
			(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)      
			VALUES(@COSTCENTERID,@DOCID,@StatusID,CONVERT(FLOAT,@AppRejDate),@Remarks,@UserID,@CompanyGUID    
			,newid(),@UserName,@Dt,@level,@InvDocDetailsID)
			
			--EXEC spCOM_SetNotifEvent @StatusID,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
			
			if(@AppRejDate is not null and @WID>0 and @StatusID=369)
			BEGIN
				select @CaseNumber=isnull(SysColumnName,'') from ADM_CostCenterDef WITH(NOLOCK)
				where CostCenterID=@CostCenterID and LocalReference=79 and LinkData=55499
				if(@CaseNumber is not null and @CaseNumber like 'dcalpha%')
				BEGIN
					set @SQL='update [COM_DocTextData]
					set '+@CaseNumber+'='''+CONVERT(nvarchar,@AppRejDate)+'''
					where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
					exec(@SQL)
				END
			END
		end
	  
	  set @WHERE=''
	  select @WHERE=isnull(X.value('@LinkedFieldWhere','nvarchar(max)'),''),@QthChld=X.value('@LinkedFieldValue','float')  
	  from @TRANSXML.nodes('/Transactions') as Data(X)      
	  
	  if(@WHERE<>'')
	  BEGIN
			set @DUPLICATECODE='SELECT @QtyFin=isnull(sum(UOMConvertedQty),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND IsQtyIgnored=0 and VoucherType='+convert(nvarchar,@VoucherType)+@WHERE
			
			EXEC sp_executesql @DUPLICATECODE, N'@QtyFin float OUTPUT', @QtyFin OUTPUT   
			
			if(@QtyFin>@QthChld and abs(@QtyFin-@QthChld)>0.001)
			BEGIN
				RAISERROR('-532',16,1)
			END
	  END	
	  
	  
		select @WHERE=isnull(X.value('@BudQtyWhere','nvarchar(max)'),''),@CaseID=X.value('@BudID','INT'),@AccLockDate=X.value('@BudStartDate','Datetime')
		from @TRANSXML.nodes('/Transactions') as Data(X)    		         
		
		select @PrefValue=Value from @TblPref where IsGlobal=1 and Name='GBudgetUnapprove'

		if(@WHERE<>'')
		BEGIN
			exec @return_value=[spDOC_ValidateBudget]
						@Where=@WHERE,
						@DocDate=@DocDate,
						@BudStartDate=@AccLockDate,
						@BudgetID=@CaseID,						
						@dtype=@DocumentType,
						@seq=@i,
						@saveUnapp=@PrefValue,
						@UserName=@UserName,
						@LangID=@LangID
			
			if(@PrefValue='true' and @return_value=2)
			BEGIN
				set @StatusID=371
				
				update T set StatusID=371
				FROM INV_DocDetails T WITH(NOLOCK)
				where T.DocID=@DocID and T.CostCenterID=@CostCenterID		
			END	
		END
		
		set @WHERE=''
		select @WHERE=isnull(X.value('@ValueBudWhere','nvarchar(max)'),''),@CaseID=X.value('@ValueBudID','INT'),@AccLockDate=X.value('@ValueBudStartDate','Datetime')
		from @TRANSXML.nodes('/Transactions') as Data(X)    		         

		if(@WHERE<>'')
		BEGIN
			exec @return_value=[spDOC_ValidateBudget]
						@Where=@WHERE,
						@DocDate=@DocDate,
						@BudStartDate=@AccLockDate,
						@BudgetID=@CaseID,						
						@dtype=@DocumentType,
						@seq=@i,
						@saveUnapp=@PrefValue,
						@UserName=@UserName,
						@LangID=@LangID
						
			if(@PrefValue='true' and @return_value=2)
			BEGIN
				set @StatusID=371
				
				update T set T.StatusID=371
				FROM INV_DocDetails T WITH(NOLOCK)
				where T.DocID=@DocID and T.CostCenterID=@CostCenterID				
			END	
		END		
	    
	    if exists(select Value from @TblPref where IsGlobal=1 and  Name='UseDimWiseLock' and Value ='true')
		BEGIN
			set @WHERE=''
			set @DUPLICATECODE=''
			select @WHERE=isnull(X.value('@LockDims','nvarchar(max)'),''),@DUPLICATECODE=isnull(X.value('@LockDimsjoin','nvarchar(max)'),'')
			from @TRANSXML.nodes('/Transactions') as Data(X)    		         
			if(@WHERE<>'')
			BEGIN
				set @SQL=' if exists(select FromDate from ADM_DimensionWiseLockData c WITH(NOLOCK) '+@DUPLICATECODE+'
				where '+convert(nvarchar,CONVERT(float,@DocDate))+' between FromDate and ToDate and c.isEnable=1 '+@WHERE
				+') RAISERROR(''-571'',16,1) '
				exec(@SQL)
			END
		END
		
	  
	  if(@DocumentType in(8,13) and @RefCCID=300 and @RefNodeid>0)
	  BEGIN
		update [INV_DocDetails]
		set LinkedInvDocDetailsID=t.id,RefNo=t.vno
		from 
		(select InvDocDetailsID as id,VoucherNo vno from [INV_DocDetails]  with(nolock)
		where DocSeqNo=(select X.value('@ParentSeqNo','nvarchar(500)')			
		from @TRANSXML.nodes('/Transactions') as Data(X)) and DocID=@RefNodeid) as t
		where InvDocDetailsID=@InvDocDetailsID
	  END
	
	 
	set @PrefValue =null
	select @PrefValue=Value from @TblPref where IsGlobal=1 and Name='Check for -Ve Stock'    
	
	if(@PrefValue is not null and @PrefValue='true' and @VoucherType=-1 
		and @tempProd<>@ProductID and @productType not in(6,8))
	BEGIN
		
		if(@IsQtyIgnored=0 or (@IsQtyIgnored=1 and exists(select ISNULL( X.value('@HoldQuantity','float'),0)  from @TRANSXML.nodes('/Transactions') as Data(X)
		where ISNULL( X.value('@HoldQuantity','float'),0)>0 or ISNULL( X.value('@ReserveQuantity','float'),0)>0 )
		and exists(select Value from @TblPref where IsGlobal=1 and Name='ConsiderHoldAndReserveAsIssued' and value='true')
		and not exists(select Value from @TblPref where IsGlobal=1 and Name='SkipNegonReserve' and value='true')))
		BEGIN
		
			set @WHERE=''
			if(@loc=1)
			BEGIN				
				set @sql='select @NID=dcCCNID2 from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
									
				set @WHERE =@WHERE+' and dcCCNID2='+CONVERT(nvarchar,@NID)        
			END

			if(@div=1)
			BEGIN
				set @sql='select @NID=dcCCNID1 from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
									
				set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@NID)        
			END
			
			if(@dim>0)
			BEGIN
				set @sql='select @NID=dcCCNID'+convert(nvarchar,@dim) +' from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
				set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,@dim)+'='+CONVERT(nvarchar,@NID)        
			END
			
			set @QtyFin=0
			set @DUPLICATECODE='set @QthChld=0 set @QtyFin=(SELECT isnull(sum(UOMConvertedQty*case when vouchertype=1 and statusid in(371,441) then 0 else  VoucherType end),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID='+convert(nvarchar,@ProductID) 
			
			set @DUPLICATECODE=@DUPLICATECODE+' and DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))
			
			set @DUPLICATECODE=@DUPLICATECODE+' and D.StatusID in(371,441,369) AND IsQtyIgnored=0 '+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
		    
		    select @PrefValue=Value from @TblPref where IsGlobal=1 and Name='ConsiderHoldAndReserveAsIssued' 
		    
		    if  @PrefValue='true'
			BEGIN
				set @DLockCCValues =''
				select @DLockCCValues=Value from @TblPref where IsGlobal=1 and Name='HoldResCancelledDocs'    
				

				set @DUPLICATECODE=@DUPLICATECODE+'set @QthChld=(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when ((LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0)'
				 
				 if(@DLockCCValues<>'')
					set @DUPLICATECODE=@DUPLICATECODE+' or l.Costcenterid in('+@DLockCCValues+')'
					
				 set @DUPLICATECODE=@DUPLICATECODE+') then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID'
				 
				 if exists(select Value from @TblPref where IsGlobal=1 and Name='ConsiderUnAppInHold' and Value ='true')				 
					set @DUPLICATECODE=@DUPLICATECODE+' in(371,441,369) '
				else	
					set @DUPLICATECODE=@DUPLICATECODE+'=369 '
				 
				 set @DUPLICATECODE=@DUPLICATECODE+' and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1'
				 
				 if exists(select Value from @TblPref where IsGlobal=1 and Name='NegatvieSotckSysDate' and value='FALSE')			
					set @DUPLICATECODE=@DUPLICATECODE+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				  
				 set @DUPLICATECODE=@DUPLICATECODE+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
				
				 set @DUPLICATECODE=@DUPLICATECODE+'set @QthChld=@QthChld+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when ((LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0) '
				 
				 if(@DLockCCValues<>'')
					set @DUPLICATECODE=@DUPLICATECODE+' or l.Costcenterid in('+@DLockCCValues+')'
					
				 set @DUPLICATECODE=@DUPLICATECODE+') then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID'
				 
				 if exists(select Value from @TblPref where IsGlobal=1 and Name='ConsiderUnAppInHold' and Value ='true')				 
					set @DUPLICATECODE=@DUPLICATECODE+' in(371,441,369) '
				else	
					set @DUPLICATECODE=@DUPLICATECODE+'=369 '
				 
				 set @DUPLICATECODE=@DUPLICATECODE+'  and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1'
				 
				set @DUPLICATECODE=@DUPLICATECODE+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				 set @DUPLICATECODE=@DUPLICATECODE+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
				
				set @DUPLICATECODE=@DUPLICATECODE+'set @QtyFin=@QtyFin-@QthChld'
			 END
			
			 select @temp=Value from @TblPref where IsGlobal=1 and Name='ConsiderExpectedAsReceived' 
		  
		    if @temp='true'			
			BEGIN			 
				 set @DUPLICATECODE=@DUPLICATECODE+'set @QtyFin=@QtyFin+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when ((LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0)'
				 
				 if(@DLockCCValues<>'')
					set @DUPLICATECODE=@DUPLICATECODE+' or l.Costcenterid in('+@DLockCCValues+')'
					
				 set @DUPLICATECODE=@DUPLICATECODE+') then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1'
				 
				set @DUPLICATECODE=@DUPLICATECODE+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				  
				 set @DUPLICATECODE=@DUPLICATECODE+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
			END
			 
	    print @DUPLICATECODE
			EXEC sp_executesql @DUPLICATECODE, N'@QtyFin float OUTPUT,@QthChld float OUTPUT', @QtyFin OUTPUT ,@QthChld OUTPUT  
			if(@QtyFin<-0.001)
			BEGIN
				set @PrefValueDoc=1
				if(@IsQtyIgnored=0 and exists(select Value from @TblPref where IsGlobal=1 and Name='SkipNegonReserve' and value='true'))
				BEGIN
					set @QtyFin=@QtyFin+@QthChld
					if not (@QtyFin<-0.001) and @LinkedID>0
						set @PrefValueDoc=0
				END
				
				if(@PrefValueDoc=1)
				BEGIN
					if exists(select Value from @TblPref where IsGlobal=1 and Name='GNegativeUnapprove' and Value='true')
					BEGIN
						set @StatusID=371
						
						UPDATE T set T.StatusID=371
						FROM INV_DocDetails T WITH(NOLOCK)
						where T.DocID=@DocID and T.CostCenterID=@CostCenterID
					END	
					ELSE
					BEGIN	
						if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
							select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
						ELSE
							SELECT @ProductName=ProductName FROM INV_Product a WITH(NOLOCK)    
							WHERE  ProductID=@ProductID     
						RAISERROR('-407',16,1)
					END	
				END	
			END
			ELSE
			BEGIN	
			 if exists(select Value from @TblPref where IsGlobal=1 and Name='ConsiderUnAppInHold' and Value ='true')				 				
				Exec @return_value =[spDOC_ValidateStock]	@ProductID,@DocDate,@QtyFin,@WHERE,@PrefValue,@temp,1,@UserName,@LangID
			else
				Exec @return_value =[spDOC_ValidateStock]	@ProductID,@DocDate,@QtyFin,@WHERE,@PrefValue,@temp,0,@UserName,@LangID
			END	
		END			
	END
	
	
	select @PrefValue=Value from @TblPref where IsGlobal=1 and Name='DontSaveReOrderLevelExceeds'    
	
	if(@PrefValue is not null and @PrefValue='true' and @VoucherType=-1 and @IsQtyIgnored=0
		and @tempProd<>@ProductID and @productType not in(6,8))
	BEGIN
		select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='DonotupdateInventory'    
		if(@PrefValue is not null and @PrefValue='false')
		BEGIN
			if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
				select @QtyFin=ReorderLevel,@ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
			ELSE
				SELECT @QtyFin=ReorderLevel,@ProductName=ProductName FROM INV_Product a WITH(NOLOCK)    
				WHERE  ProductID=@ProductID     
			
			set @QthChld=(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			WHERE D.ProductID=@ProductID and DocDate<=convert(float,@DocDate) AND IsQtyIgnored=0 and (VoucherType=1 or VoucherType=-1) )        
		    
			if(@QtyFin>@QthChld)
			BEGIN
				RAISERROR('-511',16,1)
			END
		END			
	END
		
      
	if(@LinkedID is not null and @LinkedID>0)    
	begin    
		
		if exists(select Value from @TblPref where IsGlobal=0 and  Name='UpdateDueDate' and Value='True')
		begin    
			update T set T.DueDate=CONVERT(FLOAT,@DueDate)   
			FROM INV_DocDetails T WITH(NOLOCK) 
			where T.InvDocDetailsID=@LinkedID        
		end   
		
		if exists(select Value from @TblPref where IsGlobal=0 and  Name='BackTrack' and Value='True')
		begin  
			SELECT @QtyFin=sum(Quantity) FROM INV_DocDetails a WITH(NOLOCK)    
			WHERE  LinkedInvDocDetailsID=@LinkedID and Costcenterid=@CostCenterID
			
			set @PrefValue=''			
			select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='backTrackDocs'
			if(@PrefValue<>'')
				exec [spDoc_BackTrackDocs] @InvDocDetailsID,@LinkedID,@PrefValue,@QtyFin,@UserID,@LangID
			ELSE	
			BEGIN
				update INV_DocDetails    
				set LinkedFieldValue=Quantity-@QtyFin
				where InvDocDetailsID=@LinkedID   
				
				delete from INV_DocExtraDetails where InvDocDetailsID=@LinkedID and [RefID]=@InvDocDetailsID and [Type]=10
				insert into INV_DocExtraDetails(InvDocDetailsID,[RefID],[Type],[Quantity])values(@LinkedID,@InvDocDetailsID,10,@QtyFin)
				 
				select @CaseID=LinkedInvDocDetailsID,@ddID=Costcenterid from INV_DocDetails WITH(NOLOCK)			    			
				where InvDocDetailsID=@LinkedID
				
				select @BatchID=Costcenterid,@SECTIONID=LinkStatusID from INV_DocDetails WITH(NOLOCK)
				where InvDocDetailsID=@CaseID 
				
				if (@SECTIONID is not null and @SECTIONID=445)
				BEGIN
					
					set @PrefValue=''	
					set @DocLoc=0
					select @DocLoc=SrcDoc,@PrefValue=Fld from COM_DocLinkCloseDetails WITH(NOLOCK)
					where CostCenterID=@ddID and linkedfrom=@BatchID
					if(@DocLoc is not null and @DocLoc>0 and @PrefValue<>'')
					BEGIN
						set @SQL='SELECT @Val='+@PrefValue+' from COM_DocTextData WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@CaseID)				
						exec sp_executesql @SQL,N'@Val nvarchar(max) output',@Val output
						
						set @SQL='update INV_DocDetails
						set LinkStatusID=369
						from COM_DocTextData b WITH(NOLOCK) 					
						where INV_DocDetails.InvDocDetailsID=b.InvDocDetailsID and INV_DocDetails.CostCenterID<>'+convert(nvarchar,@ddID)+'
						 and '+@PrefValue+'='''+@Val+''''
						
						EXEC(@SQL)
					END
					ELSE
						update INV_DocDetails
						set LinkStatusID=369
						where InvDocDetailsID=@CaseID
				END
			END	 
		end   
		
		set @QtyFin=0
		select @QtyFin=isnull(sum(Quantity),0) from INV_DocExtraDetails WITH(NOLOCK) where type=10 and InvDocDetailsID=@InvDocDetailsID		
		if(@QtyFin>0)
		BEGIN			
			update INV_DocDetails    
			set LinkedFieldValue=Quantity-@QtyFin
			where InvDocDetailsID=@InvDocDetailsID 
		END


		if exists(select Value from @TblPref where IsGlobal=0 and  Name='UpdateLinkQty' and Value='True')
		begin    
			SELECT @QtyFin=sum(Quantity) FROM INV_DocDetails a WITH(NOLOCK)    
			WHERE  LinkedInvDocDetailsID=@LinkedID
			
			update INV_DocDetails    
			set Quantity=@QtyFin,Gross=@QtyFin*Rate
			where InvDocDetailsID=@LinkedID        
		end    
		
		if exists(select Value from @TblPref where IsGlobal=0 and  Name='UpdateLinkValue' and Value='True')
		begin    
			update INV_DocDetails    
			set Rate=X.value('@Rate','float'),Gross=Quantity*X.value('@Rate','float')
			from @TRANSXML.nodes('/Transactions') as Data(X)        
			where InvDocDetailsID=@LinkedID        
		end    
				
		select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='UpdateJustReference'
		if((@PrefValue is not null and @PrefValue='True') or @productType=8)    
		begin    
			update T set T.LinkedFieldValue=0        
			FROM INV_DocDetails T WITH(NOLOCK)
			where T.InvDocDetailsID=@InvDocDetailsID        
		end 
		
		set @PrefValue=''
		select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='ExecReq' 
		
		if(@PrefValue ='true')
		BEGIN
			set @PrefValue=''
			select @PrefValue=SysColumnName from ADM_CostCenterDef with(nolock)
			where CostCenterID=(select CostCenterID from INV_DocDetails WITH(NOLOCK) where InvDocDetailsID=@LinkedID)
			and LocalReference=79 and LinkData=50040
			
			if(@PrefValue is not null and (@PrefValue like 'dcNum%' or @PrefValue like 'dcAlpha%')) 	
			begin 
				set @CaseID=0
				if(@PrefValue like 'dcNum%')
					set @SQL='SELECT @CaseID=isnull('+@PrefValue+',0) from COM_DocNumData WITH(NOLOCK) where InvDocDetailsID='
				else if(@PrefValue like 'dcAlpha%')
					set @SQL='SELECT @CaseID=isnull('+@PrefValue+',0) from COM_DocTextData WITH(NOLOCK) where InvDocDetailsID='
				
				set @SQL=@SQL+convert(nvarchar,@LinkedID)+' and isnumeric('+@PrefValue+')=1'
				exec sp_executesql @SQL,N'@CaseID INT output',@CaseID output
				
				if(@CaseID is not null and @CaseID>0)
				BEGIN
					SELECT @QtyFin=Quantity FROM INV_DocDetails a WITH(NOLOCK)    
					WHERE  InvDocDetailsID=@CaseID
					
					set @SQL='SELECT @QthChld=sum(isnull(Quantity,0)) FROM INV_DocDetails a WITH(NOLOCK) '
					if(@PrefValue like 'dcNum%')  
						set @SQL=@SQL+'join COM_DocNumData n with(nolock) on a.LinkedInvDocDetailsID=n.InvDocDetailsID '
					ELSE 	if(@PrefValue like 'dcAlpha%')
						set @SQL=@SQL+'join COM_DocTextData t with(nolock) on a.LinkedInvDocDetailsID=t.InvDocDetailsID '
						
					set @SQL=@SQL+' WHERE CostCenterID='+convert(nvarchar,@CostCenterID)+' and '+@PrefValue+'='''+convert(nvarchar,@CaseID)+''''  
					
					exec sp_executesql @sql,N'@QthChld float output',@QthChld output
					
					if(@QthChld>=@QtyFin)
					BEGIN
							update T set T.LinkStatusID=445 
							FROM INV_DocDetails T WITH(NOLOCK)
							where T.InvDocDetailsID=@CaseID
					END
				END	
			end 
		 END  
		
		
		EXEC @return_value =[spDOC_SetUpdateLink]
		@LinkedInvDocDetailsID =@LinkedID,    
		@InvDocDetailsID =@InvDocDetailsID,     
		@CostCenterID  =@CostCenterID,   
		@UserID =@UserID,    
		@LangID =@LangID  
					
	end   
	
		set @CaseID=0
	 select @CaseID=isnull(X.value('@MatIndentID','nvarchar(500)'),0)
	 from @TRANSXML.nodes('/Transactions') as Data(X)  
	 where X.value('@MatIndentID','nvarchar(500)') is not null and isnumeric(X.value('@MatIndentID','nvarchar(500)'))=1   
   
	 if(@CaseID is not null and @CaseID>0)    
	 begin      
		  select @PrefValue=X.value('@MatIndentIDColumn','nvarchar(500)')     
		  from @TRANSXML.nodes('/Transactions') as Data(X)  
		  
		  	if(@PrefValue like 'dcNum%')  
				set @SQL='update COM_DocNumData set '+@PrefValue+'='+CONVERT(nvarchar,@CaseID)+' where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
			ELSE 	if(@PrefValue like 'dcAlpha%')				
				set @SQL='update COM_DocTextData set '+@PrefValue+'='+CONVERT(nvarchar,@CaseID)+' where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
					
			exec(@sql)		  
    END

	select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='AssignVendors'    
	if((@PrefValue is not null and @PrefValue='True') 
	and not exists(select ProductID from INV_ProductVendors WITH(NOLOCK) where ProductID=@ProductID and AccountID=@ACCOUNT2))    
	begin    
		INSERT INTO INV_ProductVendors(ProductID,AccountID,Priority,LeadTime,
		CompanyGUID,GUID,CreatedBy,CreatedDate,MinOrderQty)
		SELECT @ProductID,@ACCOUNT2,0,0,
		@CompanyGUID,newid(),@UserName,@Dt,0
	end 
	
	
	
	 
		set @PrefValue=''
		select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='LinkForward' 
		   
		if(@PrefValue ='true' and @HistoryStatus='Update')    
		BEGIN 
				set @LinkedID=0
				select @LinkedID=[InvDocDetailsID] from [INV_DocDetails] WITH(NOLOCK) where [LinkedInvDocDetailsID]=@InvDocDetailsID    
				if(@LinkedID is not null and @LinkedID>0)
				BEGIN
					EXEC @return_value =[spDOC_SetForwardLink]
					@LinkedInvDocDetailsID =@LinkedID,    
					@InvDocDetailsID =@InvDocDetailsID,     
					@CostCenterID  =@CostCenterID,   
					@UserID =@UserID,    
					@LangID =@LangID  
				END	
		END
		
	
	if (exists(select Value from @TblPref where IsGlobal=0 and  Name='UseQtyAdjustment' and Value='true') and @QtyAdjustments is not null and CONVERT(nvarchar(max),@QtyAdjustments)<>'')
	BEGIN
		insert into COM_DocQtyAdjustments(InvDocDetailsID,Fld1,Fld2,Fld3,Fld4,Fld5,Fld6,Fld7,Fld8,Fld9,Fld10,Islinked,DocID,Fld11,Fld12,Fld13,Fld14,Fld15,Fld16,Fld17,Fld18,Fld19,Fld20,RefVoucherNo)
		select @InvDocDetailsID,X.value('@Fld1','Float'),X.value('@Fld2','Float'),X.value('@Fld3','Float')
		,X.value('@Fld4','Float'),X.value('@Fld5','Float'),X.value('@Fld6','Float'),X.value('@Fld7','Float')
		,X.value('@Fld8','Float'),X.value('@Fld9','Float'),X.value('@Fld10','nvarchar(max)'),X.value('@Islinked','BIT')
		,@DocID,X.value('@Fld11','nvarchar(max)'),X.value('@Fld12','nvarchar(max)'),X.value('@Fld13','nvarchar(max)')
		,X.value('@Fld14','nvarchar(max)'),X.value('@Fld15','nvarchar(max)'),X.value('@Fld16','nvarchar(max)'),X.value('@Fld17','nvarchar(max)')
		,X.value('@Fld18','nvarchar(max)'),X.value('@Fld19','nvarchar(max)'),X.value('@Fld20','nvarchar(max)'),X.value('@RefVoucherNo','nvarchar(200)')
		from @QtyAdjustments.nodes('/QtyAdjustments/Row') as Data(X) 

		SET @AuditTrial=0    
		SELECT @AuditTrial=CONVERT(BIT,Value) FROM @TblPref where IsGlobal=0 and  Name='AuditTrial'    
		SET @PrefValue=''    
		SELECT @PrefValue=Value FROM @TblPref where IsGlobal=0 and  Name='EnableRevision' 
    
		IF (@AuditTrial=1 or @PrefValue='true')  
		BEGIN  
				
			SET @QTYADJ=''
			SET @QTYADJSQ=''

			select @QTYADJ =@QTYADJ + 'A.' +a.name+',' from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_DocQtyAdjustments'

			SET @QTYADJSQ='INSERT INTO [COM_DocQtyAdjustmentsHISTORY]('+@QTYADJ+'[ModifiedDate])
				SELECT A.*,case when @DT is null THEN i.[ModifiedDate] else @DT end FROM COM_DocQtyAdjustments A WITH(NOLOCK)
				JOIN [INV_DocDetails] i WITH(NOLOCK) on a.[InvDocDetailsID] =i.[InvDocDetailsID]
				WHERE A.DocID='+CONVERT(VARCHAR,@DocID)+' AND A.InvDocDetailsID='+CONVERT(VARCHAR,@InvDocDetailsID)
				
				exec sp_executesql @QTYADJSQ,N'@DT float',@DT
		END
	END
	 
	
	if(@DocExtraXML is not null and CONVERT(nvarchar(max),@DocExtraXML)<>'')	
	BEGIN	
		insert into INV_DocExtraDetails(InvDocDetailsID,[Type],[RefID],[Quantity],label,
		Unit,Remarks,LabID,ReportNo,ReportDate,
		fld1,fld2,fld3,fld4,fld5,fld6,fld7,fld8,fld9,fld10)
		select @InvDocDetailsID,X.value('@Type','int'),case when X.value('@Type','int')=5 THEN @DocID else X.value('@RefID','Float') end,X.value('@Qty','Float'),X.value('@Label','Nvarchar(max)')
		,X.value('@Unit','INT'),X.value('@Remarks','NVARCHAR(max)'),X.value('@LabID','INT'),X.value('@ReportNo','NVARCHAR(max)'),ISNULL(X.value('@ReportDate','DATETIME'),NULL)
		,X.value('@Fld1','Nvarchar(max)'),X.value('@Fld2','Nvarchar(max)'),X.value('@Fld3','Nvarchar(max)'),X.value('@Fld4','Nvarchar(max)'),X.value('@Fld5','Nvarchar(max)')
		,X.value('@Fld6','Nvarchar(max)'),X.value('@Fld7','Nvarchar(max)'),X.value('@Fld8','Nvarchar(max)'),X.value('@Fld9','Nvarchar(max)'),X.value('@Fld10','Nvarchar(max)')
		from @DocExtraXML.nodes('/DocExtraXML/Row') as Data(X) 
		
		
		if(@documenttype<>5 and @IsQtyIgnored=0 and exists(select value from @TblPref where IsGlobal=0 and Name='Billlanding' and Value='true'))
		and exists(select a.VoucherNo from INV_DocDetails a with(nolock)
		join INV_DocExtraDetails b with(nolock) on a.InvDocDetailsID=b.RefID
		join INV_DocDetails c with(nolock) on c.InvDocDetailsID=b.InvDocDetailsID
		where a.InvDocDetailsID in(select X.value('@RefID','INT')
		from @DocExtraXML.nodes('/DocExtraXML/Row') as Data(X) 
		where X.value('@Type','int')=1) and b.Type=1 and c.IsQtyIgnored=0
		group by a.VoucherNo,b.RefID,a.Quantity
		having (a.Quantity+sum(b.Quantity*c.VoucherType))<-0.01)
		BEGIN
			if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
				select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
			ELSE
				select @ProductName=ProductName from INV_Product with(nolock)
				where ProductID=@ProductID
			RAISERROR('-549',16,1)   
		END	
		
		if(@DocumentType=38)
		BEGIN
			set @CaseID=0
			select @CaseID=value from @TblPref where IsGlobal=1 and Name='LoyaltyOn' and isnumeric(value)=1
			and convert(int,value)>50000
			
			if(@CaseID is not null and @CaseID>0)
			BEGIN
				set @sql='select @NID=dcCCNID'+convert(nvarchar,(@CaseID-50000)) +' from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
								
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
						
				-------- FOR OPENING POINTS
				declare @tablename nvarchar(200),@opfield nvarchar(50),@OpPoints float
				set @opfield=''
				select @opfield=Value from Adm_globalPreferences WITH(NOLOCK)
				where Name='LoyaltyOpening' and value is not null and value<>''

				set @OpPoints=0
				if(@opfield<>'')
				BEGIN
				select @tablename=TableName from ADM_Features where FeatureID=@CaseID
				set @SQL='select @OpPoints=convert(float,'+@opfield+') from '+@tablename+' WITH(NOLOCK)
				where NodeID='+convert(nvarchar,@NID)+' and '+@opfield+' is not null and isnumeric('+@opfield+')=1'
				exec sp_executesql  @SQL,N'@OpPoints Float OUTPUT',@OpPoints output
				END
				--------- 

				select @QtyFin=isnull(sum(Quantity),0) from INV_DocExtraDetails with(nolock)
				where Type=5 and fld1 is not null and ISNUMERIC(Fld1)=1 and CONVERT(INT,fld1)=@NID
				if(@OpPoints+@QtyFin<-0.001)
					RAISERROR('-554',16,1) 
			
			END
			ELSE
			BEGIN
				select @QtyFin=isnull(sum(Quantity),0) from INV_DocExtraDetails with(nolock)
				where Type=5 and fld1 is not null and ISNUMERIC(Fld1)=1 and CONVERT(INT,fld1)=@ACCOUNT1
				if(@QtyFin<-0.001)
					RAISERROR('-554',16,1) 
			END		
		END
	END
	
	if(@BinsXML is not null and CONVERT(nvarchar(max),@BinsXML)<>'')
	BEGIN
		set @CaseID=0
		if exists(select ProductID from INV_Product with(nolock)
				where ProductID=@ProductID and IsBillOfEntry in(1,2))
		BEGIN
			select @CaseID=RefID from INV_DocExtraDetails with(nolock)
			where InvDocDetailsID=@InvDocDetailsID and Type IN(1,11)
			
			if(@VoucherType=1 and @IsQtyIgnored=0 and (@CaseID is null or @CaseID=0))
				set @CaseID=@InvDocDetailsID
		END
		
		if exists(select * from @TblPref where Name in('BOEInv','BinvInv') and Value='true' and IsGlobal=0)
		BEGIN			
			insert into INV_BinDetails(InvDocDetailsID,BinID,Quantity,Remarks,RefInvDocDetailsID,VoucherType,IsQtyIgnored,boe)
			select @InvDocDetailsID,X.value('@NodeID','INT'),X.value('@Allocate','Float'),X.value('@Remarks','Nvarchar(max)'),X.value('@RefID','Nvarchar(max)'),@VoucherType,0,@CaseID
			from @BinsXML.nodes('/BinsXML/Row') as Data(X)
		END
		ELSE
		BEGIN
			insert into INV_BinDetails(InvDocDetailsID,BinID,Quantity,Remarks,RefInvDocDetailsID,VoucherType,IsQtyIgnored,boe)
			select @InvDocDetailsID,X.value('@NodeID','INT'),X.value('@Allocate','Float'),X.value('@Remarks','Nvarchar(max)'),X.value('@RefID','Nvarchar(max)'),@VoucherType,@IsQtyIgnored,@CaseID
			from @BinsXML.nodes('/BinsXML/Row') as Data(X)
		END
		
		if(@VoucherType=1 and @IsQtyIgnored=0)
		BEGIN
			  if (exists (select value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
			 and  name='MultipleProductinSameBin'  and value='true')
			  and exists (select value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
			 and  name='ProductWiseBins'  and value='false'))
			  BEGIN
				set @BinDimesionNodeID=0
				select @BinDimesionNodeID=bn.BinID,@BinDimesion=a.ProductID from INV_BinDetails bn with(nolock) 
				join  INV_DocDetails a with(nolock) on bn.InvDocDetailsID=a.InvDocDetailsID				
				where bn.IsQtyIgnored=0 and a.ProductID<>@ProductID and bn.BinID in(select X.value('@NodeID','INT') from @BinsXML.nodes('/BinsXML/Row') as Data(X) where X.value('@NodeID','INT')>1)
				group by bn.BinID,a.ProductID
				having isnull(sum(bn.Quantity*bn.VoucherType),0)>0
				if(@BinDimesionNodeID>0)
				BEGIN
					select @ProductName=ProductName from INV_Product with(nolock) where ProductID=@BinDimesion
					
					set @PrefValue=''
					select @PrefValue=value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
					and  name='BinsDimension'  
					set @BinDimesion=0 
					if(@PrefValue<>'')
					begin    		
						begin try    
							select @BinDimesion=convert(INT,@PrefValue)    
						end try    
						begin catch    
							set @BinDimesion=0    
						end catch 		
					END 
					
					select @PrefValue=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@BinDimesion 
					set @SQL='select @tempCode=name from '+@PrefValue+' with(NOLOCK) where nodeid='+CONVERT(nvarchar,@BinDimesionNodeID)
					EXEC sp_executesql @SQL,N'@tempCode nvarchar(200) OUTPUT',@tempCode output		 
					
					
					
					RAISERROR('-539',16,1)  
				END
			  END
				
			 if (exists (select value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
			 and  name='DonotExceedCapacity'  and value='true')
			  and exists (select value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
			 and  name='ProductWiseBins'  and value='true'))
			 BEGIN
				set @BinDimesionNodeID=0
				select @BinDimesionNodeID=b.BinNodeID from INV_BinDetails bn with(nolock) 
				join  INV_DocDetails a with(nolock) on bn.InvDocDetailsID=a.InvDocDetailsID
				join  INV_ProductBins b with(nolock) on bn.BinID=b.BinNodeID
				where bn.IsQtyIgnored=0 and a.ProductID=@ProductID and b.NodeID=@ProductID and b.BinNodeID in(select X.value('@NodeID','INT') from @BinsXML.nodes('/BinsXML/Row') as Data(X) where X.value('@NodeID','INT')>1)
				group by b.BinNodeID,capacity
				having isnull(sum(bn.Quantity*bn.VoucherType),0)>capacity 
				if(@BinDimesionNodeID>0)
				BEGIN
					set @PrefValue=''
					select @PrefValue=value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
					and  name='BinsDimension'  
					set @BinDimesion=0 
					if(@PrefValue<>'')
					begin    		
						begin try    
							select @BinDimesion=convert(INT,@PrefValue)    
						end try    
						begin catch    
							set @BinDimesion=0    
						end catch 		
					END 
					
					select @PrefValue=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@BinDimesion 
					set @SQL='select @ProductName=name from '+@PrefValue+' with(NOLOCK) where nodeid='+CONVERT(nvarchar,@BinDimesionNodeID)
					EXEC sp_executesql @SQL,N'@ProductName nvarchar(max) OUTPUT',@ProductName output		 
					
					RAISERROR('-537',16,1)  
				End	
			END	
		END
		else if(@VoucherType=-1  and @IsQtyIgnored=0)
		BEGIN	
			set @BinDimesionNodeID=0
			
			 if(@IsBatChes=1 and @productType=5)
			 BEGIN
				select @BatchID=X.value('@BatchID','INT')
				from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)

				select @BinDimesionNodeID=bn.BinID from INV_BinDetails bn with(nolock) 
				join  INV_DocDetails a with(nolock) on bn.InvDocDetailsID=a.InvDocDetailsID			
				where bn.IsQtyIgnored=0 and a.ProductID=@ProductID and a.batchid=@BatchID and statusid in(369,441,371)
				and bn.BinID in(select X.value('@NodeID','INT') from @BinsXML.nodes('/BinsXML/Row') as Data(X) where X.value('@NodeID','INT')>1)
				group by bn.BinID
				having isnull(sum(case when bn.VoucherType =1 and statusid<>369 then 0 else bn.VoucherType end* bn.Quantity),0)<0
			END
			ELSE
			BEGIN
				set @CaseID=0
				set @NID=0
				select @CaseID=Value  from @TblPref where IsGlobal=1 and Name ='DimensionwiseBins' and isnumeric(Value)=1
				if(@CaseID>50000)
				BEGIN  
					set @NID=0
					set @DUPLICATECODE='select @NID=dcCCNID'+convert(nvarchar,(@CaseID-50000))+' from [COM_DocCCData] with(nolock) where [InvDocDetailsID]='+convert(nvarchar,@InvDocDetailsID)
					EXEC sp_executesql @DUPLICATECODE,N'@NID INT OUTPUT',@NID output
					
						
					set @DUPLICATECODE='select @BinDimesionNodeID=bn.BinID from INV_BinDetails bn with(nolock) 
					join  INV_DocDetails a with(nolock) on bn.InvDocDetailsID=a.InvDocDetailsID		
					join  COM_DocCCData c with(nolock) on a.InvDocDetailsID=c.InvDocDetailsID 
					where bn.IsQtyIgnored=0 and a.ProductID='+convert(nvarchar(max),@ProductID)+' and statusid in(369,441,371)
					and dcCCNID'+convert(nvarchar,(@CaseID-50000))+'='+convert(nvarchar,@NID)+'
					and bn.BinID in(select X.value(''@NodeID'',''INT'') from @BinsXML.nodes(''/BinsXML/Row'') as Data(X) where X.value(''@NodeID'',''INT'')>1)
					group by bn.BinID
					having isnull(sum(case when bn.VoucherType =1 and statusid<>369 then 0 else bn.VoucherType end* bn.Quantity),0)<0'
					
					EXEC sp_executesql @DUPLICATECODE,N'@BinsXML xml,@BinDimesionNodeID INT OUTPUT',@BinsXML,@BinDimesionNodeID output
					
				END
				ELSE
				BEGIN
					select @BinDimesionNodeID=bn.BinID from INV_BinDetails bn with(nolock) 
					join  INV_DocDetails a with(nolock) on bn.InvDocDetailsID=a.InvDocDetailsID			
					where bn.IsQtyIgnored=0 and a.ProductID=@ProductID and statusid in(369,441,371)
					and bn.BinID in(select X.value('@NodeID','INT') from @BinsXML.nodes('/BinsXML/Row') as Data(X) where X.value('@NodeID','INT')>1)
					group by bn.BinID
					having isnull(sum(case when bn.VoucherType =1 and statusid<>369 then 0 else bn.VoucherType end* bn.Quantity),0)<0
				END	
			END

			
			if(@BinDimesionNodeID>0)
			BEGIN
					set @PrefValue=''
					select @PrefValue=value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
					and  name='BinsDimension'  
					set @BinDimesion=0 
					if(@PrefValue<>'')
					begin    		
						begin try    
							select @BinDimesion=convert(INT,@PrefValue)    
						end try    
						begin catch    
							set @BinDimesion=0    
						end catch 		
					END 
					
					select @PrefValue=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@BinDimesion 
					set @SQL='select @ProductName=name from '+@PrefValue+' with(NOLOCK) where nodeid='+CONVERT(nvarchar,@BinDimesionNodeID)
					EXEC sp_executesql @SQL,N'@ProductName nvarchar(max) OUTPUT',@ProductName output		 
					
					RAISERROR('-538',16,1)  
			End
		END
	END
       
	if(@ISSerial=1)	
	BEGIN	
		if (exists(select [InvDocDetailsID] from [INV_SerialStockProduct] with(nolock)
		where [InvDocDetailsID] =@InvDocDetailsID) and exists(select InvDocDetailsID from INV_DocDetails a with(nolock)
		join INV_Product b with(nolock) on a.ProductID=b.ProductID
		WHERE InvDocDetailsID=@InvDocDetailsID and b.ProductTypeID not in(2,10)))
		BEGIN
			if(@VoucherType=1)
			BEGIN
				if exists(select [SerialNumber]  from [INV_SerialStockProduct]  with(nolock)     
				WHERE [RefInvDocDetailsID]=@InvDocDetailsID)
				BEGIN
					RAISERROR('-508',16,1)
				END
			END
			ELSE if(@VoucherType=-1)
			BEGIN
					 UPDATE [INV_SerialStockProduct]      
					 SET [StatusID]=157      
					 ,IsAvailable=1 
					  from ( select [SerialNumber] sno ,SerialGUID sguid,[RefInvDocDetailsID] refinvID,[ProductID] PID from [INV_SerialStockProduct] with(nolock)      
					  WHERE [InvDocDetailsID] =@InvDocDetailsID) as t
					  where [ProductID]=PID and [SerialNumber]=sno and SerialGUID=sguid and [InvDocDetailsID]=refinvID
			END
			
			delete from [INV_SerialStockProduct]      
			WHERE [InvDocDetailsID] =@InvDocDetailsID		
		END	
	END
   IF(@AccountsXML IS NOT NULL)
   BEGIN 
		if exists(select AccountTypeID from @AcctypesTable where AccountDate>=@DocDate) and @IsImport=0 
		begin    
			if exists(select  a.AccountTypeID from @AccountsXML.nodes('/AccountsXML/Accounts') as Data(X)  
			join Acc_Accounts a with(nolock) on a.AccountID=X.value('@DebitAccount','INT')
			join @AcctypesTable b on a.AccountTypeID=b.AccountTypeID
			where X.value('@DebitAccount','INT')>0 and AccountDate>=@DocDate)
			begin  
				RAISERROR('-369',16,1)  
			end 
			
			if exists(select  a.AccountTypeID from @AccountsXML.nodes('/AccountsXML/Accounts') as Data(X)  
			join Acc_Accounts a with(nolock) on a.AccountID=X.value('@CreditAccount','INT')
			join @AcctypesTable b on a.AccountTypeID=b.AccountTypeID
			where X.value('@CreditAccount','INT')>0 
			and AccountDate>=@DocDate)
			begin  
				RAISERROR('-369',16,1)  
			end  
		end   
       
       
		INSERT INTO ACC_DocDetails      
         (InvDocDetailsID  
         ,[DocID]  
         ,VOUCHERNO      
         ,[CostCenterID]                    
         ,[DocumentType]      
         ,[VersionNo]      
         ,[DocAbbr]      
         ,[DocPrefix]      
         ,[DocNumber]      
         ,[DocDate]
         ,ActDocDate      
         ,[DueDate]      
         ,[StatusID]      
         ,[BillNo]      
         ,BillDate      
         ,[CommonNarration]      
         ,LineNarration      
         ,[DebitAccount]      
         ,[CreditAccount]      
         ,[Amount]      
         ,[DocSeqNo]      
         ,[CurrencyID]      
         ,[ExchangeRate]     
         ,[AmountFC] 
         ,[CreatedBy]      
         ,[CreatedDate]  
         ,WorkflowID   
         ,WorkFlowStatus   
         ,WorkFlowLevel  
         ,RefCCID  
         ,RefNodeid,AP)      
            
        SELECT @InvDocDetailsID,0,@VoucherNo      
         , @CostCenterID              
         , @DocumentType      
         , @VersionNo     
         , @DocAbbr      
         , @DocPrefix      
         , @DocNumber      
         , CONVERT(FLOAT,@DocDate)
         , @ActDocDate      
         , CONVERT(FLOAT,@DueDate)      
         , @StatusID      
         , @BillNo      
         , @BILLDate      
         , X.value('@CommonNarration','nvarchar(max)')      
         , X.value('@LineNarration','nvarchar(max)')               
         ,case when @IsImport=1  and X.value('@DebitAccount','nvarchar(500)')=@ACCOUNT1Name then  @ACCOUNT1      
             when @IsImport=1 and X.value('@IsNegative','bit')=1 and X.value('@DebitAccount','nvarchar(500)')=@ACCOUNT2Name then  @ACCOUNT2      
             else ISNULL( X.value('@DebitAccount','INT'),0) end              
         ,case when @IsImport=1  and X.value('@CreditAccount','nvarchar(500)')=@ACCOUNT2Name then   @ACCOUNT2      
             when @IsImport=1 and X.value('@IsNegative','bit')=1  and X.value('@CreditAccount','nvarchar(500)')=@ACCOUNT1Name then   @ACCOUNT1      
             else ISNULL( X.value('@CreditAccount','INT'),0) end 
         , X.value('@Amount','FLOAT')      
         , 1   
         , ISNULL(X.value('@CurrencyID','int'),1)      
         , ISNULL(X.value('@ExchangeRate','float'),1)      
         , ISNULL(X.value('@AmtFc','FLOAT'),X.value('@Amount','FLOAT'))                          
         , @UserName      
         , @Dt    
         , @WID  
         , @StatusID  
         , @level   
         , @RefCCID  
         , @RefNodeid,@AP
           from @AccountsXML.nodes('/AccountsXML/Accounts') as Data(X)  
      
   END      
   
   IF(@RefBatchID>0 or (@EXTRAXML IS NOT NULL and exists(select * from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X))))
   BEGIN      
    if(@DocumentType=35)
	BEGIN		
		delete from @caseTab
		SET @SQL='select CaseID FROM CRM_Cases with(nolock) where SvcContractID=@DocID and ContractLineID=@InvDocDetailsID
		and CaseID not in (SELECT X.value(''@CaseID'',''INT'') from @EXTRAXML.nodes(''/EXTRAXML/xml/Row'') as Data(X)
		where X.value(''@CaseID'',''INT'')<>0)'
		
		INSERT INTO @caseTab(CaseID)
		EXEC sp_executesql @SQL,N'@EXTRAXML XML,@DocID INT,@InvDocDetailsID INT',@EXTRAXML,@DocID,@InvDocDetailsID
		
		select @iUNIQ=MIN(id),@UNIQUECNT=MAX(id) FROM @caseTab
		
		WHILE(@iUNIQ <= @UNIQUECNT)
		BEGIN
			SELECT @CaseID=CaseID FROM @caseTab WHERE id=@iUNIQ
			
			SET @SQL='exec spCRM_DeleteCase @CASEID='+CONVERT(NVARCHAR,@CaseID)+',@USERID='+CONVERT(NVARCHAR,@UserID)+',@LangID='+CONVERT(NVARCHAR,@LangID)+',@RoleID='+CONVERT(NVARCHAR,@RoleID)
			EXEC (@SQL)
			
			SET @iUNIQ=@iUNIQ+1
		END		
		DECLARE @ActivityID INT
		delete   FROM @caseTab
		
		INSERT INTO @caseTab
		SELECT X.value('@CaseID','INT'), X.value('@StartDate','DATETIME'), X.value('@StartTime','NVARCHAR(20)'), X.value('@EndDate','DATETIME')
		, X.value('@EndTime','NVARCHAR(20)'),X.value('@AssignedTo','INT'), X.value('@Remarks','NVARCHAR(MAX)'), X.value('@SERIALNUMBER','NVARCHAR(MAX)')
		from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)
		select @iUNIQ=MIN(id),@UNIQUECNT=MAX(id) FROM @caseTab
		
		WHILE(@iUNIQ <= @UNIQUECNT)
		BEGIN
			SELECT @CaseID=CaseID,@Assignedto=AssignedTo,@SERIALNUMBER=SERIALNUMBER,@CaseDate=CONVERT(float, StartDate)
			FROM @caseTab WHERE id=@iUNIQ
			
			SELECT @CustomerName=AccountName FROM ACC_ACCOUNTS with(nolock) WHERE ACCOUNTID=@ACCOUNT2
			SET @CaseNumber=@VoucherNo+'/'+(select PRODUCTCODE  from INV_PRODUCT with(nolock) WHERE PRODUCTID=@PRODUCTID)+isnull(@SERIALNUMBER,'')+'/'+isnull(@CustomerName,'')+'/'+CONVERT(NVARCHAR,@iUNIQ)
			
			IF(@CaseID=0)
			BEGIN
				SET @SQL='EXEC @return_value = [dbo].[spCRM_SetCases]
				@CaseID = 0,@CaseNumber='''+@CaseNumber+'''
				,@CaseDate='+CONVERT(NVARCHAR(MAX),@CaseDate)+',@CUSTOMER='+CONVERT(NVARCHAR,@ACCOUNT2)+',@StatusID=10005,
				@IsGroup = 0,@SelectedNodeID = 0,
				@PRODUCTID ='+CONVERT(NVARCHAR,@ProductID)+',
				@SERIALNUMBER = '''+isnull(@SERIALNUMBER,'')+''',@SVCCONTRACTID='+CONVERT(NVARCHAR,@DocID)+',@CONTRACTLINEID='+CONVERT(NVARCHAR,@InvDocDetailsID)+',
				@BillingMethod=138,
				@Assigned='+CONVERT(NVARCHAR,@Assignedto)+',
				 @CompanyGUID='''+@CompanyGUID+''',@GUID='''+@Guid+''',@Mode=''PM'',@RefCCID='+CONVERT(NVARCHAR,@CostCenterID)+',@RefNodeID='+CONVERT(NVARCHAR,@DocID)+',
				@UserName='''+@UserName+''',@UserID='+CONVERT(NVARCHAR,@UserID)+',@RoleID='+CONVERT(NVARCHAR,@RoleID)
				print @SQL
				EXEC sp_executesql @SQL,N'@return_value INT OUTPUT',@return_value OUTPUT				
				IF(@return_value>0) 
				BEGIN
					EXEC spCRM_SetCRMAssignment 73, @return_value,0,@UserID,0,@Assignedto,'','',@CompanyGUID,@UserName,@LangId  
					INSERT INTO CRM_Activities(ActivityTypeID, ScheduleID, CostCenterID, NodeID, StatusID, Subject, Priority,  
					Location, IsAllDayActivity,  
					  CustomerID, Remarks,  ActualCloseDate,ActualCloseTime, StartDate,EndDate,StartTime,EndTime, CompanyGUID, GUID,  CreatedBy, CreatedDate)
					select 1,0,73,@return_value,412,@CaseNumber,2,'-',1,
					@CustomerName,Remarks
					,null,'',CONVERT(float, StartDate) ,CONVERT(float,EndDate),StartTime,EndTime ,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()) 
					from @caseTab WHERE id=@iUNIQ
					SET @ActivityID=SCOPE_IDENTITY() 
					EXEC [spCRM_SetActivityAssignment] 73,@return_value,0,@UserID,0,@Assignedto,'','',@CompanyGUID,@UserName,@LangID,@ActivityID
				END
			END
			ELSE
			BEGIN
				SET @SQL='update CRM_Cases
				set CaseNumber='''+@CaseNumber+''',CustomerID='+CONVERT(NVARCHAR,@ACCOUNT2)+',ProductID='+CONVERT(NVARCHAR,@ProductID)+',AssignedTo='+CONVERT(NVARCHAR,@Assignedto)+'
				where CaseID='+CONVERT(NVARCHAR,@CaseID)
				EXEC (@SQL)
				
				update 	CRM_Activities
				set Remarks=a.Remarks,
				StartDate=CONVERT(float, a.StartDate),EndDate=CONVERT(float,a.EndDate),
				StartTime=a.StartTime,EndTime=a.EndTime,Subject=@CaseNumber,CustomerID=@CustomerName
				from @caseTab a 
				WHERE CostCenterID=73 and  NodeID =@CaseID and a.id=@iUNIQ
				
				--While Resaving Service Contract document, if Assigned User is changed it should reflect in Calendar & Cases(Masood)
				Update CRM_Assignment Set UserID=@Assignedto Where CCID=73 AND CCNodeID=@CaseID
			END	
			SET @iUNIQ=@iUNIQ+1
		END							
		
		EXEC @return_value = [spDOC_SetCaseLink] @InvDocDetailsID,@UserID,@LangID
		
   END 
    else IF((@ISSerial=1 and @productType=2) or exists(select value from @TblPref where IsGlobal=0 and Name='EnableAssetSerialNo' and Value='true'))--SERIAL PRODUCT       
    BEGIN   
    	
    	if(@DocumentType=5 or @DocumentType=30)  
		begin  
			select @VoucherType=VoucherType from [INV_DocDetails]  WITH(NOLOCK)  where InvDocDetailsID=@InvDocDetailsID  
		end   
   
	if exists(select [InvDocDetailsID] from [INV_SerialStockProduct] with(nolock)
	where [SerialNumber] in(select [SerialNumber] from [INV_SerialStockProduct] with(nolock)      
     WHERE [InvDocDetailsID] =@InvDocDetailsID AND SerialProductID NOT IN      
     (SELECT X.value('@SerialProductID','INT')       
     from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)      
     WHERE X.value('@SerialProductID','INT')  IS NOT NULL AND X.value('@SerialProductID','INT')<>0))
     and [RefInvDocDetailsID]=@InvDocDetailsID)
      BEGIN
		RAISERROR('-508',16,1)
      END
     
         
      if(@VoucherType=-1)
      BEGIN
		 UPDATE [INV_SerialStockProduct]      
         SET [StatusID]=157      
         ,IsAvailable=1 
          from ( select [SerialNumber] sno ,SerialGUID sguid,[RefInvDocDetailsID] refinvID from  [INV_SerialStockProduct] with(nolock)
		 WHERE [InvDocDetailsID] =@InvDocDetailsID AND SerialProductID NOT IN      
		 (SELECT X.value('@SerialProductID','INT')       
		 from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)      
		 WHERE X.value('@SerialProductID','INT')  IS NOT NULL AND X.value('@SerialProductID','INT')<>0)) as t
		 where [ProductID]=@ProductID and [SerialNumber]=sno and SerialGUID=sguid and [InvDocDetailsID]=refinvID
	  END
	  
	  if(@DocumentType=5 and @VoucherType=1)
	  BEGIN
		DELETE FROM  [INV_SerialStockProduct]      
		WHERE [InvDocDetailsID] =@InvDocDetailsID
		
		INSERT INTO [INV_SerialStockProduct]      
				([InvDocDetailsID]      
				,[ProductID]      
				,[SerialNumber]      
				,[StockCode]      
				,[Quantity]      
				,[StatusID]      
			   ,[RefInvDocDetailsID]      
			  ,[Narration]      
			  ,SerialGUID      
			  ,IsIssue      
			  ,IsAvailable      
				,[CompanyGUID]      
				,[GUID]      
				,[CreatedBy]      
				,[CreatedDate])      
			  SELECT @InvDocDetailsID      
				,@ProductID      
				,X.value('@SerialNumber','nvarchar(500)')      
				,X.value('@StockCode','nvarchar(500)')      
				,X.value('@Quantity','float')      
				,case when (@DocumentType=5 and @VoucherType=1) THEN 157 ELSE X.value('@StatusID','int') END
				,case when (@DocumentType=5 and @VoucherType=1) THEN 0 ELSE X.value('@RefInvDocDetailsID','INT') END
				,X.value('@Narration','nvarchar(max)')       
				,X.value('@SerialGUID','nvarchar(50)')      
				,X.value('@IsIssue','bit')      
				,case when (@DocumentType=5 and @VoucherType=1) THEN 1 ELSE X.value('@IsAvailable','bit') END      
			  , @CompanyGUID      
			  , @Guid
			  , @UserName      
			  , @Dt      
			 from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)      
	  END
	  ELSE
	  BEGIN
			 DELETE FROM  [INV_SerialStockProduct]      
			 WHERE [InvDocDetailsID] =@InvDocDetailsID AND SerialProductID NOT IN      
			 (SELECT X.value('@SerialProductID','INT')       
			 from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)      
			 WHERE X.value('@SerialProductID','INT')  IS NOT NULL AND X.value('@SerialProductID','INT')<>0)      
		      
			 INSERT INTO [INV_SerialStockProduct]      
				([InvDocDetailsID]      
				,[ProductID]      
				,[SerialNumber]      
				,[StockCode]      
				,[Quantity]      
				,[StatusID]      
			   ,[RefInvDocDetailsID]      
			  ,[Narration]      
			  ,SerialGUID      
			  ,IsIssue      
			  ,IsAvailable      
				,[CompanyGUID]      
				,[GUID]      
				,[CreatedBy]      
				,[CreatedDate])      
			  SELECT @InvDocDetailsID      
				,@ProductID      
				,X.value('@SerialNumber','nvarchar(500)')      
				,X.value('@StockCode','nvarchar(500)')      
				,X.value('@Quantity','float')      
				,case when (@DocumentType=5 and @VoucherType=1) THEN 157 ELSE X.value('@StatusID','int') END
				,case when (@DocumentType=5 and @VoucherType=1) THEN 0 ELSE X.value('@RefInvDocDetailsID','INT') END
				,X.value('@Narration','nvarchar(max)')       
				,X.value('@SerialGUID','nvarchar(50)')      
				,X.value('@IsIssue','bit')      
				,case when (@DocumentType=5 and @VoucherType=1) THEN 1 ELSE X.value('@IsAvailable','bit') END      
			  , @CompanyGUID      
			  , @Guid
			  , @UserName      
			  , @Dt      
			 from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)      
			 WHERE X.value('@SerialProductID','INT') IS NULL OR X.value('@SerialProductID','INT')=0      
		      
		      
			 UPDATE [INV_SerialStockProduct]      
				SET [InvDocDetailsID]=@InvDocDetailsID      
				,[ProductID]=@ProductID      
				,[SerialNumber]=X.value('@SerialNumber','nvarchar(500)')      
				,[StockCode]=X.value('@StockCode','nvarchar(500)')      
				,[Quantity]=X.value('@Quantity','float')      
				,[StatusID]=case when (@DocumentType=5 and @VoucherType=1) THEN [StatusID] ELSE X.value('@StatusID','int') END     
			  ,[RefInvDocDetailsID]=case when (@DocumentType=5 and @VoucherType=1) THEN 0 ELSE X.value('@RefInvDocDetailsID','INT')   END
				,[Narration]=X.value('@Narration','nvarchar(max)')       
			  ,SerialGUID=X.value('@SerialGUID','nvarchar(50)')      
			  ,IsIssue=X.value('@IsIssue','bit')      
				 ,IsAvailable=case when (@DocumentType=5 and @VoucherType=1) THEN IsAvailable ELSE X.value('@IsAvailable','bit') END      
				,GUID= @Guid      
			  ,ModifiedBy= @UserName      
			  ,ModifiedDate= @Dt           
			 from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)      
			 WHERE X.value('@SerialProductID','INT')=[INV_SerialStockProduct].SerialProductID AND X.value('@SerialProductID','INT') IS NOT NULL AND X.value('@SerialProductID','INT')<>0      
		      
		       
			 UPDATE [INV_SerialStockProduct]      
				SET [StatusID]=X.value('@StatusID','int')      
				 ,IsAvailable=X.value('@IsAvailable','bit')      
			 from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)      
			 WHERE X.value('@SerialGUID','nvarchar(50)')=[INV_SerialStockProduct].SerialGUID  
     	END
      if(@VoucherType=-1 and @DocumentType not in (6,39,10)
      and not exists(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='PostAsset' and Value='true'))
      BEGIN
		if exists(select [SerialNumber] from [INV_SerialStockProduct] a with(nolock)
		join INV_DocDetails d with(nolock) on a.InvDocDetailsID=d.InvDocDetailsID
		join @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)   on a.[SerialNumber]=X.value('@SerialNumber','nvarchar(500)')
		where a.productid=@ProductID
		--and d.DocumentType<>5
		group by [SerialNumber]
		having sum(voucherType)<0)
		BEGIN
			RAISERROR('-507',16,1)
		END
      END
      ELSE if(@DocumentType not in (5,6,39,10) and @productType<>10)
      BEGIN
		if exists(select Value from @TblPref where Name='DocwiseSNo' and Value='true' and IsGlobal=0)
		BEGIN
			if exists(select [SerialNumber] from [INV_SerialStockProduct] a with(nolock)
			join INV_DocDetails d with(nolock) on a.InvDocDetailsID=d.InvDocDetailsID
			join @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)   on a.[SerialNumber]=X.value('@SerialNumber','nvarchar(500)')
			where d.DocID=@DocID and a.productid=@ProductID AND D.IsQtyIgnored=0
			group by [SerialNumber]
			having COUNT([SerialNumber])>1)
			BEGIN	
				set @ProductName=''
				select @ProductName=@ProductName+[SerialNumber]+',' from [INV_SerialStockProduct] a with(nolock)
				join INV_DocDetails d with(nolock) on a.InvDocDetailsID=d.InvDocDetailsID
				join @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)   on a.[SerialNumber]=X.value('@SerialNumber','nvarchar(500)')
				where d.DocID=@DocID and a.productid=@ProductID AND D.IsQtyIgnored=0
				group by [SerialNumber]
				having COUNT([SerialNumber])>1
				
				set @ProductName=' "'+SUBSTRING(@ProductName,0,len(@ProductName))+ '" at row no.'+CONVERT(NVARCHAR, @I -1 )
						
				RAISERROR('-506',16,1)
			END
		END
		ELSE
		BEGIN
			set @WHERE=''
			if exists(select value from @TblPref where IsGlobal=1 and Name='LW SNOS' and Value='true')
				 and exists(select value from @TblPref where IsGlobal=1 and Name='EnableLocationWise' and Value='true')
			BEGIN				
				set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@LocationID)        
			END

			if exists(select value from @TblPref where IsGlobal=1 and Name='DW SNOS' and Value='true')
			and exists(select value from @TblPref where IsGlobal=1 and Name='EnableDivisionWise' and Value='true')
			BEGIN				
				set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@DivisionID)        
			END
			
			set @sql='if exists(select [SerialNumber] from [INV_SerialStockProduct] a with(nolock)
			join INV_DocDetails d with(nolock) on a.InvDocDetailsID=d.InvDocDetailsID '
			
			if(@WHERE<>'')
				set @sql=@sql+' join COM_DocCCData c with(nolock) on d.InvDocDetailsID=c.InvDocDetailsID '
			
			set @sql=@sql+' join @EXTRAXML.nodes(''/EXTRAXML/xml/Row'') as Data(X)   on a.[SerialNumber]=X.value(''@SerialNumber'',''nvarchar(500)'')
			where (a.[RefInvDocDetailsID] is null or a.[RefInvDocDetailsID]=0) and a.productid='+CONVERT(nvarchar,@ProductID) +'
			and d.DocumentType not in (5,6)'+@WHERE+' AND D.IsQtyIgnored=0
			group by [SerialNumber]
			having COUNT([SerialNumber])>1)
			BEGIN		
				set @ProductName=''''	
				select @ProductName=@ProductName+[SerialNumber]+'','' from [INV_SerialStockProduct] a with(nolock)
				join INV_DocDetails d with(nolock) on a.InvDocDetailsID=d.InvDocDetailsID '
				
				if(@WHERE<>'')
					set @sql=@sql+' join COM_DocCCData c with(nolock) on d.InvDocDetailsID=c.InvDocDetailsID '
				
				set @sql=@sql+' join @EXTRAXML.nodes(''/EXTRAXML/xml/Row'') as Data(X)   on a.[SerialNumber]=X.value(''@SerialNumber'',''nvarchar(500)'')
				where (a.[RefInvDocDetailsID] is null or a.[RefInvDocDetailsID]=0) and a.productid='+CONVERT(nvarchar,@ProductID) +'
				and d.DocumentType not in (5,6)'+@WHERE+' AND D.IsQtyIgnored=0
				group by [SerialNumber]
				having COUNT([SerialNumber])>1
				
				set @ProductName='' "''+SUBSTRING(@ProductName,0,len(@ProductName))+ ''" at row no.'+CONVERT(NVARCHAR, @I -1 )+'''
				set @PrefValueDoc=1
			
			END ELSE set @PrefValueDoc=0'
			print @sql
			EXEC sp_executesql @sql,N'@EXTRAXML xml,@ProductName nvarchar(500) output,@PrefValueDoc bit	OUTPUT',@EXTRAXML,@ProductName output,@PrefValueDoc output
			
			if(@PrefValueDoc=1)
				RAISERROR('-506',16,1)	 
		END	
      END  
             
    END -- SERIAL PRODUCT END         
    ELSE if(@IsBatChes=1 and @productType=5)--BATCH WISE PRODUCT      
    BEGIN      
      --DECLARING TEMP VARIABLES            
		DECLARE @RefInvID INT,@Quantity FLOAT,@Hold FLOAT,@Release FLOAT,@Batchno nvarchar(max),@MfgDate datetime,@ExpDate   datetime    
	

		if(@DocumentType=5 or @DocumentType=30)  
		begin  
			select @VoucherType=VoucherType,@IsQtyIgnored=IsQtyIgnored from [INV_DocDetails]  WITH(NOLOCK)  where InvDocDetailsID=@InvDocDetailsID  
		end  
			if(@IsImport=1)    
			begin    
			
				select @Release=UOMConvertedQty from INV_DocDetails with(nolock) where InvDocDetailsID=@InvDocDetailsID    
				set @Hold=0    
				 
				set @Batchno=(select top 1   X.value('@Batchno','NVARCHAR(500)') from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X) )     
				IF(@VoucherType=-1)
				BEGIN
					select @BatchID=X.value('@BatchID','INT'),@Hold=X.value('@Hold','float'),@Release=X.value('@Release','float')
					,@RefInvID=X.value('@RefInvID','INT'),@Quantity=X.value('@Quantity','FLOAT')
					from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)
				END
				ELSE
				BEGIN
					if not exists(SELECT BatchId FROM INV_Batches with(nolock) WHERE BATCHNUMBER = @Batchno and ProductID=@ProductID)    
					begin 
						DECLARE @StaticFieldsQuery nvarchar(500), @Customfields nvarchar(500), @CCFields nvarchar(500),@UpdateSql NVARCHAR(MAX),@IBatchCode nvarchar(200),@IBatchCurrID int
					 	select @MfgDate=  X.value('@MfgDate','datetime'), @ExpDate= X.value('@ExpDate','datetime') ,
					 	@IBatchCurrID= X.value('@BatchCurrID','int'),
					 	@IBatchCode= X.value('@BatchCode','NVARCHAR(200)'),
					 	@StaticFieldsQuery= X.value('@StaticFieldsQuery','NVARCHAR(500)') ,
					 	@Customfields= X.value('@TextFields','NVARCHAR(500)') ,
					 	@CCFields= X.value('@CCFields','NVARCHAR(500)') 
					 	from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)  
					 	
						EXEC @return_value  =spINV_SetBatch 0,0,@Batchno,'MM/dd/YYYY',@MfgDate,'MM/dd/YYYY',@ExpDate,      
						77,0,null,0,0,null,0,0,null,0,@ProductID,null,0,0,1,null,0,    
						@Customfields,@CCFields,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,      
						null,
						@IBatchCode,--'',--BatchCode
						'',
						@IBatchCurrID,--0,--CurrentCodeNo
						@CompanyGUID ,'GUID',@UserName,@UserID,@RoleID,@LangID   

						if(@return_value>0)
						BEGIN
							set @BATCHID=@return_value
							
							if(@StaticFieldsQuery IS NOT NULL AND @StaticFieldsQuery <> '')    
							BEGIN    
								-- SET @ExtendedColsXML=dbo.fnCOM_GetExtraFieldsQuery(@ExtendedColsXML,3)  
								set @UpdateSql='update INV_Batches     
								SET '+@StaticFieldsQuery+' [ModifiedBy] ='''+ @UserName    
								+''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE BatchID='+convert(NVARCHAR,@BATCHID)   +' '
								exec(@UpdateSql)    
							END
						END
					end      
					else    
					begin    
						selECT @BATCHID=BatchId FROM INV_Batches with(nolock) WHERE BATCHNUMBER = @Batchno and ProductID=@ProductID    
					end  
					--Update batch link dimension to document dimension if dimension is used @ document
					declare @RefDimensionID INT, @RefDimensionNodeID INT, @BATCHMAPPING NVARCHAR(500), @BatchDimension INT,@BatchValue nvarchar(10)
					if(@batchcol<>'')
					begin
						set @BATCHMAPPING='Update [COM_DocTextData] set '+@batchcol+'='+CONVERT(NVARCHAR(10),@BATCHID)+'
						where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
						exec(@BATCHMAPPING)
					end		
					select @BatchValue= Value from COM_CostCenterPreferences with(nolock) where CostCenterID=16 and Name='BatchDimension'
					if(@BatchValue is not null and @BatchValue<>'')  
					begin     
						set @BatchDimension=0  
						begin try  
							select @BatchDimension=convert(INT,@BatchValue)  
						end try  
						begin catch  
							set @BatchDimension=0   
						end catch  
						select @RefDimensionID=RefDimensionID,@RefDimensionNodeID=RefDimensionNodeID from COM_DocBridge with(nolock) where costcenterid=16 and nodeid=@BATCHID
						if @RefDimensionID is not null and @BatchDimension=@RefDimensionID  
						and  exists (select RefDimensionID from COM_DocBridge with(nolock) where costcenterid=16 and nodeid=@BATCHID) 
						 and exists (select costcentercolid from adm_costcenterdef with(nolock) where costcenterid=@CostCenterID and iscolumninuse=1 and columncostcenterid=@RefDimensionID)
						BEGIN
							SET @BATCHMAPPING=''
							set @BATCHMAPPING='Update [COM_DocCCData] set DCCCNID'+CONVERT(NVARCHAR(10),(@RefDimensionID-50000))+'='+CONVERT(NVARCHAR(10),(@RefDimensionNodeID))+'
							where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)+''
							exec(@BATCHMAPPING)
						END  
					end
				END
			end    
			else if(@RefBatchID>0)    
			begin
				select @Batchno=BatchNumber from INV_Batches WITH(NOLOCK) where BatchID=@RefBatchID
				
				set @BatchID=0
				select @BatchID=BatchID,@MfgDate=MfgDate,@ExpDate=ExpiryDate from INV_Batches WITH(NOLOCK) 
				where BatchNumber=@Batchno and ProductID=@ProductID
				
				if(@BatchID is null or @BatchID=0)
				BEGIN						
						EXEC @return_value  =spINV_SetBatch 0,0,@Batchno,'MM/dd/YYYY',@MfgDate,'MM/dd/YYYY',@ExpDate,      
						77,0,null,0,0,null,0,0,null,0,@ProductID,null,0,0,1,null,0,    
						'','',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,      
						null,'','',0,@CompanyGUID ,'GUID',@UserName,@UserID,@RoleID,@LangID   

						if(@return_value>0)	
						begin					
							set @BATCHID=@return_value
							
							Exec [spDOC_SetLinkDimension]
								@InvDocDetailsID=@InvDocDetailsID, 
								@Costcenterid=@CostCenterID,         
								@DimCCID=16,
								@DimNodeID=@BATCHID,
								@UserID=@UserID,    
								@LangID=@LangID 
							
							select @RefDimensionID=RefDimensionID,@RefDimensionNodeID=RefDimensionNodeID from COM_DocBridge with(nolock) where costcenterid=16 and nodeid=@BATCHID
							
							if @RefDimensionID is not null and @RefDimensionID>50000 and @RefDimensionNodeID>2
							begin
								Exec [spDOC_SetLinkDimension]
									@InvDocDetailsID=@BATCHID, 
									@Costcenterid=16,         
									@DimCCID=@RefDimensionID,
									@DimNodeID=@RefDimensionNodeID,
									@UserID=@UserID,    
									@LangID=@LangID
							end
						end
				END
				
				select @OldBatchID=BatchID  FROM [INV_DocDetails] with(nolock) WHERE InvDocDetailsID=@InvDocDetailsID
				if(@OldBatchID>1 and @OldBatchID<>@BatchID and @HistoryStatus='Update')
				BEGIN  		
				 	
					select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
					where Name='AllowNegativebatches' and costcenterid=16  

					if(@ConsolidatedBatches is null or @ConsolidatedBatches ='false')
					BEGIN
						select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
						where Name='ConsolidatedBatches' and costcenterid=16  

						if(@ConsolidatedBatches is not null and @ConsolidatedBatches ='False')  
						begin     
							set @Tot=0
							
							set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
							FROM [INV_DocDetails] AS BD  with(nolock)                  
							where vouchertype=-1 and IsQtyIgnored=0  and batchid=@OldBatchID and RefInvDocDetailsID=@InvDocDetailsID),0)   
						end  
						else  
						begin  
							set @Tot=isnull((SELECT sum(BD.ReleaseQuantity)    
							FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
							where vouchertype=1 and statusid =369 and IsQtyIgnored=0  and batchid=@OldBatchID and InvDocDetailsID<>@InvDocDetailsID),0)  

							set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
							FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
							where vouchertype=-1 and statusid in(369,371,441) and IsQtyIgnored=0  and batchid=@OldBatchID),0)
						end  
						
						if(@Tot<-0.001)   
						begin  
							RAISERROR('-502',16,1)      
						end  
					END 
				END
				
				select @Quantity=UOMConvertedQty,@Release=UOMConvertedQty from INV_DocDetails with(nolock) where InvDocDetailsID=@InvDocDetailsID    
				  
			END
			else    
			begin  
				select @BatchID=X.value('@BatchID','INT'),@Hold=X.value('@Hold','float'),@Release=X.value('@Release','float')
				,@RefInvID=X.value('@RefInvID','INT'),@Quantity=X.value('@Quantity','FLOAT')
				from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)
			END	
			
			if(@Hold is null)    
				set @Hold=0    
			if((@Release is null or @DocumentType=5) and @VoucherType=1)      
				set @Release=@Quantity    
			else if(@Release is null )    
				set @Release=0    
			if(@BatchID>1)
			BEGIN
					if(@VoucherType=-1 and @IsQtyIgnored=0)  
					BEGIN  

						select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
						where Name='AllowNegativebatches' and costcenterid=16  

						if(@ConsolidatedBatches is null or @ConsolidatedBatches ='false')
						BEGIN
							select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
							where Name='ConsolidatedBatches' and costcenterid=16  

							if(@ConsolidatedBatches is not null and @ConsolidatedBatches ='False')  
							begin     
								set @Tot=(SELECT isnull(sum(BD.ReleaseQuantity),0)
								FROM [INV_DocDetails] AS BD WITH(NOLOCK)                 
								where vouchertype=1 and statusid =369 and IsQtyIgnored=0 and batchid=@BatchID and [InvDocDetailsID]=@RefInvID and convert(datetime,BD.docdate)<=@DocDate)  

								set @Tot= @Tot-(SELECT isnull(sum(BD.UOMConvertedQty),0)
								FROM [INV_DocDetails] AS BD  with(nolock)                  
								where vouchertype=-1 and IsQtyIgnored=0 and statusid in(369,371,441)  and batchid=@BatchID and RefInvDocDetailsID=@RefInvID and [InvDocDetailsID]<>@InvDocDetailsID)    
							end  
							else  
							begin
							
								set @WHERE=''								
								if exists(select value from @TblPref where IsGlobal=1 and Name='LW Batches' and Value='true')
									 and exists(select value from @TblPref where IsGlobal=1 and Name='EnableLocationWise' and Value='true')
								BEGIN				
									set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@LocationID)        
								END

								if exists(select value from @TblPref where IsGlobal=1 and Name='DW Batches' and Value='true')
								and exists(select value from @TblPref where IsGlobal=1 and Name='EnableDivisionWise' and Value='true')
								BEGIN				
									set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@DivisionID)        
								END
								
								set @PrefValue=''      
								select @PrefValue= isnull(Value,'') from @TblPref where IsGlobal=1 and Name='Maintain Dimensionwise Batches'        

								if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)        
								begin 	
									set @sql='select @NID=dcCCNID'+convert(nvarchar,(convert(INT,@PrefValue)-50000)) +' from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
								
									EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
									set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,(convert(INT,@PrefValue)-50000))+'='+CONVERT(nvarchar,@NID)        
								end 
									  
								set @sql='set @Tot=(SELECT isnull(sum(BD.ReleaseQuantity),0)  
								FROM [INV_DocDetails] AS BD  WITH(NOLOCK)
								join COM_DocCCData c with(nolock) on BD.InvDocDetailsID=c.InvDocDetailsID 
								where vouchertype=1  and statusid=369 and IsQtyIgnored=0  and BD.docdate <= '+CONVERT(nvarchar,convert(float,@DocDate))+@WHERE+' and batchid='+convert(nvarchar,@BatchID)+')  

								set @Tot= @Tot-(SELECT isnull(sum(BD.UOMConvertedQty),0)
								FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
								join COM_DocCCData c with(nolock) on BD.InvDocDetailsID=c.InvDocDetailsID  
								where vouchertype=-1 and statusid in(369,371,441) and IsQtyIgnored=0 and BD.docdate <= '+CONVERT(nvarchar,convert(float,@DocDate))+@WHERE+' and batchid='+convert(nvarchar,@BatchID)+' and BD.[InvDocDetailsID]<>'+convert(nvarchar,@InvDocDetailsID)+')'
								EXEC sp_executesql @sql,N'@Tot float OUTPUT',@Tot output	
							end 
							
							if(@Quantity>@Tot and abs(@Tot-@Quantity)>0.001)   
							begin  
								if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
									select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
								ELSE
									select @ProductName=ProductName from INV_Product with(nolock)
									where ProductID=@ProductID
								RAISERROR('-364',16,1)      
							end
							ELSE if not (@ConsolidatedBatches is not null and @ConsolidatedBatches ='False')  
							BEGIN	
										  
								set @sql='set @Tot=(SELECT isnull(sum(BD.ReleaseQuantity),0)  
								FROM [INV_DocDetails] AS BD  WITH(NOLOCK)
								join COM_DocCCData c with(nolock) on BD.InvDocDetailsID=c.InvDocDetailsID 
								where vouchertype=1  and statusid=369 and IsQtyIgnored=0 '+@WHERE+' and batchid='+convert(nvarchar,@BatchID)+')  

								set @Tot= @Tot-(SELECT isnull(sum(BD.UOMConvertedQty),0)
								FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
								join COM_DocCCData c with(nolock) on BD.InvDocDetailsID=c.InvDocDetailsID  
								where vouchertype=-1 and statusid in(369,371,441) and IsQtyIgnored=0 '+@WHERE+' and batchid='+convert(nvarchar,@BatchID)+' and BD.[InvDocDetailsID]<>'+convert(nvarchar,@InvDocDetailsID)+')'
								EXEC sp_executesql @sql,N'@Tot float OUTPUT',@Tot output	
								  
								if(@Quantity>@Tot and abs(@Tot-@Quantity)>0.001)   
								begin  
									if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
										select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
									ELSE
										select @ProductName=ProductName from INV_Product with(nolock)
										where ProductID=@ProductID
									RAISERROR('-364',16,1)      
								end
							END
						END 
					end 
				  
				
				   if exists(select value from @TblPref where IsGlobal=0 and Name='ConsBatch' and Value='true')
				   BEGIN		        
						
						select 	@PrefValueDoc=isnull(X.value('@BatchQtyIgnored','BIT'),1)
						from @TRANSXML.nodes('/Transactions') as Data(X)
						exec  [spDOC_SetConsBatch] @InvDocDetailsID,@ExtraXML,@PrefValueDoc
						
						if exists(select Value from @TblPref where IsGlobal=1 and Name='Check for -Ve Stock' and value='True' )
						BEGIN
							set @WHERE=''
							if(@loc=1)
							BEGIN				
								set @sql='select @NID=dcCCNID2 from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)			
								EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
													
								set @WHERE =@WHERE+' and dcCCNID2='+CONVERT(nvarchar,@NID)        
							END

							if(@div=1)
							BEGIN
								set @sql='select @NID=dcCCNID1 from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)			
								EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
													
								set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@NID)        
							END
							
							if(@dim>0)
							BEGIN
								set @sql='select @NID=dcCCNID'+convert(nvarchar,@dim) +' from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
							
								EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
								set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,@dim)+'='+CONVERT(nvarchar,@NID)        
							END
							
							set @QtyFin=0
							set @DUPLICATECODE='set @QtyFin=(SELECT isnull(sum(UOMConvertedQty*case when vouchertype=1 and statusid in(371,441) then 0 else  VoucherType end),0) FROM INV_DocDetails D WITH(NOLOCK)
							INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
							WHERE D.ProductID='+convert(nvarchar,@ProductID) 
							
							set @DUPLICATECODE=@DUPLICATECODE+' and DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))
							
							set @DUPLICATECODE=@DUPLICATECODE+' and D.StatusID in(371,441,369) AND IsQtyIgnored=0 '+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
							EXEC sp_executesql @DUPLICATECODE, N'@QtyFin float OUTPUT', @QtyFin OUTPUT
				
							if(@QtyFin<-0.001)
							BEGIN
								if exists(select Value from @TblPref where IsGlobal=1 and Name='GNegativeUnapprove' and Value='true')
								BEGIN
									set @StatusID=371
									
									UPDATE INV_DocDetails
									set StatusID=371
									where DocID=@DocID and CostCenterID=@CostCenterID
								END	
								ELSE
								BEGIN	
									if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
										select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
									ELSE
										SELECT @ProductName=ProductName FROM INV_Product a WITH(NOLOCK)    
										WHERE  ProductID=@ProductID     
									RAISERROR('-407',16,1)
								END	
							END
						END	
				   END
				   ELSE
				   BEGIN
					   --- INSERTING VALUES INTO BATCH DETAILS       
					   update [INV_DocDetails]      
						set [BatchID]=@BATCHID      
						,BatchHold =@Hold     
						,ReleaseQuantity =@Release     
						,RefInvDocDetailsID=@RefInvID          
						WHERE InvDocDetailsID=@InvDocDetailsID
		          END
		       
		            
				IF (@IsQtyIgnored=0 and @HistoryStatus='Update')
				BEGIN  			
					select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
					where Name='AllowNegativebatches' and costcenterid=16  
					
					set @Tot=0
					
					if(@ConsolidatedBatches is null or @ConsolidatedBatches ='false')
					BEGIN
						select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
						where Name='ConsolidatedBatches' and costcenterid=16  

						if(@ConsolidatedBatches is not null and @ConsolidatedBatches ='False')  
						begin
							if(@VoucherType=1)
							BEGIN
								if exists(select bd.[InvDocDetailsID] FROM [INV_DocDetails] AS BD WITH(NOLOCK)                 
								join [INV_DocDetails] AS sD WITH(NOLOCK) on bd.[InvDocDetailsID]=sd.RefInvDocDetailsID
								where bd.[InvDocDetailsID]=@InvDocDetailsID and BD.vouchertype=1 and sD.vouchertype=-1 and bd.IsQtyIgnored=0  and sd.IsQtyIgnored=0 and BD.docdate>sd.docdate )
								BEGIN
									raiserror('Batches issued can not update.',16,1)
								END
							
								set @Tot=isnull((SELECT sum(BD.ReleaseQuantity)    
								FROM [INV_DocDetails] AS BD WITH(NOLOCK)                 
								where vouchertype=1 and statusid =369 and IsQtyIgnored=0  and batchid=@BatchID and [InvDocDetailsID]=@InvDocDetailsID),0)  

								set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
								FROM [INV_DocDetails] AS BD  with(nolock)                  
								where vouchertype=-1 and statusid in(369,371,441) and IsQtyIgnored=0  and batchid=@BatchID and RefInvDocDetailsID=@InvDocDetailsID),0)   							
							END
							ELSE	
							BEGIN
								if exists(select bd.[InvDocDetailsID] FROM [INV_DocDetails] AS BD WITH(NOLOCK)                 
								join [INV_DocDetails] AS sD WITH(NOLOCK) on bd.[InvDocDetailsID]=sd.RefInvDocDetailsID
								where sd.RefInvDocDetailsID=@InvDocDetailsID and BD.vouchertype=1 and sD.vouchertype=-1 and bd.IsQtyIgnored=0  and sd.IsQtyIgnored=0 and BD.docdate>sd.docdate )
								BEGIN
									raiserror('Batches issued can not update.',16,1)
								END
							END
						end  
						else if(@VoucherType=1)
						begin  
							set @Tot=isnull((SELECT sum(BD.ReleaseQuantity)    
							FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
							where vouchertype=1 and statusid =369 and IsQtyIgnored=0  and batchid=@BatchID),0)  

							set @Tot= @Tot-isnull((SELECT sum(BD.UOMConvertedQty)    
							FROM [INV_DocDetails] AS BD  WITH(NOLOCK)                  
							where vouchertype=-1 and statusid in(369,371,441) and IsQtyIgnored=0  and batchid=@BatchID),0)
						end  
						 
						if(@Tot<-0.001)   
						begin  
							RAISERROR('-502',16,1)      
						end  
					END 
				
				
				end
				    
			END       
   end -- Batch TYPE END      
	ELSE if(@IsDynamic=1 and @productType in(8,3,11,12))--Dynamic PRODUCT      
	BEGIN          
	
		if exists(select Value from @TblPref where IsGlobal=1 and Name='Check for -Ve Stock' and Value='true')
			set @PrefValueDoc=1
		else
			set @PrefValueDoc=0

     
     DECLARE @TEMPEXTRAXML NVARCHAR(MAX)  
     SET @TEMPEXTRAXML=CONVERT(NVARCHAR(MAX),@EXTRAXML)  
  EXEC @return_value =[spDOC_SetDynamicSet] @DocID      
         , @CostCenterID    
         , @DocumentTypeID    
         , @DocumentType,@DocOrder    
         , @VoucherType     
         , @VoucherNo    
         , @VersionNo    
         , @DocAbbr    
         , @DocPrefix      
         , @DocNumber      
         , @DocDate      
         , @DueDate      
         , @StatusID      
         , @BillNo      
         , @BILLDate                  
         ,@ACCOUNT1      
         ,@ACCOUNT2       
  ,@WID,@level,@CheckHold,@TEMPEXTRAXML,@InvDocDetailsID,    
  @RefCCID,@RefNodeid,@PrefValueDoc,@AP, @CompanyGUID,@Guid,                 
           @UserName ,@LangID   
       
              
   end--Dynamic PRODUCT End 
    else if(@IStempINFO=1)    
    begin   
		
		if(@tempProd=convert(nvarchar,@ProductID))
		BEGIN
		declare @PCode nvarchar(200),@ProductCodeIgnoreText nvarchar(100),@IgnoreSpaces bit,@IsDuplicateCodeAllowed bit
		select @PCode=X.value('@ProductCode','nvarchar(200)') from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)    
		  
    	if(@PCode<>'')
    	begin    	
    		SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=3 and  Name='DuplicateCodeAllowed'  
			select @ProductCodeIgnoreText=Value   from COM_CostCenterPreferences with(nolock) where CostCenterID=3 and Name='CodeIgnoreSpecialCharacters'
			SELECT @IgnoreSpaces=convert(bit,Value)  FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=3 and  Name='CodeIgnoreSpaces'  
			if(@IgnoreSpaces=1)
				set @PCode=replace(@PCode,' ','')
			IF @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0
			BEGIN
			--Ignore special character in ProductCode while verifying duplicate check 
			declare  @len INT,@CodeSQL NVARCHAR(MAX) 
			set @CodeSQL='ProductCode'
			set @len=len(@ProductCodeIgnoreText) 
			if(@len>0)
			begin
				declare @tempCode1 nvarchar(100), @i1 int 
				set @tempCode1=@PCode 
				set @i1=1
				while @i1<=@len
				begin
					declare @n char
					set @n=@ProductCodeIgnoreText
					set @ProductCodeIgnoreText=replace(@ProductCodeIgnoreText,@n,'')
					set @tempCode1=replace(@tempCode1,@n,'')
					set @CodeSQL='replace('+@CodeSQL+','''+@n+''','''')'
					set @i1=@i1+1
				end  
				declare @str1 nvarchar(max) , @count1 int
				set @str1='@count1 int output'
				if @ProductID=0
					set @CodeSQL='set @count1=(select count('+@CodeSQL+') from INV_Product with(nolock) where '+@CodeSQL+' = '''+@tempCode1+''')'
				else
					set @CodeSQL='set @count1=(select count('+@CodeSQL+') from INV_Product with(nolock) where '+@CodeSQL+' = '''+@tempCode1+''' and Productid<>'+convert(nvarchar,@ProductID)+')'
				 
				exec sp_executesql @CodeSQL, @str1, @count1 OUTPUT 	
				--IF (@count1>0)  
				--	RAISERROR('-116',16,1)
				--set @ProductCode=@tempCode  
			end  
			END	
    	end	  
		
		  insert into INV_TempInfo(InvDocDetailsID,ProductCode,PurchasePrice)    
		  select @InvDocDetailsID,X.value('@ProductCode','nvarchar(200)'),X.value('@PurchasePrice','float')    
		  from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X)    
		END	  
    end  
   END -- EXTRA XML END       
   else    
   begin
		if(@DocumentType=35)
		BEGIN		
		 delete from @caseTab
		
		SET @SQL='select CaseID FROM CRM_Cases with(nolock) where SvcContractID=@DocID and ContractLineID=@InvDocDetailsID
		and CaseID not in (SELECT X.value(''@CaseID'',''INT'') from @EXTRAXML.nodes(''/EXTRAXML/xml/Row'') as Data(X)
		where X.value(''@CaseID'',''INT'')<>0)'
		
		INSERT INTO @caseTab(CaseID)
		EXEC sp_executesql @SQL,N'@EXTRAXML XML,@DocID INT,@InvDocDetailsID INT',@EXTRAXML,@DocID,@InvDocDetailsID
		
		select @iUNIQ=MIN(id),@UNIQUECNT=MAX(id) FROM @caseTab
		
			WHILE(@iUNIQ <= @UNIQUECNT)
			BEGIN
				SELECT @CaseID=CaseID FROM @caseTab WHERE id=@iUNIQ
				
				SET @SQL='exec spCRM_DeleteCase @CASEID='+CONVERT(NVARCHAR,@CaseID)+',@USERID='+CONVERT(NVARCHAR,@UserID)+',@LangID='+CONVERT(NVARCHAR,@LangID)+',@RoleID='+CONVERT(NVARCHAR,@RoleID)
				EXEC (@SQL)
				
				delete from CRM_Activities 
				where CostCenterID=73 and NodeID=@CaseID
				
				SET @iUNIQ=@iUNIQ+1
			END	
		END
		
	
		if(@ProductType=5 and @IsQtyIgnored=0)
		begin  
			SET @XML=@ActivityXML
			set @PrefValueDoc=0
			SELECT @PrefValueDoc=isnull(X.value('@IgnoreBatches','INT'),0)
			from @XML.nodes('/XML') as Data(X)    
			
			if(@PrefValueDoc<>1)
			BEGIN
				
				set @PrefValueDoc=0
				select @PrefValueDoc=isnull(X.value('@IgnoreBatches','INT'),0),@QtyFin=X.value('@Quantity','float')  
				from @TRANSXML.nodes('/Transactions') as Data(X)      
				
				if(@PrefValueDoc<>1 and @QtyFin>0)
				BEGIN 
					if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
						select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
					ELSE
						select @ProductName=ProductName from INV_Product with(nolock)
						where ProductID=@ProductID
					RAISERROR('-541',16,1)  
				END	    
			END	
		end
		ELSE if(@ProductType=2 and @IsQtyIgnored=0)
		begin
			if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
				select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
			ELSE
				select @ProductName=ProductName from INV_Product with(nolock)
				where ProductID=@ProductID
			RAISERROR('-542',16,1)      
		end
				
   end 
     
   
   if(@DocumentType=32)
	  BEGIN
		if(@LinkedID is not null and @LinkedID>0)
		BEGIN
			if((select count(LinkedInvDocDetailsID) from INV_DocDetails WITH(NOLOCK) where DocumentType=32 and LinkedInvDocDetailsID=@LinkedID)>1)
			BEGIN
					select @ProductName=voucherno from INV_DocDetails WITH(NOLOCK) 
					where DocumentType=32 and LinkedInvDocDetailsID=@LinkedID and InvDocDetailsID<>@InvDocDetailsID    
					RAISERROR('-518',16,1)
			END
		END	
		ELSE
		BEGIN
				set @DUPLICATECODE='set @QtyFin=(SELECT Count(D.ProductID) FROM INV_DocDetails D WITH(NOLOCK)			       
				WHERE D.ProductID='+convert(nvarchar,@ProductID) 
				if(@ProductType=5)
				BEGIN
				   set @BatchID=1
				   select @BatchID=isnull(X.value('@BatchID','INT'),1)
				   from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X) 
				   set @DUPLICATECODE=@DUPLICATECODE+' and Batchid='+CONVERT(nvarchar,@BatchID)
			   END
			   
			   set @DUPLICATECODE=@DUPLICATECODE+' and DocID='+CONVERT(nvarchar,@DocID)+' )'         
			      
				EXEC sp_executesql @DUPLICATECODE, N'@QtyFin float OUTPUT', @QtyFin OUTPUT   
				if(@QtyFin>1)
				BEGIN
					if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
						select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
					ELSE
						SELECT @ProductName=ProductName FROM INV_Product a WITH(NOLOCK)    
						WHERE  ProductID=@ProductID     
					RAISERROR('-519',16,1)
				END
		END
	  END
	  ELSE if(@DocumentType=31 and not exists(select Value from @TblPref where IsGlobal=0 and  Name='AllowDuplicate' and Value ='true'))
	  BEGIN
			set @WHERE=''
			if(@loc=1)
			BEGIN	
				if(@LocationID>0)
					set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@LocationID)        
				ELSE
				BEGIN
					set @sql='select @NID=dcCCNID2 from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
			
					EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
					set @WHERE =@WHERE+' and dcCCNID2='+CONVERT(nvarchar,@NID) 
				END	
			END

			if(@div=1)
			BEGIN	
				if(@DivisionID>0)
					set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@DivisionID)        
				ELSE
				BEGIN
					set @sql='select @NID=dcCCNID1 from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
			
					EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
					set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@NID) 
				END	
			END
			
			if(@dim>0)
			BEGIN
				set @sql='select @NID=dcCCNID'+convert(nvarchar,@dim) +' from COM_DocCCData with(nolock) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
				set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,@dim)+'='+CONVERT(nvarchar,@NID)        
			END
			
			set @DUPLICATECODE='set @QtyFin=(SELECT Count(D.ProductID) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID='+convert(nvarchar,@ProductID) 
			
			if(@ProductType=5)
			BEGIN
			   set @BatchID=1
			   set @RefInvID=0
			   select @BatchID=isnull(X.value('@BatchID','INT'),1),@RefInvID=X.value('@RefInvID','INT')
			   from @EXTRAXML.nodes('/EXTRAXML/xml/Row') as Data(X) 
			   set @DUPLICATECODE=@DUPLICATECODE+' and Batchid='+CONVERT(nvarchar,@BatchID)
			   if(@RefInvID is not null and @RefInvID>0)
				set @DUPLICATECODE=@DUPLICATECODE+' and RefInvDocDetailsID='+CONVERT(nvarchar,@RefInvID)
		   END
			
			
			set @DUPLICATECODE=@DUPLICATECODE+@WHERE+' and statusid=443 )'         
		      
			EXEC sp_executesql @DUPLICATECODE, N'@QtyFin float OUTPUT', @QtyFin OUTPUT 
			 
			print @DUPLICATECODE
			if(@QtyFin>1)
			BEGIN
				if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
					select @ProductName=ProductCode+'-'+ProductName from inv_product with(nolock) where ProductID=@ProductID     
				ELSE
					SELECT @ProductName=ProductName FROM INV_Product a WITH(NOLOCK)    
					WHERE  ProductID=@ProductID     
				RAISERROR('-519',16,1)
			END
			
	  END
   
    if(@PromXML is not null and @PromXML<>'')
    BEGIN
		if exists(select Value from @TblPref where IsGlobal=0 and Name='EnablePromotions' and Value='true')
		BEGIN		
			if exists(select Value from @TblPref where IsGlobal=1 and Name='Check for -Ve Stock' and Value='true')
				set @PrefValueDoc=1
			else
				set @PrefValueDoc=0
			
			SET @PromXML=REPLACE(@PromXML,'DynPromXML','EXTRAXML')  
			EXEC @return_value =[spDOC_SetDynamicSet] @DocID      
				 , @CostCenterID    
				 , @DocumentTypeID    
				 , @DocumentType,@DocOrder    
				 , @VoucherType     
				 , @VoucherNo    
				 , @VersionNo    
				 , @DocAbbr    
				 , @DocPrefix      
				 , @DocNumber      
				 , @DocDate      
				 , @DueDate      
				 , @StatusID      
				 , @BillNo      
				 , @BILLDate                  
				 ,@ACCOUNT1      
				 ,@ACCOUNT2       
				 ,@WID,@level,@CheckHold,@PromXML,@InvDocDetailsID,    
				  @RefCCID,@RefNodeid,@PrefValueDoc, @CompanyGUID,@Guid,                 
				   @UserName ,@LangID   
		END
		ELSE 
		BEGIN
			
			EXEC @return_value =[spDOc_SaveBudgetDocs]
			@Budgetxml=@PromXML,
			@INVDocDetailsID  =@InvDocDetailsID,
			@CompanyGUID =@CompanyGUID,
			@UserName =@UserName,
			@UserID =@UserID,
			@LangID =@LangID
		END	
    END
    
	 
	if exists(select Value from @TblPref where IsGlobal=0 and  Name='DumpStockCodes' and Value='true')    
	BEGIN
		set @DUPLICATECODE=''
		if(@IsImport=1)
		BEGIN
			select @DUPLICATECODE=X.value('@StockCode','nvarchar(max)')
			from @TRANSXML.nodes('/Transactions') as Data(X)      
			if(@DUPLICATECODE is not null and @DUPLICATECODE<>'')
				set @Iscode=4
			else
				set @Iscode=0
		END
		ELSE if(@HistoryStatus='Add')
			set @Iscode=0
		ELSE
			set @Iscode=1
				
		exec @return_value =spDoc_SetStockCode  @Action=@Iscode,
			  @ProductCall =0,
			  @Code =@DUPLICATECODE,
			  @ProductID =@ProductID,
			  @InvDocDetailsID =@InvDocDetailsID,
			  @DealerPrice= 0,
			  @RetailPrice =0,
			  @UOM ='',
			  @UserName=@UserName 
	END
	
	
	
	if(@DocumentType=55)
	BEGIN
		if(@HistoryStatus='Update')
		BEGIN
			set @BatchID=0
			select @BatchID=DocID,@CaseID=CostCenterID from INV_DocDetails WITH(NOLOCK)
			WHERE RefNodeid=@InvDocDetailsID and refccid=300
			if(@BatchID>0)
			BEGIN				    
			 EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]  
			 @CostCenterID = @CaseID,  
			 @DocPrefix = '',  
			 @DocNumber = '',
			 @DocID=@BatchID,
			 @UserID = @UserID,  
			 @UserName = @UserName,  
			 @LangID = @LangID,
			 @RoleID=@RoleID
			END 
		END
		  
		exec @return_value =spDOC_SetOpeningLoan
			@CostCenterID=@CostCenterID,    
			@DocID=@docid,
			@invID=@InvDocDetailsID,
			@LocationID=@LocationID,
			@DivisionID=@DivisionID,
			@DocDate=@DocDate,
			@DocNo=@DocNumber,
			@UserName =@UserName,
			@Userid =@Userid,
			@langID =@langID 
	END
	
	   
    if(@IsImport=1 and exists(SELECT ProductTypeID FROM INV_Product a   with(nolock)    
    WHERE  ProductID=@ProductID  and ProductTypeID=3)) 
    BEGIN
		INSERT INTO [INV_DocDetails]      
         ([DocID]      
         ,[CostCenterID]                     
         ,[DocumentType],DocOrder      
         ,[VoucherType]      
         ,[VoucherNo]      
         ,[VersionNo]      
         ,[DocAbbr]      
         ,[DocPrefix]      
         ,[DocNumber]      
         ,[DocDate] 
         ,ActDocDate     
         ,[DueDate]      
         ,[StatusID]      
         ,[BillNo]      
         ,BillDate      
         ,[LinkedInvDocDetailsID]      
         ,[LinkedFieldName]      
         ,[LinkedFieldValue]      
         ,[CommonNarration]      
         ,LineNarration      
         ,[DebitAccount]      
         ,[CreditAccount]      
         ,[DocSeqNo]      
         ,[ProductID]      
         ,[Quantity]      
         ,[Unit]      
         ,[HoldQuantity]    
         ,[ReserveQuantity]     
         ,[ReleaseQuantity]    
         ,[IsQtyIgnored]      
         ,[IsQtyFreeOffer]      
         ,[Rate]      
         ,[AverageRate]      
         ,[Gross]      
         ,[StockValue]      
         ,[CurrencyID]      
         ,[ExchangeRate]     
		   ,[GrossFC]    
			,[StockValueFC],UOMConversion,DynamicInvDocDetailsID
        ,UOMConvertedQty,WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID,RefNodeid,RefNo
        ,CreatedBy,CreatedDate,Account1,AP)
		SELECT  [DocID]      
         ,[CostCenterID]                     
         ,[DocumentType],DocOrder      
         ,[VoucherType]      
         ,[VoucherNo]      
         ,[VersionNo]      
         ,[DocAbbr]      
         ,[DocPrefix]      
         ,[DocNumber]      
         ,[DocDate]  
         ,ActDocDate    
         ,[DueDate]      
         ,a.[StatusID]      
         ,[BillNo]      
         ,BillDate      
         ,0      
         ,NULL      
         ,0      
         ,[CommonNarration]      
         ,LineNarration      
         ,[DebitAccount]      
         ,[CreditAccount]      
         ,[DocSeqNo]      
         ,b.[ProductID]      
         ,a.[Quantity]*b.[Quantity]
         ,c.UOMID
         ,[HoldQuantity]    
         ,[ReserveQuantity]     
         ,[ReleaseQuantity]    
         ,[IsQtyIgnored]      
         ,[IsQtyFreeOffer]      
         ,b.[Rate]      
         ,0
         ,a.[Quantity]*b.[Quantity]*b.[Rate]
         ,a.[Quantity]*b.[Quantity]*b.[Rate]    
         ,a.[CurrencyID]      
         ,[ExchangeRate]     
	     ,a.[Quantity]*b.[Quantity]*b.[Rate] 
		 ,[StockValueFC],1,@InvDocDetailsID                
         ,a.[Quantity]*b.[Quantity],a.WorkflowID , WorkFlowStatus , a.WorkFlowLevel,RefCCID,RefNodeid,RefNo
         , @UserName , @Dt 
         ,case when [DocumentType] in(1,39,27,26,25,2,34,6,3,4,13,41,42) then [CreditAccount] else [DebitAccount] end     
         ,@AP   
		FROM [INV_DocDetails] a WITH(NOLOCK)
		join INV_ProductBundles b WITH(NOLOCK) on a.ProductID=b.ParentProductID
		join INV_Product c WITH(NOLOCK) on b.ProductID=c.ProductID
		where a.InvDocDetailsID=@InvDocDetailsID
		
		INSERT INTO [COM_DocNumData] ([InvDocDetailsID])     
		select InvDocDetailsID
		from [INV_DocDetails] WITH(NOLOCK) where DynamicInvDocDetailsID=@InvDocDetailsID
		
		INSERT INTO [COM_DocTextData] ([InvDocDetailsID])     
		select InvDocDetailsID
		from [INV_DocDetails] WITH(NOLOCK) where DynamicInvDocDetailsID=@InvDocDetailsID
		
		set @sql='INSERT INTO [COM_DocCCData]  ([AccDocDetailsID]
           ,[InvDocDetailsID],'+@DocCC+'
          [ContactID]          
           ,[UserID])      
       select  NULL,b.InvDocDetailsID,'+@DocCC+'ContactID,USERID 
          from [COM_DocCCData]  a with(nolock),[INV_DocDetails] b WITH(NOLOCK)
          where DynamicInvDocDetailsID='+CONVERT(NVARCHAR(MAX),@InvDocDetailsID)+' and a.[InvDocDetailsID]='+CONVERT(NVARCHAR(MAX),@InvDocDetailsID) 
          
          exec(@sql)
          
          update INV_DocDetails
          set isqtyignored=1
          where [InvDocDetailsID]=@InvDocDetailsID
	END 
	
	
	if exists(select Value from @TblPref where IsGlobal=0 and  Name='UseasGiftVoucher' and Value ='true')
	BEGIn
		select @return_value=Value from @TblPref
		where IsGlobal=1 and  Name='PosCoupons' and isnumeric(Value)=1
		
		SET @DUPLICATECODE='select @NodeID=dcCCNID'+CONVERT(NVARCHAR,(@return_value-50000))+' from COM_DocCCData WITH(NOLOCK) WHERE InvDocDetailsID ='+CONVERT(NVARCHAR,@InvDocDetailsID)
		EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@tempDOc output	
		
		select @PrefValue=tablename from adm_features WITH(NOLOCK) where featureid=@return_value
		select @LEAVETYPE=Statusid from com_status WITH(NOLOCK) where featureid=@return_value and status='active'
		
		SET @DUPLICATECODE='update '+@PrefValue+' set statusid='+CONVERT(NVARCHAR,@LEAVETYPE)+'  WHERE statusid=476 and NodeID ='+CONVERT(NVARCHAR,@tempDOc)
		EXEC(@DUPLICATECODE)
				
	END
	
	if(@Dimesion>0 and exists(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='GenerateSeq' and Value='true'))    
	BEGIN 
		set @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+convert(nvarchar,@holseq)
		
		set @DimesionNodeID=0			
		
		if(@documenttype=45)		
		BEGIN
			SET @DUPLICATECODE='select @NodeID=dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+' from COM_DocCCData WITH(NOLOCK) WHERE InvDocDetailsID ='+CONVERT(NVARCHAR,@InvDocDetailsID)
			EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@DimesionNodeID output
			iF(@DimesionNodeID=1)
				set @DimesionNodeID=0
		END	
		ELSE
		BEGIN	
			select @cctablename=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@Dimesion
			set @DUPLICATECODE='select @NodeID=NodeID from '+@cctablename+' WITH(NOLOCK) where Name in ('''+@vno+''''	
			
			if(@tVersionNo>=1)  
				begin
					if exists(select value from @TblPref where IsGlobal=0 and Name='RevisPrefix' and Value is not null and Value<>'')
						select @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+Value+convert(nvarchar,@tVersionNo)+'/'+convert(nvarchar,@holseq)
						from @TblPref where IsGlobal=0 and Name='RevisPrefix' 					
					ELSE
						set	@vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+convert(nvarchar,@tVersionNo)+'/'+convert(nvarchar,@holseq)

				set @DUPLICATECODE=@DUPLICATECODE + ','''+@vno+''''
				end

				set @DUPLICATECODE=@DUPLICATECODE+')'	
							
			EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@DimesionNodeID output
		END
		

		--print @DUPLICATECODE
		if(@DimesionNodeID is null or (@DimesionNodeID<=0 and @DimesionNodeID>-10000))
		BEGIN
				
				set @CCStatusID = (select  statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active')
				
				SET @PrefValue=''    
				SELECT @PrefValue=Value FROM @TblPref where IsGlobal=0 and  Name='AutoCode'    
				if(@PrefValue='true')
				BEGIN	
						delete from @Codetemp
						 
						insert into @Codetemp
						EXEC [spCOM_GetCodeData] @Dimesion,1,''  
						
						select @ProductName=code,@CaseNumber= prefix, @CaseID=number from @Codetemp
				END
				ELSE
				BEGIN
					set @ProductName=@vno
					set @CaseNumber=''
					set @CaseID=0
				END
				set @SECTIONID=1
				
				if(@documenttype=45)
				BEGIN
					if exists(select dcalpha10 from com_docTextData WITH(NOLOCK) where invdocdetailsid=@InvDocDetailsID and isnumeric(dcalpha10)=1)					
					BEGIN
						select @SECTIONID=convert(INT,dcalpha10),@ProductName=dcalpha11 from com_docTextData WITH(NOLOCK) where invdocdetailsid=@InvDocDetailsID					
					END
					select  @CCStatusID = statusid from com_status where costcenterid=@Dimesion and status = 'Open'

				END
					
				EXEC @DimesionNodeID = [dbo].[spCOM_SetCostCenter]
					@NodeID = 0,@SelectedNodeID = @SECTIONID,@IsGroup = 0,
					@Code = @ProductName,
					@Name = @vno,
					@AliasName='',
					@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
					@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
					@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
					@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=1,
					@CodePrefix=@CaseNumber,@CodeNumber=@CaseID,
					@CheckLink = 0,@IsOffline=@IsOffline
				
				set @DimesionNodeID=0						
				select @cctablename=tablename from ADM_Features with(nolock) where FeatureID=@Dimesion
				set @DUPLICATECODE='select @NodeID=NodeID from '+@cctablename+' with(nolock) where Name='''+@vno+''''				
				EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@DimesionNodeID output				
		END
		
		if(@DimesionNodeID>0 or @DimesionNodeID<-10000)
		BEGIN
			set @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+convert(nvarchar,@holseq)

			if(@VersionNo>=1)  
			begin
				if exists(select value from @TblPref where IsGlobal=0 and Name='RevisPrefix' and Value is not null and Value<>'')
					select @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+Value+convert(nvarchar,@VersionNo)+'/'+convert(nvarchar,@holseq)
					from @TblPref where IsGlobal=0 and Name='RevisPrefix' 					
				ELSE
					set	@vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+convert(nvarchar,@VersionNo)+'/'+convert(nvarchar,@holseq)
			end

			select @cctablename=tablename from ADM_Features with(nolock) where FeatureID=@Dimesion
			set @DUPLICATECODE='update '+@cctablename+' set Name='''+convert(nvarchar(50),@vno)+''' where NodeID='+convert(nvarchar(50),@DimesionNodeID)
			
			exec(@DUPLICATECODE)

			SET @DUPLICATECODE='UPDATE COM_DocCCData 
			SET dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@DimesionNodeID)
			+' WHERE InvDocDetailsID ='+CONVERT(NVARCHAR,@InvDocDetailsID)
			EXEC(@DUPLICATECODE)
				
			Exec [spDOC_SetLinkDimension]
				@InvDocDetailsID=@InvDocDetailsID, 
				@Costcenterid=@CostCenterID,         
				@DimCCID=@Dimesion,
				@DimNodeID=@DimesionNodeID,
				@UserID=@UserID,    
				@LangID=@LangID    
		 END		     
	end
	
	if(@documenttype=45)
	BEGIN
		SELECT @DUPLICATECODE=CONVERT(NVARCHAR(MAX), X.query('ProjectPlanXML')) from @xml.nodes('/Row') as Data(X) 
	
		Exec @return_value =[spDoc_ProjectPlan]
			@InvDocDetID=@InvDocDetailsID,
			@DocID=@DocID,
			@CostCenterID=@CostCenterID,         
			@DimensionID=@Dimesion,
			@DimensionNodeID=@DimesionNodeID,		
			@ProjectXML =@DUPLICATECODE,
			@CompanyGUID=@CompanyGUID,
			@UserName=@UserName,      
			@UserID=@UserID,  
			@RoleID =@RoleID,  
			@LangID=@LangID        
	END
	
	
	if(@STATUSID=369 and (@oldStatus IS NULL OR @oldStatus<>369))
	begin
		if exists(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='PostAsset' and Value='true')
			EXEC @return_value =[spDoc_CreateAssets]      
				@InvDocDetID =@InvDocDetailsID,
				@CostCenterID =@CostCenterID,
				@ProductID =@ProductID,
				@DOCID=@DOCID,
				@VNO=@VoucherNo,
				@DT=@DocDate,	
				@XML=@DeprXML,			
				@CompanyGUID =@CompanyGUID,      				
				@UserName =@UserName,      
				@UserID =@UserID,      
				@LangID =@LangID
		else if @DocumentType=5 and @VoucherType=1 and convert(int,(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='DimTransferSrc'))>0
			EXEC spDoc_SetAssetTransfer @CostCenterID,@DOCID,@InvDocDetailsID
	END
  END      
      
   
     
    if(@DocumentType=32)
    BEGIN
		if exists(select b.docid from INV_DocDetails a WITH(NOLOCK)   
		join INV_DocDetails b WITH(NOLOCK)  on a.LinkedInvDocDetailsID=b.InvDocDetailsID 
		where a.CostCenterid=@CostCenterID and a.DocID =@DocID and b.DocumentType=31)
		BEGIN
			update INV_DocDetails
			set statusid=369
			where DocID=(select top 1 b.docid from INV_DocDetails a WITH(NOLOCK)   
			join INV_DocDetails b WITH(NOLOCK)  on a.LinkedInvDocDetailsID=b.InvDocDetailsID 
			where a.CostCenterid=@CostCenterID and a.DocID =@DocID and b.DocumentType=31)
		END
    END 
      
	set @PrefValue=''  
	select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='Checkallproducts'    
	if(@PrefValue='true')  
	begin  
	
		SELECT @QtyFin=count(InvDocDetailsID) from INV_DocDetails a WITH(NOLOCK)   
		where a.CostCenterid=@CostCenterID and a.DocID =@DocID

		select @QthChld=count(InvDocDetailsID)  from INV_DocDetails B WITH(NOLOCK) 
		where B.DocID in(select C.DOCID from INV_DocDetails c WITH(NOLOCK)
		join INV_DocDetails d with(nolock) on  c.InvDocDetailsID=d.LinkedInvDocDetailsID 
		Where d.CostCenterid=@CostCenterID and d.DocID =@DocID group by C.DOCID )
		
		if(@QtyFin>0 and @QthChld>0 and @QtyFin<>@QthChld)
		BEGIN
			RAISERROR('-514',16,1) 
		END
	END
	
	set @PrefValue=''  
	select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='DonotAllowtoLinkPostdatedDocuments'    
	if(@PrefValue='true')  
	begin
		IF EXISTS (SELECT IDD.DocDate,LIDD.DocDate FROM INV_DocDetails IDD WITH(NOLOCK)
		JOIN INV_DocDetails LIDD WITH(NOLOCK) ON LIDD.InvDocDetailsID=IDD.LinkedInvDocDetailsID AND IDD.DocDate<LIDD.DocDate
		WHERE IDD.DocID=@DocID)
		BEGIN
			RAISERROR('-574',16,1)
		END
	END
	
	if exists(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='OnPosted' and Value='true') and @StatusID<>369
		set @Dimesion=0
		
  --generate Line wise dimension
  if(@Dimesion>0 and not exists(SELECT Value FROM @TblPref where IsGlobal=0 and  Name='GenerateSeq' and Value='true'))    
  begin 
		set @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
		
		if(@DimesionNodeID is null or (@DimesionNodeID<=0 and @DimesionNodeID>-10000))
		BEGIN	
				set @CCStatusID = (select  statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active')
				
				SET @PrefValue=''    
				SELECT @PrefValue=Value FROM @TblPref where IsGlobal=0 and  Name='AutoCode'    
				if(@PrefValue='true')
				BEGIN
						
						delete from @Codetemp
						insert into @Codetemp
						EXEC [spCOM_GetCodeData] @Dimesion,1,''  
						
						select @ProductName=code,@CaseNumber= prefix, @CaseID=number from @Codetemp
				END
				ELSE
				BEGIN
					set @ProductName=@vno
					set @CaseNumber=''
					set @CaseID=0
				END
				--select @CCStatusID
				EXEC @DimesionNodeID = [dbo].[spCOM_SetCostCenter]
					@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
					@Code = @ProductName,
					@Name = @vno,
					@AliasName='',
					@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
					@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
					@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
					@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=1,
					@CodePrefix=@CaseNumber,@CodeNumber=@CaseID,
					@CheckLink = 0,@IsOffline=@IsOffline
				
				set @DimesionNodeID=0						
				select @cctablename=tablename from ADM_Features with(nolock) where FeatureID=@Dimesion
				set @DUPLICATECODE='select @NodeID=NodeID from '+@cctablename+' with(nolock) where Name='''+@vno+''''				
				EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@DimesionNodeID output				
		END
		
		if(@DimesionNodeID>0 or @DimesionNodeID<-10000)
		BEGIN
			
			if(@VersionNo>=1)  
			begin
				if exists(select value from @TblPref where IsGlobal=0 and Name='RevisPrefix' and Value is not null and Value<>'')
					select @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+Value+convert(nvarchar,@VersionNo)
					from @TblPref where IsGlobal=0 and Name='RevisPrefix' 					
				ELSE
					set	@vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+convert(nvarchar,@VersionNo)
			end

			set @CCStatusID = (select  statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active')
			select @cctablename=tablename from ADM_Features with(nolock) where FeatureID=@Dimesion
			set @DUPLICATECODE='update '+@cctablename+' set statusid='+convert(nvarchar(50),@CCStatusID)+',Name='''+convert(nvarchar(50),@vno)+''' where NodeID='+convert(nvarchar(50),@DimesionNodeID)
			exec(@DUPLICATECODE)
				
			SET @DUPLICATECODE='UPDATE COM_DocCCData 
			SET dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@DimesionNodeID)
			+' WHERE InvDocDetailsID IN (SELECT InvDocDetailsID FROM Inv_DocDetails with(nolock) 
			WHERE COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND DOCID='+CONVERT(NVARCHAR,@DocID)+')'
			EXEC(@DUPLICATECODE)
				
			Exec [spDOC_SetLinkDimension]
				@InvDocDetailsID=@InvDocDetailsID, 
				@Costcenterid=@CostCenterID,         
				@DimCCID=@Dimesion,
				@DimNodeID=@DimesionNodeID,
				@UserID=@UserID,    
				@LangID=@LangID    
		 END		     
 end   
  
   set @AUTOCCID=0
	SELECT @AUTOCCID=Value from @TblPref where IsGlobal=0 and  Name='ReserveRM' and Value is not null 
	and Value<>'' and Value<>'0' and isnumeric(Value)=1
	
	
	if (@AUTOCCID>0)    
	BEGIN
		select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='ResRMINVID' 
		exec @return_value =[spDoc_ReserveRM]
		@InvIDFld =@PrefValue,
		@CCID=@AUTOCCID,
		@DocID=@DocID ,		
		@CompanyGUID=@CompanyGUID,
		@UserName=@UserName ,
		@RoleID=@RoleID,
		@UserID=@UserID ,
		@LangID=@LangID
	END
	
	set @AUTOCCID=0
	SELECT @AUTOCCID=Value from @TblPref where IsGlobal=0 and  Name='ReleaseRMDOc' and Value is not null 
	and Value<>'' and Value<>'0' and isnumeric(Value)=1
	
	if (@AUTOCCID>0)    
	BEGIN
		set @indcnt=0
		SELECT @indcnt=Value from @TblPref where IsGlobal=0 and  Name='ResRMDOc' and Value is not null 
		and Value<>'' and Value<>'0' and isnumeric(Value)=1
		
		if(@indcnt=0)
			RAISERROR('Define Reserve Document',16,1)
		 exec @return_value =[spDoc_ReleaseRM]				
			@ResCCID=@indcnt,
			@CCID=@AUTOCCID,
			@DocID=@DocID ,		
			@CompanyGUID=@CompanyGUID,
			@UserName=@UserName ,
			@RoleID=@RoleID,
			@UserID=@UserID ,
			@LangID=@LangID
	END	
	
	if(@RefCCID=300)
	BEGIN  
		set @Columnname=''
		select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
		where costcenterid=@CostCenterID and 
		LocalReference is not null and LinkData is not null 
		 and LocalReference=79 and LinkData=50456

		if(@Columnname is not null and @Columnname like 'dcAlpha%')
		 begin
				select @vno =Voucherno from inv_DocDetails WITH(NOLOCK)
				where invDocDetailsID=@RefNodeid
			 set @TEMPxml='update COM_DocTextData
			 set '+@Columnname+'='''+@vno+''' 
			  where invDocDetailsID in (select invDocDetailsID from inv_DocDetails WITH(NOLOCK)
			 where DocID='+convert(nvarchar,@DocID)+')'	 
			 exec (@TEMPxml)
		end
	END  
	ELSE
	BEGIN
		--Reserved word - Print posted vouchers no in parent document
		set @Columnname=''
		select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
		where costcenterid=@CostCenterID and 
		LocalReference is not null and LinkData is not null 
		and LocalReference=79 and LinkData=50456 
		if(@Columnname is not null and @Columnname like 'dcAlpha%')
		begin
			declare @pvNos nvarchar(max)
			set @pvNos=''

			declare @ACC_PostedVNo NVARCHAR(max)
			set @ACC_PostedVNo = ''
			SELECT @ACC_PostedVNo=STUFF((SELECT ','+ a.VoucherNo from ACC_DocDetails a with(nolock) 
			JOIN ACC_DocDetails b WITH(NOLOCK) on b.AccDocDetailsID=a.RefNodeid
			WHERE b.DocID=@DocID  
			FOR XML PATH('') ),1,1,'')

			declare @INV_PostedVNo NVARCHAR(max)
			set @INV_PostedVNo = ''
			SELECT @INV_PostedVNo=STUFF((SELECT ','+ a.VoucherNo from INV_DocDetails a with(nolock) 
			JOIN INV_DocDetails b WITH(NOLOCK) on b.InvDocDetailsID=a.RefNodeid
			WHERE b.DocID=@DocID  
			FOR XML PATH('') ),1,1,'')

			if(@ACC_PostedVNo IS NOT NULL AND LEN(@ACC_PostedVNo)> 0)
				SET @pvNos+=@ACC_PostedVNo

			IF(@INV_PostedVNo IS NOT NULL AND @INV_PostedVNo!='')
			BEGIN
					IF(LEN(@pvNos)>0)
						set @pvNos+=','
					SET @pvNos+=@INV_PostedVNo
			END
			IF(@pvNos IS NOT NULL AND @pvNos!='')
				BEGIN
					set @TEMPxml='update COM_DocTextData
					set '+@Columnname+'='''+ @pvNos +''' 
					from  INV_DocDetails with(nolock)
					where INV_DocDetails.InvDocDetailsID=COM_DocTextData.InvDocDetailsID
					and DocID='+convert(nvarchar,@DocID)
					exec (@TEMPxml)
				END
			end
	END


   --GST VALIDATION
   if exists (select Value from adm_globalpreferences with(nolock) where name='GSTVersion') and (@DocumentType!=5 and @DocumentType!=8 and @DocumentType!=13 and @DocumentType!=30 and @DocumentType!=31 and @DocumentType!=32)
	and (exists (select Value from @TblPref where IsGlobal=0 and  Name='DonotupdateInventory' and Value='false') or
		 exists (select Value from @TblPref where IsGlobal=0 and  Name='DonotupdateAccounts' and Value='false'))
	exec spDOC_ValidateGST @CostCenterID,@vouchertype,@DOCID,@voucherno
	
	if exists(select Value from @TblPref where IsGlobal=0 and  Name='DonotupdateAccounts' and Value='false')
	BEGIN
		if exists(select * from inv_docdetails i WITH(NOLOCK)
		join acc_docdetails a WITH(NOLOCK) on i.invDocDetailsID=a.invDocDetailsID
		join acc_accounts dr WITH(NOLOCK) on a.DebitAccount=dr.accountid
		join acc_accounts cr WITH(NOLOCK) on a.CreditAccount=cr.accountid
		where i.costcenterid=@CostCenterID  and i.docid=@DocID and (dr.isgroup=1 or cr.isgroup=1))
					RAISERROR('-581',16,1)
		
	END

      
--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA    
    
SET @AuditTrial=0    
SELECT @AuditTrial=CONVERT(BIT,Value) FROM @TblPref where IsGlobal=0 and  Name='AuditTrial'    
  
SET @PrefValue=''    
SELECT @PrefValue=Value FROM @TblPref where IsGlobal=0 and  Name='EnableRevision' 
    
IF (@AuditTrial=1 or @PrefValue='true')  
BEGIN    
	 EXEC @return_value = [spDOC_SaveHistory]      
			@DocID =@DocID ,
			@HistoryStatus=@HistoryStatus,
			@Ininv =1,
			@ReviseReason =@ReviseReason,
			@LangID =@LangID,
			@UserName =@UserName,
			@ModDate =@Dt,
			@CCID=@CostCenterID
END    
   
   
      
  if(@BillWiseXML <>'')      
  BEGIN      
   SET @XML=@BillWiseXML
    if(@IsImport=1)      
   begin  
    
     declare @refSt int          
      --Read XML data into temporary table only to delete records   
    
    DECLARE @amt float,@accid INT,@IsNewReference bit,@RefDocNo nvarchar(200), @RefDocSeqNo int,@RefDocDate FLOAT,@RefDueDate FLOAT,@AdjCurrID INT,@AdjExchRT FLOAT      
    SELECT @I=1, @Cnt=count(ID) FROM @tblBILL        
           
    WHILE(@I<=@Cnt)        
    BEGIN      
      SELECT @accid=AccountID , @RefDocNo=DocNo,@amt=Amount,@AdjCurrID=AdjCurrID,@AdjExchRT=AdjExchRT FROM @tblBILL  WHERE ID=@I      
      
     IF EXISTS(SELECT  AccountID FROM ACC_Accounts with(nolock) WHERE IsBillwise=1 AND  AccountID=@accid)      
     BEGIN      
		 SELECT @RefDocSeqNo =DocSeqNo,@RefDocDate=DocDate,@RefDueDate=DueDate,@refSt=StatusID FROM ACC_DocDetails with(nolock)      
		 WHERE VoucherNo=@RefDocNo and (DebitAccount=@accid or CreditAccount=@accid)      
		 
		 if(@RefDocDate is null)      
		 begin      
		  SELECT @RefDocSeqNo =DocSeqNo,@RefDocDate=DocDate,@RefDueDate=DueDate,@refSt=StatusID FROM INV_DocDetails with(nolock)      
		  WHERE VoucherNo=@RefDocNo and (DebitAccount=@accid or CreditAccount=@accid)      
		 end
		        
		 if(@RefDocDate is null)      
			 set @IsNewReference=1      
		 else      
			 set @IsNewReference=0   
			    
      if(@ImpDocID is not null and @ImpDocID>0 and @IsNewReference=1
      and exists(select DocNo from [COM_Billwise] WITH(NOLOCK) where IsNewReference=1 and DocNo=@VoucherNo and AccountID=@accid))      
		BEGIN
			update [COM_Billwise]
			set AdjAmount=AdjAmount+@amt
			where IsNewReference=1 and DocNo=@VoucherNo and AccountID=@accid
		END
		ELSE
		BEGIN
			INSERT INTO [COM_Billwise]      
			 ([DocNo]      
			 ,[DocDate]      
			 ,[DocDueDate] ,StatusID,RefStatusID     
			   ,[DocSeqNo]      
			   ,[AccountID]      
			   ,[AdjAmount],AmountFC      
			   ,[AdjCurrID]      
			   ,[AdjExchRT]      
			   ,[DocType]      
			   ,[IsNewReference]      
			   ,[RefDocNo]      
			   ,[RefDocSeqNo]      
			   ,[RefDocDate]      
			   ,[RefDocDueDate]      
			   ,[Narration]      
			   ,[IsDocPDC]  )      
			 values(  @VoucherNo      
			 , CONVERT(FLOAT,@DocDate)      
			 , CONVERT(FLOAT,@DueDate),@StatusID,@refSt          
			   , 1      
			   , @accid      
			   , @amt
			   , (@amt*@AdjExchRT)       
			   , @AdjCurrID     
			   , @AdjExchRT    
			   , @DocumentType      
			   , @IsNewReference      
			   , @RefDocNo      
			   , @RefDocSeqNo      
			   , @RefDocDate      
			   , @RefDueDate      
			   , ''      
			   , 0      )
			   
			 set @DUPLICATECODE=@CC+' where docno='''+@VoucherNo+''' and InvDocDetailsID='+convert(nvarchar(max),@InvDocDetailsID)
			 exec(@DUPLICATECODE)
			 
   
		END
     END         
     SET @I=@I+1      
    END      
   end       
   else      
   begin
			
		   update com_billwise  
		   set RefDocNo=NULL,RefDocSeqNo=NULL,[IsNewReference]=1,[RefDocDueDate]=NULL  
		   where RefDocNo=@VoucherNo and RefDocSeqNo=1  
		   and AccountID not in (select  X.value('@AccountID','INT') from @XML.nodes('/BillWise/Row') as Data(X)  )   
		  
		  if(@wid<>0 and @STATUSID=369 and @oldStatus <>369)
		  BEGIN
				   update com_billwise  
				   set RefStatusid=@STATUSID
				   where RefDocNo=@VoucherNo and RefDocSeqNo=1  
				   and AccountID in (select  X.value('@AccountID','INT') from @XML.nodes('/BillWise/Row') as Data(X)  )   
		  END
				  
		  if(@documenttype=5)
		  BEGIN
		  	
			if(Charindex('InvDocDetID="1"',convert(nvarchar(max),@XML))>0)
			BEGIN
				select @prefixCCID=InvDocDetailsID from INV_DocDetails WITH(NOLOCK) where CostCenterID=@CostCenterID and DocID=@DocID and VoucherType=1
				set @XML=REPLACE(convert(nvarchar(max),@XML),'InvDocDetID="1"','InvDocDetID="'+convert(nvarchar,@prefixCCID)+'"')
			 END
			 
			if(Charindex('InvDocDetID="-1"',convert(nvarchar(max),@XML))>0)
			BEGIN
				select @prefixCCID=InvDocDetailsID from INV_DocDetails WITH(NOLOCK) where CostCenterID=@CostCenterID and DocID=@DocID and VoucherType=-1
				set @XML=REPLACE(convert(nvarchar(max),@XML),'InvDocDetID="-1"','InvDocDetID="'+convert(nvarchar,@prefixCCID)+'"')
			 END
		  
		  set @DUPLICATECODE='INSERT INTO [COM_Billwise]      
			 ([DocNo]      
			 ,[DocDate]      
			 ,[DocDueDate]      
			   ,[DocSeqNo],BillNo,BillDate,StatusID,RefStatusID      
			   ,[AccountID]      
			   ,[AdjAmount]      
			   ,[AdjCurrID]      
			   ,[AdjExchRT],AmountFC      
			   ,[DocType]      
			   ,[IsNewReference]      
			   ,[RefDocNo]      
			   ,[RefDocSeqNo]      
			 ,[RefDocDate]      
			 ,[RefDocDueDate]      
			 ,[RefBillWiseID]      
			   ,[DiscAccountID]      
			   ,[DiscAmount]      
			   ,[DiscCurrID]      
			   ,[DiscExchRT]      
			   ,[Narration]      
			   ,[IsDocPDC]      
			   ,'+@CC+')      
			 SELECT @VoucherNo      
			  , '+CONVERT(nvarchar,convert(float,@DocDate))+'
			 , '
			 
			 if(@DueDate is null)
				 set @DUPLICATECODE=@DUPLICATECODE+'NULL'
			 else	
				set @DUPLICATECODE=@DUPLICATECODE+CONVERT(nvarchar,convert(float,@DueDate))
			 
			 set @DUPLICATECODE=@DUPLICATECODE+'    
			   , X.value(''@DocSeqNo'',''int''),'''+replace(@BillNo,'''','''''')+''','
			 
			 if(@BILLDate is null)
				 set @DUPLICATECODE=@DUPLICATECODE+'NULL'
			 else	
				set @DUPLICATECODE=@DUPLICATECODE+CONVERT(nvarchar,convert(float,@BILLDate))
			 
			 set @DUPLICATECODE=@DUPLICATECODE+','+CONVERT(nvarchar,convert(float,@StatusID))+',X.value(''@RefStatusID'',''int'')
			   , X.value(''@AccountID'',''INT'')      
			   , replace(X.value(''@AdjAmount'',''nvarchar(50)''),'','','''')    
			   , X.value(''@AdjCurrID'',''int'')      
			   , X.value(''@AdjExchRT'',''float'')  ,replace(X.value(''@AmountFC'',''nvarchar(50)''),'','','''')     
			   , '+CONVERT(nvarchar,@DocumentType)+'
			   , X.value(''@IsNewReference'',''bit'')      
			   , X.value(''@RefDocNo'',''nvarchar(200)'')      
			   , X.value(''@RefDocSeqNo'',''int'')      
			 , CONVERT(FLOAT,X.value(''@RefDocDate'',''DATETIME''))      
			 , CONVERT(FLOAT,X.value(''@RefDueDate'',''DATETIME''))      
			   , X.value(''@RefBillWiseID'',''INT'')      
			   , X.value(''@DiscAccountID'',''INT'')      
			   , X.value(''@DiscAmount'',''float'')      
			   , X.value(''@DiscCurrID'',''int'')      
			   , X.value(''@DiscExchRT'',''float'')      
			   , X.value(''@Narration'',''nvarchar(max)'')      
			   , X.value(''@IsDocPDC'',''bit'')      
			   ,'+@CC +'
			 from @XML.nodes(''/BillWise/Row'') as Data(X)      
			 join [COM_DocCCData]  d WITH(NOLOCK)on d.InvDocDetailsID=X.value(''@InvDocDetID'',''INT'') '
			  EXEC sp_executesql @DUPLICATECODE,N'@VoucherNo nvarchar(200),@XML xml',@VoucherNo, @XML

		  END
		  ELSE if exists(select Value from @TblPref where Name='BillwisePosting' and Value='1')
		  BEGIN
			set @DUPLICATECODE='INSERT INTO [COM_Billwise]      
			 ([DocNo],[DocDate],[DocDueDate],[DocSeqNo],BillNo,BillDate,StatusID,RefStatusID      
			   ,[AccountID],[AdjAmount],[AdjCurrID],[AdjExchRT],AmountFC,[DocType],[IsNewReference],[RefDocNo]      
			   ,[RefDocSeqNo],[RefDocDate],[RefDocDueDate],[RefBillWiseID],[DiscAccountID],[DiscAmount],[DiscCurrID]      
			   ,[DiscExchRT],[Narration],[IsDocPDC],'+@CC+')
			 SELECT @VoucherNo      
			 , '+CONVERT(nvarchar,convert(float,@DocDate))+'
			 , '
			 if(@DueDate is null)
				 set @DUPLICATECODE=@DUPLICATECODE+'NULL'
			 else	
				set @DUPLICATECODE=@DUPLICATECODE+CONVERT(nvarchar,convert(float,@DueDate))
			 
			 set @DUPLICATECODE=@DUPLICATECODE+' , X.value(''@DocSeqNo'',''int''),'''+replace(@BillNo,'''','''''')+''','
			 
			 if(@BILLDate is null)
				 set @DUPLICATECODE=@DUPLICATECODE+'NULL'
			 else	
				set @DUPLICATECODE=@DUPLICATECODE+CONVERT(nvarchar,convert(float,@BILLDate))
			 
			 set @DUPLICATECODE=@DUPLICATECODE+','+CONVERT(nvarchar,convert(float,@StatusID))+',X.value(''@RefStatusID'',''int'')
			   , X.value(''@AccountID'',''INT'')      
			   , replace(X.value(''@AdjAmount'',''nvarchar(50)''),'','','''')    
			   , X.value(''@AdjCurrID'',''int'')      
			   , X.value(''@AdjExchRT'',''float'')  ,replace(X.value(''@AmountFC'',''nvarchar(50)''),'','','''')     
			   , '+CONVERT(nvarchar,@DocumentType)+'      
			   , X.value(''@IsNewReference'',''bit'')      
			   , X.value(''@RefDocNo'',''nvarchar(200)'')      
			   , X.value(''@RefDocSeqNo'',''int'')      
			 , CONVERT(FLOAT,X.value(''@RefDocDate'',''DATETIME''))      
			 , CONVERT(FLOAT,X.value(''@RefDueDate'',''DATETIME''))      
			   , X.value(''@RefBillWiseID'',''INT'')      
			   , X.value(''@DiscAccountID'',''INT'')      
			   , X.value(''@DiscAmount'',''float'')      
			   , X.value(''@DiscCurrID'',''int'')      
			   , X.value(''@DiscExchRT'',''float'')      
			   , X.value(''@Narration'',''nvarchar(max)'')      
			   , X.value(''@IsDocPDC'',''bit'')      
			   , '+@CC+'
			 from @XML.nodes(''/BillWise/Row'') as Data(X)  
			 join INV_DocDetails a WITH(NOLOCK) on X.value(''@DocSeqNo'',''int'')=a.docseqno
			 join [COM_DocCCData]  d WITH(NOLOCK) on d.InvDocDetailsID=a.InvDocDetailsID
			 where CostCenterID='+convert(nvarchar,@CostCenterID)+' and DocID='+convert(nvarchar,@DocID)
			 EXEC sp_executesql @DUPLICATECODE,N'@VoucherNo nvarchar(200),@XML xml',@VoucherNo, @XML

		  END
		  ELSE
		  BEGIN
			set @DUPLICATECODE='INSERT INTO [COM_Billwise]      
			 ([DocNo],[DocDate],[DocDueDate],[DocSeqNo],BillNo,BillDate,StatusID,RefStatusID      
			   ,[AccountID],[AdjAmount],[AdjCurrID],[AdjExchRT],AmountFC,[DocType],[IsNewReference],[RefDocNo]      
			   ,[RefDocSeqNo],[RefDocDate],[RefDocDueDate],[RefBillWiseID],[DiscAccountID],[DiscAmount],[DiscCurrID]      
			   ,[DiscExchRT],[Narration],[IsDocPDC],VatAdvance,'+@CC+')
			 SELECT @VoucherNo      
			 , '+CONVERT(nvarchar,convert(float,@DocDate))+'
			 , '
			 
			 if exists(select Value from @TblPref where Name='BillwisePosting' and Value='2')
				set @DUPLICATECODE=@DUPLICATECODE+'convert(float,X.value(''@DueDate'',''datetime''))'
			 else if(@DueDate is null)
				set @DUPLICATECODE=@DUPLICATECODE+'NULL'
			 else	
				set @DUPLICATECODE=@DUPLICATECODE+CONVERT(nvarchar,convert(float,@DueDate))
			 
			 set @DUPLICATECODE=@DUPLICATECODE+'
			   , X.value(''@DocSeqNo'',''int''),'''+replace(@BillNo,'''','''''')+''','
			 
			 if(@BILLDate is null)
				set @DUPLICATECODE=@DUPLICATECODE+'NULL'
			 else	
				set @DUPLICATECODE=@DUPLICATECODE+CONVERT(nvarchar,convert(float,@BILLDate))
			 
			 set @DUPLICATECODE=@DUPLICATECODE+','+CONVERT(nvarchar,convert(float,@StatusID))+',X.value(''@RefStatusID'',''int'')
			   , X.value(''@AccountID'',''INT'')      
			   , replace(X.value(''@AdjAmount'',''nvarchar(50)''),'','','''')    
			   , X.value(''@AdjCurrID'',''int'')      
			   , X.value(''@AdjExchRT'',''float'')  ,replace(X.value(''@AmountFC'',''nvarchar(50)''),'','','''')     
			   , '+CONVERT(nvarchar,@DocumentType)+'      
			   , X.value(''@IsNewReference'',''bit'')      
			   , X.value(''@RefDocNo'',''nvarchar(200)'')      
			   , X.value(''@RefDocSeqNo'',''int'')      
			 , CONVERT(FLOAT,X.value(''@RefDocDate'',''DATETIME''))      
			 , CONVERT(FLOAT,X.value(''@RefDueDate'',''DATETIME''))      
			   , X.value(''@RefBillWiseID'',''INT'')      
			   , X.value(''@DiscAccountID'',''INT'')      
			   , X.value(''@DiscAmount'',''float'')      
			   , X.value(''@DiscCurrID'',''int'')      
			   , X.value(''@DiscExchRT'',''float'')      
			   , X.value(''@Narration'',''nvarchar(max)'')      
			   , X.value(''@IsDocPDC'',''bit'') , X.value(''@VatAdvance'',''float'')     
			   ,'+@CC+'
			 from @XML.nodes(''/BillWise/Row'') as Data(X)      
			 join [COM_DocCCData]  d WITH(NOLOCK)on d.InvDocDetailsID='+convert(nvarchar(max),@InvDocDetailsID)
			 --select @DUPLICATECODE,@DueDate,@BillNo,@BILLDate,@StatusID,@DocumentType,@XML
			--print @DUPLICATECODE
			 EXEC sp_executesql @DUPLICATECODE,N'@VoucherNo nvarchar(200),@XML xml',@VoucherNo, @XML


				INSERT INTO ACC_DocDetails      
				 (InvDocDetailsID  
				 ,[DocID]  
				 ,VOUCHERNO      
				 ,[CostCenterID]      				       
				 ,[DocumentType]      
				 ,[VersionNo]      
				 ,[DocAbbr]      
				 ,[DocPrefix]      
				 ,[DocNumber]      
				 ,[DocDate]
				 ,ActDocDate      
				 ,[DueDate]      
				 ,[StatusID]      
				 ,[BillNo]      
				 ,BillDate      
				 ,[CommonNarration]      
				 ,LineNarration      
				 ,[DebitAccount]      
				 ,[CreditAccount]      
				 ,[Amount]      
				 ,[DocSeqNo]      
				 ,[CurrencyID]      
				 ,[ExchangeRate]     
				 ,[AmountFC]     				      
				 ,[CreatedBy]      
				 ,[CreatedDate]  
				 ,WorkflowID   
				 ,WorkFlowStatus   
				 ,WorkFlowLevel  
				 ,RefCCID  
				 ,RefNodeid,AP)      
		            
				SELECT @InvDocDetailsID,0,@VoucherNo      
				 , @CostCenterID      				     
				 , @DocumentType      
				 , @VersionNo     
				 , @DocAbbr      
				 , @DocPrefix      
				 , @DocNumber      
				 , CONVERT(FLOAT,@DocDate)
				 , @ActDocDate      
				 , CONVERT(FLOAT,@DueDate)      
				 , @StatusID      
				 , @BillNo      
				 , @BILLDate      
				 , ''      
				 , ''
				 ,ISNULL( X.value('@DebitAccount','INT'),0)
				 ,ISNULL( X.value('@CreditAccount','INT'),0)
				 , replace(X.value('@Amount','nvarchar(50)') ,',','')     
				 , 1
				 , ISNULL(X.value('@CurrencyID','int'),1)      
				 , ISNULL(X.value('@ExchangeRate','float'),1)      
				 , ISNULL(X.value('@AmtFc','FLOAT'),X.value('@Amount','FLOAT'))     				            
				 , @UserName      
				 , @Dt    
				 , @WID  
				 , @StatusID  
				 , @level   
				 , @RefCCID  
				 , @RefNodeid,@AP
				   from @XML.nodes('/BillWise/AccountsRow') as Data(X) 
           
			 if exists(select Value from @TblPref where Name='BillwisePosting' and Value='2')
			 BEGIN
				  set @accid=0
				  select @accid=X.value('@DimCCID','int')
				  from @XML.nodes('/BillWise/Row') as Data(X) 
				  where X.value('@DimCCID','int') is not null and X.value('@DimCCID','int')>50000
				 
				 if(@accid is not null and @accid>0)
				 BEGIN   
					 set @DUPLICATECODE=' update [COM_Billwise]
					 set dcCCNID'+convert(nvarchar,(@accid-50000))+'= X.value(''@DimNodeID'',''INT'')   
					 from @XML.nodes(''/BillWise/Row'') as Data(X)      
					 where X.value(''@DimNodeID'',''INT'') is not null and X.value(''@DimNodeID'',''INT'')>0 and DocNo=@VoucherNo and DocSeqNo=X.value(''@DocSeqNo'',''int'')'
					 
					 EXEC sp_executesql @DUPLICATECODE,N'@VoucherNo nvarchar(200),@XML xml',@VoucherNo, @XML
					 
				 END
			 
				if exists(select a.DocNo from COM_Billwise a WITH(NOLOCK)
				join COM_Billwise b WITH(NOLOCK) on a.DocNo=b.RefDocNo and a.DocSeqNo=b.RefDocSeqNo and a.AccountID=b.AccountID  
				where a.IsNewReference=1 and b.IsNewReference=0 and a.DocNo=@VoucherNo
				group by a.DocNo,a.DocSeqNo,a.AccountID
				having abs(SUM(a.AdjAmount))-abs(SUM(b.AdjAmount))<-0.001)
					RAISERROR('-556',16,1)
				if exists(select a.DocNo from COM_Billwise a WITH(NOLOCK)
				left join COM_Billwise b WITH(NOLOCK) on b.DocNo=a.RefDocNo and b.DocSeqNo=a.RefDocSeqNo and a.AccountID=b.AccountID  
				where a.RefDocNo=@VoucherNo and b.DocNo is null)
					RAISERROR('-556',16,1)
				
				set @Accid=0
				if(@DocumentType=1 or @DocumentType=39 or @DocumentType=27 or @DocumentType=26 or @DocumentType=25 or @DocumentType=2  or @DocumentType=34 or @DocumentType=6 or @DocumentType=3 or @DocumentType=4 or @DocumentType=13)      
					select @Accid=Creditaccount from inv_docdetails WITH(NOLOCK) where invdocdetailsid=@invdocdetailsid
				else 
					select @Accid=debitaccount from inv_docdetails WITH(NOLOCK) where invdocdetailsid=@invdocdetailsid
					
				update COM_Billwise
				set narration=nom
				from (select  row_number()over (order by billwiseid) nom, * 
				from COM_Billwise WITH(NOLOCK)
				where accountid=@Accid and isnewreference=1 and docno=@VoucherNo) as t
				where t.billwiseid=COM_Billwise.billwiseid
				
				select @I=count(*) from COM_Billwise WITH(NOLOCK) where  accountid=@Accid and  isnewreference=1 and docno=@VoucherNo
				
				update COM_Billwise
				set narration=narration+'/'+convert(nvarchar,@I)
				where  accountid=@Accid and isnewreference=1 and docno=@VoucherNo 
				
			 END
			 
			 
			 insert into COM_BillWiseNonAcc(DocNo,DocSeqNo,RefDocNo,Amount,AccountID)
			 SELECT @VoucherNo,1,X.value('@RefDocNo','nvarchar(200)'), replace(X.value('@Amount','nvarchar(50)'),',','')    , X.value('@AccountID','INT')
			 from @XML.nodes('/BillWise/NonAccRows') as Data(X)    
			 
			END 
			
			if(@fromvno<>'')
			BEGIN
				set @Sql=' update COM_Billwise 
					set FromDocNo='''+@fromvno+'''
					where DocNo='''+@VoucherNo+''''
					print @Sql
				EXEC (@Sql)
			END
     END    
  END      
  
  
	set @PrefValue=''
	SELECT @PrefValue=Value FROM @TblPref where IsGlobal=0 and  Name='Paypercent'   
	if(@PrefValue like 'dcalpha%')
	BEGIN
		set @amt=0
		set @DUPLICATECODE='select @amt='+@PrefValue+' from com_doctextdata WITH(NOLOCK)			 
			  where isnumeric('+@PrefValue+')=1 and invDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			  
		EXEC sp_executesql @DUPLICATECODE,N'@amt float output',@amt output
		
		if(@amt>0)
		BEGIN
			set @PrefValue=''
			SELECT @PrefValue=Value FROM @TblPref where IsGlobal=1 and  Name='NetFld'  
			set @AUTOCCID=0
			SELECT @AUTOCCID=Value FROM @TblPref where IsGlobal=0 and  Name='ValueType' 
			and ISNUMERIC(value)=1 
 
			if(@PrefValue like 'dcnum%' and @AUTOCCID>40000)
			BEGIN
				declare @tabvchrs table(vchrs nvarchar(200),typ int,ccid int)
			
				insert into @tabvchrs(vchrs,typ,ccid)values(@VoucherNo,1,@CostCenterID)
				
				set @cnt=1
				while exists(select vchrs from @tabvchrs where typ=@cnt)
				BEGIN
				
					insert into @tabvchrs
					select b.voucherno,@cnt+1,b.CostCenterID from INV_DocDetails a WITH(NOLOCK)
					join INV_DocDetails b WITH(NOLOCK) on a.linkedInvDocdetailsid=b.InvDocdetailsid
					join @tabvchrs c on a.VoucherNo=c.vchrs 
					where c.typ=@cnt and a.linkedInvDocdetailsid>0
					
					set @cnt=@cnt+1
					
				END
				
				set @vno=''
				select @vno=@vno+''''+vchrs+''''+',' from @tabvchrs
				where ccid=@AUTOCCID
				
				if(LEN(@vno)>1)
					set @vno=SUBSTRING(@vno,0,len(@vno))
				
				set @SQL='select @QthChld=isnull(sum('+@PrefValue+'),0) from INV_DocDetails a With(nolock)
				join COM_DocNumData b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID
				where a.VoucherNo in('+@vno+')'
				 
				print @SQL
				set @QthChld=0	
				EXEC sp_executesql @SQL,N'@QthChld float output',@QthChld output
				
				set @vno=''
				select @vno=@vno+''''+vchrs+''''+',' from @tabvchrs
					
				if(LEN(@vno)>1)
					set @vno=SUBSTRING(@vno,0,len(@vno))

				set @SQL='select @QtyFin= isnull(sum(Amount),0) from COM_BillWiseNonAcc WITH(NOLOCK)
				where RefDocNo in('+@vno+')'
				
				set @QtyFin=0	
				EXEC sp_executesql @SQL,N'@QtyFin float output',@QtyFin output

				if(@QthChld>0)
					set @QthChld=floor((@QthChld*@amt)/100)
				
				if(@QthChld>@QtyFin)
					RAISERROR('-552',16,1)
			END
		END
	END    
      

  --Inserts Multiple Notes      
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')      
  BEGIN      
   SET @XML=@NotesXML      
      
   --If Action is NEW then insert new Notes      
   INSERT INTO COM_Notes(FeatureID,FeaturePK,Note,         
   GUID,CreatedBy,CreatedDate)      
   SELECT @CostCenterID,@DocID,Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),      
   @Guid,@UserName,@Dt      
   FROM @XML.nodes('/NotesXML/Row') as Data(X)      
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'      
      
   --If Action is MODIFY then update Notes      
   UPDATE COM_Notes      
   SET Note=Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),    
    GUID=@Guid,      
    ModifiedBy=@UserName,      
    ModifiedDate=@Dt      
   FROM COM_Notes C       
   INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)        
   ON convert(INT,X.value('@NoteID','INT'))=C.NoteID      
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'      
      
   --If Action is DELETE then delete Notes      
   DELETE FROM COM_Notes      
   WHERE NoteID IN(SELECT X.value('@NoteID','INT')      
    FROM @XML.nodes('/NotesXML/Row') as Data(X)      
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE')      
  END      
       
--  
  --Inserts Multiple Attachments      
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')      
  BEGIN      
   SET @XML=@AttachmentsXML      
      
   INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,      
   FileExtension,FileDescription,IsProductImage,AllowInPrint,FeatureID,FeaturePK,      
   GUID,CreatedBy,CreatedDate,RowSeqNo,ColName,IsDefaultImage,ValidTill,RefNo,IsSign,status,DocNo,Remarks,Type,RefNum)      
   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),      
   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),X.value('@AllowInPrint','bit'),@CostCenterID,@DocID,      
   X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt,X.value('@RowSeqNo','int'),X.value('@ColName','NVARCHAR(100)'),X.value('@IsDefaultImage','smallint')      
   ,convert(float,X.value('@Validtill','Datetime')),X.value('@RefNo','NVARCHAR(max)'),ISNULL(X.value('@IsSign','bit'),0),X.value('@stat','int')
   ,X.value('@DocNo','NVARCHAR(max)'),X.value('@Remarks','NVARCHAR(max)'),X.value('@Type','INT'),X.value('@RefNo','NVARCHAR(max)')
   FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)        
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'      
      
   --If Action is MODIFY then update Attachments      
   UPDATE COM_Files      
   SET FilePath=X.value('@FilePath','NVARCHAR(500)'),      
    ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),      
    RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),      
    FileExtension=X.value('@FileExtension','NVARCHAR(50)'),      
    FileDescription=X.value('@FileDescription','NVARCHAR(500)'),      
    IsProductImage=X.value('@IsProductImage','bit'),
    AllowInPrint=X.value('@AllowInPrint','bit'),
	IsDefaultImage=X.value('@IsDefaultImage','smallint'),
    GUID=X.value('@GUID','NVARCHAR(50)'),      
    ModifiedBy=@UserName,      
    ModifiedDate=@Dt   
    ,ValidTill=convert(float,X.value('@Validtill','Datetime'))   
	,IsSign=ISNULL(X.value('@IsSign','bit'),0)
	,status=X.value('@stat','int')
	,DocNo=X.value('@DocNo','NVARCHAR(max)')
	,Remarks=X.value('@Remarks','NVARCHAR(max)')
	,Type=X.value('@Type','INT')
	,RefNum=X.value('@RefNo','NVARCHAR(max)')
   FROM COM_Files C  with(nolock)      
   INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X)        
   ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID      
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'      
      
   --If Action is DELETE then delete Attachments      
   DELETE FROM COM_Files      
   WHERE FileID IN(SELECT X.value('@AttachmentID','INT')      
    FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)      
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE') 
    
    	print @AttachmentsXML
		UPDATE COM_Files
		SET ValidTill=convert(float,X.value('@Validtill','Datetime'))						
			,RefNum=X.value('@RefNo','NVARCHAR(max)'),Remarks=X.value('@Remarks','NVARCHAR(max)')
			,RowSeqNo=X.value('@RowSeqNo','int')
			,status=X.value('@stat','int')
		FROM COM_Files C with(nolock)
		INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X) 	
		ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFYText'
		     
  END      
         
         
 END    
   
	DELETE FROM COM_DocAddressData WHERE DocId = @DOCID    
    
	IF (@DocAddress IS NOT NULL AND @DocAddress <> '')      
	BEGIN      
		SET @XML=@DocAddress 

		INSERT INTO COM_DocAddressData(AccDocDetailsId,InvDocDetailsId,    
		AddressHistoryID,AddressTypeID,[CreatedBy],[CreatedDate]
		,addressid,DocId)
		SELECT  0,@InvDocDetailsID,t.ID,X.value('@TypeID','INT')  
		,@UserName,@Dt,X.value('@AddressID','INT'),@DOCID
		FROM @XML.nodes('/DOCADDXML/Row') as Data(X) 
		left join (select AddressID,MAX(AddressHistoryID) ID from COM_ADDRESS_HISTORY with(nolock)
		where FeatureID=2 and FeaturePK in(@ACCOUNT1,@ACCOUNT2)
		group by AddressID) as t on X.value('@AddressID','INT')=t.AddressID
		WHERE X.value('@AddressID','INT') IS NOT NULL   AND X.value('@AddressID','INT') <> 0      

	END     
  
  delete from [COM_DocPayTerms] where VoucherNo=@VoucherNo
  
  if(@DocumentType=38 or @DocumentType=39 or @DocumentType=50)
  BEGIN
	 if (@DocumentType=39)
	 BEGIN
		 if exists(select a.VoucherType from COM_PosPayModes a WITH(NOLOCK)
		 join COM_PosPayModes b WITH(NOLOCK) on a.VoucherNodeID=b.VoucherNodeID
		 where b.VoucherType=-1 and a.DOCID=@DocID)
		 BEGIN
				RAISERROR('-524',16,1)  
		 END
		 
		     if exists(select VoucherType from COM_PosPayModes a WITH(NOLOCK)
				where DOCID=@DocID and VoucherNodeID>0)
			  BEGIN
					
					INSERT INTO @tblBILL(AccountID)      
					SELECT VoucherNodeID FROM COM_PosPayModes with(nolock)
					where DOCID=@DocID and VoucherNodeID>0
					
					delete P from COM_PosPayModes P WITH(NOLOCK) where DOCID=@DocID	
					
					SELECT @I=1, @Cnt=count(ID) FROM @tblBILL        
				    
				    select @PrefValue=Value from @TblPref where IsGlobal=1 and  Name='PosCoupons'    
					set @Dimesion=0
					if(@PrefValue is not null and @PrefValue<>'' and ISNUMERIC(@PrefValue)=1)
					begin						
						begin try
							select @Dimesion=convert(INT,@PrefValue)
						end try
						begin catch
							set @Dimesion=0
						end catch
					END
				           
					WHILE(@I<=@Cnt and @Dimesion>50000)        
					BEGIN      
					  SELECT @accid=AccountID FROM @tblBILL  WHERE ID=@I
					  
					  EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
						@CostCenterID = @Dimesion,
						@NodeID = @accid,
						@RoleID=1,
						@UserID = 1,
						@LangID = @LangID						
				
					  set @I=@I+1
				    END   
			  END
		END
	 
	delete P from COM_PosPayModes P WITH(NOLOCK) where p.DOCID=@DocID
	delete p from COM_DocDenominations P WITH(NOLOCK) where p.DOCID=@DocID
  END

  if exists(select * from @TblPref 
  where Name ='UseasOpeningDownPayment' and Value ='true' and IsGlobal=0)
  BEGIN
		set @hideBillNo=0
		if exists(select * from @TblPref 
		where Name ='CreditSupplierDownPayment' and Value ='true')
			set @hideBillNo=1
      
		exec @return_value=[dbo].[spDoc_OpeningDownPayment] 
		 @VoucherNo =@VoucherNo,
		 @CostCenterID =@CostCenterID,
		 @DocID =@DocID,
		 @InvDocDetID=@InvDocDetailsID,
		 @crAcc =@ACCOUNT2,
		 @DrAcc=@ACCOUNT1,
		 @DocDate =@DocDate,
		 @PostCredit=@hideBillNo,
		 @LocationID =@LocationID,
		 @DivisionID =@DivisionID,
		 @CompanyGUID =@CompanyGUID,
		 @UserName =@UserName,
		 @RoleID =@RoleID,
		 @UserID =@UserID,  
		 @LangID =@LangID  
  END
  
  if(@ActivityXML<>'')
  begin
		
		set @XML=@ActivityXML
		 set @DUPLICATECODE=''
		 set @PrefValue=''
		 set @TYPE=''
		SELECT @AppRejDate=X.value('@AppRejDate','Datetime'),@Remarks=X.value('@Remarks','nvarchar(max)')
		,@DUPLICATECODE=isnull(X.value('@WorkFlow','nvarchar(100)'),''),@TYPE=X.value('@TZ','nvarchar(max)'),@PrefValue=X.value('@IOType','nvarchar(max)')
		,@TEMPxml=CONVERT(NVARCHAR(MAX), X.query('ScheduleActivityXml'))
		,@WHERE=isnull(X.value('@BudQtyWhere','nvarchar(max)'),''),@CaseID=X.value('@BudID','INT'),@AccLockDate=X.value('@BudStartDate','Datetime')
		from @XML.nodes('/XML') as Data(X)    		         
		
		if(@PrefValue is not null and @PrefValue<>'' and @TYPE is not null and @TYPE<>'')
		BEGIN
			set @SQL='
			declare @dt datetime =SYSDATETIMEOFFSET() at time zone  '''+@TYPE+''',@utcdt datetime=getutcdate()
			Update b
			set '
			if(@PrefValue='CheckIn')
				set @SQL=@SQL+'dcAlpha1=convert(nvarchar,@dt,106),dcAlpha2=convert(nvarchar,@dt,100),dcAlpha28=convert(nvarchar,@utcdt,106),dcAlpha29=convert(nvarchar,@utcdt,100)'
			else
				set @SQL=@SQL+'dcAlpha3=convert(nvarchar,@dt,106),dcAlpha4=convert(nvarchar,@dt,100),dcAlpha30=convert(nvarchar,@utcdt,106),dcAlpha31=convert(nvarchar,@utcdt,100),dcAlpha5=case when dcAlpha2 is not null and isdate(dcAlpha2)=1 then convert(nvarchar,CONVERT(FLOAT, CAST((abs(datediff(minute,convert(datetime,dcAlpha2),@dt)))/60 AS VARCHAR(2))+''.''+RIGHT(''0''+ CAST((abs(datediff(minute,convert(datetime,dcAlpha2),@dt)))%60 AS VARCHAR(2)),2) )) else ''0.0'' end '
			
			set @SQL=@SQL+' from INV_DocDetails a With(nolock)
			join COM_DocTextData b with(nolock) on a.InvDocDetailsID=b.InvDocDetailsID 
			where a.DOCID='+CONVERT(NVARCHAR(MAX),@DocID)
			print @SQL
			exec(@SQL)
		END
			 
		
		if exists(select X.value('@L1Remarks','nvarchar(max)')
		from @XML.nodes('/XML') as Data(X) where X.value('@L1Remarks','nvarchar(max)') is not null)		
			select @Remarks=X.value('@L1Remarks','nvarchar(max)')
			from @XML.nodes('/XML') as Data(X)    		
		         
		select @PrefValue=Value from @TblPref where IsGlobal=1 and Name='GBudgetUnapprove'

		if(@WHERE<>'')
		BEGIN
			exec @return_value=[spDOC_ValidateBudget]
					@Where=@WHERE,
					@DocDate=@DocDate,
					@BudStartDate=@AccLockDate,
					@BudgetID=@CaseID,
					@dtype=@DocumentType,
					@seq=0,
					@saveUnapp=@PrefValue,
					@UserName=@UserName,
					@LangID=@LangID
					
				if(@PrefValue='true' and @return_value=2)
				BEGIN
					set @StatusID=371
					
					update INV_DocDetails
					set StatusID=371
					where DocID=@DocID and CostCenterID=@CostCenterID		
				END	
		END	
		
		set @WHERE=''
		select @WHERE=isnull(X.value('@ValueBudWhere','nvarchar(max)'),''),@CaseID=X.value('@ValueBudID','INT'),@AccLockDate=X.value('@ValueBudStartDate','Datetime')
		from @XML.nodes('/XML') as Data(X)    		         
		if(@WHERE<>'')
		BEGIN
			exec @return_value=[spDOC_ValidateBudget]
					@Where=@WHERE,
					@DocDate=@DocDate,
					@BudStartDate=@AccLockDate,
					@BudgetID=@CaseID,
					@dtype=@DocumentType,
					@seq=0,
					@saveUnapp=@PrefValue,
					@UserName=@UserName,
					@LangID=@LangID
					
				if(@PrefValue='true' and @return_value=2)
				BEGIN
					set @StatusID=371
					
					update INV_DocDetails
					set StatusID=371
					where DocID=@DocID and CostCenterID=@CostCenterID		
				END	
		END	
		
		if(@LineWiseApproval=0 and @DUPLICATECODE<>'NO' and (@AppRejDate is not null or @WID<>0) and @level is not null)
		begin
			if(@STATUSID=369 and @oldStatus not in (441,369))
			begin
				INSERT INTO COM_Approvals    
						(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)      
				VALUES(@COSTCENTERID,@DOCID,441,CONVERT(FLOAT,@AppRejDate),@Remarks,@UserID,@CompanyGUID    
						,newid(),@UserName,@Dt,@level,0)
				--set @Remarks='Workflow'		
				--set @AppRejDate=getdate()
				--Post Notification 
				--not to go to next level
				--EXEC spCOM_SetNotifEvent 441,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
				
			end
			
			if(@AppRejDate is not null and @WID>0 and @StatusID=369)
			BEGIN
				select @CaseNumber=isnull(SysColumnName,'') from ADM_CostCenterDef WITH(NOLOCK)
				where CostCenterID=@CostCenterID and LocalReference=79 and LinkData=55499
				if(@CaseNumber is not null and @CaseNumber like 'dcalpha%')
				BEGIN
					set @SQL='update [COM_DocTextData]
					set '+@CaseNumber+'='''+CONVERT(nvarchar,@AppRejDate)+'''
					from INV_DOcDetails d with(nolock)
					where d.InvDocDetailsID=COM_DocTextData.InvDocDetailsID and DOCID='+convert(nvarchar,@DocID)
					exec(@SQL)
				END
				
								
				if @oldStatus<>369 and exists(select Value from @TblPref where Name='DocDateasPostedDate' and Value='true')
				BEGIN
				
					update inv_docdetails
					set docdate=convert(float,@AppRejDate)
					where costcenterid=@CostCenterID and DocID=@DocID
					
					update acc_docdetails
					set docdate=convert(float,@AppRejDate)
					from ACC_DocDetails a WITH(NOLOCK) 
					join INV_DocDetails b WITH(NOLOCK)  on a.InvDocDetailsID=b.InvDocDetailsID
					where b.CostCenterID=@CostCenterID and b.DocID=@DocID
					
					update COM_Billwise 
					set docdate=convert(float,@AppRejDate)
					where DocNo=@VoucherNo
				END

			END
			

			INSERT INTO COM_Approvals    
					(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)      
			VALUES(@COSTCENTERID,@DOCID,@STATUSID,CONVERT(FLOAT,@AppRejDate),@Remarks,@UserID,@CompanyGUID    
					,newid(),@UserName,@Dt,@level,0)  
			--Post Notification 
			EXEC spCOM_SetNotifEvent @STATUSID,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
		end
		ELSE if(@LineWiseApproval=1)
		begin
			if exists(select * from  COM_Approvals  WITH(NOLOCK) 
			where CCID=@COSTCENTERID and CCNODEID=@DOCID and CreatedDate=@Dt and UserID=@UserID and StatusID=441)
				EXEC spCOM_SetNotifEvent 441,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
			
			if exists(select * from  COM_Approvals  WITH(NOLOCK) 
			where CCID=@COSTCENTERID and CCNODEID=@DOCID and CreatedDate=@Dt and UserID=@UserID and StatusID=372)
				EXEC spCOM_SetNotifEvent 372,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
				
			if exists(select * from  COM_Approvals  WITH(NOLOCK) 
			where CCID=@COSTCENTERID and CCNODEID=@DOCID and CreatedDate=@Dt and UserID=@UserID and StatusID=371)
				EXEC spCOM_SetNotifEvent 371,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
		END
		
		if(@TEMPxml<>'' and @TEMPxml<>'<ScheduleActivityXml/>' and @TEMPxml<>'<ScheduleActivityXml></ScheduleActivityXml>')
		begin
			exec spCom_SetActivitiesAndSchedules @TEMPxml,@CostCenterID,@DocID,@CompanyGUID,@Guid,@UserName,@dt,@LangID   
			if(@DocumentType=201)
			BEGIN
				set @SQL='update a set '
				
				select @SQL =@SQL+c.name+'='+a.name+',' from sys.columns a
				join sys.tables b on a.object_id=b.object_id
				join sys.columns c on c.name like 'CCNID%'
				join sys.tables d on c.object_id=d.object_id
				where b.name='COM_DocCCData' and d.name='CRM_Activities'
				and a.name like 'dcCCNID%' and a.name='dc'+c.name
				
				set @SQL =@SQL+'ScheduleID=ScheduleID  
				from CRM_Activities a WITH(NOLOCK),COM_DocCCData b WITH(NOLOCK)
				where a.StatusID not in(413,414) and a.CostCenterID='+convert(nvarchar(max),@CostCenterID)+' and a.NodeID='+convert(nvarchar(max),@DocID)+' and b.InvDocDetailsID='+convert(nvarchar(max),@InvDocDetailsID)
				--print @SQL
				exec(@SQL)
			END
			ELSE IF(@DocumentType=203)
			BEGIN
				UPDATE CRM_Activities set StartDate=CONVERT(float, @DocDate),EndDate=CONVERT(float,@DocDate) WHERE CostCenterID=@CostCenterID and  NodeID =@DocID
			END
		end
		
		--History Control Data
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('History'))
		from @XML.nodes('/XML') as Data(X) 
		
		IF (@TEMPxml IS NOT NULL AND @TEMPxml <> '')    
			EXEC spCOM_SetHistory @CostCenterID,@DocID,@TEMPxml,@UserName 
		
		 
		--PrePayment
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('PrePaymentXML'))
		from @XML.nodes('/XML') as Data(X)
		
		if(@TEMPxml is not null and @TEMPxml<>'')
		begin
			 
			set @AUTOCCID=0
			select @AUTOCCID=Value from @TblPref where IsGlobal=0 and  Name='PrepaymentDoc'    
			and Value is not null and isnumeric(Value)=1 and convert(INT,Value)>40000
			 
			 EXEC @return_value = [dbo].spDOc_SavePrePayments  
				@IsInventory=1,
				@CostCenterID = @AUTOCCID,  
				@Prepaymentxml = @TEMPxml,  
				@AccDocDetailsID=@DocID,
				@invDetID=@InvDocDetailsID,
				@CompanyGUID=@CompanyGUID,
				@UserName=@UserName,
				@UserID=@UserID,
				@LangID=@LangID
				
		END

		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('QtyAdjustments'))
		from @XML.nodes('/XML') as Data(X)
		if (exists(select Value from @TblPref where IsGlobal=0 and  Name='DocQtyAdjustment' and Value='true') and @TEMPxml<>'')
		BEGIN
			set @QtyAdjustments=@TEMPxml
			DELETE T FROM COM_DocQtyAdjustments T WITH(NOLOCK) WHERE T.DocID=@DocID AND T.InvDocDetailsID=0
			insert into COM_DocQtyAdjustments(InvDocDetailsID,Fld1,Fld2,Fld3,Fld4,Fld5,Fld6,Fld7,Fld8,Fld9,Fld10,Islinked,DocID,Fld11,Fld12,Fld13,Fld14,Fld15,Fld16,Fld17,Fld18,Fld19,Fld20,RefVoucherNo)
			select 0,X.value('@Fld1','Float'),X.value('@Fld2','Float'),X.value('@Fld3','Float')
			,X.value('@Fld4','Float'),X.value('@Fld5','Float'),X.value('@Fld6','Float'),X.value('@Fld7','Float')
			,X.value('@Fld8','Float'),X.value('@Fld9','Float'),X.value('@Fld10','nvarchar(max)'),X.value('@Islinked','BIT')
			,@DocID,X.value('@Fld11','nvarchar(max)'),X.value('@Fld12','nvarchar(max)'),X.value('@Fld13','nvarchar(max)')
			,X.value('@Fld14','nvarchar(max)'),X.value('@Fld15','nvarchar(max)'),X.value('@Fld16','nvarchar(max)'),X.value('@Fld17','nvarchar(max)')
			,X.value('@Fld18','nvarchar(max)'),X.value('@Fld19','nvarchar(max)'),X.value('@Fld20','nvarchar(max)'),X.value('@RefVoucherNo','nvarchar(200)')
			from @QtyAdjustments.nodes('/QtyAdjustments/Row') as Data(X) 

			SET @AuditTrial=0    
			SELECT @AuditTrial=CONVERT(BIT,Value) FROM @TblPref where IsGlobal=0 and  Name='AuditTrial'    
			SET @PrefValue=''    
			SELECT @PrefValue=Value FROM @TblPref where IsGlobal=0 and  Name='EnableRevision' 
    
			IF (@AuditTrial=1 or @PrefValue='true')  
			BEGIN  
				
				SET @QTYADJ=''
				SET @QTYADJSQ=''

				select @QTYADJ =@QTYADJ + 'A.' +a.name+',' from sys.columns a
				join sys.tables b on a.object_id=b.object_id
				where b.name='COM_DocQtyAdjustments'

				SET @QTYADJSQ='INSERT INTO [COM_DocQtyAdjustmentsHISTORY]('+@QTYADJ+'[ModifiedDate])
					SELECT a.*,case when @DT is null THEN i.[ModifiedDate] else @DT end FROM COM_DocQtyAdjustments A WITH(NOLOCK)
					JOIN [INV_DocDetails] i WITH(NOLOCK) on a.[InvDocDetailsID] =i.[InvDocDetailsID]
					WHERE A.DocID='+CONVERT(VARCHAR,@DocID)+' AND A.InvDocDetailsID=0'
					
					exec sp_executesql @QTYADJSQ,N'@DT float',@DT
			END

		END
	
		--Paymentterms
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('Paymentterms'))
		from @XML.nodes('/XML') as Data(X)      
		if(@TEMPxml<>'')
		begin		
			set @varxml=@TEMPxml		    
			INSERT INTO [COM_DocPayTerms]([VoucherNo],[AccountID],[Amount],AmountFC,[days],[DueDate]
           ,[Percentage],[Remarts],[Remarks1],DateNo,Period,BasedOn,BaseDate,ProfileID,[GUID],[CreatedBy],[CreatedDate],[CompanyGUID],DimCCID,DimNodeID)
			  select @VoucherNo,X.value('@Accountid','INT'),X.value('@Amount','float'),X.value('@AmountFC','float'),X.value('@Days','int'),
			  convert(float,convert(datetime, X.value('@DueDate','datetime'))),X.value('@Percentage','float'),X.value('@Remarks','nvarchar(max)'),X.value('@Remarks1','nvarchar(max)'),
			  X.value('@DateNo','int'),X.value('@Period','int'),X.value('@BasedOn','int'),
			  convert(float,convert(datetime, X.value('@BaseDate','datetime'))),X.value('@ProfileId','INT')
			  ,@Guid,@UserName,@Dt,@CompanyGUID,X.value('@DimCCID','INT'),X.value('@DimNodeID','INT')
			  FROM @varxml.nodes('/Paymentterms/Row') as Data(X) 
			  
			  set @TEMPxml=''
			  select @amt=isnull(Amount,0),@TEMPxml=[Remarts],@QthChld=isnull(AmountFC,0) from [COM_DocPayTerms] WITH(NOLOCK)
			  where [VoucherNo]=@VoucherNo and days=0
			  
				
			    set @fldName=''
				select @fldName=SysColumnName from ADM_CostCenterDef WIth(NOLOCK) 
				where LinkData=55477 and LocalReference=79 and CostCenterID=@CostCenterID
				
				SELECT @UNIQUECNT=Value FROM @TblPref WHERE IsGlobal=1 AND Name='DecimalsinAmount'
				
				SET @SQL=''
				if(@fldName like 'dcalpha%')
					set @SQL='update [COM_DocTextData]
					set '+@fldName+'='+str(@amt,18,@UNIQUECNT)+'
					from INV_DOcDetails d with(nolock)
					where d.InvDocDetailsID=COM_DocTextData.InvDocDetailsID and DOCID='+convert(nvarchar,@DocID)
				else if(@fldName like 'dcnum%')
					set @SQL='update [COM_DocNumData]
					set '+@fldName+'='+str(@amt,18,@UNIQUECNT)+'
					from INV_DOcDetails d with(nolock)
					where d.InvDocDetailsID=COM_DocNumData.InvDocDetailsID and DOCID='+convert(nvarchar,@DocID)
						
				exec(@SQL)
				
				set @fldName=''
				select @fldName=SysColumnName from ADM_CostCenterDef WIth(NOLOCK) 
				where LinkData=55475 and LocalReference=79 and CostCenterID=@CostCenterID
				
				SELECT @UNIQUECNT=Value FROM @TblPref WHERE IsGlobal=1 AND Name='DecimalsinAmount'
				
				SET @SQL=''
				if(@fldName like 'dcalpha%')
					set @SQL='update [COM_DocTextData]
					set '+@fldName+'='+str(@QthChld,18,@UNIQUECNT)+'
					from INV_DOcDetails d with(nolock)
					where d.InvDocDetailsID=COM_DocTextData.InvDocDetailsID and DOCID='+convert(nvarchar,@DocID)
				else if(@fldName like 'dcnum%')
					set @SQL='update [COM_DocNumData]
					set '+@fldName+'='+str(@QthChld,18,@UNIQUECNT)+'
					from INV_DOcDetails d with(nolock)
					where d.InvDocDetailsID=COM_DocNumData.InvDocDetailsID and DOCID='+convert(nvarchar,@DocID)
						
				exec(@SQL)
				
				set @fldName=''
				select @fldName=SysColumnName from ADM_CostCenterDef WIth(NOLOCK) 
				where LinkData=55476 and LocalReference=79 and CostCenterID=@CostCenterID
				
				SET @SQL=''
				if(@fldName like 'dcalpha%')
					set @SQL='update [COM_DocTextData]
					set '+@fldName+'='''+@TEMPxml+'''
					from INV_DOcDetails d with(nolock)
					where d.InvDocDetailsID=COM_DocTextData.InvDocDetailsID and DOCID='+convert(nvarchar,@DocID)
				
				exec(@SQL)
		end
		
		--PosPayModes
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('PosPayModes'))
		from @XML.nodes('/XML') as Data(X)      
		if(@TEMPxml<>'')
		begin		
			set @varxml=@TEMPxml		    
			INSERT INTO COM_PosPayModes([DOCID],[Type],[Amount],DBColumnName,[CardNo],[CardName],[ExpDate],RegisterID,ShiftID,DocDate,VoucherNodeID,VoucherType
			,Currency,ExchangeRate,AmountFC,BankName,CardType,ApprovalCode)
			  select @DocID,X.value('@Type','int'),X.value('@Amount','float'),X.value('@DBColumnName','nvarchar(100)'),
			  X.value('@CardNo','nvarchar(50)'),X.value('@CardName','nvarchar(500)'),convert(float,convert(datetime, X.value('@ExpDate','datetime')))			  
			  ,X.value('@RegisterID','INT'),X.value('@ShiftID','INT'),convert(float,X.value('@DocDate','datetime'))
			  ,X.value('@VoucherNodeID','INT'),@VoucherType
			  ,X.value('@Currency','INT'),X.value('@ExchangeRate','float'),convert(float,X.value('@FCAmt','float'))
			  ,X.value('@BankName','INT'),X.value('@CardType','INT'),X.value('@ApprovalCode','nvarchar(100)')
			  FROM @varxml.nodes('/PosPayModes/XML') as Data(X) where X.value('@IsDenom','BIT') is null
			  
			INSERT INTO COM_DocDenominations(DOCID,[CurrencyID],[Notes],[NotesTender],[Change],[ChangeTender])
			  select @DocID,X.value('@CurrencyID','INT'),X.value('@Notes','float'),X.value('@NotesTender','float')
			  ,X.value('@Change','float'),X.value('@ChangeTender','float')
			  FROM @varxml.nodes('/PosPayModes/XML') as Data(X) where X.value('@IsDenom','BIT')=1
			  
				select @PrefValue=Value from @TblPref where IsGlobal=1 and  Name='PosCoupons'    
				set @Dimesion=0
				if(@PrefValue is not null and @PrefValue<>'' and ISNUMERIC(@PrefValue)=1)
				begin						
					begin try
						select @Dimesion=convert(INT,@PrefValue)
					end try
					begin catch
						set @Dimesion=0
					end catch
				END
			
			if exists(select Value from @TblPref where IsGlobal=0 and  Name='UseAsOrder' and Value ='true')
			   and exists(select * from COM_PosPayModes WITH(NOLOCK) where docid=@DocID and type <>11)
			BEGIN 
				
				insert into COM_BillWiseNonAcc(DocNo,DocSeqNo,RefDocNo,Amount,AccountID,Doctype)
				SELECT @VoucherNo,1,'',sum(case when type=12 then -amount else amount end),null,@DocumentType
				from COM_PosPayModes WITH(NOLOCK)
				where docid=@DocID and type <>11    
				
				if(@HistoryStatus<>'Add')
				BEGIN
					 if exists(select a.DocNo from com_billwisenonacc a WITH(NOLOCK)
					join com_billwisenonacc b WITH(NOLOCK) on a.DocNo=b.RefDocNO
					where a.DocNo =@VoucherNo and  a.doctype=38
					group by a.DocNo,a.Amount
					having a.Amount-sum(b.Amount)<-0.01)
						RAISERROR('-578',16,1)  
				END		
			END
					
			  if(@DocumentType=38 and exists(select X.value('@Type','int') FROM @varxml.nodes('/PosPayModes/XML') as Data(X) 
			  where X.value('@Type','int') is not null and X.value('@Type','int')=9))
			  BEGIN
					INSERT INTO @tblBILL(Amount,AccountID)      
					SELECT X.value('@Amount','float'),X.value('@VoucherNodeID','INT') FROM @varxml.nodes('/PosPayModes/XML') as Data(X) 
					where X.value('@Type','int') is not null and X.value('@Type','int')=9      					
					SELECT @I=1, @Cnt=count(ID) FROM @tblBILL        
				          
					WHILE(@I<=@Cnt and @Dimesion>50000)        
					BEGIN      
					  SELECT @accid=AccountID FROM @tblBILL  WHERE ID=@I
					  
					  select @amt=SUM(Amount) from COM_PosPayModes WITH(NOLOCK) 
					  where VoucherNodeID=@accid and VoucherType=-1 
					  
					  select @ProductName=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@Dimesion
					  
					  set @SQL=' select @QtyFin=ccalpha50 from '+@ProductName+' WITH(NOLOCK) where NODEID='+convert(nvarchar,@accid)
					  +' and ccalpha50 is not null and isnumeric(ccalpha50)=1'
					  print @SQL
					  EXEC sp_executesql @SQL,N'@QtyFin FLOAT OUTPUT',@QtyFin output
					  
					  if(@QtyFin<@amt  and (@QtyFin-@amt)<-0.001)
					  BEGIN
						select @QtyFin,@amt,@QtyFin-@amt
							RAISERROR('-523',16,1)  
					  END
					  else
					  BEGIN
							  set @SQL=' update '+@ProductName+' set ccalpha49=convert(nvarchar(max),convert(float,ccalpha50)-isnull((select SUM(Amount) from COM_PosPayModes WITH(NOLOCK) where VoucherNodeID=nodeid and VoucherType=-1),0))  where NODEID='+convert(nvarchar,@accid)
							 +' and ccalpha50 is not null and isnumeric(ccalpha50)=1'
							 EXEC (@SQL)
					  END
				
					  set @I=@I+1
				    END   
			  END
			  ELSE if(@DocumentType=39 and exists(select X.value('@Type','int') FROM @varxml.nodes('/PosPayModes/XML') as Data(X) 
			  where X.value('@Type','int') is not null and X.value('@Type','int')=9))
			  BEGIN
					delete from @tblBILL
					INSERT INTO @tblBILL(Amount,DocNo)      
					SELECT X.value('@Amount','float'),X.value('@DBColumnName','nvarchar(100)') FROM @varxml.nodes('/PosPayModes/XML') as Data(X) 
					where X.value('@Type','int') is not null and X.value('@Type','int')=9      					
					SELECT @I=min(ID), @Cnt=max(ID) FROM @tblBILL        
				       
					WHILE(@I<=@Cnt and @Dimesion>50000)        
					BEGIN      
					  SELECT @amt=Amount,@Columnname=DocNo FROM @tblBILL  WHERE ID=@I   
					  
					  set @ProductName= 'ccalpha50='+convert(nvarchar,@amt)+',ccalpha49='+convert(nvarchar,@amt)+',ccalpha48='+convert(nvarchar,@DocID)+','
					  select @CCStatusID =  statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active'
				
					  EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
						@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
						@Code = @VoucherNo,
						@Name = @VoucherNo,
						@AliasName='',
						@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
						@CustomFieldsQuery=@ProductName,@AddressXML=NULL,@AttachmentsXML=NULL,
						@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
						@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=1,
						@CodePrefix='',@CodeNumber='',
						@CheckLink = 0,@IsOffline=@IsOffline
						
						update P
						set P.VoucherNodeID=@return_value
						FROM COM_PosPayModes P WITH(NOLOCK)
						where P.DBColumnName=@Columnname and P.DOCID=@DocID
				
					  set @I=@I+1
				    END   
			  END
		end	
		
		
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('ChkRtnXML'))
		from @XML.nodes('/XML') as Data(X)      
		if(@TEMPxml<>'')
		begin		
			set @DocCC=''
			select @DocCC =@DocCC +a.name+',' from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_DocCCData' and a.name like 'dcCCNID%' and convert(int,replace(a.name,'dcCCNID',''))<51

		set @varxml=@TEMPxml
		set @DUPLICATECODE='	INSERT INTO COM_ChequeReturn    
       ([DocNo]    
       ,[DocDate]    
       ,[DocDueDate]    
       ,[DocSeqNo]    
       ,[AccountID]    
       ,[AdjAmount]    
       ,[AdjCurrID]    
       ,[AdjExchRT],AmountFC    
       ,[DocType]    
       ,[IsNewReference]    
       ,[RefDocNo]    
       ,[RefDocSeqNo]    
       ,[RefDocDate]    
       ,[RefDocDueDate] 
       ,[Narration]    
       ,[IsDocPDC],'+@DocCC+' 
       [CompanyGUID]    
       ,[GUID]    
       ,[CreatedBy]    
       ,[CreatedDate])    
     SELECT '''+convert(nvarchar(max),@VoucherNo)+'''
       , '''+convert(nvarchar(max),CONVERT(FLOAT,@DocDate))+''','    
       if(@DueDate is null)
			set @DUPLICATECODE=@DUPLICATECODE+'NULL'
	   else 	
			set @DUPLICATECODE=@DUPLICATECODE+''''+convert(nvarchar(max),CONVERT(FLOAT,@DueDate))+''''
			
       set @DUPLICATECODE=@DUPLICATECODE+', 1   
       , X.value(''@AccountID'',''INT'')        
		, replace(X.value(''@AdjAmount'',''nvarchar(50)''),'','','''')
       , X.value(''@AdjCurrID'',''int'')    
       , X.value(''@AdjExchRT'',''float'')    , replace(X.value(''@AmountFC'',''nvarchar(50)''),'','','''')
       , '+convert(nvarchar(max),@DocumentType)+'   
       , X.value(''@IsNewReference'',''bit'')    
       , X.value(''@RefDocNo'',''nvarchar(200)'')    
       , X.value(''@RefDocSeqNo'',''int'')    
       , CONVERT(FLOAT,X.value(''@RefDocDate'',''DATETIME''))    
       , CONVERT(FLOAT,X.value(''@RefDueDate'',''DATETIME''))             
       , X.value(''@Narration'',''nvarchar(max)'')    
       , X.value(''@IsDocPDC'',''bit''), '+@DocCC+'    
        '''+convert(nvarchar(max),@CompanyGUID   )+''' 
     , '''+convert(nvarchar(max),@guid)+'''
     , '''+convert(nvarchar(max),@UserName)+'''
     , '''+convert(nvarchar(max),@Dt)+'''
     from @varxml.nodes(''/ChkRtnXML/Row'') as Data(X)    
     join [COM_DocCCData] d WITH(NOLOCK)  on d.InvDocDetailsID='+convert(nvarchar(max),@InvDocDetailsID)
     
     EXEC sp_executesql @DUPLICATECODE,N'@varxml XML',@varxml
	END	
		
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('LCBillsXML'))
		from @XML.nodes('/XML') as Data(X)      
		
		if(@TEMPxml<>'')
		begin		
			set @varxml=@TEMPxml
			declare @CCreplCols NVARCHAR(MAX)
		    set @CCreplCols=''
			select @CCreplCols =@CCreplCols +a.name+',' from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_DocCCData' and a.name like 'dcCCNID%' and convert(int,replace(a.name,'dcCCNID',''))<51
				set @sql='	INSERT INTO COM_LCBills    
			   ([DocNo]    
			   ,[DocDate]    
			   ,[DocDueDate]    
			   ,[DocSeqNo]    
			   ,[AccountID]    
			   ,[AdjAmount]    
			   ,[AdjCurrID]    
			   ,[AdjExchRT],AmountFC    
			   ,[DocType]    
			   ,[IsNewReference]    
			   ,[RefDocNo]    
			   ,[RefDocSeqNo]    
			   ,[RefDocDate]    
			   ,[RefDocDueDate] 
			   ,[Narration]    
			   ,[IsDocPDC],'+@CCreplCols+'[CompanyGUID]    
			   ,[GUID]    
			   ,[CreatedBy]    
			   ,[CreatedDate])    
			 SELECT '''+convert(nvarchar(max),@VoucherNo)+'''
			   , '''+convert(nvarchar(max),CONVERT(FLOAT,@DocDate))
		       
			   if(@DueDate is not null)
					set @sql=@sql+''','' '+convert(nvarchar(max),CONVERT(FLOAT,@DueDate))+''''	
			   else
					set @sql=@sql+''',NULL'
			   set @sql=@sql+', X.value(''@DocSeqNo'',''int'')      
			   , X.value(''@AccountID'',''INT'')      
			   , replace(X.value(''@AdjAmount'',''nvarchar(50)''),'','','''')    
			   , X.value(''@AdjCurrID'',''int'')      
			   , X.value(''@AdjExchRT'',''float'')  ,replace(X.value(''@AmountFC'',''nvarchar(50)''),'','','''')     
			   , '+convert(nvarchar(max),@DocumentType)+'      
			   , X.value(''@IsNewReference'',''bit'')      
			   , X.value(''@RefDocNo'',''nvarchar(200)'')      
			   , X.value(''@RefDocSeqNo'',''int'')      
			 , CONVERT(FLOAT,X.value(''@RefDocDate'',''DATETIME''))      
			 , CONVERT(FLOAT,X.value(''@RefDueDate'',''DATETIME''))       
			   , X.value(''@Narration'',''nvarchar(max)'')  
			   , 0,'+@CCreplCols+'''' +convert(nvarchar(max),@CompanyGUID)+' ''
			 , '''+convert(nvarchar(max),@guid)+'''
			 , '''+convert(nvarchar(max),@UserName)+''' 
			 , '''+convert(nvarchar(max),@Dt)+'''
				  FROM @varxml.nodes(''/LCBillsXML/Row'') as Data(X) 
				  join [COM_DocCCData] d with(nolock) on d.INVDocDetailsID='+convert(nvarchar(max),@INVDocDetailsID)
				  print @sql
				   EXEC sp_executesql @sql,N'@varxml XML',@varxml
		end	
		
		set @AUTOCCID=0
		select @AUTOCCID=Value from @TblPref where IsGlobal=0 and  Name='VatAdvanceDoc'    
		and Value is not null and isnumeric(Value)=1 and convert(INT,Value)>40000
		
		--Auto Post Vat Advance
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('AccountingDoc'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		begin
			
			set @TEMPxml=Replace(@TEMPxml,'<AccountingDoc>','<DocumentXML>')
			set @TEMPxml=Replace(@TEMPxml,'</AccountingDoc>','</DocumentXML>')
			
			
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @TEMPxml,@DocDate,@AUTOCCID,@Prefix output ,@InvDocDetailsID,0,0,0,1
			
			set @ddID=0
			
			if(@HistoryStatus='Update')
				select @ddID=DocID FROM ACC_DocDetails with(nolock)   
				where refccid=300 and refnodeid=@DocID and Costcenterid=@AUTOCCID

			
			EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
				@CostCenterID = @AUTOCCID,      
				@DocID = @ddID,      
				@DocPrefix = @Prefix,      
				@DocNumber =N'',
				@DocDate = @DocDate,      
				@DueDate = NULL,      
				@BillNo = NULL,      
				@InvDocXML = @TEMPxml,      
				@NotesXML = N'',      
				@AttachmentsXML = N'',      
				@ActivityXML  = N'',     
				@IsImport = 0,      
				@LocationID = @LocationID,      
				@DivisionID = @DivisionID,      
				@WID = 0,      
				@RoleID = @RoleID,      
				@RefCCID = 300,    
				@RefNodeid = @DocID ,    
				@CompanyGUID = @CompanyGUID,      
				@UserName = @UserName,      
				@UserID = @UserID,      
				@LangID = @LangID 
				
				if(@return_value=-999)
					return -999
					
				set @Columnname=''
				select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
				where costcenterid=@CostCenterID and 
				LocalReference is not null and LinkData is not null 
				 and LocalReference=79 and LinkData=50456
				
				select @vno =Voucherno,@amt=sum(amount) from acc_DocDetails WITH(NOLOCK)
				where DocID=@return_value
				group by Voucherno
				
				if(@Columnname is not null and @Columnname like 'dcAlpha%')
				 begin
						
					 set @TEMPxml='update COM_DocTextData
					 set '+@Columnname+'='''+@vno+''' 
					  where invDocDetailsID in (select invDocDetailsID from inv_DocDetails WITH(NOLOCK)
					 where DocID='+convert(nvarchar,@DocID)+')'	 
					 exec (@TEMPxml)
				end
				
				set @Columnname=''
				select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
				where costcenterid=@CostCenterID and 
				LocalReference is not null and LinkData is not null 
				 and LocalReference=79 and LinkData=226
				
				if(@Columnname is not null and @Columnname like 'dcAlpha%')
				 begin
					 set @TEMPxml='update COM_DocTextData
					 set '+@Columnname+'='''+str(@amt,18,3)+''' 
					  where invDocDetailsID in (select invDocDetailsID from inv_DocDetails WITH(NOLOCK)
					 where DocID='+convert(nvarchar,@DocID)+')'	 
					 exec (@TEMPxml)
				end
				
				set @Columnname=''
				select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
				where costcenterid=@AUTOCCID and 
				LocalReference is not null and LinkData is not null 
				 and LocalReference=79 and LinkData=50456
				
				if(@Columnname is not null and @Columnname like 'dcAlpha%')
				 begin
						
					 set @TEMPxml='update COM_DocTextData
					 set '+@Columnname+'='''+@VoucherNo+''' 
					  where AccDocDetailsID in (select AccDocDetailsID from Acc_DocDetails WITH(NOLOCK)
					 where DocID='+convert(nvarchar,@return_value)+')'	 
					 exec (@TEMPxml)
				end
				  
		END	
		ELSE if(@AUTOCCID>0 and @HistoryStatus='Update')
		BEGIN
				if exists(select AccDocDetailsID from acc_docdetails with(nolock) 
				where refccid=300 and refnodeid=@DocID and Costcenterid=@AUTOCCID)
				begin
					select @ddID=DocID FROM ACC_DocDetails with(nolock)   
					where refccid=300 and refnodeid=@DocID and Costcenterid=@AUTOCCID
					
					 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
						 @CostCenterID = @AUTOCCID,  
						 @DocPrefix = '',  
						 @DocNumber = '',  
						 @DOCID=@ddID,
						 @UserID = @UserID,  
						 @UserName = @UserName,  
						 @LangID = @LangID,
						 @RoleID=@RoleID
				END
		END
		
		--Auto Post ITP
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('AutoPOstXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		begin
			select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='Autopostdocument'    

			set @varxml=@TEMPxml
			set @AUTOCCID=convert(INT,@PrefValue)
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output ,@InvDocDetailsID
			
			set @TEMPxml=''
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('AutoProduceXML'))
			from @varxml.nodes('/AutoPOstXML') as Data(X)
			
			set @SQL='<XML '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'>'
			
			set @SQL=@SQL+@TEMPxml			
			set @SQL=@SQL+'</XML>'
			
			if exists(select * from com_documentpreferences WITH(NOLOCK)
			where costcenterid=@AUTOCCID and prefname  ='SameserialNo' and prefvalue='true' )
			    set @temp=@DocNumber
			 else
				set @temp=N''   
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = @temp,      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @BillNo,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = @LocationID,      
			  @DivisionID = @DivisionID ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @InvDocDetailsID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    
		END	
		
	    --Auto Post ITP

		set @TEMPxmlParent=''
		SELECT @TEMPxmlParent=CONVERT(NVARCHAR(MAX), X.query('CrossDimXMLNODES'))
		from @XML.nodes('/XML') as Data(X)

		Declare @index int ;
		declare @childnodecount int,@InvRowID Int,@CDocID INT,@DimensionFor INT,@isDel Int;
		Declare @XMLCross XML;
		Set @XMLCross = @TEMPxmlParent;

		select top 1 @CDocID = DocID From INV_DocDetails WITH(NOLOCK) Where INVDocDetailsID = @InvDocDetailsID
		--print @TEMPxml
		Set @index = 1;
		Set @childnodecount = @XMLCross.value('count(/CrossDimXMLNODES/CrossDimXML)','INT');

		while @index <= @childnodecount
		begin 
			set @TEMPxml=''
			SELECT @TEMPxml =CONVERT(NVARCHAR(MAX),@XMLCross.query('(/CrossDimXMLNODES/CrossDimXML[position()=sql:variable("@index")])[1]'))
			if(@TEMPxml<>'')
																																																																																														begin
			select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='CrossDimDocument'    

			set @varxml=@TEMPxml
			set @AUTOCCID=convert(INT,@PrefValue)
				
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/CrossDimXML') as Data(X)
			
			set @isDel=0
			SELECT @isDel=ISNULL(X.value('@IsDelete','int'),0)
			from @varxml.nodes('/CrossDimXML') as Data(X)

			if(@isDel>0)
			BEGIN				    
				EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]  
					 @CostCenterID = @AUTOCCID,  
					 @DocPrefix = '',  
					 @DocNumber = '',
					 @DocID=@ddID,
					 @UserID = 1,  
					 @UserName = @UserName,  
					 @LangID = @LangID,
					 @RoleID=1
			END 
			ELSE
			BEGIN
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/CrossDimXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/CrossDimXML') as Data(X)
			
			set @bxml=Replace(@bxml,'</BillXML>','')
			set @bxml=Replace(@bxml,'<BillXML>','')
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/CrossDimXML') as Data(X)
					set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @varxml.nodes('/CrossDimXML') as Data(X)
			
			set @DimensionFor=0
			SELECT @DimensionFor=ISNULL(X.value('@DimensionFor','int'),0)
			from @varxml.nodes('/CrossDimXML') as Data(X)


			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			
			select @Dimesion=isnull(Value,0) from adm_globalpreferences WITH(NOLOCK)
			where Name='CrossDimension' and isnumeric(Value)=1		
			
			select @fldName=syscolumnName from @TblPref a 
			join adm_costcenterdef d WITH(NOLOCK) on a.Value=d.CostcenterColID
			where Name='CrossDimField' and IsGlobal=0 and isnumeric(Value)=1 
		
			set @SQL='select @CaseID='+@fldName+' from COM_DocTextData with(nolock) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			EXEC sp_executesql @SQL,N'@CaseID INT OUTPUT',@CaseID output
			
			
			Set @InvRowID = 0;
			set @SQL='
			select top 1 @InvRowID = C.InvDocDetailsID from Inv_DocDetails A with(nolock) 
			join Com_DocTextData C WITH(NOLOCK) on C.InvDocDetailsId = A.InvDocDetailsId 
			where a.DocID = '+convert(nvarchar,@CDocID)+' and C.'+@fldName+' = '+convert(nvarchar,@DimensionFor)

			EXEC sp_executesql @SQL,N'@InvRowID INT OUTPUT',@InvRowID output

			set @SQL='<XML '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'>'						
			set @SQL=@SQL+'</XML>'
			
			set @Prefix=''
			
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output --,@InvDocDetailsID,@Dimesion,@DimensionFor						
			
			if(@Dimesion=50002)
			   set @LocationID=@DimensionFor
			
			if exists(select * from com_documentpreferences
			where costcenterid=@AUTOCCID and prefname  ='SameserialNo' and prefvalue='true' )
			    set @temp=@DocNumber
			 else
				set @temp=N''  
			
			print @ddxml

			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = @temp,      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @BillNo,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = @LocationID,      
			  @DivisionID = @DivisionID ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @InvRowID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID 
			  
			update b
			    set LinkedInvDocDetailsID=a.InvDocDetailsID,refno=a.voucherno
				from INV_DocDetails a WITH(NOLOCK) 
				JOIN INV_DocDetails b with(nolock) ON b.DocOrder=a.DocSeqNo
				where a.docid=@DocID and b.docid=@return_value
		END
		END	
			Set @index = @index + 1;
		end
		--Auto Produce
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('AutoProduceXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		begin
				
			set @varxml=@TEMPxml
			
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/AutoProduceXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/AutoProduceXML') as Data(X)
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/AutoProduceXML') as Data(X)
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/AutoProduceXML') as Data(X)
			
			SELECT @PrefValue=X.value('@CostCenterID','INT')
			from @varxml.nodes('/AutoProduceXML') as Data(X)
			set @AUTOCCID=convert(INT,@PrefValue)
			
			set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @varxml.nodes('/AutoProduceXML') as Data(X)
	
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output ,@InvDocDetailsID
			
			if(@DetIDS<>'')
				set @DetIDS='<XML DetailIds="'+@DetIDS+'"></XML>'
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @BillNo,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @DetIDS,       
			  @IsImport = 0,      
			  @LocationID = @LocationID,      
			  @DivisionID = @DivisionID ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @InvDocDetailsID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    
		END
		
		--Shortage of stock
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('ShortageXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		begin
			select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='ShortageDOC'    
			set @AUTOCCID=0
			set @varxml=@TEMPxml
			set @AUTOCCID=convert(INT,@PrefValue)
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/ShortageXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/ShortageXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
			from @varxml.nodes('/ShortageXML') as Data(X)
						
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0 
						
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = 0,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @BillNo,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = '',       
			  @IsImport = 0,      
			  @LocationID = @LocationID,      
			  @DivisionID = @DivisionID ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @InvDocDetailsID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    

			  if(@return_value>0)
			  begin
					update b 
					set b.refno=a.voucherno from INV_DocDetails a with(nolock)
					join inv_docdetails b with(nolock) on b.refnodeid=a.InvDocDetailsID
					where a.docid=@DOCID and b.DocID=@return_value
				end

		END	
		
		--Excess of stock
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('ExcessXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		begin
			select @PrefValue=Value from @TblPref where IsGlobal=0 and  Name='ExcessDOC'    

			set @AUTOCCID=0
			set @varxml=@TEMPxml
			set @AUTOCCID=convert(INT,@PrefValue)
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/ExcessXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/ExcessXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
			from @varxml.nodes('/ExcessXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
			
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = 0,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @BillNo,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = '',       
			  @IsImport = 0,      
			  @LocationID = @LocationID,      
			  @DivisionID = @DivisionID ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @InvDocDetailsID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID 
			  
			  if(@return_value>0)
			  begin
					update b 
					set b.refno=a.voucherno from INV_DocDetails a with(nolock)
					join inv_docdetails b with(nolock) on b.refnodeid=a.InvDocDetailsID
					where a.docid=@DOCID and b.DocID=@return_value
				end   
		END
		
		--LoanRepayment
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('LoanRepaymentXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		begin
			
			set @varxml=@TEMPxml
			set @AUTOCCID=40057
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/LoanRepaymentXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @varxml.nodes('/LoanRepaymentXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
			from @varxml.nodes('/LoanRepaymentXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
			
			set @ddID=0
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/LoanRepaymentXML') as Data(X)
			
			set @ActXml=''
			set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @BillNo,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @ActXml,       
			  @IsImport = 0,      
			  @LocationID = @LocationID,      
			  @DivisionID = @DivisionID ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @InvDocDetailsID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    
		END			  
		
		--Attendance Data Dimensionwise
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('AttendanceDimensionwiseXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		begin
			
			set @varxml=@TEMPxml
			set @AUTOCCID=40079
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/AttendanceDimensionwiseXML') as Data(X)
			
			
			set @TEmpWid=0
			SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
			from @varxml.nodes('/AttendanceDimensionwiseXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
			
			set @ddID=0
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/AttendanceDimensionwiseXML') as Data(X)
		
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @varxml.nodes('/AttendanceDimensionwiseXML') as Data(X)
			set @SQL='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'></XML>'
					 
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = @DueDate,      
			  @BillNo = @BillNo,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = @LocationID,      
			  @DivisionID = @DivisionID ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @InvDocDetailsID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    
		END	
		
	--Preventive Service Request From Preventive Maintenance Contract
		DECLARE @ActvityXML nvarchar(max),@ChildDocActvityXML nvarchar(max),@DDocSeqNo int,@PInvDocDetailsID INT
		SET @ActvityXML=''
		SET @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('PMCXML')) from @XML.nodes('/XML/AVX') as Data(X)		
		IF(@TEMPxml<>'')
		BEGIN
			--Create temporary table to read xml data into table  
			declare @tblPMCList TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX),ACTIVITYXML NVARCHAR(MAX))
			--Insert XML data into temporary table
			INSERT INTO @tblPMCList    
				SELECT CONVERT(NVARCHAR(MAX), X.query('PMCXML')),CONVERT(NVARCHAR(MAX), X.query('PMCACTIVITYXML')) from @XML.nodes('/XML/AVX') as Data(X)   
			--Set loop initialization varaibles    
			SELECT @I=1, @Cnt=count(*) FROM @tblPMCList 
			WHILE(@I<=@Cnt)      
			BEGIN		
				SET @TEMPxml=''
				SET @varxml=''
				SET @ddxml=''
				SET @ChildDocActvityXML=''
				SET @ActvityXML=''
				
				SELECT @TEMPxml=TRANSXML, @ActvityXML=ACTIVITYXML FROM @tblPMCList  WHERE ID=@I  
				SET @I=@I+1   
		
				set @varxml=@TEMPxml
				set @AUTOCCID=40203
				SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
				from @varxml.nodes('/PMCXML') as Data(X)
				
				set @TEmpWid=0
				SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
				from @varxml.nodes('/PMCXML') as Data(X)
				
				set @ddxml=Replace(@ddxml,'<RowHead/>','')
				set @ddxml=Replace(@ddxml,'</DOCXML>','')
				set @ddxml=Replace(@ddxml,'<DOCXML>','')
				set @Prefix=@DocPrefix--''
				EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
				
				set @ddID=0
				
				SELECT @ddID=X.value('@DocID','INT'),@DDocDate=X.value('@StartDate','DATETIME')
				from @varxml.nodes('/PMCXML') as Data(X)
				
				
				set @DDocSeqNo=0
				
				SELECT @DDocSeqNo=X.value('@DocSeqNo','INT')
				from @varxml.nodes('/PMCXML') as Data(X)
				
				set @DetIDS=''
				SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
				from @varxml.nodes('/PMCXML') as Data(X)
				set @SQL='<XML '
				if(@DetIDS<>'')
					set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
				
				set @SQL=@SQL+'>'--</XML>'
			
				--ActvityXML
				set @varxml=@ActvityXML
				SELECT @ChildDocActvityXML=CONVERT(NVARCHAR(MAX), X.query('DOCACTIVITYXML')) from @varxml.nodes('/PMCACTIVITYXML') as Data(X)
				SET @ChildDocActvityXML=REPLACE(@ChildDocActvityXML,'<DOCACTIVITYXML>','')
				SET @ChildDocActvityXML=REPLACE(@ChildDocActvityXML,'</DOCACTIVITYXML>','')
				SET @ChildDocActvityXML=REPLACE(@ChildDocActvityXML,'<PMCACTIVITYXML>','')
				SET @ChildDocActvityXML=REPLACE(@ChildDocActvityXML,'</PMCACTIVITYXML>','')
				SET @ChildDocActvityXML=@SQL+@ChildDocActvityXML+'</XML>'
				--ActvityXML
				SELECT @PInvDocDetailsID=InvDocDetailsID FROM INV_DocDetails WHERE CostCenterID=@CostCenterID and DocSeqNo=@DDocSeqNo
				EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
				  @CostCenterID = @AUTOCCID,      
				  @DocID = @ddID,      
				  @DocPrefix = @Prefix,      
				  @DocNumber = N'',      
				  @DocDate = @DDocDate,--@DocDate,      
				  @DueDate = NULL,      
				  @BillNo = @BillNo,      
				  @InvDocXML =@ddxml,      
				  @BillWiseXML = @bxml,      
				  @NotesXML = N'',      
				  @AttachmentsXML = N'',    
				  @ActivityXML =@ChildDocActvityXML,
				  @IsImport = 0,      
				  @LocationID = @LocationID,      
				  @DivisionID = @DivisionID ,      
				  @WID = @TEmpWid,      
				  @RoleID = @RoleID,      
				  @DocAddress = N'',      
				  @RefCCID = 300,    
				  @RefNodeid  = @PInvDocDetailsID,--@InvDocDetailsID,    
				  @CompanyGUID = @CompanyGUID,      
				  @UserName = @UserName,      
				  @UserID = @UserID,      
				  @LangID = @LangID    				  				  
			END
		END			
		--Apply Vacation From Leave Adjustment Document
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('ApplyVacationXML')) from @XML.nodes('/XML/AVX') as Data(X)
		IF(@TEMPxml<>'')
		BEGIN
			--Create temporary table to read xml data into table  
			declare @tblVacationList TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX))
			--Insert XML data into temporary table
			INSERT INTO @tblVacationList    
				SELECT CONVERT(NVARCHAR(MAX), X.query('ApplyVacationXML')) from @XML.nodes('/XML/AVX') as Data(X)      
			--Set loop initialization varaibles    
			SELECT @I=1, @Cnt=count(*) FROM @tblVacationList 
			WHILE(@I<=@Cnt)      
			BEGIN		
				SET @TEMPxml=''
				SET @varxml=''
				SET @ddxml=''
				
				SELECT @TEMPxml=TRANSXML FROM @tblVacationList  WHERE ID=@I  
				SET @I=@I+1   
				
				set @varxml=@TEMPxml
				set @AUTOCCID=40072
				SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
				from @varxml.nodes('/ApplyVacationXML') as Data(X)
				
				set @TEmpWid=0
				SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
				from @varxml.nodes('/ApplyVacationXML') as Data(X)
				
				set @ddxml=Replace(@ddxml,'<RowHead/>','')
				set @ddxml=Replace(@ddxml,'</DOCXML>','')
				set @ddxml=Replace(@ddxml,'<DOCXML>','')
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
				
				set @ddID=0
				
				SELECT @ddID=X.value('@DocID','INT')
				from @varxml.nodes('/ApplyVacationXML') as Data(X)

				set @ActXml=''
				set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
			
				EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
				  @CostCenterID = @AUTOCCID,      
				  @DocID = @ddID,      
				  @DocPrefix = @Prefix,      
				  @DocNumber = N'',      
				  @DocDate = @DocDate,      
				  @DueDate = NULL,      
				  @BillNo = @BillNo,      
				  @InvDocXML =@ddxml,      
				  @BillWiseXML = @bxml,      
				  @NotesXML = N'',      
				  @AttachmentsXML = N'',    
				  @ActivityXML = @ActXml,       
				  @IsImport = 0,      
				  @LocationID = @LocationID,      
				  @DivisionID = @DivisionID ,      
				  @WID = @TEmpWid,      
				  @RoleID = @RoleID,      
				  @DocAddress = N'',      
				  @RefCCID = 300,    
				  @RefNodeid  = @InvDocDetailsID,    
				  @CompanyGUID = @CompanyGUID,      
				  @UserName = @UserName,      
				  @UserID = @UserID,      
				  @LangID = @LangID    
			END
		END		
		
		----------- LATES PROCESSING LEAVES POSTING

		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('LatesLeaves')) from @XML.nodes('/XML/LPL') as Data(X)
		IF(@TEMPxml<>'')
		BEGIN
			--Create temporary table to read xml data into table  
			declare @tblLPList TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX))
			--Insert XML data into temporary table
			INSERT INTO @tblLPList    
				SELECT CONVERT(NVARCHAR(MAX), X.query('.')) from @XML.nodes('/XML/LPL/LatesLeaves') as Data(X)      
			--Set loop initialization varaibles 
			SELECT @I=1, @Cnt=count(*) FROM @tblLPList 
			WHILE(@I<=@Cnt)      
			BEGIN		
				SET @TEMPxml=''
				SET @varxml=''
				SET @ddxml=''
				
				SELECT @TEMPxml=TRANSXML FROM @tblLPList  WHERE ID=@I  
				SET @I=@I+1   
				
				set @varxml=@TEMPxml
				set @AUTOCCID=40062
				SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
				from @varxml.nodes('/LatesLeaves') as Data(X)
				
				set @TEmpWid=0
				SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
				from @varxml.nodes('/LatesLeaves') as Data(X)
				
				set @ddxml=Replace(@ddxml,'<RowHead/>','')
				set @ddxml=Replace(@ddxml,'</DOCXML>','')
				set @ddxml=Replace(@ddxml,'<DOCXML>','')
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
				
				set @ddID=0
				
				SELECT @ddID=X.value('@DocID','INT')
				from @varxml.nodes('/LatesLeaves') as Data(X)

				set @ActXml=''
				set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
			
				EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
				  @CostCenterID = @AUTOCCID,      
				  @DocID = @ddID,      
				  @DocPrefix = @Prefix,      
				  @DocNumber = N'',      
				  @DocDate = @DocDate,      
				  @DueDate = NULL,      
				  @BillNo = @BillNo,      
				  @InvDocXML =@ddxml,      
				  @BillWiseXML = @bxml,      
				  @NotesXML = N'',      
				  @AttachmentsXML = N'',    
				  @ActivityXML = @ActXml,       
				  @IsImport = 0,      
				  @LocationID = @LocationID,      
				  @DivisionID = @DivisionID ,      
				  @WID = @TEmpWid,      
				  @RoleID = @RoleID,      
				  @DocAddress = N'',      
				  @RefCCID = 300,    
				  @RefNodeid  = @InvDocDetailsID,    
				  @CompanyGUID = @CompanyGUID,      
				  @UserName = @UserName,      
				  @UserID = @UserID,      
				  @LangID = @LangID    
			END
		END	
		
		----------- END :: LATES PROCESSING LEAVES POSTING

				----------- Auto Rejoin For Vacation

		set @TEMPxml=''
		if(@STATUSID=369)
		BEGIN
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('VacRejoin')) from @XML.nodes('/XML/VRJ') as Data(X)
		IF(@TEMPxml<>'')
		BEGIN
			--Create temporary table to read xml data into table  
			declare @tblLPList1 TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX))
			--Insert XML data into temporary table
			INSERT INTO @tblLPList1    
				SELECT CONVERT(NVARCHAR(MAX), X.query('.')) from @XML.nodes('/XML/VRJ/VacRejoin') as Data(X)      
			--Set loop initialization varaibles 
			SELECT @I=1, @Cnt=count(*) FROM @tblLPList1 
			WHILE(@I<=@Cnt)      
			BEGIN		
				SET @TEMPxml=''
				SET @varxml=''
				SET @ddxml=''
				
				SELECT @TEMPxml=TRANSXML FROM @tblLPList1  WHERE ID=@I  
				SET @I=@I+1   
				
				set @varxml=@TEMPxml
				set @AUTOCCID=40065
				SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
				from @varxml.nodes('/VacRejoin') as Data(X)
				
				set @TEmpWid=0
				SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
				from @varxml.nodes('/VacRejoin') as Data(X)
				
				set @ddxml=Replace(@ddxml,'<RowHead/>','')
				set @ddxml=Replace(@ddxml,'</DOCXML>','')
				set @ddxml=Replace(@ddxml,'<DOCXML>','')
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
				
				set @ddID=0
				
				SELECT @ddID=X.value('@DocID','INT')
				from @varxml.nodes('/VacRejoin') as Data(X)

				set @ActXml=''
				set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
			
				EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
				  @CostCenterID = @AUTOCCID,      
				  @DocID = @ddID,      
				  @DocPrefix = @Prefix,      
				  @DocNumber = N'',      
				  @DocDate = @DocDate,      
				  @DueDate = NULL,      
				  @BillNo = @BillNo,      
				  @InvDocXML =@ddxml,      
				  @BillWiseXML = @bxml,      
				  @NotesXML = N'',      
				  @AttachmentsXML = N'',    
				  @ActivityXML = @ActXml,       
				  @IsImport = 0,      
				  @LocationID = @LocationID,      
				  @DivisionID = @DivisionID ,      
				  @WID = @TEmpWid,      
				  @RoleID = @RoleID,      
				  @DocAddress = N'',      
				  @RefCCID = 300,    
				  @RefNodeid  = @InvDocDetailsID,    
				  @CompanyGUID = @CompanyGUID,      
				  @UserName = @UserName,      
				  @UserID = @UserID,      
				  @LangID = @LangID    
			END
		END
		END	
		
		----------- END :: Auto Rejoin For Vacation

		----------- Auto Rejoin For Leave

		set @TEMPxml=''
		if(@STATUSID=369)
		BEGIN
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('LeaveAutoRejoin')) from @XML.nodes('/XML/LRJ') as Data(X)
		IF(@TEMPxml<>'')
		BEGIN
			--Create temporary table to read xml data into table  
			declare @tblLPList2 TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX))
			--Insert XML data into temporary table
			INSERT INTO @tblLPList2    
				SELECT CONVERT(NVARCHAR(MAX), X.query('.')) from @XML.nodes('/XML/LRJ/LeaveAutoRejoin') as Data(X)      
			--Set loop initialization varaibles 
			SELECT @I=1, @Cnt=count(*) FROM @tblLPList2 
			WHILE(@I<=@Cnt)      
			BEGIN		
				SET @TEMPxml=''
				SET @varxml=''
				SET @ddxml=''
				
				SELECT @TEMPxml=TRANSXML FROM @tblLPList2  WHERE ID=@I  
				SET @I=@I+1   
				
				set @varxml=@TEMPxml
				set @AUTOCCID=40065
				SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
				from @varxml.nodes('/LeaveAutoRejoin') as Data(X)
				
				set @TEmpWid=0
				SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
				from @varxml.nodes('/LeaveAutoRejoin') as Data(X)
				
				set @ddxml=Replace(@ddxml,'<RowHead/>','')
				set @ddxml=Replace(@ddxml,'</DOCXML>','')
				set @ddxml=Replace(@ddxml,'<DOCXML>','')
				set @Prefix=''
				EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
				
				set @ddID=0
				
				SELECT @ddID=X.value('@DocID','INT')
				from @varxml.nodes('/LeaveAutoRejoin') as Data(X)

				set @ActXml=''
				set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
			
				EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
				  @CostCenterID = @AUTOCCID,      
				  @DocID = @ddID,      
				  @DocPrefix = @Prefix,      
				  @DocNumber = N'',      
				  @DocDate = @DocDate,      
				  @DueDate = NULL,      
				  @BillNo = @BillNo,      
				  @InvDocXML =@ddxml,      
				  @BillWiseXML = @bxml,      
				  @NotesXML = N'',      
				  @AttachmentsXML = N'',    
				  @ActivityXML = @ActXml,       
				  @IsImport = 0,      
				  @LocationID = @LocationID,      
				  @DivisionID = @DivisionID ,      
				  @WID = @TEmpWid,      
				  @RoleID = @RoleID,      
				  @DocAddress = N'',      
				  @RefCCID = 300,    
				  @RefNodeid  = @InvDocDetailsID,    
				  @CompanyGUID = @CompanyGUID,      
				  @UserName = @UserName,      
				  @UserID = @UserID,      
				  @LangID = @LangID    
			END
		END
		END	
		
		----------- END :: Auto Rejoin For Leave
		
		--CREATING LOAN IF NET SALARY < 0
			
			--DELETING LOAN WHICH IS CREATED FROM MONTHLY PAYROLL, WHEN NET SALARY < 0
			set @TEMPxml=''
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('DelLoanXML'))
			from @XML.nodes('/XML') as Data(X)
			if(@TEMPxml<>'')
			begin
				set @varxml=@TEMPxml
				SELECT @ddID=X.value('@DocID','INT')
				from @varxml.nodes('/DelLoanXML') as Data(X)
				
				-- DELETE DOCUMENT HERE...
				
				if(@ddID>0)
				BEGIN				    
					 EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]  
					 @CostCenterID = 40056,  
					 @DocPrefix = '',  
					 @DocNumber = '',
					 @DocID=@ddID,
					 @UserID = 1,  
					 @UserName = @UserName,  
					 @LangID = @LangID,
					 @RoleID=1
				END 
			end
			
		
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('CreateLoanXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		begin
			
			set @varxml=@TEMPxml
			set @AUTOCCID=40056
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/CreateLoanXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=X.value('@WOrkFlowID','INT')
			from @varxml.nodes('/CreateLoanXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@InvDocDetailsID,0,0
			set @ddID=0
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/CreateLoanXML') as Data(X)

			set @ActXml=''
			set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @BillNo,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @ActXml,       
			  @IsImport = 0,      
			  @LocationID = @LocationID,      
			  @DivisionID = @DivisionID ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 300,    
			  @RefNodeid  = @InvDocDetailsID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    
		END	
		
		
		declare @EmpSeqNo INT,@PayMonth DateTime,@ArXML xml,@SlNo INT
		
		IF(@CostCenterID=40054)
		BEGIN
			SET @SQL='SELECT TOP 1 @EmpSeqNo=dcCCNID51,@PayMonth=Convert(datetime,a.DueDate) 
			FROM INV_DocDetails a WITH(NOLOCK) 
			JOIN COM_DocCCData b with(nolock) ON b.InvDocDetailsID=a.InvDocDetailsID
			WHERE a.DocID='+CONVERT(NVARCHAR,@DocID)
			EXEC sp_executesql @SQL,N'@EmpSeqNo INT OUTPUT,@PayMonth DATETIME OUTPUT',@EmpSeqNo OUTPUT,@PayMonth OUTPUT

			SET @SQL='DELETE FROM PAY_EmpMonthlyArrears where EmpSeqNo=@EmpSeqNo AND PayrollMonth=@PayMonth'
			EXEC sp_executesql @SQL,N'@EmpSeqNo INT,@PayMonth DATETIME',@EmpSeqNo,@PayMonth
		END

		-- ARREARS
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('ArrearsXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		BEGIN
		
			set @varxml=@TEMPxml
			SELECT @ArXML=X.query('Rows')
			from @varxml.nodes('/ArrearsXML') as Data(X)
			
			SELECT @EmpSeqNo=X.value('@EmpSeqNo','INT'),@PayMonth=X.value('@PayrollMonth','DateTime')
			from @ArXML.nodes('/Rows/Row') as Data(X)
			
			SET @SQL='INSERT INTO PAY_EmpMonthlyArrears
			SELECT @EmpSeqNo,@PayMonth,X.value(''@ArrearsCalcMonths'',''DateTime''),X.value(''@ArrCalcMonthPayDays'',''float''),X.value(''@ArrearsCalcDays'',''float'')
			from @ArXML.nodes(''/Rows/Row'') as Data(X)'
			
			EXEC sp_executesql @SQL,N'@ArXML XML,@EmpSeqNo INT,@PayMonth DATETIME',@ArXML,@EmpSeqNo,@PayMonth
			
		END	
		-- END : ARREARS 
		
		-- ADJUSTMENTS
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('AdjustmentsXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		BEGIN
		
			set @varxml=@TEMPxml
			SELECT @ArXML=X.query('Rows')
			from @varxml.nodes('/AdjustmentsXML') as Data(X)
			
			SELECT @EmpSeqNo=X.value('@EmpSeqNo','INT'),@PayMonth=X.value('@PayrollMonth','DateTime')
			from @ArXML.nodes('/Rows/Row') as Data(X)
			
			SET @SQL='DELETE FROM PAY_EmpMonthlyAdjustments where EmpSeqNo=@EmpSeqNo AND PayrollMonth=@PayMonth
			INSERT INTO PAY_EmpMonthlyAdjustments 
			SELECT @EmpSeqNo,@PayMonth,X.value(''@AdjMonth'',''DateTime''),X.value(''@Days'',''float''),X.value(''@Remarks'',''NVARCHAR(500)'')
			from @ArXML.nodes(''/Rows/Row'') as Data(X)'
			
			EXEC sp_executesql @SQL,N'@ArXML XML,@EmpSeqNo INT,@PayMonth DATETIME',@ArXML,@EmpSeqNo,@PayMonth
			
		END	
		-- END : ADJUSTMENTS 

		-- ARREARS Details
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('ArrearsDetailXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		BEGIN
			set @varxml=@TEMPxml
			DECLARE @Q2 NVARCHAR(MAX)

			SELECT @Q2=X.value('@Query','NVARCHAR(MAX)')
			from @varxml.nodes('ArrearsDetailXML') as Data(X)

			IF(LEN(@Q2)>0)
			BEGIN
				--print @Q2
				EXEC(@Q2)
			END
						
		END	
		-- END : ARREARS Details

		-- ADJUSTMENTS Details
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('AdjustmentsDetailXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		BEGIN
			set @varxml=@TEMPxml
			DECLARE @Q1 NVARCHAR(MAX)

			SELECT @Q1=X.value('@Query','NVARCHAR(MAX)')
			from @varxml.nodes('AdjustmentsDetailXML') as Data(X)

			IF(LEN(@Q1)>0)
			BEGIN
				--print @Q1
				EXEC(@Q1)
			END
						
		END	
		-- END : ADJUSTMENTS Details
		
		-- DUES
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('DuesXML'))
		from @XML.nodes('/XML') as Data(X)
		if(@TEMPxml<>'')
		BEGIN
		
			set @varxml=@TEMPxml
			SELECT @ArXML=X.query('Rows')
			from @varxml.nodes('/DuesXML') as Data(X)
			
			SELECT @EmpSeqNo=X.value('@EmpSeqNo','INT'),@PayMonth=X.value('@PayrollMonth','DateTime')
			from @ArXML.nodes('/Rows/Row') as Data(X)
			
			SET @SQL='DELETE FROM PAY_EmpMonthlyDues where EmpSeqNo=@EmpSeqNo AND PayrollMonth=@PayMonth
			INSERT INTO PAY_EmpMonthlyDues
			SELECT @EmpSeqNo,@PayMonth,X.value(''@FieldType'',''int''),X.value(''@ComponentID'',''INT''),X.value(''@DuesPaidMonth'',''DateTime''),X.value(''@Amount'',''float'')
			from @ArXML.nodes(''/Rows/Row'') as Data(X)'
			
			EXEC sp_executesql @SQL,N'@ArXML XML,@EmpSeqNo INT,@PayMonth DATETIME',@ArXML,@EmpSeqNo,@PayMonth
			
		END	
		-- END : DUES 
		
		IF(@CostCenterID=40056)
		BEGIN
			-- LOAN GUARANTEES
			set @TEMPxml=''
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('LoanGuaranteesXML'))
			from @XML.nodes('/XML') as Data(X)
			if(@TEMPxml<>'')
			BEGIN
			
				set @varxml=@TEMPxml
				SELECT @ArXML=X.query('Rows')
				from @varxml.nodes('/LoanGuaranteesXML') as Data(X)
				
				SELECT @EmpSeqNo=X.value('@EmpSeqNo','INT'),@SlNo=X.value('@SNo','INT')
				from @ArXML.nodes('/Rows/Row') as Data(X)
				
				SET @SQL='DELETE FROM PAY_LoanGuarantees where DocID=@DocID
				INSERT INTO PAY_LoanGuarantees(DocID,GEmpSeqNo,SNo)
				SELECT @DocID,X.value(''@EmpSeqNo'',''INT''),X.value(''@SNo'',''INT'')
				from @ArXML.nodes(''/Rows/Row'') as Data(X)'
				EXEC sp_executesql @SQL,N'@ArXML XML,@DocID INT',@ArXML,@DocID
			END	
			-- END : LOAN GUARANTEES 
		END

		IF(@CostCenterID=40061) --Vacation Management -> Define Days
		BEGIN
			-- Vacation Management Define Days
			set @TEMPxml=''
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('VacManageDefineDays'))
			from @XML.nodes('/XML') as Data(X)
			if(@TEMPxml<>'')
			BEGIN
			
				set @varxml=@TEMPxml
				SELECT @ArXML=X.query('Rows')
				from @varxml.nodes('/VacManageDefineDays') as Data(X)
				
				SELECT @SlNo=X.value('@SNo','INT')
				from @ArXML.nodes('/Rows/Row') as Data(X)
				
				SET @SQL='DELETE FROM PAY_VacManageDefineDays where VMDocID=@DocID
				INSERT INTO PAY_VacManageDefineDays(VMDocID,VMVoucherNo,SNo,FromMonth,ToMonth,DaysPerMonth,ApplyToPrevMonths)
				SELECT @DocID,@VoucherNo,X.value(''@SNo'',''INT''),X.value(''@FromMonth'',''INT''),X.value(''@ToMonth'',''INT''),X.value(''@DaysPerMonth'',''FLOAT''),X.value(''@ApplyToPrevMonths'',''NVARCHAR(50)'')
				from @ArXML.nodes(''/Rows/Row'') as Data(X)'
				EXEC sp_executesql @SQL,N'@ArXML XML,@DocID INT,@VoucherNo NVARCHAR(MAX)',@ArXML,@DocID,@VoucherNo
			END	
			-- END : Vacation Management Define Days 
		END
		
		IF(@CostCenterID=40085)
		BEGIN
			-- BULK APPRAISALS
			set @TEMPxml=''
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('PayrollBulkAppraisals'))
			from @XML.nodes('/XML') as Data(X)
			if(@TEMPxml<>'')
			BEGIN
				set @varxml=@TEMPxml
				DECLARE @Q NVARCHAR(MAX),@VALUE NVARCHAR(100),@EmpNode INT,@GradeID INT,@EffectFrom DATETIME
				--print @TEMPxml
				SELECT @Q=X.value('@Query','NVARCHAR(MAX)')
				from @varxml.nodes('PayrollBulkAppraisals') as Data(X)

				SELECT @VALUE=PrefValue FROM COM_DocumentPreferences WHERE DocumentType=85 AND PREFNAME='UpdateGradeandAppraisalData'
				IF(@VALUE is not Null AND @VALUE='True')
				BEGIN 
		
					SELECT @EmpNode=X.value('@EmpID','INT'),@GradeID=X.value('@Grade','INT'),@EffectFrom=X.value('@EffectFrom','DATETIME')
					from @varxml.nodes('PayrollBulkAppraisals') as Data(X)

					IF EXISTS (	SELECT HistoryID 
								FROM COM_HistoryDetails hd 
								WHERE hd.CostCenterID=50051 AND hd.NodeID=@EmpNode AND HistoryCCID=50053
								AND ToDate IS NULL 
								)
					BEGIN
						IF EXISTS (	SELECT HistoryID 
									FROM COM_HistoryDetails hd 
									WHERE hd.CostCenterID=50051 AND hd.NodeID=@EmpNode AND HistoryCCID=50053
									AND ToDate IS NULL AND HistoryNodeID!=@GradeID
									)
						BEGIN
							Update hd SET ToDate=Convert(INT,(DATEADD(day,-1,Convert(Datetime,@EffectFrom))))
							FROM COM_HistoryDetails hd
							WHERE  hd.CostCenterID=50051 AND hd.NodeID=@EmpNode AND hd.HistoryCCID=50053 AND hd.ToDate IS NULL
	

							INSERT INTO COM_HistoryDetails
							SELECT 50051,@EmpNode,50053,@GradeID,CONVERT(INT,@EffectFrom),NULL,'','admin',CONVERT(FLOAT,GETDATE()),'admin',CONVERT(FLOAT,GETDATE())
						
							SET @SQL='UPDATE COM_CCCCData SET CCNID53='+CONVERT(NVARCHAR,@GradeID)+' where CostCenterID=50051 AND NodeID='+CONVERT(NVARCHAR,@EmpNode)
							EXEC sp_executesql @SQL
						END
					END
					ELSE
					BEGIN
						INSERT INTO COM_HistoryDetails
						SELECT 50051,@EmpNode,50053,@GradeID,CONVERT(INT,@EffectFrom),NULL,'','admin',CONVERT(FLOAT,GETDATE()),'admin',CONVERT(FLOAT,GETDATE())
						
						SET @SQL='UPDATE COM_CCCCData SET CCNID53='+CONVERT(NVARCHAR,@GradeID)+' where CostCenterID=50051 AND NodeID='+CONVERT(NVARCHAR,@EmpNode)
						EXEC sp_executesql @SQL
					END

				END

				IF(LEN(@Q)>0)
				BEGIN
					print @Q
					if(@STATUSID=369)
					BEGIN
						EXEC(@Q)
					END
				END
			END	
			-- END : BULK APPRAISALS
		END

		IF(@CostCenterID=40072) --Apply Vacation -> Contract
		BEGIN
			-- Vacation Contract
			set @TEMPxml=''
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('VacContract'))
			from @XML.nodes('/XML') as Data(X)
			if(@TEMPxml<>'')
			BEGIN
			
				set @varxml=@TEMPxml
				SELECT @ArXML=X.query('Rows')
				from @varxml.nodes('/VacContract') as Data(X)
				
				SELECT @SlNo=X.value('@SNo','INT')
				from @ArXML.nodes('/Rows/Row') as Data(X)
				
				SET @SQL='DELETE FROM PAY_EmpDetail where Field1=CONVERT(NVARCHAR(max),@DocID)
				INSERT INTO PAY_EmpDetail(EmployeeID,DType,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,Field1,Field2,Field3,Field4,Field5,Field6,Field7,Field8,Field9,Field10)
				SELECT X.value(''@ContractNodeID'',''INT''),''-72000'','''+@UserName+''', @Dt,'''+@UserName+''', @Dt,CONVERT(NVARCHAR(max),@DocID),'''+@VoucherNo+''',X.value(''@SNo'',''INT''),X.value(''@ContractFrom'',''DATETIME''),X.value(''@ContractTo'',''DATETIME''),X.value(''@CreditedDays'',''FLOAT''),X.value(''@PrevTakenDays'',''FLOAT''),X.value(''@BalanceDays'',''FLOAT''),X.value(''@CanAvail'',''FLOAT''),X.value(''@ContractCreditedDays'',''FLOAT'')
				from @ArXML.nodes(''/Rows/Row'') as Data(X)'
				
				EXEC sp_executesql @SQL,N'@ArXML XML,@DocID INT,@Dt FLOAT',@ArXML,@DocID,@Dt
			END	
			-- END : Vacation Contract
		END
				
		set @EXTRAXML=''
		SELECT @EXTRAXML=CONVERT(NVARCHAR(MAX), X.query('DocFlowXML'))
		from @XML.nodes('/XML') as Data(X)	
		if(@EXTRAXML is not null and CONVERT(nvarchar(max),@EXTRAXML)<>'')		
		BEGIN
			select @tempDOc=X.value('@ProfileID','INT'),@ACCOUNT1=X.value('@RefCCID','INT'),@ACCOUNT2=X.value('@RefNodeID','INT'),@Series=X.value('@RefStatID','INT')		
			from @EXTRAXML.nodes('/DocFlowXML') as Data(X)
			
			exec @return_value =[spDOC_SetDocFlow] 
					  @CCID= @CostCenterID,
					  @DocID =@DocID,
					  @ProfileID=@tempDOc,
					  @RefCCID=@ACCOUNT1,
					  @RefNodeID=@ACCOUNT2,
					  @RefStatusID=@Series,
					  @UserName=@UserName,
					  @UserID=@UserID,      
					  @LangID=@LangID
		END
  end
	
	set @CaseID=0
	select @CaseID=isnull(value,0) from @TblPref 
	where IsGlobal=1 and Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
	
	if(@CaseID>0)
	BEGIN
	
		set @SQL='select @NID=dcCCNID'+convert(nvarchar,(@CaseID-50000))+' from COM_DocCCData  WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
		
		EXEC sp_executesql @SQL, N'@NID float OUTPUT', @NID OUTPUT   
		
		SELECT @BatchID=Value FROM @TblPref WHERE IsGlobal=1 AND Name='BaseCurrency'
		
		SELECT @WHERE=Value FROM @TblPref WHERE IsGlobal=1 AND Name='DecimalsinAmount'
		
		SELECT @Tot=ExchangeRate  FROM  COM_EXCHANGERATES WITH(NOLOCK) 
		where CurrencyID = @BatchID AND EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
		and DimNodeID=@NID ORDER BY EXCHANGEDATE DESC
		
		
		set @SQL='update INV_DocDetails
			set StockValueBC=round(StockValue/'+convert(nvarchar,@Tot)+','+@WHERE+'),ExhgRtBC='+convert(nvarchar,@Tot)+'
			where CostCenterID='+convert(nvarchar,@CostCenterID)+' and DocID='+convert(nvarchar,@DocID)+'
			
			update ACC_DocDetails 
			set AmountBC=round(Amount/'+convert(nvarchar,@Tot)+','+@WHERE+'),ExhgRtBC='+convert(nvarchar,@Tot)+'
			from ACC_DocDetails a WITH(NOLOCK) 
			join INV_DocDetails b WITH(NOLOCK)  on a.InvDocDetailsID=b.InvDocDetailsID
			where b.CostCenterID='+convert(nvarchar,@CostCenterID)+' and b.DocID='+convert(nvarchar,@DocID)+'
			
			update COM_Billwise 
			set AmountBC=round(AdjAmount/'+convert(nvarchar,@Tot)+','+@WHERE+'),ExhgRtBC='+convert(nvarchar,@Tot)+'
			where DocNo='''+@VoucherNo+''''
		
		exec(@sql)
		
	END
  
		set @fldName=''
		select @fldName=SysColumnName from ADM_CostCenterDef WIth(NOLOCK) 
		where LinkData=55489 and LocalReference=79 and CostCenterID=@CostCenterID
		SET @SQL=''
		if(@fldName like 'dcalpha%')
			set @SQL='update [COM_DocTextData]
			set '+@fldName+'=d.InvDocDetailsID
			from INV_DOcDetails d with(nolock)
			where d.InvDocDetailsID=COM_DocTextData.InvDocDetailsID and DOCID='+convert(nvarchar,@DocID)
		else if(@fldName like 'dcnum%')
			set @SQL='update [COM_DocNumData]
			set '+@fldName+'=d.InvDocDetailsID
			from INV_DOcDetails d with(nolock)
			where d.InvDocDetailsID=COM_DocNumData.InvDocDetailsID and DOCID='+convert(nvarchar,@DocID)
				
		exec(@SQL)
  
  
    -- SAVING CASE CONTACTS
  IF (@documenttype=35)  
  BEGIN  
	SET @XML=@ActivityXML 
  
	DELETE FROM COM_Contacts 
	WHERE FeatureID = @CostCenterID AND FeaturePK = @DocID
  
   
   --If Action is NEW then insert new contacts  
   INSERT INTO COM_Contacts(AddressTypeID,FeatureID,FeaturePK,ContactName ,FirstName,MiddleName,
   LastName,SalutationID,JobTitle,Company,Department,RoleLookupId,
   CostCenterID,  
   Address1,Address2,Address3,  
   City,State,Zip,Country,  
   Phone1,Phone2,Fax,Email1,Email2,URL,  
   GUID,CreatedBy,CreatedDate)  
   SELECT ISNULL( X.value('@AddressTypeID','int'),1),@CostCenterID,@DocID,X.value('@ContactName','NVARCHAR(500)'),X.value('@FirstName','NVARCHAR(500)'),X.value('@MiddleName','NVARCHAR(500)'),X.value('@LastName','NVARCHAR(500)'),  
   X.value('@SalutationID','int'),X.value('@JobTitle','NVARCHAR(500)'),X.value('@Company','NVARCHAR(500)'),X.value('@Department','NVARCHAR(500)'),X.value('@RoleLookup','NVARCHAR(500)'),2,X.value('@Address1','NVARCHAR(500)'),X.value('@Address2','NVARCHAR(500)'),X.value('@Address3','NVARCHAR(500)'),  
   X.value('@City','NVARCHAR(100)'),X.value('@State','NVARCHAR(100)'),X.value('@Zip','NVARCHAR(50)'),X.value('@Country','NVARCHAR(100)'),  
   X.value('@Phone1','NVARCHAR(50)'),X.value('@Phone2','NVARCHAR(50)'),X.value('@Fax','NVARCHAR(50)'),X.value('@Email1','NVARCHAR(50)'),X.value('@Email2','NVARCHAR(50)'),X.value('@URL','NVARCHAR(50)'),  
   @Guid,@UserName,@Dt  
   FROM @XML.nodes('/XML/ContactXML/Row') as Data(X)  
   
  END 
  
 -- --Asset Transfer
 -- IF (@DocumentType=5 and exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and PrefName='IsAssetTransfer' and PrefValue='True')
	--and not exists (select DocID from INV_DocDetails with(nolock) where DocID=@DocID and VoucherType=1 and StatusID!=369))
 -- BEGIN
	--EXEC spDoc_SetAssetTransfer @CostCenterID,@DocID
 -- END
	
	--Budget Definition
	if exists (SELECT Value FROM @TblPref where IsGlobal=0 and  Name='IsBudgetDocument' and Value='1')
	begin
		if(@documenttype=5 or @documenttype = 8 or @documenttype = 13)
			exec [spDoc_UpdateBudget] @CostCenterID,@DOCID,@CompanyGUID,@UserName
		ELSE	
			EXEC spDoc_SetBudgetDefn @CostCenterID,@DOCID,@CompanyGUID,@UserName
		--ROLLBACK TRANSACTION
		--RETURN
	end
  
	--Notification On Revision
	IF @IsRevision=1
	BEGIN
		EXEC spCOM_SetNotifEvent -2,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
	END
	--Notification On Add/Edit
	ELSE IF(@StatusID!=371 OR (select Value from @TblPref where IsGlobal=0 and  Name='DoNotEmailOrSMSUn-ApprovedDocuments')='FALSE')
	BEGIN
		DECLARE @ActionType INT
		IF @HistoryStatus='Add'
			SET @ActionType=1
		ELSE
			SET @ActionType=3		
		EXEC spCOM_SetNotifEvent @ActionType,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
	END
	
	if (@StatusID=369 and @HistoryStatus='Add' and exists(select Value from @TblPref where Name='DocDateasPostedDate' and Value='true'))
	BEGIN
	
		update inv_docdetails
		set docdate=floor(@dt)
		where costcenterid=@CostCenterID and DocID=@DocID
		
		update acc_docdetails
		set docdate=floor(@dt)
		from ACC_DocDetails a WITH(NOLOCK) 
		join INV_DocDetails b WITH(NOLOCK)  on a.InvDocDetailsID=b.InvDocDetailsID
		where b.CostCenterID=@CostCenterID and b.DocID=@DocID
		
		update T set T.docdate=floor(@dt)
		 FROM COM_Billwise T WITH(NOLOCK)
		where T.DocNo=@VoucherNo
	END

	
	--validate Data External function
	set @tempCode=''
	select @tempCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=9
	if(@tempCode<>'')
	begin
		--select @tempCode,@CostCenterID,@DocID,@UserID,@LangID
		exec @tempCode @CostCenterID,@DocID,@UserID,@LangID
	end
	
	if(@WID is not null and @WID>0 and @StatusID=441)
	begin
		set @tempCode=''
		select @tempCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=12
		if(@tempCode<>'')
			exec @tempCode @CostCenterID,@DocID,@UserID,@LangID
	end
	
	if(@WID is not null and @WID>0 and @StatusID=372)
	begin
		set @tempCode=''
		select @tempCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=16
		if(@tempCode<>'')
			exec @tempCode @CostCenterID,@DocID,@UserID,@LangID
	end
	
	if exists(select value from @TblPref where IsGlobal=1 and Name='ReportDims' and Value<>'')
	BEGIN
			select @SQL=Description from adm_globalpreferences with(nolock) where Name='ReportDims'
			
			SET @SQL=' Update Inv_DocDetails set '+@SQL+' from com_docccdata a with(nolock) 
			where docid='+convert(nvarchar(max),@DocID)+' and a.InvDocDetailsID=Inv_DocDetails.InvDocDetailsID
			 Update Acc_DocDetails set '+@SQL+' 
			 from Inv_DocDetails I  with(nolock)
			 join com_docccdata a with(nolock) on i.InvDocDetailsID=a.InvDocDetailsID
			 where i.Docid= '+convert(nvarchar(max),@DocID)+' and I.InvDocDetailsID=Acc_DocDetails.InvDocDetailsID'
			
			exec(@SQL)

	END
	
	--Worksheet Linked field
	--IF(@CostCenterID=40054 AND @DocID>0)
	--BEGIN
	--	DECLARE @MPPayrollMonth datetime,@MPInvdocDetailsID INT,@MPEmpNode Int
	--	SELECT TOP 1 @MPPayrollMonth=convert(datetime,td.dcAlpha17),@MPInvdocDetailsID=ID.InvDocDetailsID,@MPEmpNode=cc.dcccnid51 
	--	From Inv_Docdetails ID with(nolock),Com_DocTextData td with(nolock),Com_DocCCData cc with(nolock)
	--	WHERE ISDATE(td.dcAlpha17)=1 AND id.Costcenterid=40054 and id.invdocdetailsid=td.invdocdetailsid and id.invdocdetailsid=cc.invdocdetailsid  and ID.DocID=@DocID 
			   
	--	IF((SELECT count(*) from INV_DOCDETAILS ID WITH(NOLOCK)
	--			INNER JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
	--			INNER JOIN COM_DocCCData CC WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
	--			WHERE ISDATE(td.dcAlpha1)=1 AND ID.COSTCENTERID=40079 AND CC.dccCNID51=@MPEmpNode AND CONVERT(DATETIME,TD.dcAlpha1)=CONVERT(DATETIME,@MPPayrollMonth))>0)
	--	BEGIN
	--			UPDATE ID SET ID.LinkedInvDocDetailsID=@MPInvdocDetailsID,RefCCID=300,RefNodeid=@MPInvdocDetailsID
	--			FROM INV_DOCDETAILS ID WITH(NOLOCK)	INNER JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
	--			INNER JOIN COM_DocCCData CC WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
	--			WHERE ISDATE(td.dcAlpha1)=1 AND ID.COSTCENTERID=40079 AND CC.dccCNID51=@MPEmpNode AND CONVERT(DATETIME,TD.dcAlpha1)=CONVERT(DATETIME,@MPPayrollMonth)
	--	END
	--END

	--IF(@CostCenterID=40072 AND @DocID>0)
	--BEGIN
	--	DECLARE @AutoRejoin BIT
	--	SELECT @AutoRejoin=CONVERT(BIT,PrefValue) FROM com_documentpreferences WITH(NOLOCK) WHERE PrefName='AutoRejoinVacation'
	--	IF @AutoRejoin=1
	--	BEGIN
			
	--		SET @SQL=' UPDATE T SET T.DCALPHA1=CONVERT(VARCHAR(20), DATEADD(D,1,CONVERT(DATETIME,T.DCALPHA3)), 100) FROM INV_DocDetails I WITH(NOLOCK)
	--		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
	--		WHERE T.tCostCenterID=40072 AND DocID='+convert(nvarchar(max),@DocID) 
	--		exec(@SQL)
	--	END
	--END

	--Delegation
	IF(@DocumentType=98 AND @DocID>0 AND @StatusID=369) --DELEGATION
	BEGIN
		DECLARE @DType NVARCHAR(50),@FE INT,@TE INT,@col NVARCHAR(MAX)
		
		SET @SQL='SELECT @DType=ISNULL(t.dcAlpha3,''''),@FE=dcCCNID51,@TE=CONVERT(INT,t.dcAlpha1) 
		FROM INV_DocDetails a WITH(NOLOCK) 
		JOIN COM_DocTextData t WITH(NOLOCK) on t.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
		WHERE ISNUMERIC(t.dcAlpha1)=1 AND DocID='+CONVERT(NVARCHAR,@DocID) 
		
		EXEC sp_executesql @SQL,N'@DType NVARCHAR(50) OUTPUT,@FE INT OUTPUT,@TE INT OUTPUT',@DType OUTPUT,@FE OUTPUT,@TE OUTPUT
		
		IF(@DType='Permanent')
		BEGIN
			--UPDATE REPORTING MANAGAER HERE..
			--SET @SQL='	UPDATE COM_CC50051 
			--			SET RptManager='+CONVERT(NVARCHAR,@TE)+' 
			--			WHERE RptManager='+CONVERT(NVARCHAR,@FE)

		SET @SQL='SELECT @col=STUFF((
			select '',''+CH.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			JOIN (select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name=''COM_cc50051_History'') AS CH ON CH.name=a.name
			where b.name=''COM_cc50051'' and a.name not in (''ModifiedBy'',''ModifiedDate'') FOR XML PATH('''')),1,1,'''')'
			
			EXEC sp_executesql @SQL,N'@col NVARCHAR(MAX) OUTPUT',@col OUTPUT
			
		SET @SQL='	DECLARE @I INT,@CNT INT,@EMPNODEID BIGINT,@Audit NVARCHAR(100)
			DECLARE @T1 TABLE(ID INT IDENTITY,EMPNODEID BIGINT)

			SELECT @Audit=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=50051 and Name=''AuditTrial''

			INSERT INTO @T1
			SELECT NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE RptManager='+CONVERT(NVARCHAR,@FE)+'

			UPDATE COM_CC50051 SET RptManager='+CONVERT(NVARCHAR,@TE)+' WHERE RptManager='+CONVERT(NVARCHAR,@FE)+'

			IF(@Audit IS NOT NULL AND @Audit=''True'')
			BEGIN
			SELECT @CNT=COUNT(*) FROM @T1
			SET @I=1
			WHILE(@I<=@CNT)
			BEGIN
				SELECT @EMPNODEID=EMPNODEID FROM @T1 WHERE ID=@I

				insert into [COM_CC50051_History](CostCenterID,HistoryStatus,ModifiedBy,ModifiedDate,'+@col+')         
				select 50051,''Update'','''+CONVERT(NVARCHAR,@UserName)+''','+CONVERT(NVARCHAR,CONVERT(DECIMAL(10,5),@dt))+','+@col+' FROM COM_CC50051 WITH(NOLOCK) 
				WHERE NODEID=@EMPNODEID	
			SET @I=@I+1
			END
			END
			'
			EXEC sp_executesql @SQL

		END
	END


	IF(@DocumentType=220) -- Bid Open
	BEGIN
		set @SQL=' EXEC spCOM_PostBiddingDocs '+CONVERT(NVARCHAR,@CostCenterID)+','+CONVERT(NVARCHAR,@DocID)
		EXEC(@SQL)
	END

COMMIT TRANSACTION  
--ROLLBACK TRANSACTION 
     
select @temp=ResourceData from COM_Status S  WITH(NOLOCK)   
join COM_LanguageResources R WITH(NOLOCK) on R.ResourceID=S.ResourceID and R.LanguageID=@LangID
where S.StatusID=@StatusID    
     
SELECT ErrorMessage + N'   ' + isnull(@VoucherNo,'voucherempty') +' ['+@temp+']'  as ErrorMessage,ErrorNumber,@VoucherNo VoucherNo,@StatusID StatusID
FROM COM_ErrorMessages WITH(nolock)
WHERE ErrorNumber=105 AND LanguageID=@LangID

SET NOCOUNT OFF;        
RETURN @DocID
END TRY        
BEGIN CATCH  

	 if(@return_value is not null and  @return_value=-999 or @DimesionNodeID=-999)         
	 return -999
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000      
 BEGIN     
 IF ISNUMERIC(ERROR_MESSAGE())<>1
 BEGIN
	SELECT ERROR_MESSAGE() ErrorMessage
 END
  
  else if(ERROR_MESSAGE()=-127)    
  begin    
   set @VoucherNo=(select top 1 VoucherNo from [INV_DocDetails] WITH(NOLOCK) where LinkedInvDocDetailsID in (SELECT InvDocDetailsID FROM [INV_DocDetails]    
   WHERE CostCenterID=@CostCenterID AND DocPrefix=@DocPrefix AND DocNumber=@DocNumber))    
       
   SELECT ErrorMessage+' '+@VoucherNo as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
  end    
  else IF (ERROR_MESSAGE() LIKE '-539' )    
  BEGIN    
   SELECT   replace(ErrorMessage,'##BIN##',@tempCode)+ @ProductName ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as     
   ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)      
   WHERE ErrorNumber=-539 AND LanguageID=@LangID      
  END
   else IF (ERROR_MESSAGE() LIKE '-538' )    
  BEGIN    
   SELECT   replace(ErrorMessage,'##BIN##',@ProductName)+ CONVERT(NVARCHAR, @I -1 ) ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as     
   ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)      
   WHERE ErrorNumber=-539 AND LanguageID=@LangID      
  END
   else IF (ERROR_MESSAGE() LIKE '-346' )    
  BEGIN    
   SELECT   @TYPE +  replace(ErrorMessage,'#ROWNO#',CONVERT(NVARCHAR, @I -1 ) )  + @QUERYTEST ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as     
   ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)      
   WHERE ErrorNumber=-346 AND LanguageID=@LangID      
  END 
  else IF (ERROR_MESSAGE() in('-364','-541','-542','-549'))    
  BEGIN    
   SELECT   replace(ErrorMessage,'##PROD##',@ProductName)  + CONVERT(NVARCHAR, @I -1 ) ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as     
   ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)      
   WHERE ErrorNumber=ERROR_MESSAGE()  AND LanguageID=@LangID      
  END  
  else IF (ERROR_MESSAGE() in('-380','-387','-406','-510','-509','-511','-521','-537','-538','-566'))    
  BEGIN    
	  SELECT ErrorMessage + @ProductName  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
	  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
  END   
  else IF (ERROR_MESSAGE() ='-407')
  BEGIN    
	     SELECT @temp=ErrorMessage FROM COM_ErrorMessages WITH(nolock)      
	  WHERE ErrorNumber=-576 AND LanguageID=@LangID 
	  set @ProductName=@ProductName+@temp+CONVERT(NVARCHAR,@holseq)
	WHILE(@I<@Cnt and @IsImport=0)        
	BEGIN      
		SET @I=@I+1    
	   
		SELECT  @xml=CONVERT(NVARCHAR(MAX),TransactionRows) FROM @tblList  WHERE ID=@I        
	  
		SELECT @TRANSXML=CONVERT(NVARCHAR(MAX), X.query('Transactions')),@CCXML=CONVERT(NVARCHAR(MAX),X.query('CostCenters'))
		from @xml.nodes('/Row') as Data(X) 
		 
		SELECT @IsQtyIgnored=isnull(X.value('@IsQtyIgnored','bit'),1),@ProductID =ISNULL(X.value('@ProductID','INT') ,0),@holseq =ISNULL(X.value('@DocSeqNo','INT') ,0)
		,@ProductType=a.ProductTypeID,@tempCode=ProductName,@ddxml=ProductCode+'-'+ProductName,@QthChld=isnull(X.value('@UOMConvertedQty','Float'),0)
		from @TRANSXML.nodes('/Transactions') as Data(X)   
		join INV_Product a with(nolock) on X.value('@ProductID','INT')=a.ProductID
		
		if exists(select value from @TblPref where IsGlobal=1 and Name='ShowProdCodeinErrMsg' and Value='true')
			set @tempCode=@ddxml
		
		
		if(@tempProd<>@ProductID and @VoucherType=-1 and @productType not in(6,8) and (@IsQtyIgnored=0 or (@IsQtyIgnored=1 and exists(select ISNULL( X.value('@HoldQuantity','float'),0)  from @TRANSXML.nodes('/Transactions') as Data(X)
		where ISNULL( X.value('@HoldQuantity','float'),0)>0 or ISNULL( X.value('@ReserveQuantity','float'),0)>0 )
		and exists(select Value from @TblPref where IsGlobal=1 and Name='ConsiderHoldAndReserveAsIssued' and value='true'))))
		BEGIN		
			set @WHERE=''
			if(@loc=1)
			BEGIN				
				set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@LocationID)        
			END

			if(@div=1)
			BEGIN				
				set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@DivisionID)        
			END
			
			if(@dim>0)
			BEGIN
			
				 SET @NID=1
					
				 set @SYSCOL='dcCCNID'+CONVERT(NVARCHAR,(@dim))+'='
				 set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@CCXML))
				 if(@ind>0)
				 BEGIN
					 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL,convert(nvarchar(max),@CCXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
						set @NID=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt)  
				 END
				 
				set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,@dim)+'='+CONVERT(nvarchar,@NID)        
			END
			set @QtyFin=0
			set @DUPLICATECODE='set @QtyFin=(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID='+convert(nvarchar,@ProductID) 
			
			set @DUPLICATECODE=@DUPLICATECODE+' and DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))
			
			set @DUPLICATECODE=@DUPLICATECODE+' AND IsQtyIgnored=0 '+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
		    
		    if exists(select Value from @TblPref where IsGlobal=1 and Name='ConsiderHoldAndReserveAsIssued' and value='true')
			BEGIN
				set @DUPLICATECODE=@DUPLICATECODE+'set @QtyFin=@QtyFin-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0 then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1'
				 
				 set @DUPLICATECODE=@DUPLICATECODE+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				  
				 set @DUPLICATECODE=@DUPLICATECODE+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
				
				 set @DUPLICATECODE=@DUPLICATECODE+'set @QtyFin=@QtyFin-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0 then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release    
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1'
				 
				 set @DUPLICATECODE=@DUPLICATECODE+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				  
				 set @DUPLICATECODE=@DUPLICATECODE+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
			 END

		    if exists(select Value from @TblPref where IsGlobal=1 and Name='ConsiderExpectedAsReceived' and value='true')			
			BEGIN			 
				 set @DUPLICATECODE=@DUPLICATECODE+'set @QtyFin=@QtyFin+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0 then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1'
				  
				 set @DUPLICATECODE=@DUPLICATECODE+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				 set @DUPLICATECODE=@DUPLICATECODE+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
			END
			 
	    
			EXEC sp_executesql @DUPLICATECODE, N'@QtyFin float OUTPUT', @QtyFin OUTPUT   
			
			set @QtyFin=@QtyFin-@QthChld
			
			if(@QtyFin<-0.001)
			BEGIN
				set @ProductName=@ProductName+'
				'+@tempCode +@temp+CONVERT(NVARCHAR,@holseq)
			END	 
				
		END
	 END			
  
	  SELECT ErrorMessage + @ProductName  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
	  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
  END   
  ELSE IF (ERROR_MESSAGE() LIKE '-347' )    
  BEGIN    
   SELECT   @TYPE + ErrorMessage  + @QUERYTEST  as ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as     
   ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)      
   WHERE ErrorNumber=-347 AND LanguageID=@LangID      
  END    
 ELSE IF (ERROR_MESSAGE() in('-375', '-374'))
 BEGIN   
	if(@ProductName is null)
	BEGIN
		if(@VoucherType=1)
			SELECT @ProductName = ACCOUNTNAME FROM ACC_ACCOUNTS WITH(NOLOCK) WHERE ACCOUNTID = @ACCOUNT2     
		else
			SELECT @ProductName = ACCOUNTNAME FROM ACC_ACCOUNTS WITH(NOLOCK) WHERE ACCOUNTID = @ACCOUNT1		
	END 
	IF(@VoucherType=1)		
			SET @SQL='SELECT   @Vno=voucherno   FROM [INV_DocDetails] WITH(NOLOCK) WHERE   [CostCenterID] in('+@PrefValue+') and 
			CreditAccount = @ACCOUNT2  and  DocID<>@DocID  and  [BillNo] = @BillNo and convert(datetime,DocDate) between @frdate and @toDate and StatusID<>376'
	else
			SET @SQL='SELECT   @Vno=voucherno   FROM [INV_DocDetails] WITH(NOLOCK) WHERE  [CostCenterID] in('+@PrefValue+') and 
			DebitAccount = @ACCOUNT1  and  DocID<>@DocID  and  [BillNo] = @BillNo  and convert(datetime,DocDate) between @frdate and @toDate and StatusID<>376 '
	exec sp_executesql @SQL,N'@ACCOUNT2 INT,@ACCOUNT1 INT,@frdate datetime,@toDate datetime,@DocID INT,@BillNo  NVARCHAR(500),@Vno nvarchar(500) output',@ACCOUNT2,@ACCOUNT1,@frdate,@toDate,@DocID,@BillNo,@Vno OUTPUT	

	
  SELECT ErrorMessage + @ProductName+'('+@Vno+')'  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END   
  ELSE IF (ERROR_MESSAGE() LIKE '-389')     
 BEGIN      
	   select @VoucherNo=VoucherNo from [INV_DocDetails] WITH(NOLOCK) where [LinkedInvDocDetailsID]=@LinkedID

  SELECT ErrorMessage + @VoucherNo  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END 
   ELSE IF (ERROR_MESSAGE() LIKE '-519')     
 BEGIN      
  SELECT ErrorMessage + ' Product Name : '+ @ProductName+' at Row No: ' + CONVERT(NVARCHAR, @I -1 )   as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END 
  ELSE IF (ERROR_MESSAGE() in('-547','-506'))     
 BEGIN      
  SELECT ErrorMessage + @ProductName   as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END   
 ELSE IF (ERROR_MESSAGE() = '-377' or ERROR_MESSAGE() = '-502' or ERROR_MESSAGE() = '-532'or ERROR_MESSAGE() = '-571' )     
 BEGIN
	if(ERROR_MESSAGE() = '-377' and isnull(@fldName,'')<>'' and isnull(@fldName,'')<>'Quantity')
	begin
		SELECT ('Enter '+@fldName + ' sum exceeds linked '+@fldName+' at Row No: ' + case when @I=1 and @bi>0 then 'deleted' else CONVERT(NVARCHAR, @I -1 ) end) AS ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
		--select 'Enter '+@fldName + ' sum exceeds linked '+@fldName+' at Row No: '  AS ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
	end 
	else
	begin
		SELECT (ErrorMessage + case when @I=1 and @bi>0 then 'deleted' else CONVERT(NVARCHAR, @I -1 ) end)  AS ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
	end      
  
 END   
 ELSE IF (ERROR_MESSAGE() LIKE '-378' )     
 BEGIN      
  SELECT 'Unique Document Exists: ' + @VoucherNo   as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
  --FROM COM_ErrorMessages WITH(nolock)      
  --WHERE ErrorNumber=-375 AND LanguageID=@LangID      
 END   
  ELSE    
  BEGIN    
    --SELECT * FROM INV_DocDetails WITH(nolock) WHERE DocID=@DocID        
    SELECT  ERROR_MESSAGE() AS ServerMessage, ErrorMessage,ErrorNumber, ERROR_NUMBER() as ErrorNumber,ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)       
    WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
  END    
 END      
    
 ELSE IF ERROR_NUMBER()=547      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=-110 AND LanguageID=@LangID      
 END      
 ELSE IF ERROR_NUMBER()=2627      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=-116 AND LanguageID=@LangID      
 END      
 ELSE IF ERROR_NUMBER()=1205      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=-350 AND LanguageID=@LangID      
 END    
 ELSE      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
 END    
 if(@return_value is null or  @return_value<>-999)   
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
    
END CATCH

GO
