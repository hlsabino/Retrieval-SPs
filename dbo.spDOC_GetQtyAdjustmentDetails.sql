USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetQtyAdjustmentDetails]
	@ProductID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  

DECLARE @QUERY NVARCHAR(MAX),@TEMPCOLUMN NVARCHAR(500),@COLUMNS nvarchar(max) , @COLUMN NVARCHAR(50),@Join nvarchar(max),@COLUMNCNT int, @I int

	select a.CostCenterColID,b.ResourceData,Cformula,SysColumnName,UserDefaultValue,IsMandatory,Decimal from ADM_CostCenterDef a  WITH(NOLOCK)
	join COM_LanguageResources b WITH(NOLOCK) on a.ResourceID=b.ResourceID
	where CostCenterID=403 and b.LanguageID=@LangID and IsColumnInUse=1
		
	 
	declare @TEMPLINKTABLE TABLE (ID INT IDENTITY(1,1) ,SYSCOLUMNNAME NVARCHAR(100),COLUMNNAME NVARCHAR(100))
	
	INSERT INTO @TEMPLINKTABLE 
	select CDF.SysColumnName, a.SysColumnName from ADM_CostCenterDef a  WITH(NOLOCK)	
	JOIN ADM_CostCenterDef CDF WITH(NOLOCK)  ON a.UserDefaultValue = CDF.CostCenterColID
	where a.CostCenterID=403 and a.IsColumnInUse=1 and a.UserDefaultValue is not null and 
	isnumeric(a.UserDefaultValue)=1 
	
	
	set @Join=''
	SELECT @COLUMNCNT = COUNT(ID)  FROM @TEMPLINKTABLE
 
	 
 	SET @I = 1
    WHILE (@COLUMNCNT >= @I)
    BEGIN 		
		SELECT @TEMPCOLUMN = SYSCOLUMNNAME,@COLUMN = COLUMNNAME FROM @TEMPLINKTABLE WHERE ID =  @I  			
		
		
		IF(@TEMPCOLUMN IS NOT NULL AND @TEMPCOLUMN<>'')
		BEGIN 
			if(@TEMPCOLUMN = 'ProductTypeID')
			begin
				set @Join=@Join+'JOIN INV_ProductTypes PP WITH(NOLOCK) ON '
				set @Join=@Join+'A.ProductTypeID'				
				set @Join=@Join+'=PP.ProductTypeID            
				 JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=PP.ResourceID AND PT.LanguageID='+ convert(NVARCHAR(10),@LangID)            
				
				set @TEMPCOLUMN='PT.ResourceData AS '+ @COLUMN
			end	
			else if(@TEMPCOLUMN like '%alpha%')
			BEGIN				
					set @TEMPCOLUMN='e.'+@TEMPCOLUMN+ ' AS '+ @COLUMN					
			END	
			else 
			BEGIN
				set @TEMPCOLUMN='a.'+@TEMPCOLUMN+ ' AS '+ @COLUMN				 	
			END	
		END
		IF (@I = 1)
			SET @COLUMNS  = @TEMPCOLUMN 
		ELSE IF (@I > 1)
			SET @COLUMNS   =  @COLUMNS + ' , ' + @TEMPCOLUMN 
		SET @I = @I + 1 
	END  
	if(@COLUMNS is not null and @COLUMNS<>'')
	begin
		SET @QUERY = ' SELECT '+@COLUMNS+' FROM INV_Product a with(NOLOCK)
		join INV_ProductExtended e WITH(NOLOCK)  on a.ProductID=e.ProductID '

		set @QUERY=@QUERY+' '+@Join+' WHERE a.ProductID = ' + CONVERT(NVARCHAR(50),@ProductID)
	end
 
	print @QUERY

	EXEC (@QUERY)
  

	
	
	
SET NOCOUNT OFF;
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName,
		ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH  





GO
