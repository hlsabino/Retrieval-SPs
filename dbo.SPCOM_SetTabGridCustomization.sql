USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SPCOM_SetTabGridCustomization]
	@ParentCCID [bigint],
	@ChildCCID [bigint],
	@DataXML [nvarchar](max),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
 
 
	Declare @XML XML  
 
  --SP Required Parameters Check  
 SET @XML=@DataXML  
 delete from [COM_TabGridCustomize] where ParentCostCenter=@ParentCCID and ChildCostCenter=@ChildCCID
 
 CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),SYSCOLUMN NVARCHAR(300),USERCOLUMN NVARCHAR(300),WIDTH FLOAT,VISIBLE BIT,
 GRIDORDER INT)
 
 INSERT INTO #TBLTEMP
  SELECT  X.value('@SysColumnName','nvarchar(300)'), X.value('@UserColumnName','nvarchar(300)'),
	   X.value('@Width','nvarchar(300)'),  X.value('@Visible','bit') ,X.value('@GridOrder','INT') 
   from @XML.nodes('Fields/Row') as Data(X) ORDER BY X.value('@GridOrder','INT') ASC
   
   DECLARE @COUNT INT,@I INT,@GRIDORDER INT,@ISVISIBLE INT,@MAXNOFORZEROVALUES INT
   SELECT @I=1,@COUNT=COUNT(*),@GRIDORDER=1 FROM #TBLTEMP
   SELECT @MAXNOFORZEROVALUES=MAX(GRIDORDER)+1 FROM #TBLTEMP WHERE VISIBLE=1 
   WHILE @I<=@COUNT
   BEGIN 
   SELECT @ISVISIBLE=VISIBLE FROM #TBLTEMP WHERE ID=@I
   IF @ISVISIBLE=0
   BEGIN 
     INSERT INTO [COM_TabGridCustomize] 
     SELECT @ParentCCID,@ChildCCID,SYSCOLUMN,USERCOLUMN,WIDTH,0,@GRIDORDER FROM #TBLTEMP WHERE ID=@I
   END 
   ELSE
   BEGIN
	   IF(EXISTS(SELECT * FROM #TBLTEMP WHERE ID=@I AND GRIDORDER=0 AND VISIBLE=1))
	   BEGIN
 
			 INSERT INTO [COM_TabGridCustomize] 
			 SELECT @ParentCCID,@ChildCCID,SYSCOLUMN,USERCOLUMN,WIDTH,@I,@MAXNOFORZEROVALUES FROM #TBLTEMP WHERE ID=@I
			 SET @MAXNOFORZEROVALUES=@MAXNOFORZEROVALUES+1
	   END
	   ELSE
	   BEGIN
	   
		INSERT INTO [COM_TabGridCustomize] 
		 SELECT @ParentCCID,@ChildCCID,SYSCOLUMN,USERCOLUMN,WIDTH,@I,@GRIDORDER FROM #TBLTEMP WHERE ID=@I
		 SET @GRIDORDER=@GRIDORDER+1
	   END
	
   END
   
   SET @I=@I+1
   END
	 
   
   --if(@ChildCCID=118)
   --begin
   --update adm_costcenterdef set sectionseqnumber=X.value('@GridOrder','INT') ,
   --uiwidth=X.value('@Width','nvarchar(300)'),IsVisible=X.value('@Visible','bit')
   --from @XML.nodes('Fields/Row') as Data(X)
   --where costcenterid=@ChildCCID and syscolumnname=X.value('@SysColumnName','nvarchar(300)')
   --end
  
COMMIT TRANSACTION 

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID

return 1
GO
