USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_ReleaseJob]
	@Detxml [nvarchar](max),
	@VoucherNo [nvarchar](max),
	@DocID [int],
	@CompanyGUID [nvarchar](max),
	@UserName [nvarchar](200),
	@RoleID [int] = 1,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
BEGIN Tran
SET NOCOUNT ON
	
	DECLARE @Dimension INT,@J INT,@jbsCNT INT,@i INT,@CNT INT,@INVID BIGINT,@Qty INT,@UnitName INT,@Day INT,@Return_Value BIGINT

	CREATE TABLE #DTAB(ID INT IDENTITY(1,1) PRIMARY KEY,NodeID BIGINT,ProductID BIGINT,Quantity FLOAT,BOMID BIGINT,StageID INT,UOMID INT)
	
	DECLARE @DocDate FLOAT,@StatusID INT,@CustomFieldsQuery NVARCHAR(MAX),@xml xml,
	@JobsProductXML NVARCHAR(MAX),@GUID NVARCHAR(64),@NodeID BIGINT
	
	SELECT @Dimension=CONVERT(INT,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='JobDimension' 

	set @xml=@Detxml
	DECLARE  @TAB TABLE(ID INT IDENTITY(1,1),InvID BIGINT,Qty Float)
	
	insert into @TAB
	select X.value('@DocDetailsID','BIGINT'),X.value('@Qty','Float')
	from @xml.nodes('/xml/Row') as Data(X)
	
	select @jbsCNT=count(distinct fld1) from INV_DocExtraDetails WITH(NOLOCK) WHERE [RefID]=@DocID and [Type]=15
	if(@jbsCNT>0)
		set @VoucherNo=@VoucherNo+'/'+convert(nvarchar(max),@jbsCNT)
		
	select @guid=newid()
	
		
				
	set @i=0
	SELECT @CNT=COUNT(*) FROM @TAB 
	
	set @JobsProductXML='<XML>'
	
	WHILE @i<@CNT
	BEGIN 
			set @i=@i+1
			SELECT @INVID=InvID,@Qty=Qty FROM @TAB  WHERE ID=@i
		
		
			TRUNCATE TABLE #DTAB

			INSERT INTO #DTAB
			SELECT DISTINCT IDD.InvDocDetailsID,BP.ProductID,@Qty*(BP.Quantity*isnull(PU.Conversion,1))/(BM.FPQty*isnull(U.Conversion,1)),BM.BOMID,BS.StageNodeID,BP.UOMID
			FROM INV_DocDetails IDD WITH(NOLOCK)
			JOIN PRD_BillOfMaterial BM WITH(NOLOCK) ON BM.ProductID=IDD.ProductID
			JOIN PRD_BOMProducts BP WITH(NOLOCK) ON BP.BOMID=BM.BOMID
			left join COM_UOM PU with(nolock) ON PU.UOMID=BP.UOMID
			LEFT JOIN COM_UOM U with(nolock) ON U.UOMID=BM.UOMID
			JOIN PRD_BOMStages BS WITH(NOLOCK) ON BS.StageID=BP.StageID
			WHERE IDD.InvDocDetailsID=@INVID AND BP.ProductUse=2
			
			
			SELECT @JobsProductXML=@JobsProductXML+'<Row RowNo="'+CONVERT(NVARCHAR,ID)+'" BOMID="'+CONVERT(NVARCHAR,BOMID)+'" StageID="'+CONVERT(NVARCHAR,StageID)+'" ProductID="'+CONVERT(NVARCHAR,ProductID)+'" Qty="'+CONVERT(NVARCHAR,Quantity)+'" IsBom="0" UOMID ="'+CONVERT(NVARCHAR,UOMID)+'" Remarks ="" StatusID ="5"/>' 
			FROM #DTAB WITH(NOLOCK)
	END
		
		SELECT @StatusID=StatusID FROM COM_Status WITH(NOLOCK) 
		WHERE CostCenterID=@Dimension and [Status] = 'Active'

		SET @JobsProductXML=@JobsProductXML+'</XML>'
		
			EXEC @Return_Value=[dbo].[spCOM_SetCostCenter]
				@NodeID = 0,
				@SelectedNodeID = 2,
				@IsGroup = 0,
				@Code = @VoucherNo,
				@Name = @VoucherNo,
				@AliasName = @VoucherNo,
				@PurchaseAccount = 2,
				@SalesAccount = 3,
				@CreditLimit = 0,
				@CreditDays = 0,
				@DebitLimit = 0,
				@DebitDays = 0,
				@StatusID = @StatusID,
				@CustomFieldsQuery =  N'',
				@CustomCostCenterFieldsQuery = N'',
				@ContactsXML =  N'',
				@AddressXML = '',
				@AttachmentsXML = '',
				@NotesXML = '',
				@PrimaryContactQuery =  N'',
				@CostCenterRoleXML = '',
				@CostCenterID = @Dimension,
				@CompanyGUID = @CompanyGUID,
				@GUID = @GUID,
				@UserName = @UserName,
				@WID = 0,
				@RoleID = @RoleID,
				@UserID = @UserID,
				@LangID = @LangID,
				@CodePrefix = '',
				@CodeNumber = 0,
				@GroupSeqNoLength = 0,
				@JobsProductXML  = @JobsProductXML,
				@DimMappingXML = '',
				@HistoryXML = '',
				@StatusXML = '',
				@DocXML = '',
				@IsOffline = 0,
				@CheckLink = 1
			
			if(@Return_Value=-999)
				return @Return_Value
			else
			BEGIN
					insert into INV_DocExtraDetails(InvDocDetailsID,[RefID],[Type],[Quantity],fld1,LabID)
					select X.value('@DocDetailsID','BIGINT'),@DocID,15,X.value('@Qty','Float'),@guid,@Return_Value
					from @xml.nodes('/xml/Row') as Data(X)
			END
COMMIT TRAN		 
SET NOCOUNT OFF;
SELECT ErrorMessage+'  '+@VoucherNo ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
RETURN 1
END TRY
BEGIN CATCH
	
	ROLLBACK TRAN  
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
 
SET NOCOUNT OFF  
RETURN -999   
END CATCH
	
GO
