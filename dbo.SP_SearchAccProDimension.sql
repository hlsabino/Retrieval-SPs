USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SearchAccProDimension]
	@CostCenterID [bigint] = 0,
	@SearchValue [nvarchar](100),
	@RowCount [int] = 10,
	@LastRowValue [nvarchar](100) = null
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	Declare @Table nvarchar(max) ,@sql nvarchar(max)
	 --Check for manadatory paramters      
   --if(@CostCenterID=0)      
   --BEGIN      
   --  RAISERROR('-100',16,1)      
   --END  
  
   SELECT @Table=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterID
   
   if(@CostCenterID=2)      
	   BEGIN    
	    if(@LastRowValue is null)  
	    BEGIN
			set @sql='SELECT distinct top '+CONVERT(nvarchar,@RowCount)+' ACCOUNTID,ACCOUNTNAME, ACCOUNTCODE FROM '+@Table 
			set @sql=@sql+' with(nolock) WHERE (ACCOUNTNAME like  N''%'+@SearchValue+'%'' OR ACCOUNTCODE like  N''%'+@SearchValue+'%'')'
			set @sql=@sql + ' AND ISGROUP=0 and AccountID > 0'
		END
		else
		BEGIN
			set @sql='SELECT distinct top '+CONVERT(nvarchar,@RowCount)+' ACCOUNTID,ACCOUNTNAME, ACCOUNTCODE FROM '+@Table 
			set @sql=@sql+' with(nolock) WHERE ISGROUP=0 and AccountID > 0 AND (ACCOUNTNAME >N'''+@LastRowValue+''')'
			set @sql=@sql + ' ORDER BY ACCOUNTNAME   '
		END
	   END  
   ELSE if(@CostCenterID=3)      
   BEGIN
    if(@LastRowValue is null)  
	    BEGIN
			set @sql='SELECT distinct top '+CONVERT(nvarchar,@RowCount)+' PRODUCTID,PRODUCTNAME, PRODUCTCODE FROM '+@Table 
			set @sql=@sql+' with(nolock) WHERE (PRODUCTNAME like  N''%'+@SearchValue+'%'' OR PRODUCTCODE like  N''%'+@SearchValue+'%'')'
			set @sql=@sql + ' AND ISGROUP=0 '
		END
		else
		BEGIN
			set @sql='SELECT distinct top '+CONVERT(nvarchar,@RowCount)+' PRODUCTID,PRODUCTNAME, PRODUCTCODE FROM '+@Table 
			set @sql=@sql+' with(nolock) WHERE ISGROUP=0 AND (PRODUCTNAME >N'''+@LastRowValue+''')'
			set @sql=@sql + ' ORDER BY PRODUCTNAME   '
		END
   END
   ELSE
   BEGIN 
    if(@LastRowValue is null)  
	    BEGIN
			set @sql='SELECT distinct top '+CONVERT(nvarchar,@RowCount)+' NODEID,NAME, CODE FROM '+@Table 
			set @sql=@sql+' with(nolock) WHERE (NAME like  N''%'+@SearchValue+'%'' OR CODE like  N''%'+@SearchValue+'%'')'
			set @sql=@sql + ' AND ISGROUP=0 '
		END
		else
		BEGIN
			set @sql='SELECT distinct top '+CONVERT(nvarchar,@RowCount)+' NODEID,NAME, CODE FROM '+@Table 
			set @sql=@sql+' with(nolock) WHERE ISGROUP=0  AND (NAME >N'''+@LastRowValue+''')'
			set @sql=@sql + ' ORDER BY NAME   '
		END
   END
  print @sql
  exec (@sql)
   
END

--Sp_SearchAccProDimension 2,'AB',10,'SALARIES PAYABLE'
--select * from ACC_Accounts  where ACCOUNTNAME = N'ZONES INC'

GO
