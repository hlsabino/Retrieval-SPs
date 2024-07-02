USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_GetAutCodeXML]
	@PrefixXML [nvarchar](max),
	@NodeID [bigint],
	@PK [nvarchar](50),
	@Retxml [nvarchar](max) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON    

	DECLARE @TblDef AS TABLE(ID INT IDENTITY(1,1),colid bigint,ColNAME nvarchar(300),TblName NVARCHAR(200))
	declare @COUNT int,@I int,@SQL nvarchar(max),@NAME nvarchar(200),@TblName NVARCHAR(200),@colID bigint,@Val nvarchar(max),@xml xml,@CCID int
		
	set @xml=@PrefixXML
	set @Retxml='<Data>'
	
	if isnumeric(@PK)=1
		select @CCID=FeatureID,@PK=PrimaryKey from ADM_Features with(nolock) where FeatureID=@PK
	else
		set @CCID=72
		
	INSERT INTO @TblDef
	SELECT X.value('@CCCID','bigint'),d.SysColumnName,d.SysTableName	
	FROM @xml.nodes('XML/Row') as DATA(X)
	join ADM_CostCenterDef d on abs(X.value('@CCCID','bigint'))=d.CostCenterColID
	
	SELECT @COUNT=COUNT(*) FROM @TblDef  
	SET @I=0 
			  
	WHILE @I<@COUNT
	BEGIN 
		set @I=@I+1
		set @NAME=''
		SELECT @NAME=ColNAME,@TblName=TblName,@colID=colid FROM @TblDef  WHERE ID=@I 
		if(@NAME!='')
		BEGIN
			if(@NAME like 'CCNID%')
				set @SQL='select @Val='+@NAME+' from '+@TblName+' with(nolock) where CostCenterID='+convert(nvarchar,@CCID)+' and NodeID='+convert(nvarchar,@NodeID)
			ELSE
				set @SQL='select @Val='+@NAME+' from '+@TblName+' with(nolock) where '+@PK+'='+convert(nvarchar,@NodeID)
		--select @SQL
			exec sp_executesql @SQL,N'@Val NVARCHAR(MAX) OUTPUT',@Val OUTPUT
			
			set @Retxml=@Retxml+'<Row ColID="'+CONVERT(nvarchar,@colID)+'"  Value="'+@Val+'" />'					
		END
	END	
	if(@Retxml='<Data>')
		set @Retxml=''
	else
		set @Retxml	=@Retxml+'</Data>'

SET NOCOUNT OFF;    
GO
