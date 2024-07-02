USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetDenominationDetails]
	@CurrencyID [int] = 0,
	@UserID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @TAB TABLE(CurrencyDenominationsID BIGINT,Notes FLOAT,Change FLOAT,GUID NVARCHAR(100),ActualFileName NVARCHAR(500),
					   FilePath NVARCHAR(2000),RelativeFileName NVARCHAR(2000),FileExtension VARCHAR(10))
    INSERT INTO @TAB
    SELECT CurrencyDenominationsID,Notes,Change,'','' ActualFileName,'' FilePath,'' RelativeFileName,'' FileExtension 
	FROM Com_CurrencyDenominations with(nolock) where CurrencyID=@CurrencyID
	
	UPDATE f SET f.ActualFileName=d.ActualFileName,f.FilePath=d.FilePath,f.RelativeFileName=d.RelativeFileName,f.FileExtension=d.FileExtension
	,f.GUID=d.GUID
	FROM @TAB f INNER JOIN COM_Files d 
							  ON f.CurrencyDenominationsID=d.RowSeqNo 
	
	SELECT * FROM @TAB
    --SELECT distinct CD.CurrencyDenominationsID,CD.Notes,CD.Change,CD.GUID,isnull(CF.ActualFileName,'') ActualFileName,isnull(CF.FilePath,'') FilePath,isnull(CF.RelativeFileName,'') RelativeFileName,isnull(CF.FileExtension,'') FileExtension 
	-- FROM Com_CurrencyDenominations CD with(nolock) inner Join Com_Files CF with(nolock) on CD.CurrencyDenominationsID=CF.RowSeqNo and CD.CurrencyID=CF.FeaturePK and  CD.CurrencyID=1

END
GO
