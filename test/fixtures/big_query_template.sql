SELECT '::country' AS literal_looking_string, :country AS country
FROM some_table
WHERE country = :country;
