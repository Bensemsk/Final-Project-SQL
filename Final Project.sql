## 1. список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период, средний чек за период с 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц, количество всех операций по клиенту за период;

WITH monthly_transactions AS (
	SELECT
		t.id_client,
		YEAR(t.date_new) AS year_t,
		month(t.date_new) AS month_t,
		COUNT(t.id_check) AS t_count,
		SUM(t.sum_payment) AS total_amount,
		AVG(t.sum_payment) AS avg_t
	FROM transactions_info as t
	WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
	GROUP BY
		t.id_client,
		YEAR(t.date_new),
		month(t.date_new)
)
SELECT
    mt.id_client,
    count(mt.t_count),
    avg(mt.total_amount),
    avg(mt.avg_t)
FROM
    monthly_transactions as mt
    
group by mt.id_client
having count(mt.month_t) = 12;

--------------------------------------------------------------------
## 2. Задание
CREATE TEMPORARY TABLE regular_customers AS
	select distinct id_client, count(mon)
	from 
	(select distinct id_client, month(date_new) as mon from transactions_info
	group by id_client,  month(date_new)
	order by id_client) as tt
	group by id_client
	having count(mon) = 12;
    
CREATE TEMPORARY TABLE monthly_transactions AS
SELECT
    t.id_client,
    YEAR(t.date_new) AS year_t,
    MONTH(t.date_new) AS month_t,
    COUNT(t.id_check) AS t_count,
    SUM(t.sum_payment) AS total_amount,
    AVG(t.sum_payment) AS avg_t
FROM transactions_info AS t
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY
    t.id_client,
    YEAR(t.date_new),
    MONTH(t.date_new);
    
select * from monthly_transactions as mt
where mt.id_client in (select rc.id_client from regular_customers as rc);
----------------------------------------------------------------------------------
-- информацию в разрезе месяцев:
-- средняя сумма чека в месяц;
-- среднее количество операций в месяц;
-- среднее количество клиентов, которые совершали операции;
-- долю от общего количества операций за год и долю в месяц от общей суммы операций;

CREATE TEMPORARY TABLE aggregates AS
	select 
		ti.id_client,
		c.gender,
        year(ti.date_new) as num_year,
		month(ti.date_new) as num_month,
		round(sum(ti.sum_payment),2) as total_payment,
        round(avg(ti.sum_payment),2) as avg_sum,
		count(distinct ti.id_check) as total_check,
		count(distinct ti.id_client) as total_client,
        (select )
	from transactions_info as ti
	join customer_info as c on c.id_client = ti.id_client
	where ti.id_client in (select rc.id_client from regular_customers as rc)
	group by ti.id_client, c.gender, year(ti.date_new), month(ti.date_new);

CREATE TEMPORARY TABLE aggregates2 AS
	select 
		ti.id_client,
		c.gender,
        year(ti.date_new) as num_year,
		month(ti.date_new) as num_month,
		round(sum(ti.sum_payment),2) as total_payment,
        round(avg(ti.sum_payment),2) as avg_sum,
		count(distinct ti.id_check) as total_check,
		count(distinct ti.id_client) as total_client
	from transactions_info as ti
	join customer_info as c on c.id_client = ti.id_client
	where ti.id_client in (select rc.id_client from regular_customers as rc)
	group by ti.id_client, c.gender,  year(ti.date_new), month(ti.date_new);

CREATE TEMPORARY TABLE gender_share AS
    SELECT
        year(ti.date_new) as t_year,
		month(ti.date_new) as t_month,
        coalesce(c.gender, 0) as gender,
        round(SUM(ti.sum_payment),2) AS gender_payment,
        COUNT(distinct ti.id_client) AS gender_clients
    FROM transactions_info  as ti
    join customer_info as c on c.id_client = ti.id_client
    GROUP BY year(ti.date_new), month(ti.date_new), c.gender;

CREATE TEMPORARY TABLE gender_share2 AS
    SELECT
        year(ti.date_new) as t_year,
		month(ti.date_new) as t_month,
        coalesce(c.gender, 0) as gender,
        round(SUM(ti.sum_payment),2) AS gender_payment,
        COUNT(distinct ti.id_client) AS gender_clients
    FROM transactions_info  as ti
    join customer_info as c on c.id_client = ti.id_client
    GROUP BY year(ti.date_new), month(ti.date_new), c.gender;
    
select num_year as 'год', num_month as 'номер месяца', round(avg(avg_sum),2) as 'Сред. чек',  round(avg(total_check),2) as 'Сред. кол-во чеков', count(id_client) as 'Сред. кол-во клиентов' , round(sum(total_check) / (select sum(total_check) from aggregates2)*100, 2) as 'Доля от суммы операций'
from  aggregates
group by num_year, num_month
order by num_year, num_month asc;
-- вывести % соотношение M/F/NA в каждом месяце с их долей затрат;
select gs.t_year, gs.t_month, gs.gender, round(gs.gender_payment / (select sum(gs2.gender_payment) from gender_share2 as gs2)*100, 2) as gender_share_sum from gender_share as gs;

------------------------------------------------------------------
-- Создаем временную таблицу с возрастными группами
CREATE TEMPORARY TABLE age_groups AS
SELECT 
    c.id_client,
    c.gender,
    c.age,  -- Вычисляем возраст клиента
    CASE
        WHEN age BETWEEN 1 AND 10 THEN '1-10'
        WHEN age BETWEEN 11 AND 20 THEN '11-20'
        WHEN age BETWEEN 21 AND 30 THEN '21-30'
        WHEN age BETWEEN 31 AND 40 THEN '31-40'
        WHEN age BETWEEN 41 AND 50 THEN '41-50'
        WHEN age BETWEEN 51 AND 60 THEN '51-60'
        WHEN age BETWEEN 61 AND 70 THEN '61-70'
        WHEN age BETWEEN 71 AND 80 THEN '71-80'
        WHEN age >= 81 THEN '80+'
        ELSE 'Unknown'
    END AS age_group  -- Разбиваем на возрастные группы
FROM customer_info c;

-- Теперь создаем временную таблицу для агрегированных данных по возрастным группам
CREATE TEMPORARY TABLE age_group_aggregates AS
SELECT 
    ag.age_group,
    YEAR(ti.date_new) AS year,
    QUARTER(ti.date_new) AS quarter,  -- Вычисляем квартал
    ROUND(SUM(ti.sum_payment), 2) AS total_payment,
    COUNT(ti.id_check) AS total_transactions,
    COUNT(DISTINCT ti.id_client) AS total_clients
FROM transactions_info ti
JOIN age_groups ag ON ti.id_client = ag.id_client
GROUP BY ag.age_group, YEAR(ti.date_new), QUARTER(ti.date_new)
ORDER BY ag.age_group, year, quarter;

CREATE TEMPORARY TABLE age_group_aggregates2 AS
SELECT 
    ag.age_group,
    YEAR(ti.date_new) AS year,
    QUARTER(ti.date_new) AS quarter,  -- Вычисляем квартал
    ROUND(SUM(ti.sum_payment), 2) AS total_payment,
    COUNT(ti.id_check) AS total_transactions,
    COUNT(DISTINCT ti.id_client) AS total_clients
FROM transactions_info ti
JOIN age_groups ag ON ti.id_client = ag.id_client
GROUP BY ag.age_group, YEAR(ti.date_new), QUARTER(ti.date_new)
ORDER BY ag.age_group, year, quarter;

CREATE TEMPORARY TABLE age_group_aggregates3 AS
SELECT 
    ag.age_group,
    YEAR(ti.date_new) AS year,
    QUARTER(ti.date_new) AS quarter,  -- Вычисляем квартал
    ROUND(SUM(ti.sum_payment), 2) AS total_payment,
    COUNT(ti.id_check) AS total_transactions,
    COUNT(DISTINCT ti.id_client) AS total_clients
FROM transactions_info ti
JOIN age_groups ag ON ti.id_client = ag.id_client
GROUP BY ag.age_group, YEAR(ti.date_new), QUARTER(ti.date_new)
ORDER BY ag.age_group, year, quarter;
-- Теперь для всех возрастных групп вычисляем данные по всей продолжительности периода и поквартально

-- За весь период
SELECT 
    age_group AS 'Возрастная группа',
    ROUND(SUM(total_payment), 2) AS 'Общая сумма операций',
    SUM(total_transactions) AS 'Общее количество операций',
    SUM(total_clients) AS 'Общее количество клиентов'
FROM age_group_aggregates
GROUP BY age_group;

-- Поквартально
SELECT 
    age_group AS 'Возрастная группа',
    year AS 'Год',
    quarter AS 'Квартал',
    ROUND(AVG(total_payment), 2) AS 'Средняя сумма операции',
    ROUND(AVG(total_transactions), 2) AS 'Среднее количество операций',
    ROUND(AVG(total_clients), 2) AS 'Среднее количество клиентов',
    ROUND(SUM(total_transactions) / (SELECT SUM(total_transactions) FROM age_group_aggregates2) * 100, 2) AS 'Доля от общего числа операций',
    ROUND(SUM(total_payment) / (SELECT SUM(total_payment) FROM age_group_aggregates3) * 100, 2) AS 'Доля от общей суммы операций'
FROM age_group_aggregates
GROUP BY age_group, year, quarter
ORDER BY age_group, year, quarter;

    