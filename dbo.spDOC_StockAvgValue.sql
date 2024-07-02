USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_StockAvgValue]
	@ProductID [int],
	@CCXML [nvarchar](max),
	@DocDate [datetime],
	@DocQty [float],
	@CalcAvgrate [bit] = 0,
	@DocDetailsID [int] = 0,
	@CalcQOH [bit] = 0,
	@CalcBalQOH [bit] = 0,
	@CalcHOLDQTY [bit] = 0,
	@CalcCommittedQTY [bit] = 0,
	@CalcRESERVEQTY [bit] = 0,
	@CalcTotRESERVEQTY [bit] = 0,
	@ConsiderUnAppInHold [bit] = 0,
	@QOH [float] = 0 OUTPUT,
	@HOLDQTY [float] = 0 OUTPUT,
	@CommittedQTY [float] = 0 OUTPUT,
	@RESERVEQTY [float] = 0 OUTPUT,
	@TotalReserve [float] = 0 OUTPUT,
	@AvgRate [float] = 0 OUTPUT,
	@BalQOH [float] = 0 OUTPUT,
	@UserID [int] = 0,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON;          
        
	DECLARE @SQL NVARCHAR(MAX),@RecQty FLOAT,@RecRate FLOAT,@RecValue FLOAT,@VoucherType INT,@docType int,@WHERE NVARCHAR(MAX),@PrefValue nvarchar(50)
	DECLARE @I INT,@COUNT INT,@NID INT,@valuation int,@TotalSaleQty float,@TotalPurQty float,@Qty  Float,@StockValue Float,@XML XML,@tempQty float        
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL,Date FLOAT,Qty FLOAT,RecRate FLOAT,RecValue FLOAT,VoucherType INT,DocType int)        
	DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID INT,NodeId INT)        
	DECLARE @AvgWHERE NVARCHAR(MAX),@Rate float,@BalQOHWHere NVARCHAR(MAX),@AssignedBal BIT,@DocID INT,@ProductIDS nvarchar(max),@holdDocs nvarchar(Max)
	SELECT @AvgRate=0, @Qty=0,@StockValue=0        
	
	set @holdDocs=''
	select @holdDocs= Value from ADM_GlobalPreferences with(nolock) 
	where Name='HoldResCancelledDocs' and value is not null and value<>''

	SET @AssignedBal=dbo.fnCOM_HasAccess(@RoleID,43,208) 
			
	set @DocID=0		        
	set @XML=@CCXML        

	select @valuation=ValuationID from INV_Product with(nolock) where ProductID=@ProductID        
	INSERT INTO @tblCC(CostCenterID,NodeId)        
	SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')        
	FROM @XML.nodes('/XML/Row') as Data(X)    
	
	    
	
	if exists (select NodeId from @tblCC where CostCenterID=400)		               
			select @DocID=NodeId from @tblCC where CostCenterID=400
		
	SELECT @AvgRate=0, @Qty=0,@StockValue=0   
	
	if exists(select ProductID from INV_Product WITH(NOLOCK) where ProductID=@ProductID and IsGroup=1)
	BEGIN   
		set @ProductIDS=''
		select @ProductIDS=@ProductIDS+convert(nvarchar,ProductID)+',' from INV_Product WITH(NOLOCK)
		where ParentID=@ProductID and IsGroup=0

		if(len(@ProductIDS)>1)
		set @ProductIDS=substring(@ProductIDS,0,len(@ProductIDS))
		else
		set @ProductIDS=CONVERT(nvarchar,@ProductID)	
	END
	ELSE
		set @ProductIDS=CONVERT(nvarchar,@ProductID)     
         
	set @WHERE=''        
	set @AvgWHERE='' 
	set @BalQOHWHere=''     
	select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='EnableLocationWise'        

	if(@PrefValue='True' and exists (select NodeId from @tblCC where CostCenterID=50002))        
	begin        
		set @PrefValue=''      
		select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Location Stock'        
		if(@PrefValue='True')      
		begin      
			select @NID=NodeId from @tblCC where CostCenterID=50002        
			set @WHERE =' dcCCNID2='+CONVERT(nvarchar,@NID)
			
			if(@AssignedBal=1 and @RoleID<>1)
				set @BalQOHWHere =' and dcCCNID2 in('+(select [dbo].[fnCom_GetAssignedNodesForUser](50002,@UserID,@RoleID))+')'
			        
		end       
		set @PrefValue=''      
		select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Location AverageRate'        
		if(@PrefValue='True')      
		begin      
			select @NID=NodeId from @tblCC where CostCenterID=50002        
			set @AvgWHERE =' dcCCNID2='+CONVERT(nvarchar,@NID)        
		end      
	end        

	select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='EnableDivisionWise'        

	if(@PrefValue='True' and exists (select NodeId from @tblCC where CostCenterID=50001))        
	begin        
		select @NID=NodeId from @tblCC where CostCenterID=50001        
		set @PrefValue=''      
		select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Division Stock'        
		if(@PrefValue='True')      
		begin      
			if(@WHERE<>'')        
				set @WHERE =@WHERE+' and '        
			set @WHERE =@WHERE+' dcCCNID1='+CONVERT(nvarchar,@NID)   
		
			if(@AssignedBal=1 and @RoleID<>1)
				set @BalQOHWHere =@BalQOHWHere+'  and  dcCCNID1 in('+(select [dbo].[fnCom_GetAssignedNodesForUser](50001,@UserID,@RoleID))+')'
      
		end       
		set @PrefValue=''      
		select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Division AverageRate'        
		if(@PrefValue='True')      
		begin      
			if(@AvgWHERE<>'')        
				set @AvgWHERE =@AvgWHERE+' and '        
			set @AvgWHERE =@AvgWHERE+' dcCCNID1='+CONVERT(nvarchar,@NID)         
		end         
	end        


	set @PrefValue=''      
	select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise stock'        

	if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)
	begin 
	
		if(exists (select NodeId from @tblCC where CostCenterID=convert(INT,@PrefValue)))
		BEGIN               
			select @NID=NodeId from @tblCC where CostCenterID=convert(INT,@PrefValue)        
						    
			if(@WHERE<>'')        
				set @WHERE =@WHERE +' and '        
			set @WHERE =@WHERE+' dcCCNID'+Convert(nvarchar,convert(INT,@PrefValue)-50000) +'='+CONVERT(nvarchar,@NID) 
		END
		
		if(@AssignedBal=1 and @RoleID<>1)
			set @BalQOHWHere =@BalQOHWHere+'  and dcCCNID'+Convert(nvarchar,convert(INT,@PrefValue)-50000)+' in('+(select [dbo].[fnCom_GetAssignedNodesForUser](convert(INT,@PrefValue),@UserID,@RoleID))+')'
			
     end        

	set @PrefValue=''      
	select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise AverageRate'        

	if(@PrefValue is not null and @PrefValue<>0 and convert(INT,@PrefValue)>0)
	begin
		if exists (select NodeId from @tblCC where CostCenterID=convert(INT,@PrefValue))		
			select @NID=NodeId from @tblCC where CostCenterID=convert(INT,@PrefValue)        
		else
			select @NID=1
			
		set @PrefValue=convert(INT,@PrefValue)-50000        
		if(@AvgWHERE<>'')        
			set @AvgWHERE =@AvgWHERE +' and '        
		set @AvgWHERE =@AvgWHERE+' dcCCNID'+@PrefValue+'='+CONVERT(nvarchar,@NID)        
	end

	if(@DocDetailsID>0)  
	begin   
		if(@WHERE<>'')        
			set @WHERE =@WHERE+' and '    
		set @WHERE =@WHERE+' D.InvDocDetailsID<>'+CONVERT(nvarchar,@DocDetailsID)  
	end  
       
       
    if(@WHERE<>'')        
   set @WHERE =' and '+@WHERE        
         
    if(@AvgWHERE<>'')        
  set @AvgWHERE =' and '+@AvgWHERE           
         

	if @CalcQOH=1--Calculating QOH
	begin
		set @SQL='set @QOH=(SELECT isnull(sum(UOMConvertedQty*case when vouchertype=1 and statusid in(371,441) then 0 else  VoucherType end),0) FROM INV_DocDetails D WITH(NOLOCK)        
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
		WHERE D.ProductID in ('+@ProductIDS+') AND IsQtyIgnored=0 and D.StatusID in(371,441,369) AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))        
		set @SQL=@SQL+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
		      
		EXEC sp_executesql @SQL, N'@QOH float OUTPUT', @QOH OUTPUT        
		
	end
          
	if @CalcBalQOH=1--Calculating BalQOH
	begin
		set @SQL='set @BalQOH=(SELECT isnull(sum(UOMConvertedQty*case when vouchertype=1 and statusid in(371,441) then 0 else  VoucherType end),0) FROM INV_DocDetails D WITH(NOLOCK)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
		WHERE D.ProductID in ('+@ProductIDS+') AND IsQtyIgnored=0 and D.StatusID in(371,441,369) '
		set @SQL=@SQL+@BalQOHWHere+' and (VoucherType=1 or VoucherType=-1) )'         
		
		EXEC sp_executesql @SQL, N'@BalQOH float OUTPUT', @BalQOH OUTPUT   
    end
    
    if @CalcHOLDQTY=1--Hold Qty
    begin
		 set @SQL='set @HOLDQTY=(  select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
		 (SELECT D.HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 '
		 
		  if (@holdDocs<>'')
                 set @SQL=@SQL+' or l.Costcenterid in(' + @holdDocs+')'
		 
		 set @SQL=@SQL+' then l.UOMConvertedQty else l.ReserveQuantity end)
		  from INV_DocDetails l WITH(NOLOCK)  
		 join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID 
		 where  d.InvDocDetailsID=l.LinkedInvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+'),0) release  
		 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
		  WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID'
		 if (@ConsiderUnAppInHold=1)				 
			set @SQL=@SQL+' in(371,441,369) '
		else	
			set @SQL=@SQL+'=369 '
		 
		 set @SQL=@SQL+'  and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate)) 
		 set @SQL=@SQL+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
		          
		  EXEC sp_executesql @SQL, N'@HOLDQTY float OUTPUT', @HOLDQTY OUTPUT   
	end
	if @CalcCommittedQTY=1--Committed Qty
    begin
		set @SQL='set @CommittedQTY=(  select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from   
		(SELECT D.HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 '
		 
		  if (@holdDocs<>'')
                 set @SQL=@SQL+' or l.Costcenterid in(' + @holdDocs+')'
		 
		 set @SQL=@SQL+' then l.UOMConvertedQty else l.ReserveQuantity end)
		from INV_DocDetails l WITH(NOLOCK)  
		left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID 
		where d.InvDocDetailsID=l.LinkedInvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+'),0) release  
		FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID
		WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369  and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1 AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))
		set @SQL=@SQL+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'       
		  
		EXEC sp_executesql @SQL, N'@CommittedQTY float OUTPUT', @CommittedQTY OUTPUT   
	end
    if @CalcRESERVEQTY=1--Reserve Qty
    begin
		set @SQL='set @RESERVEQTY=(  select  isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from   
		(SELECT D.ReserveQuantity HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 '
		 
		  if (@holdDocs<>'')
                 set @SQL=@SQL+' or l.Costcenterid in(' + @holdDocs+')'
		 
		 set @SQL=@SQL+' then l.UOMConvertedQty else l.ReserveQuantity end)
	     from INV_DocDetails l  WITH(NOLOCK)   
		left join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID 
		where d.InvDocDetailsID=l.LinkedInvDocDetailsID '+REPLACE(@WHERE,'dcCCNID','LDCC.dcCCNID')+'),0) release  
		FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID   
		  WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID'
				 
		 if (@ConsiderUnAppInHold=1)				 
			set @SQL=@SQL+' in(371,441,369) '
		else	
			set @SQL=@SQL+'=369 '
		 
		 set @SQL=@SQL+'   and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))     
		set @SQL=@SQL+REPLACE(@WHERE,'dcCCNID','DCC.dcCCNID')+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'       

		EXEC sp_executesql @SQL, N'@RESERVEQTY float OUTPUT', @RESERVEQTY OUTPUT   
	end
    
    if @CalcTotRESERVEQTY=1--Reserve Qty
    begin
		set @SQL='set @TotalReserve=(  select  isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from   
		(SELECT D.ReserveQuantity HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end)
		 from INV_DocDetails l  WITH(NOLOCK)  
		join COM_DocCCData LDCC WITH(NOLOCK) ON LDCC.InvDocDetailsID=L.InvDocDetailsID 
		where d.InvDocDetailsID=l.LinkedInvDocDetailsID),0) release  
		FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID   
		WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369  and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))     
		set @SQL=@SQL+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'       

		EXEC sp_executesql @SQL, N'@TotalReserve float OUTPUT', @TotalReserve OUTPUT   
	end
	
  if(@CalcAvgrate=0)  
  begin  
	SET @AvgRate=0  
	RETURN  
  end  
  
   EXEC  [spDOC_ReconcileAvgValue] @ProductID,@AvgWHERE,@DocDate,@DocQty,@DocDetailsID,0,@DocID,@AvgRate OUTPUT
GO
