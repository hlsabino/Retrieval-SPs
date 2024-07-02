USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetAPIPostingDetails]
	@CostCenterID [int],
	@DocID [int],
	@MapID [int],
	@APIType [nvarchar](32),
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	IF @APIType IS NULL OR @APIType=''
	BEGIN
		SELECT APIName,APISysName,APIType,MapID
		FROM [COM_APIFieldsMapping] WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
		ORDER BY APIName
	END
	ELSE IF @APIType='API'
	BEGIN
		DECLARE @BodyXML XML,@Body NVARCHAR(MAX)
		SELECT @Body=Body FROM [COM_APIFieldsMapping] WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND MapID=@MapID
		
		SET @BodyXML=@Body
		
		CREATE TABLE #TTABLE (ID INT IDENTITY(1,1) PRIMARY KEY,Tag NVARCHAR(200),SysColumnName NVARCHAR(200),SysTableName NVARCHAR(200),SysAlias NVARCHAR(200)
		,ParentColumnName NVARCHAR(200),ParentTableName NVARCHAR(200),ParentColumnKey NVARCHAR(200),ParentAlias NVARCHAR(200)
		,DefaultValue NVARCHAR(200),GroupName NVARCHAR(200),isCalc bit,isRepeat bit,Reference int)  
		
		INSERT INTO #TTABLE (Tag,SysColumnName,SysTableName,SysAlias,ParentColumnName,ParentTableName,ParentColumnKey,ParentAlias
		,DefaultValue,GroupName,isCalc,isRepeat,Reference)
		SELECT X.value('@Source','NVARCHAR(200)')                
		 ,X.value('@SysColumnName','NVARCHAR(200)'),'',''
		 ,'','','',''                
		 ,X.value('@Custom','NVARCHAR(200)')                
		 ,X.value('@GroupBy','NVARCHAR(200)')  
		 ,X.value('@IsCalc','BIT')
		 ,X.value('@Repeat','BIT')
		 ,X.value('@Reference','int')    
		 FROM @BodyXML.nodes('Row') as DATA(X) 

		UPDATE T SET T.SysTableName=CD.SysTableName,
		T.ParentTableName=CD.ParentCostCenterSysName,
		T.ParentColumnKey=CD.ParentCostCenterColSysName,
		T.ParentColumnName=PCD.SysColumnName
		FROM #TTABLE T WITH(NOLOCK)
		LEFT JOIN ADM_CostCenterDef CD WITH(NOLOCK) ON CD.CostCenterID=T.Reference AND CD.SysColumnName COLLATE DATABASE_DEFAULT=T.SysColumnName COLLATE DATABASE_DEFAULT
		LEFT JOIN ADM_CostCenterDef PCD WITH(NOLOCK) ON PCD.CostCenterColID=CD.ParentCCDefaultColID 

		UPDATE #TTABLE SET SysAlias= REPLACE(SysTableName,SUBSTRING(SysTableName,1,4),'')
		UPDATE #TTABLE SET ParentAlias= REPLACE(ParentTableName,SUBSTRING(ParentTableName,1,4),'')

		DECLARE @PrimaryKey nvarchar(200),@TableName nvarchar(200),
		@COLS NVARCHAR(MAX),@JOIN NVARCHAR(MAX),@SQL NVARCHAR(MAX) 

		SELECT @PrimaryKey=REPLACE(F.TableName,SUBSTRING(F.TableName,1,4),'')+'.'+ISNULL(F.PrimaryKey,'DocID')
		,@TableName=F.TableName,@SQL=''
		,@COLS='',@JOIN=' FROM '+F.TableName+' DocDetails WITH(NOLOCK)
		JOIN COM_DocNumData DocNumData WITH(NOLOCK) ON DocNumData.InvDocDetailsID=DocDetails.InvDocDetailsID
		JOIN COM_DocCCData DocCCData WITH(NOLOCK) ON DocCCData.InvDocDetailsID=DocDetails.InvDocDetailsID
		JOIN COM_DocTextData DocTextData WITH(NOLOCK) ON DocTextData.InvDocDetailsID=DocDetails.InvDocDetailsID '
		FROM ADM_Features F WITH(NOLOCK) 
		WHERE F.FeatureID=@CostCenterID

		UPDATE T SET T.ParentColumnName=T.SysColumnName
		,T.ParentTableName=CASE WHEN T.SysTableName IS NOT NULL THEN T.SysTableName ELSE 'COM_Address' END
		,T.ParentColumnKey=CASE WHEN T.SysTableName IS NOT NULL THEN F.PrimaryKey ELSE 'FeaturePK' END
		,T.ParentAlias=CASE WHEN T.SysTableName IS NOT NULL THEN T.SysAlias ELSE 'Address'+CONVERT(NVARCHAR,T.Reference) END
		,T.SysAlias=CASE WHEN T.Reference>50000 THEN 'DocCCData' ELSE 'DocDetails' END
		,T.SysTableName=CASE WHEN T.Reference>50000 THEN 'COM_DocCCData' ELSE @TableName END
		,T.SysColumnName=CASE WHEN T.Reference>50000 THEN 'dcCCNID'+CONVERT(NVARCHAR,T.Reference-50000) ELSE '' END
		FROM #TTABLE T WITH(NOLOCK) 
		JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=T.Reference
		WHERE T.Reference>0 AND T.Reference<>@CostCenterID 

		UPDATE #TTABLE SET SysColumnName='DebitAccount' WHERE Reference=2

		DECLARE @I INT,@CNT INT,@Tag nvarchar(200)
		,@SysColumnName nvarchar(200),@SysTableName nvarchar(200),@SysAlias nvarchar(200)
		,@ParentColumnName nvarchar(200),@ParentTableName nvarchar(200),@ParentColumnKey nvarchar(200),@ParentAlias nvarchar(200)
		,@DefaultValue nvarchar(200),@GroupName nvarchar(200),@isCalc bit,@isRepeat bit
		,@PrevGroupName nvarchar(200),@Reference INT

		SELECT @I=1,@CNT=COUNT(*),@PrevGroupName='' FROM #TTABLE WITH(NOLOCK)

		WHILE @I<=@CNT
		BEGIN
			SELECT @Tag='['+Tag+CASE WHEN GroupName IS NOT NULL AND GroupName<>'' THEN '~'+GroupName ELSE '' END+']' ,@SysColumnName=SysColumnName,@SysTableName=SysTableName,@SysAlias=SysAlias
			,@ParentColumnName=ParentColumnName,@ParentTableName=ParentTableName,@ParentColumnKey=ParentColumnKey,@ParentAlias=ParentAlias
			,@DefaultValue=DefaultValue,@GroupName=GroupName,@isCalc=isCalc,@isRepeat=isRepeat,@Reference=Reference
			FROM #TTABLE WITH(NOLOCK) WHERE ID=@I
			
			IF @ParentTableName IS NOT NULL AND @ParentTableName<>''
			BEGIN
				IF @ParentColumnName LIKE 'CCNID%'
				BEGIN
					
					IF Charindex(@ParentTableName+' '+@ParentAlias+@SysColumnName,@JOIN,0)=0
					BEGIN
						SET @JOIN=@JOIN+' LEFT JOIN '+@ParentTableName+' '+@ParentAlias+@SysColumnName+' WITH(NOLOCK) ON '+@ParentAlias+@SysColumnName+'.'+@ParentColumnKey+'='+@SysAlias+'.'+@SysColumnName+' AND '+@ParentAlias+@SysColumnName+'.CostCenterID='+CONVERT(NVARCHAR,50000+CONVERT(INT,REPLACE(@ParentColumnName,'CCNID','')))
					END

					SET @SysAlias=@ParentAlias+@SysColumnName
					SELECT @ParentTableName=TableName FROM ADM_Features F WITH(NOLOCK) 
					WHERE F.FeatureID=50000+CONVERT(INT,REPLACE(@ParentColumnName,'CCNID',''))
					SET @ParentAlias= REPLACE(@ParentTableName,SUBSTRING(@ParentTableName,1,4),'')+@SysColumnName

					SET @SysColumnName=@ParentColumnName

					IF @isCalc=1
						SET @ParentColumnName='Name'
					ELSE 
						SET @ParentColumnName='Code'
				END

				SET @COLS=@COLS+',ISNULL(CONVERT(nvarchar(200),'+@ParentAlias+'.'+@ParentColumnName+'),'''') '+@Tag
				
				IF Charindex(@ParentTableName+' '+@ParentAlias,@JOIN,0)=0
				BEGIN
					SET @JOIN=@JOIN+' LEFT JOIN '+@ParentTableName+' '+@ParentAlias+' WITH(NOLOCK) ON '+@ParentAlias+'.'+@ParentColumnKey+'='+@SysAlias+'.'+@SysColumnName
					IF @ParentTableName='COM_Address'	
					BEGIN
						SET @JOIN=@JOIN+' AND '+@ParentAlias+'.AddressTypeID=1'
						
						IF @Reference<>@CostCenterID
							SET @JOIN=@JOIN+' AND '+@ParentAlias+'.FeatureID='+CONVERT(NVARCHAR,@Reference)
					END
				END
			END 
			ELSE IF @SysColumnName IS NOT NULL AND @SysColumnName<>''
			BEGIN
				IF @SysColumnName LIKE 'dcNum%' OR @SysColumnName LIKE 'Gross%' OR @SysColumnName='Rate' OR @SysColumnName='Quantity'
					SET @COLS=@COLS+',ISNULL('
				ELSE
				BEGIN
					SET @COLS=@COLS+',ISNULL(CONVERT(nvarchar(200),'
					IF (@SysColumnName LIKE '%DATE%')
						SET @COLS=@COLS+'CONVERT(DATETIME,'
				END
				
				SET @COLS=@COLS+@SysAlias+'.'
				
				IF(@SysColumnName LIKE 'dcNum%' AND @IsCalc=1)
					SET @COLS=@COLS++REPLACE(@SysColumnName,'dcNum','dcCalcNum')
				ELSE
					SET @COLS=@COLS+@SysColumnName
				
				IF @SysColumnName LIKE 'dcNum%' OR @SysColumnName LIKE 'Gross%' OR @SysColumnName='Rate' OR @SysColumnName='Quantity'
					SET @COLS=@COLS+',0'
				ELSE 
				BEGIN
					IF (@SysColumnName LIKE '%DATE%')
						SET @COLS=@COLS+'),103'
					SET @COLS=@COLS+'),'''''
				END	
				SET @COLS=@COLS+') '+@Tag
				
			END
			ELSE IF @DefaultValue IS NOT NULL AND @DefaultValue<>''
			BEGIN
				SET @COLS=@COLS+','''+@DefaultValue+''' '+@Tag
			END
			ELSE 
			BEGIN
				IF @isRepeat=0
					SET @COLS=@COLS+',''OBJECTGROUP'' '+@Tag
				ELSE
					SET @COLS=@COLS+',''ARRAYGROUP'' '+@Tag
			END
			
			SET @PrevGroupName=@GroupName

			--SELECT @I,@COLS
			SET @I=@I+1
		END

		--SELECT @PRIMARYCOL,@COLS,@FROM,@JOIN,@WHERE

		SET @SQL ='SELECT '+@PrimaryKey+ISNULL(@COLS,'')+@JOIN+' WHERE '+@PrimaryKey+'='+CONVERT(NVARCHAR,@DocID)

		DROP TABLE #TTABLE

		PRINT @SQL 
		PRINT SUBSTRING(@SQL,4001,4000) 
		EXEC sp_executesql @SQL
		
		SELECT * FROM [COM_APIFieldsMapping] WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID AND MapID=@MapID
		
		declare @table table(ID INT IDENTITY(1,1) PRIMARY KEY,Result NVARCHAR(100))  
	
		SELECT @SQL=Result FROM [COM_APIFieldsMapping] WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID AND MapID=@MapID

		insert into @table   
		exec SPSplitString @SQL,',' 

		SELECT @I=1,@CNT=COUNT(*) FROM @table

		WHILE @I<=@CNT
		BEGIN
			SELECT @SQL=Result FROM @table WHERE ID=@I
			
			insert into @table  
			exec SPSplitString @SQL,'~' 
			
			SET @I=@I+1
		END

		DELETE  FROM @table WHERE ID<=@CNT

		SELECT T1.Result Source,CD.SysColumnName FROM @table T1
		JOIN @table T2 ON T1.ID+1=T2.ID
		JOIN ADM_CostCenterDef CD WITH(NOLOCK) ON CONVERT(NVARCHAR(MAX),CD.CostCenterColID)=T2.Result
		WHERE T1.ID%2<>@CNT%2 AND CD.SysColumnName LIKE 'dcAlpha%' 
	END
END
		

GO
