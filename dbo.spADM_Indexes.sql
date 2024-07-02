USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_Indexes]
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @I int,@CNT int,@CCID int,@ColID nvarchar(20),@SQL nvarchar(max)
	declare @Tbl as Table(ID int identity(1,1),CostCenterID int)
	
	insert into @Tbl
	select distinct Value from ADM_GlobalPreferences with(nolock)
	where Name in ('Maintain Dimensionwise stock'
	,'Maintain Dimensionwise AverageRate'
	,'Maintain Dimensionwise Bills'
	,'Maintain Dimensionwise Batches'
	,'DimensionwiseBins'
	,'DimensionwiseAssets')
	and Value is not null and Value!='' and isnumeric(Value)=1
	
	select @I=1,@CNT=count(*) from @Tbl
	while(@I<=@CNT)
	begin
		select @CCID=CostCenterID from @Tbl where ID=@I
		
		set @ColID='dcCCNID'+convert(nvarchar,@CCID-50000)
		set @SQL='IF not EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_DocCCData]'') AND name = N''COM_DocCCData_'+@ColID+'_Index'')
		CREATE NONCLUSTERED INDEX [COM_DocCCData_'+@ColID+'_Index] ON [dbo].[COM_DocCCData] 
		('+@ColID+' ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]'
		--print(@SQL)
		exec(@SQL)
		
		set @ColID='CCNID'+convert(nvarchar,@CCID-50000)
		set @SQL='IF not EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N''[dbo].[COM_CCCCData]'') AND name = N''COM_CCCCData_'+@ColID+'_Index'')
		CREATE NONCLUSTERED INDEX [COM_CCCCData_'+@ColID+'_Index] ON [dbo].[COM_CCCCData] 
		('+@ColID+' ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]'
		--print(@SQL)
		exec(@SQL)

		set @I=@I+1
	end

	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID  
	
	RETURN 1
GO
