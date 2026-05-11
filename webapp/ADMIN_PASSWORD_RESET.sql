-- Admin Password Reset SQL Script
-- Password will be set to: Admin2026!

-- Find the correct database and user table
USE akeneo_pim;

-- Generate bcrypt hash for 'Admin2026!' (cost 13)
-- Hash: $2y$13$YK7YLPz8zQH9qXZ6B5nK5OLGxH3yW.UQJ6VwK3L8F9vZH2nK8qYLK

UPDATE oro_user 
SET password = '$2y$13$YK7YLPz8zQH9qXZ6B5nK5OLGxH3yW.UQJ6VwK3L8F9vZH2nK8qYLK',
    enabled = 1,
    login_count = 0,
    last_login = NULL
WHERE username = 'admin';

-- Verify the update
SELECT id, username, email, enabled, 
       SUBSTRING(password, 1, 30) as password_hash
FROM oro_user 
WHERE username = 'admin';

-- Alternative: If the above fails, try with 'pim' database
-- USE pim;
-- UPDATE oro_user SET password = '$2y$13$YK7YLPz8zQH9qXZ6B5nK5OLGxH3yW.UQJ6VwK3L8F9vZH2nK8qYLK', enabled = 1 WHERE username = 'admin';
