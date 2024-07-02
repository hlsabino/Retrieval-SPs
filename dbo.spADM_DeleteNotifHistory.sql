USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteNotifHistory]
	@Action [int],
	@MaxDate [datetime] = null,
	@List [nvarchar](max),
	@PreserveDays [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
--SET NOCOUNT ON;    

	--Declaration Section    
	CREATE TABLE #TblTemp(ID BIGINT)
	CREATE TABLE #Tbl(ID INT IDENTITY(1,1),FeatureID INT)
	CREATE TABLE #TblINV(ID INT IDENTITY(1,1),FeatureID INT,IsRevise BIT)
	CREATE TABLE #TblACC(ID INT IDENTITY(1,1),FeatureID INT,IsRevise BIT)
	DECLARE @I INT,@CNT INT,@Dt FLOAT
	DECLARE @DbName nvarchar(50),@sql nvarchar(max),@DtChar nvarchar(20),@cols nvarchar(max),@TblName nvarchar(max)
	
	SET @Dt=floor(convert(float,dateadd(day,-@PreserveDays,GETDATE())))
	SET @DtChar=convert(nvarchar,@Dt)
	--select @Dt,dateadd(day,-@PreserveDays,GETDATE())
	IF LEN(@List)<=0
		RETURN 1
		
	--select GETDATE()
	
	IF @Action=1
	BEGIN
		IF @List='ALL'
		BEGIN
			SELECT AttachmentPath,ID FROM COM_Notif_History with(nolock)
			WHERE CreatedDate<=@Dt AND AttachmentPath IS NOT NULL AND AttachmentPath!='' --AND ID=174
			--SELECT convert(datetime,CreatedDate), * FROM COM_Notif_History where CreatedDate<@Dt
		END
		ELSE
		BEGIN		
			INSERT INTO #TblTemp
			EXEC SPSplitString @List,','
			
			SELECT AttachmentPath FROM COM_Notif_History N with(nolock)
			INNER JOIN #TblTemp T ON T.ID=N.CostCenterID
			WHERE CreatedDate<@Dt AND AttachmentPath IS NOT NULL AND AttachmentPath!=''
		END
		SELECT CONVERT(DATETIME,@Dt) MaxDate
	END
	ELSE IF @Action=2
	BEGIN
		IF @List='ALL'
		BEGIN
			DELETE FROM COM_Notif_History
			WHERE CreatedDate<@MaxDate
		END
		ELSE
		BEGIN		
			INSERT INTO #TblTemp
			EXEC SPSplitString @List,','
			
			DELETE COM_Notif_History FROM COM_Notif_History N
			INNER JOIN #TblTemp T ON T.ID=N.CostCenterID
			WHERE CreatedDate<@MaxDate
		END	
	END
	
 

COMMIT TRANSACTION
--ROLLBACK TRANSACTION

--SET NOCOUNT OFF; 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID  
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
