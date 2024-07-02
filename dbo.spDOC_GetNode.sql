USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetNode]
	@CostCenterID [int],
	@Name [nvarchar](max),
	@IsCode [bit],
	@DocumentType [int],
	@Create [bit] = 1,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1,
	@NodeID [int] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @TEMPxml nvarchar(max),@IsCodeAutoGen bit,@RetVal int,@tabName nvarchar(100)
	if(@CostCenterID=3)
	begin
		if(@IsCode is not null and @IsCode=1)
			set @NodeID =(select top 1 ProductID from INV_Product with(nolock) where ProductCode=@Name)       
		else    
			set @NodeID =(select top 1 ProductID from INV_Product with(nolock) where ProductName=@Name)      
	end 
	ELSE if(@CostCenterID=2)
	begin
		 if(@Name='PactReservedAccount') 
		 BEGIN
			if(@DocumentType=17)    
				set @NodeID= -99    
			ELSE if(@DocumentType=16)    
				set @NodeID=  -100;    
			ELSE if(@DocumentType=21 or @DocumentType=29 )    
				set @NodeID=  -98;    
			ELSE if(@DocumentType=20 or @DocumentType=28 )    
				set @NodeID= -97 
			ELSE if(@DocumentType=3)      
				set @NodeID= -180      
			ELSE if(@DocumentType=8)      
				set @NodeID= -179      
			ELSE if(@DocumentType=13)      
				set @NodeID=  -178 
		 END
		 ELSE if(@IsCode is not null and @IsCode=1)
			set @NodeID =(select top 1 AccountID from ACC_Accounts with(nolock) where AccountCode=@Name and IsGroup=0)      
		 else    
			set @NodeID =(select top 1 AccountID from ACC_Accounts with(nolock) where AccountName=@Name and IsGroup=0)      
	end 
	ELSE if(@CostCenterID>50000)
	begin
		select @tabName=TableName from ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterID
		if(@IsCode is not null and @IsCode=1)
			SET @TEMPxml='set @NodeID =(select top 1 NodeID from '+@tabName+' with(nolock) where Code='''+@Name+''' and IsGroup=0)'
		else    
			SET @TEMPxml='set @NodeID =(select top 1 NodeID from '+@tabName+' with(nolock) where Name='''+@Name+''' and IsGroup=0)'
		
		EXEC sp_executesql @TEMPxml,N'@NodeID INT OUTPUT',@NodeID output
	end 


     IF(@Create=1 and (@NodeID IS NULL or @NodeID=0))      
     BEGIN   
		if(@IsCode is not null and @IsCode=1)
			set @IsCodeAutoGen=0
		ELSE	
			set @IsCodeAutoGen=1
			
		SET @TEMPxml='<XML><Row AccountName ="'+replace(replace(@Name,'&','&amp;'),'"','&quot;')+'" AccountCode ="'+replace(replace(@Name,'&','&amp;'),'"','&quot;')+'" '
		
		if(@CostCenterID=3)
		 SET @TEMPxml=@TEMPxml+' ExtraFields=" UOMID=1" '
		 
		 SET @TEMPxml=@TEMPxml+'   ></Row></XML>'

 		 EXEC @RetVal = [dbo].[spADM_SetImportData]      
		   @XML = @TEMPxml,     
		   @CCMapXML='',
		   @HistoryXML='' ,
		   @COSTCENTERID = @CostCenterID,      
		   @IsDuplicateNameAllowed = 1,      
		   @IsCodeAutoGen = @IsCodeAutoGen,      
		   @IsOnlyName = 1,      
		   @IsProductVehicle=null,
		   @IsUpdate=0,
		   @IsCode=null,
		   @Attachment=null,
		   @CompanyGUID = @CompanyGUID,      
		   @UserName = @UserName ,      
		   @UserID = @UserID, 
		   @RoleID=1,     
		   @LangID = @LangID 
		   
		   	if(@CostCenterID=3)
			begin
				if(@IsCode is not null and @IsCode=1)
					set @NodeID =(select top 1 ProductID from INV_Product with(nolock) where ProductCode=@Name and IsGroup=0)      
				else    
					set @NodeID =(select top 1 ProductID from INV_Product with(nolock) where ProductName=@Name and IsGroup=0)      
			end 
			ELSE if(@CostCenterID=2)
			begin
				if(@IsCode is not null and @IsCode=1)
					set @NodeID =(select top 1 AccountID from ACC_Accounts with(nolock) where AccountCode=@Name and IsGroup=0)      
				else    
					set @NodeID =(select top 1 AccountID from ACC_Accounts with(nolock) where AccountName=@Name and IsGroup=0)      
			end  
			ELSE if(@CostCenterID>50000)
			begin
				select @tabName=TableName from ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterID
				if(@IsCode is not null and @IsCode=1)
					SET @TEMPxml='set @NodeID =(select top 1 NodeID from '+@tabName+' with(nolock) where Code='''+@Name+''' and IsGroup=0)'
				else    
					SET @TEMPxml='set @NodeID =(select top 1 NodeID from '+@tabName+' with(nolock) where Name='''+@Name+''' and IsGroup=0)'
				
				EXEC sp_executesql @TEMPxml,N'@NodeID INT OUTPUT',@NodeID output
			end     
		 
	 end
GO
