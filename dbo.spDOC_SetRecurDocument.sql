USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetRecurDocument]
	@CostCenterID [int],
	@RecurDocID [int],
	@DocDate [datetime],
	@RecurMethod [tinyint],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1,
	@VoucherNo [nvarchar](100) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;    
  --Declaration Section    
  DECLARE @Dt float,@DocID INT,@DocumentTypeID INT,@DocumentType INT,@DocAbbr nvarchar(50),@tempDOc INT,@guid nvarchar(50)
  DECLARE @AccDocDetailsID INT,@I int,@Cnt int,@HistoryStatus nvarchar(50),@PrefValue nvarchar(50),@CrAccount INT,@BWSign int
  DECLARE @Length int,@temp varchar(100),@t int,@cctablename nvarchar(50),@DUPLICATECODE  NVARCHAR(MAX)     
  declare  @Dimesion INT,@DimesionNodeID INT,@DocOrder int,@TEMPxml nvarchar(max),@NumCols nvarchar(max),@CCCols nvarchar(max),@TexCols nvarchar(max),@CCBWCols nvarchar(max)
		
	set @TexCols=''
	select @TexCols =@TexCols +','+a.name from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocTextData'  and a.name not in('AccDocDetailsID','INVDocDetailsID','DocTextDataID')
	
	set @CCCols=''
	select @CCCols =@CCCols +','+a.name from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocCCData'  and a.name not in('AccDocDetailsID','INVDocDetailsID','DocCCDataID')
	
	set @NumCols=''
	select @NumCols =@NumCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocNumData'  and a.name not in('AccDocDetailsID','DocNumDataID')

	set @CCBWCols=''
	select @CCBWCols =@CCBWCols +','+a.name from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_Billwise'  and a.name LIKE 'dcCCNID%'

	declare @DocNumber nvarchar(200),@DocPrefix nvarchar(200),@RecurAccID INT,@RecuVoucherNo nvarchar(200)
 	set @Dt=convert(float,getdate())

    if(@DocID=0)
		set @HistoryStatus='Add'
	else
		set @HistoryStatus='Update'
	
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
	where CostCenterID=@CostCenterID and PrefName='DocumentLinkDimension'    

	if(@PrefValue is not null and @PrefValue<>'')    
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
   
  SELECT @DocumentTypeID=DocumentTypeID,@DocumentType=DocumentType,@DocAbbr=DocumentAbbr,@DocOrder=DocOrder   
  FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID    
     
	 
  --Create temporary table to read xml data into table    
  declare @tblList TABLE (ID int identity(1,1),AccID INT)      
      
   --Read XML data into temporary table only to delete records    
  INSERT INTO @tblList    
  SELECT     AccDocDetailsID from ACC_DocDetails WITH(NOLOCK) 
	where DocID=@RecurDocID
       
	--Set loop initialization varaibles    
	SELECT @I=1, @Cnt=count(*) FROM @tblList     
	 
 
 	--SELECT @DocID=ISNULL(MAX(DocID),0)+1 FROM ACC_DocDetails    WITH(HOLDLOCK) 
 	
 	--/DocumentXML/Row/CostCenters
 	
 	--select * from ADM_Features
 	--@DUPLICATECODE

	if exists(select * from COM_DocPrefix with(nolock) where DocumentTypeID=@DocumentTypeID and (CCID=51 or CCID=52 or CCID=53 or CCID=54))
	begin
		declare @TblCC as Table(ID int identity(1,1), CCID int)
		insert into @TblCC
		select C.CostCenterID from COM_DocPrefix P with(nolock)
		join adm_costcenterdef C with(nolock) on C.costcentercolid=P.CCID
		where DocumentTypeID=@DocumentTypeID and CCID!=51 and CCID!=52 and CCID!=53 and C.CostCenterID>50000
		group by C.CostCenterID
		set @TEMPxml=''		
		select @I=1,@Length=count(*) from @TblCC
		while @I<=@Length
		begin
			select @DUPLICATECODE='SELECT @t=DCC.dcCCNID'+convert(nvarchar,CCID-50000)+' from ACC_DocDetails D WITH(NOLOCK)
 			join COM_DocCCDATA DCC with(nolock) on DCC.AccDocDetailsID=D.AccDocDetailsID
			where DocID='+convert(nvarchar,@RecurDocID)
			from @TblCC where ID=@I
			exec sp_executesql @DUPLICATECODE,N'@t int OUTPUT',@t OUTPUT 
			select @TEMPxml=@TEMPxml+'dcCCNID'+convert(nvarchar,CCID-50000)+'='+convert(nvarchar,@t)+',' from @TblCC where ID=@I
			set @I=@I+1
		end
		if(@TEMPxml!='')
			set @TEMPxml='<DocumentXML><Row CostCenters="'+@TEMPxml+'"/></Row></DocumentXML>'
		EXEC [sp_GetDocPrefix] @TEMPxml,@DocDate,@CostCenterID,@DocPrefix output,0,0,0
		select @DocPrefix
 	end
	else
	begin
		SELECT @DocPrefix=DocPrefix,@RecuVoucherNo=VoucherNo from ACC_DocDetails WITH(NOLOCK) 
		where DocID=@RecurDocID
    end
    if @DocPrefix is null
		set @DocPrefix=''
    if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef  WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix)    
	begin
		select @DocNumber=PrefValue from com_documentpreferences with(nolock) where CostCenterID=@CostCenterID 
		and PrefName='StartNoForNewPrefix' and PrefValue is not null and isnumeric(PrefValue)=1

		INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
		VALUES(@CostCenterID,@CostCenterID,@DocPrefix,CONVERT(INT,@DocNumber),1,CONVERT(INT,@DocNumber),len(@DocNumber),Newid(),@UserName,convert(float,getdate()),1,1)    
	end
	else
	begin
		SELECT  @tempDOc=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1)  FROM COM_CostCenterCodeDef WITH(NOLOCK) --AS CurrentCodeNumber    
		WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix    
		 
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
	end
       
	SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')  
	set @guid=newid()  
     --select @VoucherNo
	
	--To Get Auto generate DocID
	INSERT INTO COM_DocID(DocNo,CompanyGUID,guid)
	VALUES(@VoucherNo,@CompanyGUID,@guid)
	SET @DocID=@@IDENTITY
	
	--Set loop initialization varaibles    
	SELECT @I=1, @Cnt=count(*) FROM @tblList     
   
  WHILE(@I<=@Cnt)      
  BEGIN		
    
   SELECT @RecurAccID=AccID from  @tblList WHERE ID=@I
   SET @I=@I+1	
   	      
    INSERT INTO ACC_DocDetails    
         ([DocID]    
         ,[CostCenterID]             
         ,[DocumentType],DocOrder   
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
         ,[CreatedDate] ,[ModifiedBy]  
     ,[ModifiedDate],WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID ,RefNodeid,BankAccountID,ChequeBookNo)    
          
        SELECT @DocID    
         , @CostCenterID              
          , @DocumentType,@DocOrder   
         , 1  
         , @VoucherNo    
         , @DocAbbr    
         , @DocPrefix    
         , @DocNumber    
         , CONVERT(FLOAT,@DocDate)    
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
         , @UserName    
         , @Dt, @UserName    
         , @Dt,WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID ,RefNodeid,BankAccountID,ChequeBookNo
		  from ACC_DocDetails WITH(NOLOCK) where AccDocDetailsID =@RecurAccID
		   SET @AccDocDetailsID=@@IDENTITY
	
	if @RecurMethod=2
	begin
		select @CrAccount=CreditAccount from ACC_DocDetails with(nolock) where AccDocDetailsID=@AccDocDetailsID
		update ACC_DocDetails set CreditAccount=DebitAccount where AccDocDetailsID=@AccDocDetailsID
		update ACC_DocDetails set DebitAccount=@CrAccount where AccDocDetailsID=@AccDocDetailsID
	end

	    set @DUPLICATECODE='INSERT INTO [COM_DocCCData]    
       ([AccDocDetailsID]'+@CCCols+')
          SELECT '+convert(nvarchar(max),@AccDocDetailsID)+@CCCols+'
      from [COM_DocCCData] WITH(NOLOCK) where   AccDocDetailsID ='+convert(nvarchar(max),@RecurAccID) 
	  
     exec(@DUPLICATECODE)
     
	 
     	set @DUPLICATECODE=' INSERT INTO [COM_DocNumData]('+@NumCols+'[AccDocDetailsID])select  '+@NumCols+convert(nvarchar,@AccDocDetailsID)+'
		 FROM [COM_DocNumData]  WITH(NOLOCK)
		 WHERE  AccDocDetailsID='+convert(nvarchar,@RecurAccID)		
		 
		exec(@DUPLICATECODE)
		
      set @DUPLICATECODE='INSERT INTO [COM_DocTextData]    
       ([AccDocDetailsID]'+@TexCols+')
          SELECT '+convert(nvarchar(max),@AccDocDetailsID)+@TexCols+'
      from [COM_DocTextData] WITH(NOLOCK) where   AccDocDetailsID ='+convert(nvarchar(max),@RecurAccID) 
	  
     exec(@DUPLICATECODE)
    
   END
 

if @RecurMethod=2
	set @BWSign=-1
else
	set @BWSign=1
	
 set @DUPLICATECODE='INSERT INTO [COM_Billwise]    
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
       ,[RefBillWiseID]    
       ,[DiscAccountID]    
       ,[DiscAmount]    
       ,[DiscCurrID]    
       ,[DiscExchRT]    
       ,[Narration]    
       ,[IsDocPDC]'+@CCBWCols+')    
     SELECT '''+convert(nvarchar(max),@VoucherNo)+'''    
       , '+convert(nvarchar(max),CONVERT(FLOAT,@DocDate))+'
       , NULL
       , [DocSeqNo]   
       , [AccountID]
       ,[AdjAmount]*'+convert(nvarchar(max),@BWSign)+'
       ,[AdjCurrID]    
       ,[AdjExchRT],AmountFC*'+convert(nvarchar(max),@BWSign)+'
       , '+convert(nvarchar(max),@DocumentType)+'
       , 1
       , NULL
       , NULL
       , NULL
       , NULL
       , 0
       , DiscAccountID
       , DiscAmount*'+convert(nvarchar(max),@BWSign)+'
       , DiscCurrID
       , DiscExchRT
       , Narration
       , IsDocPDC
      '+@CCBWCols+'
     from [COM_Billwise]   WITH(NOLOCK) 
     WHERe DOCNO='''+convert(nvarchar(max),@RecuVoucherNo)+''''
     
	 exec(@DUPLICATECODE)
     
     
--CHECK AUDIT TRIAL ALLOWED AND INSERTING AUDIT TRIAL DATA
DECLARE @AuditTrial BIT
SET @AuditTrial=0
SELECT @AuditTrial=CONVERT(BIT,PrefValue)  FROM [COM_DocumentPreferences] WITH(NOLOCK) 
WHERE CostCenterID=@CostCenterID AND PrefName='AuditTrial'

SET @PrefValue=''    
SELECT @PrefValue=PrefValue  FROM [COM_DocumentPreferences] WITH(NOLOCK)     
WHERE CostCenterID=@CostCenterID AND PrefName='EnableRevision' 
    
IF (@AuditTrial=1 or @PrefValue='true')  
BEGIN 
	 EXEC [spDOC_SaveHistory]      
		@DocID =@DocID ,
		@HistoryStatus=@HistoryStatus,
		@Ininv =1,
		@ReviseReason ='',
		@LangID =@LangID
END
  
  
  if(@Dimesion>0)    
  begin 
		if(@DimesionNodeID is null or @DimesionNodeID<=0)
		BEGIN
				SET @TEMPxml='<XML><Row AccountName ="'+replace(@VoucherNo,'&','&amp;')+'" AccountCode ="'+replace(@VoucherNo,'&','&amp;')+'"  ></Row></XML>'      
				
				EXEC @DimesionNodeID = [dbo].[spADM_SetImportData]      
				@XML = @TEMPxml,      
				@COSTCENTERID = @Dimesion,      
				@IsDuplicateNameAllowed = 1,      
				@IsCodeAutoGen = 0,      
				@IsOnlyName = 1,      
				@CompanyGUID = @CompanyGUID,      
				@UserName = @UserName ,      
				@UserID = @UserID,
				@RoleID =1,
				@LangID = @LangID  
				
				set @DimesionNodeID=0						
				select @cctablename=tablename from ADM_Features where FeatureID=@Dimesion
				set @DUPLICATECODE='select @NodeID=NodeID from '+@cctablename+' WITH(NOLOCK) where Name='''+@VoucherNo+''''				
				EXEC sp_executesql @DUPLICATECODE,N'@NodeID INT OUTPUT',@DimesionNodeID output
		END
		
		if(@DimesionNodeID>0)
		BEGIN
			SET @DUPLICATECODE='UPDATE COM_DocCCData 
			SET dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@DimesionNodeID)
			+' WHERE AccDocDetailsID IN (SELECT AccDocDetailsID FROM ACC_DocDetails 
			WHERE COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND DOCID='+CONVERT(NVARCHAR,@DocID)+')'
			EXEC(@DUPLICATECODE)
		END		     
 end   
 
	set @Dimesion=0
	select @Dimesion=isnull(value,0) from Adm_globalPreferences with(nolock)
	where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
	
	if(@Dimesion>0)
	BEGIN
	
		set @DUPLICATECODE='select @DimesionNodeID=dcCCNID'+convert(nvarchar,(@Dimesion-50000))+' from COM_DocCCData  WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@AccDocDetailsID)
		
		EXEC sp_executesql @DUPLICATECODE, N'@DimesionNodeID float OUTPUT', @DimesionNodeID OUTPUT   
		
		SELECT @tempDOc=Value FROM Adm_globalPreferences with(nolock) WHERE Name='BaseCurrency'
		
		SELECT @PrefValue=Value FROM Adm_globalPreferences with(nolock) WHERE Name='DecimalsinAmount'
		
		SELECT @Dt=ExchangeRate  FROM  COM_EXCHANGERATES WITH(NOLOCK) 
		where CurrencyID = @tempDOc AND EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
		and DimNodeID=@DimesionNodeID ORDER BY EXCHANGEDATE DESC
		
		set @DUPLICATECODE='update ACC_DocDetails
			set AmountBC=round(Amount/'+convert(nvarchar,@Dt)+','+@PrefValue+'),ExhgRtBC='+convert(nvarchar,@Dt)+'
			where CostCenterID='+convert(nvarchar,@CostCenterID)+' and DocID='+convert(nvarchar,@DocID)+'
			
			update COM_Billwise 
			set AmountBC=round(AdjAmount/'+convert(nvarchar,@Dt)+','+@PrefValue+'),ExhgRtBC='+convert(nvarchar,@Dt)+'
			where DocNo='''+@VoucherNo+''''
		
		exec(@DUPLICATECODE)
		
	END
  
	
COMMIT TRANSACTION 
SET NOCOUNT OFF;        
RETURN @DocID
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
