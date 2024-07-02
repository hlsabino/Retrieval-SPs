USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRen_GetUnitsData]
	@NodeIDs [nvarchar](max),
	@FieldsXML [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY            
SET NOCOUNT ON;   
	declare @SQL nvarchar(max),@Colid nvarchar(200),@CNT int,@I int,@SysColumnName nvarchar(100),@xml xml,@SysTableName nvarchar(50)

	Declare @TEMPUNIQUE TABLE(ID INT identity(1,1),CostCenterColID INT,SysColumnName NVARCHAR(50),SysTableName NVARCHAR(50))
	
	set @xml=@FieldsXML

	INSERT INTO @TEMPUNIQUE(CostCenterColID,SysTableName,SysColumnName)
	select CC.CostCenterColID,CC.SysTableName,CC.SysColumnName
	from ADM_COSTCENTERDEF CC with(NOLOCK)
	inner join @XML.nodes('/XML/R') as Data(X) ON X.value('@LinkID','INT')=CC.CostCenterColID
	where CC.COSTCENTERID=93

	select @CNT=count(*) from @TEMPUNIQUE
	
	set @SQL='select a.UnitID'
	SET  @I = 0 
	WHILE @I<@CNT
	BEGIN     
		SET @I=@I+1
		SELECT @Colid=CostCenterColID,@SysColumnName=SysColumnName,@SysTableName=SysTableName FROM @TEMPUNIQUE WHERE ID=@I
		if (@SysTableName<>'COM_CCCCData')
			set @SQL=@SQL+','+@SysColumnName+' as '''+@Colid+''''		
	END
	
	set @SQL=@SQL+' from REN_Units a WITH(NOLOCK)
	join REN_UnitsExtended b WITH(NOLOCK) on a.UnitID=b.UnitID
	where a.UnitID in('+@NodeIDs+')'
	print @SQL
	exec(@SQL)
END TRY            
BEGIN CATCH      
	            
		IF ERROR_NUMBER()=50000        
		BEGIN 
			IF ISNUMERIC(ERROR_MESSAGE())<>1			
				SELECT ERROR_MESSAGE() ErrorMessage,ERROR_NUMBER() ErrorNumber
			ELSE  
				SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)         
				WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
		END        
		ELSE IF ERROR_NUMBER()=547        
		BEGIN        
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
			FROM COM_ErrorMessages WITH(nolock)        
			WHERE ErrorNumber=-110 AND LanguageID=@LangID        
		END        
		ELSE IF ERROR_NUMBER()=2627        
		BEGIN        
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
			FROM COM_ErrorMessages WITH(nolock)        
			WHERE ErrorNumber=-116 AND LanguageID=@LangID        
		END        
		ELSE        
		BEGIN        
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine        
			FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
		END         		
	         
	SET NOCOUNT OFF            
	RETURN -999
END CATCH     


	
GO
