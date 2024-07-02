USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetCostCenterMissingNames]
	@PRODUCTXML [nvarchar](max),
	@CostCenterID [int],
	@IsCode [bit] = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  
		DECLARE @XML XML,@NodeID INT,@I INT,@COUNT INT,@PRODUCTNAME NVARCHAR(max),@PRODUCTCODE NVARCHAR(max), @TableName nvarchar(300),@TEMPxml NVARCHAR(500)
		DECLARE @SQL NVARCHAR(MAX),@Filter NVARCHAR(MAX),@SelectCols NVARCHAR(MAX)
		DECLARE @TABLE TABLE(ID INT IDENTITY(1,1),PRODUCTCODE NVARCHAR(MAX),PRODUCTNAME NVARCHAR(MAX))
		Create Table #TABNODES (ID INT,Code NVARCHAR(MAX),name NVARCHAR(MAX))
		SET @SQL=''
		SET @Filter=''
		SET @SelectCols=''
		SET @XML=@PRODUCTXML
		
		Select @TableName=TableName From ADM_FEATURES WITH(NOLOCK) WHERE FeatureID=@CostCenterID
		
		IF(@CostCenterID=2)
		BEGIN
			SET @Filter=' AccountCode = '
			SET @SelectCols=' AccountID '
		END
		ELSE IF(@CostCenterID=3)
		BEGIN
			SET @Filter=' ProductCode = '
			SET @SelectCols=' ProductID '
		END
		ELSE IF(@CostCenterID>50000)
		BEGIN
			SET @Filter=' Code = '
			SET @SelectCols=' NodeID '
		END
			
		INSERT INTO @TABLE
		SELECT
			X.value('@ProductCode','nvarchar(max)'),
           	X.value('@ProductName','nvarchar(max)')
	  	from @XML.nodes('/XML/Row') as Data(X)
	  	
	  	SELECT @I=1,@COUNT=COUNT(*) FROM @TABLE
	  	WHILE @I<=@COUNT
	  	BEGIN
	  			SET @TEMPxml=''
	  			SELECT @PRODUCTCODE=LTRIM(RTRIM(PRODUCTCODE)),@PRODUCTNAME=LTRIM(RTRIM(PRODUCTNAME)) FROM @TABLE WHERE ID=@I
				SET @TEMPxml='<XML><Row AccountName ="'+replace(@PRODUCTNAME,'&','&amp;')+'" 
						AccountCode ="'+replace(@PRODUCTCODE,'&','&amp;')+'" TypeID ="1" '
				
				IF(@CostCenterID=3)
					 SET @TEMPxml=@TEMPxml+' UOMID="1" '
					 
				SET @TEMPxml=@TEMPxml+'></Row></XML>'       
						
				EXEC @NodeID = [dbo].[spADM_SetImportData]      
				@XML = @TEMPxml,      
				@COSTCENTERID = @CostCenterID,      
				@IsDuplicateNameAllowed = 0,      
				@IsCodeAutoGen = 0,      
				@IsOnlyName = 0,      
				@CompanyGUID = @CompanyGUID,      
				@UserName = @UserName ,      
				@UserID = @UserID, 
				@RoleID=@RoleID,     
				@LangID = @LangID   
				
				SET @SQL =' Insert into #TABNODES  select '+ @SelectCols +','''+ @ProductCode+''','''+@PRODUCTNAME + ''' from '+ @TableName +' with(nolock) where '+ @Filter +'''' + @ProductCode +''''
				--PRINT (@SQL)
				EXEC (@SQL)
	  	SET @I=@I+1
	  	END
	  	
COMMIT TRANSACTION  
  SELECT * FROM #TABNODES
  Drop Table #TABNODES
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
