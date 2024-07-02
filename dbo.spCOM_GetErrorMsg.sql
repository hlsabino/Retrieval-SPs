USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetErrorMsg]
	@CCID [int],
	@HasRecord [bigint],
	@PrefixMsg [nvarchar](100),
	@ErrorMsg [nvarchar](max) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @HasAccess BIT,@Width int,@Table nvarchar(50),@SQL nvarchar(max)
	DECLARE @TEMPSQL NVARCHAR(300)
	
	set @ErrorMsg=''
				
	select @ErrorMsg=@PrefixMsg+Name,@TEMPSQL=TableName FROM ADM_Features with(nolock) WHERE FeatureID=@CCID
	if @CCID=2
		select @ErrorMsg=@ErrorMsg+' "'+AccountName+'"' from acc_accounts with(nolock) where AccountID=@HasRecord
	else if @CCID=3
		select @ErrorMsg=@ErrorMsg+' "'+ProductName+'"' from inv_product with(nolock) where ProductID=@HasRecord
	else if @CCID>50000
	begin					
		set @SQL='select @Name=isnull(Name,'''') from '+@TEMPSQL+' with(nolock) where NodeID='+convert(nvarchar,@HasRecord)
		EXEC sp_executesql @SQL,N'@Name nvarchar(max) OUTPUT',@TEMPSQL OUTPUT
		set @ErrorMsg=@ErrorMsg+' "'+@TEMPSQL+'"'
	end
	else
	begin
		begin try
			select @CCID=object_id from sys.objects where name=@TEMPSQL and type='U'

			SELECT @SQL=COL_NAME(ic.object_id, ic.column_id)
			FROM sys.indexes AS i 
			INNER JOIN sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
			WHERE (i.is_primary_key = 1) and ic.object_id=@CCID

			select top 1 @SQL='select @Name='+name+' from '+@TEMPSQL+' with(nolock) where '+@SQL+'='+convert(nvarchar,@HasRecord) from sys.columns where object_id=@CCID and name like '%Code%'

			EXEC sp_executesql @SQL,N'@Name nvarchar(max) OUTPUT',@TEMPSQL OUTPUT
			set @ErrorMsg=@ErrorMsg+' "'+@TEMPSQL+'"'
			exec(@SQL)
			
		end try
		begin catch
		end catch
	end
GO
