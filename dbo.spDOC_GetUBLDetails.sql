USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetUBLDetails]
	@DocID [int],
	@CostCenterID [int] = 0,
	@GSTType [nvarchar](16) = '',
	@CompanyID [int] = 0,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY     
SET NOCOUNT ON  

		CREATE TABLE #GSTMapping (ID INT IDENTITY(1,1) PRIMARY KEY,SysColumnName NVARCHAR(32),GSTColumnName NVARCHAR(32),SysTableName NVARCHAR(32),IsCalc BIT,DataType NVARCHAR(32),ValueType NVARCHAR(16),Reference INT,DefColumnName NVARCHAR(MAX))
		
		CREATE TABLE #MultiField (ID INT IDENTITY(1,1) PRIMARY KEY,DefColumnName NVARCHAR(MAX))
		CREATE TABLE #MultiFieldReason (ID INT IDENTITY(1,1) PRIMARY KEY,DefColumnName NVARCHAR(MAX))
		
		DECLARE @I INT,@ICNT INT,@J INT,@JCNT INT,@SysColumnName NVARCHAR(32),@GSTColumnName NVARCHAR(32),@IsCalc BIT,@SysTableName NVARCHAR(32),@DataType NVARCHAR(32),@ValueType NVARCHAR(16)
		,@TransTabColumns NVARCHAR(MAX),@TransColumns NVARCHAR(MAX),@Columns NVARCHAR(MAX),@JOIN NVARCHAR(MAX),@Reference INT,@SQL NVARCHAR(MAX),@DefColumnName NVARCHAR(MAX)

		DECLARE @CCData TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,Reference INT,NodeID INT)
		
		CREATE TABLE #AddDeatils (ID INT IDENTITY(1,1) PRIMARY KEY,DocID INT,AddType INT,Identification NVARCHAR(32),SchemeID NVARCHAR(32),BuildingNumber NVARCHAR(100),PlotIdentification NVARCHAR(100),StreetName NVARCHAR(100),AdditionalStreetName NVARCHAR(100),CityName NVARCHAR(100),District NVARCHAR(64),PostalZone NVARCHAR(32),Country NVARCHAR(64),CountrySubentityCode NVARCHAR(64),VATNumber NVARCHAR(32),RegistrationName NVARCHAR(100))
		INSERT INTO #AddDeatils(DocID,AddType)
		SELECT @DocID,1
		UNION
		SELECT @DocID,2
		
		TRUNCATE TABLE #GSTMapping
		INSERT INTO #GSTMapping
		SELECT DISTINCT GM.SysColumnName,GM.GSTColumnName,isnull(CD.SysTableName,'Com_Address')
		,GM.IsCalc,CD.ColumnDataType,GM.ValueType,GM.Reference,F.TableName
		FROM INV_GSTMapping GM WITH(NOLOCK)
		LEFT JOIN ADM_CostCenterDef CD WITH(NOLOCK) ON CD.CostCenterID=(CASE WHEN GM.Reference IN (92,93,94) THEN 110 ELSE GM.Reference END) AND CD.SysColumnName=GM.SysColumnName
		LEFT JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=(CASE WHEN GM.Reference IN (92,93,94) AND (CD.ColumnCostCenterID IS NULL OR CD.ColumnCostCenterID=0) THEN 110 ELSE CD.ColumnCostCenterID END)
		WHERE GM.CostCenterID=@CostCenterID AND GM.GSTType=@GSTType AND GM.ValueType IN ('Seller','Buyer') AND GM.Reference<>0
		
		SELECT @I=1,@ICNT=COUNT(*) FROM #GSTMapping WITH(NOLOCK)
		
		WHILE @I<=@ICNT
		BEGIN
			SELECT @SQL='',@SysColumnName=SysColumnName,@GSTColumnName=GSTColumnName,@IsCalc=IsCalc,@SysTableName=SysTableName,@DataType=DataType,@ValueType=ValueType,@DefColumnName=DefColumnName,@Reference=Reference
			FROM #GSTMapping WITH(NOLOCK) WHERE ID=@I
			
			IF @Reference=4
			BEGIN
				SET @SQL='SELECT '+@SysColumnName+' FROM PACT2C.dbo.'+@SysTableName+' WITH(NOLOCK) WHERE CompanyID='+CONVERT(NVARCHAR,@CompanyID)
				
				IF(@DataType='LISTBOX')
				BEGIN
					SET @SQL='SELECT TOP 1 '+ (CASE WHEN @IsCalc=1 THEN 'Name' ELSE 'Code' END) +' FROM '+@DefColumnName+' WITH(NOLOCK) WHERE CONVERT(NVARCHAR,NODEID) =('+@SQL+') '
				END
			END
			ELSE IF @Reference=2
			BEGIN
				IF NOT EXISTS (SELECT * FROM @CCData WHERE Reference=@Reference)
				BEGIN
					INSERT INTO @CCData
					SELECT @Reference,(CASE WHEN MAX(IDD.VoucherType)=-1 THEN MAX(IDD.DebitAccount) ELSE MAX(IDD.CreditAccount) END) 
					FROM INV_DocDetails IDD WITH(NOLOCK)
					WHERE IDD.DocID=@DocID
				END 

				
				IF(@SysTableName='COM_Address')
				BEGIN
					SET @SQL='SELECT TOP 1 '+@SysColumnName+' FROM '+@SysTableName+' WITH(NOLOCK) WHERE FEATUREID='+CONVERT(NVARCHAR,@Reference)+' AND FEATUREPK='+CONVERT(NVARCHAR,(SELECT NodeID FROM @CCData WHERE Reference=@Reference))
				END
				ELSE IF(@SysColumnName LIKE 'CCNID%')
				BEGIN
					SET @SQL='SELECT '+@SysColumnName+' FROM '+@SysTableName+' WITH(NOLOCK) WHERE CostCenterID='+CONVERT(NVARCHAR,@Reference)+' AND NodeID='+CONVERT(NVARCHAR,(SELECT NodeID FROM @CCData WHERE Reference=@Reference))
					SET @SQL='SELECT TOP 1 '+ (CASE WHEN @IsCalc=1 THEN 'Name' ELSE 'Code' END) +' FROM '+@DefColumnName+' WITH(NOLOCK) WHERE CONVERT(NVARCHAR,NODEID) =('+@SQL+') '
				END
				ELSE
					SET @SQL='SELECT '+@SysColumnName+' FROM '+@SysTableName+' WITH(NOLOCK) WHERE AccountID='+CONVERT(NVARCHAR,(SELECT NodeID FROM @CCData WHERE Reference=@Reference)) 
			END
			ELSE IF @Reference IN (92,93,94)
			BEGIN
				IF NOT EXISTS (SELECT * FROM @CCData WHERE Reference=@Reference)
				BEGIN
					INSERT INTO @CCData
					SELECT @Reference,ISNULL((SELECT AddressID FROM COM_DocAddressData WITH(NOLOCK) 
					WHERE DocID=@DocID AND [AddressTypeID]=(CASE WHEN @Reference=92 THEN 1 WHEN @Reference=93 THEN 2 ELSE 3 END )),0)
				END
				
				SET @SQL='SELECT '+@SysColumnName+' FROM '+@SysTableName+' WITH(NOLOCK) WHERE AddressID='+CONVERT(NVARCHAR,(SELECT NodeID FROM @CCData WHERE Reference=@Reference))
				IF(@SysColumnName LIKE 'CCNID%')
					SET @SQL='SELECT TOP 1 '+ (CASE WHEN @IsCalc=1 THEN 'Name' ELSE 'Code' END) +' FROM '+@DefColumnName+' WITH(NOLOCK) WHERE CONVERT(NVARCHAR,NODEID) =('+@SQL+') '
			END
			ELSE IF @Reference BETWEEN 40001 AND 49999
			BEGIN
				IF(@SysColumnName LIKE 'dcCCNID%')
				BEGIN
					SET @SQL='SELECT MAX(ISNULL(DCD.'+@SysColumnName+','''')) FROM INV_DocDetails IDD WITH(NOLOCK)
					JOIN COM_DocCCData DCD WITH(NOLOCK) ON DCD.InvDocDetailsID=IDD.InvDocDetailsID
					WHERE IDD.DocID='+CONVERT(NVARCHAR,@DocID)
					
					SET @SQL='SELECT TOP 1 '+ (CASE WHEN @IsCalc=1 THEN 'Name' ELSE 'Code' END) +' FROM '+@DefColumnName+' WITH(NOLOCK) WHERE CONVERT(NVARCHAR,NODEID) =('+@SQL+') '
				END
				ELSE IF(@SysColumnName LIKE 'dcAlpha%')
				BEGIN
					SET @SQL='SELECT MAX(ISNULL(DTD.'+@SysColumnName+','''')) FROM INV_DocDetails IDD WITH(NOLOCK)
					JOIN COM_DocTextData DTD WITH(NOLOCK) ON DTD.InvDocDetailsID=IDD.InvDocDetailsID
					WHERE IDD.DocID='+CONVERT(NVARCHAR,@DocID)
					
					IF(@DefColumnName IS NOT NULL OR @DefColumnName<>'')
						SET @SQL='SELECT TOP 1 '+ (CASE WHEN @IsCalc=1 THEN 'Name' ELSE 'Code' END) +' FROM '+@DefColumnName+' WITH(NOLOCK) WHERE CONVERT(NVARCHAR,NODEID) =('+@SQL+') '
				END
			END
			ELSE IF @Reference>50000
			BEGIN
				IF NOT EXISTS (SELECT * FROM @CCData WHERE Reference=@Reference)
				BEGIN
					SET @SQL='SELECT '+CONVERT(NVARCHAR,@Reference)+',MAX(DCD.dcCCNID'+CONVERT(NVARCHAR,(@Reference-50000))+') FROM INV_DocDetails IDD WITH(NOLOCK)
					JOIN COM_DocCCData DCD WITH(NOLOCK) ON DCD.InvDocDetailsID=IDD.InvDocDetailsID
					WHERE IDD.DocID='+CONVERT(NVARCHAR,@DocID)
					
					INSERT INTO @CCData
					EXEC (@SQL)
				END
				
				IF(@SysTableName='COM_Address')
				BEGIN
					SET @SQL='SELECT TOP 1 '+@SysColumnName+' FROM '+@SysTableName+' WITH(NOLOCK) WHERE FEATUREID='+CONVERT(NVARCHAR,@Reference)+' AND FEATUREPK='+CONVERT(NVARCHAR,(SELECT NodeID FROM @CCData WHERE Reference=@Reference))
				END
				ELSE
				BEGIN
					SET @SQL='SELECT '+@SysColumnName+' FROM '+@SysTableName+' WITH(NOLOCK) WHERE NodeID='+CONVERT(NVARCHAR,(SELECT NodeID FROM @CCData WHERE Reference=@Reference)) 
					IF(@SysColumnName LIKE 'CCNID%')
					BEGIN
						SET @SQL=@SQL+' AND CostCenterID='+CONVERT(NVARCHAR,@Reference)
						SET @SQL='SELECT TOP 1 '+ (CASE WHEN @IsCalc=1 THEN 'Name' ELSE 'Code' END) +' FROM '+@DefColumnName+' WITH(NOLOCK) WHERE CONVERT(NVARCHAR,NODEID) =('+@SQL+') '
					END
				END
			END
			
			SET @SQL='UPDATE #AddDeatils SET '+REPLACE(REPLACE(@GSTColumnName,'_Seller',''),'_Buyer','')+'=('+@SQL+')
			WHERE AddType'

			IF(@GSTColumnName LIKE '%_Seller')
				SET @SQL=@SQL+'=1'
			ELSE IF(@GSTColumnName LIKE '%_Buyer')
				SET @SQL=@SQL+'=2'
			ELSE
				SET @SQL=@SQL+' IN (1,2)'	
			
			PRINT @SQL
			EXEC (@SQL)
			SET @I=@I+1
		END
		
		TRUNCATE TABLE #GSTMapping
		INSERT INTO #GSTMapping
		SELECT DISTINCT GM.SysColumnName,GM.GSTColumnName,F.TableName,GM.IsCalc,CD.ColumnDataType,GM.ValueType,GM.Reference,GM.DefColumnName
		FROM INV_GSTMapping GM WITH(NOLOCK)
		JOIN ADM_CostCenterDef CD WITH(NOLOCK) ON CD.CostCenterID=GM.CostCenterID AND CD.SysColumnName=GM.SysColumnName
		LEFT JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=CD.ColumnCostCenterID
		WHERE GM.CostCenterID=@CostCenterID AND GM.GSTType=@GSTType AND ValueType NOT IN ('Seller','Buyer')
		UNION 
		SELECT DISTINCT GM.SysColumnName,GM.GSTColumnName,NULL,GM.IsCalc,'FLOAT',GM.ValueType,GM.Reference,GM.DefColumnName
		FROM INV_GSTMapping GM WITH(NOLOCK)
		WHERE GM.CostCenterID=@CostCenterID AND GM.GSTType=@GSTType AND ValueType NOT IN ('Seller','Buyer') AND (GM.SysColumnName='MULTIPLEFIELDS' OR GM.SysColumnName='MULTIPLEFIELDS_Reason')

		SELECT @I=1,@ICNT=COUNT(*),@TransTabColumns='',@TransColumns='',@Columns='',@JOIN='' FROM #GSTMapping WITH(NOLOCK)

		WHILE @I<=@ICNT
		BEGIN
			SELECT @SysColumnName=SysColumnName,@GSTColumnName=GSTColumnName,@IsCalc=IsCalc,@SysTableName=SysTableName,@DataType=DataType,@ValueType=ValueType,@DefColumnName=DefColumnName
			FROM #GSTMapping WITH(NOLOCK) WHERE ID=@I
			IF(@SysColumnName='MULTIPLEFIELDS')
			BEGIN
				IF @DefColumnName IS NOT NULL AND @DefColumnName<>''
				BEGIN
					IF(@ValueType='Transaction')
					BEGIN
						SET @TransTabColumns=@TransTabColumns+','+@GSTColumnName
						IF (@IsCalc=1)
							SET @TransColumns=@TransColumns+',SUM(ISNULL(DND.'+REPLACE(REPLACE(@DefColumnName,',',',0)+ISNULL(DND.'),'dcNum','dcCalcNum')+',0)) '+@GSTColumnName
						ELSE
							SET @TransColumns=@TransColumns+',SUM(ISNULL(DND.'+REPLACE(@DefColumnName,',',',0)+ISNULL(DND.')+',0)) '+@GSTColumnName
					END
					ELSE
					BEGIN
						IF (@IsCalc=1)
							SET @Columns=@Columns+',ISNULL(DND.'+REPLACE(REPLACE(@DefColumnName,',',',0)+ISNULL(DND.'),'dcNum','dcCalcNum')+',0) '+@GSTColumnName
						ELSE
							SET @Columns=@Columns+',ISNULL(DND.'+REPLACE(@DefColumnName,',',',0)+ISNULL(DND.')+',0) '+@GSTColumnName
					END
				END
			END
			ELSE IF(@SysColumnName='MULTIPLEFIELDS_Reason')
			BEGIN
				IF @DefColumnName IS NOT NULL AND @DefColumnName<>''
				BEGIN
					
					TRUNCATE TABLE #MultiField
					INSERT INTO #MultiField
					EXEC SPSplitString @DefColumnName,',' 
					
					SELECT @J=1,@JCNT=COUNT(*) FROM #MultiField WITH(NOLOCK)
					WHILE @J<=@JCNT
					BEGIN
					
						SELECT @DefColumnName=DefColumnName FROM #MultiField WITH(NOLOCK) WHERE ID=@J
					
						TRUNCATE TABLE #MultiFieldReason
						INSERT INTO #MultiFieldReason
						EXEC SPSplitString @DefColumnName,'~'
						
						
						IF(@ValueType='Transaction')
						BEGIN
							SET @TransTabColumns=@TransTabColumns+','+@GSTColumnName
							IF (@IsCalc=1)
								SET @TransColumns=@TransColumns+',SUM(ISNULL(DND.'+REPLACE(REPLACE(@DefColumnName,',',',0)+ISNULL(DND.'),'dcNum','dcCalcNum')+',0)) '+@GSTColumnName
							ELSE
								SET @TransColumns=@TransColumns+',SUM(ISNULL(DND.'+REPLACE(@DefColumnName,',',',0)+ISNULL(DND.')+',0)) '+@GSTColumnName
						END
						ELSE
						BEGIN
							IF (@IsCalc=1)
								SELECT @Columns=@Columns+',ISNULL(DND.'+REPLACE(DefColumnName,'dcNum','dcCalcNum')+',0) '
								FROM #MultiFieldReason WITH(NOLOCK) WHERE ID=1
							ELSE
								SELECT @Columns=@Columns+',ISNULL(DND.'+DefColumnName+',0) ' 
								FROM #MultiFieldReason WITH(NOLOCK) WHERE ID=1
							SELECT @Columns=@Columns+@GSTColumnName+'_'+CONVERT(NVARCHAR,@J)
							SELECT @Columns=@Columns+','''+DefColumnName+''' '+@GSTColumnName+'_Code_'+CONVERT(NVARCHAR,@J) 
							FROM #MultiFieldReason WITH(NOLOCK) WHERE ID=2
							SELECT @Columns=@Columns+','''+DefColumnName+''' '+@GSTColumnName+'_Reason_'+CONVERT(NVARCHAR,@J) 
							FROM #MultiFieldReason WITH(NOLOCK) WHERE ID=3
								
							SET @Columns=@Columns+',CU'+CONVERT(NVARCHAR,@I)+'_'+CONVERT(NVARCHAR,@J)+'.Symbol '+@GSTColumnName+'_Curr_'+CONVERT(NVARCHAR,@J)
							SELECT @JOIN=@JOIN+' JOIN COM_Currency CU'+CONVERT(NVARCHAR,@I)+'_'+CONVERT(NVARCHAR,@J)+' WITH(NOLOCK) ON CU'+CONVERT(NVARCHAR,@I)+'_'+CONVERT(NVARCHAR,@J)+'.CurrencyID=ISNULL(DND.'+REPLACE(DefColumnName,'dcNum','dcCurrID')+',1)'
	FROM #MultiFieldReason WITH(NOLOCK) WHERE ID=1				
						END
					
						SET @J=@J+1
					END 
				END
			END
			ELSE IF(@SysColumnName LIKE 'dcNum%')
			BEGIN
				IF(@ValueType='Transaction')
				BEGIN
					SET @TransTabColumns=@TransTabColumns+','+@GSTColumnName
					IF (@IsCalc=1)
						SET @TransColumns=@TransColumns+',SUM(ISNULL(DND.'+REPLACE(@SysColumnName,'dcNum','dcCalcNum')+',0)) '+@GSTColumnName
					ELSE
						SET @TransColumns=@TransColumns+',SUM(ISNULL(DND.'+@SysColumnName+',0)) '+@GSTColumnName
				END
				ELSE
				BEGIN
					IF (@IsCalc=1)
						SET @Columns=@Columns+',ISNULL(DND.'+REPLACE(@SysColumnName,'dcNum','dcCalcNum')+',0) '+@GSTColumnName
					ELSE
						SET @Columns=@Columns+',ISNULL(DND.'+@SysColumnName+',0) '+@GSTColumnName
					
					SET @Columns=@Columns+',CU'+CONVERT(NVARCHAR,@I)+'.Symbol '+@GSTColumnName+'_Curr'
					SET @JOIN=@JOIN+' JOIN COM_Currency CU'+CONVERT(NVARCHAR,@I)+' WITH(NOLOCK) ON CU'+CONVERT(NVARCHAR,@I)+'.CurrencyID=ISNULL(DND.'+REPLACE(@SysColumnName,'dcNum','dcCurrID')+',1)'
				END
			END
			ELSE IF(@SysColumnName LIKE 'dcCCNID%' AND @SysTableName IS NOT NULL AND @SysTableName<>'')
			BEGIN
				SET @Columns=@Columns+',CASE WHEN CC'+CONVERT(NVARCHAR,@I)+'.NodeID>1 THEN CC'+CONVERT(NVARCHAR,@I)+ (CASE WHEN @IsCalc=1 THEN '.Name ' ELSE '.Code ' END)+'ELSE '''' END ' +@GSTColumnName
				
				IF @GSTColumnName='VATCategory'
				BEGIN
					SET @Columns=@Columns+',CASE WHEN CC'+CONVERT(NVARCHAR,@I)+'.NodeID>1 THEN CC'+CONVERT(NVARCHAR,@I)+ (CASE WHEN @IsCalc=0 THEN '.Name ' ELSE '.Code ' END)+'ELSE '''' END ' +@GSTColumnName+'_Code'
					SET @Columns=@Columns+',CASE WHEN CC'+CONVERT(NVARCHAR,@I)+'.NodeID>1 THEN CC'+CONVERT(NVARCHAR,@I)+'.AliasName ELSE '''' END ' +@GSTColumnName+'_Reason'				
				END
					
				SET @JOIN=@JOIN+' JOIN '+@SysTableName+' CC'+CONVERT(NVARCHAR,@I)+' WITH(NOLOCK) ON CC'+CONVERT(NVARCHAR,@I)+'.NodeID=DCD.'+@SysColumnName
			END
			ELSE IF(@SysColumnName LIKE 'dcAlpha%')
			BEGIN
				IF(@SysTableName IS NULL OR @SysTableName='')
					SET @Columns=@Columns+',DTD.'+@SysColumnName+' '+@GSTColumnName
				ELSE
				BEGIN
					SET @Columns=@Columns+',CC'+CONVERT(NVARCHAR,@I)+ (CASE WHEN @IsCalc=1 THEN '.Name ' ELSE '.Code ' END) + @GSTColumnName
					SET @JOIN=@JOIN+' LEFT JOIN '+@SysTableName+' CC'+CONVERT(NVARCHAR,@I)+' WITH(NOLOCK) ON CONVERT(NVARCHAR,CC'+CONVERT(NVARCHAR,@I)+'.NodeID)=DTD.'+@SysColumnName
				END
			END
			ELSE 
			BEGIN
				IF (@DataType LIKE 'DATE%')
					SET @Columns=@Columns+',CONVERT(DATETIME,IDD.'+@SysColumnName+') '+@GSTColumnName
				ELSE IF(@SysColumnName='ProductID')
				BEGIN
					SET @Columns=@Columns+ ',PR.Product'+ (CASE WHEN @IsCalc=1 THEN 'Name ' ELSE 'Code ' END) +@GSTColumnName
				END
				ELSE IF(@SysColumnName='Net' AND @ValueType='Transaction')
				BEGIN
					SET @TransTabColumns=@TransTabColumns+','+@GSTColumnName
					SET @TransColumns=@TransColumns+',SUM(ISNULL(IDD.'+@SysColumnName+',0)) '+@GSTColumnName
				END
				ELSE
					SET @Columns=@Columns+',IDD.'+@SysColumnName+' '+@GSTColumnName
			END
			SET @I=@I+1
		END

		DECLARE @DocumentType INT
		SET @SQL='SELECT '
		
		SELECT @SysColumnName=DocumentName,@DocumentType=DocumentType FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
		
		SET @SQL=@SQL+''''+(CASE WHEN (@SysColumnName LIKE '%CREDIT%' OR @DocumentType=6) THEN 'Credit note' WHEN @SysColumnName LIKE '%DEBIT%' THEN 'Debit note' WHEN @SysColumnName LIKE '%PAYMENT%' THEN 'Prepayment Invoice' ELSE 'Tax invoice' END)+''' Invoice,'
		
		SET @SQL=@SQL+'IDD.DocID,IDD.VoucherNo,IDD.DocNumber,DID.[GUID],CONVERT(DATETIME,IDD.DocDate) IssueDate,CONVERT(DATETIME,IDD.CreatedDate) IssueTime,IDD.DocSeqNo,IDD.Rate,IDD.Gross
		,IDD.Quantity,UM.UnitName,1 UOMConversion,UM.UnitName BaseName
		,CU.Symbol CurrencyCode
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.Identification ELSE BA.Identification END) Identification_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.SchemeID ELSE BA.SchemeID END) SchemeID_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.BuildingNumber ELSE BA.BuildingNumber END) BuildingNumber_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.PlotIdentification ELSE BA.PlotIdentification END) PlotIdentification_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.StreetName ELSE BA.StreetName END) StreetName_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.AdditionalStreetName ELSE BA.AdditionalStreetName END) AdditionalStreetName_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.CityName ELSE BA.CityName END) CityName_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.District ELSE BA.District END) District_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.PostalZone ELSE BA.PostalZone END) PostalZone_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.Country ELSE BA.Country END) Country_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.CountrySubentityCode ELSE BA.CountrySubentityCode END) CountrySubentityCode_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.VATNumber ELSE BA.VATNumber END) VATNumber_Seller
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.RegistrationName ELSE BA.RegistrationName END) RegistrationName_Seller
		
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.Identification ELSE SA.Identification END) Identification_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.SchemeID ELSE SA.SchemeID END) SchemeID_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.BuildingNumber ELSE SA.BuildingNumber END) BuildingNumber_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.PlotIdentification ELSE SA.PlotIdentification END) PlotIdentification_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.StreetName ELSE SA.StreetName END) StreetName_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.AdditionalStreetName ELSE SA.AdditionalStreetName END) AdditionalStreetName_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.CityName ELSE SA.CityName END) CityName_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.District ELSE SA.District END) District_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.PostalZone ELSE SA.PostalZone END) PostalZone_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.Country ELSE SA.Country END) Country_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.CountrySubentityCode ELSE SA.CountrySubentityCode END) CountrySubentityCode_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.VATNumber ELSE SA.VATNumber END) VATNumber_Buyer
		,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN BA.RegistrationName ELSE SA.RegistrationName END) RegistrationName_Buyer
		'
		SET @SQL=@SQL+@Columns
		SET @SQL=@SQL+' FROM INV_DocDetails IDD WITH(NOLOCK)
			JOIN COM_DocID DID WITH(NOLOCK) ON DID.ID=IDD.DocID
			JOIN COM_UOM UM WITH(NOLOCK) ON UM.UOMID=IDD.Unit
			JOIN COM_Currency CU WITH(NOLOCK) ON CU.CurrencyID=IDD.CurrencyID
			JOIN COM_DocNumData DND WITH(NOLOCK) ON DND.InvDocDetailsID=IDD.InvDocDetailsID
			JOIN COM_DocCCData DCD WITH(NOLOCK) ON DCD.InvDocDetailsID=IDD.InvDocDetailsID
			JOIN COM_DocTextData DTD WITH(NOLOCK) ON DTD.InvDocDetailsID=IDD.InvDocDetailsID 
			JOIN INV_Product PR WITH(NOLOCK) ON PR.ProductID=IDD.ProductID 
			JOIN #AddDeatils SA WITH(NOLOCK) ON SA.DocID=IDD.DocID AND SA.AddType=1
			JOIN #AddDeatils BA WITH(NOLOCK) ON BA.DocID=IDD.DocID AND BA.AddType=2 '
		SET @SQL=@SQL+@JOIN
		SET @SQL=@SQL+' WHERE IDD.DocID='+CONVERT(NVARCHAR,@DocID)+' AND (IDD.IsQtyFreeOffer=0 OR IDD.ParentSchemeID IS NULL)'

		PRINT @SQL
		PRINT SUBSTRING(@SQL,4001,4000)
		EXEC (@SQL)
		
		SELECT DISTINCT LIDD.VoucherNo,CONVERT(DATETIME,LIDD.DocDate) IssueDate FROM INV_DocDetails IDD WITH(NOLOCK)
		JOIN INV_DocDetails LIDD WITH(NOLOCK) ON IDD.LinkedInvDocDetailsID=LIDD.InvDocDetailsID
		WHERE IDD.DocID=@DocID AND IDD.LinkedInvDocDetailsID>0
		
		DROP TABLE #MultiField
		DROP TABLE #MultiFieldReason
		DROP TABLE #GSTMapping
		DROP TABLE #AddDeatils

COMMIT TRANSACTION    
SET NOCOUNT OFF;    
return 1
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
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
		
--exec spDOC_GetUBLDetails 410,40011,'UBL',1 ,1,1


--SELECT * FROM INV_DOCDETAILS WHERE COSTCENTERID=40011

--select * from COM_Currency





GO
