USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductwiseBins]
	@PRODUCTID [int],
	@DocId [int],
	@DocDate [datetime],
	@VoucherType [int],
	@DimCCID [int],
	@DimNodeID [int],
	@FilterCCID [int],
	@FilterNodeID [int],
	@BoeIds [nvarchar](max),
	@batchID [int],
	@batchRefInvID [int],
	@linkedIDs [nvarchar](max),
	@CostCenterID [int],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY          
SET NOCOUNT ON;        
            
	  DECLARE @SQL NVARCHAR(MAX) ,@CCID int,@TableName nvarchar(100),@Consolidate bit,@isProdwise bit,@isVolBased bit,@vol float,@binruleid int,@i int,@cnt int
	  declare @tab table(id int identity(1,1),ruleid int)
	  declare @Len float,@wid float,@ht float,@inclWaistage bit,@waist float,@Detailids nvarchar(max),@DefaultBinSort int,@ExcldHold bit,@cancelleddocs nvarchar(max)
	 
	 set @Detailids=''
	 if(@DocId>0)
		 select @Detailids=@Detailids+CONVERT(nvarchar,InvDocDetailsID)+',' from INV_DocDetails with(nolock)
		 where DocID=@DocId and ProductID=@PRODUCTID
	
	 if(LEN(@Detailids)>1)
		set @Detailids=SUBSTRING(@Detailids,0,len(@Detailids))
	   
	   set @vol=0	
       select @CCID=convert(INT,Value) from [COM_CostCenterPreferences] with(nolock)
       where Name='BinsDimension' and costcenterid=3 and isnumeric(Value)=1
      
       select @DefaultBinSort=convert(int,Value) from [COM_CostCenterPreferences] with(nolock)
       where Name='DefaultBinSort' and costcenterid=3 and isnumeric(Value)=1
 
       		
	   select @vol=isnull(Volume,0),@Len=Length,@wid=Width,@ht=Height,@waist=isnull(Wastage,0)
	   ,@binruleid=case when @VoucherType=1 then isnull(PurchaseBinRule,0) else isnull(SalesBinRule,0) end
	   from INV_Product WITH(NOLOCK) where ProductID=@PRODUCTID
	   
       if exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='bincapacityonVolume' and costcenterid=3 and Value='true')
			set @isVolBased=1
		else
			set @isVolBased=0
       
       if exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='Waistage' and costcenterid=3 and Value='true')
			set @inclWaistage=1
		else
			set @inclWaistage=0


	  insert into @tab
	  select RuleID from INV_ProductBinRules with(nolock)
	  where ProfileID=@binruleid
	  	
		select @cnt=COUNT(id) from @tab
		set @i=0
		
	   if exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='ProductWiseBins' and costcenterid=3 and Value='true')
			set @isProdwise=1
		else
			set @isProdwise=0
			
	   if exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='ConsolidatedBins' and costcenterid=3 and Value='true')
			set @Consolidate=1
		else
			set @Consolidate=0
		
		if (@VoucherType=-1 and exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='ExcludeHoldBins' and costcenterid=3 and Value='true'))
		BEGIN
			select @cancelleddocs=Value from adm_globalPreferences WITH(NOLOCK) where  Name='HoldResCancelledDocs' 
			if(@cancelleddocs like '%'+convert(nvarchar(max),@CostCenterID)+'%')
				set @ExcldHold=0
			else
				set @ExcldHold=1
		END	
		
	   select @TableName=TableName from adm_features with(nolock) where FeatureID = @CCID
		
		if(@Consolidate=0 and @VoucherType=-1)
		BEGIN
					
			 SET @SQL='select distinct *,1 as a'
			 
			 if exists(select * from @tab where ruleid=5)
				SET @SQL=@SQL+',case when isnumeric(replace(replace(name,''.'',''''),''-'',''''))=1 then replace(replace(name,''.'',''''),''-'','''') else cast(0 as INT) end as NName '
			 else if(@cnt=0 and @DefaultBinSort=2)
				SET @SQL=@SQL+',case when isnumeric(replace(replace(Code,''.'',''''),''-'',''''))=1 then replace(replace(Code,''.'',''''),''-'','''') else cast(0 as INT) end as NName '
			 else if(@cnt=0 and @DefaultBinSort=3)
				SET @SQL=@SQL+',case when isnumeric(replace(replace(name,''.'',''''),''-'',''''))=1 then replace(replace(name,''.'',''''),''-'','''') else cast(0 as INT) end as NName '
			
			 SET @SQL=@SQL+' from ( '
			
			SET @SQL=@SQL+'select a.lft Serialno,a.NodeID,a.Name,a.Code,0 Capacity,a.ccAlpha50,'+convert(nvarchar(max),@vol)+'  as Vol,'+convert(nvarchar(max),@waist)+'  as waist,
			d.DocDate,d.Voucherno,bn.invdocdetailsid,bn.remarks,
			bn.Quantity'
			
			if(@ExcldHold=1)
			BEGIN
				if(@Detailids<>'')
					SET @SQL=@SQL+' -isnull(sum(case when lbd.invdocdetailsid is null then 0 else bd.Quantity end),0)'
				else
					SET @SQL=@SQL+'-isnull(sum(bd.Quantity),0)'
					
				SET @SQL=@SQL+' -isnull(sum(holdJoin.Qty),0)'
			END	
			else
				SET @SQL=@SQL+'-isnull(sum(bd.Quantity),0)'
			
			
			SET @SQL=@SQL+' BalQty
			from INV_BinDetails bn with(nolock) 
			join inv_docdetails d with(nolock) on d.invdocdetailsid=bn.invdocdetailsid
			join '+@TableName+' a with(nolock) on a.NodeID=bn.BINID
			JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = a.NodeID and c.[CostCenterID]='+CONVERT(NVARCHAR(50),@CCID)+'
			left join INV_BinDetails bd with(nolock) on bn.invdocdetailsid=bd.RefInvDocDetailsID and bn.BinID=bd.BinID and bd.isqtyignored=0 '
			
			if(@Detailids<>'')
					set @SQL=@SQL+' and bd.InvDocDetailsID not in ('+@Detailids+') '
			if(@ExcldHold=1 and @Detailids<>'')
				set @SQL=@SQL+' left join inv_docdetails lbd with(nolock) on bd.invdocdetailsid=lbd.invdocdetailsid  and lbd.linkedInvDocDetailsID not in ('+@Detailids+') '
				
			if(@ExcldHold=1)
			BEGIN
					select @cancelleddocs=Value from adm_globalPreferences WITH(NOLOCK) where  Name='HoldResCancelledDocs'    
			
					set @SQL=@SQL+' left join (select BinID,RefInvDocDetailsID,isnull(sum(HoldQuantity-rel),0) Qty from (select BinID,RefInvDocDetailsID,HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT bn.BinID,bn.Quantity HoldQuantity,bn.RefInvDocDetailsID,isnull(sum(lbn.Quantity),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) 
					 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 LEFT JOIN INV_BinDetails bn with(nolock) ON bn.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID and '
					 
					 if(@cancelleddocs is not null and @cancelleddocs<>'')
						set @SQL=@SQL+' (l.isqtyignored=0 or l.costcenterid in ('+@cancelleddocs+'))'
					else
						set @SQL=@SQL+' l.isqtyignored=0'
					
					set @SQL=@SQL+' left JOIN INV_BinDetails lbn with(nolock) ON lbn.InvDocDetailsID=l.InvDocDetailsID and bn.BinID=lbn.BinID
					 WHERE d.ProductID='+CONVERT(nvarchar,@PRODUCTID)+' and ((D.HoldQuantity is not null and D.HoldQuantity>0) or (D.ReserveQuantity is not null and D.ReserveQuantity>0))  AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1  '
					 
					  if (@linkedIDs is not null and @linkedIDs<>'')
                        set @SQL=@SQL+' and d.docid not in (select DOCID from INV_DocDetails temp WITH(NOLOCK) where InvDocDetailsID in(' + @linkedIDs+ ')) '

					 if(@Detailids<>'')
						set @SQL=@SQL+' and D.InvDocDetailsID not in ('+@Detailids+') '	

					set @SQL=@SQL+' group by bn.BinID,D.InvDocDetailsID,bn.Quantity,bn.RefInvDocDetailsID) as t)as temp 
					group by BinID,RefInvDocDetailsID) as holdJoin on bn.invdocdetailsid=holdJoin.RefInvDocDetailsID and bn.BinID=holdJoin.BinID  '
			END		
			
			set @SQL=@SQL+' where d.StatusID<>376 and d.productid='+CONVERT(nvarchar(max),@PRODUCTID)
			set @SQL=@SQL+' and bn.IsQtyIgnored=0 and d.vouchertype=1 and d.DocDate<='+CONVERT(NVARCHAR(50),CONVERT(float,@DocDate))
			
			if(@BoeIds<>'')
					set @SQL=@SQL+' and d.InvDocDetailsID in ('+@BoeIds+') '
		
			if(@batchID is not null and @batchID>0)
					set @SQL=@SQL+' and d.BatchID ='+CONVERT(nvarchar,@batchID)
			
			if(@DimNodeID is not null and @DimNodeID>0)
					set @SQL=@SQL+' and ccnid'+(CONVERT(NVARCHAR(50),(@DimCCID-50000)))+'='+CONVERT(nvarchar,@DimNodeID)	
			
			if(@FilterNodeID is not null and @FilterNodeID>0)
					set @SQL=@SQL+' and ccnid'+(CONVERT(NVARCHAR(50),(@FilterCCID-50000)))+'='+CONVERT(nvarchar,@FilterNodeID)

			SET @SQL=@SQL+' group by bn.invdocdetailsid,d.Voucherno,d.DocDate,bn.Quantity,bn.remarks,
			a.lft,a.NodeID,a.Name,a.Code,a.ccAlpha50) as t'
			if(@linkedIDs is not null and @linkedIDs<>'' and @cancelleddocs like '%'+convert(nvarchar(max),@CostCenterID)+'%')
			BEGIN
				set @SQL=@SQL+' join INV_BinDetails bd with(nolock) on t.invdocdetailsid=bd.RefInvDocDetailsID and t.NodeID=bd.BinID 
				where bd.invdocdetailsid in('+@linkedIDs+') '
			END
			else
				set @SQL=@SQL+' where BalQty>0'
			SET @SQL=@SQL+' order by a '
			
			while(@i<@cnt)
			BEGIN
				set @i=@i+1
				select @binruleid=ruleid from @tab where id=@i
				
				if(@binruleid=4)
					SET @SQL=@SQL+',DocDate,Voucherno'
				if(@binruleid=5)
					SET @SQL=@SQL+',NName'
				if(@binruleid=6)
					SET @SQL=@SQL+',BalQty'
				if(@binruleid=7 and not exists(select ruleid from @tab where ruleid=6))
					SET @SQL=@SQL+',BalQty desc'		
			END
			
			if(@cnt=0 and @DefaultBinSort in(2,3))
				SET @SQL=@SQL+',NName '		
			else if(@cnt=0)
				SET @SQL=@SQL+',Serialno '		
			
			
		END
		ELSE 
		BEGIN
			 
			 SET @SQL='select distinct  *,1 as a'
			 
			 if exists(select * from @tab where ruleid in(2,3,5))
				SET @SQL=@SQL+',case when isnumeric(replace(replace(name,''.'',''''),''-'',''''))=1 then replace(replace(name,''.'',''''),''-'','''') else cast(0 as INT) end as NName '
			 else if(@cnt=0 and @DefaultBinSort=2)
				SET @SQL=@SQL+',case when isnumeric(replace(replace(Code,''.'',''''),''-'',''''))=1 then replace(replace(Code,''.'',''''),''-'','''') else cast(0 as INT) end as NName '
			 else if(@cnt=0 and @DefaultBinSort=3)
				SET @SQL=@SQL+',case when isnumeric(replace(replace(name,''.'',''''),''-'',''''))=1 then replace(replace(name,''.'',''''),''-'','''') else cast(0 as INT) end as NName '

			if exists(select * from @tab where ruleid =1)
			BEGIN
				if(@isVolBased=1)
				BEGIN
					if(@inclWaistage=1)
						SET @SQL=@SQL+',case when BalQty>0 and isnumeric(ccAlpha50)=1 then convert(INT,ccAlpha50)-BalQty-Waistage else 0 end as Used '
					ELSE	
						SET @SQL=@SQL+',case when BalQty>0 and isnumeric(ccAlpha50)=1 then convert(INT,ccAlpha50)-BalQty else 0 end as Used '
				END	
				ELSE	
					SET @SQL=@SQL+',case when BalQty>0 and Capacity is not null then Capacity-BalQty else 0 end as Used '
			END
			 SET @SQL=@SQL+' from ( '
			 
			
			if(@isProdwise=1) 		
				SET @SQL=@SQL+'select b.Serialno,a.NodeID,a.Name,a.Code,b.Capacity,a.ccAlpha50,'+convert(nvarchar(max),@vol)+' as Vol,'+convert(nvarchar(max),@waist)+' as waist,'
			ELSE
				SET @SQL=@SQL+'select a.lft Serialno,a.NodeID,a.Name,a.Code,0 Capacity,a.ccAlpha50,'+convert(nvarchar(max),@vol)+' as Vol,'+convert(nvarchar(max),@waist)+' as waist,'	
			
			if(@isVolBased=1 and @VoucherType=1)
			BEGIN
				SET @SQL=@SQL+' isnull((select sum(bn.Quantity*case when d.vouchertype=1 and d.statusid in(371,441) then 0 else  bn.VoucherType end*isnull(p.Volume,0)) from INV_BinDetails bn with(nolock)
				join inv_docdetails d with(nolock) on d.invdocdetailsid=bn.invdocdetailsid
				join INV_Product p with(nolock) on d.ProductID=p.ProductID 
				where d.DocDate<='+CONVERT(NVARCHAR(50),CONVERT(float,@DocDate))
				
				if(@Detailids<>'')
					set @SQL=@SQL+' and bn.InvDocDetailsID not in ('+@Detailids+') '
					
				set @SQL=@SQL+'  and d.StatusID in(369,371,441)  and bn.BinID=a.NodeID),0) as BalQty'
				
				
				if(@inclWaistage=1)
				BEGIN
					SET @SQL=@SQL+', isnull((select sum(bn.Quantity*case when d.vouchertype=1 and d.statusid in(371,441) then 0 else  bn.VoucherType end*isnull(p.Wastage,0)) from INV_BinDetails bn with(nolock)
					join inv_docdetails d with(nolock) on d.invdocdetailsid=bn.invdocdetailsid
					join INV_Product p with(nolock) on d.ProductID=p.ProductID 
					where d.DocDate<='+CONVERT(NVARCHAR(50),CONVERT(float,@DocDate))
					
					if(@Detailids<>'')
						set @SQL=@SQL+' and bn.InvDocDetailsID not in ('+@Detailids+') '	
						
						set @SQL=@SQL+' and d.StatusID in(369,371,441)   and bn.BinID=a.NodeID),0) as Waistage'
				END

			END
			ELSE
			BEGIN
			
				if(@linkedIDs is not null and @linkedIDs<>'' and @cancelleddocs like '%'+convert(nvarchar(max),@CostCenterID)+'%')
				BEGIN
					SET @SQL=@SQL+'isnull((select sum(bn.Quantity) from INV_BinDetails bn with(nolock) 
					 left join inv_docdetails d with(nolock) on d.Linkedinvdocdetailsid=bn.invdocdetailsid '
					 
					 if(@Detailids<>'')
						set @SQL=@SQL+' and bn.InvDocDetailsID not in ('+@Detailids+') '	

					 set @SQL=@SQL+'left join INV_BinDetails LBN on d.invdocdetailsid=lbn.invdocdetailsid and bn.BinID=LBN.BinID  
					 
					  where  bn.invdocdetailsid in('+@linkedIDs+') '
				
					set @SQL=@SQL+'   and bn.BinID=a.NodeID),0) as BalQty'
				
				END
				ELSE
				BEGIN
					SET @SQL=@SQL+'(isnull((select sum(bn.Quantity) from INV_BinDetails bn with(nolock) 
					 join inv_docdetails d with(nolock) on d.invdocdetailsid=bn.invdocdetailsid'

					set @SQL=@SQL+' where bn.vouchertype=1 and bn.IsQtyIgnored=0 and d.DocDate<='+CONVERT(NVARCHAR(50),CONVERT(float,@DocDate)) +' and d.ProductID='+ CONVERT(NVARCHAR(50),@PRODUCTID)
					
					if(@VoucherType=-1 and @batchID is not null and @batchID>0)
						set @SQL=@SQL+' and d.BatchID ='+CONVERT(nvarchar,@batchID)
					
					if(@batchRefInvID is not null and @batchRefInvID>0)
						set @SQL=@SQL+' and d.invdocdetailsid ='+CONVERT(nvarchar,@batchRefInvID)
								
					if(@Detailids<>'')
						set @SQL=@SQL+' and bn.InvDocDetailsID not in ('+@Detailids+') '	

					set @SQL=@SQL+' and d.StatusID=369  and BinID=a.NodeID),0)'
						
						if exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
						where Name='ExcludeHoldBins' and costcenterid=3 and Value='true')
						BEGIN
								set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
								 (SELECT bn.Quantity HoldQuantity,isnull(sum(lbn.Quantity),0) release  
								 FROM INV_DocDetails D WITH(NOLOCK) 
								 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
								 JOIN INV_BinDetails bn with(nolock) ON bn.InvDocDetailsID=D.InvDocDetailsID
								 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 					 
								 left JOIN INV_BinDetails lbn with(nolock) ON lbn.InvDocDetailsID=l.InvDocDetailsID
								 WHERE D.ProductID='+CONVERT(nvarchar,@PRODUCTID)+' and  bn.BinID=a.NodeID and ((D.HoldQuantity is not null and D.HoldQuantity>0) or (D.ReserveQuantity is not null and D.ReserveQuantity>0))  AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1  '
								 
								  if (@linkedIDs is not null and @linkedIDs<>'')
									 set @SQL=@SQL+' and d.docid not in (select DOCID from INV_DocDetails temp WITH(NOLOCK) where InvDocDetailsID in(' + @linkedIDs+ ')) '

								 if(@batchID is not null and @batchID>0)
									set @SQL=@SQL+' and d.BatchID ='+CONVERT(nvarchar,@batchID)

								 if(@Detailids<>'')
									set @SQL=@SQL+' and D.InvDocDetailsID not in ('+@Detailids+') '	

								set @SQL=@SQL+' group by D.InvDocDetailsID,bn.Quantity) as t)as temp ),0)'
						END
						
						set @SQL=@SQL+'-isnull((select sum(bn.Quantity) from INV_BinDetails bn with(nolock) 
						join inv_docdetails d with(nolock) on d.invdocdetailsid=bn.invdocdetailsid'

						set @SQL=@SQL+' where bn.vouchertype=-1 and bn.IsQtyIgnored=0 and d.DocDate<='+CONVERT(NVARCHAR(50),CONVERT(float,@DocDate)) +' and d.ProductID='+ CONVERT(NVARCHAR(50),@PRODUCTID)
						if(@VoucherType=-1 and @batchID is not null and @batchID>0)
							set @SQL=@SQL+' and d.BatchID ='+CONVERT(nvarchar,@batchID)
						if(@Detailids<>'')
							set @SQL=@SQL+' and bn.InvDocDetailsID not in ('+@Detailids+') '	
						
						if(@batchRefInvID is not null and @batchRefInvID>0)
							set @SQL=@SQL+' and d.RefInvDocDetailsID ='+CONVERT(nvarchar,@batchRefInvID)

						set @SQL=@SQL+' and d.StatusID in (369,371,441)  and BinID=a.NodeID),0) ) as BalQty'
					END	
			END	
				
			SET @SQL=@SQL+' from '+@TableName+' a with(nolock) '
			
			if(@VoucherType=-1 and @BoeIds<>'')
					set @SQL=@SQL+' join INV_BinDetails invbd with(nolock) on a.NodeId=invbd.BinID and invbd.InvDocDetailsID in ('+@BoeIds+') '

			if(@isProdwise=1)
				SET @SQL=@SQL+' left join INV_ProductBins b with(nolock) on a.NodeID=b.BinNodeID	'
						
			SET @SQL=@SQL+' JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = a.NodeID and c.[CostCenterID]='+CONVERT(NVARCHAR(50),@CCID)+'			
			WHERE a.isGroup=0 '
			
			if(@isProdwise=1)
				set @SQL=@SQL+' and b.NodeID = '+ CONVERT(NVARCHAR(50),@PRODUCTID)
			
			if(@isProdwise=1 and @VoucherType=1)	
				set @SQL=@SQL+' and (b.StatusID is null or b.StatusID=1)'
				
			if(@DimNodeID is not null and @DimNodeID>0)
					set @SQL=@SQL+' and ccnid'+(CONVERT(NVARCHAR(50),(@DimCCID-50000)))+'='+CONVERT(nvarchar,@DimNodeID)	
			
			if(@FilterNodeID is not null and @FilterNodeID>0)
					set @SQL=@SQL+' and ccnid'+(CONVERT(NVARCHAR(50),(@FilterCCID-50000)))+'='+CONVERT(nvarchar,@FilterNodeID)

			
			if @VoucherType=1 and exists(select costcenterid from [COM_CostCenterPreferences] with(nolock)
			where Name='CheckBinLWH' and costcenterid=3 and Value='true')
			BEGIN
				if(@Len is not null)
					set @SQL=@SQL+' and (a.ccAlpha47 is null or (isnumeric(a.ccAlpha47)=1 and convert(float,a.ccAlpha47)>= '+ CONVERT(NVARCHAR(50),@Len)+'))'
				if(@wid is not null)
					set @SQL=@SQL+' and (a.ccAlpha48 is null or (isnumeric(a.ccAlpha48)=1 and convert(float,a.ccAlpha48)>='+ CONVERT(NVARCHAR(50),@wid)+'))'
				if(@ht is not null)
					set @SQL=@SQL+' and (a.ccAlpha49 is null or (isnumeric(a.ccAlpha49)=1 and convert(float,a.ccAlpha49)>='+ CONVERT(NVARCHAR(50),@ht)+'))'
			END
			
			set @SQL=@SQL+' ) as t '
			
			if(@VoucherType=-1 and @isProdwise=0)
				set @SQL=@SQL+' where BalQty>0'
				
			set @SQL=@SQL+' order by a'
			
			while(@i<@cnt)
			BEGIN
				set @i=@i+1
				select @binruleid=ruleid from @tab where id=@i
				
				if(@binruleid=1)
					SET @SQL=@SQL+',Used desc'
				if(@binruleid=2)
					SET @SQL=@SQL+',NName'
					
				if(@binruleid=3 and not exists(select ruleid from @tab where ruleid=2))
					SET @SQL=@SQL+',NName desc'
				
				if(@binruleid=5)
					SET @SQL=@SQL+',NName'
				if(@binruleid=6)
					SET @SQL=@SQL+',BalQty'
				if(@binruleid=7 and not exists(select ruleid from @tab where ruleid=6))
					SET @SQL=@SQL+',BalQty desc'		
			END
			
			if(@cnt=0 and @DefaultBinSort in(2,3))
				SET @SQL=@SQL+',NName '		
			else if(@cnt=0)
				SET @SQL=@SQL+',Serialno '		
				
			
		END	
		print 	@SQL	
		EXEC(@SQL) 
           
SET NOCOUNT OFF;        
RETURN 1        
END TRY        
BEGIN CATCH          
  --Return exception info [Message,Number,ProcedureName,LineNumber]          
  IF ERROR_NUMBER()=50000        
  BEGIN        
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE()          
  END        
  ELSE        
  BEGIN        
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS		
	ErrorLine  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999        
  END        
SET NOCOUNT OFF          
RETURN -999           
END CATCH
GO
