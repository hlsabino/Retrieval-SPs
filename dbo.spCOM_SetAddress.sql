USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetAddress]
	@CostCenterID [int],
	@NodeID [int],
	@AddressXML [nvarchar](max),
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @XML XML, @Dt FLOAT

	--Inserts Multiple Address  
	IF (@AddressXML IS NOT NULL AND @AddressXML <> '')  
	BEGIN  
		SET @Dt=CONVERT(FLOAT,GETDATE())
		SET @XML=@AddressXML  
		DECLARE @ContactQueryXML XML,@ExtraFields nvarchar(max),@UpdateSql NVARCHAR(MAX), @CCFields nvarchar(max),@PrimaryContactID int 
		SET @ContactQueryXML=@AddressXML
		DECLARE @CONTACTSTABLE TABLE(ID INT IDENTITY(1,1),ACTIONNAME NVARCHAR(300),CONTACTTYPE INT,CONTACTID INT,STATICIFLEDS NVARCHAR(MAX),ALPHAFIELDS NVARCHAR(MAX),
			CCFIELDS NVARCHAR(MAX),IsDefault bit)	
			
		DECLARE @COUNT INT,@I INT,@ACTION NVARCHAR(300),@CONTACTID INT,@TEMPCONTACTTYPE INT,@IsPrimarAddressFound BIT,@IsDefault bit
		INSERT INTO @CONTACTSTABLE
		SELECT X.value('@Action','NVARCHAR(30)') ,ISNULL(X.value('@AddressTypeID','NVARCHAR(300)'),0),ISNULL(X.value('@AddressID','NVARCHAR(300)'),0) ,X.value('@StaticFields','NVARCHAR(max)') ,X.value('@ExtraTextFields','NVARCHAR(max)')
		,X.value('@CCFields','NVARCHAR(max)'),isnull(X.value('@IsDefault','bit'),0)
		from @ContactQueryXML.nodes('/Data/Row') as Data(X)
		SELECT @COUNT=COUNT(*),@I=1,@IsPrimarAddressFound=0 FROM @CONTACTSTABLE
		
		if(SELECT count(*) FROM @CONTACTSTABLE where IsDefault=1 and CONTACTTYPE=1)>0
			update COM_Address set IsDefault=0 where FeatureID=@CostCenterID and FeaturePK=@NodeID and AddressTypeID=1
		if(SELECT count(*) FROM @CONTACTSTABLE where IsDefault=1 and CONTACTTYPE=2)>0
			update COM_Address set IsDefault=0 where FeatureID=@CostCenterID and FeaturePK=@NodeID and AddressTypeID=2
		if(SELECT count(*) FROM @CONTACTSTABLE where IsDefault=1 and CONTACTTYPE=3)>0
			update COM_Address set IsDefault=0 where FeatureID=@CostCenterID and FeaturePK=@NodeID and AddressTypeID=3		
		
		WHILE @I<=@COUNT
		BEGIN
			SELECT @ACTION=ACTIONNAME,@TEMPCONTACTTYPE=CONTACTTYPE,@CONTACTID=CONTACTID,@AddressXML=STATICIFLEDS ,@ExtraFields=ALPHAFIELDS,
			@CCFields=CCFIELDS,@IsDefault=IsDefault FROM @CONTACTSTABLE WHERE ID=@I
			--SELECT @TEMPCONTACTTYPE,@ACTION,@CONTACTID,@AddressXML,@ExtraFields,@CCFields
			IF @TEMPCONTACTTYPE=1
			BEGIN
				IF @IsPrimarAddressFound=0
				BEGIN
					IF @ACTION!='DELETE'
						SET @IsPrimarAddressFound=1
				END
				ELSE
				BEGIN
					SET @TEMPCONTACTTYPE=2
				END
			END
			
			--SELECT @ACTION,@CONTACTID,@ContactQuery,@ExtraFields,@CCFields 
			IF @ACTION='NEW' AND (@CONTACTID=0 OR @CONTACTID IS NULL)
			BEGIN
				INSERT INTO COM_Address(AddressTypeID,FeatureID,FeaturePK,IsDefault,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
				VALUES (@TEMPCONTACTTYPE,@CostCenterID,@NodeID,@IsDefault,NEWID(),NEWID(),@UserName,@Dt)
				SET @PrimaryContactID=SCOPE_IDENTITY()
				
			    IF (@AddressXML IS NOT NULL AND @AddressXML <> '')  
				BEGIN    
					set @UpdateSql='update [COM_Address]  
					SET '+@AddressXML+',[ModifiedBy] ='''+ @UserName  
					+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE AddressID='+convert(nvarchar,@PrimaryContactID)     
					--SELECT @UpdateSql 
					exec(@UpdateSql) 
					--PRINT @UpdateSql
				END
				
				IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
				BEGIN 
					set @UpdateSql='update COM_Address
					SET '+@ExtraFields+' WHERE AddressID ='+convert(nvarchar,@PrimaryContactID)	
					exec(@UpdateSql)
					--PRINT @UpdateSql
				END
				
				IF (@CCFields IS NOT NULL AND @CCFields <> '')  
				BEGIN 
					set @UpdateSql='UPDATE COM_Address
					SET '+@CCFields+' 
					WHERE AddressID='+convert(nvarchar,@PrimaryContactID)+''
					exec(@UpdateSql)
				END
			END
			ELSE IF @ACTION='MODIFY' AND @CONTACTID>0
			BEGIN
				IF (@AddressXML IS NOT NULL AND @AddressXML <> '')  
				BEGIN 
					set @UpdateSql='update [COM_Address]  
					SET '+@AddressXML+',AddressTypeID='+convert(nvarchar,@TEMPCONTACTTYPE)+',IsDefault='+convert(nvarchar,@IsDefault) +',[ModifiedBy] ='''+ @UserName  
					+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE AddressID='+convert(nvarchar,@CONTACTID)     
					--SELECT @UpdateSql 
					exec(@UpdateSql) 
					PRINT @UpdateSql
				END
				
				IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
				BEGIN 
					set @UpdateSql='update COM_Address
					SET '+@ExtraFields+', [ModifiedBy] ='''+ @UserName
					+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE AddressID ='+convert(nvarchar,@CONTACTID)	
					exec(@UpdateSql)
					--PRINT @UpdateSql
				END
					
				IF (@CCFields IS NOT NULL AND @CCFields <> '')  
				BEGIN 
					set @UpdateSql='UPDATE COM_Address
					SET '+@CCFields+' 
					WHERE AddressID='+convert(nvarchar,@CONTACTID)+' '
					exec(@UpdateSql)
				END
			END
			ELSE IF @ACTION='DELETE' AND @CONTACTID>0
			BEGIN 
				DELETE FROM COM_Address WHERE AddressID=@CONTACTID 
			END	
			SET @I=@I+1	
		END
		 
		INSERT INTO COM_Address_History 
		SELECT * FROM COM_Address with(nolock)
		WHERE FeatureID=@CostCenterID AND FeaturePK=@NodeID
	END
	
	if @CostCenterID=2 and not exists(select * from COM_Address with(nolock) where FeatureID=@CostCenterID AND FeaturePK=@NodeID and AddressTypeID=1)
	begin
		insert into COM_Address(ContactPerson,AddressTypeID,FeatureID,FeaturePK,GUID,CreatedBy,CreatedDate)
		select AccountName,1,2,AccountID,'GUID',A.CreatedBy,A.CreatedDate from ACC_Accounts A  with(nolock)
		where A.AccountID=@NodeID
	end
	
RETURN @CONTACTID
GO
