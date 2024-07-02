USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetKitProductDetails]
	@CCID [int],
	@LinkedCCID [int],
	@DynamicInvDocDetailsID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
	SET NOCOUNT ON    

	--Declaration Section    
	DECLARE @Tolerance nvarchar(50),@HasAccess bit,@CostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50),
	@ColHeader nvarchar(200) ,@DocumentLinkDefID INT    
	DECLARE @Query nvarchar(max),@LinkCostCenterID int,@ColID INT,@lINKColID INT,@PrefValue nvarchar(50),@ProductColName  nvarchar(50)       
   
	--SP Required Parameters Check    
	IF (@DocumentLinkDefID <1)    
	BEGIN    
		RAISERROR('-100',16,1)    
	END 
    
	SELECT @DocumentLinkDefID=[DocumentLinkDefID] FROM [COM_DocumentLinkDef] with(nolock) 
	where CostCenterIDBase=@CCID  and CostCenterIDLinked=@LinkedCCID
	  
	--Create temporary table     
	declare @tblList TABLE(ID int identity(1,1),DocDetailsID INT,Val float,PercentValue FLOAT)      

	SELECT @CostCenterID=[CostCenterIDBase]    
	  ,@ColID=[CostCenterColIDBase]    
	  ,@LinkCostCenterID=[CostCenterIDLinked]    
	  ,@lINKColID=[CostCenterColIDLinked]    
	FROM [COM_DocumentLinkDef] with(nolock)  
	where [DocumentLinkDefID]=@DocumentLinkDefID    
	   
	      
	SELECT @ColumnName=SysColumnName from ADM_CostCenterDef   with(nolock)  
	where CostCenterColID=@ColID    

	SELECT @lINKColumnName=SysColumnName from ADM_CostCenterDef   with(nolock)  
	where CostCenterColID=@lINKColID    

	--Create temporary table     
	   
	    
	select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)    
	where CostCenterID=@LinkCostCenterID and PrefName='AllowMultipleLinking'      
	   
	set @Tolerance=''
	select @Tolerance=PrefValue from COM_DocumentPreferences WITH(NOLOCK)        
	where CostCenterID=@CCID and PrefName='Enabletolerance'          

	set @Query=''

	if(@Tolerance is not null and @Tolerance='True'    )
		set @Query=@Query+'select InvDocDetailsID,value,per from ('

	set @Query=@Query+'SELECT a.InvDocDetailsID, a.'+@ColumnName+'-isnull(sum(b.LinkedFieldValue),0) value  '    

	if(@Tolerance is not null and @Tolerance='True'    )
		set @Query=@Query+',max(isnull(p.MaxTolerancePer,0)) TPercentage,max(isnull(p.MaxToleranceVal,0)) TValue
				,(a.'+@ColumnName+'*max(isnull(p.MaxTolerancePer,0)))/100 per '
	else
		set @Query=@Query+',0 '
		
	IF(@ColumnName LIKE 'dcNum' )    
		SET @Query=@Query+' from COM_DocNumData a with(nolock) ' +    
		'join INV_DocDetails d with(nolock) on a.InvDocDetailsID =d.InvDocDetailsID     
		join COM_DocCCData DC with(nolock) on d.InvDocDetailsID =DC.InvDocDetailsID
		join inv_product p  with(nolock) on d.ProductID=p.ProductID '    

	ELSE    
		SET @Query=@Query+' from INV_DocDetails a with(nolock)  join COM_DocCCData DC with(nolock) on a.InvDocDetailsID =DC.InvDocDetailsID
		join inv_product p  with(nolock) on a.ProductID=p.ProductID '    
	   
	SET @Query=@Query+' left join INV_DocDetails B with(nolock) on a.InvDocDetailsID =b.LinkedInvDocDetailsID  '    

	 select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)      
	 where CostCenterID=@LinkCostCenterID and PrefName='AllowMultipleLinking'        
	       
	 if(@PrefValue is not null and @PrefValue='True'    ) --FOr Linking Multiple      
	 BEGIN      
		SET @Query=@Query+' and b.CostCenterid='+convert(nvarchar(5),@CostCenterID)        
	 END      
	     
	   
	IF(@ColumnName LIKE 'dcNum' )    
		SET @Query=@Query+' where d.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID)    
	ELSE    
		SET @Query=@Query+' where a.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID)    
	   
	   
	   
	select @PrefValue=PrefValue from COM_DocumentPreferences  with(nolock)   
	where CostCenterID=@LinkCostCenterID and PrefName='Allowlinkingonce'      
	   
	if(@PrefValue is not null and @PrefValue='True')--FOr Linking only once    
	begin    
		SET @Query=@Query+' and a.InvDocDetailsID not in ( select LinkedInvDocDetailsID from INV_DocDetails with(nolock) 
		where LinkedInvDocDetailsID is not null)' 
	end    
	
	SET @Query=@Query+' group by a.InvDocDetailsID,a.'+ @ColumnName    
	   
	set @PrefValue=''        
	select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)        
	where CostCenterID=@CostCenterID and PrefName='LinkZeroQty'          


	if(@PrefValue<>'true')--FOr Link Zero Qty no validation        
	begin    
	 if(@Tolerance is not null and @Tolerance='True'    )   
		  SET @Query=@Query+') as t
		where ( (TPercentage =0 and TValue=0 and value<>0)
		or (TPercentage >0 and value<>0 and round((value),2)>per )
		or (TValue >0 and value<>0 and round((value),2)>TValue))'
	else
		SET @Query=@Query+' having a.'+@ColumnName+'-isnull(sum(b.LinkedFieldValue),0) >0 '    
	end 
	else if(@Tolerance is not null and @Tolerance='True')
		SET @Query=@Query+') as t'

	print @Query

	--Read XML data into temporary table only to delete records    
	INSERT INTO @tblList    
	Exec(@Query)    
    
	
	set @ColHeader= (select top 1 r.ResourceData from ADM_CostCenterDef c with(nolock)      
	join COM_LanguageResources r with(nolock) on r.ResourceID=c.ResourceID and r.LanguageID=@LangID      
	where CostCenterColID=@lINKColID)      
	  
	declare @tempVoucher table ( voucherno nvarchar(50))    
	  
	insert into @tempVoucher    
	SELECT distinct a.voucherno    
		  from [INV_DocDetails] a with(nolock)    
	join @tblList c on a.InvDocDetailsID=c.DocDetailsID    
	where a.statusid=369    
	   
	select @ProductColName=SysColumnName from ADM_COSTCENTERDEF WITH(NOLOCK) 
	where COSTCENTERID=@LinkCostCenterID and SysColumnName like 'dcalpha%' and ColumnCostCenterID=3

	  
	SELECT c.Val ,@lINKColumnName,@ColHeader,@lINKColumnName,@ProductColName ProductColName,A.InvDocDetailsID AS DocDetailsID,A.[AccDocDetailsID],a.VoucherNO      
		 ,a.[DocID]      
		 ,a.[CostCenterID]        
		 ,a.[DocumentType]      
		 ,a.[VersionNo]      
		 ,a.[DocAbbr]      
		 ,a.[DocPrefix]      
		 ,a.[DocNumber]      
		 ,CONVERT(DATETIME,a.[DocDate]) AS DocDate      
		 ,CONVERT(DATETIME,a.[DueDate]) AS DueDate      
		 ,a.[StatusID]      
		 ,a.[BillNo],CONVERT(DATETIME,a.BillDate) AS BillDate        
		 ,a.[LinkedInvDocDetailsID]      
		 ,a.[CommonNarration]      
		 ,a.lineNarration      
		 ,a.[DebitAccount]      
		 ,a.[CreditAccount]      
		 ,a.[DocSeqNo]      
		 ,a.[ProductID],p.QtyAdjustType,p.ProductTypeID,p.ProductName,p.ProductCode      
		 ,isnull(p.MaxTolerancePer,0) ToleranceLimitsPercentage,isnull(p.MaxToleranceVal,0)  ToleranceLimitsValue   
		 ,PercentValue
		 ,a.[Quantity]      
		 ,a.Unit      
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
		 ,a.[CreatedBy]      
		 ,a.[CreatedDate],UOMConversion,UOMConvertedQty, Cr.AccountName as CreditAcc, Dr.AccountName as DebitAcc,a.DynamicInvDocDetailsID,a.ReserveQuantity  FROM		[INV_DocDetails] a with(nolock)      
	join dbo.INV_Product p with(nolock) on  a.ProductID=p.ProductID  
	join dbo.Acc_Accounts Cr  WITH(NOLOCK) on  Cr.AccountID=a.CreditAccount    
	join dbo.Acc_Accounts Dr WITH(NOLOCK)  on  Dr.AccountID=a.DebitAccount      
	join @tblList c on a.InvDocDetailsID=c.DocDetailsID      
	WHERE a.InvDocDetailsID IN (SELECT a.InvDocDetailsID FROM  [INV_DocDetails] a with(nolock)      
	WHERE a.DynamicInvDocDetailsID=@DynamicInvDocDetailsID)
	order by InvDocDetailsID     

	--GETTING DOCUMENT EXTRA COSTCENTER FEILD DETAILS      
	SELECT * FROM  [COM_DocCCData] with(nolock)         
	WHERE InvDocDetailsID IN (SELECT a.InvDocDetailsID FROM  [INV_DocDetails] a with(nolock)      
	WHERE a.DynamicInvDocDetailsID=@DynamicInvDocDetailsID)      
	order by InvDocDetailsID      
	     
	--GETTING DOCUMENT EXTRA NUMERIC FEILD DETAILS      
	SELECT * FROM [COM_DocNumData] with(nolock)      
	WHERE InvDocDetailsID IN (SELECT a.InvDocDetailsID FROM  [INV_DocDetails] a with(nolock)      
	WHERE a.DynamicInvDocDetailsID=@DynamicInvDocDetailsID)
	order by InvDocDetailsID      
	  
	--GETTING DOCUMENT EXTRA TEXT FEILD DETAILS      
	SELECT * FROM [COM_DocTextData] with(nolock)      
	WHERE InvDocDetailsID IN (SELECT a.InvDocDetailsID FROM  [INV_DocDetails] a with(nolock)      
	WHERE a.DynamicInvDocDetailsID=@DynamicInvDocDetailsID)    
	order by InvDocDetailsID     

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
