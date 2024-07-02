USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenterExtraFields]
	@CostCenterId [int],
	@NoOfFields [int] = 10,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON   
		--Declaration Section  
		DECLARE @SQL NVARCHAR(MAX),@HasAccess BIT,@Table NVARCHAR(50),@CreatedDt FLOAT  
		DECLARE @StPos INT,@I INT,@CostCenterName NVARCHAR(50),@ResourceID bigint
		DECLARE @ColName NVARCHAR(50),@ExtraColName NVARCHAR(50)

		--SP Required Parameters Check  
		IF  @CompanyGUID IS NULL OR @CompanyGUID=''  
		BEGIN  
			RAISERROR('-100',16,1)  
		END  

		--User acces check    
		SET @HasAccess=0   
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,8,1)  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  

		SET @CreatedDt=CONVERT(FLOAT,GETDATE())    

		--Set table name
		IF @CostCenterId=3
		BEGIN
			SET @Table='INV_ProductExtended'  
			SET @ExtraColName='ptAlpha'
		END
		ELSE IF @CostCenterId=2
		BEGIN
			SET @Table='ACC_AccountsExtended'  
			SET @ExtraColName='acAlpha'
		END
		ELSE
		BEGIN
			SET @Table=(SELECT Top 1 SysTableName FROM ADM_CostCenterDef WITH(nolock) WHERE CostCenterID=@CostCenterId)  
			SET @ExtraColName='ccAlpha'
		END
		SELECT Top 1 @CostCenterName=CostCenterName FROM ADM_CostCenterDef WITH(nolock) 
		WHERE CostCenterID=@CostCenterId 


		SELECT @StPos=isnull(max(convert(int,substring(name,8,len(name)-7))),0)+1 FROM sys.columns
		WHERE object_id in (SELECT object_id FROM sys.objects WHERE type='U' AND name=@Table)
		AND Name like @ExtraColName+'%'

		SELECT @I=0

		SET @SQL=''
		
		WHILE(@I<@NoOfFields)
		BEGIN
			IF len(@SQL)>0
				SET @SQL=@SQL+','
			
			SET @ColName=@ExtraColName+convert(nvarchar,(@StPos+@I))
			SET @SQL=@SQL+@ColName+' nvarchar(max)'

			SELECT @ResourceID=max(ResourceID)+1 FROM COM_LanguageResources WITH(nolock)

			INSERT INTO COM_LanguageResources(ResourceID,ResourceName,LanguageID,LanguageName,ResourceData,GUID,CreatedBy,CreatedDate)
			SELECT @ResourceID,@ColName,LanguageID,Name,@ColName,NEWID(),@UserName,@CreatedDt
			FROM ADM_Laguages WITH(nolock)

			--SET @ResourceID=SCOPE_IDENTITY()

			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,ResourceID,SysTableName,
					UserColumnName,SysColumnName,UserColumnType,ColumnOrder,
					IsMandatory,IsEditable,IsVisible,
					IsCostCenterUserDefined,IsColumnUserDefined,IsColumnInUse,
					CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@ResourceID,@Table,
					@ColName,@ColName,'TEXT',0,
					0,1,0,
					0,1,0,
					@CompanyGUID,NEWID(),@UserName,@CreatedDt)    
	
			SET @I=@I+1
		END
		
		IF @CostCenterId=2 OR @CostCenterId=3
		BEGIN
			SET @SQL='ALTER TABLE '+ @Table + ' ADD ' + @SQL +' ALTER TABLE '+ @Table + 'History ADD ' + @SQL
		END
		ELSE
		BEGIN
			SET @SQL='ALTER TABLE '+ @Table + ' ADD ' + @SQL
		END
		
		EXEC(@SQL)

COMMIT TRANSACTION 
SET NOCOUNT OFF;  
RETURN 1 
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
