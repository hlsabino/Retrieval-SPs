USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SetImportParticulars]
	@CostCenterID [int],
	@ParticularID [bigint],
	@Action [nvarchar](10),
	@SelectedFileds [nvarchar](max),
	@SelectedFldsData [nvarchar](max),
	@ExtraFields [nvarchar](max),
	@FilterXML [nvarchar](max),
	@IsCode [bit],
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON 
	
	DECLARE @return_value int=-1,@SQL NVARCHAR(MAX),@FilterColumn NVARCHAR(20),@Table NVARCHAR(50),@DimNo NVARCHAR(10),@XML XML,@JOIN NVARCHAR(MAX)=''
	,@FilterData NVARCHAR(MAX),@I INT=1,@Cnt INT,@CostCenterWhere NVARCHAR(MAX)=''
	IF(@SelectedFileds IS NOT NULL)
		SET @SelectedFileds = @SelectedFileds+'CreatedDate'
	IF(@SelectedFldsData IS NOT NULL)
		SET @SelectedFldsData = @SelectedFldsData+'CONVERT(FLOAT,GETDATE())'
	IF(@ExtraFields IS NOT NULL)
		SET @ExtraFields = @ExtraFields+'ModifiedDate =CONVERT(FLOAT,GETDATE())'
	
	IF(@FilterXML IS NOT NULL AND @FilterXML <> '')
	BEGIN
		SET @XML = @FilterXML
		
		IF(@CostCenterID = 92)--Property
			SET @JOIN=@JOIN+' JOIN COM_CCCCData CCD WITH(NOLOCK) ON CCD.NodeID=P.NodeID AND CCD.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+''
		ELSE IF(@CostCenterID = 93)--Units
			SET @JOIN=@JOIN+' JOIN COM_CCCCData CCD WITH(NOLOCK) ON CCD.NodeID=P.UnitID AND CCD.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+''
				
		DECLARE @TAB TABLE (ID INT IDENTITY(1,1),FilterFld NVARCHAR(100),FilterData NVARCHAR(1000))
		INSERT INTO @TAB
		SELECT X.value('@FilterFld','NVARCHAR(300)'),X.value('@FilterData','NVARCHAR(MAX)')  
		FROM @XML.nodes('/XML/Row') as Data(X) 
		SELECT @Cnt=COUNT(*) FROM @TAB
		
		WHILE(@I<=@Cnt)
		BEGIN
			IF((SELECT CCD.ColumnCostCenterID FROM @TAB T
			JOIN ADM_CostCenterDef CCD WITH(NOLOCK) ON CCD.CostCenterID=@CostCenterID AND CCD.UserColumnName=T.FilterFld
			JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=CCD.ColumnCostCenterID
			WHERE T.ID=@I) > 50000)
			BEGIN				
				SELECT @DimNo=SUBSTRING(SysName,13,20),@FilterColumn='CCNID'+SUBSTRING(SysName,13,20),@Table=F.TableName,@FilterData=FilterData FROM @TAB T
				JOIN ADM_CostCenterDef CCD WITH(NOLOCK) ON CCD.CostCenterID=@CostCenterID AND CCD.UserColumnName=T.FilterFld
				JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=CCD.ColumnCostCenterID
				WHERE T.ID=@I			
					
				SET @JOIN=@JOIN+' JOIN '+@Table+' T'+CONVERT(NVARCHAR,@I)+' WITH(NOLOCK) ON T'+CONVERT(NVARCHAR,@I)+'.Name IN ('+@FilterData+') AND CCD.CCNID'+@DimNo+'=T'+CONVERT(NVARCHAR,@I)+'.NodeID'
			END
			ELSE IF((SELECT FilterFld FROM @TAB WHERE ID=@I) IN ('Property','Unit','Units'))
			BEGIN
				IF(@IsCode=1)
					SELECT @CostCenterWhere=' AND P.Code IN ('+FilterData+')' FROM @TAB WHERE ID=@I
				ELSE
					SELECT @CostCenterWhere=' AND P.Name IN ('+FilterData+')' FROM @TAB WHERE ID=@I				
			END
			
			SET @I=@I+1
		END
	END
	
	IF(@Action = 'Add')
	BEGIN
		IF(@CostCenterID = 92)--Property
		BEGIN			
			SET @SQL='INSERT INTO REN_Particulars(PropertyID,UnitID,GUID,'+@SelectedFileds+')
					  SELECT P.NodeID,0,NEWID(),'+@SelectedFldsData+' FROM REN_Property P WITH(NOLOCK) 
					  '+@JOIN+'
					  WHERE P.NodeID>1 '+@CostCenterWhere+''
					  SET @return_value=1
		END
		ELSE IF(@CostCenterID = 93)--Units
		BEGIN			
			SET @SQL='INSERT INTO REN_Particulars(PropertyID,UnitID,GUID,'+@SelectedFileds+')
					  SELECT P.PropertyID,P.UnitID,NEWID(),'+@SelectedFldsData+' FROM REN_Units P WITH(NOLOCK) 
					  '+@JOIN+'
					  WHERE P.UnitID>1 '+@CostCenterWhere+''
					  SET @return_value=1
		END
	END
	ELSE IF(@Action = 'Update')
	BEGIN
		IF(@CostCenterID = 92)--Property
		BEGIN			
			SET @SQL='UPDATE PR SET PR.GUID=NEWID(),'+@ExtraFields+' FROM REN_Particulars PR WITH(NOLOCK)
					  JOIN REN_Property P WITH(NOLOCK) ON P.NodeID=PR.PropertyID
					  '+@JOIN+'
					  WHERE PR.ParticularID='+CONVERT(NVARCHAR,@ParticularID)+' AND PR.UnitID=0 '+@CostCenterWhere+''
					  SET @return_value=1
		END
		ELSE IF(@CostCenterID = 93)--Units
		BEGIN			
			SET @SQL='UPDATE PR SET PR.GUID=NEWID(),'+@ExtraFields+' FROM REN_Particulars PR WITH(NOLOCK)
					  JOIN REN_Units P WITH(NOLOCK) ON P.UnitID=PR.UnitID 
					  '+@JOIN+'
					  WHERE PR.ParticularID='+CONVERT(NVARCHAR,@ParticularID)+' AND PR.UnitID>1 AND PR.PropertyID>1 '+@CostCenterWhere+''
					  SET @return_value=1
		END
	END
	ELSE IF(@Action = 'Delete')
	BEGIN
		IF(@CostCenterID = 92)--Property
		BEGIN			
			SET @SQL='DELETE PR FROM REN_Particulars PR WITH(NOLOCK) 
					  JOIN REN_Property P WITH(NOLOCK) ON P.NodeID=PR.PropertyID
			          '+@JOIN+'
					  WHERE PR.ParticularID='+CONVERT(NVARCHAR,@ParticularID)+' AND PR.UnitID=0 '+@CostCenterWhere+''
					  SET @return_value=1
		END
		ELSE IF(@CostCenterID = 93)--Units
		BEGIN			
			SET @SQL='DELETE PR FROM REN_Particulars PR WITH(NOLOCK) 
					  JOIN REN_Units P WITH(NOLOCK) ON P.UnitID=PR.UnitID 
			          '+@JOIN+'
					  WHERE PR.ParticularID='+CONVERT(NVARCHAR,@ParticularID)+' AND PR.UnitID>1 AND PR.PropertyID>1 '+@CostCenterWhere+''
					  SET @return_value=1
		END
	END	
	
    PRINT(@SQL)
    EXEC(@SQL)
COMMIT TRANSACTION      
  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @return_value      
END TRY      
BEGIN CATCH

if(@return_value=-999)
	return  -999
	 
 IF ERROR_NUMBER()=50000    
 BEGIN    
	IF ISNUMERIC(ERROR_MESSAGE())<>1
	BEGIN
		SELECT ERROR_MESSAGE() ErrorMessage
	END
	ELSE
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID   
	END 
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-116 AND LanguageID=@LangID    
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
