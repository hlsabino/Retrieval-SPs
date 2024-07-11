USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetIntegerListItems]
	@StrList [nvarchar](max) = NULL,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY
	SET NOCOUNT ON;

			--Declaring variables
			DECLARE @UserID nvarchar(50),@Pos INT

			CREATE TABLE #TList (USERID int) 
			SET @StrList=LTRIM(RTRIM(@StrList))+','
			SET @Pos=CHARINDEX(',',@StrList,1)

			IF REPLACE(@StrList,',','')<>''
			BEGIN
				WHILE @Pos > 0
				BEGIN
					SET @UserID=LTRIM(RTRIM(LEFT(@StrList,@Pos-1)))
					IF  @UserID<>''
						INSERT INTO #TList VALUES(@UserID)
				
					SET @StrList=RIGHT(@StrList,LEN(@StrList)-@Pos)
					SET @Pos=CHARINDEX(',',@StrList,1)
				END
			END

			SELECT USERID FROM #TList

			DROP TABLE #TList

	SET NOCOUNT OFF;

END TRY
BEGIN Catch  
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
END Catch  
GO
