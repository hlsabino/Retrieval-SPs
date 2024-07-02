USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TestExtended]
	@XML [nvarchar](max),
	@CostCenterID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @ixml INT
DECLARE @TempExtended TABLE (
ID [int] IDENTITY(1,1) NOT NULL,
name nvarchar(200),
value nvarchar(200),
type nvarchar(200)
)
SET NOCOUNT ON 
EXEC sp_xml_preparedocument @ixml OUTPUT, @XML
insert into @TempExtended(name,value,type)
SELECT Name, Value,Type
	FROM OPENXML(@ixml,'/ExtraFields/Field',2)
	WITH (Name nvarchar(200) , Value nvarchar(200),Type nvarchar(200) )
EXEC sp_xml_removedocument @ixml

Declare @Cols int
Declare @counter int
Declare @ColName nvarchar(max)
Declare @SQL nvarchar(max)
Declare @Name nvarchar(max)
Declare @Value nvarchar(max)
Declare @Type nvarchar(max)
SET @counter=1
SET @SQL=''
Select @Cols = count(id) from @TempExtended
 
while @counter <= @Cols-1
BEGIN
	select @Name=Name,@Value=Value,@Type=Type from @TempExtended where ID=@counter
	 

 SET @ColName=(SELECT SysColumnName FROM ADM_CostCenterDef WHERE
 CostCenterID=@CostCenterID and (SysColumnName= @Name or  UserColumnName=@Name ))

if(@Type='TEXT')
set @Value=''''+@Value+''''


	SET @SQL = @SQL + @ColName +'='+ @Value + ','	
 
SET @counter=@counter+1
END

select @Name=Name,@Value=Value,@Type=Type from @TempExtended where ID=@Cols
 SET @ColName=(SELECT SysColumnName FROM ADM_CostCenterDef WHERE
 CostCenterID=@CostCenterID and (SysColumnName= @Name or  UserColumnName=@Name ))

if(@Type='TEXT')
set @Value=''''+@Value+''''

SET @SQL = @SQL + @ColName +'='+ @Value

select 'final query   ' + @SQL
SET NOCOUNT OFF 
GO
