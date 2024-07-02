USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDimensionMap]
	@ProfileID [int],
	@ProfileName [nvarchar](200),
	@DataXml [nvarchar](max),
	@DefXml [nvarchar](max),
	@DepXml [nvarchar](max) = '',
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](200),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
	
	DECLARE @ErrorNumber INT
	IF(@ProfileID<>0 AND @ProfileName='Delete')
	BEGIN
		SET @ErrorNumber=102
		DECLARE @I INT,@CNT INT,@CostCenterID INT,@PrefValue nvarchar(MAX)
		declare @table table(ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT,PrefValue nvarchar(MAX))  
		--insert into @table  
		--SELECT CostCenterID,PrefValue FROM COM_DocumentPreferences WITH(NOLOCK) 
		--WHERE PrefName='DefaultProfileID' AND PrefValue IS NOT NULL AND  PrefValue<>'' 
		
		--SELECT @I=1,@CNT=COUNT(*) FROM @table
		--WHILE @I<=@CNT
		--BEGIN
			
		--	SELECT @CostCenterID=CostCenterID,@PrefValue=PrefValue FROM @table WHERE ID=@I
		--	DELETE FROM @table WHERE ID=@I
			
		--	insert into @table(PrefValue) 
		--	exec SPSplitString @PrefValue,',' 
			
		--	UPDATE @table SET CostCenterID=@CostCenterID WHERE CostCenterID IS NULL
			
		--	SET @I=@I+1

		--	--

		--	--
		--END

declare @ProfileCC nvarchar(max),@PXML XML,@K INT,@CNT_1 int;
declare @J INT,@CNT1 INT
declare @cctable table(ID INT IDENTITY(1,1),ProID nvarchar(50),ccid bigint) 
declare @Pccid int;
declare @cctableMAIN table(ID INT IDENTITY(1,1),ProfileCC nvarchar(MAX),ccid bigint) 
declare @IncludeCC nvarchar(max)
		
		INSERT INTO @cctableMAIN
			SELECT prefvalue,CostCenterID from com_documentpreferences WITH(NOLOCK) where 		 
			PrefName='DefaultProfileID' AND PrefValue IS NOT NULL AND  PrefValue<>'' 
		
		SET @J=1
		SELECT  @CNT1=COUNT(*) FROM @cctableMAIN	
		 
		WHILE (@J<=@CNT1)
		BEGIN
		 
			SET @ProfileCC=''
			SELECT @ProfileCC =ProfileCC,@Pccid=ccid FROM  @cctableMAIN WHERE ID=@J
			IF(ISNULL(@ProfileCC,'')<>'')
			BEGIN				
				create table #Profiletable(ID INT IDENTITY(1,1),wef datetime,tilldate datetime,profileid NVARCHAR(50)) 
				set @PXML=@ProfileCC				
				INSERT INTO #Profiletable      
				SELECT     
					X.value('@WEFDate','DateTime')       
					,X.value('@TillDate','DateTime')
					,X.value('@ProfileID','INT')
				from @PXML.nodes('/DimensionDefProfile/Row') as Data(X) 				
				SET @K=1
				SELECT  @CNT_1=COUNT(*) FROM #Profiletable		 
				set @IncludeCC=''''
				WHILE (@K<=@CNT_1)
				BEGIN
						insert into @cctable(ProID,ccid) 
						Select  profileid,@Pccid FROM #Profiletable WHERE ID=@K
			 
				SET @K=@K+1
				END
			END
		SET @J=@J+1			
		drop table #Profiletable
		END			
		IF exists (SELECT * FROM @cctable where ProID=convert(nvarchar,@ProfileID))
		BEGIN
			select TOP 1 @PrefValue='Profile used in Document Definition of "'+DocumentName+'"' from adm_documenttypes with(nolock) 
			where CostcenterID IN (SELECT CostcenterID FROM @cctable where ProID=convert(nvarchar,@ProfileID))
			RAISERROR(@PrefValue,16,1)
		END 
		ELSE
		BEGIN
			delete from [COM_DimensionMappings]	 
			where [ProfileID]=@ProfileID
		END
	END
	ELSE
	BEGIN
		SET @ErrorNumber=100
		Declare @XML XML,@dt float,@sql nvarchar(max)
	  --SP Required Parameters Check  
		set @dt=CONVERT(float,getdate())

		SET @XML=@DataXml
		IF(@ProfileID=0)
		BEGIN
			SELECT @ProfileID=ISNULL(MAX(ProfileID),0) +1 FROM [COM_DimensionMappings] WITH(NOLOCK)
		END
		ELSE
		BEGIN
			delete from [COM_DimensionMappings]	 
			where [ProfileID]=@ProfileID and
			DimensionMappingsID not in (select X.value('@DimMapID','INT') 
			from @XML.nodes('/XML/Row') as Data(X)  
			where X.value('@DimMapID','INT')>0)
		END
	  	 
		set @sql='INSERT INTO [COM_DimensionMappings]
			   ([ProfileID]
			   ,[ProfileName]
			   ,[ProductID]
			   ,[AccountID]'
	           
		select @sql=@sql+','+name from sys.columns
		where object_id=object_id('COM_DimensionMappings')
		and name like 'CCNID%'
		  
		select @sql=@sql+'   
			   ,[alpha1]
			   ,[alpha2]
			   ,[alpha3]
			   ,[alpha4]
			   ,[alpha5]
			   ,[DefXml]
			   ,[CompanyGUID]
			   ,[GUID]           
			   ,[CreatedBy]
			   ,[CreatedDate]
			   ,[DepXml]) select '+convert(nvarchar,@ProfileID)+','''+@ProfileName+''' ,isnull(X.value(''@ProductID'',''INT''),1)
			   ,isnull(X.value(''@AccountID'',''INT''),1)'
	    
		select @sql=@sql+',isnull(X.value(''@'+name+''',''INT''),1)' from sys.columns
		where object_id=object_id('COM_DimensionMappings')
		and name like 'CCNID%' 
	  		
   		set @sql=@sql+'   
			   ,X.value(''@alpha1'',''nvarchar(max)'')
			   ,X.value(''@alpha2'',''nvarchar(max)'')
			   ,X.value(''@alpha3'',''nvarchar(max)'')
			   ,X.value(''@alpha4'',''nvarchar(max)'')
			   ,X.value(''@alpha5'',''nvarchar(max)'')
			   ,'''+@DefXml+'''
			   ,'''+@CompanyGUID+'''
			   ,NEWID()           
			   ,'''+@UserName+'''
			   ,'+convert(nvarchar(max),@dt)+'
			   ,'''+@DepXml+'''           
				from @XML.nodes(''/XML/Row'') as Data(X)  
				where X.value(''@DimMapID'',''INT'')=0  
	  
	  UPDATE [COM_DimensionMappings]
	   SET [ProfileName] = '''+@ProfileName+'''
		  ,[ProductID] = isnull(X.value(''@ProductID'',''INT''),1)
		  ,[AccountID] =isnull(X.value(''@AccountID'',''INT''),1)'
	     
		 select @sql=@sql+','+name+'=isnull(X.value(''@'+name+''',''INT''),1)' from sys.columns
		where object_id=object_id('COM_DimensionMappings')
		and name like 'CCNID%'  
	      
		   select @sql=@sql+'
		  ,[alpha1] = X.value(''@alpha1'',''nvarchar(max)'')
		  ,[alpha2] = X.value(''@alpha2'',''nvarchar(max)'')
		  ,[alpha3] = X.value(''@alpha3'',''nvarchar(max)'')
		  ,[alpha4] = X.value(''@alpha4'',''nvarchar(max)'')
		  ,[alpha5] = X.value(''@alpha5'',''nvarchar(max)'')
		  ,[DefXml] = '''+@DefXml+'''
		  ,[DepXml]='''+@DepXml+'''
		  from @XML.nodes(''/XML/Row'') as Data(X) 
		  WHERE DimensionMappingsID=X.value(''@DimMapID'',''INT'')
		  and X.value(''@DimMapID'',''INT'')>0'
		  
		  exec sp_executesql @sql,N'@XML xml',@XML
	END

COMMIT TRANSACTION   
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=@ErrorNumber AND LanguageID=@LangID 
RETURN @ProfileID
END TRY  
BEGIN CATCH    
	--Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		if isnumeric(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		else
			SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber
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
