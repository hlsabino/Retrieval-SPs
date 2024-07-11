USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDimensionWiseLockData]
	@Type [int],
	@DimMappID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--  
BEGIN TRY  
SET NOCOUNT ON;
	DECLARE @SQL NVARCHAR(MAX)
	IF @Type=0 /*TO GET SCREEN DETAILS*/
	BEGIN
		SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE (FEATUREID>50000 OR FEATUREID=2 or FEATUREID=3)  and ISEnabled=1

		SELECT Distinct ProfileID,ProfileName FROM COM_DimensionMappings WITH(NOLOCK)
		GROUP BY ProfileID,ProfileName
		ORDER BY ProfileName
		
		SELECT  Value,Name FROM COM_CostCenterPreferences WITH(NOLOCK)		
		where CostCenterID=	153

	END
	ELSE IF @Type=2 /*TO GET PROFILE DATA BY PROFILEID*/
	BEGIN
	
		SET @SQL='SELECT P.ProductCode,
			P.ProductName,
			T.*,(SELECT TOP 1 AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=T.AccountID AND T.AccountID!=0) AccountName'
		
		if exists(select name from sys.tables with(nolock) where name='SVC_Vehicle')
		begin
			select @SQL=@SQL+',(SELECT TOP 1 a.Make+''-''+a.MOdel+''-''+a.Variant+''-(''+convert(nvarchar,a.startYear)+''-''+ case when (a.EndYear= ''0'') then convert(nvarchar,Datepart(YEAR,GETDATE()))+'')'' else convert(nvarchar,a.endYear)+'')'' end  FROM SVC_Vehicle a WITH(NOLOCK) WHERE T.VehicleID>0 and a.VehicleID=T.VehicleID) Vehicle'
		end
		
		select @SQL=@SQL+',(SELECT TOP 1 Name FROM '+F.TableName+' WITH(NOLOCK) WHERE NodeID=T.'+C.name+' AND T.'+C.name+'>0) '+REPLACE(C.name,'NID','')
		from sys.columns C WITH(NOLOCK)
		JOIN ADM_FEATURES F WITH(NOLOCK) ON F.FEATUREID=50000+CONVERT(INT,REPLACE(C.name,'CCNID',''))
		where object_id=object_id('COM_DimensionMappings') and C.name LIKE 'ccnid%'
		
		select @SQL=@SQL+'
		FROM COM_DimensionMappings T WITH(NOLOCK)
		left JOIN 	INV_Product P WITH(NOLOCK) ON P.ProductID=T.ProductID	
		WHERE T.ProfileID='+CONVERT(NVARCHAR,@DimMappID)
		
		EXEC (@SQL)	
	END
	ELSE IF @Type=5 /*TO DELETE PROFILE*/
	BEGIN
	BEGIN TRANSACTION
		DELETE FROM COM_DimensionMappings WHERE ProfileID=@DimMappID
	COMMIT TRANSACTION
	END

	
-- 
SET NOCOUNT OFF;   
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
