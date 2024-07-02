USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_AlterTableIdentity]
	@Type [int],
	@table_name [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON

	IF @TYPE=1
	BEGIN
		select o.name TableName
		from sys.columns c WITH(NOWAIT) 
		inner join sys.identity_columns ic WITH(NOWAIT) ON c.is_identity=1 AND c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
		inner join sys.objects o WITH (NOWAIT) ON o.[object_id]=c.[object_id]
		where ic.seed_value!=-10001 and ic.seed_value!=500001 and o.type='U' and o.name!='sysdiagrams' and o.name!='POS_loginHistory'
		order by TableName
		
		if not exists(select * from Adm_GlobalPreferences with(nolock) where Name='IsOffline')
		begin
			set identity_insert Adm_GlobalPreferences ON
			insert into Adm_GlobalPreferences(GlobalPrefID,ResourceID,Name,Value,DefaultValue,GUID,CreatedBy,CreatedDate)
			values(-100,0,'IsOffline','True','False','GUID','ADMIN',1)
			insert into Adm_GlobalPreferences(GlobalPrefID,ResourceID,Name,Value,DefaultValue,GUID,CreatedBy,CreatedDate)
			values(-101,0,'OfflineGUID',replace(newid(),'-',''),'','GUID','ADMIN',1)
			set identity_insert Adm_GlobalPreferences OFF
		end
		else
		begin
			update Adm_GlobalPreferences
			set Value='True'
			where Name='IsOffline'
		end
	END
	IF @TYPE=2
	BEGIN
		DECLARE @object_name SYSNAME,@tempobject_name SYSNAME,@object_id INT
		declare @TblIndexCols as TABLE([object_id] bigint,index_id bigint,is_descending_key bit,is_included_column bit,name nvarchar(50))
		declare @TblFKCols as TABLE(constraint_object_id bigint,cname nvarchar(500),rcname nvarchar(500))

		SELECT @object_name='['+s.name+'].['+o.name+']',@tempobject_name='['+s.name+'].[Temp_'+o.name+']', @object_id = o.[object_id]
		FROM sys.objects o WITH (NOWAIT)
		JOIN sys.schemas s WITH (NOWAIT) ON o.[schema_id] = s.[schema_id]
		WHERE s.name + '.' + o.name = @table_name AND o.[type] = 'U' AND o.is_ms_shipped = 0

		DECLARE @SQL NVARCHAR(MAX),@FKSQL NVARCHAR(MAX),@INDEXSQL NVARCHAR(MAX),@TEMPSQL NVARCHAR(MAX),@PK_SQL nvarchar(MAX),@COL_SQL nvarchar(MAX)


		insert into @TblIndexCols
		SELECT  ic.[object_id]
				, ic.index_id
				, ic.is_descending_key
				, ic.is_included_column
				, c.name
			FROM sys.index_columns ic WITH (NOWAIT)
			JOIN sys.columns c WITH (NOWAIT) ON ic.[object_id] = c.[object_id] AND ic.column_id = c.column_id
			WHERE ic.[object_id] = @object_id

		insert into @TblFKCols
		SELECT  k.constraint_object_id
				, cname = c.name
				, rcname = rc.name
			FROM sys.foreign_key_columns k WITH (NOWAIT)
			JOIN sys.columns rc WITH (NOWAIT) ON rc.[object_id] = k.referenced_object_id AND rc.column_id = k.referenced_column_id 
			JOIN sys.columns c WITH (NOWAIT) ON c.[object_id] = k.parent_object_id AND c.column_id = k.parent_column_id
			WHERE k.parent_object_id = @object_id
		    
		SET @COL_SQL=''
		SELECT @COL_SQL=@COL_SQL+',['+c.name+']' FROM sys.columns c WITH (NOWAIT) WHERE c.[object_id] = @object_id ORDER BY c.column_id
		SET @COL_SQL=substring(@COL_SQL,2,len(@COL_SQL))
		    
		SET @SQL=''
		SELECT @SQL = 'CREATE TABLE ' + @tempobject_name + CHAR(13) + '(' + CHAR(13) + STUFF((
			SELECT CHAR(9) + ',[' + c.name + '] ' + 
				CASE WHEN c.is_computed = 1
					THEN 'AS ' + cc.[definition] 
					ELSE UPPER(tp.name) + 
						CASE WHEN tp.name IN ('varchar', 'char', 'varbinary', 'binary')--, 'text'
							   THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(5)) END + ')'
							 WHEN tp.name IN ('nvarchar', 'nchar')--, 'ntext'
							   THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS VARCHAR(5)) END + ')'
							 WHEN tp.name IN ('datetime2', 'time2', 'datetimeoffset') 
							   THEN '(' + CAST(c.scale AS VARCHAR(5)) + ')'
							 WHEN tp.name = 'decimal' 
							   THEN '(' + CAST(c.[precision] AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
							ELSE ''
						END +
						--CASE WHEN c.collation_name IS NOT NULL THEN ' COLLATE ' + c.collation_name ELSE '' END +
						CASE WHEN c.is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END +
						CASE WHEN dc.[definition] IS NOT NULL THEN ' DEFAULT' + dc.[definition] ELSE '' END + 
						CASE WHEN ic.is_identity = 1 THEN ' IDENTITY(-10001,-1' + ')' ELSE '' END 
				END + CHAR(13)
			FROM sys.columns c WITH (NOWAIT)
			JOIN sys.types tp WITH (NOWAIT) ON c.user_type_id = tp.user_type_id
			LEFT JOIN sys.computed_columns cc WITH (NOWAIT) ON c.[object_id] = cc.[object_id] AND c.column_id = cc.column_id
			LEFT JOIN sys.default_constraints dc WITH (NOWAIT) ON c.default_object_id != 0 AND c.[object_id] = dc.parent_object_id AND c.column_id = dc.parent_column_id
			LEFT JOIN sys.identity_columns ic WITH (NOWAIT) ON c.is_identity = 1 AND c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
			WHERE c.[object_id] = @object_id
			ORDER BY c.column_id
			FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, CHAR(9) + ' ')
		    
			+ ISNULL((SELECT CHAR(9) + ', CONSTRAINT [' + k.name + '] PRIMARY KEY (' + 
							(SELECT STUFF((
								 SELECT ', [' + c.name + '] ' + CASE WHEN ic.is_descending_key = 1 THEN 'DESC' ELSE 'ASC' END
								 FROM sys.index_columns ic WITH (NOWAIT)
								 JOIN sys.columns c WITH (NOWAIT) ON c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
								 WHERE ic.is_included_column = 0
									 AND ic.[object_id] = k.parent_object_id 
									 AND ic.index_id = k.unique_index_id     
								 FOR XML PATH(N''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''))
					+ ')' + CHAR(13)
					FROM sys.key_constraints k WITH (NOWAIT)
					WHERE k.parent_object_id = @object_id 
						AND k.[type] = 'PK'), '') + ')'  + CHAR(13)
		  

		  --FOREIGN KEYS
		SELECT @FKSQL = ISNULL((SELECT (
				SELECT CHAR(13) +
					 'ALTER TABLE ' + @object_name + ' WITH' 
					+ CASE WHEN fk.is_not_trusted = 1 
						THEN ' NOCHECK' 
						ELSE ' CHECK' 
					  END + 
					  ' ADD CONSTRAINT [' + fk.name  + '] FOREIGN KEY(' 
					  + STUFF((
						SELECT ', [' + k.cname + ']'
						FROM @TblFKCols k
						WHERE k.constraint_object_id = fk.[object_id]
						FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
					   + ')' +
					  ' REFERENCES [' + SCHEMA_NAME(ro.[schema_id]) + '].[' + ro.name + '] ('
					  + STUFF((
						SELECT ', [' + k.rcname + ']'
						FROM @TblFKCols k
						WHERE k.constraint_object_id = fk.[object_id]
						FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
					   + ')'
					+ CASE 
						WHEN fk.delete_referential_action = 1 THEN ' ON DELETE CASCADE' 
						WHEN fk.delete_referential_action = 2 THEN ' ON DELETE SET NULL'
						WHEN fk.delete_referential_action = 3 THEN ' ON DELETE SET DEFAULT' 
						ELSE '' 
					  END
					+ CASE 
						WHEN fk.update_referential_action = 1 THEN ' ON UPDATE CASCADE'
						WHEN fk.update_referential_action = 2 THEN ' ON UPDATE SET NULL'
						WHEN fk.update_referential_action = 3 THEN ' ON UPDATE SET DEFAULT'  
						ELSE '' 
					  END 
					+ CHAR(13) + 'ALTER TABLE ' + @object_name + ' CHECK CONSTRAINT [' + fk.name  + ']' + CHAR(13)
				FROM sys.foreign_keys fk WITH (NOWAIT)
				JOIN sys.objects ro WITH (NOWAIT) ON ro.[object_id] = fk.referenced_object_id
				WHERE fk.parent_object_id = @object_id
				FOR XML PATH(N''), TYPE).value('.', 'NVARCHAR(MAX)')), '')
		        
		        
			-- INDEXES
		SELECT @INDEXSQL = ISNULL(((SELECT
				 CHAR(13) + 'CREATE' + CASE WHEN i.is_unique = 1 THEN ' UNIQUE' ELSE '' END 
						+ ' NONCLUSTERED INDEX [' + i.name + '] ON ' + @object_name + ' (' +
						STUFF((
						SELECT ', [' + c.name + ']' + CASE WHEN c.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
						FROM @TblIndexCols c
						WHERE c.is_included_column = 0
							AND c.index_id = i.index_id
						FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')'  
						+ ISNULL(CHAR(13) + 'INCLUDE (' + 
							STUFF((
							SELECT ', [' + c.name + ']'
							FROM @TblIndexCols c
							WHERE c.is_included_column = 1
								AND c.index_id = i.index_id
							FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')', '')  + CHAR(13)
				FROM sys.indexes i WITH (NOWAIT)
				WHERE i.[object_id] = @object_id
					AND i.is_primary_key = 0
					AND i.[type] = 2
				FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
			), '')
			--print(@INDEXSQL)

		    
			--FK
			SET @TEMPSQL=''
			SELECT @TEMPSQL=@TEMPSQL+CHAR(13)+'ALTER TABLE ['+FK.Table_Name+'] DROP CONSTRAINT ['+C.CONSTRAINT_NAME+']'
			FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS C
			INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS FK ON C.CONSTRAINT_NAME = FK.CONSTRAINT_NAME  
			INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS PK ON C.UNIQUE_CONSTRAINT_NAME = PK.CONSTRAINT_NAME  
			INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU ON C.CONSTRAINT_NAME = CU.CONSTRAINT_NAME   
			INNER JOIN (SELECT i1.TABLE_NAME, i2.COLUMN_NAME
				FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS i1  
				INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE i2 ON i1.CONSTRAINT_NAME = i2.CONSTRAINT_NAME  
				WHERE i1.CONSTRAINT_TYPE = 'PRIMARY KEY') PT ON PT.TABLE_NAME = PK.TABLE_NAME
			WHERE FK.TABLE_NAME=substring(@table_name,5,len(@table_name))

		--	print(@TEMPSQL)

			SELECT @TEMPSQL=@TEMPSQL+CHAR(13)+'ALTER TABLE ['+FK.Table_Name+'] DROP CONSTRAINT ['+C.CONSTRAINT_NAME+']'
			,@FKSQL=@FKSQL+CHAR(13)+'ALTER TABLE ['+FK.TABLE_NAME+'] WITH CHECK ADD CONSTRAINT ['+C.CONSTRAINT_NAME+'] FOREIGN KEY(['+CU.COLUMN_NAME+']) REFERENCES '+PK.TABLE_NAME+' (['+PT.COLUMN_NAME+'])
		ALTER TABLE ['+FK.TABLE_NAME+'] CHECK CONSTRAINT ['+C.CONSTRAINT_NAME+']'
			FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS C
			INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS FK ON C.CONSTRAINT_NAME = FK.CONSTRAINT_NAME  
			INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS PK ON C.UNIQUE_CONSTRAINT_NAME = PK.CONSTRAINT_NAME  
			INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU ON C.CONSTRAINT_NAME = CU.CONSTRAINT_NAME   
			INNER JOIN (SELECT i1.TABLE_NAME, i2.COLUMN_NAME
				FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS i1  
				INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE i2 ON i1.CONSTRAINT_NAME = i2.CONSTRAINT_NAME  
				WHERE i1.CONSTRAINT_TYPE = 'PRIMARY KEY') PT ON PT.TABLE_NAME = PK.TABLE_NAME
			WHERE PK.TABLE_NAME=substring(@table_name,5,len(@table_name))
			--print(@TEMPSQL)
			--print(@FKSQL)
			if @TEMPSQL is not null and @TEMPSQL!=''
				exec(@TEMPSQL)
				
				
		   --PK
			set @TEMPSQL=(SELECT  CHAR(13) +' ALTER TABLE '+@object_name+' DROP CONSTRAINT [' + k.name + ']'
					FROM sys.key_constraints k WITH (NOWAIT)
					WHERE k.parent_object_id = @object_id AND k.[type] = 'PK')
			if @TEMPSQL is not null and @TEMPSQL!=''
				exec(@TEMPSQL)
				
			-- INDEXES
			set @TEMPSQL=''
			SELECT @TEMPSQL=@TEMPSQL+ISNULL(((SELECT
				 CHAR(13) + (case when i.is_unique_constraint=0 then 'DROP INDEX ['+i.name+'] ON '+@object_name+' WITH(ONLINE=OFF)'
								else 'ALTER TABLE '+@object_name+' DROP CONSTRAINT [' + i.name + ']' end)
				FROM sys.indexes i WITH (NOWAIT)
				WHERE i.[object_id] = @object_id
					AND i.is_primary_key = 0
					AND i.[type] = 2
				FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
			), '')
			--print(@TEMPSQL)
			if @TEMPSQL is not null and @TEMPSQL!=''
				exec(@TEMPSQL)
				
			--CREATE TEMP TABLE	
			--print(@SQL)
			exec(@SQL)
			
			
			
			set @SQL='SET IDENTITY_INSERT '+@tempobject_name+' ON

		IF EXISTS(SELECT * FROM '+@object_name+')
			 EXEC(''INSERT INTO '+@tempobject_name+' ('+@COL_SQL+')
				SELECT '+@COL_SQL+' FROM '+@object_name+' WITH (HOLDLOCK TABLOCKX)'')

		SET IDENTITY_INSERT '+@tempobject_name+' OFF'
			exec(@SQL)
			
			--exec(N'select * from '+@tempobject_name+' with(nolock)')

			set @SQL='
		DROP TABLE '+@object_name+'
		EXECUTE sp_rename N'''+@tempobject_name+''',N'''+replace(replace(substring(@object_name,7,len(@object_name)),'[',''),']','')+''',''OBJECT'''
		--print(@SQL)
		exec(@SQL)
		
		--exec(N'select * from sys.tables with(nolock) where name like ''%accounts%''')

		--print(@FKSQL)
		exec(@FKSQL)
		
		--print(@INDEXSQL)
		exec(@INDEXSQL)

	END
	
	
COMMIT TRANSACTION
--ROLLBACK TRANSACTION

SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	SELECT ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
	
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
