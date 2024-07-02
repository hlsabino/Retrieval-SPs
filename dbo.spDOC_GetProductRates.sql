USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductRates]
	@ProductID [bigint] = 0,
	@UOMID [bigint] = 0,
	@CCXML [nvarchar](max),
	@CostCenterID [bigint],
	@DocDate [datetime],
	@CreditAccount [bigint],
	@IsPurchase [float],
	@UserID [int] = 0,
	@LangID [int] = 1,
	@PRate [float] = 0 OUTPUT,
	@SRate [float] = 0 OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON      
			declare @PurchaseRate float, @SellingRate float
            DECLARE @SQL NVARCHAR(MAX),@XML XML,@WHERE NVARCHAR(MAX),@I INT,@CNT INT,@NODEID BIGINT,@CcID BIGINT,@BalQOH FLOAT      
            Declare @CC nvarchar(10),@CCWHERE NVARCHAR(MAX),@OrderBY NVARCHAR(MAX),@HOLDQTY FLOAT,@CommittedQTY FLOAT,@RESERVEQTY FLOAT      
            DECLARE @AvgRate float,@LastPRate float,@PWLastPRate float,@ccCNT INT,@ccCNTT INT,@QOH float,@PrefValue nvarchar(50),@NID BIGINT      
                     
   DECLARE @SIZE INT,@Cols NVARCHAR(1000),@ColsList NVARCHAR(1000) ,@DocumentType int,@uBarcode nvarchar(100),@VBarcode nvarchar(100)  
   DECLARE @UPDATESQL NVARCHAR(MAX),@CCJOINQUERY NVARCHAR(MAX),@LastPCost float ,@PWLastPCost float     
   SET @XML=@CCXML      
         
   DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId BIGINT)      
   INSERT INTO @tblCC(CostCenterID,NodeId)      
   SELECT X.value('@CostCenterID','int'),X.value('@NODEID','BIGINT')      
   FROM @XML.nodes('/XML/Row') as Data(X)      
            
         set @PRate=0
         set @SRate=0
           
    if(@UOMID=0)      
    begin      
          select @UOMID=UOMID from INV_Product a WITH(NOLOCK)               
          WHERE ProductID = @ProductID      
    end    
          
   set @WHERE=' and (ProductID='+convert(nvarchar,@ProductID)+' or ProductID=1)'       
   set @CCWHERE=' and ProductID='+convert(nvarchar,@ProductID)       
   set @WHERE=@WHERE+' and ('      
   set @OrderBY=',ProductID Desc,AccountID Desc'      
   if exists(select CostCenterID from @tblCC where CostCenterID=2)      
   begin      
    select @NODEID=NodeId from @tblCC where CostCenterID=2      
    set @WHERE=@WHERE+' AccountID ='+convert(nvarchar,@NODEID)+'  or '       
    set @CCWHERE=@CCWHERE+' and AccountID='+convert(nvarchar,@NODEID)      
   end      
   else      
    set @CCWHERE=@CCWHERE+' and AccountID=0'      
          
   set @WHERE=@WHERE+' AccountID=0)'       
         
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
     set @CCWHERE=@CCWHERE+' and '+@CC+'0'       
           
    set @WHERE=@WHERE+@CC+'0)'          
   end      
       
	if(@IsPurchase=1)
	begin       
		set @SQL='  
		 if exists (select PriceCCID from COM_CCPrices WITH(NOLOCK)      
		where WEF<='+convert(nvarchar,convert(float,@DocDate))+@CCWHERE+') 
		set @PurRate=(select top 1 PurchaseRate from COM_CCPrices   WITH(NOLOCK)    
		where WEF<='+convert(nvarchar,convert(float,@DocDate))+@CCWHERE+' 
		and UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' order by WEF Desc) 
		else 
		set @PurRate=(select top 1 PurchaseRate from COM_CCPrices WITH(NOLOCK)      
		where WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE +'
		and (UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' or UOMID=1)   order by WEF Desc'+@OrderBY+',UOMID Desc)
		'        
	end
	else
	begin
		set @SQL=' 
		if exists (select PriceCCID from COM_CCPrices WITH(NOLOCK)      
		where WEF<='+convert(nvarchar,convert(float,@DocDate))+@CCWHERE+') 
		set @SalesRate=(select top 1  SellingRate from COM_CCPrices  WITH(NOLOCK)     
		where WEF<='+convert(nvarchar,convert(float,@DocDate))+@CCWHERE+' 
		and UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' order by WEF Desc )
		else 
		set @SalesRate=(select top 1  SellingRate from COM_CCPrices WITH(NOLOCK)       
		where WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE +'
		and (UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' or UOMID=1)   order by WEF Desc'+@OrderBY+',UOMID Desc)
		'        
	end 
	
	 
	if(@IsPurchase=1)
	begin
		exec sp_executesql @SQL  , N'@PurRate float output', @PurchaseRate output  
	   set @PRate=@PurchaseRate
	end
	else
	begin
	 
	exec sp_executesql @SQL  , N'@SalesRate float output', @SellingRate output    
	set @SRate=@SellingRate
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
