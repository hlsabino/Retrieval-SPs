USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetPostedDocuments]
	@SaveXML [nvarchar](max),
	@HoldXML [nvarchar](max),
	@PostonConversionDate [bit],
	@LockWhere [nvarchar](max) = '',
	@AP [varchar](10) = '',
	@CompanyGUID [nvarchar](50),
	@sysinfo [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @XML XML,@DocumentType INT,@TypeID INT,@CCID INT,@I INT,@Cnt INT,@DOCNumber NVARCHAR(MAX),@CreditAccountID INT,@ConDate float,@docseq int
	,@AccDocDetails INT ,@status int,@DocID INT,@CostCenterID INT,@IsDiscounted bit,@Columnname nvarchar(100),@dimWiseCurr int
	,@DebitAccountID INT,@oldPDCStatus int,@billwiseVNO nvarchar(200),@BillWiseDocType int,@sql nvarchar(max),@InterOnCDate nvarchar(50)
	DECLARE @DoCPrefix nvarchar(50),@ABBR nvarchar(50),@NewVoucherNO nvarchar(200),@retValue int,@NID INT,@ExchRate float,@WID INT,@wLvl int
	Declare @LocationID INT,@DivisionID INT,@Acc INT,@Series int,@Action int,@PostedDate datetime,@PrefValue nvarchar(50),@tempDocid int,@tempccid int
	declare @vouNO nvarchar(200),@OldvouNO nvarchar(200),@seqno int,@oldstatus int,@Dupl INT,@Dt float,@BillDate FLOAT,@NewBillDate FLOAT,@baseCurr int
	declare @temptype int ,@tempcr INT,@tempdr INT,@tempbid INT,@PrefCheqReturn nvarchar(50),@Adb INT,@penalty float,@Decimals nvarchar(10)
	DECLARE @AuditTrial BIT,@HistoryStatus nvarchar(50),@CCCols nvarchar(max),@CCreplCols nvarchar(max),@NumCols nvarchar(max),@TextCols nvarchar(max),@IsReplace int,@IsHold bit,@LinkedDB INT,@LinkedCr INT
	declare @HoldDim int,@HoldDimID INT,@HoldDateField nvarchar(20),@HoldDate nvarchar(20),@HoldDateRemarksField nvarchar(20),@HoldDateRemarks nvarchar(max)
	Declare @DocCol nvarchar(max),@TablCol nvarchar(max),@table nvarchar(max),@fid int,@dttemp datetime,@docOrder int,@refccid int,@refNodeid int
	Declare @PdcDoc nvarchar(max),@InterDOc nvarchar(max),@ConDoc nvarchar(max),@BounceDoc nvarchar(max),@clearonConvert bit,@refAccid INT,@BRDim nvarchar(max)
	
	declare @ddxml nvarchar(max),@bxml nvarchar(max),@return_value int,@ddID INT,@RefID int,@Prefix nvarchar(200),@AUTOCCID INT,@DetIDS nvarchar(max),@CCStatusID int,@TEmpWid INT   

	declare @preftble table(name nvarchar(200),value nvarchar(max),ccid int)
	insert into @preftble
	SELECT Name,Value,0 FROM ADM_GlobalPreferences WITH(NOLOCK) 
	WHERE name in('EnableCrossDimension','DimensionwiseCurrency','BaseCurrency','OnOpbConvert','OnOpbBounce','ClearonConvert','DecimalsinAmount','Intermediate PDC','IntermediatePDConConversionDate'
	,'PDCBounceResonDim','PDCHoldDimension','PDCHoldDate','PDCHoldRemarks','enableChequeReturnHistory','Dont Change PDC Bank On Convert')
		
	set @dimWiseCurr=0
	select @dimWiseCurr=isnull(value,0) from @preftble 
	where  Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
	
	SELECT @baseCurr=Value FROM @preftble WHERE Name='BaseCurrency'
						
	SELECT @Decimals=Value FROM @preftble WHERE Name='DecimalsinAmount'
	
	if exists(SELECT Value FROM @preftble WHERE Name='ClearonConvert' and Value='true')
		set @clearonConvert=1
	else
		set @clearonConvert=0	

	set @CCCols=''
	select @CCCols =@CCCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData'  and a.name not in('AccDocDetailsID','INVDocDetailsID','DocCCDataID')
	
	set @CCreplCols=''
	select @CCreplCols =@CCreplCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData'  and a.name like 'dcCCNID%' and convert(int,replace(a.name,'dcCCNID',''))<51

	set @NumCols=''
	select @NumCols =@NumCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocNumData'  and a.name not in('AccDocDetailsID','INVDocDetailsID','DocNumDataID')

	set @TextCols=''
	select @TextCols =@TextCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocTextData'  and a.name not in('AccDocDetailsID','INVDocDetailsID','DocTextDataID')

	set @Dt=convert(float,getdate())

	SET @XML=@SaveXML
	select @PrefValue=value from @preftble  where name='Intermediate PDC'
	select @InterOnCDate=value from @preftble  where name='IntermediatePDConConversionDate'
		
	Declare @TBL TABLE(ID INT IDENTITY(1,1),AccDocDetailsID INT,STATUS INT,PostedDate datetime,[Action] int,CreditAccountID INT,DebitAccountID INT,Dupl INT,IsReplace int,IsHold bit,Penalty float,isLock bit,BRDIM nvarchar(max),DocXML XML,WID INT,WLvl int)
	Declare @XMLNode XML,@ACCDetailsID Int
	insert into @TBL
	select X.value('@ID','INT'),X.value('@StatusID','INT') ,X.value('@PostedDate','DATETIME'),X.value('@ACTION','int')
	,X.value('@CreditAccountID','INT'),X.value('@DebitAccountID','INT'),X.value('@Dupl','INT') ,X.value('@IsReplace','int') ,X.value('@IsHold','bit')
	,isnull(X.value('@Penalty','Float'),0),0,X.value('@BRDim','nvarchar(max)'), X.query('AutoPOstXML'),X.value('@WID','INT'),X.value('@WLvl','INT')
	from @XMl.nodes('/XML/Row') as Data(X)
	
	IF @HoldXML!='' OR exists (select ID FROM @TBL where IsHold=1)
	BEGIN
		SELECT @HoldDim=Value FROM @preftble  where Name='PDCHoldDimension'
		set @HoldDim=@HoldDim-50000
		SELECT @HoldDateField=Value FROM @preftble  where Name='PDCHoldDate'
		SELECT @HoldDateRemarksField=Value FROM @preftble  where Name='PDCHoldRemarks'
	END
	
	DECLARE @DocDate float,@DAllowLockData BIT ,@DLockCC INT ,@AllowLockData BIT,@LockCC INT,@LockCCValues nvarchar(max)

	SELECT @AllowLockData=CONVERT(BIT,Value) FROM ADM_GlobalPreferences with(nolock) WHERE Name='Lock Data Between' 
	IF (@AllowLockData=1)  
	BEGIN   		
		SELECT @LockCC=CONVERT(INT,Value) FROM ADM_GlobalPreferences with(nolock) WHERE Name='LockCostCenters' and isnumeric(Value)=1  
	END	
	
	select @I=1,@Cnt=count(*) from @TBL
	--select * from @TBL
	while(@I<=@Cnt)
	Begin 
		set @IsReplace=0
		set @BRDim=''
		select @PostedDate=PostedDate,@status=STATUS,@Action=Action,@Acc=AccDocDetailsID,@penalty=Penalty
		 ,@CreditAccountID=CreditAccountID,@DebitAccountID=DebitAccountID,@Dupl=Dupl,@IsReplace=isnull(IsReplace,0),@IsHold=isnull(IsHold,0)
		 ,@BRDim=BRDim , @XMLNode=DocXML,@ACCDetailsID = AccDocDetailsID,@WID=WID,@WLvl=WLvl
		  from @TBL where ID=@I
		
		set @ConDoc=null
		set @InterDOc=null
		set @BounceDoc=null
		 
		if(@Action=2)
		BEGIN
				select @NID=0,@CostCenterID=CostCenterID,@DocID=DocID  
				from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
				
				select @CCID=ConvertAs from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
				
				select @DocDate=DocDate from ACC_DocDetails with(nolock) 
				where refccid=400 and RefNodeID=@Acc and CostCenterID=@CCID
		
		END
		ELSE
		BEGIN 
			select @NID=0,@DocDate=case when @PostonConversionDate=1 then floor(convert(float,getdate()))
												when @PostedDate is not null then convert(float,@PostedDate)
											 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
											 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
											 else DocDate end,@CostCenterID=CostCenterID,@DocID=DocID  from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
		END
		
		if(dbo.fnCOM_HasAccess(@RoleID,43,193)=0 and (SELECT PrefValue FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='OverrideLock')<>'true')  
		BEGIN  
			IF (@AllowLockData=1)  
			BEGIN   
				IF exists(select LockID from ADM_LockedDates WITH(NOLOCK) where isEnable=1 
				 and @DocDate between FromDate and ToDate and CostCenterID=0)
				BEGIN  
					if(@LockCC is null or @LockCC=0)  
						SET @NID=-125    
					else if(@LockCC>50000)  
					BEGIN  
						SELECT @LockCCValues=CONVERT(INT,Value) FROM ADM_GlobalPreferences with(nolock) WHERE Name='LockCostCenterNodes'  

						set @LockCCValues= rtrim(@LockCCValues)  
						set @LockCCValues=substring(@LockCCValues,0,len(@LockCCValues)- charindex(',',reverse(@LockCCValues))+1)  

						set @sql ='if exists (select a.AccDocDetailsID FROM  [COM_DocCCData] a WITH(NOLOCK)  
						join [ACC_DocDetails] b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID  
						WHERE b.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND b.docid='+convert(nvarchar,@DocID)+' and a.dcccnid'+convert(nvarchar,(@LockCC-50000))+' in('+@LockCCValues+'))  
						SET @NID=-125 '   
						EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output
					END  
				END      
			END  
  
			if(@LockWhere <>'')
			BEGIN
				if(@LockWhere like '<XML%')
				BEGIN
					set @XML=@LockWhere	
					DECLARE @TEMPLockWhere NVARCHAR(MAX)			
					select @TEMPLockWhere=isnull(X.value('@where','nvarchar(max)'),''),@LockCCValues=isnull(X.value('@join','nvarchar(max)'),'')
					from @XML.nodes('/XML') as Data(X)    		         
					set @sql ='if exists (select a.CostCenterID from Acc_DocDetails a WITH(NOLOCK)
						join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
						join ADM_DimensionWiseLockData c  WITH(NOLOCK) on '+convert(nvarchar(max),@DocDate)+' between c.fromdate and c.todate and c.isEnable=1 '+@LockCCValues+'
						where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@TEMPLockWhere+')  
						SET @NID=-125 '  
				END
				ELSE
				BEGIN
					set @sql ='if exists (select a.CostCenterID from Acc_DocDetails a WITH(NOLOCK)
						join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
						join ADM_DimensionWiseLockData c  WITH(NOLOCK) on '+convert(nvarchar(max),@DocDate)+' between c.fromdate and c.todate and c.isEnable=1
						where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND a.docid='+convert(nvarchar,@DocID)+@LockWhere+')  
						SET @NID=-125 ' 
				END	
				print @sql
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output
			END
			
			SELECT @DAllowLockData=CONVERT(BIT,PrefValue) FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='Lock Data Between'  
			IF (@DAllowLockData=1)  
			BEGIN  
				SELECT @DLockCC=CONVERT(INT,PrefValue) FROM COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and  PrefName='LockCostCenters' and isnumeric(PrefValue)=1  

				IF exists(select LockID from ADM_LockedDates WITH(NOLOCK) where isEnable=1 
				 and @DocDate between FromDate and ToDate and CostCenterID=@CostCenterID)  
				BEGIN  
					if(@DLockCC is null or @DLockCC=0)  
						SET @NID=-125  
					else if(@DLockCC>50000)  
					BEGIN  
						SELECT @LockCCValues=CONVERT(INT,PrefValue) FROM COM_DocumentPreferences with(nolock) WHERE CostCenterID=@CostCenterID and  PrefName='LockCostCenterNodes'  

						set @LockCCValues= rtrim(@LockCCValues)  
						set @LockCCValues=substring(@LockCCValues,0,len(@LockCCValues)- charindex(',',reverse(@LockCCValues))+1)  

						set @sql ='if exists (select a.AccDocDetailsID FROM  [COM_DocCCData] a WITH(NOLOCK)  
						join [ACC_DocDetails] b with(nolock) on a.AccDocDetailsID=b.AccDocDetailsID  
						WHERE b.CostCenterID='+convert(nvarchar,@CostCenterID)+' AND b.docid='+convert(nvarchar,@DocID)+' and a.dcccnid'+convert(nvarchar,(@DLockCC-50000))+' in('+@LockCCValues+'))  
						SET @NID=-125 '  
						EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output
					END   
				END         
			END  
		END  
		
		if @NID=-125
		begin
			update @TBL set isLock=1 where ID=@I
			set @I=@I+1;
			continue
		end
		
		if not exists(select name from @preftble where ccid=@CostCenterID and name='AuditTrial')
		BEGIN
			insert into @preftble
			SELECT PrefName,PrefValue,@CostCenterID FROM COM_DocumentPreferences with(nolock)
			WHERE CostCenterID=@CostCenterID and PrefName in('AuditTrial','Defaultprefix','DiscDoc')
		END
		
		
		SET @AuditTrial=0
		SELECT @AuditTrial=CONVERT(BIT,value) FROM @preftble 
		WHERE ccid=@CostCenterID and name='AuditTrial'

		IF (@AuditTrial=1 or @PrefValue='true')  
		BEGIN 
				if(@Action=3)
					set @HistoryStatus='Suspend'
				else if(@Action=1)
					set @HistoryStatus='Convert'
				else if(@Action=2)
					set @HistoryStatus='UnConvert'
				else if(@Action=0)
					set @HistoryStatus='Bounce'
				else if(@Action=6)
					set @HistoryStatus='Hold'
								
				EXEC @retValue = [spDOC_SaveHistory]      
					@DocID =@DocID ,
					@HistoryStatus=@HistoryStatus,
					@Ininv =0,
					@ReviseReason ='',
					@LangID =@LangID,
					@UserName=@UserName,
					@ModDate=@Dt,
					@CCID=0,
					@AP=@AP,
					@sysinfo=@sysinfo
		END
		
		if(@Action=3)
		begin
			 select @CostCenterID=CostCenterID,@DocID=DocID,@temptype=DocumentType,@IsDiscounted=IsDiscounted  
			 from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc

			 exec @retValue=spDOC_SuspendAccDocument
					@CostCenterID =@CostCenterID,
					@DocID =@DocID,
					@DocPrefix ='',    
					@DocNumber ='',
					@Remarks ='',
					@UserID=@UserID ,    
					@UserName =@UserName,
					@RoleID=@RoleID,
					@LangID =  @LangID ,
					@AP=@AP,
					@sysinfo=@sysinfo
			
		
			set @I=@I+1;
			continue
		end
		ELSE if(@Action=6)
		begin
			if(@WLvl is null)
				set @WLvl=1
				
			set @SQL='update ACC_DocDetails 
			 set HoldStatus=1,HoldTillDate='+convert(nvarchar(max),convert(float,@PostedDate))
			 if(@WID>0)
				set @SQL=@SQL+',StatusID=371,WorkFlowStatus=371,WorkFlowLevel='+convert(nvarchar(max),@WLvl)+',WorkflowID='+convert(nvarchar(max),@WID)
			 set @SQL=@SQL+' 
			 where AccDocDetailsID='+convert(nvarchar(max),@Acc)
			exec(@SQL)
			set @I=@I+1;
			continue
		end
		
		
		if(@IsHold=1)
		begin
			set @SQL='update com_docccdata set dcCCNID'+convert(nvarchar,@HoldDim)+'=1 where AccDocDetailsID='+convert(nvarchar,@Acc)
			if(@HoldDateField!='' or @HoldDateRemarksField!='')
			begin
				set @SQL=@SQL+'
				update com_doctextdata set '
				if(@HoldDateField!='')
					set @SQL=@SQL+'dcAlpha'+convert(nvarchar,@HoldDateField)+'=null'				
				if(@HoldDateRemarksField!='')
				begin
					if(@HoldDateField!='')
						set @SQL=@SQL+','
					set @SQL=@SQL+'dcAlpha'+convert(nvarchar,@HoldDateRemarksField)+'=null'
				end
				set @SQL=@SQL+' where AccDocDetailsID='+convert(nvarchar,@Acc)
			end
			exec(@SQL)
		end
		
		set @Adb=@DebitAccountID 		
			
		select @docOrder=DocOrder,@CostCenterID=CostCenterID,@PdcDoc=VoucherNo,@temptype=DocumentType,@IsDiscounted=IsDiscounted  
		,@refccid=refccid,@refNodeid =refNodeid 
		from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
		
		if(@docOrder=6 and @refccid=400 and exists(select value from @preftble  where name='EnableCrossDimension' and value='true'))
		BEGIn
			
			select @refAccid=AccDocDetailsID
			from ACC_DocDetails with(nolock) 
			where refccid=@refccid and refNodeid =@refNodeid  and AccDocDetailsID<>@Acc and linkedAccDocDetailsID is null
			and DocOrder=5
			
			exec @retValue = [spDoc_SetCrossDimDoc]
			@Action =@Action,
			@Acc =@refAccid,
			@PostedDate =@PostedDate,
			@PostonConversionDate=@PostonConversionDate,
			@CompanyGUID=@CompanyGUID ,    
			@UserName=@UserName ,    
			@UserID=@UserID ,
			@RoleID=@RoleID ,
			@LangID=@LangID ,
			@AP=@AP,
			@sysinfo=@sysinfo
			
			
			if(@retValue=-999)
				return -999
		END
		
		
		if(@IsDiscounted=1 and @temptype=19 and @Action=1)
		begin			
				select @DebitAccountID=pdcDiscountAccount from ACC_Accounts WITH(NOLOCK)
				where accountid=@DebitAccountID 			
		end
		 
		if(@Action=1)
		begin
			if(select case when documenttype=16 then OpPdcStatus else StatusID end from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc)=@status
			begin
				set @I=@I+1;
				continue
			end
			if(@temptype=16)
			BEGIN
				set @CCID=0
				select @CCID=isnull(value,0) from @preftble 
				where  Name='OnOpbConvert' and ISNUMERIC(value)=1 and CONVERT(INT,value)>40000
				set @Series=0
			END	
			else
				select @CCID=ConvertAs,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
			select @TypeID=DocumentTypeID,@DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=@CCID						
			set @status=369
			
		end
		else if(@Action=0)
		begin 
			if(@temptype=16)
			BEGIN
				select @oldPDCStatus=OpPdcStatus from ACC_DocDetails with(nolock)
				where AccDocDetailsID=@Acc
				
				if(@oldPDCStatus=369)
					UPDATE A 
					SET A.StatusID = 429 
					FROM ACC_DocDetails A WITH(NOLOCK)
					where A.RefCCID=400 and A.RefNodeID=@Acc 
			END	
			ELSE
			begin
				select @oldPDCStatus=StatusID from ACC_DocDetails with(nolock)
				where AccDocDetailsID=@Acc
				
				if(@oldPDCStatus=369)
				begin
					if (select count(*) from sys.columns a
					join sys.tables b on a.object_id=b.object_id
					where b.name='COM_DocTextData'  and a.name in('dcAlpha48','dcAlpha49','dcAlpha47','dcAlpha50'))=4
					BEGIN		
						set @sql ='select @ConDoc=dcAlpha48,@InterDOc=dcAlpha49 from COM_DocTextData with(nolock)
						where AccDocDetailsID='+convert(nvarchar(max),@Acc)
						EXEC sp_executesql @sql,N'@ConDoc nvarchar(max) OUTPUT,@InterDOc nvarchar(max) OUTPUT',@ConDoc output,@InterDOc output
					END
					
					select @vouNO=voucherNo from ACC_DocDetails with(nolock)
					where RefCCID=400 and RefNodeID=@Acc
					select @OldvouNO=voucherNo,@BillDate=DocDate,@seqno=DocSeqNo,@oldstatus=StatusID,@DocumentType=DocumentType 
					from ACC_DocDetails with(nolock)
					where AccDocDetailsID=@Acc
				 
					update B
					set B.docno=@OldvouNO,B.DocDate=@BillDate,B.DocType=@DocumentType,B.StatusID=429,B.ConvertedDate=NUll
					FROM com_billWise B WITH(NOLOCK)
					where B.docno=@vouNO and B.DocSeqNo=@seqno
					
					update B
					set B.Refdocno=@OldvouNO,B.refDocDate=@BillDate,B.RefStatusID=429
					FROM com_billWise B WITH(NOLOCK)
					where B.Refdocno=@vouNO and B.RefDocSeqNo=@seqno
					
					UPDATE A 
					SET A.StatusID = 429 
					FROM ACC_DocDetails A WITH(NOLOCK)
					where A.RefCCID=400 and A.RefNodeID=@Acc 
					
				end	
			END
			 select @PrefCheqReturn=value from @preftble 
			 where name='enableChequeReturnHistory'
			 if( @PrefCheqReturn is not null and @PrefCheqReturn='true')
			 begin
			 
				set @sql='insert into COM_ChequeReturn(DocNo,DocSeqNo,AccountID,AdjAmount,AdjCurrID,AdjExchRT,AmountFC,
				DocDate,DocDueDate,DocType,IsNewReference,Narration,IsDocPDC,CompanyGUID,GUID,CreatedBy,'+@CCreplCols+'CreatedDate)
				select VoucherNo,DocSeqNo,case when documenttype=16 then DebitAccount when (IsNegative is null or IsNegative=0) and DocumentType in(14,15,23) THEN DebitAccount 
											   when (IsNegative is null or IsNegative=0) and DocumentType in(18,19,22) THEN CreditAccount 
											   when IsNegative is not null and IsNegative=1 and DocumentType in(14,15,23) THEN CreditAccount
											   when IsNegative is not null and IsNegative=1 and DocumentType in(18,19,22) THEN  DebitAccount end 
				, case when documenttype=16 then Amount when (IsNegative is null or IsNegative=0) and DocumentType in(14,15,23) THEN Amount 
											   when (IsNegative is null or IsNegative=0) and DocumentType in(18,19,22) THEN (Amount*-1) 
											   when IsNegative is not null and IsNegative=1 and DocumentType in(14,15,23) THEN (Amount*-1)
											   when IsNegative is not null and IsNegative=1 and DocumentType in(18,19,22) THEN  Amount end,CurrencyID,ExchangeRate,AmountFC,DocDate,DueDate,DocumentType,1,'''',0,
											   
											   '''+convert(nvarchar(max),@CompanyGUID)+''',newid(),'''+convert(nvarchar(max),@UserName)+''',
											   '+@CCreplCols+'
											   convert(float,getdate())
				from ACC_DocDetails a WITH(nolock)
				join dbo.COM_DocCCData b WITH(nolock) on a.AccDocDetailsID=b.AccDocDetailsID
				where a.AccDocDetailsID = '+convert(nvarchar(max),@Acc )
				exec(@sql)
			 end
			 
			if(@temptype=16)
			BEGIN
				set @CCID=0
				select @CCID=isnull(value,0) from @preftble 
				where  Name='OnOpbBounce' and ISNUMERIC(value)=1 and CONVERT(INT,value)>40000				
				set @Series=0
			END	
			else	
				select @CCID=Bounce,@Series=BounceSeries from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
			select @TypeID=DocumentTypeID,@DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES WITH(NOLOCK) where CostCenterId=@CCID						
			set @status=429
		end
		else if(@Action=2)
		begin
			set @status=370
			select @CostCenterID=CostCenterID,@OldvouNO=voucherNo,@BillDate=DocDate,@seqno=DocSeqNo,@oldstatus=StatusID,@DocumentType=DocumentType,@IsDiscounted=IsDiscounted 
			from ACC_DocDetails with(nolock)
			where AccDocDetailsID=@Acc
						
			if(@IsDiscounted=1)
				set  @status=439
				
			select @CCID=ConvertAs,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
			if(@PrefValue='true')
			begin
				select @CCID=IntermediateConvertion,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
			end
				 
			select @vouNO=voucherNo,@seqno=DocSeqNo from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc and CostCenterID=@CCID
			
		
			if(@oldstatus=429)
			begin
				delete from COM_ChequeReturn
				where docno=@OldvouNO and DocSeqNo=@seqno
				
				delete from COM_ChequeReturn
				where Refdocno=@OldvouNO and RefDocSeqNo=@seqno
				
				update B
				set B.docno=@OldvouNO,B.DocDate=@BillDate,B.StatusID=@status,B.AdjAmount=AdjAmount,B.AmountFC=AmountFC,B.DocType=@DocumentType
				FROM com_billWise B WITH(NOLOCK)
				where B.docno=@vouNO and B.DocSeqNo=@seqno
				
				select @CCID=Bounce,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
				select @DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=@CCID						
				
				select @OldvouNO=voucherNo,@seqno=DocSeqNo from ACC_DocDetails with(nolock)
				where refccid=400 and refnodeid=@Acc and CostCenterID=@CCID
			
				delete B from com_billWise B WITH(NOLOCK)
				where B.docno=@OldvouNO and B.DocSeqNo=@seqno and B.DocType=@DocumentType
				
				set @ccid=0
				set @docid=0
				select @ccid=CostCenterID,@docid=DocID from INV_DocDetails with(nolock)
				where RefCCID=400 and RefNodeID=@Acc
				if(@ccid>0 and @docid>0)
				BEGIN
					 EXEC @retValue = [dbo].[spDOC_DeleteInvDocument]  
						 @CostCenterID = @ccid,  
						 @DocPrefix = '',  
						 @DocNumber = '',
						 @DocID=@docid,
						 @UserID = @UserID,  
						 @UserName = @UserName,  
						 @LangID = @LangID,
						 @RoleID=@RoleID
				END		 
			end
			else if(@oldstatus=369)
			begin
				update B
				set B.docno=@OldvouNO,B.DocDate=@BillDate,B.DocType=@DocumentType,B.StatusID=@status,B.ConvertedDate=NUll
				FROM com_billWise B WITH(NOLOCK)
				where B.docno=@vouNO and B.DocSeqNo=@seqno
				
				if exists(select Refdocno from com_billWise	with(nolock) where Refdocno=@vouNO and RefDocSeqNo=@seqno)
				BEGIN	
					update B
					set B.Refdocno=NULL,B.RefDocSeqNo=NULL,B.IsNewReference=1,B.RefStatusID=null
					FROM com_billWise B WITH(NOLOCK)
					where B.Refdocno=@vouNO and B.RefDocSeqNo=@seqno
				END
			end
			
			set @CCID=0
			SELECT @CCID=value FROM @preftble  
			WHERE ccid=@CostCenterID and name='DiscDoc' and value<>'' and isnumeric(value)=1

			delete D from [COM_DocCCData] D WITH(NOLOCK)
			where AccDocDetailsID is not null and AccDocDetailsID in(select AccDocDetailsID from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc and CostCenterID<>@CCID)
			
			delete D from [COM_DocNumData] D WITH(NOLOCK)
			where AccDocDetailsID is not null and AccDocDetailsID in(select AccDocDetailsID from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc and CostCenterID<>@CCID)
			
			delete D from [COM_DocTextData] D WITH(NOLOCK)
			where AccDocDetailsID is not null and AccDocDetailsID in (select AccDocDetailsID from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc and CostCenterID<>@CCID)
			
			delete D from [COM_DocID] D WITH(NOLOCK)
			where ID in (select docid from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc and CostCenterID<>@CCID) 

			delete D from ACC_DocDetails D WITH(NOLOCK)
			where RefCCID=400 and RefNodeID=@Acc and CostCenterID<>@CCID
			
			UPDATE A 
			SET A.ConvertedDate=NUll
			FROM ACC_DocDetails A WITH(NOLOCK)
			where A.AccDocDetailsID=@Acc or A.LinkedAccDocDetailsID=@Acc
			
		end
		--select * from adm_globalpreferences
		if(@Action=1)
		begin
			set @tempbid=0
			declare @BankAccountID INT,@tempAccID INT,@ChangeCheck bit
		    select @tempcr=case when IsNegative=1 THEN DebitAccount else CreditAccount end,@tempdr=case when IsNegative=1 THEN CreditAccount else DebitAccount end,@temptype=DocumentType,@tempbid=BankAccountID from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
			select @ChangeCheck=Value from @preftble  where Name='Dont Change PDC Bank On Convert'
			if(@temptype=16)
			BEGIN
				set @CreditAccountID =@tempdr
				set @DebitAccountID  =@tempbid
			END
			
			IF(@ChangeCheck=0)
			BEGIN
				if(@PrefValue='True' and ((@temptype=19 and @Adb<>@tempbid) or (@temptype=14 and @CreditAccountID<>@tempbid) ))
				begin
				
					if(@temptype=19)
					begin
					
					if exists(select accounttypeid from ACC_Accounts with(nolock) where AccountID=@Adb and accounttypeid in(2,3))
					begin
						set @BankAccountID=@Adb
						select @tempAccID=PDCReceivableAccount from ACC_Accounts with(nolock) where AccountID=@Adb
						 IF(@tempAccID is null or @tempAccID <=1)
							RAISERROR('-365',16,1)									
					end
							UPDATE A 
							SET A.DebitAccount = @tempAccID ,A.BankAccountID=@BankAccountID
							FROM ACC_DocDetails A WITH(NOLOCK)
							where A.AccDocDetailsID=@Acc 
							set @tempdr=@tempAccID
					end
					else 
					begin
						if exists(select accounttypeid from ACC_Accounts with(nolock) where AccountID=@CreditAccountID and accounttypeid in(2,3))
						begin
							set @BankAccountID=@CreditAccountID
							select @tempAccID=PDCPayableAccount from ACC_Accounts with(nolock) where AccountID=@CreditAccountID
							 IF(@tempAccID is null or @tempAccID <=1)
								RAISERROR('-366',16,1)				
						end
							UPDATE A 
							SET A.CreditAccount = @tempAccID ,A.BankAccountID=@BankAccountID
							FROM ACC_DocDetails A WITH(NOLOCK)
							where A.AccDocDetailsID=@Acc 
							set @tempcr=@tempAccID
					end
				end
				else if(@PrefValue<>'True')
				begin
					if(@temptype=19 and @tempdr<>@DebitAccountID )
					begin
							UPDATE A 
							SET A.DebitAccount = @Adb 
							FROM ACC_DocDetails A WITH(NOLOCK)
							where A.AccDocDetailsID=@Acc 
					end
					else if(@temptype=14 and @tempcr<>@CreditAccountID)
					begin
							UPDATE A 
							SET A.CreditAccount = @CreditAccountID 
							FROM ACC_DocDetails A WITH(NOLOCK)
							where A.AccDocDetailsID=@Acc 
					end
				end
			END
			if(@PrefValue='True')
			begin
				if(@temptype=19)
				begin
					set @CreditAccountID=@tempdr 
				end
				else if(@temptype=14)
				begin
					set @DebitAccountID=@tempcr
				end		
			end	
		end
		ELSE if(@temptype=16 and @Action=0)
		BEGIN			
		    select @tempcr=case when IsNegative=1 THEN DebitAccount else CreditAccount end,@tempdr=case when IsNegative=1 THEN CreditAccount else DebitAccount end,@temptype=DocumentType,@tempbid=BankAccountID 
		    ,@tempdr=Description
		    from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
			
			set @CreditAccountID =@tempbid
			set @DebitAccountID  =@tempdr
			 
		END
		--select * from COM_CostCenterCodeDef
		--UPDATING PRESENT DOC status
		if(@temptype=16)
			UPDATE A 
			SET A.OpPdcStatus = @status 
			FROM ACC_DocDetails A WITH(NOLOCK)
			where A.AccDocDetailsID=@Acc or A.LinkedAccDocDetailsID=@Acc
		ELSE	
			UPDATE A 
			SET A.StatusID = @status 
			FROM ACC_DocDetails A WITH(NOLOCK)
			where A.AccDocDetailsID=@Acc or A.LinkedAccDocDetailsID=@Acc
		
		if(@Action=1 or @Action=0)
		begin
			--Inserting New DoC
			if(@Dupl is not null and @Dupl>0)
			BEGIN
				SELECT @DocID=DocID,@DoCPrefix=DocPrefix ,@DOCNumber=DocNumber,@NewVoucherNO=[VoucherNo]
				FROM ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeID=@Dupl and [CostCenterID]=@CCID
			END
			ELSE
			BEGIN
	    		--SELECT @DocID=ISNULL(MAX(DocID),0)+1 FROM ACC_DocDetails 
				
 				if(@DoCPrefix is null)
				begin 
					set	@DoCPrefix=''
				end
				
				if(@Series=2)
				begin
					select @DOCNumber=DocNumber,@DoCPrefix=DocPrefix,@docseq=DocseqNo from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc
					
					if exists(SELECT value FROM @preftble 
					WHERE ccid=@CostCenterID and name='Defaultprefix' and value='true')
					BEGIN
						if not exists(select CCID from COM_DocPrefix WITH(NOLOCK)
						where DocumentTypeID=@TypeID and IsDefault=1)
						and (select count(SeriesNo) from  (select SeriesNo from COM_DocPrefix WITH(NOLOCK)
						where DocumentTypeID=@TypeID
						group by SeriesNo) as t)>1
						BEGIN
							RAISERROR('-564',16,1)
						END

						set @DoCPrefix=''
						EXEC [sp_GetDocPrefix] '',@dttemp,@CCID,@DoCPrefix output,@Acc
						
					END
					
					
					
					if(@DoCPrefix='')
					begin
						set @DoCPrefix=convert(nvarchar(50), @DOCNumber)+'/'
					end
					else
					begin
						set @DoCPrefix=@DoCPrefix+convert(nvarchar(50), @DOCNumber)+'/'
					end	
					
					set @DOCNumber=@docseq
					
					set @NewVoucherNO=@ABBR+'-'+@DoCPrefix+convert(nvarchar(50), @DOCNumber)

					if exists(select docid from ACC_DocDetails with(nolock) where DocNumber=convert(nvarchar(50),@DOCNumber) and DocPrefix=@DoCPrefix and [CostCenterID]=@CCID)
					begin
						RAISERROR('-373',16,1)
					end
				end
				else if(@Series=0)
				begin	
					select @DoCPrefix=DocPrefix,@dttemp =case when @PostonConversionDate=1 then floor(convert(float,getdate()))
											when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end 
					from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc          

					if exists(SELECT value FROM @preftble 
					WHERE ccid=@CostCenterID and name='Defaultprefix' and value='true')
					BEGIN
						if not exists(select CCID from COM_DocPrefix WITH(NOLOCK)
						where DocumentTypeID=@TypeID and IsDefault=1)
						and (select count(SeriesNo) from  (select SeriesNo from COM_DocPrefix WITH(NOLOCK)
						where DocumentTypeID=@TypeID
						group by SeriesNo) as t)>1
						BEGIN
							RAISERROR('-564',16,1)
						END

						set @DoCPrefix=''
						EXEC [sp_GetDocPrefix] '',@dttemp,@CCID,@DoCPrefix output,@Acc
						
						
					END
		
					 if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=@CCID AND CodePrefix=@DocPrefix)    
					 begin 
						 set @DOCNumber=1
						 select @DOCNumber=isnull(prefvalue,1) from com_documentpreferences WITH(NOLOCK)
						 WHERE CostCenteriD=@CCID and prefname='StartNoForNewPrefix'
						 and prefvalue is not null and prefvalue<>'' and prefvalue<>'0'
						 
						 select  @LocationID=dcCCNID2,@DivisionID=dcCCNID1 from COM_DocCCData with(nolock) where AccDocDetailsID=@Acc
						 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
						 VALUES(@CCID,@CCID,@DocPrefix,@DOCNumber,1,@DOCNumber,len(@DOCNumber),Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    
					end   
					else
					begin		 
						select  @DOCNumber=CurrentCodeNumber+1,@fid=CodeNumberLength from Com_CostCenterCodeDef with(nolock) 
						where CodePrefix=@DoCPrefix  and CostCenterID=@CCID
						
						while(len(@DOCNumber)<@fid)    
						begin    
							SET @DocNumber='0'+@DOCNumber
						end  
						
						 UPDATE T SET T.CurrentCodeNumber=CurrentCodeNumber+1 
						 FROM Com_CostCenterCodeDef T WITH(NOLOCK)
						 where T.CodePrefix=@DoCPrefix  and T.CostCenterID=@CCID
					end
					if(@DoCPrefix='')
					begin
						set @NewVoucherNO=@ABBR+'-'+convert(nvarchar(50), @DOCNumber)
					end
					else
					begin
						set @NewVoucherNO=@ABBR+'-'+@DoCPrefix+convert(nvarchar(50), @DOCNumber)
					end
				end
				else
				begin
					select @DOCNumber=DocNumber,@DoCPrefix=DocPrefix from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc
				 
					if(@DoCPrefix='')
					begin
							set @NewVoucherNO=@ABBR+'-'+convert(nvarchar(50), @DOCNumber)
					end
					else
					begin
							set @NewVoucherNO=@ABBR+'-'+@DoCPrefix+convert(nvarchar(50), @DOCNumber)
					end			
						
					if exists(select docid from ACC_DocDetails with(nolock) where DocNumber=convert(nvarchar(50),@DOCNumber) and DocPrefix=@DoCPrefix and [CostCenterID]=@CCID)
					begin
						RAISERROR('-373',16,1)
					end
				end
				
				
				--To Get Auto generate DocID
				INSERT INTO COM_DocID(DocNo,[CompanyGUID],[GUID],SysInfo)
				VALUES(@NewVoucherNO,@CompanyGUID,Newid(),@sysinfo)
				SET @DocID=@@IDENTITY
				
				if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=@CCID AND CodePrefix=@DocPrefix)    
				begin 
					 select  @LocationID=dcCCNID2,@DivisionID=dcCCNID1 from COM_DocCCData with(nolock) where AccDocDetailsID=@Acc
					 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
					 VALUES(@CCID,@CCID,@DocPrefix,1,1,1,1,Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    				 
				end   	
				
			END   		
			
			
			
			if(@CCID=0)
			BEGIN
				RAISERROR('-394',16,1)
			END
			
			if not (@Action=1 and @PrefValue='True' and (@tempbid is null or @tempbid=0))
			BEGIN
				select @tempDocid=DocID,@tempccid=Costcenterid from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc
				if not exists(select * from COM_Files WITH(NOLOCK) where  FeatureID=@CCID  and FeaturePK=@DocID)			
				BEGIN
					insert into COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,FeatureID,FeaturePK,CompanyGUID
					,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,FileDescription,CostCenterID,AllowInPrint,IsDefaultImage
					,RowSeqNo,ColName,LocationID,DivisionID,ValidTill,RefNo,HasThumb,RefNum,Remarks,DocNo,Type,IssueDate,status,IsSign)
					select FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,@CCID,@DocID,CompanyGUID
					,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,FileDescription,@CCID,AllowInPrint,IsDefaultImage
					,RowSeqNo,ColName,LocationID,DivisionID,ValidTill,RefNo,HasThumb,RefNum,Remarks,DocNo,Type,IssueDate,status,IsSign
					from COM_Files WITH(NOLOCK)
					where FeatureID=@tempccid  and FeaturePK=@tempDocid
				END	 

			set @billwiseVNO=@NewVoucherNO
			set @BillWiseDocType=@DocumentType
			
			INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]    								     
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,BRS_Status,ClearanceDate,BankAccountID,AP)
								 
								 Select @DocID  
										,@CCID 										  
										,@DocumentType   
										,[VersionNo]    
										,@NewVoucherNO
										,@ABBR    
										,@DoCPrefix    
										,@DOCNumber  
										,case when @PostonConversionDate=1 then floor(convert(float,getdate()))
											when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end    
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,[LinkedAccDocDetailsID]
										,[CommonNarration]    
										,LineNarration    
										, case when IsNegative=1 THEN @CreditAccountID ELSE @DebitAccountID END										
									    , case when IsNegative=1 THEN @DebitAccountID ELSE @CreditAccountID END
										,[Amount]    
										,IsNegative    
										,[DocSeqNo]    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC]   										
										,@UserName    
										,@Dt,@Dt,400,@Acc
										,case when @clearonConvert=1 then 1 else 0 end ,case when @clearonConvert=1 then case when @PostonConversionDate=1 then floor(convert(float,getdate()))
											when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end else 0 end
										 ,case when @Action!=0 and DocumentType=19 then CreditAccount 
										 when @Action!=0 then DebitAccount
										 else null END,@AP
										 from ACC_DocDetails with(nolock) where  AccDocDetailsID =@Acc

			set @AccDocDetails=@@IDENTITY
			
			if(@Action=1)
				set @ConDoc=@NewVoucherNO
			else if(@Action=0)
				set @BounceDoc=@NewVoucherNO
				
			if(@dimWiseCurr>50000)
			BEGIN
				set @sql='update ACC_DocDetails 
				set AmountBC=t.AmountBC,ExhgRtBC=t.ExhgRtBC
				from (select AmountBC,ExhgRtBC from ACC_DocDetails a WITH(NOLOCK)
				where a.AccDocDetailsID='+CONVERT(nvarchar,@Acc)+' )as t
				where AccDocDetailsID='+CONVERT(nvarchar,@AccDocDetails)
				exec(@sql)
			END
			
			if exists(select [DocID] from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc)
			BEGIN
				if(@Action=0)
						select @LinkedDB=CreditAccount,@LinkedCr=DebitAccount from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc
				else if(@Action=1)
				BEGIN
						select @LinkedDB=DebitAccount,@LinkedCr=CreditAccount from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc						
						if(@PrefValue='True')
						BEGIN
							select @tempdr=DebitAccount,@tempcr=CreditAccount from ACC_DocDetails WITH(NOLOCK) where AccDocDetailsID=@Acc
							if(@temptype=19 and @LinkedCr=@tempcr)
							begin
								set @LinkedCr=@CreditAccountID
							end
							else if(@temptype=14 and @LinkedDB=@tempdr)
							begin
								set @LinkedDB=@DebitAccountID
							end	
						END	
				END
			
			
				if(@dimWiseCurr>50000)
				BEGIN
					 select @NewBillDate=DocDate from ACC_DocDetails with(nolock)
						where AccDocDetailsID=@AccDocDetails
						
					set @sql='INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]      
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,AmountBC,ExhgRtBC,AP)
								 Select '+CONVERT(nvarchar,@DocID)+'
										,'+CONVERT(nvarchar,@CCID)+'  
										,'+CONVERT(nvarchar,@DocumentType)+'   
										,[VersionNo]    
										,'''+CONVERT(nvarchar,@NewVoucherNO)+'''
										,'''+CONVERT(nvarchar,@ABBR)+'''    
										,'''+CONVERT(nvarchar,@DoCPrefix)+'''    
										,'''+CONVERT(nvarchar,@DOCNumber)+'''  
										, '+CONVERT(nvarchar,@NewBillDate)+'   
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,'+CONVERT(nvarchar,@AccDocDetails)+'
										,[CommonNarration]    
										,LineNarration    
										,'+CONVERT(nvarchar,@LinkedDB)+' 
										,'+CONVERT(nvarchar,@LinkedCr)+'   
										,[Amount]    
										,IsNegative    
										,[DocSeqNo]    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC]      
										,'''+@UserName+'''    
										,'+CONVERT(nvarchar,@Dt)+','+CONVERT(nvarchar,@Dt)+',400,'+CONVERT(nvarchar,@Acc)+',AmountBC,ExhgRtBC
										,'''+@AP+'''
										 from ACC_DocDetails with(nolock) where  LinkedAccDocDetailsID ='+CONVERT(nvarchar,@Acc)
										
					
					exec(@sql)						
				END
				ELSE
				BEGIN
				INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]    								   
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,AP)
								 Select @DocID  
										,@CCID 										
										,@DocumentType   
										,[VersionNo]    
										,@NewVoucherNO
										,@ABBR    
										,@DoCPrefix    
										,@DOCNumber  
										,case when @PostonConversionDate=1 then floor(convert(float,getdate()))
											when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end    
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,@AccDocDetails
										,[CommonNarration]    
										,LineNarration    
										,@LinkedDB    
										,@LinkedCr    
										,[Amount]    
										,IsNegative    
										,[DocSeqNo]    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC]
										,@UserName    
										,@Dt,@Dt,400,@Acc,@AP from ACC_DocDetails with(nolock) where  LinkedAccDocDetailsID =@Acc
						END		
										  
				set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+'a.AccDocDetailsID
				FROM ACC_DocDetails a  WITH(NOLOCK) ,  [COM_DocCCData] b    WITH(NOLOCK) 
				WHERE  LinkedAccDocDetailsID='+convert(nvarchar,@AccDocDetails)+' and b.AccDocDetailsID='+convert(nvarchar,@Acc)		
				exec(@sql)
			END

			set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocCCData]  WITH(NOLOCK)
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)

			set @sql=' INSERT INTO [COM_DocNumData]('+@NumCols+'[AccDocDetailsID]) select '+@NumCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocNumData]  WITH(NOLOCK)
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)
			
			if not (@Dupl is not null and @Dupl>0) and (@Action=0 and @IsReplace=0)
			BEGIN
				EXEC spCOM_SetNotifEvent 429,@CCID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
			END	
			
		END
			if(@penalty>0 and @Action=0)
			BEGIN
				set @Columnname='' 
				select @Columnname=BouncePenaltyFld from ADM_DocumentTypes WITH(NOLOCK)  where CostCenterID=@CostCenterID
				if(@Columnname is null or @Columnname ='')
					RAISERROR('-394',16,1)
				
				set @sql=' update [COM_DocNumData] set '+@Columnname+'='+CONVERT(nvarchar,@penalty)+'
					,'+replace(@Columnname,'dc','dcCalc')+'='+CONVERT(nvarchar,@penalty)+'
					 WHERE  AccDocDetailsID='+convert(nvarchar,@AccDocDetails)		
					exec(@sql)	
					
				set @LinkedDB=0
				set @LinkedCr=0
				
				  SELECT @LinkedDB=DebitAccount,@LinkedCr=DD.CreditAccount				 
				  FROM ADM_CostCenterDef C WITH(NOLOCK)   	  
				  JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID     
				  WHERE C.CostCenterID =@CCID and c.SysColumnName=@Columnname
				
				
				if(@LinkedDB=0 and exists(	SELECT DD.DrRefID FROM ADM_CostCenterDef C WITH(NOLOCK)   	  
				JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID     
				WHERE C.CostCenterID =@CCID and c.SysColumnName=@Columnname and DD.DrRefColID is not null and DD.DrRefColID>0 and DD.DrRefID is not null and DD.DrRefID>0))
				BEGIN
					SELECT @TablCol=DRef.SysColumnName,@fid=DRef.CostCenterID,@table=Drf.TableName,@DocCol=DR.SysColumnName
					FROM ADM_CostCenterDef C WITH(NOLOCK)   	  
					JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID     
					JOIN ADM_CostCenterDef DR WITH(NOLOCK) ON DR.CostCenterColID = DD.DrRefID
					JOIN ADM_CostCenterDef DRef WITH(NOLOCK) ON DRef.CostCenterColID = DD.DrRefColID
					join ADM_Features Drf WITH(NOLOCK) ON Drf.FeatureID = DRef.CostCenterID
					WHERE C.CostCenterID =@CCID and c.SysColumnName=@Columnname
					
					if(@DocCol like 'dcccnid%')
						set @sql='select @NID='+@DocCol+' from COM_DocCCData  WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@AccDocDetails)
					else
						set @sql='select @NID='+@DocCol+' from ACC_DocDetails  WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@AccDocDetails)	
						print @sql
					EXEC sp_executesql @sql, N'@NID float OUTPUT', @NID OUTPUT 
					
					if(@fid=2 and @TablCol like '%alpha%')
						set @table='ACC_AccountsExtended'
					
					set @LinkedDB=0
					if(@fid=2)
						set @sql='select @LinkedDB='+@TablCol+' from '+@table+'  WITH(NOLOCK) where AccountID='+convert(nvarchar,@NID)	
					else
						set @sql='select @LinkedDB='+@TablCol+' from '+@table+'  WITH(NOLOCK) where NodeID='+convert(nvarchar,@NID)	
							print @sql
					EXEC sp_executesql @sql, N'@LinkedDB float OUTPUT', @LinkedDB OUTPUT 
				
					if(@LinkedDB is null or @LinkedDB=0)
						 RAISERROR('-546',16,1)
				END	
				
				if(@LinkedCr=0 and exists(	SELECT DD.CrRefID FROM ADM_CostCenterDef C WITH(NOLOCK)   	  
				JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID     
				WHERE C.CostCenterID =@CCID and c.SysColumnName=@Columnname and DD.CrRefColID is not null and DD.CrRefColID>0 and DD.CrRefID is not null and DD.CrRefID>0))
				BEGIN
					SELECT @TablCol=DRef.SysColumnName,@fid=DRef.CostCenterID,@table=Drf.TableName,@DocCol=DR.SysColumnName
					FROM ADM_CostCenterDef C WITH(NOLOCK)   	  
					JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID     
					JOIN ADM_CostCenterDef DR WITH(NOLOCK) ON DR.CostCenterColID = DD.CrRefID
					JOIN ADM_CostCenterDef DRef WITH(NOLOCK) ON DRef.CostCenterColID = DD.CrRefColID
					join ADM_Features Drf WITH(NOLOCK) ON Drf.FeatureID = DRef.CostCenterID
					WHERE C.CostCenterID =@CCID and c.SysColumnName=@Columnname
					
					if(@DocCol like 'dcccnid%')
						set @sql='select @NID='+@DocCol+' from COM_DocCCData  WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@AccDocDetails)
					else
						set @sql='select @NID='+@DocCol+' from ACC_DocDetails  WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@AccDocDetails)	
						print @sql
					EXEC sp_executesql @sql, N'@NID float OUTPUT', @NID OUTPUT 
					
					if(@fid=2 and @TablCol like '%alpha%')
						set @table='ACC_AccountsExtended'
					
					set @LinkedCr=0
					if(@fid=2)
						set @sql='select @LinkedCr='+@TablCol+' from '+@table+'  WITH(NOLOCK) where AccountID='+convert(nvarchar,@NID)	
					else
						set @sql='select @LinkedCr='+@TablCol+' from '+@table+'  WITH(NOLOCK) where NodeID='+convert(nvarchar,@NID)	
						print @sql
					EXEC sp_executesql @sql, N'@LinkedCr float OUTPUT', @LinkedCr OUTPUT 
					
					if(@LinkedCr is null or @LinkedCr=0)
						 RAISERROR('-546',16,1)
				END	
				
				INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]    								    
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    								
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,AP)
								 Select @DocID  
										,@CCID 										
										,@DocumentType   
										,[VersionNo]    
										,@NewVoucherNO
										,@ABBR    
										,@DoCPrefix    
										,@DOCNumber  
										,DocDate
										,[DueDate]    
										,[StatusID]    
										,[BillNo]    
										,BillDate    
										,@AccDocDetails
										,[CommonNarration]    
										,LineNarration    
										,case when @LinkedDB is not null and @LinkedDB>0 then @LinkedDB else DebitAccount end
										,case when @LinkedCr is not null and @LinkedCr>0 then @LinkedCr else CreditAccount end    										
										,@penalty    
										,0    
										,[DocSeqNo]    
										,1    
										,1 
										,@penalty   										   
										,@UserName    
										,@Dt,@Dt,400,@Acc ,@AP
										from ACC_DocDetails with(nolock) where  AccDocDetailsID =@AccDocDetails										
										
										set @HoldDimID=@@IDENTITY
										
	  				set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+convert(nvarchar,@HoldDimID)+'
					FROM [COM_DocCCData]  WITH(NOLOCK)
					WHERE  AccDocDetailsID='+convert(nvarchar,@AccDocDetails)		
					exec(@sql)  
					   				  
					set @LinkedCr=0				  
					if(@temptype=19)
					begin						
						select @LinkedCr=DebitAccount from ACC_DocDetails a WITH(NOLOCK) 
						join ACC_Accounts b WITH(NOLOCK) on a.DebitAccount=b.AccountID
						where b.IsBillwise=1 and a.AccDocDetailsID=@HoldDimID						
					end
					else if(@temptype=14)
					begin
						select @LinkedCr=CreditAccount from ACC_DocDetails a WITH(NOLOCK) 
						join ACC_Accounts b WITH(NOLOCK) on a.CreditAccount=b.AccountID
						where b.IsBillwise=1 and a.AccDocDetailsID=@HoldDimID
						set @penalty=-@penalty
					end	
										  
								  
			if(@LinkedCr>0)
			BEGIN							  
					set @sql='insert into com_billWise([DocNo]
				   ,[DocSeqNo]
				   ,[AccountID]
				   ,[AdjAmount]
				   ,[AdjCurrID]
				   ,[AdjExchRT]
				   ,[DocDate]
				   ,[DocDueDate]
				   ,[DocType]
				   ,[IsNewReference]				  
				   ,[Narration]
				   ,[IsDocPDC]				  
				   ,'+@CCreplCols+' [AmountFC]
				   ,[BillNo]
				   ,[BillDate]
				   ,[StatusID]
				   ,[RefStatusID]
				   ,[ConvertedDate])
						SELECT a.VoucherNo
							  ,a.DocSeqNo
							  ,'+Convert(nvarchar(max),@LinkedCr)+'
							  ,'+Convert(nvarchar(max),@penalty)+'
							  ,1
							  ,1
							  ,a.DocDate
							  ,a.DueDate
							  ,a.DocumentType
							  ,1
							  ,''''
							  ,0
							  ,'+@CCreplCols+Convert(nvarchar(max),@penalty)+',NULL,NULL,a.StatusID,null,null
						  FROM  ACC_DocDetails a with(nolock)
						  join COM_DocCCData d with(nolock) on a.AccDocDetailsID=d.AccDocDetailsID
						   where  a.AccDocDetailsID ='+Convert(nvarchar(max),@HoldDimID)
					
					exec(@sql)	   
										
				END
				
				
					if(@dimWiseCurr>50000)
					BEGIN
					
						set @sql='select @NID=dcCCNID'+convert(nvarchar,(@dimWiseCurr-50000))+' from COM_DocCCData  WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@HoldDimID)
						
						EXEC sp_executesql @sql, N'@NID float OUTPUT', @NID OUTPUT   
						
						select @NewBillDate=DocDate from ACC_DocDetails WITH(NOLOCK) where AccDocDetailsID=@HoldDimID
						
						SELECT @ExchRate=ExchangeRate  FROM  COM_EXCHANGERATES WITH(NOLOCK) 
						where CurrencyID = @baseCurr AND EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@NewBillDate))
						and DimNodeID=@NID ORDER BY EXCHANGEDATE DESC
						
						set @sql='update A
							set A.AmountBC=round(Amount/'+convert(nvarchar,@ExchRate)+','+@Decimals+'),A.ExhgRtBC='+convert(nvarchar,@ExchRate)+'
							FROM ACC_DocDetails A WITH(NOLOCK)
							where A.AccDocDetailsID='+convert(nvarchar,@HoldDimID)+'
							
							update B 
							set B.AmountBC=round(AdjAmount/'+convert(nvarchar,@ExchRate)+','+@Decimals+'),B.ExhgRtBC='+convert(nvarchar,@ExchRate)+'
							FROM com_billWise B WITH(NOLOCK)
							where B.DocNo='''+@NewVoucherNO+''''
						
						exec(@sql)
						
					END
			
			END
			
			set @sql=' INSERT INTO [COM_DocTextData]('+@TextCols+'[AccDocDetailsID]) select '+@TextCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocTextData]  WITH(NOLOCK)
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)  
				
			if(@Action=1 and @PrefValue<>'True')
			begin
				select @OldvouNO=voucherNo,@seqno=DocSeqNo,@oldstatus=StatusID from ACC_DocDetails with(nolock)
			    where AccDocDetailsID=@Acc
			    
			    select @BillDate=DocDate from ACC_DocDetails with(nolock)
			    where AccDocDetailsID=@AccDocDetails
			    
			
				update B
				set B.docno=@NewVoucherNO,B.DocDate=@BillDate,B.DocType=@DocumentType,B.StatusID=@status
				FROM com_billWise B WITH(NOLOCK)
				where B.docno=@OldvouNO and B.DocSeqNo=@seqno
				
				update B
				set B.Refdocno=@NewVoucherNO,B.RefDocDate=@BillDate,B.RefStatusID=@status
				FROM com_billWise B WITH(NOLOCK)
				where B.Refdocno=@OldvouNO and B.RefDocSeqNo=@seqno
			end
			else if(@Action=0)
			begin
			
				select @OldvouNO=voucherNo,@seqno=DocSeqNo,@oldstatus=StatusID from ACC_DocDetails with(nolock)
			    where AccDocDetailsID=@Acc
			 
				update B
				set B.Refdocno=NULL,B.RefStatusID=null,B.RefDocSeqNo=NUll,B.RefDocDate=NULL,B.RefDocDueDate=NULL,B.IsNewReference=1
				FROM com_billWise B WITH(NOLOCK)
				where B.Refdocno=@OldvouNO and B.RefDocSeqNo=@seqno
				
			end
		
		--created by ,createddate
		set @Columnname='' 
		select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
		where costcenterid=@CCID and 
		LocalReference is not null and LinkData is not null 
		 and LocalReference=79 and LinkData=24060
		 if(@Columnname is not null and @Columnname like 'dcAlpha%')
		 begin
			 set @sql='update COM_DocTextData
			 set '+@Columnname+'='''+@UserName+''' 
			 where AccDocDetailsID ='+convert(nvarchar,@AccDocDetails)
			 exec (@sql)
		 end  
		
		set @Columnname='' 
		select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
		where costcenterid=@CCID and 
		LocalReference is not null and LinkData is not null 
		 and LocalReference=79 and LinkData=24061
		 if(@Columnname is not null and @Columnname like 'dcAlpha%')
		 begin
			 set @sql='update COM_DocTextData
			 set '+@Columnname+'='''+CONVERT(nvarchar,convert(datetime,@dt),106)+''' 
			 where AccDocDetailsID ='+convert(nvarchar,@AccDocDetails)
			 exec (@sql)
		 end  
		 
		 
		 if(@Action=0 and @oldPDCStatus<>369)
		 BEGIN
			set @tempbid=0
		 	select @tempcr=CreditAccount,@tempdr=DebitAccount,@temptype=DocumentType,@tempbid=BankAccountID from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
		 	
		 END
 
		 if((@Action=0 and @oldPDCStatus<>369) and not (@PrefValue='True' and (@tempbid is null or @tempbid=0)))
		 begin
		 
			if(@temptype=16)
			BEGIN
				set @CCID=0
				select @CCID=isnull(value,0) from @preftble 
				where  Name='OnOpbConvert' and ISNUMERIC(value)=1 and CONVERT(INT,value)>40000
				set @Series=0
			END	
			else			
				select @CCID=ConvertAs,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
			select @TypeID=DocumentTypeID,@DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=@CCID						
			if(@Dupl is not null and @Dupl>0)
			BEGIN
				SELECT @DocID=DocID,@DoCPrefix=DocPrefix ,@DOCNumber=DocNumber,@NewVoucherNO=[VoucherNo]
				FROM ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeID=@Dupl and [CostCenterID]=@CCID
			END
			ELSE
			BEGIN
							
 				if(@DoCPrefix is null)
				begin 
					set	@DoCPrefix=''
				end
				
				
				if(@Series=2)
				begin
					select @DOCNumber=DocNumber,@DoCPrefix=DocPrefix,@docseq=DocseqNo from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc
					
					if exists(SELECT value FROM @preftble 
					WHERE ccid=@CostCenterID and name='Defaultprefix' and value='true')
					BEGIN
						if not exists(select CCID from COM_DocPrefix WITH(NOLOCK)
						where DocumentTypeID=@TypeID and IsDefault=1)
						and (select count(SeriesNo) from  (select SeriesNo from COM_DocPrefix WITH(NOLOCK)
						where DocumentTypeID=@TypeID
						group by SeriesNo) as t)>1
						BEGIN
							RAISERROR('-564',16,1)
						END

						set @DoCPrefix=''
						EXEC [sp_GetDocPrefix] '',@dttemp,@CCID,@DoCPrefix output,@Acc
						
					END
					
					if(@DoCPrefix='')
					begin
						set @DoCPrefix=convert(nvarchar(50), @DOCNumber)+'/'
					end
					else
					begin
						set @DoCPrefix=@DoCPrefix+convert(nvarchar(50), @DOCNumber)+'/'
					end	
					
					set @DOCNumber=@docseq
					
					set @NewVoucherNO=@ABBR+'-'+@DoCPrefix+convert(nvarchar(50), @DOCNumber)

					if exists(select docid from ACC_DocDetails with(nolock) where DocNumber=convert(nvarchar(50),@DOCNumber) and DocPrefix=@DoCPrefix and [CostCenterID]=@CCID)
					begin
						RAISERROR('-373',16,1)
					end
				end
				else if(@Series=0)
				begin
					
					select @DoCPrefix=DocPrefix,@dttemp =case when @PostonConversionDate=1 then floor(convert(float,getdate()))
											when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end 
					from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc          

					if exists(SELECT value FROM @preftble 
					WHERE ccid=@CostCenterID and name='Defaultprefix' and value='true')
					BEGIN
						if not exists(select CCID from COM_DocPrefix WITH(NOLOCK)
						where DocumentTypeID=@TypeID and IsDefault=1)
						and (select count(SeriesNo) from  (select SeriesNo from COM_DocPrefix WITH(NOLOCK)
						where DocumentTypeID=@TypeID
						group by SeriesNo) as t)>1
						BEGIN
							RAISERROR('-564',16,1)
						END

						set @DoCPrefix=''
						EXEC [sp_GetDocPrefix] '',@dttemp,@CCID,@DoCPrefix output,@Acc
					END
								
				   if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=@CCID AND CodePrefix=@DocPrefix)    
				   begin 
					  set @DOCNumber=1
						 select @DOCNumber=isnull(prefvalue,1) from com_documentpreferences WITH(NOLOCK)
						 WHERE CostCenteriD=@CCID and prefname='StartNoForNewPrefix'
						 and prefvalue is not null and prefvalue<>'' and prefvalue<>'0'
						 
						 select  @LocationID=dcCCNID2,@DivisionID=dcCCNID1 from COM_DocCCData with(nolock) where AccDocDetailsID=@Acc
						 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
						 VALUES(@CCID,@CCID,@DocPrefix,@DOCNumber,1,@DOCNumber,len(@DOCNumber),Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    
					end   
					else
					begin		 
						select  @DOCNumber=CurrentCodeNumber+1,@fid=CodeNumberLength from Com_CostCenterCodeDef with(nolock) 
						where CodePrefix=@DoCPrefix  and CostCenterID=@CCID
						
						while(len(@DOCNumber)<@fid)    
						begin    
							SET @DocNumber='0'+@DOCNumber
						end  
						
						UPDATE T  SET T.CurrentCodeNumber=CurrentCodeNumber+1 
						from Com_CostCenterCodeDef T with(nolock)
						where T.CodePrefix=@DoCPrefix  and T.CostCenterID=@CCID
					end
					if(@DoCPrefix='')
					begin
						set @NewVoucherNO=@ABBR+'-'+convert(nvarchar(50), @DOCNumber)
					end
					else
					begin
						set @NewVoucherNO=@ABBR+'-'+@DoCPrefix+convert(nvarchar(50), @DOCNumber)
					end
					
				end
				else
				begin
					 
					select @DOCNumber=DocNumber,@DoCPrefix=DocPrefix from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc
				 
					if(@DoCPrefix='')
					begin
						set @NewVoucherNO=@ABBR+'-'+convert(nvarchar(50), @DOCNumber)
					end
					else
					begin
						set @NewVoucherNO=@ABBR+'-'+@DoCPrefix+convert(nvarchar(50), @DOCNumber)
					end		
					
					if exists(select docid from ACC_DocDetails with(nolock) where DocNumber=convert(nvarchar(50), @DOCNumber) and DocPrefix=@DoCPrefix and [CostCenterID]=@CCID)
					begin
						RAISERROR('-373',16,1)
					end
				end
				
				--To Get Auto generate DocID
				INSERT INTO COM_DocID(DocNo,[CompanyGUID],[GUID],SysInfo)
				VALUES(@NewVoucherNO,@CompanyGUID,Newid(),@sysinfo)
				SET @DocID=@@IDENTITY
				
			   if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=@CCID AND CodePrefix=@DocPrefix)    
			   begin 
				 select  @LocationID=dcCCNID2,@DivisionID=dcCCNID1 from COM_DocCCData with(nolock) where AccDocDetailsID=@Acc
				 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
				 VALUES(@CCID,@CCID,@DocPrefix,1,1,1,1,Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    				 
			   end 
			 END
			 	
			 	if(@temptype=16)
				BEGIN
					select @tempdr=DebitAccount,@tempbid=BankAccountID 
					from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc

					set  @DebitAccountID=@tempdr
					set  @CreditAccountID =@tempbid
				END
				
			 	if(@PrefValue='True')
			 	begin
			 		select @tempcr=case when IsNegative=1 THEN DebitAccount else CreditAccount end,@tempdr=case when IsNegative=1 THEN CreditAccount else DebitAccount end,@temptype=DocumentType,@tempbid=BankAccountID from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
					if(@temptype=19)
						set @DebitAccountID=@tempdr
					else if(@temptype=14)
						set @CreditAccountID=@tempcr				
			 	end
 			 	
			 	if(@IsDiscounted=1 and @temptype=19)
				begin			
					select @CreditAccountID=pdcDiscountAccount from ACC_Accounts WITH(NOLOCK)
					where accountid=@CreditAccountID 			
				end
				 
	 			if(@CCID=0)
				BEGIN
					RAISERROR('-395',16,1)
				END
				
				select @tempDocid=DocID,@tempccid=Costcenterid from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc
				if not exists(select * from COM_Files WITH(NOLOCK) where  FeatureID=@CCID  and FeaturePK=@DocID)			
				BEGIN
					insert into COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,FeatureID,FeaturePK,CompanyGUID
					,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,FileDescription,CostCenterID,AllowInPrint,IsDefaultImage
					,RowSeqNo,ColName,LocationID,DivisionID,ValidTill,RefNo,HasThumb,RefNum,Remarks,DocNo,Type,IssueDate,status,IsSign)
					select FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,@CCID,@DocID,CompanyGUID
					,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,FileDescription,@CCID,AllowInPrint,IsDefaultImage
					,RowSeqNo,ColName,LocationID,DivisionID,ValidTill,RefNo,HasThumb,RefNum,Remarks,DocNo,Type,IssueDate,status,IsSign
					from COM_Files WITH(NOLOCK)
					where FeatureID=@tempccid  and FeaturePK=@tempDocid
				END	 

 							     INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]    								
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],RefCCID,RefNodeID,BRS_Status,ClearanceDate,BankAccountID)
								 
								 Select @DocID  
										,@CCID 										
										,@DocumentType   
										,[VersionNo]    
										,@NewVoucherNO
										,@ABBR    
										,@DoCPrefix    
										,@DOCNumber  
										,case when @PostonConversionDate=1 then floor(convert(float,getdate()))
										 when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end    
    
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,[LinkedAccDocDetailsID]
										,[CommonNarration]    
										,LineNarration 
									    , case when IsNegative=1 THEN @DebitAccountID ELSE @CreditAccountID END
										, case when IsNegative=1 THEN @CreditAccountID ELSE @DebitAccountID END
										,[Amount]    
										,IsNegative    
										,[DocSeqNo]    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC] 
										,@UserName    
										,@Dt,400,@Acc
										,case when @clearonConvert=1 then 1 else 0 end ,
										case when @PostonConversionDate=1 then floor(convert(float,getdate()))
										 when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end  
										 ,case when DocumentType=19 then CreditAccount else DebitAccount END
										 from ACC_DocDetails with(nolock) where  AccDocDetailsID =@Acc
	

				set @AccDocDetails=@@IDENTITY
				
				set @ConDoc=@NewVoucherNO
				
			if(@dimWiseCurr>50000)
			BEGIN
				set @sql='update ACC_DocDetails 
				set AmountBC=t.AmountBC,ExhgRtBC=t.ExhgRtBC
				from (select AmountBC,ExhgRtBC from ACC_DocDetails a WITH(NOLOCK)
				where a.AccDocDetailsID='+CONVERT(nvarchar,@Acc)+' )as t
				where AccDocDetailsID='+CONVERT(nvarchar,@AccDocDetails)
				exec(@sql)
			END
			
			if exists(select [DocID] from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc)
			BEGIN
				select @LinkedDB=DebitAccount,@LinkedCr=CreditAccount from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc						
				if(@PrefValue='True')
				BEGIN
					select @tempdr=DebitAccount,@tempcr=CreditAccount from ACC_DocDetails WITH(NOLOCK) where AccDocDetailsID=@Acc
					if(@temptype=19 and @LinkedCr=@tempcr)
						set @LinkedCr=@CreditAccountID
					else if(@temptype=14 and @LinkedDB=@tempdr)
						set @LinkedDB=@DebitAccountID
				END	
				
				if(@dimWiseCurr>50000)
				BEGIN
					select @NewBillDate=DocDate from ACC_DocDetails with(nolock)
					where AccDocDetailsID=@AccDocDetails
						
					set @sql='INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]       
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,AmountBC,ExhgRtBC,AP)
								 Select '+CONVERT(nvarchar,@DocID)+'
										,'+CONVERT(nvarchar,@CCID)+'    
										,'+CONVERT(nvarchar,@DocumentType)+'   
										,[VersionNo]    
										,'''+CONVERT(nvarchar,@NewVoucherNO)+'''
										,'''+CONVERT(nvarchar,@ABBR)+'''    
										,'''+CONVERT(nvarchar,@DoCPrefix)+'''    
										,'''+CONVERT(nvarchar,@DOCNumber)+'''  
										, '+CONVERT(nvarchar,@NewBillDate)+'   
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,'+CONVERT(nvarchar,@AccDocDetails)+'
										,[CommonNarration]    
										,LineNarration    
										,'+CONVERT(nvarchar,@LinkedDB)+' 
										,'+CONVERT(nvarchar,@LinkedCr)+'   
										,[Amount]    
										,IsNegative    
										,[DocSeqNo]    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC]     
										,'''+@UserName+'''
										,'+CONVERT(nvarchar,@Dt)+','+CONVERT(nvarchar,@Dt)+',400,'+CONVERT(nvarchar,@Acc)+',AmountBC,ExhgRtBC
										,'''+@AP+'''
										 from ACC_DocDetails with(nolock) where  LinkedAccDocDetailsID ='+CONVERT(nvarchar,@Acc)
					
					exec(@sql)						
				END
				ELSE
				BEGIN
					INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]    								 
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,AP)
								 Select @DocID  
										,@CCID 										 
										,@DocumentType   
										,[VersionNo]    
										,@NewVoucherNO
										,@ABBR    
										,@DoCPrefix    
										,@DOCNumber  
										,case when @PostonConversionDate=1 then floor(convert(float,getdate()))
											when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end    
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,@AccDocDetails
										,[CommonNarration]    
										,LineNarration    
										,@LinkedDB    
										,@LinkedCr    
										,[Amount]    
										,IsNegative    
										,[DocSeqNo]    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC]
										,@UserName    
										,@Dt,@Dt,400,@Acc,@AP from ACC_DocDetails with(nolock) where  LinkedAccDocDetailsID =@Acc										
					END					
	  									   
					set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+'a.AccDocDetailsID
					FROM ACC_DocDetails a WITH(NOLOCK) , [COM_DocCCData] b WITH(NOLOCK) 
					WHERE LinkedAccDocDetailsID='+convert(nvarchar,@AccDocDetails)+' and b.AccDocDetailsID='+convert(nvarchar,@Acc)		
					exec(@sql) 
				END		
				
				set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+convert(nvarchar,@AccDocDetails)+'
				FROM [COM_DocCCData]  WITH(NOLOCK)
				WHERE AccDocDetailsID='+convert(nvarchar,@Acc)		
				exec(@sql) 
           
				set @sql=' INSERT INTO [COM_DocNumData]('+@NumCols+'[AccDocDetailsID])select  '+@NumCols+convert(nvarchar,@AccDocDetails)+'
				FROM [COM_DocNumData]  WITH(NOLOCK)
				WHERE AccDocDetailsID='+convert(nvarchar,@Acc)		
				exec(@sql)
				
				set @sql=' INSERT INTO [COM_DocTextData]('+@TextCols+'[AccDocDetailsID]) select '+@TextCols+convert(nvarchar,@AccDocDetails)+'
				FROM [COM_DocTextData]  WITH(NOLOCK)
				WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
				exec(@sql) 
		 
				set @Columnname='' 
				select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
				where costcenterid=@CCID and LocalReference is not null and LinkData is not null 
				and LocalReference=79 and LinkData=24060
				if(@Columnname is not null and @Columnname like 'dcAlpha%')
				begin
					set @sql='update COM_DocTextData
					set '+@Columnname+'='''+@UserName+''' 
					where AccDocDetailsID ='+convert(nvarchar,@AccDocDetails)
					exec (@sql)
				end  
				
				set @Columnname='' 
				select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
				where costcenterid=@CCID and LocalReference is not null and LinkData is not null 
				and LocalReference=79 and LinkData=24061
				if(@Columnname is not null and @Columnname like 'dcAlpha%')
				begin
					set @sql='update COM_DocTextData
					set '+@Columnname+'='''+CONVERT(nvarchar,convert(datetime,@dt),106)+''' 
					where AccDocDetailsID ='+convert(nvarchar,@AccDocDetails)
					exec (@sql)
				end  
				
			end
		 
			if(@PrefValue='True' and @temptype<>16 and (@Action=1 or (@Action=0 and @oldPDCStatus<>369)))
			begin
						
				select @OldvouNO=voucherNo,@seqno=DocSeqNo,@oldstatus=StatusID from ACC_DocDetails with(nolock)
			    where AccDocDetailsID=@Acc
			
				update B
				set B.DocType=@DocumentType
				FROM com_billWise B WITH(NOLOCK)
				where B.docno=@OldvouNO and B.DocSeqNo=@seqno
				
			 	select @CCID=IntermediateConvertion,@series=isnull(IntermedSeries,1) from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
				select @TypeID=DocumentTypeID,@DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=@CCID						
			
				if(@Dupl is not null and @Dupl>0)
				BEGIN
					SELECT @DocID=DocID,@DoCPrefix=DocPrefix ,@DOCNumber=DocNumber,@NewVoucherNO=[VoucherNo]
					FROM ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeID=@Dupl and [CostCenterID]=@CCID
				END
				ELSE
				BEGIN
					--SELECT @DocID=ISNULL(MAX(DocID),0)+1 FROM ACC_DocDetails with(nolock)  			 
					
					if(@Series=2)
					begin
						select @DOCNumber=DocNumber,@DoCPrefix=DocPrefix,@docseq=DocseqNo from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc
						
						if exists(SELECT value FROM @preftble 
						WHERE ccid=@CostCenterID and name='Defaultprefix' and value='true')
						BEGIN
							if not exists(select CCID from COM_DocPrefix WITH(NOLOCK)
							where DocumentTypeID=@TypeID and IsDefault=1)
							and (select count(SeriesNo) from  (select SeriesNo from COM_DocPrefix WITH(NOLOCK)
							where DocumentTypeID=@TypeID
							group by SeriesNo) as t)>1
							BEGIN
								RAISERROR('-564',16,1)
							END

							set @DoCPrefix=''
							EXEC [sp_GetDocPrefix] '',@dttemp,@CCID,@DoCPrefix output,@Acc
							
						END
						
						if(@DoCPrefix='')
							set @DoCPrefix=convert(nvarchar(50), @DOCNumber)+'/'
						else
							set @DoCPrefix=@DoCPrefix+convert(nvarchar(50), @DOCNumber)+'/'
							
						set @DOCNumber=@docseq
						
						set @NewVoucherNO=@ABBR+'-'+@DoCPrefix+convert(nvarchar(50), @DOCNumber)

						if exists(select docid from ACC_DocDetails with(nolock) where DocNumber=convert(nvarchar(50),@DOCNumber) and DocPrefix=@DoCPrefix and [CostCenterID]=@CCID)
						begin
							RAISERROR('-373',16,1)
						end
					end
					else if(@series=0)
					BEGIN
						select @DoCPrefix=DocPrefix,@dttemp =case when @PostonConversionDate=1 then floor(convert(float,getdate()))
												when @PostedDate is not null then convert(float,@PostedDate)
											 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
											 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
											 else DocDate end 
						from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc          

						if exists(SELECT value FROM @preftble 
						WHERE ccid=@CostCenterID and name='Defaultprefix' and value='true')
						BEGIN
							if not exists(select CCID from COM_DocPrefix WITH(NOLOCK)
							where DocumentTypeID=@TypeID and IsDefault=1)
							and (select count(SeriesNo) from  (select SeriesNo from COM_DocPrefix WITH(NOLOCK)
							where DocumentTypeID=@TypeID
							group by SeriesNo) as t)>1
							BEGIN
								RAISERROR('-564',16,1)
							END

							set @DoCPrefix=''
							EXEC [sp_GetDocPrefix] '',@dttemp,@CCID,@DoCPrefix output,@Acc
						END
						
						 if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=@CCID AND CodePrefix=@DocPrefix)    
						 begin 
							 set @DOCNumber=1
							 select @DOCNumber=isnull(prefvalue,1) from com_documentpreferences WITH(NOLOCK)
							 WHERE CostCenteriD=@CCID and prefname='StartNoForNewPrefix'
							 and prefvalue is not null and prefvalue<>'' and prefvalue<>'0'
							 
							 select  @LocationID=dcCCNID2,@DivisionID=dcCCNID1 from COM_DocCCData with(nolock) where AccDocDetailsID=@Acc
							 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
							 VALUES(@CCID,@CCID,@DocPrefix,@DOCNumber,1,@DOCNumber,len(@DOCNumber),Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    
						end   
						else
						begin		 
							select  @DOCNumber=CurrentCodeNumber+1,@fid=CodeNumberLength from Com_CostCenterCodeDef with(nolock) 
							where CodePrefix=@DoCPrefix  and CostCenterID=@CCID
							
							while(len(@DOCNumber)<@fid)    
							begin    
								SET @DocNumber='0'+@DOCNumber
							end  
							 UPDATE T SET T.CurrentCodeNumber=CurrentCodeNumber+1 
							 FROM Com_CostCenterCodeDef T WITH(NOLOCK)
							where T.CodePrefix=@DoCPrefix  and T.CostCenterID=@CCID
						end
					END
					ELSE
						select @DOCNumber=DocNumber,@DoCPrefix=DocPrefix from ACC_DocDetails  with(nolock) where AccDocDetailsID=@Acc
				 
					if(@DoCPrefix='')
					begin
						set @NewVoucherNO=@ABBR+'-'+convert(nvarchar(50), @DOCNumber)
					end
					else
					begin
						set @NewVoucherNO=@ABBR+'-'+@DoCPrefix+convert(nvarchar(50), @DOCNumber)
					end
					
					--To Get Auto generate DocID
					INSERT INTO COM_DocID(DocNo,[CompanyGUID],[GUID],SysInfo)
					VALUES(@NewVoucherNO,@CompanyGUID,Newid(),@sysinfo)
					SET @DocID=@@IDENTITY
						
					if exists(select docid from ACC_DocDetails with(nolock) where DocNumber=+convert(nvarchar(50), @DOCNumber) and DocPrefix=@DoCPrefix and [CostCenterID]=@CCID)
					begin
						RAISERROR('-373',16,1)
					end
				END
				
				
				 
				 			if(@CCID=0)
							BEGIN
								RAISERROR('-396',16,1)
							END
				
						select @tempDocid=DocID,@tempccid=Costcenterid from ACC_DocDetails with(nolock)  where AccDocDetailsID=@Acc
						if not exists(select * from COM_Files WITH(NOLOCK) where  FeatureID=@CCID  and FeaturePK=@DocID)			
						BEGIN
							insert into COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,FeatureID,FeaturePK,CompanyGUID
							,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,FileDescription,CostCenterID,AllowInPrint,IsDefaultImage
							,RowSeqNo,ColName,LocationID,DivisionID,ValidTill,RefNo,HasThumb,RefNum,Remarks,DocNo,Type,IssueDate,status,IsSign)
							select FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,@CCID,@DocID,CompanyGUID
							,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,FileDescription,@CCID,AllowInPrint,IsDefaultImage
							,RowSeqNo,ColName,LocationID,DivisionID,ValidTill,RefNo,HasThumb,RefNum,Remarks,DocNo,Type,IssueDate,status,IsSign
							from COM_Files WITH(NOLOCK)
							where FeatureID=@tempccid  and FeaturePK=@tempDocid
						END	 

							INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]    								 
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],RefCCID,RefNodeID,ConvertedDate,BankAccountID,AP)
								 
								 Select @DocID  
										,@CCID 										 
										,@DocumentType   
										,[VersionNo]    
										,@NewVoucherNO
										,@ABBR    
										,@DoCPrefix    
										,@DOCNumber 
										,case when @InterOnCDate is null or @InterOnCDate ='' or @InterOnCDate<>'true' THEN DocDate
										 when @PostonConversionDate=1 then floor(convert(float,getdate()))
										 when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end 
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,[LinkedAccDocDetailsID]
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
										,@UserName    
										,@Dt,400,@Acc
										,case
										 when @PostonConversionDate=1 then floor(convert(float,getdate()))
										 when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end,BankAccountID,@AP  from ACC_DocDetails with(nolock) where  AccDocDetailsID =@Acc
	

							set @AccDocDetails=@@IDENTITY
							set @InterDOc=@NewVoucherNO
			if(@dimWiseCurr>50000)
			BEGIN
				set @sql='update ACC_DocDetails 
				set AmountBC=t.AmountBC,ExhgRtBC=t.ExhgRtBC
				from (select AmountBC,ExhgRtBC from ACC_DocDetails a WITH(NOLOCK)
				where a.AccDocDetailsID='+CONVERT(nvarchar,@Acc)+' )as t
				where AccDocDetailsID='+CONVERT(nvarchar,@AccDocDetails)
				exec(@sql)
			END
							
			if exists(select [DocID] from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc)
			BEGIN
				select @LinkedDB=DebitAccount,@LinkedCr=CreditAccount from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc						
				
				select @tempdr=DebitAccount,@tempcr=CreditAccount,@tempbid=BankAccountID from ACC_DocDetails WITH(NOLOCK) where AccDocDetailsID=@Acc
				
				if(@temptype=19 and @LinkedDB=@tempbid)
					set @LinkedDB=@DebitAccountID
				else if(@temptype=14 and @LinkedCr=@tempbid)
					 set @LinkedCr=@CreditAccountID
					
				if(@dimWiseCurr>50000)
				BEGIN
					 select @NewBillDate=DocDate from ACC_DocDetails with(nolock)
						where AccDocDetailsID=@AccDocDetails
						
					set @sql='INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]       
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,AmountBC,ExhgRtBC,AP)
								 Select '+CONVERT(nvarchar,@DocID)+'
										,'+CONVERT(nvarchar,@CCID)+'    
										,'+CONVERT(nvarchar,@DocumentType)+'   
										,[VersionNo]    
										,'''+CONVERT(nvarchar,@NewVoucherNO)+'''
										,'''+CONVERT(nvarchar,@ABBR)+'''    
										,'''+CONVERT(nvarchar,@DoCPrefix)+'''    
										,'''+CONVERT(nvarchar,@DOCNumber)+'''  
										, '+CONVERT(nvarchar,@NewBillDate)+'   
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,'+CONVERT(nvarchar,@AccDocDetails)+'
										,[CommonNarration]    
										,LineNarration    
										,'+CONVERT(nvarchar,@LinkedDB)+' 
										,'+CONVERT(nvarchar,@LinkedCr)+'   
										,[Amount]    
										,IsNegative    
										,[DocSeqNo]    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC]  
										,'''+@UserName+'''    
										,'+CONVERT(nvarchar,@Dt)+','+CONVERT(nvarchar,@Dt)+',400,'+CONVERT(nvarchar,@Acc)+',AmountBC,ExhgRtBC
										,'''+@AP+'''  
										 from ACC_DocDetails with(nolock) where  LinkedAccDocDetailsID ='+CONVERT(nvarchar,@Acc)
					exec(@sql)						
				END
				ELSE
				BEGIN
				
					INSERT INTO ACC_DocDetails    
								 ([DocID]    
								 ,[CostCenterID]    								    
								 ,[DocumentType]    
								 ,[VersionNo]    
								 ,[VoucherNo]    
								 ,[DocAbbr]    
								 ,[DocPrefix]    
								 ,[DocNumber]    
								 ,[DocDate]    
								 ,[DueDate]    
								 ,[StatusID]    
								 ,[ChequeBankName]    
								 ,[ChequeNumber]    
								 ,[ChequeDate]    
								 ,[ChequeMaturityDate]    
								 ,[BillNo]    
							     ,BillDate    
								 ,[LinkedAccDocDetailsID]    
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,AP)
								 Select @DocID  
										,@CCID 										 
										,@DocumentType   
										,[VersionNo]    
										,@NewVoucherNO
										,@ABBR    
										,@DoCPrefix    
										,@DOCNumber  
										,case when @PostonConversionDate=1 then floor(convert(float,getdate()))
											when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end    
										,[DueDate]    
										,[StatusID]    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,@AccDocDetails
										,[CommonNarration]    
										,LineNarration    
										,@LinkedDB    
										,@LinkedCr    
										,[Amount]    
										,IsNegative    
										,[DocSeqNo]    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC]   										  
										,@UserName    
										,@Dt,@Dt,400,@Acc,@AP from ACC_DocDetails with(nolock) where  LinkedAccDocDetailsID =@Acc										
						END				
	  				
	  					set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+'a.AccDocDetailsID
						FROM ACC_DocDetails a WITH(NOLOCK) , [COM_DocCCData] b WITH(NOLOCK) 
						WHERE LinkedAccDocDetailsID='+convert(nvarchar,@AccDocDetails)+' and b.AccDocDetailsID='+convert(nvarchar,@Acc)		
						exec(@sql) 
					END	

					set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+convert(nvarchar,@AccDocDetails)+'
					FROM [COM_DocCCData]  WITH(NOLOCK)
					WHERE AccDocDetailsID='+convert(nvarchar,@Acc)		
					exec(@sql) 
					
					set @sql=' INSERT INTO [COM_DocNumData]('+@NumCols+'[AccDocDetailsID])select  '+@NumCols+convert(nvarchar,@AccDocDetails)+'
					FROM [COM_DocNumData]  WITH(NOLOCK)
					WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
					exec(@sql)

					set @sql=' INSERT INTO [COM_DocTextData]('+@TextCols+'[AccDocDetailsID]) select '+@TextCols+convert(nvarchar,@AccDocDetails)+'
					FROM [COM_DocTextData]  WITH(NOLOCK)
					WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
					exec(@sql) 

				if(@Action=1)
				begin
					select @OldvouNO=voucherNo,@seqno=DocSeqNo,@oldstatus=StatusID from ACC_DocDetails with(nolock)
					where AccDocDetailsID=@Acc
					
					 select @BillDate=DocDate,@ConDate=ConvertedDate from ACC_DocDetails with(nolock)
					 where AccDocDetailsID=@AccDocDetails
			    
					update B
					set B.docno=@NewVoucherNO,B.DocDate=@BillDate,B.DocType=@DocumentType,B.StatusID=@status,B.ConvertedDate=@ConDate
					FROM com_billWise B WITH(NOLOCK)
					where B.docno=@OldvouNO and B.DocSeqNo=@seqno
					
					update B
					set B.Refdocno=@NewVoucherNO,B.RefDocDate=@BillDate,B.RefStatusID=@status
					FROM com_billWise B WITH(NOLOCK)
					where B.Refdocno=@OldvouNO and B.RefDocSeqNo=@seqno					
				end
		
		 
			--created by ,createddate
		set @Columnname='' 
		select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
		where costcenterid=@CCID and 
		LocalReference is not null and LinkData is not null 
		 and LocalReference=79 and LinkData=24060
		 if(@Columnname is not null and @Columnname like 'dcAlpha%')
		 begin
			 set @sql='update COM_DocTextData
			 set '+@Columnname+'='''+@UserName+''' 
			 where AccDocDetailsID ='+convert(nvarchar,@AccDocDetails)
			 exec (@sql)
		 end  
		
		set @Columnname='' 
		select @Columnname=syscolumnname from [ADM_COSTCENTERDEF] WITH(NOLOCK)
		where costcenterid=@CCID and 
		LocalReference is not null and LinkData is not null 
		 and LocalReference=79 and LinkData=24061
		 if(@Columnname is not null and @Columnname like 'dcAlpha%')
		 begin
			 set @sql='update COM_DocTextData
			 set '+@Columnname+'='''+CONVERT(nvarchar,convert(datetime,@dt),106)+''' 
			 where AccDocDetailsID ='+convert(nvarchar,@AccDocDetails)
			 exec (@sql)
		 end  
		 end
		 
		 if(@BRDim<>'')
		 BEGIN
			 set @sql='update a
			 set '+@BRDim+'
			 from COM_DocCCData a WITH(NOLOCK)
			 where AccDocDetailsID ='+convert(nvarchar,@Acc)
			 
			 set @sql=@sql+'  update a
			 set '+@BRDim+'
			 from COM_DocCCData a WITH(NOLOCK)
			 join Acc_DocDetails b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
			 where b.RefCCID=400 and b.RefNodeid ='+convert(nvarchar,@Acc)			 
			 
			 exec (@sql)
			
		 END
		 
		  if(@Action=0)
		  begin
				if(@oldPDCStatus=369)
				begin
					select @CostCenterID=CostCenterID,@OldvouNO=voucherNo,@seqno=DocSeqNo,@oldstatus=StatusID,@DocumentType=DocumentType from ACC_DocDetails with(nolock)
					where AccDocDetailsID=@Acc
					 
					select @CCID=ConvertAs,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
					if(@PrefValue='true')
					begin
						select @CCID=IntermediateConvertion,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
					end
						 
					select @NewVoucherNO=voucherNo,@BillDate=DocDate,@seqno=DocSeqNo,@DocumentType=DocumentType from ACC_DocDetails with(nolock)
					where RefCCID=400 and RefNodeID=@Acc and CostCenterID=@CCID
			 
				end
				ELSE
					select @BillDate=DocDate,@DocumentType=DocumentType from ACC_DocDetails with(nolock)
					where voucherNo=@NewVoucherNO
			 
				 select @NewBillDate=DocDate from ACC_DocDetails with(nolock)
				 where voucherno=@billwiseVNO
			    
				set @sql ='insert into com_billWise([DocNo]
           ,[DocSeqNo]
           ,[AccountID]
           ,[AdjAmount]
           ,[AdjCurrID]
           ,[AdjExchRT]
           ,[DocDate]
           ,[DocDueDate]
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
           ,'+@CCreplCols+'[AmountFC]
           ,[BillNo]
           ,[BillDate]
           ,[StatusID]
           ,[RefStatusID]
           ,[ConvertedDate])
				SELECT '''+convert(nvarchar(max),@billwiseVNO)+'''
					  ,[DocSeqNo]
					  ,[AccountID]
					  ,-[AdjAmount]
					  ,[AdjCurrID]
					  ,[AdjExchRT]
					  ,'''+convert(nvarchar(max),@NewBillDate)+'''
					  ,[DocDueDate]
					  ,'+convert(nvarchar(max),@BillWiseDocType)+'
					  ,0
					  ,'''+convert(nvarchar(max),@NewVoucherNO)+'''
					  ,[DocSeqNo]
					  ,'''+convert(nvarchar(max),@BillDate)+'''
					  ,[DocDueDate]
					  ,[RefBillWiseID]
					  ,[DiscAccountID]
					  ,[DiscAmount]
					  ,[DiscCurrID]
					  ,[DiscExchRT]
					  ,[Narration]
					  ,[IsDocPDC]
					  ,'+@CCreplCols+'-[AmountFC],NULL,NULL,'+convert(nvarchar(max),@status)+','+convert(nvarchar(max),@status)+',null
				  FROM [COM_Billwise] with(nolock)
				where docno='''+convert(nvarchar(max),@OldvouNO)+''' and DocSeqNo='+convert(nvarchar(max),@seqno)
				exec(@sql)
		
			
				update B
				set B.docno=@NewVoucherNO,B.docdate=@BillDate,B.AdjAmount=AdjAmount,B.AmountFC=AmountFC,B.DocType=@DocumentType
				,B.StatusID=@status,B.RefStatusID=null,B.Refdocno=NULL,B.RefDocSeqNo=NUll,B.RefDocDate=NULL,B.RefDocDueDate=NULL,B.IsNewReference=1
				FROM com_billWise B WITH(NOLOCK)
				where B.docno=@OldvouNO and B.DocSeqNo=@seqno
				
				
				if((select COUNT(BillwiseID) from com_billwise WITH(NOLOCK)
				where docno=@NewVoucherNO and DocSeqNo=@seqno)>1)
				BEGIN
					declare @amt float,@fcamt float,@billid INT

					select @billid=min(BillwiseID),@amt=sum(AdjAmount),@fcamt=sum(AmountFC) from com_billWise with(nolock)
					where docno=@NewVoucherNO and DocSeqNo=@seqno

					update B
					set B.AdjAmount=@amt,B.AmountFC=@fcamt
					FROM com_billWise B WITH(NOLOCK)
					where B.BillwiseID=@billid 
					
					
					if(@dimWiseCurr>50000)
					BEGIN
						set @sql=' declare @amtBc float
						
						select @amtBc=sum(AmountBC) from com_billWise with(nolock)
						where docno='''+@NewVoucherNO+''' and DocSeqNo='+convert(nvarchar,@seqno)+'

						update B
						set B.AmountBC=@amtBc
						FROM com_billWise B WITH(NOLOCK)
						where B.BillwiseID='+convert(nvarchar,@billid)
					
						exec(@sql)
					END

					delete B from com_billWise B WITH(NOLOCK)
					where BillwiseID<>@billid and docno=@NewVoucherNO and DocSeqNo=@seqno
					
					select @billid=min(BillwiseID),@amt=sum(AdjAmount),@fcamt=sum(AmountFC) from com_billWise with(nolock)
					where DocNo=@billwiseVNO and RefDocNo=@NewVoucherNO and RefDocSeqNo=@seqno and IsNewReference=0

					update B
					set B.AdjAmount=@amt,B.AmountFC=@fcamt
					FROM com_billWise B WITH(NOLOCK)
					where B.BillwiseID=@billid 
					
					delete B from com_billWise B WITH(NOLOCK)
					where BillwiseID<>@billid and docno=@billwiseVNO  and IsNewReference=0
				END
				
				if(@dimWiseCurr>50000)
				BEGIN
					set @sql='update com_billWise 
					set AmountBC=t.AmountBC,ExhgRtBC=t.ExhgRtBC
					from (select a.BillwiseID id,b.AmountBC,b.ExhgRtBC from COM_Billwise a WITH(NOLOCK)
					join COM_Billwise b WITH(NOLOCK) on a.RefDocNo=b.DocNo and a.RefDocSeqNo=b.DocSeqNo
					where a.DocNo='''+@billwiseVNO+''') as t
					where BillwiseID=id'
					
					exec(@sql)
				END	
		  end
		 
		end	
		
		if(@Action=0)
		BEGIN			
			update A
			set A.BillDate=@IsReplace
			FROM ACC_DocDetails A WITH(NOLOCK)
			where A.AccDocDetailsID=@Acc or (A.RefCCID=400 and A.RefNodeid=@Acc)
		END
		if (select count(*) from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_DocTextData'  and a.name in('dcAlpha48','dcAlpha49','dcAlpha47','dcAlpha50'))=4
			BEGIN
				set @sql ='update COM_DocTextData 
				set dcAlpha47='''+@PdcDoc+''',dcAlpha48='''+@ConDoc+''',dcAlpha49='''+@InterDOc+''',dcAlpha50='''+@BounceDoc+'''
				from COM_DocTextData a WITH(NOLOCK)
				join ACC_DocDetails b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
				where b.AccDocDetailsID='+convert(nvarchar(max),@Acc)+' or (b.RefCCID=400 and b.RefNodeid='+convert(nvarchar(max),@Acc)+')'
				exec(@sql)
			END
		if(@Action in(1,0))
		BEGIN
			update A
			set A.converteddate=case when @PostonConversionDate=1 then floor(convert(float,getdate()))
				when @PostedDate is not null then convert(float,@PostedDate)
			 when A.[ChequeMaturityDate] is not null and A.[ChequeMaturityDate]>0 then A.[ChequeMaturityDate]
			 when A.[ChequeDate] is not null and A.[ChequeDate]>0 then A.[ChequeDate]
			 else A.DocDate end 
			 FROM ACC_DocDetails A WITH(NOLOCK)
			where A.AccDocDetailsID=@Acc
		END
		
		set @I=@I+1;
		
		select @documenttype=documenttype,@CostCenterID=CostCenterID,@DocID=DocID from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc		
		
		if (@documenttype in(19) and exists(select value from com_costcenterpreferences WITH(NOLOCK)
		WHere costcenterid=92 and name ='EnableManagProp' and value='true'))
		BEGIN
			if(@Action=1)
			BEGIN
				set @sql='spRen_CommisionPosting'
				exec @sql @Acc,@CostCenterID,@DocID,@UserID,@LangID
			END	
			ELSE if(@Action in(0,2))
			BEGIN
				set @docid=0
				select @ccid=costcenterid,@docid=docid from inv_docdetails WITH(NOLOCK) 
				where refccid=400 and refnodeid=@Acc and statusid<>376
				if(@docid>0)
				BEGIN	
					if(@Action =0)
						set @sql='PDC Bounced'
					ELSE if(@Action =2)
						set @sql='PDC UnConverted'
							
					EXEC	@retValue = [dbo].[spDOC_SuspendInvDocument]
							@CostCenterID = @ccid,
							@DocID = @docid,
							@DocPrefix = N'',
							@DocNumber = N'',
							@Remarks =@sql,
							@LockWhere = N'',
							@SuspendAll = 0,
							@sysinfo = @sysinfo,
							@AP = @AP,
							@UserID = @UserID,
							@UserName =@UserName,
							@RoleID = @RoleID,
							@LangID = @LangID
				
							    
					 --EXEC @retValue = [dbo].[spDOC_DeleteInvDocument]  
					 --@CostCenterID = @ccid,  
					 --@DocPrefix = '',  
					 --@DocNumber = '',
					 --@DocID=@docid,
					 --@UserID = @UserID,  
					 --@UserName = @UserName,  
					 --@LangID = @LangID,
					 --@RoleID=@RoleID
				END 
				
				set @docid=0
				select @ccid=costcenterid,@docid=docid from inv_docdetails WITH(NOLOCK) 
				where refccid=400 and refnodeid=@Acc and statusid<>376
				if(@docid>0)
				BEGIN				    
						EXEC	@retValue = [dbo].[spDOC_SuspendInvDocument]
							@CostCenterID = @ccid,
							@DocID = @docid,
							@DocPrefix = N'',
							@DocNumber = N'',
							@Remarks = @sql,
							@LockWhere = N'',
							@SuspendAll = 0,
							@sysinfo = @sysinfo,
							@AP = @AP,
							@UserID = @UserID,
							@UserName =@UserName,
							@RoleID = @RoleID,
							@LangID = @LangID
				END 
			END			
		END
		
		set @sql=''
		select @sql=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=13
		if(@sql<>'')
		BEGIN
			exec @sql @Acc,@Action,@UserID,@LangID
		END
		
		if(@Action=0 and @IsReplace=0)
		BEGIN
			select @CostCenterID=CostCenterID,@DocID=DocID from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
			EXEC spCOM_SetNotifEvent 429,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID
		END	

		--Select @XMLNode = DocXML , @ACCDetailsID = AccDocDetailsID from @TBL where ID=@I
		
		set @AUTOCCID=0					
	    SELECT @AUTOCCID=ISNULL(X.value('@CCID','INT'),0)  from @XMLNode.nodes('/AutoPOstXML') as Data(X)
		print @AUTOCCID
	    if (@XMLNode Is not null and @AUTOCCID <> 0)
		begin			
		
			SELECT @AUTOCCID=X.value('@CCID','INT')
			from @XMLNode.nodes('/AutoPOstXML') as Data(X)

			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @XMLNode.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @bxml=CONVERT(NVARCHAR(MAX), X.query('BillXML'))
			from @XMLNode.nodes('/AutoPOstXML') as Data(X)
			
			set @DetIDS=''
			SELECT @DetIDS=X.value('@DocDetIDs','nvarchar(max)')
			from @XMLNode.nodes('/AutoPOstXML') as Data(X)
			
			SELECT @ddID=X.value('@DocID','INT')
			from @XMLNode.nodes('/AutoPOstXML') as Data(X)
			
			set @TEmpWid=0
			SELECT @TEmpWid=ISNULL(X.value('@WOrkFlowID','int'),0)
			from @XMLNode.nodes('/AutoPOstXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output
			
			
			set @SQL='<XML '
			if(@DetIDS<>'')
				set @SQL=@SQL+' DetailIds="'+@DetIDS+'" '
			
			set @SQL=@SQL+'></XML>'
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'1',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = N'',      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = @bxml,      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = @SQL,       
			  @IsImport = 0,      
			  @LocationID = 0,      
			  @DivisionID = 0 ,      
			  @WID = @TEmpWid,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 400,    
			  @RefNodeid  = @ACCDetailsID,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    			  
			 
		END

	End
		
		
	if(@Action=1)
	begin
		select a.AccDocDetailsID,A.IsReplace,d.VoucherNo, d.AccDocDetailsID as ConvertedAccDocID,
		(select top 1   status from com_status with(nolock) where statusid =d.statusid) as ConvertedStatus, d.StatusID,
		(select  top 1 voucherno from ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeid=A.AccDocDetailsID and 
						CostCenterID =(select IntermediateConvertion from ADM_DocumentTypes with(nolock) where  CostCenterID=
						(Select top 1 CostCenterid from acc_docdetails with(nolock) where AccDocDetailsID= A.AccDocDetailsID))) InterMediateVoucherNO,
		(select top 1 AccDocDetailsID from ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeid=A.AccDocDetailsID and 
		CostCenterID =(select IntermediateConvertion from ADM_DocumentTypes  with(nolock) where  CostCenterID=
		(Select top 1 CostCenterid from acc_docdetails with(nolock) where AccDocDetailsID= A.AccDocDetailsID))) InterMediateDocID
		from acc_docdetails D WITH(NOLOCK)
		join @TBL A ON A.AccDocDetailsID=D.RefNodeid  and d.RefCCID=400 
		where d.costcenterid =(select ConvertAS from ADM_DocumentTypes D with(nolock) where d.CostCenterID =
		(select costcenterid from acc_docdetails with(nolock) where Accdocdetailsid=A.AccDocDetailsID))
	end
	else if(@Action=0)
	begin 
		select a.AccDocDetailsID, A.IsReplace,d.VoucherNo, d.AccDocDetailsID as ConvertedAccDocID,
		(select   top 1 status from com_status with(nolock) where statusid =d.statusid) as ConvertedStatus, d.StatusID,
		(select top 1 voucherno from ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeid=A.AccDocDetailsID and 
						CostCenterID =(select IntermediateConvertion from ADM_DocumentTypes with(nolock)  where  CostCenterID=
						(Select top 1 CostCenterid from acc_docdetails with(nolock) where AccDocDetailsID= A.AccDocDetailsID))) InterMediateVoucherNO,
		(select top 1 AccDocDetailsID from ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeid=A.AccDocDetailsID and 
		CostCenterID =(select IntermediateConvertion from ADM_DocumentTypes with(nolock)  where  CostCenterID=
		(Select top 1 CostCenterid from acc_docdetails with(nolock) where AccDocDetailsID= A.AccDocDetailsID))) InterMediateDocID
		from acc_docdetails D WITH(NOLOCK)
		join @TBL A ON A.AccDocDetailsID=D.RefNodeid  and d.RefCCID=400 
		where d.costcenterid =(select bounce from ADM_DocumentTypes D with(nolock) where d.CostCenterID =
		(select costcenterid from acc_docdetails with(nolock) where Accdocdetailsid=A.AccDocDetailsID))
	end
	ELSE 
		SELECT 1 where 1<>1
		
	--HOLD PDC	
	IF @HoldXML!=''
	BEGIN		
		Declare @TBLHOLD TABLE(ID INT IDENTITY(1,1),AccDocDetailsID INT,HoldDimension INT,HoldDate nvarchar(50),Remarks nvarchar(max))
		set @XMl=@HoldXML
		insert into @TBLHOLD
		select X.value('@ID','INT'),X.value('@HoldDimension','INT'),X.value('@HoldDate','nvarchar(20)'),X.value('@HoldRemarks','nvarchar(max)')
		from @XMl.nodes('/XML/Row') as Data(X)

		select @I=1,@Cnt=count(*) from @TBLHOLD
		
		while(@I<=@Cnt)
		Begin
			select @Acc=AccDocDetailsID,@HoldDimID=HoldDimension,@HoldDate=HoldDate,@HoldDateRemarks=Remarks from @TBLHOLD where ID=@I
			set @SQL='update com_docccdata set dcCCNID'+convert(nvarchar,@HoldDim)+'='+convert(nvarchar,@HoldDimID)+' where AccDocDetailsID='+convert(nvarchar,@Acc)
			if(@HoldDateField!='' or @HoldDateRemarksField!='')
			begin
				set @SQL=@SQL+'
				update com_doctextdata set '
				if(@HoldDateField!='')
				begin
					if @HoldDate is null
						set @SQL=@SQL+'dcAlpha'+convert(nvarchar,@HoldDateField)+'=null'
					else
						set @SQL=@SQL+'dcAlpha'+convert(nvarchar,@HoldDateField)+'='''+@HoldDate+''''
				end
				if(@HoldDateRemarksField!='')
				begin
					if(@HoldDateField!='')
						set @SQL=@SQL+','
					if @HoldDateRemarks is null
						set @SQL=@SQL+'dcAlpha'+convert(nvarchar,@HoldDateRemarksField)+'=null'
					else
						set @SQL=@SQL+'dcAlpha'+convert(nvarchar,@HoldDateRemarksField)+'='''+replace(@HoldDateRemarks,'''','''''')+''''
				end
				set @SQL=@SQL+' where AccDocDetailsID='+convert(nvarchar,@Acc)
			end
			exec(@SQL)
			set @I=@I+1
		end
	END
	
	 

	SELECT distinct VoucherNo from acc_docdetails D WITH(NOLOCK)
	join @TBL a on d.AccDocDetailsID=a.AccDocDetailsID
	WHERE isLock=1
	
COMMIT TRANSACTION 
--ROLLBACK TRANSACTION

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	IF ERROR_NUMBER()=50000
	BEGIN
		if(ERROR_MESSAGE()=-373)
			SELECT ErrorMessage+@NewVoucherNO ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		else
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
