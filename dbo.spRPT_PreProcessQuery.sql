USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_PreProcessQuery]
	@Type [int] = 0,
	@ReportID [bigint],
	@Query [nvarchar](max) = NULL,
	@GroupID [bigint],
	@Token [nvarchar](50) = NULL,
	@CompanyIndex [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;

DECLARE @DbName nvarchar(50),@Str nvarchar(max),@TempDBName nvarchar(50)
set @DbName=DB_NAME()
set @TempDBName=@DbName+'_TEMP'
if not exists(select name from sys.databases where name=@TempDBName)
begin
	declare @path nvarchar(500)
	select @path=replace(F.physical_name,'.mdf','_TEMP.mdf') from sys.databases D 
	inner join sys.master_files F on D.database_id=F.database_id
	where D.name=@DbName and F.type_desc='ROWS'
	
	BEGIN TRY      
		set @Str='CREATE DATABASE '+@TempDBName+' ON  PRIMARY (NAME = '''+@TempDBName+''', FILENAME ='''+@path+''')
		 LOG ON (NAME='''+@TempDBName+'_log'', FILENAME='''+replace(@path,'.mdf','.ldf')+''')'
		 
		 --	CREATE DATABASE PACT2C_TEMP ON  PRIMARY (NAME = 'PACT2C_TEMP', FILENAME ='D:\Database\RevenU\PAC2C.mdf')
		 --LOG ON (NAME='PACT2C_TEMP_log', FILENAME='D:\Database\RevenU\PAC2C.ldf')
		--print(@Str)
		exec(@Str)
	END TRY
	BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  
		IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END	
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END
		SET NOCOUNT OFF  
		RETURN -999   
	END CATCH
end


declare @ProcessStartsOn float,@TempToken nvarchar(50)

if @Type=0
begin
	select @ProcessStartsOn=ProcessStartsOn from ADM_RevenUReports with(nolock) where ReportID=@ReportID

	if (@ProcessStartsOn is not null)
		RAISERROR('-101',16,1)

	set @ProcessStartsOn=convert(float,getdate())
	update ADM_RevenUReports set ProcessStartsOn=@ProcessStartsOn where ReportID=@ReportID

	set @Str=N'USE PACT2C'+convert(nvarchar,@CompanyIndex)+'_TEMP
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].[RPT_TBL'+convert(nvarchar,@ReportID)+']'') AND type in (N''U''))
DROP TABLE [dbo].RPT_TBL'+convert(nvarchar,@ReportID)
	exec(@Str)

	exec(@Query)
	
	update ADM_RevenUReports
	set ProcessedOn=convert(float,getdate()),ProcessStartsOn=null,ProcessedBy=@UserID
	where ReportID=@ReportID
end
else if @Type=1
begin
	if not exists (select ReportID from ADM_RevProcessdReports with(nolock) where ReportID=@ReportID)
	begin
		insert into ADM_RevProcessdReports(ReportID,ColumnsObj,GroupFilter)
		values(@ReportID,@Query,@GroupID)
	end
	else
	begin
		select @TempToken=Token from ADM_RevProcessdReports with(nolock) where ReportID=@ReportID
		if (@TempToken is not null)
			RAISERROR('-101',16,1)
		update ADM_RevProcessdReports set ColumnsObj=@Query where ReportID=@ReportID
	end

	set @TempToken=newid()
	update ADM_RevProcessdReports set Token=@TempToken,ProcessedBy=@UserID,ProcessedOn=convert(float,getdate()) where ReportID=@ReportID

	set @Str=N'USE PACT2C'+convert(nvarchar,@CompanyIndex)+'_TEMP
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].[RPT_OBJ'+convert(nvarchar,@ReportID)+']'') AND type in (N''U''))
TRUNCATE TABLE [dbo].RPT_OBJ'+convert(nvarchar,@ReportID)+'
ELSE
CREATE TABLE [dbo].RPT_OBJ'+convert(nvarchar,@ReportID)+'
(
	ID int NOT NULL IDENTITY (1, 1) PRIMARY KEY,
	GroupID bigint NULL,
	RowObject nvarchar(MAX) NOT NULL
)
'
	exec(@Str)

	select @TempToken Token
end
else if @Type=2
begin
	if not exists (select ReportID from ADM_RevProcessdReports with(nolock) where ReportID=@ReportID and Token=@Token)
		RAISERROR('-101',16,1)
	set @Query='USE PACT2C'+convert(nvarchar,@CompanyIndex)+'_TEMP
	insert into RPT_OBJ'+convert(nvarchar,@ReportID)+'(GroupID,RowObject)
	values('+convert(nvarchar,@GroupID)+','''+@Query+''')'
	--print(@Query)
	exec(@Query)
end
else if @Type=3
begin
	if not exists (select ReportID from ADM_RevProcessdReports with(nolock) where ReportID=@ReportID and Token=@Token)
		RAISERROR('-101',16,1)

	update ADM_RevProcessdReports
	set ProcessedOn=convert(float,getdate()),Token=null
	where ReportID=@ReportID
end
	
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
RETURN 1
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  
		IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1
		END
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=1
		END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
