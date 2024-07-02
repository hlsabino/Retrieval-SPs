USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDocPrefix]
	@DocPrefixXml [nvarchar](max),
	@IsDefault [bit],
	@Type [int],
	@IsDelete [bit] = 0,
	@CompanyGUID [nvarchar](200),
	@UserName [nvarchar](200),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION                
BEGIN TRY                
SET NOCOUNT ON;              
	--Declaration Section              
	DECLARE @HasAccess BIT,@XML XML,@SeriesNo int,@I int, @Cnt int,@DocumentTypeID BIGINT
	             
	declare @tabcc table(ID bigint identity(1,1),CCCID bigint)
	if(@Type=2)
		insert into @tabcc	             
		SELECT DocumentTypeID  FROM ADM_DocumentTypes WITH(NOLOCK) where isinventory=0
	else if(@Type=3)
		insert into @tabcc	             
		SELECT DocumentTypeID FROM ADM_DocumentTypes WITH(NOLOCK) where isinventory=1
	else 
		insert into @tabcc	             
		SELECT DocumentTypeID FROM ADM_DocumentTypes WITH(NOLOCK)
		
     
     SELECT @I=0,@Cnt=count(ID) FROM @tabcc

  WHILE(@I<@Cnt)                
  BEGIN     
	set  @I=@I+1        
    SELECT @DocumentTypeID=CCCID FROM @tabcc where ID=@I
      select @DocumentTypeID
	
	select @SeriesNo=max(seriesno) from [COM_DocPrefix]
	where [DocumentTypeID]=@DocumentTypeID
	
	if(@SeriesNo is null)
		set @SeriesNo=-1
	
	set @SeriesNo=@SeriesNo+1	
	
	set @XML=@DocPrefixXml
	
	if(@IsDefault=1)
	BEGIN
		UPdate	[COM_DocPrefix]
		set Isdefault=0
		where [DocumentTypeID]=@DocumentTypeID
	END
	if(@IsDelete=0)
	begin
		INSERT INTO [COM_DocPrefix]              
		   ([DocumentTypeID]              
		   ,[CCID]              
		   ,[Length]              
		   ,[Delimiter]              
		   ,[PrefixOrder]
		   ,seriesno
		   ,Isdefault
		   ,[CompanyGUID]              
		   ,[GUID]              
		   ,[CreatedBy]              
		   ,[CreatedDate])              
		 select @DocumentTypeID              
		 ,X.value('@CCID','int')
		 ,X.value('@Length','nvarchar(50)')              
		 ,X.value('@Delimiter','nvarchar(50)')              
		 ,X.value('@PrefixOrder','int')      
		 ,@SeriesNo
		 ,@IsDefault
		 ,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE())              
		 FROM @XML.nodes('/Prefix/Row') as Data(X)  
     end     
     else
     begin
		delete from  COM_DocPrefix 
		where docprefixid in (select d.docprefixid from COM_DocPrefix d
		join @XML.nodes('/Prefix/Row') as Data(X)  
		on d.DocumentTypeID=@DocumentTypeID and d.ccid=X.value('@CCID','int') and
		d.length=X.value('@Length','nvarchar(50)') and d.delimiter=X.value('@Delimiter','nvarchar(50)')
		and d.prefixorder=X.value('@PrefixOrder','int') ) 
     end        
    END
    
COMMIT TRANSACTION                
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
WHERE ErrorNumber=100 AND LanguageID=@LangID              
SET NOCOUNT OFF;                
RETURN @DocumentTypeID                
END TRY                
BEGIN CATCH                
 --Return exception info [Message,Number,ProcedureName,LineNumber]                
 IF ERROR_NUMBER()=50000              
 BEGIN                             
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID              
 END              
 ELSE IF ERROR_NUMBER()=547              
 BEGIN              
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)              
  WHERE ErrorNumber=-110 AND LanguageID=@LangID              
 END              
 ELSE IF ERROR_NUMBER()=2627              
 BEGIN              
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)              
  WHERE ErrorNumber=-116 AND LanguageID=@LangID              
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
