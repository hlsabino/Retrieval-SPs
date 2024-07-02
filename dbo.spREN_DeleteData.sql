﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_DeleteData]
	@FeaturesList [nvarchar](25) = '92,93,94,95,103,104,129',
	@UserID [int] = 1,
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
	DECLARE @TAB TABLE(ID INT IDENTITY(1,1) PRIMARY KEY,FeatureID INT)
	DECLARE @DATATAB TABLE(NodeID INT)
	DECLARE @DOCTAB TABLE(DocID INT)
	
	DECLARE @CostCenterID INT,@I INT,@CNT INT,@IsExists BIT
	DECLARE @PrefValue NVARCHAR(MAX),@Dimesion INT,@ICNT INT ,@TCNT INT,@NID INT
	
	CREATE TABLE #NodeTAB(ID INT IDENTITY(1,1) PRIMARY KEY,NodeID INT)
	
	INSERT INTO #NodeTAB		
	EXEC SPSplitString @FeaturesList,',' 
	
	INSERT INTO @TAB
	SELECT NodeID FROM #NodeTAB WHERE NodeID=104
	
	INSERT INTO @TAB
	SELECT NodeID FROM #NodeTAB WHERE NodeID=95
	
	INSERT INTO @TAB
	SELECT NodeID FROM #NodeTAB WHERE NodeID=129
	
	INSERT INTO @TAB
	SELECT NodeID FROM #NodeTAB WHERE NodeID=103
	
	INSERT INTO @TAB
	SELECT NodeID FROM #NodeTAB WHERE NodeID=93
	
	INSERT INTO @TAB
	SELECT NodeID FROM #NodeTAB WHERE NodeID=94
	
	INSERT INTO @TAB
	SELECT NodeID FROM #NodeTAB WHERE NodeID=92
	
	SELECT @I=1,@CNT=COUNT(*) FROM @TAB 
	
	WHILE @I<=@CNT
	BEGIN
		SELECT @PrefValue='',@Dimesion=0,@CostCenterID=FeatureID FROM @TAB WHERE ID=@I

		IF @CostCenterID=95 OR @CostCenterID=104 OR @CostCenterID=103 OR @CostCenterID=129
		BEGIN
			DELETE FROM @DATATAB
			DELETE FROM @DOCTAB
			
			IF @CostCenterID=95 OR @CostCenterID=104
			BEGIN
				INSERT INTO @DATATAB
				SELECT ContractID FROM REN_Contract WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
				UNION
				SELECT CCD.NodeID FROM COM_CCCCDATA CCD WITH(NOLOCK)
				LEFT JOIN REN_Contract RC WITH(NOLOCK) ON RC.ContractID=CCD.NodeID
				WHERE CCD.CostCenterID=@CostCenterID AND RC.ContractID IS NULL
			END
			ELSE IF @CostCenterID=103 OR @CostCenterID=129
			BEGIN
				INSERT INTO @DATATAB
				SELECT QuotationID FROM REN_Quotation WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
				UNION
				SELECT CCD.NodeID FROM COM_CCCCDATA CCD WITH(NOLOCK)
				LEFT JOIN REN_Quotation RQ WITH(NOLOCK) ON RQ.QuotationID=CCD.NodeID
				WHERE CCD.CostCenterID=@CostCenterID AND RQ.QuotationID IS NULL
			END
			
			INSERT INTO @DOCTAB
			SELECT DISTINCT DocID FROM REN_ContractDocMapping WITH(NOLOCK) 
			WHERE ContractID IN (SELECT NodeID FROM @DATATAB) AND ContractCCID=@CostCenterID
			UNION
			SELECT DISTINCT DocID FROM INV_DocDetails WITH(NOLOCK) 
			WHERE RefCCID=@CostCenterID AND RefNodeid>0
			UNION
			SELECT DISTINCT DocID FROM ACC_DocDetails WITH(NOLOCK) 
			WHERE RefCCID=@CostCenterID AND RefNodeid>0
			
			INSERT INTO @DOCTAB
			SELECT DISTINCT DocID FROM INV_DocDetails WITH(NOLOCK)
			WHERE RefCCID=400 AND RefNodeid IN (SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			
			INSERT INTO @DOCTAB
			SELECT DISTINCT DocID FROM ACC_DocDetails WITH(NOLOCK)
			WHERE RefCCID=400 AND RefNodeid IN (SELECT AccDocDetailsID FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			
			INSERT INTO @DOCTAB
			SELECT DISTINCT IDD.DocID FROM ACC_DocDetails IDD WITH(NOLOCK)
			LEFT JOIN ACC_DocDetails RDD WITH(NOLOCK) ON RDD.AccDocDetailsID=IDD.RefNodeid
			WHERE IDD.RefCCID=400 AND IDD.RefNodeid>0 AND RDD.AccDocDetailsID IS NULL

			DELETE FROM COM_Files WHERE FeatureID BETWEEN 40000 AND 49999 AND FeaturePK IN (SELECT DocID FROM @DOCTAB)
			DELETE FROM COM_Notes WHERE FeatureID BETWEEN 40000 AND 49999 AND FeaturePK IN (SELECT DocID FROM @DOCTAB)
			
			DELETE FROM COM_BillwiseHistory WHERE DocumentNo IN (SELECT DocNo FROM COM_DocID WITH(NOLOCK) WHERE ID IN (SELECT DocID FROM @DOCTAB))
			DELETE FROM COM_Billwise WHERE DocNo IN (SELECT DocNo FROM COM_DocID WITH(NOLOCK) WHERE ID IN (SELECT DocID FROM @DOCTAB))
			
			DELETE FROM COM_BillWiseNonAcc WHERE DocNo IN (SELECT DocNo FROM COM_DocID WITH(NOLOCK) WHERE ID IN (SELECT DocID FROM @DOCTAB))
			
			DELETE FROM COM_DocCCData_History WHERE InvDocDetailsID IN (SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			OR AccDocDetailsID IN (SELECT AccDocDetailsID FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			DELETE FROM COM_DocCCData WHERE InvDocDetailsID IN (SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			OR AccDocDetailsID IN (SELECT AccDocDetailsID FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			DELETE FROM COM_DocNumData_History WHERE InvDocDetailsID IN (SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			OR AccDocDetailsID IN (SELECT AccDocDetailsID FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			DELETE FROM COM_DocNumData WHERE InvDocDetailsID IN (SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			OR AccDocDetailsID IN (SELECT AccDocDetailsID FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			DELETE FROM COM_DocTextData_History  WHERE InvDocDetailsID IN (SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			OR AccDocDetailsID IN (SELECT AccDocDetailsID FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			DELETE FROM COM_DocTextData WHERE InvDocDetailsID IN (SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))
			OR AccDocDetailsID IN (SELECT AccDocDetailsID FROM ACC_DocDetails WITH(NOLOCK) WHERE DocID IN (SELECT DocID FROM @DOCTAB))

			DELETE FROM ACC_DocDetails_History_ATUser WHERE DocID IN (SELECT DocID FROM @DOCTAB)
			DELETE FROM ACC_DocDetails_History WHERE DocID IN (SELECT DocID FROM @DOCTAB)
			DELETE FROM ACC_DocDetails WHERE DocID IN (SELECT DocID FROM @DOCTAB)

			DELETE FROM INV_DocDetails_History_ATUser WHERE DocID IN (SELECT DocID FROM @DOCTAB)
			DELETE FROM INV_DocDetails_History WHERE DocID IN (SELECT DocID FROM @DOCTAB)
			DELETE FROM INV_DocDetails WHERE DocID IN (SELECT DocID FROM @DOCTAB)

			DELETE FROM COM_DocID WHERE ID IN (SELECT DocID FROM @DOCTAB)
			DELETE FROM REN_CollectionHistory WHERE DocID IN (SELECT DocID FROM @DOCTAB) AND ContractCCID=@CostCenterID
			DELETE FROM REN_ContractDocMapping WHERE ContractID IN (SELECT NodeID FROM @DATATAB) AND ContractCCID=@CostCenterID
			
			DELETE FROM CRM_ACTIVITIES WHERE CostCenterID=@CostCenterID AND NodeID IN (SELECT NodeID FROM @DATATAB)
			DELETE FROM COM_Files WHERE FeatureID=@CostCenterID AND FeaturePK IN (SELECT NodeID FROM @DATATAB)
			DELETE FROM COM_Notes WHERE FeatureID=@CostCenterID AND FeaturePK IN (SELECT NodeID FROM @DATATAB)
			
			DELETE FROM COM_DocBridge WHERE CostCenterID=@CostCenterID AND NodeID IN (SELECT NodeID FROM @DATATAB)
			DELETE FROM COM_CCCCDATA WHERE CostCenterID=@CostCenterID AND NodeID IN (SELECT NodeID FROM @DATATAB)
			
			IF @CostCenterID=95 OR @CostCenterID=104
			BEGIN
				DELETE FROM REN_TerminationParticulars WHERE ContractID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_ContractParticulars_History WHERE ContractID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_ContractPayTerms_History WHERE ContractID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_ContractExtended_History WHERE NodeID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_Contract_History WHERE ContractID IN (SELECT NodeID FROM @DATATAB)
				
				DELETE FROM REN_ContractParticularsDetail WHERE ContractID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_ContractParticulars WHERE ContractID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_ContractPayTerms WHERE ContractID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_ContractExtended WHERE NodeID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_Contract WHERE ContractID IN (SELECT NodeID FROM @DATATAB)
			END
			ELSE IF @CostCenterID=103 OR @CostCenterID=129
			BEGIN
				DELETE FROM REN_QuotationParticulars WHERE QuotationID IN (SELECT NodeID FROM @DATATAB) 
				DELETE FROM REN_QuotationPayTerms WHERE QuotationID IN (SELECT NodeID FROM @DATATAB) 
				DELETE FROM REN_QuotationExtended WHERE QuotationID IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_Quotation WHERE QuotationID IN (SELECT NodeID FROM @DATATAB)
			END
		END
		ELSE IF (@CostCenterID=92 OR @CostCenterID=93 OR @CostCenterID=94)
		BEGIN
			DELETE FROM @DATATAB
			
			IF (@CostCenterID=92)
			BEGIN
				INSERT INTO @DATATAB
				SELECT DISTINCT PropertyID FROM REN_Contract WITH(NOLOCK) WHERE PropertyID IS NOT NULL
				UNION
				SELECT DISTINCT PropertyID FROM REN_Quotation WITH(NOLOCK) WHERE PropertyID IS NOT NULL
				UNION
				SELECT DISTINCT PropertyID FROM REN_Units WITH(NOLOCK) WHERE PropertyID IS NOT NULL
			END
			ELSE IF (@CostCenterID=93)
			BEGIN
				INSERT INTO @DATATAB
				SELECT DISTINCT UnitID FROM REN_Contract WITH(NOLOCK) WHERE UnitID IS NOT NULL
				UNION
				SELECT DISTINCT UnitID FROM REN_Quotation WITH(NOLOCK) WHERE UnitID IS NOT NULL
			END
			ELSE IF (@CostCenterID=94)
			BEGIN
				INSERT INTO @DATATAB
				SELECT DISTINCT TenantID FROM REN_Contract WITH(NOLOCK) WHERE TenantID IS NOT NULL
				UNION
				SELECT DISTINCT TenantID FROM REN_Quotation WITH(NOLOCK) WHERE TenantID IS NOT NULL
				UNION
				SELECT DISTINCT TenantID FROM REN_Units WITH(NOLOCK) WHERE TenantID IS NOT NULL
				
				DELETE FROM CRM_ACTIVITIES WHERE CostCenterID=@CostCenterID AND NodeID IN (SELECT NodeID FROM @DATATAB)
			END
			
			DELETE FROM COM_Files WHERE FeatureID=@CostCenterID AND FeaturePK NOT IN (SELECT NodeID FROM @DATATAB)
			DELETE FROM COM_DocBridge WHERE CostCenterID=@CostCenterID AND NodeID NOT IN (SELECT NodeID FROM @DATATAB)
			DELETE FROM COM_CCCCDATA WHERE CostCenterID=@CostCenterID AND NodeID NOT IN (SELECT NodeID FROM @DATATAB) 
			
			IF (@CostCenterID=92)
			BEGIN
				DELETE FROM REN_Particulars WHERE PropertyID NOT IN (SELECT NodeID FROM @DATATAB) AND UnitID=0
				DELETE FROM REN_PropertyShareHolder WHERE PropertyID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_PropertyUnits WHERE PropertyID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM ADM_PropertyUserRoleMap WHERE PropertyID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_PropertyExtended WHERE NodeID>1 AND NodeID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_Property WHERE NodeID>1 AND NodeID NOT IN (SELECT NodeID FROM @DATATAB)
			END
			ELSE IF (@CostCenterID=93)
			BEGIN
				DELETE FROM REN_UnitsExtendedHistory WHERE UnitID>1 AND UnitID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_UnitsHistory WHERE UnitID>1 AND UnitID NOT IN (SELECT NodeID FROM @DATATAB)
				
				DELETE FROM REN_Particulars WHERE UnitID NOT IN (SELECT NodeID FROM @DATATAB) AND UnitID<>0
				DELETE FROM Ren_UnitRate WHERE UnitID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_UnitsExtended WHERE UnitID>1 AND UnitID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_Units WHERE UnitID>1 AND UnitID NOT IN (SELECT NodeID FROM @DATATAB)
			END
			ELSE IF (@CostCenterID=94)
			BEGIN
				DELETE FROM REN_TenantHistory WHERE TenantID>1 AND TenantID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_TenantExtendedHistory WHERE TenantID>1 AND TenantID NOT IN (SELECT NodeID FROM @DATATAB)
				
				DELETE FROM REN_TenantExtended WHERE TenantID>1 AND TenantID NOT IN (SELECT NodeID FROM @DATATAB)
				DELETE FROM REN_Tenant WHERE TenantID>1 AND TenantID NOT IN (SELECT NodeID FROM @DATATAB)
			END
		END
		
		SELECT @PrefValue=Value FROM COM_CostCenterPreferences WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID AND Name='LinkDocument'
		
		if(@PrefValue is not null and @PrefValue<>'')      
		begin       
			begin try      
				select @Dimesion=convert(INT,@PrefValue)      
			end try      
			begin catch      
				set @Dimesion=0      
			end catch      
			if(@Dimesion>0)      
			begin
				SET @IsExists=0
				TRUNCATE TABLE #NodeTAB
				IF (@CostCenterID=92 AND EXISTS (SELECT CCNodeID FROM REN_Property WITH(NOLOCK) WHERE NodeID>1 AND CCNodeID IS NOT NULL AND CCNodeID>0 AND CCID=@Dimesion))
				BEGIN
					SET @IsExists=1
					SELECT @PrefValue='INSERT INTO #NodeTAB
					SELECT CC.NodeID FROM '+TableName+' CC WITH(NOLOCK) 
					LEFT JOIN REN_Property R WITH(NOLOCK) ON R.CCNodeID=CC.NodeID 
					WHERE CC.NodeID>2 AND R.NodeID IS NULL'
					FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@Dimesion
					exec sp_executesql @PrefValue
				END
				ELSE IF (@CostCenterID=93 AND EXISTS (SELECT CCNodeID FROM REN_Units WITH(NOLOCK) WHERE UnitID>1 AND CCNodeID IS NOT NULL AND CCNodeID>0 AND LinkCCID=@Dimesion))
				BEGIN
					SET @IsExists=1
					SELECT @PrefValue='INSERT INTO #NodeTAB
					SELECT CC.NodeID FROM '+TableName+' CC WITH(NOLOCK) 
					LEFT JOIN REN_Units R WITH(NOLOCK) ON R.CCNodeID=CC.NodeID 
					WHERE CC.NodeID>2 AND R.UnitID IS NULL'
					FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@Dimesion
					exec sp_executesql @PrefValue
				END
				ELSE IF (@CostCenterID=94 AND EXISTS (SELECT CCNodeID FROM REN_Tenant WITH(NOLOCK)  WHERE TenantID>1 AND CCNodeID IS NOT NULL AND CCNodeID>0 AND CCID=@Dimesion))
				BEGIN
					SET @IsExists=1
					SELECT @PrefValue='INSERT INTO #NodeTAB
					SELECT CC.NodeID FROM '+TableName+' CC WITH(NOLOCK) 
					LEFT JOIN REN_Tenant R WITH(NOLOCK) ON R.CCNodeID=CC.NodeID 
					WHERE CC.NodeID>2 AND R.TenantID IS NULL'
					FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@Dimesion
					exec sp_executesql @PrefValue
				END

				
				IF (@IsExists=0) 
				BEGIN
					EXEC spCOM_DeleteDimensionData 
							@DimensionsList=@Dimesion,
							@IsNode =False, 
							@UserID =1,
							@RoleID =1,
							@LangID =1
				END
				ELSE
				BEGIN
					SELECT @ICNT=1,@TCNT=COUNT(*) FROM #NodeTAB
					WHILE @ICNT<=@TCNT
					BEGIN
						SELECT @NID=NodeID FROM #NodeTAB WHERE ID=@ICNT
						
						EXEC [dbo].[spCOM_DeleteCostCenter]
								@CostCenterID = @Dimesion,
								@NodeID = @NID,
								@RoleID= 1,
								@UserID = 1,
								@LangID = 1,
								@CheckLink = 1
						SET @ICNT=@ICNT+1	
					END 
				END
			end
		end

		SET @I=@I+1
	END
	
	DROP TABLE #NodeTAB
	
	
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
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


--EXEC spREN_DeleteData 94
GO
