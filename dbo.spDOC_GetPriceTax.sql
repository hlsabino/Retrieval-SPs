USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetPriceTax]
	@ProductID [int] = 0,
	@CCXML [nvarchar](max),
	@DocDate [datetime],
	@DocDetailsID [int] = 0,
	@ProfileID [nvarchar](max) = '',
	@UOMID [int] = 0,
	@CostCenterID [int] = 0,
	@DocQty [float],
	@CalcAvgrate [bit] = 0,
	@CalcQOH [bit] = 0,
	@CalcBalQOH [bit] = 0,
	@CalcHOLDQTY [bit] = 0,
	@CalcCommittedQTY [bit] = 0,
	@CalcRESERVEQTY [bit] = 0,
	@CalcTotRESERVEQTY [bit] = 0,
	@DocumentType [int],
	@ConsiderUnAppInHold [bit] = 0,
	@mode [int],
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON      

 DECLARE @SQL NVARCHAR(MAX),@XML XML,@WHERE NVARCHAR(MAX),@I INT,@CNT INT,@NODEID INT,@CcID INT,@BalQOH FLOAT,@table   nvarchar(200),@TestCaseExists BIT
    Declare @CC nvarchar(30),@CCWHERE NVARCHAR(MAX),@OrderBY NVARCHAR(MAX),@HOLDQTY FLOAT,@CommittedQTY FLOAT,@RESERVEQTY FLOAT,@stockID INT,@IsPromo BIT,@StCCID int
    DECLARE @AvgRate float,@LastPRate float,@PWLastPRate float,@iCNT INT,@ccCNTT INT,@QOH float,@PrefValue nvarchar(50),@NID INT,@dp float,@rp float,@AvgPrice float
    DECLARE @DrAccount INT,@CrAccount INT,@CrName NVARCHAR(200),@DrName NVARCHAR(200),@VendorQty float,@JOIN nvarchar(max),@tmpccid int
   DECLARE @SIZE INT,@Cols NVARCHAR(1000),@ColsList NVARCHAR(1000) ,@uBarcode nvarchar(100),@VBarcode nvarchar(100),@CurrencyID INT,@ptype int,@TotalReserve float
   DECLARE @UPDATESQL NVARCHAR(MAX),@CCJOINQUERY NVARCHAR(MAX),@LastPCost float ,@PWLastPCost float,@isGrp bit,@tblName NVARCHAR(200),@LastPRSNS Float
   SET @XML=@CCXML        
    
	if(@mode<>4)
	BEGIN
		--AVG RATE SP CALL
		IF @CalcAvgrate=1 or @CalcQOH=1 or @CalcBalQOH=1 or @CalcHOLDQTY=1 or @CalcCommittedQTY=1 or @CalcRESERVEQTY=1 or @CalcTotRESERVEQTY=1
			EXEC [spDOC_StockAvgValue] @ProductID,@CCXML,@DocDate,@DocQty,@CalcAvgrate,@DocDetailsID
				,@CalcQOH,@CalcBalQOH,@CalcHOLDQTY,@CalcCommittedQTY,@CalcRESERVEQTY,@CalcTotRESERVEQTY,@ConsiderUnAppInHold
				,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID
	  
		SELECT @AvgRate AvgRate,@BalQOH BalQOH,@QOH QOH ,@HOLDQTY HOLDQTY,@RESERVEQTY RESERVEQTY,@CommittedQTY CommittedQTY,@TotalReserve TotalReserve            
    END    
    
   declare @tblSplitcc table(CCIDS int)        
   DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId INT)        
   INSERT INTO @tblCC(CostCenterID,NodeId)        
   SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')        
   FROM @XML.nodes('/XML/Row') as Data(X)  
   

	declare @PTCC table(id 	int identity(1,1),CCID int,isgrp bit,tblname nvarchar(200))
	
	if(@mode in(1,3,4))
	BEGIN
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
				ELSE if(@CcID=3)
					set @CC=' ProductID ='	
				ELSE if(@CcID=12)
					set @CC=' CurrencyID ='		
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
							if(@CcID=50006)
									set @SQL='Select @NID=CategoryID from inv_product WITH(NOLOCK) 
									where ProductID='+convert(nvarchar,@ProductID)
							ELSE if(@CcID=50004)
									set @SQL='Select @NID=DepartmentID from inv_product WITH(NOLOCK) 
									where ProductID='+convert(nvarchar,@ProductID)
							ELSE		
									set @SQL='Select @NID='+REPLACE(@CC,'=','')+' from com_CCCCData WITH(NOLOCK) 
									where CostcenterID=3 and NOdeID='+convert(nvarchar,@ProductID)
								
							EXEC sp_executesql @SQL, N'@NID INT OUTPUT', @NID OUTPUT  
							if( @NID is null)
								set @NID=0  
							 insert into @tblCC(CostCenterID,NodeId)values(@CcID,@NID)
						END
						ELSE if(@ProfileID IS NOT NULL AND @ProfileID<>'')
						BEGIN
							SET @XML=@ProfileID
							
							SET @ProfileID='0'
							SELECT TOP 1 @ProfileID=X.value('@ProfileID','INT')
							from @XML.nodes('/DimensionDefProfile/Row') as Data(X) 
							WHERE (X.value('@TillDate','NVARCHAR') is null or X.value('@TillDate','NVARCHAR')='' or X.value('@TillDate','DateTime')>=@DocDate) and (X.value('@WEFDate','NVARCHAR') is null or X.value('@WEFDate','NVARCHAR')='' or X.value('@WEFDate','DateTime')<=@DocDate)
							
							IF @ProfileID IS NULL
								SET @ProfileID='0'
							
							IF 	ISNUMERIC(@ProfileID)=1 AND @ProfileID > '0'
							BEGIN
								 SelecT @XML=defxml from COM_DimensionMappings WITH(NOLOCK)
								 where ProfileID=@ProfileID
								 
								 if exists(select X.value('@cols','int')  
								 FROM @XML.nodes('/XML/Row') as Data(X)	
								 where X.value('@IsBase','int')=0 and X.value('@cols','int')=@CcID)
								 BEGIN
									
									declare @dtcols table(id int identity(1,1),ccid int)
									insert into @dtcols
									SELECT X.value('@cols','int')
									FROM @XML.nodes('/XML/Row') as Data(X)									
									join adm_costcenterdef c with(nolock) on c.ColumnCostCenterID=X.value('@cols','int')
									join adm_costcenterdef b with(nolock) on c.LocalReference=b.CostCenterColID
									left join @tblCC a on X.value('@cols','int')=a.CostCenterID	
									where X.value('@IsBase','int')=1 and X.value('@cols','int')>50000
									and c.CostCenterID=@CostCenterID and b.CostCenterID=@CostCenterID and b.SysColumnName='productid'
									and a.NodeId is null 
									
									set @iCNT=0
									select @ccCNTT=COUNT(id) from @dtcols
									while(@iCNT<@ccCNTT)        
									begin  
										set @iCNT=@iCNT+1
										
										select @tmpccid=ccid from @dtcols where id=@iCNT
										
										if(@tmpccid=50006)
												set @SQL='Select @NID=CategoryID from inv_product WITH(NOLOCK) 
												where ProductID='+convert(nvarchar,@ProductID)
										ELSE if(@tmpccid=50004)
												set @SQL='Select @NID=DepartmentID from inv_product WITH(NOLOCK) 
												where ProductID='+convert(nvarchar,@ProductID)
										ELSE		
												set @SQL='Select @NID=CCNID'+CONVERT(nvarchar,(@tmpccid-50000))+' from com_CCCCData WITH(NOLOCK) 
												where CostcenterID=3 and NOdeID='+convert(nvarchar,@ProductID)
											
										EXEC sp_executesql @SQL, N'@NID INT OUTPUT', @NID OUTPUT  
										if( @NID is null)
											set @NID=0  
										 insert into @tblCC(CostCenterID,NodeId)values(@tmpccid,@NID)
										
									END
									
									 
									 set @CCWHERE=''
									 
									SELECT @CCWHERE=@CCWHERE+case when X.value('@cols','int')=2 THEN ' and AccountID='+isnull(CONVERT(nvarchar,NodeId),'0')
									 when X.value('@cols','int')=3 THEN ' and ProductID='+isnull(CONVERT(nvarchar,@ProductID),'0')
									 ELSE  ' and CCNID'+convert(nvarchar,X.value('@cols','int')-50000)+'='+CONVERT(nvarchar,NodeId) END
									 FROM @XML.nodes('/XML/Row') as Data(X)
									 left join @tblCC a on X.value('@cols','int')=a.CostCenterID
									 where X.value('@IsBase','int')=1
									 
									if(@CCWHERE is not null and @CCWHERE<>'')
									BEGIN				
										set @SQL='Select @NID='+REPLACE(@CC,'=','')+' from COM_DimensionMappings WITH(NOLOCK) 
											where ProfileID='+convert(nvarchar,@ProfileID)+@CCWHERE
										set @NID=0
										EXEC sp_executesql @SQL, N'@NID INT OUTPUT', @NID OUTPUT  
										if( @NID is null)
											set @NID=0  
										 insert into @tblCC(CostCenterID,NodeId)values(@CcID,@NID)
									END	
								 END
							 END
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
		
			set @SQL='select top 1 convert(datetime,TillDate) TillDate,convert(datetime,[WEF]) WEF,ProfileName,P.[PurchaseRate],P.[PurchaseRateA],P.[PurchaseRateB],P.[PurchaseRateC],P.[PurchaseRateD]
			  ,P.[PurchaseRateE],P.[PurchaseRateF],P.[PurchaseRateG],P.[SellingRate],P.[SellingRateA],P.[SellingRateB],P.[SellingRateC]
			  ,P.[SellingRateD],P.[SellingRateE],P.[SellingRateF],P.[SellingRateG] from COM_CCPrices P WITH(NOLOCK) '+@JOIN+'
				where p.StatusID=1 AND (TillDate is null or TillDate=0 or TillDate>='+convert(nvarchar,convert(float,@DocDate))+') and WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE
				
   			if(@DocumentType in(11,7,9,24,33,10,8,12,38))        
				set @SQL=@SQL+' and PriceType in(0,1) '
			else
				set @SQL=@SQL+' and PriceType in(0,2) '

			set @SQL=@SQL+' and (P.UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' or P.UOMID=0)   order by '+@OrderBY+'WEF Desc,P.UOMID Desc'          
		print @SQL
		   exec(@SQL)  
   END
   else
		select 1 where 1<>1
		
	if(@mode in(2,3,4))
	BEGIN	
		   delete from @PTCC
		   insert into @PTCC
			SELECT [CostCenterID],[IsGroupExists],b.TableName
			FROM COM_CCPriceTaxCCDefn a WITH(NOLOCK)
			join ADM_Features b WITH(NOLOCK) on a.[CostCenterID]=b.FeatureID
			where [DefType]=2 and ProfileID=0
		    
			Select @I=MIN(id),@CNT=Max(id) from @PTCC
			set @JOIN=''
			set @WHERE=''
			while(@I<=@CNT)        
			begin 
				set @isGrp=0   
				 select @CcID=CCID,@isGrp=isgrp,@tblName=tblname from @PTCC where id=@I
		        
				if(@CcID=2)
					set @CC=' AccountID='
				ELSE if(@CcID=3)
					set @CC=' ProductID='	
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
							if(@CcID=50006)
									set @SQL='Select @NID=CategoryID from inv_product WITH(NOLOCK) 
									where ProductID='+convert(nvarchar,@ProductID)
							ELSE if(@CcID=50004)
									set @SQL='Select @NID=DepartmentID from inv_product WITH(NOLOCK) 
									where ProductID='+convert(nvarchar,@ProductID)
							ELSE		
									set @SQL='Select @NID='+REPLACE(@CC,'=','')+' from com_CCCCData WITH(NOLOCK) 
									where CostcenterID=3 and NOdeID='+convert(nvarchar,@ProductID)
							EXEC sp_executesql @SQL, N'@NID INT OUTPUT', @NID OUTPUT 
							if( @NID is null)
								set @NID=0   
							--if(@NID>1)
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
										left join '+@tblName+' CJ'+CONVERT(nvarchar,@I)+' with(nolock) on CJ'+CONVERT(nvarchar,@I)+'.lft between CC'+CONVERT(nvarchar,@I)+'.lft and CC'+CONVERT(nvarchar,@I)+'.rgt'				
							set @WHERE=@WHERE+'CJ'+CONVERT(nvarchar,@I)+'.'+@CC+convert(nvarchar,@NODEID)+' or '
						END
						ELSE
						BEGIN
							set @JOIN=@JOIN+' left join '+@tblName+' CC'+CONVERT(nvarchar,@I)+' with(nolock) on P.'+@CC+'CC'+CONVERT(nvarchar,@I)+'.NodeID
										left join '+@tblName+' CJ'+CONVERT(nvarchar,@I)+' with(nolock) on CJ'+CONVERT(nvarchar,@I)+'.lft between CC'+CONVERT(nvarchar,@I)+'.lft and CC'+CONVERT(nvarchar,@I)+'.rgt'				
							set @WHERE=@WHERE+'CJ'+CONVERT(nvarchar,@I)+'.NODEID='+convert(nvarchar,@NODEID)+' or '
						END
					END
					ELSE
					BEGIN
						set @WHERE=@WHERE+@CC+convert(nvarchar,@NODEID)+' or '
						
					END         
				 END        
					
				set @WHERE=@WHERE+' p.'+@CC+'0)'	
					
				set @I=@I+1
			END	
		   
		           
		   set @SQL='SELECT distinct C.SysColumnName,P.Value,P.ColID,convert(datetime,TillDate) TillDate,convert(datetime,[WEF]) WEF,ProfileName,[Message] FROM COM_CCTaxes P with(nolock)  '+@JOIN+'      
			   INNER JOIN ADM_CostCenterDef C WITH(NOLOCK) on P.ColID=C.CostCenterColID        
			   where p.StatusID=1 AND (TillDate is null or TillDate=0 or TillDate>='+convert(nvarchar,convert(float,@DocDate))+') and DOCID ='+convert(nvarchar,@CostCenterID)+'   and  WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE
		   set @SQL=@SQL+' UNION
			   SELECT distinct ''Message'',P.Value,P.ColID,convert(datetime,TillDate) TillDate,convert(datetime,[WEF]) WEF,ProfileName,[Message] FROM COM_CCTaxes P with(nolock)  '+@JOIN+'           
			   where p.StatusID=1 AND P.ColID=-1 AND (TillDate is null or TillDate=0 or TillDate>='+convert(nvarchar,convert(float,@DocDate))+') and DOCID ='+convert(nvarchar,@CostCenterID)+'   and  WEF<='+convert(nvarchar,convert(float,@DocDate))+@WHERE
		   set @SQL=@SQL+' order by WEF Desc'         
		   print @SQL 
		   
		   exec(@SQL) 
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
