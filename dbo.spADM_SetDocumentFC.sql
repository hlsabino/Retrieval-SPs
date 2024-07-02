USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDocumentFC]
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
SET NOCOUNT ON    
BEGIN TRY    
	declare @prefVal nvarchar(20),@objID bigint, @i int,@NumDataFound int,@colsql nvarchar(max),@c1 nvarchar(20),@c2 nvarchar(20),@c3 nvarchar(20),@c4 nvarchar(20),@c5 nvarchar(20)
	declare @msg nvarchar(max)
	select @prefVal=Value from ADM_GlobalPreferences WHERE Name='Use Foreign Currency'
	set @objID=object_id('COM_DocNumData')
	set @i=1
	--set @prefVal='False'
	if @prefVal='True'
		set @msg='Field already added'
	else
		set @msg='Field already removed'
	while(@i<=100)
	begin
	--	select * from COM_DocNumData
		if @prefVal='True'
		begin
			if exists (select * from sys.columns where object_id=@objID and name='dcNum'+convert(nvarchar,@i))
				and not exists (select * from sys.columns where object_id=@objID and name='dcCurrID'+convert(nvarchar,@i))
			begin
				set @colsql='alter table COM_DocNumData add dcCurrID'+convert(nvarchar,@i)+' int default(1)
				,dcExchRT'+convert(nvarchar,@i)+' float default(1)
				,dcCalcNumFC'+convert(nvarchar,@i)+' float'
				exec(@colsql)
			
				set @colsql='alter table COM_DocNumData_History add dcCurrID'+convert(nvarchar,@i)+' int default(1)
				,dcExchRT'+convert(nvarchar,@i)+' float default(1)
				,dcCalcNumFC'+convert(nvarchar,@i)+' float'
				exec(@colsql)
				set @msg='Field added successfully'
			end
		end
		else
		begin
			if exists (select * from sys.columns where object_id=@objID and name='dcNum'+convert(nvarchar,@i))
				and exists (select * from sys.columns where object_id=@objID and name='dcCurrID'+convert(nvarchar,@i))
			begin
				set @colsql='select @NumDataFound=count(*) from COM_DocNumData with(nolock) where dcCurrID'+convert(nvarchar,@i)+' is not null and dcCurrID'+convert(nvarchar,@i)+'!=1'
				EXEC sp_executesql @colsql,N' @NumDataFound INT OUTPUT',@NumDataFound OUTPUT  
				if(@NumDataFound!=0)
				begin
					set @colsql='Currency Data exists @ index '+convert(nvarchar,@i)
					RAISERROR(@colsql,16,1)  
				end
				else
				begin
					set @c3='dcCurrID'+convert(nvarchar,@i)
					set @c4='dcExchRT'+convert(nvarchar,@i)
					set @c5='dcCalcNumFC'+convert(nvarchar,@i)
					
					set @colsql=''
					select @colsql=@colsql+',['+d.name+']' from sys.columns c 
					inner join sys.default_constraints d on c.column_id=d.parent_column_id and c.object_id=d.parent_object_id
					where c.object_id=object_id('COM_DocNumData') and c.name in (@c3,@c4,@c5)
					if len(@colsql)>0
					begin
						select @colsql='alter table COM_DocNumData DROP CONSTRAINT '+substring(@colsql,2,len(@colsql))
						print(@colsql)
						exec(@colsql)
					end
					
					set @colsql=''
					select @colsql=@colsql+',['+d.name+']' from sys.columns c 
					inner join sys.default_constraints d on c.column_id=d.parent_column_id and c.object_id=d.parent_object_id
					where c.object_id=object_id('COM_DocNumData_History') and c.name in (@c3,@c4,@c5)
					if len(@colsql)>0
					begin
						select @colsql='alter table COM_DocNumData_History DROP CONSTRAINT '+substring(@colsql,2,len(@colsql))
						print(@colsql)
						exec(@colsql)
					end

					set @colsql='alter table COM_DocNumData drop column '+@c3+','+@c4+','+@c5
					print(@colsql)
					exec(@colsql)
					
					set @colsql='alter table COM_DocNumData_History drop column '+@c3+','+@c4+','+@c5
					print(@colsql)
					exec(@colsql)
					set @msg='Field removed successfully'
				end
			end
		end
		set @i=@i+1
	end


SET NOCOUNT OFF;     
COMMIT TRANSACTION 
--ROLLBACK TRANSACTION
SELECT @msg ErrorMessage,100 ErrorNumber
SET NOCOUNT OFF;      
RETURN 1
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]  
 
 IF ERROR_NUMBER()=50000    
 BEGIN    
	if isnumeric(ERROR_MESSAGE())=0
		SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber
	else
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
 ROLLBACK TRANSACTION    
 SET NOCOUNT OFF      
 RETURN -999       
END CATCH     
GO
