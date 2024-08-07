﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_UpdateAssignLeavesConsumed]
	@DATE [datetime] = NULL,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

					DECLARE @CURRYEARALDOCNO INT
					SET @CURRYEARALDOCNO=(SELECT DISTINCT TOP 1 DOCID FROM INV_DOCDETAILS 
 										  WHERE YEAR(CONVERT(DATETIME,DOCDATE))=YEAR(CONVERT(DATETIME,@Date)) AND COSTCENTERID=40060	ORDER BY DOCID DESC)

					DECLARE @UPDATEAL TABLE(InvDocID INT,dcCCNID51 INT,dcCCNID53 INT,dcCCNID52 INT,
										 PrevYearAlloted INT,PrevYearBalanceOB INT,CurrYearConsumed DECIMAL(9,2),Balance DECIMAL(9,2),CurrYearAlloted INT)
					INSERT INTO @UPDATEAL 
					SELECT ID.INVDOCDETAILSID,DC.dcCCNID51,DC.dcCCNID53,DC.dcCCNID52,0,0,0,0,ISNULL(DN.DCNUM3,0)
					FROM   INV_DOCDETAILS ID,COM_DocCCData DC ,COM_DocNumData DN
					WHERE  ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DN.INVDOCDETAILSID AND DC.INVDOCDETAILSID=DN.INVDOCDETAILSID
						   AND ID.DOCID=@CURRYEARALDOCNO



		--CURRENT YEAR CONSUMED LEAVES	
		UPDATE T SET T.CurrYearConsumed=LT.NOOFDAYSTAKEN
						FROM @UPDATEAL T 
							INNER JOIN
							(SELECT DC.dcCCNID51,DC.dcCCNID52,DC.dcCCNID53,SUM(ISNULL(CONVERT(DECIMAL(9,2),TD.dcAlpha7),0)) AS NOOFDAYSTAKEN
								FROM COM_DocTextData TD,INV_DOCDETAILS ID,COM_DocCCData DC 
								WHERE  TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND TD.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND
								YEAR(CONVERT(DATETIME,ID.DOCDATE))=YEAR(CONVERT(DATETIME,@Date)) AND ID.COSTCENTERID=40062
								group by DC.dcCCNID51,DC.dcCCNID52,DC.dcCCNID53) LT  
								ON LT.DCCCNID51=T.DCCCNID51  AND LT.DCCCNID53= T.DCCCNID53 AND LT.DCCCNID52=T.DCCCNID52
		
		--PREVIOUS YEAR ALLOTED LEAVES			
		UPDATE T SET T.PrevYearAlloted=CONVERT(DECIMAL,DN.DCNUM3)
				FROM INV_DOCDETAILS ID WITH(NOLOCK)
				INNER JOIN COM_DocCCData C51 WITH(NOLOCK) ON C51.INVDOCDETAILSID=ID.INVDOCDETAILSID
				--INNER JOIN COM_DocCCData C53 WITH(NOLOCK) ON C53.INVDOCDETAILSID=ID.INVDOCDETAILSID
				--INNER JOIN COM_DocCCData C52 WITH(NOLOCK) ON C52.INVDOCDETAILSID=ID.INVDOCDETAILSID
				INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON DN.INVDOCDETAILSID=ID.INVDOCDETAILSID
				INNER JOIN COM_CCCCDATA CC WITH(NOLOCK) ON C51.DCCCNID51=CC.NODEID AND CC.COSTCENTERID=50051
				INNER JOIN  @UPDATEAL T ON T.DCCCNID51=C51.DCCCNID51 AND T.DCCCNID52=C51.DCCCNID52 AND T.DCCCNID53=C51.DCCCNID53
				WHERE YEAR(CONVERT(DATETIME,ID.DOCDATE))=YEAR(CONVERT(DATETIME,DATEADD("yy",-1,@Date))) AND ID.COSTCENTERID=40060
				
		--OPENING BALANCE
		UPDATE T SET T.PrevYearBalanceOB=ISNULL(E.OpVacationDays ,0)
				FROM @UPDATEAL T INNER JOIN  COM_CC50051 E ON T.DCCCNID51=E.NODEID 
							INNER JOIN  COM_CCCCDATA EG ON  E.NODEID=EG.NODEID  AND T.DCCCNID53=EG.CCNID53  WHERE EG.COSTCENTERID=50051
		--BALANCE LEAVES							
		UPDATE @UPDATEAL SET Balance=ISNULL(PrevYearBalanceOB ,0)+ISNULL(CurrYearAlloted ,0)-ISNULL(CurrYearConsumed ,0)

		UPDATE DN SET DN.DCNUM1=T.PrevYearAlloted,
			   DN.DCNUM2=T.PrevYearBalanceOB,
			   DN.DCNUM4=T.CurrYearConsumed,
			   DN.DCNUM5=Balance 
		  FROM COM_DocNumData DN INNER JOIN @UPDATEAL T ON T.InvDocID=DN.INVDOCDETAILSID

--SELECT * FROM @UPDATEAL
SET NOCOUNT OFF;
END
GO
