USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetStatusMap]
	@CostCenterID [int],
	@NodeID [bigint],
	@StatusXML [nvarchar](max),
	@UserName [nvarchar](50),
	@Dt [float]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @XML XML
IF (@StatusXML IS NOT NULL AND @StatusXML <> '')
BEGIN
	SET @XML=@StatusXML
	INSERT INTO [COM_CostCenterStatusMap] ([CostCenterID],[NodeID],[Status],FromDate,ToDate,[CreatedBy],[CreatedDate])
	SELECT @CostCenterID,@NodeID,X.value('@StatusID','int'),convert(float,X.value('@FromDate','datetime')),convert(float,X.value('@ToDate','datetime'))
	,@UserName,@Dt
	FROM @XML.nodes('/XML/Row') as Data(X)    
	WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

	--If Action is MODIFY then update Attachments  
	UPDATE [COM_CostCenterStatusMap]  
	SET [Status]=X.value('@StatusID','int'),
	FromDate=convert(float,X.value('@FromDate','datetime')),
	ToDate=convert(float,X.value('@ToDate','datetime')),
	ModifiedBy=@UserName,  
	ModifiedDate=@Dt
	FROM [COM_CostCenterStatusMap] C WITH(NOLOCK)  
	INNER JOIN @XML.nodes('/XML/Row') as Data(X)    
	ON convert(bigint,X.value('@MapID','bigint'))=C.StatusMapID  
	WHERE X.value('@Action','NVARCHAR(500)')='EDIT'
END
GO
