USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetLinkDocDetails]
	@VoucherNo [nvarchar](max),
	@DocumentLinkDefID [int],
	@DocID [int] = 0,
	@AccID [int] = 0,
	@DimWhere [nvarchar](max) = '',
	@IgnoreSpec [int],
	@StrJoin [nvarchar](max),
	@StrWhere [nvarchar](max),
	@listTypeID [int],
	@invIDs [nvarchar](max),
	@CCid [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    
    
	--Declaration Section    
	DECLARE @Tolerance nvarchar(50),@CostCenterID int,@LinkCostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50),@ProductColName  nvarchar(50)   
	DECLARE @Query nvarchar(max),@Vouchers nvarchar(max),@ColID INT,@lINKColID INT,@ColHeader nvarchar(200),@PrefValue nvarchar(50),@PackQty nvarchar(50)
	declare @autoCCID int,@tempDOcID INT,@CrAccID INT,@DbAccID INT,@docType int ,@LinkdocType int,@Join nvarchar(max),@Where nvarchar(max),@GroupFilter nvarchar(max)

	--SP Required Parameters Check    
	IF (@VoucherNo ='' or @DocumentLinkDefID < 1) and @invIDs=''   
	BEGIN    
		RAISERROR('-100',16,1)    
	END    
    
	SELECT @CostCenterID=[CostCenterIDBase]    
	,@ColID=[CostCenterColIDBase]    
	,@LinkCostCenterID=[CostCenterIDLinked]    
	,@lINKColID=[CostCenterColIDLinked]    
	,@Vouchers = [LinkedVouchers]     
	,@docType=b.DocumentType,@LinkdocType=c.DocumentType
	FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
	join ADM_DocumentTypes b  WITH(NOLOCK) on a.CostCenterIDBase=b.CostCenterID
	join ADM_DocumentTypes c  WITH(NOLOCK) on a.CostCenterIDLinked=c.CostCenterID
	where [DocumentLinkDefID]=@DocumentLinkDefID   
    
	SELECT @ColumnName=SysColumnName from ADM_CostCenterDef   WITH(NOLOCK)  
	where CostCenterColID=@lINKColID    

	SELECT @lINKColumnName=SysColumnName from ADM_CostCenterDef  WITH(NOLOCK)  
	where CostCenterColID=@ColID  

	set @ColHeader=(select top 1 r.ResourceData from ADM_CostCenterDef c   WITH(NOLOCK)  
	join COM_LanguageResources r WITH(NOLOCK)  on r.ResourceID=c.ResourceID and r.LanguageID=@LangID    
	where CostCenterColID=@lINKColID)    
    
    if (@listTypeID>0)
    BEGIN
		select @Where=SearchFilter,@GroupFilter=GroupSearchFilter  from ADM_ListView WITH(NOLOCK) where CostCenterID=3 and ListViewTypeID=@listTypeID
		
		if(@StrWhere='')
		BEGIN
			if(@Where is not null and len(@Where)>0)
				set @Where =' and '+REPLACE(@Where,'a.','p.')
			else
				set @Where =''
					
			set @Join=' LEFT JOIN COM_CCCCData CC with(nolock) ON CC.COSTCENTERID=3 and CC.NODEID=p.ProductID '
		END
		ELSE
		BEGIN
			if(@Where is not null and len(@Where)>0)
				set @Where =' and '+@Where
			else
				set @Where =' '
			set @Join=' '
		END	
		
		if(@Where is not null and @Where like '%Grp.%')
				set @Join=@Join+' join Inv_product Grp WITH(NOLOCK) on p.lft between Grp.lft and Grp.rgt '
		
		if(@GroupFilter is not null and @GroupFilter like '%Grp.%')
		BEGIN
			if(@GroupFilter like '%Grp.ProductID  <>%')
			BEGIN
					set @GroupFilter =REPLACE(@GroupFilter,'Grp.ProductID  <>','Grp.ProductID =')
					set @GroupFilter =REPLACE(@GroupFilter,'and','or')
					set @Join=@Join+' LEFT join Inv_product Grp WITH(NOLOCK) on p.lft between Grp.lft and Grp.rgt '
					set @Join=@Join+' and ('+@GroupFilter+') '
					
					 IF (@Where IS not NULL and len(@Where) > 0)        
						SET @Where=@Where+' and Grp.ProductID IS NULL '      
					 else
				 		SET @Where=' Grp.ProductID  IS NULL '         				
			END
			ELSE
			BEGIN
				set @Join=@Join+' join Inv_product Grp WITH(NOLOCK) on p.lft between Grp.lft and Grp.rgt '
				set @GroupFilter =REPLACE(@GroupFilter,'and','or')
				set @Join=@Join+' and ('+@GroupFilter+') '
			END	
		end
	END
	  
	--Create temporary table     
	create  TABLE #tblDocList(ID int identity(1,1),DocDetailsID INT,Val float,PercentValue FLOAT,VoucherType int,DocSeqNo int,alpha nvarchar(max),ProductID INT,QDocID INT)      
	if(@invIDs<>'')
	BEGIN
		insert into #tblDocList(DocDetailsID)
		EXEC SPSplitString @invIDs,','
		
		update #tblDocList
		set Val=0,PercentValue=0,VoucherType =-1,DocSeqNo=1
		
		select @LinkCostCenterID=a.costcenterid	from inv_docdetails a with(nolock)
		inner join #tblDocList c WITH(NOLOCK) on a.InvDocDetailsID=c.DocDetailsID
		 
			SELECT @CostCenterID=[CostCenterIDBase]    
		,@ColID=[CostCenterColIDBase]    
		,@LinkCostCenterID=[CostCenterIDLinked]    
		,@lINKColID=[CostCenterColIDLinked]    
		,@Vouchers = [LinkedVouchers]     
		,@docType=b.DocumentType,@LinkdocType=c.DocumentType
		FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
		join ADM_DocumentTypes b  WITH(NOLOCK) on a.CostCenterIDBase=b.CostCenterID
		join ADM_DocumentTypes c  WITH(NOLOCK) on a.CostCenterIDLinked=c.CostCenterID
		where [CostCenterIDBase]=@CCid and [CostCenterColIDLinked]=@LinkCostCenterID
	    
		SELECT @ColumnName=SysColumnName from ADM_CostCenterDef   WITH(NOLOCK)  
		where CostCenterColID=@lINKColID    

		SELECT @lINKColumnName=SysColumnName from ADM_CostCenterDef  WITH(NOLOCK)  
		where CostCenterColID=@ColID  

		set @ColHeader=(select top 1 r.ResourceData from ADM_CostCenterDef c   WITH(NOLOCK)  
		join COM_LanguageResources r WITH(NOLOCK)  on r.ResourceID=c.ResourceID and r.LanguageID=@LangID    
		where CostCenterColID=@lINKColID)    
		
	END
	ELSE
	BEGIN
		
		set @Tolerance=''	
		set @PackQty=''
		
		select @Tolerance=PrefValue from COM_DocumentPreferences WITH(NOLOCK)       
		where CostCenterID=@CostCenterID and PrefName='Enabletolerance'          
		
		select @PackQty=PrefValue from COM_DocumentPreferences WITH(NOLOCK)
		where CostCenterID=@CostCenterID and PrefName ='Checkpackedqty' 


		set @Query=''
	  
		set @Query=@Query+'select InvDocDetailsID,value,PercentValue,VoucherType,DocSeqNo,ProductID,DocID from ('
		
		if(@PackQty='true')
			set @Query=@Query+'SELECT distinct a.InvDocDetailsID,case when p.IsPacking=1 THEN cast(isnull(sum(DE.Quantity),0)-isnull(sum(b.LinkedFieldValue),0) as numeric(36,5)) ELSE cast(a.'+@ColumnName+'-isnull(sum(b.LinkedFieldValue),0) as numeric(36,5)) END as value '
  		ELSE
  		BEGIN
  			set @Query=@Query+'SELECT distinct a.InvDocDetailsID, cast(a.'+@ColumnName+'-isnull(sum('
	  		
  			set @Query=@Query+' case when b.Statusid=376 or b.DocID='+convert(nvarchar,@DocID)+' then 0 '
		
		
			select @PrefValue=PrefValue from COM_DocumentPreferences  WITH(NOLOCK)       
			where CostCenterID=@LinkCostCenterID and PrefName='AllowMultipleLinking'                     
			if(@PrefValue is not null and @PrefValue='True'    ) --FOr Linking Multiple        
			BEGIN    
				DECLARE @FinalStr nvarchar(max)
				if(@Vouchers is not null and @Vouchers <>'')
				BEGIN
					SET @FinalStr =@Vouchers
					SET @FinalStr = @FinalStr +','+convert(nvarchar(5),@CostCenterID)   
				END 
				ELSE
					SET @FinalStr = convert(nvarchar(5),@CostCenterID)       
					--SET @Query=@Query+' and b.CostCenterid='+convert(nvarchar(5),@CostCenterID)   
				SET @Query=@Query+' when b.CostCenterid  not in ('+@FinalStr  +') then 0 '
			END  
	  		
	  		
			set @Query=@Query+' else b.LinkedFieldValue end ),0)as numeric(36,5)) value '      
	  		
		END
		if(@Tolerance is not null and @Tolerance='True'    )
			set @Query=@Query+',max(isnull(p.MinTolerancePer,0)) TPercentage,max(isnull(p.MinToleranceVal,0)) TValue
				,(a.'+@ColumnName+'*max(isnull(p.MaxTolerancePer,0)))/100 PercentValue	,(a.'+@ColumnName+'*max(isnull(p.MinTolerancePer,0)))/100 per,max(isnull(p.MaxTolerancePer,0)) thp,max(isnull(p.MaxToleranceVal,0)) THV '
		else
			set @Query=@Query+',0 PercentValue '
			
		IF(@ColumnName LIKE 'dcNum%' )    
			SET @Query=@Query+',d.VoucherType,d.DocSeqNo,d.ProductID,d.DocID from COM_DocNumData a with(nolock) ' +      
			'join INV_DocDetails d with(nolock) on a.InvDocDetailsID =d.InvDocDetailsID  
			join inv_product p  with(nolock) on d.ProductID=p.ProductID     
			join COM_DocCCData DC with(nolock) on d.InvDocDetailsID =DC.InvDocDetailsID'      
		ELSE      
			SET @Query=@Query+',a.VoucherType,a.DocSeqNo,a.ProductID,a.DocID from INV_DocDetails a with(nolock) 
			join inv_product p  with(nolock) on a.ProductID=p.ProductID
			join COM_DocCCData DC with(nolock) on a.InvDocDetailsID =DC.InvDocDetailsID'      
		   
		SET @Query=@Query+' left join INV_DocDetails B WITH(NOLOCK) on a.InvDocDetailsID =b.LinkedInvDocDetailsID'     
	  
		if (@listTypeID>0 and @StrWhere='')
			  SET @Query=@Query+@Join

		set @PrefValue=''
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)
		where CostCenterID=@CostCenterID and PrefName='LinkVendorProducts'        
	          
		if(@PrefValue is not null and @PrefValue='True')
		BEGIN
			SET @Query=@Query+' join INV_ProductVendors PV WITH(NOLOCK) ON p.ProductID=pv.ProductID and pv.AccountID='+convert(nvarchar,@AccID)
		END   
	    
		if(@PackQty='true')
		BEGIN
			SET @Query=@Query+' left join INV_DocExtraDetails DE WITH(NOLOCK) ON a.InvDocDetailsID=DE.InvDocDetailsID and DE.TYPE=2 '
		END   

		IF(@ColumnName LIKE 'dcNum%' )    
			SET @Query=@Query+' where d.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID) +' and d.VoucherNo in ('''+@VoucherNo+''')' 
		ELSE    
			SET @Query=@Query+' where a.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID) +' and a.VoucherNo in ('''+@VoucherNo+''')'  
		
		
		if (@listTypeID>0 and @StrWhere='')
			SET @Query=@Query+@where
			
		set @PrefValue=''  
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)     
		where CostCenterID=@CostCenterID and PrefName='IgnoreTempProduct'        
	        
		if(@PrefValue is not null and @PrefValue='True')--      
		begin  		
			select @PrefValue=Value from COM_CostCenterPreferences WITH(NOLOCK)     
			where CostCenterID=3 and Name='TempPartProduct'  
			if(@PrefValue is not null and @PrefValue<>'')--      
			begin  		
				IF(@ColumnName LIKE 'dcNum%' )    
					SET @Query=@Query+' and d.ProductID<>'+@PrefValue      
				Else    
					SET @Query=@Query+' and a.ProductID<>'+@PrefValue    
			end  
		end
	  
  		if(@DimWhere is NOT null and @DimWhere<>'') --FOr Dimension filter      
		BEGIN      		
			SET @Query=@Query+@DimWhere
		END
		
		set @PrefValue=''	
		select @PrefValue=PrefValue from COM_DocumentPreferences  WITH(NOLOCK)    
		where CostCenterID=@CostCenterID and PrefName='onlyTempProduct'        
		if(@PrefValue is not null and @PrefValue='True')--      
		begin  		
			select @PrefValue=Value from COM_CostCenterPreferences  WITH(NOLOCK)    
			where CostCenterID=3 and Name='TempPartProduct'  
			if(@PrefValue is not null and @PrefValue<>'')--      
			begin  		
				IF(@ColumnName LIKE 'dcNum%' )    
					SET @Query=@Query+' and d.ProductID='+@PrefValue      
				Else    
					SET @Query=@Query+' and a.ProductID='+@PrefValue    
			end  
		end 
	  
		set @PrefValue=''   
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)      
		where CostCenterID=@CostCenterID and PrefName='linkSingleline'        
		    
		if(@PrefValue is not null and @PrefValue='True')--FOr link Single line      
		begin  
		  IF(@ColumnName LIKE 'dcNum%' )    
			SET @Query=@Query+' and d.DocSeqNo=1'      
		  Else    
			SET @Query=@Query+' and a.DocSeqNo=1'      
		end   
	  
		set @PrefValue=''
  		select @PrefValue=PrefValue from COM_DocumentPreferences  WITH(NOLOCK)  
		where CostCenterID=@CostCenterID and PrefName='Debit Account'        

  		if(@PrefValue is NOT null AND  @PrefValue='True'
  		and @docType in(6,10,7,9,11,12,24)) --FOr Debit Account filter      
		BEGIN      
			if((@docType in(6,10) and @LinkdocType not in(6,10)) or (@LinkdocType in(6,10) and @docType not in(6,10)))
			BEGIN
				IF(@ColumnName LIKE 'dcNum%' )       
				SET @Query=@Query+' and d.CreditAccount = '+convert(nvarchar,@AccID)
			 else
				SET @Query=@Query+' and a.CreditAccount = '+convert(nvarchar,@AccID)
			END
			ELSE
			BEGIN
			 IF(@ColumnName LIKE 'dcNum%' )       
				SET @Query=@Query+' and d.DebitAccount = '+convert(nvarchar,@AccID)
			 else
				SET @Query=@Query+' and a.DebitAccount = '+convert(nvarchar,@AccID)
			END	
		END  
		
		set @PrefValue=''
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)   
		where CostCenterID=@CostCenterID and PrefName='Credit Account'        

  		if(@PrefValue is NOT null AND  @PrefValue='True'
  		and @docType in(1,2,6,3,4,10,25,26,27,13)) --FOr Debit Account filter      
		BEGIN      
			if((@docType in(6,10) and @LinkdocType not in(6,10)) or (@LinkdocType in(6,10) and @docType not in(6,10)))
			BEGIN
				IF(@ColumnName LIKE 'dcNum%' )       
				SET @Query=@Query+' and d.DebitAccount = '+convert(nvarchar,@AccID)
			 else
				SET @Query=@Query+' and a.DebitAccount = '+convert(nvarchar,@AccID)
			END
			ELSE
			BEGIN
			 IF(@ColumnName LIKE 'dcNum%' )       
				SET @Query=@Query+' and d.CreditAccount = '+convert(nvarchar,@AccID)
			 else
				SET @Query=@Query+' and a.CreditAccount = '+convert(nvarchar,@AccID)
			END	
		END  
		
		 set @PrefValue=''
		 select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
		 where CostCenterID=@LinkCostCenterID and PrefName='LinkUnposted'        
		 
		 if(@PrefValue ='true' and @ColumnName LIKE 'dcNum%')
			SET @Query=@Query+' and d.statusid in(369,372) '
		 else  if(@PrefValue ='true')
	 		SET @Query=@Query+' and a.statusid in(369,372) '
		 else if(@ColumnName LIKE 'dcNum%')
			SET @Query=@Query+' and d.statusid=369 '
		 else
			SET @Query=@Query+' and a.statusid=369 '	
			
		set @PrefValue=''
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)     
		where CostCenterID=@CostCenterID and PrefName='OnlyLinked'        
	        
		if(@PrefValue is not null and @PrefValue='True')--FOr link Single line      
		begin
		  IF(@ColumnName LIKE 'dcNum%' )    
			SET @Query=@Query+' and d.LinkedInvDocDetailsID is not null and d.LinkedInvDocDetailsID>0 '      
		  Else
			SET @Query=@Query+' and a.LinkedInvDocDetailsID is not null and a.LinkedInvDocDetailsID>0 '      
		end 
	  
		SET @Query=@Query+' group by a.InvDocDetailsID,p.IsPacking,a.'+@ColumnName 
		
		 IF(@ColumnName LIKE 'dcNum%' )    
			SET @Query=@Query+' ,d.VoucherType,d.DocSeqNo,d.ProductID,d.DocID'      
		  Else
		   SET @Query=@Query+' ,a.VoucherType,a.DocSeqNo,a.ProductID,a.DocID' 
		   
		set @PrefValue=''        
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)       
		where CostCenterID=@CostCenterID and PrefName='LinkZeroQty'          
	    
		if(@PrefValue='true')--FOr Link Zero Qty no validation        
			SET @Query=@Query+') as t'
		ELSE
		begin     
			if(@Tolerance is not null and @Tolerance='True')   
				SET @Query=@Query+') as t
				where ( (TPercentage =0 and thp=0 and THV=0 and TValue=0 and value<>0)
				or (THV >0 and TValue=0 and TPercentage=0 and value>0)
				or (thp >0 and TValue=0 and TPercentage=0 and value>0)
				or (TPercentage >0 and value<>0 and round((value),2)>per )
				or (TValue >0 and value<>0 and round((value),2)>TValue))'
			else
				SET @Query=@Query+' ) as t where cast(value as numeric(36,5)) >0 '    
		end	
	  
		print @Query  
	    
		--Read XML data into   
		INSERT INTO #tblDocList  (DocDetailsID ,Val ,PercentValue ,VoucherType ,DocSeqNo,ProductID,QDocID)
		Exec(@Query)  
		
		if(@LinkdocType=5)
		BEGIN
			delete from #tblDocList
			where DocDetailsID in(
			select min(DocDetailsID)  from #tblDocList WITH(NOLOCK)
			group by  DocSeqNo
			having COUNT(*)=1)
		END    
	END
	
	delete from #tblDocList where ID in (
	select c.id from inv_docdetails a with(nolock)
	inner join #tblDocList c WITH(NOLOCK) on a.InvDocDetailsID=c.DocDetailsID   
	left join inv_docdetails b with(nolock) on b.LinkedInvDocDetailsID=a.InvDocDetailsID
	where isnull(b.docid,-123)<>@docid and a.linkstatusid=445 )
	
	set @Query=''
	select @Query=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=18
	if(@Query<>'')
	begin
		exec @Query @CostCenterID,@DocID,@UserID,@LangID
	end
	
	set @PrefValue=''
    select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)       
    where CostCenterID=@CostCenterID and PrefName='CheckFifoQOH'
	 
	select @ProductColName=SysColumnName from ADM_COSTCENTERDEF WITH(NOLOCK)
	where COSTCENTERID=@LinkCostCenterID and SysColumnName like 'dcalpha%' and ColumnCostCenterID=3

	--GETTING DOCUMENT DETAILS    
	SELECT c.Val, @ColumnName,@ColHeader,@lINKColumnName,@ProductColName ProductColName,A.InvDocDetailsID AS DocDetailsID,A.[AccDocDetailsID],a.VoucherNO    
         ,a.[DocID]    
         ,a.[CostCenterID]             
         ,a.[DocumentType]    
         ,a.[VersionNo]    
         ,a.[DocAbbr]    
         ,a.[DocPrefix]    
         ,a.[DocNumber]    
         ,CONVERT(DATETIME,a.[DocDate]) AS DocDate    
         ,CONVERT(DATETIME,a.[DueDate]) AS DueDate    
         ,CONVERT(DATETIME,a.[BillDate]) AS BillDate    
         ,a.[StatusID]    
         ,a.[BillNo]    
         ,a.[LinkedInvDocDetailsID]    
         ,a.[CommonNarration]    
         ,a.LineNarration    
         ,a.[DebitAccount]     
         ,a.[CreditAccount]   
         ,a.[DocSeqNo]    
         ,p.[ProductID],p.QtyAdjustType,p.IsPacking,p.IsBillOfEntry,p.ProductTypeID,p.ProductName,p.ProductCode,p.Volume,p.Weight,p.ParentID,p.IsGroup,p.Wastage
         ,isnull(p.MaxTolerancePer,0) ToleranceLimitsPercentage,isnull(p.MaxToleranceVal,0)  ToleranceLimitsValue   
         ,PercentValue
         ,a.[Quantity]    
         ,a.Unit  ,u.UnitName  
         ,a.[HoldQuantity]    
         ,a.[ReleaseQuantity]    
         ,a.[IsQtyIgnored]    
         ,a.[IsQtyFreeOffer]    
         ,a.[Rate]    
         ,a.[AverageRate]    
         ,a.[Gross], a.[GrossFC]   
         ,a.[StockValue]  ,a.[StockValueFC]   
         ,a.[CurrencyID]    
         ,a.[ExchangeRate]
         ,a.ParentSchemeID
         ,a.[CreatedBy],a.VoucherType  
         ,a.[CreatedDate],UOMConversion,UOMConvertedQty, Cr.AccountName as CreditAcc, Dr.AccountName as DebitAcc,a.DynamicInvDocDetailsID,a.ReserveQuantity 
         ,case when @PrefValue='true' THEN isnull((select sum(qty) from(
		select inv.Quantity-isnull(sum(lv.LinkedFieldValue),0) qty from INV_DocDetails inv WITH(NOLOCK)  
		left  join  INV_DocDetails lv WITH(NOLOCK) on inv.InvDocDetailsID=lv.LinkedInvDocDetailsID 
		where inv.ProductID=a.ProductID and inv.CostCenterID=a.CostCenterID and  inv.StatusID=369
		and (inv.DocDate<a.DocDate or (inv.DocDate=a.DocDate and inv.VoucherNo<a.VoucherNo))
		group by inv.InvDocDetailsID, inv.Quantity  )as t),0) else 0 end Fifo
	FROM  [INV_DocDetails] a   WITH(NOLOCK)  
	join #tblDocList c WITH(NOLOCK) on a.InvDocDetailsID=c.DocDetailsID  
	join dbo.INV_Product p WITH(NOLOCK) on  c.ProductID=p.ProductID    
	join dbo.Acc_Accounts Cr  WITH(NOLOCK) on  Cr.AccountID=a.CreditAccount    
	join dbo.Acc_Accounts Dr WITH(NOLOCK)  on  Dr.AccountID=a.DebitAccount  
	left join com_uom u WITH(NOLOCK)  on a.Unit=u.UOMID   
	order by a.VoucherNo,a.DocSeqNo,a.VoucherType  ,a.DynamicInvDocDetailsID
	
	set @Query='' 
	SELECT @Query=@Query+','+CASE WHEN TC.name IS NOT NULL THEN 'T' ELSE 'CC' END +'.'+C.name FROM sys.columns C WITH(NOLOCK)
	LEFT JOIN tempdb.sys.columns TC WITH(NOLOCK) ON TC.OBJECT_ID=OBJECT_ID('tempdb..#tblDocList') AND TC.name collate database_default=C.name collate database_default
	WHERE C.OBJECT_ID=OBJECT_ID('COM_DocCCData') and C.name not in ('DocCCDataID')
	order by C.column_id
	
	--GETTING DOCUMENT EXTRA COSTCENTER FEILD DETAILS    
	set @Query='SELECT CC.DocCCDataID'+@Query+' FROM [COM_DocCCData] CC with(nolock)  
	join [INV_DocDetails] D WITH(NOLOCK) on CC.InvDocDetailsID=D.InvDocDetailsID     
	join #tblDocList t on t.DocDetailsID=D.InvDocDetailsID   	
	order by D.VoucherNo,D.DocSeqNo,D.VoucherType  ,d.DynamicInvDocDetailsID'
	exec (@Query)

	set @Query='' 
	SELECT @Query=@Query+','+CASE WHEN TC.name IS NOT NULL THEN 'T' ELSE 'CC' END +'.'+C.name FROM sys.columns C WITH(NOLOCK)
	LEFT JOIN tempdb.sys.columns TC WITH(NOLOCK) ON TC.OBJECT_ID=OBJECT_ID('tempdb..#tblDocList') AND TC.name collate database_default=C.name collate database_default
	WHERE C.OBJECT_ID=OBJECT_ID('[COM_DocNumData]') and C.name not in ('DocNumDataID')
	order by C.column_id

	--GETTING DOCUMENT EXTRA NUMERIC FEILD DETAILS    
	set @Query='SELECT CC.DocNumDataID'+@Query+' FROM [COM_DocNumData] CC  WITH(NOLOCK) 
	join [INV_DocDetails] D WITH(NOLOCK) on CC.InvDocDetailsID=D.InvDocDetailsID     
	join #tblDocList t WITH(NOLOCK) on t.DocDetailsID=D.InvDocDetailsID    	
	order by D.VoucherNo,D.DocSeqNo,D.VoucherType   ,d.DynamicInvDocDetailsID'
	exec (@Query)
    
	set @Query='' 
	SELECT @Query=@Query+','+CASE WHEN TC.name IS NOT NULL THEN 'T' ELSE 'CC' END +'.'+C.name FROM sys.columns C WITH(NOLOCK)
	LEFT JOIN tempdb.sys.columns TC WITH(NOLOCK) ON TC.OBJECT_ID=OBJECT_ID('tempdb..#tblDocList') AND TC.name collate database_default=C.name collate database_default
	WHERE C.OBJECT_ID=OBJECT_ID('COM_DocTextData') and C.name not in ('DocTextDataID')
	order by C.column_id

	--GETTING DOCUMENT EXTRA TEXT FEILD DETAILS    
	set @Query='SELECT CC.DocTextDataID'+@Query+' FROM [COM_DocTextData] CC  WITH(NOLOCK) 
	join [INV_DocDetails] D WITH(NOLOCK) on CC.InvDocDetailsID=D.InvDocDetailsID     
	join #tblDocList t WITH(NOLOCK) on t.DocDetailsID=D.InvDocDetailsID   	  
	order by D.VoucherNo,D.DocSeqNo,D.VoucherType   ,d.DynamicInvDocDetailsID'
	exec (@Query)
    
   --Getting Linking Fields    
   SELECT case when A.CostCenterColIDBase <0 THEN 'TO'+B.SysColumnName else B.SysColumnName end BASECOL,L.SysColumnName LINKCOL ,A.[VIEW],A.CostCenterColIDLinked,A.CalcValue  
   FROM COM_DocumentLinkDetails A WITH(NOLOCK) 
   JOIN ADM_CostCenterDef B WITH(NOLOCK) ON (B.CostCenterColID=A.CostCenterColIDBase or B.CostCenterColID=A.CostCenterColIDBase*-1)
   left JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON (L.CostCenterColID=A.CostCenterColIDLinked or L.CostCenterColID=A.CostCenterColIDLinked *-1)   
   WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
       
        
	SELECT a.[BatchID],a.[InvDocDetailsID],a.UomConvertedQty Quantity,a.[HoldQuantity] 
	,a.[ReleaseQuantity],a.[VoucherType],a.DynamicInvDocDetailsID
	,[RefInvDocDetailsID], b.[BatchNumber], b.BatchCode,CONVERT(datetime,b.[MfgDate]) MfgDate  
	,CONVERT(datetime,b.[ExpiryDate]) ExpiryDate,b.[MRPRate],b.[RetailRate]  
	,b.[StockistRate],IsQtyIgnored FROM [inv_DocDetails] a WITH(NOLOCK)   
	join INV_Batches b WITH(NOLOCK) on a.BatchID=b.BatchID  
	WHERE a.[BatchID]>1 and a.[InvDocDetailsID] IN (SELECT DocDetailsID FROM  #tblDocList WITH(NOLOCK))  AND a.StatusID=369
        
       
	--GETTING SYSCOLDATA FROM COSTCENTERDEF   
	SELECT C.*,TBL.SysColumnName FROM ADM_COSTCENTERDEF C WITH(NOLOCK)    
	INNER JOIN  (  
    SELECT  case when L.SysColumnName IS null then B.SysColumnName else L.SysColumnName end as SysColumnName,A.[VIEW]   FROM COM_DocumentLinkDetails A WITH(NOLOCK)     
	JOIN ADM_CostCenterDef B WITH(NOLOCK)  ON B.CostCenterColID=A.CostCenterColIDBase    
	left JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON L.CostCenterColID=A.CostCenterColIDLinked    
	WHERE A.DocumentLinkDeFID =@DocumentLinkDefID  ) AS TBL ON C.SysColumnName = TBL.SysColumnName  
	WHERE C.COSTCENTERID = @LinkCostCenterID  AND TBL.[VIEW] = 1 
  
     
   SELECT distinct f.[FileID],f.[FilePath],f.[ActualFileName],f.[RelativeFileName],f.[FileExtension],f.[IsProductImage]  
   ,RowSeqNo,ColName,f.[FileDescription],f.[CostCenterID],f.[GUID],f.AllowInPrint,f.FeaturePK,f.IsDefaultImage
   ,CASE WHEN f.RowSeqNo IS NULL THEN NULL ELSE aa.InvDocDetailsID END as InvDocDetailsID 
   FROM  COM_Files f WITH(NOLOCK)   
	join [INV_DocDetails] a   WITH(NOLOCK) on   f.FeaturePK=a.DocID
   join #tblDocList c WITH(NOLOCK) on a.InvDocDetailsID=c.DocDetailsID
   left join [INV_DocDetails] aa   WITH(NOLOCK) on   aa.DocID=a.DocID AND aa.DocSeqNo=f.RowSeqNo
   WHERE f.FeatureID=a.CostCenterID 
	
	set @PrefValue=''
    select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)       
    where CostCenterID=@CostCenterID and PrefName='CopySerialNos'     
         
	if(@PrefValue is not null and @PrefValue='True')
	BEGIN
	   SELECT A.[InvDocDetailsID]  
		  ,A.[ProductID]  
		  ,a.[SerialNumber]  
		  ,a.[StockCode]  
		  ,A.[Quantity]  
		  ,A.[StatusID]  
		  ,a.[SerialGUID]  
		  ,a.[IsIssue]  
		  ,a.[IsAvailable]  
		  ,a.[RefInvDocDetailsID]  
		  ,a.[Narration] FROM INV_SerialStockProduct A WITH(NOLOCK)  
   		join #tblDocList t WITH(NOLOCK) on t.DocDetailsID=A.InvDocDetailsID 
   		left join inv_docdetails b WITH(NOLOCK) on a.InvDocDetailsID=b.LinkedInvDocDetailsID 
		left  join INV_SerialStockProduct bs WITH(NOLOCK) on bs.InvDocDetailsID=b.InvDocDetailsID and a. [SerialNumber]=bs.SerialNumber
		where bs.SerialProductID is null 
	END
	ELSE
		SELECT 1 where 1=2
		
	select a.*,'' VoucherNo
	from COM_DocQtyAdjustments a WITH(NOLOCK)  
	join #tblDocList t WITH(NOLOCK) on a.InvDocDetailsID=t.DocDetailsID	
	union
	select a.*,I.VoucherNo from COM_DocQtyAdjustments a WITH(NOLOCK)
	JOIN #tblDocList T WITH(NOLOCK) ON T.QDocID=A.DocID
	JOIN INV_DocDetails I WITH(NOLOCK) ON I.DocID=T.QDocID
	WHERE A.InvDocDetailsID=0
	
	IF exists (SELECT PrefValue  FROM COM_DocumentPreferences WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID and PrefName in('CopyAddresses') and PrefValue='true')
		and exists (SELECT PrefValue  FROM COM_DocumentPreferences WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID and PrefName in('PrimaryAddress','ShippingAddress','BillingAddress') and PrefValue='true')	 
	BEGIN 
		   	select @DbAccID=DebitAccount,@CrAccID=CreditAccount,@tempDOcID=DocID
			FROM  [INV_DocDetails] a   WITH(NOLOCK)  
			join #tblDocList c WITH(NOLOCK) on a.InvDocDetailsID=c.DocDetailsID 
			
			SELECT a.addressid,A.[InvDocDetailsID]  
			,[AddressHistoryID],[AddressTypeID] 
			FROM COM_DocAddressData A WITH(NOLOCK)  			
			WHERE DocID=@tempDOcID  
						
			SELECT FEATUREPK,AddressName,Address1,Phone1,AddressID,AddressTypeID,0 
			,ContactPerson,Address2,Address3,State,Zip,City,IsDefault
			FROM COM_Address WITH(NOLOCK) 
			WHERE FEATUREID = 2 AND FEATUREPK in(@CrAccID,@DbAccID)
			UNION
			SELECT FEATUREPK,AddressName,Address1,Phone1,a.AddressID,a.AddressTypeID,a.AddressHistoryID 
			,ContactPerson,Address2,Address3,State,Zip,City,IsDefault
			FROM COM_Address_History a WITH(NOLOCK) 
			join COM_DocAddressData b WITH(NOLOCK) on a.AddressHistoryID=b.AddressHistoryID
			WHERE FEATUREID = 2 AND FEATUREPK in(@CrAccID,@DbAccID)			
			and  b.DocID=@tempDOcID and a.AddressID not in (SELECT AddressID FROM COM_Address WITH(NOLOCK) 
			WHERE FEATUREID = 2 AND FEATUREPK in(@CrAccID,@DbAccID))
			
	END
	ELSE
	BEGIN
		SELECT 1 WHERE 1<>1
		SELECT 1 WHERE 1<>1
	END
	
	set @PrefValue=''
    select @PrefValue=PrefValue from COM_DocumentPreferences  WITH(NOLOCK)      
    where CostCenterID=@CostCenterID and PrefName='CopyBins' 
    
    if(@PrefValue is not null and @PrefValue='True')
	BEGIN
		select a.InvDocDetailsID,a.BinID,a.Quantity
		from   INV_BinDetails a WITH(NOLOCK)  
		join #tblDocList t WITH(NOLOCK) on t.DocDetailsID=A.InvDocDetailsID 
	END
	ELSE
		SELECT 1 WHERE 1<>1
	
	select a.*
	from   INV_DocExtraDetails a WITH(NOLOCK)  
	join #tblDocList t WITH(NOLOCK) on t.DocDetailsID=A.InvDocDetailsID 
	
	
	if exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK)       
    where CostCenterID=@CostCenterID and PrefName='ExpandStages' and PrefValue is not null and PrefValue='True')
	BEGIN
		select @autoCCID=value from ADM_GlobalPreferences  WITH(NOLOCK) 
		where Name='PaytermLinkDim' and ISNUMERIC(value)=1
		
		if(@autoCCID>50000 and exists(select DocDetailsID from #tblDocList WITH(NOLOCK)))
		BEGIN
			set @query=''
			select @query=@query+convert(nvarchar,DocDetailsID)+',' from #tblDocList WITH(NOLOCK)
			
			set @query=SUBSTRING(@query,0,len(@query))
			 
			set @query='select distinct pdid,percentage,Days,Period,TypeID,basedon,Occurences,Remarks,a.dimNodeID,a.dimccid,b.dimNodeID Nodeid from Acc_PaymentDiscountTerms a WITH(NOLOCK)    
			join Acc_PaymentDiscountProfile b WITH(NOLOCK) on a.ProfileID=b.ProfileID
			join COM_DocCCData c WITH(NOLOCK) on c.dcCCNID'+convert(nvarchar,@autoCCID-50000)+'=b.dimNodeID
			where c.InvDocDetailsID in('+@query+')'
			print @query
			exec(@query)
		END
		ELSE
			SELECT 1 WHERE 1<>1
	END
	ELSE
		SELECT 1 WHERE 1<>1
	
	if(@StrWhere<>'')
	BEGIN
		 --Getting Linking Fields    
		   set @PrefValue=''	
		   SELECT @PrefValue=L.SysColumnName FROM COM_DocumentLinkDetails A WITH(NOLOCK) 
		   JOIN ADM_CostCenterDef B WITH(NOLOCK) ON (B.CostCenterColID=A.CostCenterColIDBase or B.CostCenterColID=A.CostCenterColIDBase*-1)
		   left JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON L.CostCenterColID=A.CostCenterColIDLinked    
		   WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
		   and B.SysColumnName='productid' and B.ParentCCDefaultColID=261
		   
		   if(@PrefValue like 'dcAlpha%')
		   BEGIN
			
				set @query='update #tblDocList '
				if(@IgnoreSpec=1 or @IgnoreSpec=2)					
					set @query=@query+' set alpha='',''+dbo.fnStr_IgnoreSpecialchar('+@PrefValue+')+'','''
				else
					set @query=@query+' set alpha='+@PrefValue
				set @query=@query+' from COM_DoctextData DCA WITH(NOLOCK)
				where DocDetailsID =DCA.InvDocDetailsID'
				
				 exec(@query)
				 
			   set @query='select distinct d.DocDetailsID,a.[ProductID],a.ProductName,a.ProductCode
				from #tblDocList d WITH(NOLOCK)				
				left join INV_Product a WITH(NOLOCK) on   a.isgroup=0
				LEFT JOIN COM_CCCCData CC with(nolock) ON CC.COSTCENTERID=3 AND CC.NODEID=a.ProductID 
				LEft JOIN INV_ProductExtended E  WITH(NOLOCK) on  E.ProductID=a.ProductID '+@StrJoin
				
				 if (@listTypeID>0)
					set @query=@query+@Join
					
				set @query=@query+' where '+replace(@StrWhere,'{0}','''+alpha+''') 	
				
				if (@listTypeID>0)
					set @query=@query+@Where
	
			   print @query
			   exec(@query)
		  END
		  ELSE
			SELECT 1 WHERE 1<>1
	   
	END
	ELSE
		SELECT 1 WHERE 1<>1
			
	set @PrefValue=''
	select @PrefValue=PrefValue from COM_DocumentPreferences  WITH(NOLOCK)    
	where CostCenterID=@CostCenterID and PrefName='Autopostdocument'        
        
	if(@PrefValue is not null and @PrefValue<>'')
	begin		
		set @autoCCID=0
		begin try
			select @autoCCID=convert(INT,@PrefValue)
		end try
		begin catch
			set @autoCCID=0
		end catch
		
		if(@autoCCID>40000)
		BEGIN
			select @tempDOcID=DocID  FROM  [INV_DocDetails] a   WITH(NOLOCK)  
			join #tblDocList c WITH(NOLOCK) on a.InvDocDetailsID=c.DocDetailsID
			
			
			SELECT a.Quantity,a.Unit ,a.ProductID,P.ProductName,P.ProductCOde,U.UnitName,a.voucherno 
			from INV_DocDetails a WITH(NOLOCK)
			join INV_DocDetails B WITH(NOLOCK) on a.InvDocDetailsID =b.LinkedInvDocDetailsID			
			join INV_Product P WITH(NOLOCK) on  a.ProductID=P.ProductID
			join COM_UOM U WITH(NOLOCK) on  a.Unit=U.UOMID 
			WHere b.DocID=@tempDOcID and a.StatusID=369
			order by a.DocSeqNo
			
			SELECT @DocumentLinkDefID=DocumentLinkDeFID 
			FROM [COM_DocumentLinkDef]    WITH(NOLOCK) 
			where [CostCenterIDBase]=@autoCCID and [CostCenterIDLinked]=@COstCenterID
	  
		   SELECT B.SysColumnName BASECOL,L.SysColumnName LINKCOL ,A.[VIEW],A.CostCenterColIDLinked  
		   FROM COM_DocumentLinkDetails A WITH(NOLOCK) 
		   JOIN ADM_CostCenterDef B WITH(NOLOCK) ON B.CostCenterColID=A.CostCenterColIDBase    
		   left JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON L.CostCenterColID=A.CostCenterColIDLinked    
		   WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
 
		END
		ELSE
		BEGIN
			SELECT 1 WHERE 1<>1
			SELECT 1 WHERE 1<>1
		END
	END  
	ELSE
	BEGIN
		SELECT 1 WHERE 1<>1
		SELECT 1 WHERE 1<>1
	END
		
	if(@doctype=30 and @LinkdocType=30 and exists (SELECT PrefValue from COM_DocumentPreferences WITH(NOLOCK)      
    where CostCenterID=@LinkCostCenterID and PrefName='UseasAssemble/DisAssembly' and PrefValue='true')
    and exists (SELECT PrefValue from COM_DocumentPreferences WITH(NOLOCK)      
    where CostCenterID=@CostCenterID and PrefName='UseasAssemble/DisAssembly' and PrefValue='true'))
	BEGIN
		
		select pb.ProductID,case when isnull(p.KitSize,0)>1 then pb.Quantity/p.KitSize else pb.Quantity END as Quantity,pb.ParentProductID
		 from   [INV_DocDetails] a WITH(NOLOCK)  
		join INV_ProductBundles pb WITH(NOLOCK) on a.ProductID=pb.parentproductid
		join INV_Product p WITH(NOLOCK) on p.ProductID=pb.parentproductid
		join #tblDocList t WITH(NOLOCK) on t.DocDetailsID=a.InvDocDetailsID
		
	END	
	ELSE
		SELECT 1 WHERE 1<>1	
	
	if exists(select LocalReference from ADM_CostCenterDef WITH(NOLOCK) where CostCenterID=@CostCenterID and LocalReference is not null and LocalReference=79 and LinkData=55478)	
	BEGIN
				declare @tabvchrs table(vchrs nvarchar(200),typ int,ccid int)
				
				insert into @tabvchrs(vchrs,typ,ccid)values(@VoucherNo,1,@CostCenterID)
				
				set @docType=1
				while exists(select vchrs from @tabvchrs where typ=@docType)
				BEGIN
				
					insert into @tabvchrs
					select b.voucherno,@docType+1,b.CostCenterID from INV_DocDetails a WITH(NOLOCK)
					join INV_DocDetails b WITH(NOLOCK) on a.linkedInvDocdetailsid=b.InvDocdetailsid
					join @tabvchrs c on a.VoucherNo=c.vchrs 
					where c.typ=@docType and a.linkedInvDocdetailsid>0
					
					set @docType=@docType+1
					
				END
				
				set @Vouchers=''
				select distinct @Vouchers=@Vouchers+''''+vchrs+''''+',' from @tabvchrs
					
				if(LEN(@Vouchers)>1)
					set @Vouchers=SUBSTRING(@Vouchers,0,len(@Vouchers))

				
				set @Query='select isnull(sum(Amount),0) from COM_BillWiseNonAcc WITH(NOLOCK)
				where RefDocNo in('+@Vouchers+')'
				
				EXEC (@Query)
	END
	ELSE
		SELECT 1 WHERE 1<>1
			
	----LOAN REPAYMENT BALANCE AMOUNT
	--IF(@CostCenterID=40057)
	--BEGIN
	--	SET @Query='SELECT isnull(sum(d.linkedfieldvalue),0) PaidLoanAmount'
	--	SET @Query=@Query+' from  INV_DocDetails d with(nolock) join inv_product p  with(nolock) on d.ProductID=p.ProductID  join COM_DocCCData DC with(nolock) on d.linkedInvDocDetailsID =DC.InvDocDetailsID '   
	--	SET @Query=@Query+' left join INV_DocDetails B WITH(NOLOCK) on d.linkedInvDocDetailsID =b.InvDocDetailsID and b.Statusid<>376  and b.DocID<>'+convert(nvarchar,@DocID)     
	--	SET @Query=@Query+' where b.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID) +' and b.VoucherNo in ('''+@VoucherNo+''') ' 
	--	IF(@DimWhere is NOT null and @DimWhere<>'') --FOr Dimension filter      
	--	BEGIN      		
	--		SET @Query=@Query+@DimWhere
	--	END
	--	print (@Query)
	--	exec(@Query)
	--END	
	
 SET NOCOUNT OFF;    
RETURN 1    
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
	SET NOCOUNT OFF      
	RETURN -999       
END CATCH

GO
