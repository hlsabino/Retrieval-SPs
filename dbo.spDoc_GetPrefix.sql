USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetPrefix]
	@DocXML [nvarchar](max),
	@DocDate [datetime],
	@CostCenterID [bigint]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @J int,@Count int,@ccnum int,@Length nvarchar(50),@Delimiter nvarchar(3),@ColName nvarchar(50),@CID BIGINT,@CCID bigint
declare @TableName nvarchar(50),@sql nvarchar(max),@temp nvarchar(500),@dcCCNID bigint,@data nvarchar(200),@tempPrefix nvarchar(200),@DetID bigint
Declare @TypeID BIGINT,@Prefix nvarchar(200) ,@SYSCOL   nvarchar(200),@indcnt int,@ind int,@FrmMont int


			select @FrmMont=AccountingFromMonth from PACT2C.dbo.ADM_Company
			where DBName=DB_NAME()

			select @TypeID=DocumentTypeID from adm_documenttypes where CostCenterID=@CostCenterID

			set @Prefix=''							 
			if exists (select CCID from COM_DocPrefix where DocumentTypeID=@TypeID)
			begin
				declare @tblpref table(tblprefID INT IDENTITY(1,1),tblCCID INT,tblLength nvarchar(50),tblDelimiter nvarchar(50))
				
				if exists(select CCID from COM_DocPrefix
				where DocumentTypeID=@TypeID and IsDefault=1)				
				BEGIN
					insert into @tblpref
					select CCID,Length,Delimiter from COM_DocPrefix
					where DocumentTypeID=@TypeID  and IsDefault=1 order by PrefixOrder
				END
				ELSE
				BEGIN
					insert into @tblpref
					select CCID,Length,Delimiter from COM_DocPrefix
					where DocumentTypeID=@TypeID and SeriesNo=0 order by PrefixOrder				
				END
				
				select @J=1,@Count=Count(tblCCID) from  @tblpref
				while(@J<=@Count)
				begin

				select @CCID=tblCCID,@Length=tblLength,@Delimiter=tblDelimiter from @tblpref where  tblprefID=@J
				set @tempPrefix=''
				IF(@CCID=51)
				BEGIN
					set @tempPrefix=DAY(@DocDate)
				END
				ELSE IF(@CCID=53)
				BEGIN 							
					set @tempPrefix=YEAR(@DocDate)
					if(@Length='YY')
						select @tempPrefix= substring(@tempPrefix,3,4)
					else if(@Length='YY-YY')
                    BEGIN
						if (MONTH(@DocDate) < @FrmMont)
							set @tempPrefix = Substring(convert(nvarchar,(YEAR(@DocDate)- 1)),3,4) + '-' + Substring(convert(nvarchar,YEAR(@DocDate)),3,4)
						else
							set @tempPrefix = Substring(convert(nvarchar,YEAR(@DocDate)),3,4) +  '-'  + Substring(convert(nvarchar,(YEAR(@DocDate)+ 1)),3,4)
					END	
				END
				ELSE IF(@CCID=52)
				BEGIN 							
					if(MONTH(@DocDate)>9)							
						set @tempPrefix=MONTH(@DocDate)
					else					
						set @tempPrefix='0'+convert(nvarchar,MONTH(@DocDate))						
					
					if(@Length='MMM')
					set @tempPrefix=CONVERT(varchar(3), @DocDate,100)
					if(@Length='Name')
					set @tempPrefix=datename(MONTH, @DocDate)
				END
				ELSE if exists(select costcenterid from adm_costcenterdef where costcentercolid=@CCID)
				begin
						select @CID=costcenterid,@ColName=SysColumnName from adm_costcenterdef where costcentercolid=@CCID
						
						set @ccnum = @CID-50000
						
				 		set @ind=Charindex('@dcCCNID',convert(nvarchar(max),@DocXML))							
							if(@ind>0)
							BEGIN							
				 				 set @temp='@DocXML XML,@dcCCNID bigint output'
								  
								 SET @sql  = 'SELECT   @dcCCNID = isnull(X.value(''@dcCCNID'+convert(nvarchar(50),@ccnum)+''',''nvarchar(max)''),1)
								 from @DocXML.nodes(''/DocumentXML/Row/CostCenters'') as Data(X)'      
								 EXEC sp_executesql @sql, @temp,@DocXML,@dcCCNID OUTPUT 
							END 
							ELSE
							BEGIN 
								set @SYSCOL='dcCCNID'+convert(nvarchar(50),@ccnum)+'='
								set @ind=Charindex(@SYSCOL,convert(nvarchar(max),@DocXML))
								 
								 if(@ind>0)
								 BEGIN
									 set @ind=Charindex('=',convert(nvarchar(max),@DocXML), Charindex(@SYSCOL,convert(nvarchar(max),@DocXML),0))
									 set @indcnt=Charindex(',',convert(nvarchar(max),@DocXML), Charindex(@SYSCOL,convert(nvarchar(max),@DocXML),0)) 
									 set @indcnt=@indcnt-@ind-1
									 if(@ind>0 and @indcnt>0)				 
									 BEGIN
										set @dcCCNID=Substring(convert(nvarchar(max),@DocXML),@ind+1,@indcnt) 
										
									 END	
								END
						   END
						select @TableName=TableName from  ADM_FEATURES where FeatureID=@CID
						if(@dcCCNID>0)
						begin
							set @temp='@data nvarchar(500) output'
							
							set @sql='select @data='+@ColName+' from ' +@TableName+' where NODEID='+convert(nvarchar(50),@dcCCNID)
							 
							exec sp_executesql @sql,@temp,@data output
							
							select @tempPrefix= substring(@data,1,convert(int,@Length))
						end
				end
 				
				set @Prefix =@Prefix+@tempPrefix+@Delimiter
				set @J=@J+1
 				end
			end
			
		
select @Prefix		
GO
