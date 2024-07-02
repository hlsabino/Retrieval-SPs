USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetHoldQty]
	@ProductID [bigint] = 0,
	@CCXML [nvarchar](max),
	@DocDetailsID [bigint] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON      
      
           declare @SQL nvarchar(max),@WHERE nvarchar(max),@BalQOH float,@XML xml,@PrefValue nvarchar(100),@NID bigint,@ExecQTY float
           declare @Bal float,@freestock float,@HOLDQTY float,@RESERVEQTY float,@TotalHoldQty Float,@stat nvarchar(50)
            DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID bigint,NodeId BIGINT)        

           
		 set @XML=@CCXML        		         
		 
		 INSERT INTO @tblCC(CostCenterID,NodeId)        
		 SELECT X.value('@CostCenterID','int'),X.value('@NODEID','BIGINT')        
		 FROM @XML.nodes('/XML/Row') as Data(X)        
		 
	 	 if exists(select Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold' and value='true')
				set @stat=' in(371,441,369) '
			else	
				set @stat='=369 '          
		 	         
		 set @WHERE=''        
		 	select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='EnableLocationWise'        
		            
			if(@PrefValue='True' and exists (select NodeId from @tblCC where CostCenterID=50002))        
			begin        
		  set @PrefValue=''      
		  select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Location Stock'        
		  if(@PrefValue='True')      
		  begin      
			 select @NID=NodeId from @tblCC where CostCenterID=50002        
			 set @WHERE =' dcCCNID2='+CONVERT(nvarchar,@NID)        
		  end       		 
			end        
		             
			select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='EnableDivisionWise'        
		            
			if(@PrefValue='True' and exists (select NodeId from @tblCC where CostCenterID=50001))        
			begin        
			 select @NID=NodeId from @tblCC where CostCenterID=50001        
			 set @PrefValue=''      
			 select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Division Stock'        
			  if(@PrefValue='True')      
			  begin      
			   if(@WHERE<>'')        
				set @WHERE =@WHERE+' and '        
				set @WHERE =@WHERE+' dcCCNID1='+CONVERT(nvarchar,@NID)         
			  end       		         
			end        
		          
		          
			set @PrefValue=''      
			select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise stock'        
		          
			if(@PrefValue is not null and @PrefValue<>'' and convert(bigint,@PrefValue)>0  and exists (select NodeId from @tblCC where CostCenterID=convert(bigint,@PrefValue)))        
			begin        
			select @NID=NodeId from @tblCC where CostCenterID=convert(bigint,@PrefValue)        
			set @PrefValue=convert(bigint,@PrefValue)-50000        
			if(@WHERE<>'')        
			set @WHERE =@WHERE +' and '        
			set @WHERE =@WHERE+' dcCCNID'+@PrefValue+'='+CONVERT(nvarchar,@NID)        
			end        
		       
			if(@WHERE<>'')        
		   set @WHERE =' and '+@WHERE    
   
			
		           
		  EXEC sp_executesql @SQL, N'@BalQOH float OUTPUT', @BalQOH OUTPUT   
			
			
			
			 set @SQL='declare @tab table(DetID bigint) 
						declare @tabids table(id bigint identity(1,1),DetID bigint) 

						declare @DocDetailsID nvarchar(max) ,@sql nvarchar(max) ,@i int,@cnt int,@ID bigint
						set @DocDetailsID='''+convert(nvarchar,@DocDetailsID)+'''

						insert into @tab(DetID)values('+convert(nvarchar,@DocDetailsID)+')

						set @sql=''SELECT InvDocDetailsID FROM INV_DocDetails with(nolock)        
							WHERE LinkedInvDocDetailsID in(''+@DocDetailsID+'')''

						insert into @tabids
						exec(@sql)

						while exists (select DetID from @tabids)      
						begin       	       
							insert into @tab(DetID)
							select DetID from @tabids	
							
							set @DocDetailsID=''''
							select @i=min(id),@cnt=max(id) from @tabids
							set @i=@i-1
							while(@i<@cnt)
							begin
								set @i=@i+1
								select @ID=DetID from @tabids where id=@i
								set @DocDetailsID=@DocDetailsID+convert(nvarchar,@ID)
								if(@i<>@cnt)
									set @DocDetailsID=@DocDetailsID+'',''
							end
							delete from @tabids
							
							set @sql=''SELECT InvDocDetailsID FROM INV_DocDetails with(nolock)         
							WHERE VoucherType<>1 and  LinkedInvDocDetailsID in(''+@DocDetailsID+'')''
							insert into @tabids
							exec(@sql)
						end      

				set @BalQOH=(SELECT isnull(sum(Quantity*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)        
		  INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
		  WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND IsQtyIgnored=0 '
		  set @SQL=@SQL+@WHERE+' and (VoucherType=1 or VoucherType=-1) and D.INVDocDetailsID not in(select DetID from @tab) )'         
		       
		       		set @SQL=@SQL+' set @ExecQTY=(SELECT isnull(sum(Quantity*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)        
		  INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
		  WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND IsQtyIgnored=0 '
		  set @SQL=@SQL+@WHERE+' and (VoucherType=1 or VoucherType=-1) and D.INVDocDetailsID in(select DetID from @tab) )'         
		   
	  EXEC sp_executesql @SQL, N'@BalQOH float OUTPUT,@ExecQTY float OUTPUT',@BalQOH OUTPUT,@ExecQTY OUTPUT   
                    
			set @SQL=' set @Bal=(SELECT isnull(sum(Quantity*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)        
		  INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
		  WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND IsQtyIgnored=0 '
		  set @SQL=@SQL+@WHERE+' and (VoucherType=1 or VoucherType=-1))'         
		       
		  EXEC sp_executesql @SQL, N'@Bal float OUTPUT',@Bal OUTPUT
		  
		  set @PrefValue =''
		  select @PrefValue=Value from Adm_globalPreferences WITH(NOLOCK) where Name='HoldResCancelledDocs'    
				
		   set @SQL='set @TotalHoldQty=(  select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from   
		 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
		 if(@PrefValue<>'')
			set @SQL=@SQL+' or l.Costcenterid in('+@PrefValue+')'
			
		 set @SQL=@SQL+') then l.Quantity else l.ReserveQuantity end),0) release  
		 FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID   
		 left join INV_DocDetails l  WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
		 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1  and D.StatusID'+@stat+' and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 '
		 set @SQL=@SQL+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'       
          
		EXEC sp_executesql @SQL, N'@TotalHoldQty float OUTPUT', @TotalHoldQty OUTPUT   
    
		  set @HOLDQTY=@TotalHoldQty  
		   
		    
		   set @SQL='set @TotalHoldQty=(  select  isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from   
		 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
		 if(@PrefValue<>'')
			set @SQL=@SQL+' or l.Costcenterid in('+@PrefValue+')'
			
		 set @SQL=@SQL+') then l.Quantity else l.ReserveQuantity end),0) release  
		 FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID   
		 left join INV_DocDetails l  WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
		 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1  and D.StatusID'+@stat+' and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 '
		 set @SQL=@SQL+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'       
		   
		  EXEC sp_executesql @SQL, N'@TotalHoldQty float OUTPUT', @TotalHoldQty OUTPUT   
		  
		  set @RESERVEQTY=@TotalHoldQty     
             
	                    
		  SELECT HoldQuantity,@BalQOH BalQOH,@ExecQTY ExecQTY,@Bal Bal,@HOLDQTY Hold,@RESERVEQTY Res FROM INV_DocDetails WITH(NOLOCK)      
		  WHERE INVDocDetailsID=@DocDetailsID
			   
	 
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
