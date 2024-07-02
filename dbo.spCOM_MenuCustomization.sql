USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_MenuCustomization]
	@Data [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY
SET NOCOUNT ON;  
	
	--SP Required Parameters Check
	IF @UserID IS NULL OR @UserID=''
	BEGIN
		RAISERROR('-100',16,1)
	END
	 
	DECLARE @XML XML
	SET @XML=@Data
	
	UPDATE COM_LANGUAGERESOURCES  
    SET RESOURCEDATA=X.value('@DisplayName','NVARCHAR(500)') ,
    RESOURCENAME=X.value('@DisplayName','NVARCHAR(500)') 
	FROM COM_LANGUAGERESOURCES C WITH(NOLOCK)   
	INNER JOIN @XML.nodes('/XML/Row') as Data(X) ON convert(bigint,X.value('@DisplayNameKey','bigint'))=C.RESOURCEID  
	WHERE LANGUAGEID=@LangID
	 
	UPDATE ADM_RIBBONVIEW  
    SET ScreenName=X.value('@DisplayName','NVARCHAR(500)')   
	FROM ADM_RIBBONVIEW C WITH(NOLOCK)   
	INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
	ON convert(bigint,X.value('@DisplayNameKey','bigint'))=C.ScreenResourceID  

	UPDATE COM_LANGUAGERESOURCES  
    SET RESOURCEDATA=X.value('@DisplayName','NVARCHAR(500)') ,
    RESOURCENAME=X.value('@DisplayName','NVARCHAR(500)') 
	FROM COM_LANGUAGERESOURCES C WITH(NOLOCK)   
	INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
	ON convert(bigint,X.value('@DisplayNameResourceID','bigint'))=C.RESOURCEID  
	and X.value('@DisplayNameResourceID','bigint') is not null 
	WHERE LANGUAGEID=@LangID
	
	UPDATE ADM_RIBBONVIEW  
    SET DisplayName=X.value('@DisplayName','NVARCHAR(500)')   
	FROM ADM_RIBBONVIEW C WITH(NOLOCK)  
	INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
	ON convert(bigint,X.value('@DisplayNameResourceID','bigint'))=C.DisplayNameResourceID 
	and X.value('@DisplayNameResourceID','bigint') is not null
	 
	UPDATE ADM_RIBBONVIEW  
    SET ShowInWeb=X.value('@ShowInWeb','INT'),
	ShowInMobile=X.value('@ShowInMobile','INT'),
	IsMobile=X.value('@ShowInMobile','INT') ,
	ColumnOrder=X.value('@ColumnOrder','int'),
	IsOffLine=X.value('@IsOffLine','int')
	FROM ADM_RIBBONVIEW C WITH(NOLOCK) 
	INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
	ON convert(bigint,X.value('@RibbonViewID','bigint'))=C.RibbonViewID
	AND X.value('@TabID','bigint') is null AND X.value('@GroupID','bigint') is null
	
	DECLARE @TAB TABLE (ID INT IDENTITY(1,1),RibbonViewID BIGINT,TabID INT,GroupID INT,DrpID INT)

	INSERT INTO @TAB
	SELECT X.value('@RibbonViewID','bigint'),X.value('@TabID','int'),X.value('@GroupID','int'),X.value('@DrpID','int')
	FROM @XML.nodes('/XML/Row') as Data(X) 
	WHERE X.value('@TabID','int') is not null AND X.value('@GroupID','int') is not null
	
	DECLARE @I INT,@COUNT INT,@RibbonViewID BIGINT,@TabID INT,@GroupID INT,@DrpID INT
	SELECT @I=1,@COUNT=COUNT(*) FROM @TAB

	WHILE @I <= @COUNT
	BEGIN
		SELECT @RibbonViewID=RibbonViewID,@TabID=TabID,@GroupID=GroupID,@DrpID=DrpID FROM @TAB WHERE ID=@I
		
		IF ((SELECT COUNT(*) FROM ADM_RIBBONVIEW RV1 WITH(NOLOCK) 
		INNER JOIN ADM_RIBBONVIEW RV2 WITH(NOLOCK) ON RV2.TabID=RV1.TabID AND RV2.GroupID=RV1.GroupID
		WHERE RV2.RibbonViewID=@RibbonViewID)>1) 
		BEGIN
			UPDATE RV SET RV.TabID=T.TabID,RV.GroupID=T.GroupID,RV.DrpID=@DrpID
			,RV.TabName=T.TabName,RV.GroupName=T.GroupName
			,RV.TabResourceID=T.TabResourceID,RV.GroupResourceID=T.GroupResourceID,RV.DrpResourceID=T.DrpResourceID
			,RV.TabOrder=T.TabOrder, RV.GroupOrder=T.GroupOrder
			,RV.TabKeyTip=T.TabKeyTip,RV.GroupKeyTip=T.GroupKeyTip,RV.DrpKeyTip=T.DrpKeyTip
			,RV.ImageType=T.ImageType
			FROM ADM_RibbonView RV,(SELECT TOP 1 * FROM ADM_RibbonView WITH(NOLOCK) WHERE TabID=@TabID AND GroupID=@GroupID) AS T
			WHERE RV.RibbonViewID=@RibbonViewID
		END
		SET @I=@I+1
	END

COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
 SET NOCOUNT OFF;  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=104 AND LanguageID=@LangID    
RETURN 1  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN 
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
