USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetTempBatches]
	@PRODUCTID [int],
	@DOCDetailsID [int],
	@DOCID [int],
	@VoucherType [int],
	@DocDate [datetime],
	@DivisionID [int],
	@LocationID [int],
	@CostCenterID [int],
	@DimensionNodeID [int],
	@BatchFilterDim [int],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY          
SET NOCOUNT ON;        
            
	  DECLARE @SQL NVARCHAR(MAX) ,@ConsolidatedBatches nvarchar(50),@LWBatch nvarchar(50),@CCID INT,@Colname nvarchar(200),@GridviewID INT,@PrefValue nvarchar(50)
      DECLARE @CustomQuery1 nvarchar(max),@FeatureName nvarchar(100),@CustomQuery2 nvarchar(max),@PrefExpiredValue nvarchar(50),@PrefonlyExpired nvarchar(50),@shelfLife float
	  DECLARE @CustomQuery3 nvarchar(max),@i int ,@CNT int,@TableName nvarchar(100),@TabRef nvarchar(3),@PrefExcludePreExpiry nvarchar(50),@textNum nvarchar(max),@months int
	  DECLARE @CustomQuery4 nvarchar(max),@CustomQuery5 nvarchar(max),@FilterDim int,@SearchFilter nvarchar(max),@isQOHExists bit,@HoldResCancelledDocs nvarchar(max),@sorton nvarchar(100)
	  
	  set @HoldResCancelledDocs =''
	  select @HoldResCancelledDocs=Value from Adm_globalPreferences WITH(NOLOCK) where Name='HoldResCancelledDocs'    

		
       select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
       where Name='ConsolidatedBatches' and costcenterid=16
       
       set @FilterDim=0
       select @FilterDim=Value from [COM_CostCenterPreferences] with(nolock)
       where Name='BatchFilterDim' and costcenterid=16 and ISNUMERIC(value)=1

		select @PrefExcludePreExpiry=PrefValue from [COM_DocumentPreferences] with(nolock)
		where PrefName='ExcludePreExpired' and costcenterid=@CostCenterID
       
		select @PrefExpiredValue=PrefValue from [COM_DocumentPreferences] with(nolock)
		where PrefName='IncludeExpired' and costcenterid=@CostCenterID
		select @PrefonlyExpired=PrefValue from [COM_DocumentPreferences] with(nolock)
		where PrefName='OnlyExpired' and costcenterid=@CostCenterID
				
		select @shelfLife=ShelfLife from INV_Product WITH(NOLOCK) where ProductID=@PRODUCTID
		
		if (@shelfLife is not null and @shelfLife>0 and exists(select Value from [COM_CostCenterPreferences] with(nolock)
		where Name='IncludeMfgDate' and costcenterid=16 and Value='true'))
			set @shelfLife=@shelfLife-1
       
		 
		declare @CustomTable table(ID int identity(1,1),Name INT,colname nvarchar(200),CCID INT)

		SELECT @GridviewID=ParentNodeID FROM COM_CostCenterCostCenterMap a WITH(NOLOCK) 
		join ADM_GridView b WITH(NOLOCK) on a.ParentNodeID=b.GridViewID and b.CostCenterID=16
		WHERE ParentCostCenterID=26 AND a.CostCenterID=6 AND NodeID=@RoleID
		if not exists(SELECT GridViewID FROM [ADM_GridView] WITH(NOLOCK)  WHERE GridViewID =@GridviewID and CostCenterID=16)
		set @GridviewID=300
		
		set @textNum=''
		select  @textNum=@textNum+','+SysColumnName from(
		select b.SysColumnName from adm_gridviewcolumns a with(nolock)
		join ADM_CostCenterDef b with(nolock) on a.CostCenterColID=b.CostCenterColID
		where GridViewID=@GridviewID and b.CostCenterColID between 1100 and 1250 
		union
		select SysColumnName from COM_DocumentBatchLinkDetails a WITH(NOLOCK)
		join ADM_CostCenterDef b with(nolock) on a.BatchColID=b.CostCenterColID
		where a.[CostCenterID]=@CostCenterID  and BatchColID between 1100 and 1250) as t
		
		insert into @CustomTable(Name,colname,CCID)
		select a.CostCenterColID,b.SysColumnName,b.ColumnCostCenterID from adm_gridviewcolumns a with(nolock)
		join ADM_CostCenterDef b with(nolock) on a.CostCenterColID=b.CostCenterColID
		where GridViewID=@GridviewID and b.CostCenterID=16  
		AND (a.CostCenterColID in(1582,1584,53584) or b.SysColumnName LIKE 'alpha%' or b.SysColumnName LIKE 'ccnid%')		 
		union
		select BatchColID,SysColumnName,b.ColumnCostCenterID   from COM_DocumentBatchLinkDetails a WITH(NOLOCK)
		join ADM_CostCenterDef b with(nolock) on a.BatchColID=b.CostCenterColID
		where a.[CostCenterID]=@CostCenterID  and b.CostCenterID=16  
		AND (BatchColID in(1582,1584,53584) or b.SysColumnName LIKE 'alpha%' or b.SysColumnName LIKE 'ccnid%')
	    
	    if exists(select costcentercolid from adm_gridviewcolumns with(nolock)
					where GridViewID=@GridviewID and costcentercolid=53732)
				set @isQOHExists=1
		else
				set @isQOHExists=0
						
		set @i=1
		set @CustomQuery1=''
		set @CustomQuery2=', '
		set @CustomQuery3=', '
		select @CNT=count(id) from @CustomTable
		while (@i<=	@CNT)
		begin
			select @CCID=CCID,@Colname=colname from @CustomTable where ID=@i
		   		
    		if(@Colname like 'ccnid%')
    		begin
    			select @TableName=TableName,@FeatureName=FeatureID from adm_features with(nolock) where FeatureID = @CCID
		    
    			set @TabRef='A'+CONVERT(nvarchar,@i)
    			set @CCID=@CCID-50000
    			
				set @CustomQuery1=@CustomQuery1+' left join '+@TableName+' '+@TabRef+' with(nolock) on '+@TabRef+'.NodeID=C.CCNID'+CONVERT(nvarchar,@CCID)
				--set @CustomQuery2=@CustomQuery2+' A'+@FeatureName+' ,'
				--set @CustomQuery3=@CustomQuery3+' '+@TabRef+'.Name as A'+@FeatureName+' ,'
				
				set @CustomQuery2=@CustomQuery2+@Colname+' ,'+@Colname+'_Key ,'
				set @CustomQuery3=@CustomQuery3+'c.'+@Colname+' '+@Colname+'_Key,'+@TabRef+'.Name as '+@Colname+' ,'
			end
			else if(@Colname = 'RetestDate')
    		begin    			
    			set @CustomQuery2=@CustomQuery2+@Colname+' ,'
				set @CustomQuery3=@CustomQuery3+'CONVERT(DATETIME,B.'+@Colname+') as '+@Colname+' ,'
    		END
			else
			BEGIN
				set @CustomQuery2=@CustomQuery2+@Colname+' ,'
				set @CustomQuery3=@CustomQuery3+'B.'+@Colname+' ,'
			END	
			set @i=@i+1
		end
		
		select @SearchFilter=SearchFilter,@sorton=b.syscolumnname from ADM_GridView a with(nolock) 
		left join ADM_CostCenterDef b with(nolock) on a.DefaultColID=b.CostCenterColID
		where GridViewID=@GridviewID
		
		if(@sorton is null or @sorton='')
			set @sorton='ExpiryDate'
		
		IF(@SearchFilter<>'')
		BEGIN
			set @SearchFilter=Replace(@SearchFilter,'a.dcCCNID','CC.dcCCNID')
			set @SearchFilter=Replace(@SearchFilter,'CCM.CCNID','C.CCNID')
		END
		
		declare @DimensionTable table(ID int identity(1,1),colname nvarchar(200),CCID INT)
		insert into @DimensionTable(colname,CCID)
		select b.SysColumnName,b.ColumnCostCenterID from adm_gridviewcolumns a with(nolock)
		join ADM_CostCenterDef b with(nolock) on a.CostCenterColID=b.CostCenterColID
		where GridViewID=@GridviewID and b.CostCenterColID between 1261 and 1310
		union
		select b.SysColumnName,b.ColumnCostCenterID from COM_DocumentBatchLinkDetails a WITH(NOLOCK)
		join ADM_CostCenterDef b with(nolock) on a.BatchColID=b.CostCenterColID
		where a.[CostCenterID]=@CostCenterID  and BatchColID between 1261 and 1310
		
		set @CustomQuery4=''
		set @CustomQuery5=', '
		set @i=1
		select @CNT=count(id) from @DimensionTable
		while (@i<=	@CNT)
		begin
			select @CCID=CCID,@Colname=colname from @DimensionTable where ID=@i
			
			select @TableName=TableName,@FeatureName=FeatureID from adm_features with(nolock) where FeatureID = @CCID
		    
			set @TabRef='AA'+CONVERT(nvarchar,@i)
			set @CCID=@CCID-50000
			
			set @CustomQuery4=@CustomQuery4+' left join '+@TableName+' '+@TabRef+' with(nolock) on '+@TabRef+'.NodeID=CC.dcCCNID'+CONVERT(nvarchar,@CCID)
			--set @CustomQuery5=@CustomQuery5+'CC.'+@Colname+' ,'+@TabRef+'.Name as '+@Colname+'_Key ,'
			set @CustomQuery5=@CustomQuery5+'CC.'+@Colname+' '+@Colname+'_Key,'+@TabRef+'.Name as '+@Colname+' ,'
			
			set @i=@i+1
		end
		
		if(len(@CustomQuery2)>0)
		begin
	    set @CustomQuery2=SUBSTRING(@CustomQuery2,0,LEN(@CustomQuery2)-1)
	    end
	    
		if(len(@CustomQuery3)>0)
		begin
	    set @CustomQuery3=SUBSTRING(@CustomQuery3,0,LEN(@CustomQuery3)-1)
		end
       
    if(@VoucherType=1)
    begin    
	  SET @SQL='select BATCHNUMBER,BatchID,CONVERT(DATETIME,MfgDate) MfgDate,CONVERT(DATETIME,ExpiryDate) ExpiryDate,	
		MRPRate MRATE,RETAILRATE RRATE,STOCKISTRATE  SRATE'+@CustomQuery3+',BatchCode from dbo.INV_Batches B with(nolock)
		LEFT JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = B.BatchID and c.[CostCenterID]=16
		'+@CustomQuery1+'
		WHERE b.STATUSID = 77 and B.ProductID='+ CONVERT(NVARCHAR(50),@PRODUCTID)
		
		if(@FilterDim>50000)
			  set @SQL=@SQL+' and c.CCNID'+convert(nvarchar,@FilterDim-50000)+' ='+convert(nvarchar,@BatchFilterDim)
			
		if(@PrefonlyExpired is not null and @PrefonlyExpired ='true')
        BEGIN
			set @SQL=@SQL+' and CONVERT(Datetime,B.ExpiryDate)<'''+CONVERT(NVARCHAR(50),@DocDate)+''''
			
			select @months=convert(int,PrefValue) from [COM_DocumentPreferences] with(nolock)
			where PrefName='OnlyExpiredMonths' and costcenterid=@CostCenterID and PrefValue<>'' and ISNUMERIC(PrefValue)=1
			
			if(@months>0)
				set @SQL=@SQL+' and CONVERT(Datetime,ExpiryDate)>='''+CONVERT(NVARCHAR(50),dateadd(MONTH,-@months,@DocDate))+''''

        END
        ELSE if(@PrefExpiredValue is null or @PrefExpiredValue ='false')
        BEGIN
			set @SQL=@SQL+' and (B.ExpiryDate is null or CONVERT(Datetime,B.ExpiryDate)'
			if(@PrefExcludePreExpiry is not null and @PrefExcludePreExpiry ='true')
				set @SQL=@SQL+'-isnull(B.PreexpiryDays,0)'
			set @SQL=@SQL+'>='''+CONVERT(NVARCHAR(50),@DocDate)+''')'
		END	
		ELSE if(@PrefExpiredValue is not null or @PrefExpiredValue ='true')
        BEGIN         					
			select @months=convert(int,PrefValue) from [COM_DocumentPreferences] with(nolock)
			where PrefName='IncludeExpiredMonths' and costcenterid=@CostCenterID and PrefValue<>'' and ISNUMERIC(PrefValue)=1					

			if(@months>0)
				set @SQL=@SQL+' and CONVERT(Datetime,ExpiryDate)>='''+CONVERT(NVARCHAR(50),dateadd(MONTH,-@months,@DocDate))+''''
		END
		
		if(@DOCDetailsID>0)
			set @SQL=@SQL+' or  BatchID in (select BatchID from Inv_DocDetails with(nolock) where InvDocDetailsID='+ CONVERT(NVARCHAR,@DOCDetailsID) +' )'
		
		
		
		EXEC(@SQL) 
    end 
    else	
    begin
		if(@ConsolidatedBatches is not null and @ConsolidatedBatches ='False')
		begin
			    select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
				where Name='Excluderetestbatches' and costcenterid=16
			

			SET @SQL='	select * from (SELECT BD.BillNo,CONVERT(DATETIME, BD.BillDate) AS BillDate, BD.InvDocDetailsID,BD.VoucherNo,CONVERT(DATETIME,BD.DocDate) DocDate,BD.BatchID, B.BATCHNUMBER,B.BatchCode, CONVERT(DATETIME, B.MfgDate) AS MfgDate, CONVERT(DATETIME, B.ExpiryDate) AS ExpiryDate'
			 
			if(@isQOHExists=1)
			BEGIN
				SET @SQL=@SQL+', ROUND(case when CONVERT(Datetime,BD.DOCDate)<='''+CONVERT(NVARCHAR(50),@DocDate)+''' then BD.ReleaseQuantity else 0 end-isnull((select sum(UOMConvertedQty) from Inv_DocDetails td with(nolock) 
				 where td.RefInvDocDetailsID =BD.InvDocDetailsID and td.STATUSID in(369,371,441) and CONVERT(Datetime,td.DOCDate)<='''+CONVERT(NVARCHAR(50),@DocDate)+''''
				
				if(@DOCID is not null and @DOCID>0)
					set @SQL=@SQL+' and td.DOCID <>'+CONVERT(nvarchar,@DOCID)
									
				 set @SQL=@SQL+' and td.VoucherType = - 1 and td.IsQtyIgnored=0 ),0),4) as QOH' 
			END
			SET @SQL=@SQL+'	,BD.ReleaseQuantity-isnull((select sum(UOMConvertedQty) from Inv_DocDetails td with(nolock) 
				 where td.RefInvDocDetailsID =BD.InvDocDetailsID and td.STATUSID in(369,371,441) '				 
				if(@DOCID is not null and @DOCID>0)
					set @SQL=@SQL+' and td.DOCID <>'+CONVERT(nvarchar,@DOCID)
				 set @SQL=@SQL+' and td.VoucherType = - 1 and td.IsQtyIgnored=0 ),0) '
				 
			 	
				
				if exists(select Value from [COM_CostCenterPreferences] with(nolock)
				where Name='ExcludeHold' and costcenterid=16 and Value='true')
				BEGIN
						set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) 
					 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.BatchID=BD.BatchID and D.RefInvDocDetailsID =BD.InvDocDetailsID and D.DOCID <>'+CONVERT(nvarchar,@DOCID)+'  AND D.IsQtyIgnored=1 and D.StatusID'
				 
				 if exists(select Value from ADM_GlobalPreferences with(nolock) where Name='ConsiderUnAppInHold' and Value ='true')				 
					set @SQL=@SQL+' in(371,441,369) '
				else	
					set @SQL=@SQL+'=369 '
				 
				 set @SQL=@SQL+'  and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 '
					 if(@LocationID is not null and @LocationID>0)
							set @SQL=@SQL+'and DCC.dcccnid2='+CONVERT(nvarchar,@LocationID)
						if(@DivisionID is not null and @DivisionID>0)
							set @SQL=@SQL+' and DCC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
					   
						if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
						begin  				 
							  set @SQL=@SQL+' and DCC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
						end  
					 set @SQL=@SQL+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp ),0)'
				END
				
				if exists(select Value from [COM_CostCenterPreferences] with(nolock)
				where Name='ExcludeReserve' and costcenterid=16 and Value='true')
				BEGIN
						set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) 
					 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.BatchID=BD.BatchID and D.RefInvDocDetailsID =BD.InvDocDetailsID and D.DOCID <>'+CONVERT(nvarchar,@DOCID)+'  AND D.IsQtyIgnored=1 and D.StatusID'
				 
				 if exists(select Value from ADM_GlobalPreferences with(nolock) where Name='ConsiderUnAppInHold' and Value ='true')				 
					set @SQL=@SQL+' in(371,441,369) '
				else	
					set @SQL=@SQL+'=369 '
				 
				 set @SQL=@SQL+' and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 '
					 if(@LocationID is not null and @LocationID>0)
							set @SQL=@SQL+'and DCC.dcccnid2='+CONVERT(nvarchar,@LocationID)
						if(@DivisionID is not null and @DivisionID>0)
							set @SQL=@SQL+' and DCC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
					   
						if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
						begin  				 
							  set @SQL=@SQL+' and DCC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
						end  
					 set @SQL=@SQL+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp ),0)'
				END 
				set @SQL=@SQL+' as BalQty,
				 MRPRate MRATE,RETAILRATE RRATE,STOCKISTRATE  SRATE'+@CustomQuery3+@textNum+Substring(@CustomQuery5,1,Len(@CustomQuery5)-1)+'
				FROM  Inv_DocDetails AS BD with(nolock)
                INNER JOIN INV_Batches AS B with(nolock) ON BD.BatchID = B.BatchID
                JOIN INV_product AS p with(nolock) ON B.ProductID = p.ProductID
                LEFT JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = B.BatchID and c.[CostCenterID]=16                
                INNER JOIN COM_DocCCData AS CC with(nolock) ON BD.InvDocDetailsID = CC.InvDocDetailsID
                '
                if(@textNum<>'')
					set @SQL=@SQL+'INNER JOIN COM_DocNUMData AS num with(nolock) ON BD.InvDocDetailsID = num.InvDocDetailsID
					INNER JOIN COM_DocTextData AS tex with(nolock) ON BD.InvDocDetailsID = tex.InvDocDetailsID '
				
				IF(@CustomQuery4<>'')
					set @SQL=@SQL+@CustomQuery4
					
                set @SQL=@SQL+@CustomQuery1+'
               WHERE BD.VoucherType = 1 and BD.IsQtyIgnored=0 and B.STATUSID = 77 and B.ProductID='+ CONVERT(NVARCHAR(50),@PRODUCTID)
               
               if(@DOCDetailsID>0)
               BEGIN
					select @i=BatchID from Inv_DocDetails WITH(NOLOCK) where InvDocDetailsID=@DOCDetailsID
					set @SQL=@SQL+ ' and (BD.BatchID='+convert(nvarchar(max),@i)+' or (BD.BatchID<>'+convert(nvarchar(max),@i)+'  and BD.STATUSID=369 and CONVERT(Datetime,BD.DOCDate)<='''+CONVERT(NVARCHAR(50),@DocDate)+''' ))'
                
               END
               ELSE
					set @SQL=@SQL+ ' and BD.STATUSID=369 and CONVERT(Datetime,BD.DOCDate)<='''+CONVERT(NVARCHAR(50),@DocDate)+''' '
                
                if(@PrefonlyExpired is not null and @PrefonlyExpired ='true')
                BEGIN
					set @SQL=@SQL+' and CONVERT(Datetime,B.ExpiryDate)<'''+CONVERT(NVARCHAR(50),@DocDate)+''''
					
					select @months=convert(int,PrefValue) from [COM_DocumentPreferences] with(nolock)
					where PrefName='OnlyExpiredMonths' and costcenterid=@CostCenterID and PrefValue<>'' and ISNUMERIC(PrefValue)=1
					
					if(@months>0)
						set @SQL=@SQL+' and CONVERT(Datetime,ExpiryDate)>='''+CONVERT(NVARCHAR(50),dateadd(MONTH,-@months,@DocDate))+''''

                END
                ELSE if(@PrefExpiredValue is null or @PrefExpiredValue ='false')
                BEGIN
					set @SQL=@SQL+' and (B.ExpiryDate is null or CONVERT(Datetime,B.ExpiryDate)'
					if(@PrefExcludePreExpiry is not null and @PrefExcludePreExpiry ='true')
						set @SQL=@SQL+'-isnull(B.PreexpiryDays,0)'
					set @SQL=@SQL+'>='''+CONVERT(NVARCHAR(50),@DocDate)+''')'
				END	
				ELSE if(@PrefExpiredValue is not null or @PrefExpiredValue ='true')
                BEGIN
                                					
					select @months=convert(int,PrefValue) from [COM_DocumentPreferences] with(nolock)
					where PrefName='IncludeExpiredMonths' and costcenterid=@CostCenterID and PrefValue<>'' and ISNUMERIC(PrefValue)=1					

					if(@months>0)
						set @SQL=@SQL+' and CONVERT(Datetime,ExpiryDate)>='''+CONVERT(NVARCHAR(50),dateadd(MONTH,-@months,@DocDate))+''''
				
				END
				
				if(@LocationID is not null and @LocationID>0)
					set @SQL=@SQL+' and CC.dcccnid2='+CONVERT(nvarchar,@LocationID)
				if(@DivisionID is not null and @DivisionID>0)
					set @SQL=@SQL+' and CC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
                
                if(@DimensionNodeID is not null and @DimensionNodeID>=0)
				begin
					set @PrefValue=''
					select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise Batches'  
				    
					if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
					begin  
						  set @PrefValue=convert(INT,@PrefValue)-50000  						 
						  set @SQL=@SQL+' and CC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
					end  			
				end
				if(@FilterDim>50000)
					set @SQL=@SQL+' and c.CCNID'+convert(nvarchar,@FilterDim-50000)+' ='+convert(nvarchar,@BatchFilterDim)

               if((@ConsolidatedBatches is not null and @ConsolidatedBatches ='true') and not (@PrefExpiredValue is null or @PrefExpiredValue ='false'))
					 SET @SQL=@SQL+' and (B.RetestDate is null or  CONVERT(Datetime,B.RetestDate)>='''+CONVERT(NVARCHAR(50),@DocDate)+''')'
              
				if(@SearchFilter<>'')
					set @SQL=@SQL+' and '+@SearchFilter
              if exists(select DocumentType from ADM_DocumentTypes WITH(NOLOCK) where CostCenterID=@CostCenterID and DocumentType=31)              
               SET @SQL=@SQL+') AS T  order by '+@sorton
			ELSE
               SET @SQL=@SQL+') AS T                                  
               where ROUND(BalQty,2)>0 order by '+@sorton
			   print @SQL 
			  exec(@SQL)
			  
		end
		else
		begin
		    set @PrefValue=''
		    if(@DimensionNodeID is not null and @DimensionNodeID>=0)
			begin
				select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise Batches'  
			END   
		
			set @SQL='select * from (
			select BATCHNUMBER,BatchCode,BatchID,CONVERT(DATETIME,MfgDate) MfgDate,CONVERT(DATETIME,ExpiryDate) ExpiryDate'+@CustomQuery3+',
			(isnull((select sum(ReleaseQuantity) from Inv_DocDetails a with(nolock)
			join com_docccdata d with(nolock) on d.invdocdetailsid=a.invdocdetailsid		
			where vouchertype=1 and a.IsQtyIgnored=0 and a.statusid=369 '
			
			if(@LocationID is not null and @LocationID>0)
				set @SQL=@SQL+'and d.dcccnid2='+CONVERT(nvarchar,@LocationID)
			if(@DivisionID is not null and @DivisionID>0)
				set @SQL=@SQL+' and d.dcccnid1='+CONVERT(nvarchar,@DivisionID)
			if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
			begin  			
				  set @PrefValue=convert(INT,@PrefValue)-50000  				  				 
				  set @SQL=@SQL+' and d.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
			end  
			
			set @SQL=@SQL+' and BatchID=b.BatchID and a.ProductID=b.ProductID),0)-
			isnull((select sum(UOMConvertedQty) from Inv_DocDetails a with(nolock)
			join com_docccdata d with(nolock) on d.invdocdetailsid=a.invdocdetailsid		
			where vouchertype=-1 and a.IsQtyIgnored=0  and a.STATUSID in(369,371,441) '
			if(@LocationID is not null and @LocationID>0)
				set @SQL=@SQL+'and d.dcccnid2='+CONVERT(nvarchar,@LocationID)
			if(@DivisionID is not null and @DivisionID>0)
				set @SQL=@SQL+' and d.dcccnid1='+CONVERT(nvarchar,@DivisionID)
		   
			if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
			begin  				 
				  set @SQL=@SQL+' and d.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
			end  			
				
			if(@DOCID is not null and @DOCID>0)
					set @SQL=@SQL+' and a.DOCID <>'+CONVERT(nvarchar,@DOCID)

			set @SQL=@SQL+'  and BatchID=b.BatchID and a.ProductID=b.ProductID),0)'
			
			set @ConsolidatedBatches=''
			select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
			where Name='ExcludeHold' and costcenterid=16
			if(@ConsolidatedBatches='true')
			BEGIN
					set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) 
				 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 WHERE D.BatchID=b.BatchID  AND D.IsQtyIgnored=1 and D.StatusID'
				 
				 if exists(select Value from ADM_GlobalPreferences with(nolock) where Name='ConsiderUnAppInHold' and Value ='true')				 
					set @SQL=@SQL+' in(371,441,369) '
				else	
					set @SQL=@SQL+'=369 '
				 
				 set @SQL=@SQL+' and D.DocumentType in (7,9,11,12,24)  and D.DOCID <>'+CONVERT(nvarchar,@DOCID)+' and D.VoucherType=-1 '
				 if(@LocationID is not null and @LocationID>0)
						set @SQL=@SQL+'and DCC.dcccnid2='+CONVERT(nvarchar,@LocationID)
					if(@DivisionID is not null and @DivisionID>0)
						set @SQL=@SQL+' and DCC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
				   
					if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
					begin  				 
						  set @SQL=@SQL+' and DCC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
					end  
				 set @SQL=@SQL+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp ),0)'
			END
			
			set @ConsolidatedBatches=''
			select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
			where Name='ExcludeReserve' and costcenterid=16
			if(@ConsolidatedBatches='true')
			BEGIN
					set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) 
				 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 WHERE D.BatchID=b.BatchID  AND D.IsQtyIgnored=1 and D.StatusID'
				 
				 if exists(select Value from ADM_GlobalPreferences with(nolock) where Name='ConsiderUnAppInHold' and Value ='true')				 
					set @SQL=@SQL+' in(371,441,369) '
				else	
					set @SQL=@SQL+'=369 '
				 
				 set @SQL=@SQL+' and D.DocumentType in (7,9,11,12,24)  and D.DOCID <>'+CONVERT(nvarchar,@DOCID)+' and D.VoucherType=-1 '
				 if(@LocationID is not null and @LocationID>0)
						set @SQL=@SQL+'and DCC.dcccnid2='+CONVERT(nvarchar,@LocationID)
					if(@DivisionID is not null and @DivisionID>0)
						set @SQL=@SQL+' and DCC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
				   
					if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
					begin  				 
						  set @SQL=@SQL+' and DCC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
					end  
				 set @SQL=@SQL+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp ),0)'
			END
			
			set @SQL=@SQL+'   ) as BalQty'
			
			if(@isQOHExists=1)
			BEGIN
				
				set @SQL=@SQL+' ,round(isnull((select sum(ReleaseQuantity) from Inv_DocDetails a with(nolock)
				join com_docccdata d with(nolock) on d.invdocdetailsid=a.invdocdetailsid		
				where vouchertype=1 and a.IsQtyIgnored=0 '
				
				set @SQL=@SQL+' and CONVERT(Datetime,a.DOCDate)<='''+CONVERT(NVARCHAR(50),@DocDate)+''''
			
				if(@LocationID is not null and @LocationID>0)
					set @SQL=@SQL+'and d.dcccnid2='+CONVERT(nvarchar,@LocationID)
				if(@DivisionID is not null and @DivisionID>0)
					set @SQL=@SQL+' and d.dcccnid1='+CONVERT(nvarchar,@DivisionID)
				if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
				begin  			
						  				 
					  set @SQL=@SQL+' and d.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
				end  
				
				set @SQL=@SQL+' and BatchID=b.BatchID and a.ProductID=b.ProductID),0)-
				isnull((select sum(UOMConvertedQty) from Inv_DocDetails a with(nolock)
				join com_docccdata d with(nolock) on d.invdocdetailsid=a.invdocdetailsid		
				where vouchertype=-1 and a.IsQtyIgnored=0 '
				set @SQL=@SQL+' and CONVERT(Datetime,a.DOCDate)<='''+CONVERT(NVARCHAR(50),@DocDate)+''''
				if(@LocationID is not null and @LocationID>0)
					set @SQL=@SQL+'and d.dcccnid2='+CONVERT(nvarchar,@LocationID)
				if(@DivisionID is not null and @DivisionID>0)
					set @SQL=@SQL+' and d.dcccnid1='+CONVERT(nvarchar,@DivisionID)
			   
				if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
				begin  				 
					  set @SQL=@SQL+' and d.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
				end  			
					
				if(@DOCID is not null and @DOCID>0)
						set @SQL=@SQL+' and a.DOCID <>'+CONVERT(nvarchar,@DOCID)

				set @SQL=@SQL+'  and BatchID=b.BatchID and a.ProductID=b.ProductID),0)'
				
				set @ConsolidatedBatches=''
				select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
				where Name='ExcludeHold' and costcenterid=16
				if(@ConsolidatedBatches='true')
				BEGIN
						set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) 
					 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.BatchID=b.BatchID  AND D.IsQtyIgnored=1 and D.StatusID'
				 
					 if exists(select Value from ADM_GlobalPreferences with(nolock) where Name='ConsiderUnAppInHold' and Value ='true')				 
						set @SQL=@SQL+' in(371,441,369) '
					else	
						set @SQL=@SQL+'=369 '
					 
					 set @SQL=@SQL+' and D.DocumentType in (7,9,11,12,24)  and D.DOCID <>'+CONVERT(nvarchar,@DOCID)+' and D.VoucherType=-1 '
						set @SQL=@SQL+' and CONVERT(Datetime,D.DOCDate)<='''+CONVERT(NVARCHAR(50),@DocDate)+''''
					 if(@LocationID is not null and @LocationID>0)
							set @SQL=@SQL+'and DCC.dcccnid2='+CONVERT(nvarchar,@LocationID)
						if(@DivisionID is not null and @DivisionID>0)
							set @SQL=@SQL+' and DCC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
					   
						if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
						begin  				 
							  set @SQL=@SQL+' and DCC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
						end  
					 set @SQL=@SQL+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp ),0)'
				END
				
				set @ConsolidatedBatches=''
				select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
				where Name='ExcludeReserve' and costcenterid=16
				if(@ConsolidatedBatches='true')
				BEGIN
						set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) 
					 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.BatchID=b.BatchID  AND D.IsQtyIgnored=1 and D.StatusID'
				 
					 if exists(select Value from ADM_GlobalPreferences with(nolock) where Name='ConsiderUnAppInHold' and Value ='true')				 
						set @SQL=@SQL+' in(371,441,369) '
					else	
						set @SQL=@SQL+'=369 '
					 
					 set @SQL=@SQL+' and D.DocumentType in (7,9,11,12,24)  and D.DOCID <>'+CONVERT(nvarchar,@DOCID)+' and D.VoucherType=-1 '
						set @SQL=@SQL+' and CONVERT(Datetime,D.DOCDate)<='''+CONVERT(NVARCHAR(50),@DocDate)+''''
					 if(@LocationID is not null and @LocationID>0)
							set @SQL=@SQL+'and DCC.dcccnid2='+CONVERT(nvarchar,@LocationID)
						if(@DivisionID is not null and @DivisionID>0)
							set @SQL=@SQL+' and DCC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
					   
						if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
						begin  				 
							  set @SQL=@SQL+' and DCC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
						end  
					 set @SQL=@SQL+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp ),0)'
				END
				set @SQL=@SQL+'   ,2) as QOH'
			END
			
			set @SQL=@SQL+',MRPRate MRATE,RETAILRATE RRATE,STOCKISTRATE  SRATE from dbo.INV_Batches B with(nolock)
							 LEFT JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = B.BatchID and c.[CostCenterID]=16'+@CustomQuery1							  
			set @SQL=@SQL+'  WHERE b.STATUSID = 77 and b.ProductID='+CONVERT(nvarchar,@PRODUCTID)
				
				if(@FilterDim>50000)
					set @SQL=@SQL+' and c.CCNID'+convert(nvarchar,@FilterDim-50000)+' ='+convert(nvarchar,@BatchFilterDim)
				
				set @ConsolidatedBatches=''
				select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
				where Name='Excluderetestbatches' and costcenterid=16
			
			if(@ConsolidatedBatches is not null and @ConsolidatedBatches ='true')
					 SET @SQL=@SQL+' and (B.RetestDate is null or  CONVERT(Datetime,B.RetestDate)>='''+CONVERT(NVARCHAR(50),@DocDate)+''')'
              
             
				if(@PrefonlyExpired is not null and @PrefonlyExpired ='true')
                BEGIN
					set @SQL=@SQL+' and CONVERT(Datetime,ExpiryDate)<'''+CONVERT(NVARCHAR(50),@DocDate)+''''
					
					select @months=convert(int,PrefValue) from [COM_DocumentPreferences] with(nolock)
					where PrefName='OnlyExpiredMonths' and costcenterid=@CostCenterID and PrefValue<>'' and ISNUMERIC(PrefValue)=1
					
					if(@months>0)
						set @SQL=@SQL+' and CONVERT(Datetime,ExpiryDate)>='''+CONVERT(NVARCHAR(50),dateadd(MONTH,-@months,@DocDate))+''''
					
                END
                ELSE if(@PrefExpiredValue is null or @PrefExpiredValue ='false')
                BEGIN
					set @SQL=@SQL+' and (ExpiryDate is null or CONVERT(Datetime,ExpiryDate)'
					if(@PrefExcludePreExpiry is not null and @PrefExcludePreExpiry ='true')
						set @SQL=@SQL+'-isnull(PreexpiryDays,0)'
					set @SQL=@SQL+'>='''+CONVERT(NVARCHAR(50),@DocDate)+''')'
				END	
				ELSE if(@PrefExpiredValue is not null or @PrefExpiredValue ='true')
                BEGIN
                					
					select @months=convert(int,PrefValue) from [COM_DocumentPreferences] with(nolock)
					where PrefName='IncludeExpiredMonths' and costcenterid=@CostCenterID and PrefValue<>'' and ISNUMERIC(PrefValue)=1
					
					if(@months>0)
						set @SQL=@SQL+' and CONVERT(Datetime,ExpiryDate)>='''+CONVERT(NVARCHAR(50),dateadd(MONTH,-@months,@DocDate))+''''
				
				END
				
			set @SQL=@SQL+') as ttt'
			
			if exists(select DocumentType from ADM_DocumentTypes WITH(NOLOCK) where CostCenterID=@CostCenterID and DocumentType=31)
				set @SQL=@SQL+'  order by '+@sorton
			ELSE
				set @SQL=@SQL+'  where ROUND(BalQty,2)>0 order by '+@sorton
			 print @SQL
			exec(@SQL)
		end
		
		  if(@@rowcount=0 and (@PrefExpiredValue is null or @PrefExpiredValue ='false')
		  and (@PrefonlyExpired is  null or @PrefonlyExpired ='false'))
		  BEGIN			
				set @SQL='if exists(select * from (select BatchID,
			(isnull((select sum(ReleaseQuantity) from Inv_DocDetails a with(nolock)
			join com_docccdata d with(nolock) on d.invdocdetailsid=a.invdocdetailsid		
			where vouchertype=1 and a.IsQtyIgnored=0  and a.STATUSID =369 '
			
			if(@LocationID is not null and @LocationID>0)
				set @SQL=@SQL+'and d.dcccnid2='+CONVERT(nvarchar,@LocationID)
			if(@DivisionID is not null and @DivisionID>0)
				set @SQL=@SQL+' and d.dcccnid1='+CONVERT(nvarchar,@DivisionID)
			if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
			begin 
				  set @SQL=@SQL+' and d.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
			end  
			
			set @SQL=@SQL+' and BatchID=b.BatchID and a.ProductID=b.ProductID),0)-
			isnull((select sum(UOMConvertedQty) from Inv_DocDetails a with(nolock)
			join com_docccdata d with(nolock) on d.invdocdetailsid=a.invdocdetailsid		
			where vouchertype=-1 and a.IsQtyIgnored=0  and a.STATUSID in(369,371,441) '
			if(@LocationID is not null and @LocationID>0)
				set @SQL=@SQL+'and d.dcccnid2='+CONVERT(nvarchar,@LocationID)
			if(@DivisionID is not null and @DivisionID>0)
				set @SQL=@SQL+' and d.dcccnid1='+CONVERT(nvarchar,@DivisionID)
		   
			if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
			begin  				 
				  set @SQL=@SQL+' and d.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
			end  			
				
			if(@DOCID is not null and @DOCID>0)
					set @SQL=@SQL+' and a.DOCID <>'+CONVERT(nvarchar,@DOCID)

			set @SQL=@SQL+'  and BatchID=b.BatchID and a.ProductID=b.ProductID),0)'
			
			set @ConsolidatedBatches=''
			select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
			where Name='ExcludeHold' and costcenterid=16
			if(@ConsolidatedBatches='true')
			BEGIN
					set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) 
				 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 WHERE D.BatchID=b.BatchID  AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24)  and D.DOCID <>'+CONVERT(nvarchar,@DOCID)+' and D.VoucherType=-1 '
				 if(@LocationID is not null and @LocationID>0)
						set @SQL=@SQL+'and DCC.dcccnid2='+CONVERT(nvarchar,@LocationID)
					if(@DivisionID is not null and @DivisionID>0)
						set @SQL=@SQL+' and DCC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
				   
					if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
					begin  				 
						  set @SQL=@SQL+' and DCC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
					end  
				 set @SQL=@SQL+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp ),0)'
			END
			
			set @ConsolidatedBatches=''
			select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
			where Name='ExcludeReserve' and costcenterid=16
			if(@ConsolidatedBatches='true')
			BEGIN
					set @SQL=@SQL+'- isnull((select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) 
				 INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 WHERE D.BatchID=b.BatchID  AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24)  and D.DOCID <>'+CONVERT(nvarchar,@DOCID)+' and D.VoucherType=-1 '
				 if(@LocationID is not null and @LocationID>0)
						set @SQL=@SQL+'and DCC.dcccnid2='+CONVERT(nvarchar,@LocationID)
					if(@DivisionID is not null and @DivisionID>0)
						set @SQL=@SQL+' and DCC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
				   
					if(@DimensionNodeID is not null and @DimensionNodeID>=0 and @PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
					begin  				 
						  set @SQL=@SQL+' and DCC.dcCCNID'+@PrefValue+' ='+convert(nvarchar,@DimensionNodeID)
					end  
				 set @SQL=@SQL+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp ),0)'
			END
			
			set @SQL=@SQL+'   ) as BalQty
			from dbo.INV_Batches B with(nolock)
			LEFT JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = B.BatchID and c.[CostCenterID]=16'
			set @SQL=@SQL+'  WHERE b.STATUSID = 77 and b.ProductID='+CONVERT(nvarchar,@PRODUCTID)
			
			if(@FilterDim>50000)
					set @SQL=@SQL+' and c.CCNID'+convert(nvarchar,@FilterDim-50000)+' ='+convert(nvarchar,@BatchFilterDim)

			set @SQL=@SQL+') as ttt'
			set @SQL=@SQL+'  where ROUND(BalQty,2)>0 ) RAISERROR(''-548'',16,1)     '
			 print @SQL
			exec(@SQL)	
			
		  END
    end
    
    
    
   if(@DOCDetailsID>0)
   begin
		select BatchID,UOMConvertedQty Quantity,HoldQuantity,ReleaseQuantity
		from INV_DocDetails with(nolock)
		where InvDocDetailsID=@DOCDetailsID
   end
   else 
   begin
		select BatchID,Quantity,HoldQuantity,ReleaseQuantity 
		from INV_DocDetails with(nolock)
		where 1<>1
   end
   
	select Name,Value,@shelfLife ShelfLife from COM_CostCenterPreferences with(nolock)
    where CostCenterID=16 and Name in('BatchNumSameAsCode','HoldandReleaseQTY','OnlyMonthYear','ConsolidatedBatches','AutoGenerateBatches','BatchCodeAutoGen','SortBatchGrid')
    
    select b.SysColumnName BatchCol,c.SysColumnName BaseCol  from COM_DocumentBatchLinkDetails a WITH(NOLOCK)
	join ADM_CostCenterDef b with(nolock) on a.BatchColID=b.CostCenterColID
	join ADM_CostCenterDef c with(nolock) on a.CostCenterColIDBase=c.CostCenterColID
	where a.[CostCenterID]=@CostCenterID  and 
	(BatchColID>1572 or BatchColID between 1100 and 1250 or BatchColID between 1261 and 1310) and linkdimccid=16
	
	
		
    select a.CostCenterID, a.CostCenterColID, r.ResourceData UserColumnName,  case when SysColumnName='ExpiryDate' then 'ExpDate'
	when SysColumnName='MRPRate' then 'MRate'
	when SysColumnName='RetailRate' then 'RRate'
	when SysColumnName='StockistRate' then 'SRate'
	when SysColumnName='HoldQuantity' then 'Hold'
	when SysColumnName='ReleaseQuantity' then 'Release' else SysColumnName end Name,
    UserColumnType, g.ColumnWidth, g.ColumnOrder, A.IsEditable                        
    from adm_costcenterdef a WITH(NOLOCK) 
    join    ADM_GridViewColumns g WITH(NOLOCK) on a.CostCenterColID=g.CostCenterColID and g.GridViewID=@GridviewID           
    join    COM_LanguageResources R WITH(NOLOCK) on R.ResourceID=a.ResourceID and r.LanguageID=@LangID
    where a.CostCenterID=16 or a.CostCenterColID between 1101 and 1250 or  a.CostCenterColID between 1261 and 1310
    order by g.ColumnOrder
	
	
	
	SELECT  distinct C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,                              
	C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,isnull(C.IsVisible,1) IsVisible,C.ColumnCCListViewTypeID,                              
	QuickAddOrder,C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName , C.RowNo,C.ColumnNo, C.ColumnSpan,C.TextFormat,C.SectionSeqNumber                             
	FROM ADM_CostCenterDef C WITH(NOLOCK)                              
	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=1                              
	WHERE C.CostCenterID = 16 AND ShowInQuickAdd=1 and IsVisible=1  and C.SysColumnName not in ('Depth','ParentID')                             
	AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)                              
	ORDER BY QuickAddOrder

	select * from com_costcentercodedef WITH(NOLOCK) WHERE CostCenterID=16                                           
		
	if exists(select * from ADM_TypeRestrictions with(nolock) where CostCenterID=16)
	BEGIN
		select @GridviewID=ParentID from inv_product WITH(NOLOCK) where Productid=@PRODUCTID
		set @CCID=0
		select @CCID=isnull(TypeID,0) from ADM_TypeRestrictions with(nolock) where CostCenterID=16 and TypeID=@GridviewID
		while(@CCID=0 and @GridviewID>0)
		BEGIN
			select @GridviewID=ParentID from inv_product WITH(NOLOCK) where Productid=@GridviewID
			set @CCID=0
			select @CCID=isnull(TypeID,0) from ADM_TypeRestrictions with(nolock) where CostCenterID=16 and TypeID=@GridviewID
		END
		select * from ADM_TypeRestrictions with(nolock) where CostCenterID=16 and TypeID=@CCID
	END
           
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
