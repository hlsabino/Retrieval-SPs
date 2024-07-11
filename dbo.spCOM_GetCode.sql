USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCode]
	@CostCenterID [int],
	@ParentCode [nvarchar](200) = '',
	@CodeGenerated [nvarchar](200) OUTPUT,
	@CodeNumber [bigint] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON;    
		-- Declare the variable here
		DECLARE @Result nvarchar(200),@Year int,@Month nvarchar(3),@Day int,@DocDate datetime,
			@CodePrefix nvarchar(50),
			@CodeNumberRoot bigint,
			@CodeNumberInc int,
			@CodeDelimiter nvarchar(5),
			@CurrentCodeNumber bigint,
			@CodeNumberLength int,
			@IsDateIncluded bit,
			@DateFormat nvarchar(10),
			@IsDateDelimiterDefined bit,
			@IsParentCodeInherited bit,@CompanyGUID nvarchar(50),@DATA XML,@Code nvarchar(300)

		SET @DocDate=getdate()

		--Reading Costcenter code definition
		SELECT  @CodePrefix=CodePreview,@Code=CodePrefix,
				@CodeNumberRoot=CodeNumberRoot,
				@CodeNumberInc=CodeNumberInc,
				@CodeDelimiter=isnull(CodeDelimiter,''),
				@CurrentCodeNumber=CurrentCodeNumber,
				@CodeNumberLength=CodeNumberLength,
				@IsDateIncluded=IsDateIncluded,
				@DateFormat=[DateFormat],
				@IsDateDelimiterDefined=IsDateDelimiterDefined,
				@IsParentCodeInherited=IsParentCodeInherited,@CompanyGUID=CompanyGUID,@DATA=PrefixContent			
		FROM COM_CostCenterCodeDef WITH(nolock)
		WHERE CostCenterID=@CostCenterID and IsName=0

		 	SET @Result=''
	
		--Append code prefix
		IF @Code<>''
		SET @Result=ISNULL(@Code,'')
	 

		CREATE TABLE #TBLTEMP (ID INT IDENTITY(1,1),NAME nvarchar(300),Length int)
		INSERT INTO #TBLTEMP
		SELECT X.value('@Name','NVARCHAR(300)'),CASE WHEN ISNUMERIC(X.value('@Length','NVARCHAR(300)'))=1 THEN X.value('@Length','int') ELSE LEN(X.value('@Length','NVARCHAR(300)')) END from @DATA.nodes('XML/Row') as DATA(X)

		DECLARE @I INT,@COUNT INT,@Length INT,@NAME NVARCHAR(300)
		SELECT @COUNT=COUNT(*) FROM #TBLTEMP 
		SET @I=1 
		WHILE @I<=@COUNT
		BEGIN
		SELECT @NAME=[NAME],@Length=Length FROM #TBLTEMP  WHERE ID=@I 
		IF @NAME<>''
		BEGIN
		 IF @NAME='Company' 
			SET @Result=@Result +(SELECT substring([NAME],1,@Length) FROM PACT2C.dbo.ADM_Company WHERE CompanyGUID=@CompanyGUID)  +@CodeDelimiter
		 ELSE IF @NAME='Feature' 
			SET @Result=@Result + (SELECT substring([NAME],1,@Length) FROM ADM_FEATURES WHERE FEATUREID=@CostCenterID) +@CodeDelimiter
		END
		SET @I=@I+1
		END
 
	
		--Append date if it is included
		IF @IsDateIncluded=1
		BEGIN
			SELECT @Year=datepart(year,@DocDate)
			SELECT @Month=upper(datename(month,@DocDate))
			SELECT @Day=datepart(day,@DocDate)
			SET @Result=@Result + @CodeDelimiter
			IF @DateFormat='Y'
			BEGIN
				SET @Result=@Result+convert(nvarchar,@Year)
			END
			ELSE IF @DateFormat='YM'
			BEGIN
				SET @Result=@Result+convert(nvarchar,@Year)+@Month
			END
			ELSE IF @DateFormat='YMD'
			BEGIN
				SET @Result=@Result+convert(nvarchar,@Year)+@Month+convert(nvarchar,@Day)
			END
			ELSE IF @DateFormat='M'
			BEGIN
				SET @Result=@Result+@Month
			END
			ELSE IF @DateFormat='MD'
			BEGIN
				SET @Result=@Result+@Month+convert(nvarchar,@Day)
			END
			
			SET @Result=@Result
		END
--select @Result,@CodeDelimiter
		--Append parent code
		IF @IsParentCodeInherited=1 and @ParentCode<>''
		BEGIN
			SET @Result=@ParentCode+@CodeDelimiter+@Result
		END
		
		--Append sequence number
		SET @CurrentCodeNumber=@CurrentCodeNumber+@CodeNumberInc
		
		SET @CodeNumberLength=@CodeNumberLength-len(convert(nvarchar,@CurrentCodeNumber))
		--select @CodeNumberLength ,'@@CodeNumberLength'
		SET @Result=@Result+@CodeDelimiter+ISNULL(replicate('0',@CodeNumberLength),'')+convert(nvarchar,@CurrentCodeNumber)

		--Set OUTPUT parameters
		SET @CodeGenerated = @Result
		SET @CodeNumber = @CurrentCodeNumber
		--select @CodeNumber ,'@CodeNumber'
    
SET NOCOUNT OFF;     
RETURN 1
END TRY
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT 'ERROR' 
		END   
   
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH   

GO
