USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocDetailsBYInvDetID]
	@InvDetID [bigint] = 0,
	@CostCenterID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    
    
	--Declaration Section    
	DECLARE @DocumentLinkDefID bigint,@LinkCostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50),@ProductColName  nvarchar(50)   
	DECLARE @Query nvarchar(max),@Vouchers nvarchar(max),@ColID BIGINT,@lINKColID BIGINT,@ColHeader nvarchar(200),@PrefValue nvarchar(50),@PackQty nvarchar(50)
	declare @autoCCID int,@tempDOcID bigint,@CrAccID BIGINT,@DbAccID BIGINT,@docType int ,@LinkdocType int,@Join nvarchar(max),@Where nvarchar(max),@GroupFilter nvarchar(max)
	
	select @LinkCostCenterID=CostCenterID
	FROM  [INV_DocDetails] a   WITH(NOLOCK)  	 
	where a.InvDocDetailsID=@InvDetID

	SELECT     @ColID=[CostCenterColIDBase]
	,@lINKColID=[CostCenterColIDLinked]    
	,@Vouchers = [LinkedVouchers]
	,@docType=b.DocumentType,@LinkdocType=c.DocumentType
	,@DocumentLinkDefID=[DocumentLinkDefID]
	FROM [COM_DocumentLinkDef]  a WITH(NOLOCK)
	join ADM_DocumentTypes b  WITH(NOLOCK) on a.CostCenterIDBase=b.CostCenterID
	join ADM_DocumentTypes c  WITH(NOLOCK) on a.CostCenterIDLinked=c.CostCenterID
	where   [CostCenterIDBase]=@CostCenterID and [CostCenterIDLinked]=@LinkCostCenterID
    
	SELECT @ColumnName=SysColumnName from ADM_CostCenterDef   WITH(NOLOCK)  
	where CostCenterColID=@lINKColID    

	SELECT @lINKColumnName=SysColumnName from ADM_CostCenterDef  WITH(NOLOCK)  
	where CostCenterColID=@ColID  

	set @ColHeader=(select top 1 r.ResourceData from ADM_CostCenterDef c   WITH(NOLOCK)  
	join COM_LanguageResources r WITH(NOLOCK)  on r.ResourceID=c.ResourceID and r.LanguageID=@LangID    
	where CostCenterColID=@lINKColID)    
    
	set @PrefValue=''
    select @PrefValue=PrefValue from COM_DocumentPreferences WITH(NOLOCK)       
    where CostCenterID=@CostCenterID and PrefName='CheckFifoQOH'
	 
	select @ProductColName=SysColumnName from ADM_COSTCENTERDEF WITH(NOLOCK)
	where COSTCENTERID=@LinkCostCenterID and SysColumnName like 'dcalpha%' and ColumnCostCenterID=3

	--GETTING DOCUMENT DETAILS    
	SELECT  0,@ColumnName,@ColHeader,@lINKColumnName,@ProductColName ProductColName,A.InvDocDetailsID AS DocDetailsID,A.[AccDocDetailsID],a.VoucherNO    
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
         ,a.lineNarration    
         ,a.[DebitAccount]     
         ,a.[CreditAccount]   
         ,a.[DocSeqNo]    
         ,a.[ProductID],p.QtyAdjustType,p.IsPacking,p.IsBillOfEntry,p.ProductTypeID,p.ProductName,p.ProductCode,p.Volume,p.Weight,p.ParentID,p.IsGroup,p.Wastage
         ,isnull(p.MaxTolerancePer,0) ToleranceLimitsPercentage,isnull(p.MaxToleranceVal,0)  ToleranceLimitsValue   
        
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
         ,a.[CreatedBy],a.vouchertype  
         ,a.[CreatedDate],UOMConversion,UOMConvertedQty, Cr.AccountName as CreditAcc, Dr.AccountName as DebitAcc,a.DynamicInvDocDetailsID,a.ReserveQuantity 
         ,case when @PrefValue='true' THEN isnull((select sum(qty) from(
		select inv.Quantity-isnull(sum(lv.LinkedFieldValue),0) qty from INV_DocDetails inv WITH(NOLOCK)  
		left  join  INV_DocDetails lv WITH(NOLOCK) on inv.InvDocDetailsID=lv.LinkedInvDocDetailsID 
		where inv.ProductID=a.ProductID and inv.CostCenterID=a.CostCenterID and  inv.StatusID=369
		and (inv.DocDate<a.DocDate or (inv.DocDate=a.DocDate and inv.VoucherNo<a.VoucherNo))
		group by inv.InvDocDetailsID, inv.Quantity  )as t),0) else 0 end Fifo
	FROM  [INV_DocDetails] a   WITH(NOLOCK)  
	join dbo.INV_Product p WITH(NOLOCK) on  a.ProductID=p.ProductID    
	join dbo.Acc_Accounts Cr  WITH(NOLOCK) on  Cr.AccountID=a.CreditAccount    
	join dbo.Acc_Accounts Dr WITH(NOLOCK)  on  Dr.AccountID=a.DebitAccount  
	left join com_uom u WITH(NOLOCK)  on a.Unit=u.UOMID    
	where a.InvDocDetailsID=@InvDetID
	 

    --GETTING DOCUMENT EXTRA COSTCENTER FEILD DETAILS    
	SELECT cc.* FROM    [COM_DocCCData]  cc with(nolock)  
	where InvDocDetailsID=@InvDetID
	

	--GETTING DOCUMENT EXTRA NUMERIC FEILD DETAILS    
	SELECT n.* FROM [COM_DocNumData]  n  WITH(NOLOCK) 
	where InvDocDetailsID=@InvDetID
    
	--GETTING DOCUMENT EXTRA TEXT FEILD DETAILS    
	SELECT te.* FROM [COM_DocTextData]  te  WITH(NOLOCK) 
	where InvDocDetailsID=@InvDetID
    
   --Getting Linking Fields    
   SELECT case when A.CostCenterColIDBase <0 THEN 'TO'+B.SysColumnName else B.SysColumnName end BASECOL,L.SysColumnName LINKCOL ,A.[VIEW],A.CostCenterColIDLinked,A.CalcValue  
   FROM COM_DocumentLinkDetails A WITH(NOLOCK) 
   JOIN ADM_CostCenterDef B WITH(NOLOCK) ON (B.CostCenterColID=A.CostCenterColIDBase or B.CostCenterColID=A.CostCenterColIDBase*-1)
   left JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON (L.CostCenterColID=A.CostCenterColIDLinked or L.CostCenterColID=A.CostCenterColIDLinked *-1)   
   WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
       
        
	
	
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
