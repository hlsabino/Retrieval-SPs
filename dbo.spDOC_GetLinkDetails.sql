USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetLinkDetails]
	@DocumentLinkDefID [int],
	@LocationID [int] = 0,
	@DivisionID [int] = 0,
	@DocDate [datetime] = null,
	@DueDate [datetime] = null,
	@DocID [int] = 0,
	@DbAcc [int] = 0,
	@CrAcc [int] = 0,
	@DimWhere [nvarchar](max) = '',
	@LinkDocsDateFilter [datetime] = null,
	@UserID [int] = 0,
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY       
SET NOCOUNT ON      
      
	--Declaration Section      
	DECLARE @Tolerance nvarchar(50),@CostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50),@ProductColName  nvarchar(50),@LinkdocType int         
	DECLARE @Query nvarchar(max),@Vouchers nvarchar(max),@LinkCostCenterID int,@ColID INT,@lINKColID INT,@PrefValue nvarchar(50),@docType int,@UserWise bit

	--SP Required Parameters Check      
	IF (@DocumentLinkDefID <1)      
	BEGIN      
		RAISERROR('-100',16,1)      
	END      
          
        
	SELECT @CostCenterID=a.[CostCenterIDBase]      
	,@ColID=a.[CostCenterColIDBase]      
	,@LinkCostCenterID=a.[CostCenterIDLinked]      
	,@lINKColID=a.[CostCenterColIDLinked]   
	,@Vouchers = a.[LinkedVouchers]   
	,@docType=b.DocumentType 
	,@LinkdocType=c.DocumentType
	FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
	join ADM_DocumentTypes b  WITH(NOLOCK) on a.CostCenterIDBase=b.CostCenterID
	left join ADM_DocumentTypes c  WITH(NOLOCK) on a.CostCenterIDLinked=c.CostCenterID
	where [DocumentLinkDefID]=@DocumentLinkDefID      
      
	if(@LinkCostCenterID=158)
	BEGIN
		select @ColID=Value from COM_CostCenterPreferences WITH(NOLOCK) 
		where CostCenterID=76 and Name='JobDimension' and ISNUMERIC(Value)=1

		select @ColumnName=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@ColID

		select @lINKColID=StatusID from COM_Status WITH(NOLOCK) where CostCenterID=@ColID
		and Status='Active'

		set @Query='select a.NODEID DocID,Name voucherno,0 CreditAccount,0 DebitAccount,b.* 
		from '+@ColumnName+' a WITH(NOLOCK) 
		join com_ccccdata b WITH(NOLOCK) on a.NODEID=b.NODEID and b.CostcenterID='+CONVERT(nvarchar,@ColID)

		set @PrefValue=''
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)                          
		where CostCenterID=@CostCenterID and PrefName='jobswithissues'        
		      
		if(@PrefValue is not null and @PrefValue='True')
		BEGIN
			SET @Query=@Query+' join  (select distinct dcCCNID'+CONVERT(nvarchar,(@ColID-50000))+' ID 
			from INV_DocDetails i WITH(NOLOCK) 
			join COM_DocCCData d WITH(NOLOCK) on d.InvDocDetailsID=i.InvDocDetailsID
			where i.VoucherType=-1 and IsQtyIgnored=0) as t on a.NodeID=t.ID '
		END
		
	    SET @Query=@Query+' where isgroup=0 and a.StatusID='+ CONVERT(nvarchar,@lINKColID)
	    
		IF(@LocationID > 0) 
		BEGIN     
			select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)                          
			where CostCenterID=@CostCenterID and PrefName='OverrideLocationwise'        

			if(@PrefValue is null or @PrefValue<>'True')
				SET @Query=@Query+' and b.CCNID2='+convert(nvarchar(5),@LocationID)      
		END 
		IF(@DivisionID > 0)      
		BEGIN      
			select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)                    
			where CostCenterID=@CostCenterID and PrefName='OverrideDivisionwise'        

			if(@PrefValue is null or @PrefValue<>'True')
				SET @Query=@Query+' and b.CCNID1='+convert(nvarchar(5),@DivisionID)      
		END  
		  
	  	if exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
		where CostCenterID=@CostCenterID and PrefName='Debit Account' and PrefValue='true')
			SET @Query=@Query+' and a.PurchaseAccount = '+convert(nvarchar,@DbAcc)
		
		if exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
		where CostCenterID=@CostCenterID and PrefName='Credit Account' and PrefValue='true')
			SET @Query=@Query+' and a.SalesAccount = '+convert(nvarchar,@CrAcc)
print @Query
	    Exec(@Query)
	    return
	END
	ELSE if(@LinkCostCenterID=76)
	BEGIN	
		set @Query='select a.BomID DocID,BomName voucherno,0 CreditAccount,0 DebitAccount from PRD_BillOfMaterial a WITH(NOLOCK) 
		join com_ccccdata b WITH(NOLOCK) on a.BomID=b.NODEID and b.CostcenterID=76 and a.StatusID != 52'

		IF(@LocationID > 0) 
		BEGIN     
			select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)                          
			where CostCenterID=@CostCenterID and PrefName='OverrideLocationwise'        

			if(@PrefValue is null or @PrefValue<>'True')
				SET @Query=@Query+' and b.CCNID2='+convert(nvarchar(5),@LocationID)      
		END 
		IF(@DivisionID > 0)      
		BEGIN      
			select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)                    
			where CostCenterID=@CostCenterID and PrefName='OverrideDivisionwise'        

			if(@PrefValue is null or @PrefValue<>'True')
				SET @Query=@Query+' and b.CCNID1='+convert(nvarchar(5),@DivisionID)      
		END   
		Exec(@Query)
		return
	END
	
	SELECT @ColumnName=SysColumnName from ADM_CostCenterDef WITH(NOLOCK)  
	where CostCenterColID=@lINKColID
  
	set @Tolerance=''
    select @Tolerance=PrefValue from COM_DocumentPreferences WITH(NOLOCK)        
    where CostCenterID=@CostCenterID and PrefName='Enabletolerance'          

	--Create temporary table       
	CREATE TABLE #tblList(ID int identity(1,1) PRIMARY KEY,DocDetailsID INT,Val float,LinkStatusID INT,VoucherType int,DocSeqNo int,Voucherno nvarchar(200))
	     
	set @Query=''

	set @Query=@Query+'select InvDocDetailsID,value,linkstatusid,VoucherType,DocSeqNo,Voucherno from ('
	  
	set @Query=@Query+'SELECT a.InvDocDetailsID,cast(a.'+@ColumnName+'-isnull(sum('
	
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
    
	set @Query=@Query+' else b.LinkedFieldValue end ),0)as numeric(36,5)) value,'      

	if(@Tolerance is not null and @Tolerance='True')
		set @Query=@Query+'max(isnull(p.MinTolerancePer,0)) TPercentage,max(isnull(p.MinToleranceVal,0)) TValue
				,(a.'+@ColumnName+'*max(isnull(p.MinTolerancePer,0)))/100 per,max(isnull(p.MaxTolerancePer,0)) thp,max(isnull(p.MaxToleranceVal,0)) THV, '

	IF(@ColumnName LIKE 'dcNum%' )      
		SET @Query=@Query+'d.linkstatusid,d.VoucherType,d.DocSeqNo,d.Voucherno 
		from COM_DocNumData a with(nolock) ' +      
		'join INV_DocDetails d with(nolock) on a.InvDocDetailsID =d.InvDocDetailsID  
		join inv_product p  with(nolock) on d.ProductID=p.ProductID     
		join COM_DocCCData DC with(nolock) on d.InvDocDetailsID =DC.InvDocDetailsID'      
	ELSE      
		SET @Query=@Query+'a.linkstatusid,a.VoucherType,a.DocSeqNo,a.Voucherno 
		from INV_DocDetails a with(nolock) 
		join inv_product p  with(nolock) on a.ProductID=p.ProductID
		join COM_DocCCData DC with(nolock) on a.InvDocDetailsID =DC.InvDocDetailsID'      
        
    SET @Query=@Query+' left join INV_DocDetails B with(nolock) on a.InvDocDetailsID =b.LinkedInvDocDetailsID '          
        
    
   
	set @PrefValue=''
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)
	where CostCenterID=@CostCenterID and PrefName='LinkVendorProducts'        	      
	if(@PrefValue is not null and @PrefValue='True')
	BEGIN
		if(@docType in(1,27,26,25,2,34,6,3,4,13))
			SET @Query=@Query+' join INV_ProductVendors PV WITH(NOLOCK) ON p.ProductID=pv.ProductID and pv.AccountID='+convert(nvarchar,@CrAcc)      
		ELSE
			SET @Query=@Query+' join INV_ProductVendors PV WITH(NOLOCK) ON p.ProductID=pv.ProductID and pv.AccountID='+convert(nvarchar,@DbAcc)
	END  
        
	IF(@ColumnName LIKE 'dcNum%' )      
		SET @Query=@Query+' where d.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID)      
	ELSE      
		SET @Query=@Query+' where a.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID)      

	IF(@ColumnName LIKE 'dcNum%' )      
		SET @Query=@Query+' and d.ProductID<>0 '      
	ELSE      
		SET @Query=@Query+' and a.ProductID<>0 '
		
     
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
  
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)      
	where CostCenterID=@CostCenterID and PrefName='onlyTempProduct'        
	if(@PrefValue is not null and @PrefValue='True')--      
	begin  		
		select @PrefValue=Value from COM_CostCenterPreferences WITH(NOLOCK)      
		where CostCenterID=3 and Name='TempPartProduct'  
		if(@PrefValue is not null and @PrefValue<>'')--      
		begin  		
			IF(@ColumnName LIKE 'dcNum%' )    
				SET @Query=@Query+' and d.ProductID='+@PrefValue      
			Else    
				SET @Query=@Query+' and a.ProductID='+@PrefValue    
		end  
	end  
        
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)      
	where CostCenterID=@LinkCostCenterID and PrefName='Allowlinkingonce'        
	if(@PrefValue is not null and @PrefValue='True')--FOr Linking only once      
	begin      
		SET @Query=@Query+' and (b.InvDocDetailsID is null or b.DocID='+convert(nvarchar,@DocID)+')'
	end  

	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)      
	where CostCenterID=@CostCenterID and PrefName='linkSingleline'        	    
	if(@PrefValue is not null and @PrefValue='True')--FOr link Single line      
	begin
		IF(@ColumnName LIKE 'dcNum%' )    
			SET @Query=@Query+' and d.DocSeqNo=1'      
		Else
			SET @Query=@Query+' and a.DocSeqNo=1'      
	end    
  
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)      
	where CostCenterID=@CostCenterID and PrefName='OnlyLinked'               
	if(@PrefValue is not null and @PrefValue='True')--FOr link Single line      
	begin
		IF(@ColumnName LIKE 'dcNum%' )    
			SET @Query=@Query+' and d.LinkedInvDocDetailsID is not null and d.LinkedInvDocDetailsID>0 '      
		Else
			SET @Query=@Query+' and a.LinkedInvDocDetailsID is not null and a.LinkedInvDocDetailsID>0 '      
	end 
      
	IF(@LocationID > 0) 
	BEGIN     
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)                          
		where CostCenterID=@CostCenterID and PrefName='OverrideLocationwise'        
		if(@PrefValue is null or @PrefValue<>'True')
			SET @Query=@Query+' and DC.dcCCNID2='+convert(nvarchar(5),@LocationID)      
	END 
	
	IF(@DivisionID > 0)      
	BEGIN      
		select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)                    --Need to check      
		where CostCenterID=@CostCenterID and PrefName='OverrideDivisionwise'        

		if(@PrefValue is null or @PrefValue<>'True')--FOr Override Division wise      
			SET @Query=@Query+' and DC.dcCCNID1='+convert(nvarchar(5),@DivisionID)      
	END      
        
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    --Need to check      
	where CostCenterID=@CostCenterID and PrefName='MonthWise'         
	if(@PrefValue is NOT null AND  @PrefValue='True' and @DocDate is not null and @DocDate <> '')--FOr DocDate filter      
	BEGIN    
		IF(@ColumnName LIKE 'dcNum%' ) 
			SET @Query=@Query+' and month(convert(datetime, d.DocDate)) = '''+convert(nvarchar(20),month(@DocDate))+''''       
		ELSE		   
			SET @Query=@Query+' and month(convert(datetime, a.DocDate)) = '''+convert(nvarchar(20),month(@DocDate))+''''       
	END      
         
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    --Need to check      
	where CostCenterID=@CostCenterID and PrefName='Ondocumentdate'          
	if(@PrefValue is NOT null AND  @PrefValue='True' and @DocDate is not null and @DocDate <> '')--FOr DocDate filter      
	BEGIN  
		IF(@ColumnName LIKE 'dcNum%' ) 
			SET @Query=@Query+' and convert(datetime, d.DocDate) = '''+convert(nvarchar(20),@DocDate)+''''       
		ELSE  
			SET @Query=@Query+' and convert(datetime, a.DocDate) = '''+convert(nvarchar(20),@DocDate)+''''       
	END      
           
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    --Need to check      
	where CostCenterID=@CostCenterID and PrefName='Duedatewise'        
	if(@PrefValue is NOT null AND  @PrefValue='True' and @DocDate is not null and @DocDate <> '') --FOr DueDate filter      
	BEGIN   
		IF(@ColumnName LIKE 'dcNum%' ) 
			SET @Query=@Query+' and convert(datetime, d.DueDate) >= '''+convert(nvarchar(20),@DocDate)+''''      
		ELSE   
			SET @Query=@Query+' and convert(datetime, a.DueDate) >= '''+convert(nvarchar(20),@DocDate)+''''      
	END 
	
	set @PrefValue=''
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
	where CostCenterID=@CostCenterID and PrefName='Debit Account'        
	if(@PrefValue is NOT null AND  @PrefValue='True') --FOr Debit Account filter      
	BEGIN      
		if((@docType in(6,10,40,42) and @LinkdocType not in(6,10,40,42)) or (@LinkdocType in(6,10,40,42) and @docType not in(6,10,40,42)))
		BEGIN
			IF(@ColumnName LIKE 'dcNum%' )       
				SET @Query=@Query+' and d.CreditAccount = '+convert(nvarchar,@DbAcc)
			else
				SET @Query=@Query+' and a.CreditAccount = '+convert(nvarchar,@DbAcc)
		END
		ELSE
		BEGIN
			IF(@ColumnName LIKE 'dcNum%' )       
				SET @Query=@Query+' and d.DebitAccount = '+convert(nvarchar,@DbAcc)
			else
				SET @Query=@Query+' and a.DebitAccount = '+convert(nvarchar,@DbAcc)
		END	
	END 
	 
	set @PrefValue=''
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
	where CostCenterID=@CostCenterID and PrefName='Credit Account'        
	if(@PrefValue is NOT null AND  @PrefValue='True') --FOr Debit Account filter      
	BEGIN  
		if((@docType in(6,10,40,42) and @LinkdocType not in(6,10,40,42)) or (@LinkdocType in(6,10,40,42) and @docType not in(6,10,40,42)))
		BEGIN
			IF(@ColumnName LIKE 'dcNum%' )       
				SET @Query=@Query+' and d.DebitAccount = '+convert(nvarchar,@CrAcc)
			else
				SET @Query=@Query+' and a.DebitAccount = '+convert(nvarchar,@CrAcc)
		END
		ELSE
		BEGIN    
			IF(@ColumnName LIKE 'dcNum%' )       
				SET @Query=@Query+' and d.CreditAccount = '+convert(nvarchar,@CrAcc)
			else
				SET @Query=@Query+' and a.CreditAccount = '+convert(nvarchar,@CrAcc)
		END	
	END

	if(@DimWhere is NOT null and @DimWhere<>'') --FOr Dimension filter      
	BEGIN      		
		SET @Query=@Query+@DimWhere
	END 

	set @PrefValue=''
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
	where CostCenterID=@LinkCostCenterID and PrefName='Expiredafter'        
	if(@PrefValue is NOT null and @PrefValue<>'' and convert(int,@PrefValue)>0) --FOr DueDate filter      
	BEGIN      
		IF(@ColumnName LIKE 'dcNum%' )       
			SET @Query=@Query+' and convert(datetime, d.DocDate) >= '''+convert(nvarchar(20),(@DocDate-convert(int,@PrefValue)))+''''      
		else
			SET @Query=@Query+' and convert(datetime, a.DocDate) >= '''+convert(nvarchar(20),(@DocDate-convert(int,@PrefValue)))+''''      	 
	END  
  
	SET @UserWise=dbo.fnCOM_HasAccess(@RoleID,43,137)		
	if(@UserWise=1)	
	BEGIN
		IF(@ColumnName LIKE 'dcNum%' )  
			set @Query=@Query+'  and d.CreatedBy in '
		ELSE
			set @Query=@Query+'  and a.CreatedBy in '
			
			set @Query=@Query+' (select username from ADM_Users   WITH(NOLOCK) 
			where UserID='+convert(nvarchar,@UserID)+' or  UserID in (select NodeID from COM_CostCenterCostCenterMap  WITH(NOLOCK)  
			where parentcostcenterid=7 and parentnodeid='+convert(nvarchar,@UserID)+' and costcenterid=7)) '          
	END		 
  
	IF(@ColumnName LIKE 'dcNum%' )       
		SET @Query=@Query+' group by a.InvDocDetailsID,d.Voucherno,d.VoucherType,d.DocSeqNo,d.linkstatusid,a.'+@ColumnName      
	ELSE       
		SET @Query=@Query+' group by a.InvDocDetailsID,a.Voucherno ,a.VoucherType,a.DocSeqNo,a.linkstatusid,a.'+@ColumnName      

	set @PrefValue=''      
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)      
	where CostCenterID=@CostCenterID and PrefName='LinkZeroQty'    
	
	if(@PrefValue='true')--FOr Link Zero Qty no validation        
		SET @Query=@Query+') as t'
	ELSE
	begin     
		if(@Tolerance is not null and @Tolerance='True'    )   
			SET @Query=@Query+') as t
			where ( (TPercentage =0 and thp=0 and THV=0 and TValue=0 and value<>0)
			or (THV >0 and TValue=0 and TPercentage=0 and value>0)
			or (thp >0 and TValue=0 and TPercentage=0 and value>0)
			or (TPercentage >0 and value<>0 and round((value),2)>per )
			or (TValue >0 and value<>0 and round((value),2)>TValue))'
		else
			SET @Query=@Query+' ) as t where cast(value as numeric(36,5)) >0 '    
	end	
	
	--Read XML data into temporary table only to delete records      
	print @Query      
	INSERT INTO #tblList      
	Exec(@Query)      
       
   	if(@LinkdocType=5)
	BEGIN
		delete from #tblList
		where DocDetailsID in(
		select min(DocDetailsID)  from #tblList WITH(NOLOCK)
		group by  Voucherno,DocSeqNo
		having COUNT(*)=1)
	END    

	delete from #tblList where ID in (
	select c.id from inv_docdetails a with(nolock)
	inner join #tblList c WITH(NOLOCK) on a.InvDocDetailsID=c.DocDetailsID   
	left join inv_docdetails b with(nolock) on b.LinkedInvDocDetailsID=a.InvDocDetailsID
	where isnull(b.docid,-123)<>@docid and a.linkstatusid=445 )
   --select * from #tblList
     
  --GETTING DOCUMENT DETAILS      
  --SELECT   DISTINCT  a.voucherno  , Convert(datetime, a.DocDate) DocDate    
  --,a.[DocID], a.DebitAccount, a.CreditAccount,a.DocAbbr,a.DocPrefix, CONVERT(INT,a.DocNumber) DocNumber,A.MODIFIEDDATE ,cc.*       
  --from [INV_DocDetails] a WITH(NOLOCK)      
  --join #tblList c on a.InvDocDetailsID=c.DocDetailsID      
  --join COM_DocCCData CC  WITH(NOLOCK) on a.InvDocDetailsID=CC.InvDocDetailsID      
  --where a.statusid=369      
  --order by     A.MODIFIEDDATE DESC ,  a.[DocID] DESC   
	select @ProductColName=SysColumnName from ADM_COSTCENTERDEF WITH(NOLOCK) 
	where COSTCENTERID=@LinkCostCenterID and SysColumnName like 'dcalpha%' and ColumnCostCenterID=3
   
	SET @Query=' SELECT   DISTINCT  a.voucherno  , Convert(datetime, a.DocDate) DocDate,convert(INT,DOcNUmber) docnumber    
	,a.[DocID],a.DocAbbr,a.DocPrefix,CASE WHEN A.MODIFIEDDATE IS NULL THEN A.CREATEDDATE else A.MODIFIEDDATE END MODDATE'
	
	if exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK)
	where CostCenterID=@CostCenterID and PrefName ='Linkallprodspacked' and PrefValue ='true')
		SET @Query=@Query+',a.COstcenterid into #tempTble '

	SET @Query=@Query+' from [INV_DocDetails] a WITH(NOLOCK)      
	join #tblList c WITH(NOLOCK) on a.InvDocDetailsID=c.DocDetailsID      
	join COM_DocCCData CC  WITH(NOLOCK) on a.InvDocDetailsID=CC.InvDocDetailsID
	join [COM_DocTextData] dT  WITH(NOLOCK) on a.InvDocDetailsID=dT.InvDocDetailsID '
	
	if((@LinkCostCenterID>40000 and @LinkCostCenterID<50000) and @LinkDocsDateFilter is not null and @LinkDocsDateFilter <> '' and @LinkDocsDateFilter <>'1900-01-02 00:00:00.000')
		SET @Query=@Query+' and convert(datetime, a.DocDate) <= '''+convert(nvarchar(20),@LinkDocsDateFilter)+''''  
	 
	set @PrefValue=''
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
	where CostCenterID=@LinkCostCenterID and PrefName='LinkUnposted'        
    if(@PrefValue ='true')
		SET @Query=@Query+' where a.statusid in(369,372) '
	else	
		SET @Query=@Query+' where a.statusid=369 '
		
	set @PrefValue=''      
	select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)
	where CostCenterID=@CostCenterID and PrefName='SortDesc'        
	if(@PrefValue ='true')
		SET @Query=@Query+' order by     MODDATE DESC,convert(INT,DOcNUmber) DESC, a.[DocID] DESC  '
	else
		SET @Query=@Query+' order by a.DocAbbr DESC ,a.DocPrefix DESC,convert(INT,DOcNUmber) DESC'
	
	if exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK)
	where CostCenterID=@CostCenterID and PrefName ='Linkallprodspacked' and PrefValue ='true')
	BEGIN
		SET @Query=@Query+' select * from #tempTble WITH(NOLOCK) where [dbo].[fnDoc_IsFullyPacked](CostCenterid,DocID)=1 '
		if(@PrefValue ='true')
			SET @Query=@Query+' order by MODDATE DESC,convert(INT,DOcNUmber) DESC, [DocID] DESC  '
		else
			SET @Query=@Query+' order by DocAbbr DESC ,DocPrefix DESC,convert(INT,DOcNUmber) DESC '
		
		SET @Query=@Query+' DROP TABLE #tempTble'
	END
	
	print(@Query)
	exec(@Query)
	DROP TABLE #tblList    
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
