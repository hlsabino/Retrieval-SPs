USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetDynamicSet]
	@DocID [int],
	@CostCenterID [int],
	@DocumentTypeID [int],
	@DocumentType [int],
	@DocOrder [int],
	@VoucherType [int],
	@VoucherNo [nvarchar](100),
	@VersionNo [int],
	@DocAbbr [nvarchar](50),
	@DocPrefix [nvarchar](50),
	@DocNumber [nvarchar](500),
	@DocDate [datetime],
	@DueDate [datetime],
	@StatusID [int],
	@BillNo [nvarchar](50),
	@BILLDate [float],
	@ACCOUNT1 [int],
	@ACCOUNT2 [int],
	@WID [int],
	@level [int],
	@CheckHold [bit],
	@DocXML [nvarchar](max),
	@DocDetailsID [int],
	@RefCCID [int],
	@RefNodeid [int],
	@chkNeg [bit],
	@AP [varchar](10),
	@CompanyGUID [nvarchar](50),
	@Guid [nvarchar](50),
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION            
BEGIN TRY            
SET NOCOUNT ON; 

declare @xml xml,@TRANSXML xml,@I int,@Cnt int,@InvDocDetailsID INT,@Dt float,@LinkedID INT,@TotLinkedQty float,@ToTValue float,@sql nvarchar(max),@accxml xml,@Extraxml xml
declare @ProductID INT,@loc int,@div int,@dim int,@IsQtyIgnored bit,@where nvarchar(max),@HRAsIssue bit,@CommAsRec bit,@SaveUnApp bit,@NID INT
declare @tblList TABLE(ID int identity(1,1),TRANSXML NVARCHAR(MAX),AccXML nvarchar(max))      
SET @xml=@DocXML


DECLARE @TblDelDynRows AS Table(ID INT)
insert into @TblDelDynRows
SELECT InvDocDetailsID from [INV_DocDetails] with(nolock)
where DocID=@DocID and DynamicInvDocDetailsID is not null and DynamicInvDocDetailsID= @DocDetailsID   
and InvDocDetailsID NOT IN  (SELECT X.value('@DocDetailsID','INT')    
from @xml.nodes('/EXTRAXML/xml/Row/xml') as Data(X) where X.value('@DocDetailsID','INT')>0)
 
if exists(select ID from @TblDelDynRows)
begin
		DELETE T FROM COM_DocCCData t with(nolock)
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID		

		--DELETE DOCUMENT EXTRA NUMERIC FEILD DETAILS      
		DELETE T FROM [COM_DocNumData] t with(nolock)
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID
			
		DELETE T FROM [COM_DocTextData] T with(nolock)
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID

		--DELETE Accounts DocDetails      
		DELETE T FROM [ACC_DocDetails] T with(nolock)
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID 
		
		--DELETE Accounts DocDetails      
		DELETE T FROM [INV_DocDetails] T with(nolock)
		join @TblDelDynRows a on t.InvDocDetailsID=a.ID 
end

	delete from @TblDelDynRows
	
	insert into @TblDelDynRows
	SELECT X.value('@DocDetailsID','INT')    
	from @xml.nodes('/EXTRAXML/xml/Row/xml') as Data(X) where X.value('@DocDetailsID','INT')>0
		
	DELETE T FROM [ACC_DocDetails] T with(nolock)
	join @TblDelDynRows a on t.InvDocDetailsID=a.ID

	
	if(@chkNeg=1 and @VoucherType=-1)
	BEGIN
		set @loc=0
		set @div=0
		set @dim=0
		set @CommAsRec=0
		set @HRAsIssue=0
		set @SaveUnApp=0
		
		if exists(select Value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='GNegativeUnapprove' and Value='true')
			set @SaveUnApp=1
		if exists(select Value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='ConsiderHoldAndReserveAsIssued' 
		and Value='true')
			set @HRAsIssue=1
		
		if exists(select Value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='ConsiderExpectedAsReceived' 
		and Value='true')
			set @CommAsRec=1
	 
		if exists(select Value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='EnableLocationWise' and Value='true')
		and exists(select Value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='Location Stock' and Value='true')		     
				set @loc=1 
		
		if exists(select Value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='EnableDivisionWise' and Value='true')
		and exists(select Value from ADM_GlobalPreferences WITH(NOLOCK) where  Name='Division Stock' and Value='true')		     
				set @div=1 
		      
		select @dim=convert(int,Value)-50000  from ADM_GlobalPreferences WITH(NOLOCK) where Name='Maintain Dimensionwise stock'        
		and ISNUMERIC(value)=1 and convert(int,Value)>50000

	END	
	
	
set @Dt=convert(float,getdate())
--Read XML data into temporary table only to delete records    
INSERT INTO @tblList    
SELECT CONVERT(NVARCHAR(MAX), X.query('xml')), CONVERT(NVARCHAR(MAX), X.query('AccountsXML'))
from @xml.nodes('/EXTRAXML/xml/Row') as Data(X)    
SELECT @I=0,@Cnt=COUNT(ID) FROM @tblList
 
WHILE(@I<@Cnt)      
BEGIN    
   SET @I=@I+1     	
   SELECT @TRANSXML=TRANSXML,@accxml=AccXML  FROM @tblList WHERE ID=@I      
 
      
   SELECT @InvDocDetailsID=ISNULL(X.value('@DocDetailsID','INT'),0)
   from @TRANSXML.nodes('/xml') as Data(X)    
   
    if(@CheckHold=1)
	begin
		declare @hld float,@QOH float,@HOLDQTY float,@RESERVEQTY float
		select @hld=ISNULL(X.value('@HoldQuantity','float'),0),@ProductID =ISNULL(X.value('@ProductID','INT') ,0)
		from @TRANSXML.nodes('/Transactions') as Data(X) 

		set @QOH=(SELECT isnull(sum(Quantity*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)      
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID      
		WHERE D.ProductID=@ProductID AND IsQtyIgnored=0 AND D.DocDate<=CONVERT(float,@DocDate)      
		and (VoucherType=-1 or VoucherType=1))       
 
		set @HOLDQTY=( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from 
		(SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.Quantity else l.ReserveQuantity end),0) release
		FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID 
		left join INV_DocDetails l  WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID
		WHERE D.ProductID=@ProductID AND D.IsQtyIgnored=1 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND D.DocDate<=CONVERT(float,@DocDate)   
		group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp)       


		set @RESERVEQTY=(  select  isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from 
		(SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.Quantity else l.ReserveQuantity end),0) release
		FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID 
		left join INV_DocDetails l  WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID
		WHERE D.ProductID=@ProductID AND D.IsQtyIgnored=1 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND D.DocDate<=CONVERT(float,@DocDate)
		group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp ) 

		if(@hld>(@QOH-@HOLDQTY-@RESERVEQTY))
		begin
			RAISERROR('-380',16,1)
		end
	
  end
   IF(@InvDocDetailsID=0)    
   BEGIN        
 
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
         ,[CreatedDate],UOMConversion     
        ,UOMConvertedQty,WorkflowID , WorkFlowStatus , WorkFlowLevel,DynamicInvDocDetailsID,RefCCID,RefNodeid
        ,Account1,AP)  
        SELECT X.value('@AccDocDetailsID','INT')    
         , @DocID    
         , @CostCenterID           
         , @DocumentType,@DocOrder  
         , case when @DocumentType=5 or @DocumentType=30 then X.value('@VoucherType','int') else  @VoucherType end  
         , @VoucherNo  
         , @VersionNo  
		 , @DocAbbr  
         , @DocPrefix    
         , @DocNumber    
         , CONVERT(FLOAT,@DocDate)    
         , CONVERT(FLOAT,@DueDate)    
         , @StatusID    
         , @BillNo    
         , @BILLDate    
         , X.value('@LinkedInvDocDetailsID','INT')    
         , X.value('@LinkedFieldName','nvarchar(200)')    
         , X.value('@LinkedFieldValue','float')    
         , X.value('@CommonNarration','nvarchar(max)')    
          , X.value('@LineNarration','nvarchar(max)')    
         ,ISNULL( X.value('@DebitAccount','INT'),@ACCOUNT1)      
       ,ISNULL(X.value('@CreditAccount','INT'),@ACCOUNT2)        
         , X.value('@DocSeqNo','int')    
          , X.value('@ProductID','INT')     
         , X.value('@Quantity','float')    
         ,ISNULL( X.value('@Unit','INT'),1)     
         ,ISNULL( X.value('@HoldQuantity','float'),0)   
         ,ISNULL( X.value('@ReserveQuantity','float'),0)    
         ,0 --Release Qyt          
         , ISNULL(X.value('@IsQtyIgnored','bit'),0)    
         , ISNULL(X.value('@IsQtyFreeOffer','bit'),0)    
         , X.value('@Rate',' float')    
         , ISNULL(X.value('@AverageRate','float'),0)    
         , ( X.value('@Gross',' float') * ISNULL(X.value('@ExchangeRate','float'),1) )   
         , ISNULL(X.value('@StockValue','float'),0)    
         , ISNULL(X.value('@CurrencyID','int'),1)    
         , ISNULL(X.value('@ExchangeRate','float'),1)  
   ,  X.value('@Gross',' float')  
   , ISNULL(X.value('@StockValueFC','float'),ISNULL(X.value('@StockValue','float'),0))                         
         , @UserName    
   , @Dt    
   , (select top 1 Conversion from COM_UOM with(nolock) where UOMID = ISNULL( X.value('@Unit','INT'),1))  --X.value('@UOMConversion','float')     
  , ((select top 1 Conversion from COM_UOM with(nolock) where UOMID = ISNULL( X.value('@Unit','INT'),1)) * X.value('@Quantity','float') ) --X.value('@UOMConvertedQty','INT')           
  ,@WID,@StatusID,@level,@DocDetailsID,@RefCCID,@RefNodeid 
  ,case when @DocumentType in(1,39,27,26,25,2,34,6,3,4,13,41,42) then ISNULL(X.value('@CreditAccount','INT'),1)  else ISNULL( X.value('@DebitAccount','INT'),1)   end
  ,@AP
      from @TRANSXML.nodes('/xml') as Data(X)    
    
		SET @InvDocDetailsID=@@IDENTITY    
      
		INSERT INTO [COM_DocCCData]([InvDocDetailsID])values(@InvDocDetailsID)

		INSERT INTO [COM_DocNumData]([InvDocDetailsID])values( @InvDocDetailsID)
  
   
     INSERT INTO [COM_DocTextData]    
        ([InvDocDetailsID] )values(@InvDocDetailsID)
  END    
  ELSE    
  BEGIN      
   
  
  UPDATE [INV_DocDetails]      
   SET     AccDocDetailsID=X.value('@AccDocDetailsID','INT')   
		,DynamicInvDocDetailsID=@DocDetailsID 
		,VoucherNo=@VoucherNo
         ,VersionNo=@VersionNo  
         ,DocDate= CONVERT(FLOAT,@DocDate)    
         ,DueDate= CONVERT(FLOAT,@DueDate)    
         ,StatusID= @StatusID    
         ,BillNo= @BillNo    
       ,BillDate=CONVERT(FLOAT,X.value('@BillDate','datetime'))    
         ,LinkedInvDocDetailsID= X.value('@LinkedInvDocDetailsID','INT')    
         ,LinkedFieldName=X.value('@LinkedFieldName','nvarchar(200)')    
         ,LinkedFieldValue= X.value('@LinkedFieldValue','float')    
         ,CommonNarration= X.value('@CommonNarration','nvarchar(max)')    
       ,LineNarration= X.value('@LineNarration','nvarchar(max)')    
         ,DebitAccount=ISNULL( X.value('@DebitAccount','INT'),@ACCOUNT1)    
         ,CreditAccount= ISNULL(X.value('@CreditAccount','INT'),@ACCOUNT2)    
         ,DocSeqNo= X.value('@DocSeqNo','int')    
         ,ProductID= X.value('@ProductID','INT')    
         ,Quantity= X.value('@Quantity','float')    
         ,Unit= X.value('@Unit','INT')    
         ,HoldQuantity=ISNULL( X.value('@HoldQuantity','float'),0)    
         ,ReserveQuantity=ISNULL( X.value('@ReserveQuantity','float'),0)            
         ,IsQtyIgnored= ISNULL(X.value('@IsQtyIgnored','bit'),0)    
         ,IsQtyFreeOffer= ISNULL(X.value('@IsQtyFreeOffer','bit'),0)    
         ,Rate= X.value('@Rate',' float')    
         ,AverageRate= ISNULL(X.value('@AverageRate','float'),0)    
         ,Gross= (X.value('@Gross',' float') * ISNULL(X.value('@ExchangeRate','float'),1) )   
   ,GrossFC=   X.value('@Gross',' float')   
         ,StockValue= ISNULL(X.value('@StockValue','float'),0)    
         ,CurrencyID=ISNULL(X.value('@CurrencyID','int'),1)    
         ,ExchangeRate= ISNULL(X.value('@ExchangeRate','float'),1)    
   ,StockValueFC=ISNULL(X.value('@StockValueFC','float'),X.value('@StockValue','float'))  
             
         ,ModifiedBy= @UserName    
         ,ModifiedDate= @Dt    
          ,UOMConversion  = (select top 1 Conversion from COM_UOM with(nolock) where UOMID = ISNULL( X.value('@Unit','INT'),0))  --X.value('@UOMConversion','float')     
   ,UOMConvertedQty =((select top 1 Conversion from COM_UOM with(nolock) where UOMID = ISNULL( X.value('@Unit','INT'),0)) * X.value('@Quantity','float') ) --X.value('@UOMConvertedQty','INT')           
           ,WorkflowID=@WID  
  , WorkFlowStatus =@StatusID  
  , WorkFlowLevel=@level 
  ,RefCCID=@RefCCID,RefNodeid =@RefNodeid 
  ,AP=@AP
  ,Account1=case when @DocumentType in(1,39,27,26,25,2,34,6,3,4,13,41,42) then ISNULL(X.value('@CreditAccount','INT'),1)  else ISNULL( X.value('@DebitAccount','INT'),1)   end
      from @TRANSXML.nodes('/xml') as Data(X)    
      WHERE InvDocDetailsID=@InvDocDetailsID    
     
   END 

	  set @sql=''
      SELECT @sql=X.value('@texQuery',' nvarchar(max)')
      from @TRANSXML.nodes('/xml') as Data(X)              
	  if(@sql<>'')
	  BEGIN
			set @sql= rtrim(@sql)
			set @sql=substring(@sql,0,len(@sql)- charindex(',',reverse(@sql))+1)

			set @sql='Update [COM_DocTextData] set '+@sql+' where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			exec(@sql)
	  END
	  
	  set @sql=''
      SELECT @sql=X.value('@CCQuery',' nvarchar(max)')
      from @TRANSXML.nodes('/xml') as Data(X)              
	  if(@sql<>'')
	  BEGIN
			set @sql= rtrim(@sql)
			set @sql=substring(@sql,0,len(@sql)- charindex(',',reverse(@sql))+1)

			set @sql='Update [COM_DocCCData] set '+@sql+' where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			exec(@sql)
	  END
	  
	  set @sql=''
      SELECT @sql=X.value('@NumQuery',' nvarchar(max)')
      from @TRANSXML.nodes('/xml') as Data(X)              
	  if(@sql<>'')
	  BEGIN
			set @sql= rtrim(@sql)
			set @sql=substring(@sql,0,len(@sql)- charindex(',',reverse(@sql))+1)

			set @sql='Update [COM_DocNumData] set '+@sql+' where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			exec(@sql)
	  END
	  
	  SELECT @Extraxml=X.value('@ExtraXML',' nvarchar(max)')
      from @TRANSXML.nodes('/xml') as Data(X) 
	  
	if(@Extraxml is not null)--BATCH WISE PRODUCT      
    BEGIN      
      --DECLARING TEMP VARIABLES            
		DECLARE @RefInvID INT,@Hold FLOAT,@Release FLOAT,@BATCHID INT,@Quantity float
	 
				select @BatchID=X.value('@BatchID','INT'),@Hold=X.value('@Hold','float'),@Release=X.value('@Release','float')
				,@RefInvID=X.value('@RefInvID','INT'),@Quantity=X.value('@Quantity','FLOAT')
				from @Extraxml.nodes('/xml/Row') as Data(X)
			 	
			if(@Hold is null)    
				set @Hold=0    
			if((@Release is null or @DocumentType=5) and @VoucherType=1)      
				set @Release=@Quantity    
			else if(@Release is null )    
				set @Release=0  
			
		   --- INSERTING VALUES INTO BATCH DETAILS       
		   update [INV_DocDetails]      
			set [BatchID]=@BATCHID      
			,BatchHold =@Hold     
			,ReleaseQuantity =@Release     
			,RefInvDocDetailsID=@RefInvID          
			WHERE InvDocDetailsID=@InvDocDetailsID
		            	  
			
   end -- Batch TYPE END      
   	  
	if(@chkNeg=1 and @VoucherType=-1)
	BEGIN
		 select @ProductID= X.value('@ProductID','INT')             
         ,@IsQtyIgnored= ISNULL(X.value('@IsQtyIgnored','bit'),0)    
        from @TRANSXML.nodes('/xml') as Data(X)
        
		if(@IsQtyIgnored=0 or (@IsQtyIgnored=1 and exists(select ISNULL( X.value('@HoldQuantity','float'),0)  from @TRANSXML.nodes('/xml') as Data(X)
		where ISNULL( X.value('@HoldQuantity','float'),0)>0 or ISNULL( X.value('@ReserveQuantity','float'),0)>0 )
		and @HRAsIssue=1))
		BEGIN
		
			set @WHERE=''
			if(@loc=1)
			BEGIN				
				set @sql='select @NID=dcCCNID2 from COM_DocCCData where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
									
				set @WHERE =@WHERE+' and dcCCNID2='+CONVERT(nvarchar,@NID)        
			END

			if(@div=1)
			BEGIN
				set @sql='select @NID=dcCCNID1 from COM_DocCCData where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
									
				set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@NID)        
			END
			
			if(@dim>0)
			BEGIN
				set @sql='select @NID=dcCCNID'+convert(nvarchar,@dim) +' from COM_DocCCData where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
				set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,@dim)+'='+CONVERT(nvarchar,@NID)        
			END
			
			set @ToTValue=0
			
			set @sql='set @ToTValue=(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID='+convert(nvarchar,@ProductID) 
			
			set @sql=@sql+' and DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))
			
			set @sql=@sql+' and D.StatusID=369 AND IsQtyIgnored=0 '+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
		    
		   
		    if  @HRAsIssue=1
			BEGIN
				set @sql=@sql+'set @ToTValue=@ToTValue-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0 then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1'
			
				set @sql=@sql+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				  
				 set @sql=@sql+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
				
				 set @sql=@sql+'set @ToTValue=@ToTValue-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0 then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1'
				 
				set @sql=@sql+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				  
				 set @sql=@sql+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
			 END
			
		  
		    if @CommAsRec=1			
			BEGIN			 
				 set @sql=@sql+'set @ToTValue=@ToTValue+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when LDCC.InvDocDetailsID is not null and l.IsQtyIgnored=0 then l.UOMConvertedQty when LDCC.InvDocDetailsID is not null then l.ReserveQuantity else 0 end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+
				 ' WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1'
				 
				set @sql=@sql+' and D.DocDate<='+CONVERT(nvarchar,convert(float,@DocDate))

				  
				 set @sql=@sql+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
			END
			 
			EXEC sp_executesql @sql, N'@ToTValue float OUTPUT', @ToTValue OUTPUT   
			
			if(@ToTValue<-0.001)
			BEGIN
				if(@SaveUnApp=1)
				BEGIN
					set @StatusID=371
					
					UPDATE INV_DocDetails
					set StatusID=371
					where DocID=@DocID and CostCenterID=@CostCenterID
				END	
				ELSE
				BEGIN	
					SELECT @where=ProductName FROM INV_Product a WITH(NOLOCK)    
					WHERE  ProductID=@ProductID     
					RAISERROR('-407',16,1)
				END	
			END
		END			
	END
	
	
	IF(@accxml IS NOT NULL)
   BEGIN 
		
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
         , CONVERT(FLOAT,@DocDate)      
         , CONVERT(FLOAT,@DueDate)      
         , @StatusID      
         , @BillNo      
         , @BILLDate      
         , X.value('@CommonNarration','nvarchar(max)')      
         , X.value('@LineNarration','nvarchar(max)')               
         ,ISNULL( X.value('@DebitAccount','INT'),0)
         ,ISNULL( X.value('@CreditAccount','INT'),0) 
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
         , @RefNodeid   ,@AP
           from @accxml.nodes('/AccountsXML/Accounts') as Data(X)  
      
   END      
   
    
    
END
COMMIT TRANSACTION           
SET NOCOUNT OFF;          
RETURN 1          
END TRY          
BEGIN CATCH            
  --Return exception info [Message,Number,ProcedureName,LineNumber]            
  IF ERROR_NUMBER()=50000          
  BEGIN          
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID          
  END  
   ELSE IF (ERROR_MESSAGE() LIKE '-407')     
 BEGIN      
  SELECT ErrorMessage + @where  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END   
        
  ELSE          
  BEGIN          
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine          
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID          
  END          
ROLLBACK TRANSACTION          
SET NOCOUNT OFF            
RETURN -999             
END CATCH    
GO
