USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetWorkFlowDefinition]
	@CostCenterId [int],
	@IsLineWise [bit],
	@OnReject [bit],
	@UserWise [bit],
	@FieldWidth [int],
	@WorkFlowXML [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@CreatedBy [nvarchar](50),
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
	SET NOCOUNT ON
	BEGIN TRY

		IF(@CostCenterId=0)
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		DECLARE @CreatedDate FLOAT, @XML XML
		SET @CreatedDate=CONVERT(FLOAT,getdate())

	


		SET @XML=@WorkFlowXML

		--DECLARE @tab table(id int identity(1,1),WorkFlowID INT)
		--insert into @tab
		--SELECT distinct X.value('@WorkFlowID','INT')
		--from @XML.nodes('XML/Row') as Data(X)

		--if exists (select userid from (select [WorkFlowID],userid from [COM_WorkFlow] with(nolock)
		--								where [WorkFlowID] in (select WorkFlowID from @tab)
		--								group by [WorkFlowID],userid) as t 
		--			group by t.userid
		--			having count(*) >1)
		--BEGIN
		--	RAISERROR('-100',16,1)
		--END
		
		delete from COM_WorkFlowDef where CostCenterID=@CostCenterId   
	 

		INSERT INTO COM_WorkFlowDef (CostCenterID,[Action],Expression,WorkFlowID,LevelID,IsEnabled,IsExpressionLineWise
		,IsLineWise,OnReject,UserWise,FieldWidth,CompanyGUID,[GUID],CreatedBy,CreatedDate,WEFDate,TillDate)
		SELECT @CostCenterId
		,X.value('@Action','nvarchar(100)')
		,X.value('@Expression','nvarchar(max)')
		,X.value('@WorkFlowID','INT')
		,X.value('@LevelID','INT')
		,X.value('@IsEnabled','BIT')
		,X.value('@IsExpLW','BIT')
		,@IsLineWise,@OnReject,@UserWise,@FieldWidth
		,@CompanyGUID
		,NewId()
		,@CreatedBy
		,convert(float,getdate())		 
	    ,convert(float,X.value('@WEFDate','DateTime'))
	    ,convert(float,X.value('@TillDate','DateTime'))
		 from @XML.nodes('XML/Row') as Data(X)
		 
		
		COMMIT TRANSACTION  
		SET NOCOUNT OFF;  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
		WHERE ErrorNumber=100 AND LanguageID=@LangID
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



----EXEC [spADM_SetWorkFlowDefiniton] 4,1,'1','20',1,'ABCD','ADMIN'
GO
