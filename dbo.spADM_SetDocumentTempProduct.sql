USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDocumentTempProduct]
	@DocumentTypeID [bigint],
	@TempProductXml [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](200),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  

	Declare @XML XML
	--SP Required Parameters Check  
	IF @DocumentTypeID=0  
	BEGIN  
		RAISERROR('-100',16,1)  
	END  
	
	declare @CostCenterID bigint
	if(@DocumentTypeID>0)
	begin
		SELECT @CostCenterID=COSTCENTERID FROM ADM_DocumentTypes             
		WITH(NOLOCK) WHERE  DocumentTypeID=2
	end  
	DECLARE @dt float
	set @XML=@TempProductXml
	set @dt=convert(float,getdate())

	UPDATE [COM_DocTempProductDef]
	SET [UserColumnName] = X.value('@Rename','NVARCHAR(100)')  
	,[UserColumnType] = X.value('@DataType','NVARCHAR(100)')    
	,[IsMandatory] = X.value('@IsMandatory','BIT')
	,[IsEditable] =  X.value('@IsEditable','BIT') 
	,[IsVisible] = X.value('@IsVisible','BIT')   
	,[TextFormat]= X.value('@TextFormat','INT')   
	,[ColumnCostCenterID] =ISNULL(X.value('@ColumnCostcenterID','BIGINT'),0)
	,[ColumnCCListViewTypeID] =  ISNULL( X.value('@ListViewTypeID','BIGINT'),0)
	,[SectionSeqNumber] =ISNULL( X.value('@SectionSeqNumber','INT') ,0)
	,[ColumnSpan] =ISNULL( X.value('@ColumnSpan','INT')  ,0)
	,[IsDefault] =   X.value('@IsDefault','BIT')  
	,[ModifiedBy] = @UserName
	,[ModifiedDate] = @dt 
	from [COM_DocTempProductDef] WITH(NOLOCK)
	INNER JOIN @XML.nodes('/XML/Row') as Data(X)
	on convert(bigint,X.value('@TempProductColID','bigint'))=TempProductColID 
	WHERE X.value('@TempProductColID','BIGINT') IS NOT NULL AND  X.value('@TempProductColID','BIGINT')>0

	declare @r int, @c int, @cnt int, @icnt int, @ColSpan int, @Colid int		
	CREATE TABLE #TBL(ID INT identity(1,1), ColID int, SeqNum int,visible BIT,ColSpan int)       
	INSERT INTO #TBL      
	SELECT  X.value('@TempProductColID','INT'),      
	X.value('@Order','INT'),
	IsVisible = X.value('@IsVisible','BIT'),
	X.value('@ColumnSpan','INT') 
	from @XML.nodes('XML/Row') as DATA(X) 
	order by X.value('@Order','INT') asc

	set @r=0
	set @c=0
	set @icnt=0
	set @cnt=(select count(*) from #TBL )
	while @icnt<@cnt
	begin
		set @icnt=@icnt+1 
		if exists(Select visible from #TBL where ID=@icnt and visible=0)
		begin
			continue;
		end

		set @Colid=(Select Colid from #TBL where ID=@icnt)

		set @ColSpan=(Select ColSpan from #TBL where ID=@icnt)

		if(@ColSpan is null)
			set @ColSpan=1 
		if(@c+@ColSpan>2)
		begin
			set @r=@r+1
			set @c=0
		end

		SELECT @r,@c,(Select visible from #TBL where ID=@icnt) as visible, @ColSpan,SysColumnName,TempProductColID 
		FROM COM_DocTempProductDef WITH(NOLOCK) where TempProductColID=@Colid
		
		update COM_DocTempProductDef set RowNo=@r, ColumnNo=@c 
		where TempProductColID=@Colid 

		set @c=@c+@ColSpan
		set @ColSpan=0
	end
	
	UPDATE ADM_DocumentTypes SET GUID=NEWID()where CostCenterID=@CostCenterID 
	
	COMMIT TRANSACTION   
	SET NOCOUNT OFF; 
	
	SELECT * FROM [COM_DocTempProductDef] WITH(nolock) 
	WHERE CostCenterid in (select costcenterid from adm_documenttypes where documenttypeid=@DocumentTypeID)
	
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID 
	
	RETURN @DocumentTypeID
END TRY  
BEGIN CATCH    
	--Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
