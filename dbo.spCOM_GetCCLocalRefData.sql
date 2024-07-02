USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCCLocalRefData]
	@CostCenterID [int],
	@NodeID [bigint],
	@FieldsXML [nvarchar](max)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @SQL nvarchar(max),@TableName nvarchar(200),@CNT int,@I int,@PK nvarchar(50),@PKTemp nvarchar(50),@val nvarchar(max)
		,@SysTableName nvarchar(50),@SysColumnName nvarchar(100),@ColumnDataType nvarchar(50),@xml xml

	Declare @TEMPUNIQUE TABLE(ID INT identity(1,1),CostCenterColID bigint,SysTableName NVARCHAR(50),SysColumnName NVARCHAR(50),ColumnDataType NVARCHAR(50),LinkValue NVARCHAR(max))
	
	set @xml=@FieldsXML

	INSERT INTO @TEMPUNIQUE(CostCenterColID,SysTableName,SysColumnName,ColumnDataType)
	select CC.CostCenterColID,CC.SysTableName,CC.SysColumnName,CC.ColumnDataType
	from ADM_COSTCENTERDEF CC with(NOLOCK)
	inner join @XML.nodes('/XML/R') as Data(X) ON X.value('@LinkID','BIGINT')=CC.CostCenterColID
	where CC.COSTCENTERID=@CostCenterID

	select @CNT=count(*) from @TEMPUNIQUE
	
	select @TableName=TableName,@PK=PrimaryKey from ADM_Features with(NOLOCK) where FeatureID=@CostCenterID

	SET  @I = 0 
	WHILE @I<@CNT
	BEGIN     
		SET @I=@I+1
		SELECT @SysTableName=SysTableName,@SysColumnName=SysColumnName,@ColumnDataType=ColumnDataType FROM @TEMPUNIQUE WHERE ID=@I
		set @PKTemp=@PK
		set @val=null
		if @SysTableName='COM_CCCCData'
		begin
			set @SQL='select @val='+@SysColumnName+' from COM_CCCCData with(nolock) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+convert(nvarchar,@NodeID)
			--print(@SQL)		
			exec sp_executesql @SQL,N'@val nvarchar(max) output',@val output
		end
		else
		begin
			set @SQL='select @val='+@SysColumnName+' from '+@SysTableName+' with(nolock) where '+@PK+'='+convert(nvarchar,@NodeID)
			--print(@SQL)		
			exec sp_executesql @SQL,N'@val nvarchar(max) output',@val output
			if(@ColumnDataType='DATE' and isdate(@val)=1)
				set @val=convert(nvarchar,convert(datetime,@val))
		end
		--select @val
		update @TEMPUNIQUE set LinkValue=@val WHERE ID=@I
	END
	select CostCenterColID,LinkValue from @TEMPUNIQUE
GO
