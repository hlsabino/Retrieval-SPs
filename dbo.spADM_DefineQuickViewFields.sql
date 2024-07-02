USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DefineQuickViewFields]
	@QID [bigint],
	@QName [nvarchar](100),
	@CostCenterID [bigint],
	@ColumnsXML [nvarchar](max),
	@ShowInCC [nvarchar](max),
	@Groups [nvarchar](max),
	@Roles [nvarchar](max),
	@Users [nvarchar](max),
	@LastPRateDocs [nvarchar](1000),
	@LastSRateDocs [nvarchar](1000),
	@CompanyGUID [varchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section
	DECLARE @TempGuid nvarchar(50),@HasAccess bit,@ListViewID BIGINT,@NEWID NVARCHAR(50)
	DECLARE @Dt float,@XML xml,@I int,@Cnt int,@CostCenterColID BIGINT
	DECLARE @TblApp AS TABLE(G BIGINT NOT NULL DEFAULT(0),R BIGINT NOT NULL DEFAULT(0),U BIGINT NOT NULL DEFAULT(0))
	DECLARE @TblDocs AS TABLE(D BIGINT NOT NULL DEFAULT(0))

	--User acces check 
	BEGIN
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,28,1)
	END
	  
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END
	
	IF @QID=0
	BEGIN
		IF EXISTS (SELECT QID FROM ADM_QuickViewDefn WITH(nolock) WHERE CostCenterID=@CostCenterID AND QName=@QName) 
		BEGIN  
			RAISERROR('-112',16,1)  
		END  
		
		SELECT @QID=MAX(QID)+1 FROM ADM_QuickViewDefn WITH(nolock)
	END
	ELSE
	BEGIN
		IF EXISTS (SELECT QID FROM ADM_QuickViewDefn WITH(nolock) WHERE CostCenterID=@CostCenterID AND QID!=@QID AND QName=@QName) 
		BEGIN  
			RAISERROR('-112',16,1)  
		END  
	
		DELETE FROM ADM_QuickViewDefnUserMap WHERE QID=@QID
		DELETE FROM ADM_QuickViewDefn WHERE QID=@QID
	END

	SET @NEWID=NEWID()
	SET @Dt=convert(float,getdate())--Getting Current Date
	
	--INSERT COLUMNS XML
	SET @XML=@ColumnsXML

	insert into ADM_QuickViewDefn(QID,QName,CostCenterID,CostCenterColID,ColumnOrder,
			LastPRateDocs,LastSRateDocs,Param1,CompanyGUID,GUID,CreatedBy,CreatedDate,Description)
	SELECT @QID,@QName,@CostCenterID,X.value('@CostCenterColID','BIGINT'),X.value('@ColumnOrder','int'),
		@LastPRateDocs,@LastSRateDocs,X.value('@LastValueField','BIGINT'),@CompanyGUID,@NEWID,@UserName,@Dt,X.value('@Description','Nvarchar(500)')
	from @XML.nodes('/XML/Row') as Data(X)

	--INSERT MAPPINGS
	INSERT INTO @TblDocs(D)
	EXEC [SPSplitString] @ShowInCC,','
	
	INSERT INTO @TblApp(G)
	EXEC [SPSplitString] @Groups,','

	INSERT INTO @TblApp(R)
	EXEC [SPSplitString] @Roles,','

	INSERT INTO @TblApp(U)
	EXEC [SPSplitString] @Users,','

	INSERT INTO ADM_QuickViewDefnUserMap(QID,ShowCCID,GroupID,RoleID,UserID)
	SELECT @QID,D,G,R,U
	FROM @TblApp,@TblDocs
	ORDER BY D,U,R,G

COMMIT TRANSACTION  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;  
RETURN @QID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN 
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
