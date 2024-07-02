USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spUTL_GetProcedureMetaData]
	@objname [nvarchar](776) = NULL
WITH ENCRYPTION, EXECUTE AS CALLER
AS
set nocount on
	select
		'Parameter_name' = t1.name,
		'Type'=type_name(xusertype),
		'Length'=CASE WHEN type_name(xusertype)='Text' THEN 2147483647 ELSE convert(int,length) END,
		'Prec'=CASE WHEN type_name(xusertype)='uniqueidentifier' THEN xprec ELSE odbcPrec(t1.xtype,length,xprec) END,
		'Param_order' = colid,
		'Out_parameter' = isoutparam
	from syscolumns t1,sysobjects t2
	where t1.id = t2.id and t2.name=@objname
return (0)

GO
