USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetChequeReturnCCDetails]
	@AccountID [bigint] = 0,
	@VoucherNo [nvarchar](500),
	@CostCenterID [bigint],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY 
		declare @table table(id int identity(1,1),ccid bigint)
		declare @i int,@cnt int,@ccid bigint,@Columns nvarchar(max),@sql nvarchar(max),@tablename nvarchar(100)
		insert into @table
		select ColumnCostCenterID from adm_costcenterdef with(nolock)
		where LocalReference is not null and LocalReference =159 and CostCenterID=@CostCenterID
		set @Columns=''
		set @sql=''
		select @i=0,@cnt=COUNT(id) from @table
		while(@i<@cnt)
		begin
			set @i=@i+1
			select @ccid=ccid from @table where id=@i
			if(@ccid>50000)
			BEGIN
				select @tablename=TableName from ADM_Features with(nolock) where FeatureID=@ccid
				set @Columns=@Columns+' ,a.dcccnid'+convert(nvarchar,(@ccid-50000))+',c'+convert(nvarchar,@i)+'.Name as dcccnid'+convert(nvarchar,(@ccid-50000))+'name '
				set @sql=@sql+' left join '+@tablename+' c'+convert(nvarchar,@i)+' with(nolock) on c'+convert(nvarchar,@i)+'.Nodeid=a.dcccnid'+convert(nvarchar,(@ccid-50000))
			END
		end
		select @sql='select docno'+@Columns+' from COM_ChequeReturn a with(nolock) '+@sql 
		 +' where docno='''+@VoucherNo +''' and accountid='+convert(nvarchar,@AccountID)
		-- print @sql
		 exec(@sql)

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
