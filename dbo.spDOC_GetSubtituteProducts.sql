USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetSubtituteProducts]
	@ProductID [int] = 0,
	@CCXML [nvarchar](max),
	@DocDate [datetime],
	@DocDetailsID [int] = 0,
	@CostCenterID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON      
      
	DECLARE @SQL NVARCHAR(MAX),@XML XML,@WHERE NVARCHAR(MAX),@ParentPrefValue nvarchar(100),@PrefValue nvarchar(100),@NID INT,@Join nvarchar(max),@QOH float
	Declare @i int ,@CNT int,@TableName nvarchar(100),@ColID INT,@Colname nvarchar(100),@CustomCols nvarchar(max),@EnableSubstituteType nvarchar(20),@SubsQOH nvarchar(20)
	SET @XML=@CCXML   
	
	select @ParentPrefValue=Value from com_costcenterpreferences with(nolock) where CostCenterID=3 and Name='ProductsOfSameParentAsSubstitue'
	select @EnableSubstituteType=Value from com_costcenterpreferences with(nolock) where CostCenterID=3 and Name='EnableSubstituteType'
	
	select @SubsQOH=PrefValue from COM_DocumentPreferences with(nolock) where CostCenterID=@CostCenterID and prefName='EnableSubtitutesQty'
	
	
         
	DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId INT)      
	INSERT INTO @tblCC(CostCenterID,NodeId)      
	SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')      
	FROM @XML.nodes('/XML/Row') as Data(X)      
	        
    declare @TEMP TABLE (ID INT IDENTITY(1,1),ColID INT,SYSCOLUMNNAME NVARCHAR(100),TableName NVARCHAR(100),CCID int,UserColumnName NVARCHAR(200),ColumnWidth int,ColumnOrder int,usercolumntype nvarchar(50))
	  
	INSERT INTO @TEMP 
	select a.CostCenterColID,b.SysColumnName,c.TableName,isnull(c.FeatureID,0),case when b.UserColumnName is null then c.Name else r.resourcedata end,a.ColumnWidth,a.ColumnOrder,usercolumntype
	from adm_gridviewcolumns a with(nolock)
	left join ADM_CostCenterDef b with(nolock) on a.CostCenterColID=b.CostCenterColID
	left join com_languageresources r with(nolock) on r.resourceid=b.resourceid and r.languageid=@LangID
	left join  adm_features c with(nolock) on c.FeatureID=a.CostCenterColID and c.FeatureID between 50001 and 50100
	where GridViewID=311
       
	
    set @WHERE=''      
  
    select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='EnableLocationWise'      
          
    if(@PrefValue='True' and exists (select NodeId from @tblCC where CostCenterID=50002))      
    begin      
	  set @PrefValue=''    
	  select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Location Stock'      
	  if(@PrefValue='True')    
	  begin    
		 select @NID=NodeId from @tblCC where CostCenterID=50002      
		 set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@NID)      
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
		set @WHERE =@WHERE+' and dcCCNID1='+CONVERT(nvarchar,@NID)       
	  end     
      
    end      
        
        
    set @PrefValue=''    
    select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise stock'      
        
    if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0  and exists (select NodeId from @tblCC where CostCenterID=convert(INT,@PrefValue)))      
    begin      
		select @NID=NodeId from @tblCC where CostCenterID=convert(INT,@PrefValue)      
		set @PrefValue=convert(INT,@PrefValue)-50000             
		set @WHERE =@WHERE+' and dcCCNID'+@PrefValue+'='+CONVERT(nvarchar,@NID)      
    end               
         
     if(@DocDetailsID>0)
     begin 
		set @WHERE =@WHERE+' and D.InvDocDetailsID<>'+CONVERT(nvarchar,@DocDetailsID)	 
     end
     
    if(@SubsQOH is not null and @SubsQOH='true')
	BEGIN
		set @SQL='set @QOH=(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)        
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
		WHERE D.ProductID = '+convert(nvarchar,@ProductID)+' AND IsQtyIgnored=0 and D.StatusID=369 AND D.DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))        
		set @SQL=@SQL+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
		      
		EXEC sp_executesql @SQL, N'@QOH float OUTPUT', @QOH OUTPUT        
		
		if(@QOH>0.001)
		BEGIN
			select 1 where 1=2
			select 1 where 1=2
			RETURN 1   
		END	
	
	END     
  
    set @Join=''
    set @CustomCols='' 
    set @i=1
	select @CNT=count(ID) from @TEMP
	while (@i<=	@CNT)
	begin
		set @TableName=''	
		select @ColID=ColID,@Colname=SYSCOLUMNNAME,@TableName=TableName,@NID=CCID from @TEMP where ID=@i
		
		set @CustomCols=@CustomCols+','
		if(@TableName is not null and @TableName<>'')
		BEGIN
			set @Join=@Join+' left JOIN '+@TableName+' d'+CONVERT(nvarchar,@i)+'  WITH(NOLOCK) on  d'+CONVERT(nvarchar,@i)+'.NodeID=c.CCNID'+CONVERT(nvarchar,(@NID-50000))
			set @CustomCols=@CustomCols+'d'+CONVERT(nvarchar,@i)+'.Name as ['+CONVERT(nvarchar,@ColID)+']'
		END
		ELSE IF(@Colname='ProductGroup')
		BEGIN
			set @Join=@Join+' left JOIN Inv_product PP  WITH(NOLOCK) on  PPP.ParentID=PP.ProductID '
			set @CustomCols=@CustomCols+'PP.ProductName as [ProductGroup]'

		END
		ELSE IF(@ColID=26428)
			set @CustomCols=@CustomCols+'isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i WITH(NOLOCK)
            join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID
			WHERE ProductID= PPP.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1)),0) as onHand'   
		ELSE IF(@Colname='QOH')
			 set @CustomCols=@CustomCols+'(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i WITH(NOLOCK)  
						join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID  
						WHERE ProductID= PPP.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1)						
					'+@WHERE+' AND  DocDate < = '''+convert(nvarchar,convert(float,@DocDate))+''' )  as QOH'
		else
			set @CustomCols=@CustomCols+'PPP.'+@Colname
		
		set @i=@i+1
	END  		


	set @SQL='SELECT DISTINCT PPP.ProductID ProductName_Key,ISNULL(S.SNo,0) SNo'+@CustomCols
	if @EnableSubstituteType='True'
		set @SQL=@SQL+',SType.Name SubstituteType,SType.NodeID STypeID'
		
	set @SQL=@SQL+' FROM INV_ProductSubstitutes S WITH(NOLOCK)     
	INNER JOIN INV_Product P WITH(NOLOCK) on '
	if @EnableSubstituteType='True'
		set @SQL=@SQL+'S.SProductID=P.ProductID'
	else
		set @SQL=@SQL+'S.ProductID=P.ProductID' 
	
	SET @SQL=@SQL+' left join  INV_Product PPP WITH(NOLOCK) on PPP.LFT BETWEEN P.LFT AND P.RGT'
	set @SQL=@SQL+' left JOIN COM_CCCCData c WITH(NOLOCK) on c.NodeID=PPP.ProductID  and c.CostCenterID=3 '+@Join
	
	if @EnableSubstituteType='True'
		set @SQL=@SQL+' JOIN COM_Lookup SType WITH(NOLOCK) on S.SubstituteGroupID=SType.NodeID'
	else
		set @SQL=@SQL+' JOIN INV_ProductSubstitutes SP WITH(NOLOCK) on s.SubstituteGroupID=sp.SubstituteGroupID'
	
	set @SQL=@SQL+' WHERE '
	if @EnableSubstituteType='True'
		set @SQL=@SQL+' S.ProductID=' + convert(varchar,@ProductID)
	else
		set @SQL=@SQL+' sp.ProductID=' + convert(varchar,@ProductID)
	
	set @SQL=@SQL+' AND PPP.ISGROUP=0'
	
	
	--To Get Reverse Of Substitute
	if @EnableSubstituteType='True' and exists (select Value from com_costcenterpreferences with(nolock) where CostCenterID=3 and Name='AssignedPrdAsSubstitute' and Value='True')
	BEGIN
		set @SQL=@SQL+' 
		UNION
		SELECT DISTINCT PPP.ProductID ProductName_Key,ISNULL(S.SNo,0) SNo'+@CustomCols+',SType.Name SubstituteType,SType.NodeID STypeID'
		set @SQL=@SQL+' FROM INV_ProductSubstitutes S WITH(NOLOCK)     
		INNER JOIN INV_Product P WITH(NOLOCK) on S.SProductID=P.ProductID
		INNER JOIN INV_Product SP WITH(NOLOCK) on S.SProductID=SP.ProductID 
INNER JOIN INV_Product PPP WITH(NOLOCK) on S.ProductID=PPP.ProductID
INNER JOIN INV_Product GSP WITH(NOLOCK) on GSP.LFT BETWEEN SP.LFT AND SP.RGT '
		
		set @SQL=@SQL+' left JOIN COM_CCCCData c WITH(NOLOCK) on c.NodeID=PPP.ProductID  and c.CostCenterID=3 '+@Join
		set @SQL=@SQL+' JOIN COM_Lookup SType WITH(NOLOCK) on S.SubstituteGroupID=SType.NodeID'
			
		set @SQL=@SQL+' WHERE '
		set @SQL=@SQL+' GSP.ProductID=' + convert(varchar,@ProductID)
		set @SQL=@SQL+' AND PPP.ISGROUP=0'
	END
	
	
	set @SQL=@SQL+' 
	UNION
	select PPP.ProductID ProductName_Key,0'+@CustomCols
	if @EnableSubstituteType='True'
		set @SQL=@SQL+',null SubstituteType,null STypeID'
		
	set @SQL=@SQL+' from INV_Product PPP WITH(NOLOCK)
	left JOIN COM_CCCCData c  WITH(NOLOCK) on c.NodeID=PPP.ProductID  and c.CostCenterID=3'+@Join
    if(@ParentPrefValue='True')
        set @SQL=@SQL+' where  PPP.ParentID=(select ParentID from INV_Product with(nolock) where ParentID<>1 and  ProductID='+ convert(varchar,@ProductID)+')'
    else
		set @SQL=@SQL+' where  PPP.ProductID='+ convert(varchar,@ProductID)

	select @PrefValue=Value from com_costcenterpreferences with(nolock) where CostCenterID=3 and Name='SameDimensionAsSubstitute'
	if @PrefValue is not null and @PrefValue<>''
	begin
			declare @TblDimSub as table(DIM int)
			declare @subdimwhere nvarchar(max)
			insert into @TblDimSub
			exec SPSplitString  @PrefValue,';'
			 set @subdimwhere=''
			select @subdimwhere=@subdimwhere+' and c.CCNID'+CONVERT(nvarchar,DIM-50000)+'=(select top 1 CCNID'+CONVERT(nvarchar,DIM-50000)+' from COM_CCCCData with(nolock) where NodeID='+convert(nvarchar,@ProductID)+' and CostCenterID=3)' from @TblDimSub
			if(@ParentPrefValue='True')
				set @SQL=@SQL+' and ('+SUBSTRING(@subdimwhere,6,len(@subdimwhere)-5)+')'
			else
				set @SQL=@SQL+' or ('+SUBSTRING(@subdimwhere,6,len(@subdimwhere)-5)+')'
	end
	
	if @EnableSubstituteType='True'
		set @SQL=@SQL+' ORDER BY STypeID,SNo'
	else
		set @SQL=@SQL+' ORDER BY SNo'	
	
	--@EnableSubstituteType
		
	print(@SQL) 
	
    exec (@SQL)
    
    
    select * from @TEMP
    order by ColumnOrder
    
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
