USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_SetPayrollCutomization]
	@GradeID [int],
	@PayrollDate [datetime],
	@XML [nvarchar](max) = null,
	@PTXML [nvarchar](max) = null,
	@sDBAlter [nvarchar](max) = null,
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@UserName [nvarchar](50),
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  

	DECLARE @Dt float,@TempGuid nvarchar(50),@HasAccess bit,@CostCenterID int=50054
	DECLARE @DATAXML XML,@CUSERNAME nvarchar(50),@CDATE FLOAT,@Audit NVARCHAR(100),@HistoryStatus NVARCHAR(300)
	
	SET @CUSERNAME=@UserName
	SET @CDATE=CONVERT(FLOAT,GETDATE())

	SELECT @Audit=ISNULL(Value,'False') FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='AllowAuditTrailinCustomizePayroll'

	IF (@XML IS NOT NULL AND @XML <> '')  
	BEGIN
		SET @DATAXML=@XML
		
		IF EXISTS (SELECT * FROM [COM_CC50054] with(nolock) WHERE [GradeID]=@GradeID AND [PayrollDate]=convert(float,convert(datetime,@PayrollDate)))
		BEGIN
			set @HistoryStatus='Update' 
		
			SELECT @CUSERNAME=MAX([CreatedBy]),@CDATE=MAX([CreatedDate]) FROM [COM_CC50054] WITH(NOLOCK)
			WHERE [GradeID]=@GradeID AND [PayrollDate]=@PayrollDate
			
			DELETE FROM [COM_CC50054] WHERE [GradeID]=@GradeID AND [PayrollDate]=@PayrollDate
			DELETE FROM [PAY_PayrollPT] WHERE [PayrollDate]=@PayrollDate
		END
		ELSE
		BEGIN
			set @HistoryStatus='Add'

			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,1)
			IF @HasAccess=0  
			BEGIN  
				RAISERROR('-105',16,1)  
			END
		END
		
		INSERT INTO [COM_CC50054]
		   ([GradeID]
		   ,[PayrollDate]
		   ,[Type]
		   ,[SNo]
		   ,[ComponentID]
		   ,[Formula]
		   ,[AddToNet]
		   ,[ShowInDuesEntry]
		   ,[CalculateArrears]
		   ,[CalculateAdjustments]
		   ,[FieldType]
		   ,[Applicable]
		   ,[Behaviour]
		   ,[MaxOTHrs]
		   ,[ROff]
		   ,[TaxMap]
		   ,[Expression]
		   ,[Message]
		   ,[Action]
		   ,[DrAccount]
		   ,[CrAccount]
		   ,[Percentage]
		   ,[MaxLeaves]
		   ,[AtATime]
		   ,[CarryForward]
		   ,[IncludeRExclude]
		   ,[MaxCarryForwardDays]
		   ,[MaxEncashDays]
		   ,[EncashFormula]
		   ,[LeaveErrorMessage]
		   ,LEThresholdLimit,LEDaysField,LEAmountField,LeaveOthFeatures
		   ,[ShowInESS]
		   ,[AccrualInProbation]
		   ,[AvailInProbation]
		   ,[IsCalculate]
		   ,[CarryForwardExpireDays]
		   ,[CompanyGUID]
		   ,[GUID]
		   ,[Description]
		   ,[CreatedBy]
		   ,[CreatedDate]
		   ,[ModifiedBy]
		   ,[ModifiedDate])
		SELECT @GradeID
		   ,CONVERT(FLOAT,@PayrollDate)
		   ,X.value('@Type','INT')
		   ,X.value('@SNo','INT')
		   ,X.value('@ComponentID','INT')
		   ,X.value('@Formula','NVARCHAR(MAX)')
		   ,X.value('@AddToNet','NVARCHAR(50)')
		   ,ISNULL(X.value('@ShowInDuesEntry','NVARCHAR(50)'),'Yes')
		   ,ISNULL(X.value('@CalculateArrears','NVARCHAR(50)'),'Yes')
		   ,ISNULL(X.value('@CalculateAdjustments','NVARCHAR(50)'),'Yes')
		   ,X.value('@FieldType','NVARCHAR(50)')
		   ,X.value('@Applicable','NVARCHAR(10)')
		   ,X.value('@Behaviour','NVARCHAR(50)')
		   ,X.value('@MaxOTHrs','FLOAT')
		   ,X.value('@ROff','FLOAT')
		   ,X.value('@TaxMap','INT')
		   ,X.value('@Expression','NVARCHAR(500)')
		   ,X.value('@Message','NVARCHAR(500)')
		   ,X.value('@Action','INT')
		   ,isnull(X.value('@DrAccount','INT'),0)
		   ,isnull(X.value('@CrAccount','INT'),0)
		   ,X.value('@Percentage','FLOAT')
		   ,X.value('@MaxLeaves','FLOAT')
		   ,X.value('@AtATime','FLOAT')
		   ,X.value('@CarryForward','NVARCHAR(50)')
		   ,X.value('@IncludeRExclude','NVARCHAR(50)')
		   ,isnull(X.value('@MaxCarryForwardDays','FLOAT'),0)
		   ,isnull(X.value('@MaxEncashDays','FLOAT'),0)
		   ,X.value('@EncashFormula','NVARCHAR(MAX)')
		   ,X.value('@LeaveErrorMessage','NVARCHAR(500)')
		   ,X.value('@LEThresholdLimit','FLOAT'),X.value('@LEDaysField','INT'),X.value('@LEAmountField','INT'),X.value('@LeaveOthFeatures','NVARCHAR(MAX)')
		   ,ISNULL(X.value('@ShowInESS','NVARCHAR(50)'),'Yes')
		   ,ISNULL(X.value('@AccrualInProbation','NVARCHAR(50)'),'Yes')
		   ,ISNULL(X.value('@AvailInProbation','NVARCHAR(50)'),'Yes')
		   ,ISNULL(X.value('@IsCalculate','NVARCHAR(50)'),'Yes')
		   ,isnull(X.value('@CarryForwardExpireDays','FLOAT'),0)
		   ,@CompanyGUID
		   ,@GUID
		   ,NULL
		   ,@CUSERNAME
		   ,@CDATE
		   ,@UserName     
		   ,CONVERT(FLOAT,GETDATE()) 
		FROM @DATAXML.nodes('/Xml/Row') as Data(X)
		
		IF (@PTXML IS NOT NULL AND @PTXML <> '')  
		BEGIN
			SET @DATAXML=@PTXML
			DECLARE @PayrollPTDimension INT
			SELECT @PayrollPTDimension=VALUE FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='PayrollPTDimension'
			INSERT INTO [PAY_PayrollPT]
			   ([PayrollDate]
			   ,[CostCenterID]
			   ,[NodeID]
			   ,[FromSlab]
			   ,[ToSlab]
			   ,[Amount]
			   ,[Formula]
			   ,[CreatedBy]
			   ,[CreatedDate]
			   ,[ModifiedBy]
			   ,[ModifiedDate])
			SELECT CONVERT(FLOAT,@PayrollDate)
				,@PayrollPTDimension
				,X.value('@NodeID','INT')
				,X.value('@FromSlab','FLOAT')
				,X.value('@ToSlab','FLOAT')
				,X.value('@Amount','FLOAT')
				,X.value('@Formula','NVARCHAR(MAX)')
				,@CUSERNAME
				,@CDATE
				,@UserName     
				,CONVERT(FLOAT,GETDATE()) 
			FROM @DATAXML.nodes('/Xml/Row') as Data(X)
		END
		--select @HistoryStatus
		--INSERT INTO HISTROY
		IF(@Audit IS NOT NULL AND @Audit='True')
		BEGIN    
			insert into [COM_CC50054_History]         
			select 50054,@HistoryStatus,* FROM COM_CC50054 WITH(NOLOCK) WHERE [GradeID]=@GradeID AND [PayrollDate]=@PayrollDate
		END
		--END INTO HISTROY
		
		IF (@sDBAlter IS NOT NULL AND @sDBAlter <> '' AND LEN(@sDBAlter)>0)  
		BEGIN
			EXEC sp_executesql @sDBAlter
		END
		
	END

	
	--ADDING NUMERIC DATA COLUMNS
		EXEC spPay_SetDocumentFields 1,@GradeID,@UserID,@LangID

		---- UPDATING RESOURCES DATA FOR REPORTING
	
		EXEC [spPAY_UpdatePayCompRptFields]
	
	---- END :: UPDATING RESOURCES DATA FOR REPORTING
		
COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @GradeID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN   
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
