USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_ReconcileAvgValue]
	@ProductID [int],
	@AvgWHERE [nvarchar](max),
	@DocDate [datetime],
	@DocQty [float],
	@DocDetailsID [int] = 0,
	@IsFromReconcile [bit],
	@DocumentID [int] = 0,
	@AvgRate [float] = 0 OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON; 
 set @AvgRate=0
	declare @valuation int,@SQL nvarchar(max),@STWHERE nvarchar(MAX),@I int,@TotalSaleQty float,@StockValue float,@RecQty FLOAT,@RecRate FLOAT,@RecValue FLOAT,@VoucherType INT,@docType int,@cd float,@dd float,@tempwher nvarchar(max),@tempsql nvarchar(max)
	declare @Qty float,@tempQty float,@COUNT int,@Rate float,@Dtype int,@DocID INT,@vtype int,@prefix nvarchar(50),@docno nvarchar(50),@SortAvgRate  nvarchar(10),@AvgRateBasedOn  nvarchar(100),@CloseDt nvarchar(20)
	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,DocID INT,Date FLOAT,cD float,Qty FLOAT,RecRate FLOAT,RecValue FLOAT,VoucherType INT,DocType int)        
	
	if not (@IsFromReconcile=1 and @valuation=3)
		SELECT @CloseDt=convert(nvarchar(20), max(ToDate)+1) FROM ADM_FinancialYears with(nolock) where InvClose=1 and ToDate<convert(int,@DocDate)
		
	set @StockValue=0
	set @Qty=0
	set @tempwher=''
	select @Dtype=documenttype,@vtype=VoucherType,@prefix =DocPrefix,@docno=DocNumber from INV_DocDetails  
	where DocID=@DocumentID
	if(@Dtype=5)
		set @vtype=-1
	select @SortAvgRate=Value from ADM_GlobalPreferences with(nolock)
	where Name='SortAvgRate'
	if(@SortAvgRate='true')
		select @AvgRateBasedOn=Value from ADM_GlobalPreferences with(nolock)
		where Name='AvgRateBasedOn'
	else
		set @AvgRateBasedOn=''
	
	DECLARE @STVal NVARCHAR(max),@STValDocs NVARCHAR(MAX)
	SELECT @STVal=Value From ADM_GlobalPreferences with(nolock) where Name='ExcludeSTAvgRate'
	IF(@STVal='True')
	BEGIN
		SELECT @STValDocs=Value From ADM_GlobalPreferences with(nolock) where Name='ExcludeSTAvgRateDocs'
		IF(LEN(@STValDocs)>0)
			set @STWHERE=' and CostCenterID IN('+@STValDocs+') '
		ELSE
			set @STWHERE=' and DocumentType<>5 '
	END
	ELSE 
		set @STWHERE=''


	--if exists(select Value from ADM_GlobalPreferences with(nolock)
	--where Name='ExcludeSTAvgRate' and Value='True')
	--	set @STWHERE=' and DocumentType<>5 '
	--else
	--	set @STWHERE=''

			
	select @valuation=ValuationID from INV_Product with(nolock) where ProductID=@ProductID        

	if(@IsFromReconcile=1 and @valuation=3)
	BEGIN		
		set @SQL='select @AvgRate=isnull(AvgRate,0),@RecQty=DocDate,@cd=CreatedDate,@Qty=StockQty,@StockValue=StockVal from INV_ProductAvgRate WITH(NOLOCK) where ProductID='+convert(nvarchar(max),@ProductID)+ @AvgWHERE
		EXEC sp_executesql @SQL, N'@AvgRate float OUTPUT,@RecQty float OUTPUT,@cd float OUTPUT,@StockValue float OUTPUT,@Qty float OUTPUT', @AvgRate OUTPUT,@RecQty OUTPUT,@cd OUTPUT,@StockValue OUTPUT,@Qty OUTPUT
		
		if(@RecQty is not null and @RecQty>0)
		BEGIN
			if(@SortAvgRate='true')
			BEGIN
				if(@AvgRateBasedOn='DocDate,CreatedDate')
					set @tempwher=' and (DocDate>'+convert(nvarchar(max),@RecQty)+'  or (DocDate='+convert(nvarchar(max),@RecQty)+' and CreatedDate>'+convert(nvarchar(max),@cd)+'))'				
				else if(@AvgRateBasedOn='CreatedDate')
					set @tempwher=' and CreatedDate>'+convert(nvarchar(max),@cd)
				else if(@AvgRateBasedOn='DocDate,ModifiedDate')
					set @tempwher=' and (DocDate>'+convert(nvarchar(max),@RecQty)+'  or (DocDate='+convert(nvarchar(max),@RecQty)+' and ModifiedDate>'+convert(nvarchar(max),@cd)+'))'									
				else if(@AvgRateBasedOn='ModifiedDate')
					set @tempwher=' and ModifiedDate>'+convert(nvarchar(max),@cd)			
			END	
			else
				set @tempwher=' and DocDate>'+convert(nvarchar(max),@RecQty)				
		END		
		else
		BEGIN
			set @AvgRate=0
			set @StockValue=0
			set @Qty=0
		END	
	END
		
	if(@AvgRateBasedOn='DocDate,CreatedDate')
		set @AvgRateBasedOn='D.DocDate,D.CreatedDate'
	else if(@AvgRateBasedOn='CreatedDate')
		set @AvgRateBasedOn='D.CreatedDate,0 cd'
	else if(@AvgRateBasedOn='DocDate,ModifiedDate')
		set @AvgRateBasedOn='D.DocDate,D.ModifiedDate'		
	else if(@AvgRateBasedOn='ModifiedDate')
		set @AvgRateBasedOn='D.ModifiedDate,0 cd'
	
	
	set @tempQty=0 
	set @SQL=''
	if(@valuation=3) 
	BEGIN
		set @SQL='SELECT DocID,'
		
		if(@SortAvgRate='true')
			set @SQL=@SQL+@AvgRateBasedOn
		else
			set @SQL=@SQL+'DocDate,0 cd'
			
		set @SQL=@SQL+',Qty,RecRate,RecValue,VoucherType,DocumentType FROM ( '
	END
	
	set @SQL=@SQL+'SELECT D.DocID,'
	
	if(@SortAvgRate='true')
		set @SQL=@SQL+@AvgRateBasedOn
	else
		set @SQL=@SQL+'DocDate,0 cd'
			
	if(@valuation=3) 
		set @SQL=@SQL+',D.VoucherNo,case when DocumentType=5 then 1 else 2 end ST,case when DocumentType=3 then 1 else 0 end isOP '
	
	set @SQL=@SQL+',UOMConvertedQty Qty,StockValue/UOMConvertedQty RecRate,StockValue RecValue,VoucherType,DocumentType
			FROM INV_DocDetails D WITH(NOLOCK)        
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID='+convert(nvarchar,@ProductID) +' and D.StatusID=369 and VoucherType=1 AND IsQtyIgnored=0 and UOMConvertedQty<>0 '

	
	set @SQL=@SQL+' AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))        		
	
	if(@CloseDt is not null)
	begin
		set @SQL=@SQL+' and D.DocDate>='+@CloseDt	
	END
	
	set @SQL=@SQL+@AvgWHERE +@tempwher+@STWHERE
    
  if(@valuation=1)   
  BEGIN     
	if(@CloseDt is not null)
	begin
		set @tempsql='SELECT 0,CloseDate DocDate,0 cd,Qty,Rate,BalValue,1,3 
		FROM INV_ProductClose DCC WITH(NOLOCK)
		WHERE ProductID='+convert(nvarchar,@ProductID) +' AND CloseDate='+convert(nvarchar,(@CloseDt-1))+@AvgWHERE
		INSERT INTO @Tbl(DocID,Date,cD,Qty,RecRate,RecValue,VoucherType,DocType)
		exec(@tempsql)
	end
	set @SQL=@SQL+'  ORDER BY '
	if(@SortAvgRate='true')
		set @SQL=@SQL+replace(@AvgRateBasedOn,',0 cd','')
	else
		set @SQL=@SQL+'DocDate'
		
	set @SQL=@SQL+',D.InvDocDetailsID '        
  END		
  else if(@valuation=2)   
  BEGIN     
	if(@CloseDt is not null)
	begin
		set @tempsql='SELECT 0,CloseDate DocDate,0 cd,Qty,Rate,BalValue,1,3 
		FROM INV_ProductClose DCC WITH(NOLOCK)
		WHERE ProductID='+convert(nvarchar,@ProductID) +' AND CloseDate='+convert(nvarchar,(@CloseDt-1))+@AvgWHERE
		INSERT INTO @Tbl(DocID,Date,cD,Qty,RecRate,RecValue,VoucherType,DocType)
		exec(@tempsql)
	end

    set @SQL=@SQL+' ORDER BY '
    if(@SortAvgRate='true')
		set @SQL=@SQL+ replace(replace(@AvgRateBasedOn,',0 cd',''),'DocDate','DocDate desc')
	else
		set @SQL=@SQL+'DocDate'
		
    set @SQL=@SQL+' DESC,D.InvDocDetailsID DESC'        
  END  
  else  if(@valuation=3) 
  BEGIN
	if(@CloseDt is not null)
	begin
		SET @SQL=@SQL+' UNION ALL
		SELECT 0,CloseDate DocDate,0 cd,''hard'',2,1,Qty,Rate RecRate,BalValue RecValue,1 VoucherType,3 DocumentType
		FROM INV_ProductClose DCC WITH(NOLOCK)
		WHERE ProductID='+convert(nvarchar,@ProductID) +' AND CloseDate='+convert(nvarchar,(@CloseDt-1))+@AvgWHERE
	end
	set @SQL=@SQL+'  UNION ALL SELECT D.DocID,'
	
	if(@SortAvgRate='true')
		set @SQL=@SQL+@AvgRateBasedOn
	else
		set @SQL=@SQL+'DocDate,0 cd'
		
	set @SQL=@SQL+',D.VoucherNo,case when DocumentType=5 then 1 else 0 end ST,0 isOP,UOMConvertedQty Qty,StockValue/UOMConvertedQty RecRate,StockValue RecValue,VoucherType,DocumentType
		        
		FROM INV_DocDetails D WITH(NOLOCK)        
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
		WHERE D.ProductID='+convert(nvarchar,@ProductID) +' and VoucherType=-1  and D.StatusID=369 AND IsQtyIgnored=0 and UOMConvertedQty<>0 AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))        
		if(@CloseDt is not null)
		begin
			set @SQL=@SQL+' and D.DocDate>='+@CloseDt	
		END
		
	set @SQL=@SQL+@AvgWHERE  +@tempwher+@STWHERE
    set @SQL=@SQL+' ) AS D ORDER BY isOP desc,'
    
    if(@SortAvgRate='true')
		set @SQL=@SQL+replace(@AvgRateBasedOn,',0 cd','')
	else
		set @SQL=@SQL+'DocDate'
		
    set @SQL=@SQL+',ST DESC,VoucherType DESC,VoucherNo'        
  END       
  
	
  print @SQL        
  INSERT INTO @Tbl(DocID,Date,cD,Qty,RecRate,RecValue,VoucherType,DocType)        
  exec(@SQL)       

    if(@DocDetailsID>0 or @DocumentID>0)  
	begin 		
		set @DocID=0
		select @DocID=min(id) from @Tbl where DocID= @DocumentID				
		if(@DocID>0)
		BEGIN
			delete from @Tbl
			where id>=@DocID
			set @DocID=0
		END
	end
   
  if(@valuation=1 or @valuation=2)        
  begin 
	  set @SQL='set @TotalSaleQty=(SELECT isnull(sum(UOMConvertedQty),0) FROM INV_DocDetails D WITH(NOLOCK)        
	  INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
	  WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND IsQtyIgnored=0 and D.StatusID=369'
		
		if((@DocDetailsID>0 or @DocumentID>0) and @vtype=-1)  
		begin 		
			set @SQL=@SQL+' AND (D.DocDate<'+convert(nvarchar,CONVERT(float,@DocDate))        
			 +' or (D.DocDate='+convert(nvarchar,CONVERT(float,@DocDate))   
			if(@DocDetailsID>0)
				set @SQL =@SQL+' and (D.DocPrefix<'''+@prefix +''' or (D.DocPrefix='''+@prefix +''' and convert(INT,DocNumber)<convert(INT,'+@docno+'))  
				or (D.DocPrefix='''+@prefix +''' and convert(INT,DocNumber)=convert(INT,'+@docno+') and d.InvDocDetailsID <'+CONVERT(nvarchar,@DocDetailsID)+') )) )'  
			else
				set @SQL =@SQL+' and (D.DocPrefix<'''+@prefix +''' or (D.DocPrefix='''+@prefix +''' and convert(INT,DocNumber)<=convert(INT,'+@docno+')) )) )'  				
		end
		ELSE
			 set @SQL=@SQL+' AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))  
		
		if(@CloseDt is not null)
		begin
			set @SQL=@SQL+' and D.DocDate>='+@CloseDt	
		END
		
	  set @SQL=@SQL+@AvgWHERE+@STWHERE+' and VoucherType=-1)'         
			--print @SQL  
	   EXEC sp_executesql @SQL, N'@TotalSaleQty float OUTPUT', @TotalSaleQty OUTPUT        
   END    
          
	declare @cur Cursor 
	set @I=0 
	set  @cur=cursor for   
	SELECT DocID,DocType,VoucherType,ISNULL(Qty,0),ISNULL(RecRate,0),ISNULL(RecValue ,0),Date,cD       
	FROM @Tbl    
	open @cur  
	FETCH NEXT FROM  @cur into @DocID,@docType,@VoucherType,@RecQty,@RecRate,@RecValue,@dd,@cd

	WHILE(@@FETCH_STATUS<> -1)        
	BEGIN    
		set @I=@I+1
		if(@valuation=1 or @valuation=2)        
		begin 
			if(@docType<>6 and @docType<>39)
				set @AvgRate=  @RecRate

			if(@TotalSaleQty>0)        
			begin  
				if(@RecQty>@TotalSaleQty)        
				begin        
					update @Tbl        
					set Qty=Qty-@TotalSaleQty        
					WHERE ID=@I        
					set @TotalSaleQty=0        
					break;        
				end        
				else        
				begin             
					set @TotalSaleQty=@TotalSaleQty-@RecQty   

					select @docType=DocType from @Tbl where ID=@I+1  
					if(@docType=6 or @docType=39)  
					begin  
						update @Tbl        
						set RecRate=@RecRate,  
						RecValue=(Qty*(@RecValue/@RecQty))  
						WHERE ID=@I+1   
					end 
				 
					delete from @Tbl WHERE ID=@I        
				END        
			END        
			else        
				break;        
		End        
		else if(@valuation=3)        
		begin  
			if(@DocDetailsID>0 and @Dtype=5 and @DocumentID=@DocID)  
				break;

			IF @VoucherType=1        
			BEGIN

				if(@docType=6 or @docType=39)  
				begin    
					SET @RecRate=@AvgRate   
					set @RecValue=@AvgRate*@RecQty 
					set @Rate=@AvgRate
				end 
				else   
					set @Rate = @RecValue / @RecQty; 
				if (@Qty < 0)
				begin
					set @Qty = @RecQty + @Qty;
					if (@Qty > 0)
						set @RecQty = @Qty;
					else
						set @RecQty = 0;
				end
				else
					SET @Qty=@Qty+@RecQty   

				SET @StockValue=@StockValue+(@RecQty*@Rate)       
				IF @Qty>0        
					SET @AvgRate = @StockValue / @Qty;        

			END        
			ELSE        
			BEGIN        
				SET @Qty=@Qty-@RecQty        
				SET @StockValue = @AvgRate * @Qty;        
			END   

			IF @Qty<0
			BEGIN    
				set @StockValue=0
			END 

		end        
           
	FETCH NEXT FROM  @cur into @DocID,@docType,@VoucherType,@RecQty,@RecRate,@RecValue,@dd,@cd

	END        
	CLOSE @cur  
	DEALLOCATE @cur  
    
    if(@IsFromReconcile=1 and @valuation=3)
	BEGIn
		if(@vtype=-1 and @DocQty>0)
		BEGIn
			set @Qty=@Qty-@DocQty
			set @StockValue=@Qty*@AvgRate
		END
			set @SQL='if exists(select * from INV_ProductAvgRate WITH(NOLOCK) where ProductID='+convert(nvarchar(max),@ProductID)+ @AvgWHERE+') 
					update INV_ProductAvgRate
					set AvgRate='+convert(nvarchar(max),@AvgRate)+',StockQty='+convert(nvarchar(max),@Qty)+',StockVal='+convert(nvarchar(max),@StockValue)+'
					,DocDate='+convert(nvarchar(max),@dd)+',CreatedDate='+convert(nvarchar(max),@cd)+'
					where ProductID='+convert(nvarchar(max),@ProductID)+ @AvgWHERE
				if(	@dd is not null)
				BEGIN
					set @SQL=@SQL+'
						else
						BEGIN
							declare @val INT
							insert into INV_ProductAvgRate(AvgRate,ProductID,DocDate,CreatedDate)
							values('+convert(nvarchar(max),@AvgRate)+','+convert(nvarchar(max),@ProductID)+','+convert(nvarchar(max),@dd)+','+convert(nvarchar(max),@cd)+')
							set @val=@@identity '
							if(@AvgWHERE<>'')
							BEGIN
								set @AvgWHERE=replace(@AvgWHERE,'and',',')
								
								set @SQL=@SQL+'update INV_ProductAvgRate
								set StockQty='+convert(nvarchar(max),@Qty)+',StockVal='+convert(nvarchar(max),@StockValue)+ @AvgWHERE+'
								where ProductAvgID=@val'
							END	
							
						set @SQL=@SQL+' END'
				END		
				print @SQL
				
			EXEC (@SQL)
		
	END
	     
	set @tempQty=@DocQty         
	set @StockValue=0     
	   
	if(@valuation=1 or @valuation=2)        
	begin   
		SELECT @I=min(ID),@COUNT=COUNT(*)+min(ID) FROM @Tbl        
		WHILE(@I<@COUNT)        
		BEGIN        
			SELECT @docType=DocType,@RecQty=ISNULL(Qty,0),@RecRate=ISNULL(RecRate,0)         
			FROM @Tbl WHERE ID=@I        

			if(@docType=6 or @docType=39)  
			begin  
				if exists(select Qty  FROM @Tbl WHERE ID=@I-1)  
				begin  
					SELECT @RecRate=ISNULL(RecRate,0)         
					FROM @Tbl WHERE ID=@I-1  
				end  
			end  

			if(@tempQty>0)        
			begin        
				if(@RecQty>@tempQty)        
				begin        
					SET @Qty=@Qty+@tempQty        
					set @StockValue=@StockValue+(@tempQty*@RecRate)        
					set @tempQty=0        
				end        
				else        
				begin        
					SET @Qty=@Qty+@RecQty        
					set @tempQty=@tempQty-@RecQty        
					set @StockValue=@StockValue+(@RecQty*@RecRate)        
				end        
			end        
			else        
				break;        

			SET @I=@I+1        
		END 
		       
		if(@Qty>0)         
			set  @AvgRate=@StockValue/@Qty   
	end

GO
