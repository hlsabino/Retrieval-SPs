USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetPrices]
	@ProductIDs [nvarchar](max),
	@CCXML [nvarchar](max),
	@DocDate [datetime],
	@CostCenterID [bigint] = 0,
	@DocumentType [int],
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON      

 DECLARE @SQL NVARCHAR(MAX),@XML XML,@WHERE NVARCHAR(MAX),@I INT,@CNT INT,@NODEID BIGINT,@CcID BIGINT,@BalQOH FLOAT,@table   nvarchar(200),@TestCaseExists BIT
    Declare @CC nvarchar(30),@CCWHERE NVARCHAR(MAX),@OrderBY NVARCHAR(MAX),@JOIN nvarchar(max),@isGrp bit,@tblName NVARCHAR(200)
     
   set @XML=@CCXML
   
   declare @tblSplitcc table(CCIDS int)        
   DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId BIGINT)        
   INSERT INTO @tblCC(CostCenterID,NodeId)        
   SELECT X.value('@CostCenterID','int'),X.value('@NODEID','BIGINT')        
   FROM @XML.nodes('/XML/Row') as Data(X)  
   

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
				set @isGrp=0
				 select @CcID=CCID,@isGrp=isgrp,@tblName=tblname from @PTCC where id=@I
		       
				if(@CcID=2)
					set @CC=' AccountID ='					
				ELSE if(@CcID=12)
					set @CC=' CurrencyID ='		
				ELSE  if(@CcID>50000)
					set @CC='CCNID'+convert(nvarchar,@CcID-50000)+'='  
				ELSE
				BEGIN
					set @I=@I+1
					Continue;	
				END
				
				 set @WHERE=@WHERE+' and (' 
				
				 if exists(select CostCenterID from @tblCC where CostCenterID=@CcID) 
				 BEGIN
						
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
					ELSE if(@CcID=12)	 		
						set @WHERE=@WHERE+' p.CurrencyID='+convert(nvarchar,@NODEID)+' or '
					ELSE
					BEGIN
						set @WHERE=@WHERE+@CC+convert(nvarchar,@NODEID)+' or '
					END 
					
					if(@isGrp=1 and (@CcID=2 or @CcID>50000))
						set @OrderBY=@OrderBY+' CC'+CONVERT(nvarchar,@I)+'.lft desc,'        
				 END        
				
				
				set @WHERE=@WHERE+' p.'+@CC+'0)'
				
						
				if(@CcID=2)
					set @OrderBY=@OrderBY+' p.AccountID desc,'
				ELSE if(@CcID=3)
					set @OrderBY=@OrderBY+' p.ProductID desc,'
				ELSE if(@CcID=12)
					set @OrderBY=@OrderBY+' p.CurrencyID desc,'	
				ELSE  if(@CcID>50000)
					set @OrderBY=@OrderBY+' p.CCNID'+convert(nvarchar,@CcID-50000)+' desc ,'  	
					
				set @I=@I+1
			END	
		
			set @SQL='select row_number() over( order by '+@OrderBY+'WEF Desc,P.UOMID Desc) RowID, p.ProductID,convert(datetime,TillDate) TillDate,convert(datetime,[WEF]) WEF,ProfileName,P.[PurchaseRate],P.[PurchaseRateA],P.[PurchaseRateB],P.[PurchaseRateC],P.[PurchaseRateD]
			  ,P.[PurchaseRateE],P.[PurchaseRateF],P.[PurchaseRateG],P.[SellingRate],P.[SellingRateA],P.[SellingRateB],P.[SellingRateC]
			  ,P.[SellingRateD],P.[SellingRateE],P.[SellingRateF],P.[SellingRateG] from COM_CCPrices P WITH(NOLOCK) '+@JOIN+'
				where p.ProductID in('+@ProductIDs+') and p.StatusID=1 AND (TillDate is null or TillDate=0 or TillDate>='+convert(nvarchar,convert(float,@DocDate))+') and WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE
				
   			set @SQL=@SQL+' and PriceType in(0,1) '
			

			set @SQL=@SQL+' order by '+@OrderBY+'WEF Desc,P.UOMID Desc'          
		print @SQL
		   exec(@SQL)  
 
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
