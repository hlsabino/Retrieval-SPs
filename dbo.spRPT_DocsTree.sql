USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_DocsTree]
	@DocNo [nvarchar](max),
	@IsSummary [int],
	@IsInv [bit],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
	declare @Docs nvarchar(max), @I INT,@CNT INT, @costcenterid bigint
	DECLARE @ExeQty FLOAT,@IsInventory bit
	CREATE TABLE #TblDocs (ID INT IDENTITY(1,1) PRIMARY KEY, CostCenterID INT,VoucherNo nvarchar(50),ParentVoucherNo nvarchar(50),VAbbr nvarchar(20),VPrefix nvarchar(40),VNumber int,DetailsID INT,LinkedDetailsID INT,DocDate float)
	set @Docs=''
	
if isnumeric(@DocNo)=1
begin
	CREATE TABLE #TblDef(ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT,ChildName nvarchar(max),ParentCostCenterID INT,ParentName nvarchar(max))
	
	insert into #TblDef(CostCenterID,ChildName,ParentCostCenterID,ParentName)
	select C.CostCenterID,C.DocumentName,P.CostCenterID,P.DocumentName 
	from COM_DocumentLinkDef D with(nolock)
	join ADM_DocumentTypes P with(nolock) on P.CostCenterID=D.CostCenterIDLinked
	join ADM_DocumentTypes C with(nolock) on C.CostCenterID=D.CostCenterIDBase
	where CostCenterIDLinked=@DocNo

	--select * from @TblDeff
	SET @I=0
	WHILE(1=1)
	BEGIN		
		SET @CNT=(SELECT Count(*) FROM #TblDef with(nolock))
		if @CNT>10000
			break
/*		INSERT INTO @TblDef(CostCenterID,ParentName,LinkedCostCenterID,ChildName)
		select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber
		FROM INV_DocDetails D with(nolock) 
		INNER JOIN #TblDocs T on T.ParentVoucherNo=D.VoucherNo AND T.ID>@I
		LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
		LEFT JOIN #TblDocs TD on TD.VoucherNo=D.VoucherNo AND TD.ParentVoucherNo=P.VoucherNo-- AND TD.ID>@I
		WHERE T.ParentVoucherNo!='-1' and TD.VoucherNo IS NULL and D.CostCenterID>0
		group by D.CostCenterID,D.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,P.VoucherNo
	*/
		
		INSERT INTO #TblDef(CostCenterID,ChildName,ParentCostCenterID,ParentName)
		select T.ParentCostCenterID,T.ParentName,-1,'-1'
		from #TblDef T with(nolock)
		left join #TblDef TD with(nolock) ON T.ParentCostCenterID=TD.CostCenterID
		left JOIN COM_DocumentLinkDef D with(nolock) ON T.ParentCostCenterID=D.CostCenterIDBase 
		where D.CostCenterIDBase is null and TD.CostCenterID is null and T.ParentCostCenterID!=-1 
		group by T.ParentCostCenterID,T.ParentName

		INSERT INTO #TblDef(CostCenterID,ChildName,ParentCostCenterID,ParentName)
		select C.CostCenterID,C.DocumentName,P.CostCenterID,P.DocumentName
		from COM_DocumentLinkDef D with(nolock)
		join ADM_DocumentTypes C with(nolock) on C.CostCenterID=D.CostCenterIDBase
		JOIN #TblDef T with(nolock) ON T.ParentCostCenterID=C.CostCenterID AND ID>@I and ID<=@CNT
		join ADM_DocumentTypes P with(nolock) on P.CostCenterID=D.CostCenterIDLinked
		left join #TblDef TD with(nolock) ON TD.CostCenterID=P.CostCenterID
		where TD.CostCenterID IS NULL
		group by P.CostCenterID,P.DocumentName,C.CostCenterID,C.DocumentName
			
		INSERT INTO #TblDef(CostCenterID,ChildName,ParentCostCenterID,ParentName)
		select C.CostCenterID,C.DocumentName,P.CostCenterID,P.DocumentName
		from COM_DocumentLinkDef D with(nolock)
		join ADM_DocumentTypes P with(nolock) on P.CostCenterID=D.CostCenterIDLinked
		join ADM_DocumentTypes C with(nolock) on C.CostCenterID=D.CostCenterIDBase
		JOIN #TblDef T with(nolock) ON T.CostCenterID=P.CostCenterID AND ID>@I and ID<=@CNT
		left join #TblDef TD with(nolock) ON TD.ParentCostCenterID=P.CostCenterID
		where TD.CostCenterID IS NULL
		group by C.CostCenterID,C.DocumentName,P.CostCenterID,P.DocumentName
	
	    IF @CNT=(SELECT Count(*) FROM #TblDef with(nolock))
			BREAK
			
		SET @I=@CNT
	END
	
	if (select count(*) from #TblDef with(nolock))>0
		select CostCenterID,ChildName VoucherNo,ParentCostCenterID,ParentName ParentVoucherNo from #TblDef with(nolock)
		group by CostCenterID ,ChildName,ParentCostCenterID,ParentName
		order by ChildName
	else
		select D.CostCenterID,D.DocumentName VoucherNo,-1 ParentCostCenterID,'-1' ParentVoucherNo
		FROM ADM_DocumentTypes D with(nolock) 
		WHERE D.CostCenterID=@DocNo
		
	select 1 where 1!=1
	DROP TABLE #TblDef
end
else if(@DocNo like 'LINEID:%')
begin
	set @DocNo=substring(@DocNo,8,len(@DocNo))
	if exists (select D.VoucherNo FROM INV_DocDetails D with(nolock) WHERE D.InvDocDetailsID=@DocNo)
	begin
		set @IsInventory=1
		INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
		select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate
		FROM INV_DocDetails D with(nolock) 
		LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
		WHERE D.InvDocDetailsID=@DocNo and D.DynamicInvDocDetailsID is null
	end
	else
	begin
		set @IsInventory=0
		INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
		select distinct D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,null,D.RefNodeID,D.DocDate
		FROM ACC_DocDetails D with(nolock) 
		LEFT JOIN ACC_DocDetails P with(nolock) ON D.RefCCID=400 and P.AccDocDetailsID=D.RefNodeID
		WHERE D.AccDocDetailsID=@DocNo
	end
	
	SET @I=0
	IF @IsInventory=1
	BEGIN
		WHILE(1=1)
		BEGIN		
			SET @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
			if @CNT>10000
				break
			INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
			select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate
			FROM INV_DocDetails D with(nolock) 
			INNER JOIN #TblDocs T with(nolock) on T.LinkedDetailsID=D.InvDocDetailsID AND T.ID>@I
			LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
			LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo collate database_default=D.VoucherNo collate database_default AND TD.ParentVoucherNo collate database_default=P.VoucherNo collate database_default-- AND TD.ID>@I
			WHERE T.ParentVoucherNo collate database_default!='-1' and TD.VoucherNo IS NULL and D.CostCenterID>0 and D.DynamicInvDocDetailsID is null
			
			IF @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
				BREAK			
			SET @I=@CNT
		END
		SET @I=0
		WHILE(1=1)
		BEGIN		
			SET @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
			if @CNT>10000
				break
			IF @I=0
				INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
				SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
				FROM INV_DocDetails INV with(nolock) 
				INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID
				INNER JOIN #TblDocs T with(nolock) ON TINV.InvDocDetailsID=T.DetailsID AND ID>@I and ID=1
				LEFT JOIN #TblDocs TD with(nolock) on TD.DetailsID=INV.LinkedInvDocDetailsID AND TD.ParentVoucherNo collate database_default=TINV.VoucherNo collate database_default-- AND TD.ID>@I
				where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null
			ELSE
				INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
				SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
				FROM INV_DocDetails INV with(nolock) 
				INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID
				INNER JOIN #TblDocs T with(nolock) ON TINV.InvDocDetailsID=T.DetailsID AND ID>@I and ID<=@CNT
				LEFT JOIN #TblDocs TD with(nolock) on TD.DetailsID=INV.LinkedInvDocDetailsID AND TD.ParentVoucherNo collate database_default=TINV.VoucherNo collate database_default-- AND TD.ID>@I
				where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null
			
			IF @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
				BREAK			
			SET @I=@CNT
		END
	END

	select CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,CONVERT(DATETIME,DocDate) DocDate from #TblDocs with(nolock)
	group by CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DocDate
	order by VPrefix,VNumber
	
	if @IsInventory=1
	begin
		select max(T.VoucherNo) VoucherNo,sum(Quantity) Qty,sum(Gross) Value
		from #TblDocs T with(nolock)
		inner join INV_DocDetails D with(nolock) on D.InvDocDetailsID=T.DetailsID
		where (D.DocumentType!=5 or D.VoucherType=1) and D.DynamicInvDocDetailsID is null
		group by T.DetailsID
			
		select B.RefDocNo BWDocNo,T.VoucherNo ParentVoucherNo from #TblDocs T with(nolock)
		join COM_BillWise B with(nolock) on T.VoucherNo collate database_default=B.DocNo collate database_default
		where B.RefDocNo is not null
		union
		select B.DocNo,T.VoucherNo ParentVoucherNo from #TblDocs T with(nolock)
		join COM_BillWise B with(nolock) on T.VoucherNo collate database_default=B.RefDocNo collate database_default
		where B.DocNo is not null
		order by BWDocNo
		
		--select CostCenterID from #TblDocs with(nolock)
		--where VoucherNo not in (select ParentVoucherNo from #TblDocs with(nolock))
	end
	else
		select null VoucherNo,0 Qty,0 Value
		where 1!=1

	--SELECT * from #TblDocs with(nolock)
end
else if @IsSummary=2
begin
	INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
		select distinct D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate
		FROM INV_DocDetails D with(nolock) 
		LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
		WHERE D.VoucherNo=@DocNo and D.DynamicInvDocDetailsID is null
		union
		select distinct D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate
		FROM INV_DocDetails D with(nolock) 
		LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
		WHERE (D.DocAbbr+'-'+D.DocPrefix+D.DocNumber)=@DocNo and D.DynamicInvDocDetailsID is null
		
		
	SET @I=0

			WHILE(1=1)
			BEGIN		
				SET @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
				if @CNT>10000
					break
				INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
				select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate
				FROM INV_DocDetails D with(nolock) 
				INNER JOIN #TblDocs T with(nolock) on T.LinkedDetailsID=D.InvDocDetailsID AND T.ID>@I
				LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
				LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo collate database_default=D.VoucherNo collate database_default AND TD.ParentVoucherNo collate database_default=P.VoucherNo collate database_default-- AND TD.ID>@I
				WHERE T.ParentVoucherNo collate database_default!='-1' and TD.VoucherNo IS NULL and D.CostCenterID>0 and D.DynamicInvDocDetailsID is null
				
				IF @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
					BREAK			
				SET @I=@CNT
			END
			
			SET @I=0
			WHILE(1=1)
			BEGIN		
				SET @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
				if @CNT>10000
					break
				IF @I=0
					INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
					SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
					FROM INV_DocDetails INV with(nolock) 
					INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID
					INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID=1
					LEFT JOIN #TblDocs TD with(nolock) on TD.DetailsID=INV.LinkedInvDocDetailsID AND TD.ParentVoucherNo collate database_default=TINV.VoucherNo collate database_default-- AND TD.ID>@I
					where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null
				ELSE
					INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
					SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
					FROM INV_DocDetails INV with(nolock) 
					INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID
					INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID<=@CNT
					LEFT JOIN #TblDocs TD with(nolock) on TD.DetailsID=INV.LinkedInvDocDetailsID AND TD.ParentVoucherNo collate database_default=TINV.VoucherNo collate database_default-- AND TD.ID>@I
					where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null
				
				IF @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
					BREAK			
				SET @I=@CNT
			END
		
		
	select T.*,DT.DocumentName,convert(datetime,T.DocDate) VoucherDate from #TblDocs T
	JOIN ADM_DocumentTypes DT with(nolock) on DT.CostCenterID=T.CostCenterID
end
else
begin
	if exists (select D.VoucherNo FROM INV_DocDetails D with(nolock) 
	WHERE D.VoucherNo=@DocNo
	union
	select D.VoucherNo FROM INV_DocDetails D with(nolock) 
	WHERE (DocAbbr+'-'+DocPrefix+DocNumber)=@DocNo)
	begin
		set @IsInventory=1
		INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
		select distinct D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate
		FROM INV_DocDetails D with(nolock) 
		LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
		WHERE D.VoucherNo=@DocNo and D.DynamicInvDocDetailsID is null
		union
		select distinct D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate
		FROM INV_DocDetails D with(nolock) 
		LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
		WHERE (D.DocAbbr+'-'+D.DocPrefix+D.DocNumber)=@DocNo and D.DynamicInvDocDetailsID is null		
	end
	else
	begin
		set @IsInventory=0
		INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
		select distinct D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,null,D.RefNodeID,D.DocDate
		FROM ACC_DocDetails D with(nolock) 
		LEFT JOIN ACC_DocDetails P with(nolock) ON D.RefCCID=400 and P.AccDocDetailsID=D.RefNodeID
		WHERE D.VoucherNo=@DocNo
		union
		select distinct D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,null,D.RefNodeID,D.DocDate
		FROM ACC_DocDetails D with(nolock) 
		LEFT JOIN ACC_DocDetails P with(nolock) ON D.RefCCID=400 and P.AccDocDetailsID=D.RefNodeID
		WHERE (D.DocAbbr+'-'+D.DocPrefix+D.DocNumber)=@DocNo
	end

	SET @I=0

	IF @IsInventory=1
	BEGIN	
		IF @IsSummary=1
		BEGIN
			WHILE(1=1)
			BEGIN		
				SET @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
				if @CNT>10000
					break
					
				INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
				select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate
				FROM INV_DocDetails D with(nolock) 
				INNER JOIN #TblDocs T with(nolock) on T.LinkedDetailsID=D.InvDocDetailsID AND T.ID>@I
				LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
				LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo collate database_default=D.VoucherNo collate database_default AND TD.ParentVoucherNo collate database_default=P.VoucherNo collate database_default-- AND TD.ID>@I
				WHERE T.ParentVoucherNo collate database_default!='-1' and TD.VoucherNo IS NULL and D.CostCenterID>0 and D.DynamicInvDocDetailsID is null
				
				IF @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
					BREAK			
				SET @I=@CNT
			END
			
			SET @I=0
			WHILE(1=1)
			BEGIN		
				SET @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
				if @CNT>10000
					break
				IF @I=0
				BEGIN
					INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
					SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
					FROM INV_DocDetails INV with(nolock) 
					INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID
					INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID=1
					LEFT JOIN #TblDocs TD with(nolock) on TD.DetailsID=INV.LinkedInvDocDetailsID AND TD.ParentVoucherNo collate database_default=TINV.VoucherNo collate database_default-- AND TD.ID>@I
					where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null

					select @costcenterid=CostCenterID from #TblDocs WITH(NOLOCK)

					IF(ISNULL(@costcenterid,0)=40065)
					BEGIN
						UPDATE T SET T.ParentVoucherNo=I.VoucherNo FROM INV_DOCDETAILS I WITH(NOLOCK) 
						JOIN INV_DocDetails A WITH(NOLOCK) ON A.RefNodeid=I.InvDocDetailsID
						JOIN #TblDocs T WITH(NOLOCK) ON T.VoucherNo=A.VoucherNo
						WHERE A.CostCenterID=40065 AND A.RefNodeid>0

						INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
						SELECT distinct INV.CostCenterID,INV.VoucherNo,NULL,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
						FROM INV_DocDetails INV with(nolock) 
						INNER JOIN INV_DocDetails TINV with(nolock) on TINV.RefNodeid=INV.InvDocDetailsID
						INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID=1
						where INV.CostCenterID>0 
					END
					
					if(ISNULL(@costcenterid,0)=40072 OR ISNULL(@costcenterid,0)=40062 )
					begin
						INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
						SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
						FROM INV_DocDetails INV with(nolock) 
						INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.RefNodeid
						INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID=1
						where INV.CostCenterID>0 
					end
					
				END
				ELSE
					INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
					SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
					FROM INV_DocDetails INV with(nolock) 
					INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID
					INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID<=@CNT
					LEFT JOIN #TblDocs TD with(nolock) on TD.DetailsID=INV.LinkedInvDocDetailsID AND TD.ParentVoucherNo collate database_default=TINV.VoucherNo collate database_default-- AND TD.ID>@I
					where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null
					
				
				IF @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
					BREAK			
				SET @I=@CNT
			END
		END
		ELSE
		BEGIN
			WHILE(1=1)
			BEGIN		
				SET @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
				if @CNT>10000
					break
			--	select *,@I,@CNT from #TblDocs with(nolock)

				INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DocDate)
				select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.DocDate
				FROM INV_DocDetails D with(nolock) 
				INNER JOIN #TblDocs T with(nolock) on T.ParentVoucherNo collate database_default=D.VoucherNo collate database_default AND T.ID>@I
				LEFT JOIN INV_DocDetails P with(nolock) ON P.InvDocDetailsID=D.LinkedInvDocDetailsID
				LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo collate database_default=D.VoucherNo collate database_default AND TD.ParentVoucherNo collate database_default=P.VoucherNo collate database_default-- AND TD.ID>@I
				WHERE T.ParentVoucherNo collate database_default!='-1' and TD.VoucherNo IS NULL and D.CostCenterID>0 and D.DynamicInvDocDetailsID is null
				group by D.CostCenterID,D.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,P.VoucherNo,D.DocDate
			
				INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DocDate)
				SELECT INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.DocDate
				FROM INV_DocDetails INV with(nolock) 
				INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID
				INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID<=@CNT
				LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo collate database_default=INV.VoucherNo collate database_default AND TD.ParentVoucherNo collate database_default=TINV.VoucherNo collate database_default-- AND TD.ID>@I
				where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null
				group by INV.CostCenterID,INV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,TINV.VoucherNo,INV.DocDate
				 
				 select @costcenterid=CostCenterID from #TblDocs WITH(NOLOCK)

					IF(ISNULL(@costcenterid,0)=40065)
					BEGIN
						UPDATE T SET T.ParentVoucherNo=I.VoucherNo FROM INV_DOCDETAILS I WITH(NOLOCK) 
						JOIN INV_DocDetails A WITH(NOLOCK) ON A.RefNodeid=I.InvDocDetailsID
						JOIN #TblDocs T WITH(NOLOCK) ON T.VoucherNo=A.VoucherNo
						WHERE A.CostCenterID=40065 AND A.RefNodeid>0

						INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
						SELECT distinct INV.CostCenterID,INV.VoucherNo,NULL,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
						FROM INV_DocDetails INV with(nolock) 
						INNER JOIN INV_DocDetails TINV with(nolock) on TINV.RefNodeid=INV.InvDocDetailsID
						INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID=1
						where INV.CostCenterID>0 
					END
					
					if(ISNULL(@costcenterid,0)=40072 OR ISNULL(@costcenterid,0)=40062 )
					begin
						INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
						SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate
						FROM INV_DocDetails INV with(nolock) 
						INNER JOIN INV_DocDetails TINV with(nolock) on TINV.InvDocDetailsID=INV.RefNodeid
						INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID=1
						where INV.CostCenterID>0 
					end

				 IF @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
					BREAK
					
				SET @I=@CNT
			END
		END
	END
	ELSE
	BEGIN
		WHILE(1=1)
		BEGIN		
			SET @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
			if @CNT>10000
				break
			--select *,@I,@CNT from #TblDocs with(nolock)

--		LEFT JOIN ACC_DocDetails P with(nolock) ON D.RefCCID=400 and P.DocID=D.RefNodeID
		
		
			INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DocDate)
			select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.DocDate
			FROM ACC_DocDetails D with(nolock) 
			INNER JOIN #TblDocs T with(nolock) on T.ParentVoucherNo=D.VoucherNo AND T.ID>@I
			LEFT JOIN ACC_DocDetails P with(nolock) ON D.RefCCID=400 and P.AccDocDetailsID=D.RefNodeID
			LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo collate database_default=D.VoucherNo collate database_default AND TD.ParentVoucherNo collate database_default=P.VoucherNo collate database_default-- AND TD.ID>@I
			WHERE T.ParentVoucherNo collate database_default!='-1' and TD.VoucherNo IS NULL and D.CostCenterID>0
			group by D.CostCenterID,D.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,P.VoucherNo,D.DocDate
			/*select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber
			FROM ACC_DocDetails D with(nolock) 
			INNER JOIN #TblDocs T with(nolock) on T.ParentVoucherNo=D.VoucherNo AND T.ID>@I
			LEFT JOIN ACC_DocDetails P with(nolock) ON D.RefCCID=400 and P.DocID=D.RefNodeID
			LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo=D.VoucherNo AND TD.ParentVoucherNo=P.VoucherNo-- AND TD.ID>@I
			WHERE T.ParentVoucherNo!='-1' and TD.VoucherNo IS NULL and D.CostCenterID>0
			group by D.CostCenterID,D.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,P.VoucherNo*/
		
			INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DocDate)
			SELECT INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.DocDate
			FROM ACC_DocDetails INV with(nolock) 
			INNER JOIN ACC_DocDetails TINV with(nolock) on INV.RefCCID=400 and INV.RefNodeID=TINV.AccDocDetailsID
			INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo collate database_default=T.VoucherNo collate database_default AND ID>@I and ID<=@CNT
			LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo collate database_default=INV.VoucherNo collate database_default AND TD.ParentVoucherNo collate database_default=TINV.VoucherNo collate database_default-- AND TD.ID>@I
			where TD.VoucherNo IS NULL and INV.CostCenterID>0
			group by INV.CostCenterID,INV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,TINV.VoucherNo,INV.DocDate
			/*SELECT INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber
			FROM ACC_DocDetails INV with(nolock) 
			INNER JOIN ACC_DocDetails TINV with(nolock) on INV.RefCCID=400 and INV.RefNodeID=TINV.DocID
			INNER JOIN #TblDocs T with(nolock) ON TINV.VoucherNo=T.VoucherNo AND ID>@I and ID<=@CNT
			LEFT JOIN #TblDocs TD with(nolock) on TD.VoucherNo=INV.VoucherNo AND TD.ParentVoucherNo=TINV.VoucherNo-- AND TD.ID>@I
			where TD.VoucherNo IS NULL and INV.CostCenterID>0
			group by INV.CostCenterID,INV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,TINV.VoucherNo*/
			 
			 IF @CNT=(SELECT Count(*) FROM #TblDocs with(nolock))
				BREAK
				
			SET @I=@CNT
		END
	END
	----PrePayment Preference
	INSERT INTO #TblDocs(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)
		   SELECT DISTINCT D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,P.InvDocDetailsID,D.REFNODEID,D.DocDate
		   FROM Acc_DocDetails D with(nolock) INNER JOIN INV_DocDetails P with(nolock) ON P.DocID=D.REFNODEID
		   WHERE (P.DocAbbr+'-'+P.DocPrefix+P.DocNumber)=@DocNo and D.REFCCID=300 
	--
	select CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,CONVERT(DATETIME,DocDate) DocDate from #TblDocs with(nolock)
	group by CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DocDate
	order by VPrefix,VNumber
	
	if (@IsInventory=1 or @IsInv=0 )
	begin
		select T.*,sum(Quantity) Qty,sum(Gross) Value
		from (select VoucherNo from #TblDocs with(nolock) group by VoucherNo) T
		inner join INV_DocDetails D with(nolock) on D.VoucherNo collate database_default=T.VoucherNo collate database_default
		where (D.DocumentType!=5 or D.VoucherType=1) and D.DynamicInvDocDetailsID is null
		group by T.VoucherNo
			
		select B.RefDocNo BWDocNo,T.VoucherNo ParentVoucherNo,convert(datetime,B.RefDocDate) DocDate from #TblDocs T with(nolock)
		join COM_BillWise B with(nolock) on T.VoucherNo collate database_default=B.DocNo collate database_default
		where B.RefDocNo is not null AND B.RefDocNo<>''
		union
		select B.DocNo,T.VoucherNo ParentVoucherNo,convert(datetime,B.DocDate) DocDate from #TblDocs T with(nolock)
		join COM_BillWise B with(nolock) on T.VoucherNo collate database_default=B.RefDocNo collate database_default
		where B.DocNo is not null AND B.DocNo<>''
		order by BWDocNo
		
		--select CostCenterID from #TblDocs with(nolock)
		--where VoucherNo not in (select ParentVoucherNo from #TblDocs with(nolock))
	end
	else
		select null VoucherNo,0 Qty,0 Value
		where 1!=1
end

DROP TABLE  #TblDocs

SET NOCOUNT OFF;  
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
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
