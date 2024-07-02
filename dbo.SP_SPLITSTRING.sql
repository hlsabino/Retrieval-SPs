﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SPLITSTRING]
	@PARAM1 [nvarchar](max)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

DECLARE @TAB TABLE(ID BIGINT IDENTITY(1,1),TABLENAME VARCHAR(300))
INSERT INTO @TAB
SELECT DATA FROM [fnCOM_SplitString] (@PARAM1,',')
SELECT * FROM @TAB


END
GO
