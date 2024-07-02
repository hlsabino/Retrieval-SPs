USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_PostBillWiseDetails]
	@AccountID [int] = 0,
	@IsCredit [bit],
	@VoucherNo [nvarchar](500),
	@DocSeqNo [int],
	@Docdate [datetime],
	@CostCenterID [int],
	@DocDetailsID [int],
	@BillWiseXml [nvarchar](max),
	@FromDocNo [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
SET NOCOUNT ON
BEGIN TRY 
   
		DECLARE @docType int,@IsInv bit,@i int ,@CNT int,@dt float,@DueDate float,@crAcc INT,@drAcc INT
		DECLARE @amt float,@billamt float,@StatusID int,@EXTRAXML xml,@CC nvarchar(max),@sql nvarchar(max),@CCCols nvarchar(max)
		
		set @CCCols=''
		select @CCCols =@CCCols +','+a.name from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='COM_DocCCData'  and a.name like '%ccnid%'

		--SP Required Parameters Check
		IF @AccountID=0
		BEGIN
			RAISERROR('-100',16,1)
		END
		set @EXTRAXML=@BillWiseXml
		
		set @CC=''
		set @CC='update Com_Billwise set '
		select @CC =@CC +a.name+'=a.'+a.name+',' from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='COM_DocCCData' and a.name like 'dcCCNID%'
		set @CC=substring(@CC,0,len(@CC))+' from [COM_DocCCData] a with(nolock) '
		
		set @dt=CONVERT(float,getdate())
		
		if(@FromDocNo is not null and @FromDocNo<>'' and not exists(select name from sys.columns where name='FromDocNo' and object_id=object_id('COM_Billwise')))
		BEGIN
			alter table [COM_Billwise] add FromDocNo nvarchar(200)
		END
		
		select @docType=DocumentType,@IsInv=IsInventory from ADM_DocumentTypes WITH(NOLOCK)
		where CostCenterID=@CostCenterID
		
		if(@IsInv=1)
		BEGIN
		
		
			select @amt=isnull(SUM(AdjAmount),0) FROM [COM_Billwise] WITH(NOLOCK)     
			WHERE [DocNo]=@VoucherNo AND DocSeqNo=@DOCSEQNO and AccountID=@AccountID
			
			if(@amt is null or @amt=0)
				RAISERROR('-503',16,1)
				
			if(@amt<0 and @IsCredit=0)
				RAISERROR('-503',16,1)
				
			if(@amt>0 and @IsCredit=1)
				RAISERROR('-503',16,1)
				
			SELECT   @billamt=sum(CONVERT(float,replace(X.value('@AdjAmount','nvarchar(50)'),',','')))
			from @EXTRAXML.nodes('/BillWise/Row') as Data(X)    
			
			if((abs(@billamt)-abs(@amt))>0.01 or (abs(@amt)-abs(@billamt))>0.01)
			BEGIN
				RAISERROR('-504',16,1)
			END
					
			select @DueDate=DueDate,@StatusID=StatusID,@drAcc=InvDocDetailsID from INV_DocDetails WITH(NOLOCK)
			where VoucherNo=@VoucherNo
			
			DELETE FROM [COM_Billwise]     
			WHERE [DocNo]=@VoucherNo AND DocSeqNo=@DOCSEQNO and AccountID=@AccountID
		
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
       , CONVERT(FLOAT,@DueDate)    
       , 1,@StatusID, X.value('@RefStatusID','int')        
       , X.value('@AccountID','INT')        
		, replace(X.value('@AdjAmount','nvarchar(50)'),',','')
       , X.value('@AdjCurrID','int')    
       , X.value('@AdjExchRT','float')    , replace(X.value('@AmountFC','nvarchar(50)'),',','')
       , @docType    
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
     from @EXTRAXML.nodes('/BillWise/Row') as Data(X)    
   
     
     	 set @sql=@CC+' where docno='''+@VoucherNo+''' and InvDocDetailsID='+convert(nvarchar(max),@drAcc)
		 print @sql
		  exec(@sql)
		  
		 if(@FromDocNo is not null and @FromDocNo<>'')
		 BEGIN
			 set @sql='update  [COM_Billwise] set FromDocNo='''+@FromDocNo+''' where docno='''+@VoucherNo+''''
			exec(@sql)
		END	
	END
	ELSE
	BEGIN
		select @DueDate=DueDate,@StatusID=StatusID,@crAcc=CreditAccount,@drAcc=DebitAccount,@DOCSEQNO=DOCSEQNO from ACC_DocDetails WITH(NOLOCK)
		where AccDocDetailsID=@DocDetailsID
		
		if(@IsCredit=1 and @crAcc<>@AccountID)
		BEGIN
			RAISERROR('-503',16,1)
		END
		
		if(@IsCredit=0 and @drAcc<>@AccountID)
		BEGIN
			RAISERROR('-503',16,1)
		END
			
		select @amt=isnull(SUM(AdjAmount),0) FROM [COM_Billwise] WITH(NOLOCK)     
		WHERE [DocNo]=@VoucherNo AND DocSeqNo=@DOCSEQNO		
		
		SELECT   @billamt=sum(CONVERT(float,replace(X.value('@AdjAmount','nvarchar(50)'),',','')))
		from @EXTRAXML.nodes('/BillWise/Row') as Data(X)    
		
		if((abs(@billamt)-abs(@amt))>0.01 or (abs(@amt)-abs(@billamt))>0.01)
		BEGIN
			RAISERROR('-504',16,1)
		END
		
		DELETE FROM [COM_Billwise]     
		WHERE [DocNo]=@VoucherNo AND DocSeqNo=@DOCSEQNO
		
		DELETE FROM [COM_BillWiseNonAcc]
		WHERE [DocNo]=@VoucherNo AND DocSeqNo=@DOCSEQNO

		set @sql='INSERT INTO [COM_Billwise]    
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
       ,[IsDocPDC]    
       '+@CCCols+')    
     SELECT '''+convert(nvarchar(max),@VoucherNo)+'''
       , '+convert(nvarchar(max),CONVERT(FLOAT,@DocDate))+'    
       , '+isnull(convert(nvarchar(max),CONVERT(FLOAT,@DueDate)),'NULL')+'       
       , '+convert(nvarchar(max),@DOCSEQNO)+','+convert(nvarchar(max),@StatusID)+', X.value(''@RefStatusID'',''int'')        
       , X.value(''@AccountID'',''INT'')        
		, replace(X.value(''@AdjAmount'',''nvarchar(50)''),'','','''')
       , X.value(''@AdjCurrID'',''int'')    
       , X.value(''@AdjExchRT'',''float'')    , replace(X.value(''@AmountFC'',''nvarchar(50)''),'','','''')
       ,'+convert(nvarchar(max), @docType)+'
       , X.value(''@IsNewReference'',''bit'')    
       , X.value(''@RefDocNo'',''nvarchar(200)'')    
       , X.value(''@RefDocSeqNo'',''int'')    
       , CONVERT(FLOAT,X.value(''@RefDocDate'',''DATETIME''))    
       , CONVERT(FLOAT,X.value(''@RefDocDueDate'',''DATETIME''))    
       , X.value(''@RefBillWiseID'',''INT'')    
       , X.value(''@DiscAccountID'',''INT'')    
       , X.value(''@DiscAmount'',''float'')    
       , X.value(''@DiscCurrID'',''int'')    
       , X.value(''@DiscExchRT'',''float'')    
       , X.value(''@Narration'',''nvarchar(max)'')    
       , X.value(''@IsDocPDC'',''bit'')    
      '+@CCCols+'
     from @EXTRAXML.nodes(''/BillWise/Row'') as Data(X)    
     join [COM_DocCCData] d  WITH(NOLOCK) on d.AccDocDetailsID='+convert(nvarchar(max),@DocDetailsID) 
     
     EXEC sp_executesql @sql,N'@EXTRAXML XML',@EXTRAXML
     
     insert into COM_BillWiseNonAcc(DocNo,DocSeqNo,RefDocNO,Amount,Narration)
     SELECT @VoucherNo,@DOCSEQNO,X.value('@RefDocNo','nvarchar(200)')
       , X.value('@Amount','float') , X.value('@Narration','nvarchar(max)')
     from @EXTRAXML.nodes('/BillWise/NonAccRows') as Data(X)    
       
		END
		
 COMMIT TRANSACTION

 SELECT   ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    

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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	
ROLLBACK TRANSACTION    
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
