USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportProductWithMulitpleUOMBarcode]
	@Product [nvarchar](max),
	@ProductUOM [nvarchar](max) = '',
	@IsUpdate [bit] = 0,
	@IsCode [bit] = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON	
	if @ProductUOM is not null and @ProductUOM<>'' 
	begin
		--Declaration Section
		DECLARE	@failCount int,@NodeID bigint
		
		DECLARE @HasAccess BIT,@Cnt INT,@I INT
		
		--SP Required Parameters Check
		IF @CompanyGUID IS NULL OR @CompanyGUID=''
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		set @failCount=0
		
		if( @IsCode is not null and @IsCode =0)
			set @NodeID= (Select  top 1 ProductID from INV_Product WITH(NOLOCK) where ProductName=@Product) 
		else if(@IsCode is not null and @IsCode=1)	 
			set @NodeID= (Select  top 1 ProductID from INV_Product WITH(NOLOCK) where ProductCode=@Product) 
	
		declare @TblUomBarcodes TABLE(Barcode NVARCHAR(300))
		DECLARE @BARCODE NVARCHAR(100),@BarKey BIGINT, @BarDim int ,@CCStatusID int,@SQL NVARCHAR(MAX)
		DECLARE @UOMDATA XML,@RUOMID INT,@RPRODUCTID INT,@RCOUNT INT,@BASEDATA XML,@BCOUNT INT,@J INT,@BASEID BIGINT,@Conversion FLOAT,
		@UOMID bigint,@BASENAME NVARCHAR(300),@TEMPBASEID BIGINT,@multiBarcodes NVARCHAR(MAX)
		,@UNITID INT,@UNAME NVARCHAR(300),@CONVERSIONRATE FLOAT
		
		SET @UOMDATA=@ProductUOM 
		SET @BASEDATA=@ProductUOM 
		DECLARE @TBLBASE TABLE(ID INT IDENTITY(1,1),BASEID BIGINT,BASENAME NVARCHAR(300),MAPACTION INT,CONVERSION float,BaseBarcode NVARCHAR(100),BaseBarKey BIGINT,MultiBarcode NVARCHAR(max))

		INSERT INTO @TBLBASE (BASENAME,BASEID,MAPACTION,CONVERSION,BaseBarcode,BaseBarKey,MultiBarcode)
		SELECT distinct( X.value('@BaseName','NVARCHAR(50)')), 
		 X.value('@BaseID','int'), X.value('@MapAction','NVARCHAR(50)') , X.value('@Conversion','float') , 
		  X.value('@BaseBarcode','NVARCHAR(100)'),isnull(X.value('@BaseBarKey','bigint'),0)
		  , X.value('@BaseMultiBarcode','NVARCHAR(MAX)')
		FROM @BASEDATA.nodes('/Data/Row') as Data(X)

		DECLARE @TBLUOM TABLE(ID INT IDENTITY(1,1),UNITID BIGINT,UNITNAME NVARCHAR(300),BASEID BIGINT,
		BASENAME NVARCHAR(300),CONVERSIONRATE FLOAT,MAPACTION INT,CONVERSION float,Barcode NVARCHAR(100),BarKey BIGINT,MultiBarcode NVARCHAR(max))

		INSERT INTO @TBLUOM
		SELECT X.value('@UnitiD','int'),X.value('@UnitName','NVARCHAR(50)'),X.value('@BaseID','int'),
		   X.value('@BaseName','NVARCHAR(50)'),X.value('@ConversionUnit','float') ,X.value('@MapAction','INT') 
		   , X.value('@Conversion','float') , X.value('@Barcode','NVARCHAR(100)'),isnull(X.value('@BarKey','bigint'),0), X.value('@MultiBarcode','NVARCHAR(MAX)')
		FROM @UOMDATA.nodes('/Data/Row') as Data(X) 
		WHERE X.value('@UnitName','NVARCHAR(50)') NOT IN ( SELECT BASENAME FROM @TBLBASE)
		
		SELECT * FROM @TBLBASE
		SELECT * FROM @TBLUOM
		
		declare @BARDIMENSION NVARCHAR(100)
		SELECT @BARDIMENSION=Value FROM COM_CostCenterPreferences with(nolock) where Name='BarcodeDimension' 
		if @BARDIMENSION!='' and isnumeric(@BARDIMENSION)=1 and convert(int,@BARDIMENSION)>50000
			set @BarDim=convert(int,@BARDIMENSION)
		else
			set @BarDim=0
				
		IF @IsUpdate=0
		BEGIN
			
			IF((SELECT COUNT(*) FROM [COM_UOM] WITH(NOLOCK) WHERE PRODUCTID=@NodeID)>0)
			BEGIN 
				UPDATE INV_PRODUCT SET UOMID=1 WHERE PRODUCTID=@NodeID 
				DELETE FROM [COM_UOM] WHERE PRODUCTID=@NodeID
			END
			
			SELECT @J=1,@BCOUNT=COUNT(*) FROM @TBLBASE
			WHILE @J<=@BCOUNT
			BEGIN
				SELECT @TEMPBASEID=BASEID,@BASENAME=BASENAME,@Conversion=CONVERSION, @BARCODE=BaseBarcode,@BarKey=BaseBarKey ,@multiBarcodes=MultiBarcode
				FROM @TBLBASE WHERE ID=@J
				
				delete from @TblUomBarcodes
				INSERT INTO @TblUomBarcodes
				EXEC SPSplitString @multiBarcodes,','
				
				IF((SELECT ISNULL(COUNT(*),0) FROM [COM_UOM] WITH(NOLOCK) WHERE BASEID = @TEMPBASEID)=0)
				BEGIN
					SET @BASEID=0
					SELECT @BASEID=ISNULL(MAX(BASEID),0) FROM [COM_UOM] WITH(NOLOCK)
					SET @BASEID=@BASEID+1
					
					INSERT INTO [COM_UOM] (BASEID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
					VALUES(@BASEID,@BASENAME,@Conversion,@BASENAME,@Conversion,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@NodeID,1) 
					
					SET @UOMID=SCOPE_IDENTITY() 
					 
					If exists(select Barcode from INV_ProductBarcode with(nolock) where BARCODE=@BARCODE and @BARCODE is not null and @BARCODE<>'')
						RAISERROR('-130',16,1) 
					
					If exists(select a.Barcode from INV_ProductBarcode a with(nolock)
					join @TblUomBarcodes b on a.BARCODE=b.Barcode)
					begin 
						set @failCount=@failCount+1
						RAISERROR('-130',16,1) 
					END
					
				 	if(@BARCODE is null)
					begin
						set @BARCODE=''
						set @BarKey=0
					end
					else if(@BarDim>0 AND @BARCODE<>'')
					begin
						 
						select @SQL=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@BarDim
						set @SQL='select @NodeID=NodeID from '+@SQL+' WITH(NOLOCK) where Name='''+@BARCODE+''''				
						EXEC sp_executesql @SQL,N'@NodeID bigint OUTPUT',@BarKey output
						
						if(@BarKey is null or (@BarKey<=0 and @BarKey>-10000))
						BEGIN
							select @CCStatusID =  statusid from com_status with(nolock) where costcenterid=@BarDim and status = 'Active'

							EXEC @BarKey = [dbo].[spCOM_SetCostCenter]
							@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
							@Code = @BARCODE,
							@Name = @BARCODE,
							@AliasName='',
							@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
							@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
							@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
							@CostCenterID = @BarDim,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=@UserID,
							@CodePrefix='',@CodeNumber=0,
							@CheckLink = 0,@IsOffline=0

						END
					end
					insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
					VALUES (@BARCODE,@BarKey,0,@UOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE()))
					
					insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
					select Barcode,0,0,@UOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE())
					from @TblUomBarcodes
				END		
				ELSE
				BEGIN
					UPDATE [COM_UOM] SET BASENAME=@BASENAME,UNITNAME=@BASENAME WHERE BASEID=@TEMPBASEID AND UNITID=1		
					SET @BASEID=@TEMPBASEID
				END
				
				SELECT @I=1,@RCOUNT=COUNT(*) FROM @TBLUOM
				WHILE @I<=@RCOUNT
				BEGIN 
					SELECT @RUOMID=UNITID,@UNAME=UNITNAME,@CONVERSIONRATE=CONVERSIONRATE,@BARCODE=Barcode ,@BarKey=BarKey ,@multiBarcodes=MultiBarcode
					FROM @TBLUOM WHERE ID=@I 
					
					delete from @TblUomBarcodes
					INSERT INTO @TblUomBarcodes
					EXEC SPSplitString @multiBarcodes,','
					
					If exists(select unitname from Com_uom WITH(NOLOCK) where BaseID=@BASEID and Unitname=@UNAME AND UnitID>1)
					begin
						RAISERROR('-124',16,1)
					end 
					
					--SELECT UNIT ID MAX FROM TABLE 
					SELECT @UNITID=ISNULL(MAX(UNITID),0) FROM [COM_UOM] WITH(NOLOCK)
					
					INSERT INTO [COM_UOM] (BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
					VALUES(@BASEID,@BASENAME,@UNITID+1,@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@NodeID,1)
					
					SET @RUOMID=SCOPE_IDENTITY()	
				
					If exists(select Barcode from INV_ProductBarcode with(nolock) where BARCODE=@BARCODE and @BARCODE is not null and @BARCODE<>'')
					begin 
						set @failCount=@failCount+1
						RAISERROR('-130',16,1)
					end	
					
					If exists(select a.Barcode from INV_ProductBarcode a with(nolock)
					join @TblUomBarcodes b on a.BARCODE=b.Barcode)
					begin 
						set @failCount=@failCount+1
						RAISERROR('-130',16,1) 
					END
					
					if(@BARCODE is null)
					begin
						set @BARCODE=''
						set @BarKey=0
					end
					else if(@BarDim>0 AND @BARCODE<>'')
					begin
						 
						select @SQL=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@BarDim
						set @SQL='select @NodeID=NodeID from '+@SQL+' WITH(NOLOCK) where Name='''+@BARCODE+''''				
						EXEC sp_executesql @SQL,N'@NodeID bigint OUTPUT',@BarKey output
						
						if(@BarKey is null or (@BarKey<=0 and @BarKey>-10000))
						BEGIN
							select @CCStatusID =  statusid from com_status with(nolock) where costcenterid=@BarDim and status = 'Active'

							EXEC @BarKey = [dbo].[spCOM_SetCostCenter]
							@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
							@Code = @BARCODE,
							@Name = @BARCODE,
							@AliasName='',
							@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
							@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
							@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
							@CostCenterID = @BarDim,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=@UserID,
							@CodePrefix='',@CodeNumber=0,
							@CheckLink = 0,@IsOffline=0

						END
					end

			 		insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
					VALUES (@BARCODE,@BarKey,0,@RUOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE()))
					
					insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
					select Barcode,0,0,@RUOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE())
					from @TblUomBarcodes
					
					SET @I=@I+1
				END
				SET @TEMPBASEID=0
				SET @J=@J+1
			END
			update inv_product set UOMID=@UOMID where ProductID=@NodeID
		END
		ELSE
		BEGIN
			
			SELECT @J=1,@BCOUNT=COUNT(*) FROM @TBLBASE
			WHILE @J<=@BCOUNT
			BEGIN
				SELECT @BASENAME=BASENAME,@Conversion=CONVERSION,@BARCODE=BaseBarcode,@BarKey=BaseBarKey 
				FROM @TBLBASE WHERE ID=@J
				
				SET @UOMID=0 SET @BASEID=0
				
				SELECT @UOMID=ISNULL(UOMID,0),@BASEID=ISNULL(BASEID,0) FROM [COM_UOM] WITH(NOLOCK) WHERE BASENAME=@BASENAME AND UNITNAME=@BASENAME AND productID=@NodeID
				
				IF @UOMID=0
				BEGIN
					SELECT @BASEID=ISNULL(MAX(BASEID),0)+1 FROM [COM_UOM] WITH(NOLOCK)
					
					INSERT INTO [COM_UOM] (BASEID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
					VALUES(@BASEID,@BASENAME,@Conversion,@BASENAME,@Conversion,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@NodeID,1) 
					
					SET @UOMID=SCOPE_IDENTITY() 
				END	
				 
				If exists(select a.Barcode from INV_ProductBarcode a with(nolock)
				join @TblUomBarcodes b on a.BARCODE=b.Barcode
				 where UNITID<>@UOMID)
				begin 
					set @failCount=@failCount+1
					RAISERROR('-130',16,1) 
				END
				
				
				If exists(select Barcode from INV_ProductBarcode with(nolock) where UNITID<>@UOMID and BARCODE=@BARCODE and @BARCODE is not null and @BARCODE<>'')
				begin 
					set @failCount=@failCount+1
					RAISERROR('-130',16,1) 
				END
				ELSE
				BEGIN	
					if(@BARCODE is null)
					begin
						set @BARCODE=''
						set @BarKey=0
					end
					else if(@BarDim>0 AND @BARCODE<>'')
					begin
						 
						select @SQL=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@BarDim
						set @SQL='select @NodeID=NodeID from '+@SQL+' WITH(NOLOCK) where Name='''+@BARCODE+''''				
						EXEC sp_executesql @SQL,N'@NodeID bigint OUTPUT',@BarKey output
						
						if(@BarKey is null or (@BarKey<=0 and @BarKey>-10000))
						BEGIN
							select @CCStatusID =  statusid from com_status with(nolock) where costcenterid=@BarDim and status = 'Active'

							EXEC @BarKey = [dbo].[spCOM_SetCostCenter]
							@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
							@Code = @BARCODE,
							@Name = @BARCODE,
							@AliasName='',
							@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
							@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
							@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
							@CostCenterID = @BarDim,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=@UserID,
							@CodePrefix='',@CodeNumber=0,
							@CheckLink = 0,@IsOffline=0

						END
					end

				 	
				 	IF EXISTS(select Barcode from INV_ProductBarcode with(nolock) where unitID=@UOMID AND productID=@NodeID)
				 	BEGIN
				 		delete from INV_ProductBarcode
		 				where unitID=@UOMID and productID=@NodeID
		 				
		 				insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
						VALUES (@BARCODE,@BarKey,0,@UOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE()))
						
						insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
						select Barcode,0,0,@UOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE())
						from @TblUomBarcodes
				 	END
				 	ELSE
				 	BEGIN
						insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
						VALUES (@BARCODE,@BarKey,0,@UOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE()))
						
						insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
						select Barcode,0,0,@UOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE())
						from @TblUomBarcodes
					END
				END
					
				
				SELECT @I=1,@RCOUNT=COUNT(*) FROM @TBLUOM
				WHILE @I<=@RCOUNT
				BEGIN 
					SELECT @RUOMID=0,@UNAME=UNITNAME,@CONVERSIONRATE=CONVERSIONRATE,@BARCODE=Barcode ,@BarKey=BarKey FROM @TBLUOM WHERE ID=@I 
					
					SELECT @RUOMID=ISNULL(UOMID,0) FROM [COM_UOM] WITH(NOLOCK) 
					WHERE BaseID=@BASEID and Unitname=@UNAME AND UnitID>1 AND productID=@NodeID 
					
					If @RUOMID is null or @RUOMID=0
					begin
						--SELECT UNIT ID MAX FROM TABLE 
						SELECT @UNITID=ISNULL(MAX(UNITID),0)+1 FROM [COM_UOM] WITH(NOLOCK)
						
						INSERT INTO [COM_UOM] (BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
						VALUES(@BASEID,@BASENAME,@UNITID,@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@NodeID,1)
						
						SET @RUOMID=SCOPE_IDENTITY()	
					end
					
					If exists(select Barcode from INV_ProductBarcode with(nolock) where UNITID<>@RUOMID and  BARCODE=@BARCODE and @BARCODE is not null and @BARCODE<>'')
					begin 
						set @failCount=@failCount+1
						RAISERROR('-130',16,1)
					end	
					ELSE
					BEGIN
						if(@BARCODE is null)
						begin
							set @BARCODE=''
							set @BarKey=0
						end
						else if(@BarDim>0 AND @BARCODE<>'')
						begin
						 
							select @SQL=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@BarDim
							set @SQL='select @NodeID=NodeID from '+@SQL+' WITH(NOLOCK) where Name='''+@BARCODE+''''				
							EXEC sp_executesql @SQL,N'@NodeID bigint OUTPUT',@BarKey output
						
							if(@BarKey is null or (@BarKey<=0 and @BarKey>-10000))
							BEGIN
								select @CCStatusID =  statusid from com_status with(nolock) where costcenterid=@BarDim and status = 'Active'

								EXEC @BarKey = [dbo].[spCOM_SetCostCenter]
								@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
								@Code = @BARCODE,
								@Name = @BARCODE,
								@AliasName='',
								@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
								@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
								@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
								@CostCenterID = @BarDim,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=@UserID,
								@CodePrefix='',@CodeNumber=0,
								@CheckLink = 0,@IsOffline=0

							END
						end
						IF EXISTS(select Barcode from INV_ProductBarcode with(nolock) where unitID=@RUOMID AND productID=@NodeID)
				 		BEGIN
		 					UPDATE INV_ProductBarcode SET Barcode=@BARCODE,Barcode_Key=@BarKey,MODIFIEDBY=@USERNAME,MODIFIEDDATE=CONVERT(FLOAT,GETDATE())
		 					WHERE unitID=@RUOMID AND productID=@NodeID
		 				END
		 				ELSE
		 				BEGIN
		 					insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
							VALUES (@BARCODE,@BarKey,0,@RUOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE()))
		 				END
					END
					
					SET @I=@I+1
				END
				SET @TEMPBASEID=0
				SET @J=@J+1
			END
		END
	end
		
COMMIT TRANSACTION  

SET NOCOUNT OFF;   
RETURN @failCount  
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
