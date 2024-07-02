USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductTypeDetails]
	@ProductID [int] = 0,
	@StockCode [nvarchar](max) = null,
	@UOMID [int] = 0,
	@CCXML [nvarchar](max),
	@CostCenterID [int],
	@DocDate [datetime],
	@CreditAccount [int],
	@DocQty [float],
	@CalcAvgrate [bit] = 0,
	@DocDetailsID [int] = 0,
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1,
	@CalcPWLastPCost [bit] = 0,
	@CalcPWLastPRate [bit] = 0,
	@CalcLastPCost [bit] = 0,
	@CalcLastPRate [bit] = 0,
	@CalcQOH [bit] = 0,
	@CalcBalQOH [bit] = 0,
	@CalcHOLDQTY [bit] = 0,
	@CalcCommittedQTY [bit] = 0,
	@CalcRESERVEQTY [bit] = 0,
	@CalcTotRESERVEQTY [bit] = 0,
	@CalcLastPRSNS [bit] = 0,
	@CalcLocQOH [bit] = 0,
	@CalcDivQOH [bit] = 0,
	@IsTestCase [bit] = 0,
	@IsLink [bit] = 0,
	@ProfileID [nvarchar](max) = ''
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON        
        
    DECLARE @SQL NVARCHAR(MAX),@XML XML,@WHERE NVARCHAR(MAX),@I INT,@CNT INT,@NODEID INT,@CcID INT,@BalQOH FLOAT,@table   nvarchar(200),@TestCaseExists BIT
    Declare @CC nvarchar(30),@CCWHERE NVARCHAR(MAX),@OrderBY NVARCHAR(MAX),@HOLDQTY FLOAT,@CommittedQTY FLOAT,@RESERVEQTY FLOAT,@stockID INT,@IsPromo BIT,@StCCID int
    DECLARE @AvgRate float,@LastPRate float,@PWLastPRate float,@iCNT INT,@ccCNTT INT,@QOH float,@PrefValue nvarchar(50),@NID INT,@dp float,@rp float,@AvgPrice float,@DivQoh float
    DECLARE @DrAccount INT,@CrAccount INT,@CrName NVARCHAR(200),@DrName NVARCHAR(200),@VendorQty float,@JOIN nvarchar(max),@ProductIDS nvarchar(max),@tmpccid int,@LocQOH Float
   DECLARE @SIZE INT,@Cols NVARCHAR(1000),@ColsList NVARCHAR(1000) ,@DocumentType int,@uBarcode nvarchar(100),@VBarcode nvarchar(100),@CurrencyID INT,@ptype int,@uBarcodeKey INT
   DECLARE @UPDATESQL NVARCHAR(MAX),@CCJOINQUERY NVARCHAR(MAX),@LastPCost float ,@PWLastPCost float,@isGrp bit,@tblName NVARCHAR(200),@LastPRSNS Float,@TotRESERVE float
   SET @XML=@CCXML        
    

   declare @tblSplitcc table(CCIDS int)        
   DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId INT)        
   INSERT INTO @tblCC(CostCenterID,NodeId)        
   SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')        
   FROM @XML.nodes('/XML/Row') as Data(X)  
   

	--Loading Global Preferences
	DECLARE @TblPref AS TABLE(Name nvarchar(100),Value nvarchar(max))
	INSERT INTO @TblPref
	SELECT Name,Value FROM ADM_GlobalPreferences with(nolock)
	WHERE Name IN ('EnableLocationWise','Location Stock','EnableDivisionWise','Division Stock','Maintain Dimensionwise stock'
		,'Maintain Dimensionwise AverageRate','LW Bins','DimensionwiseBins','ConsiderUnAppInHold')
            
	select @DocumentType=DocumentType from adm_documenttypes with(nolock) where CostCenterID=@CostCenterID    
	
   if(@DocumentType=38 and @ProductID=0 and  @StockCode is not null and @StockCode<>'')
   BEGIN
		select @table= b.TableName,@StCCID=FeatureID from adm_globalpreferences a with(nolock)
		join adm_features b with(nolock) on a.value=b.featureid
		where a.Name='POSItemCodeDimension' 

		set @SQL='select @ProductID=ProductID,@stockID=NodeID,@DP=DealerPrice,@RP=RetailPrice,@AvgPrice=AvgPrice		
		 from '+@table+' with(nolock)  where COde='''+@StockCode+''''

		exec sp_executesql @SQL,N'@ProductID INT OUTPUT,@stockID INT OUTPUT,@DP float OUTPUT,@RP float OUTPUT,@AvgPrice float OUTPUT',@ProductID output,@stockID output,@dp output,@rp output,@AvgPrice output
		if(@ProductID is null or @ProductID=0)
		BEGIN
			set @SQL='select @ProductID=ProductID,@stockID=NodeID,@DP=DealerPrice,@RP=RetailPrice,@AvgPrice=AvgPrice
			from '+@table+' with(nolock)  where EAN='''+@StockCode+''''

			exec sp_executesql @SQL,N'@ProductID INT OUTPUT,@stockID INT OUTPUT,@DP float OUTPUT,@RP float OUTPUT,@AvgPrice float OUTPUT',@ProductID output,@stockID output,@dp output,@rp output,@AvgPrice output

			if(@ProductID is null or @ProductID=0)
			BEGIN
				select @ProductID=ProductID from INV_Product with(NOLOCK) where ProductCode=@StockCode
				if(@ProductID is null or @ProductID=0)
					return;  
			END
		END	
   END
   
   
   select @CurrencyID=CurrencyID,@isGrp=IsGroup,@ptype=ProductTypeID from INV_Product WITH(NOLOCK) where ProductID=@ProductID
   
   if (@isGrp=1)
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
		
	if(@DocumentType=11 or @DocumentType=7 or @DocumentType=9 or @DocumentType=24 or @DocumentType=33 or @DocumentType=10 or @DocumentType=8 or @DocumentType=12)        
	begin
		if @CalcPWLastPCost=1
		begin
			set @WHERE=''
			select @WHERE=lastvaluevouchers from adm_costcenterdef  WITH(NOLOCK) 
			where costcenterid=@CostCenterID and  linkdata=23821 and LocalReference=79  
			
			set @CCWHERE=''
			if (@WHERE is not null and @WHERE like '%~%')
			BEGIN
				set @CNT=Charindex('~',@WHERE,0)
				
				set @CCWHERE= substring(@WHERE,@CNT+1,5000)
				set @WHERE= substring(@WHERE,0,@CNT)
				
				insert into @tblSplitcc  
				exec SPSplitString @CCWHERE,','
				
				set @CCWHERE=''
				
			   select @CCWHERE=@CCWHERE+' and dcccnid'+convert(nvarchar(max),(CCIDS-50000))+'='+convert(nvarchar(max),NodeId)
			   from @tblSplitcc a
			   join @tblCC b on a.CCIDS=b.CostCenterID
			END
			
			set @SQL='select @PWLastPCost=StockValueFC/UOMConvertedQty from INV_DocDetails a with(nolock) '
			if(@CCWHERE<>'')
				set @SQL=@SQL+' join com_docccdata b with(nolock) on a.INVDocDetailsid=b.INVDocDetailsid '
				
			set @SQL=@SQL+' where IsQtyIgnored=0 and VoucherType=-1 and ProductID in ('+@ProductIDS+') and DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))+'           
			and DebitAccount='+convert(nvarchar,@CreditAccount)
			if (@WHERE is not null and @WHERE<>'')  
				set @SQL=@SQL+' and CostcenterID in ('+@WHERE+') '
			
			if (@CCWHERE<>'')  
				set @SQL=@SQL+@CCWHERE
		
			set @SQL=@SQL+' and UOMConvertedQty is not null and UOMConvertedQty>0   
			order by DocDate'     
			exec sp_executesql  @SQL,N'@PWLastPCost FLOAT OUTPUT',@PWLastPCost OUTPUT         
			
		end
		if @CalcPWLastPRate=1
		begin
			set @WHERE=''
			select @WHERE=lastvaluevouchers from adm_costcenterdef  WITH(NOLOCK) 
			where costcenterid=@CostCenterID and  linkdata=24062 and LocalReference=79  
			
			set @CCWHERE=''
			if (@WHERE is not null and @WHERE like '%~%')
			BEGIN
				set @CNT=Charindex('~',@WHERE,0)
				
				set @CCWHERE= substring(@WHERE,@CNT+1,5000)
				set @WHERE= substring(@WHERE,0,@CNT)
				
				insert into @tblSplitcc  
				exec SPSplitString @CCWHERE,','
				
				set @CCWHERE=''
				
			   select @CCWHERE=@CCWHERE+' and dcccnid'+convert(nvarchar(max),(CCIDS-50000))+'='+convert(nvarchar(max),NodeId)
			   from @tblSplitcc a
			   join @tblCC b on a.CCIDS=b.CostCenterID
			END
			
			set @SQL='select  @PWLastPRate=Rate*ExchangeRate from INV_DocDetails a with(nolock) '
			if(@CCWHERE<>'')
				set @SQL=@SQL+' join com_docccdata b with(nolock) on a.INVDocDetailsid=b.INVDocDetailsid '
				
			set @SQL=@SQL+' where IsQtyIgnored=0 and VoucherType=-1 and ProductID in ('+@ProductIDS+')  and DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))+'           
			and DebitAccount='+convert(nvarchar,@CreditAccount)
			if (@WHERE is not null and @WHERE<>'')  
				set @SQL=@SQL+' and CostcenterID in ('+@WHERE+') '
			
			if (@CCWHERE<>'')  
				set @SQL=@SQL+@CCWHERE

	
			set @SQL=@SQL+' order by DocDate'  
			
			exec sp_executesql  @SQL,N'@PWLastPRate FLOAT OUTPUT',@PWLastPRate OUTPUT    			
		end
	end    
	else    
	begin
		if @CalcPWLastPCost=1
		begin
			set @WHERE=''
			select @WHERE=lastvaluevouchers from adm_costcenterdef  WITH(NOLOCK) 
			where costcenterid=@CostCenterID and  linkdata=23821 and LocalReference=79  
			
			set @CCWHERE=''
			if (@WHERE is not null and @WHERE like '%~%')
			BEGIN
				set @CNT=Charindex('~',@WHERE,0)
				
				set @CCWHERE= substring(@WHERE,@CNT+1,5000)
				set @WHERE= substring(@WHERE,0,@CNT)
				
				insert into @tblSplitcc  
				exec SPSplitString @CCWHERE,','
				
				set @CCWHERE=''
				
			   select @CCWHERE=@CCWHERE+' and dcccnid'+convert(nvarchar(max),(CCIDS-50000))+'='+convert(nvarchar(max),NodeId)
			   from @tblSplitcc a
			   join @tblCC b on a.CCIDS=b.CostCenterID
			END
			
			set @SQL='select @PWLastPCost=StockValueFC/UOMConvertedQty from INV_DocDetails a WITH(NOLOCK) '
			if(@CCWHERE<>'')
				set @SQL=@SQL+' join com_docccdata b with(nolock) on a.INVDocDetailsid=b.INVDocDetailsid '
				
			set @SQL=@SQL+' where IsQtyIgnored=0 and VoucherType=1 and ProductID in ('+@ProductIDS+')  and DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))+'           
			and CreditAccount='+convert(nvarchar,@CreditAccount)
			if (@WHERE is not null and @WHERE<>'')  
				set @SQL=@SQL+' and CostcenterID in ('+@WHERE+') '
			if (@CCWHERE<>'')  
				set @SQL=@SQL+@CCWHERE
					
			set @SQL=@SQL+' and UOMConvertedQty is not null and UOMConvertedQty>0   
			order by DocDate'     
			exec sp_executesql  @SQL,N'@PWLastPCost FLOAT OUTPUT',@PWLastPCost OUTPUT    			
		end
		
		if @CalcPWLastPRate=1
		begin
			set @WHERE=''
			select @WHERE=lastvaluevouchers from adm_costcenterdef WITH(NOLOCK) 
			where costcenterid=@CostCenterID and  linkdata=24062 and LocalReference=79  
			
			set @CCWHERE=''
			if (@WHERE is not null and @WHERE like '%~%')
			BEGIN
				set @CNT=Charindex('~',@WHERE,0)
				
				set @CCWHERE= substring(@WHERE,@CNT+1,5000)
				set @WHERE= substring(@WHERE,0,@CNT)
				
				insert into @tblSplitcc  
				exec SPSplitString @CCWHERE,','
				
				set @CCWHERE=''
				
			   select @CCWHERE=@CCWHERE+ ' and dcccnid'+convert(nvarchar(max),(CCIDS-50000))+'='+convert(nvarchar(max),NodeId)
			   from @tblSplitcc a
			   join @tblCC b on a.CCIDS=b.CostCenterID
			END
			
			set @SQL='select  @PWLastPRate=Rate*ExchangeRate from INV_DocDetails a with(nolock) '
			if(@CCWHERE<>'')
				set @SQL=@SQL+' join com_docccdata b with(nolock) on a.INVDocDetailsid=b.INVDocDetailsid '
				
			set @SQL=@SQL+' where IsQtyIgnored=0 and VoucherType=1 and ProductID in ('+@ProductIDS+')  and DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))+'           
			and CreditAccount='+convert(nvarchar,@CreditAccount)
			if (@WHERE is not null and @WHERE<>'')  
				set @SQL=@SQL+' and CostcenterID in ('+@WHERE+') '
			
			if (@CCWHERE<>'')  
				set @SQL=@SQL+@CCWHERE	
		
			set @SQL=@SQL+' order by DocDate'  
			
			exec sp_executesql  @SQL,N'@PWLastPRate FLOAT OUTPUT',@PWLastPRate OUTPUT    			
		end
	end
	
	
	if @CalcLastPCost=1--To Calculate last purchase cost
	begin
		set @WHERE=''
		select @WHERE=lastvaluevouchers from adm_costcenterdef  WITH(NOLOCK) 
		where costcenterid=@CostCenterID and  linkdata=50051 and LocalReference=79  
		
		set @CCWHERE=''
			if (@WHERE is not null and @WHERE like '%~%')
			BEGIN
				set @CNT=Charindex('~',@WHERE,0)
				
				set @CCWHERE= substring(@WHERE,@CNT+1,5000)
				set @WHERE= substring(@WHERE,0,@CNT)
				
				insert into @tblSplitcc  
				exec SPSplitString @CCWHERE,','
				
				set @CCWHERE=''
				
			   select @CCWHERE=@CCWHERE+' and dcccnid'+convert(nvarchar(max),(CCIDS-50000))+'='+convert(nvarchar(max),NodeId)
			   from @tblSplitcc a
			   join @tblCC b on a.CCIDS=b.CostCenterID
			END
			
		set @SQL='select @LastPCost=StockValueFC/UOMConvertedQty from INV_DocDetails a with(nolock)  '
			if(@CCWHERE<>'')
				set @SQL=@SQL+' join com_docccdata b with(nolock) on a.INVDocDetailsid=b.INVDocDetailsid '
				
			set @SQL=@SQL+' where IsQtyIgnored=0 and VoucherType=1 and ProductID in ('+@ProductIDS+')  and DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))
		if (@WHERE is not null and @WHERE<>'')  
				set @SQL=@SQL+' and CostcenterID in ('+@WHERE+') '
		
		if (@CCWHERE<>'')  
				set @SQL=@SQL+@CCWHERE
						
		set @SQL=@SQL+'  and UOMConvertedQty is not null and UOMConvertedQty>0   
		order by DocDate'   
		  print @SQL
		exec sp_executesql  @SQL,N'@LastPCost FLOAT OUTPUT',@LastPCost OUTPUT    	
			
	end
	
	if @CalcLastPRate=1--To Calculate last purchase rate
	begin	
		set @WHERE=''
		select @WHERE=lastvaluevouchers from adm_costcenterdef WITH(NOLOCK) 
		where costcenterid=@CostCenterID and linkdata=23820 and LocalReference=79  
		
		set @CCWHERE=''
			if (@WHERE is not null and @WHERE like '%~%')
			BEGIN
				set @CNT=Charindex('~',@WHERE,0)
				
				set @CCWHERE= substring(@WHERE,@CNT+1,5000)
				set @WHERE= substring(@WHERE,0,@CNT)
				
				insert into @tblSplitcc  
				exec SPSplitString @CCWHERE,','
				
				set @CCWHERE=''
				
			   select @CCWHERE=@CCWHERE+' and dcccnid'+convert(nvarchar(max),(CCIDS-50000))+'='+convert(nvarchar(max),NodeId)
			   from @tblSplitcc a
			   join @tblCC b on a.CCIDS=b.CostCenterID
			END
			
		set @SQL='select  @LastPRate=Rate*ExchangeRate from INV_DocDetails a WITH(NOLOCK) '
			if(@CCWHERE<>'')
				set @SQL=@SQL+' join com_docccdata b with(nolock) on a.INVDocDetailsid=b.INVDocDetailsid '
				
			set @SQL=@SQL+' where IsQtyIgnored=0 and VoucherType=1 and ProductID in ('+@ProductIDS+')  and DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))
			if (@WHERE is not null and @WHERE<>'')  
				set @SQL=@SQL+' and CostcenterID in ('+@WHERE+') '
			
			if (@CCWHERE<>'')  
				set @SQL=@SQL+@CCWHERE	
	
			+'  order by DocDate' 
			 
		exec sp_executesql  @SQL,N'@LastPRate FLOAT OUTPUT',@LastPRate OUTPUT    		 
	end
	
	if @CalcLastPRSNS=1--To Calculate last purchase rate Stock non stock
	begin	
		set @WHERE=''
		select @WHERE=lastvaluevouchers from adm_costcenterdef WITH(NOLOCK) 
		where costcenterid=@CostCenterID and linkdata=55479 and LocalReference=79  
		
		set @CCWHERE=''
			if (@WHERE is not null and @WHERE like '%~%')
			BEGIN
				set @CNT=Charindex('~',@WHERE,0)
				
				set @CCWHERE= substring(@WHERE,@CNT+1,5000)
				set @WHERE= substring(@WHERE,0,@CNT)
				
				insert into @tblSplitcc  
				exec SPSplitString @CCWHERE,','
				
				set @CCWHERE=''
				
			   select @CCWHERE=@CCWHERE+' and dcccnid'+convert(nvarchar(max),(CCIDS-50000))+'='+convert(nvarchar(max),NodeId)
			   from @tblSplitcc a
			   join @tblCC b on a.CCIDS=b.CostCenterID
			END
			
		
		set @SQL='select  @LastPRSNS=Rate*ExchangeRate from INV_DocDetails a WITH(NOLOCK) '
			if(@CCWHERE<>'')
				set @SQL=@SQL+' join com_docccdata b with(nolock) on a.INVDocDetailsid=b.INVDocDetailsid '
				
			set @SQL=@SQL+' where VoucherType=1 and ProductID in ('+@ProductIDS+')  and DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))
			if (@WHERE is not null and @WHERE<>'')  
				set @SQL=@SQL+' and CostcenterID in ('+@WHERE+') '
			
			if (@CCWHERE<>'')  
				set @SQL=@SQL+@CCWHERE	
	
			+'  order by DocDate' 
			 print @SQL
		exec sp_executesql  @SQL,N'@LastPRSNS FLOAT OUTPUT',@LastPRSNS OUTPUT    		 
	end
		if exists (select linkdata from adm_costcenterdef WITH(NOLOCK) 
		where costcenterid=@CostCenterID and SysColumnName='DebitAccount'  AND localreference IS NULL and linkdata is not null and linkdata<>0)
		BEGIN
			select @NODEID=linkdata from adm_costcenterdef WITH(NOLOCK) 
			where costcenterid=@CostCenterID and SysColumnName='DebitAccount'
			if(@NODEID<0)
			BEGIN
				set @NODEID=@NODEID*-1
				SELECT @DrName=SysColumnName FROM ADM_CostCenterDef with(nolock) WHERE CostCenterColID=@NODEID		
				
				if(@DrName like 'ptAlpha%')				
					set @SQL='select  @DrAccount=b.'+@DrName+' FROM INV_Product a WITH(NOLOCK) 
					LEFT join INV_Product pa WITH(NOLOCK)  on a.ParentID=pa.ProductID
					LEFT join INV_ProductExtended b on pa.ProductID=b.ProductID 
					WHERE a.ProductID='+convert(nvarchar,@ProductID)			
				ELSE
					set @SQL='select  @DrAccount=pa.'+@DrName+' FROM INV_Product a WITH(NOLOCK) 
					LEFT join INV_Product pa WITH(NOLOCK)  on a.ParentID=pa.ProductID					
					WHERE a.ProductID='+convert(nvarchar,@ProductID)				
			END
			ELSE
			BEGIN			
				SELECT @DrName=SysColumnName FROM ADM_CostCenterDef with(nolock) WHERE CostCenterColID=@NODEID		
				set @SQL='select  @DrAccount='+@DrName+' FROM INV_Product a WITH(NOLOCK) 
				join INV_ProductExtended b with(nolock) on a.ProductID=b.ProductID WHERE a.ProductID='+convert(nvarchar,@ProductID)
			END	
			print @SQL
			exec sp_executesql @SQL,N'@DrAccount INT OUTPUT',@DrAccount OUTPUT							
			if(@DrAccount>0)
				select 		@DrName=AccountName from ACC_Accounts with(nolock)  where AccountID= @DrAccount 	
	
		END 
		else
			set @DrAccount=0
		
		if exists (select prefvalue from [com_documentpreferences] WITH(NOLOCK) 
		where costcenterid=@CostCenterID  and PrefName='ProductDefaultVendor' AND prefvalue='true')
		BEGIN
			set @CrAccount=isnull((select top 1 AccountID from INV_ProductVendors with(nolock)
			where ProductID=@ProductID
			order by Priority),0)
			if(@CrAccount>0)
				select @CrName=AccountName from ACC_Accounts with(nolock)  where  AccountID= @CrAccount	
		END       
		else
			set @CrAccount=0
			
		if exists (select linkdata from adm_costcenterdef WITH(NOLOCK) 
		where costcenterid=@CostCenterID  and SysColumnName='CreditAccount' AND localreference IS NULL and linkdata is not null and linkdata<>0)
		BEGIN
			select @NODEID=linkdata from adm_costcenterdef WITH(NOLOCK) 
			where costcenterid=@CostCenterID and SysColumnName='CreditAccount'
			
			if(@NODEID<0)
			BEGIN
				set @NODEID=@NODEID*-1			
				SELECT @CrName=SysColumnName FROM ADM_CostCenterDef with(nolock) WHERE CostCenterColID=@NODEID		
				if(@CrName like 'ptAlpha%')				
					set @SQL='select  @CrAccount=b.'+@CrName+' FROM INV_Product   a WITH(NOLOCK) 
					LEFT join INV_Product pa WITH(NOLOCK)  on a.ParentID=pa.ProductID
					LEFT join INV_ProductExtended b with(nolock) on pa.ProductID=b.ProductID 
					WHERE a.ProductID='+convert(nvarchar,@ProductID)
				else
					set @SQL='select  @CrAccount=pa.'+@CrName+' FROM INV_Product   a WITH(NOLOCK) 
					LEFT join INV_Product pa WITH(NOLOCK)  on a.ParentID=pa.ProductID					
					WHERE a.ProductID='+convert(nvarchar,@ProductID)	
			END	
			ELSE
			BEGIN				
				SELECT @CrName=SysColumnName FROM ADM_CostCenterDef with(nolock) WHERE CostCenterColID=@NODEID		
				set @SQL='select  @CrAccount='+@CrName+' FROM INV_Product   a WITH(NOLOCK) 
				join INV_ProductExtended b with(nolock) on a.ProductID=b.ProductID WHERE a.ProductID='+convert(nvarchar,@ProductID)
			END	
			print @SQL
			exec sp_executesql @SQL,N'@CrAccount INT OUTPUT',@CrAccount OUTPUT	
			if(@CrAccount>0)
				select 		@CrName=AccountName from ACC_Accounts  where  AccountID= @CrAccount	
		END       
		
		if @CalcLocQOH=1 and exists (select NodeId from @tblCC where CostCenterID=50002)--Calculating Location QOH
		begin
			select @NODEID=NodeId from @tblCC where CostCenterID=50002
			
			set @SQL='set @LocQOH=(SELECT isnull(sum(UOMConvertedQty*case when vouchertype=1 and statusid in(371,441) then 0 else  VoucherType end),0) FROM INV_DocDetails D WITH(NOLOCK)        
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID in ('+@ProductIDS+') AND IsQtyIgnored=0 and D.StatusID in(371,441,369) AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))        
			set @SQL=@SQL+' and  Dcccnid2='+convert(nvarchar,@NODEID)+' and (VoucherType=1 or VoucherType=-1) )'         
			      
			EXEC sp_executesql @SQL, N'@LocQOH float OUTPUT', @LocQOH OUTPUT        
			
		end
	
		if @CalcDivQOH=1 and exists (select NodeId from @tblCC where CostCenterID=50001)--Calculating Division QOH
		begin
			select @NODEID=NodeId from @tblCC where CostCenterID=50001
			
			set @SQL='set @DivQOH=(SELECT isnull(sum(UOMConvertedQty*case when vouchertype=1 and statusid in(371,441) then 0 else  VoucherType end),0) FROM INV_DocDetails D WITH(NOLOCK)        
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID in ('+@ProductIDS+') AND IsQtyIgnored=0 and D.StatusID in(371,441,369) AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))        
			set @SQL=@SQL+' and  Dcccnid1='+convert(nvarchar,@NODEID)+' and (VoucherType=1 or VoucherType=-1) )'         
			      
			EXEC sp_executesql @SQL, N'@DivQOH float OUTPUT', @DivQOH OUTPUT        
			
		end

	
	if(@ptype=5 and @DocumentType in(31,32) and @CalcQOH=1 )
		set @CalcQOH=0
	
		select @IsTestCase=Value from @TblPref where Name='ConsiderUnAppInHold' 
	
	--AVG RATE SP CALL
	IF @CalcAvgrate=1 or @CalcQOH=1 or @CalcBalQOH=1 or @CalcHOLDQTY=1 or @CalcCommittedQTY=1 or @CalcRESERVEQTY=1
		EXEC [spDOC_StockAvgValue] @ProductID,@CCXML,@DocDate,@DocQty,@CalcAvgrate,@DocDetailsID
			,@CalcQOH,@CalcBalQOH,@CalcHOLDQTY,@CalcCommittedQTY,@CalcRESERVEQTY,@CalcTotRESERVEQTY,@IsTestCase
			,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotRESERVE output,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID
    
         
        if(@UOMID=0)        
        begin 
			  if(@DocumentType in(1,2,3,4,6,13,25,26,27,39))
			  BEGIN
				  select @UOMID=PurchaseUom from INV_Product a WITH(NOLOCK)                 
				  WHERE ProductID = @ProductID
				  if(@UOMID is null or @UOMID=0)
					select @UOMID=UOMID from INV_Product a WITH(NOLOCK)                 
					WHERE ProductID = @ProductID
			  END
			  ELSE
			  BEGIN
				  select @UOMID=UOMID from INV_Product a WITH(NOLOCK)                 
				  WHERE ProductID = @ProductID
			  END	  
        end
        
        if(@IsTestCase=1 and exists(select DocumentID from INV_ProductTestcases WITH(NOLOCK) 
        where DocumentID=@CostCenterID and ProductID=@ProductID))
			set @TestCaseExists=1
		ELSE
			set @TestCaseExists=0
			
          
        select @uBarcode=Barcode,@uBarcodeKey=Barcode_Key  from INV_ProductBarcode WITH(NOLOCK)  where ProductID =@ProductID and UNITID=@UOMID  
          
        select @VBarcode=Barcode from INV_ProductBarcode WITH(NOLOCK)  where ProductID =@ProductID and VenderID=@CreditAccount  
    
       	select @VendorQty=MinOrderQty from INV_ProductVendors WITH(NOLOCK)
		where ProductID=@ProductID and AccountID=@CreditAccount
        
        SELECT a.ProductID,a.ProductName,a.ProductCode,ProductTypeID,AttributeGroupID,@UOMID uomid,BaseName,UnitName,b.Conversion        
        ,reorderlevel,reorderqty,PurchaseRate,PurchaseRateA,PurchaseRateB,PurchaseRateC,PurchaseRateD,PurchaseRateE,PurchaseRateF,PurchaseRateG        
        ,SellingRate,SellingRateA,SellingRateB,SellingRateC,SellingRateD,SellingRateE,SellingRateF,SellingRateG,@TestCaseExists TestCaseExists
        ,f.FileExtension,f.GUID FileGUID,@LastPCost LastPCost,@PWLastPCost  PWLastPCost,CreditDays,QtyAdjustType,IsPacking,IsBillOfEntry,Packing
        ,@AvgRate AvgRate,@LastPRate LastPurchaseRate,@PWLastPRate PWLastPRate,@QOH QOH ,@HOLDQTY HOLDQTY,@RESERVEQTY RESERVEQTY,@CommittedQTY CommittedQTY    
        ,@uBarcode UnitProductCode,@uBarcodeKey Barcode_Key,@VBarcode VendorProductCode,@TotRESERVE TotalReserve,@BalQOH BalQOH,@DrAccount DrAccount,@DrName DrName,@CrAccount CrAccount,@CrName CrName
        ,@VendorQty VendorQty,@stockID stockID,@dp dp,@rp rp,@AvgPrice AvgPrice,isnull(BinWise,0) BinWise,a.UOMID ProdBaseUOM,@LastPRSNS LPRStockNonStock
        ,IsWeightable,@LocQOH Loc_QOH,@DivQOH Div_QOH
        FROM INV_Product a WITH(NOLOCK)    
        left join  COM_UOM b WITH(NOLOCK)   on b.UOMID=@UOMID     
        left join COM_Files f WITH(NOLOCK) on FeaturePK=@ProductID and FeatureID=3 and IsProductImage=1      
        WHERE a.ProductID = @ProductID     
		
		if(@stockID is not null and @stockID>0 and @IsPromo is not null and @IsPromo=1)
		BEGIN
			set @SQL='select a.ProductID,b.ProductCode,b.ProductName,a.Quantity,u.UnitName,a.Unit,u.Conversion,b.ProductTypeID from INV_DocDetails a WITH(NOLOCK)
			join INV_DocDetails I with(nolock) on a.DynamicInvDocDetailsID=I.InvDocDetailsID
			join COM_DocCCData c WITH(NOLOCK) on i.InvDocDetailsID=c.InvDocDetailsID			 
			join INV_Product b WITH(NOLOCK) on a.ProductID=b.ProductID
			join COM_UOM u WITH(NOLOCK) on a.Unit=u.UOMID
			where dcCCNID'+CONVERT(nvarchar,(@StCCID-50000))+'='+CONVERT(nvarchar,@stockID)+' and i.VoucherType=1 and i.IsQtyIgnored=0'
			exec(@sql)
		END
		ELSE
			select 1 where 1<>1
         
         select 1 where 1<>1      
                
	exec [spDOC_GetPriceTax]       
      @ProductID =@ProductID,
      @CCXML =@CCXML,
      @DocDate=@DocDate,
      @DocDetailsID=@DocDetailsID,
	  @ProfileID=@ProfileID,
	  @UOMID=@UOMID,
      @CostCenterID =@CostCenterID, 
      @DocQty=@DocQty,
	  @CalcAvgrate =@CalcAvgrate, 
      @CalcQOH =@CalcQOH,
	  @CalcBalQOH =@CalcBalQOH ,
	  @CalcHOLDQTY =@CalcHOLDQTY,
	  @CalcCommittedQTY =@CalcCommittedQTY ,
	  @CalcRESERVEQTY =@CalcRESERVEQTY,	  
	  @DocumentType=@DocumentType,	  
	  @mode=4,
	  @RoleID=@RoleID ,    
      @UserID =@UserID ,      
      @LangID =@LangID 
            
   	SELECT  a.ProductID,b.Productcode,b.ProductName,Quantity,Rate,LinkType,c.KitSize,a.UNIT,a.ModifierName,a.MinSelect,a.MaxSelect
	FROM INV_ProductBundles a WITH(NOLOCK)           
	join inv_product b WITH(NOLOCK)  on a.ProductID=b.ProductID 
	join inv_product c WITH(NOLOCK)  on a.ParentProductID=c.ProductID 
	where a.ParentProductID=@ProductID
       
 --  set @SQL='SELECT C.SysColumnName,P.* FROM COM_CCTaxes P with(nolock)        
 --     INNER JOIN ADM_CostCenterDef C WITH(NOLOCK) on P.ColID=C.CostCenterColID        
 --      where DOCID ='+convert(nvarchar,@CostCenterID)+'  and WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE+' order by WEF Desc'+@OrderBY         
	----print @SQL 
	--exec(@SQL)        
        
	if(@CostCenterID=78)  
	begin     
		--To Get Last Unit Cost        
		SELECT TOP 1 Rate FROM INV_DocDetails WITH(NOLOCK)        
		WHERE @CostCenterID=78 AND DocumentType=34 AND ProductID=@ProductID        
		AND DocDate<=CONVERT(float,@DocDate)        
		ORDER BY DocDate DESC        
	end  
	else  
	begin  
		select 1  
	end       
          
	select @PrefValue=value from com_costcenterpreferences   WITH(NOLOCK)    
	where costcenterid=3 and name='LinkedProductDimension'        
	set @CC=0        
	if(@PrefValue is not null and @PrefValue<>'')        
	begin        
		set @CC=convert(int,@PrefValue)        
		if(@CC=50006)        
			set @SQL='select @NodeID=CategoryID FROM  INV_Product WITH(NOLOCK)        
			where ProductID='+convert(nvarchar,@ProductID)           
		else if(@CC=50004)        
			set @SQL='select @NodeID=DepartmentID FROM  INV_Product WITH(NOLOCK)         
			where ProductID='+convert(nvarchar,@ProductID)        
		else        
			set @SQL='select @NodeID=ccnid'+convert(nvarchar,@CC-50000)+' FROM  com_ccccdata WITH(NOLOCK)         
			where NodeID='+convert(nvarchar,@ProductID)+' and costcenterid=3'        
		
		if(@CC>0)      
		begin      
			EXEC sp_executesql @SQL, N'@NodeID INT OUTPUT', @NodeID OUTPUT              
		end      
	end        
          
  SELECT  LinkType,a.ProductID,b.Productcode,ProductName        
  FROM INV_LinkedProducts a WITH(NOLOCK)           
  join inv_product b WITH(NOLOCK)  on a.ProductID=b.ProductID          
  where a.CostCenterID=@CC  and NodeID=@NodeID        
         
  
	select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
	where PrefName ='EnableSubtitutes' and costcenterid=@CostCenterID
	
	set @CCWHERE=''
	select @CCWHERE=PrefValue from COM_DocumentPreferences with(nolock)
	where PrefName ='SubstituteOnQty' and costcenterid=@CostCenterID

	if(@IsLink=0 and @PrefValue is not null and @PrefValue='true' and not (@CCWHERE is not null and @CCWHERE='true'))
	begin		
		exec spDOC_GetSubtituteProducts   @ProductID,@CCXML,@DocDate,@DocDetailsID,@CostCenterID,@UserID,@LangID 
	END
	else
	BEGIN
		select 1 where 1=2
		select 1 where 1=2
	END
 
   
	select @PrefValue= Value from com_costcenterpreferences WITH(NOLOCK) where name='BinsDimension' and costcenterid=3  
	if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0 )        
	begin  
		set @CcID=convert(INT,@PrefValue)  

		set @SQL='select @NODEID=BinNodeID from INV_ProductBins WITH(NOLOCK)  where NodeID='+convert(nvarchar,@ProductID )  
		set @SQL=@SQL+' and BinDimension='+convert(nvarchar,@CcID)+ ' and isdefault=1 '  

		select @PrefValue= Value from @TblPref where Name='EnableLocationWise'        

		if(@PrefValue='True' and exists (select NodeId from @tblCC where CostCenterID=50002))        
		begin        
			set @PrefValue=''      
			select @PrefValue= Value from @TblPref where Name='LW Bins'        
			if(@PrefValue='True')      
			begin      
				select @NID=NodeId from @tblCC where CostCenterID=50002        
				set @SQL=@SQL +' and Location='+CONVERT(nvarchar,@NID)        
			end       
		end      

		select @PrefValue= Value from @TblPref where Name='EnableDivisionWise'        

		if(@PrefValue='True' and exists (select NodeId from @tblCC where CostCenterID=50001))        
		begin        
			set @PrefValue=''      
			select @PrefValue= Value from @TblPref where Name='DW Bins'        
			if(@PrefValue='True')      
			begin
				select @NID=NodeId from @tblCC where CostCenterID=50001                  
				set @SQL=@SQL +' and Division='+CONVERT(nvarchar,@NID)         
			end   
		end 
		
		set @PrefValue=''
		select @PrefValue= Value from @TblPref  where Name='DimensionwiseBins' and isnumeric(Value)=1  
		if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>50000)        
		begin  		
			select @NID=NodeId from @tblCC where CostCenterID=convert(INT,@PrefValue)                  
			set @SQL=@SQL +' and DimNodeID='+CONVERT(nvarchar,@NID)         		   
		end 

		set @NODEID=0    
		exec sp_executesql @SQL,N'@NODEID INT OUTPUT',@NODEID output    
		if(@NODEID>0)  
		begin  

			select @PrefValue=tablename from adm_features WITH(NOLOCK)  where featureid=@CcID  
			declare @Name nvarchar(200)  
			set @SQL='select @Name=name  from '+@PrefValue+' WITH(NOLOCK) where Nodeid='+CONVERT(nvarchar,@NODEID)  

			exec sp_executesql @SQL,N'@Name nvarchar(200) OUTPUT',@Name output  
			select  @NODEID BinId,@Name BinName  
		end  
		else   
			select  0 BinId,'' BinName  
	end  
	else   
		select  0 BinId,'' BinName  

	SELECT * FROM  COM_Files WITH(NOLOCK) 
	WHERE FeatureID=3 and  FeaturePK=@ProductID
	
	IF @CurrencyID IS NOT NULL and @CurrencyID>0
	BEGIN
		set @NODEID=1
		set @CcID=0
		select @CcID=isnull(value,0) from ADM_GlobalPreferences with(nolock) 
		where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
		if(@CcID>0)
			select @NODEID=NodeId from @tblCC where CostCenterID=@CcID
		
		SELECT CurrencyID,Name from COM_Currency  with(nolock)where CurrencyID=@CurrencyID
		EXEC [spDoc_GetCurrencyExchangeRate] @CurrencyID,@DocDate,@NODEID,@LangID
		
	END
	else
	begin
		select 1 CurrencyID where 1=2
		select 1 Rate where 1=2
	end
   
    
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
           SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine        
            FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
      END
 SET NOCOUNT OFF
RETURN -999
END CATCH


GO
