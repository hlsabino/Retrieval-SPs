USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetPriceofUnit]
	@ProductID [int] = 0,
	@UOMID [int] = 0,
	@CCXML [nvarchar](max),
	@CostCenterID [int],
	@DocDate [datetime],
	@CreditAccount [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON        
        
    DECLARE @SQL NVARCHAR(MAX),@XML XML,@WHERE NVARCHAR(MAX),@I INT,@CNT INT,@NODEID INT,@CcID INT,@table   nvarchar(200),@CC nvarchar(max)                 
    DECLARE @baseID INT,@DocumentType int,@NID INT,@JOIN NVARCHAR(MAX),@OrderBY NVARCHAR(MAX),@tblName nvarchar(200)          
	declare @isGrp bit	
	SET @XML=@CCXML        
    
          
   DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId INT)        
   INSERT INTO @tblCC(CostCenterID,NodeId)        
   SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')        
   FROM @XML.nodes('/XML/Row') as Data(X)        

	select @DocumentType=DocumentType from adm_documenttypes with(nolock) where CostCenterID=@CostCenterID    
	declare @RateTble table(WEF float,[PurchaseRate] float,[SellingRate] float,[PurchaseRateA]float,[PurchaseRateB]float,[PurchaseRateC]float,[PurchaseRateD]float
				,[PurchaseRateE]float,[PurchaseRateF]float,[PurchaseRateG]float,[SellingRateA]float,[SellingRateB]float,[SellingRateC]float
				,[SellingRateD]float,[SellingRateE]float,[SellingRateF]float,[SellingRateG] float)  
                
	declare @PTCC table(id 	int identity(1,1),CCID int,isgrp bit,tblname nvarchar(200))
	insert into @PTCC
	SELECT [CostCenterID],[IsGroupExists],b.TableName
	FROM COM_CCPriceTaxCCDefn a WITH(NOLOCK)
	join ADM_Features b WITH(NOLOCK) on a.[CostCenterID]=b.FeatureID
	where [DefType]=1 and ProfileID=0
    set @WHERE=''
	Select @I=MIN(id),@CNT=Max(id) from @PTCC
	set @JOIN=''
	set @OrderBY=''
	while(@I<=@CNT)        
	begin      
         select @CcID=CCID,@isGrp=isgrp,@tblName=tblname from @PTCC where id=@I
       
        if(@CcID=2)
			set @CC=' AccountID ='
		ELSE if(@CcID=3)
			set @CC=' ProductID ='	
        ELSE  if(@CcID>50000)
			set @CC='CCNID'+convert(nvarchar,@CcID-50000)+'='  
		ELSE
		BEGIN
			set @I=@I+1
			Continue;	
		END
		if not exists(select CostCenterID from @tblCC where CostCenterID=@CcID)
		BEGIN
				if exists(select b.CostcenterCOlID from adm_costcenterdef a with(nolock)
				join adm_costcenterdef b with(nolock) on a.CostcenterCOlID=b.LocalReference
				where a.costcenterid=@CostCenterID and b.costcenterid=@CostCenterID and a.syscolumnname='productid'
				and b.ColumnCostCenterID=@CcID)
				BEGIN
					set @SQL='Select @NID='+REPLACE(@CC,'=','')+' from com_CCCCData WITH(NOLOCK) 
					where CostcenterID=3 and NOdeID='+convert(nvarchar,@ProductID)
					EXEC sp_executesql @SQL, N'@NID INT OUTPUT', @NID OUTPUT  
					if(@NID>1)
						insert into @tblCC(CostCenterID,NodeId)values(@CcID,@NID)
				END
		END
		
		 
		 set @WHERE=@WHERE+' and (' 
         if (exists(select CostCenterID from @tblCC where CostCenterID=@CcID) or @CcID=3)
         BEGIN
			if(@CcID=3)
				set @NODEID=@ProductID
			ELSE	
				select @NODEID=NodeId from @tblCC where CostCenterID=@CcID			
			if(@isGrp=1)
			BEGIN				
				if(@CcID in(2,3))
				BEGIN
					set @JOIN=@JOIN+' left join '+@tblName+' CC'+CONVERT(nvarchar,@I)+' with(nolock) on P.'+@CC+'CC'+CONVERT(nvarchar,@I)+'.'+REPLACE(@CC,'=','')+'
								left join '+@tblName+'  CJ'+CONVERT(nvarchar,@I)+' with(nolock) on CJ'+CONVERT(nvarchar,@I)+'.lft between CC'+CONVERT(nvarchar,@I)+'.lft and CC'+CONVERT(nvarchar,@I)+'.rgt'				
					set @WHERE=@WHERE+'CJ'+CONVERT(nvarchar,@I)+'.'+@CC+convert(nvarchar,@NODEID)+' or '
				END
				ELSE
				BEGIN
					set @JOIN=@JOIN+' left join '+@tblName+' CC'+CONVERT(nvarchar,@I)+' with(nolock) on P.'+@CC+'CC'+CONVERT(nvarchar,@I)+'.NodeID
								left join '+@tblName+'  CJ'+CONVERT(nvarchar,@I)+' with(nolock) on CJ'+CONVERT(nvarchar,@I)+'.lft between CC'+CONVERT(nvarchar,@I)+'.lft and CC'+CONVERT(nvarchar,@I)+'.rgt'				
					set @WHERE=@WHERE+'CJ'+CONVERT(nvarchar,@I)+'.NODEID='+convert(nvarchar,@NODEID)+' or '
				END
			END
			ELSE
			BEGIN
				set @WHERE=@WHERE+@CC+convert(nvarchar,@NODEID)+' or '
				
			END         
         END        
		
		
		set @WHERE=@WHERE+' p.'+@CC+'0)'
		
		if(@CcID=2)
			set @OrderBY=@OrderBY+' p.AccountID desc,'
		ELSE if(@CcID=3)
			set @OrderBY=@OrderBY+' p.ProductID desc,'
        ELSE  if(@CcID>50000)
			set @OrderBY=@OrderBY+' p.CCNID'+convert(nvarchar,@CcID-50000)+' desc ,'  	
			
		set @I=@I+1
	END	
	
	select Conversion,b.Barcode,b.Barcode_Key from COM_UOM a WITH(NOLOCK)	
	left join INV_ProductBarcode b WITH(NOLOCK)	on a.UOMID=b.UnitID and b.ProductID=@ProductID
	where UOMID=@UOMID 
		
    set @SQL='select top 1 [WEF],P.[PurchaseRate],P.[SellingRate],P.[PurchaseRateA],P.[PurchaseRateB],P.[PurchaseRateC],P.[PurchaseRateD]
      ,P.[PurchaseRateE],P.[PurchaseRateF],P.[PurchaseRateG],P.[SellingRateA],P.[SellingRateB],P.[SellingRateC]
      ,P.[SellingRateD],P.[SellingRateE],P.[SellingRateF],P.[SellingRateG] from COM_CCPrices P WITH(NOLOCK) '+@JOIN+'
		where P.StatusID=1 AND (TillDate is null or TillDate=0 or TillDate>='+convert(nvarchar,convert(float,@DocDate))+') and WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE
		
   	if(@DocumentType in(11,7,9,24,33,10,8,12,38))        
		set @SQL=@SQL+' and PriceType in(0,1) '
	else
		set @SQL=@SQL+' and PriceType in(0,2) '

    set @SQL=@SQL+' and (P.UOMID=' +convert(nvarchar,@UOMID)+')   order by '+@OrderBY+'WEF Desc,P.UOMID Desc'          
	print @SQL
	insert into @RateTble
    exec(@SQL)  
   
   if(select count(PurchaseRate) from @RateTble)=0
   BEGIN
		select @baseID=a.UOMID from INV_Product a WITH(NOLOCK)	
		where a.ProductID=@ProductID


		set @SQL='select top 1 [WEF],P.[PurchaseRate],P.[SellingRate],P.[PurchaseRateA],P.[PurchaseRateB],P.[PurchaseRateC],P.[PurchaseRateD]
      ,P.[PurchaseRateE],P.[PurchaseRateF],P.[PurchaseRateG],P.[SellingRateA],P.[SellingRateB],P.[SellingRateC]
      ,P.[SellingRateD],P.[SellingRateE],P.[SellingRateF],P.[SellingRateG] from COM_CCPrices P WITH(NOLOCK) '+@JOIN+'
		where P.StatusID=1 AND (TillDate is null or TillDate=0 or TillDate>='+convert(nvarchar,convert(float,@DocDate))+') and WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE

		if(@DocumentType in(11,7,9,24,33,10,8,12))        
			set @SQL=@SQL+' and PriceType in(0,1) '
		else
			set @SQL=@SQL+' and PriceType in(0,2) '

		set @SQL=@SQL+' and (P.UOMID=' +convert(nvarchar,@baseID)+')   order by '+@OrderBY+'WEF Desc,P.UOMID Desc'          
		print @SQL
		insert into @RateTble
		exec(@SQL) 
		
		if(select count(PurchaseRate) from @RateTble)=0
		BEGIN
			select @baseID UOMID,[PurchaseRate],[SellingRate],[PurchaseRateA],[PurchaseRateB],[PurchaseRateC],[PurchaseRateD]
				,[PurchaseRateE],[PurchaseRateF],[PurchaseRateG],[SellingRateA],[SellingRateB],[SellingRateC]
				,[SellingRateD],[SellingRateE],[SellingRateF],[SellingRateG] from INV_Product P WITH(NOLOCK) 
			where ProductID=@ProductID
		END 
		ELSE
			select @baseID UOMID,* from @RateTble
   END
   ELSE
		select * from @RateTble
   
  
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
