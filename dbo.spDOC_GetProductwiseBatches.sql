USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductwiseBatches]
	@PRODUCTID [bigint],
	@DOCDetailsID [bigint],
	@DOCID [bigint],
	@VoucherType [int],
	@DocDate [datetime],
	@DivisionID [bigint],
	@LocationID [bigint],
	@CostCenterID [int],
	@UserID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY          
SET NOCOUNT ON;        
            
	  DECLARE @SQL NVARCHAR(MAX) ,@ConsolidatedBatches nvarchar(50),@LWBatch nvarchar(50),@CCID bigint,@Colname nvarchar(200),@GridviewID bigint
      DECLARE @CustomQuery1 nvarchar(max),@FeatureName nvarchar(100),@CustomQuery2 nvarchar(max),@PrefExpiredValue nvarchar(50),@PrefRetestValue nvarchar(50)
	  DECLARE @CustomQuery3 nvarchar(max),@i int ,@CNT int,@TableName nvarchar(100),@TabRef nvarchar(3),@PrefExcludePreExpiry nvarchar(50)
		
       select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
       where Name='ConsolidatedBatches' and costcenterid=16

		select @PrefExcludePreExpiry=PrefValue from [COM_DocumentPreferences] with(nolock)
		where PrefName='ExcludePreExpired' and costcenterid=@CostCenterID
       
		select @PrefExpiredValue=PrefValue from [COM_DocumentPreferences] with(nolock)
		where PrefName='IncludeExpired' and costcenterid=@CostCenterID
		select @PrefRetestValue=PrefValue from [COM_DocumentPreferences] with(nolock)
		where PrefName='IncludeRetest' and costcenterid=@CostCenterID

       declare @CustomTable table(ID int identity(1,1),Name bigint,colname nvarchar(200),CCID bigint)
		
			SELECT @GridviewID=ParentNodeID FROM COM_CostCenterCostCenterMap a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.ParentNodeID=b.GridViewID and b.CostCenterID=16
			WHERE ParentCostCenterID=26 AND a.CostCenterID=6 AND NodeID=@RoleID
			if not exists(SELECT GridViewID FROM [ADM_GridView]  WHERE GridViewID =@GridviewID and CostCenterID=16)
				set @GridviewID=300

		insert into @CustomTable(Name,colname,CCID)
		select a.CostCenterColID,b.SysColumnName,b.ColumnCostCenterID from adm_gridviewcolumns a with(nolock)
		join ADM_CostCenterDef b with(nolock) on a.CostCenterColID=b.CostCenterColID
		 where GridViewID=@GridviewID and 
		 (a.CostCenterColID in(1582,1584,53584) or a.CostCenterColID between 53591 and 53691)		 
		 union
		select BatchColID,SysColumnName,b.ColumnCostCenterID   from COM_DocumentBatchLinkDetails a
		join ADM_CostCenterDef b with(nolock) on a.BatchColID=b.CostCenterColID
	    where a.[CostCenterID]=@CostCenterID  and 
	    (BatchColID in(1582,1584,53584) or BatchColID between 53591 and 53691)
	    
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
				set @CustomQuery3=@CustomQuery3+'c.'+@Colname+' ,'+@TabRef+'.Name as '+@Colname+'_Key ,'
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
		MRPRate MRATE,RETAILRATE RRATE,STOCKISTRATE  SRATE'+@CustomQuery3+' from dbo.INV_Batches B with(nolock)
		LEFT JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = B.BatchID and c.[CostCenterID]=16
		'+@CustomQuery1+'
		WHERE b.STATUSID = 77 and B.ProductID='+ CONVERT(NVARCHAR(50),@PRODUCTID)
		if(@PrefExpiredValue is null or @PrefExpiredValue ='false')
			set @SQL=@SQL+' and (ExpiryDate>='+CONVERT(NVARCHAR(50),CONVERT(float,@DocDate))
		if(@DOCDetailsID>0)
			set @SQL=@SQL+' or  BatchID in (select BatchID from INV_BatchDetails with(nolock) where InvDocDetailsID='+ CONVERT(NVARCHAR(50),@DOCDetailsID) +' )'
		if(@PrefExpiredValue is null or @PrefExpiredValue ='false')		
			set @SQL=@SQL+' )'	
		PRINT @SQL
		EXEC(@SQL) 
    end 
    else
    begin
		if(@ConsolidatedBatches is not null and @ConsolidatedBatches ='False')
		begin
			    select @ConsolidatedBatches=Value from [COM_CostCenterPreferences] with(nolock)
				where Name='Excluderetestbatches' and costcenterid=16
			

			 SET @SQL='	select * from ( SELECT   BillNo,BillDate, InvDocDetailsID,VoucherNo,convert(datetime,DocDate) DocDate,BatchID, BatchNumber BATCHNUMBER, MfgDate, ExpiryDate'+@CustomQuery2+',  isnull(sum(ReleaseQuantity),0)- isnull(sum(Quantity),0) as BalQty,MRATE,RRATE,SRATE
				FROM (SELECT INV.BillNo,CONVERT(DATETIME, INV.BillDate) AS BillDate, BD.InvDocDetailsID,inv.VoucherNo,inv.DocDate,BD.BatchID, B.BatchNumber, CONVERT(DATETIME, B.MfgDate) AS MfgDate, CONVERT(DATETIME, B.ExpiryDate) AS ExpiryDate, 
				 BD.ReleaseQuantity, 0 AS Quantity,MRPRate MRATE,RETAILRATE RRATE,STOCKISTRATE  SRATE'+@CustomQuery3+'
				FROM  INV_BatchDetails AS BD with(nolock)
                INNER JOIN INV_Batches AS B with(nolock) ON BD.BatchID = B.BatchID
                JOIN INV_product AS p with(nolock) ON B.ProductID = p.ProductID
                LEFT JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = B.BatchID and c.[CostCenterID]=16
                INNER JOIN INV_DocDetails AS INV with(nolock) ON INV.InvDocDetailsID = BD.InvDocDetailsID
                INNER JOIN COM_DocCCData AS CC with(nolock) ON BD.InvDocDetailsID = CC.InvDocDetailsID
                '+@CustomQuery1+'
               WHERE BD.VoucherType = 1 and BD.IsQtyIgnored=0 and B.STATUSID = 77 and B.ProductID='+ CONVERT(NVARCHAR(50),@PRODUCTID)
               
                if(@PrefExpiredValue is null or @PrefExpiredValue ='false')
                BEGIN
					set @SQL=@SQL+' and CONVERT(Datetime,B.ExpiryDate)'
					if(@PrefExcludePreExpiry is null or @PrefExcludePreExpiry ='false')
						set @SQL=@SQL+'-isnull(B.PreexpiryDays,0)'
					set @SQL=@SQL+'>='''+CONVERT(NVARCHAR(50),@DocDate)+''''
				END	
				if(@LocationID is not null and @LocationID>0)
					set @SQL=@SQL+' and CC.dcccnid2='+CONVERT(nvarchar,@LocationID)
				if(@DivisionID is not null and @DivisionID>0)
					set @SQL=@SQL+' and CC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
                
               if((@ConsolidatedBatches is not null and @ConsolidatedBatches ='true') and not (@PrefExpiredValue is null or @PrefExpiredValue ='false'))
					 SET @SQL=@SQL+' and (B.RetestDate is null or  CONVERT(Datetime,B.RetestDate)>='''+CONVERT(NVARCHAR(50),@DocDate)+''')'

               SET @SQL=@SQL+' UNION ALL
               SELECT  INV.BillNo,CONVERT(DATETIME, INV.BillDate) AS BillDate, BD.RefInvDocDetailsID InvDocDetailsID,INV.VoucherNo,inv.DocDate,BD.BatchID, B.BatchNumber, CONVERT(DATETIME, B.MfgDate) AS MfgDate, CONVERT(DATETIME, B.ExpiryDate) 
                                     AS ExpiryDate, 0 AS ReleaseQuantity, BD.Quantity,MRPRate MRATE,RETAILRATE RRATE,STOCKISTRATE  SRATE'+@CustomQuery3+'
               FROM   INV_BatchDetails AS BD with(nolock)
               INNER JOIN INV_Batches AS B with(nolock) ON BD.BatchID = B.BatchID
                JOIN INV_product AS p with(nolock) ON B.ProductID = p.ProductID
               LEFT JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = B.BatchID and c.[CostCenterID]=16
                INNER JOIN INV_DocDetails AS INV with(nolock) ON INV.InvDocDetailsID = BD.RefInvDocDetailsID
               INNER JOIN COM_DocCCData AS CC with(nolock) ON BD.InvDocDetailsID = CC.InvDocDetailsID
                '+@CustomQuery1+'
               WHERE BD.VoucherType = - 1 and BD.IsQtyIgnored=0 and B.STATUSID = 77 and B.ProductID='+ CONVERT(NVARCHAR(50),@PRODUCTID) 
               
                if(@PrefExpiredValue is null or @PrefExpiredValue ='false')
                BEGIN
					set @SQL=@SQL+' and CONVERT(Datetime,B.ExpiryDate)'
					if(@PrefExcludePreExpiry is null or @PrefExcludePreExpiry ='false')
						set @SQL=@SQL+'-isnull(B.PreexpiryDays,0)'
					set @SQL=@SQL+'>='''+CONVERT(NVARCHAR(50),@DocDate)+''''
				END	
				if(@LocationID is not null and @LocationID>0)
					set @SQL=@SQL+' and CC.dcccnid2='+CONVERT(nvarchar,@LocationID)
				if(@DivisionID is not null and @DivisionID>0)
					set @SQL=@SQL+' and CC.dcccnid1='+CONVERT(nvarchar,@DivisionID)
                if(@DOCID is not null and @DOCID>0)
					set @SQL=@SQL+' and CC.InvDocDetailsID not in (select InvDocDetailsID from INV_DocDetails with(nolock) where DOCID='+CONVERT(nvarchar,@DOCID)+') '

               if((@ConsolidatedBatches is not null and @ConsolidatedBatches ='true') and not (@PrefExpiredValue is null or @PrefExpiredValue ='false'))
					 SET @SQL=@SQL+' and (B.RetestDate is null or  CONVERT(Datetime,B.RetestDate)>='''+CONVERT(NVARCHAR(50),@DocDate)+''')'

               SET @SQL=@SQL+') AS T                    
               group by BillNo,BillDate,InvDocDetailsID,VoucherNo,DocDate,BatchID, BatchNumber, MfgDate, ExpiryDate'+@CustomQuery2+', MRATE,RRATE,SRATE) as bat
               where BalQty>0 order by ExpiryDate'
			   print @SQL 
			  exec(@SQL)
		
		end
		else
		begin
		
			set @SQL='select * from (
			select BATCHNUMBER,BatchID,CONVERT(DATETIME,MfgDate) MfgDate,CONVERT(DATETIME,ExpiryDate) ExpiryDate'+@CustomQuery3+',
			(isnull((select sum(ReleaseQuantity) from INV_BatchDetails a with(nolock)
			join com_docccdata d with(nolock) on d.invdocdetailsid=a.invdocdetailsid		
			where vouchertype=1 and a.IsQtyIgnored=0 '
			
			if(@LocationID is not null and @LocationID>0)
				set @SQL=@SQL+'and d.dcccnid2='+CONVERT(nvarchar,@LocationID)
			if(@DivisionID is not null and @DivisionID>0)
				set @SQL=@SQL+' and d.dcccnid1='+CONVERT(nvarchar,@DivisionID)
			
			set @SQL=@SQL+' and BatchID=b.BatchID),0)-
			isnull((select sum(Quantity) from INV_BatchDetails a with(nolock)
			join com_docccdata d with(nolock) on d.invdocdetailsid=a.invdocdetailsid		
			where vouchertype=-1 and a.IsQtyIgnored=0 '
			if(@LocationID is not null and @LocationID>0)
				set @SQL=@SQL+'and d.dcccnid2='+CONVERT(nvarchar,@LocationID)
			if(@DivisionID is not null and @DivisionID>0)
				set @SQL=@SQL+' and d.dcccnid1='+CONVERT(nvarchar,@DivisionID)
			if(@DOCID is not null and @DOCID>0)
					set @SQL=@SQL+' and a.InvDocDetailsID not in (select InvDocDetailsID from INV_DocDetails with(nolock) where DOCID='+CONVERT(nvarchar,@DOCID)+') '

			set @SQL=@SQL+'  and BatchID=b.BatchID),0) ) as BalQty,'
			set @SQL=@SQL+'  MRPRate MRATE,RETAILRATE RRATE,STOCKISTRATE  SRATE from dbo.INV_Batches B with(nolock)
							 LEFT JOIN COM_CCCCData AS c with(nolock) ON c.[NodeID] = B.BatchID and c.[CostCenterID]=16'+@CustomQuery1							  
			set @SQL=@SQL+'  WHERE b.STATUSID = 77 and b.ProductID='+CONVERT(nvarchar,@PRODUCTID)
			
                if(@PrefExpiredValue is null or @PrefExpiredValue ='false')
                BEGIN
					set @SQL=@SQL+' and CONVERT(Datetime,ExpiryDate)'
					if(@PrefExcludePreExpiry is null or @PrefExcludePreExpiry ='false')
						set @SQL=@SQL+'-isnull(PreexpiryDays,0)'
					set @SQL=@SQL+'>='''+CONVERT(NVARCHAR(50),@DocDate)+''''
				END	
			set @SQL=@SQL+') as ttt'
			set @SQL=@SQL+'  where BalQty>0 order by ExpiryDate'
			 print @SQL
			exec(@SQL)
		end
    end
   if(@DOCDetailsID>0)
   begin
		select BatchDetailsID,BatchID,Quantity,HoldQuantity,ReleaseQuantity,RefBatchDetailsID 
		from INV_BatchDetails with(nolock)
		where InvDocDetailsID=@DOCDetailsID
   end
   else 
   begin
		select BatchDetailsID,BatchID,Quantity,HoldQuantity,ReleaseQuantity ,RefBatchDetailsID
		from INV_BatchDetails with(nolock)
		where 1<>1
   end
   
	select * from COM_CostCenterPreferences with(nolock)
    where CostCenterID=16
    
    select b.SysColumnName BatchCol,c.SysColumnName BaseCol  from COM_DocumentBatchLinkDetails a
	join ADM_CostCenterDef b with(nolock) on a.BatchColID=b.CostCenterColID
	join ADM_CostCenterDef c with(nolock) on a.CostCenterColIDBase=c.CostCenterColID
	where a.[CostCenterID]=@CostCenterID  and BatchColID>1572
	
	
		
    select a.CostCenterID, a.CostCenterColID,  UserColumnName,  case when SysColumnName='ExpiryDate' then 'ExpDate'
	when SysColumnName='MRPRate' then 'MRate'
	when SysColumnName='RetailRate' then 'RRate'
	when SysColumnName='StockistRate' then 'SRate'
	when SysColumnName='HoldQuantity' then 'Hold'
	when SysColumnName='ReleaseQuantity' then 'Release' else SysColumnName end Name,
    UserColumnType, g.ColumnWidth, g.ColumnOrder, A.IsEditable ,    UserDefaultValue                   
    from adm_costcenterdef a 
    join    ADM_GridViewColumns g on a.CostCenterColID=g.CostCenterColID and g.GridViewID=@GridviewID           
    where a.CostCenterID=16                         
    order by g.ColumnOrder
	
	if(@VoucherType=1)
	BEGIN
		SELECT  distinct C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,                              
		C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,isnull(C.IsVisible,1) IsVisible,C.ColumnCCListViewTypeID,                              
		QuickAddOrder,C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName , C.RowNo,C.ColumnNo, C.ColumnSpan,C.TextFormat,C.SectionSeqNumber                             
		FROM ADM_CostCenterDef C WITH(NOLOCK)                              
		LEFT JOIN COM_LanguageResources R ON R.ResourceID=C.ResourceID AND R.LanguageID=1                              
		WHERE C.CostCenterID = 16 AND ShowInQuickAdd=1    and C.SysColumnName not in ('Depth','ParentID')                             
		AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)                              
		ORDER BY QuickAddOrder
	
		select * from com_costcentercodedef WHERE CostCenterID=16                                           
		
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
