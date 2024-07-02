USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetReconcileAvgRate]
	@ProductXML [nvarchar](max),
	@DocDate [datetime],
	@DocID [int],
	@IsFromReconcile [bit],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON        
        
      DECLARE @TblProducts AS TABLE(ID INT IDENTITY(1,1),PID INT,qty float,invid INT,rowcc nvarchar(max))  
      DECLARE @TblRates AS TABLE(PID INT ,invid INT ,AvgRate Float)  
      declare @i int,@cnt int,@XML xml,@rowcc nvarchar(max) ,@AvgWHERE  nvarchar(max),@PrefValue nvarchar(100),@NID INT
   declare @value INT,@QOH float,@AvgRate float,@HOLDQTY FLOAT,@RESERVEQTY FLOAT,@DocQty float, @DocDetailsID INT  
      DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID INT,NodeId INT)        

   set @XML=@ProductXML  
  INSERT INTO @TblProducts  
   SELECT X.value('@ProductID','INT'), X.value('@QTY','float'),   X.value('@DETAILSID','INT'),X.value('@avgwhere','nvarchar(max)')
  FROM @XML.nodes('/PXML/Row') as Data(X)  
         
              
   set @i=0  
   select @cnt=count(*) from @TblProducts  
   while @i<@cnt  
   begin  
    set @i=@i+1  
    set @rowcc=''  
    select @value=PID,@DocQty=qty,@DocDetailsID=invid,@rowcc=rowcc  
     from @TblProducts where ID=@i  
     
        EXEC  [spDOC_ReconcileAvgValue] @value,@rowcc,@DocDate,@DocQty,@DocDetailsID,@IsFromReconcile,@DocID,@AvgRate OUTPUT
 
      insert into @TblRates(PID,invid,AvgRate)values(@value,@DocDetailsID,@AvgRate)  
   end   
      
    select PID,invid,AvgRate from @TblRates  
    
COMMIT TRANSACTION        
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
ROLLBACK TRANSACTION        
SET NOCOUNT OFF          
RETURN -999           
END CATCH
GO
