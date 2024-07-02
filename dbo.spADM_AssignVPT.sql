USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_AssignVPT]
	@Type [int],
	@DocPrintLayoutID [bigint],
	@Groups [nvarchar](max),
	@Roles [nvarchar](max),
	@Users [nvarchar](max),
	@Locations [nvarchar](max),
	@BasedOn [nvarchar](max),
	@LocationWhere [nvarchar](max) = null,
	@DivisionWhere [nvarchar](max) = null,
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON; 
	--Declaration Section  
	DECLARE @HasAccess BIT,@Dt FLOAT
	DECLARE @TblApp AS TABLE(G BIGINT NOT NULL DEFAULT(0),R BIGINT NOT NULL DEFAULT(0),U BIGINT NOT NULL DEFAULT(0),CCNID2 BIGINT NOT NULL DEFAULT(0),BasedOn BIGINT NOT NULL DEFAULT(0))

	SET @Dt=CONVERT(FLOAT,GETDATE())

	IF @Type=1--TO GET MAP INFORMATION
	BEGIN	
		--Groups,Roles,Users
		EXEC spADM_AssignInfo @LocationWhere,@DivisionWhere,@UserID

		SELECT UserID,RoleID,GroupID,CCNID2,BasedOn FROM ADM_DocPrintLayoutsMap WITH(NOLOCK) WHERE DocPrintLayoutID=@DocPrintLayoutID
		
		--Getting All Locations
		SELECT NodeID,Name FROM COM_Location WITH(NOLOCK)
		WHERE IsGroup=0
		ORDER BY Name
		
		declare @PrefValue nvarchar(max),@CCID BIGINT
		select top 1 @CCID = DocumentID from ADM_DocPrintLayouts with(nolock) where DocPrintLayoutID=@DocPrintLayoutID
		

		if(@CCID is not null and (@CCID = 95 or @CCID = 103 or @CCID = 129))
		begin
		select @PrefValue=[Value] from COM_CostCenterPreferences with(nolock) where CostCenterID=@CCID
		    and Name='VPTBasedOnDimension'
		end
		else
		begin 
			select @PrefValue=PrefValue from com_documentpreferences with(nolock) where CostCenterID=@CCID
			and prefName='VPTBasedOn'
		end

		if @PrefValue is not null and @PrefValue!='' and isnumeric(@PrefValue)=1
		begin
		Declare @PrefTable nvarchar(100)
			select @PrefTable=TableName from ADM_Features with(nolock) where FeatureID=@PrefValue
			 if @PrefValue = 92
			   set @PrefValue='select PropertyID NodeID,Name from '+@PrefTable+' with(nolock) where IsGroup=0 ORDER BY Name'
			 else if @PrefValue = 93
			   set @PrefValue='select UnitID NodeID, Name from '+@PrefTable+' with(nolock) where IsGroup=0 ORDER BY Name'
			 else
			   set @PrefValue='select NodeID,Name from '+@PrefTable+' with(nolock) where IsGroup=0 ORDER BY Name'
			--print @PrefValue
			exec(@PrefValue)
		end
		else
		begin
			select 1 BasedOn where 1!=1
		end
	END
	ELSE IF @Type=2
	BEGIN
		DELETE FROM ADM_DocPrintLayoutsMap 
		WHERE DocPrintLayoutID=@DocPrintLayoutID AND PrintOtherVPT IS NULL
	
		INSERT INTO @TblApp(G)
		EXEC [SPSplitString] @Groups,','

		INSERT INTO @TblApp(R)
		EXEC [SPSplitString] @Roles,','

		INSERT INTO @TblApp(U)
		EXEC [SPSplitString] @Users,','
		
		INSERT INTO @TblApp(CCNID2)
		EXEC [SPSplitString] @Locations,','
		
		INSERT INTO @TblApp(BasedOn)
		EXEC [SPSplitString] @BasedOn,','
		

		SELECT *,@UserName,@Dt FROM @TblApp

		INSERT INTO ADM_DocPrintLayoutsMap(DocPrintLayoutID,GroupID,RoleID,UserID,CCNID2,BasedOn,CreatedBy,CreatedDate)
		SELECT @DocPrintLayoutID,G,R,U,CCNID2,BasedOn,@UserName,@Dt
		FROM @TblApp
		ORDER BY U,R,G,CCNID2,BasedOn
		
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID
	END
	IF @Type=3--TO GET MAP INFORMATION
	BEGIN	
		DECLARE @DocumentID BIGINT,@DocType INT
		SELECT @DocumentID=DocumentID,@DocType=DocType FROM ADM_DocPrintLayouts WITH(NOLOCK) WHERE DocPrintLayoutID=@DocPrintLayoutID
		
		SELECT DocPrintLayoutID,Name FROM ADM_DocPrintLayouts WITH(NOLOCK) 
		WHERE DocPrintLayoutID<>@DocPrintLayoutID AND @DocumentID=DocumentID AND @DocType=DocType 
		UNION
		SELECT DocPrintLayoutID,Name+'('+D.DocumentName+')'
		FROM ADM_DocPrintLayouts L WITH(NOLOCK)
		INNER JOIN ADM_DocumentTypes D ON D.CostCenterID=L.DocumentID
		WHERE L.DocumentID IN (select CostCenterIDLinked from COM_DocumentLinkDef where CostCenterIDBase=@DocumentID)
		ORDER BY Name
		
		SELECT DocPrintLayoutID,Name,PrintContinue FROM ADM_DocPrintLayouts WITH(NOLOCK) 
		, (	SELECT PrintOtherVPT,PrintContinue,MapID FROM ADM_DocPrintLayoutsMap WITH(NOLOCK) 
				WHERE PrintOtherVPT IS NOT NULL AND DocPrintLayoutID=@DocPrintLayoutID) T
		WHERE T.PrintOtherVPT=DocPrintLayoutID
		ORDER BY T.MapID

		
		if @DocumentID=95
		begin
			SELECT DocPrintLayoutID,Name+'('+D.DocumentName+')' Name
			FROM ADM_DocPrintLayouts L WITH(NOLOCK)
			INNER JOIN ADM_DocumentTypes D ON D.CostCenterID=L.DocumentID
			WHERE L.DocumentID in (select Value from COM_costcenterpreferences with(nolock) where FeatureID=95 and (Name='ContractSalesInvoice' or Name='ContractSalesReturn') and isnumeric(Value)=1)
			ORDER BY Name
		end
		else if exists (SELECT * FROM ADM_DocumentTypes WHERE CostCenterID=@DocumentID and DocumentType in (1,4))
		begin
			SELECT DocPrintLayoutID,Name+'('+D.DocumentName+')' Name 
			FROM ADM_DocPrintLayouts L WITH(NOLOCK)
			INNER JOIN ADM_DocumentTypes D ON D.CostCenterID=L.DocumentID
			WHERE DocumentType in (14,15,23)
		end
		else if exists (SELECT * FROM ADM_DocumentTypes WHERE CostCenterID=@DocumentID and DocumentType in (11,12))
		begin
			SELECT DocPrintLayoutID,Name+'('+D.DocumentName+')' Name 
			FROM ADM_DocPrintLayouts L WITH(NOLOCK)
			INNER JOIN ADM_DocumentTypes D ON D.CostCenterID=L.DocumentID
			WHERE DocumentType in (18,19,22)
		end
		
	END
	ELSE IF @Type=4--TO SET VPT MAP
	BEGIN
		DELETE FROM ADM_DocPrintLayoutsMap 
		WHERE DocPrintLayoutID=@DocPrintLayoutID AND PrintOtherVPT IS NOT NULL
	
		DECLARE @XML XML

		SET @XML=@Groups
		
		INSERT INTO ADM_DocPrintLayoutsMap(DocPrintLayoutID,GroupID,RoleID,UserID,CreatedBy,CreatedDate,PrintOtherVPT,PrintContinue)
		SELECT @DocPrintLayoutID,0,0,0,@UserName,@Dt,X.value('@ID','BIGINT'),X.value('@Continue','INT')
		FROM @XML.nodes('/XML/Row') as Data(X)
		
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID
	END
	ELSE IF @Type=5--To Get Mapped VPTs
	BEGIN
		SELECT L.*,PrintContinue,D.IsInventory FROM ADM_DocPrintLayouts L WITH(NOLOCK)		
		JOIN (	SELECT PrintOtherVPT,PrintContinue,MapID FROM ADM_DocPrintLayoutsMap WITH(NOLOCK) 
					WHERE PrintOtherVPT IS NOT NULL AND DocPrintLayoutID=@DocPrintLayoutID) T ON T.PrintOtherVPT=DocPrintLayoutID
		LEFT join ADM_DocumentTypes D with(nolock) on D.CostCenterID=L.DocumentID 
		ORDER BY T.MapID
	END
	
	
	
COMMIT TRANSACTION
SET NOCOUNT OFF;

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		 SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		 FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
