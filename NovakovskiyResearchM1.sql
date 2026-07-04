--Поиск первой и последней даты выставления объявлений
SELECT 
    MIN(first_day_exposition) AS first_date,
    MAX(first_day_exposition) AS last_date
FROM real_estate.advertisement;

--Распределение объявлений по населённым пунктам
SELECT 
    t.type AS type_name,
    COUNT(DISTINCT c.city_id) AS cities_count,
    COUNT(a.id) AS ads_count,
    ROUND(COUNT(a.id)::numeric / COUNT(DISTINCT c.city_id), 2) AS avg_ads_per_city
FROM real_estate.advertisement AS a
LEFT JOIN real_estate.flats AS f ON a.id = f.id
LEFT JOIN real_estate.city AS c ON f.city_id = c.city_id
LEFT JOIN real_estate.type AS t ON f.type_id = t.type_id
GROUP BY t.type
ORDER BY ads_count DESC;

--Основные статистические показатели по времени активности 
SELECT 
    MIN(days_exposition) AS min_value,
    MAX(days_exposition) AS max_value,
    ROUND(AVG(days_exposition)::numeric, 2) AS avg_value,
    ROUND((SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_exposition) 
         FROM real_estate.advertisement)::numeric, 2) AS median_value
FROM real_estate.advertisement;

--Доля снятых с публикации объявлений
SELECT 
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM real_estate.advertisement),2) AS sold_percent
FROM real_estate.advertisement
WHERE days_exposition IS NOT NULL;

--Доля объявлений в Питере
SELECT 
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM real_estate.advertisement),2) AS spb_percent
FROM real_estate.advertisement a
JOIN real_estate.flats f ON a.id = f.id
JOIN real_estate.city c ON f.city_id = c.city_id
WHERE c.city = 'Санкт-Петербург';

--Основные статистические показатели по стоимости квадратного метра
WITH price_per_sqm AS (
    SELECT 
        a.last_price / f.total_area AS sqm_price
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    WHERE f.total_area > 0 
      AND a.last_price > 0
)
SELECT 
    ROUND(MIN(sqm_price)::numeric, 2) AS min_value,
    ROUND(MAX(sqm_price)::numeric, 2) AS max_value,
    ROUND(AVG(sqm_price)::numeric, 2) AS avg_value,
    ROUND((SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sqm_price) FROM price_per_sqm)::numeric, 2) AS median_value
FROM price_per_sqm;

--Статистические показатели по категориям
WITH clean_flats AS (
    SELECT *
    FROM real_estate.flats
      WHERE total_area > 0 -- Без фильтра некоррекных значений показывает правильный перцентиль - 197,56, но я подумал, что уместнее будет рассматривать корректные значения
      AND rooms >= 0
      AND balcony >= 0
      AND ceiling_height > 0
      AND floor >= 0
)
SELECT 'Общая площадь (кв. м)'        AS parameter,
       MIN(total_area)               AS min_value,
       MAX(total_area)               AS max_value,
       ROUND(AVG(total_area)::numeric, 2) AS avg_value,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_area)::numeric, 2) AS median_value,
       ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area)::numeric, 2) AS p99_value
FROM clean_flats
UNION ALL
SELECT 'Количество комнат',
       MIN(rooms),
       MAX(rooms),
       ROUND(AVG(rooms)::numeric, 2),
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms)::numeric, 2),
       ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY rooms)::numeric, 2)
FROM clean_flats
UNION ALL
SELECT 'Количество балконов',
       MIN(balcony),
       MAX(balcony),
       ROUND(AVG(balcony)::numeric, 2),
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony)::numeric, 2),
       ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY balcony)::numeric, 2)
FROM clean_flats
UNION ALL
SELECT 'Высота потолков (м)',
       MIN(ceiling_height),
       MAX(ceiling_height),
       ROUND(AVG(ceiling_height)::numeric, 2),
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ceiling_height)::numeric, 2),
       ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height)::numeric, 2)
FROM clean_flats
UNION ALL
SELECT 'Этаж квартиры',
       MIN(floor),
       MAX(floor),
       ROUND(AVG(floor)::numeric, 2),
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor)::numeric, 2),
       ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY floor)::numeric, 2)
FROM clean_flats;