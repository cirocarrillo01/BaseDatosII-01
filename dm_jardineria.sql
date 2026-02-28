
-- Crear Base de Datos --

CREATE DATABASE dm_jardineria1;
use dm_jardineria1;

-- DIEMNSIONES --

-- DimFecha
CREATE TABLE DimFecha (
	DateKey int not null primary key, -- YYYYMMDD
    Fecha date not null,
    Anio smallint not null,
    Mes tinyint not null,
    Dia tinyint not null,
    Trimestre tinyint not null,
    Semana tinyint not null,
    unique key UK_DimFecha (Fecha),
    index IX_DimFecha_Anio (Anio)
);

-- DimProducto
CREATE TABLE DimProducto(
	ProductoKey int not null auto_increment primary key,
    IdProductoOLTP varchar(50) not null, -- producto.id_producto
    IdCategoriaOLTP int not null,
    NombreProducto varchar(70) not null,
    Proveedor varchar(50) null,
    PrecioVenta decimal(15,2) null,
    DescCategoria varchar(100) not null,
    
    unique key UK_DimProducto_IdOLTP (IdProductoOLTP),
    index IX_DimProducto_nombre (NombreProducto),
    index IX_DimProducto_categoria(DescCategoria),
    index IX_DimProducto_Idcategoria (IdCategoriaOLTP)
);

-- DimCliente
CREATE TABLE DimCliente(
	ClienteKey int not null auto_increment primary key,
    idClienteOLTP int not null, -- cliente.id_cliente
    NombreCliente varchar(100) not null,
    Ciudad varchar(50) null,
    Region varchar(50) null,
    Pais varchar(50) null,
    unique key UK_DimCliente_IdOLTP (IdClienteOLTP),
    index IX_DimCliente_Pais (Pais),
    index IX_DimCliente_nombre (NombreCliente)
);

-- Tabla de Hechos
CREATE TABLE FactVentas (
	VentaKey bigint not null auto_increment primary key,
    DateKey int not null,
    ProductoKey int not null,
    ClienteKey int not null,
    IdPedidoOLTP int not null,
    NumeroLinea int not null,
    Cantidad int not null,
    PrecioUnidad decimal(15,2) not null,
    Importe decimal(15,2) as (Cantidad * PrecioUnidad) STORED,
    
    unique key UK_FactVentas_Grano (IdPedidoOLTP, ProductoKey, NumeroLinea),
    index IX_FactVentas_DateKey (DateKey),
    index IX_FactVentas_ProductoKey (ProductoKey),
    index IX_FactVentas_ClienteKey (ClienteKey),
    index IX_FactVentas_Pedido (IdPedidoOLTP),
    
    constraint FK_FactVentas_DimFecha foreign key (DateKey) references DimFecha (DateKey),
    constraint FK_FactVentas_DimProducto foreign key (ProductoKey) references DimProducto(ProductoKey),
    constraint FK_FactVentas_DimCliente foreign key (ClienteKey) references DimCliente (ClienteKey)
);

SET FOREIGN_KEY_CHECKS = 1;

-- CARGA INICIAL DESDE OLTP jardineria1 --

use dm_jardineria1; 
-- Carga DimProducto
INSERT INTO DimProducto (IdProductoOLTP, IdCategoriaOLTP, NombreProducto, Proveedor, PrecioVenta, DescCategoria) 
select
	p.ID_producto,
	p.Categoria,
	p.nombre,
	p.proveedor,
	p.precio_venta,
	c.Desc_Categoria
from jardineria1.producto p
inner join jardineria1.categoria_producto c
	on c.ID_categoria = p.Categoria
where not exists (
	select 1
	from DimProducto dp
	where dp.IdProductoOLTP = p.id_producto
);
-- verificar carga
SELECT CONCAT('DimProducto: ', ROW_COUNT(), ' registros insertados') AS Resultado;

-- Ver carga de datos
SELECT * FROM DimProducto LIMIT 10;

USE dm_jardineria1;
-- Carga DimCliente
INSERT INTO DimCliente (IdClienteOLTP, NombreCliente, Ciudad, Region, Pais)
select
	c.ID_cliente,
	c.nombre_cliente,
    c.ciudad,
    c.region,
    c.pais
from jardineria1.cliente c
where not exists (
	select 1
    from DimCliente d 
    where d.IdClienteOLTP = c.id_cliente
);
-- verificar carga
SELECT CONCAT('DimCliente: ', ROW_COUNT(), ' registros insertados') AS Resultado;

-- Ver carga de datos
SELECT * FROM DimCliente LIMIT 10;

USE dm_jardineria1;
--  carga fecha
INSERT INTO DimFecha (DateKey, Fecha, Anio, Mes, Dia, Trimestre, Semana)
select distinct
	cast(date_format(p.fecha_pedido, '%Y%m%d') AS unsigned) AS DateKey,
    p.fecha_pedido AS Fecha,
    year(p.fecha_pedido) AS Anio,
    month(p.fecha_pedido) AS Mes,
    day(p.fecha_pedido) AS Dia,
    quarter(p.fecha_pedido) AS Trimestre,
    week(p.fecha_pedido) AS Semana
from jardineria1.pedido p
where not exists(
	select 1
    from DimFecha d 
    where d.fecha = p.fecha_pedido
);
-- Verificar carga
SELECT CONCAT('DimFecha: ', ROW_COUNT(), ' registros insertados') AS Resultado;

-- Ver carga de datos
SELECT * FROM DimFecha LIMIT 10;

USE dm_jardineria1;

-- Cargar FactVentas
INSERT INTO FactVentas (DateKey, ProductoKey, ClienteKey, IdPedidoOLTP, NumeroLinea, Cantidad, PrecioUnidad)
SELECT
    CAST(DATE_FORMAT(pe.fecha_pedido, '%Y%m%d') AS UNSIGNED) AS DateKey,
    dp.ProductoKey,
    dc.ClienteKey,
    pe.id_pedido AS IdPedidoOLTP,
    dpe.numero_linea AS NumeroLinea,
    dpe.cantidad AS Cantidad,
    dpe.precio_unidad AS PrecioUnidad
FROM jardineria1.detalle_pedido dpe
INNER JOIN jardineria1.pedido pe ON dpe.id_pedido = pe.id_pedido
INNER JOIN jardineria1.cliente cl ON pe.id_cliente = cl.id_cliente
INNER JOIN dm_jardineria1.DimProducto dp ON dpe.id_producto = dp.IdProductoOLTP
INNER JOIN dm_jardineria1.DimCliente dc ON cl.id_cliente = dc.IdClienteOLTP
LEFT JOIN dm_jardineria1.DimFecha df ON df.Fecha = pe.fecha_pedido
WHERE NOT EXISTS (
    SELECT 1 FROM FactVentas fv 
    WHERE fv.IdPedidoOLTP = pe.id_pedido 
    AND fv.ProductoKey = dp.ProductoKey
    AND fv.NumeroLinea = dpe.numero_linea
);

-- Verificar carga (DEBERÍAS VER MÁS DE 100 REGISTROS)
SELECT COUNT(*) AS 'Registros en FactVentas' FROM FactVentas;

-- Ver carga de datos
SELECT * FROM FactVentas LIMIT 20;

-- tres preguntas analiticas --

-- producto mas venv_producto_mas_vendidodido
create or replace view V_Producto_Mas_Vendido AS
select
	p.NombreProducto,
    p.DescCategoria,
    sum(f.Cantidad) AS TotalUnidades,
    sum(f.Importe) AS TotalVentas,
    count(distinct f.IdPedidoOLTP) AS NumeroPedidos,
    avg(f.PrecioUnidad) AS PrecioPromedio
from FactVentas f
	Inner join DimProducto p on f.ProductoKey = p.ProductoKey
    group by p.ProductoKey, p.NombreProducto, p.DescCategoria
    order by TotalUnidades desc;

-- categoria con mas productos
create or replace view V_Categoria_Mas_Productos AS
select
	p.DescCategoria,
    count(distinct p.ProductoKey) AS TotalProductos,
    coalesce(sum(f.Cantidad),0) AS ToltalUnidadesVendidas,
    coalesce(sum(f.Importe),0) AS TotalVentas
from DimProducto p
	left join FactVentas f on p.ProductoKey = f.ProductoKey
    group by p.DescCategoria
    order by TotalProductos desc;
    
-- año con mas ventas
create or replace view V_Anio_Mas_ventas AS
select
	d.Anio,
    count(distinct f.IdPedidoOLTP) AS TotalPedidos,
    sum(f.Cantidad) AS TotalUnidades,
    sum(f.Importe) AS ToltalVentas,
    avg(f.importe) AS PromedioVenta,
    max(f.importe) AS VentaMaxima,
    min(f.importe) AS VentaMinima
from FactVentas f
	inner join DimFecha d on f.DateKey = d.DateKey
	group by d.Anio
	order by sum(f.Cantidad * f.PrecioUnidad) desc;

-- ver carga de datos    
select * from FactVentas limit 10;

-- ver cantidad de datos cargados
select count(*) from DimProducto;
select count(*) from DimCliente;
select count(*) from DimFecha;
    
-- ver resultado de las consultas analiticas --
    
-- consulta 1: producto mas vendido
SELECT *
FROM V_Producto_Mas_Vendido
LIMIT 1;  -- opcional, cambiar cantidad de lo más vendidos

-- Consulta 2: Categoría con más productos
SELECT *
FROM V_Categoria_Mas_Productos
LIMIT 10;  -- opcional

-- Consulta 3: Año con más ventas (importe)
SELECT *
FROM V_Anio_Mas_Ventas
LIMIT 1;  -- por ejemplo, los 5 años con más ventas