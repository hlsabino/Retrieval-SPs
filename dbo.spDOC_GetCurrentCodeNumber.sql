USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetCurrentCodeNumber]
	@CostCenterID [int],
	@DocPrefix [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit,@Code varchar(100),@Length int,@temp varchar(100),@i int,@div bigint,@loc bigint
		DECLARE @divName nvarchar(500),@locName nvarchar(500)
		declare @Series bigint,@ConCCID bigint,@DType int
		--SP Required Parameters Check
		IF (@CostCenterID < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		SELECT @Series=Series,@ConCCID=ConvertAs,@DType=DocumentType FROM  ADM_DocumentTypes WITH(NOLOCK) where CostCenterID=@CostCenterID  
		if((@DType=14 or @DType=19) and @Series=1 and @ConCCID is not null and  @ConCCID>0)--alternate series   
			set @CostCenterID=@ConCCID    
	   else if(@DType<>14 and @DType<>19 and @Series is not null and @Series>40000)
			set @CostCenterID=@Series    
			
		SELECT  @Code=ISNULL(CurrentCodeNumber,0)+1,@Length=isnull(CodeNumberLength,1),@div =Division,@loc=Location  FROM COM_CostCenterCodeDef WITH(NOLOCK)--AS CurrentCodeNumber
		WHERE CostCenterID=@CostCenterID AND CodePrefix=@DocPrefix
		 
		if(len(@Code)<@Length)
		begin
		set @i=1
		set @temp=''
			while(@i<=(@Length-len(@Code)))
			begin				
				set @temp=@temp+'0'			 
					set @i=@i+1
			end
			SET @Code=@temp+cast(@Code as varchar)
		end
		
		if(@div>0) 
		select @divName=name from com_division with(nolock) where nodeid=@div
		if(@loc>0) 
		select @locName=name from com_location with(nolock) where nodeid=@loc

		SELECT @Code  AS CurrentCodeNumber,@div Division,@loc Location,@divName DivName,@locName LocName,@Length Codelength


 SET NOCOUNT OFF;
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
 SET NOCOUNT OFF  
RETURN -999   
END CATCH  









GO
