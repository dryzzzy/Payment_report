-- Payment report part 1
-- Comparison of salaries of women and men. Only the current salary should be taken into account, the salary column in the salaries table is expressed in one currency.

select * from employees16_65.employees;
select * from salaries where to_date = '9999-01-01';

DROP TABLE IF EXISTS tmp_gender_salary;
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_gender_salary AS
select
    distinct s.emp_no,
             s.salary,
             s.to_date,
             e.gender
from employees16_65.salaries as s
left join employees16_65.employees e on s.emp_no = e.emp_no
where to_date = '9999-01-01';

select gender, avg(salary) from tmp_gender_salary group by gender;

-- Payment report part 2
-- Checking the differences in earnings in the following groups: by gender and department, by gender, without differentiation.
DROP TABLE IF EXISTS tmp_gender_salary_dep;
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_gender_salary_dep AS
select
    distinct s.emp_no,
             s.salary,
             s.to_date,
             e.gender,
             de.dept_no,
             dep.dept_name
from employees16_65.salaries as s
left join employees16_65.employees as e on s.emp_no = e.emp_no
left join employees16_65.dept_emp as de on de.emp_no = e.emp_no AND NOW() BETWEEN de.from_date AND de.to_date
left join employees16_65.departments as dep on de.dept_no = dep.dept_no
where NOW() BETWEEN s.from_date and s.to_date;

select  gender, dept_name, count(emp_no), avg(salary) from tmp_gender_salary_dep
group by 1, 2
WITH ROLLUP
order by 2, 1;

-- Payment report part 3
-- Calculating the percentage difference between earnings in every group.

select
    gender,
    dept_name,
    count(emp_no) as population,
    avg(salary) as average_salary,
    lead(avg(salary)) over (order by  dept_name, gender) as 'lead_salary',
    (lead(avg(salary)) over (partition by dept_name order by gender))/avg(salary) as 'diff_salary_lead'
from tmp_gender_salary_dep
group by gender, dept_name
WITH ROLLUP
having not (gender iS null and dept_name is null);

-- Payment report part 4
-- Procedure 'generate_payment_report', which will take as a parameter the date for which the report is to be generated, and then write the results to the employees.payment_report table. The report is to be available at the end of a given month.

select * from employees16_65.payment_report;
DROP TABLE IF EXISTS temp_payment_report;
CREATE TEMPORARY TABLE temp_payment_report AS
    select gender, dept_name, avg_salary, diff, report_date,report_generation_date from employees16_65.payment_report;

USE employees16_65;
DROP PROCEDURE IF EXISTS generate_payment_report;
DELIMITER $$
CREATE PROCEDURE generate_payment_report(IN p_date DATE)
BEGIN

    SET p_date = LAST_DAY(p_date);

    DROP TABLE IF EXISTS tmp_report;
    CREATE TEMPORARY TABLE tmp_report AS
            WITH cte as (select e.gender, d.dept_name, avg(s.salary) as laczne_zarobki
                         from employees16_65.salaries as s
                                  left join employees16_65.employees as e using (emp_no)
                                  left join employees16_65.dept_emp as de
                                            on de.emp_no = e.emp_no AND NOW() BETWEEN de.from_date AND de.to_date
                                  left join employees16_65.departments as d using (dept_no)
                         where NOW() BETWEEN s.from_date and s.to_date
                         group by 1, 2
                         WITH ROLLUP
                         order by 2, 1)
            SELECT *,
                   LEAD(laczne_zarobki) OVER (partition by dept_name order by gender) / laczne_zarobki as M_vs_F
            FROM cte
            where gender iS not null
              and dept_name is not null;


    DELETE FROM temp_payment_report
        WHERE report_generation_date = p_date;

    INSERT INTO temp_payment_report
        SELECT *, DATE(p_date), NOW()
        FROM tmp_report;

end $$
#---------------------------------------------------------------
CALL generate_payment_report('2022-01-20');


# Result
SELECT * FROM temp_payment_report;
