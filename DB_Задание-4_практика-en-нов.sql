-- ============================================================
-- БАЗА ДАННЫХ ДЛЯ ПРОЦЕССА ВЗАИМОДЕЙСТВИЯ СОТРУДНИКОВ
-- Сделано по BPMN, соответственно и по всем пользовательским историям, русский текст НЕ принимается в xampp (скампп вообще), но есть версия с русскими данными
-- ============================================================

-- Удаление существующих таблиц (для пересоздания)
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS request_status_log CASCADE;
DROP TABLE IF EXISTS auto_generated_tasks CASCADE;
DROP TABLE IF EXISTS processing_metrics CASCADE;
DROP TABLE IF EXISTS request_history CASCADE;
DROP TABLE IF EXISTS staffing_requests CASCADE;
DROP TABLE IF EXISTS response_presets CASCADE;
DROP TABLE IF EXISTS sla_configurations CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS positions CASCADE;
DROP TABLE IF EXISTS stores CASCADE;
DROP TABLE IF EXISTS request_types CASCADE;
DROP TABLE IF EXISTS job_descriptions CASCADE;
DROP TABLE IF EXISTS compliance_standards CASCADE;
DROP TABLE IF EXISTS ui_menu_items CASCADE;
DROP TABLE IF EXISTS system_settings CASCADE;

-- ============================================================
-- СПРАВОЧНЫЕ ТАБЛИЦЫ
-- ============================================================

-- Таблица: Магазины (Stores)
CREATE TABLE stores (
    store_id SERIAL PRIMARY KEY,
    store_code VARCHAR(20) UNIQUE NOT NULL,
    store_name VARCHAR(100) NOT NULL,
    address VARCHAR(200) NOT NULL,
    region VARCHAR(50) NOT NULL,
    store_manager_id INTEGER,
    opening_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица: Должности (Positions)
CREATE TABLE positions (
    position_id SERIAL PRIMARY KEY,
    position_code VARCHAR(20) UNIQUE NOT NULL,
    position_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    base_salary DECIMAL(10,2),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- Таблица: Типы запросов (Request Types)
CREATE TABLE request_types (
    type_id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) UNIQUE NOT NULL,
    type_name VARCHAR(100) NOT NULL,
    description TEXT,
    default_priority INTEGER DEFAULT 3,
    default_deadline_hours INTEGER DEFAULT 72,
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================================
-- ОСНОВНЫЕ ТАБЛИЦЫ ДАННЫХ ("DATA OBJECTS" ИЗ BPMN)
-- ============================================================

-- Таблица: Сотрудники (Employee Database)
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    employee_code VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    position_id INTEGER REFERENCES positions(position_id),
    store_id INTEGER REFERENCES stores(store_id),
    hire_date DATE NOT NULL,
    termination_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    is_duplicate_flag BOOLEAN DEFAULT FALSE,
    duplicate_of_employee_id INTEGER REFERENCES employees(employee_id),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица: Должностные инструкции (Job Descriptions Database)
CREATE TABLE job_descriptions (
    description_id SERIAL PRIMARY KEY,
    position_id INTEGER REFERENCES positions(position_id),
    version VARCHAR(10) NOT NULL,
    effective_date DATE NOT NULL,
    responsibilities TEXT NOT NULL,
    qualifications TEXT NOT NULL,
    skills_required TEXT,
    performance_criteria TEXT,
    is_compliant BOOLEAN DEFAULT TRUE,
    compliance_check_date DATE,
    compliance_notes TEXT,
    created_by INTEGER REFERENCES employees(employee_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(position_id, version)
);

-- Таблица: Стандарты соответствия (Compliance Standards)
CREATE TABLE compliance_standards (
    standard_id SERIAL PRIMARY KEY,
    standard_code VARCHAR(20) UNIQUE NOT NULL,
    standard_name VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    requirement_text TEXT NOT NULL,
    effective_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================================
-- ТАБЛИЦА ШАБЛОНОВ ОТВЕТОВ (RESPONSE PRESETS)
-- Для HR специалиста на шлюзе "Assign Executor"
-- ============================================================

CREATE TABLE response_presets (
    preset_id SERIAL PRIMARY KEY,
    preset_code VARCHAR(20) UNIQUE NOT NULL,
    preset_name VARCHAR(100) NOT NULL,
    request_type_id INTEGER REFERENCES request_types(type_id),
    priority_level INTEGER NOT NULL CHECK (priority_level BETWEEN 1 AND 5),
    deadline_hours INTEGER NOT NULL,
    auto_message TEXT NOT NULL,
    recommended_action TEXT,
    escalation_contact_id INTEGER REFERENCES employees(employee_id),
    is_active BOOLEAN DEFAULT TRUE,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ТАБЛИЦЫ ПРОЦЕССА ЗАПРОСОВ
-- ============================================================

-- Таблица: Конфигурации SLA (SLA Configurations)
CREATE TABLE sla_configurations (
    sla_id SERIAL PRIMARY KEY,
    request_type_id INTEGER REFERENCES request_types(type_id),
    size_category VARCHAR(20) NOT NULL CHECK (size_category IN ('small', 'medium', 'large')),
    min_employees INTEGER NOT NULL,
    max_employees INTEGER NOT NULL,
    target_response_hours INTEGER NOT NULL,
    target_completion_hours INTEGER NOT NULL,
    escalation_hours INTEGER NOT NULL DEFAULT 48,
    penalty_rate DECIMAL(5,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_by INTEGER REFERENCES employees(employee_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(request_type_id, size_category)
);

-- Таблица: Запросы на персонал (Staffing Requests)
CREATE TABLE staffing_requests (
    request_id SERIAL PRIMARY KEY,
    request_number VARCHAR(30) UNIQUE NOT NULL,
    store_id INTEGER NOT NULL REFERENCES stores(store_id),
    requester_id INTEGER NOT NULL REFERENCES employees(employee_id),
    request_type_id INTEGER NOT NULL REFERENCES request_types(type_id),
    position_id INTEGER REFERENCES positions(position_id),
    quantity INTEGER NOT NULL DEFAULT 1,
    size_category VARCHAR(20) NOT NULL,
    urgency_reason TEXT,
    description TEXT NOT NULL,
    required_skills TEXT,
    preferred_start_date DATE,
    status VARCHAR(30) NOT NULL DEFAULT 'new' CHECK (status IN (
        'new', 'under_review', 'executor_assigned', 'in_progress', 'pending_approval', 'completed', 'closed', 'rejected'
    )),
    assigned_to INTEGER REFERENCES employees(employee_id),
    assigned_at TIMESTAMP,
    sla_deadline TIMESTAMP,
    completed_at TIMESTAMP,
    closed_by INTEGER REFERENCES employees(employee_id),
    closed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица: История запросов (Request History Database)
-- Для управляющего магазом - просмотр истории за 6 месяцев
CREATE TABLE request_history (
    history_id SERIAL PRIMARY KEY,
    request_id INTEGER NOT NULL REFERENCES staffing_requests(request_id),
    store_id INTEGER NOT NULL REFERENCES stores(store_id),
    requester_id INTEGER NOT NULL REFERENCES employees(employee_id),
    action_type VARCHAR(50) NOT NULL,
    old_status VARCHAR(30),
    new_status VARCHAR(30),
    action_description TEXT,
    performed_by INTEGER REFERENCES employees(employee_id),
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- Таблица: Метрики обработки (Processing Metrics Database)
-- Для управляющего централом (офисом) - метрики времени обработки
CREATE TABLE processing_metrics (
    metric_id SERIAL PRIMARY KEY,
    request_id INTEGER NOT NULL REFERENCES staffing_requests(request_id),
    store_id INTEGER NOT NULL REFERENCES stores(store_id),
    request_type_id INTEGER NOT NULL REFERENCES request_types(type_id),
    size_category VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    assigned_at TIMESTAMP,
    completed_at TIMESTAMP,
    closed_at TIMESTAMP,
    response_time_hours DECIMAL(10,2),
    completion_time_hours DECIMAL(10,2),
    total_time_hours DECIMAL(10,2),
    sla_target_hours INTEGER,
    is_sla_met BOOLEAN,
    delay_hours DECIMAL(10,2) DEFAULT 0,
    delay_reason TEXT,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица: Автозадачи для HR Specialist (Auto-Generated Tasks)
CREATE TABLE auto_generated_tasks (
    task_id SERIAL PRIMARY KEY,
    task_number VARCHAR(30) UNIQUE NOT NULL,
    request_id INTEGER NOT NULL REFERENCES staffing_requests(request_id),
    assigned_to INTEGER NOT NULL REFERENCES employees(employee_id),
    priority INTEGER NOT NULL CHECK (priority BETWEEN 1 AND 5),
    deadline TIMESTAMP NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    checklist TEXT,
    -- был JSONB в checklist
    status VARCHAR(30) NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'accepted', 'in_progress', 'completed', 'cancelled')),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    compliance_check_passed BOOLEAN,
    duplicate_check_passed BOOLEAN,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица: Журнал статусов запросов
CREATE TABLE request_status_log (
    log_id SERIAL PRIMARY KEY,
    request_id INTEGER NOT NULL REFERENCES staffing_requests(request_id),
    status VARCHAR(30) NOT NULL,
    changed_by INTEGER NOT NULL REFERENCES employees(employee_id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comment TEXT
);

-- Таблица: Уведомления (для задержек > 48 часов)
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    recipient_id INTEGER NOT NULL REFERENCES employees(employee_id),
    notification_type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    related_request_id INTEGER REFERENCES staffing_requests(request_id),
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    priority INTEGER DEFAULT 3 CHECK (priority BETWEEN 1 AND 5)
);

-- ============================================================
-- ДОПОЛНИТЕЛЬНЫЕ ТАБЛИЦЫ (UI И ФУНКЦИОНАЛЬНОСТЬ)
-- ============================================================

-- Таблица: Элементы меню UI
CREATE TABLE ui_menu_items (
    menu_id SERIAL PRIMARY KEY,
    parent_id INTEGER REFERENCES ui_menu_items(menu_id),
    menu_code VARCHAR(30) UNIQUE NOT NULL,
    menu_name VARCHAR(100) NOT NULL,
    menu_path VARCHAR(200),
    icon_class VARCHAR(50),
    display_order INTEGER NOT NULL,
    role_required VARCHAR(50) NOT NULL CHECK (role_required IN (
        'store_manager', 'central_office_manager', 'hr_specialist', 'all'
    )),
    is_active BOOLEAN DEFAULT TRUE
);

-- Таблица: Системные настройки
CREATE TABLE system_settings (
    setting_id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    setting_type VARCHAR(20) NOT NULL DEFAULT 'string',
    description TEXT,
    updated_by INTEGER REFERENCES employees(employee_id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ПРЕДСТАВЛЕНИЯ (VIEWS) ДЛЯ УДОБНОГО ВЫВОДА ДАННЫХ
-- ============================================================

-- Представление: История запросов для управляющего магазом
CREATE OR REPLACE VIEW vw_store_manager_history AS
SELECT 
    rh.history_id,
    rh.request_id,
    sr.request_number,
    st.store_name,
    rt.type_name AS request_type,
    pos.position_name AS requested_position,
    sr.quantity,
    sr.description,
    rh.old_status,
    rh.new_status,
    rh.action_type,
    rh.action_description,
    rh.action_timestamp,
    e.first_name || ' ' || e.last_name AS performed_by_name,
    pm.response_time_hours,
    pm.completion_time_hours,
    pm.is_sla_met
FROM request_history rh
JOIN staffing_requests sr ON rh.request_id = sr.request_id
JOIN stores st ON rh.store_id = st.store_id
JOIN request_types rt ON sr.request_type_id = rt.type_id
LEFT JOIN positions pos ON sr.position_id = pos.position_id
LEFT JOIN employees e ON rh.performed_by = e.employee_id
LEFT JOIN processing_metrics pm ON rh.request_id = pm.request_id
ORDER BY rh.action_timestamp DESC;

-- Представление: Автозадачи для HR Specialist
CREATE OR REPLACE VIEW vw_hr_auto_tasks AS
SELECT 
    agt.task_id,
    agt.task_number,
    agt.request_id,
    sr.request_number,
    st.store_name,
    rt.type_name AS request_type,
    pos.position_name,
    sr.quantity,
    agt.priority,
    agt.deadline,
    agt.task_type,
    agt.description,
    agt.status,
    agt.compliance_check_passed,
    agt.duplicate_check_passed,
    agt.created_at,
    e.first_name || ' ' || e.last_name AS assigned_to_name,
    rp.preset_name AS response_preset,
    CASE 
        WHEN agt.deadline < CURRENT_TIMESTAMP THEN 'overdue'
        -- WHEN agt.deadline < CURRENT_TIMESTAMP + INTERVAL '24 hours' THEN 'urgent'
        ELSE 'on_time'
    END AS deadline_status
FROM auto_generated_tasks agt
JOIN staffing_requests sr ON agt.request_id = sr.request_id
JOIN stores st ON sr.store_id = st.store_id
JOIN request_types rt ON sr.request_type_id = rt.type_id
LEFT JOIN positions pos ON sr.position_id = pos.position_id
LEFT JOIN employees e ON agt.assigned_to = e.employee_id
LEFT JOIN response_presets rp ON rt.type_id = rp.request_type_id 
    AND rp.is_active = TRUE
ORDER BY agt.priority, agt.deadline;

-- Представление: Метрики для управляющего централом (офисом)
CREATE OR REPLACE VIEW vw_central_office_metrics AS
SELECT 
    pm.metric_id,
    pm.request_id,
    sr.request_number,
    st.store_code,
    st.store_name,
    st.region,
    rt.type_name AS request_type,
    pm.size_category,
    pm.created_at,
    pm.assigned_at,
    pm.completed_at,
    pm.closed_at,
    pm.response_time_hours,
    pm.completion_time_hours,
    pm.total_time_hours,
    pm.sla_target_hours,
    pm.is_sla_met,
    pm.delay_hours,
    pm.delay_reason,
    CASE 
        WHEN pm.is_sla_met THEN 'SLA Met'
        ELSE 'SLA Violation'
    END AS sla_status,
    sr.status AS request_status
FROM processing_metrics pm
JOIN staffing_requests sr ON pm.request_id = sr.request_id
JOIN stores st ON pm.store_id = st.store_id
JOIN request_types rt ON pm.request_type_id = rt.type_id
ORDER BY pm.created_at DESC;

-- Представление: Анализ запросов по частоте
CREATE OR REPLACE VIEW vw_request_frequency_analysis AS
SELECT 
    st.store_id,
    st.store_code,
    st.store_name,
    st.region,
    rt.type_name AS request_type,
    COUNT(*) AS total_requests,
    COUNT(CASE WHEN sr.status = 'completed' THEN 1 END) AS completed_requests,
    COUNT(CASE WHEN sr.status = 'rejected' THEN 1 END) AS rejected_requests,
    AVG(pm.response_time_hours) AS avg_response_time,
    AVG(pm.completion_time_hours) AS avg_completion_time,
    AVG(pm.total_time_hours) AS avg_total_time,
    SUM(CASE WHEN pm.is_sla_met THEN 0 ELSE 1 END) AS sla_violations,
    ROUND(100.0 * COUNT(CASE WHEN pm.is_sla_met THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS sla_compliance_rate
FROM staffing_requests sr
JOIN stores st ON sr.store_id = st.store_id
JOIN request_types rt ON sr.request_type_id = rt.type_id
LEFT JOIN processing_metrics pm ON sr.request_id = pm.request_id
GROUP BY st.store_id, st.store_code, st.store_name, st.region, rt.type_name
ORDER BY total_requests DESC;

-- Представление: Проверка дублей сотрудников
CREATE OR REPLACE VIEW vw_employee_duplicates_check AS
SELECT 
    e1.employee_id AS employee1_id,
    e1.employee_code AS employee1_code,
    e1.first_name || ' ' || e1.last_name AS employee1_name,
    e1.email AS employee1_email,
    s1.store_name AS employee1_store,
    e2.employee_id AS employee2_id,
    e2.employee_code AS employee2_code,
    e2.first_name || ' ' || e2.last_name AS employee2_name,
    e2.email AS employee2_email,
    s2.store_name AS employee2_store,
    CASE 
        WHEN e1.email = e2.email THEN 'Exact email match'
        WHEN e1.first_name = e2.first_name AND e1.last_name = e2.last_name 
             AND e1.phone = e2.phone THEN 'Full name and phone match'
        WHEN e1.first_name = e2.first_name AND e1.last_name = e2.last_name 
             AND e1.phone IS NOT NULL AND e2.phone IS NOT NULL 
             AND LENGTH(e1.phone) >= 7 AND LENGTH(e2.phone) >= 7
             AND RIGHT(e1.phone, 7) = RIGHT(e2.phone, 7) THEN 'Full name and last 7 digits match'
        ELSE 'Possible duplicate'
    END AS duplicate_type
FROM employees e1
JOIN employees e2 ON e1.employee_id < e2.employee_id
JOIN stores s1 ON e1.store_id = s1.store_id
JOIN stores s2 ON e2.store_id = s2.store_id
WHERE 
    e1.is_active = TRUE AND e2.is_active = TRUE
    AND (
        LOWER(e1.email) = LOWER(e2.email)
        OR (e1.first_name = e2.first_name AND e1.last_name = e2.last_name 
            AND e1.phone IS NOT NULL AND e2.phone IS NOT NULL
            AND RIGHT(e1.phone, 7) = RIGHT(e2.phone, 7))
    );

-- Представление: Проверка соответствия должностных инструкций
CREATE OR REPLACE VIEW vw_job_description_compliance AS
SELECT 
    jd.description_id,
    jd.version,
    p.position_code,
    p.position_name,
    jd.effective_date,
    jd.is_compliant,
    jd.compliance_check_date,
    jd.compliance_notes,
    cs.standard_code,
    cs.standard_name,
    COUNT(CASE WHEN jd.is_compliant = FALSE THEN 1 END) OVER (PARTITION BY p.position_id) AS non_compliant_count
FROM job_descriptions jd
JOIN positions p ON jd.position_id = p.position_id
LEFT JOIN compliance_standards cs ON cs.is_active = TRUE
ORDER BY jd.is_compliant, jd.effective_date DESC;

-- Представление: Активные SLA конфигурации
CREATE OR REPLACE VIEW vw_active_sla_configs AS
SELECT 
    sla.sla_id,
    rt.type_name AS request_type,
    sla.size_category,
    sla.min_employees,
    sla.max_employees,
    sla.target_response_hours,
    sla.target_completion_hours,
    sla.escalation_hours,
    sla.penalty_rate,
    e.first_name || ' ' || e.last_name AS created_by_name,
    sla.created_at
FROM sla_configurations sla
JOIN request_types rt ON sla.request_type_id = rt.type_id
LEFT JOIN employees e ON sla.created_by = e.employee_id
WHERE sla.is_active = TRUE
ORDER BY rt.type_name, sla.size_category;

-- Представление: Шаблоны ответов HR
CREATE OR REPLACE VIEW vw_response_presets_active AS
SELECT 
    rp.preset_id,
    rp.preset_code,
    rp.preset_name,
    rt.type_name AS request_type,
    rp.priority_level,
    rp.deadline_hours,
    rp.auto_message,
    rp.recommended_action,
    e.first_name || ' ' || e.last_name AS escalation_contact,
    rp.usage_count
FROM response_presets rp
JOIN request_types rt ON rp.request_type_id = rt.type_id
LEFT JOIN employees e ON rp.escalation_contact_id = e.employee_id
WHERE rp.is_active = TRUE
ORDER BY rp.priority_level DESC, rt.type_name;

-- ============================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦ ДАННЫМИ (ENGLISH VERSION)
-- ============================================================

-- Вставка магазинов (15 записей)
INSERT INTO stores (store_code, store_name, address, region, opening_date, is_active) VALUES
('MOW-001', 'Alexeevsky Store', 'Moscow, Alexeevskaya St., 15', 'Moscow', '2019-03-15', TRUE),
('MOW-002', 'Arbat Store', 'Moscow, Arbat St., 22', 'Moscow', '2020-06-01', TRUE),
('SPB-001', 'Nevsky Store', 'St. Petersburg, Nevsky Pr., 45', 'St. Petersburg', '2018-09-10', TRUE),
('SPB-002', 'Petrogradsky Store', 'St. Petersburg, Petrogradskaya Emb., 18', 'St. Petersburg', '2021-02-20', TRUE),
('EKB-001', 'Ural Store', 'Yekaterinburg, Lenin St., 32', 'Sverdlovsk Region', '2019-11-05', TRUE),
('NSK-001', 'Siberian Store', 'Novosibirsk, Krasny Pr., 50', 'Novosibirsk Region', '2020-04-12', TRUE),
('KZN-001', 'Kazan Store', 'Kazan, Bauman St., 28', 'Republic of Tatarstan', '2018-07-22', TRUE),
('NNV-001', 'Nizhny Novgorod Store', 'Nizhny Novgorod, Bolshaya Pokrovskaya St., 35', 'Nizhny Novgorod Region', '2021-05-30', TRUE),
('SAM-001', 'Samara Store', 'Samara, Kuibyshev St., 120', 'Samara Region', '2019-08-14', TRUE),
('RND-001', 'Rostov Store', 'Rostov-on-Don, Budennovsky Pr., 65', 'Rostov Region', '2020-10-08', TRUE),
('UFA-001', 'Bashkir Store', 'Ufa, Oktyabr Pr., 45', 'Republic of Bashkortostan', '2022-01-15', TRUE),
('KRS-001', 'Krasnoyarsk Store', 'Krasnoyarsk, Karl Marx St., 78', 'Krasnoyarsk Krai', '2019-12-03', TRUE),
('VRN-001', 'Voronezh Store', 'Voronezh, Revolution Pr., 25', 'Voronezh Region', '2021-07-19', TRUE),
('PER-001', 'Perm Store', 'Perm, Petropavlovskaya St., 55', 'Perm Krai', '2020-03-25', TRUE),
('VLG-001', 'Volgograd Store', 'Volgograd, Mira St., 10', 'Volgograd Region', '2022-04-10', TRUE);

-- Вставка должностей (15 записей)
INSERT INTO positions (position_code, position_name, department, base_salary, description, is_active) VALUES
('POS-001', 'Sales Consultant', 'Sales', 45000.00, 'Customer consultation, product display, sales assistance', TRUE),
('POS-002', 'Senior Salesperson', 'Sales', 55000.00, 'Leading sales team, quality control of customer service', TRUE),
('POS-003', 'Cashier', 'Sales', 40000.00, 'Checkout operations, payment processing', TRUE),
('POS-004', 'Floor Manager', 'Management', 65000.00, 'Maintaining order in sales floor, conflict resolution', TRUE),
('POS-005', 'Merchandiser', 'Logistics', 50000.00, 'Goods receiving, inventory control, stocktaking', TRUE),
('POS-006', 'Warehouse Manager', 'Logistics', 55000.00, 'Warehouse management, goods storage organization', TRUE),
('POS-007', 'HR Specialist', 'HR', 60000.00, 'Recruitment, personnel documentation', TRUE),
('POS-008', 'Accountant', 'Finance', 55000.00, 'Store accounting, financial reporting', TRUE),
('POS-009', 'Store Director', 'Management', 120000.00, 'Full store management, reporting', TRUE),
('POS-010', 'Deputy Director', 'Management', 90000.00, 'Deputizing director, department supervision', TRUE),
('POS-011', 'Marketing Specialist', 'Marketing', 65000.00, 'Store promotion, marketing campaigns', TRUE),
('POS-012', 'Claims Specialist', 'Customer Service', 48000.00, 'Handling returns and customer complaints', TRUE),
('POS-013', 'Storekeeper', 'Logistics', 42000.00, 'Warehouse operations, order picking', TRUE),
('POS-014', 'Loader', 'Logistics', 38000.00, 'Loading and unloading operations', TRUE),
('POS-015', 'Security Guard', 'Security', 40000.00, 'Store security and safety', TRUE);

-- Вставка типов запросов (10 записей)
INSERT INTO request_types (type_code, type_name, description, default_priority, default_deadline_hours, is_active) VALUES
('REQ-TYPE-001', 'New Employee Hiring', 'Request for hiring a new employee for a vacant position', 3, 120, TRUE),
('REQ-TYPE-002', 'Employee Replacement', 'Request to replace a resigned or leaving employee', 2, 72, TRUE),
('REQ-TYPE-003', 'Temporary Replacement', 'Request for temporary replacement (vacation, sick leave)', 2, 48, TRUE),
('REQ-TYPE-004', 'Additional Staff', 'Request for additional staff during peak periods', 3, 96, TRUE),
('REQ-TYPE-005', 'Employee Transfer', 'Request to transfer an employee from another store', 4, 168, TRUE),
('REQ-TYPE-006', 'Skills Development', 'Request for training or professional development', 4, 240, TRUE),
('REQ-TYPE-007', 'Urgent Replacement', 'Emergency request for replacement (illness, absence)', 1, 24, TRUE),
('REQ-TYPE-008', 'Staff Expansion', 'Request to expand store staffing', 5, 336, TRUE),
('REQ-TYPE-009', 'Staff Reduction', 'Request to reduce a staff position', 5, 336, TRUE),
('REQ-TYPE-010', 'Schedule Change', 'Request to change employee work schedules', 3, 72, TRUE);

-- Вставка сотрудников (18 записей)
INSERT INTO employees (employee_code, first_name, last_name, middle_name, email, phone, position_id, store_id, hire_date, is_active) VALUES
-- Директора магазинов
('EMP-001', 'Griblo', 'Kuskov', 'Sergeevich', 'i.petrov@company.ru', '+79001112233', 9, 1, '2019-03-15', TRUE),
('EMP-002', 'Limona', 'Sidorova', 'Begemotovichna', 'm.sidorova@company.ru', '+79002223344', 9, 2, '2020-06-01', TRUE),
('EMP-003', 'Alexey', 'Kozlov', 'Ivanovich', 'a.kozlov@company.ru', '+79003334455', 9, 3, '2018-09-10', TRUE),
('EMP-004', 'Elena', 'Novikova', 'Vladimirovna', 'e.novikova@company.ru', '+79004445566', 9, 4, '2021-02-20', TRUE),
-- HR специалисты в центральном офисе
('EMP-005', 'Olga', 'Morozova', 'Nikolaevna', 'o.morozova@company.ru', '+79005556677', 7, 1, '2019-05-20', TRUE),
('EMP-006', 'Dmitry', 'Volkov', 'Andreevich', 'd.volkov@company.ru', '+79006667788', 7, 2, '2020-02-15', TRUE),
('EMP-007', 'Anna', 'Lebedeva', 'Sergeevna', 'a.lebedeva@company.ru', '+79007778899', 7, 3, '2018-11-10', TRUE),
-- Менеджеры центрального офиса
('EMP-008', 'Sergey', 'Kuznetsov', 'Petrovich', 's.kuznetsov@company.ru', '+79008889900', 10, 1, '2019-01-10', TRUE),
('EMP-009', 'Natalya', 'Sokolova', 'Ivanovna', 'n.sokolova@company.ru', '+79009990011', 10, 2, '2020-04-05', TRUE),
-- Продавцы и другие сотрудники
('EMP-010', 'Pavel', 'Popov', 'Viktorovich', 'p.popov@company.ru', '+79010011223', 1, 1, '2021-06-15', TRUE),
('EMP-011', 'Tatiana', 'Kuznetsova', 'Dmitrievna', 't.kuznetsova@company.ru', '+79011122334', 1, 2, '2021-07-20', TRUE),
-- Возможный дубль - тот же человек в другом магазине (тот же email) (не сработало, выдало ошибку на тот же email при импорте в xampp, теперь он Пупло Леонов Слонович и email его другой)
('EMP-012', 'Puplo', 'Leonov', 'Slonovich', 'p.leonov@company.ru', '+79020022334', 1, 3, '2022-01-10', TRUE),
-- Кассиры
('EMP-013', 'Viktoria', 'Smirnova', 'Alexandrovna', 'v.smirnova@company.ru', '+79012233445', 3, 1, '2020-08-25', TRUE),
('EMP-014', 'Abdula', 'Abduzhalobov', 'Abdubashabovich', 'a.fedorov@company.ru', '+79013344556', 3, 2, '2021-03-10', TRUE),
-- Товароведы
('EMP-015', 'Irina', 'Belova', 'Nikolaevna', 'i.belova@company.ru', '+79014455667', 5, 1, '2019-10-05', TRUE),
-- Администраторы
('EMP-016', 'Maxim', 'Orlov', 'Dmitrievich', 'm.orlov@company.ru', '+79015566778', 4, 1, '2020-01-15', TRUE),
-- Бухгалтер
('EMP-017', 'Svetlana', 'Krylova', 'Vladimirovna', 's.krylova@company.ru', '+79016677889', 8, 1, '2018-05-20', TRUE),
-- Охранник
('EMP-018', 'Nikolay', 'Zhukov', 'Ivanovich', 'n.zhukov@company.ru', '+79017788990', 15, 1, '2019-07-12', TRUE);

-- Обновление store_manager_id в таблице stores
UPDATE stores SET store_manager_id = 1 WHERE store_id = 1;
UPDATE stores SET store_manager_id = 2 WHERE store_id = 2;
UPDATE stores SET store_manager_id = 3 WHERE store_id = 3;
UPDATE stores SET store_manager_id = 4 WHERE store_id = 4;

-- Вставка стандартов соответствия (10 записей)
INSERT INTO compliance_standards (standard_code, standard_name, description, requirement_text, effective_date, is_active) VALUES
('STD-001', 'Educational Requirements', 'Minimum educational requirements for positions', 'Vocational or higher education required for management positions', '2023-01-01', TRUE),
('STD-002', 'Experience Requirements', 'Minimum work experience for positions', 'Minimum 2 years experience in similar position for senior roles', '2023-01-01', TRUE),
('STD-003', 'Software Skills', 'Computer skills requirements', 'Proficiency in PC, office software, 1C accounting system', '2023-01-01', TRUE),
('STD-004', 'Communication Skills', 'Communication skills requirements', 'Business communication skills, customer service, conflict resolution', '2023-01-01', TRUE),
('STD-005', 'Product Knowledge', 'Product knowledge requirements', 'Knowledge of assortment, product characteristics, storage rules', '2023-01-01', TRUE),
('STD-006', 'Safety Standards', 'Workplace safety requirements', 'Knowledge and compliance with safety regulations, fire safety', '2023-01-01', TRUE),
('STD-007', 'Qualification Requirements', 'Professional competencies', 'Professional certifications required for specific positions', '2023-01-01', TRUE),
('STD-008', 'Appearance Standards', 'Dress code and appearance standards', 'Compliance with company dress code, neat appearance', '2023-01-01', TRUE),
('STD-009', 'Legal Knowledge', 'Legal competencies', 'Knowledge of labor legislation for managers', '2023-01-01', TRUE),
('STD-010', 'Leadership Competencies', 'Management skills requirements', 'Team leadership skills, planning, motivation', '2023-01-01', TRUE);

-- Вставка должностных инструкций (15 записей)
INSERT INTO job_descriptions (position_id, version, effective_date, responsibilities, qualifications, skills_required, performance_criteria, is_compliant, compliance_check_date, compliance_notes, created_by) VALUES
(1, '2.0', '2023-06-01', 'Customer consultation on assortment; product demonstration; sales processing; maintaining order in sales floor; participating in inventory', 'Vocational education; retail experience from 1 year', 'Communication skills; product knowledge; sales skills; cash register operation', 'Sales targets; service quality; no complaints; product knowledge', TRUE, '2023-12-15', 'Full compliance with standards STD-001, STD-004, STD-005', 5),
(2, '2.0', '2023-06-01', 'Leading sales team; service quality control; training new employees; conflict resolution; sales reporting', 'Vocational education; sales experience from 2 years', 'Leadership skills; training abilities; analytical skills; service standards knowledge', 'Department sales targets; team evaluation; staff turnover; department NPS', TRUE, '2023-12-15', 'Full compliance with standards STD-001, STD-002, STD-010', 5),
(3, '2.0', '2023-06-01', 'Customer checkout; payment processing; receipt printing; price tag verification; cash collection participation', 'Secondary education; cashier experience from 6 months', 'Attention to detail; work speed; cash discipline knowledge; honesty', 'Checkout productivity; no errors; courtesy; no shortages', TRUE, '2023-12-15', 'Full compliance with standards STD-003, STD-006', 5),
(4, '2.0', '2023-06-01', 'Maintaining order in sales floor; conflict resolution; staff coordination; standards compliance control', 'Vocational education; retail experience from 3 years', 'Management skills; stress resistance; communication skills; standards knowledge', 'Floor order; no conflicts; staff evaluation; standards compliance', TRUE, '2023-12-15', 'Full compliance with standards STD-004, STD-008', 5),
(5, '2.1', '2023-09-01', 'Goods receiving from suppliers; quality and quantity control; documentation; stock accounting; inventory', 'Vocational education; merchandiser experience from 1 year', 'Attention to detail; 1C knowledge; analytical skills; storage standards', 'Receiving accuracy; documentation timeliness; no mix-ups', TRUE, '2023-12-15', 'Full compliance with standards STD-003, STD-005', 6),
(6, '1.5', '2023-03-01', 'Warehouse management; goods placement organization; storage conditions control; storekeeper supervision; reporting', 'Vocational education; warehouse experience from 2 years', 'Organizational skills; warehouse logistics knowledge; personnel management', 'Warehouse order; goods safety; warehouse efficiency', TRUE, '2023-12-15', 'Full compliance with standards STD-006, STD-010', 6),
(7, '3.0', '2023-07-01', 'Personnel recruitment; hiring and termination processing; HR records management; training organization; labor discipline control', 'Higher education (HR management); HR experience from 2 years', 'Recruitment skills; Labor Code knowledge; communication skills; documentation', 'Timely hiring; staff turnover; compliance with processing deadlines', TRUE, '2023-12-15', 'Full compliance with standards STD-001, STD-009', 7),
(8, '2.0', '2023-06-01', 'Store accounting; payroll calculation; tax reporting; cash discipline control', 'Higher economic education; accountant experience from 3 years', 'Accounting knowledge; 1C Accounting; attention to detail; analytics', 'Reporting timeliness; no fines; calculation accuracy', TRUE, '2023-12-15', 'Full compliance with standards STD-001, STD-003', 7),
(9, '2.5', '2023-08-01', 'Full store management; achieving targets; personnel management; reporting; interaction with central office', 'Higher education; retail management experience from 5 years', 'Leadership skills; strategic thinking; analytics; communication', 'Sales plan fulfillment; profitability; turnover; store NPS', TRUE, '2023-12-15', 'Full compliance with all standards', 7),
(10, '2.0', '2023-06-01', 'Deputizing director; department supervision; resolving operational issues; planning participation; execution control', 'Higher education; retail experience from 3 years', 'Management skills; initiative; responsibility; communication', 'Task execution; assigned area performance; director evaluation', TRUE, '2023-12-15', 'Full compliance with standards STD-002, STD-010', 7),
(11, '1.8', '2023-05-01', 'Developing marketing activities; conducting promotional campaigns; effectiveness analysis; social media management; window display', 'Higher education (marketing); experience from 1 year', 'Creativity; analytical skills; SMM knowledge; design skills', 'Traffic growth; campaign effectiveness; social media reach; promotional sales', FALSE, '2023-12-15', 'Need to add qualification requirements section according to STD-001', 7),
(12, '1.5', '2023-04-01', 'Receiving and processing claims; resolving customer conflicts; product quality control; return reporting', 'Vocational education; service experience from 1 year', 'Stress resistance; diplomacy; Consumer Protection Law knowledge; communication', 'Processed claims count; customer satisfaction; processing time', TRUE, '2023-12-15', 'Full compliance with standards STD-004, STD-009', 6),
(13, '2.0', '2023-06-01', 'Receiving goods at warehouse; storage placement; order picking for sales floor; maintaining warehouse order', 'Secondary education; warehouse experience preferred', 'Physical endurance; attention to detail; responsibility; neatness', 'Work speed; picking accuracy; workplace order', TRUE, '2023-12-15', 'Full compliance with standards STD-006', 6),
(14, '1.2', '2023-02-01', 'Loading and unloading operations; goods movement; inventory participation; warehouse cleanliness maintenance', 'Secondary education; no experience required', 'Physical endurance; responsibility; neatness; discipline', 'Work volume completed; no goods damage; discipline', TRUE, '2023-12-15', 'Full compliance with standards STD-006', 6),
(15, '2.0', '2023-06-01', 'Store security; entrance/exit control; theft prevention; emergency response; visitor log maintenance', 'Secondary education; security license; experience from 1 year', 'Observation skills; stress resistance; security rules knowledge; responsibility', 'No thefts; assigned area order; timely response', TRUE, '2023-12-15', 'Full compliance with standards STD-006, STD-007', 7);

-- Вставка конфигураций SLA (15 записей)
INSERT INTO sla_configurations (request_type_id, size_category, min_employees, max_employees, target_response_hours, target_completion_hours, escalation_hours, penalty_rate, is_active, created_by) VALUES
(1, 'small', 1, 2, 24, 72, 48, 0.50, TRUE, 8),
(1, 'medium', 3, 5, 48, 120, 48, 0.75, TRUE, 8),
(1, 'large', 6, 15, 72, 168, 48, 1.00, TRUE, 8),
(2, 'small', 1, 2, 12, 48, 48, 0.75, TRUE, 8),
(2, 'medium', 3, 5, 24, 72, 48, 1.00, TRUE, 8),
(3, 'small', 1, 2, 8, 36, 48, 1.00, TRUE, 8),
(3, 'medium', 3, 5, 16, 48, 48, 1.25, TRUE, 8),
(4, 'small', 1, 3, 24, 72, 48, 0.50, TRUE, 9),
(4, 'medium', 4, 8, 48, 96, 48, 0.75, TRUE, 9),
(4, 'large', 9, 20, 72, 144, 48, 1.00, TRUE, 9),
(7, 'small', 1, 2, 4, 24, 48, 1.50, TRUE, 8),
(7, 'medium', 3, 5, 8, 36, 48, 1.75, TRUE, 8),
(8, 'small', 1, 2, 72, 240, 48, 0.25, TRUE, 9),
(8, 'medium', 3, 5, 96, 336, 48, 0.50, TRUE, 9),
(8, 'large', 6, 10, 120, 480, 48, 0.75, TRUE, 9);

-- Вставка шаблонов ответов (Response Presets) - 15 записей
INSERT INTO response_presets (preset_code, preset_name, request_type_id, priority_level, deadline_hours, auto_message, recommended_action, escalation_contact_id, is_active) VALUES
('RP-001', 'Urgent Replacement - Standard', 7, 1, 24, 'Your urgent replacement request has been accepted. Expect executor assignment within 4 hours.', 'Immediately check available employee database; contact candidate; confirm shift', 5, TRUE),
('RP-002', 'Urgent Replacement - High Priority', 7, 1, 12, 'Request forwarded to senior HR specialist. We understand the urgency.', 'Contact regional manager; consider transfer options from other stores', 6, TRUE),
('RP-003', 'Temporary Replacement - Standard', 3, 2, 48, 'Temporary replacement request accepted. Candidate search has started.', 'Check vacation schedule; find employee for additional shifts; agree on schedule', 5, TRUE),
('RP-004', 'Employee Replacement - Standard', 2, 2, 72, 'Your employee replacement request has been accepted. Candidate search has begun.', 'Post vacancy; conduct initial screening; schedule interviews', 7, TRUE),
('RP-005', 'New Employee Hiring - Small', 1, 3, 96, 'New employee hiring request accepted. Completion time - up to 5 business days.', 'Analyze resumes on portals; organize interviews', 5, TRUE),
('RP-006', 'New Employee Hiring - Medium', 1, 3, 120, 'Multiple employee hiring request accepted. Mass recruitment has started.', 'Launch vacancy ads; conduct job fair; mass selection', 6, TRUE),
('RP-007', 'New Employee Hiring - Large', 1, 4, 168, 'Large-scale recruitment request forwarded for priority processing.', 'Coordination with regional HR; engage recruitment agencies', 7, TRUE),
('RP-008', 'Additional Staff - Seasonal', 4, 3, 96, 'Additional staff request accepted. Seasonal worker search has started.', 'Activate seasonal worker database; post on social media; work with universities', 5, TRUE),
('RP-009', 'Employee Transfer', 5, 4, 168, 'Employee transfer request accepted. Coordination with both stores required.', 'Contact directors of both stores; agree on transfer conditions', 6, TRUE),
('RP-010', 'Staff Expansion - Standard', 8, 4, 240, 'Staff expansion request accepted for review. Justification required.', 'Prepare workload analytics; coordinate with finance department', 8, TRUE),
('RP-011', 'Skills Development', 6, 4, 336, 'Training request accepted. Selecting optimal program.', 'Analyze training needs; select provider; coordinate budget', 7, TRUE),
('RP-012', 'Schedule Change', 10, 3, 72, 'Schedule change request accepted. Reviewing possibilities.', 'Analyze current schedules; coordinate with employees; approve changes', 5, TRUE),
('RP-013', 'Staff Reduction', 9, 5, 336, 'Reduction request accepted. Careful procedure compliance required.', 'Consult with legal department; prepare notifications; meet deadlines', 8, TRUE),
('RP-014', 'Temporary Replacement - Urgent', 3, 1, 24, 'Urgent temporary replacement request. Working in priority mode.', 'Emergency employee call; check availability for shift', 6, TRUE),
('RP-015', 'Additional Staff - Urgent', 4, 2, 48, 'Urgent additional staff request accepted.', 'Mobilize internal resources; engage quick-hire agencies', 7, TRUE);

-- Вставка запросов на персонал (Staffing Requests) - 18 записей
INSERT INTO staffing_requests (request_number, store_id, requester_id, request_type_id, position_id, quantity, size_category, urgency_reason, description, required_skills, preferred_start_date, status, assigned_to, assigned_at, sla_deadline, created_at) VALUES
('REQ-2026-001', 1, 1, 1, 1, 2, 'small', 'Electronics department expansion', 'Two sales consultants needed for electronics department due to assortment expansion', 'Knowledge of home appliances and electronics; sales experience from 1 year', '2026-02-01', 'completed', 5, '2026-01-15 10:30:00', '2026-01-22 10:30:00', '2026-01-10 10:30:00'),
('REQ-2026-002', 2, 2, 2, 3, 1, 'small', 'Employee resignation', 'Cashier replacement due to voluntary resignation', 'Cashier experience; attention to detail; responsibility', '2026-02-15', 'closed', 6, '2026-01-20 09:00:00', '2026-01-24 09:00:00', '2026-01-18 09:00:00'),
('REQ-2026-003', 3, 3, 7, 1, 1, 'small', 'Employee illness', 'Urgent replacement of salesperson during sick leave', 'Ready to start within days', '2026-01-22', 'completed', 5, '2026-01-21 16:00:00', '2026-01-22 16:00:00', '2026-01-21 14:30:00'),
('REQ-2026-004', 1, 1, 4, 13, 3, 'medium', 'Inventory preparation', 'Additional staff for annual inventory preparation', 'Physical endurance; attention to detail', '2026-02-10', 'completed', 6, '2026-01-28 11:00:00', '2026-02-05 11:00:00', '2026-01-25 11:00:00'),
('REQ-2026-005', 4, 4, 1, 2, 1, 'small', 'New department opening', 'Senior salesperson needed for new cosmetics department', 'Cosmetics experience; management skills', '2026-03-01', 'executor_assigned', 7, '2026-02-01 10:00:00', '2026-02-15 10:00:00', '2026-01-30 10:00:00'),
('REQ-2026-006', 5, 1, 3, 3, 2, 'small', 'Vacation period', 'Temporary replacement of two cashiers during vacation period', 'Cashier experience; flexible schedule', '2026-02-20', 'in_progress', 5, '2026-02-03 14:00:00', '2026-02-07 14:00:00', '2026-02-01 14:00:00'),
('REQ-2026-007', 6, 3, 8, 1, 5, 'medium', 'Second floor opening', 'Staff expansion due to second floor opening', 'Retail experience; willingness to learn', '2026-04-01', 'under_review', NULL, NULL, '2026-03-15 10:00:00', '2026-02-05 09:00:00'),
('REQ-2026-008', 2, 2, 5, 4, 1, 'small', 'Transfer from another store', 'Administrator transfer from store MOW-001', 'Employee consent; administrator experience', '2026-03-01', 'completed', 6, '2026-02-08 12:00:00', '2026-02-15 12:00:00', '2026-02-05 12:00:00'),
('REQ-2026-009', 7, 4, 6, 1, 3, 'medium', 'New employee training', 'Request for onboarding program for new salespersons', 'Training skills; standards knowledge', '2026-03-15', 'completed', 7, '2026-02-12 10:00:00', '2026-02-26 10:00:00', '2026-02-10 10:00:00'),
('REQ-2026-010', 8, 1, 7, 14, 2, 'medium', 'Urgent need', 'Urgent hiring of loaders due to increased deliveries', 'Physical endurance; responsibility', '2026-02-15', 'completed', 5, '2026-02-14 08:00:00', '2026-02-15 20:00:00', '2026-02-14 06:00:00'),
('REQ-2026-011', 3, 3, 2, 5, 1, 'small', 'Maternity leave replacement', 'Merchandiser replacement during maternity leave', 'Merchandiser experience; 1C knowledge', '2026-03-01', 'in_progress', 6, '2026-02-18 11:00:00', '2026-02-22 11:00:00', '2026-02-15 11:00:00'),
('REQ-2026-012', 9, 2, 4, 1, 4, 'medium', 'Seasonal rush', 'Additional salespersons for spring season', 'Weekend availability; communication skills', '2026-03-01', 'new', NULL, NULL, '2026-02-28 10:00:00', '2026-02-18 10:00:00'),
('REQ-2026-013', 10, 4, 1, 6, 1, 'small', 'Volume growth', 'Warehouse manager needed due to increased turnover', 'Warehouse management experience; logistics knowledge', '2026-04-01', 'pending_approval', 7, '2026-02-20 14:00:00', '2026-02-27 14:00:00', '2026-02-19 14:00:00'),
('REQ-2026-014', 1, 1, 10, NULL, 0, 'small', 'Schedule optimization', 'Request to change work schedules for grocery department', 'Consent of all department employees', '2026-03-01', 'completed', 5, '2026-02-22 09:00:00', '2026-02-25 09:00:00', '2026-02-20 09:00:00'),
('REQ-2026-015', 11, 3, 3, 15, 1, 'small', 'Sick leave', 'Temporary replacement of security guard', 'Security guard license required', '2026-02-28', 'completed', 6, '2026-02-25 10:00:00', '2026-02-26 10:00:00', '2026-02-24 22:00:00'),
('REQ-2026-016', 4, 4, 9, 2, 1, 'small', 'Staff optimization', 'Reduction of one senior salesperson position', 'Compliance with reduction procedure', '2026-05-01', 'under_review', NULL, NULL, '2026-03-10 10:00:00', '2026-02-26 10:00:00'),
('REQ-2026-017', 12, 1, 7, 13, 2, 'medium', 'Emergency situation', 'Urgent replacement of storekeepers due to warehouse accident', 'Warehouse experience; night shift availability', '2026-02-28', 'completed', 5, '2026-02-27 07:00:00', '2026-02-28 07:00:00', '2026-02-27 05:30:00'),
('REQ-2026-018', 5, 2, 1, 11, 1, 'small', 'New project', 'Marketing specialist needed for loyalty program launch', 'Loyalty program experience; analytics', '2026-04-15', 'new', NULL, NULL, '2026-03-20 10:00:00', '2026-02-28 10:00:00');

-- Вставка истории запросов (Request History) - 20 записей
INSERT INTO request_history (request_id, store_id, requester_id, action_type, old_status, new_status, action_description, performed_by, action_timestamp, notes) VALUES
(1, 1, 1, 'Request Created', NULL, 'new', 'Request created by store director', 1, '2026-01-10 10:30:00', 'Staff expansion request'),
(1, 1, 1, 'Executor Assigned', 'new', 'executor_assigned', 'Request assigned to HR specialist Olga Morozova', 5, '2026-01-15 10:30:00', 'Responsible assigned'),
(1, 1, 1, 'Completed', 'in_progress', 'completed', '2 candidates found and hired', 5, '2026-01-20 15:00:00', 'Request completed on time'),
(2, 2, 2, 'Request Created', NULL, 'new', 'Cashier replacement request', 2, '2026-01-18 09:00:00', 'Urgent replacement'),
(2, 2, 2, 'Executor Assigned', 'new', 'executor_assigned', 'Assigned to HR specialist Dmitry Volkov', 6, '2026-01-20 09:00:00', 'Executor assigned'),
(2, 2, 2, 'Closed', 'completed', 'closed', 'Candidate started work', 8, '2026-01-25 14:00:00', 'Closed by director'),
(3, 3, 3, 'Request Created', NULL, 'new', 'Urgent replacement due to illness', 3, '2026-01-21 14:30:00', 'Emergency request'),
(3, 3, 3, 'Executor Assigned', 'new', 'executor_assigned', 'Urgent assignment', 5, '2026-01-21 16:00:00', 'Within 1.5 hours'),
(4, 1, 1, 'Request Created', NULL, 'new', 'Additional staff request', 1, '2026-01-25 11:00:00', 'Inventory preparation'),
(4, 1, 1, 'Executor Assigned', 'new', 'executor_assigned', 'Responsible assigned', 6, '2026-01-28 11:00:00', ''),
(5, 4, 4, 'Request Created', NULL, 'new', 'Senior salesperson request', 4, '2026-01-30 10:00:00', 'New department'),
(5, 4, 4, 'Accepted for Review', 'new', 'under_review', 'Request forwarded for review', 8, '2026-01-31 10:00:00', ''),
(5, 4, 4, 'Executor Assigned', 'under_review', 'executor_assigned', 'HR specialist assigned', 7, '2026-02-01 10:00:00', ''),
(6, 5, 1, 'Request Created', NULL, 'new', 'Temporary replacement during vacation period', 1, '2026-02-01 14:00:00', ''),
(6, 5, 1, 'Work Started', 'executor_assigned', 'in_progress', 'Candidate search started', 5, '2026-02-03 14:00:00', ''),
(10, 8, 1, 'Request Created', NULL, 'new', 'Urgent loader hiring', 1, '2026-02-14 06:00:00', 'Emergency situation'),
(10, 8, 1, 'Executor Assigned', 'new', 'executor_assigned', 'Immediate assignment', 5, '2026-02-14 08:00:00', 'Response within 2 hours'),
(17, 12, 1, 'Request Created', NULL, 'new', 'Emergency replacement', 1, '2026-02-27 05:30:00', 'Night situation'),
(17, 12, 1, 'Executor Assigned', 'new', 'executor_assigned', 'Emergency assignment', 5, '2026-02-27 07:00:00', 'Response within 1.5 hours'),
(17, 12, 1, 'Completed', 'in_progress', 'completed', 'Employees found and started work', 5, '2026-02-28 06:00:00', 'Request completed');

-- Вставка метрик обработки (Processing Metrics) - 15 записей
INSERT INTO processing_metrics (request_id, store_id, request_type_id, size_category, created_at, assigned_at, completed_at, closed_at, response_time_hours, completion_time_hours, total_time_hours, sla_target_hours, is_sla_met, delay_hours, delay_reason) VALUES
(1, 1, 1, 'small', '2026-01-10 10:30:00', '2026-01-15 10:30:00', '2026-01-20 15:00:00', '2026-01-21 10:00:00', 120.00, 242.50, 263.50, 72, TRUE, 0, NULL),
(2, 2, 2, 'small', '2026-01-18 09:00:00', '2026-01-20 09:00:00', '2026-01-24 12:00:00', '2026-01-25 14:00:00', 48.00, 102.00, 149.00, 48, TRUE, 0, NULL),
(3, 3, 7, 'small', '2026-01-21 14:30:00', '2026-01-21 16:00:00', '2026-01-22 08:00:00', '2026-01-22 10:00:00', 1.50, 16.00, 17.50, 24, TRUE, 0, NULL),
(4, 1, 4, 'medium', '2026-01-25 11:00:00', '2026-01-28 11:00:00', '2026-02-05 16:00:00', '2026-02-06 10:00:00', 72.00, 261.00, 291.00, 96, TRUE, 0, NULL),
(5, 4, 1, 'small', '2026-01-30 10:00:00', '2026-02-01 10:00:00', NULL, NULL, 48.00, NULL, NULL, 72, TRUE, 0, NULL),
(6, 5, 3, 'small', '2026-02-01 14:00:00', '2026-02-03 14:00:00', NULL, NULL, 48.00, NULL, NULL, 36, FALSE, 12, 'Delayed executor assignment'),
(7, 6, 8, 'medium', '2026-02-05 09:00:00', NULL, NULL, NULL, NULL, NULL, NULL, 336, TRUE, 0, NULL),
(8, 2, 5, 'small', '2026-02-05 12:00:00', '2026-02-08 12:00:00', '2026-02-14 16:00:00', '2026-02-15 10:00:00', 72.00, 151.00, 239.00, 168, TRUE, 0, NULL),
(9, 7, 6, 'medium', '2026-02-10 10:00:00', '2026-02-12 10:00:00', '2026-02-25 17:00:00', '2026-02-26 09:00:00', 48.00, 319.00, 383.00, 336, TRUE, 0, NULL),
(10, 8, 7, 'medium', '2026-02-14 06:00:00', '2026-02-14 08:00:00', '2026-02-15 18:00:00', '2026-02-16 09:00:00', 2.00, 36.00, 51.00, 36, TRUE, 0, NULL),
(11, 3, 2, 'small', '2026-02-15 11:00:00', '2026-02-18 11:00:00', NULL, NULL, 72.00, NULL, NULL, 48, FALSE, 24, 'Extended candidate search'),
(14, 1, 10, 'small', '2026-02-20 09:00:00', '2026-02-22 09:00:00', '2026-02-24 17:00:00', '2026-02-25 10:00:00', 48.00, 77.00, 97.00, 72, TRUE, 0, NULL),
(15, 11, 3, 'small', '2026-02-24 22:00:00', '2026-02-25 10:00:00', '2026-02-26 08:00:00', '2026-02-26 10:00:00', 12.00, 34.00, 36.00, 36, TRUE, 0, NULL),
(17, 12, 7, 'medium', '2026-02-27 05:30:00', '2026-02-27 07:00:00', '2026-02-28 06:00:00', '2026-02-28 10:00:00', 1.50, 24.50, 28.50, 36, TRUE, 0, NULL),
(18, 5, 1, 'small', '2026-02-28 10:00:00', NULL, NULL, NULL, NULL, NULL, NULL, 96, TRUE, 0, NULL);

-- Вставка автозадач для HR Specialist - 15 записей
INSERT INTO auto_generated_tasks (task_number, request_id, assigned_to, priority, deadline, task_type, description, checklist, status, compliance_check_passed, duplicate_check_passed, created_at) VALUES
('TASK-2026-001', 1, 5, 3, '2026-01-22 10:30:00', 'Recruitment', 'Hiring 2 sales consultants for Alexeevsky store', '["Post vacancy", "Screen resumes", "Schedule interviews", "Verify documents", "Process hiring"]', 'completed', TRUE, TRUE, '2026-01-15 10:30:00'),
('TASK-2026-002', 2, 6, 2, '2026-01-24 09:00:00', 'Employee Replacement', 'Cashier hiring to replace resigned employee', '["Post vacancy", "Candidate screening", "Interview", "Processing"]', 'completed', TRUE, TRUE, '2026-01-20 09:00:00'),
('TASK-2026-003', 3, 5, 1, '2026-01-22 16:00:00', 'Urgent Replacement', 'Urgent salesperson replacement for sick leave', '["Check available database", "Contact candidate", "Confirm shift"]', 'completed', TRUE, TRUE, '2026-01-21 16:00:00'),
('TASK-2026-004', 4, 6, 3, '2026-02-05 11:00:00', 'Temporary Staff Hiring', 'Hiring 3 storekeepers for inventory', '["Analyze needs", "Find candidates", "Processing"]', 'completed', TRUE, TRUE, '2026-01-28 11:00:00'),
('TASK-2026-005', 5, 7, 3, '2026-02-15 10:00:00', 'Recruitment', 'Senior salesperson hiring for cosmetics department', '["Post vacancy", "Resume screening", "Interviews"]', 'in_progress', TRUE, TRUE, '2026-02-01 10:00:00'),
('TASK-2026-006', 6, 5, 2, '2026-02-07 14:00:00', 'Temporary Replacement', 'Hiring 2 cashiers for vacation period', '["Check database", "Schedule coordination"]', 'in_progress', TRUE, TRUE, '2026-02-03 14:00:00'),
('TASK-2026-007', 7, 6, 4, '2026-03-15 10:00:00', 'Mass Recruitment', 'Hiring 5 salespersons for new floor', '["Market analysis", "Mass selection", "Training"]', 'new', NULL, NULL, '2026-02-05 09:00:00'),
('TASK-2026-008', 8, 6, 4, '2026-02-15 12:00:00', 'Employee Transfer', 'Coordinator for administrator transfer between stores', '["Coordinate with directors", "Process transfer"]', 'completed', TRUE, TRUE, '2026-02-08 12:00:00'),
('TASK-2026-009', 9, 7, 4, '2026-02-26 10:00:00', 'Training', 'Onboarding program for new salespersons', '["Prepare program", "Assign mentors"]', 'completed', TRUE, TRUE, '2026-02-12 10:00:00'),
('TASK-2026-010', 10, 5, 1, '2026-02-15 20:00:00', 'Urgent Recruitment', 'Urgent hiring of 2 loaders', '["Emergency calls", "Processing"]', 'completed', TRUE, TRUE, '2026-02-14 08:00:00'),
('TASK-2026-011', 11, 6, 2, '2026-02-22 11:00:00', 'Maternity Leave Replacement', 'Merchandiser hiring for maternity leave coverage', '["Find candidates", "Interviews"]', 'in_progress', TRUE, TRUE, '2026-02-18 11:00:00'),
('TASK-2026-012', 12, 5, 3, '2026-02-28 10:00:00', 'Seasonal Recruitment', 'Hiring 4 salespersons for spring season', '["Post vacancies", "Candidate screening"]', 'new', NULL, NULL, '2026-02-18 10:00:00'),
('TASK-2026-013', 13, 7, 3, '2026-02-27 14:00:00', 'Recruitment', 'Warehouse manager hiring', '["Analyze requirements", "Find candidates"]', 'in_progress', TRUE, TRUE, '2026-02-20 14:00:00'),
('TASK-2026-014', 15, 6, 2, '2026-02-26 10:00:00', 'Temporary Replacement', 'Security guard replacement for sick leave', '["Find licensed guard", "Processing"]', 'completed', TRUE, TRUE, '2026-02-25 10:00:00'),
('TASK-2026-015', 17, 5, 1, '2026-02-28 07:00:00', 'Emergency Replacement', 'Urgent replacement of 2 storekeepers', '["Emergency search", "Start work"]', 'completed', TRUE, TRUE, '2026-02-27 07:00:00');

-- Вставка уведомлений - 15 записей
INSERT INTO notifications (recipient_id, notification_type, title, message, related_request_id, is_read, sent_at, priority) VALUES
(8, 'Assignment Delay', 'Executor assignment time exceeded', 'Request REQ-2026-006 has been without executor assignment for over 48 hours. Intervention required.', 6, FALSE, '2026-02-05 14:00:00', 1),
(8, 'SLA Violation', 'Target SLA time exceeded', 'Request REQ-2026-011 has exceeded target response time. Take action.', 11, FALSE, '2026-02-20 11:00:00', 2),
(1, 'Request Status', 'Request completed', 'Your request REQ-2026-001 has been successfully completed. 2 employees hired.', 1, TRUE, '2026-01-20 15:00:00', 3),
(2, 'Request Status', 'Request closed', 'Request REQ-2026-002 is closed. Candidate started work.', 2, TRUE, '2026-01-25 14:00:00', 3),
(3, 'Request Status', 'Executor assigned', 'Your request REQ-2026-003 has an assigned executor. Expect results.', 3, TRUE, '2026-01-21 16:00:00', 2),
(5, 'New Task', 'New task assigned', 'Task TASK-2026-005 assigned to you. Deadline: Feb 15, 2026', 5, TRUE, '2026-02-01 10:00:00', 3),
(6, 'New Task', 'New task assigned', 'Task TASK-2026-006 assigned to you. Deadline: Feb 07, 2026', 6, TRUE, '2026-02-03 14:00:00', 2),
(7, 'New Task', 'New task assigned', 'Task TASK-2026-007 assigned to you. Large recruitment request.', 7, TRUE, '2026-02-05 09:00:00', 4),
(8, 'Information', 'Approval required', 'Request REQ-2026-007 requires approval for staff expansion.', 7, FALSE, '2026-02-06 10:00:00', 3),
(1, 'Request Status', 'Request in progress', 'Your request REQ-2026-004: staff recruitment has started.', 4, TRUE, '2026-01-28 11:00:00', 3),
(4, 'Request Status', 'Executor assigned', 'Request REQ-2026-005 has an assigned HR specialist. Recruitment started.', 5, TRUE, '2026-02-01 10:00:00', 3),
(5, 'Reminder', 'Deadline approaching', 'Task TASK-2026-005 deadline expires in 3 days.', 5, FALSE, '2026-02-12 10:00:00', 2),
(8, 'Report', 'Weekly report ready', 'Weekly request processing metrics report is available for review.', NULL, FALSE, '2026-02-19 09:00:00', 4),
(1, 'Urgent', 'Emergency request', 'Urgent request REQ-2026-017 created. Immediate response required.', 17, TRUE, '2026-02-27 05:30:00', 1),
(8, 'Information', 'New reduction request', 'Request REQ-2026-016 for staff reduction requires review.', 16, FALSE, '2026-02-26 11:00:00', 3);

-- Вставка журнала статусов - 18 записей
INSERT INTO request_status_log (request_id, status, changed_by, changed_at, comment) VALUES
(1, 'new', 1, '2026-01-10 10:30:00', 'Request created'),
(1, 'executor_assigned', 5, '2026-01-15 10:30:00', 'HR specialist assigned as responsible'),
(1, 'in_progress', 5, '2026-01-16 09:00:00', 'Candidate search started'),
(1, 'completed', 5, '2026-01-20 15:00:00', 'Candidates found and hired'),
(2, 'new', 2, '2026-01-18 09:00:00', 'Request created'),
(2, 'executor_assigned', 6, '2026-01-20 09:00:00', 'HR specialist assigned'),
(2, 'completed', 6, '2026-01-24 12:00:00', 'Candidate found and started work'),
(2, 'closed', 8, '2026-01-25 14:00:00', 'Request closed by Central Office Manager'),
(3, 'new', 3, '2026-01-21 14:30:00', 'Urgent request created'),
(3, 'executor_assigned', 5, '2026-01-21 16:00:00', 'Emergency assignment'),
(3, 'completed', 5, '2026-01-22 08:00:00', 'Replacement found in shortest time'),
(5, 'new', 4, '2026-01-30 10:00:00', 'Request created'),
(5, 'under_review', 8, '2026-01-31 10:00:00', 'Forwarded for review'),
(5, 'executor_assigned', 7, '2026-02-01 10:00:00', 'Responsible assigned'),
(6, 'new', 1, '2026-02-01 14:00:00', 'Request created'),
(6, 'executor_assigned', 5, '2026-02-03 14:00:00', 'Assigned as executor'),
(6, 'in_progress', 5, '2026-02-04 09:00:00', 'Temporary employee search started'),
(17, 'completed', 5, '2026-02-28 06:00:00', 'Emergency situation resolved');

-- Вставка элементов меню UI - 15 записей
INSERT INTO ui_menu_items (parent_id, menu_code, menu_name, menu_path, icon_class, display_order, role_required, is_active) VALUES
(NULL, 'MENU_DASHBOARD', 'Dashboard', '/dashboard', 'fa-home', 1, 'all', TRUE),
(NULL, 'MENU_REQUESTS', 'Requests', '/requests', 'fa-file-alt', 2, 'all', TRUE),
(NULL, 'MENU_HISTORY', 'Request History', '/history', 'fa-history', 3, 'store_manager', TRUE),
(NULL, 'MENU_NEW_REQUEST', 'Create Request', '/requests/new', 'fa-plus-circle', 4, 'store_manager', TRUE),
(NULL, 'MENU_METRICS', 'Metrics', '/metrics', 'fa-chart-bar', 5, 'central_office_manager', TRUE),
(NULL, 'MENU_SLA', 'SLA Settings', '/sla', 'fa-cog', 6, 'central_office_manager', TRUE),
(NULL, 'MENU_ANALYTICS', 'Analytics', '/analytics', 'fa-chart-line', 7, 'central_office_manager', TRUE),
(NULL, 'MENU_TASKS', 'My Tasks', '/tasks', 'fa-tasks', 8, 'hr_specialist', TRUE),
(NULL, 'MENU_EMPLOYEES', 'Employees', '/employees', 'fa-users', 9, 'hr_specialist', TRUE),
(NULL, 'MENU_JOB_DESC', 'Job Descriptions', '/job-descriptions', 'fa-book', 10, 'hr_specialist', TRUE),
(NULL, 'MENU_PRESETS', 'Response Presets', '/presets', 'fa-copy', 11, 'hr_specialist', TRUE),
(NULL, 'MENU_NOTIFICATIONS', 'Notifications', '/notifications', 'fa-bell', 12, 'all', TRUE),
(NULL, 'MENU_REPORTS', 'Reports', '/reports', 'fa-file-pdf', 13, 'central_office_manager', TRUE),
(NULL, 'MENU_SETTINGS', 'Settings', '/settings', 'fa-wrench', 14, 'all', TRUE),
(NULL, 'MENU_HELP', 'Help', '/help', 'fa-question-circle', 15, 'all', TRUE);

-- Вставка системных настроек - 15 записей
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, updated_by) VALUES
('DEFAULT_SLA_RESPONSE_HOURS', '48', 'integer', 'Стандартное время реакции SLA в часах', 8),
('MAX_HISTORY_MONTHS', '6', 'integer', 'Период хранения истории запросов (месяцы)', 8),
('NOTIFICATION_DELAY_THRESHOLD', '48', 'integer', 'Порог задержки для уведомлений (часы)', 8),
('AUTO_ASSIGN_ENABLED', 'true', 'boolean', 'Автоматическое назначение исполнителей', 8),
('ESCALATION_ENABLED', 'true', 'boolean', 'Автоматическая эскалация при задержках', 8),
('DUPLICATE_CHECK_ENABLED', 'true', 'boolean', 'Автоматическая проверка дублей сотрудников', 7),
('COMPLIANCE_CHECK_ENABLED', 'true', 'boolean', 'Автоматическая проверка соответствия должностных инструкций', 7),
('MAX_REQUESTS_PER_DAY', '50', 'integer', 'Максимальное количество запросов в день на магазин', 8),
('REPORT_GENERATION_HOUR', '09:00', 'time', 'Время автоматической генерации отчётов', 8),
('BACKUP_INTERVAL_HOURS', '24', 'integer', 'Интервал резервного копирования (часы)', 8),
('SESSION_TIMEOUT_MINUTES', '30', 'integer', 'Таймаут сессии пользователя (минуты)', 8),
('PASSWORD_MIN_LENGTH', '8', 'integer', 'Минимальная длина пароля', 8),
('LANGUAGE_DEFAULT', 'en', 'string', 'Язык интерфейса по умолчанию', 8),
('TIMEZONE_DEFAULT', 'Europe/Moscow', 'string', 'Часовой пояс по умолчанию', 8),
('CURRENCY_DEFAULT', 'RUB', 'string', 'Валюта по умолчанию', 8);

-- ============================================================
-- ИНДЕКСЫ ДЛЯ ОПТИМИЗАЦИИ ЗАПРОСОВ
-- ============================================================

CREATE INDEX idx_employees_store ON employees(store_id);
CREATE INDEX idx_employees_position ON employees(position_id);
CREATE INDEX idx_employees_active ON employees(is_active);
CREATE INDEX idx_requests_store ON staffing_requests(store_id);
CREATE INDEX idx_requests_status ON staffing_requests(status);
CREATE INDEX idx_requests_type ON staffing_requests(request_type_id);
CREATE INDEX idx_requests_created ON staffing_requests(created_at);
CREATE INDEX idx_history_store ON request_history(store_id);
CREATE INDEX idx_history_request ON request_history(request_id);
CREATE INDEX idx_history_timestamp ON request_history(action_timestamp);
CREATE INDEX idx_metrics_store ON processing_metrics(store_id);
CREATE INDEX idx_metrics_request ON processing_metrics(request_id);
CREATE INDEX idx_metrics_sla ON processing_metrics(is_sla_met);
CREATE INDEX idx_tasks_assigned ON auto_generated_tasks(assigned_to);
CREATE INDEX idx_tasks_status ON auto_generated_tasks(status);
CREATE INDEX idx_tasks_deadline ON auto_generated_tasks(deadline);
CREATE INDEX idx_notifications_recipient ON notifications(recipient_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);

-- ============================================================
-- КОММЕНТАРИИ К ТАБЛИЦАМ (не нравятся скамппу)
-- ============================================================

-- COMMENT ON TABLE stores IS 'Справочник магазинов';
-- COMMENT ON TABLE positions IS 'Справочник должностей';
-- COMMENT ON TABLE employees IS 'База данных сотрудников (Data Object из BPMN)';
-- COMMENT ON TABLE job_descriptions IS 'База должностных инструкций (Data Object из BPMN)';
-- COMMENT ON TABLE request_history IS 'История запросов для управляющего магазом (Data Object из BPMN)';
-- COMMENT ON TABLE processing_metrics IS 'Метрики обработки для управляющего централом (офисом) (Data Object из BPMN)';
-- COMMENT ON TABLE staffing_requests IS 'Запросы на персонал';
-- COMMENT ON TABLE response_presets IS 'Шаблоны ответов HR-специалиста (для того шлюза Assign Executor)';
-- COMMENT ON TABLE sla_configurations IS 'Конфигурации SLA по размеру запроса';
-- COMMENT ON TABLE auto_generated_tasks IS 'Автозадачи для HR-специалиста';
-- COMMENT ON TABLE notifications IS 'Уведомления о задержках и событиях';
-- COMMENT ON TABLE compliance_standards IS 'Стандарты соответствия компании';

-- ============================================================
-- ФИНАЛЬНЫЕ ЗАПРОСЫ ДЛЯ ПРОВЕРКИ ДАННЫХ
-- ============================================================

-- Количество записей в каждой таблице
SELECT 'stores' AS table_name, COUNT(*) AS record_count FROM stores
UNION ALL SELECT 'positions', COUNT(*) FROM positions
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'job_descriptions', COUNT(*) FROM job_descriptions
UNION ALL SELECT 'request_types', COUNT(*) FROM request_types
UNION ALL SELECT 'staffing_requests', COUNT(*) FROM staffing_requests
UNION ALL SELECT 'request_history', COUNT(*) FROM request_history
UNION ALL SELECT 'processing_metrics', COUNT(*) FROM processing_metrics
UNION ALL SELECT 'auto_generated_tasks', COUNT(*) FROM auto_generated_tasks
UNION ALL SELECT 'response_presets', COUNT(*) FROM response_presets
UNION ALL SELECT 'sla_configurations', COUNT(*) FROM sla_configurations
UNION ALL SELECT 'notifications', COUNT(*) FROM notifications
UNION ALL SELECT 'request_status_log', COUNT(*) FROM request_status_log
UNION ALL SELECT 'ui_menu_items', COUNT(*) FROM ui_menu_items
UNION ALL SELECT 'system_settings', COUNT(*) FROM system_settings;

-- Показать возможные дубли сотрудников (работало бы это в скамппе)
SELECT * FROM vw_employee_duplicates_check;

-- Показать несоответствующие должностные инструкции
SELECT * FROM vw_job_description_compliance WHERE is_compliant = FALSE;

-- Показать нарушения SLA
SELECT * FROM vw_central_office_metrics WHERE is_sla_met = FALSE;