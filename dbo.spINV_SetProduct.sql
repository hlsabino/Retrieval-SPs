USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetProduct]
	@ProductID [int],
	@ProductCode [nvarchar](200) = NULL,
	@ProductName [nvarchar](max),
	@AliasName [nvarchar](max),
	@ProductTypeID [int],
	@StatusID [int],
	@UOMID [int] = NULL,
	@BarcodeID [nvarchar](50) = NULL,
	@Description [nvarchar](max),
	@SelectedNodeID [int],
	@IsGroup [bit],
	@CustomFieldsQuery [nvarchar](max) = NULL,
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@ContactsXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@SubstitutesXML [nvarchar](max) = null,
	@VendorsXML [nvarchar](max) = null,
	@SerializationXML [nvarchar](max) = null,
	@KitXML [nvarchar](max) = null,
	@LinkedProductsXML [nvarchar](max) = null,
	@ProdSpecs [nvarchar](max) = null,
	@MatrixSeqno [int] = NULL,
	@AttributesXML [nvarchar](max) = null,
	@AttributesData [nvarchar](max) = null,
	@AttributesColumnsData [nvarchar](max) = null,
	@HasSubItem [bit] = null,
	@ItemProductData [nvarchar](max) = null,
	@AssignCCCCData [nvarchar](max) = null,
	@BinXML [nvarchar](max) = null,
	@ProductWiseUOMData [nvarchar](max) = null,
	@ProductWiseUOMData1 [nvarchar](max) = null,
	@CodePrefix [nvarchar](50) = NULL,
	@CodeNumber [int] = 0,
	@IsOffline [bit] = 0,
	@ProductStaticFieldsQuery [nvarchar](max) = NULL,
	@TestcasesXML [nvarchar](max) = NULL,
	@HistoryXML [nvarchar](max) = null,
	@StatusXML [nvarchar](max) = null,
	@IsLink [bit] = 1,
	@CompanyGUID [nvarchar](50) = null,
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@WID [int] = 0,
	@RoleID [int] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
	SET NOCOUNT ON;
	--Declaration Section 
	DECLARE @Dt FLOAT ,@HasAccess bit,@IsDuplicateNameAllowed bit,@IsDuplicateCodeAllowed BIT,@BarcodID INT,
	@MaintainUniqueProductDescription bit,@ProductCodeLength INT,@IsMultipleProductinSameBin bit
	declare @ProductCodeIgnoreText nvarchar(50),@IsProductLinkDimension bit,@multiBarcodes NVARCHAR(MAX) 
	DECLARE @UpdateSql NVARCHAR(MAX),@XML XML,@TempGuid NVARCHAR(50),@CCCCCData XML
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth INT,@ParentID INT 
	DECLARE @SelectedIsGroup BIT, @ParentCode NVARCHAR(MAX), @VCOUNT int
	DECLARE @TblSubstitue TABLE(ID int identity(1,1),GroupID INT,GroupName nvarchar(50), SProductID INT)
	DECLARE @I int,@Cnt int,@SubGroupID INT,@SubGroupName nvarchar(50),@SubItemID INT, @SProductID INT
	DECLARE @ActionType INT
	declare @isparentcode bit,@DimensionPrefValue INT,@Dimesion INT,@DimTEMPxml nvarchar(max),@return_value int,@IgnoreSpaces bit
	DECLARE @CCStatusID INT,@VenderID INT,@HistoryStatus NVARCHAR(300),@BARCODE NVARCHAR(100)
	DECLARE @RefSelectedNodeID INT
	Declare @level int,@maxLevel int
		
	--SP Required Parameters Check
	IF @CompanyGUID IS NULL OR @CompanyGUID=''
	BEGIN
		RAISERROR('-100',16,1)
	END
	
	if(@ProductID=0)
		set @HistoryStatus='Add'
	else
		set @HistoryStatus='Update'
	
	--User acces check
	IF @ProductID=0
	BEGIN
		SET @ActionType=1
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,1)
	END
	ELSE
	BEGIN
		SET @ActionType=3
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,3)
	END
	
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END

	IF @ProductID>0 
	BEGIN
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,201) 
		IF (@HasAccess =0 and @ProductID >0 AND EXISTS (SELECT PRODUCTID FROM INV_DocDetails WITH(NOLOCK) WHERE ProductID=@ProductID) AND 
		(SELECT PRODUCTTYPEID FROM INV_PRODUCT WITH(NOLOCK) WHERE ProductID=@ProductID)<>@ProductTypeID)
		BEGIN
			RAISERROR('-516',16,1)
		END
	END

	declare @TempUOMID INT
	select @TempUOMID=UOMID from inv_product WITH(NOLOCK) where productid=@ProductID
	 
	IF(@ProductID >0 AND @TempUOMID<>@UOMID and EXISTS (SELECT D.ProductID FROM INV_DocDetails D WITH(NOLOCK) 
								JOIN INV_PRODUCT P WITH(NOLOCK) ON D.PRODUCTID=P.PRODUCTID AND D.UNIT=P.UOMID
								WHERE P.ProductID=@ProductID AND P.UOMID<>@UOMID) AND @UOMID<>-399)
	BEGIN
		RAISERROR('-540',16,1)
	END
	
	--User acces check FOR Notes
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')
	BEGIN
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,8)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
	END

	--User acces check FOR Attachments
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')
	BEGIN
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,12)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
	END

	--User acces check FOR Contacts
	IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')
	BEGIN
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,16)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
	END

	IF not exists(SELECT  FeatureTypeID FROM ADM_FeatureTypeValues WITH(NOLOCK) where FeatureTypeID= @ProductTypeID 
		and FeatureID=3 and (userid =@UserID or roleid=@RoleID))
	BEGIN     
		RAISERROR('-358',16,1)  
	END
	
	IF @ProductTypeID=4 and @HasSubItem=1
	BEGIN
		SET @IsGroup=1
	END
	
	--GETTING PREFERENCE
	IF @IsGroup=0	
	BEGIN
		SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) 
		WHERE COSTCENTERID=3 and Name='DuplicateCodeAllowed'  
		SELECT @IsDuplicateNameAllowed=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) 
		WHERE COSTCENTERID=3 and Name='DuplicateNameAllowed'
	END
	ELSE
	BEGIN
		SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) 
		WHERE COSTCENTERID=3 and Name='DuplicateGroupCodeAllowed'  
		SELECT @IsDuplicateNameAllowed=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) 
		WHERE COSTCENTERID=3 and Name='DuplicateGroupNameAllowed'
	END
	select @MaintainUniqueProductDescription=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) 
	WHERE COSTCENTERID=3 and Name='MaintainUniqueProductDescription'
	select @ProductCodeLength=convert(INT,Value) FROM COM_CostCenterPreferences WITH(NOLOCK)
	WHERE COSTCENTERID=3 and Name='ProductCodeLength'
	--@IgnoreSpaces
	SELECT @IgnoreSpaces=convert(bit,Value)  FROM COM_CostCenterPreferences WITH(nolock) 
	WHERE COSTCENTERID=3 and Name='CodeIgnoreSpaces' 
	SELECT @IsMultipleProductinSameBin=convert(bit,Value)  FROM COM_CostCenterPreferences WITH(nolock) 
	WHERE COSTCENTERID=3 and Name='MultipleProductinSameBin' 
	select @ProductCodeIgnoreText=Value from COM_CostCenterPreferences WITH(NOLOCK) 
	where CostCenterID=3 and Name='CodeIgnoreSpecialCharacters'
	select @IsProductLinkDimension=Value from COM_CostCenterPreferences WITH(NOLOCK) 
	where CostCenterID=3 and Name='CreateDimensionBasedOn'
	select @DimensionPrefValue=Value from COM_CostCenterPreferences with(nolock) 
	where CostCenterID=3 and Name = 'ProductLinkWithDimension'
	SELECT @BARCODE=Value FROM COM_CostCenterPreferences with(nolock) 
	where CostCenterID=3 and Name='BarcodeDimension'
	
	select @isparentcode=IsParentCodeInherited from COM_CostCenterCodeDef WITH(NOLOCK) 
	where CostCenterID=3
	  
	--MaintainUniqueProductDescription--
	if @MaintainUniqueProductDescription is not null and @MaintainUniqueProductDescription=1
	begin 
		IF @ProductID=0 
		BEGIN
			IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Description=@Description and Description is not null  and Description !='' )
			BEGIN
				RAISERROR('-342',16,1)
			END
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Description=@Description AND ProductID <> @ProductID and 
			Description is not null  and Description !='' )
			BEGIN
				RAISERROR('-342',16,1)
			END
		END
	end	
	
	if(@IgnoreSpaces=1)
		set @ProductCode=replace(@ProductCode,' ','')
			
	--DUPLICATE CHECK
	IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0
	BEGIN
		IF @ProductID=0
		BEGIN
			IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Isgroup=@IsGroup and ProductName=@ProductName)
				RAISERROR('-114',16,1)
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Isgroup=@IsGroup and ProductName=@ProductName AND ProductID <> @ProductID)
				RAISERROR('-114',16,1)
		END
	END
	
	--BINS CHECK
	IF @IsMultipleProductinSameBin IS NOT NULL AND @IsMultipleProductinSameBin=1
	BEGIN
		IF (@BinXML IS NOT NULL AND @BinXML <> '')
		BEGIN
			SET @XML=@BinXML				
			IF EXISTS (SELECT ProductBinID FROM INV_ProductBins WITH(NOLOCK) 
						WHERE nodeid<>@ProductID and BinNodeID IN (SELECT X.value('@BinNodeID','INT') 
						from @XML.nodes('/BinsXML/Row') as Data(X))
						and BinDimension in (SELECT X.value('@BinDimension','INT') 
						from @XML.nodes('/BinsXML/Row') as Data(X)))
			BEGIN
			
				RAISERROR('-536',16,1)
			END
		END
	END
	
	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
	
	 --ADDED CODE ON JULY 03 2012 BY HAFEEZ FOR PRODUCTWISE UOM
	DECLARE @UOMDATA XML,@RUOMID INT,@RPRODUCTID INT,@RCOUNT INT,@BASEDATA XML,@BCOUNT INT,@J INT,@BASEID INT,@Conversion FLOAT,
	@ACTION NVARCHAR(300),@BASENAME NVARCHAR(300),@TEMPBASEID INT,@BarDim int,
	@UNITID INT,@UNAME NVARCHAR(300),@CONVERSIONRATE FLOAT,@BarKey INT

	IF @ProductID=0
		SET @RPRODUCTID=-100
	ELSE
	BEGIN
		SET @RPRODUCTID=@ProductID
		IF @UOMID<>-399
		BEGIN
			IF((SELECT COUNT(*) FROM COM_UOM with(nolock) WHERE PRODUCTID=@ProductID)>0)
			BEGIN 
				UPDATE INV_PRODUCT SET UOMID=1 WHERE PRODUCTID=@ProductID 
				DELETE FROM [COM_UOM] WHERE PRODUCTID=@ProductID
				DELETE FROM INV_ProductBarcode WHERE  ProductID=@ProductID
			END
		END
	END

	SET @UOMDATA=@ProductWiseUOMData
	SET @BASEDATA=@ProductWiseUOMData1
	
	declare @TblUomBarcodes TABLE(Barcode NVARCHAR(300))
	DECLARE @TBLBASE TABLE(ID INT IDENTITY(1,1),BASEID INT,BASENAME NVARCHAR(300),CONVERSION float)

	INSERT INTO @TBLBASE
	SELECT X.value('@BaseID','int'),X.value('@BaseName','NVARCHAR(50)'), X.value('@Conversion','float') 
	FROM @BASEDATA.nodes('/Data/Row') as Data(X)

	DECLARE @TBLUOM TABLE(ID INT IDENTITY(1,1),UNITID INT,UNITNAME NVARCHAR(300),BASEID INT,BASENAME NVARCHAR(300),CONVERSIONRATE FLOAT,
	[ACTION] NVARCHAR(300),CONVERSION float,Barcode NVARCHAR(100),BarKey INT,MultiBarcode NVARCHAR(max))

	INSERT INTO @TBLUOM
	SELECT X.value('@UnitiD','int'),X.value('@UnitName','NVARCHAR(50)'),X.value('@BaseID','int'),
	   X.value('@BaseName','NVARCHAR(50)'),X.value('@ConversionUnit','float'),X.value('@Action','nvarchar(300)')  
	   , X.value('@Conversion','float') , X.value('@Barcode','NVARCHAR(100)'),isnull(X.value('@BarKey','INT'),0)
	   , X.value('@MultiBarcode','NVARCHAR(MAX)')
	FROM @UOMDATA.nodes('/Data/Row') as Data(X)

	IF EXISTS (SELECT * FROM INV_DocDetails IDD WITH(NOLOCK)
				JOIN @TBLUOM TU ON TU.UNITID=IDD.Unit AND TU.CONVERSIONRATE<>IDD.UOMConversion
				WHERE [ACTION]='UPDATE')
	BEGIN
		RAISERROR('-573',16,1)
	END
	
	IF EXISTS (SELECT * FROM INV_DocDetails IDD WITH(NOLOCK)
	JOIN @TBLUOM TU ON TU.UNITID=IDD.Unit 
	WHERE [ACTION]='DELETE')
	BEGIN
		RAISERROR('-573',16,1)
	END
	
	if @BARCODE!='' and isnumeric(@BARCODE)=1 and convert(int,@BARCODE)>50000
		set @BarDim=convert(int,@BARCODE)
	else
		set @BarDim=0
	
	SELECT @I=1,@RCOUNT=COUNT(*) FROM @TBLUOM
	SELECT @J=1,@BCOUNT=COUNT(*) FROM @TBLBASE
	WHILE @J<=@BCOUNT
	BEGIN
		SELECT  @TEMPBASEID=BASEID,@BASENAME=BASENAME,@Conversion=CONVERSION FROM @TBLBASE WHERE ID=@J
		
		IF((SELECT ISNULL(COUNT(*),0) FROM [COM_UOM] with(nolock) WHERE BASEID=@TEMPBASEID)=0)
		BEGIN
			select 1
			SELECT @BASEID=ISNULL(MAX(BASEID),0) FROM [COM_UOM] WITH(NOLOCK)
			SET @BASEID=@BASEID+1
			INSERT INTO [COM_UOM] (BASEID,BASENAME,UNITID,UNITNAME,CONVERSION,[GUID],CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
			VALUES(@BASEID,@BASENAME,@Conversion,@BASENAME,@Conversion,NEWID(),@USERNAME,@Dt,@RPRODUCTID,1) 
			SET @UOMID=SCOPE_IDENTITY()
			
			SELECT @BARCODE=Barcode,@BarKey=BarKey,@multiBarcodes=MultiBarcode FROM @TBLUOM WHERE ID=1 
			
			delete from @TblUomBarcodes
			INSERT INTO @TblUomBarcodes
			EXEC SPSplitString @multiBarcodes,',' 

			If exists(select Barcode from INV_ProductBarcode with(nolock) 
			where @BARCODE is not null and @BARCODE<>'' AND BARCODE=@BARCODE)
				RAISERROR('-130',16,1)
				
			If exists(select a.Barcode from INV_ProductBarcode a with(nolock) 
					join @TblUomBarcodes b on a.BARCODE=b.Barcode
					where b.Barcode is not null and b.Barcode<>''
					)
						RAISERROR('-130',16,1)	
			
			-------
			IF(@BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND @BarcodeID=@BARCODE)		
				RAISERROR('-130',16,1)

			If exists(select BarcodeID from INV_Product with(nolock) 
			where @BARCODE is not null and @BARCODE<>'' AND BarcodeID=@BARCODE)
				RAISERROR('-130',16,1)

			If exists(select a.BarcodeID from INV_Product a with(nolock) 
				join @TblUomBarcodes b on a.BarcodeID=b.Barcode
				where b.Barcode is not null and b.Barcode<>'' )
					RAISERROR('-130',16,1)	

			If exists(select Barcode from INV_ProductBarcode with(nolock) 
			where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND BARCODE=@BarcodeID)
				RAISERROR('-130',16,1)
				
			If exists(select Barcode from @TblUomBarcodes
			where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND Barcode=@BarcodeID )
				RAISERROR('-130',16,1)	
				
			If exists(select Barcode from @TblUomBarcodes
			where @BARCODE is not null and @BARCODE<>'' AND Barcode=@BARCODE )
				RAISERROR('-130',16,1)	
			-------								
							
			insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
			VALUES (@BARCODE,@BarKey,0,@UOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt)
			SET @BarcodID=SCOPE_IDENTITY()
			--INV_ProductBarcodeHistory
			insert into INV_ProductBarcodeHistory(BarcodeID,Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
			VALUES (@BarcodID,@BARCODE,@BarKey,0,@UOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt)
			
			insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
			select Barcode,0,0,@UOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt
			from @TblUomBarcodes
			SET @BarcodID=SCOPE_IDENTITY()
			--INV_ProductBarcodeHistory
			insert into INV_ProductBarcodeHistory(BarcodeID,Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
			select @BarcodID,Barcode,0,0,@UOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt
			from @TblUomBarcodes
			
			
			--COM_UOMHISTORY
			INSERT INTO [COM_UOMHISTORY] (UOMID,BASEID,BASENAME,UNITID,UNITNAME,CONVERSION,[GUID],CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
			VALUES(@UOMID,@BASEID,@BASENAME,@Conversion,@BASENAME,@Conversion,NEWID(),@USERNAME,@Dt,@RPRODUCTID,1)
			--COM_UOMHISTORY 
		END
		ELSE
		BEGIN
			SET @BASEID=@TEMPBASEID
		END
		
		IF EXISTS (select UNITID from @TBLUOM T where Action='DELETE' and ID>1 and UNITID>0)
		BEGIN
			DELETE FROM [COM_UOM] WHERE UOMID IN (select UNITID from @TBLUOM T where Action='DELETE' and ID>1 and UNITID>0)
			DELETE FROM [INV_ProductBarcode] WHERE UnitID IN (select UNITID from @TBLUOM T where Action='DELETE' and ID>1 and UNITID>0)
		END
		select 	@RCOUNT
		WHILE @I<=@RCOUNT
		BEGIN
			SELECT @ACTION=[ACTION],@RUOMID=UNITID,@UNAME=UNITNAME,@CONVERSIONRATE=CONVERSIONRATE,@Conversion=CONVERSION,@BARCODE=Barcode,@BarKey=BarKey,@multiBarcodes=MultiBarcode
			FROM @TBLUOM WHERE ID=@I 
			
			delete from @TblUomBarcodes
			INSERT INTO @TblUomBarcodes
			EXEC SPSplitString @multiBarcodes,',' 
			 select @ACTION
			IF (@ACTION=LTRIM(RTRIM('NEW')))
			BEGIN
				IF @I>1
				BEGIN
					If exists(select unitname from Com_uom with(nolock) where BaseID=@BASEID and Unitname=@UNAME AND UnitID>1)
						RAISERROR('-124',16,1)

					 If exists(select Barcode from INV_ProductBarcode with(nolock) 
					 where BARCODE=@BARCODE and @BARCODE is not null and @BARCODE<>'')
						RAISERROR('-130',16,1)
						
					If exists(select a.Barcode from INV_ProductBarcode a with(nolock) 
					join @TblUomBarcodes b on a.BARCODE=b.Barcode
					where b.Barcode is not null and b.Barcode<>'')
						RAISERROR('-130',16,1)

					-------
					IF(@BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND @BarcodeID=@BARCODE)		
						RAISERROR('-130',16,1)

					If exists(select BarcodeID from INV_Product with(nolock) 
					where @BARCODE is not null and @BARCODE<>'' AND BarcodeID=@BARCODE)
						RAISERROR('-130',16,1)

					If exists(select a.BarcodeID from INV_Product a with(nolock) 
						join @TblUomBarcodes b on a.BarcodeID=b.Barcode
						where b.Barcode is not null and b.Barcode<>'' )
							RAISERROR('-130',16,1)

					If exists(select Barcode from INV_ProductBarcode with(nolock) 
					where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND BARCODE=@BarcodeID)
						RAISERROR('-130',16,1)
				
					If exists(select Barcode from @TblUomBarcodes
					where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND Barcode=@BarcodeID )
						RAISERROR('-130',16,1)	
				
					If exists(select Barcode from @TblUomBarcodes
					where @BARCODE is not null and @BARCODE<>'' AND Barcode=@BARCODE )
						RAISERROR('-130',16,1)	
					-------
						  
					--SELECT UNIT ID MAX FROM TABLE 
					SELECT @UNITID=ISNULL(MAX(UNITID),0) FROM [COM_UOM] WITH(NOLOCK)

					INSERT INTO [COM_UOM] (BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
					VALUES(@BASEID,@BASENAME,(@UNITID+1),@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,@Dt,@RPRODUCTID,1)
					SET @RUOMID=SCOPE_IDENTITY()

					insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
					VALUES (@BARCODE,@BarKey,0,@RUOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt)
					SET @BarcodID=SCOPE_IDENTITY()
					--INV_ProductBarcodeHistory
					insert into INV_ProductBarcodeHistory(BarCodeID,Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
					VALUES (@BarcodID,@BARCODE,@BarKey,0,@RUOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt)
					
					insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
					select Barcode,0,0,@RUOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt
					from @TblUomBarcodes
					SET @BarcodID=SCOPE_IDENTITY()
					--INV_ProductBarcodeHistory
					insert into INV_ProductBarcodeHistory(BarCodeID,Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
					select @BarcodID,Barcode,0,0,@RUOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt
					from @TblUomBarcodes
					
					--COM_UOMHISTORY
					INSERT INTO [COM_UOMHISTORY] (UOMID,BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
					VALUES(@RUOMID,@BASEID,@BASENAME,(@UNITID+1),@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,@Dt,@RPRODUCTID,1)
					--COM_UOMHISTORY
				END
			END	
			ELSE if(@ACTION=LTRIM(RTRIM('UPDATE')))
			BEGIN 
				If exists(select unitname from Com_uom with(nolock) where BaseID=@BASEID and Unitname=@UNAME AND UnitID>1 AND UOMID<>@RUOMID)
					RAISERROR('-124',16,1)

				If exists(select Barcode from INV_ProductBarcode with(nolock) 
				where BARCODE=@BARCODE AND UNITID!=@RUOMID and @BARCODE is not null and @BARCODE<>'')
					RAISERROR('-130',16,1)

				If exists(select a.Barcode from INV_ProductBarcode a with(nolock) 
					join @TblUomBarcodes b on a.BARCODE=b.Barcode
					where b.Barcode is not null and b.Barcode<>'' AND A.UNITID!=@RUOMID )
						RAISERROR('-130',16,1)

				-------
				IF(@BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND @BarcodeID=@BARCODE)		
					RAISERROR('-130',16,1)

				If exists(select BarcodeID from INV_Product with(nolock) 
				where @BARCODE is not null and @BARCODE<>'' AND BarcodeID=@BARCODE)
					RAISERROR('-130',16,1)

				If exists(select a.BarcodeID from INV_Product a with(nolock) 
				join @TblUomBarcodes b on a.BarcodeID=b.Barcode
				where b.Barcode is not null and b.Barcode<>'' )
						RAISERROR('-130',16,1)


				If exists(select Barcode from INV_ProductBarcode with(nolock) 
				where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND BARCODE=@BarcodeID)
					RAISERROR('-130',16,1)
				
				If exists(select Barcode from @TblUomBarcodes
				where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND Barcode=@BarcodeID )
					RAISERROR('-130',16,1)	
				
				If exists(select Barcode from @TblUomBarcodes
				where @BARCODE is not null and @BARCODE<>'' AND Barcode=@BARCODE )
					RAISERROR('-130',16,1)	
				-------
							 
				UPDATE [COM_UOM]
				SET  UNITNAME=@UNAME,CONVERSION=@CONVERSIONRATE,BASENAME=@BASENAME,
					MODIFIEDBY=@USERNAME,ModifiedDate=@Dt
				where UOMID=@RUOMID
				
				--COM_UOMHISTORY
				INSERT INTO [COM_UOMHISTORY] (UOMID,BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise,MODIFIEDBY,ModifiedDate)
				SELECT @RUOMID,BaseID,@BASENAME,UNITID,@UNAME,@CONVERSIONRATE,NEWID(),CREATEDBY,CREATEDDATE,ProductID,IsProductWise,@USERNAME,@Dt
				FROM [COM_UOM] WITH(NOLOCK) WHERE UOMID=@RUOMID
				--COM_UOMHISTORY

				delete from INV_ProductBarcode
				where unitID=@RUOMID
				
				insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
				VALUES (@BARCODE,@BarKey,0,@RUOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt)
				SET @BarcodID=SCOPE_IDENTITY()
				--INV_ProductBarcodeHistory
				insert into INV_ProductBarcodeHistory(BarCodeID,Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
				VALUES (@BarcodID,@BARCODE,@BarKey,0,@RUOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt)
				
				insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
				select Barcode,0,0,@RUOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt
				from @TblUomBarcodes
				SET @BarcodID=SCOPE_IDENTITY()
				--INV_ProductBarcodeHistory
				insert into INV_ProductBarcodeHistory(BarCodeID,Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
				select @BarcodID,Barcode,0,0,@RUOMID,@RPRODUCTID,NULL,NEWID(),@USERNAME,@Dt,@USERNAME,@Dt
				from @TblUomBarcodes
					
				IF @I=1 AND @UOMID=-399
					SET @UOMID=@RUOMID
			END
			SET @I=@I+1
		END
		SET @TEMPBASEID=0
		SET @I=1
		SET @J=@J+1
	END
	
	IF(@UOMID=0)	    
		SET @UOMID=NULL	

	declare @CStatusID int
	SELECT @CStatusID=StatusID	FROM [INV_Product] WITH(NOLOCK) where ProductID=@ProductID
  if(@WID>0 and @ProductID>0)	 
	  begin
		set @level=(SELECT  top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
		where WorkFlowID=@WID and  UserID =@UserID)

		if(@level is null )
			set @level=(SELECT top 1 LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)  
			where WorkFlowID=@WID and  RoleID =@RoleID)

		if(@level is null ) 
			set @level=(SELECT top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID))

		if(@level is null )
			set @level=( SELECT top 1  LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) 
			where RoleID =@RoleID))

		select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK)  where WorkFlowID=@WID  
		select @level,@maxLevel
		if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
		begin 
		 	set @StatusID=1001 
		end	
		else if(@level is not null and  @maxLevel is not null and @level<@maxLevel and @CStatusID in (1003))--rejected status time
		begin	
		 	set @StatusID=1001 
		end	
		 
		 
	end
	
	IF @ProductID=0--ProductID will be 0 in ALTER procedureess--  
	BEGIN--CREATE Product--  	
			if(@WID>0)
		begin
			set @level=(SELECT  top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
			where WorkFlowID=@WID and  UserID =@UserID)

			if(@level is null )
				set @level=(SELECT top 1 LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)  
				where WorkFlowID=@WID and  RoleID =@RoleID)

			if(@level is null ) 
				set @level=(SELECT top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
				where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID))

			if(@level is null )
				set @level=( SELECT top 1  LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
				where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) 
				where RoleID =@RoleID))

			select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK)  where WorkFlowID=@WID  
			
			if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
			begin			
				set @StatusID=1001
			END
		END   		 
		--To SET Left,Right And Depth of Record  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		FROM [INV_Product] WITH(NOLOCK) WHERE ProductID=@SelectedNodeID  
	  
		--IF No Record Selected or Record Doesn't Exist  
		IF(@SelectedIsGroup is null)   
		BEGIN
			SELECT @SelectedNodeID=ProductID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			FROM [INV_Product] WITH(NOLOCK) WHERE ParentID =0  
	    END
	      
		IF(@SelectedIsGroup = 1)--Adding Node Under the Group  
		BEGIN  
			  UPDATE INV_Product SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
			  UPDATE INV_Product SET lft = lft + 2 WHERE lft > @Selectedlft;  
			  SET @lft =  @Selectedlft + 1  
			  SET @rgt = @Selectedlft + 2  
			  SET @ParentID = @SelectedNodeID  
			  SET @Depth = @Depth + 1  
		END  
		ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level  
		BEGIN  
			  UPDATE INV_Product SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
			  UPDATE INV_Product SET lft = lft + 2 WHERE lft > @Selectedrgt;  
			  SET @lft =  @Selectedrgt + 1  
			  SET @rgt = @Selectedrgt + 2   
		END  
		ELSE --Adding Root  
		BEGIN  
			  SET @lft =  1  
			  SET @rgt = 2   
			  SET @Depth = 0  
			  SET @ParentID =0  
			  SET @IsGroup=1  
		END  
		
		if @IsGroup=0 and (SELECT Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=3 and  Name='AutoBarcode')='TRUE'
		begin
			set @BarcodeID=dbo.fnGetBarCode()
		end
	  
		if @IsOffline=0
		begin
			-- Insert statements for procedure here  
			INSERT INTO [INV_Product]  
				(CodePrefix,CodeNumber,[ProductCode],[ProductName],[AliasName],[ProductTypeID],[StatusID]
				,[UOMID],[BarcodeID],[Description]
				,[Depth],[ParentID],[lft],[rgt],[IsGroup]  
				,[GUID],[CreatedBy],[CreatedDate],[ModifiedDate],CompanyGUID,HasSubItem,WorkFlowID,WorkFlowLevel)  
			VALUES  
				(@CodePrefix,@CodeNumber,@ProductCode,@ProductName,@AliasName,@ProductTypeID,@StatusID,  
				@UOMID,@BarcodeID,@Description,
				@Depth,@ParentID,@lft,@rgt,@IsGroup,  
				NEWID(),@UserName,@Dt,@Dt,@CompanyGUID,@HasSubItem,@WID,@level)
				--To get inserted record primary key
				SET @ProductID=SCOPE_IDENTITY()
		end
		else
		begin
			set identity_insert [INV_Product] ON
			select @ProductID=min(ProductID) from [INV_Product] with(nolock)
			if(@ProductID>-10000)
				set @ProductID=-10001
			else
				set @ProductID=@ProductID-1
				
			-- Insert statements for procedure here  
		    INSERT INTO [INV_Product](ProductID,CodePrefix,CodeNumber,[ProductCode],[ProductName],[AliasName],[ProductTypeID],[StatusID] 
			,[UOMID],[BarcodeID],[Description]
			,[Depth],[ParentID],[lft],[rgt],[IsGroup]  
			,[GUID],[CreatedBy],[CreatedDate],[ModifiedDate],CompanyGUID,HasSubItem,WorkFlowID,WorkFlowLevel)  
			VALUES(@ProductID,@CodePrefix,@CodeNumber,@ProductCode,@ProductName,@AliasName,@ProductTypeID,@StatusID,  
			@UOMID,@BarcodeID,@Description,
			@Depth,@ParentID,@lft,@rgt,@IsGroup,  
			NEWID(),@UserName,@Dt,@Dt,@CompanyGUID,@HasSubItem,@WID,@level)
			set identity_insert [INV_Product] OFF
	  	   
			INSERT INTO ADM_OfflineOnlineIDMap VALUES(3,@ProductID,0)
		end 
		
		--Handling of Extended Table  
		INSERT INTO INV_ProductExtended ([ProductID],[CreatedBy],[CreatedDate])  
		VALUES (@ProductID,@UserName,@Dt)  
		
		INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
		VALUES(3,@ProductID,newid(),  @UserName, @Dt)  
			 
		UPDATE [COM_UOM] SET PRODUCTID=@ProductID  WHERE PRODUCTID=-100
		UPDATE [INV_ProductBarcode] SET PRODUCTID=@ProductID  WHERE PRODUCTID=-100
		--INV_ProductBarcodeHistory
		UPDATE [INV_ProductBarcodeHistory] SET PRODUCTID=@ProductID  WHERE PRODUCTID=-100
		--
		--COM_UOMHISTORY
		UPDATE [COM_UOMHISTORY] SET PRODUCTID=@ProductID  WHERE PRODUCTID=-100
		--COM_UOMHISTORY

		if(@WID>0)
	BEGIN	 
		INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
		VALUES(3,@ProductID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
	end


	END--CREATE Product--  
	ELSE--UPDATE Product--  
	BEGIN  
	
		IF EXISTS(SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE ProductID=@ProductID AND ParentID=0)
		BEGIN
			RAISERROR('-123',16,1)
		END    
		 
		SELECT @TempGuid=[GUID] FROM [INV_Product]  WITH(NOLOCK)   
		WHERE ProductID=@ProductID  

	    IF(@Guid IS NOT NULL AND @Guid <> '' AND @TempGuid!=@Guid)  
	    BEGIN  
		  	RAISERROR('-101',16,1)
	    END  		
					
		UPDATE [INV_Product]  
		  SET [ProductCode] = @ProductCode   
		  ,[ProductName] = @ProductName   
		  ,[AliasName] = @AliasName   
		  ,[ProductTypeID] = @ProductTypeID   
		     
		  ,[StatusID] = @StatusID    
		  ,[UOMID] = @UOMID
		  ,HasSubItem=@HasSubItem    
		   
		  ,[BarcodeID] = @BarcodeID 	
		  ,[Description] = @Description        
		  ,[IsGroup] = @IsGroup 
		  ,[GUID] =  NEWID()  				
		  ,[ModifiedBy] = @UserName  
		  ,[ModifiedDate] = @Dt  
		  ,[WorkFlowLevel]=isnull(@level,0)
		  
		  
		  WHERE ProductID=@ProductID      
	END  
	
	If exists(select BarcodeID from INV_Product with(nolock) 
	where ProductID<>@ProductID AND @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND BarcodeID=@BarcodeID)
		RAISERROR('-130',16,1)

	If exists(select Barcode from INV_ProductBarcode with(nolock) 
	where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND BARCODE=@BarcodeID)
		RAISERROR('-130',16,1)

	--Series Check
	declare @retSeries INT
	EXEC @retSeries=spCOM_ValidateCodeSeries 3,@ProductID,@LangID
	if @retSeries>0
	begin
		ROLLBACK TRANSACTION
		SET NOCOUNT OFF  
		RETURN -999
	end

	

	--SETTING ACCOUNT CODE EQUALS ProductID IF EMPTY
	IF(@ProductCode IS NULL OR @ProductCode='')
	BEGIN
		set @ProductCode=convert(nvarchar,@ProductID)
		if @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0
		begin
			set @I=@ProductID
			while(1=1)
			begin
				set @ProductCode=convert(nvarchar,@I)
				if not EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE [ProductCode]=@ProductCode AND ProductID<>@ProductID)
					break;
				set @I=@I+1
			end
		end
		UPDATE  [INV_Product]
		SET ProductCode = @ProductCode
		WHERE ProductID=@ProductID
	END
	
	--DUPLICATE CODE CHECK 
	IF @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0
	BEGIN
		select @ProductCode=ProductCode from inv_product with(nolock) where ProductID=@ProductID
		--Ignore special character in ProductCode while verifying duplicate check 
		declare  @len INT
		set @UpdateSql='ProductCode'
		set @len=len(@ProductCodeIgnoreText) 
		if(@len>0)
		begin
			declare @tempCode nvarchar(100), @i1 int 
			set @tempCode=@ProductCode 
			set @i1=1
			while @i1<=@len
			begin
				declare @n char
				set @n=@ProductCodeIgnoreText
				set @ProductCodeIgnoreText=replace(@ProductCodeIgnoreText,@n,'')
				set @tempCode=replace(@tempCode,@n,'')
				set @UpdateSql='replace('+@UpdateSql+','''+@n+''','''')'
				set @i1=@i1+1
			end  
			declare @count1 int
			set @UpdateSql='set @count1=(select count('+@UpdateSql+') from INV_Product with(nolock) 
				where '+@UpdateSql+' = '''+@tempCode+''' and Isgroup='+convert(nvarchar,@IsGroup)+' and Productid<>'+convert(nvarchar,@ProductID)+')'
			 
			exec sp_executesql @UpdateSql,N'@count1 int output', @count1 OUTPUT 	
			IF (@count1>0)  
				RAISERROR('-116',16,1)
			--set @ProductCode=@tempCode  
		end 
		else
		begin
			IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Isgroup=@IsGroup and [ProductCode]=@ProductCode AND ProductID<>@ProductID)
				RAISERROR('-116',16,1)
		end
	END
	
	--CHECK WORKFLOW
	EXEC spCOM_CheckCostCentetWF 3,@ProductID,@WID,@RoleID,@UserID,@UserName,@StatusID output
    
    --Update Static Fields
	IF(@ProductStaticFieldsQuery IS NOT NULL AND @ProductStaticFieldsQuery <> '')
	BEGIN
		set @UpdateSql='update INV_Product
		SET '+@ProductStaticFieldsQuery+' 
		WHERE ProductID='+convert(NVARCHAR,@ProductID)
	 
		exec(@UpdateSql)
	END
	
	--Update CostCenter Extra Fields
	set @UpdateSql='update COM_CCCCDATA
	SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
	WHERE NodeID='+convert(nvarchar,@ProductID) + ' AND COSTCENTERID = 3 '
	exec(@UpdateSql)

	--ADDED CODE ON DEC 08 2011 BY HAFEEZ
	IF  (@AssignCCCCData IS NOT NULL AND @AssignCCCCData <> '') 
	BEGIN
		 SET @CCCCCData=@AssignCCCCData
		 EXEC [spCOM_SetCCCCMap] 3,@ProductID,@CCCCCData,@UserName,@LangID
	END
	
	--Update Extended
	IF(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <> '')
	BEGIN
		set @UpdateSql='update INV_ProductExtended
		SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =@ModDate
		WHERE ProductID='+convert(NVARCHAR,@ProductID)
	 
		EXEC sp_executesql @UpdateSql,N'@ModDate float',@Dt
	END
	
	--Duplicate Check
	exec [spCOM_CheckUniqueCostCenter] @CostCenterID=3,@NodeID =@ProductID,@LangID=@LangID
	
	--Dimension History Data
	IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
		EXEC spCOM_SetHistory 3,@ProductID,@HistoryXML,@UserName  
	
	--Inserts Multiple Attachments
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')
		exec [spCOM_SetAttachments] @ProductID,3,@AttachmentsXML,@UserName,@Dt
	
	-- Map Dimension
	set @Dimesion=0
	IF @IsProductLinkDimension IS NULL OR @IsProductLinkDimension=0 OR @IsProductLinkDimension=''
	BEGIN
		IF(@DimensionPrefValue is not null and @DimensionPrefValue<>'' and @IsLink=1)  
		BEGIN  

			BEGIN try  
				select @Dimesion=convert(INT,@DimensionPrefValue)  
			end try  
			BEGIN catch  
				set @Dimesion=0   
			end catch  
			
			if(@Dimesion>0)  
			BEGIN  
				select @CCStatusID=statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active'
				
				declare @ccCode nvarchar(20),@ccCodeNumber INT,@ccCodePrefix nvarchar(20)
				set @ccCode=@ProductCode
				
				declare @NID INT, @CCIDAcc INT
				select @NID = isnull(CCNodeID,0), @CCIDAcc=CCID  from INV_PRODUCT WITH(NOLOCK) where ProductID=@ProductID   
				if(@CCIDAcc<>@Dimesion)
					set @NID=0	
				
				declare @Gid nvarchar(50) , @Table nvarchar(100)
				declare @NodeidXML nvarchar(max) 
				select @Table=Tablename from adm_features WITH(NOLOCK) where featureid=@Dimesion
				declare @str nvarchar(max) 
				set @str='@Gid nvarchar(50) output' 
				set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' WITH(NOLOCK) where NodeID='+convert(nvarchar,@NID)+')'
				exec sp_executesql @NodeidXML, @str, @Gid OUTPUT
						
				if (SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@Dimesion AND Name='CodeAutoGen')='TRUE'
				begin
					declare @ccTblCode as table(prefix NVARCHAR(100),Number NVARCHAR(100),suffix NVARCHAR(100),Code NVARCHAR(100), IsManualcode bit)
					insert into @ccTblCode (prefix,Number,suffix,Code,IsManualcode)
					exec [spCOM_GetCodeData] @Dimesion,1,'',null,0,0
					select @ccCode=Code,@ccCodeNumber=Number,@ccCodePrefix=prefix+suffix from @ccTblCode
				end
				else
				begin
					set @ccCodePrefix=''
					set @ccCodeNumber=0
				end
				
				if @NID is null
					set @NID=0
				
				SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
				WHERE CostCenterID=3 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
						
				EXEC @return_value = [dbo].[spCOM_SetCostCenter]
				@NodeID = @NID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
				@Code = @ccCode,
				@Name = @ProductName,
				@AliasName=@ProductName,
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
				@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID=@Gid,
				@UserName=@UserName,@RoleID=@RoleID,@UserID=@UserID,
				@CodePrefix=@ccCodePrefix,@CodeNumber=@ccCodeNumber,
				@CheckLink = 0,@IsOffline=@IsOffline
				
				Update INV_PRODUCT set CCID=@Dimesion, CCNodeID=@return_value where ProductID=@ProductID
				
				if(@NID = 0)
				BEGIN		
					INSERT INTO COM_DocBridge (CostCenterID,NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,[guid],Createdby,CreatedDate,Abbreviation)
					values(3, @ProductID,0,0,@Dimesion,@return_value,'',newid(),@UserName, @dt,'Product')
				END
				
				set @UpdateSql='update COM_CCCCData
					set CCNID'+convert(nvarchar,(@Dimesion-50000))+'=convert(nvarchar,'+convert(nvarchar,@return_value)+')
					where CostCenterID=3 and NodeID='+convert(nvarchar,@ProductID)
				exec (@UpdateSql)
				
				Exec [spDOC_SetLinkDimension]
					@InvDocDetailsID=@ProductID, 
					@Costcenterid=3,         
					@DimCCID=@Dimesion,
					@DimNodeID=@return_value,
					@BasedOnValue=0,
					@UserID=@UserID,    
					@LangID=@LangID 
		
			END  
		END 	
	END

	--Creating Dimension based on Preference 'ProductTypeLinkDimension'
	IF @IsProductLinkDimension IS NOT NULL OR @IsProductLinkDimension=1 OR @IsProductLinkDimension<>''
	BEGIN
		declare @CC nvarchar(max), @CCID nvarchar(10)
		SELECT @CC=[Value] FROM com_costcenterpreferences with(nolock) WHERE [Name]='ProductTypeLinkDimension' and CostCenterID=3
		if (@CC is not null and @CC<>'' and @IsLink=1)
		begin
			DECLARE @TblCC AS TABLE(ID INT IDENTITY(1,1),CC nvarchar(100))
			DECLARE @TblCCVal AS TABLE(ID INT IDENTITY(1,1),CC2 nvarchar(100))
			DECLARE @ProductLinkDimensionID int,@LinkDimension nvarchar(300),@LinkXML nvarchar(max)
			select @LinkDimension=[Value] from com_costcenterpreferences with(nolock) WHERE [Name]='SelectedDimensionBasedOn' and CostCenterID=3
			declare @LinkVariable nvarchar(max) 
			set @LinkVariable='@ProductLinkDimensionID nvarchar(50) output' 
			set @LinkXML='set @ProductLinkDimensionID= (select '+@LinkDimension+' from COM_CCCCDATA with(nolock) where 
			CostCenterID=3 and NodeID='+convert(nvarchar,@ProductID)+') '
			exec sp_executesql @LinkXML, @LinkVariable, @ProductLinkDimensionID OUTPUT 

			INSERT INTO @TblCC(CC)
			EXEC SPSplitString @CC,',' 
			declare @value nvarchar(max),@BasedOnValue INT
			set @i=1
			set @CCStatusID=1 
			select @cnt=count(*) from @TblCC
			while @i<=@cnt
			begin
				select @value=cc from @TblCC where id=@i
				--select @value
				insert into @TblCCVal (CC2)
				EXEC SPSplitString @value,'~' 
				--select cc2 from @TblCCVal
				if exists (select cc2 from @TblCCVal where cc2 =@ProductLinkDimensionID )
				begin
					select @CCID=cc2 from @TblCCVal where cc2>50000   
					--select @CCID
					if(@CCID>50000)
					begin


						select @CCStatusID = statusid from com_status WITH(NOLOCK) where costcenterid=@CCID and status = 'Active'
						set @NID=0
						set @CCIDAcc=0 
						select @NID = CCNodeID, @CCIDAcc=CCID  from INV_Product with(nolock) where ProductID=@ProductID
						iF(@CCIDAcc<>@CCID)
						BEGIN
							if(@NID>0)
							begin 
								Update INV_Product set CCID=0, CCNodeID=0 where ProductID=@ProductID
								
								set @UpdateSql='update COM_CCCCDATA  
								SET  CCNID'+convert(nvarchar,(@CCIDAcc-50000))+'=1
								WHERE NodeID = '+convert(nvarchar,@ProductID) + ' AND CostCenterID = 3' 
								EXEC (@UpdateSql)
								
								delete from COM_DocBridge where CostCenterID=3 and NodeID=@ProductID 
								and RefDimensionNodeID=@NID and RefDimensionID=@CCIDAcc
								
								EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
									@CostCenterID = @CCIDAcc,
									@NodeID = @NID,
									@RoleID=@RoleID,
									@UserID = @UserID,
									@LangID = @LangID
								
								set @NID=0
								set @CCIDAcc=0 
							end
						END 
						
						if @NID is null
							set @NID=0 
											 
						select @Table=Tablename from adm_features WITH(NOLOCK) where featureid=@CCID 
						set @str='@Gid nvarchar(50) output' 
						set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' WITH(NOLOCK) where NodeID='+convert(nvarchar,@NID)+')'
						exec sp_executesql @NodeidXML, @str, @Gid OUTPUT 
						
						SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
						WHERE CostCenterID=3 AND RefDimensionID=@CCID AND NodeID=@SelectedNodeID 
						SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				
						EXEC @return_value = [dbo].[spCOM_SetCostCenter]
						@NodeID = @NID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
						@Code = @ProductCode,
						@Name = @ProductName,
						@AliasName=@ProductName,
						@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
						@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
						@CustomCostCenterFieldsQuery=NULL,@ContactsXML=@ContactsXML,@NotesXML=NULL,
						@CostCenterID = @CCID,@CompanyGUID=@CompanyGUID,@GUID=@Gid,
						@UserName=@UserName,@RoleID=@RoleID,@UserID=@UserID, @CheckLink = 0
						
				 		if(@NID =0)
						begin	
							INSERT INTO COM_DocBridge(CostCenterID,NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby, CreatedDate,Abbreviation)
							values(3, @ProductID,0,0,@CCID,@return_value,'',newid(),@UserName, @dt,'Product')
				 		end
				
						Update INV_Product set CCID=@CCID, CCNodeID=@return_value where ProductID=@ProductID					
						set @UpdateSql='update COM_CCCCDATA  
						SET  CCNID'+convert(nvarchar,(@CCID-50000))+'='+CONVERT(NVARCHAR,@return_value)+'
						WHERE NodeID = '+convert(nvarchar,@ProductID) + ' AND CostCenterID = 3' 
						EXEC (@UpdateSql)
						
						select @BasedOnValue=isnull(cc2,0) from @TblCCVal where cc2<50000 
						
						Exec [spDOC_SetLinkDimension]
							@InvDocDetailsID=@ProductID, 
							@Costcenterid=3,         
							@DimCCID=@CCID,
							@DimNodeID=@return_value,
							@BasedOnValue=@BasedOnValue,
							@UserID=@UserID,    
							@LangID=@LangID 
					end
				end
				delete from @TblCCVal
				set @i=@i+1
			end 
		end
	END
	
	IF (@StatusXML IS NOT NULL AND @StatusXML <> '')
		exec spCOM_SetStatusMap 3,@ProductID,@StatusXML,@UserName,@Dt	
	
	--Inserts Multiple Contacts
	IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')
	BEGIN
		SET @XML=@ContactsXML

		--If Action is NEW then insert new contacts
		INSERT INTO COM_Contacts(AddressTypeID,FeatureID,CostCenterID,FeaturePK,ContactName,
		Address1,Address2,Address3,City,[State],Zip,Country,Phone1,Phone2,Fax,Email1,Email2,[GUID],CreatedBy,CreatedDate)
		SELECT X.value('@AddressTypeID','int'),3,3,@ProductID,X.value('@ContactName','NVARCHAR(500)'),
		X.value('@Address1','NVARCHAR(500)'),X.value('@Address2','NVARCHAR(500)'),X.value('@Address3','NVARCHAR(500)'),
		X.value('@City','NVARCHAR(100)'),X.value('@State','NVARCHAR(100)'),X.value('@Zip','NVARCHAR(50)'),X.value('@Country','NVARCHAR(100)'),
		X.value('@Phone1','NVARCHAR(50)'),X.value('@Phone2','NVARCHAR(50)'),X.value('@Fax','NVARCHAR(50)'),X.value('@Email1','NVARCHAR(50)'),
		X.value('@Email2','NVARCHAR(50)'),
		newid(),@UserName,@Dt
		FROM @XML.nodes('/ContactsXML/Row') as Data(X)
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'

		--If Action is MODIFY then update contacts
		UPDATE COM_Contacts
		SET AddressTypeID=X.value('@AddressTypeID','int'),
			ContactName=X.value('@ContactName','NVARCHAR(500)'),
			Address1=X.value('@Address1','NVARCHAR(500)'),
			Address2=X.value('@Address2','NVARCHAR(500)'),
			Address3=X.value('@Address3','NVARCHAR(500)'),
			City=X.value('@City','NVARCHAR(100)'),
			[State]=X.value('@State','NVARCHAR(100)'),
			Zip=X.value('@Zip','NVARCHAR(50)'),
			Country=X.value('@Country','NVARCHAR(100)'),
			Phone1=X.value('@Phone1','NVARCHAR(50)'),
			Phone2=X.value('@Phone2','NVARCHAR(50)'),
			Fax=X.value('@Fax','NVARCHAR(50)'),
			Email1=X.value('@Email1','NVARCHAR(50)'),
			Email2=X.value('@Email2','NVARCHAR(50)'),
			[GUID]=newid(),
			ModifiedBy=@UserName,
			ModifiedDate=@Dt
		FROM COM_Contacts C with(nolock)
		INNER JOIN @XML.nodes('/ContactsXML/Row') as Data(X) 	
		ON convert(INT,X.value('@ContactID','INT'))=C.ContactID
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'

		--If Action is DELETE then delete contacts
		DELETE FROM COM_Contacts
		WHERE ContactID IN(SELECT X.value('@ContactID','INT')
			FROM @XML.nodes('/ContactsXML/Row') as Data(X)
			WHERE X.value('@Action','NVARCHAR(10)')='DELETE')
	END

	--Inserts Multiple Notes
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')
	BEGIN
		SET @XML=@NotesXML

		--If Action is NEW then insert new Notes
		INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,[GUID],CreatedBy,CreatedDate)
		SELECT 3,3,@ProductID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
'),  
		newid(),@UserName,@Dt
		FROM @XML.nodes('/NotesXML/Row') as Data(X)
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'

		--If Action is MODIFY then update Notes
		UPDATE COM_Notes
		SET Note=Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
'),  		
			[GUID]=newid(),
			ModifiedBy=@UserName,
			ModifiedDate=@Dt
		FROM COM_Notes C with(nolock)
		INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X) 	
		ON convert(INT,X.value('@NoteID','INT'))=C.NoteID
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'

		--If Action is DELETE then delete Notes
		DELETE FROM COM_Notes
		WHERE NoteID IN(SELECT X.value('@NoteID','INT')
			FROM @XML.nodes('/NotesXML/Row') as Data(X)
			WHERE X.value('@Action','NVARCHAR(10)')='DELETE')

	END

	--Inserts Multiple Substitute Groups
	IF (@SubstitutesXML IS NOT NULL AND @SubstitutesXML <> '')
	BEGIN
		SET @XML=@SubstitutesXML				

		--If Action is DELETE then remove ftom Substitute Group
		DELETE FROM INV_ProductSubstitutes
		WHERE ProductID=@ProductID
		
		if exists(SELECT 1 from @XML.nodes('/SubstituteType') as Data(X))
		begin
			INSERT INTO [INV_ProductSubstitutes](ProductID,SProductID,SubstituteGroupID,SubstituteGroupName,[GUID],[CreatedBy],[CreatedDate])
			SELECT @ProductID,X.value('@SID','INT'),X.value('@TID','NVARCHAR(50)'),'',NEWID(),@UserName,@Dt
			from @XML.nodes('/SubstituteType/TP') as Data(X)		
		end
		else
		begin
			INSERT INTO [INV_ProductSubstitutes](SubstituteGroupID,SubstituteGroupName,[ProductID],[SProductID],[GUID],[CreatedBy],[CreatedDate])
			SELECT X.value('@GroupID','NVARCHAR(50)'),X.value('@GroupName','NVARCHAR(50)'),@ProductID,0,NEWID(),@UserName,@Dt
			from @XML.nodes('/SubstitutesXML/Row') as Data(X)
		end
	END
	
	IF (@BinXML IS NOT NULL AND @BinXML <> '')
	BEGIN
			SET @XML=@BinXML
			if exists(select bn.BinID from 
			(select a.BinNodeID from [INV_ProductBins] a with(nolock)
			left join @XML.nodes('/BinsXML/Row') as Data(X) on a.BinNodeID= X.value('@BinNodeID','INT')
			where CostcenterID=3 and NodeID=@ProductID and  X.value('@BinNodeID','INT') is null ) as t
			join INV_BinDetails bn with(nolock) on bn.BinID=t.BinNodeID
			join  INV_DocDetails a with(nolock) on bn.InvDocDetailsID=a.InvDocDetailsID
			where bn.IsQtyIgnored=0 and a.ProductID=@ProductID and a.statusid in(369,441,371)
			group by bn.BinID
			having isnull(sum(bn.VoucherType* bn.Quantity),0)<-0.01)
				raiserror('Transaction exists can not un assign bins',16,1)			
	END	
	else
	BEGIN
			if exists(select bn.BinID from [INV_ProductBins] t with(nolock)						 
			join INV_BinDetails bn with(nolock) on bn.BinID=t.BinNodeID
			join  INV_DocDetails a with(nolock) on bn.InvDocDetailsID=a.InvDocDetailsID
			where bn.IsQtyIgnored=0 and a.ProductID=@ProductID and a.statusid in(369,441,371)
			and t.CostcenterID=3 and t.NodeID=@ProductID
			group by bn.BinID
			having isnull(sum(bn.VoucherType* bn.Quantity),0)<-0.01)
				raiserror('Transaction exists can not un assign bins',16,1)			
	END
	
	--Inserts Multiple Bins 
	DELETE FROM [INV_ProductBins]
	WHERE CostcenterID=3 and NodeID=@ProductID
	
	IF (@BinXML IS NOT NULL AND @BinXML <> '')
	BEGIN
			SET @XML=@BinXML
	 
			INSERT INTO [INV_ProductBins](CostcenterID,NodeID,Location,Division
				,BinDimension,BinNodeID,IsDefault,DimCCID,DimNodeID
				,[CreatedBy],[CreatedDate],Serialno,Capacity,StatusID)  			  
			SELECT 3,@ProductID,X.value('@Location','INT'),X.value('@Division','INT')
				,X.value('@BinDimension','INT'),X.value('@BinNodeID','INT'),X.value('@Default','bit')
				,X.value('@DimCCID','INT'),X.value('@DimNodeID','INT')
				,@UserName,@Dt,X.value('@Serialno','INT'),X.value('@Capacity','float'),X.value('@Status','INT')
			from @XML.nodes('/BinsXML/Row') as Data(X)
			
			if exists( select BinDimension from [INV_ProductBins] with(NOLOCK) where CostcenterID=3 and NodeID=@ProductID
					group by BinDimension,BinNodeID
					HAVING COUNT(*)>1)
				raiserror('Duplicate Bin at Bins Tab',16,1)
	END
		
	--Inserts Product Testcases
	DELETE FROM [INV_ProductTestcases]
	WHERE ProductID=@ProductID
	
	IF (@TestcasesXML IS NOT NULL AND @TestcasesXML <> '')
	BEGIN
		
		SET @XML=@TestcasesXML				
		
		INSERT INTO [INV_ProductTestcases]  
			([ProductID],
			[TestCaseID],
			[Min],
			[Max] ,
			[Iteration],
			[Sample],
			[CostCenterID],
			[CCNodeID],
			[DocumentID],
			TestType,
			ProbableValues,
			Variance,
			SampleType,
			RetestDays)  			  
		SELECT @ProductID,X.value('@TestCaseID','INT'),X.value('@Min','float')
			,X.value('@Max','float'),X.value('@Iteration','INT'),X.value('@Sample','float')
			,X.value('@CostCenterID','INT'),X.value('@CCNodeID','INT')
			,X.value('@DocumentID','INT')
			,X.value('@TestType','INT')
			,X.value('@ProbableValues','NVARCHAR(max)')
			,X.value('@Variance','float')
			,X.value('@SampleType','INT')
			,X.value('@RetestDays','INT')
		from @XML.nodes('/XML/Row') as Data(X)
	END
		  
	--Inserts Multiple Vendors
	IF (@VendorsXML IS NOT NULL AND @VendorsXML <> '')
	BEGIN
		declare @VendorTable table(id int identity(1,1),VendorID INT, AccountID INT,Priorty INT,LeadTime float,
		Barcode nvarchar(100),[Action] NVARCHAR(10), MinOrderQty float,[Weight] float,Volume float, Remarks NVARCHAR(MAX))
		declare @VVendorID INT,@VAccountID INT,@VPriorty INT,@VLeadTime float, @VMinOrderQty float,@Remarks NVARCHAR(MAX), 
		@VBarcode nvarchar(100),@VAction nvarchar(10),@Vid INT,@Vcnt INT,@Weight float,@Volume float
		SET @XML=@VendorsXML
		
		declare @vtable table(id int identity(1,1),bar nvarchar(100))
		declare @VVid INT,@VVcnt INT,@VVbar nvarchar(100)

		insert into @VendorTable(VendorID,AccountID,Priorty,LeadTime,Barcode,[Action],MinOrderQty,Weight,Volume,Remarks)
		SELECT DISTINCT X.value('@VendorID','INT'),Grp.AccountID,X.value('@Priority','INT'),X.value('@LeadTime','FLOAT'), 
		X.value('@Barcode','NVARCHAR(100)'),X.value('@Action','NVARCHAR(10)'),X.value('@MinOrderQty','FLOAT')
		,X.value('@Weight','Float'),X.value('@Volume','Float'),X.value('@Remarks','NVARCHAR(MAX)')
		FROM @XML.nodes('/VendorsXML/Row') as Data(X) 
		JOIN ACC_ACCOUNTS ACC WITH(NOLOCK) ON ACC.AccountID=X.value('@AccountID','INT')
		JOIN ACC_ACCOUNTS Grp WITH(NOLOCK) ON ACC.lft <= Grp.lft and  ACC.rgt >= Grp.rgt AND Grp.ISGROUP=0
		
		insert into @VendorTable(VendorID,[Action])
		SELECT X.value('@VendorID','INT'),X.value('@Action','NVARCHAR(10)')
		FROM @XML.nodes('/VendorsXML/Row') as Data(X) 
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE'
		
		set @Vid=1
		select @Vcnt=count(*) from @VendorTable
			
		while(@Vid<=@Vcnt)
		BEGIN
			select @VVendorID=VendorID,@VAccountID=AccountID,@VPriorty=Priorty,@VLeadTime=LeadTime,@VMinOrderQty=MinOrderQty,
			@VBarcode=Barcode,@VAction=[Action],@Weight=[Weight],@Volume=Volume,@Remarks=Remarks from @VendorTable where id=@Vid
				
			--If Action is NEW then insert new Vedors
			if(@VAction=ltrim(rtrim('NEW')))
			BEGIN
				INSERT INTO INV_ProductVendors(ProductID,AccountID,Priority,LeadTime,
					CompanyGUID,[GUID],CreatedBy,CreatedDate,MinOrderQty,Volume,[Weight],Remarks)
				SELECT @ProductID,@VAccountID,@VPriorty,@VLeadTime,
					@CompanyGUID,newid(),@UserName,@Dt,@VMinOrderQty,@Volume,@Weight,@Remarks
					
					set @VVendorID=scope_identity()
				 
			END	
				
			--If Action is MODIFY then update Vedors
			else if(@VAction=ltrim(rtrim('MODIFY')))
			BEGIN
				UPDATE INV_ProductVendors
				SET Priority=@VPriorty,
					LeadTime=@VLeadTime,
					MinOrderQty=@VMinOrderQty,
					[GUID]=newid(),
					ModifiedBy=@UserName,
					ModifiedDate=@Dt
					,Volume=@Volume
					,[Weight]=@Weight
					,Remarks=@Remarks
				WHERE ProductVendorID=@VVendorID
	
			END

			--If Action is DELETE then delete Vedors
			else if(@VAction=ltrim(rtrim('DELETE')))
			BEGIN
				select @VAccountID=AccountID from INV_ProductVendors WITH(NOLOCK)
				WHERE ProductVendorID=@VVendorID
				
				DELETE FROM	INV_ProductBarcode
				WHERE VenderID=@VAccountID and productID=@ProductID
				
				DELETE FROM INV_ProductVendors
				WHERE ProductVendorID=@VVendorID
				
			END	
				
			if(@VAction<>ltrim(rtrim('DELETE')))
			begin	
				if exists(select * from INV_ProductBarcode WITH(NOLOCK) where VenderID=@VAccountID and productID=@ProductID )
				BEGIN
					delete from INV_ProductBarcode where VenderID=@VAccountID and productID=@ProductID
				END
				
				delete from @vtable
				
				insert into @vtable(bar)
				exec SPSplitString @VBarcode,','
				select @VVid=MIN(id),@VVcnt=MAX(id) from @vtable
				
				while(@VVid<=@VVcnt)
				BEGIN
					select @VVbar=bar from @vtable where id=@VVid
					
					if exists(select * from INV_ProductBarcode WITH(NOLOCK) 
					where Barcode=@VVbar and @VVbar is not null and @VVbar<>'')
					BEGIN
						raiserror('-130',16,1)
					END

					-------
					IF(@BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND @BarcodeID=@VVbar)		
						RAISERROR('-130',16,1)

					If exists(select BarcodeID from INV_Product with(nolock) 
					where @BARCODE is not null and @BARCODE<>'' AND BarcodeID=@BARCODE)
						RAISERROR('-130',16,1)

					If exists(select a.BarcodeID from INV_Product a with(nolock) 
					join @TblUomBarcodes b on a.BarcodeID=b.Barcode
					where b.Barcode is not null and b.Barcode<>'' )
						RAISERROR('-130',16,1)

					If exists(select Barcode from INV_ProductBarcode with(nolock) 
					where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND BARCODE=@BarcodeID)
						RAISERROR('-130',16,1)
				
					If exists(select bar from @vtable
					where @BarcodeID is not null and @BarcodeID<>'' AND @BarcodeID<>'1' AND bar=@BarcodeID )
						RAISERROR('-130',16,1)	
				
					If exists(select bar from @vtable
					where @BARCODE is not null and @BARCODE<>'' AND bar=@BARCODE )
						RAISERROR('-130',16,1)	
					-------
				
					insert into INV_ProductBarcode(Barcode,VenderID,UnitID,ProductID,CompanyGUID,[GUID],CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
					select @VVbar,@VAccountID,0,@ProductID,@CompanyGUID,newid(),@UserName,@Dt,@UserName,@Dt 
					
					SET @BarcodID=SCOPE_IDENTITY()
					--INV_ProductBarcodeHistory
					insert into INV_ProductBarcodeHistory(BarCodeID,Barcode,VenderID,UnitID,ProductID,CompanyGUID,[GUID],CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
					select @BarcodID,@VVbar,@VAccountID,0,@ProductID,@CompanyGUID,newid(),@UserName,@Dt,@UserName,@Dt 
					--
					set @VVid=@VVid+1
				END
			end	
			set @Vid=@Vid+1;
		END	
	END
	
	delete from INV_ProductSpecification where ProductID=@ProductID
	if(@ProdSpecs is not null or @ProdSpecs<>'')
	BEGIN
			set @XML=@ProdSpecs
			insert into INV_ProductSpecification(ProductID,GroupName,FldType,LookUpID,Val,ShowinHeader,LookUpVal,DisplayOrder)
			select @ProductID,X.value('@GroupName','nvarchar(max)'),X.value('@FldType','int')
			,X.value('@LookUpID','INT'),X.value('@Val','nvarchar(max)'),X.value('@ShowinHeader','int')
			,X.value('@LookUpVal','INT'),X.value('@DisplayOrder','INT')
			FROM @XML.nodes('/XML/Row') as Data(X) 
	END
	
	if(@KitXML is not null or @KitXML<>'')
	BEGIN
		declare @DATA xml
		set @DATA=@KitXML
		--IF DATA EXISTS @ DOCUMENTS THE RAISE ERROR 
		if exists (select pb.productid  from inv_docdetails d WITH(NOLOCK)
				join inv_product p WITH(NOLOCK) on d.productid=p.productid and p.producttypeid=3
				join [INV_ProductBundles] pb WITH(NOLOCK) on d.productid=pb.parentproductid
				join inv_docdetails kitdoc WITH(NOLOCK) on d.invdocdetailsid=kitdoc.dynamicinvdocdetailsid 
				and pb.productid=kitdoc.productid and d.voucherno=kitdoc.voucherno 
				where kitdoc.productid is not null  and d.productid= @ProductID and kitdoc.productid not in 
				(select A.value('@Product','INT') from @DATA.nodes('/XML/Row') as DATA(A) ))
			RAISERROR('-110',16,1)

		EXEC [spINV_SetProductBundle] @KitXML,@ProductID,@CompanyGUID,@UserName,@UserID,@LangID 
	END
	
	--link products based on dimension
	EXEC [spINV_SetLinkedProducts] @LinkedProductsXML,@CompanyGUID,@UserName,@UserID,@LangID 

	--IF PRODUCT IS OF SERIALIZED sPRODUCT
	IF @ProductTypeID=2
	BEGIN
		SET @XML=@SerializationXML
		UPDATE INV_PRODUCT SET Warranty=X.value('@Warranty','bit'),
		WarrantyExpires=X.value('@WarrantyExpires','float'),WarrantyExpiryFormat=X.value('@WarrantyExpiresTo','INT')
        FROM @XML.nodes('/XML/Row') as Data(X) 
		WHERE ProductID=@ProductID     
		   
	END
	ELSE IF @ProductTypeID=4  --IF PRODUCTTYPE IS MATRIX AND ITEM IS TRUE THEN
	BEGIN
		 UPDATE INV_PRODUCT SET AttributeGroupID=@MatrixSeqno  WHERE ProductID=@ProductID    
	END
	
	--Insert Stock Code
	if(select Value from ADM_GlobalPreferences with(nolock) where Name='POSEnable')='True'
	begin
		if @HistoryStatus='Add'
			exec spDoc_SetStockCode 0,1,@ProductCode,@ProductID,null,0,0,null,@UserName
		else
			exec spDoc_SetStockCode 1,1,@ProductCode,@ProductID,null,0,0,null,@UserName
	end

	--INSERT SUB ITEM PRODUCT DATA
	IF @HasSubItem=1
	BEGIN
		UPDATE INV_Product
		SET AttributeMapXML=@AttributesXML, IsSubItem=1
		WHERE ProductID=@ProductID
		
		SET @I =1
		DECLARE @COUNT INT,@AttCCCCMap NVARCHAR(MAX)
		
		CREATE TABLE #TBLProduct(
		ID INT IDENTITY(1,1),
		[ProductCode] [nvarchar](200)  ,
		[ProductName] [nvarchar](500)  ,
		[AliasName] [nvarchar](500) ,
		[ValuationID] [int] NOT NULL,
		[StatusID] [int] NOT NULL,
		[IsLotwise] [bit] NOT NULL  ,
		[UOMID] [INT] NULL,
		[CurrencyID] [INT] NULL,
		[SalesAccountID] [INT] NULL,
		[PurchaseAccountID] [INT] NULL,
		[COGSAccountID] [INT] NULL,
		[ClosingStockAccountID] [INT] NULL,
		CustomFieldCCMapXML nvarchar(max))
		
		--DELETE FROM INV_Product WHERE ParentProductID=@ProductID 
		SET @XML=@ItemProductData

		INSERT INTO #TBLProduct([ProductCode] ,[ProductName],[AliasName],[ValuationID],[StatusID],[IsLotwise],[UOMID],[CurrencyID]
		,[SalesAccountID],[PurchaseAccountID],[COGSAccountID],[ClosingStockAccountID],CustomFieldCCMapXML)  
		SELECT X.value('@ProductCode','NVARCHAR(500)'),X.value('@ProductName','NVARCHAR(max)'),X.value('@AliasName','NVARCHAR(max)'),
		X.value('@Valuation','INT'),X.value('@ProductStatus','INT'),X.value('@LotWise','BIT'),
		X.value('@UOM','INT'),X.value('@Currency','INT'),X.value('@SalesAccount','INT'),X.value('@PurchaseAccount','INT'),X.value('@COGSAccount','INT'),
		X.value('@ClosingStockAccount','INT'),X.value('@CustomFieldCCMapXML','NVARCHAR(max)')
		FROM @XML.nodes('/ItemProducts/Row') as Data(X)
			
		DECLARE @DUPName NVARCHAR(200)
		--DUPLICATE CHECK
		IF @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0
		BEGIN
			
			SELECT TOP 1 @DUPName=T.ProductName 
			FROM INV_Product P WITH(NOLOCK)
			INNER JOIN #TBLProduct T with(nolock) ON P.ProductCode=T.ProductCode
			IF @DUPName IS NOT NULL
			BEGIN
				SET @DUPName='Duplicate Code "'+@DUPName+'"'
				RAISERROR(@DUPName,16,1)
			END
		END
		IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0
		BEGIN
			
			SELECT TOP 1 @DUPName=T.ProductName 
			FROM INV_Product P WITH(NOLOCK)
			INNER JOIN #TBLProduct T ON P.ProductName=T.ProductName
			IF @DUPName IS NOT NULL
			BEGIN
				SET @DUPName='Duplicate Name "'+@DUPName+'"'
				RAISERROR(@DUPName,16,1)
			END
		END
 
		SELECT @COUNT=COUNT(*) FROM #TBLProduct with(nolock)
		
		set @SelectedNodeID=@ProductID
			 
		WHILE @I<=@COUNT
		BEGIN
			--To SET Left,Right And Depth of Record  
			SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			FROM [INV_Product] WITH(NOLOCK) WHERE ProductID=@SelectedNodeID  

			--IF No Record Selected or Record Doesn't Exist  
			IF(@SelectedIsGroup is null)   
			BEGIN
				SELECT @SelectedNodeID=ProductID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				FROM [INV_Product] WITH(NOLOCK) WHERE ParentID =0  
			END

			IF(@SelectedIsGroup = 1)--Adding Node Under the Group  
			BEGIN  
				UPDATE INV_Product SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
				UPDATE INV_Product SET lft = lft + 2 WHERE lft > @Selectedlft;  
				SET @lft =  @Selectedlft + 1  
				SET @rgt = @Selectedlft + 2  
				SET @ParentID = @SelectedNodeID  
				SET @Depth = @Depth + 1  
			END  
			ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level  
			BEGIN  
				UPDATE INV_Product SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
				UPDATE INV_Product SET lft = lft + 2 WHERE lft > @Selectedrgt;  
				SET @lft =  @Selectedrgt + 1  
				SET @rgt = @Selectedrgt + 2   
			END  
			ELSE  --Adding Root  
			BEGIN  
				SET @lft =  1  
				SET @rgt = 2   
				SET @Depth = 0  
				SET @ParentID =0  
				SET @IsGroup=1  
			END  

			INSERT INTO INV_Product(ParentProductID,[ProductCode] ,[ProductName],[AliasName],[ProductTypeID],[ValuationID],[StatusID],
			[IsLotwise],[UOMID],[CurrencyID],[SalesAccountID],[PurchaseAccountID],[COGSAccountID],[ClosingStockAccountID],			
				[BarcodeID],[Description],
				[Depth],[ParentID],LFT,RGT,[IsGroup],HASSUBITEM,[GUID]  			
				,[CreatedBy],[CreatedDate],CompanyGUID)  
			SELECT @ProductID,[ProductCode] ,[ProductName],[AliasName],1,[ValuationID],[StatusID],
			[IsLotwise],[UOMID],[CurrencyID],[SalesAccountID],[PurchaseAccountID],[COGSAccountID],[ClosingStockAccountID],
				@BarcodeID,@Description,
				@Depth,
				@ParentID, 
				@lft,  
				@rgt,  
				0,0,NEWID(),   			 
				@UserName,@Dt,@CompanyGUID
				
				FROM #TBLProduct with(nolock) 
				WHERE ID=@I

			set @SubItemID =@@identity

			INSERT INTO INV_ProductExtended  
				([ProductID]  
				,[CreatedBy]  
				,[CreatedDate])  
			VALUES  
				(@SubItemID,         
				 @UserName,  
				 @Dt)  

			INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
			VALUES(3,@SubItemID,newid(),  @UserName, @Dt) 
			
			IF(@ProductStaticFieldsQuery IS NOT NULL AND @ProductStaticFieldsQuery <> '')
			BEGIN
				set @UpdateSql='update INV_Product
				SET '+@ProductStaticFieldsQuery+' 
				WHERE ProductID='+convert(NVARCHAR,@SubItemID)
			 
				exec(@UpdateSql)
			END 

			IF(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <> '')
			BEGIN
				set @UpdateSql='update INV_ProductExtended SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +'				WHERE ProductID='+convert(NVARCHAR,@SubItemID)
				exec(@UpdateSql)
			END

			SELECT @AttCCCCMap=CustomFieldCCMapXML FROM #TBLProduct with(nolock) WHERE ID=@I

			set @UpdateSql='UPDATE COM_CCCCDATA	SET '+@AttCCCCMap+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
			WHERE NodeID='+convert(nvarchar,@SubItemID) + ' AND CostCenterID = 3'
			exec(@UpdateSql)
			
			--Insert Stock Code
			if(select Value from ADM_GlobalPreferences with(nolock) where Name='POSEnable')='True'
			begin
				select @UpdateSql=ProductCode from #TBLProduct with(nolock) WHERE ID=@I
				exec spDoc_SetStockCode 0,1,@UpdateSql,@SubItemID,null,0,0,null,@UserName
			end
			SET  @I=@I+1
		END
	END

	--Insert Notifications
	EXEC spCOM_SetNotifEvent @ActionType,3,@ProductID,@CompanyGUID,@UserName,@UserID,@RoleID
	--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=3 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 3,@ProductID,@UserID,@LangID
	end  
	--INSERT INTO HISTROY   
	EXEC [spCOM_SaveHistory]  
		@CostCenterID =3,    
		@NodeID =@ProductID,
		@HistoryStatus =@HistoryStatus,
		@UserName=@UserName,
		@DT=@DT
		
	COMMIT TRANSACTION
--	ROLLBACK TRANSACTION

	SELECT * FROM [INV_Product] WITH(NOLOCK) WHERE ProductID=@ProductID

	IF @ActionType=1
		SELECT   ErrorMessage + ' ''' + isnull(@ProductCode,'')+'''' as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
		WHERE ErrorNumber=105 AND LanguageID=@LangID 
	ELSE
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID   
	SET NOCOUNT OFF;  
	RETURN @ProductID 		
	
END TRY
BEGIN CATCH  

	IF @return_value = -999
		RETURN @return_value
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		IF(ISNUMERIC(ERROR_MESSAGE())=1 and ERROR_MESSAGE()=-536)    
		BEGIN    
			set @ProductName=(SELECT ProductName FROM [INV_Product] WITH(NOLOCK) WHERE ProductID IN (SELECT NodeID FROM INV_ProductBins WITH(NOLOCK) 
						WHERE BinNodeID IN (SELECT X.value('@BinNodeID','INT')
						from @XML.nodes('/BinsXML/Row') as Data(X))))    
			   
			SELECT ErrorMessage+' '+@ProductName as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
			WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
		END   
		ELSE IF ISNUMERIC(ERROR_MESSAGE())=1
		BEGIN
			SELECT * FROM [INV_Product] WITH(NOLOCK) WHERE ProductID=@ProductID 
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		ELSE
			SELECT ERROR_MESSAGE() ErrorMessage
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
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
