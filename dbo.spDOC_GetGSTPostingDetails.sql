USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetGSTPostingDetails]
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
	IF (@GSTType IS NULL OR @GSTType='')
	BEGIN
		SELECT GSTType FROM INV_GSTMapping WITH(NOLOCK)
		WHERE CostCenterID=@CostCenterID
		GROUP BY GSTType
		
		SELECT GSTType,SysColumnName,GSTColumnName FROM INV_GSTMapping WITH(NOLOCK)
		WHERE CostCenterID=@CostCenterID AND (ValueType='Result' OR GSTColumnName='transDistance')
		UNION
		SELECT GSTType,SysColumnName,GSTColumnName FROM INV_GSTMapping WITH(NOLOCK)
		WHERE CostCenterID=@CostCenterID AND GSTType='EWB' AND GSTColumnName='transporterId'
	END
	ELSE IF (@GSTType='GST')
	BEGIN
		SELECT SysColumnName,GSTColumnName FROM INV_GSTMapping WITH(NOLOCK)
		WHERE CostCenterID=0 AND GSTType='GST'
	END
	ELSE
	BEGIN
		CREATE TABLE #AddDeatils (ID INT IDENTITY(1,1) PRIMARY KEY,DocID INT,AddType INT,Gstin NVARCHAR(32),LglName NVARCHAR(100),TrdName NVARCHAR(100),Addr1 NVARCHAR(MAX),Addr2 NVARCHAR(MAX),Place NVARCHAR(100),Pincode INT,StateCode NVARCHAR(100),Phone NVARCHAR(32),Email NVARCHAR(64),Pos NVARCHAR(32),gstReg NVARCHAR(32),UserName NVARCHAR(32),Password NVARCHAR(32))
		
		CREATE TABLE #Transaction (ID INT IDENTITY(1,1) PRIMARY KEY,DocID INT,totValue FLOAT,cgstValue FLOAT,sgstValue FLOAT,igstValue FLOAT,cessValue FLOAT,
		stateCessValue FLOAT,totDiscount FLOAT,totOtherCharges FLOAT,roundOffAmout FLOAT,totInvValue FLOAT,totInvValueFc FLOAT)

		CREATE TABLE #GSTMapping (ID INT IDENTITY(1,1) PRIMARY KEY,SysColumnName NVARCHAR(32),GSTColumnName NVARCHAR(32),SysTableName NVARCHAR(32),IsCalc BIT,DataType NVARCHAR(32),ValueType NVARCHAR(16),Reference INT,DefColumnName NVARCHAR(MAX))
		
		DECLARE @I INT,@ICNT INT,@SysColumnName NVARCHAR(32),@GSTColumnName NVARCHAR(32),@IsCalc BIT,@SysTableName NVARCHAR(32),@DataType NVARCHAR(32),@ValueType NVARCHAR(16)
		,@TransTabColumns NVARCHAR(MAX),@TransColumns NVARCHAR(MAX),@Columns NVARCHAR(MAX),@JOIN NVARCHAR(MAX),@Reference INT,@SQL NVARCHAR(MAX),@DefColumnName NVARCHAR(MAX)

		INSERT INTO #AddDeatils(DocID,AddType)
		SELECT @DocID,1
		UNION
		SELECT @DocID,2
		UNION
		SELECT @DocID,3
		UNION
		SELECT @DocID,4
		
		DECLARE @CCData TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,Reference INT,NodeID INT)
		
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
			
			SET @SQL='UPDATE #AddDeatils SET '+REPLACE(REPLACE(REPLACE(REPLACE(@GSTColumnName,'from',''),'to',''),'disp',''),'ship','')+'=('+@SQL+')
			WHERE AddType'

			IF(@GSTColumnName LIKE 'from%')
				SET @SQL=@SQL+'=1'
			ELSE IF(@GSTColumnName LIKE 'disp%')
				SET @SQL=@SQL+'=2'
			ELSE IF(@GSTColumnName LIKE 'to%')
				SET @SQL=@SQL+'=3'
			ELSE IF(@GSTColumnName LIKE 'ship%')
				SET @SQL=@SQL+'=4'
			ELSE
				SET @SQL=@SQL+' IN (1,2,3,4)'	
			
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
		WHERE GM.CostCenterID=@CostCenterID AND GM.GSTType=@GSTType AND ValueType NOT IN ('Seller','Buyer') AND GM.SysColumnName='MULTIPLEFIELDS'

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
				END
			END
			ELSE IF(@SysColumnName LIKE 'dcCCNID%' AND @SysTableName IS NOT NULL AND @SysTableName<>'')
			BEGIN
				SET @Columns=@Columns+',CASE WHEN CC'+CONVERT(NVARCHAR,@I)+'.NodeID>1 THEN CC'+CONVERT(NVARCHAR,@I)+ (CASE WHEN @IsCalc=1 THEN '.Name ' ELSE '.Code ' END)+'ELSE '''' END ' +@GSTColumnName
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

		SET @SQL='INSERT INTO #Transaction (DocID'
		SET @SQL=@SQL+@TransTabColumns
		SET @SQL=@SQL+')	
		SELECT '+CONVERT(NVARCHAR,@DocID)
		SET @SQL=@SQL+@TransColumns
		SET @SQL=@SQL+' FROM INV_DocDetails IDD WITH(NOLOCK)
		JOIN COM_DocNumData DND WITH(NOLOCK) ON DND.InvDocDetailsID=IDD.InvDocDetailsID
		JOIN COM_DocCCData DCD WITH(NOLOCK) ON DCD.InvDocDetailsID=IDD.InvDocDetailsID
		WHERE IDD.DocID='+CONVERT(NVARCHAR,@DocID)+' AND (IDD.IsQtyFreeOffer=0 OR IDD.ParentSchemeID IS NULL)'
		PRINT @SQL
		EXEC(@SQL)
		
		DECLARE @DocumentType INT
		
		SET @SQL='SELECT '
		IF (@GSTType='EINV')	
		BEGIN
			SELECT @SysColumnName=DocumentName,@DocumentType=DocumentType FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
			
			SET @SQL=@SQL+''''+(CASE WHEN (@SysColumnName LIKE '%CREDIT%' OR @DocumentType=6) THEN 'CREDIT NOTE' WHEN @SysColumnName LIKE '%DEBIT%' THEN 'DEBIT NOTE' ELSE 'INVOICE' END)+''' docType,'
		END
		ELSE IF (@GSTType='EWB')	
			SET @SQL=@SQL+'(CASE WHEN IDD.VoucherType=-1 THEN ''Outward'' ELSE ''Inward'' END) supplyType,'
		
		SET @SQL=@SQL+'FA.UserName,FA.Password,(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.Gstin ELSE TA.Gstin END) fromGstin,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.LglName ELSE TA.LglName END) fromLglName,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.TrdName ELSE TA.TrdName END) fromTrdName,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.Addr1 ELSE TA.Addr1 END) fromAddr1,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.Addr2 ELSE TA.Addr2 END) fromAddr2,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.Place ELSE TA.Place END) fromPlace,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.Pincode ELSE TA.Pincode END) fromPincode,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.StateCode ELSE TA.StateCode END) fromStateCode,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.Phone ELSE TA.Phone END) fromPhone,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN FA.Email ELSE TA.Email END) fromEmail,
		
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN DA.LglName ELSE SA.TrdName END) dispLglName,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN DA.Addr1 ELSE SA.Addr1 END) dispAddr1,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN DA.Addr2 ELSE SA.Addr2 END) dispAddr2,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN DA.Place ELSE SA.Place END) dispPlace,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN DA.Pincode ELSE SA.Pincode END) dispPincode,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN DA.StateCode ELSE SA.StateCode END) dispStateCode,
		
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.gstReg ELSE FA.gstReg END) gstReg,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.Gstin ELSE FA.Gstin END) toGstin,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.LglName ELSE FA.LglName END) toLglName,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.TrdName ELSE FA.TrdName END) toTrdName,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.Addr1 ELSE FA.Addr1 END) toAddr1,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.Addr2 ELSE FA.Addr2 END) toAddr2,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.Place ELSE FA.Place END) toPlace,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.Pincode ELSE FA.Pincode END) toPincode,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.StateCode ELSE FA.StateCode END) toStateCode,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.Phone ELSE FA.Phone END) toPhone,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.Email ELSE FA.Email END) toEmail,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN TA.Pos ELSE FA.Pos END) Pos,
		
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.Gstin ELSE DA.Gstin END) shipGstin,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.LglName ELSE DA.LglName END) shipLglName,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.TrdName ELSE DA.TrdName END) shipTrdName,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.Addr1 ELSE DA.Addr1 END) shipAddr1,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.Addr2 ELSE DA.Addr2 END) shipAddr2,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.Place ELSE DA.Place END) shipPlace,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.Pincode ELSE DA.Pincode END) shipPincode,
		(CASE WHEN IDD.VoucherType=-1 OR IDD.DocumentType=6 THEN SA.StateCode ELSE DA.StateCode END) shipStateCode,
		BATC.BatchNumber batchName,CONVERT(DATETIME,BATC.ExpiryDate) batchExpDate,CONVERT(DATETIME,BATC.ExpiryDate) batchWarDate,
		FIDD.Quantity freeQty,
		TR.* '
		SET @SQL=@SQL+@Columns
		SET @SQL=@SQL+' FROM INV_DocDetails IDD WITH(NOLOCK)
			JOIN COM_DocNumData DND WITH(NOLOCK) ON DND.InvDocDetailsID=IDD.InvDocDetailsID
			JOIN COM_DocCCData DCD WITH(NOLOCK) ON DCD.InvDocDetailsID=IDD.InvDocDetailsID
			JOIN COM_DocTextData DTD WITH(NOLOCK) ON DTD.InvDocDetailsID=IDD.InvDocDetailsID 
			JOIN INV_Product PR WITH(NOLOCK) ON PR.ProductID=IDD.ProductID 
			JOIN #Transaction TR WITH(NOLOCK) ON TR.DocID=IDD.DocID
			JOIN #AddDeatils FA WITH(NOLOCK) ON FA.DocID=IDD.DocID AND FA.AddType=1
			JOIN #AddDeatils DA WITH(NOLOCK) ON DA.DocID=IDD.DocID AND DA.AddType=2
			JOIN #AddDeatils TA WITH(NOLOCK) ON TA.DocID=IDD.DocID AND TA.AddType=3
			JOIN #AddDeatils SA WITH(NOLOCK) ON SA.DocID=IDD.DocID AND SA.AddType=4 
			LEFT JOIN INV_Batches BATC WITH(NOLOCK) ON BATC.BatchID=IDD.BatchID AND BATC.BatchID>1
			LEFT JOIN INV_DocDetails FIDD WITH(NOLOCK) ON FIDD.DocID=IDD.DocID AND FIDD.IsQtyFreeOffer=1 AND FIDD.ParentSchemeID IS NOT NULL AND FIDD.DocSeqNo=(IDD.DocSeqNo+1) '
		SET @SQL=@SQL+@JOIN
		SET @SQL=@SQL+' WHERE IDD.DocID='+CONVERT(NVARCHAR,@DocID)+' AND (IDD.IsQtyFreeOffer=0 OR IDD.ParentSchemeID IS NULL)'

		PRINT @SQL
		EXEC (@SQL)
		
		DROP TABLE #GSTMapping
		DROP TABLE #Transaction
		DROP TABLE #AddDeatils
	END
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
		





GO
