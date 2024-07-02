USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetStockCode]
	@Action [int],
	@ProductCall [bit],
	@Code [nvarchar](50) = NULL,
	@ProductID [bigint],
	@InvDocDetailsID [bigint] = null,
	@DealerPrice [float] = 0,
	@RetailPrice [float] = 0,
	@UOM [nvarchar](20),
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--Declaration Section  
	DECLARE @CostCenterId int,@NodeID bigint,@Table NVARCHAR(50),@SQL NVARCHAR(max),@StatusID INT,@BID BIGINT,@temp nvarchar(500),@I int,@Cnt int,@ManufacturerBarcode bit
	DECLARE @xml xml,@Dsource NVARCHAR(200),@SYSCOLUMNNAME NVARCHAR(200),@Width BIGINT, @Delimiter nvarchar(5),@Decimals int,@cctab  nvarchar(500),@ccid int
	select @Table=Value from ADM_GlobalPreferences with(nolock) where Name='POSItemCodeDimension'
	if @Table is null or ISNUMERIC(@Table)=0
		return -1

	set @BID=0
	set @ManufacturerBarcode=0
	select @BID=case when producttypeid=4 and AttributeGroupID is not null and  AttributeGroupID>0 THEN
			(select top 1 BarcodeID from INV_MatrixDef M WITH(NOLOCK) where ProfileID=AttributeGroupID)
			 ELSE BarcodeLayoutID end,@ManufacturerBarcode=ManufacturerBarcode from inv_product WITH(NOLOCK)
	where  ProductID=@ProductID 
	
	if(@ManufacturerBarcode=1)
		return 1
		
	set @CostCenterId=convert(int,@Table)

	--To get costcenter table name  
	SELECT @Table=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterId  

	--If Update
	if @Action=1 or @Action=2
	begin
		if @ProductCall=1
			set @SQL=' select @NodeID=NodeID from '+@Table+' with(nolock) WHERE ProductID='+convert(nvarchar,@ProductID) +' and InvDocDetailsID is null'     
		else
			set @SQL=' select @NodeID=NodeID from '+@Table+' with(nolock) WHERE InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
		EXEC sp_executesql @SQL,N'@NodeID INT OUTPUT',@NodeID OUTPUT
		--If Stock Code Not Found Then Insert
		if @NodeID is null
		begin
			if @Action=1
				set @Action=0
			else
				return 1
		end
	end
	
	if ((@Action=1 or @Action=0)and @InvDocDetailsID>0 )
	begin
		SET @SQL='	SELECT @temp=Code FROM '+@Table+' SC WITH(NOLOCK)
		JOIN COM_DocCCData DCD WITH(NOLOCK)ON DCD.dcCCNID'+convert(nvarchar,(@CostCenterId-50000))+'=SC.NodeID
		WHERE SC.NodeID>2 AND DCD.INVDOCDETAILSID='+convert(nvarchar,@INVDOCDETAILSID)
		EXEC sp_executesql @SQL,N'@temp nvarchar(200) OUTPUT',@temp output	
		
		IF @temp IS NOT NULL OR @temp<>''
		BEGIN
			SET @Code=@temp
		END
		ELSE if(@BID>0)
		BEGIN
			select @SQL=DefinitionXML from ADM_DocBarcodeLayouts
			where BarcodeLayoutID=@BID
			set @xml=@SQL
			Declare @TEMPtbl TABLE(ID INT identity(1,1),Dsource NVARCHAR(200),SYSCOLUMNNAME NVARCHAR(200),Width BIGINT, Delimiter nvarchar(5),Decimals int)
	
			INSERT INTO @TEMPtbl     
			 SELECT   X.value('DataSource[1]','nvarchar(200)')       
				, X.value('SysColumn[1]','nvarchar(200)')             
				, X.value('Width[1]','BIGINT')
				, X.value('Delimiter[1]','nvarchar(5)')  
				, X.value('Decimals[1]','int')  
				from @xml.nodes('/Definition/Field') as Data(X)       
			
			select @I=0,@Cnt=count(ID) from @TEMPtbl
			
			WHILE(@I<@Cnt)        
			BEGIN      
				SET @I=@I+1  
				SELECT @Dsource=Dsource ,@SYSCOLUMNNAME=SYSCOLUMNNAME ,@Width=Width , @Delimiter=isnull(Delimiter,'') ,@Decimals=Decimals
				from @TEMPtbl where  ID=@I

				if(@Dsource='Product')
				BEGIN
					if(@SYSCOLUMNNAME='SequenceNo')
					BEGIN
						set @SQL='select  @temp=isnull(max(convert(bigint,substring(code,len('''+@Code+''')+1,len(code)))),0)+1  from '+@Table+' 
						where productid='+convert(nvarchar,@ProductID)+' and isnumeric(substring(code,len('''+@Code+''')+1,len(code)))=1
						and code like '''+@Code+'%'''
						
					END
					ELSE
						set @SQL='select @temp='+@SYSCOLUMNNAME+' from inv_product WITH(NOLOCK) where ProductID='+convert(nvarchar,@ProductID)
				END	
				ELSE if(@Dsource like 'CC%')
				BEGIN
					set @ccid=replace(@Dsource,'CC','')
					set @ccid=@ccid+50000
					select @cctab=tablename from adm_features WITH(NOLOCK) where featureid=@ccid
					
					set @SQL='select @temp='+@SYSCOLUMNNAME+' from '+@cctab+' a WITH(NOLOCK)
						JOIN Com_DocCCData b WITH(NOLOCK) on a.NodeID=b.Dcccnid'+replace(@Dsource,'CC','')+'
					 where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
				END
				ELSE if(@Dsource='Document')
				BEGIN
					if @SYSCOLUMNNAME like 'dcAlpha%'
						set @SQL='select @temp='+@SYSCOLUMNNAME+' from Com_DocTextData a WITH(NOLOCK)
						 where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
					else if @SYSCOLUMNNAME='Quantity' or @SYSCOLUMNNAME='Rate' or @SYSCOLUMNNAME='Gross'
						set @SQL='select @temp='+@SYSCOLUMNNAME+' from INV_DocDetails WITH(NOLOCK)
						 where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
					else
						set @SQL='select @temp='+@SYSCOLUMNNAME+' from Com_DocNumData a WITH(NOLOCK)
						 where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
				END
				--print @SQL
				
				EXEC sp_executesql @SQL,N'@temp nvarchar(200) OUTPUT',@temp output
				IF(@SYSCOLUMNNAME='SequenceNo' and @Width<>-1 and isnumeric(@temp)=1 and LEN(@temp)<@Width)
				BEGIN
					while(LEN(@temp)<@Width)
						set @temp='0'+@temp
				END
				ELSE IF((@SYSCOLUMNNAME like 'dcNum%' or @SYSCOLUMNNAME like 'dcCalcNum%' or @SYSCOLUMNNAME='Quantity' or @SYSCOLUMNNAME='Rate' or @SYSCOLUMNNAME='Gross') and @Width<>-1 and isnumeric(@temp)=1)
				BEGIN
					declare @num float,@fraction float
					declare @TempDec nvarchar(50)
					set @TempDec=''
					set @num=convert(float,isnull(@temp,'0'))
					if @Decimals is not null and @Decimals>0 and @Width>@Decimals
					begin
						if CHARINDEX('.',@temp,1)>0
						begin
							set @TempDec=convert(nvarchar,@num-convert(int,@num))
							set @TempDec=substring(@TempDec,CHARINDEX('.',@TempDec,1)+1,len(@TempDec))
						end
						if LEN(@TempDec)>@Decimals
							set @TempDec=substring(@TempDec,1,@Decimals)
						while(LEN(@TempDec)<@Decimals)
							set @TempDec=@TempDec+'0'
						set @Width=@Width-@Decimals						
					end
					set @temp=convert(nvarchar(20),convert(int,floor(@num)))
					while(LEN(@temp)<@Width)
						set @temp='0'+@temp
					set @temp=@temp+@TempDec
				END
				ELSE if(len(@temp)>@Width+1 and @Width<>-1)
				begin
					set @temp=substring(@temp,0,@Width+1)
				end
				set @Code=@Code+@temp+@Delimiter
			END
		END
		ELSE
			select @Code=ProductCode from inv_product
			where ProductID=@ProductID
		

			
	END
	
	if(@InvDocDetailsID>0 and @Action in(0,1,4))
	BEGIN
	    select @ccid=CostcenterID from Inv_docdetails with(nolock) WHERE InvDocDetailsID=@InvDocDetailsID
		
		set @SYSCOLUMNNAME=''
		select @SYSCOLUMNNAME=prefvalue from com_documentpreferences  WITH(NOLOCK) where  CostcenterID=@ccid and prefname='POSRetailPrice'
		if(@SYSCOLUMNNAME<>'')
		BEGIN
			set @SQL='select @temp='+@SYSCOLUMNNAME+' from Com_DocNumData a WITH(NOLOCK)
					 where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			EXEC sp_executesql @SQL,N'@temp nvarchar(200) OUTPUT',@temp output
			
			set @RetailPrice=convert(float,@temp)				 
		END
		
		set @SYSCOLUMNNAME=''
		select @SYSCOLUMNNAME=prefvalue from com_documentpreferences  WITH(NOLOCK) where  CostcenterID=@ccid and prefname='POSDealerPrice'
		if(@SYSCOLUMNNAME<>'')
		BEGIN
			set @SQL='select @temp='+@SYSCOLUMNNAME+' from Com_DocNumData a WITH(NOLOCK)
					 where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)
			EXEC sp_executesql @SQL,N'@temp nvarchar(200) OUTPUT',@temp output
			
			set @DealerPrice=convert(float,@temp)				 
		END
	END
		
	IF @Action in(0,4)
	BEGIN
		select @StatusID=StatusID from com_status with(nolock) where featureid=@CostCenterId and [Status]='Active'

	    set @SQL='DECLARE @rgt BIGINT'
	      
	    set @SQL=@SQL+' select @rgt=rgt from '+@Table+' with(NOLOCK) where NodeID=2
	   UPDATE '+@Table+' SET rgt=rgt+2 WHERE NodeID=2'   
	  
		set @SQL=@SQL+'
		INSERT INTO '+@Table+'(StatusID,  
		  [Code],name,
		  DealerPrice,RetailPrice,
		  ProductID,InvDocDetailsID,
		  [Depth],  
		  [ParentID],  
		  [lft],  
		  [rgt],    
		  [IsGroup],
		  [ModifiedBy],  
		  [ModifiedDate]
		  )    
		 VALUES('  
		  +convert(nvarchar,@StatusID)+',  
		  N'''+(case when @Code is null or @Code='' then convert(nvarchar,@ProductID) else @Code end)+''','
		  set @SQL=@SQL+(case when @UOM is null then 'null' else +'N'''+@UOM+'''' end)+','
		  set @SQL=@SQL+convert(nvarchar,@DealerPrice)+','+convert(nvarchar,@RetailPrice)+','+convert(nvarchar,@ProductID)+','
		  set @SQL=@SQL+(case when @InvDocDetailsID is null then 'null' else convert(nvarchar,@InvDocDetailsID) end)+','
		  set @SQL=@SQL+'
		  1,  
		  2,  
		  @rgt,  
		  @rgt+1,     
		  0,
		  '''+@UserName+''',  
		  convert(float,getdate()))
		 SET @NodeID=SCOPE_IDENTITY()'--To get inserted record primary key  

	   EXEC sp_executesql @SQL, N'@NodeID INT OUTPUT', @NodeID OUTPUT 
	   
	   if(@InvDocDetailsID>0)
	   BEGIN	   
			SET @SQL='	UPDATE COM_DocCCData SET 
			dcCCNID'+convert(nvarchar,(@CostCenterId-50000))+'='+convert(nvarchar,@NodeID)
			 +'WHERE INVDOCDETAILSID='+convert(nvarchar,@INVDOCDETAILSID)
			 EXEC(@SQL) 
	   END
	          
	END
	ELSE IF @Action=1
	BEGIN
	   SET @SQL='UPDATE '+@Table+'       
	   SET code=N'''+(case when @Code is null or @Code='' then convert(nvarchar,@ProductID) else @Code end)+''','
	 --  set @SQL=@SQL+'Name='+(case when @UOM is null then 'null' else +'N'''+@UOM+'''' end)+','
	   set @SQL=@SQL+'DealerPrice='+convert(nvarchar,@DealerPrice)+',
	   RetailPrice='+convert(nvarchar,@RetailPrice)+',
	   ModifiedBy=N'''+@UserName+''',
	   ModifiedDate=CONVERT(FLOAT,GETDATE()) WHERE NodeID='+convert(nvarchar,@NodeID)
	  print(@SQL)
	   EXEC(@SQL)
	   if(@InvDocDetailsID>0)
	   BEGIN	   
			SET @SQL='	UPDATE COM_DocCCData SET 
			dcCCNID'+convert(nvarchar,(@CostCenterId-50000))+'='+convert(nvarchar,@NodeID)
			 +'WHERE INVDOCDETAILSID='+convert(nvarchar,@INVDOCDETAILSID)
			 EXEC(@SQL) 
	   END
	END
	ELSE IF @Action=2
	BEGIN
	   SET @SQL='DELETE FROM '+@Table+' WHERE NodeID='+convert(nvarchar,@NodeID)
	   EXEC(@SQL)
	END

RETURN @NodeID  
GO
