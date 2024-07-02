USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportToBinsDimension]
	@BinXML [nvarchar](max),
	@ProductName [nvarchar](max) = null,
	@ProductCode [nvarchar](max) = null,
	@IsCode [bit] = 0,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section  
	DECLARE @XML XML,@TSQL NVARCHAR(MAX),@SQL NVARCHAR(MAX),@BinTableName NVARCHAR(20),@TableName NVARCHAR(20),@return_value INT
	DECLARE @ProductID INT,@BINID INT,@BIN NVARCHAR(300),@I INT,@COUNT INT,@CCID INT,@DimCCID INT,
	@DimensionName NVARCHAR(300),@DimNodeID INT,@Capacity FLOAT,@IsDefault BIT,@StatusID INT
	
	DECLARE @TABLE TABLE(ID INT IDENTITY(1,1),BIN NVARCHAR(300),Dimension NVARCHAR(300),Capacity FLOAT,IsDefault BIT,StatusID INT)
	

	IF (@BinXML IS NOT NULL AND @BinXML <> '')
	BEGIN
		SELECT @CCID=ISNULL(VALUE,0) FROM COM_CostCenterPreferences with(nolock) WHERE NAME='BinsDimension' and costcenterid=3
		declare @DeptSQL nvarchar(max)
		
		SELECT @DimCCID=ISNULL(VALUE,0) FROM ADM_GLOBALPREFERENCES with(nolock) WHERE NAME='DimensionwiseBins'	
		
		IF(@CCID>0)
		BEGIN
			if @IsCode=0 and exists(select ProductID from dbo.INV_Product with(nolock) where ProductName=@ProductName)
			begin
				set @ProductID=(select top 1 ProductID from dbo.INV_Product with(nolock) where ProductName=@ProductName)
			end 
			else if @IsCode=1 and exists(select ProductID from dbo.INV_Product with(nolock) where ProductCode=@ProductCode)
			begin
				set @ProductID=(select top 1 ProductID from dbo.INV_Product with(nolock) where ProductCode=@ProductCode)
			end 
	
			SELECT @BinTableName=TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID=@CCID
			if(@DimCCID>0)
				SELECT @TableName=Tablename FROM Adm_Features WITH(NOLOCK) WHERE featureid=@DimCCID
			
			SET @XML=@BinXML	 
			INSERT INTO @TABLE
			SELECT  X.value('@Bin','NVARCHAR(300)'),X.value('@DimesionWiseBin','NVARCHAR(300)') , X.value('@Capacity','FLOAT') , X.value('@IsDefault','BIT'), X.value('@StatusID','INT')
			from @XML.nodes('/XML/Row') as Data(X)
		 
			SELECT @COUNT=COUNT(*),@I=1 FROM @TABLE

			WHILE @I<=@COUNT
			BEGIN
				SELECT * FROM @TABLE
				SELECT @BIN=BIN,@DimensionName=Dimension,@Capacity=Capacity,@IsDefault=isnull(IsDefault,0),@StatusID=isnull(StatusID,0)  FROM @TABLE where id=@I 
				
				set @SQL=''	
				set @TSQL=''
				SET @TSQL=' @BINID nvarchar(100) OUTPUT'     
				if @IsCode is not null and @IsCode=0 
					SET @SQL=' select  @BINID=isnull(NodeID,0)  from '+@BinTableName+' with(nolock) WHERE Name='''+@BIN+'''  '
				else 
					SET @SQL=' select  @BINID=isnull(NodeID,0)  from '+@BinTableName+' with(nolock) WHERE Code='''+@BIN+'''  '
				
				EXEC sp_executesql @SQL, @TSQL, @BINID OUTPUT   
				 
				IF @BINID=0 OR @BINID IS NULL
				BEGIN 
					EXEC @return_value = [dbo].[spCOM_SetCostCenter]
						@NodeID = 0,@SelectedNodeID = 0,@IsGroup = 0,
						@Code = @BIN,
						@Name = @BIN,
						@AliasName=@BIN,
						@PurchaseAccount=0,@SalesAccount=0,@StatusID=0,
						@CustomFieldsQuery=NULL,@AddressXML='',@AttachmentsXML=NULL,
						@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
						@CostCenterID =@CCID,@CompanyGUID=@COMPANYGUID,@GUID='GUID',@UserName=@UserName,@RoleID=1,@UserID=@USERID
					SET @BINID=@return_value 
				END
				
				if(@DimCCID>0)
				BEGIN	
					if (@DimensionName<>'' and @DimensionName is not null)
					BEGIN
						SET @SQL=''	
						SET @TSQL=''
						SET @TSQL=' @DimNodeID nvarchar(100) OUTPUT'    
						IF @IsCode is not null and @IsCode=0  
							SET @SQL=' select  @DimNodeID=isnull(NodeID,0)  from '+@TableName+' with(nolock) WHERE Name='''+@DimensionName+'''  '
						ELSE
							SET @SQL=' select  @DimNodeID=isnull(NodeID,0)  from '+@TableName+' with(nolock) WHERE Code='''+@DimensionName+'''  '
						--SELECT  @SQL '1',@IsCode '2'
						SELECT @DimensionName DimensionName
						PRINT(@SQL)
						EXEC sp_executesql @SQL, @TSQL, @DimNodeID OUTPUT    
						IF @DimNodeID=0 OR @DimNodeID IS NULL
						BEGIN 
							EXEC @return_value = [dbo].[spCOM_SetCostCenter]
								@NodeID = 0,@SelectedNodeID = 0,@IsGroup = 0,
								@Code = @DimensionName,
								@Name = @DimensionName,
								@AliasName=@DimensionName,
								@PurchaseAccount=0,@SalesAccount=0,@StatusID=0,
								@CustomFieldsQuery=NULL,@AddressXML='',@AttachmentsXML=NULL,
								@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
								@CostCenterID =@CCID,@CompanyGUID=@COMPANYGUID,@GUID='GUID',@UserName=@UserName,@RoleID=1,@UserID=@USERID 
							SET @DimNodeID=@return_value 
						END		
					END
				END 
					
				
				
				IF @DimNodeID>0 AND @DimCCID>0 and NOT EXISTS(SELECT BinNodeID FROM [INV_ProductBins] with(nolock) WHERE CostcenterID=3 AND NodeID=@ProductID AND
					BinDimension=@CCID AND BinNodeID=@BINID AND DimCCID=@DimCCID and DimNodeID=@DimNodeID)
				BEGIN
					INSERT INTO [INV_ProductBins](CostcenterID,NodeID,Location,Division,BinDimension,BinNodeID,IsDefault,[CreatedBy],[CreatedDate],DIMCCID,DIMNODEID,Capacity,StatusID)  
					SELECT 3,@ProductID,1,1,@CCID,@BINID,@IsDefault,@UserName,CONVERT(FLOAT,GETDATE()),@DimCCID,@DimNodeID,@Capacity,@StatusID	
				END
				else IF NOT EXISTS(SELECT BinNodeID FROM [INV_ProductBins] with(nolock) WHERE CostcenterID=3 AND NodeID=@ProductID AND
					BinDimension=@CCID AND BinNodeID=@BINID)
					INSERT INTO [INV_ProductBins](CostcenterID,NodeID   ,Location  ,Division,BinDimension,BinNodeID,IsDefault,[CreatedBy],[CreatedDate],Capacity,StatusID)  
					SELECT 3,@ProductID,1,1,@CCID,@BINID,@IsDefault,@UserName,CONVERT(FLOAT,GETDATE()),@Capacity,@StatusID
				
				SET @BINID=0
				SET @BIN=''	
				SET @I=@I+1			
			 END
		END	
	  END
	  
	  select * from [INV_ProductBins] with(nolock)
	  
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;  
RETURN @ProductID
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
