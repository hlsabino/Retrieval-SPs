USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetGridView]
	@CallType [int],
	@COSTCENTERID [int],
	@TypeID [int],
	@StrXml [nvarchar](max),
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
SET NOCOUNT ON    
BEGIN TRY    
	declare @XML xml,@sql nvarchar(max),@DT Float
	
	set @DT=convert(Float,getdate())
	if @CallType=1
	begin
		if(@StrXml is not null and @StrXml<>'')
		BEGIN
			set @sql=' select * from ADM_MobileGridView with(nolock)
			where CostCenterID='+convert(nvarchar(max),@CostCenterID)+' and TypeID='+convert(nvarchar(max),@TypeID)+@StrXml			
			exec(@sql)
		END
		ELSE
			select * from ADM_MobileGridView with(nolock)
			where CostCenterID=@CostCenterID and TypeID=@TypeID 
			
	end
	else if @CallType=2
	begin
		set @XML=@StrXml
		delete from ADM_MobileGridView
		where CostCenterID=@CostCenterID and TypeID=@TypeID 

		insert into ADM_MobileGridView(TypeID,CostCenterID,DimType,Name,CostCenterColID,CompanyGUID,GUID,CreatedBy,CreatedDate,[Type],RowNo,ColNo,RowSpan,ColSpan,Mode)
		select X.value('@TypeID','INT'),@CostCenterID,X.value('@DimType','nvarchar(50)'),X.value('@Name','nvarchar(50)')
							,X.value('@CostCenterColID','INT')
							,null,newid(),@UserID,@DT,X.value('@Type','nvarchar(50)')
							,isnull(X.value('@row','int'),0),isnull(X.value('@col','int'),0),isnull(X.value('@rowspan','int'),1),isnull(X.value('@colspan','int'),1)
							,isnull(X.value('@Mode','int'),0)
							from  @XML.nodes('/XML/Rows') as Data(x)
	end
SET NOCOUNT OFF;     
COMMIT TRANSACTION 
 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID        
SET NOCOUNT OFF;      
RETURN 1
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT * FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID=@COSTCENTERID     
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
