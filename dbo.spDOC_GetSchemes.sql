USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetSchemes]
	@ProductID [int] = 0,
	@CCXML [nvarchar](max),
	@DocDate [datetime]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @SQL NVARCHAR(MAX),@XML XML,@WHERE NVARCHAR(MAX),@I INT,@CNT INT,@NODEID INT,@TblName Nvarchar(max)
	Declare @CC nvarchar(20),@CCWHERE NVARCHAR(MAX),@IDs nvarchar(max),@OrderBY nvarchar(max)
	
	set @XML=@CCXML
	DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId INT)        
	INSERT INTO @tblCC(CostCenterID,NodeId)        
	SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')        
	FROM @XML.nodes('/XML/Row') as Data(X)        
	set @WHERE=''
	set @CCWHERE=''
	set @WHERE=' and ('      
	if(@ProductID>0)
	BEGIN
		set @IDs=''
		select @IDs=@IDs+convert(nvarchar,ProductID)+',' from Inv_Product WITH(NOLOCK) where (select lft from Inv_Product WITH(NOLOCK) where ProductID=@ProductID) between lft and rgt
		if(LEN(@IDs)>1)
			set @IDs=SUBSTRING(@IDs,0,len(@IDs))
		set @WHERE=@WHERE+'a.ProductID in ('+@IDs+')  or '
		set @CCWHERE=' and a.ProductID  in('+@IDs+') '
	END	
	ELSE
		set @CCWHERE=' and a.ProductID=1 '
	set @WHERE=@WHERE+' a.ProductID=1)' 

	set @WHERE=@WHERE+' and ('        
	set @OrderBY=',a.ProductID Desc,AccountID Desc'        
	if exists(select CostCenterID from @tblCC where CostCenterID=2)        
	begin 
		select @NODEID=NodeId from @tblCC where CostCenterID=2               
		set @IDs=''
		select @IDs=@IDs+convert(nvarchar,AccountID)+',' from ACC_Accounts WITH(NOLOCK) where (select lft from ACC_Accounts WITH(NOLOCK) where AccountID=@NODEID) between lft and rgt
        if(LEN(@IDs)>1)
			set @IDs=SUBSTRING(@IDs,0,len(@IDs))

		set @WHERE=@WHERE+' AccountID in('+@IDs+' ) or '         
		set @CCWHERE=@CCWHERE+' and AccountID in('+@IDs+') '
	end       
	else        
		set @CCWHERE=@CCWHERE+' and AccountID=1'        

	set @WHERE=@WHERE+' AccountID =1 )'     


	-----------------
	DECLARE @ColName NVARCHAR(100)
	DECLARE CUR CURSOR FOR Select Name From Sys.Columns WHERE object_id=OBJECT_ID('ADM_SchemesDiscounts') AND Name LIKE 'CCNID%'
	OPEN CUR
	FETCH NEXT FROM CUR INTO @ColName
	WHILE @@FETCH_STATUS=0
	BEGIN
		set @OrderBY=@OrderBY+','+@ColName+' Desc '  
		set @CC=@ColName  
		SET @I=50000 + CONVERT(INT,REPLACE(@ColName,'CCNID',''))
		set @WHERE=@WHERE+' and ('    
		if exists(select CostCenterID from @tblCC where CostCenterID=@I)        
		begin        
			select @TblName=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@I 
			select @NODEID=NodeId from @tblCC where CostCenterID=@I 
		
			set @SQL=' 		set @IDs=''''
						select @IDs=@IDs+convert(nvarchar,nodeid)+'','' from '+@TblName+' WITH(NOLOCK) where (select lft from '+@TblName+' WITH(NOLOCK) where nodeid='+convert(nvarchar,@NODEID)+') between lft and rgt'
			print @SQL
			exec sp_executesql @SQL,N'@IDs Nvarchar(max) OUTPUT',@IDs OUTPUT
			if(LEN(@IDs)>1)
				set @IDs=SUBSTRING(@IDs,0,len(@IDs))

			set @WHERE=@WHERE+@CC+' in ('+@IDs+') or '        
			set @CCWHERE=@CCWHERE+' and '+@CC+' in ('+@IDs +') '            
		end        
		else        
			set @CCWHERE=@CCWHERE+' and '+@CC+'=1'         

		set @WHERE=@WHERE+@CC+'=1 )' 

	FETCH NEXT FROM CUR INTO @ColName
	END
	CLOSE CUR
	DEALLOCATE CUR


/*	    
	Set @I=50000         
	Set @CNT=50050         
	while(@I<@CNT)        
	begin        
	set @I=@I+1        
	set @OrderBY=@OrderBY+',CCNID'+convert(nvarchar,@I-50000)+' Desc '        
	set @CC='CCNID'+convert(nvarchar,@I-50000)
	set @WHERE=@WHERE+' and ('        
	if exists(select CostCenterID from @tblCC where CostCenterID=@I)        
	begin        
		select @TblName=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@I 
		select @NODEID=NodeId from @tblCC where CostCenterID=@I 
		
		set @SQL=' 		set @IDs=''''
					select @IDs=@IDs+convert(nvarchar,nodeid)+'','' from '+@TblName+' WITH(NOLOCK) where (select lft from '+@TblName+' WITH(NOLOCK) where nodeid='+convert(nvarchar,@NODEID)+') between lft and rgt'
        print @SQL
        exec sp_executesql @SQL,N'@IDs Nvarchar(max) OUTPUT',@IDs OUTPUT
        if(LEN(@IDs)>1)
			set @IDs=SUBSTRING(@IDs,0,len(@IDs))

		set @WHERE=@WHERE+@CC+' in ('+@IDs+') or '        
		set @CCWHERE=@CCWHERE+' and '+@CC+' in ('+@IDs +') '            
	end        
	else        
		set @CCWHERE=@CCWHERE+' and '+@CC+'=1'         

	set @WHERE=@WHERE+@CC+'=1 )'            
	end  
	
	*/



	set @I=0
	select @I=Value from ADM_GlobalPreferences WITH(NOLOCK)
	where Name='SchemeFreeProdDim' and ISNUMERIC(Value)=1 and convert(INT,value)>50000
	if(@I is not null and @I>0)
		select @CC=TableName from ADM_Features WITH(NOLOCK) where FeatureID=@I

	set @SQL=' if exists (select SchemeID from ADM_SchemesDiscounts a WITH(NOLOCK)
	where '+convert(nvarchar,convert(float,@DocDate))+' between FromDate and ToDate '+@CCWHERE+')   
		select a.SchemeID,a.ProfileName,a.FromQty,a.ToQty,a.FromValue,a.ToValue,'+convert(nvarchar,@ProductID)+' ProductID,a.Quantity,a.Value,a.Percentage,a.IsQtyPercent,b.ProductID freeProductID,a.ProductID SchemeProductID
		,P.ProductName,P.ProductCode,b.Quantity freeQuantity,b.Value freeValue,b.Percentage freePercentage,b.IsQtyPercent FreeQtyPercent,P.ProductTypeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate '
		
		if(@I is not null and @I>0)
			set @SQL=@SQL+' ,b.Dim1,dim.Name'

		set @SQL=@SQL+' from ADM_SchemesDiscounts a WITH(NOLOCK)        
		left join ADM_SchemeProducts b WITH(NOLOCK) on a.SchemeID=b.SchemeID '
		
		if(@I is not null and @I>0)
			set @SQL=@SQL+' left join '+@CC+' dim  WITH(NOLOCK) on b.Dim1=dim.NOdeid '
		
		set @SQL=@SQL+' left JOIN INV_Product P WITH(NOLOCK) on b.ProductID=P.ProductID
		join COM_Status s WITH(NOLOCK) on a.StatusID=s.StatusID 
		where s.Status=''Active'' and '+convert(nvarchar,convert(float,@DocDate))+' between FromDate and ToDate '+@CCWHERE+'          
	else  
		select  a.SchemeID,a.ProfileName,a.FromQty,a.ToQty,a.FromValue,a.ToValue,'+convert(nvarchar,@ProductID)+' ProductID,a.Quantity,a.Value,a.Percentage,a.IsQtyPercent,b.ProductID freeProductID,a.ProductID SchemeProductID
		,P.ProductName,P.ProductCode  ,b.Quantity freeQuantity,b.Value freeValue,b.Percentage freePercentage,b.IsQtyPercent FreeQtyPercent,P.ProductTypeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate'
		
		if(@I is not null and @I>0)
			set @SQL=@SQL+' ,b.Dim1,dim.Name'

		set @SQL=@SQL+' from ADM_SchemesDiscounts a WITH(NOLOCK)        
		left join ADM_SchemeProducts b WITH(NOLOCK) on a.SchemeID=b.SchemeID'
		
		if(@I is not null and @I>0)
			set @SQL=@SQL+' left join '+@CC+' dim  WITH(NOLOCK) on b.Dim1=dim.NOdeid '
		
		set @SQL=@SQL+' left JOIN INV_Product P WITH(NOLOCK) on b.ProductID=P.ProductID
		join COM_Status s WITH(NOLOCK) on a.StatusID=s.StatusID 
		where s.Status=''Active'' and  '+convert(nvarchar,convert(float,@DocDate))+' between FromDate and ToDate '+@WHERE+'           
		order by FromDate Desc'+@OrderBY          
   print @SQL      
   exec(@SQL)

GO
