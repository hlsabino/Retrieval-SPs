USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetbatchpaymentDoc]
	@DocID [bigint],
	@CCID [int],
	@DocDate [datetime],
	@VNO [nvarchar](max),
	@PostEach [bit],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @XML XML,@DocumentType INT,@I INT,@Cnt INT,@DOCNumber NVARCHAR(MAX),@CreditAccountID INT,@ConDate float,@docseq int
	,@AccDocDetails INT ,@status int,@CostCenterID INT,@IsDiscounted bit,@Columnname nvarchar(100),@dimWiseCurr int
	,@DebitAccountID INT,@oldPDCStatus int,@billwiseVNO nvarchar(200),@BillWiseDocType int,@sql nvarchar(max),@InterOnCDate nvarchar(50)
	DECLARE @DoCPrefix nvarchar(50),@ABBR nvarchar(50),@NewVoucherNO nvarchar(200),@retValue int,@NID BIGINT,@ExchRate float
	Declare @LocationID bigint,@DivisionID bigint,@Acc BIGINT,@Series int,@Action int,@PostedDate datetime,@PrefValue nvarchar(50)
	declare @vouNO nvarchar(200),@OldvouNO nvarchar(200),@seqno int,@oldstatus int,@Dupl bigint,@Dt float,@BillDate FLOAT,@NewBillDate FLOAT,@baseCurr int
	declare @temptype int ,@tempcr bigint,@tempdr bigint,@tempbid bigint,@PrefCheqReturn nvarchar(50),@Adb bigint,@penalty float,@Decimals nvarchar(10)
	DECLARE @AuditTrial BIT,@HistoryStatus nvarchar(50),@CCCols nvarchar(max),@NumCols nvarchar(max),@TextCols nvarchar(max),@IsReplace int,@IsHold bit,@LinkedDB BIGINT,@LinkedCr BIGINT
	declare @HoldDim int,@HoldDimID bigint,@HoldDateField nvarchar(20),@HoldDate nvarchar(20),@HoldDateRemarksField nvarchar(20),@HoldDateRemarks nvarchar(max)
	Declare @DocCol nvarchar(max),@TablCol nvarchar(max),@table nvarchar(max),@fid int,@dttemp datetime,@docOrder int,@refccid int,@refNodeid int
	Declare @PdcDoc nvarchar(max),@InterDOc nvarchar(max),@ConDoc nvarchar(max),@BounceDoc nvarchar(max),@clearonConvert bit,@refAccid bigint
	
	declare @preftble table(name nvarchar(200),value nvarchar(max),ccid int)
	insert into @preftble
	SELECT Name,Value,0 FROM ADM_GlobalPreferences WITH(NOLOCK) 
	WHERE name in('EnableCrossDimension','DimensionwiseCurrency','BaseCurrency','OnOpbConvert','OnOpbBounce','ClearonConvert','DecimalsinAmount','Intermediate PDC','IntermediatePDConConversionDate'
	,'PDCHoldDimension','PDCHoldDate','PDCHoldRemarks','enableChequeReturnHistory','Dont Change PDC Bank On Convert')
		
	set @dimWiseCurr=0
	select @dimWiseCurr=isnull(value,0) from @preftble 
	where  Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(bigint,value)>50000
	
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
	select @DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=@CCID						

	
	Declare @TBL TABLE(ID INT IDENTITY(1,1),AccDocDetailsID BIGINT,DocSeqNo int)

	insert into @TBL
	select AccDocDetailsID,DocSeqNo from ACC_DocDetails with(nolock) 
	where DOCID=@DocID and (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0)
	
	if(@PostEach=1)
	BEGIN

		select @I=0,@Cnt=count(*) from @TBL
		--select * from #TBL
		while(@I<@Cnt)
		Begin 
			set @I=@I+1
			select @Acc=AccDocDetailsID,@docseq=DocSeqNo from @TBL where ID=@I
		    set @DoCPrefix=''
			EXEC [sp_GetDocPrefix] '',@DocDate,@CCID,@DoCPrefix output,@Acc
						
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
				 
				
				
				--To Get Auto generate DocID
				INSERT INTO COM_DocID(DocNo,CompanyGUID,guid)
				VALUES(@NewVoucherNO,@CompanyGUID,newid())
				SET @DocID=@@IDENTITY
				
				if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=@CCID AND CodePrefix=@DocPrefix)    
				begin 
					 select  @LocationID=dcCCNID2,@DivisionID=dcCCNID1 from COM_DocCCData with(nolock) where AccDocDetailsID=@Acc
					 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
					 VALUES(@CCID,@CCID,@DocPrefix,1,1,1,1,Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    				 
				end   	
			 
			 
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,ChequeBookNo)
								 
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
										,369    
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
										,1    
										,[CurrencyID]    
										,[ExchangeRate] 
										,[AmountFC]   
										  
										,@UserName    
										,@Dt,@Dt,400,@Acc,ChequeBookNo										
										 from ACC_DocDetails with(nolock) where  AccDocDetailsID =@Acc

			set @AccDocDetails=@@IDENTITY
			
			update Com_Billwise
			set Docno=@NewVoucherNO,[DocSeqNo]=1
			where Docno=@VNO and [DocSeqNo]=@docseq
		
			if exists(select [DocID] from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc)
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,ChequeBookNo)
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
										,369    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,@AccDocDetails
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
										,@Dt,@Dt,400,@Acc,ChequeBookNo from ACC_DocDetails with(nolock) where  LinkedAccDocDetailsID =@Acc
										  
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
			
			set @sql=' INSERT INTO [COM_DocTextData]('+@TextCols+'[AccDocDetailsID]) select '+@TextCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocTextData]  WITH(NOLOCK)
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)  
						
		END
	END
	ELSE
	BEGIN
		 set @DoCPrefix=''
		 EXEC [sp_GetDocPrefix] '',@DocDate,@CCID,@DoCPrefix output,@Acc
						
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
				
			--To Get Auto generate DocID
			INSERT INTO COM_DocID(DocNo,CompanyGUID,guid)
			VALUES(@NewVoucherNO,@CompanyGUID,newid())
			SET @DocID=@@IDENTITY
			
			if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=@CCID AND CodePrefix=@DocPrefix)    
			begin 
				 select  @LocationID=dcCCNID2,@DivisionID=dcCCNID1 from COM_DocCCData with(nolock) where AccDocDetailsID=@Acc
				 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
				 VALUES(@CCID,@CCID,@DocPrefix,1,1,1,1,Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    				 
			end   
				
		update Com_Billwise
		set Docno=@NewVoucherNO
		where Docno=@VNO
				
		select @I=0,@Cnt=count(*) from @TBL
		--select * from #TBL
		while(@I<@Cnt)
		Begin 
			set @I=@I+1
			select @Acc=AccDocDetailsID,@docseq=DocSeqNo from @TBL where ID=@I
		   
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,ChequeBookNo)
								 
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
										,369    
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
										,@Dt,@Dt,400,@Acc,ChequeBookNo										
										 from ACC_DocDetails with(nolock) where  AccDocDetailsID =@Acc

			set @AccDocDetails=@@IDENTITY
			
		
		
			if exists(select [DocID] from ACC_DocDetails WITH(NOLOCK) where LinkedAccDocDetailsID=@Acc)
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
								 ,[CreatedDate],[ModifiedDate],RefCCID,RefNodeID,ChequeBookNo)
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
										,369    
										,[ChequeBankName]    
										,[ChequeNumber]    
										,[ChequeDate]    
										,[ChequeMaturityDate]   
										,[BillNo]    
										,BillDate    
										,@AccDocDetails
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
										,@Dt,@Dt,400,@Acc,ChequeBookNo from ACC_DocDetails with(nolock) where  LinkedAccDocDetailsID =@Acc
										  
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
			
			set @sql=' INSERT INTO [COM_DocTextData]('+@TextCols+'[AccDocDetailsID]) select '+@TextCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocTextData]  WITH(NOLOCK)
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)  
						
		END
	
	
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
