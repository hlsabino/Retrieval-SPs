USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DefineCodeDefination]
	@CostCenterID [bigint],
	@CODEPREFIX [nvarchar](300),
	@SEPERATOR [nvarchar](300),
	@PREVIEW [nvarchar](300),
	@ISDATECHECK [bit] = NULL,
	@PREFIX [nvarchar](300) = NULL,
	@DATA [nvarchar](max) = NULL,
	@ISPARENTCODEINCLUDED [bit] = NULL,
	@ISSEPERATORINCLUDE [bit] = NULL,
	@ContinuousSeqNo [bit] = NULL,
	@DATEFORMAT [nvarchar](300) = NULL,
	@ParentCodeLevels [nvarchar](max) = NULL,
	@IsName [bit] = 0,
	@IsGroupCode [int] = 0,
	@IsEnable [bit] = 1,
	@ShowSeriesNos [bit] = 1,
	@SameSeriesForGroups [bit] = 1,
	@ShowAutoManual [bit] = 1,
	@RootNodeAutoCode [bit],
	@COMPANYGUID [nvarchar](300),
	@USERNAME [nvarchar](300),
	@USERID [int],
	@LANGID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;

	-- Declare the variable here
	DECLARE @CodeNumber BIGINT,@xml xml
	
	DELETE FROM COM_CostCenterCodeDef WHERE COSTCENTERID=@CostCenterID and ISName=@IsName and IsGroupCode=@IsGroupCode
	
	INSERT INTO  [COM_CostCenterCodeDef]
       ([CostCenterID]
       ,[FeatureID] 
       ,[CodePrefix]
       ,[CodeNumberRoot]
       ,[CodeNumberInc]
       ,[CodeDelimiter]
       ,[CurrentCodeNumber]
       ,[CodeNumberLength],CodePreview
       ,[IsDateIncluded]
       ,[DateFormat]
       ,[IsDateDelimiterDefined]
       ,[IsParentCodeInherited]
       ,[IsSeperatorInclude]
       ,ContinuousSeqNo
       ,[IsCodeUserDefined]
       ,[PrefixContent]
       ,[CompanyGUID]
       ,[GUID]
       ,[CreatedBy]
       ,[CreatedDate],ISName,IsEnable,IsGroupCode
       ,ShowSeriesNos,SameSeriesForGroups,ShowAutoManual,RootNodeAuto
        )
 VALUES
       (@CostCenterID
       ,@CostCenterID 
       ,@CODEPREFIX
       ,1
       ,1
       ,@SEPERATOR
       ,0
       ,@PREFIX,@PREVIEW
       ,@ISDATECHECK
       ,@DATEFORMAT
       ,0
       ,@ISPARENTCODEINCLUDED
       ,@ISSEPERATORINCLUDE
       ,@ContinuousSeqNo
       ,1
       ,@DATA
       ,@COMPANYGUID
       ,NEWID()           
       ,@USERNAME
       ,CONVERT(FLOAT,GETDATE()),@IsName,@IsEnable,@IsGroupCode
       ,@ShowSeriesNos,@SameSeriesForGroups,@ShowAutoManual,@RootNodeAutoCode
       )
       
    set @xml= @ParentCodeLevels
	delete from COM_CCParentCodeDef
	where [CostCenterID]=@CostCenterID

	insert into COM_CCParentCodeDef([CostCenterID],[LEVELNO],
	[CodeLength],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
	SELECT @CostCenterID,X.value('@LEVELNO','INT'),
	X.value('@Length','INT'),@COMPANYGUID,NEWID(), @USERNAME,CONVERT(FLOAT,GETDATE())
	FROM @xml.nodes('XML/Row') as DATA(X)
	
	--declare @RootNode int
	--set @RootNode=1
	--if @CostCenterID>50000 and @CostCenterID<=50050
	--	set @RootNode=2
	--update COM_CCCCDATA set IsManual=(case when @RootNodeAutoCode=1 then 0 else 1 end)
	--where CostCenterID=@CostCenterID and NodeID=@RootNode

		
COMMIT TRANSACTION  
SELECT * FROM [COM_CostCenterCodeDef] WITH(nolock) WHERE COSTCENTERID=@CostCenterID
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;  
RETURN @CostCenterID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM [COM_CostCenterCodeDef] WITH(nolock) WHERE COSTCENTERID=@CostCenterID
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
