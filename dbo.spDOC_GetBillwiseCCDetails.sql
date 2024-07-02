USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetBillwiseCCDetails]
	@AccountID [int] = 0,
	@VoucherNo [nvarchar](500),
	@CostCenterID [int],
	@xml [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY 
		declare @table table(id int identity(1,1),ccid INT)
		declare @i int,@cnt int,@ccid INT,@Columns nvarchar(max),@sql nvarchar(max),@tablename nvarchar(100)
		declare @join nvarchar(max),@Gropby nvarchar(max),@Where nvarchar(max)
		insert into @table
		select ColumnCostCenterID from adm_costcenterdef with(nolock)
		where LocalReference is not null and LocalReference =99 and CostCenterID=@CostCenterID
		and ColumnCostCenterID>50000
		
		set @Columns=''
		set @join=''
		set @Where=''
		set @Gropby=' group by '
		select @i=0,@cnt=COUNT(id) from @table
		while(@i<@cnt)
		begin
			set @i=@i+1
			select @ccid=ccid from @table where id=@i
			select @tablename=TableName from ADM_Features with(nolock) where FeatureID=@ccid
			if(@i>1)
			BEGIN
				set @Columns=@Columns+' ,'
				set @Gropby=@Gropby+' ,'
			END	
			set @Columns=@Columns+' a.dcccnid'+convert(nvarchar,(@ccid-50000))+',c'+convert(nvarchar,@i)+'.Name as dcccnid'+convert(nvarchar,(@ccid-50000))+'name '
			set @Gropby=@Gropby+' a.dcccnid'+convert(nvarchar,(@ccid-50000))+',c'+convert(nvarchar,@i)+'.Name '
			set @Where=@Where+' and DB.dcccnid'+convert(nvarchar,(@ccid-50000))+'=a.dcccnid'+convert(nvarchar,(@ccid-50000))
			set @join=@join+' join '+@tablename+' c'+convert(nvarchar,@i)+' with(nolock) on c'+convert(nvarchar,@i)+'.Nodeid=a.dcccnid'+convert(nvarchar,(@ccid-50000))
		
		end
		
		if @Columns!=''
		begin
			set @sql=' declare @data xml
			 set @data=@xml
			 select '+@Columns
			if(@VoucherNo like '%'',''%')
				set @sql=@sql+',STUFF((select distinct '',''+DB.docno from com_BillWise DB with(nolock) 
				 where docno in ('''+@VoucherNo+''') and accountid='+convert(nvarchar,@AccountID)+@Where+'
					 FOR XML PATH(''''))
					,1,1,'''') as docno '
			
			set @sql=@sql+' from com_BillWise a with(nolock) 
			join @data.nodes(''/XML/Row'') as Data(X) on X.value(''@DocNO'',''nvarchar(200)'')=a.DocNo

			'+@join 
			 +' where X.value(''@SeqNo'',''int'')=a.DocSeqNo and accountid='+convert(nvarchar,@AccountID)
			 if(@VoucherNo like '%'',''%')
				set @sql=@sql+@Gropby
			 print @sql
			 exec sp_executesql @SQL,N'@xml nvarchar(max)',@xml
		 end
		 else
			select 1 DocNo  where 1<>1
			
		 set @sql='
		 declare @data xml
		 set @data=@xml
		 select a.DocNo,a.DocSeqNo'
		 
		 if @Columns!=''
			set @sql=@sql+','+@Columns
		
		set @sql=@sql+' from @data.nodes(''/XML/Row'') as Data(X) 
		join com_BillWise a with(nolock) on X.value(''@DocNO'',''nvarchar(200)'')=a.DocNo
		 '+@join 
		 +' where X.value(''@SeqNo'',''int'')=a.DocSeqNo and accountid='+convert(nvarchar,@AccountID)		 
		 
		 if (@Gropby=' group by ')
			set @sql=@sql+@Gropby+' a.DocNo,a.DocSeqNo'
		 else 
			set @sql=@sql+@Gropby+',a.DocNo,a.DocSeqNo'
			
		 print @sql
		 exec sp_executesql @SQL,N'@xml nvarchar(max)',@xml

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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
