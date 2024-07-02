USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetCustomizeLead]
	@CCID [int] = 0,
	@Mode [int],
	@LinkXML [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@USERID [int],
	@LANGID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section  	
	DECLARE @XML xml,@I INT,@Cnt INT,@LinkDefID int,@linkedCCID INT
	DECLARE @tabTrans table(id int identity(1,1),ccid INT)
	DECLARE @tabXML table(id int identity(1,1),ccid INT,Base INT,Link INT)
	 
	SET @XML=@LinkXML              
    
    INSERT INTO @tabXML
    select X.value('@CostCenterIDLinked','INT'),X.value('@CostCenterColIDBase','INT'),X.value('@CostCenterColIDLink','INT') 
    from @XML.nodes('/Xml/Row') as Data(X)
   
	IF EXISTS (SELECT ccid,Link FROM @tabXML GROUP BY ccid,Link HAVING COUNT(*)>1)
    BEGIN
		DECLARE @MSG NVARCHAR(MAX)='' 
		SELECT @MSG='Duplicate Mapping at '+C.CostCenterName+':'+C.UserColumnName FROM @tabXML T
		JOIN ADM_CostCenterDef C WITH(nolock) on T.Link=C.CostCenterColID  AND C.CostCenterID=T.ccid
		GROUP BY T.ccid,T.Link,C.CostCenterName,C.UserColumnName
		HAVING COUNT(*)>1
		
		RAISERROR(@MSG,16,1)
    END
     
	DELETE FROM COM_DocumentLinkDetails where DocumentLinkDefID in (
	select DocumentLinkDefID FROM [COM_DocumentLinkDef] WITH(NOLOCK)            
	WHERE CostCenterIDBase=@CCID)   	

	DELETE FROM [COM_DocumentLinkDef]              
	WHERE CostCenterIDBase=@CCID
	 
	if(@LinkXML IS NOT NULL AND @LinkXML <>'')              
	BEGIN              

		insert into @tabTrans
		select distinct ccid from @tabXML

		select @cnt=COUNT(*),@i=1 from @tabTrans
		while(@i<=@cnt)
		begin
			select  @linkedCCID=ccid from @tabTrans Where  id=@i
			INSERT INTO [COM_DocumentLinkDef]([CostCenterIDLinked],[CostCenterIDBase],[CostCenterColIDBase],[CostCenterColIDLinked],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],Mode)			select @linkedCCID,@CCID,22777,111,@CompanyGUID,'GUID',@UserName,CONVERT(FLOAT,GETDATE()),@Mode 

			set @LinkDefID=scope_identity()	

			insert into COM_DocumentLinkDetails(DocumentLinkDeFID,CostCenterColIDBase,CostCenterColIDLinked,CompanyGUID,[GUID],CreatedBy,CreatedDate)
			select @LinkDefID,Base,Link,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE())
			from @tabXML 
			where ccid=@linkedCCID
			
			set @i=@i+1
		END	
	END

COMMIT TRANSACTION    
--ROLLBACK TRANSACTION
SET NOCOUNT OFF; 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
RETURN 1  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN		
		IF ISNUMERIC(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		ELSE
			SELECT ERROR_MESSAGE() ErrorMessage
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
