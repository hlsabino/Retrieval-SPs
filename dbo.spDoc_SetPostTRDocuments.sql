USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetPostTRDocuments]
	@SaveXML [nvarchar](max),
	@PostonConversionDate [bit],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @XML XML,@DocumentType INT,@TypeID INT,@CCID INT,@I INT,@Cnt INT,@DOCNumber INT,@CreditAccountID INT,@Amount float 
	,@AccDocDetails INT ,@status int,@DocID INT,@CostCenterID INT
	,@DebitAccountID INT,@oldPDCStatus int,@billwiseVNO nvarchar(200),@CCCols nvarchar(max),@NumCols nvarchar(max),@TextCols nvarchar(max),@BillWiseDocType int
	DECLARE @DoCPrefix nvarchar(50),@ABBR nvarchar(50),@Voucher nvarchar(50),@NewVoucherNO nvarchar(200),@sql nvarchar(max)
	Declare @LocationID INT,@DivisionID INT,@Acc INT,@Series BIT,@Action int,@PostedDate datetime,@PrefValue nvarchar(50)
	declare @vouNO nvarchar(200),@OldvouNO nvarchar(200),@seqno int,@oldstatus int,@Dupl INT
	declare @temptype int ,@tempcr INT,@tempdr INT,@tempbid INT,@PrefCheqReturn nvarchar(50) 
	
	
	
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

		SET @XML=@SaveXML
	  
			
		declare @TBL TABLE(ID INT IDENTITY(1,1),AccDocDetailsID INT,STATUS INT,PostedDate datetime,[Action] int,CreditAccountID INT,DebitAccountID INT,Dupl INT,Amount float)

		insert into @TBL
		select X.value('@ID','INT'),X.value('@StatusID','INT') ,X.value('@PostedDate','DATETIME'),X.value('@ACTION','int'),X.value('@CreditAccountID','INT'),X.value('@DebitAccountID','INT'),X.value('@Dupl','INT'),X.value('@Amount','float') from @XMl.nodes('/XML/Row') as Data(X)

		select @I=1,@Cnt=count(*) from @TBL
		while(@I<=@Cnt)
		Begin 
		
		 select @PostedDate=PostedDate,@status=STATUS,@Action=Action,@Acc=AccDocDetailsID,@CreditAccountID=CreditAccountID,@DebitAccountID=DebitAccountID,@Dupl=Dupl, @Amount=Amount from @TBL where ID=@I
		  
		 select @CostCenterID=costcenterid from ACC_DocDetails with(nolock) where AccDocDetailsID=(
		  select RefNodeid from ACC_DocDetails  with(nolock)
		  where AccDocDetailsID=@Acc) 
		  
		if(@Action=1)
		begin
			select @CCID=Convert(INT,isnull(prefvalue,0)),@Series=0 from com_documentpreferences with(nolock) where CostCenterID=@CostCenterID and prefname='TRCloseDocument'
			select @TypeID=DocumentTypeID,@DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=@CCID						
			set @status=369
		end 
		select @CCID,@CostCenterID,@Acc
		
		if(@Action=1)
		begin
		    select @tempcr=CreditAccount,@tempdr=DebitAccount,@temptype=DocumentType,@tempbid=BankAccountID from ACC_DocDetails with(nolock) where AccDocDetailsID=@Acc
			
			if(@CCID is null or  @CCID=0)
			BEGIN
				RAISERROR('-397',16,1)
			END

		end
		
		if(@Action=1 )
		begin
			--Inserting New DoC
			
		 	set	@DoCPrefix=''	
		    if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=@CCID AND CodePrefix=@DocPrefix)    
		    begin 
			 select  @LocationID=dcCCNID2,@DivisionID=dcCCNID1 from COM_DocCCData with(nolock) where AccDocDetailsID=@Acc
			 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
			 VALUES(@CCID,@CCID,@DocPrefix,1,1,1,1,Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    
			 set @DOCNumber=1
		    end   
			else
			begin		 
				set @DOCNumber=(select  CurrentCodeNumber+1 from Com_CostCenterCodeDef with(nolock) where CodePrefix=@DoCPrefix  and CostCenterID=@CCID)
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
			INSERT INTO COM_DocID(DocNo)
			VALUES(@NewVoucherNO)
			SET @DocID=@@IDENTITY
				 	 
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
								 ,[CreatedDate],RefCCID,RefNodeID)
								 
								 Select @DocID  
										,@CCID   
										,@DocumentType   
										,[VersionNo]    
										,@NewVoucherNO
										,@ABBR    
										,@DoCPrefix    
										,@DOCNumber  
										,convert(float,@PostedDate)
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
										,@CreditAccountID
										,@DebitAccountID    
										,@Amount   
										,IsNegative    
										,[DocSeqNo]    
										,1    
										,1 
										,@Amount   
										,[CreatedBy]    
										,[CreatedDate],400,@Acc from ACC_DocDetails with(nolock) where  AccDocDetailsID =@Acc

			set @AccDocDetails=@@IDENTITY
			
			
									  
			set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocCCData] b    WITH(NOLOCK) 
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)

			set @sql=' INSERT INTO [COM_DocCCData]('+@CCCols+'[AccDocDetailsID]) select '+@CCCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocCCData]  WITH(NOLOCK)
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)

			set @sql=' INSERT INTO [COM_DocNumData]('+@NumCols+'[AccDocDetailsID]) select '+@NumCols+convert(nvarchar,@AccDocDetails)+'
			FROM [COM_DocNumData]  WITH(NOLOCK)
			WHERE  AccDocDetailsID='+convert(nvarchar,@Acc)		
			exec(@sql)
			
		end	 
		
		set @I=@I+1;
		End

COMMIT TRANSACTION


 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	IF ERROR_NUMBER()=50000
	BEGIN
		if(ERROR_MESSAGE()=-373)
			SELECT ErrorMessage+@NewVoucherNO,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
