USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetTempAccDocument]
	@CostCenterID [int],
	@DocID [int],
	@DocPrefix [nvarchar](50),
	@DocNumber [nvarchar](500),
	@DocDate [datetime],
	@DueDate [datetime] = NULL,
	@BillNo [nvarchar](500),
	@InvDocXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@ActivityXML [nvarchar](max),
	@IsImport [bit],
	@LocationID [int],
	@DivisionID [int],
	@WID [int],
	@RoleID [int],
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
	DECLARE @QUERYTEST NVARCHAR(100), @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100),@ii int,@ccnt int ,@SYSCOL NVARCHAR(50) ,@ind int,@indcnt int 
	DECLARE @Dt float,@XML XML,@DocumentTypeID INT,@HasAccess int ,@DocumentType INT,@DocAbbr nvarchar(50),@tempDOc INT,@LCStatus nvarchar(500)    
	DECLARE @AccDocDetailsID INT,@I int,@Cnt int,@ACCOUNT1Name nvarchar(500),@ACCOUNT2Name nvarchar(500),@ReviseReason NVARCHAR(max)    
	DECLARE @DrAcc INT,@CrAcc INT,@ACCOUNT1 INT,@ACCOUNT2 INT,@Amount FLOAT,@HistoryStatus nvarchar(50),@WorkFlow  nvarchar(50),@AP varchar(10)   
	DECLARE @TRANSXML XML,@NUMXML XML,@CCXML XML,@TEXTXML XML,@EXTRAXML XML,@DiscXML NVARCHAR(max),@TEMPxml NVARCHAR(max),@AccountsXML xml,@batchID INT,@ActXML xml  
	DECLARE @VoucherNo NVARCHAR(500),@Length int,@temp varchar(100),@t int,@DOCSEQNO INT,@VersionNo INT,@ReturnXML  xml,@Denominationxml xml  
	DECLARE @return_value int ,@BankAccountID INT,@IsRevision BIT,@AppRejDate datetime,@Remarks nvarchar(max),@ChWID INT,@IsLockedPosting BIT			    
	DECLARE @amt float,@accid INT,@IsNewReference bit,@RefDocNo nvarchar(200), @RefDocSeqNo int,@RefDocDate FLOAT,@RefDueDate FLOAT,@ManaProp BIT
	declare @Series INT,@ConCCID INT,@prefixccid INT,@PrefValue NVARCHAR(500),@oldStatus int, @Chequeno nvarchar(100),@vno nvarchar(100)
	declare @level int,@maxLevel int,@StatusID INT,@DocOrder int,@IsPcode bit,@oldseqno int,@oldVoucherNo nvarchar(200),@DELETEDOCID INT,@TEmpWid INT,@tempLevel INT
	declare  @Dimesion INT,@DimesionNodeID INT,@cctablename nvarchar(50),@DUPLICATECODE  NVARCHAR(MAX),@IsLineWisePDC bit,@PDCDocument int,@DocCC nvarchar(max),@CCreplCols nvarchar(max)
	Declare @LockCrAcc INT,@LockDrAcc INT,@AccType nvarchar(max),@CAccountTypeID INT,@DAccountTypeID INT,@sysinfo nvarchar(max),@CC nvarchar(max)
	declare @table table(TypeID nvarchar(50))
	declare @EndNo INT,@ChequeBookNo nvarchar(max),@CurrentChequeNumber nvarchar(max),@PrefVal nvarchar(50),@ScheduleID INT,@StNo INT
	declare @Refstatus int,@DELETECCID INT,@NID INT,@DLockCC INT,@DLockCCValues NVARCHAR(max),@LockCC INT,@LockCCValues NVARCHAR(max)
	DECLARE @DELDocPrefix NVARCHAR(50),@Iscode BIT,@DELDocNumber NVARCHAR(500),@Guid nvarchar(100),@CCGuid nvarchar(100),@isCrossDim BIT,@CrossDimension INT,@CrossDimFld nvarchar(50)
	declare @ttdel table(id int identity(1,1),accid INT)
	declare @Currid int, @ExchRate float, @Amtfc float,@refSt int,@Columnname nvarchar(100),@BillDate float,@DontChangeBillwise bit,@IgnoreConvertedPDC bit
	
	set @IgnoreConvertedPDC=0
	--Loading Global Preferences
	DECLARE @TblPref AS TABLE(Name nvarchar(100),Value nvarchar(max))
	INSERT INTO @TblPref
	SELECT Name,Value FROM ADM_GlobalPreferences with(nolock)
	WHERE Name IN ('LockTransactionAccountType','UseDimWiseLock','DoNotAllowFutureDateDays','LockCostCenterNodes','NoFuturetransaction','Nobackdatedtransaction'
	,'LockCostCenters','ReportDims','EnableCrossDimension','DocDateasPostedDate','CrossDimension','Lock Data Between','Intermediate PDC','DimensionwiseCurrency','BaseCurrency','DecimalsinAmount','DoNotAllowPastDateDays','NoPasttransaction')
	 
	--Loading Document Preferences
	DECLARE @TblDocPref AS TABLE(PrefName nvarchar(100),PrefValue nvarchar(max))
	INSERT INTO @TblDocPref
	SELECT PrefName,PrefValue FROM COM_DocumentPreferences with(nolock)
	WHERE CostCenterID=@CostCenterID and (PrefName='DocumentLinkDimension' or PrefName='LineWisePDC' or PrefName='PDCDocument' or PrefName='UseasCrossDimension' or PrefName='CrossDimField'
	or PrefName='PostEachLineSeperate' or PrefName='batchpaymentDoc' or PrefName='SameserialNo' or PrefName='DonotupdateAccounts' or PrefName='DiscDoc' or PrefName='Lock Data Between'	or PrefName='OverrideLock' or PrefName='CrossDimDocument'
	or PrefName='PostRevisOnSysDate' or PrefName='RevisPrefix' or PrefName='PrepaymentDoc' or PrefName='AutoCode' or PrefName='Postonmaturity' or PrefName='PostBRS' or PrefName='UseasBrsBankStmt' or PrefName='PostBounce' or PrefName='UseAsLC' or PrefName='UseAsTR' or PrefName='LockCostCenterNodes' or PrefName='LockCostCenters' or PrefName='AllowDuplicateChequeNumber' 
	or PrefName='AutoChequeNo' or PrefName='AutoChequeonPost' or PrefName='DocDateasPostedDate' or PrefName='AuditTrial' or PrefName='EnableRevision' or PrefName='DoNotEmailOrSMSUn-ApprovedDocuments'
	or PrefName='ReversalBasedOn' or PrefName='ReversalDate')
	
	set @DocCC=''
	select @DocCC =@DocCC +','+a.name from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData' and a.name like 'dcCCNID%'

	set @CCreplCols=''
	select @CCreplCols =@CCreplCols +','+a.name from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData' and a.name like 'dcCCNID%' and convert(int,replace(a.name,'dcCCNID',''))<51

	set @CC='update Com_Billwise set '
	select @CC =@CC +a.name+'=a.'+a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData' and a.name like 'dcCCNID%'
	set @CC=substring(@CC,0,len(@CC))+' from [COM_DocCCData] a with(nolock) '
	
	set @PrefValue=''
	set @DontChangeBillwise=0
	select @PrefValue=Value from @TblPref where Name='NoFuturetransaction'    
	if(@PrefValue='true')
	BEGIN
		set @ind=0
		select @ind=isnull(Value,0) from @TblPref where Name='DoNotAllowFutureDateDays'
		and  isnumeric(Value)=1

		if(CONVERT(float,@DocDate)>FLOOR(CONVERT(float,GETDATE()))+@ind)
			RAISERROR('-530',16,1)  
	END
	
	set @PrefValue=''
	 select @PrefValue=Value from @TblPref where Name='NoPasttransaction'    
	 if(@PrefValue='true')
	 BEGIN
		set @ind=0
		select @ind=isnull(Value,0) from @TblPref where Name='DoNotAllowPastDateDays'
		and  isnumeric(Value)=1
		
		if(CONVERT(float,@DocDate)<FLOOR(CONVERT(float,GETDATE()))-@ind)
			RAISERROR('-531',16,1) 
	 END
	 
	 set @PrefValue=''
	 select @PrefValue=Value from @TblPref where Name='Nobackdatedtransaction'    
	 if(@PrefValue='true' and @DocID=0)
	 BEGIN
		if exists(select CostCenterID from ACC_DocDetails WITH(NOLOCK) where CostCenterID=@CostCenterID and DocDate>CONVERT(float,@DocDate))
			RAISERROR('-531',16,1)  
	 END

	 SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,673)
	 if(@HasAccess=1)
	 BEGIN
		SELECT @ChWID=FeatureActionID FROM ADM_FeatureAction WITH(nolock)
		WHERE  FeatureID=@CostCenterID AND FeatureActionTypeID=673
		
		set @ind=0
		SELECT @ind=CONVERT(int,Description) FROM ADM_FeatureActionRoleMap WITH(nolock)
		WHERE RoleID=@RoleID AND FeatureActionID=@ChWID and ISNUMERIC(Description)=1

		if(CONVERT(float,@DocDate)>FLOOR(CONVERT(float,GETDATE()))+@ind)
			RAISERROR('-530',16,1)  
	 END

	 SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,672)
	 if(@HasAccess=1)
	 BEGIN
		SELECT @ChWID=FeatureActionID FROM ADM_FeatureAction WITH(nolock)
		WHERE  FeatureID=@CostCenterID AND FeatureActionTypeID=672
		
		set @ind=0
		SELECT @ind=CONVERT(int,Description) FROM ADM_FeatureActionRoleMap WITH(nolock)
		WHERE RoleID=@RoleID AND FeatureActionID=@ChWID and ISNUMERIC(Description)=1
		
		if(CONVERT(float,@DocDate)<FLOOR(CONVERT(float,GETDATE()))-@ind)
			RAISERROR('-531',16,1) 
	 END
	 

	SELECT @AccType=Value FROM @TblPref WHERE Name='LockTransactionAccountType'
	if(	@AccType is not null)
	begin
		insert into @table
		exec SPSplitString @AccType,','
	end
    declare @AcctypesTable table (ID INT identity(1,1),AccountTypeID INT,AccountDate datetime)
	
	if(@IsImport=0 and dbo.fnCOM_HasAccess(@RoleID,43,193)=0)
	BEGIN	
		insert into @AcctypesTable 
		select reverse(parsename(replace(reverse(TypeID),'~','.'),1)) as [AccountTypeID],
		convert(datetime,reverse(parsename(replace(reverse(TypeID),'~','.'),2))) as [Date] from @table
	END
	
	set @IsLockedPosting=0	
	set @IsLineWisePDC=0
	set @isCrossDim=0
	select @IsLineWisePDC=isnull(PrefValue,0) from @TblDocPref where PrefName='LineWisePDC'   	
	select @isCrossDim=isnull(PrefValue,0) from @TblDocPref where PrefName='UseasCrossDimension'   	
	select @PDCDocument=isnull(PrefValue,0) from @TblDocPref where PrefName='PDCDocument'   
	select @PrefValue=PrefValue from @TblDocPref where PrefName='DocumentLinkDimension'   

	if(@isCrossDim=1)
	BEGIN
		set @PDCDocument=0
		select @PDCDocument=isnull(PrefValue,0) from @TblDocPref where PrefName='CrossDimDocument' and isnumeric(PrefValue)=1
		select @CrossDimFld=syscolumnName from @TblDocPref a
		join adm_costcenterdef d WITH(NOLOCK) on a.PrefValue=d.CostcenterColID
		where PrefName='CrossDimField' and isnumeric(PrefValue)=1
		select @CrossDimension=isnull(Value,0) from @TblPref where Name='CrossDimension' and isnumeric(Value)=1		
	END
	

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
	
	set @ManaProp=0
	if exists(select value from com_costcenterpreferences WITH(NOLOCK)
	WHere costcenterid=92 and name ='EnableManagProp' and value='true')
		set @ManaProp=1
	
			
  if(@DocNumber is null or @DocNumber='')
   set @DocNumber='1'
   
	SELECT @DocumentTypeID=DocumentTypeID,@DocumentType=DocumentType,@DocAbbr=DocumentAbbr,@DocOrder=DocOrder   
	,@Series=Series,@ConCCID=ConvertAs,@PrefValue=guid FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID  
	  
	SET @XML=@ActivityXML
	set @ActXML=@ActivityXML
	set @WorkFlow=''
	set @ChWID=0
	--PosSessionID
	declare @PosSessionID INT,@IsSessionCls bit
	SELECT @PosSessionID=X.value('@PosSessionID','INT'),@IsSessionCls=ISNULL(X.value('@IsSessionCls','INT'),0) ,@DontChangeBillwise=ISNULL(X.value('@DontChangeBillwise','bit'),0)  
	from @ActXML.nodes('/XML') as Data(X)
	
	if(@IsSessionCls=0 and @PosSessionID is not null and not exists(select POSLoginHistoryID from POS_loginHistory with(nolock) where POSLoginHistoryID=@PosSessionID and IsUserClose=0))
		RAISERROR('-152',16,1)	
			 
	SELECT @LCStatus=X.value('@LCStatus','Nvarchar(500)'),@WorkFlow=X.value('@WorkFlow','nvarchar(100)')
			,@AppRejDate=X.value('@AppRejDate','Datetime'),@Guid=X.value('@Guid','nvarchar(100)'),@IsNewReference=isnull(X.value('@GenratePrefix','bit'),0),
			@EndNo=X.value('@SaveUnapproved','int'),@sysinfo=X.value('@SysInfo','nvarchar(max)'), @CCGuid=X.value('@CCGuid','nvarchar(100)'),@ChWID=isnull(X.value('@ChildWorkFlowID','INT'),0)
			,@AP=X.value('@AP','varchar(10)')
	from @XML.nodes('/XML') as Data(X) 
	if(@AP is null)
		set @AP=''
    if(@PrefValue!=@CCGuid)
    BEGIN
		RAISERROR('-513',16,1)  
    END
    
    
    
    if(@DocID=0)
	BEGIN
		set @HistoryStatus='Add'
		if(@IsNewReference is not null and @IsNewReference=1)
			EXEC [sp_GetDocPrefix] @InvDocXML,@DocDate,@CostCenterID,@DocPrefix output,0,0,0
	END
	else
	BEGIN
		set @HistoryStatus='Update'
		set @oldVoucherNo=''
		set @VersionNo=0
		set @TEmpWid=0
		
		select @oldStatus=StatusID,@TEmpWid=WorkflowID,@tempLevel=WorkFlowLevel,@oldVoucherNo=VoucherNo
		,@VersionNo=VersionNo,@DocPrefix=case when @RefCCID=95 and @DocPrefix is not null and @DocPrefix<>'' and @DocPrefix<>DocPrefix  then @DocPrefix else DocPrefix end ,@DocNumber=DocNumber from ACC_DocDetails WITH(NOLOCK) 
		where DocID=@DocID
		
		select @PrefValue=guid from COM_DocID WITH(NOLOCK) WHERE ID=@DocID
		
		if(@PrefValue!=@Guid)
		BEGIN
			RAISERROR('-101',16,1)  
		END
		
		update D
		set D.LockedBY=null
		FROM COM_DocID D WITH(NOLOCK)
		where D.ID=@DocID
		
    END
        	 
    if exists(select Value from @TblPref where Name='UseDimWiseLock' and Value ='true')
	BEGIN
		set @PrefValue=''
		set @ChequeBookNo=''
		select @PrefValue=isnull(X.value('@LockDims','nvarchar(max)'),''),@ChequeBookNo=isnull(X.value('@LockDimsjoin','nvarchar(max)'),'')
		from @XML.nodes('/XML') as Data(X)    		         
		if(@PrefValue<>'')
		BEGIN
			set @DUPLICATECODE=' if exists(select FromDate from ADM_DimensionWiseLockData c WITH(NOLOCK) '+@ChequeBookNo+' 
			where '+convert(nvarchar,CONVERT(float,@DocDate))+' between FromDate and ToDate and c.isEnable=1 '+@PrefValue
			+') RAISERROR(''-125'',16,1) '
			exec(@DUPLICATECODE)
		END
	END
 
     if exists( select X.value('@LockedPosting','BIT') from @XML.nodes('/XML') as Data(X)  
			where X.value('@LockedPosting','BIT')  is not null and X.value('@LockedPosting','BIT')=1)
	BEGIN
				
					EXEC @return_value = spDOC_SuspendAccDocument        
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

	set @StatusID=369
	
	
	if exists(select PrefValue from @TblDocPref where PrefName='DonotupdateAccounts' and PrefValue='true')
		set @StatusID=377
			
	 if(@DocumentType=14 or @DocumentType=19)
	 BEGIN
		if(@isCrossDim=1 and @PDCDocument>1)	
			set @StatusID=448	
	    ELSE  if(@IsLineWisePDC=1 and @PDCDocument>1)	
			set @StatusID=447
		ELSE
			set @StatusID=370
	 END	 
	 else if(@DocumentType in(18,15,22,23))
	 BEGIN
	    if(@isCrossDim=1 and @PDCDocument>1)	
			set @StatusID=448		
		else if exists(select PrefValue from @TblDocPref where PrefName='PostBRS' and PrefValue='true')
			set @StatusID=449
		else if exists(select PrefValue from @TblDocPref where PrefName='PostBounce' and PrefValue='true')
			set @StatusID=453
	 END
	 else if(@DocumentType in(17))
	 BEGIN
	   if exists(select PrefValue from @TblDocPref where PrefName='UseasBrsBankStmt' and PrefValue='true')
			set @StatusID=500	
	 END
	 
	if(@WID is not null and @WID>0)
	begin
		if(@DocID>0 and @tempLevel is not null and @oldStatus not in (369,370,372))
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
		ELSE
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
	end
	
		
	IF( @RefCCID = 95 )
	BEGIN
		SET @DUPLICATECODE='IF EXISTS (SELECT STATUS FROM [adm_featureactionrolemap] WITH(NOLOCK)  WHERE ROLEID = '+CONVERT(NVARCHAR,@RoleID)+' AND FEATUREACTIONID = 3764)
		BEGIN 
			set @StatusID=371 
		END
		ELSE if('+CONVERT(NVARCHAR,@DocumentType)+'=19 and exists(select a.ContractID  from REN_Contract a WITH(NOLOCK) 
		join REN_ContractDocMapping b WITH(NOLOCK) on a.ContractID=b.ContractID
		where a.ContractID='+CONVERT(NVARCHAR,@RefNodeid)+' and StatusID=428 and b.DocID='+CONVERT(NVARCHAR,@DocID)+' and b.Type<>-4 and b.IsAccDoc=1))
			set @StatusID=452'
		EXEC sp_executesql @DUPLICATECODE,N'@StatusID INT OUTPUT',@StatusID OUTPUT 
	END
	
	if(@LCStatus is not null)
	BEGIN  
		if(@LCStatus='open') 
			set @StatusID=443
		if(@LCStatus='approved') 
			set @StatusID=369	
	END		
 	
 	if(@EndNo=1)--budget crossed save as unapproved
		set @StatusID=371 

	SET @Dt=convert(float,getdate())--Setting Current Date    
 
  IF(@InvDocXML IS NOT NULL AND @InvDocXML<>'')    
  BEGIN    
    
  SET @XML=@InvDocXML  
  
	if exists(select AccountTypeID from @AcctypesTable where AccountDate>=@DocDate)  
	begin    
		if exists(select  a.AccountTypeID from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)  
		join Acc_Accounts a with(nolock) on a.AccountID=X.value('@DebitAccount','INT')
		join @AcctypesTable b on a.AccountTypeID=b.AccountTypeID
		where X.value('@DebitAccount','INT')>0 and AccountDate>=@DocDate)
		begin  
			RAISERROR('-369',16,1)  
		end 
		
		if exists(select  a.AccountTypeID from @XML.nodes('/DocumentXML/Row/AccountsXML/Accounts') as Data(X)  
		join Acc_Accounts a with(nolock) on a.AccountID=X.value('@DebitAccount','INT')
		join @AcctypesTable b on a.AccountTypeID=b.AccountTypeID
		where X.value('@DebitAccount','INT')>0 and AccountDate>=@DocDate)
		begin  
			RAISERROR('-369',16,1)  
		end 

		if exists(select  a.AccountTypeID from @XML.nodes('/DocumentXML/Row/AccountsXML/Accounts') as Data(X)  
		join Acc_Accounts a with(nolock) on a.AccountID=X.value('@CreditAccount','INT')
		join @AcctypesTable b on a.AccountTypeID=b.AccountTypeID
		where X.value('@CreditAccount','INT')>0 and AccountDate>=@DocDate)
		begin  
			RAISERROR('-369',16,1)  
		end 

		if exists(select  a.AccountTypeID from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)  
		join Acc_Accounts a with(nolock) on a.AccountID=X.value('@CreditAccount','INT')
		join @AcctypesTable b on a.AccountTypeID=b.AccountTypeID
		where X.value('@CreditAccount','INT')>0 and AccountDate>=@DocDate)
		begin  
			RAISERROR('-369',16,1)  
		end 
		
	END	
	
	--if(@DocumentType=14 or @DocumentType=15 or @DocumentType= 20 or @DocumentType= 23)
	--BEGIN
	--	if exists(select  a.IsBillwise from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)  
	--	join Acc_Accounts a with(nolock) on a.AccountID=X.value('@DebitAccount','INT')		
	--	where X.value('@DebitAccount','INT')>0 and X.value('@IsNegative','BIT') is not null
	--	and X.value('@IsNegative','BIT')=1 and a.IsBillwise=1)
	--	begin  
	--		RAISERROR('-369',16,1)  
	--	end 
		
	--	if exists(select  a.IsBillwise from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)  
	--	join Acc_Accounts a with(nolock) on a.AccountID=X.value('@CreditAccount','INT')		
	--	where X.value('@CreditAccount','INT')>0 and X.value('@IsNegative','BIT') is null
	--	and a.IsBillwise=1)
	--	begin  
	--		RAISERROR('-369',16,1)  
	--	end 
	--END	
	--ELSE if(@DocumentType=18 or @DocumentType=19 or @DocumentType= 21 or @DocumentType= 22)
	--BEGIN
	--	if exists(select  a.IsBillwise from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)  
	--	join Acc_Accounts a with(nolock) on a.AccountID=X.value('@CreditAccount','INT')		
	--	where X.value('@CreditAccount','INT')>0 and X.value('@IsNegative','BIT') is not null
	--	and X.value('@IsNegative','BIT')=1 and a.IsBillwise=1)
	--	begin  
	--		RAISERROR('-369',16,1)  
	--	end 
		
	--	if exists(select  a.IsBillwise from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)  
	--	join Acc_Accounts a with(nolock) on a.AccountID=X.value('@DebitAccount','INT')		
	--	where X.value('@DebitAccount','INT')>0 and a.IsBillwise=1)
	--	begin  
	--		RAISERROR('-369',16,1)  
	--	end 
	--END
	
	DECLARE @DAllowLockData BIT,@AllowLockData BIT,@IsLock bit    
	
	SELECT @DAllowLockData=CONVERT(BIT,PrefValue) FROM @TblDocPref WHERE   PrefName='Lock Data Between'    	
	SELECT @AllowLockData=CONVERT(BIT,Value) FROM @TblPref where  Name='Lock Data Between'
	
	set @IsLock=0
	
	if((@AllowLockData=1 or @DAllowLockData=1) and dbo.fnCOM_HasAccess(@RoleID,43,193)=0 )
	BEGIN
		IF exists(select LockID from ADM_LockedDates WITH(NOLOCK) where isEnable=1 
		and ((@AllowLockData=1 and CONVERT(float,@DocDate) between FromDate and ToDate and CostCenterID=0)
		or (@DAllowLockData=1 and CONVERT(float,@DocDate) between FromDate and ToDate and CostCenterID=@CostCenterID)))
			set @IsLock=1
			
		IF (@DAllowLockData=1 and @IsLock=1)
		BEGIN	
			SELECT @DLockCC=CONVERT(INT,PrefValue) FROM @TblDocPref WHERE  PrefName='LockCostCenters' and isnumeric(PrefValue)=1

			if(@DLockCC is null or @DLockCC=0)
				RAISERROR('-125',16,1)      			
		END
		
		IF (@AllowLockData=1 and @IsLock=1 and (SELECT PrefValue FROM @TblDocPref where PrefName='OverrideLock')<>'true')
		BEGIN
			SELECT @LockCC=CONVERT(INT,Value) FROM @TblPref where  Name='LockCostCenters' and isnumeric(Value)=1
		
			if(@LockCC is null or @LockCC=0)
				RAISERROR('-125',16,1)      			
		END
	END
	
	
  set @IsRevision=0      
  SELECT @IsRevision=X.value('@IsRevision','BIT'), @ReviseReason=X.value('@ReviseReason','NVARCHAR(MAX)')
  from @XML.nodes('/DocumentXML') as Data(X)  	

	if(@IsRevision=1 and @DocID>0 and exists(select prefValue from @TblDocPref where prefName='PostRevisOnSysDate' and prefValue='true'))
		set @DocDate=CONVERT(datetime,floor(convert(float,getdate())))	
	
	
	if exists(SELECT X.value('@IgnoreConvertedPDC','BIT')  from @XML.nodes('/DocumentXML') as Data(X)
	where isnull(X.value('@IgnoreConvertedPDC','BIT'),0) =1)
		set @IgnoreConvertedPDC=1
	
  IF(@DocID=0)    
  BEGIN    
	SET @VersionNo=0
		
		if((@DocumentType=14 or @DocumentType=19) and @Series=1 and @ConCCID is not null and  @ConCCID>0)--alternate series   
			set @prefixccid=@ConCCID    
		else if(@Series is not null and  @DocumentType<>14 and @DocumentType<>19 and @Series>40000)
			set @prefixccid=@Series   
		else	 
			set @prefixccid=@CostCenterID
		
		IF(@DocNumber is not null AND @DocNumber!='' AND CONVERT(BIGINT,@DocNumber)>2147483647)
		BEGIN
			raiserror('DocNumber Cannot be more than 2147483647',16,1)
		END

		if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef  WITH(NOLOCK) WHERE CostCenterID=@prefixccid AND CodePrefix=@DocPrefix)    
		begin    
			INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
			VALUES(@prefixccid,@prefixccid,@DocPrefix,CONVERT(INT,@DocNumber),1,CONVERT(INT,@DocNumber),len(@DocNumber),Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    
			SET @tempDOc=CONVERT(INT,@DocNumber)+1    
		end    
		ELSE
		BEGIN
		   SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK) --AS CurrentCodeNumber    
		   WHERE CostCenterID=@prefixccid AND CodePrefix=@DocPrefix    
	       
			   if(@DocNumber='1' and @RefCCID>0)
					set  @DocNumber=@tempDOc
				
				IF(@DocNumber is not null AND @DocNumber!='' AND CONVERT(BIGINT,@DocNumber)>2147483647)
				BEGIN
					raiserror('DocNumber Cannot be more than 2147483647',16,1)
				END
		
			   IF(CONVERT(INT,@DocNumber)>= @tempDOc)    
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
							UPDATE COM_CostCenterCodeDef     
							SET CurrentCodeNumber=@DocNumber    
							WHERE CostCenterID=@prefixccid AND CodePrefix=@DocPrefix 
					END
					ELSE
					BEGIN
						UPDATE COM_CostCenterCodeDef     
						SET CurrentCodeNumber=@DocNumber    
						WHERE CostCenterID=@prefixccid AND CodePrefix=@DocPrefix    
					END	
				END  
		END 
		
		 IF(@DocNumber is not null AND @DocNumber!='' AND CONVERT(BIGINT,@DocNumber)>2147483647)
		BEGIN
			raiserror('DocNumber Cannot be more than 2147483647',16,1)
		END
	   
		IF ((EXISTS(SELECT DocID FROM ACC_DocDetails WITH(NOLOCK)  WHERE CostCenterID in (
			SELECT CostCenterID FROM  ADM_DocumentTypes WITH(NOLOCK)   WHERE Series=@prefixCCID or CostCenterID=@prefixCCID) AND DocPrefix=@DocPrefix AND CONVERT(BIGINT,DocNumber)=CONVERT(INT,@DocNumber))    )
			or ((@DocumentType=14 or @DocumentType=19) and @Series=1 and EXISTS(SELECT DocID FROM ACC_DocDetails WITH(NOLOCK)  WHERE (CostCenterID=@prefixCCID or CostCenterID=@CostCenterID) AND DocPrefix=@DocPrefix AND CONVERT(BIGINT,DocNumber)=CONVERT(INT,@DocNumber)) ))
		BEGIN      
			set @PrefValue=''  
			select @PrefValue=PrefValue from @TblDocPref where PrefName='SameserialNo'
		     
			if (@IsImport=1 or @PrefValue='true')
				RAISERROR('-122',16,1)  
				
			while ((EXISTS(SELECT DocID FROM ACC_DocDetails WITH(NOLOCK)  WHERE CostCenterID in (
			SELECT CostCenterID FROM  ADM_DocumentTypes WITH(NOLOCK)   WHERE Series=@prefixCCID or CostCenterID=@prefixCCID) AND DocPrefix=@DocPrefix AND CONVERT(BIGINT,DocNumber)=CONVERT(INT,@DocNumber))    )
			or ((@DocumentType=14 or @DocumentType=19) and @Series=1 and EXISTS(SELECT DocID FROM ACC_DocDetails WITH(NOLOCK)  WHERE (CostCenterID=@prefixCCID or CostCenterID=@CostCenterID) AND DocPrefix=@DocPrefix AND CONVERT(BIGINT,DocNumber)=CONVERT(INT,@DocNumber)) ))
			BEGIN

				SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK) --AS CurrentCodeNumber    
				WHERE CostCenterID=@prefixccid AND CodePrefix=@DocPrefix  

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
				UPDATE COM_CostCenterCodeDef     
				SET CurrentCodeNumber=@DocNumber    
				WHERE CostCenterID=@prefixccid AND CodePrefix=@DocPrefix  
			END  
		END    
       
       
   SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')    
    if(@IsRevision=1)
	begin		
		set @VoucherNo=@VoucherNo+'/'+convert(nvarchar,@VersionNo)
	end	
	
   	 --To Get Auto generate DocID
   	while exists (select DocNo from COM_DocID with(nolock) where DocNo=@VoucherNo)
	begin			
		SET @DocNumber=@DocNumber+1
		SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
	end
	
	if exists(select name from sys.columns where name='FromDocNo' and object_id=object_id('COM_Billwise'))
	BEGIN
		set @DUPLICATECODE= 'update B
		set FromDocNo='''+@VoucherNo+'''
		FROM COM_Billwise B WITH(NOLOCK)
		where FromDocNo='''+@guid+''''
		exec(@DUPLICATECODE)
	END
	
	set @guid=newid()
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
    
    set @PrefValue=''
    SELECT @ScheduleID=isnull(X.value('@ScheduleID','INT'),0),@PrefValue=X.value('@SchGUID','nvarchar(max)')
    from @ActXML.nodes('/XML') as Data(X)
    if(@ScheduleID>0)
    BEGIN
		if(@PrefValue <>'')
		BEGIN
			select @CCGuid=GUID from COM_SchEvents WITH(NOLOCK) where SCHEVENTID=@ScheduleID	
			
			 if(@CCGuid!=@PrefValue)
				RAISERROR('-101',16,1)  
		END
		
		UPDATE COM_SchEvents 
		SET STATUSID=2,PostedVoucherNo=@VoucherNo,GUID=newid()
		WHERE SCHEVENTID=@ScheduleID
    END
    
  END    
  ELSE    
  BEGIN   
	
	
	 if(@WID=0 and @TEmpWid>0)
     begin
		 set @WID=@TEmpWid
		
		    if(@WorkFlow is not null and @WorkFlow='NO')  
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
        
	declare @lcPrefValue nvarchar(50),@trPrefValue nvarchar(50),@LCAmount float,@LCCloseAmount float	   
	
	SELECT @lcPrefValue=PrefValue FROM @TblDocPref WHERE PrefName='UseAsLC' 	
	SELECT @trPrefValue=PrefValue FROM @TblDocPref WHERE PrefName='UseAsTR' 
			
	IF(@IgnoreConvertedPDC=0 and (@lcPrefValue='true' or @trPrefValue='true' or @DocumentType=14 or @DocumentType=19))
	BEGIN
		if exists (SELECT a.ACCDocDetailsID from ACC_DocDetails a WITH(NOLOCK)  	 
		join ACC_DocDetails B WITH(NOLOCK)  on a.ACCDocDetailsID =b.RefNodeid and b.RefCCID=400  
		where a.CostCenterid=@CostCenterID and a.DocID =@DocID )
		begin
    			  
			IF (@lcPrefValue='true' or @trPrefValue='true') 
			BEGIN
				select @LCAmount=isnull(sum(amount),0) from ACC_DocDetails  WITH(NOLOCK) 
				where DocID =@DocID and (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0) and  StatusID=369 
			
				select @LCCloseAmount=isnull(sum(amount),0) from ACC_DocDetails  WITH(NOLOCK) 
				where RefCCID=400 and  RefNodeid =(SELECT AccDocDetailsID from ACC_DocDetails  WITH(NOLOCK) 
				where DocID =@DocID and (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0) and  StatusID=369 )
				
				if(@LCCloseAmount>=@LCAmount)
				BEGIN
					IF (@lcPrefValue='true')
						RAISERROR('-390',16,1)  
					else
						RAISERROR('-391',16,1)
				END		
			END
			ELSE if exists(select ACCDocDetailsID from ACC_DocDetails WITH(NOLOCK)  where DocID =@DocID and StatusID=369)
				RAISERROR('-370',16,1)  
		--else if exists(select ACCDocDetailsID from ACC_DocDetails where DocID =@DocID and StatusID=369) -- for discount
		--	RAISERROR('-376',16,1) 
			else if exists(select ACCDocDetailsID from ACC_DocDetails WITH(NOLOCK)  where DocID =@DocID and StatusID=429)
				RAISERROR('-371',16,1)  
		end
	 END
	 	
	if(@oldVoucherNo<>'')
	begin
		set @VoucherNo=@oldVoucherNo
	
		set @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')			
		if(@RefCCID=95 and @VoucherNo<>@vno)
		BEGIN
			
				if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef  WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix)    
				begin  
					set  @DocNumber=1
					INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
					VALUES(@CostCenterID,@CostCenterID,@DocPrefix,CONVERT(INT,@DocNumber),1,CONVERT(INT,@DocNumber),len(@DocNumber),Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    					  
				end    
				ELSE
				BEGIN
				   SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK) --AS CurrentCodeNumber    
				   WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix    
			       
					  set  @DocNumber=@tempDOc
						
						IF(@DocNumber is not null AND @DocNumber!='' AND CONVERT(BIGINT,@DocNumber)>2147483647)
						BEGIN
							raiserror('DocNumber Cannot be more than 2147483647',16,1)
						END	
					   IF(CONVERT(INT,@DocNumber)>= @tempDOc)    
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
								UPDATE COM_CostCenterCodeDef     
								SET CurrentCodeNumber=@DocNumber    
								WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix 
							 	
						END  
				END 
			
			set @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
				 --To Get Auto generate DocID
   			while exists (select DocNo from COM_DocID with(nolock) where DocNo=@VoucherNo)
			begin			
				SET @DocNumber=@DocNumber+1
				SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
			end
			
			update D
			set D.DocNo=@VoucherNo
			FROM COM_DocID D WITH(NOLOCK)
			where D.id=@DocID
		END
		if(@Dimesion>0)    
		begin
			set @DimesionNodeID=0						
			select @cctablename=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@Dimesion
			set @DUPLICATECODE='select @NodeID=NodeID from '+@cctablename+' WITH(NOLOCK) where Name='''+@vno+''''				
			EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@DimesionNodeID output
		end  			
	end
	else
	begin
		if((@DocumentType=14 or @DocumentType=19) and @Series=1 and @ConCCID is not null and  @ConCCID>0)--alternate series   
			set @prefixccid=@ConCCID    
		else if(@Series is not null and  @DocumentType<>14 and @DocumentType<>19 and @Series>40000)
			set @prefixccid=@Series   
		else	 
			set @prefixccid=@CostCenterID
	
		if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef  WITH(NOLOCK) WHERE CostCenterID=@prefixccid AND CodePrefix=@DocPrefix)    
		begin    
			set @DocNumber='1'
			INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
			VALUES(@prefixccid,@prefixccid,@DocPrefix,CONVERT(INT,@DocNumber),1,CONVERT(INT,@DocNumber),len(@DocNumber),Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    
			SET @tempDOc=CONVERT(INT,@DocNumber)+1    
		end    
		ELSE
		BEGIN
		   SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK) --AS CurrentCodeNumber    
		   WHERE CostCenterID=@prefixccid AND CodePrefix=@DocPrefix    
	    END
	    
	    set @DimesionNodeID=0
		SET @DocNumber=@tempDOc    
		
		set @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
		
		while exists (select DocNo from COM_DocID with(nolock) where DocNo=@VoucherNo)
		begin			
			SET @DocNumber=@DocNumber+1
			SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
		end	
		
		update D
		set D.DocNo=@VoucherNo 
		FROM COM_DocID D WITH(NOLOCK)
		where D.ID=@DocID
		 
		UPDATE COM_CostCenterCodeDef     
		SET CurrentCodeNumber=@DocNumber    
		WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix
	end	
	if(@IsRevision=1)
	begin
		set @VersionNo=@VersionNo+1
		
		if exists(select prefValue from @TblDocPref where prefName='RevisPrefix' and prefValue is not null and prefValue<>'')
			select @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+prefValue+convert(nvarchar, @VersionNo  ) from @TblDocPref where prefName='RevisPrefix' 					
		ELSE
			set @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')+'/'+convert(nvarchar,@VersionNo)
		--Update Voucher No While Revision
		--update COM_DocID set DocNo=@VoucherNo where ID=@DocID
	end		
	
	if exists(select name from sys.columns where name='FromDocNo' and object_id=object_id('COM_Billwise'))
	BEGIN
		set @DUPLICATECODE= 'update B
		set FromDocNo='''+@VoucherNo+'''
		FROM COM_Billwise B WITH(NOLOCK)
		where FromDocNo='''+@guid+''''
		exec(@DUPLICATECODE)
	END
	
	set @guid=newid()
	
	update D
	set D.GUID= @guid,D.SysInfo =@SysInfo 
	FROM COM_DocID D WITH(NOLOCK)
	where D.ID=@DocID
	
	delete from COM_DocDenominations
	where docid=@DocID	
	
	delete from COM_ChequeReturn
	where DocNo=@oldVoucherNo
	
	declare @tabdet table(id int identity(1,1),detid INT,SeqNo int,linkacc int)
	INSERT INTO @tabdet
	SELECT AccDocDetailsID,DocSeqNo,LinkedAccDocDetailsID FROM  [ACC_DocDetails]  WITH(NOLOCK)    
	WHERE DocID =@DocID AND AccDocDetailsID NOT IN    
	(SELECT X.value('@DocDetailsID','INT')    
	from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X))
	
	 
	if(@RefCCID=95 and @IgnoreConvertedPDC=1)
	BEGIN
			delete a from @tabdet a
			join [ACC_DocDetails] b  WITH(NOLOCK) on b.AccDocDetailsID=a.detid
			WHERE b.DocID =@DocID AND statusid in(369,429)
	END
	
	if exists(select ID from @tabdet)
	BEGIN	
		 --if exists (SELECT a.ACCDocDetailsID from ACC_DocDetails a with(nolock)	 
		 --join REN_ContractDocMapping B with(nolock) on a.DocID =b.DocID
		 --join @tabdet d on a.AccDocDetailsID=d.detid	
		 --where B.JVVoucherNo is not null and B.JVVoucherNo<>'')
		 --begin		
			--	RAISERROR('-538',16,1)  
		 --end
		 
		 
		--ondelete External function
		set @cctablename=''
		select @cctablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=8
		if(@cctablename<>'')
		BEGIN
			set @ChequeBookNo=''
			select @ChequeBookNo=@ChequeBookNo+CONVERT(nvarchar,detid)+',' from @tabdet
			set @ChequeBookNo=@ChequeBookNo+'-1'
			exec @cctablename @CostCenterID,@DocID,@ChequeBookNo,@UserID,@LangID
		END
			 
		--DELETE DOCUMENT EXTRA COSTCENTER FEILD DETAILS
		DELETE T FROM COM_DocCCData t WITH(NOLOCK)
		join @tabdet a on t.AccDocDetailsID=a.detid		

		--DELETE DOCUMENT EXTRA NUMERIC FEILD DETAILS    
		DELETE T FROM [COM_DocNumData] t WITH(NOLOCK)
		join @tabdet a on t.AccDocDetailsID=a.detid		
		
		--DELETE DOCUMENT EXTRA TEXT FEILD DETAILS    
		DELETE T FROM [COM_DocTextData] t WITH(NOLOCK)
		join @tabdet a on t.AccDocDetailsID=a.detid	
   
		declare @di int,@dc int,@detid INT,@linnkacc int

		select @di=0,@dc=count(id) from @tabdet
		while(@di<@dc)
		begin
			set @di=@di+1
			set @linnkacc=0
			select @detid=detid,@oldseqno=SeqNo,@linnkacc=linkacc from @tabdet where id=@di
			
			
			if(@linnkacc=0)
			BEGIN
				if(@DontChangeBillwise=0)	
					DELETE B FROM [COM_Billwise] B WITH(NOLOCK)    
					WHERE [DocNo]=@oldVoucherNo AND DocSeqNo=@oldseqno    
	    		
    			DELETE B FROM COM_BillWiseNonAcc  B WITH(NOLOCK)      
				WHERE [DocNo]=@oldVoucherNo AND DocSeqNo=@oldseqno    
			   	
		   		if(@DontChangeBillwise=0)	
				   update B
				   set RefDocNo=NULL,RefDocSeqNo=NULL,[IsNewReference]=1,[RefDocDueDate]=NULL
				   FROM COM_Billwise B WITH(NOLOCK)
				   where RefDocNo=@oldVoucherNo and RefDocSeqNo=@oldseqno
		   END
		   
			if(@IsLineWisePDC=1)
			BEGIN
				Select @Refstatus=StatusID from ACC_DocDetails  WITH(NOLOCK) where RefCCID = 400 and RefNodeid=@detid
				if(@Refstatus is not null and @Refstatus in(370,371,372,441))
				BEGIN
						SELECT @DELETEDOCID=DocID , @DELETECCID = COSTCENTERID FROM ACC_DocDetails with(nolock)   
						where refccid=400 and refnodeid=@detid
							
						if(@DELETEDOCID is not null and @DELETEDOCID>0)
						BEGIN	    
							 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
								 @CostCenterID = @DELETECCID,  
								 @DocPrefix = '',  
								 @DocNumber = '',  
								 @DocID=@DELETEDOCID ,
								 @UserID = 1,  
								 @UserName = @UserName,  
								 @LangID = @LangID,
								 @RoleID=1
						END  
				END
			END
	  		ELSE if(@isCrossDim=1)
			BEGIN 
					insert into @ttdel
					SELECT AccDocDetailsID FROM  [ACC_DocDetails]  WITH(NOLOCK)    
					WHERE refccid=400 and refnodeid=@detid
					 
					select @ii=0,@ccnt=COUNT(accid) from @ttdel
					while(@ii<@ccnt)
					BEGIN
						set @ii=@ii+1
						set @DELETEDOCID=0						
						SELECT @DELDocPrefix = DocPrefix, @DELDocNumber=  DocNumber , @DELETECCID = COSTCENTERID FROM ACC_DocDetails with(nolock)   
						where refccid=400 and refnodeid=(select accid from @ttdel where id=@ii)
						if(@DELETEDOCID is not null and @DELETEDOCID>0)
						BEGIN	
							 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
									 @CostCenterID = @DELETECCID,  
									 @DocPrefix = '',  
									 @DocNumber = '',  
									 @DocID=@DELETEDOCID ,
									 @UserID = 1,  
									 @UserName = @UserName,  
									 @LangID = @LangID,
									 @RoleID=1
						END			 
					END
			END
		end
   
   
		--DELETE DOCUMENT     
		DELETE  T FROM  ACC_DocDetails t WITH(NOLOCK)
		join @tabdet a on t.AccDocDetailsID=a.detid		    
	END    
  END
	
	
	Declare @TEMPUNIQUE  TABLE (ID INT identity(1,1) , SYSCOLUMNNAME NVARCHAR(50),USERCOLUMNNAME NVARCHAR(50) , SECTIONID INT,CCID INT)
	declare @UNIQUECNT int

	INSERT INTO @TEMPUNIQUE 
	SELECT CC.SYSCOLUMNNAME,R.RESOURCEDATA , CC.SECTIONID,0 FROM ADM_COSTCENTERDEF CC WITH(NOLOCK) 
	JOIN COM_LANGUAGERESOURCES  R WITH(NOLOCK)  ON CC.RESOURCEID = R.RESOURCEID and R.LanguageID=@LangID
	WHERE CC.COSTCENTERID = @CostCenterID  AND CC.ISUNIQUE = 1

	SELECT @UNIQUECNT = COUNT(*) FROM @TEMPUNIQUE
	
	IF (@IsRevision=1 and @DocID>0 and not exists(select DocID from [ACC_DocDetails_History] with(nolock) where DocID=@DocID))  
	BEGIN    
		EXEC @return_value = [spDOC_SaveHistory]      
				@DocID =@DocID ,
				@HistoryStatus='ADD',
				@Ininv =0,
				@ReviseReason ='',
				@LangID =@LangID
	END 

	--Create temporary table to read xml data into table    
	declare @tblList TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX),NUMXML NVARCHAR(MAX),CCXML NVARCHAR(MAX),TEXTXML NVARCHAR(MAX),EXTRAXML NVARCHAR(MAX),AccountsXML NVARCHAR(MAX),ReturnXML NVARCHAR(MAX),Denominationxml NVARCHAR(MAX),PrePaymentXML NVARCHAR(MAX),DiscXML NVARCHAR(MAX))
	Declare @Create bit
	--Read XML data into temporary table only to delete records    
	INSERT INTO @tblList    
	SELECT CONVERT(NVARCHAR(MAX), X.query('Transactions')),CONVERT(NVARCHAR(MAX),X.query('Numeric')),CONVERT(NVARCHAR(MAX),X.query('CostCenters')),CONVERT(NVARCHAR(MAX),X.query('Alpha')),CONVERT(NVARCHAR(MAX),X.query('EXTRAXML')),CONVERT(NVARCHAR(MAX), X.query('AccountsXML'))
	,CONVERT(NVARCHAR(MAX), X.query('ReturnXML')) ,CONVERT(NVARCHAR(MAX), X.query('PosPayModes'))  ,CONVERT(NVARCHAR(MAX), X.query('PrePaymentXML')) ,CONVERT(NVARCHAR(MAX), X.query('DiscXML'))  
	from @XML.nodes('/DocumentXML/Row') as Data(X)    

	--Set loop initialization varaibles    
	SELECT @I=1, @Cnt=count(*) FROM @tblList 
	 
  WHILE(@I<=@Cnt)      
  BEGIN		
    set @ReturnXML=NULL
    set @Denominationxml=null
    set @DiscXML=''
   SELECT @TRANSXML=TRANSXML ,@NUMXML =NUMXML ,@CCXML=CCXML ,@TEXTXML=TEXTXML,@EXTRAXML=EXTRAXML,@AccountsXML=AccountsXML,@DiscXML=DiscXML
   ,@ReturnXML=ReturnXML,@Denominationxml=Denominationxml FROM @tblList  WHERE ID=@I      
   SET @I=@I+1	
   
   	declare @tble table(NIDs INT)  
	 
    IF (@AllowLockData=1 and @IsLock=1 and @LockCC>50000)
	BEGIN	
				SELECT @LockCCValues=Value FROM @TblPref WHERE Name='LockCostCenterNodes'
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
				 SElECT @DLockCCValues=PrefValue from @TblDocPref where PrefName='LockCostCenterNodes'
				 
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
	
	if exists(select Value from @TblPref where Name='UseDimWiseLock' and Value ='true')
	BEGIN
		set @PrefValue=''
		set @ChequeBookNo=''
		select @PrefValue=isnull(X.value('@LockDims','nvarchar(max)'),''),@ChequeBookNo=isnull(X.value('@LockDimsjoin','nvarchar(max)'),'')
		from @TRANSXML.nodes('/Transactions') as Data(X)    		         
		if(@PrefValue<>'')
		BEGIN
			set @DUPLICATECODE=' if exists(select FromDate from ADM_DimensionWiseLockData c WITH(NOLOCK) '+@ChequeBookNo+'
			where '+convert(nvarchar,CONVERT(float,@DocDate))+' between FromDate and ToDate and c.isEnable=1 '+@PrefValue
			+') RAISERROR(''-571'',16,1) '
			exec(@DUPLICATECODE)
		END
	END
	     
	set @Chequeno='' 
	set @ChequeBookNo=''
	if(@IsImport=1)
	BEGIN

		select @DOCSEQNO=X.value('@DocSeqNo','INT'),@ACCOUNT1Name=X.value('@DebitAccount','nvarchar(500)'),@Iscode=ISNULL(X.value('@DrAccCode','bit') ,0)      
		,@Chequeno=X.value('@ChequeNumber','nvarchar(100)'),@BillDate=CONVERT(FLOAT,X.value('@BillDate','datetime')),@Create=isnull(X.value('@Create','bit'),1) 
		from @TRANSXML.nodes('/Transactions') as Data(X)

		exec [spDOC_GetNode] 2,@ACCOUNT1Name,@Iscode,@DocumentType,@Create,@CompanyGUID,@UserName,@UserID,@LangID,@ACCOUNT1 output

		select @ACCOUNT2Name=X.value('@CreditAccount','nvarchar(500)'),@Iscode=ISNULL(X.value('@CrAccCode','bit') ,0)             
		from @TRANSXML.nodes('/Transactions') as Data(X)

		exec [spDOC_GetNode] 2,@ACCOUNT2Name,@Iscode,@DocumentType,@Create,@CompanyGUID,@UserName,@UserID,@LangID,@ACCOUNT2 output

		set @AccDocDetailsID=0
	END
	ELSE
	BEGIN      
		SELECT @AccDocDetailsID=X.value('@DocDetailsID','INT'),@DOCSEQNO=X.value('@DocSeqNo','INT')
		,@ACCOUNT1=X.value('@DebitAccount','INT'),@ACCOUNT2=X.value('@CreditAccount','INT')
		,@Chequeno=X.value('@ChequeNumber','nvarchar(100)'),@BillDate=CONVERT(FLOAT,X.value('@BillDate','datetime')) 
		,@ChequeBookNo=X.value('@ChequeBookNo','nvarchar(max)')
		from @TRANSXML.nodes('/Transactions') as Data(X)  

		if exists(SELECT X.value('@IgnoreEdit','BIT')  from @TRANSXML.nodes('/Transactions') as Data(X)
		where isnull(X.value('@IgnoreEdit','BIT'),0) =1)
		BEGIN
			iF exists(select statusid from acc_docdetails with(nolock) 
			where AccDocDetailsID=@AccDocDetailsID and statusid in(369,429))
			continue;
		END	
			
		if(@IsLockedPosting=1)
			set @AccDocDetailsID=0
	END
	declare @DuplicateChequeNumber bit
	select @DuplicateChequeNumber=PrefValue from @TblDocPref where PrefName='AllowDuplicateChequeNumber' 
	
	if (@Chequeno is not null and @Chequeno <>'' and (@DuplicateChequeNumber=0 or @DuplicateChequeNumber is null))
	begin 	 
		declare @ChequeAccountID int	 	    
		
		if (@DocumentType=14 or @DocumentType=15)	
			SET @ChequeAccountID=@ACCOUNT2 		   
		else if (@DocumentType=18 or @DocumentType=19)	
			SET @ChequeAccountID=@ACCOUNT1
 			
			EXEC	@return_value = [spACC_ValidateChequeNo]
					@AccountID = @ChequeAccountID,					
					@DocDetID = @AccDocDetailsID,
					@Typeid = @DocumentType,
					@ChequeNo = @Chequeno,
					@ChequeBookNo = @ChequeBookNo,
					@RefCCID = 400,    
					@RefNodeid = @RefNodeid ,					
					@CostCenterID=@CostCenterID,
					@DocID=@DocID,    
					@UserID = @UserID,
					@LangID = @LangID
			
			if(@return_value=-999)
			BEGIN
				 ROLLBACK TRANSACTION    
				 SET NOCOUNT OFF      
				 RETURN -999 
			END
	end 
    
	IF(@TEXTXML IS NOT NULL AND CONVERT(NVARCHAR(MAX),@TEXTXML)<>'' and @UNIQUECNT>0)  
	BEGIN 
			 
			DECLARE @iUNIQ INT
			DECLARE @TableName NVARCHAR(50) , @SECTIONID INT 
			DECLARE @tempCode NVARCHAR(200),@DUPNODENO NVARCHAR(200)
						
			SET  @iUNIQ = 0 
			
			WHILE (@iUNIQ < @UNIQUECNT )
				BEGIN 
					SET @iUNIQ = @iUNIQ + 1 
					SELECT @SYSCOL = SYSCOLUMNNAME  ,@TYPE = USERCOLUMNNAME  , @SECTIONID = SECTIONID  FROM @TEMPUNIQUE WHERE ID =  @iUNIQ 
					
					set @DUPNODENO=''
					
					IF(@SECTIONID = 3)
						SET @IROWNO = ISNULL(@IROWNO , 0) + 1
					
					IF(@SYSCOL LIKE '%dcAlpha%')
						BEGIN
							continue;
						END 
					ELSE IF(@SYSCOL LIKE '%dcCCNID%') 
						BEGIN
							SET @TableName = 'COM_DOCCCDATA'
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
							SET @TableName = 'COM_DOCNUMDATA'
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
						SET @DUPLICATECODE =  ' IF EXISTS (SELECT   DOCEXT.ACCDOCDETAILSID    FROM '+ @TableName +' DOCEXT WITH(NOLOCK) 
						JOIN ACC_DOCDETAILS ACC WITH(NOLOCK)  ON DOCEXT.ACCDOCDETAILSID = ACC.ACCDOCDETAILSID WHERE ACC.StatusID<>376 AND '
						IF(@SECTIONID = 3)
								set @DUPLICATECODE = @DUPLICATECODE+' ACC.ACCDOCDETAILSID <> '+ CONVERT(NVARCHAR(50),@AccDocDetailsID) +' AND '
							else
								set @DUPLICATECODE = @DUPLICATECODE+' ACC.DOCID <> '+ CONVERT(NVARCHAR(50),@DocID) +' AND '
						
						SET @DUPLICATECODE = @DUPLICATECODE+ ' ACC.COSTCENTERID =  '+ CONVERT(NVARCHAR(50), @CostCenterID) +' and '+ @SYSCOL+' = '''+ @DUPNODENO +''') 
						BEGIN 
							SET @QUERYTEST = (SELECT TOP 1  ACC.VOUCHERNO    FROM '+ @TableName +' DOCEXT WITH(NOLOCK) 
							JOIN ACC_DOCDETAILS ACC WITH(NOLOCK)  ON DOCEXT.ACCDOCDETAILSID = ACC.ACCDOCDETAILSID WHERE ' 
							IF(@SECTIONID = 3)
								set @DUPLICATECODE = @DUPLICATECODE+' ACC.ACCDOCDETAILSID <> '+ CONVERT(NVARCHAR(50),@AccDocDetailsID) +' AND '
							else
								set @DUPLICATECODE = @DUPLICATECODE+' ACC.DOCID <> '+ CONVERT(NVARCHAR(50),@DocID) +' AND '
							SET @DUPLICATECODE = @DUPLICATECODE+' ACC.COSTCENTERID =  '+ CONVERT(NVARCHAR(50), @CostCenterID) +' and '+ @SYSCOL+' = '''+ @DUPNODENO +''')					
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

			
		select @PrefVal=PrefValue from @TblDocPref where PrefName='AutoChequeNo'			
		if(@PrefVal='True' and @IsImport=0)
		BEGIN
			set @ChequeBookNo=''
			select @ChequeBookNo=X.value('@ChequeBookNo','nvarchar(max)') from @TRANSXML.nodes('/Transactions') as Data(X)  
			select @CurrentChequeNumber=CurrentNo,@EndNo=EndNo,@StNo=StartNo from ACC_ChequeBooks WITH(NOLOCK)  where BankAccountID=@ACCOUNT2 and BookNo=@ChequeBookNo
			
			if exists(select PrefValue from @TblDocPref where PrefName='AutoChequeonPost' and PrefValue='true')
			and (@Chequeno is null or @Chequeno='') and @StatusID in(369,370)
			BEGIN
				if(@I>2)
					select @Chequeno=ChequeNumber from ACC_DocDetails  WITH(NOLOCK) where  docid=@DocID and ChequeNumber is not null and ChequeNumber<>''
				ELSE
					set @Chequeno=@CurrentChequeNumber
			END
		
			if(@Chequeno>@EndNo or @Chequeno<@StNo)
				RAISERROR('-400',16,1)  --NotValid			
			
			IF exists(select ChequeNo from ACC_ChequeCancelled  WITH(NOLOCK) where BankAccountID=@ACCOUNT2 and BookNo=@ChequeBookNo and ChequeNo=@Chequeno)
			BEGIN
				RAISERROR('-401',16,1)  --Cancelled
			END
			
			if exists (select CostCenterID from ADM_CostCenterDef WITH(NOLOCK) where CostCenterID=@CostCenterID and SysColumnName='ChequeNumber' and SectionID=3)
			BEGIN
				IF exists(select ChequeNumber from ACC_DocDetails  WITH(NOLOCK) where AccDocDetailsID<>@AccDocDetailsID and [CreditAccount]=@ACCOUNT2 and ChequeBookNo=@ChequeBookNo and ChequeNumber=convert(nvarchar,@Chequeno))
				BEGIN
					RAISERROR('-402',16,1)  --Used Cheque
				END
			END
			ELSE
			BEGIN
				IF exists(select ChequeNumber from ACC_DocDetails  WITH(NOLOCK) where DocID<>@DocID and [CreditAccount]=@ACCOUNT2 and ChequeBookNo=@ChequeBookNo and ChequeNumber=convert(nvarchar,@Chequeno))
				BEGIN
					RAISERROR('-402',16,1)  --Used Cheque
				END
			END
			
			IF(@Chequeno>=@CurrentChequeNumber)
			BEGIN
				Update Acc_ChequeBooks Set CurrentNo=REPLACE(@Chequeno,CONVERT(INT,@Chequeno),'')+CONVERT(NVARCHAR,(@Chequeno+1)) 
				where BankAccountID=@ACCOUNT2 and BookNo=@ChequeBookNo 
			END
		 END
	
	set @BankAccountID=null
	select @PrefValue=value from @TblPref where name='Intermediate PDC'		
    if(@PrefValue='True' and @DocumentType in(19,14))
    begin     
		if(@DocumentType =19)
		begin
			if (select ISNULL(X.value('@IsNegative','BIT'),0)
			from @TRANSXML.nodes('/Transactions') as Data(X))=1
			BEGIN
				if exists(select accounttypeid from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT2 and accounttypeid in(2,3))
				begin
					set @BankAccountID=@ACCOUNT2
					select @ACCOUNT2=PDCReceivableAccount from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT2
					 IF(@ACCOUNT2 is null or @ACCOUNT2 <=1)
						RAISERROR('-365',16,1)
									
				end
			END
		  	ELSE
		  	BEGIN			
				if exists(select accounttypeid from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT1 and accounttypeid in(2,3))
				begin
					set @BankAccountID=@ACCOUNT1
					select @ACCOUNT1=PDCReceivableAccount from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT1
					 IF(@ACCOUNT1 is null or @ACCOUNT1 <=1)
						RAISERROR('-365',16,1)
									
				end
			END	
		end
		else
		begin
			if (select ISNULL(X.value('@IsNegative','BIT'),0)
			from @TRANSXML.nodes('/Transactions') as Data(X))=1
			BEGIN
				if exists(select accounttypeid from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT1 and accounttypeid in(2,3))
				begin
					set @BankAccountID=@ACCOUNT1
					
					if(@RefCCID=95 and exists(select Value from COM_CostCenterPreferences WITH(NOLOCK) where CostCenterID=95 and Name='PDCRecievableforPDP' and Value='true'))
						select @ACCOUNT1=PDCReceivableAccount from ACC_Accounts WITH(NOLOCK)  where AccountID=@ACCOUNT1
					else	
						select @ACCOUNT1=PDCPayableAccount from ACC_Accounts WITH(NOLOCK)  where AccountID=@ACCOUNT1
						
					 IF(@ACCOUNT1 is null or @ACCOUNT1 <=1)
						RAISERROR('-366',16,1)				
				end
			END
			ELSE
			BEGIN
				if exists(select accounttypeid from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT2 and accounttypeid in(2,3))
				begin
					set @BankAccountID=@ACCOUNT2
					
					if(@RefCCID=95 and exists(select Value from COM_CostCenterPreferences WITH(NOLOCK) where CostCenterID=95 and Name='PDCRecievableforPDP' and Value='true'))
						select @ACCOUNT2=PDCReceivableAccount from ACC_Accounts WITH(NOLOCK)  where AccountID=@ACCOUNT2
					else	
						select @ACCOUNT2=PDCPayableAccount from ACC_Accounts WITH(NOLOCK)  where AccountID=@ACCOUNT2
						
					 IF(@ACCOUNT2 is null or @ACCOUNT2 <=1)
						RAISERROR('-366',16,1)				
				end
			END	
		end
    end
    ELSE if(@DocumentType =16)
    BEGIN
		if exists(select  X.value('@PostPDC','INT')  from @TRANSXML.nodes('/Transactions') as Data(X)   
		 where X.value('@PostPDC','INT')=1)
		 BEGIN
			if(@ACCOUNT1>0 and exists(select accounttypeid from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT1 and accounttypeid in(2,3)))
			BEGIN
				set @BankAccountID=@ACCOUNT1
				select @ACCOUNT1=PDCReceivableAccount from ACC_Accounts WITH(NOLOCK)  where AccountID=@ACCOUNT1
			END
			else if(@ACCOUNT2>0 and exists(select accounttypeid from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT2 and accounttypeid in(2,3)))
			BEGIN	
				set @BankAccountID=@ACCOUNT2
				select @ACCOUNT2=PDCPayableAccount from ACC_Accounts WITH(NOLOCK)  where AccountID=@ACCOUNT2
			END		
		 END
    END
   
   IF(@AccDocDetailsID=0)    
   BEGIN  
		INSERT INTO ACC_DocDetails    
         ([DocID]    
         ,[CostCenterID]                 
         ,[DocumentType],DocOrder   
         ,[VersionNo]    
         ,[VoucherNo]    
         ,[DocAbbr]    
         ,[DocPrefix]    
         ,[DocNumber]    
         , ActDocDate
         ,[DocDate]    
         ,[DueDate]    
         ,[StatusID]    
         ,[ChequeBankName]    
         ,[ChequeNumber]    
         ,[ChequeDate]    
         ,[ChequeMaturityDate]    
         ,[BillNo]    
         ,BillDate                 
         ,[CommonNarration]    
         ,LineNarration    
         ,[DebitAccount]    
         ,[CreditAccount]    
         ,[Amount]    
         ,IsNegative    
         ,[DocSeqNo]    
         ,[CurrencyID]    
         ,[ExchangeRate] 
		 ,[AmountFC]   
         ,[CreatedBy]    
         ,[CreatedDate] ,[ModifiedBy]  
         ,[ModifiedDate],WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID ,RefNodeid
         ,BankAccountID,ChequeBookNo,[Description],OpPdcStatus,AP)    
          
        SELECT @DocID    
         , @CostCenterID             
         , @DocumentType,@DocOrder   
         , @VersionNo  
         , @VoucherNo    
         , @DocAbbr    
         , @DocPrefix    
         , @DocNumber    
         ,CONVERT(int, X.value('@ActDocDate','Datetime'))       
         , CONVERT(FLOAT,@DocDate)    
         , Case WHEN CONVERT(FLOAT, X.value('@DueDate','DATETIME')) is null THEN CONVERT(FLOAT,@DueDate)    
           ELSE CONVERT(FLOAT, X.value('@DueDate','DATETIME')) END
         , @StatusID    
         , X.value('@ChequeBankName','nvarchar(1000)')    
         , @Chequeno    
         , CONVERT(FLOAT, X.value('@ChequeDate','DATETIME'))    
         , CONVERT(FLOAT,X.value('@ChequeMaturityDate','DATETIME'))    
		, Case WHEN  X.value('@BillNo','NVarChar(500)') is not null THEN X.value('@BillNo','NVarChar(500)') ELSE @BillNo  END    
		 ,CONVERT(FLOAT,X.value('@BillDate','datetime'))               
         , X.value('@CommonNarration','nvarchar(max)')    
         , X.value('@LineNarration','nvarchar(max)')    
         ,@ACCOUNT1  --debit    
         ,@ACCOUNT2  --Credit    
         , X.value('@Amount','FLOAT')    
         , ISNULL(X.value('@IsNegative','BIT'),0)         
         , X.value('@DocSeqNo','int')    
         , ISNULL(X.value('@CurrencyID','int'),1)    
         , ISNULL(X.value('@ExchangeRate','float'),1)    
		 , ISNULL(X.value('@AmtFc','float'),(X.value('@Amount','FLOAT')/ISNULL(X.value('@ExchangeRate','float'),1)))  
        
         , @UserName    
         , @Dt, @UserName    
         , @Dt,@WID,@StatusID,@level,@RefCCID,@RefNodeid,@BankAccountID, X.value('@ChequeBookNo','nvarchar(max)')
         ,X.value('@Description','Nvarchar(max)'),X.value('@OpPdcStatus','INT'),@AP
		  from @TRANSXML.nodes('/Transactions') as Data(X)    
		SET @AccDocDetailsID=@@IDENTITY  
     
     
		INSERT INTO [COM_DocCCData] ([AccDocDetailsID])     
		values(@AccDocDetailsID)

		INSERT INTO [COM_DocNumData] ([AccDocDetailsID])     
		values(@AccDocDetailsID)
	  
		INSERT INTO [COM_DocTextData]([AccDocDetailsID])
        values(@AccDocDetailsID)
         
  END    
  ELSE    
  BEGIN  
		
		select @oldseqno=DocSeqNo,@oldVoucherNo=VoucherNo
		,@StNo=brs_status,@Amount=Amount,@RefDueDate=Docdate,@NID=case when documenttype in(14,15) THEN CreditAccount else Debitaccount end
		from [ACC_DocDetails] WITH(NOLOCK) 
		WHERE AccDocDetailsID=@AccDocDetailsID    
		
		if(@StNo=1)
		BEGIN
			select @Amtfc=X.value('@Amount','float')
			 from @TRANSXML.nodes('/Transactions') as Data(X)   
			  
			iF @Amtfc<>@Amount or @RefDueDate<>convert(float,@DocDate) or (@DocumentType in(14,15) and @ACCOUNT2<>@NID) or (@DocumentType not in(14,15)and @ACCOUNT1<>@NID)
				set @StNo=0
		END

		DELETE B FROM [COM_Billwise] B WITH(NOLOCK)   
		WHERE [DocNo]=@oldVoucherNo AND DocSeqNo=@oldseqno 
		
		DELETE B FROM COM_BillWiseNonAcc   B WITH(NOLOCK)     
		WHERE [DocNo]=@oldVoucherNo AND DocSeqNo=@oldseqno 
		
		DELETE B FROM COM_LCBills   B WITH(NOLOCK)     
		WHERE [DocNo]=@oldVoucherNo AND DocSeqNo=@oldseqno 
		 
	   update B
	   set RefDocNo=NULL,RefDocSeqNo=NULL,[IsNewReference]=1,[RefDocDueDate]=NULL
	   FROM COM_Billwise B WITH(NOLOCK)
	   where RefDocNo=@oldVoucherNo and RefDocSeqNo=@oldseqno
	   and AccountID not in (select  X.value('@AccountID','INT') from @EXTRAXML.nodes('/EXTRAXML/BillWise/Row') as Data(X)) 
	   
	   update B
	   set RefDocNo=@VoucherNo,RefDocSeqNo=@DOCSEQNO
	   FROM COM_Billwise B WITH(NOLOCK)
	   where RefDocNo=@oldVoucherNo and RefDocSeqNo=@oldseqno

	
    UPDATE [ACC_DocDetails]    
     SET  VersionNo =@VersionNo 
         ,DocNumber=@DocNumber
		 ,VoucherNo=@VoucherNo
         ,DocDate= CONVERT(FLOAT,@DocDate)    
         ,DueDate=   Case WHEN CONVERT(FLOAT, X.value('@DueDate','DATETIME')) is null THEN CONVERT(FLOAT,@DueDate)    
          ELSE CONVERT(FLOAT, X.value('@DueDate','DATETIME')) END
         ,StatusID= @StatusID    
         ,ActDocDate=CONVERT(int, X.value('@ActDocDate','Datetime'))       
         ,BillNo= Case WHEN  X.value('@BillNo','NVarChar(500)') is not null THEN X.value('@BillNo','NVarChar(500)') ELSE @BillNo  END
         ,BillDate=CONVERT(FLOAT,X.value('@BillDate','datetime'))    
         ,ChequeBankName= X.value('@ChequeBankName','nvarchar(1000)')    
         ,ChequeNumber= @Chequeno    
         ,ChequeDate= CONVERT(FLOAT, X.value('@ChequeDate','DATETIME'))    
         ,ChequeMaturityDate= CONVERT(FLOAT,X.value('@ChequeMaturityDate','DATETIME'))               
         ,CommonNarration= X.value('@CommonNarration','nvarchar(max)')    
         ,LineNarration=   X.value('@LineNarration','nvarchar(max)')    
         ,DebitAccount= @ACCOUNT1 
         ,CreditAccount=@ACCOUNT2
         ,Amount= X.value('@Amount','float')    
         ,DocSeqNo= X.value('@DocSeqNo','int')    
         ,CurrencyID=ISNULL(X.value('@CurrencyID','int'),1)    
         ,ExchangeRate= ISNULL(X.value('@ExchangeRate','float'),1)    
		 ,AmountFC=ISNULL(X.value('@AmtFc','float'),(X.value('@Amount','FLOAT')/ISNULL(X.value('@ExchangeRate','float'),1)))  
		 ,IsNegative=ISNULL(X.value('@IsNegative','BIT'),0)          
         ,ModifiedBy= @UserName    
         ,ModifiedDate= @Dt    
         ,WorkflowID=@WID
		, WorkFlowStatus =@StatusID
		, WorkFlowLevel=@level
		,RefCCID=@RefCCID,RefNodeid=@RefNodeid
		,BankAccountID=@BankAccountID
		,ChequeBookNo= X.value('@ChequeBookNo','nvarchar(max)') 		
		,brs_status=@StNo
		,Description=X.value('@Description','Nvarchar(max)')
		,AP=@AP
      from @TRANSXML.nodes('/Transactions') as Data(X)    
      WHERE AccDocDetailsID=@AccDocDetailsID          
    
           
   END    
    
    
      set @DUPLICATECODE=''
      SELECT @DUPLICATECODE=X.value('@Query',' nvarchar(max)')
      from @NUMXML.nodes('/Numeric') as Data(X)              
	  if(@DUPLICATECODE<>'')
	  BEGIN
			set @DUPLICATECODE= rtrim(@DUPLICATECODE)
			set @DUPLICATECODE=substring(@DUPLICATECODE,0,len(@DUPLICATECODE)- charindex(',',reverse(@DUPLICATECODE))+1)

			set @DUPLICATECODE='Update [COM_DocNumData] set '+@DUPLICATECODE+'  where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)
			print @DUPLICATECODE
			exec(@DUPLICATECODE)
	  END	
	  
	  set @DUPLICATECODE=''
      SELECT @DUPLICATECODE=X.value('@Query',' nvarchar(max)')
      from @TEXTXML.nodes('/Alpha') as Data(X)              
	  if(@DUPLICATECODE<>'')
	  BEGIN
			set @DUPLICATECODE= rtrim(@DUPLICATECODE)
			set @DUPLICATECODE=substring(@DUPLICATECODE,0,len(@DUPLICATECODE)- charindex(',',reverse(@DUPLICATECODE))+1)
			set @DUPLICATECODE=replace(@DUPLICATECODE,'@~','
')      
			set @DUPLICATECODE='Update [COM_DocTextData] set '+@DUPLICATECODE+'   where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)
			print @DUPLICATECODE
			exec(@DUPLICATECODE)
	  END	
	  
	  IF(@UNIQUECNT>0)      
	  BEGIN  
		SET  @iUNIQ = 0 
		
		WHILE (@iUNIQ < @UNIQUECNT )    
		BEGIN     
			SET @iUNIQ = @iUNIQ + 1     
			SELECT @SYSCOL = SYSCOLUMNNAME  ,@TYPE = USERCOLUMNNAME  , @SECTIONID = SECTIONID  FROM @TEMPUNIQUE WHERE ID =  @iUNIQ     
	        
	        set @DUPNODENO=''
			IF(@SYSCOL LIKE '%dcAlpha%')    
			BEGIN    
				SET @tempCode='@DUPNODENO nvarchar(max) OUTPUT '     
				SET @DUPLICATECODE  = 'SELECT   @DUPNODENO ='+@SYSCOL +'     
				from COM_DOCTEXTDATA WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)     
				EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT 
			END     
			ELSE    			    
				 continue;  			
	          
			--sectionid = 3 for linewise    
			if(@DUPNODENO is not null and @DUPNODENO<>'')
			BEGIN     
				SET @tempCode ='@QUERYTEST  NVARCHAR(100) OUTPUT'    
				SET @DUPLICATECODE =  ' IF EXISTS (SELECT DOCEXT.AccDocDetailsID FROM COM_DOCTEXTDATA DOCEXT with(nolock)
				JOIN ACC_DOCDETAILS ACC with(nolock) ON DOCEXT.AccDocDetailsID=ACC.AccDocDetailsID WHERE ACC.StatusID<>376 AND  '
				IF(@SECTIONID = 3)
					set @DUPLICATECODE = @DUPLICATECODE+' ACC.AccDocDetailsID <> '+ CONVERT(NVARCHAR(50),@AccDocDetailsID) +' AND '
				else
					set @DUPLICATECODE = @DUPLICATECODE+' ACC.DOCID <> '+ CONVERT(NVARCHAR(50),@DocID) +' AND '

				SET @DUPLICATECODE = @DUPLICATECODE+ '    
				ACC.COSTCENTERID =  '+ CONVERT(NVARCHAR(50), @CostCenterID) +' and '+ @SYSCOL+' = '''+ @DUPNODENO +''')     
				BEGIN     
				SET @QUERYTEST = (SELECT  TOP 1 ACC.VOUCHERNO FROM COM_DOCTEXTDATA DOCEXT with(nolock)
				JOIN ACC_DOCDETAILS ACC with(nolock) ON DOCEXT.AccDocDetailsID = ACC.AccDocDetailsID WHERE  '
				IF(@SECTIONID = 3)
					set @DUPLICATECODE = @DUPLICATECODE+' ACC.AccDocDetailsID <> '+ CONVERT(NVARCHAR(50),@AccDocDetailsID) +' AND '
				else
					set @DUPLICATECODE = @DUPLICATECODE+' ACC.DOCID <> '+ CONVERT(NVARCHAR(50),@DocID) +' AND '

				SET @DUPLICATECODE = @DUPLICATECODE+ '  ACC.COSTCENTERID =  '+     
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

	  set @DUPLICATECODE=''
      SELECT @DUPLICATECODE=X.value('@Query',' nvarchar(max)')
      from @CCXML.nodes('/CostCenters') as Data(X)              
	  if(@DUPLICATECODE<>'')
	  BEGIN
			set @DUPLICATECODE= rtrim(@DUPLICATECODE)
			set @DUPLICATECODE=substring(@DUPLICATECODE,0,len(@DUPLICATECODE)- charindex(',',reverse(@DUPLICATECODE))+1)

			set @DUPLICATECODE='Update [COM_DocCCData] set '+@DUPLICATECODE+' where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)
			exec(@DUPLICATECODE)
	  END
	  
	  set @batchID=0
	   select @batchID=X.value('@BatchID','INT') 
		  from @TRANSXML.nodes('/Transactions') as Data(X) 
	
		if(@batchID is not null and @batchID>0)
		BEGIN
			set @DUPLICATECODE='Update [ACC_DocDetails] set BatchID='+convert(nvarchar,@batchID)+' where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)
			print @DUPLICATECODE
			exec(@DUPLICATECODE)
		END
		
		--PosPayModes		      
		if(@Denominationxml is not null and CONVERT(nvarchar(max),@Denominationxml)<>'')
		begin
			INSERT INTO COM_DocDenominations(DOCID,[CurrencyID],[Notes],[NotesTender],[Change],[ChangeTender],AccDocDetailsID,PosCloseID)
			  select @DocID,X.value('@CurrencyID','INT'),X.value('@Notes','float'),X.value('@NotesTender','float')
			  ,X.value('@Change','float'),X.value('@ChangeTender','float'),@AccDocDetailsID,(CASE WHEN @IsSessionCls=1 THEN @PosSessionID ELSE 0 END)
			  FROM @Denominationxml.nodes('/PosPayModes/XML') as Data(X) where X.value('@IsDenom','BIT')=1
		end
		
		set @DUPLICATECODE=''
		SELECT @DUPLICATECODE=PrePaymentXML FROM @tblList  WHERE ID=@I-1
		if(@DUPLICATECODE is not null and @DUPLICATECODE<>'')
		begin
			set @DELETECCID=0
			select @DELETECCID=PrefValue from @TblDocPref where PrefName='PrepaymentDoc'
			and isnumeric(PrefValue)=1 and CONVERT(int,PrefValue)>40000
			 
			 EXEC @return_value = [dbo].spDOc_SavePrePayments  
				@IsInventory=0,
				@CostCenterID = @DELETECCID,  
				@Prepaymentxml = @DUPLICATECODE,  
				@AccDocDetailsID=@AccDocDetailsID,
				@invDetID=0,
				@CompanyGUID=@CompanyGUID,
				@UserName=@UserName,
				@UserID=@UserID,
				@LangID=@LangID
				
		END
	
	if (@StatusID=369 and @documenttype in(17,18,22) and @ManaProp=1)
	BEGIN
		set @tempCode='spRen_CommisionPosting'
		exec @tempCode @AccDocDetailsID,@CostCenterID,@DocID,@UserID,@LangID
	END		
    
    if((@IsLineWisePDC=1 or @isCrossDim=1) and @PDCDocument>1)
	begin
		if(@isCrossDim=1)
		BEGIN
			set @DUPLICATECODE='select @ConCCID=DcccNID'+convert(nvarchar,(@CrossDimension-50000))+' from COM_DocCCData with(nolock) where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)
			EXEC sp_executesql @DUPLICATECODE,N'@ConCCID INT OUTPUT',@ConCCID output
			
			set @DUPLICATECODE='select @NID='+@CrossDimFld+' from COM_DocTextData with(nolock) where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)
			EXEC sp_executesql @DUPLICATECODE,N'@NID INT OUTPUT',@NID output
			
			
			set @DUPLICATECODE=''
			set @Remarks=''
			select @DUPLICATECODE=Value from ADM_GlobalPreferences WITH(NOLOCK)
			where name ='ToCrossDimensions'
			
			if(@DUPLICATECODE<>'')
			BEGIN
				delete from @table
				insert into @table
				exec SPSplitString @DUPLICATECODE,','
				
				set @DUPLICATECODE=''
				select @DUPLICATECODE=@DUPLICATECODE+'+  '' and DcCCNID'+convert(nvarchar(max),(convert(bigint,TypeID)-50000))+'=''+convert(nvarchar(max),DcCCNID'+convert(nvarchar(max),(convert(bigint,TypeID)-50000))+')' from @table
				where isnumeric(TypeID)=1
				
				set @DUPLICATECODE='select @Remarks='+substring(@DUPLICATECODE,2,len(@DUPLICATECODE))+'
				from COM_DocCCData with(nolock) where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)			
				EXEC sp_executesql @DUPLICATECODE,N'@Remarks nvarchar(max) OUTPUT',@Remarks output
			END
						
			set @ACCOUNT1=0
			set @ACCOUNT2=0
			if(@ConCCID<>@NID)
			BEGIN
				
				if(@Remarks<>'')
				BEGIN
					set @DUPLICATECODE='SELECT @ACCOUNT1=DrAccount,@ACCOUNT2=CrAccount	from ADM_CrossDimension WITH(NOLOCK)
					where DimIn='+convert(nvarchar,@ConCCID)+' and DimFor='+convert(nvarchar,@NID)+' and Document='+convert(nvarchar,@CostCenterID)+@Remarks
					EXEC sp_executesql @DUPLICATECODE,N'@ACCOUNT1 INT output,@ACCOUNT2 INT OUTPUT',@ACCOUNT1 output,@ACCOUNT2 output			
				END
				ELSE
					SELECT @ACCOUNT1=DrAccount,@ACCOUNT2=CrAccount	from ADM_CrossDimension WITH(NOLOCK) 
					where DimIn=@ConCCID  and DimFor=@NID and Document=@CostCenterID
					
				if(@ACCOUNT1 is null or @ACCOUNT2 is null or @ACCOUNT2=0 or  @ACCOUNT1=0)
				BEGIN
					if(@DocumentType in(18,19,22))
					BEGIN
						if(@Remarks<>'')
						BEGIN
							set @DUPLICATECODE='SELECT @ACCOUNT1=DrAccount,@ACCOUNT2=CrAccount	from ADM_CrossDimension WITH(NOLOCK)
							where DimIn='+convert(nvarchar,@ConCCID)+' and DimFor='+convert(nvarchar,@NID)+' and Document=1 '+@Remarks
							EXEC sp_executesql @DUPLICATECODE,N'@ACCOUNT1 INT output,@ACCOUNT2 INT OUTPUT',@ACCOUNT1 output,@ACCOUNT2 output			
						END
						ELSE
							SELECT @ACCOUNT1=DrAccount,@ACCOUNT2=CrAccount	from ADM_CrossDimension WITH(NOLOCK) 
							where DimIn=@ConCCID  and DimFor=@NID and Document=1
					END	
					Else if(@DocumentType in(15,14,23))
					BEGIN
						if(@Remarks<>'')
						BEGIN
							set @DUPLICATECODE='SELECT @ACCOUNT1=DrAccount,@ACCOUNT2=CrAccount	from ADM_CrossDimension WITH(NOLOCK)
							where DimIn='+convert(nvarchar,@ConCCID)+' and DimFor='+convert(nvarchar,@NID)+' and Document=2 '+@Remarks
							EXEC sp_executesql @DUPLICATECODE,N'@ACCOUNT1 INT output,@ACCOUNT2 INT OUTPUT',@ACCOUNT1 output,@ACCOUNT2 output			
						END
						ELSE
							SELECT @ACCOUNT1=DrAccount,@ACCOUNT2=CrAccount	from ADM_CrossDimension WITH(NOLOCK) 
							where DimIn=@ConCCID  and DimFor=@NID and Document=2
					END	
				END
					
				if(@ACCOUNT1 is null or @ACCOUNT2 is null or @ACCOUNT2=0 or  @ACCOUNT1=0)
					RAISERROR('-517',16,1)
			END					
		END
		set @Refstatus=null
		Select @Refstatus=StatusID from ACC_DocDetails  WITH(NOLOCK) where RefCCID = 400 and RefNodeid=@AccDocDetailsID
		if(@isCrossDim=1)
		BEGIN
				insert into @ttdel
				SELECT AccDocDetailsID FROM  [ACC_DocDetails]  WITH(NOLOCK)    
				WHERE refccid=400 and refnodeid=@AccDocDetailsID
				
				select @ii=0,@ccnt=COUNT(accid) from @ttdel
				while(@ii<@ccnt)
				BEGIN
					set @ii=@ii+1
					set @DELETEDOCID=0						
					SELECT @DELETEDOCID = DocID, @DELETECCID = COSTCENTERID FROM ACC_DocDetails with(nolock)   
					where AccDocDetailsID=(select accid from @ttdel where id=@ii)
					
					if(@DELETEDOCID is not null and @DELETEDOCID>0)
					BEGIN
						 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
						 @CostCenterID = @DELETECCID,  
						 @DocPrefix = '',  
						 @DocNumber = '', 
						 @DocID=@DELETEDOCID , 
						 @UserID = 1,  
						 @UserName = @UserName,  
						 @LangID = @LangID,
						 @RoleID=1
					END  
				END 	
		
		END
		ELSE if(@IsLineWisePDC=1 and (@Refstatus is not null and @Refstatus in(370,371,372,441)))
		BEGIN
				set @DELETEDOCID=0
				SELECT @DELETEDOCID = DocID, @DELETECCID = COSTCENTERID FROM ACC_DocDetails with(nolock)   
				where refccid=400 and refnodeid=@AccDocDetailsID	
				if(@DELETEDOCID is not null and @DELETEDOCID>0)
				BEGIN	    
					 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
					 @CostCenterID = @DELETECCID,  
					 @DocPrefix = '',  
					 @DocNumber = '',  
					 @DocID=@DELETEDOCID ,
					 @UserID = 1,  
					 @UserName = @UserName,  
					 @LangID = @LangID,
					 @RoleID=1
				END 				
		END
		
		if(@isCrossDim=1 or (@Refstatus is null or @Refstatus in(370,371,372,441)))
		BEGIN
			declare @dxml nvarchar(max),@Prefix nvarchar(max)
			set  @TRANSXML.modify('replace value of (/Transactions/@DocDetailsID)[1] with "0"')
			set  @TRANSXML.modify('replace value of (/Transactions/@DocSeqNo)[1] with "1"')
									
		   set @dxml='<DocumentXML><Row>'
		   set @dxml=@dxml+convert(nvarchar(max),@TRANSXML)
		   set @dxml=@dxml+convert(nvarchar(max),@NUMXML)
		   set @dxml=@dxml+convert(nvarchar(max),@CCXML)
		   set @dxml=@dxml+convert(nvarchar(max),@TEXTXML)
		   if(@IsLineWisePDC=1 or @ConCCID=@NID)
		   BEGIN
			   set @dxml=@dxml+convert(nvarchar(max),@EXTRAXML)
			   set @dxml=@dxml+convert(nvarchar(max),@AccountsXML)
			   set @dxml=@dxml+convert(nvarchar(max),@ReturnXML)
		   END
		   ELSE
		   BEGIN
			 set @XML=@AccountsXML
			 set @xml.modify('
				delete /AccountsXML/Accounts[@IsExchangeGL=1]')
			 set @xml.modify('
				delete /AccountsXML/Accounts[@FromTo=2]')
				
			 set @dxml=@dxml+convert(nvarchar(max),@xml)
		   END	 
			 
		   set @dxml=@dxml+'</Row></DocumentXML>'
		   set @Prefix=''
		   
		   set @AppRejDate=@DocDate
		   
		   if(@IsLineWisePDC=1 and exists(select PrefValue from @TblDocPref where PrefName='Postonmaturity' and PrefValue='true'))
				select @AppRejDate=isnull(X.value('@ChequeMaturityDate','DATETIME'),@DocDate)
				from @TRANSXML.nodes('/Transactions') as Data(X)   
		   
		   EXEC [sp_GetDocPrefix] @dxml,@AppRejDate,@PDCDocument,@Prefix output,@AccDocDetailsID,@CrossDimension,@ConCCID   

			set @Prefix=@Prefix+@DocNumber+'/'
			EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
			@CostCenterID = @PDCDocument,      
			@DocID = 0,      
			@DocPrefix = @Prefix,      
			@DocNumber =@DOCSEQNO,      
			@DocDate = @AppRejDate,      
			@DueDate = NULL,      
			@BillNo = NULL,      
			@InvDocXML = @dxml,      
			@NotesXML = N'',      
			@AttachmentsXML = N'',      
			@ActivityXML  = N'',     
			@IsImport = @IsImport,      
			@LocationID = @LocationID,      
			@DivisionID = @DivisionID,      
			@WID = @ChWID,      
			@RoleID = @RoleID,      
			@RefCCID = 400,    
			@RefNodeid = @AccDocDetailsID ,    
			@CompanyGUID = @CompanyGUID,      
			@UserName = @UserName,      
			@UserID = @UserID,      
			@LangID = @LangID 
			
			if(@isCrossDim=1 and @ConCCID<>@NID and @return_value>0)
			BEGIN
				set @Columnname=''
				select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
				where costcenterid=@CostCenterID and 
				LocalReference is not null and LinkData is not null 
				 and LocalReference=79 and LinkData=50403
				 if(@Columnname is not null and @Columnname like 'dcNum%')
				 begin	
					 set @TEMPxml='update com_docnumdata
					 set '+@Columnname+'=0,dccalc'+replace(@Columnname,'dc','')+'=0
					 from  ACC_DocDetails with(nolock)
					 where ACC_DocDetails.AccDocDetailsID=com_docnumdata.AccDocDetailsID
					 and DocID='+convert(nvarchar,@return_value)
					 exec (@TEMPxml)
				 end 
				
				if(@ChWID=0 and @WID>0 and @StatusID not in(448,447))
				BEGIN
					Update A set StatusID=@StatusID
					FROM ACC_DocDetails A WITH(NOLOCK)
					where DOCID=@return_value  
				END
				
				select @DrAcc=DebitAccount,@CrAcc=CreditAccount from ACC_DocDetails WITH(NOLOCK)
				where DOCID=@return_value and LinkedAccDocDetailsID is null
				
				Update A set DocOrder=6
				FROM ACC_DocDetails A WITH(NOLOCK)
				where DOCID=@return_value and LinkedAccDocDetailsID is null

				if(@DocumentType in(18,19,22))	
				BEGIN
					Update A set CreditAccount=@ACCOUNT2
					FROM ACC_DocDetails A WITH(NOLOCK)
					where IsNegative=0 and DOCID=@return_value and LinkedAccDocDetailsID is null
					
					Update A set DebitAccount=@ACCOUNT2
					FROM ACC_DocDetails A WITH(NOLOCK)
					where IsNegative=1 and DOCID=@return_value and LinkedAccDocDetailsID is null
				END	
				ELSE
				BEGIN
					Update A set DebitAccount=@ACCOUNT1
					FROM ACC_DocDetails A WITH(NOLOCK)
					where IsNegative=0 and DOCID=@return_value and LinkedAccDocDetailsID is null
					
					Update A set CreditAccount=@ACCOUNT1
					FROM ACC_DocDetails A WITH(NOLOCK)
					where IsNegative=1 and DOCID=@return_value and LinkedAccDocDetailsID is null
				END
				
				if(@DocumentType in(18,19,22))
				BEGIN
					Update A set CreditAccount=@ACCOUNT1
					FROM ACC_DocDetails A WITH(NOLOCK)
					where IsNegative=1 and LinkedAccDocDetailsID is not null and LinkedAccDocDetailsID>0 and DOCID=@return_value and CreditAccount=@DrAcc
					
					Update A set DebitAccount=@ACCOUNT1
					FROM ACC_DocDetails A WITH(NOLOCK)
					where IsNegative=0 and LinkedAccDocDetailsID is not null and LinkedAccDocDetailsID>0 and DOCID=@return_value and DebitAccount=@DrAcc					
				END
				ELSE if(@DocumentType in(15,14,23))
				BEGIN
					Update A set CreditAccount=@ACCOUNT1
					FROM ACC_DocDetails A WITH(NOLOCK)
					where IsNegative=1 and LinkedAccDocDetailsID is not null and LinkedAccDocDetailsID>0 and DOCID=@return_value and CreditAccount=@DrAcc
					
					Update A set DebitAccount=@ACCOUNT1
					FROM ACC_DocDetails A WITH(NOLOCK)
					where IsNegative=0 and LinkedAccDocDetailsID is not null and LinkedAccDocDetailsID>0 and DOCID=@return_value and DebitAccount=@DrAcc
				END

				
			if (exists(select name from sys.columns
				where name='ExhgRtBC') and @CrossDimension=(select isnull(value,0) from @TblPref 
					where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000))
				BEGIN	
						
						SELECT @batchID=Value FROM @TblPref WHERE Name='BaseCurrency'

						SELECT @Columnname=Value FROM @TblPref WHERE Name='DecimalsinAmount'
						select @Currid=CurrencyID from ACC_DocDetails WITH(NOLOCK) where DocID=@return_value
						
						SELECT @LCAmount=ExchangeRate  FROM  COM_EXCHANGERATES WITH(NOLOCK) 
						where CurrencyID = @Currid AND EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
						and DimNodeID=@ConCCID ORDER BY EXCHANGEDATE DESC
						
						if(@batchID<>@Currid)
						BEGIN
							SELECT @ExchRate=ExchangeRate  FROM  COM_EXCHANGERATES WITH(NOLOCK) 
							where CurrencyID = @batchID AND EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
							and DimNodeID=@ConCCID ORDER BY EXCHANGEDATE DESC
							
							set @DUPLICATECODE='update A
								set  Amount=round(AmountFC*'+convert(nvarchar,@LCAmount)+','+@Columnname+'),ExchangeRate='+convert(nvarchar,@LCAmount)+'
								,AmountBC=round(((AmountFC*'+convert(nvarchar,@LCAmount)+')/'+convert(nvarchar,@ExchRate)+'),'+@Columnname+'),ExhgRtBC='+convert(nvarchar,@ExchRate)+'							
								FROM ACC_DocDetails A WITH(NOLOCK)
								where CostCenterID='+convert(nvarchar,@PDCDocument)+' and DocID='+convert(nvarchar,@return_value)
						END
						ELSE
							set @DUPLICATECODE='update A
							set  Amount=round(AmountFC*'+convert(nvarchar,@LCAmount)+','+@Columnname+'),ExhgRtBC='+convert(nvarchar,@LCAmount)+'
							   ,AmountBC=AmountFC,ExchangeRate='+convert(nvarchar,@LCAmount)+'							
							FROM ACC_DocDetails A WITH(NOLOCK)
							where CostCenterID='+convert(nvarchar,@PDCDocument)+' and DocID='+convert(nvarchar,@return_value)
						exec(@DUPLICATECODE)
				END
				
				set @DLockCC =@LocationID
				set @LockCC= @DivisionID
				
				if(@CrossDimension=50002)
					set @DLockCC =@NID
				if(@CrossDimension=50001)
					set @LockCC =@NID
				
				 set @TYPE='dcccnid'+convert(nvarchar,(@CrossDimension-50000))
				 
				 set @ind=Charindex(@TYPE+'=',convert(nvarchar(max),@CCXML))
				 if(@ind>0)
				 BEGIN
					 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@TYPE+'=',convert(nvarchar(max),@CCXML),0))
					 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@TYPE+'=',convert(nvarchar(max),@CCXML),0)) 
					 set @indcnt=@indcnt-@ind-1
					 if(@ind>0 and @indcnt>0)				 
					 BEGIN
				 		set @DUPNODENO=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt) 
						
						set @CCXML=replace(convert(nvarchar(max),@CCXML),@TYPE+'='+@DUPNODENO,@TYPE+'='+convert(nvarchar,@NID))
						
					 END
				END
			   
						
				Declare @TEMPRef  TABLE (ID INT identity(1,1) , SYSCOLUMNNAME NVARCHAR(50),USERCOLUMNNAME NVARCHAR(50) , SECTIONID INT,CCID INT)
				declare @REfcnt int

				
				insert into @TEMPRef
				select b.SysColumnName,a.SysColumnName,b.ColumnCostCenterID,a.ColumnCostCenterID from ADM_CostCenterDef a with(nolock)
				join ADM_CostCenterDef b with(nolock) on a.LocalReference=b.CostCenterColID
				join ADM_Features c with(nolock) on b.ColumnCostCenterID=c.FeatureID
				where a.costcenterid=@PDCDocument and a.SysColumnName like 'dcccnid%'
				and a.localreference is not null and a.localreference>0
				order by b.ColumnCostCenterID
				
				SELECT  @iUNIQ = MIN(ID),@REfcnt=max(ID) from @TEMPRef
			
				WHILE (@iUNIQ <= @REfcnt )
				BEGIN 
					
					 SELECT @SYSCOL = SYSCOLUMNNAME,@TYPE=USERCOLUMNNAME,@SECTIONID=SECTIONID,@StNo=CCID  FROM @TEMPRef WHERE ID =  @iUNIQ 
					 
					 set @ind=Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML))
					 if(@ind>0)
					 BEGIN
						 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML),0))
						 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@SYSCOL+'=',convert(nvarchar(max),@CCXML),0)) 
						 set @indcnt=@indcnt-@ind-1
						 if(@ind>0 and @indcnt>0)				 
						 BEGIN
							set @DUPNODENO=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt) 
						 
						 		set @DUPLICATECODE='select @EndNo =CCNID'+convert(nvarchar,(@StNo-50000))+' from COM_CCCCDATA WITH(NOLOCK) WHERE Costcenterid='
								+convert(nvarchar,@SECTIONID)+' and NOdeID='+@DUPNODENO
								print @DUPLICATECODE
								EXEC sp_executesql @DUPLICATECODE,N'@EndNo INT OUTPUT',@EndNo output
								
								 set @ind=Charindex(@TYPE+'=',convert(nvarchar(max),@CCXML))
								 if(@ind>0 AND @EndNo IS NOT NULL)
								 BEGIN
									 set @ind=Charindex('=',convert(nvarchar(max),@CCXML), Charindex(@TYPE+'=',convert(nvarchar(max),@CCXML),0))
									 set @indcnt=Charindex(',',convert(nvarchar(max),@CCXML), Charindex(@TYPE+'=',convert(nvarchar(max),@CCXML),0)) 
									 set @indcnt=@indcnt-@ind-1
									 if(@ind>0 and @indcnt>0)				 
									 BEGIN
									 	set @DUPNODENO=Substring(convert(nvarchar(max),@CCXML),@ind+1,@indcnt) 
										
										set @CCXML=replace(convert(nvarchar(max),@CCXML),@TYPE+'='+@DUPNODENO,@TYPE+'='+convert(nvarchar,@EndNo))
										
										if(@StNo=50002)
											set @DLockCC =@EndNo
										if(@StNo=50001)
											set @LockCC =@EndNo
											
									 END
								END	
						 END							 
					 END
					
					SET @iUNIQ = @iUNIQ + 1 
				END
				
				
			   set @dxml='<DocumentXML><Row>'
			   set @dxml=@dxml+convert(nvarchar(max),@TRANSXML)
			   set @dxml=@dxml+convert(nvarchar(max),@NUMXML)
			   set @dxml=@dxml+convert(nvarchar(max),@CCXML)
			   set @dxml=@dxml+convert(nvarchar(max),@TEXTXML)
			   set @dxml=@dxml+convert(nvarchar(max),@EXTRAXML)
			   
			   set @XML=@AccountsXML
			   set @xml.modify('
				delete /AccountsXML/Accounts[@FromTo=3]')
				
			   set @dxml=@dxml+convert(nvarchar(max),@xml)
			 
			 --  set @dxml=@dxml+convert(nvarchar(max),@AccountsXML)
			   set @dxml=@dxml+convert(nvarchar(max),@ReturnXML)
				
			   set @dxml=@dxml+'</Row></DocumentXML>'
			   set @Prefix=''
			   
			   EXEC [sp_GetDocPrefix] @dxml,@DocDate,@PDCDocument,@Prefix output

				
				set @Prefix=@Prefix+@DocNumber+'/'
				
				
				EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
				@CostCenterID = @PDCDocument,      
				@DocID = 0,      
				@DocPrefix = @Prefix,      
				@DocNumber =@DOCSEQNO,      
				@DocDate = @DocDate,      
				@DueDate = NULL,      
				@BillNo = NULL,      
				@InvDocXML = @dxml,      
				@NotesXML = N'',      
				@AttachmentsXML = N'',      
				@ActivityXML  = N'',     
				@IsImport = @IsImport,      
				@LocationID = @DLockCC,      
				@DivisionID = @LockCC,      
				@WID = @ChWID,      
				@RoleID = @RoleID,      
				@RefCCID = 400,    
				@RefNodeid = @AccDocDetailsID ,    
				@CompanyGUID = @CompanyGUID,      
				@UserName = @UserName,      
				@UserID = @UserID,      
				@LangID = @LangID 
				
				if(@return_value>0)
				BEGIN
					
					if(@ChWID=0 and @WID>0 and @StatusID not in(448,447))
					BEGIN
						Update A set StatusID=@StatusID
						FROM ACC_DocDetails A WITH(NOLOCK)
						where DOCID=@return_value  
					END

					select @DrAcc=DebitAccount,@CrAcc=CreditAccount from ACC_DocDetails WITH(NOLOCK)
					where DOCID=@return_value and LinkedAccDocDetailsID is null
					
					Update A set DocOrder=5
					FROM ACC_DocDetails A WITH(NOLOCK)
					where DOCID=@return_value
							
					if(@DocumentType in(18,19,22))	
					BEGIN
						if(@DocumentType=19 and exists(select value from @TblPref where name='Intermediate PDC' and value='True')
						and exists(select accounttypeid from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT1 and accounttypeid in(2,3)))
						BEGIN
							set @BankAccountID=@ACCOUNT1
							select @ACCOUNT1=PDCReceivableAccount from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT1
							IF(@ACCOUNT1 is null or @ACCOUNT1 <=1)
								RAISERROR('-365',16,1)
							
							Update A set DebitAccount=@ACCOUNT1,BankAccountID=@BankAccountID
							FROM ACC_DocDetails A WITH(NOLOCK)
							where IsNegative=0 and LinkedAccDocDetailsID is null and DOCID=@return_value
							
							Update A set CreditAccount=@ACCOUNT1,BankAccountID=@BankAccountID
							FROM ACC_DocDetails A WITH(NOLOCK)
							where IsNegative=1 and LinkedAccDocDetailsID is null and DOCID=@return_value
						END
						ELSE
						BEGIN
							Update A set DebitAccount=@ACCOUNT1,BankAccountID=null
							FROM ACC_DocDetails A WITH(NOLOCK)
							where IsNegative=0 and LinkedAccDocDetailsID is null and DOCID=@return_value
							
							Update A set CreditAccount=@ACCOUNT1,BankAccountID=null
							FROM ACC_DocDetails A WITH(NOLOCK)
							where IsNegative=1 and LinkedAccDocDetailsID is null and DOCID=@return_value
						END	
					END	
					ELSE
					BEGIN
						if(@DocumentType=14 and exists(select value from @TblPref where name='Intermediate PDC' and value='True')
						and exists(select accounttypeid from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT2 and accounttypeid in(2,3)))
						BEGIN
							set @BankAccountID=@ACCOUNT2
							select @ACCOUNT2=PDCPayableAccount from ACC_Accounts  WITH(NOLOCK) where AccountID=@ACCOUNT2
							IF(@ACCOUNT2 is null or @ACCOUNT2 <=1)
								RAISERROR('-365',16,1)
							
							Update A set CreditAccount=@ACCOUNT2,BankAccountID=@BankAccountID
							FROM ACC_DocDetails A WITH(NOLOCK)
							where IsNegative=0 and LinkedAccDocDetailsID is null and DOCID=@return_value
							
							Update A set DebitAccount=@ACCOUNT2,BankAccountID=@BankAccountID
							FROM ACC_DocDetails A WITH(NOLOCK)
							where IsNegative=1 and LinkedAccDocDetailsID is null and DOCID=@return_value
						END
						ELSE
						BEGIN
							Update A set CreditAccount=@ACCOUNT2,BankAccountID=null
							FROM ACC_DocDetails A WITH(NOLOCK)
							where IsNegative=0 and LinkedAccDocDetailsID is null and DOCID=@return_value
							
							Update A set DebitAccount=@ACCOUNT2,BankAccountID=null
							FROM ACC_DocDetails A WITH(NOLOCK)
							where IsNegative=1 and LinkedAccDocDetailsID is null and DOCID=@return_value
						END	
					END
					
					
					if(@DocumentType in(15,14,23))
					BEGIN
						Update A set CreditAccount=@ACCOUNT2
						FROM ACC_DocDetails A WITH(NOLOCK)
						where IsNegative=0 and LinkedAccDocDetailsID is not null and LinkedAccDocDetailsID>0 and DOCID=@return_value and CreditAccount=@CrAcc
						
						Update A set DebitAccount=@ACCOUNT2
						FROM ACC_DocDetails A WITH(NOLOCK)
						where IsNegative=1 and LinkedAccDocDetailsID is not null and LinkedAccDocDetailsID>0 and DOCID=@return_value and DebitAccount=@CrAcc
						
					END
				END	
			END
			
			
			if(@IsLineWisePDC=1 and @StatusID<>447)
			BEGIN
				Update A
				set StatusID=@StatusID,WorkflowID=@WID,WorkFlowLevel=@level,WorkFlowStatus=@StatusID
				FROM ACC_DocDetails A WITH(NOLOCK)
				where RefCCID=400 and RefNodeid=@AccDocDetailsID
			END
						 				
		END	
		set @EXTRAXML=NULL set @AccountsXML=NULL set @ReturnXML	=NULL

	end	
	
    if(@IsImport=1)    
   begin       
     SET @accid=0    
     IF EXISTS(SELECT  AccountID FROM ACC_Accounts  WITH(NOLOCK) WHERE IsBillwise=1 AND  AccountID=@ACCOUNT1)    
     BEGIN    
		 IF EXISTS(SELECT  AccountID FROM ACC_Accounts  WITH(NOLOCK) WHERE IsBillwise=1 AND  AccountID=@ACCOUNT2)    
		 BEGIN 
			if(@DocumentType in(14,15,20,23))
				RAISERROR('-568',16,1)
			else
				RAISERROR('-567',16,1)	
		 END
      SELECT @amt=X.value('@Amount','FLOAT')     
      ,@Currid=isnull(X.value('@CurrencyID','FLOAT'),1)     
      ,@ExchRate=isnull(X.value('@ExchangeRate','FLOAT') ,1)   
       ,@Amtfc=	ISNULL(X.value('@AmtFc','float'),(X.value('@Amount','FLOAT')/ISNULL(X.value('@ExchangeRate','float'),1)))    
         ,@RefDocNo= X.value('@BillWiseDocNo','NVARCHAR(500)')     
      from @TRANSXML.nodes('/Transactions') as Data(X)    
      SET @accid=@ACCOUNT1    
     END     
     ELSE IF EXISTS(SELECT  AccountID FROM ACC_Accounts  WITH(NOLOCK) WHERE IsBillwise=1 AND  AccountID=@ACCOUNT2)    
     BEGIN    
       SELECT @amt=X.value('@Amount','FLOAT')     
      ,@Currid=isnull(X.value('@CurrencyID','FLOAT'),1)     
      ,@ExchRate=isnull(X.value('@ExchangeRate','FLOAT') ,1)   
       ,@Amtfc=	ISNULL(X.value('@AmtFc','float'),(X.value('@Amount','FLOAT')/ISNULL(X.value('@ExchangeRate','float'),1)))    
         ,@RefDocNo= X.value('@BillWiseDocNo','NVARCHAR(500)')     
      from @TRANSXML.nodes('/Transactions') as Data(X)    
    
      SET @amt=-@amt 
      SET @Amtfc=-@Amtfc   
      SET @accid=@ACCOUNT2    
     END 
     
     
     if(@DocumentType in(14,15,20,23) and @ACCOUNT2=@accid)
		RAISERROR('-568',16,1)
	 else  if(@DocumentType in(18,19,21,22) and @ACCOUNT1=@accid)
		RAISERROR('-567',16,1)	
    
    IF(@accid!=0)    
    BEGIN    
     SELECT @RefDocSeqNo =DocSeqNo,@RefDocDate=DocDate,@RefDueDate=DOCDueDate,@refSt=StatusID FROM com_Billwise   WITH(NOLOCK)   
     WHERE DocNo=@RefDocNo and AccountID=@accid 
    
     if(@RefDocDate is null)    
      set @IsNewReference=1    
     else    
      set @IsNewReference=0   
       
      
    INSERT INTO [COM_Billwise]    
     ([DocNo]    
     ,[DocDate]    
     ,[DocDueDate]    
       ,[DocSeqNo],StatusID,RefStatusID,billno,BillDate       
       ,[AccountID]    
       ,[AdjAmount]    
       ,[AdjCurrID]    
       ,[AdjExchRT]    
       ,[DocType]    
       ,[IsNewReference]    
       ,[RefDocNo]    
       ,[RefDocSeqNo]    
       ,[RefDocDate]    
       ,[RefDocDueDate]    
       ,[Narration]    
       ,[IsDocPDC]             
       , AmountFC)    
     values( @VoucherNo    
     , CONVERT(FLOAT,@DocDate)    
     , CONVERT(FLOAT,@DueDate)    
       , @DOCSEQNO,@StatusID,@refSt ,@billno,@BillDate     
       , @accid    
       , @amt    
       , @Currid    
       , @ExchRate
       , @DocumentType    
       , @IsNewReference    
       , @RefDocNo    
       ,@RefDocSeqNo    
     , @RefDocDate    
     ,@RefDueDate    
       , ''    
       , 0       
       , @Amtfc)
       
       set @DUPLICATECODE=@CC+' where docno='''+@VoucherNo+''' and DocSeqNo='+convert(nvarchar(max),@DOCSEQNO)+' and AccDocDetailsID='+convert(nvarchar(max),@AccDocDetailsID)
		exec(@DUPLICATECODE)
    END    
    
   end 
   ELSE if(@DontChangeBillwise=0 and @IsImport=0 and @EXTRAXML IS NOT NULL)
   BEGIN  
		 select @RefDueDate=Case WHEN CONVERT(FLOAT, X.value('@DueDate','DATETIME')) is null THEN CONVERT(FLOAT,@DueDate)    
           ELSE CONVERT(FLOAT, X.value('@DueDate','DATETIME')) END
            from @TRANSXML.nodes('/Transactions') as Data(X)
            
		set @XML=@ActivityXML
		set @PrefVal=null
		SELECT @PrefVal=isnull(X.value('@IsRef','Nvarchar(50)'),'NO')   
		from @XML.nodes('/XML') as Data(X)    
   if((@RefCCID=95 or @RefCCID=104) and (@PrefVal is null or @PrefVal<>'Yes'))
   begin
   
      select @IsNewReference=isnull(X.value('@IsNewReference','bit') ,1)
      from @EXTRAXML.nodes('/EXTRAXML/BillWise/Row') as Data(X)
      where X.value('@IsNewReference','bit')=0
           
		
		set @refSt=null
		set @RefDocSeqNo=null
		set @RefDocNo=null
		set @RefDocDate=null
		set @RefDueDate=null
		
		if(@IsNewReference=0)
		BEGIN
			SET @RefDocSeqNo=1
			
			SET @DUPLICATECODE='select @refSt=Doc.StatusID, @RefDocNo=Doc.VoucherNo,@RefDocDate= Doc.DocDate, @RefDueDate=Doc.DueDate 
			from @EXTRAXML.nodes(''/EXTRAXML/BillWise/Row'') as Data(X)
			LEFT JOIN REN_ContractDocMapping CDM WITH(NOLOCK)  ON CDM.ContractID = '+CONVERT(NVARCHAR,@RefNodeid)+' AND X.value(''@RefDocNo'',''int'') = CDM.SNO  and CDM.isaccdoc = 0   AND CDM.ContractCCID = '+CONVERT(NVARCHAR,@RefCCID)+'      
			LEFT JOIN Inv_DocDetails Doc  WITH(NOLOCK) on  CDM.DocID =  Doc.DocID 
			where	X.value(''@IsNewReference'',''bit'')=0'
			
			EXEC sp_executesql @DUPLICATECODE,N'@EXTRAXML XML,@refSt INT OUTPUT, @RefDocNo NVARCHAR(64) OUTPUT,@RefDocDate FLOAT OUTPUT, @RefDueDate FLOAT OUTPUT',@EXTRAXML,@refSt OUTPUT, @RefDocNo OUTPUT,@RefDocDate OUTPUT, @RefDueDate OUTPUT 
		END
    
			
    INSERT INTO [COM_Billwise]    
       ([DocNo]    
       ,[DocDate]    
       ,[DocDueDate]    
       ,[DocSeqNo],StatusID,RefStatusID    
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
       ,[IsDocPDC] )  
     SELECT @VoucherNo    
       , CONVERT(FLOAT,@DocDate)    
       , @RefDueDate    
       , @DOCSEQNO,@StatusID       
       , case when X.value('@IsNewReference','bit') =0 THEN @refSt ELSE NULL END  
       , X.value('@AccountID','INT')        
	   , replace(X.value('@AdjAmount','nvarchar(50)'),',','')
       , X.value('@AdjCurrID','int')    
       , X.value('@AdjExchRT','float')    , replace(X.value('@AmountFC','nvarchar(50)'),',','')
       , @DocumentType    
       , X.value('@IsNewReference','bit')         
       , case when X.value('@IsNewReference','bit') =0 THEN @RefDocNo ELSE NULL END  
       , case when X.value('@IsNewReference','bit') =0 THEN @RefDocSeqNo ELSE NULL END  
       , case when X.value('@IsNewReference','bit') =0 THEN @RefDocDate ELSE NULL END  
       , case when X.value('@IsNewReference','bit') =0 THEN @RefDueDate ELSE NULL END  
       , X.value('@RefBillWiseID','INT')    
       , X.value('@DiscAccountID','INT')    
       , X.value('@DiscAmount','float')    
       , X.value('@DiscCurrID','int')    
       , X.value('@DiscExchRT','float')    
       , X.value('@Narration','nvarchar(max)')    
       , X.value('@IsDocPDC','bit')  
     from @EXTRAXML.nodes('/EXTRAXML/BillWise/Row') as Data(X)    
     
     set @DUPLICATECODE=@CC+' where docno='''+@VoucherNo+''' and DocSeqNo='+convert(nvarchar(max),@DOCSEQNO)+' and AccDocDetailsID='+convert(nvarchar(max),@AccDocDetailsID)
	 
	 exec(@DUPLICATECODE)
  end
  else
  begin
   
   INSERT INTO [COM_Billwise]    
       ([DocNo]    
       ,[DocDate]    
       ,[DocDueDate]    
       ,[DocSeqNo],StatusID,RefStatusID ,Billno,BillDate   
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
       ,[IsDocPDC] )    
     SELECT @VoucherNo    
       , CONVERT(FLOAT,@DocDate)    
       , @RefDueDate
       , @DOCSEQNO,@StatusID, X.value('@RefStatusID','int'),@billno,@BillDate        
       , X.value('@AccountID','INT')        
		, replace(X.value('@AdjAmount','nvarchar(50)'),',','')
       , X.value('@AdjCurrID','int')    
       , X.value('@AdjExchRT','float')    , replace(X.value('@AmountFC','nvarchar(50)'),',','')
       , @DocumentType    
       , X.value('@IsNewReference','bit')    
       , X.value('@RefDocNo','nvarchar(200)')    
       , X.value('@RefDocSeqNo','int')    
       , CONVERT(FLOAT,X.value('@RefDocDate','DATETIME'))    
       , CONVERT(FLOAT,X.value('@RefDocDueDate','DATETIME'))    
       , X.value('@RefBillWiseID','INT')    
       , X.value('@DiscAccountID','INT')    
       , X.value('@DiscAmount','float')    
       , X.value('@DiscCurrID','int')    
       , X.value('@DiscExchRT','float')    
       , X.value('@Narration','nvarchar(max)')    
       , X.value('@IsDocPDC','bit') 
     from @EXTRAXML.nodes('/EXTRAXML/BillWise/Row') as Data(X)    
     
     set @DUPLICATECODE=@CC+' where docno='''+@VoucherNo+''' and DocSeqNo='+convert(nvarchar(max),@DOCSEQNO)+' and AccDocDetailsID='+convert(nvarchar(max),@AccDocDetailsID)
	 exec(@DUPLICATECODE)

     
     insert into COM_BillWiseNonAcc(DocNo,DocSeqNo,RefDocNo,Amount,Narration)
     SELECT @VoucherNo,@DOCSEQNO,X.value('@RefDocNo','nvarchar(200)')
       , X.value('@Amount','float') , X.value('@Narration','nvarchar(max)')
     from @EXTRAXML.nodes('/EXTRAXML/BillWise/NonAccRows') as Data(X)    
     
     end
     
		declare @Bill Table(id int identity(1,1),accid INT,[DocNo] nvarchar(200),[DocSeqNo] int,amt float)
		declare @acid INT,@amtUse float,@docno nvarchar(200),@seq int,@newAmt float,@adjamt float,@Diff Float
		delete from @Bill
		insert into @Bill 
		select     X.value('@AccountID','INT') ,X.value('@RefDocNo','nvarchar(200)'), X.value('@RefDocSeqNo','int'),replace(X.value('@AdjAmount','nvarchar(50)'),',','')
		from @EXTRAXML.nodes('/EXTRAXML/BillWise/Row') as Data(X) 
		where X.value('@IsNewReference','bit') =0
		set @ii=0
		select @ii=min(id) from @Bill 
		select @ccnt=count(id)+@ii from @Bill
		while(@ii<@ccnt)
		begin
			select @acid=accid,@docno=DocNo,@seq=[DocSeqNo] from @Bill
			where id=@ii
			
			select @newAmt=isnull(sum([AdjAmount]),0) from [COM_Billwise] WITH(NOLOCK) 
			where [DocNo]=@docno and [DocSeqNo]=@seq and [IsNewReference]=1
			and [AccountID]=@acid
			
			select @adjamt=isnull(sum([AdjAmount]),0) from [COM_Billwise] WITH(NOLOCK) 
			where [RefDocNo]=@docno and [RefDocSeqNo]=@seq and [IsNewReference]=0
			and [AccountID]=@acid and (DocNo<>@VoucherNo or (DocNo=@VoucherNo and [DocSeqNo]<=@DOCSEQNO))
			
			set @Diff=round((@newAmt+@adjamt),2)
			if((@newAmt>0 and @Diff<-0.01) or (@newAmt<0 and @Diff>0.01))		
			begin
				RAISERROR('-381',16,1)
			end
			set @ii=@ii+1			
		end
    
   END    
 		
		set @tempDOc=0
		select @tempDOc=PrefValue from @TblDocPref where PrefName='DiscDoc'    
		and PrefValue is not null and isnumeric(PrefValue)=1 and convert(INT,PrefValue)>40000
		
		if(@DiscXML<>'')
		begin
			
			set @DiscXML=Replace(@DiscXML,'<DiscXML>','<DocumentXML>')
			set @DiscXML=Replace(@DiscXML,'</DiscXML>','</DocumentXML>')
			
			
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @DiscXML,@DocDate,@tempDOc,@Prefix output ,@AccDocDetailsID,0,0,0,1
			
			set @DELETEDOCID=0
			
			if(@HistoryStatus='Update')
				select @DELETEDOCID=DocID FROM ACC_DocDetails with(nolock)   
				where refccid=400 and refnodeid=@AccDocDetailsID and Costcenterid=@tempDOc

			
			EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
				@CostCenterID = @tempDOc,      
				@DocID = @DELETEDOCID,      
				@DocPrefix = @Prefix,      
				@DocNumber =N'',
				@DocDate = @DocDate,      
				@DueDate = NULL,      
				@BillNo = NULL,      
				@InvDocXML = @DiscXML,      
				@NotesXML = N'',      
				@AttachmentsXML = N'',      
				@ActivityXML  = N'',     
				@IsImport = 0,      
				@LocationID = @LocationID,      
				@DivisionID = @DivisionID,      
				@WID = 0,      
				@RoleID = @RoleID,      
				@RefCCID = 400,    
				@RefNodeid = @AccDocDetailsID ,    
				@CompanyGUID = @CompanyGUID,      
				@UserName = @UserName,      
				@UserID = @UserID,      
				@LangID = @LangID 
				
				if(@return_value=-999)
					return -999
					
				  
		END	
		ELSE if(@tempDOc>0 and @HistoryStatus='Update')
		BEGIN
				if exists(select AccDocDetailsID from acc_docdetails with(nolock) 
				where refccid=400 and refnodeid=@AccDocDetailsID and Costcenterid=@tempDOc)
				begin
					select @DELETEDOCID=DocID FROM ACC_DocDetails with(nolock)   
					where refccid=400 and refnodeid=@AccDocDetailsID and Costcenterid=@tempDOc
					
					 EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
						 @CostCenterID = @tempDOc,  
						 @DocPrefix = '',  
						 @DocNumber = '',  
						 @DOCID=@DELETEDOCID,
						 @UserID = @UserID,  
						 @UserName = @UserName,  
						 @LangID = @LangID,
						 @RoleID=@RoleID
				END
		END
   
	IF(@IsImport=0 and @AccountsXML IS NOT NULL)      
    BEGIN  		
     INSERT INTO ACC_DocDetails      
         ([DocID]  
         ,VOUCHERNO,ChequeNumber
         ,[CostCenterID]                
         ,[DocumentType]      
         ,[VersionNo]      
         ,[DocAbbr]      
         ,[DocPrefix]      
         ,[DocNumber]      
         ,[DocDate]      
         ,[DueDate]      
         ,[StatusID]      
         ,[BillNo]       
         ,[CommonNarration]      
         ,LineNarration      
         ,[DebitAccount]      
         ,[CreditAccount]      
         ,[Amount]      
         ,[DocSeqNo]      
         ,[CurrencyID]      
         ,[ExchangeRate]     
         ,[AmountFC]   
         ,IsNegative               
         ,[CreatedBy]      
         ,[CreatedDate]   ,[ModifiedBy]      
         ,[ModifiedDate] 
         ,WorkflowID   
         ,WorkFlowStatus   
         ,WorkFlowLevel  
         ,RefCCID  
         ,RefNodeid,LinkedAccDocDetailsID,AP)      
            
        SELECT @DocID,@VoucherNo,@Chequeno    
         , @CostCenterID                
          , @DocumentType      
         , @VersionNo     
         , @DocAbbr      
         , @DocPrefix      
         , @DocNumber      
         , CONVERT(FLOAT,@DocDate)      
         , CONVERT(FLOAT,@DueDate)      
         , @StatusID      
         , @BillNo         
         , X.value('@CommonNarration','nvarchar(max)')      
         , X.value('@LineNarration','nvarchar(max)')      
         , ISNULL( X.value('@DebitAccount','INT'),0) 
         , ISNULL( X.value('@CreditAccount','INT'),0) 
         , X.value('@Amount','FLOAT')      
         , @DOCSEQNO
         , ISNULL(X.value('@CurrencyID','int'),1)      
         , ISNULL(X.value('@ExchangeRate','float'),1)      
         , ISNULL(X.value('@AmtFc','FLOAT'),X.value('@Amount','FLOAT')) 
         ,ISNULL(X.value('@IsNegative','BIT'),0)             
         , @UserName      
         , @Dt   , @UserName      
         , @Dt  
         ,@WID  
         ,@StatusID  
         ,@level   
         ,@RefCCID  
         ,@RefNodeid,@AccDocDetailsID ,@AP  
           from @AccountsXML.nodes('/AccountsXML/Accounts') as Data(X)  
			
	 set @DUPLICATECODE='INSERT INTO [COM_DocCCData]([AccDocDetailsID]
           ,[InvDocDetailsID]
          
           ,[ContactID]
          
           ,[UserID]'+@DocCC+')        
       select   a.AccDocDetailsID ,NULL,ContactID,UserID'+@DocCC+' from ACC_DocDetails a  WITH(NOLOCK) 
          ,  [COM_DocCCData] b    WITH(NOLOCK) 
          where LinkedAccDocDetailsID='+convert(nvarchar(max),@AccDocDetailsID)+' and b.AccDocDetailsID='+convert(nvarchar(max),@AccDocDetailsID)
          exec(@DUPLICATECODE)
          
	 END  
	
	if exists(select PrefValue from @TblDocPref where PrefName='PostBounce' and PrefValue='true')
	BEGIN
			set @DUPLICATECODE='insert into COM_ChequeReturn(DocNo,DocSeqNo,AccountID,AdjAmount,AdjCurrID,AdjExchRT,AmountFC,
				DocDate,DocDueDate,DocType,IsNewReference,Narration,IsDocPDC,CompanyGUID,GUID,CreatedBy,CreatedDate
				'+@CCreplCols+')
				select VoucherNo,DocSeqNo,case when (IsNegative is null or IsNegative=0) and DocumentType in(14,15,23) THEN DebitAccount 
											   when (IsNegative is null or IsNegative=0) and DocumentType in(18,19,22) THEN CreditAccount 
											   when IsNegative is not null and IsNegative=1 and DocumentType in(14,15,23) THEN CreditAccount
											   when IsNegative is not null and IsNegative=1 and DocumentType in(18,19,22) THEN  DebitAccount end 
				, case when (IsNegative is null or IsNegative=0) and DocumentType in(14,15,23) THEN Amount 
											   when (IsNegative is null or IsNegative=0) and DocumentType in(18,19,22) THEN (Amount*-1) 
											   when IsNegative is not null and IsNegative=1 and DocumentType in(14,15,23) THEN (Amount*-1)
											   when IsNegative is not null and IsNegative=1 and DocumentType in(18,19,22) THEN  Amount end,CurrencyID,ExchangeRate,AmountFC,DocDate,DueDate,DocumentType,1,'',0,'+convert(nvarchar(max),@CompanyGUID   )+' ,newid(),'+convert(nvarchar(max),@UserName)+' ,convert(float,getdate())
				'+@CCreplCols+'
				from ACC_DocDetails a WITH(nolock)
				join dbo.COM_DocCCData b WITH(nolock) on a.AccDocDetailsID=b.AccDocDetailsID
				where a.AccDocDetailsID = '+convert(nvarchar(max),@AccDocDetailsID )
				exec(@DUPLICATECODE)
	END 
	else if(@ReturnXML is not null)
	BEGIN
		set @DUPLICATECODE='INSERT INTO COM_ChequeReturn    
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
       ,[IsDocPDC]
       ,[CompanyGUID]    
       ,[GUID]    
       ,[CreatedBy]    
       ,[CreatedDate]'+@CCreplCols+')    
     SELECT '''+convert(nvarchar(max),@VoucherNo)+'''
       , '''+convert(nvarchar(max),CONVERT(FLOAT,@DocDate))
       
       if(@DueDate is not null)
		set @DUPLICATECODE=@DUPLICATECODE+''','''+convert(nvarchar(max),CONVERT(FLOAT,@DueDate))+''''
	   else
		set @DUPLICATECODE=@DUPLICATECODE+''',NULL'	
       
       set @DUPLICATECODE=@DUPLICATECODE+', '+convert(nvarchar(max),@DOCSEQNO )+'  
       , X.value(''@AccountID'',''INT'')        
		, replace(X.value(''@AdjAmount'',''nvarchar(50)''),'','','''')
       , X.value(''@AdjCurrID'',''int'')    
       , X.value(''@AdjExchRT'',''float'')    , replace(X.value(''@AmountFC'',''nvarchar(50)''),'','','''')
       ,'+convert(nvarchar(max), @DocumentType)+'   
       , X.value(''@IsNewReference'',''bit'')    
       , X.value(''@RefDocNo'',''nvarchar(200)'')    
       , X.value(''@RefDocSeqNo'',''int'')    
       , CONVERT(FLOAT,X.value(''@RefDocDate'',''DATETIME''))    
       , CONVERT(FLOAT,X.value(''@RefDueDate'',''DATETIME''))             
       , X.value(''@Narration'',''nvarchar(max)'')    
       , X.value(''@IsDocPDC'',''bit'') 
       , '''+convert(nvarchar(max),@CompanyGUID   )+' ''
     , '''+convert(nvarchar(max),@guid)+'''
     , '''+convert(nvarchar(max),@UserName)+' ''
     , '''+convert(nvarchar(max),@Dt)+''''+@CCreplCols+'
     from @ReturnXML.nodes(''/ReturnXML/XML/Row'') as Data(X)    
     join [COM_DocCCData] d WITH(NOLOCK)  on d.AccDocDetailsID='+convert(nvarchar(max),@AccDocDetailsID )
    
     EXEC sp_executesql @DUPLICATECODE,N'@ReturnXML XML',@ReturnXML
	END
	
	if(@LCStatus is not null and @LCStatus='approved')
	BEGIN 
		set @DUPLICATECODE='INSERT INTO COM_LCBills    
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
       ,[IsDocPDC]             
       ,[CompanyGUID]    
       ,[GUID]    
       ,[CreatedBy]    
       ,[CreatedDate]'+@CCreplCols+')    
     SELECT '''+convert(nvarchar(max),@VoucherNo)+'''
       , '''+convert(nvarchar(max),CONVERT(FLOAT,@DocDate))+'''
       , '''+convert(nvarchar(max),CONVERT(FLOAT,@DueDate))+'''
       , '+convert(nvarchar(max),@DOCSEQNO )+'  
       , DebitAccount        
		, -Amount		 	
       , CurrencyID   
       , ExchangeRate    ,-AmountFC
       , '+convert(nvarchar(max),@DocumentType )+'   
       , 1
       , NULL
       , NULL    
       , NULL
       , NULL            
       , ''''
       , 0  
       , '''+convert(nvarchar(max),@CompanyGUID   )+''' 
     , '''+convert(nvarchar(max),@guid)+'''
     , '''+convert(nvarchar(max),@UserName)+''' 
     , '''+convert(nvarchar(max),@Dt)+''''+@CCreplCols+'
     from ACC_DocDetails a  WITH(NOLOCK)
     join [COM_DocCCData] d WITH(NOLOCK)  on d.AccDocDetailsID=a.AccDocDetailsID
     Where a.AccDocDetailsID='+convert(nvarchar(max),@AccDocDetailsID )
     exec(@DUPLICATECODE)
	END	 
  END

if(@RefCCID=300 or @RefCCID=400)
BEGIN	
	select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
	where costcenterid=@CostCenterID and 
	LocalReference is not null and LinkData is not null 
	 and LocalReference=79 and LinkData=50456
	 if(@Columnname is not null and @Columnname like 'dcAlpha%')
	 begin
		if(@RefCCID=300)
			select @vno =Voucherno from inv_DocDetails with(nolock)
			where DocID=@RefNodeid
		else if(@RefCCID=400)
			select @vno =Voucherno from ACC_DocDetails with(nolock)
			where AccDocDetailsID=@RefNodeid
		 set @TEMPxml='update COM_DocTextData
		 set '+@Columnname+'='''+@vno+''' 
		  where AccDocDetailsID in (select AccDocDetailsID from ACC_DocDetails with(nolock)
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
			from  ACC_DocDetails with(nolock)
			where ACC_DocDetails.AccDocDetailsID=COM_DocTextData.AccDocDetailsID
			and DocID='+convert(nvarchar,@DocID)
			exec (@TEMPxml)
		END
	end
END

	if(@IsImport=1 and @documenttype in(17,28,29)) 
	BEGIN
		select @Amount=isnull(sum(Amount),0)  from ACC_DocDetails with(nolock)
		where DocID=@DocID and CreditAccount<0

		select @amt=isnull(sum(Amount),0) from ACC_DocDetails with(nolock)
		where DocID=@DocID and DebitAccount<0
		
		
		if((@Amount-@amt)<-0.01 or (@Amount-@amt)>0.01)
		BEGIN	
			RAISERROR('-515',16,1)      			
		END	
	END 
	   	  
--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA
DECLARE @AuditTrial BIT
SET @AuditTrial=0
SELECT @AuditTrial=CONVERT(BIT,PrefValue) FROM @TblDocPref WHERE PrefName='AuditTrial'

SET @PrefValue=''    
SELECT @PrefValue=PrefValue FROM @TblDocPref WHERE PrefName='EnableRevision' 
    
IF (@AuditTrial=1 or @PrefValue='true')  
BEGIN 
	EXEC @return_value = [spDOC_SaveHistory]      
			@DocID =@DocID ,
			@HistoryStatus=@HistoryStatus,
			@Ininv =0,
			@ReviseReason =@ReviseReason,
			@LangID =@LangID

END

	set @PDCDocument=0
	select @PDCDocument=isnull(PrefValue,0) from @TblDocPref where PrefName='batchpaymentDoc' and isnumeric(PrefValue)=1
	if(@PDCDocument>0 and @StatusID=377)
	BEGIN
		if exists(select PrefValue from @TblDocPref 
		where PrefName='PostEachLineSeperate' and PrefValue='true')
			set @IsNewReference=1
		else
			set @IsNewReference=0
				
		exec @return_value= [spDoc_SetbatchpaymentDoc]
				@DocID =@DocID,
				@CCID =@PDCDocument,
				@DocDate =@DocDate,
				@VNO =@VoucherNo,
				@PostEach =@IsNewReference,
				@CompanyGUID=@CompanyGUID ,    
				@UserName=@UserName ,    
				@UserID =@UserID,
				@RoleID=@RoleID ,
				@LangID=@LangID 
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
   @guid,@UserName,@Dt    
   FROM @XML.nodes('/NotesXML/Row') as Data(X)    
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'    
    
   --If Action is MODIFY then update Notes    
   UPDATE COM_Notes    
   SET Note=Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),  
    GUID=@guid,    
    ModifiedBy=@UserName,    
    ModifiedDate=@Dt    
   FROM COM_Notes C  with(nolock)    
   INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)      
   ON convert(INT,X.value('@NoteID','INT'))=C.NoteID    
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'    
    
   --If Action is DELETE then delete Notes    
   DELETE FROM COM_Notes    
   WHERE NoteID IN(SELECT X.value('@NoteID','INT')    
    FROM @XML.nodes('/NotesXML/Row') as Data(X)    
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE')    
  END    
    
  
  if(@ActivityXML<>'')
  begin
		
		set @XML=@ActivityXML
		DECLARE @RecurDocsWithApproval INT
		SELECT @AppRejDate=X.value('@AppRejDate','Datetime'),@Remarks=X.value('@Remarks','nvarchar(max)')    
		,@RecurDocsWithApproval=X.value('@RecurDocsWithApproval','INT'),@TEMPxml=CONVERT(NVARCHAR(MAX), X.query('ScheduleActivityXml'))    
		from @XML.nodes('/XML') as Data(X)    		         
		
		if exists(select X.value('@L1Remarks','nvarchar(max)')
		from @XML.nodes('/XML') as Data(X) where X.value('@L1Remarks','nvarchar(max)') is not null)		
			select @Remarks=X.value('@L1Remarks','nvarchar(max)')
			from @XML.nodes('/XML') as Data(X)    		

		
		if @RecurDocsWithApproval is not null
			update A
			set PostRecurWithApproval=@RecurDocsWithApproval
			FROM ACC_DocDetails A WITH(NOLOCK)
			where CostCenterID=@CostCenterID and DocID=@DocID 
		
		if((@AppRejDate is not null or @WID<>0) and @level is not null)
		begin
			if((@STATUSID=369 or (@STATUSID=370 and (@DocumentType=14 or @DocumentType=19)))  and @oldStatus not in(441,369))
			begin
				INSERT INTO COM_Approvals    
						(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)      
				VALUES(@COSTCENTERID,@DOCID,441,CONVERT(FLOAT,@AppRejDate),@Remarks,@UserID,@CompanyGUID    
						,newid(),@UserName,@Dt,@level,0)
				--set @Remarks='Workflow'		
				--set @AppRejDate=getdate()
				--Post Notification 
				EXEC spCOM_SetNotifEvent 441,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
			end	
			
			INSERT INTO COM_Approvals    
					(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)      
			VALUES(@COSTCENTERID,@DOCID,@STATUSID,CONVERT(FLOAT,@AppRejDate),@Remarks,@UserID,@CompanyGUID    
					,newid(),@UserName,@Dt,@level,0)
			--Post Notification 
			EXEC spCOM_SetNotifEvent @STATUSID,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
			
			if @AppRejDate is not null and @WID>0 and @STATUSID in (369,370) and @oldStatus not in (369,370) and (exists(select Value from @TblPref where Name='DocDateasPostedDate' and Value='true')
				or exists(select PrefValue from @TblDocPref where prefName='DocDateasPostedDate' and PrefValue='true'))
			BEGIN
					update A
					set docdate=CONVERT(FLOAT,@AppRejDate)
					FROM ACC_DocDetails A WITH(NOLOCK)
					where costcenterid=@CostCenterID and DocID=@DocID
					
					update B set 
					B.docdate=CONVERT(FLOAT,@AppRejDate)
					FROM COM_Billwise B WITH(NOLOCK)
					where B.DocNo=@VoucherNo
			END
				  
		end
		
		--Activities		
		if(@TEMPxml<>'' and @TEMPxml<>'<ScheduleActivityXml/>' and @TEMPxml<>'<ScheduleActivityXml></ScheduleActivityXml>')
		begin
			exec spCom_SetActivitiesAndSchedules @TEMPxml,@CostCenterID,@DocID,@CompanyGUID,@Guid,@UserName,@dt,@LangID   
		end
		
		--History Control Data
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('History'))
		from @XML.nodes('/XML') as Data(X) 
		
		IF (@TEMPxml IS NOT NULL AND @TEMPxml <> '')    
			EXEC spCOM_SetHistory @CostCenterID,@DocID,@TEMPxml,@UserName 

		--PosPayModes
		set @TEMPxml=''
		SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('PosPayModes'))
		from @XML.nodes('/XML') as Data(X)      
		if(@TEMPxml<>'')
		begin		
			set @XML=@TEMPxml		    
			INSERT INTO COM_PosPayModes([DOCID],[Type],[Amount],DBColumnName,[CardNo],[CardName],[ExpDate],RegisterID,ShiftID,DocDate,VoucherNodeID,VoucherType)
			  select @DocID,X.value('@Type','int'),X.value('@Amount','float'),X.value('@DBColumnName','nvarchar(100)'),
			  X.value('@CardNo','nvarchar(50)'),X.value('@CardName','nvarchar(500)'),convert(float,convert(datetime, X.value('@ExpDate','datetime')))			  
			  ,X.value('@RegisterID','INT'),X.value('@ShiftID','INT'),convert(float,X.value('@DocDate','datetime'))
			  ,X.value('@VoucherNodeID','INT'),0
			  FROM @XML.nodes('/PosPayModes/XML') as Data(X) where X.value('@IsDenom','BIT') is null
		END
  end
  
  
  
  if(@Dimesion>0)    
  begin 
		set @vno=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')			
		if(@DimesionNodeID is null or (@DimesionNodeID<=0 and @DimesionNodeID>-10000))
		BEGIN
				declare @CCStatusID int
				set @CCStatusID = (select  statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active')
				
				SET @PrefValue=''    
				SELECT @PrefValue=PrefValue FROM @TblDocPref where PrefName='AutoCode'    
				if(@PrefValue='true')
				BEGIN
    					declare @Codetemp table (prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200),IsManualCode bit)
						
						insert into @Codetemp
						EXEC [spCOM_GetCodeData] @Dimesion,1,''  						 
						select @ChequeBookNo=code,@CurrentChequeNumber= prefix, @EndNo=number from @Codetemp

										
				END
				ELSE
				BEGIN
					set @ChequeBookNo=@vno
					set @CurrentChequeNumber=''
					set @EndNo=0
				END
				
				EXEC	@DimesionNodeID = [dbo].[spCOM_SetCostCenter]
					@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
					@Code = @ChequeBookNo,
					@Name = @vno,
					@AliasName='',
					@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
					@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
					@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
					@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=1,
					@CodePrefix=@CurrentChequeNumber,@CodeNumber=@EndNo,
					@CheckLink = 0,@IsOffline=@IsOffline
				
				set @DimesionNodeID=0						
				select @cctablename=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@Dimesion
				set @DUPLICATECODE='select @NodeID=NodeID from '+@cctablename+' WITH(NOLOCK) where Name='''+@vno+''''				
				EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@DimesionNodeID output
		END
		
		if(@DimesionNodeID>0 or @DimesionNodeID<-10000)
		BEGIN
			SET @DUPLICATECODE='UPDATE COM_DocCCData 
			SET dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@DimesionNodeID)
			+' FROM ACC_DocDetails a with(nolock)
			WHERE COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND DOCID='+CONVERT(NVARCHAR,@DocID)
			+' and COM_DocCCData.AccDocDetailsID=a.AccDocDetailsID'
			EXEC(@DUPLICATECODE)
			
			Exec [spDOC_SetLinkDimension]
					@InvDocDetailsID=@AccDocDetailsID,
					@Costcenterid=@CostCenterID,     
					@DimCCID=@Dimesion,
					@DimNodeID=@DimesionNodeID,
					@UserID=@UserID,    
					@LangID=@LangID    
		END		     
 end   
 
  --Inserts Multiple Attachments    
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')    
  BEGIN    
   SET @XML=@AttachmentsXML    
    
   INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,    
   FileExtension,FileDescription,IsProductImage,AllowInPrint,FeatureID,FeaturePK,    
   GUID,CreatedBy,CreatedDate,RowSeqNo,ColName,IsDefaultImage,ValidTill,IsSign,status,DocNo,Remarks,Type,RefNum)    
   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),    
   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),X.value('@AllowInPrint','bit'),@CostCenterID,@DocID,    
   X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt,X.value('@RowSeqNo','int'),X.value('@ColName','NVARCHAR(100)'),X.value('@IsDefaultImage','smallint') 
    ,convert(float,X.value('@Validtill','Datetime')),ISNULL(X.value('@IsSign','bit'),0),X.value('@stat','int')    
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
   FROM COM_Files C  with(nolock)    
   INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X)      
   ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID    
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'    
    
   --If Action is DELETE then delete Attachments    
   DELETE FROM COM_Files    
   WHERE FileID IN(SELECT X.value('@AttachmentID','INT')    
    FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE') 
     
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

	set @CrossDimension=0
	select @CrossDimension=isnull(value,0) from @TblPref 
	where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
	
	if(@CrossDimension>0)
	BEGIN
	
		set @DUPLICATECODE='select @NID=dcCCNID'+convert(nvarchar,(@CrossDimension-50000))+' from COM_DocCCData  WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)
		
		EXEC sp_executesql @DUPLICATECODE, N'@NID float OUTPUT', @NID OUTPUT   
		
		SELECT @batchID=Value FROM @TblPref WHERE Name='BaseCurrency'
		
		SELECT @Columnname=Value FROM @TblPref WHERE Name='DecimalsinAmount'
		
		SELECT @LCAmount=ExchangeRate  FROM  COM_EXCHANGERATES WITH(NOLOCK) 
		where CurrencyID = @BatchID AND EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
		and DimNodeID=@NID ORDER BY EXCHANGEDATE DESC
		
		set @DUPLICATECODE='update A
			set AmountBC=round(Amount/'+convert(nvarchar,@LCAmount)+','+@Columnname+'),ExhgRtBC='+convert(nvarchar,@LCAmount)+'
			FROM ACC_DocDetails A WITH(NOLOCK)
			where CostCenterID='+convert(nvarchar,@CostCenterID)+' and DocID='+convert(nvarchar,@DocID)+'
			
			update B 
			set AmountBC=round(AdjAmount/'+convert(nvarchar,@LCAmount)+','+@Columnname+'),ExhgRtBC='+convert(nvarchar,@LCAmount)+'
			FROM COM_Billwise B WITH(NOLOCK)
			where DocNo='''+@VoucherNo+''''
		
		exec(@DUPLICATECODE)
		
	END

	--Notification On Revision
	IF @IsRevision=1
	BEGIN
		EXEC spCOM_SetNotifEvent -2,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
	END
	--Notification On Add/Edit
	ELSE IF(@StatusID!=371 OR (select PrefValue from @TblDocPref where PrefName='DoNotEmailOrSMSUn-ApprovedDocuments')='FALSE')
	BEGIN
		DECLARE @ActionType INT
		IF @HistoryStatus='Add'
			SET @ActionType=1
		ELSE
			SET @ActionType=3				
		EXEC spCOM_SetNotifEvent @ActionType,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
	END
	
	if (@StatusID=369 and @HistoryStatus='Add' and 
	(exists(select Value from @TblPref where Name='DocDateasPostedDate' and Value='true')
	or exists(select PrefValue from @TblDocPref where prefName='DocDateasPostedDate' and PrefValue='true')))
	BEGIN
		update A
		set docdate=floor(@dt)
		FROM ACC_DocDetails A WITH(NOLOCK)
		where costcenterid=@CostCenterID and DocID=@DocID
		
		update B 
		set docdate=floor(@dt)
		FROM COM_Billwise B WITH(NOLOCK)
		where DocNo=@VoucherNo
	END
	
	--To post recur schedule
	set @tempCode=(select PrefValue from @TblDocPref where PrefName='ReversalBasedOn')
	if @tempCode is not null and @tempCode!='' and isnull((SELECT X.value('@ScheduleID','INT') from @ActXML.nodes('/XML') as Data(X)),0)=0
	begin
		set @tempCode='select top 1 @DUPLICATECODE=T.'+@tempCode+' from Acc_DocDetails D with(nolock)
		join COM_DocTextData T with(nolock) on D.AccDocDetailsID=T.AccDocDetailsID where D.DocID='+convert(nvarchar,@DocID)
		EXEC sp_executesql @tempCode,N'@DUPLICATECODE nvarchar(max) OUTPUT',@DUPLICATECODE output

		if @DUPLICATECODE='Yes'
		begin
			set @tempCode=(select PrefValue from @TblDocPref where PrefName='ReversalDate')
			set @tempCode='select top 1 @DUPLICATECODE=T.'+@tempCode+' from Acc_DocDetails D with(nolock)
			join COM_DocTextData T with(nolock) on D.AccDocDetailsID=T.AccDocDetailsID where D.DocID='+convert(nvarchar,@DocID)
			EXEC sp_executesql @tempCode,N'@DUPLICATECODE nvarchar(max) OUTPUT',@DUPLICATECODE output
			declare @DtReverseOn datetime
			if @DUPLICATECODE is null or @DUPLICATECODE=''
				set @DtReverseOn=dateadd(month,1,(dateadd(day,1-day(@DocDate),@DocDate)))
			else
				set @DtReverseOn=convert(datetime,@DUPLICATECODE)

			set @t=isnull((select ScheduleID from COM_CCSchedules with(nolock) where CostCenterID=@CostCenterID and NodeID=@DocID),0)
			if(@t>0)
			begin
				if exists(select StatusID from COM_SchEvents with(nolock) Where ScheduleID=@t and StatusID=2)
					RAISERROR('-105',16,1)
			end
			
			set @tempCode=year(@DtReverseOn)		
			if month(@DtReverseOn)<10 set @tempCode=@tempCode+'0'
			set @tempCode=@tempCode+convert(nvarchar,month(@DtReverseOn))
			if day(@DtReverseOn)<10	set @tempCode=@tempCode+'0'
			set @tempCode=@tempCode+convert(nvarchar,day(@DtReverseOn))
			
			set @ii=isnull((SELECT PrefValue FROM COM_DocumentPreferences with(nolock) where CostCenterID=@CostCenterID and PrefName='DefaultRecurringMethod'),1)
			set @ccnt=isnull((SELECT PrefValue FROM COM_DocumentPreferences with(nolock) where CostCenterID=@CostCenterID and PrefName='PostRecurDocument'),0)

			exec spDOC_SetRecurrence @CostCenterID,@DocID,@t,'Recurrence',1,1,0,0,0,0,0,@tempCode,NULL,'00:30:00',NULL,NULL,'','',@UserID,'10',@ccnt,@ii,@guid,@UserName,@UserID,@LangID
		end
		else if @HistoryStatus='Update'
		begin
			set @t=isnull((select ScheduleID from COM_CCSchedules with(nolock) where CostCenterID=@CostCenterID and NodeID=@DocID),0)
			if @t>0
			begin
				if exists(select StatusID from COM_SchEvents with(nolock) Where ScheduleID=@t and StatusID=2)
					RAISERROR('-105',16,1)
				exec spDOC_DeleteRecurrence @t,@UserID,@LangID
			end
		end
	end
	
	if exists(select value from @TblPref where Name='ReportDims' and Value<>'')
	BEGIN
			select @DUPLICATECODE=Description from adm_globalpreferences with(nolock) where Name='ReportDims'
			
			SET @DUPLICATECODE=' Update Acc_DocDetails set '+@DUPLICATECODE+' 
			 from com_docccdata a with(nolock)
			 where Docid= '+convert(nvarchar(max),@DocID)+' and a.AccDocDetailsID=Acc_DocDetails.AccDocDetailsID'
			
			exec(@DUPLICATECODE)
	END
	
	
	--validate Data External function
	set @tempCode=''
	select @tempCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=9
	if(@tempCode<>'')
		exec @tempCode @CostCenterID,@DocID,@UserID,@LangID
		
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
	
COMMIT TRANSACTION
--rollback TRANSACTION
   
select @temp=ResourceData from COM_Status S WITH(NOLOCK) 
join COM_LanguageResources R  WITH(NOLOCK) on R.ResourceID=S.ResourceID and R.LanguageID=@LangID
where S.StatusID=@StatusID
 
SELECT   ErrorMessage + '   ' + isnull(@VoucherNo,'voucherempty') +' ['+@temp+']' as ErrorMessage,@VoucherNo VoucherNo,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=105 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @DocID      
END TRY      
BEGIN CATCH   
	 if(@return_value is not null and  @return_value=-999)         
	 return -999  
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN  
	 IF ISNUMERIC(ERROR_MESSAGE())<>1
	 BEGIN
		SELECT ERROR_MESSAGE() ErrorMessage
	 END
	 else	IF (ERROR_MESSAGE() LIKE '-346' )
		BEGIN			
			SELECT    ERROR_MESSAGE(),@TYPE +  replace(ErrorMessage,'#ROWNO#',@IROWNO )  + @QUERYTEST  ErrorMessage, ERROR_MESSAGE() AS ServerMessage,
			ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE() as ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)  
			WHERE ErrorNumber=-346 AND LanguageID=@LangID  
		END 
	ELSE IF (ERROR_MESSAGE() LIKE '-347' )
		BEGIN
			SELECT   @TYPE + ErrorMessage  + @QUERYTEST ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber,		
			ERROR_PROCEDURE()as 
			ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)  
			WHERE ErrorNumber=-347 AND LanguageID=@LangID  
		END 
	ELSE IF (ERROR_MESSAGE() LIKE '-381' )
	BEGIN
		  SELECT ErrorMessage+@docno ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
		  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END
	ELSE IF (ERROR_MESSAGE() LIKE '-402' )
	BEGIN
		  SELECT  @Chequeno +'  '+ErrorMessage ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
		  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END
		 ELSE IF (ERROR_MESSAGE() = '-571' )     
	 BEGIN      
	  SELECT (ErrorMessage +  CONVERT(NVARCHAR, @I-1 ))  AS ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
	  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
	 END  
	ELSE
	BEGIN	  
	  SELECT ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
	  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END  
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END  
  ELSE IF ERROR_NUMBER()=1205  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-350 AND LanguageID=@LangID  
 END   
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-116 AND LanguageID=@LangID    
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
