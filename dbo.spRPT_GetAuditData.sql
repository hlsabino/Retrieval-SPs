USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetAuditData]
	@CostCenterID [int] = 7,
	@QueryWhere [nvarchar](max) = '',
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	
	DECLARE @SQL NVARCHAR(MAX) ,@WHERE NVARCHAR(MAX)
	
	IF (@CostCenterID=7)
	BEGIN
		
		set @WHERE='' 
		set @SQL='SELECT [Nxt].UserHistoryID,[Nxt].UserName,[Nxt].CreatedBy,convert(datetime,[Nxt].CreatedDate) CreatedDate,[Nxt].ModifiedBy,convert(datetime,[Nxt].ModifiedDate) ModifiedDate,[Nxt].HistoryStatus'

		select @SQL=@SQL +(CASE WHEN a.name='StatusID' THEN ',[CurrStatus].[Status] old'+a.name+',[NxtStatus].[Status] new'+a.name
		ELSE ',[Curr].'+a.name+' old'+a.name+',[Nxt].'+a.name+' new'+a.name END)
		+',case when (([Curr].'+a.name+'=[Nxt].'+a.name+') OR ([Curr].'+a.name+' IS NULL AND [Nxt].'+a.name+' IS NULL)) then 0 else 1 end diff'+a.name
		,@WHERE=@WHERE+'(case when (([Curr].'+a.name+'=[Nxt].'+a.name+') OR ([Curr].'+a.name+' IS NULL AND [Nxt].'+a.name+' IS NULL)) then 0 else 1 end) = 1 OR '
		from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='ADM_UsersHistory' and a.name not in ('UserHistoryID','UserID','UserName','GUID','CreatedBy','CreatedDate','ModifiedBy','ModifiedDate','HistoryStatus')
		and a.name not like '%Password'
		
		set @SQL=@SQL+' FROM ADM_UsersHistory [Curr] WITH(NOLOCK)
		JOIN COM_Status [CurrStatus] WITH(NOLOCK) ON [CurrStatus].StatusID=[Curr].StatusID
		JOIN ADM_UsersHistory [Nxt] WITH(NOLOCK) ON [Nxt].UserID=[Curr].UserID 
		JOIN COM_Status [NxtStatus] WITH(NOLOCK) ON [NxtStatus].StatusID=[Nxt].StatusID
		AND [Nxt].UserHistoryID=(SELECT MIN(UserHistoryID) FROM ADM_UsersHistory WITH(NOLOCK) WHERE UserID=[Curr].UserID AND UserHistoryID>[Curr].UserHistoryID)
		WHERE 1=1 '
		
		if(@QueryWhere is not null and @QueryWhere<>'')
			set @SQL=@SQL+@QueryWhere
			
		if(@WHERE is not null and @WHERE<>'')
			set @SQL=@SQL+' AND ('+SUBSTRING(@WHERE,0,LEN(@WHERE)-2)+')'
		
		set @SQL=@SQL+' ORDER BY [Nxt].UserName,[Nxt].ModifiedDate'
	
	END
	ELSE IF (@CostCenterID=400)
	BEGIN
		set @WHERE='' 
		set @SQL='SELECT [Nxt].CostCenterID,[Nxt].CostCenterName DocName,[Nxt].CostCenterColID,[Nxt].SysColumnName,[Nxt].CreatedBy,convert(datetime,[Nxt].CreatedDate) CreatedDate,[Nxt].ModifiedBy,convert(datetime,[Nxt].ModifiedDate) ModifiedDate'

		select @SQL=@SQL +',[Curr].'+a.name+' old'+a.name+',[Nxt].'+a.name+' new'+a.name
		+',case when (([Curr].'+a.name+'=[Nxt].'+a.name+') OR ([Curr].'+a.name+' IS NULL AND [Nxt].'+a.name+' IS NULL)) then 0 else 1 end diff'+a.name
		,@WHERE=@WHERE+'(case when (([Curr].'+a.name+'=[Nxt].'+a.name+') OR ([Curr].'+a.name+' IS NULL AND [Nxt].'+a.name+' IS NULL)) then 0 else 1 end) = 1 OR '
		from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='ADM_CostCenterDef_History' and a.name not in ('CostCenterID','CostCenterColID','ResourceID','CostCenterName','SysTableName','SysColumnName','ColumnDataType','CompanyGUID','GUID','CreatedBy','CreatedDate','ModifiedBy','ModifiedDate')
		
		
		set @SQL=@SQL+' FROM ADM_CostCenterDef_History [Curr] WITH(NOLOCK)
		JOIN ADM_CostCenterDef_History [Nxt] WITH(NOLOCK) ON [Nxt].CostCenterColID=[Curr].CostCenterColID AND [Nxt].CostCenterID=[Curr].CostCenterID 
		AND [Nxt].ModifiedDate=(SELECT MIN(ModifiedDate) FROM ADM_CostCenterDef_History WITH(NOLOCK) WHERE CostCenterColID=[Curr].CostCenterColID AND CostCenterID=[Curr].CostCenterID AND ModifiedDate>[Curr].ModifiedDate)
		WHERE [Nxt].SysColumnName NOT LIKE ''dcCalc%'' AND [Nxt].SysColumnName NOT LIKE ''dcCurrID%'' AND [Nxt].SysColumnName NOT LIKE ''dcExchRT%'' '
		
		if(@QueryWhere is not null and @QueryWhere<>'')
			set @SQL=@SQL+@QueryWhere
			
		if(@WHERE is not null and @WHERE<>'')
			set @SQL=@SQL+' AND ('+SUBSTRING(@WHERE,0,LEN(@WHERE)-2)+')'
		
		set @SQL=@SQL+' ORDER BY [Nxt].CostCenterID,[Nxt].SysColumnName,[Nxt].ModifiedDate'
		

		--set @WHERE='' 
		--set @SQL=@SQL+' SELECT [Nxt].CostCenterID,[Nxt].CostCenterColID,[Nxt].CreatedBy,convert(datetime,[Nxt].CreatedDate) CreatedDate,[Nxt].ModifiedBy,convert(datetime,[Nxt].ModifiedDate) ModifiedDate'

		--select @SQL=@SQL +',[Curr].'+a.name+' old'+a.name+',[Nxt].'+a.name+' new'+a.name 
		--+',case when (([Curr].'+a.name+'=[Nxt].'+a.name+') OR ([Curr].'+a.name+' IS NULL AND [Nxt].'+a.name+' IS NULL)) then 0 else 1 end diff'+a.name
		--,@WHERE=@WHERE+'(case when (([Curr].'+a.name+'=[Nxt].'+a.name+') OR ([Curr].'+a.name+' IS NULL AND [Nxt].'+a.name+' IS NULL)) then 0 else 1 end) = 1 OR '
		--from sys.columns a
		--join sys.tables b on a.object_id=b.object_id
		--where b.name='ADM_DocumentDef_History' and a.name not in ('CostCenterID','CostCenterColID','CompanyGUID','GUID','CreatedBy','CreatedDate','ModifiedBy','ModifiedDate')
		
		
		--set @SQL=@SQL+' FROM ADM_DocumentDef_History [Curr] WITH(NOLOCK)
		--JOIN ADM_DocumentDef_History [Nxt] WITH(NOLOCK) ON [Nxt].CostCenterColID=[Curr].CostCenterColID AND [Nxt].CostCenterID=[Curr].CostCenterID 
		--AND [Nxt].ModifiedDate=(SELECT MIN(ModifiedDate) FROM ADM_DocumentDef_History WITH(NOLOCK) WHERE CostCenterColID=[Curr].CostCenterColID AND CostCenterID=[Curr].CostCenterID AND ModifiedDate>[Curr].ModifiedDate)
		--WHERE 1=1 '
		
		--if(@QueryWhere is not null and @QueryWhere<>'')
		--	set @SQL=@SQL+@QueryWhere
			
		--if(@WHERE is not null and @WHERE<>'')
		--	set @SQL=@SQL+' AND ('+SUBSTRING(@WHERE,0,LEN(@WHERE)-2)+')'
		
		--set @SQL=@SQL+' ORDER BY [Nxt].CostCenterID,[Nxt].CostCenterColID,[Nxt].ModifiedDate'
	END
	--print substring(@SQL,0,4000)
	--print substring(@SQL,4000,4000)
	--print substring(@SQL,8000,4000)
	--print substring(@SQL,12000,4000)
	--print substring(@SQL,16000,4000)
	--print substring(@SQL,20000,4000)
	--print substring(@SQL,24000,4000)
	--print substring(@SQL,28000,4000)
	--print substring(@SQL,32000,4000)
	--print substring(@SQL,36000,4000)
	--print substring(@SQL,40000,4000)
	exec(@SQL)


END
--SELECT * FROM ADM_UsersHistory
GO
