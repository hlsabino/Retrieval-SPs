USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_PCRate]
	@PID [bigint],
	@ToDate [datetime],
	@RateColumn [nvarchar](50),
	@PCFilter [nvarchar](max) = NULL,
	@Rate [float] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId BIGINT)
	DECLARE @WHERE NVARCHAR(MAX),@I INT,@COUNT INT,@Query NVARCHAR(MAX),@JOIN nvarchar(max),@ORDER nvarchar(max)
	,@TblName nvarchar(50),@IsGroupExists bit,@NodeID bigint
	SET @JOIN=''
	SET @ORDER=''
	SET @WHERE='(WEF<=@EDATE and (TillDate is null or TillDate>=@EDATE)) and ProductID=@PID'	
	SET @WHERE=@WHERE+' AND '+@RateColumn+'>0'
	IF @RateColumn like 'SellingRate%'
		SET @WHERE=@WHERE+' AND (PriceType=0 or PriceType=1)'
	ELSE IF @RateColumn like 'PurchaseRate%'
		SET @WHERE=@WHERE+' AND (PriceType=0 or PriceType=2)'
	ELSE
		SET @WHERE=@WHERE+' AND (PriceType=0 or PriceType=3)'
		
	if @PCFilter!=''
	begin
		declare @xml xml
		set @xml=@PCFilter
		insert into @tblCC
		select X.value('@CC','int'),X.value('@ID','bigint')
		from @xml.nodes('PC/Row') as DATA(X)
	end

	SET @I=50000       
	SET @COUNT=50050
	WHILE(@I<@COUNT)
	BEGIN
		SET @I=@I+1    
		
		set @NodeID=null
		select @NodeID=NodeID from @tblCC where CostCenterID=@I
		IF @NodeID IS NOT NULL
		BEGIN
			SET @IsGroupExists=null
			SELECT @IsGroupExists=IsGroupExists,@TblName=b.TableName FROM COM_CCPriceTaxCCDefn a WITH(NOLOCK)
				join ADM_Features b WITH(NOLOCK) on a.[CostCenterID]=b.FeatureID
			where [DefType]=1 and ProfileID=0 and IsGroupExists=1 and CostCenterID=@I
			if @IsGroupExists=1
			begin
				set @JOIN=@JOIN+' join '+@tblName+' CC'+CONVERT(nvarchar,@I)+' on P.CCNID'+CONVERT(nvarchar,@I-50000)+'=CC'+CONVERT(nvarchar,@I)+'.NodeID
								join '+@tblName+'  CJ'+CONVERT(nvarchar,@I)+' on CJ'+CONVERT(nvarchar,@I)+'.lft between CC'+CONVERT(nvarchar,@I)+'.lft and CC'+CONVERT(nvarchar,@I)+'.rgt'
				set @WHERE=@WHERE+' AND CJ'+CONVERT(nvarchar,@I)+'.NODEID='+convert(nvarchar,@NodeID)
			end
			else
				SET @WHERE=@WHERE+' AND (CCNID'+convert(nvarchar,@I-50000)+'='+convert(nvarchar,@NodeID)+' or CCNID'+convert(nvarchar,@I-50000)+'=0)'
			set @ORDER=@ORDER+'P.CCNID'+convert(nvarchar,@I-50000)+','
		END
		ELSE
			SET @WHERE=@WHERE+' AND CCNID'+convert(nvarchar,@I-50000)+'=0'
	END
	
	SET @Query='DECLARE @PID BIGINT,@EDATE float
set @PID='+CONVERT(NVARCHAR,@PID)+'
set @EDATE='+convert(nvarchar,convert(float,@ToDate))
	
	SET @Query=@Query+'
set @Rate=(SELECT TOP 1 '+@RateColumn+' FROM COM_CCPrices P with(nolock) '+@JOIN+'
WHERE '+@WHERE+'		
ORDER BY '+@ORDER+'WEF DESC)
		'	

	SET @Query=@Query+'
IF @Rate IS NULL
	SELECT @Rate='+@RateColumn+' FROM INV_Product with(nolock) WHERE ProductID=@PID '
	
	--SET @Query=@Query+' select @Rate'
	
	--print (@Query)
	
	--EXEC(@Query)
	EXEC sp_executesql @Query,N'@Rate FLOAT OUTPUT',@Rate OUTPUT
GO
