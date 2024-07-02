USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetDenominations]
	@CurrencyID [int] = 0,
	@DenomXML [nvarchar](max),
	@AttachmentXML [nvarchar](max),
	@companyGUID [nvarchar](50),
	@Username [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY 
	declare @xml xml,@xml1 xml
	set @xml=@DenomXML
	set @xml1=@AttachmentXML
	
	IF EXISTS (select * FROM COM_DocDenominations WITH(NOLOCK)
			WHERE CurrencyID=@CurrencyID AND Notes NOT IN ( SELECT X.value('@Notes','Float')
			FROM @xml.nodes('/XML/Row') as Data(X)))
	BEGIN
		RAISERROR('-110',16,1)
	END

	delete from [Com_CurrencyDenominations] where CurrencyID=@CurrencyID
	
	insert into [Com_CurrencyDenominations](CurrencyID,[Notes],[Change],[GUID],CompanyGUID,CreatedBy,CreatedDate)
	select @CurrencyID,X.value('@Notes','Float'),X.value('@Change','Float'),newid(),@companyGUID,@username,CONVERT(float,getdate())
	FROM @xml.nodes('/XML/Row') as Data(X)      

	--TO INSERT IMAGES IN COMFILES 
	declare @comfiles table(FilePath nvarchar(2000),ActualFileName nvarchar(500), RelativeFileName nvarchar(2000),FileExtension nvarchar(10),IsProductImage bit,
				AllowInPrint bit,FeatureID int,CostCenterID int,FeaturePK bigint,IsDefaultImage bit,RowSeqNo int,CompanyGUID nvarchar(100),GUID varchar(50),CreatedBy nvarchar(100),CreatedDate float,Notes float,Change float)
				
	insert into @comfiles(FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,AllowInPrint,FeatureID,CostCenterID,
						  FeaturePK,IsDefaultImage,RowSeqNo,CompanyGUID,GUID,CreatedBy,CreatedDate,Notes,Change)
	select 	X.value('@FilePath','nvarchar(2000)'),X.value('@ActualFileName','nvarchar(500)'),
			X.value('@RelativeFileName','nvarchar(2000)'),X.value('@FileExtension','nvarchar(10)'),
			X.value('@IsProductImage','bit'),X.value('@AllowInPrint','Float'),
			X.value('@FeatureID','int'),X.value('@CostCenterID','int'),
			X.value('@FeaturePK','bigint'),X.value('@IsDefaultImage','bit'),
			0,@companyGUID,X.value('@GUID','nvarchar(100)')
			,@username,CONVERT(float,getdate()),X.value('@Notes','Float'),X.value('@Change','Float')
	FROM @xml1.nodes('/AttachmentXML/Row') as Data(X)		
	
	UPDATE f SET f.RowSeqNo=d.CurrencyDenominationsID FROM @comfiles f 
	INNER JOIN Com_CurrencyDenominations d with(nolock) ON f.FeaturePK=d.CurrencyID and f.FeatureID=12 and f.Notes=d.Notes and f.Change=d.change and d.CurrencyID= @CurrencyID 
	  
	IF(SELECT COUNT(*) FROM @COMFILES)>0
	BEGIN
		delete from COM_Files where featurepk=@CurrencyID
		insert into com_files(FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,AllowInPrint,FeatureID,CostCenterID,FeaturePK,IsDefaultImage,RowSeqNo,CompanyGUID,GUID,CreatedBy,CreatedDate)
		select FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,AllowInPrint,FeatureID,CostCenterID,FeaturePK,IsDefaultImage,RowSeqNo,CompanyGUID,GUID,CreatedBy,CreatedDate from @comfiles
	END
			--TO INSERT IMAGES IN COMFILES 
   
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
