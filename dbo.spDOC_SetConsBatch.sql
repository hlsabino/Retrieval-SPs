USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetConsBatch]
	@InvID [bigint],
	@ExtraXML [xml],
	@IsQtyIgn [bit]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN

declare @xml xml,@I int,@Cnt int,@InvDocDetailsID bigint,@Dt float,@LinkedID bigint,@TotStockVal float,@ToTGross float,@ToTQty float,@sql nvarchar(max)
declare @chkNeg bit,@ProductID bigint,@vtype int,@CC nvarchar(max),@DocID bigint
declare @BatchID BIGINT,@Hold float,@Release float,@RefInvID BIGINT,@Quantity FLOAT,@stkVal float,@GrssVal float,@dec int,@UsedStockVal float,@UsedGross float
declare @tblList TABLE(ID int identity(1,1),BatchID BIGINT,Hold float,Release float,RefInvID BIGINT,Quantity FLOAT,LinkedID BIGINT,INVDocdetailsID BIGINT,StockVal float,Grssval float)


select  @TotStockVal=StockValue,@ToTGross=Gross,@ToTQty=Quantity,@vtype=vouchertype,@DocID=DocID	from INV_DOCDETAILS WITH(NOLOCK) WHERE InvDocDetailsID=@InvID

SET @xml=@ExtraXML

DECLARE @TblDelDynRows AS Table(ID BIGINT)
insert into @TblDelDynRows
SELECT InvDocDetailsID from [INV_DocDetails] with(nolock)
where DocID=@DocID and DynamicInvDocDetailsID is not null and DynamicInvDocDetailsID= @InvID   
and InvDocDetailsID NOT IN  (SELECT X.value('@DocDetailsID','bigint')    
from @xml.nodes('/EXTRAXML/xml/Row') as Data(X) where X.value('@DocDetailsID','BIGINT')>0)
 
if exists(select ID from @TblDelDynRows)
begin
		DELETE T FROM COM_DocCCData t
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID		

		--DELETE DOCUMENT EXTRA NUMERIC FEILD DETAILS      
		DELETE T FROM [COM_DocNumData] t
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID
			
		DELETE T FROM [COM_DocTextData] T
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID
		
		--DELETE Accounts DocDetails      
		DELETE T FROM [INV_DocDetails] T
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID 
end
	

set @Dt=convert(float,getdate())
set @CC=''

select @CC =@CC +a.name+'=c.'+a.name+',' from sys.columns a
join sys.tables b on a.object_id=b.object_id
where b.name='COM_DocCCData' and a.name not in ('InvDocDetailsID','DocCCDataID','AccDocDetailsID')
set @CC=substring(@CC,0,len(@CC))

INSERT INTO @tblList
select X.value('@BatchID','BIGINT'),isnull(X.value('@Hold','float'),0),isnull(X.value('@Release','float'),0)
,X.value('@RefInvID','BIGINT'),X.value('@Quantity','FLOAT'),X.value('@LinkedID','BIGINT'),isnull(X.value('@DocDetailsID','BIGINT'),0)
,0,0
from @xml.nodes('/EXTRAXML/xml/Row') as Data(X) 

set @dec=2

SELECT @I=0,@Cnt=COUNT(ID) FROM @tblList

set @UsedGross=0
set @UsedStockVal=0
WHILE(@I<@Cnt)      
BEGIN
   SET @I=@I+1
   SELECT @Release=Release,@Quantity=Quantity FROM @tblList WHERE ID=@I
   
   if(@Release=0 and @Hold=0 and @vtype=1)
	set @Release=@Quantity
   
   if(@I=@Cnt)
   BEGIN
	   set @stkVal=round(@TotStockVal-@UsedStockVal,@dec)
	   set @GrssVal=round(@ToTGross-@UsedGross,@dec)
   END
   ELSE
   BEGIN
	   set @stkVal=round(@Quantity/@ToTQty*@TotStockVal,@dec)
	   set @GrssVal=round(@Quantity/@ToTQty*@ToTGross,@dec)
	   set @UsedStockVal =@UsedStockVal+@stkVal
	   set @UsedGross=@UsedGross+@GrssVal
	   
   END
   
   update @tblList 
   set StockVal =@stkVal,Grssval=@GrssVal,Release=@Release
   WHERE ID=@I

END   
    
   
    INSERT INTO [INV_DocDetails]
         ([AccDocDetailsID]
         ,[DocID]    
         ,[CostCenterID]     
         ,[DocumentType],DocOrder    
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
         ,[CreatedDate],UOMConversion     
        ,UOMConvertedQty,WorkflowID , WorkFlowStatus , WorkFlowLevel,DynamicInvDocDetailsID,RefCCID,RefNodeid
        ,Account1,[BatchID]
					,BatchHold 
					,ReleaseQuantity 
					,RefInvDocDetailsID)  
        SELECT [AccDocDetailsID]
         ,[DocID]    
         ,[CostCenterID]             
         ,[DocumentType],DocOrder    
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
         ,LinkedID
         ,case when LinkedID>0 THEN 'Quantity' else NULL END
         ,case when LinkedID>0 THEN b.Quantity else NULL END         
         ,[CommonNarration]    
         ,LineNarration    
         ,[DebitAccount]    
         ,[CreditAccount]    
         ,ID
         ,[ProductID]    
         ,b.Quantity  
         ,[Unit]    
         ,[HoldQuantity]  
         ,[ReserveQuantity] 
         ,@IsQtyIgn    
         ,[IsQtyFreeOffer]    
         ,[Rate]    
         ,[AverageRate]            
         ,Grssval    
         ,StockVal    
         ,[CurrencyID]    
         ,[ExchangeRate]   
		 ,Grssval/ [ExchangeRate] 
		 ,StockVal/  [ExchangeRate]
         ,[CreatedBy]    
         ,[CreatedDate],UOMConversion     
         ,b.Quantity,WorkflowID , WorkFlowStatus , WorkFlowLevel,@InvID,RefCCID,RefNodeid
         ,Account1,b.BatchID,Hold,Release,RefInvID
      from [INV_DocDetails] a WITH(NOLOCK),@tblList b
      where a.[InvDocDetailsID]=@InvID and b.InvDocDetailsID=0
      
	
  UPDATE b
   SET 
       [VoucherType] = a.VoucherType
      ,[VersionNo] = a.VersionNo
      ,[DocDate] = a.DocDate
      ,[DueDate] = a.DueDate
      ,[StatusID] = a.StatusID
      ,[BillNo] = a.BillNo
      ,[BillDate] = a.BillDate
      ,[LinkedInvDocDetailsID] = LinkedID
      ,[LinkedFieldName] = case when LinkedID>0 THEN 'Quantity' else NULL END
      ,[LinkedFieldValue] = case when LinkedID>0 THEN c.Quantity else NULL END         
      ,[CommonNarration] = a.CommonNarration
      ,[LineNarration] = a.LineNarration
      ,[DebitAccount] = a.DebitAccount
      ,[CreditAccount] = a.CreditAccount
      ,[DocSeqNo] = ID
      ,[ProductID] = a.ProductID
      ,[Quantity] = c.Quantity
      ,[Unit] = a.Unit
      ,[HoldQuantity] = a.HoldQuantity
      ,[ReleaseQuantity] = Release
      ,[IsQtyIgnored] = @IsQtyIgn
      ,[IsQtyFreeOffer] = a.IsQtyFreeOffer
      ,[Rate] = a.Rate
      ,[AverageRate] = a.AverageRate      
      ,[CurrencyID] = a.CurrencyID
      ,[ExchangeRate] = a.ExchangeRate    
      ,[CreatedBy] = a.CreatedBy
      ,[CreatedDate] = a.CreatedDate
      ,[ModifiedBy] = a.ModifiedBy
      ,[ModifiedDate] = a.ModifiedDate      
      ,[UOMConversion] = a.UOMConversion
      ,[UOMConvertedQty] = c.Quantity
      ,[WorkflowID] = a.WorkflowID
      ,[WorkFlowStatus] = a.WorkFlowStatus
      ,[WorkFlowLevel] = a.WorkFlowLevel
      ,[DocOrder] = a.DocOrder            
      ,[RefCCID] = a.RefCCID
      ,[RefNodeid] = a.RefNodeid
      ,[LinkStatusID] = a.LinkStatusID
      ,[CancelledRemarks] = a.CancelledRemarks
      ,[LinkStatusRemarks] = a.LinkStatusRemarks
      ,[ParentSchemeID] = a.ParentSchemeID
      ,[RefNo] = a.RefNo
      ,[BatchID] = c.BatchID
      ,[BatchHold] = Hold
      ,[RefInvDocDetailsID] = RefInvID
    
      ,[ActDocDate] = a.ActDocDate      
      ,[Net] = a.Net 
      ,[Account1] = a.Account1 
      ,[StockValue]=StockVal	,[Gross]=Grssval
	   ,[GrossFC]  =Grssval/ a.[ExchangeRate]
		 ,[StockValueFC]= StockVal/  a.[ExchangeRate]     
	  from [INV_DocDetails] a WITH(NOLOCK)
	  join @tblList c on  c.InvDocDetailsID>0
	  join [INV_DocDetails] b on b.[InvDocDetailsID]=c.INVDocdetailsID
      where a.[InvDocDetailsID]=@InvID
      
		INSERT INTO [COM_DocCCData]([InvDocDetailsID])
		select a.[InvDocDetailsID] from [INV_DocDetails] a WITH(NOLOCK)
		join @tblList b on a.docseqno=b.id
		WHERE DynamicInvDocDetailsID=@InvID and b.InvDocDetailsID=0
		
		INSERT INTO [COM_DocNumData]([InvDocDetailsID])
		select a.[InvDocDetailsID] from [INV_DocDetails] a WITH(NOLOCK)
		join @tblList b on a.docseqno=b.id
		WHERE DynamicInvDocDetailsID=@InvID and b.InvDocDetailsID=0
		
		INSERT INTO [COM_DocTextData]([InvDocDetailsID])
		select a.[InvDocDetailsID] from [INV_DocDetails] a WITH(NOLOCK)
		join @tblList b on a.docseqno=b.id
		WHERE DynamicInvDocDetailsID=@InvID and b.InvDocDetailsID=0
 
		set @SQL='update b
		set '+@CC+'
		from [INV_DocDetails]  a WITH(NOLOCK)
		join [COM_DocCCData] b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
		join [COM_DocCCData] c WITH(NOLOCK) on c.InvDocDetailsID='+convert(nvarchar(20),@InvID) +'
		where a.DynamicInvDocDetailsID='+convert(nvarchar(20),@InvID) 
		print @sql
		exec (@sql)
END
GO
