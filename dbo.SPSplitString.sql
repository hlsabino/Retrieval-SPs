USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SPSplitString]
	@StrList [nvarchar](max) = NULL,
	@SplitChar [nvarchar](2) = ';'
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--Declaring variables  
declare @Data nvarchar(max),@Pos INT  
CREATE TABLE #TList (ID int identity(1,1),Data nvarchar(max))   
SET @StrList=LTRIM(RTRIM(@StrList))+@SplitChar  
SET @Pos=CHARINDEX(@SplitChar,@StrList,1)  
IF REPLACE(@StrList,@SplitChar,'')<>''  
BEGIN  
 WHILE @Pos > 0  
 BEGIN  
  SET @Data=LTRIM(RTRIM(LEFT(@StrList,@Pos-1)))  
  INSERT INTO #TList VALUES(@Data)  
  SET @StrList=RIGHT(@StrList,LEN(@StrList)-@Pos)  
  SET @Pos=CHARINDEX(@SplitChar,@StrList,1)  
 END  
  
  
END  
  
select Data from #TList  order by ID
  
drop table #TList
GO
