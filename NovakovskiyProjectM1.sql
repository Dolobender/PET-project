/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор:Новаковский Дмитрий
 * Дата: 30.06.2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
svodnaya AS (
    SELECT 
        a.id,
        a.days_exposition,
        a.last_price,
        f.total_area,
        f.living_area,
        f.kitchen_area,
        f.rooms,
        f.balcony,
        f.ceiling_height,
        f.floor,
        f.floors_total,
        f.is_apartment,
        f.open_plan,
        c.city,
        CASE 
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'Ленинградская область'
        END AS region_category,
        a.last_price / NULLIF(f.total_area, 0) AS price_per_sqm,
        CASE 
            WHEN a.days_exposition IS NULL THEN 'нет данных'
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
            WHEN a.days_exposition >= 181 THEN '181+ days'
            ELSE 'other'
        END AS activity_category
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE 
        a.id IN (SELECT id FROM filtered_id)
        AND t.type = 'город'-- Добавил фильтр по городу
        AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'-- Добавил интересующий нас временной период
)
SELECT 
    region_category AS Регион,
    activity_category AS Сегмент_активности,
    COUNT(*) AS Количество_объявлений,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY region_category), 2) AS Доля_в_регионе_проц,
    ROUND(AVG(price_per_sqm)::numeric, 2) AS Средняя_цена_кв_м,
    ROUND(AVG(total_area)::numeric, 2) AS Средняя_общая_площадь,
    ROUND(AVG(living_area)::numeric, 2) AS Средняя_жилая_площадь,
    ROUND(AVG(kitchen_area)::numeric, 2) AS Средняя_площадь_кухни,
    ROUND(AVG(ceiling_height)::numeric, 2) AS Средняя_высота_потолков,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms)::numeric, 2) AS Медиана_комнат,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony)::numeric, 2) AS Медиана_балконов,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor)::numeric, 2) AS Медиана_этажа_квартиры,
    ROUND(AVG(floors_total)::numeric, 2) AS Средняя_этажность_дома,
    ROUND(SUM(CASE WHEN is_apartment = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Доля_апартаментов_проц,
    ROUND(SUM(CASE WHEN open_plan = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Доля_открытой_планировки_проц
FROM svodnaya
GROUP BY region_category, activity_category
ORDER BY 
    region_category,
    CASE activity_category
        WHEN '1-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        WHEN '181+ days' THEN 4
        WHEN 'нет данных' THEN 5
        ELSE 6
    END;


-- Задача 2: Сезонность (усреднённые показатели по месяцам)
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
base_data AS (
    SELECT 
        a.id,
        a.first_day_exposition,
        a.days_exposition,
        a.last_price,
        f.total_area,
        a.last_price / NULLIF(f.total_area, 0) AS price_per_sqm,
        EXTRACT(MONTH FROM a.first_day_exposition) AS pub_month_num,
        CASE 
            WHEN a.days_exposition IS NOT NULL 
            THEN EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition * INTERVAL '1 day')
            ELSE NULL
        END AS close_month_num
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE 
        t.type = 'город'
        AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
        AND a.id IN (SELECT id FROM filtered_id)
        AND f.total_area > 0
        AND a.last_price > 0
),
months AS (
    SELECT * FROM (VALUES 
        (1,'Январь'),(2,'Февраль'),(3,'Март'),(4,'Апрель'),
        (5,'Май'),(6,'Июнь'),(7,'Июль'),(8,'Август'),
        (9,'Сентябрь'),(10,'Октябрь'),(11,'Ноябрь'),(12,'Декабрь')
    ) AS m(month_num, month_name)
)
-- Публикации
SELECT 
    m.month_num,
    m.month_name AS Месяц,
    'Публикация' AS Тип_активности,
    COUNT(b.id) AS Количество_объявлений,
    ROUND(AVG(b.price_per_sqm)::numeric, 2) AS Средняя_цена_кв_м,
    ROUND(AVG(b.total_area)::numeric, 2) AS Средняя_площадь
FROM months m
LEFT JOIN base_data b ON m.month_num = b.pub_month_num
GROUP BY m.month_num, m.month_name
UNION ALL
-- Снятия
SELECT 
    m.month_num,
    m.month_name AS Месяц,
    'Снятие' AS Тип_активности,
    COUNT(b.id) AS Количество_объявлений,
    ROUND(AVG(b.price_per_sqm)::numeric, 2) AS Средняя_цена_кв_м,
    ROUND(AVG(b.total_area)::numeric, 2) AS Средняя_площадь
FROM months m
LEFT JOIN base_data b ON m.month_num = b.close_month_num
WHERE b.days_exposition IS NOT NULL  
GROUP BY m.month_num, m.month_name
ORDER BY 
    month_num,
    Тип_активности;