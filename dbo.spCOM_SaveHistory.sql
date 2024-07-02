USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SaveHistory]
	@CostCenterID [int],
	@NodeID [int],
	@HistoryStatus [nvarchar](32),
	@UserName [nvarchar](50) = '',
	@DT [float] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY        
SET NOCOUNT ON;  
  
	DECLARE @UpdateSql NVARCHAR(MAX),@TableName NVARCHAR(32),@HistoryTableName NVARCHAR(48),@PrimaryKey NVARCHAR(32)       
	
	IF @DT IS NULL OR @DT=1
		SET @DT=CONVERT(FLOAT,GETDATE())
	
	SELECT @TableName=TableName,@PrimaryKey=PrimaryKey FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterID
	set @HistoryTableName=''

	if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'_History')
		set @HistoryTableName=@TableName+'_History'
	else if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'History')
		set @HistoryTableName=@TableName+'History'
	
	if(@HistoryTableName is not null and @HistoryTableName<>'')		
	begin	 
		SET @UpdateSql=''
		SELECT @UpdateSql=@UpdateSql+','+a.name
		FROM sys.columns a WITH(NOLOCK)
		JOIN sys.columns b WITH(NOLOCK) on a.name=b.name and b.object_id= object_id(@TableName)
		WHERE a.object_id= object_id(@HistoryTableName) and a.name not in ('ModifiedBy','ModifiedDate')
		
		set @UpdateSql= 'insert into '+@HistoryTableName+' (HistoryStatus,ModifiedBy,ModifiedDate'+@UpdateSql+') 
		select '''+@HistoryStatus+''','''+@UserName+''','+CONVERT(NVARCHAR(32),CAST(@DT AS DECIMAL(18,10)))+@UpdateSql+' 
		from '+@TableName+' with(nolock) 
		WHERE '+@PrimaryKey+'='+CONVERT(NVARCHAR,@NodeID) 
		PRINT @UpdateSql    
		EXEC (@UpdateSql)
	end
	
	set @TableName=@TableName+'Extended'
	set @HistoryTableName=''
	
	if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName)
	begin
		if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'_History')
			set @HistoryTableName=@TableName+'_History'
		else if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'History')
			set @HistoryTableName=@TableName+'History' 
		
		if(@HistoryTableName is not null and @HistoryTableName<>'')		
		begin	
			SET @UpdateSql=''
			SELECT @UpdateSql=@UpdateSql+','+a.name
			FROM sys.columns a WITH(NOLOCK)
			JOIN sys.columns b WITH(NOLOCK) on a.name=b.name and b.object_id= object_id(@TableName)
			WHERE a.object_id= object_id(@HistoryTableName) and a.name not in ('ModifiedBy','ModifiedDate')
			
			set @UpdateSql= 'insert into '+@HistoryTableName+' (HistoryStatus'+(CASE WHEN @CostCenterID IN (103,129) THEN '' ELSE ',ModifiedBy,ModifiedDate' END)+@UpdateSql+') 
			select '''+@HistoryStatus+''''+(CASE WHEN @CostCenterID IN (103,129) THEN '' ELSE ','''+@UserName+''','+CONVERT(NVARCHAR(32),CAST(@DT AS DECIMAL(18,10))) END)+@UpdateSql+' 
			from '+@TableName+' with(nolock) 
			WHERE '+(CASE WHEN @CostCenterID IN (95,104) THEN 'NodeID' ELSE @PrimaryKey END)+'='+CONVERT(NVARCHAR,@NodeID)     
			EXEC (@UpdateSql)	
		end
    end
    
    set @TableName=REPLACE(@TableName,'Extended','Particulars')
	set @HistoryTableName=''
	
	if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName)
	begin
		if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'_History')
			set @HistoryTableName=@TableName+'_History'
		else if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'History')
			set @HistoryTableName=@TableName+'History' 
		
		if(@HistoryTableName is not null and @HistoryTableName<>'')		
		begin	
			SET @UpdateSql=''
			SELECT @UpdateSql=@UpdateSql+','+a.name
			FROM sys.columns a WITH(NOLOCK)
			JOIN sys.columns b WITH(NOLOCK) on a.name=b.name and b.object_id= object_id(@TableName)
			WHERE a.object_id= object_id(@HistoryTableName) and a.name not in ('ModifiedBy','ModifiedDate')
			
			set @UpdateSql= 'insert into '+@HistoryTableName+' (ModifiedBy,ModifiedDate'+@UpdateSql+') 
			select '''+@UserName+''','+CONVERT(NVARCHAR(32),CAST(@DT AS DECIMAL(18,10)))+@UpdateSql+' 
			from '+@TableName+' with(nolock) 
			WHERE '+@PrimaryKey+'='+CONVERT(NVARCHAR,@NodeID)     
			EXEC (@UpdateSql)	
		end
    end
	
	set @TableName=REPLACE(@TableName,'Particulars','PayTerms')
	set @HistoryTableName=''
	
	if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName)
	begin
		if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'_History')
			set @HistoryTableName=@TableName+'_History'
		else if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'History')
			set @HistoryTableName=@TableName+'History' 
		
		if(@HistoryTableName is not null and @HistoryTableName<>'')		
		begin	
			SET @UpdateSql=''
			SELECT @UpdateSql=@UpdateSql+','+a.name
			FROM sys.columns a WITH(NOLOCK)
			JOIN sys.columns b WITH(NOLOCK) on a.name=b.name and b.object_id= object_id(@TableName)
			WHERE a.object_id= object_id(@HistoryTableName) and a.name not in ('ModifiedBy','ModifiedDate')
			
			set @UpdateSql= 'insert into '+@HistoryTableName+' (ModifiedBy,ModifiedDate'+@UpdateSql+') 
			select '''+@UserName+''','+CONVERT(NVARCHAR(32),CAST(@DT AS DECIMAL(18,10)))+@UpdateSql+' 
			from '+@TableName+' with(nolock) 
			WHERE '+@PrimaryKey+'='+CONVERT(NVARCHAR,@NodeID)     
			EXEC (@UpdateSql)	
		end
    end	
	
	set @TableName='COM_CCCCData'
	set @HistoryTableName=''
	
	if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName)
	begin
		if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'_History')
			set @HistoryTableName=@TableName+'_History'
		else if exists(select name from sys.tables WITH(NOLOCK) where name=@TableName+'History')
			set @HistoryTableName=@TableName+'History' 
		
		if(@HistoryTableName is not null and @HistoryTableName<>'')		
		begin	
			SET @UpdateSql=''
			SELECT @UpdateSql=@UpdateSql+' alter table '+@HistoryTableName+' drop CONSTRAINT '+name 
			FROM sys.objects with(nolock)
			WHERE  parent_object_id=OBJECT_ID(@HistoryTableName) and type_desc='DEFAULT_CONSTRAINT'

			SELECT @UpdateSql=@UpdateSql+' alter table '+@HistoryTableName+' alter column '+name+' int null' 
			FROM sys.columns with(nolock)
			WHERE OBJECT_ID=OBJECT_ID(@HistoryTableName) and name like 'ccnid%' and is_nullable=0
			EXEC (@UpdateSql)
			
			
			SET @UpdateSql=''
			SELECT @UpdateSql=@UpdateSql+','+a.name
			FROM sys.columns a WITH(NOLOCK)
			JOIN sys.columns b WITH(NOLOCK) on a.name=b.name and b.object_id= object_id(@TableName)
			WHERE a.object_id= object_id(@HistoryTableName) and a.name not in ('ModifiedBy','ModifiedDate')
			
			DECLARE @NodeHistoryID INT
			SELECT @NodeHistoryID=ISNULL(MAX(NodeHistoryID)+1,1) FROM COM_CCCCDataHistory WITH(NOLOCK)
			
			set @UpdateSql= 'DECLARE @NodeHistoryID INT
			SELECT @NodeHistoryID=ISNULL(MAX(NodeHistoryID)+1,1) FROM '+@HistoryTableName+' WITH(NOLOCK)
			
			insert into '+@HistoryTableName+' (NodeHistoryID,ModifiedBy,ModifiedDate'+@UpdateSql+') 
			select @NodeHistoryID,'''+@UserName+''','+CONVERT(NVARCHAR(32),CAST(@DT AS DECIMAL(18,10)))+@UpdateSql+' 
			from '+@TableName+' with(nolock) 
			WHERE CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND NodeID='+CONVERT(NVARCHAR,@NodeID)   
			EXEC (@UpdateSql)	
		end
    end
    
COMMIT TRANSACTION
SET NOCOUNT OFF;        
RETURN @NodeID
END TRY        
BEGIN CATCH  
  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
      
 
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
    
    
END CATCH
GO
