USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_FillCCDefaultValues]
	@CostCenterID [int],
	@NodeID [int],
	@ExtraXml [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  
		DECLARE @XML XML,@I INT,@COUNT INT,@UserDefaultValue NVARCHAR(100), @SysTableName nvarchar(100),@SysColumnName NVARCHAR(200),@ColumnDataType  NVARCHAR(100)
		DECLARE @TABLE TABLE(ID INT IDENTITY(1,1),TableName NVARCHAR(100),SysColumnName NVARCHAR(100),Type NVARCHAR(100),DefaultValue NVARCHAR(100))
		DECLARE @TABLENODES TABLE(ID INT IDENTITY(1,1),NodeID INT)
		DECLARE @SQL NVARCHAR(MAX),@SQLFINAL NVARCHAR(MAX),@SQLCCCCTABLE NVARCHAR(MAX),@SQLALPHATABLE NVARCHAR(MAX),@DT FLOAT,@CCID INT,@NID INT
		
		SET @DT=CONVERT(FLOAT,GETDATE())
		
		SET @SQL=''
		SET @SQLCCCCTABLE=''
		SET @SQLALPHATABLE=''
		SET @SQLFINAL=''
		SET @CCID=@CostCenterID
		IF(ISNULL(@ExtraXml,'')<>'')
		BEGIN
			SET @XML=@ExtraXml
			INSERT INTO @TABLENODES
				SELECT
           			X.value('@NodeID','INT')
	  			from @XML.nodes('/XML/Row') as Data(X)
	  	END
	  	ELSE
	  		INSERT INTO @TABLENODES SELECT @NodeID
	  	
		
		Insert Into @TABLE Select SysTableName,SysColumnName,Isnull(ColumnDataType,UserColumnType),UserDefaultValue from ADM_CostCenterDef with(nolock)
					Where Isnull(UserDefaultValue,'')<>'' and Isnull(UserColumnType,'')<>'' and Isnull(SysColumnName,'')<>'' and CostCenterID=@CostCenterID
					order by SysTableName
		UPDATE @TABLE SET SysColumnName='' WHERE SysColumnName IN ('ProductGroup' ,'ACCOUNTGROUP','IsGroup')
		
		--SELECT * FROM @TABLE
		
	  	SELECT @I=1,@COUNT=COUNT(*) FROM @TABLE
	  	WHILE @I<=@COUNT
	  	BEGIN
	  			SELECT @UserDefaultValue=DefaultValue,@SysTableName=TableName ,@SysColumnName=SysColumnName,@ColumnDataType=Type FROM @TABLE WHERE ID=@I
	  			IF(@SysTableName LIKE '%CCCC%')
					SET @SQLCCCCTABLE=@SQLCCCCTABLE+ @SysColumnName +'='+ @UserDefaultValue + ' ,'
				ELSE IF(@SysTableName LIKE '%Extended')
					SET @SQLALPHATABLE=@SQLALPHATABLE+ @SysColumnName +'='''+ @UserDefaultValue + ''','
				ELSE
				BEGIN
					IF(ISNULL(@SysColumnName,'')<>'')
					BEGIN
	  					IF(@ColumnDataType='string')
	  						SET @SQL=@SQL+ @SysColumnName +'='''+ @UserDefaultValue + ''','
						ELSE IF(@ColumnDataType='BIT')
						BEGIN
							if(@UserDefaultValue='yes' or @UserDefaultValue='y' or @UserDefaultValue='true' or @UserDefaultValue='t') 
	  							SET @SQL=@SQL+ @SysColumnName +'=1 ,'	  		
	  						else if(@UserDefaultValue='no' or @UserDefaultValue='n' or @UserDefaultValue='false' or @UserDefaultValue='f') 
	  							SET @SQL=@SQL+ @SysColumnName +'=0 ,'	
	  						else if(@UserDefaultValue='fifo') 
	  							SET @SQL=@SQL+ @SysColumnName +'=2 ,'	
	  						else 
	  							SET @SQL=@SQL+ @SysColumnName +'='+ @UserDefaultValue + ' ,'  						
	  					END
						ELSE
							SET @SQL=@SQL+ @SysColumnName +'='+ @UserDefaultValue + ' ,'
					END
				END
	  	SET @I=@I+1
	  	END
		
		SELECT @I=1,@COUNT=COUNT(*) FROM @TABLENODES
		WHILE @I<=@COUNT
	  	BEGIN	  			
			SELECT @NID=NodeID FROM @TABLENODES WHERE ID=@I
			SET @SQLFINAL=''
			IF(ISNULL(@SQLCCCCTABLE,'')<>'')
	  			SET @SQLFINAL=@SQLFINAL+ ' UPDATE COM_CCCCData SET ' +@SQLCCCCTABLE + 'MODIFIEDDATE='+ CONVERT(VARCHAR,@DT) +' where CostCenterID='+ convert(varchar,@CCID) +' and NodeID='+ convert(nvarchar,@NID)+''
		  	
	  		IF(@CostCenterID=2)
	  		BEGIN
	  			IF(ISNULL(@SQL,'')<>'')
	  				SET @SQLFINAL=@SQLFINAL+ ' UPDATE ACC_Accounts SET ' +@SQL +'MODIFIEDDATE='+ CONVERT(VARCHAR,@DT) +' where AccountID='+ convert(nvarchar,@NID)+''
	  			IF(ISNULL(@SQLALPHATABLE,'')<>'')
	  				SET @SQLFINAL=@SQLFINAL+ ' UPDATE ACC_AccountsExtended SET ' +@SQLALPHATABLE +'MODIFIEDDATE='+ CONVERT(VARCHAR,@DT) +' where AccountID='+ convert(nvarchar,@NID)+''
	  		END
	  		ELSE IF(@CostCenterID=3)
	  		BEGIN
	  			IF(ISNULL(@SQL,'')<>'')
	  				SET @SQLFINAL=@SQLFINAL+ ' UPDATE INV_Product SET ' +@SQL +'MODIFIEDDATE='+ CONVERT(VARCHAR,@DT) +' where ProductID='+ convert(nvarchar,@NID)+''
	  			IF(ISNULL(@SQLALPHATABLE,'')<>'')
	  				SET @SQLFINAL=@SQLFINAL+ ' UPDATE INV_ProductEXTENDED SET ' +@SQLALPHATABLE +'MODIFIEDDATE='+ CONVERT(VARCHAR,@DT) +' where ProductID='+ convert(nvarchar,@NID)+''
	  		END
	  		ELSE IF(@CostCenterID>50000)
	  		BEGIN
	  			IF(ISNULL(@SQL,'')<>'')
	  			BEGIN
	  				Select @SysTableName=TableName From ADM_FEATURES WITH(NOLOCK) WHERE FeatureID=@CCID
	  				SET @SQLFINAL=@SQLFINAL+' UPDATE '+@SysTableName+' SET ' +@SQL +'MODIFIEDDATE='+ CONVERT(VARCHAR,@DT) +' where NodeID='+ convert(nvarchar,@NID)+''
	  			END
	  		END
	    --print @SQLCCCCTABLE
		--print @SQLALPHATABLE				
		--print @SQL
		--print @SQLFINAL
	  	EXEC (@SQLFINAL)
	  	SET @I=@I+1
	  	END
	  	
	  	
	  	
COMMIT TRANSACTION  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;  
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
