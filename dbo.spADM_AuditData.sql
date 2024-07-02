USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_AuditData]
	@Type [int],
	@CostCenterID [int],
	@NodeID [bigint],
	@HistoryStatus [nvarchar](50),
	@Options [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @DbName nvarchar(50),@sql nvarchar(max),@ArchDBName nvarchar(50)
set @DbName=DB_NAME()
set @ArchDBName=@DbName+'_ARCHIVE'
	
if not exists(select name from sys.databases where name=@ArchDBName)
begin
	declare @path nvarchar(500)
	select @path=replace(F.physical_name,'.mdf','_ARCHIVE.mdf') from sys.databases D 
	inner join sys.master_files F on D.database_id=F.database_id
	where D.name=@DbName and F.type_desc='ROWS'
	
	BEGIN TRY      
		set @sql='CREATE DATABASE '+@ArchDBName+' ON  PRIMARY (NAME = '''+@ArchDBName+''', FILENAME ='''+@path+''')
		 LOG ON (NAME='''+@ArchDBName+'_log'', FILENAME='''+replace(@path,'.mdf','.ldf')+''')'
		 
		 --	CREATE DATABASE PACT2C_ARCHIVE ON  PRIMARY (NAME = 'PACT2C_ARCHIVE', FILENAME ='D:\Database\RevenU\PAC2C.mdf')
		 --LOG ON (NAME='PACT2C_ARCHIVE_log', FILENAME='D:\Database\RevenU\PAC2C.ldf')
		--print(@sql)
		exec(@sql)
	END TRY
	BEGIN CATCH  
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


BEGIN TRANSACTION
BEGIN TRY
	--Declaration Section    
	DECLARE @TblName nvarchar(max),@ExtendedColsXML nvarchar(max),@HistoryID bigint

	if @Type=1
	begin
		SET @TblName=@ArchDBName+'.dbo.COM_CCMastHistory'
		EXEC spADM_COPYTABLE 'COM_CCMastHistory',@ArchDBName,@TblName
		
		set @ExtendedColsXML=db_name()
		SET @TblName='COM_CCCCDataHistory'
		EXEC spADM_COPYTABLE 'COM_CCCCData',@ExtendedColsXML,@TblName

		SET @TblName=@ArchDBName+'.dbo.COM_CCCCDataHistory'
		EXEC spADM_COPYTABLE 'COM_CCCCDataHistory',@ArchDBName,@TblName

		
		
		select @TblName=TableName from ADM_Features with(nolock) where FeatureID=@CostCenterID

		set @ExtendedColsXML=''
		select @ExtendedColsXML=@ExtendedColsXML+' alter table '+@ArchDBName+'.dbo.COM_CCMastHistory add '+a.name+ ' nvarchar(max)' 
		from sys.columns a
		left join sys.columns b on a.name=b.name and b.object_id=object_id('COM_CCMastHistory')
		where a.object_id=object_id (@TblName) and b.name is null and a.name like '%alpha%'
		 
		if(@ExtendedColsXML<>'')
		BEGIN
			exec (@ExtendedColsXML)
			
			set @ExtendedColsXML=''
			select @ExtendedColsXML=@ExtendedColsXML+' alter table COM_CCMastHistory add '+a.name+ ' nvarchar(max)' 
			from sys.columns a
			left join sys.columns b on a.name=b.name and b.object_id=object_id('COM_CCMastHistory')
			where a.object_id=object_id (@TblName) and b.name is null and a.name like '%alpha%'
			exec (@ExtendedColsXML)
		END

		set @ExtendedColsXML=''
		select @ExtendedColsXML =@ExtendedColsXML +a.name+',' from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name=@TblName
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)
		

		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.COM_CCMastHistory(CostCenterID,HistoryStatus,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@CostCenterID)+',@HistoryStatus,'+@ExtendedColsXML+' from '+@TblName+' with(nolock) where NodeID='+convert(nvarchar,@NodeID)+'
		 SET @HistoryID=SCOPE_IDENTITY()'--To get inserted record primary key  
		print(@SQL)
		exec sp_executesql @SQL,N'@HistoryID INT OUTPUT,@HistoryStatus nvarchar(50)',@HistoryID OUTPUT,@HistoryStatus
			
		set @ExtendedColsXML=''
		select @ExtendedColsXML =@ExtendedColsXML +a.name+',' from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='COM_CCCCData' --and (a.name not like 'CCNID%' or replace(a.name,'CCNID','')<=50)
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)

		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.COM_CCCCDataHistory(NodeHistoryID,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@HistoryID)+','+@ExtendedColsXML+' from COM_CCCCData with(nolock)
		 where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+convert(nvarchar,@NodeID)
		--print(@SQL)
		exec sp_executesql @SQL
	end
	else if @Type=2
	begin
		SET @TblName=@ArchDBName+'.dbo.COM_CCCCDataHistory'
		EXEC spADM_COPYTABLE 'COM_CCCCDataHistory',@ArchDBName,@TblName

		SET @TblName=@ArchDBName+'.dbo.PRD_BillOfMaterialHistory'
		EXEC spADM_COPYTABLE 'PRD_BillOfMaterialHistory',@ArchDBName,@TblName

		SET @TblName=@ArchDBName+'.dbo.PRD_BillOfMaterialExtendedHistory'
		EXEC spADM_COPYTABLE 'PRD_BillOfMaterialExtendedHistory',@ArchDBName,@TblName

		SET @TblName=@ArchDBName+'.dbo.PRD_BOMProductsHistory'
		EXEC spADM_COPYTABLE 'PRD_BOMProductsHistory',@ArchDBName,@TblName

		SET @TblName=@ArchDBName+'.dbo.PRD_BOMResourcesHistory'
		EXEC spADM_COPYTABLE 'PRD_BOMResourcesHistory',@ArchDBName,@TblName

		SET @TblName=@ArchDBName+'.dbo.PRD_BOMStagesHistory'
		EXEC spADM_COPYTABLE 'PRD_BOMStagesHistory',@ArchDBName,@TblName

		SET @TblName=@ArchDBName+'.dbo.PRD_ExpensesHistory'
		EXEC spADM_COPYTABLE 'PRD_ExpensesHistory',@ArchDBName,@TblName

		SET @TblName=@ArchDBName+'.dbo.PRD_JobOuputProductsHistory'
		EXEC spADM_COPYTABLE 'PRD_JobOuputProductsHistory',@ArchDBName,@TblName

		set @ExtendedColsXML=''
		select @ExtendedColsXML=@ExtendedColsXML+a.name+',' from sys.columns a join sys.tables b on a.object_id=b.object_id
		where b.name='PRD_BillOfMaterial'
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)
		
		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.PRD_BillOfMaterialHistory(HistoryStatus,'+@ExtendedColsXML+')    
		 select @HistoryStatus,'+@ExtendedColsXML+' from PRD_BillOfMaterial with(nolock) where BOMID='+convert(nvarchar,@NodeID)+'
		 SET @HistoryID=SCOPE_IDENTITY()'--To get inserted record primary key  
		--print(@SQL)
		exec sp_executesql @SQL,N'@HistoryID INT OUTPUT,@HistoryStatus nvarchar(50)',@HistoryID OUTPUT,@HistoryStatus

		set @ExtendedColsXML=''
		select @ExtendedColsXML =@ExtendedColsXML +a.name+',' from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='COM_CCCCData' --and (a.name not like 'CCNID%' or replace(a.name,'CCNID','')<=50)
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)

		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.COM_CCCCDataHistory(NodeHistoryID,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@HistoryID)+','+@ExtendedColsXML+' from COM_CCCCData with(nolock)
		 where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+convert(nvarchar,@NodeID)
		exec sp_executesql @SQL
		
		--PRD_BillOfMaterialExtended
		set @ExtendedColsXML=''
		select @ExtendedColsXML=@ExtendedColsXML+a.name+',' from sys.columns a join sys.tables b on a.object_id=b.object_id
		where b.name='PRD_BillOfMaterialExtended'
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)
		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.PRD_BillOfMaterialExtendedHistory(BOMHistoryID,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@HistoryID)+','+@ExtendedColsXML+' from PRD_BillOfMaterialExtended with(nolock)
		 where BOMID='+convert(nvarchar,@NodeID)
		exec sp_executesql @SQL
		
		--PRD_BOMProducts
		set @ExtendedColsXML=''
		select @ExtendedColsXML=@ExtendedColsXML+a.name+',' from sys.columns a join sys.tables b on a.object_id=b.object_id
		where b.name='PRD_BOMProducts'
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)
		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.PRD_BOMProductsHistory(BOMHistoryID,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@HistoryID)+','+@ExtendedColsXML+' from PRD_BOMProducts with(nolock)
		 where BOMID='+convert(nvarchar,@NodeID)
		exec sp_executesql @SQL
		
		--PRD_BOMResources
		set @ExtendedColsXML=''
		select @ExtendedColsXML=@ExtendedColsXML+a.name+',' from sys.columns a join sys.tables b on a.object_id=b.object_id
		where b.name='PRD_BOMResources'
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)
		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.PRD_BOMResourcesHistory(BOMHistoryID,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@HistoryID)+','+@ExtendedColsXML+' from PRD_BOMResources with(nolock)
		 where BOMID='+convert(nvarchar,@NodeID)
		exec sp_executesql @SQL

		--PRD_BOMStages
		set @ExtendedColsXML=''
		select @ExtendedColsXML=@ExtendedColsXML+a.name+',' from sys.columns a join sys.tables b on a.object_id=b.object_id
		where b.name='PRD_BOMStages'
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)
		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.PRD_BOMStagesHistory(BOMHistoryID,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@HistoryID)+','+@ExtendedColsXML+' from PRD_BOMStages with(nolock)
		 where BOMID='+convert(nvarchar,@NodeID)
		exec sp_executesql @SQL

		--PRD_Expenses
		set @ExtendedColsXML=''
		select @ExtendedColsXML=@ExtendedColsXML+a.name+',' from sys.columns a join sys.tables b on a.object_id=b.object_id
		where b.name='PRD_Expenses'
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)
		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.PRD_ExpensesHistory(BOMHistoryID,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@HistoryID)+','+@ExtendedColsXML+' from PRD_Expenses with(nolock)
		 where BOMID='+convert(nvarchar,@NodeID)
		exec sp_executesql @SQL

		--PRD_JobOuputProducts
		set @ExtendedColsXML=''
		select @ExtendedColsXML=@ExtendedColsXML+a.name+',' from sys.columns a join sys.tables b on a.object_id=b.object_id
		where b.name='PRD_JobOuputProducts'
		set @ExtendedColsXML=substring(@ExtendedColsXML,1,len(@ExtendedColsXML)-1)
		SET @SQL='INSERT INTO '+@ArchDBName+'.dbo.PRD_JobOuputProductsHistory(BOMHistoryID,'+@ExtendedColsXML+')    
		 select '+convert(nvarchar,@HistoryID)+','+@ExtendedColsXML+' from PRD_JobOuputProducts with(nolock)
		 where BOMID='+convert(nvarchar,@NodeID)
		exec sp_executesql @SQL
	end

COMMIT TRANSACTION
--ROLLBACK TRANSACTION

--SET NOCOUNT OFF; 
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
