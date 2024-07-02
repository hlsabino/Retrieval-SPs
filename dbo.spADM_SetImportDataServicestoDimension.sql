USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportDataServicestoDimension]
	@XML [nvarchar](max),
	@COSTCENTERID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON	
		--Declaration Section  fgsdgfsd gsdfg fsdg
		DECLARE	@return_value int,@failCount int
		DECLARE @NodeID INT, @SQL NVARCHAR(max)
		DECLARE @AccountName nvarchar(max), @LinkFields NVARCHAR(MAX), @LinkOption NVARCHAR(MAX),@Dt float
		
		DECLARE @DATA XML,@Cnt INT,@I INT
	    SET @DATA=@XML
		SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
		
		--SP Required Parameters Check
		IF @CompanyGUID IS NULL OR @CompanyGUID=''
		BEGIN
			RAISERROR('-100',16,1)
		END
	 
		-- Create Temp Table
		CREATE TABLE #temptbl(ID int identity(1,1)
           ,[AccountName] nvarchar(max)
           ,LinkFields nvarchar(max), LinkOption nvarchar(max))  
		   
		INSERT INTO #temptbl
           ([AccountName]
           ,LinkFields, LinkOption)          
		SELECT X.value('@AccountName','nvarchar(max)')
          ,isnull(X.value('@LinkFields','nvarchar(max)'),'')
			,isnull(X.value('@LinkOption','nvarchar(max)'),'')
			
 		from @DATA.nodes('/XML/Row') as Data(X)
		
		SELECT @I=1, @Cnt=count(ID) FROM #temptbl 
		set @failCount=0
		WHILE(@I<=@Cnt)  
		BEGIN
		begin try
				 	select @AccountName    =  AccountName  
					,@LinkFields=LinkFields
					,@LinkOption=LinkOption
					from  #temptbl where ID=@I
	  
			if(@LinkOption is not null and @LinkOption <>'')
				set @LinkOption ='<XML><Row LinkedProductID=''-1''  '+ @LinkOption+' Qty=''0'' Rate=''0'' />'
			--<Row  LinkedProductID="-1"  CostCenterID="50029" NodeID="14"/>

	 		if(@LinkFields is not null and @LinkFields<>'')
			begin
			
				if  exists(select ProductID from dbo.INV_Product  with(nolock) where ProductName=@AccountName)
				begin
					set @NodeID=(select top 1 ProductID from dbo.INV_Product with(nolock) where ProductName=@AccountName)
				end 
			    set @LinkFields =@LinkOption +'<Row RowNo=''1'' LinkedProductID=''0'' '+ @LinkFields+' Qty=''0'' Rate=''0'' /></XML>'
		 		print @LinkFields
		 		 	--link products based on dimension
				EXEC [spINV_SetLinkedProducts] @LinkFields,@CompanyGUID,@UserName,@UserID,@LangID 
 	  		end
 		 
			End Try
			 Begin Catch
				 
			end Catch
			 
			set @I=@I+1

	end

COMMIT TRANSACTION  
--ROLLBACK TRANSACTION  


if(@COSTCENTERID=3)
begin
	SELECT ProductID NodeID,ProductName Name FROM INV_Product WITH(nolock)where ProductName in ( 
	SELECT X.value('@AccountName','nvarchar(500)')
	from @DATA.nodes('/XML/Row') as Data(X))

end
 	 

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
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
