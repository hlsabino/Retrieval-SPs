USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductDetails]
	@ProductIDs [nvarchar](max),
	@UOMID [int] = 0,
	@CCXML [nvarchar](max),
	@CostCenterID [int],
	@DocDate [datetime],
	@CreditAccount [int],
	@DocQty [float],
	@CalcAvgrate [bit] = 0,
	@DocDetailsID [int] = 0,
	@LocationId [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON      
      
    DECLARE @SQL NVARCHAR(MAX),@XML XML,@WHERE NVARCHAR(MAX),@I INT,@CNT INT,@NODEID INT,@CcID INT      
    Declare @CC nvarchar(10),@CCWHERE NVARCHAR(MAX),@OrderBY NVARCHAR(MAX),@HOLDQTY FLOAT,@CommittedQTY FLOAT,@RESERVEQTY FLOAT      
    DECLARE @AvgRate float,@LastPRate float,@PWLastPRate float,@ccCNT INT,@ccCNTT INT,@QOH float,@PrefValue nvarchar(50),@NID INT      
                     
   DECLARE @SIZE INT,@Cols NVARCHAR(1000),@ColsList NVARCHAR(1000) ,@DocumentType int,@uBarcode nvarchar(100),@VBarcode nvarchar(100)  
   DECLARE @UPDATESQL NVARCHAR(MAX),@CCJOINQUERY NVARCHAR(MAX),@LastPCost float ,@PWLastPCost float     
   SET @XML=@CCXML      
         
   DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId INT)      
   INSERT INTO @tblCC(CostCenterID,NodeId)      
   SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')      
   FROM @XML.nodes('/XML/Row') as Data(X)      
            
          
             select @DocumentType=DocumentType from adm_documenttypes with(nolock) where CostCenterID=@CostCenterID  
    
            
            set @SQL='SELECT a.ProductID,ProductTypeID,AttributeGroupID,a.uomid,BaseName,UnitName,b.Conversion      
            ,reorderlevel,reorderqty,PurchaseRate,PurchaseRateA,PurchaseRateB,PurchaseRateC,PurchaseRateD,PurchaseRateE,PurchaseRateF,PurchaseRateG      
            ,SellingRate,SellingRateA,SellingRateB,SellingRateC,SellingRateD,SellingRateE,SellingRateF,SellingRateG  
            ,f.FileExtension,f.GUID FileGUID,0 LastPCost,0  PWLastPCost
            ,0 AvgRate,0 LastPurchaseRate,0 PWLastPRate,0 QOH ,0 HOLDQTY,0 RESERVEQTY,0 CommittedQTY  
            ,'' UnitProductCode,'' VendorProductCode
            FROM INV_Product a WITH(NOLOCK)  
            left join  COM_UOM b WITH(NOLOCK)   on b.UOMID=a.UOMID   
            left join COM_Files f WITH(NOLOCK) on FeaturePK=a.ProductID and FeatureID=3 and IsProductImage=1    
            WHERE a.ProductID in ('+@ProductIDs+') '
			    print @SQL

			exec(@SQL)
                
             
      
   set @WHERE=' and (ProductID in ('+@ProductIDs+') or ProductID=1)'       
   set @CCWHERE=' and ProductID in ('+@ProductIDs+')'       
   set @WHERE=@WHERE+' and ('      
   set @OrderBY=',ProductID Desc,AccountID Desc'      
   if exists(select CostCenterID from @tblCC where CostCenterID=2)      
   begin      
    select @NODEID=NodeId from @tblCC where CostCenterID=2      
    set @WHERE=@WHERE+' AccountID ='+convert(nvarchar,@NODEID)+'  or '       
    set @CCWHERE=@CCWHERE+' and AccountID='+convert(nvarchar,@NODEID)      
   end      
   else      
    set @CCWHERE=@CCWHERE+' and AccountID=1'      
          
   set @WHERE=@WHERE+' AccountID =1 )'       
         
   Set @I=50000       
   Set @CNT=50050       
   while(@I<@CNT)      
   begin      
    set @I=@I+1      
    set @OrderBY=@OrderBY+',CCNID'+convert(nvarchar,@I-50000)+' Desc '      
    set @CC='CCNID'+convert(nvarchar,@I-50000)+'='      
    set @WHERE=@WHERE+' and ('      
    if exists(select CostCenterID from @tblCC where CostCenterID=@I)      
    begin      
     select @NODEID=NodeId from @tblCC where CostCenterID=@I      
     set @WHERE=@WHERE+@CC+convert(nvarchar,@NODEID)+' or '      
     set @CCWHERE=@CCWHERE+' and '+@CC+convert(nvarchar,@NODEID)           
    end      
    else      
     set @CCWHERE=@CCWHERE+' and '+@CC+'1'       
           
    set @WHERE=@WHERE+@CC+'1 )'          
   end      
       
        
         
   set @SQL='  select * from COM_CCPrices with(nolock)      
   where WEF<='+convert(nvarchar,convert(float,@DocDate))+@CCWHERE+' 
   and UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' order by WEF Desc 
     
    select * from COM_CCPrices with(nolock)      
   where WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE +'
    and (UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' or UOMID=1)   order by WEF Desc'+@OrderBY+',UOMID Desc'        
    print @SQL
    exec(@SQL)      
   
	set @CCJOINQUERY=''
	select @CCJOINQUERY=PrefValue from COM_DocumentPreferences
	where PrefName='TransitDOcs' and CostCenterID=@CostCenterID
	
	if(@CCJOINQUERY<>'')
	BEGIN
		if(@LocationId>0)   
			set @WHERE=' join com_docccdata d on a.invdocdetailsid=d.invdocdetailsid and dcccnid2='+CONVERT(nvarchar,@LocationId)+' '
		else
			set @WHERE=''	
		SET @SQL=dbo.fnGetPendingOrders(@CCJOINQUERY,@ProductIDs,@WHERE,'',0)
		exec( @SQL)
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
