USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetProductQuick]
	@ProductID [int],
	@ProductCode [nvarchar](200) = NULL,
	@ProductName [nvarchar](max),
	@ProductTypeID [int],
	@CodePrefix [nvarchar](50) = null,
	@CodeNumber [int],
	@StaticFieldsQuery [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@AssignCCCCData [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
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
		DECLARE @Dt FLOAT,@StatusID INT,@HasAccess bit,@IsDuplicateNameAllowed bit,@IsDuplicateCodeAllowed BIT,@IsProductCodeAutoGen bit,@MaintainUniqueProductDescription bit,@ProductCodeLength INT
		DECLARE @TempGuid NVARCHAR(50),@DimensionPrefValue INT,@return_value int,@SQL NVARCHAR(MAX)
		DECLARE @Dimesion INT   ,@IgnoreSpaces bit,@IsProductLinkDimension bit
		declare @ProductCodeIgnoreText nvarchar(50) ,@HistoryStatus NVARCHAR(300)
		DECLARE @IsGroup BIT=0
		DECLARE @RefSelectedNodeID INT,@SelectedNodeID INT
		
		--SP Required Parameters Check
		IF @CompanyGUID IS NULL OR @CompanyGUID=''
		BEGIN
			RAISERROR('-100',16,1)
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
		
		IF @ProductID>0 
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,201) 
			IF (@HasAccess =0 and @ProductID >0 AND EXISTS (SELECT PRODUCTID FROM INV_DocDetails WITH(NOLOCK) WHERE ProductID=@ProductID) AND 
			(SELECT PRODUCTTYPEID FROM INV_PRODUCT WITH(NOLOCK) WHERE ProductID=@ProductID)<>@ProductTypeID)
			BEGIN
				RAISERROR('-516',16,1)
			END
			
			Select @IsGroup=IsGroup from INV_Product WITH(NOLOCK) WHERE ProductID=@ProductID
		END
	    
	    if(@ProductID=0)
			set @HistoryStatus='Add'
		else
			set @HistoryStatus='Update'
		
		--User acces check
		IF @ProductID=0
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,1)
		END
		ELSE
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,3)
		END
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		IF not exists(SELECT  FeatureTypeID FROM ADM_FeatureTypeValues with(nolock) where FeatureTypeID= @ProductTypeID 
		and FeatureID=3 and (userid =@UserID or roleid=@RoleID))
		BEGIN     
			RAISERROR('-358',16,1)  
		END
		
		--GETTING PREFERENCE
		IF @IsGroup=0
		BEGIN
			SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) 
			WHERE COSTCENTERID=3 and  Name='DuplicateCodeAllowed'  
			SELECT @IsDuplicateNameAllowed=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) 
			WHERE COSTCENTERID=3 and Name='DuplicateNameAllowed'
		END
		ELSE 
		BEGIN
			SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) 
			WHERE COSTCENTERID=3 and  Name='DuplicateGroupCodeAllowed'  
			SELECT @IsDuplicateNameAllowed=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) 
			WHERE COSTCENTERID=3 and Name='DuplicateGroupNameAllowed'
		END
		SELECT @IsProductCodeAutoGen=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) 
		WHERE COSTCENTERID=3 and Name='ProductCodeAutoGen'
		select @MaintainUniqueProductDescription=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) 
		WHERE COSTCENTERID=3 and Name='MaintainUniqueProductDescription'
		select @ProductCodeLength=convert(INT,Value)  FROM COM_CostCenterPreferences WITH(NOLOCK) 
		WHERE COSTCENTERID=3 and Name='ProductCodeLength'
		select @ProductCodeIgnoreText=Value   from COM_CostCenterPreferences with(nolock) 
		where CostCenterID=3 and Name='CodeIgnoreSpecialCharacters'
		SELECT @IgnoreSpaces=convert(bit,Value) FROM COM_CostCenterPreferences WITH(nolock) 
		WHERE COSTCENTERID=3 and  Name='CodeIgnoreSpaces'  
		select @IsProductLinkDimension=Value   from COM_CostCenterPreferences with(nolock) 
		where CostCenterID=3 and Name='CreateDimensionBasedOn'
		select @DimensionPrefValue=Value from COM_CostCenterPreferences with(nolock) 
		where CostCenterID=3 and  Name = 'ProductLinkWithDimension'  
		
		if(@IgnoreSpaces=1)
			set @ProductCode=replace(@ProductCode,' ','')
		
		--DUPLICATE CODE CHECK
		IF  @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0
		BEGIN
			--Ignore special character in ProductCode while verifying duplicate check 
			declare  @len INT,@CodeSQL NVARCHAR(MAX)
			set @CodeSQL='ProductCode'
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
					set @CodeSQL='replace('+@CodeSQL+','''+@n+''','''')'
					set @i1=@i1+1
				end  
				declare @str1 nvarchar(max) , @count1 int
				set @str1='@count1 int output'
				if @ProductID=0
					set @CodeSQL='set @count1=(select count('+@CodeSQL+') from INV_Product with(nolock) where '+@CodeSQL+' = '''+@tempCode+''' and Isgroup='+convert(nvarchar,@IsGroup)+')'
				else
					set @CodeSQL='set @count1=(select count('+@CodeSQL+') from INV_Product with(nolock) where '+@CodeSQL+' = '''+@tempCode+''' and Isgroup='+convert(nvarchar,@IsGroup)+' and Productid<>'+convert(nvarchar,@ProductID)+')'
				 
				exec sp_executesql @CodeSQL, @str1, @count1 OUTPUT 	
				IF (@count1>0)  
					RAISERROR('-116',16,1)
				--set @ProductCode=@tempCode  
			end 
			else
			begin
				IF @ProductID=0
				BEGIN 
					IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Isgroup=@IsGroup and [ProductCode]=@ProductCode)
						RAISERROR('-116',16,1)
				END
				ELSE
				BEGIN
					IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Isgroup=@IsGroup and [ProductCode]=@ProductCode AND ProductID <> @ProductID)
						RAISERROR('-116',16,1)
				END			
			end
		END
		
		--DUPLICATE CHECK
		IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0
		BEGIN
			IF @ProductID=0
			BEGIN
				IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Isgroup=@IsGroup and ProductName=@ProductName)
				BEGIN
					RAISERROR('-114',16,1)
				END
			END
			ELSE
			BEGIN
				IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE Isgroup=@IsGroup and  ProductName=@ProductName AND ProductID <> @ProductID)
				BEGIN
					RAISERROR('-114',16,1)
				END
			END
		END
		
		SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
		
		IF EXISTS(SELECT ProductID FROM INV_Product with(nolock) WHERE ProductID=@ProductID AND ParentID=0)
		BEGIN
			RAISERROR('-123',16,1)
		END    
				 
		SELECT @TempGuid=[GUID] FROM [INV_Product]  WITH(NOLOCK)   
		WHERE ProductID=@ProductID  

		IF(@TempGuid!=@Guid)  
		BEGIN  
			RAISERROR('-101',16,1)
		END  		  
		
		--Update CostCenter Extra Fields
		set @SQL='update COM_CCCCDATA
		SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@ProductID) + ' AND COSTCENTERID = 3 '
		exec(@SQL)
	
	set @Dimesion=0  
	IF @IsProductLinkDimension IS NULL OR @IsProductLinkDimension=0 OR @IsProductLinkDimension=''
	BEGIN
		if(@DimensionPrefValue is not null and @DimensionPrefValue<>'' and @IsLink=1)  
		begin  

			begin try  
				select @Dimesion=convert(INT,@DimensionPrefValue)  
			end try  
			begin catch  
				set @Dimesion=0   
			end catch  
			
			declare @NID INT, @CCIDAcc INT
			
			select @NID = ISNULL(CCNodeID,0), @CCIDAcc=CCID,@SelectedNodeID=ParentID  from INV_PRODUCT with(nolock) where ProductID=@ProductID 
				
			if(@Dimesion>0)  
			begin  
				declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)
				declare @NodeidXML nvarchar(max) 
				select @Table=Tablename from adm_features with(nolock) where featureid=@Dimesion
				declare @str nvarchar(max) 
				set @str='@Gid nvarchar(50) output' 
				set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' with(nolock) where NodeID='+convert(nvarchar,@NID)+')'
				 
				exec sp_executesql @NodeidXML, @str, @Gid OUTPUT 
				
				SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
				WHERE CostCenterID=3 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
					
				DECLARE @CCStatusID INT
				select  @CCStatusID =statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active'
				EXEC @return_value = [dbo].[spCOM_SetCostCenter]
				@NodeID = @NID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
				@Code = @ProductCode,
				@Name = @ProductName,
				@AliasName=@ProductName,
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=null,@NotesXML=NULL,
				@CostCenterID = @Dimesion,@CompanyGUID=@CompanyGUID,@GUID=@Gid,
				@UserName=@UserName,@RoleID=@RoleID,@UserID=@UserID,@CheckLink = 0
			 	
				Update INV_PRODUCT set CCID=@Dimesion, CCNodeID=@return_value where ProductID=@ProductID      
				DECLARE @CCMapSql nvarchar(max)
				set @CCMapSql='update COM_CCCCDATA  
				SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  WHERE NodeID = '+convert(nvarchar,@ProductID) + ' AND CostCenterID = 3' 
				EXEC (@CCMapSql)
				
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
			declare @LinkVariable nvarchar(max) ,@i INT,@cnt INT
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
						select @CCStatusID = statusid from com_status WITH(NOLOCK) where costcenterid=@CCID
						set @NID=0
						set @CCIDAcc=0 
						select @NID = CCNodeID, @CCIDAcc=CCID,@SelectedNodeID=ParentID  from INV_Product with(nolock) where ProductID=@ProductID
						iF(@CCIDAcc<>@CCID)
						BEGIN
							if(@NID>0)
							begin 
								Update INV_Product set CCID=0, CCNodeID=0 where ProductID=@ProductID
								
								set @CCMapSql='update COM_CCCCDATA  
								SET  CCNID'+convert(nvarchar,(@CCIDAcc-50000))+'=1
								WHERE NodeID = '+convert(nvarchar,@ProductID) + ' AND CostCenterID = 3' 
								EXEC (@CCMapSql)
								
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
						   						 
						select @Table=Tablename from adm_features with(nolock) where featureid=@CCID 
						set @str='@Gid nvarchar(50) output' 
						set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' with(nolock) where NodeID='+convert(nvarchar,@NID)+')'
						exec sp_executesql @NodeidXML, @str, @Gid OUTPUT 
						
						SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
						WHERE CostCenterID=3 AND RefDimensionID=@CCID AND NodeID=@SelectedNodeID 
						SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				
						EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
						@NodeID = @NID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
						@Code = @ProductCode,
						@Name = @ProductName,
						@AliasName=@ProductName,
						@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
						@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
						@CustomCostCenterFieldsQuery=NULL,@ContactsXML='',@NotesXML=NULL,
						@CostCenterID = @CCID,@CompanyGUID=@CompanyGUID,@GUID=@Gid,
						@UserName=@UserName,@RoleID=@RoleID,@UserID=@UserID, @CheckLink = 0
						
						
						if(@NID =0)
						begin 	
							--Link Dimension Mapping
							INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)
							values(3, @ProductID,0,0,@CCID,@return_value,'',newid(),@UserName, @dt,'Product')
					 	end
					 	
						Update INV_Product set CCID=@CCID, CCNodeID=@return_value where ProductID=@ProductID					
						
						set @CCMapSql='update COM_CCCCDATA  
						SET  CCNID'+convert(nvarchar,(@CCID-50000))+'='+CONVERT(NVARCHAR,@return_value)+'
						WHERE NodeID = '+convert(nvarchar,@ProductID) + ' AND CostCenterID = 3' 
						EXEC (@CCMapSql)
						
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
  
  
	--Update Main Table
	IF(@StaticFieldsQuery IS NOT NULL AND @StaticFieldsQuery <> '')
	BEGIN
		DECLARE @TEMPUOMID INT , @CurrentUOM INT
		if  @ProductID >0 and ((select isnull(ShowinQuickAdd,0) from adm_Costcenterdef with(nolock) where costcenterid=3 and syscolumnname='UOMID')=1 )
			SELECT @TEMPUOMID=UOMID FROM INV_Product with(nolock) WHERE PRODUCTID=@ProductID
		set @SQL='update INV_Product
		SET '+@StaticFieldsQuery+'[GUID]= NEWID(), [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE ProductID='+convert(NVARCHAR,@ProductID)
		exec(@SQL)
		--UOM Check 
		if ((select isnull(ShowinQuickAdd,0) from adm_Costcenterdef with(nolock) where costcenterid=3 and syscolumnname='UOMID')=1 )
		BEGIN
			if exists (select * from com_UOm where productid=@ProductID)
			BEGIN
				if not exists (select * from com_UOM with(nolock) where productid=@ProductID and
				 UOMID in (select UOMID from inv_product with(nolock) where productid=@ProductID))
				BEGIN
					delete from com_uom where productid=@ProductID
				END 
			END
			SELECT @CurrentUOM=UOMID FROM INV_Product with(nolock) WHERE PRODUCTID=@ProductID
			
			IF(@ProductID >0 AND @TEMPUOMID<>@CurrentUOM and EXISTS 
			(SELECT D.ProductID FROM INV_DocDetails D WITH(NOLOCK) 
			JOIN INV_PRODUCT P with(nolock) ON D.PRODUCTID=P.PRODUCTID AND D.UNIT=@TEMPUOMID
			WHERE P.ProductID=@ProductID AND @TEMPUOMID<>@CurrentUOM) AND @CurrentUOM<>-399)
			BEGIN
				RAISERROR('-540',16,1)
			END				
		END
	END
	ELSE
	BEGIN
		set @SQL='update INV_Product
		SET [GUID]= NEWID(), [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE ProductID='+convert(NVARCHAR,@ProductID)
		exec(@SQL)
	END
	
	--Product code update if code is Auto generated
	if(@ProductID>0 and @IsProductCodeAutoGen=1)
	begin
		update inv_Product set ProductCode=@ProductCode,codeprefix=@codeprefix,codenumber=@codenumber  WHERE ProductID=@ProductID   
	end
	
	--Update Extended
	IF(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <> '')
	BEGIN
		set @SQL='update INV_ProductExtended
		SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =@ModDate WHERE ProductID='+convert(NVARCHAR,@ProductID)
		EXEC sp_executesql @SQL,N'@ModDate float',@Dt
	END

	--Duplicate Check
	exec [spCOM_CheckUniqueCostCenter] @CostCenterID=3,@NodeID =@ProductID,@LangID=@LangID
	
	--Series Check
	declare @retSeries INT
	EXEC @retSeries=spCOM_ValidateCodeSeries 3,@ProductID,@LangID
	if @retSeries>0
	begin
		ROLLBACK TRANSACTION
		SET NOCOUNT OFF  
		RETURN -999
	end	

	--CHECK WORKFLOW
	SELECT @StatusID=StatusID from INV_Product with(nolock) where ProductID=@ProductID
	EXEC spCOM_CheckCostCentetWF 3,@ProductID,@WID,@RoleID,@UserID,@UserName,@StatusID output
	
	--CC CC MAP
	IF (@AssignCCCCData IS NOT NULL AND @AssignCCCCData <> '') 
	BEGIN
		DECLARE @CCCCCData xml
		SET @CCCCCData=@AssignCCCCData
		EXEC [spCOM_SetCCCCMap] 3,@ProductID,@CCCCCData,@UserName,@LangID
	END
	
	--Dimension History Data
	IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
		EXEC spCOM_SetHistory 3,@ProductID,@HistoryXML,@UserName  

	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')
		exec [spCOM_SetAttachments] 3,@ProductID,@AttachmentsXML,@UserName,@Dt
	
	IF (@StatusXML IS NOT NULL AND @StatusXML <> '')
		exec spCOM_SetStatusMap 3,@ProductID,@StatusXML,@UserName,@Dt

	if(select Value from ADM_GlobalPreferences with(nolock) where Name='POSEnable')='True'
	begin
		declare @SellingRateF float,@SellingRateG float
		select @SellingRateF=isnull(SellingRateF,0),@SellingRateG=isnull(SellingRateG,0) from INV_Product with(nolock) WHERE ProductID=@ProductID
		exec spDoc_SetStockCode 1,1,@ProductCode,@ProductID,null,@SellingRateF,@SellingRateG,null,@UserName
	end
	
	--Insert Notifications
	EXEC spCOM_SetNotifEvent 3,3,@ProductID,@CompanyGUID,@UserName,@UserID,@RoleID
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
--ROLLBACK TRANSACTION

SELECT * FROM [INV_Product] WITH(NOLOCK) WHERE ProductID=@ProductID
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID   

SET NOCOUNT OFF;  
RETURN @ProductID  
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		IF ISNUMERIC(ERROR_MESSAGE())=1
		BEGIN
			SELECT * FROM [INV_Product] WITH(NOLOCK) WHERE ProductID=@ProductID 
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		ELSE
			SELECT ERROR_MESSAGE() ErrorMessage
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
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
