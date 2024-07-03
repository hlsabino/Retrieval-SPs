USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_SetTemplateReport]
	@CallType [int],
	@TemplateID [int],
	@TemplateName [nvarchar](max),
	@IsDefault [bit],
	@ReportBodyXML [nvarchar](max),
	@ReportHeaderXML [nvarchar](max),
	@PageHeaderXML [nvarchar](max),
	@PageFooterXML [nvarchar](max),
	@ReportFooterXML [nvarchar](max),
	@BodyFieldXML [nvarchar](max) = null,
	@FormulaFieldsXML [nvarchar](max) = null,
	@Type [nvarchar](50) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
--SET NOCOUNT ON;
	DECLARE @Tbl AS TABLE(ReportID INT)

if(@CallType=1)
begin
BEGIN TRANSACTION
	if @IsDefault=1
		update ADM_PrintFormates set IsDefault=0 where Type=@Type
	
	if(@TemplateID > 0)
	begin
			update ADM_PrintFormates
	 		set Name=@TemplateName,
				ReportBody=@ReportBodyXML,
				ReportHeader=@ReportHeaderXML,
				PageHeader=@PageHeaderXML,
				PageFooter=@PageFooterXML,
				ReportFooter=@ReportFooterXML,
				IsDefault=@IsDefault,
				BodyFields=@BodyFieldXML,
				FormulaFields=@FormulaFieldsXML
			where FormateID=@TemplateID
	end
	else
	begin
		insert into ADM_PrintFormates(Name,ReportBody,ReportHeader,PageHeader,PageFooter,ReportFooter,BodyFields,FormulaFields,Type,IsDefault,CompanyGUID,GUID,CreatedBy,CreatedDate)
		values  (@TemplateName,@ReportBodyXML,@ReportHeaderXML,@PageHeaderXML,@PageFooterXML,@ReportFooterXML,@BodyFieldXML,@FormulaFieldsXML,@Type,@IsDefault,@CompanyGUID,NEWID(),@UserName,convert(float,GETDATE()))
	end
COMMIT TRANSACTION
end
else if(@CallType=2)
begin
	if exists(select FormateID from ADM_PrintFormates with(nolock) where FormateID=@TemplateID)
	begin
		
		select @ReportBodyXML=ReportBody,@ReportHeaderXML=ReportHeader,@PageHeaderXML=PageHeader,@PageFooterXML=PageFooter,@ReportFooterXML=ReportFooter,@FormulaFieldsXML=FormulaFields
		from ADM_PrintFormates with(nolock) where FormateID=@TemplateID
	
		BEGIN TRANSACTION 
		INSERT INTO @Tbl(ReportID)
		EXEC [SPSplitString] @TemplateName,','
				
		update ADM_RevenuReports
		set ReportBody=@ReportBodyXML
		,ReportHeader=@ReportHeaderXML
		,PageHeader=@PageHeaderXML
		,PageFooter=@PageFooterXML
		,ReportFooter=@ReportFooterXML
		,FormulaFields=@FormulaFieldsXML
		from ADM_RevenuReports R WITH(NOLOCK)
		inner join @Tbl T ON R.ReportID=T.ReportID
		COMMIT TRANSACTION 

	end
end
else if(@CallType=3)
begin
	if exists(select FormateID from ADM_PrintFormates with(nolock) where FormateID=@TemplateID)
	begin
		select @ReportBodyXML=ReportBody,@ReportHeaderXML=ReportHeader,@PageHeaderXML=PageHeader,@PageFooterXML=PageFooter,@ReportFooterXML=ReportFooter,@FormulaFieldsXML=FormulaFields
		from ADM_PrintFormates with(nolock) where FormateID=@TemplateID
		
		BEGIN TRANSACTION 
		INSERT INTO @Tbl(ReportID)
		EXEC [SPSplitString] @TemplateName,','
		
		--select * from ADM_DocPrintLayouts R WITH(NOLOCK) inner join @Tbl T ON R.DocPrintLayoutID=T.ReportID

		if @ReportBodyXML like '%ReportHeader%'
			update R
			set ReportHeader=@ReportHeaderXML
			from ADM_DocPrintLayouts R WITH(NOLOCK)
			inner join @Tbl T ON R.DocPrintLayoutID=T.ReportID

		if @ReportBodyXML like '%PageHeader%'
			update R
			set PageHeader=@PageHeaderXML
			from ADM_DocPrintLayouts R WITH(NOLOCK)
			inner join @Tbl T ON R.DocPrintLayoutID=T.ReportID

		if @ReportBodyXML like '%PageFooter%'
			update R
			set PageFooter=@PageFooterXML
			from ADM_DocPrintLayouts R WITH(NOLOCK)
			inner join @Tbl T ON R.DocPrintLayoutID=T.ReportID

		if @ReportBodyXML like '%ReportFooter%'
			update R
			set ReportFooter=@ReportFooterXML
			from ADM_DocPrintLayouts R WITH(NOLOCK)
			inner join @Tbl T ON R.DocPrintLayoutID=T.ReportID

			if @ReportBodyXML like '%VPFormField%'
			update R
			set FormulaFields = @FormulaFieldsXML
			from ADM_DocPrintLayouts R WITH(NOLOCK)
			inner join @Tbl T ON R.DocPrintLayoutID=T.ReportID
		COMMIT TRANSACTION 
	end
end
 
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
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
