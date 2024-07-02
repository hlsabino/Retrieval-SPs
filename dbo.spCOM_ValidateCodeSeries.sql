USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_ValidateCodeSeries]
	@CCID [int],
	@NodeID [bigint],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @IsManual BIT,@SeriesStart bigint,@SeriesEnd bigint,@ParentGroup nvarchar(200),@PID bigint,@RootID bigint
	declare @SQL nvarchar(max),@ColName nvarchar(20),@TblName nvarchar(50),@PK nvarchar(30)
		
	select @IsManual=IsManual,@SeriesStart=SeriesStart,@SeriesEnd=SeriesEnd
	from COM_CCCCDATA DCC with(nolock) 
	where DCC.CostCenterID=@CCID AND DCC.NodeID=@NodeID

	if @IsManual=1 or @SeriesEnd=0 or not exists(select ShowSeriesNos from COM_costcentercodedef with(nolock) where CostCenterID=@CCID and IsGroupCode=1 and ShowSeriesNos=1)
		return 0

	select @TblName=TableName,@PK=PrimaryKey from ADM_Features with(nolock) where FeatureID=@CCID

	--Check For Is Group
	set @SQL='select @ColName=convert(nvarchar,'+@PK+') from '+@TblName+' with(nolock) where '+@PK+'='+convert(nvarchar,@NodeID)+' and IsGroup=1'
	EXEC sp_executesql @SQL,N'@ColName nvarchar(200) OUTPUT',@ColName OUTPUT

	if @ColName is null
		return 0
		
	create table #TblSeries(ID int identity(1,1),NodeID bigint,SeriesStart int,SeriesEnd int,Depth int,Name nvarchar(200),PType int)
	
	if @CCID=2 set @ColName='AccountName'
	else if @CCID=3 set @ColName='ProductName'
	else if @CCID=86 set @ColName='Code'
	else if @CCID>50000 set @ColName='Name'
	else set @ColName=@PK
	
	set @SQL='select G.'+@PK+',SeriesStart,SeriesEnd,G.Depth,G.'+@ColName+',1 from '+@TblName+' P with(nolock) 
	inner join '+@TblName+' G with(nolock) ON P.lft between G.lft and G.rgt
	inner join COM_CCCCDATA DCC with(nolock) ON DCC.CostCenterID='+convert(nvarchar,@CCID)+' and DCC.NodeID=G.'+@PK+'
	where G.IsGroup=1 and P.'+@PK+'='+convert(nvarchar,@NodeID)+' and G.'+@PK+'!='+convert(nvarchar,@NodeID)+' and G.Depth>0
	and DCC.IsManual=0 and DCC.SeriesEnd!=0
	order by G.lft'
	insert into #TblSeries
	exec(@SQL)
	
	select @ParentGroup=Name,@PID=NodeID from #TblSeries where (@SeriesStart not between SeriesStart and SeriesEnd) or (@SeriesEnd not between SeriesStart and SeriesEnd)
	if @ParentGroup is not null
	begin
		SELECT ErrorMessage+@ParentGroup ErrorMessage,-146 ErrorNumber FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-146 AND LanguageID=@LangID
		drop table #TblSeries
		--select @PID,@ParentGroup,1
		return @PID
	end
	
	set @SQL='select G.'+@PK+',SeriesStart,SeriesEnd,G.Depth,G.'+@ColName+',2 from '+@TblName+' P with(nolock) 
	inner join '+@TblName+' G with(nolock) ON G.lft between P.lft and P.rgt
	inner join COM_CCCCDATA DCC with(nolock) ON DCC.CostCenterID='+convert(nvarchar,@CCID)+' and DCC.NodeID=G.'+@PK+'
	where G.IsGroup=1 and P.'+@PK+'='+convert(nvarchar,@NodeID)+' and G.'+@PK+'!='+convert(nvarchar,@NodeID)+' and G.Depth>0 and DCC.IsManual=0
	and DCC.IsManual=0 and DCC.SeriesEnd!=0
	order by G.lft'
	insert into #TblSeries
	exec(@SQL)
	

	select @ParentGroup=Name,@PID=NodeID from #TblSeries where PType=2 and ((SeriesStart not between @SeriesStart and @SeriesEnd) or (SeriesEnd not between @SeriesStart and @SeriesEnd))
	if @ParentGroup is not null
	begin
		SELECT ErrorMessage+@ParentGroup ErrorMessage,-146 ErrorNumber FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-146 AND LanguageID=@LangID
		drop table #TblSeries
		--select @PID,@ParentGroup,2
		return @PID
	end
	
	set @SQL='select CG.'+@PK+',DCC.SeriesStart,DCC.SeriesEnd,CG.Depth,CG.'+@ColName+',3 from '+@TblName+' P with(nolock) 
	inner join #TblSeries T on T.NodeID=P.'+@PK+'
	inner join '+@TblName+' CG with(nolock) ON CG.lft between P.lft and P.rgt
	inner join COM_CCCCDATA DCC with(nolock) ON DCC.CostCenterID='+convert(nvarchar,@CCID)+' and DCC.NodeID=CG.'+@PK+'
	left join #TblSeries TE on TE.NodeID=CG.'+@PK+'
	where T.PType=1 and T.ID=1 and CG.IsGroup=1 and CG.'+@PK+'!='+convert(nvarchar,@NodeID)+' and DCC.IsManual=0 and TE.ID IS NULL
	and DCC.IsManual=0 and DCC.SeriesEnd!=0
	order by CG.lft'
	insert into #TblSeries
	exec(@SQL)
	
	select @ParentGroup=Name,@PID=NodeID from #TblSeries where PType=3 and ((@SeriesStart between SeriesStart and SeriesEnd) or (@SeriesEnd between SeriesStart and SeriesEnd))
	if @ParentGroup is not null
	begin
		SELECT ErrorMessage+@ParentGroup ErrorMessage,-146 ErrorNumber FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-146 AND LanguageID=@LangID
		drop table #TblSeries
		return @PID
	end
	
RETURN 0 
GO
