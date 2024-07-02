USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetLinkDefDetails]
	@CostcenterID [int],
	@LinkCostCenterID [int],
	@Vouchers [nvarchar](max),
	@productids [nvarchar](max),
	@DocSeqNos [nvarchar](max),
	@CCColIDs [nvarchar](max),
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON  
    declare @sql nvarchar(max),@sql2 nvarchar(max),@VoucherWhere nvarchar(max),@OrderBy nvarchar(max)
    SET @sql=''
    SET @sql2=''
    SET @VoucherWhere=''
    SET @OrderBy=''
    IF(@Vouchers='')
    BEGIN
	   --Getting Linking Fields    
	   SELECT B.SysColumnName BASECOL,L.SysColumnName LINKCOL ,A.[VIEW],A.CostCenterColIDLinked  
	   FROM COM_DocumentLinkDetails A WITH(NOLOCK) 
	   JOIN ADM_CostCenterDef B WITH(NOLOCK) ON B.CostCenterColID=A.CostCenterColIDBase    
	   left JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON L.CostCenterColID=A.CostCenterColIDLinked    
	   WHERE b.CostCenterID=@LinkCostCenterID and L.CostCenterID=@CostcenterID  and A.CostCenterColIDLinked<>0  
	   
	   SELECT distinct [WorkFlowDefID],[CostCenterID],[Action],[Expression],a.WorkFlowID
	   FROM [COM_WorkFlowDef]  a   WITH(NOLOCK)
	   join COM_WorkFlow b WITH(NOLOCK) on a.WorkFlowID=b.WorkFlowID  and a.LevelID=b.LevelID
	   LEFT JOIN COM_Groups G with(nolock) on b.GroupID=G.GID
	   where [CostCenterID]=@LinkCostCenterID and IsEnabled=1  
	   and (b.UserID =@UserID or b.RoleID=@RoleID or G.UserID=@UserID or G.RoleID=@RoleID ) 
	   
	   
	    select a.CostCenterColID,a.SysColumnName from ADM_CostCenterDef a WITH(NOLOCK)  
		left join COM_DocumentLinkDetails b WITH(NOLOCK) on a.CostCenterColID=b.CostCenterColIDBase  
		where a.[CostCenterID]=@LinkCostCenterID and (SysColumnName='ProductID' or (  
		linkData is not null and (LinkData =26585 or LinkData =54306 or LinkData =54307 or LinkData =53529 or LinkData =53589 or LinkData =53530)  
		and (b.CostCenterColIDBase is null or b.CostCenterColIDlinked=0)))  
    
	  SELECT  C.CostCenterColID,C.ResourceID,C.SysColumnName,C.ColumnCostCenterID,C.LinkData,C.LocalReference
	  FROM ADM_CostCenterDef C WITH(NOLOCK)    WHERE C.CostCenterID = @LinkCostCenterID     
	  AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0) 
	  AND   	  (C.SysColumnName NOT LIKE '%dcCalcNum%')  AND (C.SysColumnName NOT LIKE '%dcExchRT%') 
	  AND (C.SysColumnName NOT LIKE '%dcCurrID%') AND (C.SysColumnName NOT LIKE 'dcPOSRemarksNum%')  
	  AND (C.SysColumnName <> 'UOMConversion')   AND (C.SysColumnName <> 'UOMConvertedQty')  
    END
    ELSE 
    BEGIN			
		SET @VoucherWhere=' Where a.VoucherNo IN ('+@Vouchers+') '

		IF (ISNULL(@DocSeqNos,'')<>'')
			SET @VoucherWhere=@VoucherWhere+' and a.DocSeqNo in('+@DocSeqNos+')'
		ELSE IF (ISNULL(@productids,'')<>'')
			SET @VoucherWhere=@VoucherWhere+' and a.ProductID in('+@productids+')'

		SET @OrderBy=' order by a.VoucherNo,a.DocSeqNo,a.vouchertype'
		--Table0
		SET @sql='Select a.InvDocDetailsID,A.[AccDocDetailsID],a.VoucherNO,a.[DocID],a.[CostCenterID],a.[DocumentType],a.[VersionNo],a.[DocAbbr],a.[DocPrefix],a.[DocNumber],CONVERT(DATETIME,a.[DocDate]) AS DocDate,CONVERT(DATETIME,a.[DueDate]) AS DueDate    
                   ,CONVERT(DATETIME,a.[BillDate]) AS BillDat,a.[StatusID],a.[BillNo],a.[LinkedInvDocDetailsID],a.[CommonNarration],a.LineNarration,a.[DebitAccount],a.[CreditAccount],a.[DocSeqNo],a.[ProductID],p.QtyAdjustType,p.IsPacking,p.IsBillOfEntry,p.ProductTypeID,p.ProductName,p.ProductCode,p.Volume,p.Weight,p.ParentID,p.IsGroup,p.Wastage
                   ,isnull(p.MaxTolerancePer,0) ToleranceLimitsPercentage,isnull(p.MaxToleranceVal,0)  ToleranceLimitsValue,a.[Quantity],a.Unit,u.UnitName,a.[HoldQuantity],a.[ReleaseQuantity],a.[IsQtyIgnored],a.[IsQtyFreeOffer],a.[Rate],a.[AverageRate],a.[Gross], a.[GrossFC],a.[StockValue]  ,a.[StockValueFC]   
                   ,a.[CurrencyID],a.[ExchangeRate],a.ParentSchemeID,a.[CreatedBy],a.vouchertype,a.[CreatedDate],UOMConversion,UOMConvertedQty,a.DynamicInvDocDetailsID,a.ReserveQuantity,a.ProductID ID '
		
		IF (ISNULL(@CCColIDs,'')<>'')                   
            SET @sql=@sql+' ,Cr.AccountName as CreditAcc, Dr.AccountName as DebitAcc '
        
        SET @sql=@sql+' From INV_DocDetails a with(nolock) join INV_Product p with(nolock) on a.ProductID=p.ProductID '
		
		IF (ISNULL(@CCColIDs,'')<>'')                   
			SET @sql=@sql+' join dbo.Acc_Accounts Cr  WITH(NOLOCK) on  Cr.AccountID=a.CreditAccount join dbo.Acc_Accounts Dr WITH(NOLOCK)  on  Dr.AccountID=a.DebitAccount  '

	    SET @sql=@sql+' left join com_uom u WITH(NOLOCK)  on a.Unit=u.UOMID   '
		SET @sql=@sql+@VoucherWhere+@OrderBy	 
		
		--IF (ISNULL(@DocSeqNos,'')<>'')
		--	SET @sql=@sql+' and a.DocSeqNo in('+@DocSeqNos+')'
		--ELSE IF (ISNULL(@productids,'')<>'')
		--	SET @sql=@sql+' and a.ProductID in('+@productids+')'	
			               
		--SET @sql=@sql+@OrderBy	
		
		--Table1
		SET @sql2=' SELECT a.InvDocDetailsID,Cc.* From INV_DocDetails a with(nolock) inner join COM_DocCCData Cc with(nolock) on a.InvDocDetailsID=Cc.InvDocDetailsID '
		SET @sql2=@sql2+@VoucherWhere+@OrderBy
		
		--Table2	                 
		SET @sql2=@sql2+' SELECT a.InvDocDetailsID,Num.* From INV_DocDetails a with(nolock) inner join COM_DocNumData Num with(nolock) on a.InvDocDetailsID=Num.InvDocDetailsID '
		SET @sql2=@sql2+@VoucherWhere+@OrderBy
	        
		--Table3	                   
		SET @sql2=@sql2+' SELECT a.InvDocDetailsID,Txt.* From INV_DocDetails a with(nolock) inner join COM_DocTextData Txt with(nolock) on a.InvDocDetailsID=Txt.InvDocDetailsID '
		SET @sql2=@sql2+@VoucherWhere+@OrderBy

		--Table4	                     
		SET @sql2=@sql2+' DECLARE @CCIDLinked INT
					      SET  @CCIDLinked=(Select Top 1 CostCenterID FROM Inv_DocDetails WITH(NOLOCK) WHERE  VoucherNo IN ('+@Vouchers+'))
					      SELECT B.SysColumnName BASECOL,L.SysColumnName LINKCOL ,A.[VIEW],A.CostCenterColIDLinked,A.CalcValue 
					      FROM COM_DocumentLinkDetails A WITH(NOLOCK) JOIN COM_DocumentLinkDef D WITH(NOLOCK) ON A.DocumentLinkDeFID=D.DocumentLinkDeFID  
					      JOIN ADM_CostCenterDef B WITH(NOLOCK) ON B.CostCenterColID=A.CostCenterColIDBase LEFT JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON L.CostCenterColID=A.CostCenterColIDLinked    
					      WHERE A.CostCenterColIDLinked<>0 AND D.CostCenterIDBase='+CONVERT(nvarchar,@LinkCostCenterID)+' AND D.CostCenterIDLinked=@CCIDLinked  '
		IF (ISNULL(@CCColIDs,'')<>'')
			SET @sql2=@sql2+' AND A.CostCenterColIDBase NOT IN ('+@CCColIDs+')'

		--Table5				
		SET @sql2=@sql2+' select CostCenterIDLinked,b.SysColumnName from COM_DocumentLinkDef a WITH(NOLOCK)
				join ADM_CostCenterDef b WITH(NOLOCK) on a.CostCenterColIDBase=b.CostCenterColID
				where CostCenterIDBase='+CONVERT(nvarchar,@LinkCostCenterID)+' 
				and CostCenterIDLinked iN(select CostCenterID from INV_DocDetails WITH(NOLOCK) where VoucherNo in('+@Vouchers+')'
		IF (ISNULL(@DocSeqNos,'')<>'')
			Set @sql2=@sql2+' and DocSeqNo in('+@DocSeqNos+'))'	
		ELSE
			Set @sql2=@sql2+' and ProductID in('+@productids+'))'
		--
		
		SET @sql=@sql+@sql2
		PRINT (@sql)    	
		EXEC(@sql)
	END
         
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
