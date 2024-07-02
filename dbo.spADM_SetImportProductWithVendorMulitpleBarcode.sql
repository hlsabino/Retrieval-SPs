USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportProductWithVendorMulitpleBarcode]
	@XML [nvarchar](max),
	@VendorXML [nvarchar](max) = '',
	@COSTCENTERID [bigint],
	@IsDuplicateNameAllowed [bit],
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

  
		--Declaration Section
		DECLARE	@return_value int,@failCount int, @Dt float 
		DECLARE @NodeID bigint, @Table NVARCHAR(50),@SQL NVARCHAR(max),@ParentGroupName NVARCHAR(200),@PK NVARCHAR(50)
		DECLARE @AccountCode nvarchar(max),@GUID nvarchar(max),@AccountName nvarchar(max),@AliasName nvarchar(max)
        DECLARE  @HasAccess BIT,@DATA XML,@Cnt INT,@I INT, @CCID INT , @VXML xml
      
		SET @DATA=@XML
		
		SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
		
		--SP Required Parameters Check
		IF @CompanyGUID IS NULL OR @CompanyGUID=''
		BEGIN
			RAISERROR('-100',16,1)
		END
 
			
		-- Create Temp Table
		DECLARE  @temptbl TABLE(ID int identity(1,1),
           [AccountCode] nvarchar(500)
           ,[AccountName] nvarchar(max)) 
	  
		INSERT INTO @temptbl ([AccountCode],[AccountName])          
		SELECT X.value('@AccountCode','nvarchar(500)')
           ,X.value('@AccountName','nvarchar(max)')
 		from @DATA.nodes('/XML/Row') as Data(X)
 	
 	
 	--SELECT * FROM @temptbl
		SELECT @I=1, @Cnt=count(ID) FROM @temptbl 
		set @failCount=0
		WHILE(@I<=@Cnt)  
		BEGIN
		begin try
				 	select @AccountCode    = ISNULL(AccountCode ,'')
					,@AccountName    =  AccountName  
					from  @temptbl where ID=@I
		    
		 	-- Update statements 
			IF  @IsUpdate=1
			BEGIN	 
				set @SQL='' 
				if(@COSTCENTERID=3)
				begin
				if( @IsCode is not null and @IsCode =0)
					set @NodeID= (Select  top 1 ProductID from INV_Product where ProductName=@AccountName) 
				else
					set @NodeID= (Select  top 1 ProductID from INV_Product where ProductCode=@AccountCode) 
				
				IF (@VendorXML IS NOT NULL AND @VendorXML <> '')
				BEGIN
					
					declare @VendorTable table(id int identity(1,1),VendorID bigint, AccountID bigint,Priorty bigint,LeadTime float,Barcode nvarchar(100),Volume FLOAT,Weight FLOAT,Remarks NVARCHAR(MAX),[Action] NVARCHAR(10))
					declare @VVendorID bigint,@VAccountID bigint,@VPriorty bigint,@VLeadTime float,@VBarcode nvarchar(100),@VVolume FLOAT,@VWeight FLOAT,@VRemarks NVARCHAR(MAX),@VAction nvarchar(10),@Vid bigint,@Vcnt bigint
					SET @VXML=@VendorXML
					
					declare @vtable table(id int identity(1,1),bar nvarchar(100))
					declare @VVid bigint,@VVcnt bigint,@VVbar nvarchar(100)

					insert into @VendorTable(VendorID,AccountID,Priorty,LeadTime,Barcode,Volume,Weight,Remarks,[Action])
					SELECT X.value('@VendorID','bigint'),X.value('@AccountID','BIGINT'),X.value('@Priority','INT'),X.value('@LeadTime','FLOAT'), X.value('@Barcode','NVARCHAR(100)'),X.value('@Volume','FLOAT'),X.value('@Weight','FLOAT'),X.value('@Remarks','NVARCHAR(MAX)'),X.value('@Action','NVARCHAR(10)')
					FROM @VXML.nodes('/VendorsXML/Row') as Data(X)
				
					set @Vid=1
					select @Vcnt=count(*) from @VendorTable
					--select * from @VendorTable
					while(@Vid<=@Vcnt)
					BEGIN
					
						select @VVendorID=VendorID,@VAccountID=AccountID,@VPriorty=Priorty,@VLeadTime=LeadTime,@VBarcode=Barcode,@VVolume=Volume,@VWeight=Weight,@VRemarks=Remarks,@VAction=[Action] from @VendorTable where id=@Vid
						--If Action is NEW then insert new Vedors
						if(@VAction=ltrim(rtrim('NEW')))
						BEGIN
				
						IF NOT EXISTS (SELECT * FROM INV_ProductVendors WHERE ProductID=@NodeID AND AccountID =@VAccountID)
						BEGIN
							if(@VPriorty is null)
								set @VPriorty=0
							--DELETE FROM INV_ProductVendors WHERE ProductID=@NodeID AND AccountID =@VAccountID
				
							INSERT INTO INV_ProductVendors(ProductID,AccountID,Priority,LeadTime,Volume,Weight,Remarks,
								CompanyGUID,GUID,CreatedBy,CreatedDate)
							SELECT @NodeID,@VAccountID,@VPriorty,@VLeadTime,@VVolume,@VWeight,@VRemarks,
								@CompanyGUID,newid(),@UserName,@Dt 
							set @VVendorID=scope_identity() 		 
				
							if exists(select * from INV_ProductBarcode where VenderID=@VAccountID and productID=@NodeID)
							BEGIN
								delete from INV_ProductBarcode where VenderID=@VAccountID and productID=@NodeID
							END 
							delete from @vtable 
							insert into @vtable(bar)
							exec SPSplitString @VBarcode,','
							select @VVid=MIN(id),@VVcnt=MAX(id) from @vtable
							--select * from @vtable
							while(@VVid<=@VVcnt)
							BEGIN  
								select @VVbar=bar from @vtable where id=@VVid  
								if exists(select * from INV_ProductBarcode where Barcode=@VVbar and @VVbar is not null and @VVbar<>'' AND VENDERID<>@VAccountID AND ProductID<>@NodeID)
								BEGIN
									raiserror('-130',16,1)
								END 
							--	select @VVbar,@VVid,@VVcnt
								insert into INV_ProductBarcode(Barcode,VenderID,UnitID,ProductID,CompanyGUID,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
								select @VVbar,@VAccountID,0,@NodeID,@CompanyGUID,newid(),@UserName,@Dt,@UserName,@Dt 
								set @VVid=@VVid+1
							END 
						END
						 END
						set @Vid=@Vid+1;
					END	
				END 
				end 
			END 
			
	 		End Try
			 Begin Catch 
				 select ERROR_MESSAGE()
				set @failCount=@failCount+1
			end Catch 
			set @I=@I+1 
	end

COMMIT TRANSACTION  
--ROLLBACK TRANSACTION  


if(@COSTCENTERID=3)
begin
	SET @SQL='SELECT ProductID NodeID,ProductName Name FROM INV_PRODUCT WITH(nolock)where ProductName in ( 
	SELECT X.value(''@AccountName'',''nvarchar(500)'')
	from @sml.nodes(''/XML/Row'') as Data(X))'

	EXEC sp_executesql @SQL, N'@sml xml', @XML	
end 

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;   
RETURN @failCount  
END TRY  
BEGIN CATCH  
select 'asdf'

	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountCode=@AccountCode  
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
