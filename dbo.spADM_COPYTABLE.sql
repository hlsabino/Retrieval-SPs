USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_COPYTABLE]
	@TblName [nvarchar](100),
	@TargetDBName [nvarchar](50),
	@DestTbl [nvarchar](100)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON; 
 
DECLARE @sql nvarchar(max),@cols nvarchar(max),@IsExists INT
DECLARE @TblTarget AS TABLE(column_id int,name nvarchar(100))

set @sql='SELECT @IsExists=count(*) FROM '+@TargetDBName+'.sys.objects WHERE object_id = OBJECT_ID(N'''+@DestTbl+''') AND type in (N''U'')'
exec sp_executesql @sql,N'@IsExists INT OUTPUT',@IsExists OUTPUT

IF @IsExists=0
BEGIN
	set @cols=''
	select @cols=@cols+',
	'+C.name+' '+T.name+case when T.precision=0 then '('+ case when C.max_length=-1 then 'MAX' else convert(nvarchar,C.max_length) end+')' else '' end
	from sys.columns C inner join sys.types T on T.user_type_id=C.user_type_id
	 where OBJECT_ID=OBJECT_ID(@TblName) 
	order by column_id
	
	if @TblName='COM_CCMastHistory'
		set @cols=replace(@cols,'NodeHistoryID bigint','NodeHistoryID bigint identity(1,1) PRIMARY KEY')
	else if @TblName='PRD_BillOfMaterialHistory'
		set @cols=replace(@cols,'BOMHistoryID bigint','BOMHistoryID bigint identity(1,1) PRIMARY KEY')

	set @cols=substring(@cols,2,len(@cols)-1)
	set @cols='create table '+@DestTbl+'('+@cols+')'
	exec(@cols)
END
ELSE BEGIN
	set @sql='SELECT column_id,name FROM '+@TargetDBName+'.sys.columns WHERE object_id = OBJECT_ID(N'''+@DestTbl+''') order by column_id'
	
	insert into @TblTarget
	exec(@sql)
	
	set @cols=''
	select @cols=@cols+',
	'+C.name+' '+T.name+case when T.precision=0 then '('+ case when C.max_length=-1 then 'MAX' else convert(nvarchar,C.max_length) end+')' else '' end
	from sys.columns C inner join sys.types T on T.user_type_id=C.user_type_id
	where OBJECT_ID=OBJECT_ID(@TblName) and C.name not in (select name from @TblTarget)
	order by column_id

	if len(@cols)>0
	begin
		set @cols=substring(@cols,2,len(@cols)-1)
		set @cols='alter table '+@DestTbl+' add '+@cols+''
		print(@cols)
		exec(@cols)
	end
END

--CREATING INDEXES ON TABLES
if @TblName='ACC_DocDetails_History'
begin
	set @sql='use '+@TargetDBName+'
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[ACC_DocDetails_History]'') AND name = N''Acc_DocHistory_AccDetailsID'')
CREATE NONCLUSTERED INDEX [Acc_DocHistory_AccDetailsID] ON [dbo].[ACC_DocDetails_History] 
([AccDocDetailsID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[ACC_DocDetails_History]'') AND name = N''Acc_DocHistory_CostCenterID'')
CREATE NONCLUSTERED INDEX [Acc_DocHistory_CostCenterID] ON [dbo].[ACC_DocDetails_History] 
([CostCenterID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[ACC_DocDetails_History]'') AND name = N''Acc_DocHistory_ModDate'')
CREATE NONCLUSTERED INDEX [Acc_DocHistory_ModDate] ON [dbo].[ACC_DocDetails_History] 
([ModifiedDate] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[ACC_DocDetails_History]'') AND name = N''ACC_DocHistory_DebitAccount'')
CREATE NONCLUSTERED INDEX [ACC_DocHistory_DebitAccount] ON [dbo].[ACC_DocDetails_History] 
([DebitAccount] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[ACC_DocDetails_History]'') AND name = N''ACC_DocHistory_CreditAccount'')
CREATE NONCLUSTERED INDEX [ACC_DocHistory_CreditAccount] ON [dbo].[ACC_DocDetails_History] 
([CreditAccount] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[ACC_DocDetails_History]'') AND name = N''ACC_DocHistory_DocDate'')
CREATE NONCLUSTERED INDEX [ACC_DocHistory_DocDate] ON [dbo].[ACC_DocDetails_History] 
([DocDate] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]'
	exec(@sql)
end
else if @TblName='INV_DocDetails_History'
begin
	set @sql='use '+@TargetDBName+'
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[INV_DocDetails_History]'') AND name = N''INV_DocHistory_ModDate'')
CREATE NONCLUSTERED INDEX [INV_DocHistory_ModDate] ON [dbo].[INV_DocDetails_History] 
([ModifiedDate] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[INV_DocDetails_History]'') AND name = N''INV_DocHistory_InvDetailsID'')
CREATE NONCLUSTERED INDEX [INV_DocHistory_InvDetailsID] ON [dbo].[INV_DocDetails_History] 
([InvDocDetailsID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[INV_DocDetails_History]'') AND name = N''INV_DocHistory_CostCenterID'')
CREATE NONCLUSTERED INDEX [INV_DocHistory_CostCenterID] ON [dbo].[INV_DocDetails_History] 
([CostCenterID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[INV_DocDetails_History]'') AND name = N''INV_DocHistory_ProductID'')
CREATE NONCLUSTERED INDEX [INV_DocHistory_ProductID] ON [dbo].[INV_DocDetails_History] 
([ProductID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[INV_DocDetails_History]'') AND name = N''INV_DocHistory_DebitAccount'')
CREATE NONCLUSTERED INDEX [INV_DocHistory_DebitAccount] ON [dbo].[INV_DocDetails_History] 
([DebitAccount] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[INV_DocDetails_History]'') AND name = N''INV_DocHistory_CreditAccount'')
CREATE NONCLUSTERED INDEX [INV_DocHistory_CreditAccount] ON [dbo].[INV_DocDetails_History] 
([CreditAccount] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[INV_DocDetails_History]'') AND name = N''INV_DocHistory_DocDate'')
CREATE NONCLUSTERED INDEX [INV_DocHistory_DocDate] ON [dbo].[INV_DocDetails_History] 
([DocDate] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]'
	exec(@sql)
end
else if @TblName='COM_DocCCData_History'
begin
	set @sql='use '+@TargetDBName+'
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocCCData_History]'') AND name = N''COM_DocCCData_History_ModDate'')
CREATE NONCLUSTERED INDEX [COM_DocCCData_History_ModDate] ON [dbo].[COM_DocCCData_History] 
([ModifiedDate] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocCCData_History]'') AND name = N''COM_DocCCData_History_InvDetailID'')
CREATE NONCLUSTERED INDEX [COM_DocCCData_History_InvDetailID] ON [dbo].[COM_DocCCData_History] 
([InvDocDetailsID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocCCData_History]'') AND name = N''COM_DocCCData_History_AccDetailID'')
CREATE NONCLUSTERED INDEX [COM_DocCCData_History_AccDetailID] ON [dbo].[COM_DocCCData_History] 
([AccDocDetailsID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]'
	exec(@sql)
end
else if @TblName='COM_DocNumData_History'
begin
	set @sql='use '+@TargetDBName+'
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocNumData_History]'') AND name = N''COM_DocNumData_History_ModDate'')
CREATE NONCLUSTERED INDEX [COM_DocNumData_History_ModDate] ON [dbo].[COM_DocNumData_History] 
([ModifiedDate] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocNumData_History]'') AND name = N''COM_DocNumData_History_InvDetailsID'')
CREATE NONCLUSTERED INDEX [COM_DocNumData_History_InvDetailsID] ON [dbo].[COM_DocNumData_History] 
([InvDocDetailsID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocNumData_History]'') AND name = N''COM_DocNumData_History_AccDetailsID'')
CREATE NONCLUSTERED INDEX [COM_DocNumData_History_AccDetailsID] ON [dbo].[COM_DocNumData_History] 
([AccDocDetailsID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]'
	exec(@sql)
end
else if @TblName='COM_DocTextData_History'
begin
	set @sql='use '+@TargetDBName+'
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocTextData_History]'') AND name = N''COM_DocTextData_History_InvDetailsID'')
CREATE NONCLUSTERED INDEX [COM_DocTextData_History_InvDetailsID] ON [dbo].[COM_DocTextData_History] 
([InvDocDetailsID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocTextData_History]'') AND name = N''COM_DocTextData_History_ModDate'')
CREATE NONCLUSTERED INDEX [COM_DocTextData_History_ModDate] ON [dbo].[COM_DocTextData_History] 
([ModifiedDate] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocTextData_History]'') AND name = N''COM_DocTextData_History_AccDetailsID'')
CREATE NONCLUSTERED INDEX [COM_DocTextData_History_AccDetailsID] ON [dbo].[COM_DocTextData_History] 
([AccDocDetailsID] ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]'
	exec(@sql)
end

COMMIT TRANSACTION
SET NOCOUNT OFF;

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	
	SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
	FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 --AND LanguageID=@LangID
	
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH 
GO
