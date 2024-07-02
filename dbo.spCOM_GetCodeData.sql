USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCodeData]
	@CostCenterID [int],
	@ParentID [int],
	@DataXML [nvarchar](max),
	@Dt [datetime] = null,
	@IsName [bit] = 0,
	@IsGroupCode [smallint] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;    
	-- Declare the variable here
	DECLARE @Result nvarchar(500),@Year nvarchar(4),@Month nvarchar(20),@Day nvarchar(2),@DocDate datetime,
		@CodeNumberRoot INT,@CodeNumberInc int,
		@CurrentCodeNumber INT,@IsSeqNoExists BIT,@ContinuousSeqNo BIT,@SeqNoLen int,
		@IsParentCodeInherited bit,@CompanyGUID nvarchar(50),@DATA XML,@Code nvarchar(300),
		@Suffix NVARCHAR(100),@CodePrefix NVARCHAR(500),@CodeNumber NVARCHAR(20),
		@ColID INT,@colType nvarchar(50),@Delimiter nvarchar(2),@TblName nvarchar(50),@PK nvarchar(30),@ApplyAutoCode int
		,@ShowSeriesNos bit,@SameSeriesForGroups bit,@ShowAutoManual bit,@IsGroupMaual bit,@SeriesStart int,@SeriesEnd int,@TempParentID INT
	declare @SQL nvarchar(max)
	
	/*IF len(@DataXML)>0
	begin	
		if @DataXML like '<Password>%'
		begin
			declare @DATAStr nvarchar(max),@DATAStr2 nvarchar(max)
			set @DATAStr2=convert(nvarchar(max),@DATA)
			set @DATA=@DataXML
			SELECT @DataXML=X.value('@NodeID','INT') FROM @DATA.nodes('Password/Row') as DATA(X)
			exec [spCom_GetAutCodeXML] @DATAStr2,1,@CostCenterID,@DATAStr output
			select @DataXML=@DATAStr
		end
		set @DATA=@DataXML
	end*/

	SET @DocDate=getdate()
	set @ShowAutoManual=0

	--Reading Costcenter code definition
	SELECT  @CodeNumberRoot=CodeNumberRoot,
			@CodeNumberInc=CodeNumberInc,
			@CurrentCodeNumber=CurrentCodeNumber,
			@ContinuousSeqNo=ContinuousSeqNo,
			@IsParentCodeInherited=IsParentCodeInherited,
			@CompanyGUID=CompanyGUID,
			@DATA=PrefixContent,
			@ApplyAutoCode=ApplyAutoCode
	FROM COM_CostCenterCodeDef WITH(nolock)
	WHERE CostCenterID=@CostCenterID and IsName=@IsName and IsGroupCode=@IsGroupCode

	--Check Childrens Auto/Manual
	SELECT  @ShowSeriesNos=ShowSeriesNos,@ShowAutoManual=ShowAutoManual,@SameSeriesForGroups=SameSeriesForGroups
	FROM COM_CostCenterCodeDef WITH(nolock)
	WHERE CostCenterID=@CostCenterID and IsName=@IsName and IsGroupCode=1
	if @ShowAutoManual=1
	begin
		set @ShowAutoManual=isnull((select top 1 IsManual from COM_CCCCDATA with(nolock) where CostCenterID=@CostCenterID and NodeID=@ParentID),0)
		if @ShowAutoManual=1
		begin
			select null Prefix,null Number,null Suffix,null Code,@ShowAutoManual IsManualCode
			--rollback transaction
			return 1
		end
	end
	
	if @IsName=0 and ((@CostCenterID IN (2,3,72,92,93,94) and @ParentID=1) or (@CostCenterID>50000 and @ParentID=2)) 
	and exists(select RootNodeAuto from COM_CostCenterCodeDef with(nolock) where CostCenterID=@CostCenterID and IsName=@IsName and IsGroupCode=@IsGroupCode and RootNodeAuto=0)
	begin
		select null Prefix,null Number,null Suffix,null Code,1 IsManualCode
		return 1
	end


	SET @Result=''
	set @CodePrefix=null
	set @Suffix=null

	select @TblName=TableName,@PK=PrimaryKey from adm_features with(nolock) where featureid=@CostCenterID

    DECLARE @TblDef AS TABLE(ID INT IDENTITY(1,1),NAME nvarchar(300),Length NVARCHAR(50),ColID INT,Delimiter NVARCHAR(2),
    colType NVARCHAR(50),Value NVARCHAR(MAX))
	INSERT INTO @TblDef(NAME,[Length],ColID,Delimiter,colType)
	SELECT X.value('@Name','NVARCHAR(300)'),X.value('@Length','NVARCHAR(50)'),X.value('@CCCID','INT'),X.value('@Delimiter','nvarchar(2)'),
	X.value('@Type','nvarchar(50)')
	FROM @DATA.nodes('XML/Row') as DATA(X)
	
	IF len(@DataXML)>0
	begin	
		if @DataXML like '<Password>%'
		begin
			declare @DATAStr nvarchar(max),@DATAStr2 nvarchar(max)
			set @DATAStr2=convert(nvarchar(max),@DATA)
			set @DATA=@DataXML
			SELECT @DataXML=X.value('@NodeID','INT') FROM @DATA.nodes('Password/Row') as DATA(X)
			
			exec [spCom_GetAutCodeXML] @DATAStr2,@DataXML,@CostCenterID,@DATAStr output
			select @DataXML=@DATAStr
		end
		set @DATA=@DataXML
		
		UPDATE @TblDef
		SET Value=X.value('@Value','nvarchar(200)')
		FROM @TblDef D,@DATA.nodes('Data/Row') as DATA(X)
		WHERE D.ColID=X.value('@ColID','INT')
	end

--	select * from @TblDef

	DECLARE @I INT,@COUNT INT,@Length INT,@Format NVARCHAR(50),@NAME NVARCHAR(300),@Value NVARCHAR(MAX)
	declare @str nvarchar(max) ,@NodeidXML nvarchar(max)
	declare @columnCCID INT, @tbname nvarchar(200) ,@listval nvarchar(200)
	SELECT @COUNT=COUNT(*) FROM @TblDef  
	SET @I=1 
	
	WHILE @I<=@COUNT
	BEGIN 
		SELECT @NAME=[NAME],@Format=Length,@ColID=ColID,@Delimiter=Delimiter,@colType=colType,@Value=Value 
		FROM @TblDef WHERE ID=@I 

		IF len(@DataXML)>0 and @Value is null and @ColID not in(-1,-2,-4,-5,-6)
		begin
			set @I=@I+1
			continue;
		END
		
		set @listval=null
		
		if(@ColID<0)
			select @columnCCID =columncostcenterid from adm_costcenterdef with(nolock) where costcentercolid=-@ColID
		else
			select @columnCCID =columncostcenterid from adm_costcenterdef with(nolock) where costcentercolid=@ColID
	 
	 	if ISNUMERIC(@Format)=1
			set @Length=convert(INT,@Format)
		else
			set @Length=0  

		if(@Value is not null and @columnCCID is not null and (@columnccid=2 or @columnccid=3 or @columnccid=11 or @columnccid=72 or @columnccid=92 or @columnccid=93 or @columnccid=94 or @columnccid=44 or (@columnccid>50000 and @columnccid<50057) or @columnccid>50999 ))
		begin
			declare @cccol nvarchar(20),@ccPK nvarchar(20)			
			select @tbname=tablename,@ccPK=PrimaryKey from adm_features where featureid=@columnccid  
			set @str='@listval nvarchar(200) output' 			
			if(@columnccid=11)			
				set @cccol='UnitName'					
			else if(@columnccid=72)
			begin
				set @cccol='Assetcode'
				if(@ColID<0)
					set @cccol='AssetName'
			end
			else if(@columnccid=2)
			begin
				set @cccol='AccountName'
				if(@ColID<0)
					set @cccol='AccountCode'
			end
			else if(@columnccid=3)
			begin
				set @cccol='ProductName'
				if(@ColID<0)
					set @cccol='ProductCode'
			end
			else if(@columnccid=94)
			begin
				set @cccol='Tenantcode'
				if(@ColID<0)
					set @cccol='Tenantcode'
			end
			else
			begin
				set @cccol='name'
				if(@ColID<0)
					set @cccol='code'
			end

			set @NodeidXML='set @listval= (select '+@cccol+' from '+convert(nvarchar,@tbname)+' where '+@ccPK+'='+convert(nvarchar,@value)+')'	
			exec sp_executesql @NodeidXML, @str, @listval OUTPUT  
		
			if @Length=-1 or @Length=0
				set @Result=@Result+@listval
			else
				set @Result=@Result+substring(@listval,1,@Length)
			--select @IsName,@columnCCID,@ColID,@Value,@listval,@Result,@Format
		end
		else 
		begin 
			--SELECT @NAME,@Format,@Length,@ColID,@Delimiter,@colType FROM @TblDef WHERE ID=@I  
			if @ColID=-1--SEQ NO
			begin
				set @IsSeqNoExists=1
				set @SeqNoLen=@Length
				if @I>0
					set @CodePrefix=@Result
				set @Result=''
			end
			else if @ColID=-4--CUSTOM TEXT
			begin
				set @Result=@Result+@Format
			end
			else if @ColID=-5--PARENT CODE
			begin
				exec [spCOM_GetParentCodeData] @CostCenterID,@ParentID,@Code output 
				if @Length=-1
					set @Result=@Result+@Code
				else
					set @Result=@Result+substring(@Code,1,@Length)
			end
			else if @ColID=-2--COMPANY
				set @Result=@Result +(SELECT substring([NAME],1,@Length) FROM PACT2C.dbo.ADM_Company WHERE CompanyGUID=@CompanyGUID)
			else if @ColID=-3--FEATURE
				set @Result=@Result + (SELECT substring([NAME],1,@Length) FROM ADM_FEATURES WHERE FEATUREID=@CostCenterID)
			else
			begin
		 
				if @Value is not null or @ColID=-6
				begin
					if @colType='DATE'
					begin
						declare @TmpDate datetime
						
						if @ColID=-6--TODAYS DATE
						begin	  
							if(@CostCenterID=73 and @Dt is not null)
								set @TmpDate=@Dt
							else
								set @TmpDate=@DocDate
						end
						else
							set @TmpDate=CONVERT(DATETIME,@Value)
					 
						SELECT @Year=datepart(year,@TmpDate)
						SELECT @Month=upper(datename(month,@TmpDate))
						SELECT @Day=datepart(day,@TmpDate)
						
						if @Format='Y'
							set @Result=@Result+substring(@Year,4,1)
						else if @Format='YY'
							set @Result=@Result+substring(@Year,3,2)
						else if @Format='YYYY'
							set @Result=@Result+@Year
						else if @Format='DD'
						begin
							if @Day<10
								set @Result=@Result+'0'+convert(nvarchar,@Day)
							else
								set @Result=@Result+convert(nvarchar,@Day)					
						end
						else if @Format='MM'
						begin
							if datepart(month,@TmpDate)<10
								set @Result=@Result+'0'+convert(nvarchar,datepart(month,@TmpDate))
							else
								set @Result=@Result+convert(nvarchar,datepart(month,@TmpDate))						
						end
						else if @Format='MMM'
							set @Result=@Result+substring(@Month,1,3)
						else if @Format='Name'
							set @Result=@Result+@Month
					
						else if @Format='MM/YY'
						BEGIN
							if datepart(month,@TmpDate)<10
								set @Result=@Result+'0'+convert(nvarchar,datepart(month,@TmpDate))
							else
								set @Result=@Result+convert(nvarchar,datepart(month,@TmpDate))	
							set @Result=@Result+'/'+substring(@Year,3,2)
						END 
						else if @Format='DDMMYY'
						BEGIN
							if datepart(day,@TmpDate)<10
								set @Result=@Result+'0'+convert(nvarchar,datepart(day,@TmpDate))
							else
								set @Result=@Result+convert(nvarchar,datepart(day,@TmpDate))
								
							if datepart(month,@TmpDate)<10
								set @Result=@Result+'0'+convert(nvarchar,datepart(month,@TmpDate))
							else
								set @Result=@Result+convert(nvarchar,datepart(month,@TmpDate))	
							set @Result=@Result+substring(@Year,3,2)
						END 
						else if @Format='DDMMYYYY'
						BEGIN
							if datepart(day,@TmpDate)<10
								set @Result=@Result+'0'+convert(nvarchar,datepart(day,@TmpDate))
							else
								set @Result=@Result+convert(nvarchar,datepart(day,@TmpDate))
								
							if datepart(month,@TmpDate)<10
								set @Result=@Result+'0'+convert(nvarchar,datepart(month,@TmpDate))
							else
								set @Result=@Result+convert(nvarchar,datepart(month,@TmpDate))	
							set @Result=@Result+@Year
						END 
						else if @Format='MM/YYYY'
							BEGIN
							if datepart(month,@TmpDate)<10
								set @Result=@Result+'0'+convert(nvarchar,datepart(month,@TmpDate))
							else
								set @Result=@Result+convert(nvarchar,datepart(month,@TmpDate))	
							set @Result=@Result+'/'+@Year
						END
						else if @Format='MMM/YY'
							set @Result=@Result+substring(UPPER(SUBSTRING(@Month,1,1))+LOWER(SUBSTRING(@Month,2,LEN(@Month))),1,3)+'/'+substring(@Year,3,2)
						else if @Format='MMM/YYYY'
							set @Result=@Result+substring(UPPER(SUBSTRING(@Month,1,1))+LOWER(SUBSTRING(@Month,2,LEN(@Month))),1,3)+'/'+@Year
						
						else if @Format='Name/YY'
							set @Result=@Result+UPPER(SUBSTRING(@Month,1,1))+LOWER(SUBSTRING(@Month,2,LEN(@Month)))+'/'+substring(@Year,3,2)
						else if @Format='Name/YYYY'
							set @Result=@Result+UPPER(SUBSTRING(@Month,1,1))+LOWER(SUBSTRING(@Month,2,LEN(@Month)))+'/'+@Year
							
							
					end
					else
					begin
						if @Length=-1
							set @Result=@Result+@Value
						else
							set @Result=@Result+substring(@Value,1,@Length)
					end
				end
				set @Result=@Result
			end 
		end
		 
		if @I<@COUNT
		begin
		  --if @listval is not null or @Value is not null --Condition commented in the case : ParentCode,SeqNo(delimiter not coming)
				set @Result=@Result+@Delimiter
		end
		SET @I=@I+1
	END		

	if @CodePrefix is not null and @Suffix is null
		set @Suffix=@Result
		
	if @CodePrefix is null
		set @CodePrefix=@Result
		
	if @IsSeqNoExists=1
	begin
	
		if @IsGroupCode=1 and @SameSeriesForGroups=0
		begin
			set @SeriesEnd=0
		end
		else if @ShowSeriesNos=1
		begin
			set @SeriesEnd=0
			set @TempParentID=@ParentID			
			while(1=1)
			begin
				select @SeriesStart=SeriesStart,@SeriesEnd=SeriesEnd from COM_CCCCDATA with(nolock) where CostCenterID=@CostCenterID and NodeID=@TempParentID
				if @SeriesEnd>0
					break
				set @SQL='select @TempParentID=ParentID from '+@TblName+' with(nolock) where '+@PK+'='+convert(nvarchar,@TempParentID)
				--print @SQL
				exec sp_executesql @SQL,N'@TempParentID INT OUTPUT',@TempParentID OUTPUT
				--select @TempParentID
				if @TempParentID=1 or @TempParentID=0
					break
			end
			--select @SeriesStart
		end
		
		SELECT @NAME=[NAME],@Format=Length,@ColID=ColID,@Delimiter=Delimiter,@colType=colType,@Value=Value FROM @TblDef  WHERE ColID=-1
		Declare @AccLen int
	--	if(@IsParentCodeInherited=1)
		begin
			if(@CostCenterID=2)
			BEGIN
				select @AccLen=GroupSeqNoLength from ACC_Accounts with(nolock) where AccountID=@ParentID 
				if(@AccLen>0)
					set @SeqNoLen=@AccLen
			END	
			else if (@CostCenterID=3)
			begin
				select @AccLen=GroupSeqNoLength from INV_Product with(nolock) where ProductID=@ParentID 
				if(@AccLen>0)
					set @SeqNoLen=@AccLen
			end 
			
			else if (@CostCenterID>50000 OR @CostCenterID=92 OR @CostCenterID=93 OR @CostCenterID=94)
			begin
				declare @NumSQL nvarchar(max)
				if(@CostCenterID=94)
					set @NumSQL='select  @AccLen=GroupSeqNoLength from '+@TblName+' with(nolock) where TenantID='+Convert(nvarchar,@ParentID) +' ' 
				else
					set @NumSQL='select  @AccLen=GroupSeqNoLength from '+@TblName+' with(nolock) where NodeID='+Convert(nvarchar,@ParentID) +' ' 
				exec sp_executesql @NumSQL,N'@AccLen INT OUTPUT',@AccLen OUTPUT 
			   print 	@AccLen
				IF(@AccLen>0 and @AccLen is not null)
					set @SeqNoLen=@AccLen
			end
		end

		set @SQL='select @CodeNumber=ISNULL(max(A.CodeNumber),0) from '+@TblName+' A with(nolock)'

		--if(@ApplyAutoCode=1)
		--	set @SQL=@SQL+' and A.IsGroup=0'
		--else if(@ApplyAutoCode=2)
		--	set @SQL=@SQL+' and A.IsGroup=1'
		
		if @ContinuousSeqNo=0
		begin
			declare @temp nvarchar(200)
			set @temp=ISNULL(@CodePrefix,'')+ISNULL(@Suffix,'')
			if(@SeriesEnd>0)
			begin				
				set @SQL=@SQL+' inner join '+@TblName+' P with(nolock) on A.lft>P.lft and A.lft<P.rgt'
				set @SQL=@SQL+' where P.'+@PK+'='+convert(nvarchar,@TempParentID)
			end
			else 
			begin
				set @SQL=@SQL+' where 1=1'
				if @temp=''
					set @SQL=@SQL+' and (A.CodePrefix is null or A.CodePrefix='''+@temp+''')'
				else
					set @SQL=@SQL+' and A.CodePrefix='''+@temp+''''	
			end	
		end

		print @SQL
		exec sp_executesql @SQL,N'@CodeNumber FLOAT OUTPUT',@CurrentCodeNumber OUTPUT
		
		set @CurrentCodeNumber=@CurrentCodeNumber+1
		
		if(@SeriesEnd>0)
		begin		
			if @CurrentCodeNumber>@SeriesEnd
			begin
				select null Prefix,null Number,null Suffix,null Code,@ShowAutoManual IsManualCode,@SeriesEnd ExceedsLimit
				--rollback transaction
				return 1
			end
			else if(@CurrentCodeNumber<@SeriesStart)
			begin
				set @CurrentCodeNumber=@SeriesStart
			end
		end
		
		
		--Append sequence number
		set @SeqNoLen=@SeqNoLen-len(convert(nvarchar,@CurrentCodeNumber))
		set @CodeNumber=ISNULL(replicate('0',@SeqNoLen),'')+convert(nvarchar,@CurrentCodeNumber)
	end

	select @CodePrefix Prefix,@CodeNumber Number,@Suffix Suffix,ISNULL(@CodePrefix,'')+ISNULL(@CodeNumber,'')+ISNULL(@Suffix,'') Code
		,@ShowAutoManual IsManualCode

--COMMIT TRANSACTION    
SET NOCOUNT OFF;     
RETURN 1
END TRY
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT 'ERROR' 
		END  
		ELSE
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=1 
			
 --ROLLBACK TRANSACTION  
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH
GO
