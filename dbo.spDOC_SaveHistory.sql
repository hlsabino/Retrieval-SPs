USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SaveHistory]
	@DocID [int],
	@HistoryStatus [nvarchar](500),
	@Ininv [bit],
	@ReviseReason [nvarchar](max),
	@LangID [int],
	@UserName [nvarchar](50) = NULL,
	@ModDate [float] = NULL,
	@CCID [int] = 0,
	@AP [varchar](10) = '',
	@sysinfo [nvarchar](max) = ''
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY        
SET NOCOUNT ON;  

if(@DocID=0)
	return @DocID
	
declare @NumCols nvarchar(max),@CC nvarchar(max),@txt nvarchar(max)
set @NumCols=''
set @CC=''
set @txt=''

if(@CCID=40054)	
	select @NumCols =@NumCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='Pay_DocNumData'
ELSE
	select @NumCols =@NumCols +a.name+',' from sys.columns a
	join sys.tables b on a.object_id=b.object_id
	where b.name='COM_DocNumData'

select @CC =@CC +a.name+',' from sys.columns a
join sys.tables b on a.object_id=b.object_id
where b.name='COM_DocCCData'

select @txt =@txt +a.name+',' from sys.columns a
join sys.tables b on a.object_id=b.object_id
where b.name='COM_DocTextData' and a.name not in('tCostCenterID','tDocumentType')


if(@Ininv=1)
BEGIN
	INSERT INTO [INV_DocDetails_History]    
		 ([InvDocDetailsID]    
		 ,[AccDocDetailsID]    
		 ,[DocID]    
		 ,[CostCenterID]    		     
		 ,[DocumentType]    
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
		 ,[BillDate]    
		 ,[LinkedInvDocDetailsID]    
		 ,[LinkedFieldName]    
		 ,[LinkedFieldValue]    
		 ,[CommonNarration]    
		 ,[LineNarration]    
		 ,[DebitAccount]    
		 ,[CreditAccount]    
		 ,[DocSeqNo]    
		 ,[ProductID]    
		 ,[Quantity]    
		 ,[Unit]    
		 ,[HoldQuantity]    
		 ,[ReleaseQuantity]    
		 ,[IsQtyIgnored]    
		 ,[IsQtyFreeOffer]    
		 ,[Rate]    
		 ,[AverageRate]    
		 ,[Gross]    
		 ,[StockValue]    
		 ,[CurrencyID]    
		 ,[ExchangeRate]    
		 ,[CompanyGUID]    
		 ,[GUID]    
		 ,[Description]    
		 ,[CreatedBy]    
		 ,[CreatedDate]    
		 ,[ModifiedBy]    
		 ,[ModifiedDate]    
		 ,[StockValueFC]    
		 ,[GrossFC]    
		 ,[UOMConversion]    
		 ,[UOMConvertedQty]    
		 ,[WorkflowID]    
			   ,[WorkFlowStatus]    
			   ,[WorkFlowLevel],RefCCID,RefNodeid,ReserveQuantity,DynamicInvDocDetailsID,HistoryStatus,ReviseReason,AP,SysInfo)    
	  SELECT [InvDocDetailsID]    
		 ,[AccDocDetailsID]    
		 ,[DocID]    
		 ,[CostCenterID]    		  
		 ,[DocumentType]    
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
		 ,[BillDate]    
		 ,[LinkedInvDocDetailsID]    
		 ,[LinkedFieldName]    
		 ,[LinkedFieldValue]    
		 ,[CommonNarration]    
		 ,[LineNarration]    
		 ,[DebitAccount]    
		 ,[CreditAccount]    
		 ,[DocSeqNo]    
		 ,[ProductID]    
		 ,[Quantity]    
		 ,[Unit]    
		 ,[HoldQuantity]    
		 ,[ReleaseQuantity]    
		 ,[IsQtyIgnored]    
		 ,[IsQtyFreeOffer]    
		 ,[Rate]    
		 ,[AverageRate]    
		 ,[Gross]    
		 ,[StockValue]    
		 ,[CurrencyID]    
		 ,[ExchangeRate]    
		 ,[CompanyGUID]    
		 ,[GUID]    
		 ,[Description]    
		 ,[CreatedBy]    
		 ,[CreatedDate]    
		 ,case when @UserName is null THEN [ModifiedBy] else @UserName end
		 ,case when @ModDate is null THEN [ModifiedDate] else @ModDate end		 
		 ,[StockValueFC]    
		 ,[GrossFC]    
		 ,[UOMConversion]    
		 ,[UOMConvertedQty]    
		 ,[WorkflowID]    
			   ,[WorkFlowStatus]    
			   ,[WorkFlowLevel],RefCCID,RefNodeid,ReserveQuantity,DynamicInvDocDetailsID,@HistoryStatus,@ReviseReason,case when @AP='' then AP ELSE @AP END,case when @sysinfo='' then sysinfo ELSE @sysinfo END
				FROM [INV_DocDetails] a WITH(NOLOCK)
				join COM_DOCID b WITH(NOLOCK) on a.DocID=b.id
				 WHERE DocID=@DocID    
	               
	
		 set @CC=' INSERT INTO [COM_DocCCData_History]('+@CC+'[ModifiedDate])
		 select  '+replace(replace(replace(@CC,'AccDocDetailsID,','a.AccDocDetailsID,'),'InvDocDetailsID,','a.InvDocDetailsID,'),',Remarks',',convert(nvarchar(max),Remarks)')
		
		 set @CC=@CC+'case when @ModDate is null THEN i.[ModifiedDate] else @ModDate end	 FROM [COM_DocCCData] a WITH(NOLOCK)
		 JOIN [INV_DocDetails] i WITH(NOLOCK) on a.[InvDocDetailsID] =i.[InvDocDetailsID]
		 WHERE  DocID='+convert(nvarchar,@DocID)	
		
		exec sp_executesql @CC,N'@ModDate float',@ModDate
		 
	  	 set @txt=' INSERT INTO [COM_DocTextData_History]('+@txt+'[ModifiedDate])
		 select  '+replace(replace(@txt,'AccDocDetailsID,','a.AccDocDetailsID,'),'InvDocDetailsID,','a.InvDocDetailsID,')
		
		 set @txt=@txt+'case when @ModDate is null THEN i.[ModifiedDate] else @ModDate end	 FROM [COM_DocTextData] a WITH(NOLOCK)
		 JOIN [INV_DocDetails] i WITH(NOLOCK) on a.[InvDocDetailsID] =i.[InvDocDetailsID]
		 WHERE  DocID='+convert(nvarchar,@DocID)	

		 exec sp_executesql @txt,N'@ModDate float',@ModDate
		
		if(@CCID=40054)	
		BEGIN
				set @NumCols=' INSERT INTO [PAY_DocNumData_History]('+@NumCols+'[ModifiedDate])
				select  '+replace(replace(replace(@NumCols,'AccDocDetailsID,','a.AccDocDetailsID,'),'InvDocDetailsID,','a.InvDocDetailsID,'),',Remarks',',convert(nvarchar(max),Remarks)')

				set @NumCols=@NumCols+'case when @ModDate is null THEN i.[ModifiedDate] else @ModDate end	 FROM [PAY_DocNumData] a WITH(NOLOCK)
				JOIN [INV_DocDetails] i WITH(NOLOCK) on a.[InvDocDetailsID] =i.[InvDocDetailsID]
				WHERE  DocID='+convert(nvarchar,@DocID)
		END
		ELSE	
		BEGIN			
			set @NumCols=' INSERT INTO [COM_DocNumData_History]('+@NumCols+'[ModifiedDate])
			select  '+replace(replace(replace(@NumCols,'AccDocDetailsID,','a.AccDocDetailsID,'),'InvDocDetailsID,','a.InvDocDetailsID,'),',Remarks',',convert(nvarchar(max),Remarks)')

			set @NumCols=@NumCols+'case when @ModDate is null THEN i.[ModifiedDate] else @ModDate end	 FROM [COM_DocNumData] a WITH(NOLOCK)
			JOIN [INV_DocDetails] i WITH(NOLOCK) on a.[InvDocDetailsID] =i.[InvDocDetailsID]
			WHERE  DocID='+convert(nvarchar,@DocID)
		END	
		--print(@NumCols)
		--print(substring(@NumCols,4001,4000))
		--print(substring(@NumCols,8001,4000))
		exec sp_executesql @NumCols,N'@ModDate float',@ModDate
END
ELSE
BEGIN
		INSERT INTO [ACC_DocDetails_History]
           ([AccDocDetailsID]
           ,[InvDocDetailsID]
           ,[DocID]
           ,[CostCenterID]           
           ,[DocumentType]
           ,[VoucherNo]
           ,[VersionNo]
           ,[DocAbbr]
           ,[DocPrefix]
           ,[DocNumber]
           ,[DocDate]
           ,[DueDate]
           ,[ChequeBankName]
           ,[ChequeNumber]
           ,[ChequeDate]
           ,[ChequeMaturityDate]
           ,[StatusID]
           ,[BillNo]
           ,[BillDate]
           ,[LinkedAccDocDetailsID]
           ,[CommonNarration]
           ,[LineNarration]
           ,[DocSeqNo]
           ,[DebitAccount]
           ,[CreditAccount]
           ,[Amount]
           ,[CurrencyID]
           ,[ExchangeRate]
           ,[CompanyGUID]
           ,[GUID]
           ,[Description]
           ,[CreatedBy]
           ,[CreatedDate]
           ,[ModifiedBy]
           ,[ModifiedDate]
           ,[IsNegative]
           ,[ClearanceDate]
           ,[BRS_Status]
           ,[AmountFC]
           ,[WorkflowID]
           ,[WorkFlowStatus]
           ,[WorkFlowLevel],RefCCID,RefNodeid,HistoryStatus,ReviseReason,ConvertedDate,AP,SysInfo,BankAccountID)
  SELECT [AccDocDetailsID]
           ,[InvDocDetailsID]
           ,[DocID]
           ,[CostCenterID]           
           ,[DocumentType]
           ,[VoucherNo]
           ,[VersionNo]
           ,[DocAbbr]
           ,[DocPrefix]
           ,[DocNumber]
           ,[DocDate]
           ,[DueDate]
           ,[ChequeBankName]
           ,[ChequeNumber]
           ,[ChequeDate]
           ,[ChequeMaturityDate]
           ,[StatusID]
           ,[BillNo]
           ,[BillDate]
           ,[LinkedAccDocDetailsID]
           ,[CommonNarration]
           ,[LineNarration]
           ,[DocSeqNo]
           ,[DebitAccount]
           ,[CreditAccount]
           ,[Amount]
           ,[CurrencyID]
           ,[ExchangeRate]
           ,[CompanyGUID]
           ,[GUID]
           ,[Description]
           ,[CreatedBy]
           ,[CreatedDate]
           ,case when @UserName is null THEN [ModifiedBy] else @UserName end
           ,case when @ModDate is null THEN [ModifiedDate] else @ModDate end
           ,[IsNegative]
           ,[ClearanceDate]
           ,[BRS_Status]
           ,[AmountFC]
           ,[WorkflowID]
           ,[WorkFlowStatus]
           ,[WorkFlowLevel],RefCCID,RefNodeid,@HistoryStatus,@ReviseReason,ConvertedDate,case when @AP='' then AP ELSE @AP END,case when @sysinfo='' then sysinfo ELSE @sysinfo END,BankAccountID 
           FROM [ACC_DocDetails] a WITH(NOLOCK)
           join COM_DOCID b WITH(NOLOCK) on a.DocID=b.id
             WHERE DocID=@DocID
          
          
         set @CC=' INSERT INTO [COM_DocCCData_History]('+@CC+'[ModifiedDate])
		 select  '+replace(replace(replace(@CC,'AccDocDetailsID,','a.AccDocDetailsID,'),'InvDocDetailsID,','a.InvDocDetailsID,'),',Remarks',',convert(nvarchar(max),Remarks)')
		
		 set @CC=@CC+'case when @ModDate is null THEN i.[ModifiedDate] else @ModDate end	 FROM [COM_DocCCData] a WITH(NOLOCK)
		 JOIN [ACC_DocDetails] i WITH(NOLOCK) on a.[AccDocDetailsID] =i.[AccDocDetailsID]
		 WHERE  DocID='+convert(nvarchar,@DocID)	
		
		exec sp_executesql @CC,N'@ModDate float',@ModDate
		 
	  	 set @txt=' INSERT INTO [COM_DocTextData_History]('+@txt+'[ModifiedDate])
		 select  '+replace(replace(@txt,'AccDocDetailsID,','a.AccDocDetailsID,'),'InvDocDetailsID,','a.InvDocDetailsID,')
		
		 set @txt=@txt+'case when @ModDate is null THEN i.[ModifiedDate] else @ModDate end	 FROM [COM_DocTextData] a WITH(NOLOCK)
		 JOIN ACC_DocDetails i WITH(NOLOCK) on a.[AccDocDetailsID] =i.[AccDocDetailsID]
		 WHERE  DocID='+convert(nvarchar,@DocID)	

		 exec sp_executesql @txt,N'@ModDate float',@ModDate
 
			 
		 set @NumCols=' INSERT INTO [COM_DocNumData_History]('+@NumCols+'[ModifiedDate])
		 select  '+replace(replace(replace(@NumCols,'AccDocDetailsID,','a.AccDocDetailsID,'),'InvDocDetailsID,','a.InvDocDetailsID,'),',Remarks',',convert(nvarchar(max),Remarks)')
			
		set @NumCols=@NumCols+'case when @ModDate is null THEN ac.[ModifiedDate] else @ModDate end
		 FROM [COM_DocNumData] a WITH(NOLOCK)
		 JOIN [ACC_DocDetails] ac WITH(NOLOCK) on ac.[AccDocDetailsID] =a.[AccDocDetailsID]
		 WHERE  DocID='+convert(nvarchar,@DocID)
		
		 exec sp_executesql @NumCols,N'@ModDate float',@ModDate


END     
     
COMMIT TRANSACTION
SET NOCOUNT OFF;        
RETURN @DocID
END TRY        
BEGIN CATCH  
  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
      
 
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
    
    
END CATCH
GO
