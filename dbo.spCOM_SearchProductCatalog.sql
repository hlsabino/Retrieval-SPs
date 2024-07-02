USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SearchProductCatalog]
	@GridViewID [int],
	@WHere [nvarchar](max),
	@QtyWhere [nvarchar](max),
	@DocDate [datetime],
	@SearchType [int],
	@fulltextWhere [nvarchar](max),
	@Fultextjoin [nvarchar](max),
	@OtherDimSelect [nvarchar](max),
	@UomSelect [nvarchar](max),
	@LocationWhere [nvarchar](max) = NULL,
	@IsPrev [bit],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON;    

	declare @sql nvarchar(max) ,@strColumns nvarchar(max),@STRJOIN nvarchar(max),@I int, @Cnt int,@CostCenterColID INT,@IsContDisplayed bit,@CostCenterTableName nvarchar(100)
	declare @CCID INT,@ColumnCostCenterID INT,@SysColumnName nvarchar(100),@IsColumnUserDefined bit,@ColumnDataType nvarchar(50),@ColCostCenterPrimary nvarchar(100),@CC int
	declare @tblList TABLE (ID int identity(1,1),CostCenterColID INT)    
	declare @productNameExists bit,@productCodeExists bit,@PrefValue nvarchar(100),@featureid INT,@table Nvarchar(100),@STKDIM int,@chkCnT int

	select @STKDIM=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='POSItemCodeDimension'
	and Value is not null and isnumeric(Value)=1

	SELECT @featureid=a.FeatureID,@table=b.TableName,@chkCnT=ChunkCount FROM [ADM_GridView] a WITH(NOLOCK)
	join ADM_Features b WITH(NOLOCK) on a.FeatureID=b.FeatureID
	WHERE GRIDVIEWID=@GridViewID

	--Read CostCenterColUMNS FROM  GridViewColumns into temporary table  
	INSERT INTO @tblList  
	select costcentercolid from ADM_GridViewColumns  WITH(NOLOCK) 
	WHERE GRIDVIEWID =@GridViewID
	and columntype=2 and costcentercolid>0
	
	--Set loop initialization varaibles  
	SELECT @I=1, @Cnt=count(*) FROM @tblList    
	SET @CC=0   
	set @IsContDisplayed=0
	SET @strColumns=''
	SET @STRJOIN=''
	WHILE(@I<=@Cnt)    
	BEGIN     

		SELECT @CostCenterColID=CostCenterColID FROM @tblList  WHERE ID=@I    
		SET @I=@I+1  
		SET @ColumnCostCenterID=0  
		SET @SysColumnName=''    
		SET @IsColumnUserDefined=0  
		SELECT @SysColumnName=SysColumnName,@ColumnDataType=ColumnDataType,@IsColumnUserDefined=IsColumnUserDefined,
		@ColumnCostCenterID=ColumnCostCenterID,@CCID=CostCenterID  
		FROM ADM_CostCenterDef  WITH(nolock) WHERE CostCenterColID=@CostCenterColID  

		SET @strColumns=@strColumns+','  
		
		IF(@ColumnCostCenterID IS NOT NULL AND @ColumnCostCenterID>0)--IF COSTCENTER COLUMN  
		BEGIN  

			--GETTING COLUMN COSTCENTER TABLE  
			SET @CostCenterTableName=(SELECT Top 1 TableName FROM ADM_features with(nolock) WHERE Featureid=@ColumnCostCenterID)     

			if(@ColumnCostCenterID=2)  
			BEGIN       
				set @ColCostCenterPrimary='AccountID'  
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.AccountName as '+@SysColumnName  
			END
			ELSE if(@ColumnCostCenterID=3)  
			BEGIN      
				set @ColCostCenterPrimary='ProductID'  
				IF @SysColumnName='ProductGroup'
					SET @SysColumnName='ParentID'					
				if(@STKDIM=@featureid)       
				BEGIN	
					SET @strColumns=@strColumns+'PE.ProductName '
					continue;		
				END
				ELSE
					SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ProductName as '+@SysColumnName   
			END  
			ELSE if(@ColumnCostCenterID=11)  
			BEGIN  
				--set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.UnitName  '
				set @ColCostCenterPrimary='UOMID'  
				if(@UomSelect<>'')
					SET @strColumns=@strColumns+@UomSelect+' else CC'+CONVERT(NVARCHAR(10),@CC)+'.UnitName END as '+@SysColumnName   
				ELSE	
					SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.UnitName as '+@SysColumnName   
			END  
			ELSE if(@ColumnCostCenterID=12)  
			BEGIN  
				--set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Name  '
				set @ColCostCenterPrimary='CurrencyID'  
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME as '+@SysColumnName 
			END  
			ELSE if(@ColumnCostCenterID=17)  
			BEGIN  
				--set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BarcodeName  '
				set @ColCostCenterPrimary='BarcodeID'  
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BarcodeName as '+@SysColumnName 
			END  
			ELSE if(@ColumnCostCenterID=16)  
			BEGIN  
				--set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BatchNumber  '
				set @ColCostCenterPrimary='BatchID'  
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BatchNumber as '+@SysColumnName 
			END
			ELSE  if(@ColumnCostCenterID=113)  
			BEGIN    
				set @ColCostCenterPrimary='StatusID'  
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Status as '+@SysColumnName 
			END   
			ELSE   
			BEGIN    
				set @ColCostCenterPrimary='NodeID'  
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME as '+@SysColumnName 
			END  

			IF(@IsColumnUserDefined=0)  
			BEGIN  
				SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)  
				+' WITH(NOLOCK) ON P.'+@SysColumnName+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary  
			END  
			ELSE 
			BEGIN  
				IF @SysColumnName LIKE 'ptAlpha%'
				BEGIN
					SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)  
					+' WITH(NOLOCK) ON E.'+@SysColumnName+'= CONVERT(NVARCHAR,CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+')'
				END
				ELSE IF @ColumnCostCenterID>50000
				BEGIN
					SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)  
					+' WITH(NOLOCK) ON C.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary
				END
			END  

			--INCREMENT COSTCENTER COLUMNS COUNT  
			SET @CC=@CC+1  

		END 
		ELSE IF(@ColumnCostCenterID IS NOT NULL AND @ColumnCostCenterID=0 AND @CCID=110)
		BEGIN
			SET @strColumns=@strColumns+'Addr.'+@SysColumnName
		END
		ELSE IF(@IsColumnUserDefined IS NOT NULL AND @IsColumnUserDefined = 1 AND @SysColumnName not like '%alpha%')   
		BEGIN     
			SET @strColumns=@strColumns+'Cont.'+@SysColumnName
			if(@IsContDisplayed=0)
			begin
				SET @IsContDisplayed=1
				if(@featureid=3)
					SET @STRJOIN=@STRJOIN+' left JOIN COM_Contacts Cont WITH(NOLOCK) ON p.productid=Cont.FeaturePK and Cont.FeatureID=3 and Cont.AddressTypeID=1'
				else if(@featureid=2)
					SET @STRJOIN=@STRJOIN+' left JOIN COM_Contacts Cont WITH(NOLOCK) ON p.AccountID=Cont.FeaturePK and Cont.FeatureID=2 and Cont.AddressTypeID=1'
				ELSE if(@featureid>50000)
					SET @STRJOIN=@STRJOIN+' left JOIN COM_Contacts Cont WITH(NOLOCK) ON p.NodeID=Cont.FeaturePK and Cont.FeatureID='+CONVERT(nvarchar,@featureid)+' and Cont.AddressTypeID=1'	
			end
		END   
		ELSE IF(@IsColumnUserDefined IS NOT NULL AND @IsColumnUserDefined = 1 AND @SysColumnName like '%alpha%')   
		BEGIN      
			SET @strColumns=@strColumns+'E.'+@SysColumnName   
		END  
 		ELSE IF(@SysColumnName='QOH' and @IsColumnUserDefined=0  )          
		BEGIN          
			SET @strColumns=@strColumns +'(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i  WITH(NOLOCK)
			join COM_DocCCData d on i.InvDocDetailsID=d.InvDocDetailsID
			WHERE ProductID= P.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1)
			and DocDate<='+CONVERT(nvarchar,CONVERT(float,@DocDate))
			if(@QtyWhere <>'')  
				SET @strColumns=@strColumns +' and '+@QtyWhere  
			SET @strColumns=@strColumns +') as QOH'     
		END  
		ELSE IF(@SysColumnName='HOLDQTY' and @IsColumnUserDefined=0 )          
		BEGIN   
			set @PrefValue =''
			select @PrefValue=Value from Adm_globalPreferences WITH(NOLOCK) where Name='HoldResCancelledDocs'    
		
			SET @strColumns=@strColumns +'( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from 
			(SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
			 if(@PrefValue<>'')
				set @strColumns=@strColumns+' or l.Costcenterid in('+@PrefValue+')'
				
			 set @strColumns=@strColumns+') then l.Quantity else l.ReserveQuantity end),0) release
			FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID 
			left join INV_DocDetails l  WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID
			WHERE D.ProductID=P.ProductID AND D.IsQtyIgnored=1 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND convert(datetime,D.DocDate)<='+CONVERT(nvarchar,CONVERT(float,@DocDate))
	       
			if(@QtyWhere <>'')  
				SET @strColumns=@strColumns +' and '+@QtyWhere  
			SET @strColumns=@strColumns +' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp) as HOLDQTY'                      
	     
		END 
		ELSE IF(@SysColumnName='RESERVEQTY' and @IsColumnUserDefined=0 )          
		BEGIN   
			set @PrefValue =''
			select @PrefValue=Value from Adm_globalPreferences WITH(NOLOCK) where Name='HoldResCancelledDocs'    

			SET @strColumns=@strColumns +'( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from 
			(SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
			 if(@PrefValue<>'')
				set @strColumns=@strColumns+' or l.Costcenterid in('+@PrefValue+')'
				
			 set @strColumns=@strColumns+') then l.Quantity else l.ReserveQuantity end),0) release
			FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID 
			left join INV_DocDetails l  WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID
			WHERE D.ProductID=P.ProductID AND D.IsQtyIgnored=1 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND convert(datetime,D.DocDate)<='+CONVERT(nvarchar,CONVERT(float,@DocDate))
	            
			if(@QtyWhere <>'')  
				SET @strColumns=@strColumns +' and '+@QtyWhere  
			SET @strColumns=@strColumns +' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp) as RESERVEQTY'            
	    
		END 	  
		ELSE IF(@SysColumnName='StatusID')  
		BEGIN     
			SET @strColumns=@strColumns+'S.ResourceData as StatusID'  
			SET @STRJOIN=@STRJOIN+' JOIN COM_Status SS WITH(NOLOCK) ON P.StatusID=SS.StatusID  
			JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=SS.ResourceID AND S.LanguageID='+convert(NVARCHAR(10),@LangID)  
		END  
		 
		ELSE IF(@SysColumnName='ProductTypeID')  
		BEGIN  
			--if @CostCenterID=2
			--set @tempgroup=@tempgroup+'PT.ResourceData , '
			SET @strColumns=@strColumns+'PT.ResourceData as ProductTypeID'  
			SET @STRJOIN=@STRJOIN+' JOIN INV_ProductTypes PP WITH(NOLOCK) ON P.ProductTypeID=PP.ProductTypeID  
			JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=PP.ResourceID AND PT.LanguageID='+ convert(NVARCHAR(10),@LangID)  
		END  
		ELSE IF(@SysColumnName='ValuationID')  
		BEGIN  
			SET @strColumns=@strColumns+'VT.ResourceData as ValuationID'  
			SET @STRJOIN=@STRJOIN+' JOIN INV_ValuationMethods VV WITH(NOLOCK) ON P.ValuationID=VV.ValuationID  
			JOIN COM_LanguageResources VT WITH(NOLOCK) ON VT.ResourceID=VV.ResourceID AND VT.LanguageID='+ convert(NVARCHAR(10),@LangID)  
		END       
		ELSE IF(@SysColumnName <> '')  
		BEGIN  
			if(@ColumnDataType is not null and @ColumnDataType='DATE')  
			begin 
				SET @strColumns=@strColumns+'convert(nvarchar(12),Convert(datetime,P.'+@SysColumnName+'),106) as '+@SysColumnName  
			end 
			else  
			begin  
				if(@SysColumnName='ProductName' or @SysColumnName='AccountName' or @SysColumnName='Name')
					set @productNameExists=1 
				if(@SysColumnName='ProductCode' or @SysColumnName='AccountCode' or @SysColumnName='Code')
					set @productCodeExists=1
				SET @strColumns=@strColumns+'P.'+@SysColumnName  
			end
		END
	END
    if(@Fultextjoin is not null and @Fultextjoin<>'')
		set @STRJOIN= @STRJOIN+@Fultextjoin
    
    if(@fulltextWhere is not null and @fulltextWhere<>'')
    begin
		if(@WHere <>'')
			set @WHere= @WHere+' and ('+@fulltextWhere+')'
		else
			set @WHere= @fulltextWhere
    end
    
    select @PrefValue=Value from ADM_GlobalPreferences  with(nolock) where name='HideBlockedAccountsandProducts'  
	if(@PrefValue is not null and @PrefValue='True')  
	begin 
		if(@WHere <>'')
			set @WHere= @WHere+' and p.StatusID<>32 '
		else	
			set @Where=' p.StatusID<>32 '		
	end 

	if(@featureid=3)		
		set @sql='select distinct top '+convert(nvarchar,@chkCnT)+' p.productid'+@strColumns+@OtherDimSelect+',P.ParentID, isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i WITH(NOLOCK)
				 join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID
				 WHERE ProductID= P.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1)),0) as onHand  
				 from INV_Product p with(nolock)  
				 join INV_ProductExtended E with(nolock) on E.ProductID=p.ProductID  
				 join COM_CCCCData C with(nolock) on C.NodeID=p.ProductID  AND C.CostCenterID=3 '
	else if(@featureid=2)
		set @sql='select top '+convert(nvarchar,@chkCnT)+' p.AccountID as productid'+@strColumns+' from Acc_accounts p with(nolock)  
				 join Acc_accountsExtended E with(nolock) on E.AccountID=p.AccountID  
				 join COM_CCCCData C with(nolock) on C.NodeID=p.AccountID  AND C.CostCenterID=2 
				 LEFT JOIN COM_Address Addr WITH(NOLOCK) ON P.AccountID=Addr.FeaturePK and Addr.FeatureID=2 and Addr.AddressTypeID=1 '
	else if(@featureid>50000)
	BEGIN
		set @sql='select top '+convert(nvarchar,@chkCnT)+' p.NodeID as productid'+@strColumns+' from '+@table+' p with(nolock) '
		
		if(@STKDIM is null or @STKDIM='' or @STKDIM!=@featureid)	 
			set @sql= @sql+' join COM_CCCCData C with(nolock) on C.NodeID=p.NodeID  AND C.CostCenterID='+convert(nvarchar,@featureid)
		else
			set @sql= @sql+' join INV_Product PE with(nolock) on PE.ProductID=p.ProductID '
	END			 
  
	if(@LocationWhere is not null and @LocationWhere<>'')
	BEGIN
		set @STRJOIN=@STRJOIN+' JOIN  COM_CostCenterCostCenterMap CCMl with(nolock) on (p.ProductID =CCMl.ParentNodeID and CCMl.ParentCostCenterID = 3)'
		if(@WHere <>'')
			set @WHere= @WHere+' and  '
		set @WHere=@WHere+'  ((CCMl.CostCenterID=50002 and CCMl.NodeID in('+@LocationWhere+'))  OR p.ParentID =0) '
	END
	
	set @sql=@sql+@STRJOIN 

	if(@WHere <>'')
	begin
		set @sql=@sql+' where ('+@WHere+')'
		
		if (@SearchType=1 or @SearchType=3)
		begin
			declare @subdimQuery nvarchar(max),@subGroupQuery nvarchar(max)
			declare @SameParentAsSubstitue nvarchar(20),@SameDimensionAsSubstitute nvarchar(200)
			select @SameParentAsSubstitue=Value from com_costcenterpreferences with(nolock) where CostCenterID=3 and Name='ProductsOfSameParentAsSubstitue'
			select @SameDimensionAsSubstitute=Value from com_costcenterpreferences with(nolock) where CostCenterID=3 and Name='SameDimensionAsSubstitute'
		
			--Include Products Of Same Parent As Substitue
			if @SameParentAsSubstitue='True' AND (@SameDimensionAsSubstitute is null or @SameDimensionAsSubstitute='')
			begin
				set @subGroupQuery='P.ParentID IN (
				select distinct p.ParentID from INV_Product p with(nolock)  
				join INV_ProductExtended E with(nolock) on E.ProductID=p.ProductID  
				join COM_CCCCData C with(nolock) on C.NodeID=p.ProductID AND C.CostCenterID=3 ' +@STRJOIN 
				set @subGroupQuery=@subGroupQuery+' where ('+@WHere+')'		
				set @subGroupQuery=@subGroupQuery+')'
			end
			
			--Include Products Of Same Dimension As Substitute		
			if @SameDimensionAsSubstitute is not null and @SameDimensionAsSubstitute<>''
			begin
				declare @subdimwhere nvarchar(max),@selectCCID nvarchar(max)
				declare @TblDimSub as table(DIM int)
				insert into @TblDimSub
				exec SPSplitString  @SameDimensionAsSubstitute,';'
				set @subdimwhere=''
				set @selectCCID=''
				select @selectCCID=@selectCCID+',c.CCNID'+CONVERT(nvarchar,DIM-50000),@subdimwhere=@subdimwhere+' and c.CCNID'+CONVERT(nvarchar,DIM-50000)+'=t.CCNID'+CONVERT(nvarchar,DIM-50000) from @TblDimSub
				select @selectCCID=SUBSTRING(@selectCCID,2,len(@subdimwhere)-1)
				if @SameParentAsSubstitue='True'
				begin
					set @selectCCID=@selectCCID+',P.ParentID'
					set @subdimwhere=@subdimwhere+' and t.ParentID=P.ParentID'
				end
				
				set @subdimQuery='
				inner join (select distinct '+@selectCCID+' from INV_Product p with(nolock)
				join INV_ProductExtended E with(nolock) on E.ProductID=p.ProductID
				join COM_CCCCData C with(nolock) on C.NodeID=p.ProductID AND C.CostCenterID=3 ' +@STRJOIN 
				set @subdimQuery=@subdimQuery+' where ('+@WHere+')) as t on C.CostCenterID=3'+@subdimwhere
				
			end
			
			if(@subdimQuery is not null)
			begin
				--set @sql=@sql+' OR '+@subdimQuery
				set @sql=@sql+' 
				UNION
				select p.productid'+@strColumns+@OtherDimSelect+',P.ParentID, isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i WITH(NOLOCK)
				join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID
				WHERE ProductID= P.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1)),0) as onHand  from INV_Product p with(nolock)
				join INV_ProductExtended E with(nolock) on E.ProductID=p.ProductID  
				join COM_CCCCData C with(nolock) on C.NodeID=p.ProductID AND C.CostCenterID=3 ' +@STRJOIN  
				+@subdimQuery+' and P.Isgroup=0 and p.StatusID<>32'			
			end
			else if(@subGroupQuery is not null)
			begin			
				set @sql=@sql+' OR '+@subGroupQuery
			end
		end
	end

	if(@SearchType=1 or @SearchType=3)  
	begin  
	   
		set @sql=@sql+' 
		UNION
		select p.productid'+@strColumns+@OtherDimSelect+',P.ParentID, isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i WITH(NOLOCK)
		join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID
		WHERE ProductID= P.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1)),0) as onHand  from INV_Product p with(nolock)
		join INV_ProductExtended E with(nolock) on E.ProductID=p.ProductID  
		join COM_CCCCData C with(nolock) on C.NodeID=p.ProductID AND C.CostCenterID=3 ' +@STRJOIN  
	    
		set @sql=@sql+' where p.productid in(select s.ProductID from INV_ProductSubstitutes s with(nolock)
		WHERE S.SubstituteGroupID IN 
		(SELECT SubstituteGroupID FROM INV_ProductSubstitutes with(nolock) WHERE PRODUCTID in ((select sp.productid from INV_Product sp with(nolock)
		join INV_ProductExtended sE with(nolock) on sE.ProductID=sp.ProductID
		join COM_CCCCData sC with(nolock) on sC.NodeID=sp.ProductID AND sC.CostCenterID=3'  
		
		if(@WHere <>'')  
		  set @sql=@sql+' where '+@WHere  
		
		set @sql=@sql+'))))'  
	end
	  
	if(@SearchType=2 or @SearchType=3)  
	begin  
		declare @prefval nvarchar(50),@linkcc INT  
		select @prefval=value from COM_CostCenterPreferences  with(nolock) where CostCenterID=3 and name='LinkedProductDimension'  
		if(@prefval is not null and @prefval<>'')  
			set @linkcc =convert(INT,@prefval)  

		if(@linkcc>0)  
		begin  
			set @sql=@sql+' 
			UNION
			select p.productid'+@strColumns+@OtherDimSelect+',P.ParentID, isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i  WITH(NOLOCK)
			join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID
			WHERE ProductID= P.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1)),0) as onHand  from INV_Product p with(nolock)  
			join INV_ProductExtended E with(nolock) on E.ProductID=p.ProductID  
			join COM_CCCCData C with(nolock) on C.NodeID=p.ProductID  AND C.CostCenterID = 3 ' +@STRJOIN  
		      
			set @sql=@sql+' where p.productid in(select l.ProductID from  INV_LinkedProducts l with(nolock) where CostCenterID='+convert(nvarchar,@linkcc)+' and NodeID in (select CCNID'+convert(nvarchar,(@linkcc-50000))+' from INV_Product lp with(nolock)  
			join INV_ProductExtended lE with(nolock) on lE.ProductID=lp.ProductID  
			join COM_CCCCData lC with(nolock) on lC.NodeID=lp.ProductID  AND C.CostCenterID = 3'  
			if(@WHere <>'')  
			set @sql=@sql+' where '+@WHere  
			set @sql=@sql+'))'  
		end   
	end  
 
	if(@productCodeExists is not null and @productCodeExists=1)
	BEGIN	
		if(@featureid=3)		
			set @sql=@sql+' Order by p.productCode'
		ELSE if(@featureid=2)
			set @sql=@sql+' Order by p.AccountCode'
		ELSE if(@featureid>50000)
			set @sql=@sql+' Order by p.Code'

		if(@IsPrev=1)	
			set @sql=@sql+' desc'
	END		
	else if(@productNameExists is not null and @productNameExists=1)
	BEGIN	
		if(@featureid=3)		
			set @sql=@sql+' Order by p.productName'
		ELSE if(@featureid=2)
			set @sql=@sql+' Order by p.AccountName'
		ELSE if(@featureid>50000)
			set @sql=@sql+' Order by p.Name'
			
		if(@IsPrev=1)	
			set @sql=@sql+' desc'
	END

	print (@sql)
	exec(@sql)   

	if(@featureid=3)		
	BEGIN      
		declare @IsGroup bit
		select @IsGroup=CONVERT(bit,value) from com_costcenterpreferences with(nolock) where CostCenterID=3 and Name='ShowgroupsatProductCatalog'      
		if(@IsGroup=1)
			select ProductID, ProductCode, ProductName from INV_Product with(nolock) where IsGroup=1
	END
   
SET NOCOUNT OFF;        
RETURN 1        
END TRY        
BEGIN CATCH          
	--Return exception info [Message,Number,ProcedureName,LineNumber]          
	IF ERROR_NUMBER()=50000        
	BEGIN        
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
	END        
	ELSE        
	BEGIN        
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine        
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
	END        
SET NOCOUNT OFF          
RETURN -999           
END CATCH
GO
