USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetActivityLinking]
	@CCID [bigint] = 0,
	@LocalRefernce [int],
	@LinkXML [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@USERID [int],
	@LANGID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  	
		DECLARE @XML xml,@I INT,@Cnt INT,@LinkDefID int,@linkedCCID bigint
		DECLARE @tabTrans table(id int identity(1,1),ccid bigint)
		 
		SET @XML=@LinkXML              
          
   DELETE FROM COM_DocumentLinkDetails where DocumentLinkDefID in (
   select DocumentLinkDefID FROM [COM_DocumentLinkDef]              
   WHERE CostCenterIDBase=@CCID AND CostCenterIDLinked=@LocalRefernce)   	
    
    DELETE FROM [COM_DocumentLinkDef]              
	WHERE CostCenterIDBase=@CCID AND CostCenterIDLinked=@LocalRefernce
	 
	
           
  if(@LinkXML IS NOT NULL AND @LinkXML <>'')              
  BEGIN              
  
  	  insert into @tabTrans
	  select distinct X.value('@CostCenterIDLinked','bigint') from @XML.nodes('/Xml/Row') as Data(X)

	select @cnt=max(id),@i=min(id) from @tabTrans
	set @i=@i-1	
	while(@i<@cnt)
	begin
		set @i=@i+1
  		 select  @linkedCCID=ccid from @tabTrans Where  id=@i
		   INSERT INTO [COM_DocumentLinkDef]              
				([CostCenterIDLinked] 
				,[CostCenterIDBase]              
				,[CostCenterColIDBase]   
				,[CostCenterColIDLinked]   
				,[CompanyGUID]              
				,[GUID]              
				,[CreatedBy]              
				,[CreatedDate],Mode)  
			select @linkedCCID,
				@CCID
				,22777				 
				,111				 
				,@CompanyGUID 
				,'GUID'
				,@UserName
				,CONVERT(FLOAT,GETDATE()),0 
				  
				set @LinkDefID=scope_identity()	
	  
 	 
		insert into COM_DocumentLinkDetails(DocumentLinkDeFID,
											CostCenterColIDBase,
											CostCenterColIDLinked,
											CompanyGUID,
											GUID,
											CreatedBy,
											CreatedDate)
		select @LinkDefID,X.value('@CostCenterColIDBase','bigint'),X.value('@CostCenterColIDLink','bigint'),@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE())
		from @XML.nodes('/Xml/Row') as Data(X)
		where X.value('@CostCenterIDLinked','bigint')=@linkedCCID
		
		  UPDATE adm_costcenterDef  
   SET isEditable=1
   FROM adm_costcenterDef C   
   INNER JOIN @XML.nodes('/Xml/Row') as Data(X)    
   ON convert(bigint,X.value('@CostCenterColIDBase','bigint'))=C.CostCenterColID  
   WHERE  X.value('@CostCenterIDLinked','bigint')=@linkedCCID and C.CostCenterid=144 and C.LocalReference=@LocalRefernce
		
	END	
   END

COMMIT TRANSACTION    
--ROLLBACK TRANSACTION
SET NOCOUNT OFF; 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	ROLLBACK TRANSACTION
	SET NOCOUNT OFF  
	RETURN -999   
END CATCH 


 
GO
