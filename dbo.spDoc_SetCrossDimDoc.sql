USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetCrossDimDoc]
	@Action [int],
	@Acc [int],
	@PostedDate [datetime],
	@PostonConversionDate [bit],
	@AP [varchar](10),
	@sysinfo [nvarchar](50),
	@CompanyGUID [nvarchar](50),
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
	,@AccDocDetails INT ,@DocID INT,@CostCenterID INT,@IsDiscounted bit,@Columnname nvarchar(100),@dimWiseCurr int
	,@DebitAccountID INT,@oldPDCStatus int,@billwiseVNO nvarchar(200),@BillWiseDocType int,@sql nvarchar(max),@InterOnCDate nvarchar(50)
	DECLARE @DoCPrefix nvarchar(50),@ABBR nvarchar(50),@NewVoucherNO nvarchar(200),@retValue int,@NID INT,@ExchRate float
	Declare @LocationID INT,@DivisionID INT,@Series int,@PrefValue nvarchar(50),@status int,@DocDate datetime
	declare @vouNO nvarchar(200),@OldvouNO nvarchar(200),@seqno int,@oldstatus int,@Dupl INT,@Dt float,@BillDate FLOAT,@NewBillDate FLOAT,@baseCurr int
	declare @temptype int ,@tempcr INT,@tempdr INT,@tempbid INT,@PrefCheqReturn nvarchar(50),@Adb INT,@penalty float,@Decimals nvarchar(10)
	DECLARE @AuditTrial BIT,@HistoryStatus nvarchar(50),@CCCols nvarchar(max),@NumCols nvarchar(max),@TextCols nvarchar(max),@IsReplace int,@IsHold bit,@LinkedDB INT,@LinkedCr INT
	declare @HoldDim int,@HoldDimID INT,@HoldDateField nvarchar(20),@HoldDate nvarchar(20),@HoldDateRemarksField nvarchar(20),@HoldDateRemarks nvarchar(max)
	Declare @DocCol nvarchar(max),@TablCol nvarchar(max),@table nvarchar(max),@fid int,@dttemp datetime
	Declare @PdcDoc nvarchar(max),@CCreplCols nvarchar(max),@InterDOc nvarchar(max),@ConDoc nvarchar(max),@BounceDoc nvarchar(max),@clearonConvert bit
	
	
	set @CCreplCols=''
	select @CCreplCols =@CCreplCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData'  and a.name like 'dcCCNID%' and convert(int,replace(a.name,'dcCCNID',''))<51


	declare @preftble table(name nvarchar(200),value nvarchar(max),ccid int)
	insert into @preftble
	SELECT Name,Value,0 FROM ADM_GlobalPreferences WITH(NOLOCK) 
	WHERE name in('EnableCrossDimension','DimensionwiseCurrency','BaseCurrency','OnOpbConvert','OnOpbBounce','ClearonConvert','DecimalsinAmount','Intermediate PDC','IntermediatePDConConversionDate'
	,'PDCHoldDimension','PDCHoldDate','PDCHoldRemarks','enableChequeReturnHistory','Dont Change PDC Bank On Convert')
		
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
	
	set @NumCols=''
	select @NumCols =@NumCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocNumData'  and a.name not in('AccDocDetailsID','INVDocDetailsID','DocNumDataID')

	set @TextCols=''
	select @TextCols =@TextCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocTextData'  and a.name not in('AccDocDetailsID','INVDocDetailsID','DocTextDataID')

	set @Dt=convert(float,getdate())

	select @PrefValue=value from @preftble  where name='Intermediate PDC'
	select @InterOnCDate=value from @preftble  where name='IntermediatePDConConversionDate'
		
	

		set @ConDoc=null
		set @InterDOc=null
		set @BounceDoc=null
			
		select @CostCenterID=CostCenterID,@PdcDoc=VoucherNo,@temptype=DocumentType,@IsDiscounted=IsDiscounted  
		,@DocDate=CONVERT(DATETIME,DocDate),@DocID=DocID
		from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
		
		 
		if(@Action=1)
		begin
			select @CCID=ConvertAs,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
			select @TypeID=DocumentTypeID,@DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=@CCID						
			set @status=369
		end
		else if(@Action=0)
		begin 
			
				select @oldPDCStatus=StatusID from ACC_DocDetails with(nolock)
				where AccDocDetailsID=@Acc
				
				if(@oldPDCStatus=369)
				begin
					
					
					select @vouNO=voucherNo from ACC_DocDetails with(nolock)
					where RefCCID=400 and RefNodeID=@Acc
					select @OldvouNO=voucherNo,@BillDate=DocDate,@seqno=DocSeqNo,@oldstatus=StatusID,@DocumentType=DocumentType 
					from ACC_DocDetails with(nolock)
					where AccDocDetailsID=@Acc
				 
					update com_billWise
					set docno=@OldvouNO,DocDate=@BillDate,DocType=@DocumentType,StatusID=429,ConvertedDate=NUll
					where docno=@vouNO and DocSeqNo=@seqno
					
					update com_billWise
					set Refdocno=@OldvouNO,refDocDate=@BillDate,RefStatusID=429
					where Refdocno=@vouNO and RefDocSeqNo=@seqno
					
					UPDATE ACC_DocDetails 
					SET StatusID = 429 
					where RefCCID=400 and RefNodeID=@Acc 
					
				end	
			
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
											   '+@CCreplCols+'convert(float,getdate())
		from ACC_DocDetails a WITH(nolock)
		join dbo.COM_DocCCData b WITH(nolock) on a.AccDocDetailsID=b.AccDocDetailsID
		where a.AccDocDetailsID = '+convert(nvarchar(max),@Acc )
				exec(@sql)
	 end
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
				
			select @CCID=ConvertAs,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
				 
			select @vouNO=voucherNo,@seqno=DocSeqNo from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc and CostCenterID=@CCID
			
			
			if(@oldstatus=429)
			begin
				delete from COM_ChequeReturn
				where docno=@OldvouNO and DocSeqNo=@seqno
				
				delete from COM_ChequeReturn
				where Refdocno=@OldvouNO and RefDocSeqNo=@seqno
				
				update com_billWise
				set docno=@OldvouNO,DocDate=@BillDate,StatusID=@status,AdjAmount=AdjAmount,AmountFC=AmountFC,DocType=@DocumentType
				where docno=@vouNO and DocSeqNo=@seqno
				
				select @CCID=Bounce,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
				select @DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=@CCID						
				
				select @OldvouNO=voucherNo,@seqno=DocSeqNo from ACC_DocDetails with(nolock)
				where refccid=400 and refnodeid=@Acc and CostCenterID=@CCID
			
				delete from com_billWise
				where docno=@OldvouNO and DocSeqNo=@seqno and DocType=@DocumentType
			end
			else if(@oldstatus=369)
			begin
				update com_billWise
				set docno=@OldvouNO,DocDate=@BillDate,DocType=@DocumentType,StatusID=@status,ConvertedDate=NUll
				where docno=@vouNO and DocSeqNo=@seqno
				
				if exists(select Refdocno from com_billWise with(nolock)	where Refdocno=@vouNO and RefDocSeqNo=@seqno)
				BEGIN	
					update com_billWise
					set Refdocno=NULL,RefDocSeqNo=NULL,IsNewReference=1,RefStatusID=null
					where Refdocno=@vouNO and RefDocSeqNo=@seqno
				END
			end
			
			delete from [COM_DocCCData]
			where AccDocDetailsID is not null and AccDocDetailsID in(select AccDocDetailsID from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc)
			
			delete from [COM_DocNumData]
			where AccDocDetailsID is not null and AccDocDetailsID in(select AccDocDetailsID from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc)
			
			delete from [COM_DocTextData]
			where AccDocDetailsID is not null and AccDocDetailsID in (select AccDocDetailsID from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc)
			
			delete from [COM_DocID]
			where ID in (select docid from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeID=@Acc) 
			
			delete from ACC_DocDetails
			where RefCCID=400 and RefNodeID=@Acc
			
			UPDATE ACC_DocDetails 
			SET ConvertedDate=NUll
			where AccDocDetailsID=@Acc or LinkedAccDocDetailsID=@Acc
			
		end
		
		--UPDATING PRESENT DOC status		
			UPDATE ACC_DocDetails 
			SET StatusID = @status 
			where AccDocDetailsID=@Acc or LinkedAccDocDetailsID=@Acc
		
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
						
						 UPDATE Com_CostCenterCodeDef
						 SET CurrentCodeNumber=CurrentCodeNumber+1 
						 where CodePrefix=@DoCPrefix  and CostCenterID=@CCID
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
				INSERT INTO COM_DocID(DocNo,SysInfo)
				VALUES(@NewVoucherNO,@sysinfo)
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,BRS_Status,ClearanceDate,AP)
								 
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
										 ,case when @Action=0 then [CreditAccount] else [DebitAccount] end
									 ,case when @Action=0 then [DebitAccount] else [CreditAccount] end
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
										 else DocDate end else 0 end,@AP
										 from ACC_DocDetails with(nolock) 
										 where  AccDocDetailsID =@Acc

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
			
			set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocCCData]  WITH(NOLOCK)
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)

			set @sql=' INSERT INTO [COM_DocNumData]('+@NumCols+'[AccDocDetailsID]) select '+@NumCols+convert(nvarchar,@AccDocDetails)+'
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
			    
			    select @BillDate=DocDate from ACC_DocDetails with(nolock)
			    where AccDocDetailsID=@AccDocDetails
			    
			
				update com_billWise
				set docno=@NewVoucherNO,DocDate=@BillDate,DocType=@DocumentType,StatusID=@status
				where docno=@OldvouNO and DocSeqNo=@seqno
				
				update com_billWise
				set Refdocno=@NewVoucherNO,RefDocDate=@BillDate,RefStatusID=@status
				where Refdocno=@OldvouNO and RefDocSeqNo=@seqno
			end
			else if(@Action=0)
			begin
			
				select @OldvouNO=voucherNo,@seqno=DocSeqNo,@oldstatus=StatusID from ACC_DocDetails with(nolock)
			    where AccDocDetailsID=@Acc
			 
				update com_billWise
				set Refdocno=NULL,RefStatusID=null,RefDocSeqNo=NUll,RefDocDate=NULL,RefDocDueDate=NULL,IsNewReference=1
				where Refdocno=@OldvouNO and RefDocSeqNo=@seqno
				
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
		 begin
		 
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
						
						UPDATE Com_CostCenterCodeDef
						 SET CurrentCodeNumber=CurrentCodeNumber+1 
						 where CodePrefix=@DoCPrefix  and CostCenterID=@CCID
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
				INSERT INTO COM_DocID(DocNo,SysInfo)
				VALUES(@NewVoucherNO,@sysinfo)
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
					RAISERROR('-395',16,1)
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
								 ,[CreatedDate],RefCCID,RefNodeID,BRS_Status,ClearanceDate,AP)
								 
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
										,case when @clearonConvert=1 then 1 else 0 end ,
										case when @PostonConversionDate=1 then floor(convert(float,getdate()))
										 when @PostedDate is not null then convert(float,@PostedDate)
										 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
										 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
										 else DocDate end  ,@AP
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
		 
			
				if(@Action=1)
				begin
					select @OldvouNO=voucherNo,@seqno=DocSeqNo,@oldstatus=StatusID from ACC_DocDetails with(nolock)
					where AccDocDetailsID=@Acc
					
					 select @BillDate=DocDate,@ConDate=ConvertedDate from ACC_DocDetails with(nolock)
					 where AccDocDetailsID=@AccDocDetails
			    
					update com_billWise
					set docno=@NewVoucherNO,DocDate=@BillDate,DocType=@DocumentType,StatusID=@status,ConvertedDate=@ConDate
					where docno=@OldvouNO and DocSeqNo=@seqno
					
					update com_billWise
					set Refdocno=@NewVoucherNO,RefDocDate=@BillDate,RefStatusID=@status
					where Refdocno=@OldvouNO and RefDocSeqNo=@seqno					
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
		 
		 
		  if(@Action=0)
		  begin
				if(@oldPDCStatus=369)
				begin
					select @CostCenterID=CostCenterID,@OldvouNO=voucherNo,@seqno=DocSeqNo,@oldstatus=StatusID,@DocumentType=DocumentType from ACC_DocDetails with(nolock)
					where AccDocDetailsID=@Acc
					 
					select @CCID=ConvertAs,@Series=Series from ADM_DOCUMENTTYPES with(nolock) where CostCenterID=@CostCenterID
						 
					select @NewVoucherNO=voucherNo,@BillDate=DocDate,@seqno=DocSeqNo,@DocumentType=DocumentType from ACC_DocDetails with(nolock)
					where RefCCID=400 and RefNodeID=@Acc and CostCenterID=@CCID
			 
				end
				ELSE
					select @BillDate=DocDate,@DocumentType=DocumentType from ACC_DocDetails with(nolock)
					where voucherNo=@NewVoucherNO
			 
				 select @NewBillDate=DocDate from ACC_DocDetails with(nolock)
				 where voucherno=@billwiseVNO
			    
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
            ,'+@CCreplCols+' [AmountFC]
           ,[BillNo]
           ,[BillDate]
           ,[StatusID]
           ,[RefStatusID]
           ,[ConvertedDate])
				SELECT '''+@billwiseVNO+'''
					  ,[DocSeqNo]
					  ,[AccountID]
					  ,-[AdjAmount]
					  ,[AdjCurrID]
					  ,[AdjExchRT]
					  ,@NewBillDate
					  ,[DocDueDate]
					  ,'+convert(nvarchar(max),@BillWiseDocType)+'
					  ,0
					  ,'''+@NewVoucherNO+'''
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
				where docno='''+@OldvouNO+''' and DocSeqNo='+convert(nvarchar(max),@seqno)
		exec(@sql)
			
				update com_billWise
				set docno=@NewVoucherNO,docdate=@BillDate,AdjAmount=AdjAmount,AmountFC=AmountFC,DocType=@DocumentType
				,StatusID=@status,RefStatusID=null,Refdocno=NULL,RefDocSeqNo=NUll,RefDocDate=NULL,RefDocDueDate=NULL,IsNewReference=1
				where docno=@OldvouNO and DocSeqNo=@seqno
				
				
				if((select COUNT(BillwiseID) from com_billwise WITH(NOLOCK)
				where docno=@NewVoucherNO and DocSeqNo=@seqno)>1)
				BEGIN
					declare @amt float,@fcamt float,@billid INT

					select @billid=min(BillwiseID),@amt=sum(AdjAmount),@fcamt=sum(AmountFC) from com_billWise with(nolock)
					where docno=@NewVoucherNO and DocSeqNo=@seqno

					update com_billWise
					set AdjAmount=@amt,AmountFC=@fcamt
					where BillwiseID=@billid 
					
					
					if(@dimWiseCurr>50000)
					BEGIN
						set @sql=' declare @amtBc float
						
						select @amtBc=sum(AmountBC) from com_billWise with(nolock)
						where docno='''+@NewVoucherNO+''' and DocSeqNo='+convert(nvarchar,@seqno)+'

						update com_billWise
						set AmountBC=@amtBc
						where BillwiseID='+convert(nvarchar,@billid)
					
						exec(@sql)
					END

					delete from com_billWise
					where BillwiseID<>@billid and docno=@NewVoucherNO and DocSeqNo=@seqno
					
					select @billid=min(BillwiseID),@amt=sum(AdjAmount),@fcamt=sum(AmountFC) from com_billWise with(nolock)
					where DocNo=@billwiseVNO and RefDocNo=@NewVoucherNO and RefDocSeqNo=@seqno and IsNewReference=0

					update com_billWise
					set AdjAmount=@amt,AmountFC=@fcamt
					where BillwiseID=@billid 
					
					delete from com_billWise
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
		 
			
		
		
		if (select count(*) from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='COM_DocTextData'  and a.name in('dcAlpha48','dcAlpha49','dcAlpha47','dcAlpha50'))=4
		BEGIN		
			set @sql='update COM_DocTextData 
			set dcAlpha47='''+@PdcDoc+''',dcAlpha48='''+@ConDoc+''',dcAlpha49='''+@InterDOc+''',dcAlpha50='''+@BounceDoc+'''
			from COM_DocTextData a WITH(NOLOCK)
			join ACC_DocDetails b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
			where b.AccDocDetailsID='+convert(nvarchar(max),@Acc)+' or (b.RefCCID=400 and b.RefNodeid='+convert(nvarchar(max),@Acc)+')'
			exec(@sql)
		END
		if(@Action in(1,0))
		BEGIN
			update ACC_DocDetails
			set converteddate=case when @PostonConversionDate=1 then floor(convert(float,getdate()))
				when @PostedDate is not null then convert(float,@PostedDate)
			 when [ChequeMaturityDate] is not null and [ChequeMaturityDate]>0 then [ChequeMaturityDate]
			 when [ChequeDate] is not null and [ChequeDate]>0 then [ChequeDate]
			 else DocDate end 
			where AccDocDetailsID=@Acc
		END
		
	
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
