﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetUOM]
	@BASENAME [nvarchar](300),
	@BASEID [bigint],
	@UOMXML [nvarchar](max),
	@IsImport [bit],
	@COMPANYGUID [nvarchar](50),
	@USERNAME [nvarchar](50),
	@RoleID [int],
	@LANGID [int],
	@PRODUCTID [bigint] = 0,
	@ISPRODUCTWISE [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  	
		DECLARE @UOMID BIGINT,@DATA XML,@I INT,@COUNT INT,@UNITID INT,@UNAME NVARCHAR(300),@CONVERSIONRATE FLOAT, @RowCount int, @MapAction NVARCHAR(20)
		SET @DATA=@UOMXML
		DECLARE @HasAccess BIT,@DuplicateBaseID BIGINT

		DECLARE @TEMP TABLE (ID INT IDENTITY(1,1),uomid bigint,UNAME NVARCHAR(300),CONVERSIONRATE FLOAT,PRIMARYKEY INT,MAPACTION NVARCHAR(300))
		
	 	--User access check 
	 	IF (@BASEID=-100 OR @BASEID=0)
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,11,1)
		ELSE
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,11,3)
			
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		 
		--IF BASEID IS ZERO THEN INSERT BASENAME 
		SET @DuplicateBaseID=0
		SELECT @DuplicateBaseID	= BASEID FROM [COM_UOM] WITH(NOLOCK) WHERE IsProductWise=0 and BASENAME=@BASENAME and  BASEID != @BASEID
		 
		IF (@DuplicateBaseID >1  )
		BEGIN						 
			RAISERROR('-120',16,1)
		END
		ELSE
		BEGIN

			IF (@BASEID=-100 OR @BASEID=0) and (@IsImport=0)
			BEGIN 
				SELECT @BASEID=ISNULL(MAX(BASEID),0)+1 FROM [COM_UOM] WITH(NOLOCK)
				
				INSERT INTO [COM_UOM] (BASEID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
				VALUES (@BASEID,@BASENAME,1,@BASENAME,1,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@PRODUCTID,@ISPRODUCTWISE) 
			END
			ELSE if (@IsImport=0)
			BEGIN
				UPDATE [COM_UOM] SET BASENAME=@BASENAME,UNITNAME=@BASENAME WHERE BASEID=@BASEID AND UNITID=1
			END
		END
		 
		--INSERT INTO TEMPORAY TABLE
		INSERT INTO @TEMP (UOMID,UNAME,CONVERSIONRATE,PRIMARYKEY,MAPACTION)
		SELECT A.value('@PrimaryKey','BIGINT'),A.value('@UName','nvarchar(300)'),A.value('@ConversionRate','float'),A.value('@PrimaryKey','nvarchar(300)'),A.value('@MapAction','nvarchar(300)')
		FROM @DATA.nodes('/XML/Row') AS DATA(A) 
		
		IF EXISTS (SELECT * FROM INV_DocDetails IDD WITH(NOLOCK)
				JOIN @TEMP TU ON TU.UOMID=IDD.Unit AND TU.CONVERSIONRATE<>IDD.UOMConversion
				WHERE MAPACTION='UPDATE')
		BEGIN
			RAISERROR('-573',16,1)
		END
		
		IF EXISTS (SELECT * FROM INV_DocDetails IDD WITH(NOLOCK)
				JOIN @TEMP TU ON TU.UOMID=IDD.Unit 
				WHERE MAPACTION='DELETE')
		BEGIN
			RAISERROR('-573',16,1)
		END
	 
		SELECT @I=1,@COUNT=COUNT(*) FROM @TEMP  
		
		--FOR NEW UNITS INSERT THROUGH LOOP BECAUSE FOR EACH ROW WE NEED MAX(UNIT) TO INSERT
		WHILE @I<=@COUNT
		BEGIN

			SELECT @UOMID=UOMID,@UNAME=UNAME,@CONVERSIONRATE=CONVERSIONRATE,@MAPACTION=MAPACTION FROM @TEMP WHERE ID=@I 
			if(@MAPACTION=LTRIM(RTRIM('NEW')))
			begin
				If exists(SELECT unitname FROM [COM_UOM] WITH(NOLOCK) WHERE IsProductWise=0 and BaseID=@BASEID and Unitname=@UNAME)
				 begin
					RAISERROR('-124',16,1)
				 end
				 --SELECT UNIT ID MAX FROM TABLE 
				SELECT @UNITID=ISNULL(MAX(UNITID),0)+1 FROM [COM_UOM] WITH(NOLOCK)
				
				if (@IsImport=0)				
					INSERT INTO [COM_UOM] (BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
					VALUES (@BASEID,@BASENAME,@UNITID,@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@PRODUCTID,@ISPRODUCTWISE)
				else if (@IsImport=1)
				begin
					if(@BASEID=0)
						SELECT @BASEID=ISNULL(MAX(BASEID),0)+1 FROM [COM_UOM] WITH(NOLOCK)
						
					INSERT INTO [COM_UOM] (BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE)
					VALUES (@BASEID,@UNAME,1,@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()))
				end
				IF @@ERROR<>0 BEGIN ROLLBACK TRANSACTION RETURN -100 END
			end
			else if(@MAPACTION=LTRIM(RTRIM('UPDATE')))
			begin
			
				If exists(SELECT UNITNAME FROM [COM_UOM] WITH(NOLOCK) WHERE IsProductWise=0 and BaseID=@BASEID and UNITNAME=@UNAME and UOMID!=@UOMID)
				begin
					RAISERROR('-124',16,1)
				end
				
				UPDATE [COM_UOM]
				SET  UNITNAME=@UNAME,
				CONVERSION=@CONVERSIONRATE,
				MODIFIEDBY=@USERNAME,ModifiedDate=CONVERT(FLOAT,GETDATE())
				where UOMID=@UOMID
			end
			else if(@MAPACTION=LTRIM(RTRIM('DELETE')))
			begin
				DELETE FROM [COM_UOM]
				WHERE UOMID=@UOMID
			end
			SET @I=@I+1
		END 
		
		--GET MAX OF UOMID TO RETURN
		SELECT @UOMID=MAX(UOMID) FROM [COM_UOM] WITH(NOLOCK)

COMMIT TRANSACTION    
SET NOCOUNT OFF;
	select * from [COM_UOM] WITH(NOLOCK) where BaseID=@BASEID
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
	WHERE ErrorNumber=100 AND LanguageID=@LangID  
	RETURN @UOMID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN		  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	ROLLBACK TRANSACTION
	SET NOCOUNT OFF  
	RETURN -999   
END CATCH 


 

 








 
GO
