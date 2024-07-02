USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductLinkDetails]
	@CCID [int],
	@ProductID [int],
	@LocationID [int] = 0,
	@DivisionID [int] = 0,
	@DocDate [datetime] = null,
	@DueDate [datetime] = null,
	@DimensionWhere [nvarchar](max),
	@DbAcc [int] = 0,
	@CrAcc [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    
    
  --Declaration Section    
  DECLARE @Tolerance nvarchar(50),@HasAccess bit,@CostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50),@ColHeader nvarchar(200) ,@DocumentLinkDefID INT,@docType int
  DECLARE @Query nvarchar(max),@LinkCostCenterID int,@ColID INT,@lINKColID INT,@PrefValue nvarchar(50),@ProductColName  nvarchar(50),@Vouchers nvarchar(max),@LinkdocType int
  --DECLARE @DocDate Datetime     
  --SP Required Parameters Check    
  IF (@DocumentLinkDefID <1)    
  BEGIN    
   RAISERROR('-100',16,1)    
  END    
  --Create temporary table     
  declare  @tblDocLinkDef TABLE(ID INT IDENTITY (1,1), DocumentLinkDefID INT ,CCID INT)      
     
  INSERT INTO @tblDocLinkDef      
  SELECT  [DocumentLinkDefID],[CostCenterIDLinked] FROM [COM_DocumentLinkDef] with(nolock) where  CostCenterIDBase =  @CCID    
    --Create temporary table     
  declare @tblList TABLE(ID int identity(1,1),DocDetailsID INT,Val float,PercentValue FLOAT)      
      
   DECLARE @iCnt int ,@iTotCnt int     
   Set  @iCnt = 1    
        
  SELECT @iTotCnt = count(ID) FROM  @tblDocLinkDef    
      
  WHILE ( @iCnt <= @iTotCnt)    
  BEGIN     
       
   SELECT @DocumentLinkDefID = DocumentLinkDefID  FROM  @tblDocLinkDef  WHERE ID = @iCnt    
   SELECT @CostCenterID=[CostCenterIDBase]    
      ,@ColID=[CostCenterColIDBase]    
      ,@LinkCostCenterID=[CostCenterIDLinked]    
      ,@lINKColID=[CostCenterColIDLinked] 
       ,@Vouchers = [LinkedVouchers]      
       ,@docType=b.DocumentType ,@LinkdocType=c.DocumentType
     FROM [COM_DocumentLinkDef] a with(nolock)  
         join ADM_DocumentTypes b  WITH(NOLOCK) on a.CostCenterIDBase=b.CostCenterID
    left join ADM_DocumentTypes c  WITH(NOLOCK) on a.CostCenterIDLinked=c.CostCenterID
   where [DocumentLinkDefID]=@DocumentLinkDefID    
       
          
   SELECT @ColumnName=SysColumnName from ADM_CostCenterDef   with(nolock)  
   where CostCenterColID=@ColID    
    
   SELECT @lINKColumnName=SysColumnName from ADM_CostCenterDef   with(nolock)  
   where CostCenterColID=@lINKColID    
    
   --Create temporary table  
	set @Tolerance=''
	select @Tolerance=PrefValue from COM_DocumentPreferences with(nolock)        
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
		if(@Vouchers is not null and @Vouchers <>'')
			SET @Vouchers = @Vouchers +','+convert(nvarchar(5),@CostCenterID) 
		ELSE
			SET @Vouchers = convert(nvarchar(5),@CostCenterID)       

		SET @Query=@Query+' and b.CostCenterid in('+@Vouchers+')'
	END      
         
       
   IF(@ColumnName LIKE 'dcNum' )    
    SET @Query=@Query+' where d.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID)    
   ELSE    
    SET @Query=@Query+' where a.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID)    
       
       
       
   select @PrefValue=PrefValue from COM_DocumentPreferences  with(nolock)   
   where CostCenterID=@LinkCostCenterID and PrefName='Allowlinkingonce'      
       
   if(@PrefValue is not null and @PrefValue='True')--FOr Linking only once    
   begin    
    SET @Query=@Query+' and a.InvDocDetailsID not in ( select LinkedInvDocDetailsID from INV_DocDetails with(nolock) where LinkedInvDocDetailsID is not null)'    
   end    
     
   IF(@LocationID > 0)    
   BEGIN  
    select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)                            
    where CostCenterID=@CostCenterID and PrefName='OverrideLocationwise'          
            
   if(@PrefValue is null or @PrefValue<>'True')    
    SET @Query=@Query+' and DC.dcCCNID2='+convert(nvarchar(5),@LocationID)    
   END   
   IF(@DivisionID > 0)    
   BEGIN    
    select @PrefValue=PrefValue from COM_DocumentPreferences  with(nolock)                   --Need to check    
    where CostCenterID=@CostCenterID and PrefName='OverrideDivisionwise'      
        
    if(@PrefValue is null or @PrefValue<>'True')--FOr Override Division wise    
    SET @Query=@Query+' and DC.dcCCNID1='+convert(nvarchar(5),@DivisionID)    
   END    
        
   select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)    --Need to check    
   where CostCenterID=@CostCenterID and PrefName='MonthWise'      
     
   if(@PrefValue is NOT null AND  @PrefValue='True' and @DocDate is not null and @DocDate <> '')--FOr DocDate filter    
   BEGIN    
    SET @Query=@Query+' and month(convert(datetime, a.DocDate)) = '''+convert(nvarchar(20),month(@DocDate))+''''     
      END    
           
        
   select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)    --Need to check    
   where CostCenterID=@CostCenterID and PrefName='Ondocumentdate'      
       
   if(@PrefValue is NOT null AND  @PrefValue='True' and @DocDate is not null and @DocDate <> '')--FOr DocDate filter    
   BEGIN    
    SET @Query=@Query+' and convert(datetime, a.DocDate) = '''+convert(nvarchar(20),@DocDate)+''''     
      END    
          
      select @PrefValue=PrefValue from COM_DocumentPreferences  with(nolock)   --Need to check    
   where CostCenterID=@CostCenterID and PrefName='Duedatewise'      
       
   if(@PrefValue is NOT null AND  @PrefValue='True' and @DueDate is not null and @DueDate <> '' and @DueDate not like  '1-1-1900%') --FOr DueDate filter    
   BEGIN    
    SET @Query=@Query+' and convert(datetime, a.DueDate) = '''+convert(nvarchar(20),@DueDate)+''''    
      END    
          
 if(@DimensionWhere is not null and @DimensionWhere<>'')  
  begin            
      SET @Query=@Query+@DimensionWhere
  end  
  
  set @PrefValue=''
	select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)    
	where CostCenterID=@CostCenterID and PrefName='Debit Account'        

	if(@PrefValue is NOT null AND  @PrefValue='True') --FOr Debit Account filter      
	BEGIN      
		if((@docType in(6,10) and @LinkdocType not in(6,10)) or (@LinkdocType in(6,10) and @docType not in(6,10)))
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
	select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)    
	where CostCenterID=@CostCenterID and PrefName='Credit Account'        


	if(@PrefValue is NOT null AND  @PrefValue='True') --FOr Debit Account filter      
	BEGIN  
		if((@docType in(6,10) and @LinkdocType not in(6,10)) or (@LinkdocType in(6,10) and @docType not in(6,10)))
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

	--SET @PrefValue=''        
	--SELECT  @prefvalue =  prefvalue from COM_DocumentPreferences    --Need to check    
	--WHERE preferenceTypeName = 'Linking' and CostCenterID  = @CostCenterID  AND   PrefName='DimensionWise'

	--IF(@PrefValue is not null and @PrefValue <>'')--FOr Dimension Wise
	--BEGIN    
	--	SET @Query=@Query+' having a.'+@ColumnName+'-isnull(sum(b.LinkedFieldValue),0) >0 '    
	--END 
   
   
       

    
   
   print @Query
   
    --Read XML data into temporary table only to delete records    
   INSERT INTO @tblList    
    Exec(@Query)    
   SET @iCnt = @iCnt + 1    
  END     
        
           
   
     
 --GETTING DOCUMENT DETAILS    
 --SELECT distinct a.voucherno    
 --      ,a.[DocID], a.DebitAccount, a.CreditAccount ,a.ProductID from [INV_DocDetails] a    
 --join @tblList c on a.InvDocDetailsID=c.DocDetailsID    
 --where a.statusid=369    
 -- order by  a.voucherno    
        
 --GETTING DOCUMENT DETAILS      
     
   set @ColHeader= (select top 1 r.ResourceData from ADM_CostCenterDef c with(nolock)      
  join COM_LanguageResources r with(nolock) on r.ResourceID=c.ResourceID and r.LanguageID=@LangID      
  where CostCenterColID=@lINKColID)      
      
  declare @tempVoucher table ( voucherno nvarchar(50))    
      
  insert into @tempVoucher    
  SELECT distinct a.voucherno    
          from [INV_DocDetails] a with(nolock)    
   join @tblList c on a.InvDocDetailsID=c.DocDetailsID    
   where a.statusid=369 and a.linkstatusid<>445   
       
   select @ProductColName=SysColumnName from ADM_COSTCENTERDEF with(nolock) 
   where COSTCENTERID=@LinkCostCenterID and SysColumnName like 'dcalpha%' and ColumnCostCenterID=3
    
      
   SELECT c.Val ,@lINKColumnName,@ColHeader,@ColumnName,@ProductColName ProductColName,A.InvDocDetailsID AS DocDetailsID,A.[AccDocDetailsID],a.VoucherNO      
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
         ,a.[ProductID],p.QtyAdjustType,p.ProductTypeID,p.ProductName,p.ProductCode ,p.ParentID,p.IsGroup     
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
         ,a.[CreatedDate],UOMConversion,UOMConvertedQty, Cr.AccountName as CreditAcc, Dr.AccountName as DebitAcc,a.DynamicInvDocDetailsID,a.ReserveQuantity  
         FROM  [INV_DocDetails] a with(nolock)      
   join dbo.INV_Product p with(nolock) on  a.ProductID=p.ProductID  
   join dbo.Acc_Accounts Cr  WITH(NOLOCK) on  Cr.AccountID=a.CreditAccount    
     join dbo.Acc_Accounts Dr WITH(NOLOCK)  on  Dr.AccountID=a.DebitAccount      
   join @tblList c on a.InvDocDetailsID=c.DocDetailsID      
   WHERE A.VoucherNo IN ( select voucherno from @tempVoucher ) AND  a.ProductID = @ProductID        
   order by InvDocDetailsID     
    
    
    
   --GETTING DOCUMENT EXTRA COSTCENTER FEILD DETAILS      
   SELECT * FROM  [COM_DocCCData] with(nolock)      
   WHERE InvDocDetailsID IN (SELECT a.InvDocDetailsID FROM  [INV_DocDetails] a with(nolock)      
   join @tblList c on a.InvDocDetailsID=c.DocDetailsID      
   WHERE VoucherNo IN ( select voucherno from @tempVoucher ) AND  a.ProductID = @ProductID)      
   order by InvDocDetailsID      
         
   --GETTING DOCUMENT EXTRA NUMERIC FEILD DETAILS      
   SELECT * FROM [COM_DocNumData] with(nolock)      
   WHERE InvDocDetailsID IN (SELECT a.InvDocDetailsID FROM  [INV_DocDetails] a with(nolock)      
   join @tblList c on a.InvDocDetailsID=c.DocDetailsID      
   WHERE VoucherNo IN ( select voucherno from @tempVoucher ) AND  a.ProductID = @ProductID)      
   order by InvDocDetailsID      
      
   --GETTING DOCUMENT EXTRA TEXT FEILD DETAILS      
   SELECT * FROM [COM_DocTextData] with(nolock)      
   WHERE InvDocDetailsID IN (SELECT a.InvDocDetailsID FROM  [INV_DocDetails] a  with(nolock)     
   join @tblList c on a.InvDocDetailsID=c.DocDetailsID      
   WHERE VoucherNo IN ( select voucherno from @tempVoucher ) AND  a.ProductID = @ProductID)      
   order by InvDocDetailsID      
      
   --Getting Linking Fields       
   SELECT B.SysColumnName BASECOL,L.SysColumnName LINKCOL ,A.[VIEW],A.CostCenterColIDLinked,c.[CostCenterIDLinked] ,A.CalcValue  
   FROM COM_DocumentLinkDetails A  with(nolock)   
   JOIN [COM_DocumentLinkDef] c with(nolock) ON c.[DocumentLinkDefID]=A.DocumentLinkDeFID      
   JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.CostCenterColIDBase      
   JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDLinked      
   WHERE A.DocumentLinkDeFID in (SELECT  DocumentLinkDefID  FROM  @tblDocLinkDef )    
         
   
   	SELECT a.[BatchID],a.[InvDocDetailsID],a.UomConvertedQty Quantity,a.[HoldQuantity] 
	,a.[ReleaseQuantity],a.[VoucherType] ,a.DynamicInvDocDetailsID 
	,[RefInvDocDetailsID], b.[BatchNumber],CONVERT(datetime,b.[MfgDate]) MfgDate  
	,CONVERT(datetime,b.[ExpiryDate]) ExpiryDate,b.[MRPRate],b.[RetailRate]  
	,b.[StockistRate],IsQtyIgnored FROM INV_DocDetails a WITH(NOLOCK)   
	join INV_Batches b WITH(NOLOCK) on a.BatchID=b.BatchID  
	WHERE  a.InvDocDetailsID IN (SELECT a.InvDocDetailsID FROM  [INV_DocDetails] a with(nolock)      
   join @tblList c on a.InvDocDetailsID=c.DocDetailsID      
   WHERE VoucherNo IN ( select voucherno from @tempVoucher ) AND  a.ProductID = @ProductID)  
      
    
     SELECT C.*,TBL.SysColumnName FROM ADM_COSTCENTERDEF C with(nolock)    
  INNER JOIN  (  
     SELECT  case when L.SysColumnName IS null then B.SysColumnName else L.SysColumnName end as SysColumnName,A.[VIEW]   FROM COM_DocumentLinkDetails A   with(nolock)  
   JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.CostCenterColIDBase    
   left JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDLinked    
   WHERE A.DocumentLinkDeFID in (select DocumentLinkDefID from @tblDocLinkDef) ) AS TBL ON C.SysColumnName = TBL.SysColumnName  
   WHERE C.COSTCENTERID in (select CCID from @tblDocLinkDef)  AND TBL.[VIEW] = 1  
   
      
   SELECT [FileID],[FilePath],[ActualFileName],[RelativeFileName],[FileExtension],[IsProductImage]  
   ,[FileDescription],f.[CostCenterID],GUID,t.DocID FROM  COM_Files f WITH(NOLOCK)   
    join (select CostCenterID,DocID   FROM  [INV_DocDetails] a with(nolock)      
   join dbo.INV_Product p with(nolock) on  a.ProductID=p.ProductID      
   join @tblList c on a.InvDocDetailsID=c.DocDetailsID      
   WHERE A.VoucherNo IN ( select voucherno from @tempVoucher ) AND  a.ProductID = @ProductID )
   as t on f.FeatureID=t.CostCenterID and f.FeaturePK=t.DocID
 
		set @PrefValue=''
    select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)        
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
   		join @tblList t on t.DocDetailsID=A.InvDocDetailsID 
   		left join inv_docdetails b with(nolock) on a.InvDocDetailsID=b.LinkedInvDocDetailsID 
		left  join INV_SerialStockProduct bs with(nolock) on bs.InvDocDetailsID=b.InvDocDetailsID and a.[SerialNumber]=bs.SerialNumber
		where bs.SerialProductID is null 
	END
	ELSE
		SELECT 1 where 1=2
		
	select a.*
	from   COM_DocQtyAdjustments a WITH(NOLOCK)  
	join @tblList t on a.InvDocDetailsID=t.DocDetailsID	
	
		
  select distinct b.DocumentAbbr , a.[CostCenterID] from [INV_DocDetails] a  with(nolock)     
  join @tblList c on a.InvDocDetailsID=c.DocDetailsID     
  join  adm_documenttypes b with(nolock) on a.[CostCenterID] = b.[CostCenterID]    
	
    SELECT 1 where 1=2
    
	set @PrefValue=''
    select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)        
    where CostCenterID=@CostCenterID and PrefName='CopyBins'     
         
	if(@PrefValue is not null and @PrefValue='True')
	BEGIN
		select a.InvDocDetailsID,a.BinID,a.Quantity from   INV_BinDetails a WITH(NOLOCK)  
   		join @tblList t on t.DocDetailsID=A.InvDocDetailsID 
	END
	ELSE
		SELECT 1 where 1=2

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
