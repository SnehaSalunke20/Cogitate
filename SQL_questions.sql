CREATE DATABASE cogitate;
USE cogitate;


-- question 1
SELECT 
	cust.customer_id,
	cust.name AS customer_name,
	COUNT(claim.claim_id) AS total_claims,
	SUM(claim.claim_amount) AS total_claim_amount
FROM 
	customers_sample as cust
JOIN 
	policies_sample AS pol ON cust.customer_id = pol.customer_id
JOIN
	claims_sample AS claim ON pol.policy_id = claim.policy_id
WHERE
	YEAR(claim.claim_date) = '2024'
GROUP BY
	cust.customer_id, cust.name
HAVING
	total_claims > 2
ORDER BY
	total_claim_amount DESC;
    



-- question 2
SELECT 
	CASE
		WHEN cust.age BETWEEN 18 AND 30 THEN "Young"
        WHEN cust.age BETWEEN 31 AND 50 THEN "Middle-aged"
        ELSE "Senior"
	END AS age_group,
    pol.policy_type,
    ROUND(AVG(pol.annual_premium), 2) AS avg_premium,
    COUNT(cust.customer_id) AS customer_count
FROM
	customers_sample AS cust
JOIN
	policies_sample AS pol ON cust.customer_id = pol.customer_id
GROUP BY
    age_group,
    pol.policy_type
ORDER BY
    age_group,
    pol.policy_type;
    
    
    
    

-- question 3 (not executing)
WITH FraudulentClaims AS (
    SELECT
        fd.claim_id,
        COALESCE(fd.detected_by, 'Unknown') AS detected_by,
        fd.detection_date,
        cl.claim_amount,
        p.policy_type,
        c.customer_id,
        c.name AS customer_name
    FROM fraud_detection_sample fd
    JOIN claims_sample cl ON fd.claim_id = cl.claim_id
    JOIN policies_sample p ON cl.policy_id = p.policy_id
    JOIN customers_sample c ON p.customer_id = c.customer_id
    WHERE fd.is_fraudulent = TRUE
),
DetectionMethodAnalysis AS (
    SELECT
        detected_by,
        COUNT(claim_id) AS total_frauds_detected,
        ROUND((COUNT(claim_id) * 100.0) / SUM(COUNT(claim_id)) OVER (), 2) AS fraud_catch_rate,
        ROW_NUMBER() OVER (ORDER BY COUNT(claim_id) DESC) AS rank_num
    FROM FraudulentClaims
    WHERE detected_by != 'Unknown'
    GROUP BY detected_by
),
FraudPronePolicy AS (
    SELECT
        policy_type,
        ROW_NUMBER() OVER (ORDER BY COUNT(claim_id) DESC) AS rank_num
    FROM FraudulentClaims
    GROUP BY policy_type
),
HighRiskCustomers AS (
    SELECT
        GROUP_CONCAT(customer_name SEPARATOR '; ') AS high_risk_customers
    FROM (
        SELECT customer_name
        FROM FraudulentClaims
        GROUP BY customer_id, customer_name
        HAVING COUNT(claim_id) >= 2
    ) AS high_risk_subquery
),
MonthlyTrend2024 AS (
    SELECT
        CONCAT('{', GROUP_CONCAT(CONCAT('"', DATE_FORMAT(detection_date, '%Y-%m'), '":', cnt) ORDER BY month_num), '}') AS monthly_trend
    FROM (
        SELECT 
            DATE_FORMAT(detection_date, '%Y-%m') AS month_label,
            MONTH(detection_date) AS month_num,
            COUNT(claim_id) AS cnt
        FROM FraudulentClaims
        WHERE YEAR(detection_date) = 2024
        GROUP BY DATE_FORMAT(detection_date, '%Y-%m'), MONTH(detection_date)
    ) AS trend
)
SELECT
    (SELECT detected_by FROM DetectionMethodAnalysis WHERE rank_num = 1) AS detection_method,
    (SELECT total_frauds_detected FROM DetectionMethodAnalysis WHERE rank_num = 1) AS total_frauds_detected,
    (SELECT CONCAT(fraud_catch_rate, '%') FROM DetectionMethodAnalysis WHERE rank_num = 1) AS fraud_catch_rate,
    (SELECT policy_type FROM FraudPronePolicy WHERE rank_num = 1) AS most_fraud_prone_policy_type,
    ROUND(AVG(fc.claim_amount), 2) AS avg_fraud_amount,
    hrc.high_risk_customers,
    mt.monthly_trend AS monthly_fraud_trend_2024
FROM FraudulentClaims fc
CROSS JOIN HighRiskCustomers hrc
CROSS JOIN MonthlyTrend2024 mt
LIMIT 1;

