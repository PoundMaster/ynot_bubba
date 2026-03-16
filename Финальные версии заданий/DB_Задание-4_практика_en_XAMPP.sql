-- ============================================================
-- БАЗА ДАННЫХ ДЛЯ ПРОЦЕССА ВЗАИМОДЕЙСТВИЯ СОТРУДНИКОВ
-- BPMN Diagram Database Implementation (MySQL Version)
-- Compatible with XAMPP / phpMyAdmin / MySQL / MariaDB
-- ============================================================

-- Установка кодировки
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- УДАЛЕНИЕ СУЩЕСТВУЮЩИХ ТАБЛИЦ (в правильном порядке)
-- ============================================================

DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS request_status_log;
DROP TABLE IF EXISTS auto_generated_tasks;
DROP TABLE IF EXISTS processing_metrics;
DROP TABLE IF EXISTS request_history;
DROP TABLE IF EXISTS staffing_requests;
DROP TABLE IF EXISTS response_presets;
DROP TABLE IF EXISTS sla_configurations;
DROP TABLE IF EXISTS job_descriptions;
DROP TABLE IF EXISTS compliance_standards;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS positions;
DROP TABLE IF EXISTS stores;
DROP TABLE IF EXISTS request_types;
DROP TABLE IF EXISTS ui_menu_items;
DROP TABLE IF EXISTS system_settings;

-- ============================================================
-- СПРАВОЧНЫЕ ТАБЛИЦЫ
-- ============================================================

-- Таблица: Магазины (Stores)
CREATE TABLE stores (
    store_id INT AUTO_INCREMENT PRIMARY KEY,
    store_code VARCHAR(20) UNIQUE NOT NULL,
    store_name VARCHAR(100) NOT NULL,
    address VARCHAR(200) NOT NULL,
    region VARCHAR(50) NOT NULL,
    store_manager_id INT NULL,
    opening_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_store_code (store_code),
    INDEX idx_region (region)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Должности (Positions)
CREATE TABLE positions (
    position_id INT AUTO_INCREMENT PRIMARY KEY,
    position_code VARCHAR(20) UNIQUE NOT NULL,
    position_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    base_salary DECIMAL(10,2),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_position_code (position_code),
    INDEX idx_department (department)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Типы запросов (Request Types)
CREATE TABLE request_types (
    type_id INT AUTO_INCREMENT PRIMARY KEY,
    type_code VARCHAR(20) UNIQUE NOT NULL,
    type_name VARCHAR(100) NOT NULL,
    description TEXT,
    default_priority INT DEFAULT 3,
    default_deadline_hours INT DEFAULT 72,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_type_code (type_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Стандарты соответствия (Compliance Standards)
CREATE TABLE compliance_standards (
    standard_id INT AUTO_INCREMENT PRIMARY KEY,
    standard_code VARCHAR(20) UNIQUE NOT NULL,
    standard_name VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    requirement_text TEXT NOT NULL,
    effective_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_standard_code (standard_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ОСНОВНЫЕ ТАБЛИЦЫ ДАННЫХ (DATA OBJECTS ИЗ BPMN)
-- ============================================================

-- Таблица: Сотрудники (Employee Database)
CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_code VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    position_id INT NULL,
    store_id INT NULL,
    hire_date DATE NOT NULL,
    termination_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    is_duplicate_flag BOOLEAN DEFAULT FALSE,
    duplicate_of_employee_id INT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_employee_code (employee_code),
    INDEX idx_email (email),
    INDEX idx_position (position_id),
    INDEX idx_store (store_id),
    INDEX idx_active (is_active),
    CONSTRAINT fk_employees_position FOREIGN KEY (position_id) REFERENCES positions(position_id) ON DELETE SET NULL,
    CONSTRAINT fk_employees_store FOREIGN KEY (store_id) REFERENCES stores(store_id) ON DELETE SET NULL,
    CONSTRAINT fk_employees_duplicate FOREIGN KEY (duplicate_of_employee_id) REFERENCES employees(employee_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Должностные инструкции (Job Descriptions Database)
CREATE TABLE job_descriptions (
    description_id INT AUTO_INCREMENT PRIMARY KEY,
    position_id INT NOT NULL,
    version VARCHAR(10) NOT NULL,
    effective_date DATE NOT NULL,
    responsibilities TEXT NOT NULL,
    qualifications TEXT NOT NULL,
    skills_required TEXT,
    performance_criteria TEXT,
    is_compliant BOOLEAN DEFAULT TRUE,
    compliance_check_date DATE,
    compliance_notes TEXT,
    created_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_position_version (position_id, version),
    INDEX idx_position (position_id),
    INDEX idx_compliant (is_compliant),
    CONSTRAINT fk_jobdesc_position FOREIGN KEY (position_id) REFERENCES positions(position_id) ON DELETE CASCADE,
    CONSTRAINT fk_jobdesc_creator FOREIGN KEY (created_by) REFERENCES employees(employee_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ТАБЛИЦА ШАБЛОНОВ ОТВЕТОВ (RESPONSE PRESETS)
-- Для HR Specialist на развилке "Assign Executor"
-- ============================================================

CREATE TABLE response_presets (
    preset_id INT AUTO_INCREMENT PRIMARY KEY,
    preset_code VARCHAR(20) UNIQUE NOT NULL,
    preset_name VARCHAR(100) NOT NULL,
    request_type_id INT NOT NULL,
    priority_level INT NOT NULL CHECK (priority_level BETWEEN 1 AND 5),
    deadline_hours INT NOT NULL,
    auto_message TEXT NOT NULL,
    recommended_action TEXT,
    escalation_contact_id INT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    usage_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_preset_code (preset_code),
    INDEX idx_request_type (request_type_id),
    INDEX idx_priority (priority_level),
    CONSTRAINT fk_presets_request_type FOREIGN KEY (request_type_id) REFERENCES request_types(type_id) ON DELETE CASCADE,
    CONSTRAINT fk_presets_escalation FOREIGN KEY (escalation_contact_id) REFERENCES employees(employee_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ТАБЛИЦЫ ПРОЦЕССА ЗАПРОСОВ
-- ============================================================

-- Таблица: Конфигурации SLA (SLA Configurations)
CREATE TABLE sla_configurations (
    sla_id INT AUTO_INCREMENT PRIMARY KEY,
    request_type_id INT NOT NULL,
    size_category ENUM('small', 'medium', 'large') NOT NULL,
    min_employees INT NOT NULL,
    max_employees INT NOT NULL,
    target_response_hours INT NOT NULL,
    target_completion_hours INT NOT NULL,
    escalation_hours INT NOT NULL DEFAULT 48,
    penalty_rate DECIMAL(5,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_type_size (request_type_id, size_category),
    INDEX idx_request_type (request_type_id),
    INDEX idx_size (size_category),
    CONSTRAINT fk_sla_request_type FOREIGN KEY (request_type_id) REFERENCES request_types(type_id) ON DELETE CASCADE,
    CONSTRAINT fk_sla_creator FOREIGN KEY (created_by) REFERENCES employees(employee_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Запросы на персонал (Staffing Requests)
CREATE TABLE staffing_requests (
    request_id INT AUTO_INCREMENT PRIMARY KEY,
    request_number VARCHAR(30) UNIQUE NOT NULL,
    store_id INT NOT NULL,
    requester_id INT NOT NULL,
    request_type_id INT NOT NULL,
    position_id INT NULL,
    quantity INT NOT NULL DEFAULT 1,
    size_category VARCHAR(20) NOT NULL,
    urgency_reason TEXT,
    description TEXT NOT NULL,
    required_skills TEXT,
    preferred_start_date DATE,
    status ENUM('new', 'under_review', 'executor_assigned', 'in_progress', 'pending_approval', 'completed', 'closed', 'rejected') NOT NULL DEFAULT 'new',
    assigned_to INT NULL,
    assigned_at TIMESTAMP NULL,
    sla_deadline TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    closed_by INT NULL,
    closed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_request_number (request_number),
    INDEX idx_store (store_id),
    INDEX idx_requester (requester_id),
    INDEX idx_request_type (request_type_id),
    INDEX idx_position (position_id),
    INDEX idx_status (status),
    INDEX idx_created (created_at),
    CONSTRAINT fk_requests_store FOREIGN KEY (store_id) REFERENCES stores(store_id) ON DELETE CASCADE,
    CONSTRAINT fk_requests_requester FOREIGN KEY (requester_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_requests_type FOREIGN KEY (request_type_id) REFERENCES request_types(type_id) ON DELETE CASCADE,
    CONSTRAINT fk_requests_position FOREIGN KEY (position_id) REFERENCES positions(position_id) ON DELETE SET NULL,
    CONSTRAINT fk_requests_assigned FOREIGN KEY (assigned_to) REFERENCES employees(employee_id) ON DELETE SET NULL,
    CONSTRAINT fk_requests_closed_by FOREIGN KEY (closed_by) REFERENCES employees(employee_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: История запросов (Request History Database)
-- Для Store Manager - просмотр истории за 6 месяцев
CREATE TABLE request_history (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    request_id INT NOT NULL,
    store_id INT NOT NULL,
    requester_id INT NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    old_status VARCHAR(30),
    new_status VARCHAR(30),
    action_description TEXT,
    performed_by INT NULL,
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    INDEX idx_request (request_id),
    INDEX idx_store (store_id),
    INDEX idx_requester (requester_id),
    INDEX idx_timestamp (action_timestamp),
    CONSTRAINT fk_history_request FOREIGN KEY (request_id) REFERENCES staffing_requests(request_id) ON DELETE CASCADE,
    CONSTRAINT fk_history_store FOREIGN KEY (store_id) REFERENCES stores(store_id) ON DELETE CASCADE,
    CONSTRAINT fk_history_requester FOREIGN KEY (requester_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_history_performed FOREIGN KEY (performed_by) REFERENCES employees(employee_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Метрики обработки (Processing Metrics Database)
-- Для Central Office Manager - метрики времени обработки
CREATE TABLE processing_metrics (
    metric_id INT AUTO_INCREMENT PRIMARY KEY,
    request_id INT NOT NULL,
    store_id INT NOT NULL,
    request_type_id INT NOT NULL,
    size_category VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    assigned_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    closed_at TIMESTAMP NULL,
    response_time_hours DECIMAL(10,2),
    completion_time_hours DECIMAL(10,2),
    total_time_hours DECIMAL(10,2),
    sla_target_hours INT,
    is_sla_met BOOLEAN,
    delay_hours DECIMAL(10,2) DEFAULT 0,
    delay_reason TEXT,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_request (request_id),
    INDEX idx_store (store_id),
    INDEX idx_request_type (request_type_id),
    INDEX idx_sla_met (is_sla_met),
    CONSTRAINT fk_metrics_request FOREIGN KEY (request_id) REFERENCES staffing_requests(request_id) ON DELETE CASCADE,
    CONSTRAINT fk_metrics_store FOREIGN KEY (store_id) REFERENCES stores(store_id) ON DELETE CASCADE,
    CONSTRAINT fk_metrics_type FOREIGN KEY (request_type_id) REFERENCES request_types(type_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Автозадачи для HR Specialist (Auto-Generated Tasks)
CREATE TABLE auto_generated_tasks (
    task_id INT AUTO_INCREMENT PRIMARY KEY,
    task_number VARCHAR(30) UNIQUE NOT NULL,
    request_id INT NOT NULL,
    assigned_to INT NOT NULL,
    priority INT NOT NULL CHECK (priority BETWEEN 1 AND 5),
    deadline TIMESTAMP NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    checklist JSON,
    status ENUM('new', 'accepted', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'new',
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    compliance_check_passed BOOLEAN,
    duplicate_check_passed BOOLEAN,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_task_number (task_number),
    INDEX idx_request (request_id),
    INDEX idx_assigned (assigned_to),
    INDEX idx_status (status),
    INDEX idx_deadline (deadline),
    CONSTRAINT fk_tasks_request FOREIGN KEY (request_id) REFERENCES staffing_requests(request_id) ON DELETE CASCADE,
    CONSTRAINT fk_tasks_assigned FOREIGN KEY (assigned_to) REFERENCES employees(employee_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Журнал статусов запросов
CREATE TABLE request_status_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    request_id INT NOT NULL,
    status VARCHAR(30) NOT NULL,
    changed_by INT NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comment TEXT,
    INDEX idx_request (request_id),
    INDEX idx_changed_at (changed_at),
    CONSTRAINT fk_log_request FOREIGN KEY (request_id) REFERENCES staffing_requests(request_id) ON DELETE CASCADE,
    CONSTRAINT fk_log_changed_by FOREIGN KEY (changed_by) REFERENCES employees(employee_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Уведомления (для задержек > 48 часов)
CREATE TABLE notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    recipient_id INT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    related_request_id INT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    priority INT DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    INDEX idx_recipient (recipient_id),
    INDEX idx_read (is_read),
    INDEX idx_sent (sent_at),
    CONSTRAINT fk_notifications_recipient FOREIGN KEY (recipient_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_notifications_request FOREIGN KEY (related_request_id) REFERENCES staffing_requests(request_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ДОПОЛНИТЕЛЬНЫЕ ТАБЛИЦЫ (UI И ФУНКЦИОНАЛЬНОСТЬ)
-- ============================================================

-- Таблица: Элементы меню UI
CREATE TABLE ui_menu_items (
    menu_id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NULL,
    menu_code VARCHAR(30) UNIQUE NOT NULL,
    menu_name VARCHAR(100) NOT NULL,
    menu_path VARCHAR(200),
    icon_class VARCHAR(50),
    display_order INT NOT NULL,
    role_required ENUM('store_manager', 'central_office_manager', 'hr_specialist', 'all') NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_menu_code (menu_code),
    INDEX idx_parent (parent_id),
    INDEX idx_role (role_required),
    CONSTRAINT fk_menu_parent FOREIGN KEY (parent_id) REFERENCES ui_menu_items(menu_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица: Системные настройки
CREATE TABLE system_settings (
    setting_id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    setting_type VARCHAR(20) NOT NULL DEFAULT 'string',
    description TEXT,
    updated_by INT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_setting_key (setting_key),
    CONSTRAINT fk_settings_updated_by FOREIGN KEY (updated_by) REFERENCES employees(employee_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ДОБАВЛЕНИЕ ВНЕШНЕГО КЛЮЧА ДЛЯ stores.store_manager_id
-- ============================================================

ALTER TABLE stores
ADD CONSTRAINT fk_stores_manager FOREIGN KEY (store_manager_id) REFERENCES employees(employee_id) ON DELETE SET NULL;

-- ============================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦ ДАННЫМИ (ENGLISH VERSION)
-- ============================================================

-- Вставка типов запросов (сначала, т.к. нужны для других таблиц)
INSERT INTO request_types (type_id, type_code, type_name, description, default_priority, default_deadline_hours, is_active) VALUES
(1, 'REQ-TYPE-001', 'New Employee Hiring', 'Request for hiring a new employee for a vacant position', 3, 120, TRUE),
(2, 'REQ-TYPE-002', 'Employee Replacement', 'Request to replace a resigned or leaving employee', 2, 72, TRUE),
(3, 'REQ-TYPE-003', 'Temporary Replacement', 'Request for temporary replacement (vacation, sick leave)', 2, 48, TRUE),
(4, 'REQ-TYPE-004', 'Additional Staff', 'Request for additional staff during peak periods', 3, 96, TRUE),
(5, 'REQ-TYPE-005', 'Employee Transfer', 'Request to transfer an employee from another store', 4, 168, TRUE),
(6, 'REQ-TYPE-006', 'Skills Development', 'Request for training or professional development', 4, 240, TRUE),
(7, 'REQ-TYPE-007', 'Urgent Replacement', 'Emergency request for replacement (illness, absence)', 1, 24, TRUE),
(8, 'REQ-TYPE-008', 'Staff Expansion', 'Request to expand store staffing', 5, 336, TRUE),
(9, 'REQ-TYPE-009', 'Staff Reduction', 'Request to reduce a staff position', 5, 336, TRUE),
(10, 'REQ-TYPE-010', 'Schedule Change', 'Request to change employee work schedules', 3, 72, TRUE);

-- Вставка должностей (сначала, т.к. нужны для сотрудников)
INSERT INTO positions (position_id, position_code, position_name, department, base_salary, description, is_active) VALUES
(1, 'POS-001', 'Sales Consultant', 'Sales', 45000.00, 'Customer consultation, product display, sales assistance', TRUE),
(2, 'POS-002', 'Senior Salesperson', 'Sales', 55000.00, 'Leading sales team, quality control of customer service', TRUE),
(3, 'POS-003', 'Cashier', 'Sales', 40000.00, 'Checkout operations, payment processing', TRUE),
(4, 'POS-004', 'Floor Manager', 'Management', 65000.00, 'Maintaining order in sales floor, conflict resolution', TRUE),
(5, 'POS-005', 'Merchandiser', 'Logistics', 50000.00, 'Goods receiving, inventory control, stocktaking', TRUE),
(6, 'POS-006', 'Warehouse Manager', 'Logistics', 55000.00, 'Warehouse management, goods storage organization', TRUE),
(7, 'POS-007', 'HR Specialist', 'HR', 60000.00, 'Recruitment, personnel documentation', TRUE),
(8, 'POS-008', 'Accountant', 'Finance', 55000.00, 'Store accounting, financial reporting', TRUE),
(9, 'POS-009', 'Store Director', 'Management', 120000.00, 'Full store management, reporting', TRUE),
(10, 'POS-010', 'Deputy Director', 'Management', 90000.00, 'Deputizing director, department supervision', TRUE),
(11, 'POS-011', 'Marketing Specialist', 'Marketing', 65000.00, 'Store promotion, marketing campaigns', TRUE),
(12, 'POS-012', 'Claims Specialist', 'Customer Service', 48000.00, 'Handling returns and customer complaints', TRUE),
(13, 'POS-013', 'Storekeeper', 'Logistics', 42000.00, 'Warehouse operations, order picking', TRUE),
(14, 'POS-014', 'Loader', 'Logistics', 38000.00, 'Loading and unloading operations', TRUE),
(15, 'POS-015', 'Security Guard', 'Security', 40000.00, 'Store security and safety', TRUE);

-- Вставка магазинов (сначала без manager_id)
INSERT INTO stores (store_id, store_code, store_name, address, region, opening_date, is_active) VALUES
(1, 'MOW-001', 'Alexeevsky Store', 'Moscow, Alexeevskaya St., 15', 'Moscow', '2019-03-15', TRUE),
(2, 'MOW-002', 'Arbat Store', 'Moscow, Arbat St., 22', 'Moscow', '2020-06-01', TRUE),
(3, 'SPB-001', 'Nevsky Store', 'St. Petersburg, Nevsky Pr., 45', 'St. Petersburg', '2018-09-10', TRUE),
(4, 'SPB-002', 'Petrogradsky Store', 'St. Petersburg, Petrogradskaya Emb., 18', 'St. Petersburg', '2021-02-20', TRUE),
(5, 'EKB-001', 'Ural Store', 'Yekaterinburg, Lenin St., 32', 'Sverdlovsk Region', '2019-11-05', TRUE),
(6, 'NSK-001', 'Siberian Store', 'Novosibirsk, Krasny Pr., 50', 'Novosibirsk Region', '2020-04-12', TRUE),
(7, 'KZN-001', 'Kazan Store', 'Kazan, Bauman St., 28', 'Republic of Tatarstan', '2018-07-22', TRUE),
(8, 'NNV-001', 'Nizhny Novgorod Store', 'Nizhny Novgorod, Bolshaya Pokrovskaya St., 35', 'Nizhny Novgorod Region', '2021-05-30', TRUE),
(9, 'SAM-001', 'Samara Store', 'Samara, Kuibyshev St., 120', 'Samara Region', '2019-08-14', TRUE),
(10, 'RND-001', 'Rostov Store', 'Rostov-on-Don, Budennovsky Pr., 65', 'Rostov Region', '2020-10-08', TRUE),
(11, 'UFA-001', 'Bashkir Store', 'Ufa, Oktyabr Pr., 45', 'Republic of Bashkortostan', '2022-01-15', TRUE),
(12, 'KRS-001', 'Krasnoyarsk Store', 'Krasnoyarsk, Karl Marx St., 78', 'Krasnoyarsk Krai', '2019-12-03', TRUE),
(13, 'VRN-001', 'Voronezh Store', 'Voronezh, Revolution Pr., 25', 'Voronezh Region', '2021-07-19', TRUE),
(14, 'PER-001', 'Perm Store', 'Perm, Petropavlovskaya St., 55', 'Perm Krai', '2020-03-25', TRUE),
(15, 'VLG-001', 'Volgograd Store', 'Volgograd, Mira St., 10', 'Volgograd Region', '2022-04-10', TRUE);

-- Вставка сотрудников (директора магазинов, HR, менеджеры)
INSERT INTO employees (employee_id, employee_code, first_name, last_name, middle_name, email, phone, position_id, store_id, hire_date, is_active) VALUES
(1, 'EMP-001', 'Ivan', 'Petrov', 'Sergeevich', 'i.petrov@company.ru', '+79001112233', 9, 1, '2019-03-15', TRUE),
(2, 'EMP-002', 'Maria', 'Sidorova', 'Alexandrovna', 'm.sidorova@company.ru', '+79002223344', 9, 2, '2020-06-01', TRUE),
(3, 'EMP-003', 'Alexey', 'Kozlov', 'Ivanovich', 'a.kozlov@company.ru', '+79003334455', 9, 3, '2018-09-10', TRUE),
(4, 'EMP-004', 'Elena', 'Novikova', 'Vladimirovna', 'e.novikova@company.ru', '+79004445566', 9, 4, '2021-02-20', TRUE),
(5, 'EMP-005', 'Olga', 'Morozova', 'Nikolaevna', 'o.morozova@company.ru', '+79005556677', 7, 1, '2019-05-20', TRUE),
(6, 'EMP-006', 'Dmitry', 'Volkov', 'Andreevich', 'd.volkov@company.ru', '+79006667788', 7, 2, '2020-02-15', TRUE),
(7, 'EMP-007', 'Anna', 'Lebedeva', 'Sergeevna', 'a.lebedeva@company.ru', '+79007778899', 7, 3, '2018-11-10', TRUE),
(8, 'EMP-008', 'Sergey', 'Kuznetsov', 'Petrovich', 's.kuznetsov@company.ru', '+79008889900', 10, 1, '2019-01-10', TRUE),
(9, 'EMP-009', 'Natalya', 'Sokolova', 'Ivanovna', 'n.sokolova@company.ru', '+79009990011', 10, 2, '2020-04-05', TRUE),
(10, 'EMP-010', 'Pavel', 'Popov', 'Viktorovich', 'p.popov@company.ru', '+79010011223', 1, 1, '2021-06-15', TRUE),
(11, 'EMP-011', 'Tatiana', 'Kuznetsova', 'Dmitrievna', 't.kuznetsova@company.ru', '+79011122334', 1, 2, '2021-07-20', TRUE),
(12, 'EMP-012', 'Pavel', 'Popov', 'Viktorovich', 'p.popov.duplicate@company.ru', '+79020022334', 1, 3, '2022-01-10', TRUE),
(13, 'EMP-013', 'Viktoria', 'Smirnova', 'Alexandrovna', 'v.smirnova@company.ru', '+79012233445', 3, 1, '2020-08-25', TRUE),
(14, 'EMP-014', 'Artem', 'Fedorov', 'Sergeevich', 'a.fedorov@company.ru', '+79013344556', 3, 2, '2021-03-10', TRUE),
(15, 'EMP-015', 'Irina', 'Belova', 'Nikolaevna', 'i.belova@company.ru', '+79014455667', 5, 1, '2019-10-05', TRUE),
(16, 'EMP-016', 'Maxim', 'Orlov', 'Dmitrievich', 'm.orlov@company.ru', '+79015566778', 4, 1, '2020-01-15', TRUE),
(17, 'EMP-017', 'Svetlana', 'Krylova', 'Vladimirovna', 's.krylova@company.ru', '+79016677889', 8, 1, '2018-05-20', TRUE),
(18, 'EMP-018', 'Nikolay', 'Zhukov', 'Ivanovich', 'n.zhukov@company.ru', '+79017788990', 15, 1, '2019-07-12', TRUE);

-- Обновление store_manager_id в таблице stores
UPDATE stores SET store_manager_id = 1 WHERE store_id = 1;
UPDATE stores SET store_manager_id = 2 WHERE store_id = 2;
UPDATE stores SET store_manager_id = 3 WHERE store_id = 3;
UPDATE stores SET store_manager_id = 4 WHERE store_id = 4;

-- Вставка стандартов соответствия
INSERT INTO compliance_standards (standard_id, standard_code, standard_name, description, requirement_text, effective_date, is_active) VALUES
(1, 'STD-001', 'Educational Requirements', 'Minimum educational requirements for positions', 'Vocational or higher education required for management positions', '2023-01-01', TRUE),
(2, 'STD-002', 'Experience Requirements', 'Minimum work experience for positions', 'Minimum 2 years experience in similar position for senior roles', '2023-01-01', TRUE),
(3, 'STD-003', 'Software Skills', 'Computer skills requirements', 'Proficiency in PC, office software, 1C accounting system', '2023-01-01', TRUE),
(4, 'STD-004', 'Communication Skills', 'Communication skills requirements', 'Business communication skills, customer service, conflict resolution', '2023-01-01', TRUE),
(5, 'STD-005', 'Product Knowledge', 'Product knowledge requirements', 'Knowledge of assortment, product characteristics, storage rules', '2023-01-01', TRUE),
(6, 'STD-006', 'Safety Standards', 'Workplace safety requirements', 'Knowledge and compliance with safety regulations, fire safety', '2023-01-01', TRUE),
(7, 'STD-007', 'Qualification Requirements', 'Professional competencies', 'Professional certifications required for specific positions', '2023-01-01', TRUE),
(8, 'STD-008', 'Appearance Standards', 'Dress code and appearance standards', 'Compliance with company dress code, neat appearance', '2023-01-01', TRUE),
(9, 'STD-009', 'Legal Knowledge', 'Legal competencies', 'Knowledge of labor legislation for managers', '2023-01-01', TRUE),
(10, 'STD-010', 'Leadership Competencies', 'Management skills requirements', 'Team leadership skills, planning, motivation', '2023-01-01', TRUE);

-- Вставка должностных инструкций
INSERT INTO job_descriptions (description_id, position_id, version, effective_date, responsibilities, qualifications, skills_required, performance_criteria, is_compliant, compliance_check_date, compliance_notes, created_by) VALUES
(1, 1, '2.0', '2023-06-01', 'Customer consultation on assortment; product demonstration; sales processing; maintaining order in sales floor; participating in inventory', 'Vocational education; retail experience from 1 year', 'Communication skills; product knowledge; sales skills; cash register operation', 'Sales targets; service quality; no complaints; product knowledge', TRUE, '2023-12-15', 'Full compliance with standards STD-001, STD-004, STD-005', 5),
(2, 2, '2.0', '2023-06-01', 'Leading sales team; service quality control; training new employees; conflict resolution; sales reporting', 'Vocational education; sales experience from 2 years', 'Leadership skills; training abilities; analytical skills; service standards knowledge', 'Department sales targets; team evaluation; staff turnover; department NPS', TRUE, '2023-12-15', 'Full compliance with standards STD-001, STD-002, STD-010', 5),
(3, 3, '2.0', '2023-06-01', 'Customer checkout; payment processing; receipt printing; price tag verification; cash collection participation', 'Secondary education; cashier experience from 6 months', 'Attention to detail; work speed; cash discipline knowledge; honesty', 'Checkout productivity; no errors; courtesy; no shortages', TRUE, '2023-12-15', 'Full compliance with standards STD-003, STD-006', 5),
(4, 4, '2.0', '2023-06-01', 'Maintaining order in sales floor; conflict resolution; staff coordination; standards compliance control', 'Vocational education; retail experience from 3 years', 'Management skills; stress resistance; communication skills; standards knowledge', 'Floor order; no conflicts; staff evaluation; standards compliance', TRUE, '2023-12-15', 'Full compliance with standards STD-004, STD-008', 5),
(5, 5, '2.1', '2023-09-01', 'Goods receiving from suppliers; quality and quantity control; documentation; stock accounting; inventory', 'Vocational education; merchandiser experience from 1 year', 'Attention to detail; 1C knowledge; analytical skills; storage standards', 'Receiving accuracy; documentation timeliness; no mix-ups', TRUE, '2023-12-15', 'Full compliance with standards STD-003, STD-005', 6),
(6, 6, '1.5', '2023-03-01', 'Warehouse management; goods placement organization; storage conditions control; storekeeper supervision; reporting', 'Vocational education; warehouse experience from 2 years', 'Organizational skills; warehouse logistics knowledge; personnel management', 'Warehouse order; goods safety; warehouse efficiency', TRUE, '2023-12-15', 'Full compliance with standards STD-006, STD-010', 6),
(7, 7, '3.0', '2023-07-01', 'Personnel recruitment; hiring and termination processing; HR records management; training organization; labor discipline control', 'Higher education (HR management); HR experience from 2 years', 'Recruitment skills; Labor Code knowledge; communication skills; documentation', 'Timely hiring; staff turnover; compliance with processing deadlines', TRUE, '2023-12-15', 'Full compliance with standards STD-001, STD-009', 7),
(8, 8, '2.0', '2023-06-01', 'Store accounting; payroll calculation; tax reporting; cash discipline control', 'Higher economic education; accountant experience from 3 years', 'Accounting knowledge; 1C Accounting; attention to detail; analytics', 'Reporting timeliness; no fines; calculation accuracy', TRUE, '2023-12-15', 'Full compliance with standards STD-001, STD-003', 7),
(9, 9, '2.5', '2023-08-01', 'Full store management; achieving targets; personnel management; reporting; interaction with central office', 'Higher education; retail management experience from 5 years', 'Leadership skills; strategic thinking; analytics; communication', 'Sales plan fulfillment; profitability; turnover; store NPS', TRUE, '2023-12-15', 'Full compliance with all standards', 7),
(10, 10, '2.0', '2023-06-01', 'Deputizing director; department supervision; resolving operational issues; planning participation; execution control', 'Higher education; retail experience from 3 years', 'Management skills; initiative; responsibility; communication', 'Task execution; assigned area performance; director evaluation', TRUE, '2023-12-15', 'Full compliance with standards STD-002, STD-010', 7),
(11, 11, '1.8', '2023-05-01', 'Developing marketing activities; conducting promotional campaigns; effectiveness analysis; social media management; window display', 'Higher education (marketing); experience from 1 year', 'Creativity; analytical skills; SMM knowledge; design skills', 'Traffic growth; campaign effectiveness; social media reach; promotional sales', FALSE, '2023-12-15', 'Need to add qualification requirements section according to STD-001', 7),
(12, 12, '1.5', '2023-04-01', 'Receiving and processing claims; resolving customer conflicts; product quality control; return reporting', 'Vocational education; service experience from 1 year', 'Stress resistance; diplomacy; Consumer Protection Law knowledge; communication', 'Processed claims count; customer satisfaction; processing time', TRUE, '2023-12-15', 'Full compliance with standards STD-004, STD-009', 6),
(13, 13, '2.0', '2023-06-01', 'Receiving goods at warehouse; storage placement; order picking for sales floor; maintaining warehouse order', 'Secondary education; warehouse experience preferred', 'Physical endurance; attention to detail; responsibility; neatness', 'Work speed; picking accuracy; workplace order', TRUE, '2023-12-15', 'Full compliance with standards STD-006', 6),
(14, 14, '1.2', '2023-02-01', 'Loading and unloading operations; goods movement; inventory participation; warehouse cleanliness maintenance', 'Secondary education; no experience required', 'Physical endurance; responsibility; neatness; discipline', 'Work volume completed; no goods damage; discipline', TRUE, '2023-12-15', 'Full compliance with standards STD-006', 6),
(15, 15, '2.0', '2023-06-01', 'Store security; entrance/exit control; theft prevention; emergency response; visitor log maintenance', 'Secondary education; security license; experience from 1 year', 'Observation skills; stress resistance; security rules knowledge; responsibility', 'No thefts; assigned area order; timely response', TRUE, '2023-12-15', 'Full compliance with standards STD-006, STD-007', 7);

-- Вставка конфигураций SLA
INSERT INTO sla_configurations (sla_id, request_type_id, size_category, min_employees, max_employees, target_response_hours, target_completion_hours, escalation_hours, penalty_rate, is_active, created_by) VALUES
(1, 1, 'small', 1, 2, 24, 72, 48, 0.50, TRUE, 8),
(2, 1, 'medium', 3, 5, 48, 120, 48, 0.75, TRUE, 8),
(3, 1, 'large', 6, 15, 72, 168, 48, 1.00, TRUE, 8),
(4, 2, 'small', 1, 2, 12, 48, 48, 0.75, TRUE, 8),
(5, 2, 'medium', 3, 5, 24, 72, 48, 1.00, TRUE, 8),
(6, 3, 'small', 1, 2, 8, 36, 48, 1.00, TRUE, 8),
(7, 3, 'medium', 3, 5, 16, 48, 48, 1.25, TRUE, 8),
(8, 4, 'small', 1, 3, 24, 72, 48, 0.50, TRUE, 9),
(9, 4, 'medium', 4, 8, 48, 96, 48, 0.75, TRUE, 9),
(10, 4, 'large', 9, 20, 72, 144, 48, 1.00, TRUE, 9),
(11, 7, 'small', 1, 2, 4, 24, 48, 1.50, TRUE, 8),
(12, 7, 'medium', 3, 5, 8, 36, 48, 1.75, TRUE, 8),
(13, 8, 'small', 1, 2, 72, 240, 48, 0.25, TRUE, 9),
(14, 8, 'medium', 3, 5, 96, 336, 48, 0.50, TRUE, 9),
(15, 8, 'large', 6, 10, 120, 480, 48, 0.75, TRUE, 9);

-- Вставка шаблонов ответов (Response Presets)
INSERT INTO response_presets (preset_id, preset_code, preset_name, request_type_id, priority_level, deadline_hours, auto_message, recommended_action, escalation_contact_id, is_active) VALUES
(1, 'RP-001', 'Urgent Replacement - Standard', 7, 1, 24, 'Your urgent replacement request has been accepted. Expect executor assignment within 4 hours.', 'Immediately check available employee database; contact candidate; confirm shift', 5, TRUE),
(2, 'RP-002', 'Urgent Replacement - High Priority', 7, 1, 12, 'Request forwarded to senior HR specialist. We understand the urgency.', 'Contact regional manager; consider transfer options from other stores', 6, TRUE),
(3, 'RP-003', 'Temporary Replacement - Standard', 3, 2, 48, 'Temporary replacement request accepted. Candidate search has started.', 'Check vacation schedule; find employee for additional shifts; agree on schedule', 5, TRUE),
(4, 'RP-004', 'Employee Replacement - Standard', 2, 2, 72, 'Your employee replacement request has been accepted. Candidate search has begun.', 'Post vacancy; conduct initial screening; schedule interviews', 7, TRUE),
(5, 'RP-005', 'New Employee Hiring - Small', 1, 3, 96, 'New employee hiring request accepted. Completion time - up to 5 business days.', 'Analyze resumes on portals; organize interviews', 5, TRUE),
(6, 'RP-006', 'New Employee Hiring - Medium', 1, 3, 120, 'Multiple employee hiring request accepted. Mass recruitment has started.', 'Launch vacancy ads; conduct job fair; mass selection', 6, TRUE),
(7, 'RP-007', 'New Employee Hiring - Large', 1, 4, 168, 'Large-scale recruitment request forwarded for priority processing.', 'Coordination with regional HR; engage recruitment agencies', 7, TRUE),
(8, 'RP-008', 'Additional Staff - Seasonal', 4, 3, 96, 'Additional staff request accepted. Seasonal worker search has started.', 'Activate seasonal worker database; post on social media; work with universities', 5, TRUE),
(9, 'RP-009', 'Employee Transfer', 5, 4, 168, 'Employee transfer request accepted. Coordination with both stores required.', 'Contact directors of both stores; agree on transfer conditions', 6, TRUE),
(10, 'RP-010', 'Staff Expansion - Standard', 8, 4, 240, 'Staff expansion request accepted for review. Justification required.', 'Prepare workload analytics; coordinate with finance department', 8, TRUE),
(11, 'RP-011', 'Skills Development', 6, 4, 336, 'Training request accepted. Selecting optimal program.', 'Analyze training needs; select provider; coordinate budget', 7, TRUE),
(12, 'RP-012', 'Schedule Change', 10, 3, 72, 'Schedule change request accepted. Reviewing possibilities.', 'Analyze current schedules; coordinate with employees; approve changes', 5, TRUE),
(13, 'RP-013', 'Staff Reduction', 9, 5, 336, 'Reduction request accepted. Careful procedure compliance required.', 'Consult with legal department; prepare notifications; meet deadlines', 8, TRUE),
(14, 'RP-014', 'Temporary Replacement - Urgent', 3, 1, 24, 'Urgent temporary replacement request. Working in priority mode.', 'Emergency employee call; check availability for shift', 6, TRUE),
(15, 'RP-015', 'Additional Staff - Urgent', 4, 2, 48, 'Urgent additional staff request accepted.', 'Mobilize internal resources; engage quick-hire agencies', 7, TRUE);

-- Вставка запросов на персонал (Staffing Requests)
INSERT INTO staffing_requests (request_id, request_number, store_id, requester_id, request_type_id, position_id, quantity, size_category, urgency_reason, description, required_skills, preferred_start_date, status, assigned_to, assigned_at, sla_deadline, created_at) VALUES
(1, 'REQ-2026-001', 1, 1, 1, 1, 2, 'small', 'Electronics department expansion', 'Two sales consultants needed for electronics department due to assortment expansion', 'Knowledge of home appliances and electronics; sales experience from 1 year', '2026-02-01', 'completed', 5, '2026-01-15 10:30:00', '2026-01-22 10:30:00', '2026-01-10 10:30:00'),
(2, 'REQ-2026-002', 2, 2, 2, 3, 1, 'small', 'Employee resignation', 'Cashier replacement due to voluntary resignation', 'Cashier experience; attention to detail; responsibility', '2026-02-15', 'closed', 6, '2026-01-20 09:00:00', '2026-01-24 09:00:00', '2026-01-18 09:00:00'),
(3, 'REQ-2026-003', 3, 3, 7, 1, 1, 'small', 'Employee illness', 'Urgent replacement of salesperson during sick leave', 'Ready to start within days', '2026-01-22', 'completed', 5, '2026-01-21 16:00:00', '2026-01-22 16:00:00', '2026-01-21 14:30:00'),
(4, 'REQ-2026-004', 1, 1, 4, 13, 3, 'medium', 'Inventory preparation', 'Additional staff for annual inventory preparation', 'Physical endurance; attention to detail', '2026-02-10', 'completed', 6, '2026-01-28 11:00:00', '2026-02-05 11:00:00', '2026-01-25 11:00:00'),
(5, 'REQ-2026-005', 4, 4, 1, 2, 1, 'small', 'New department opening', 'Senior salesperson needed for new cosmetics department', 'Cosmetics experience; management skills', '2026-03-01', 'executor_assigned', 7, '2026-02-01 10:00:00', '2026-02-15 10:00:00', '2026-01-30 10:00:00'),
(6, 'REQ-2026-006', 5, 1, 3, 3, 2, 'small', 'Vacation period', 'Temporary replacement of two cashiers during vacation period', 'Cashier experience; flexible schedule', '2026-02-20', 'in_progress', 5, '2026-02-03 14:00:00', '2026-02-07 14:00:00', '2026-02-01 14:00:00'),
(7, 'REQ-2026-007', 6, 3, 8, 1, 5, 'medium', 'Second floor opening', 'Staff expansion due to second floor opening', 'Retail experience; willingness to learn', '2026-04-01', 'under_review', NULL, NULL, '2026-03-15 10:00:00', '2026-02-05 09:00:00'),
(8, 'REQ-2026-008', 2, 2, 5, 4, 1, 'small', 'Transfer from another store', 'Administrator transfer from store MOW-001', 'Employee consent; administrator experience', '2026-03-01', 'completed', 6, '2026-02-08 12:00:00', '2026-02-15 12:00:00', '2026-02-05 12:00:00'),
(9, 'REQ-2026-009', 7, 4, 6, 1, 3, 'medium', 'New employee training', 'Request for onboarding program for new salespersons', 'Training skills; standards knowledge', '2026-03-15', 'completed', 7, '2026-02-12 10:00:00', '2026-02-26 10:00:00', '2026-02-10 10:00:00'),
(10, 'REQ-2026-010', 8, 1, 7, 14, 2, 'medium', 'Urgent need', 'Urgent hiring of loaders due to increased deliveries', 'Physical endurance; responsibility', '2026-02-15', 'completed', 5, '2026-02-14 08:00:00', '2026-02-15 20:00:00', '2026-02-14 06:00:00'),
(11, 'REQ-2026-011', 3, 3, 2, 5, 1, 'small', 'Maternity leave replacement', 'Merchandiser replacement during maternity leave', 'Merchandiser experience; 1C knowledge', '2026-03-01', 'in_progress', 6, '2026-02-18 11:00:00', '2026-02-22 11:00:00', '2026-02-15 11:00:00'),
(12, 'REQ-2026-012', 9, 2, 4, 1, 4, 'medium', 'Seasonal rush', 'Additional salespersons for spring season', 'Weekend availability; communication skills', '2026-03-01', 'new', NULL, NULL, '2026-02-28 10:00:00', '2026-02-18 10:00:00'),
(13, 'REQ-2026-013', 10, 4, 1, 6, 1, 'small', 'Volume growth', 'Warehouse manager needed due to increased turnover', 'Warehouse management experience; logistics knowledge', '2026-04-01', 'pending_approval', 7, '2026-02-20 14:00:00', '2026-02-27 14:00:00', '2026-02-19 14:00:00'),
(14, 'REQ-2026-014', 1, 1, 10, NULL, 0, 'small', 'Schedule optimization', 'Request to change work schedules for grocery department', 'Consent of all department employees', '2026-03-01', 'completed', 5, '2026-02-22 09:00:00', '2026-02-25 09:00:00', '2026-02-20 09:00:00'),
(15, 'REQ-2026-015', 11, 3, 3, 15, 1, 'small', 'Sick leave', 'Temporary replacement of security guard', 'Security guard license required', '2026-02-28', 'completed', 6, '2026-02-25 10:00:00', '2026-02-26 10:00:00', '2026-02-24 22:00:00'),
(16, 'REQ-2026-016', 4, 4, 9, 2, 1, 'small', 'Staff optimization', 'Reduction of one senior salesperson position', 'Compliance with reduction procedure', '2026-05-01', 'under_review', NULL, NULL, '2026-03-10 10:00:00', '2026-02-26 10:00:00'),
(17, 'REQ-2026-017', 12, 1, 7, 13, 2, 'medium', 'Emergency situation', 'Urgent replacement of storekeepers due to warehouse accident', 'Warehouse experience; night shift availability', '2026-02-28', 'completed', 5, '2026-02-27 07:00:00', '2026-02-28 07:00:00', '2026-02-27 05:30:00'),
(18, 'REQ-2026-018', 5, 2, 1, 11, 1, 'small', 'New project', 'Marketing specialist needed for loyalty program launch', 'Loyalty program experience; analytics', '2026-04-15', 'new', NULL, NULL, '2026-03-20 10:00:00', '2026-02-28 10:00:00');

-- Вставка истории запросов (Request History)
INSERT INTO request_history (history_id, request_id, store_id, requester_id, action_type, old_status, new_status, action_description, performed_by, action_timestamp, notes) VALUES
(1, 1, 1, 1, 'Request Created', NULL, 'new', 'Request created by store director', 1, '2026-01-10 10:30:00', 'Staff expansion request'),
(2, 1, 1, 1, 'Executor Assigned', 'new', 'executor_assigned', 'Request assigned to HR specialist Olga Morozova', 5, '2026-01-15 10:30:00', 'Responsible assigned'),
(3, 1, 1, 1, 'Completed', 'in_progress', 'completed', '2 candidates found and hired', 5, '2026-01-20 15:00:00', 'Request completed on time'),
(4, 2, 2, 2, 'Request Created', NULL, 'new', 'Cashier replacement request', 2, '2026-01-18 09:00:00', 'Urgent replacement'),
(5, 2, 2, 2, 'Executor Assigned', 'new', 'executor_assigned', 'Assigned to HR specialist Dmitry Volkov', 6, '2026-01-20 09:00:00', 'Executor assigned'),
(6, 2, 2, 2, 'Closed', 'completed', 'closed', 'Candidate started work', 8, '2026-01-25 14:00:00', 'Closed by director'),
(7, 3, 3, 3, 'Request Created', NULL, 'new', 'Urgent replacement due to illness', 3, '2026-01-21 14:30:00', 'Emergency request'),
(8, 3, 3, 3, 'Executor Assigned', 'new', 'executor_assigned', 'Urgent assignment', 5, '2026-01-21 16:00:00', 'Within 1.5 hours'),
(9, 4, 1, 1, 'Request Created', NULL, 'new', 'Additional staff request', 1, '2026-01-25 11:00:00', 'Inventory preparation'),
(10, 4, 1, 1, 'Executor Assigned', 'new', 'executor_assigned', 'Responsible assigned', 6, '2026-01-28 11:00:00', ''),
(11, 5, 4, 4, 'Request Created', NULL, 'new', 'Senior salesperson request', 4, '2026-01-30 10:00:00', 'New department'),
(12, 5, 4, 4, 'Accepted for Review', 'new', 'under_review', 'Request forwarded for review', 8, '2026-01-31 10:00:00', ''),
(13, 5, 4, 4, 'Executor Assigned', 'under_review', 'executor_assigned', 'HR specialist assigned', 7, '2026-02-01 10:00:00', ''),
(14, 6, 5, 1, 'Request Created', NULL, 'new', 'Temporary replacement during vacation period', 1, '2026-02-01 14:00:00', ''),
(15, 6, 5, 1, 'Work Started', 'executor_assigned', 'in_progress', 'Candidate search started', 5, '2026-02-03 14:00:00', ''),
(16, 10, 8, 1, 'Request Created', NULL, 'new', 'Urgent loader hiring', 1, '2026-02-14 06:00:00', 'Emergency situation'),
(17, 17, 12, 1, 'Request Created', NULL, 'new', 'Emergency replacement', 1, '2026-02-27 05:30:00', 'Night situation'),
(18, 17, 12, 1, 'Executor Assigned', 'new', 'executor_assigned', 'Emergency assignment', 5, '2026-02-27 07:00:00', 'Response within 1.5 hours'),
(19, 17, 12, 1, 'Completed', 'in_progress', 'completed', 'Employees found and started work', 5, '2026-02-28 06:00:00', 'Request completed'),
(20, 10, 8, 1, 'Executor Assigned', 'new', 'executor_assigned', 'Immediate assignment', 5, '2026-02-14 08:00:00', 'Response within 2 hours');

-- Вставка метрик обработки (Processing Metrics)
INSERT INTO processing_metrics (metric_id, request_id, store_id, request_type_id, size_category, created_at, assigned_at, completed_at, closed_at, response_time_hours, completion_time_hours, total_time_hours, sla_target_hours, is_sla_met, delay_hours, delay_reason) VALUES
(1, 1, 1, 1, 'small', '2026-01-10 10:30:00', '2026-01-15 10:30:00', '2026-01-20 15:00:00', '2026-01-21 10:00:00', 120.00, 242.50, 263.50, 72, TRUE, 0, NULL),
(2, 2, 2, 2, 'small', '2026-01-18 09:00:00', '2026-01-20 09:00:00', '2026-01-24 12:00:00', '2026-01-25 14:00:00', 48.00, 102.00, 149.00, 48, TRUE, 0, NULL),
(3, 3, 3, 7, 'small', '2026-01-21 14:30:00', '2026-01-21 16:00:00', '2026-01-22 08:00:00', '2026-01-22 10:00:00', 1.50, 16.00, 17.50, 24, TRUE, 0, NULL),
(4, 4, 1, 4, 'medium', '2026-01-25 11:00:00', '2026-01-28 11:00:00', '2026-02-05 16:00:00', '2026-02-06 10:00:00', 72.00, 261.00, 291.00, 96, TRUE, 0, NULL),
(5, 5, 4, 1, 'small', '2026-01-30 10:00:00', '2026-02-01 10:00:00', NULL, NULL, 48.00, NULL, NULL, 72, TRUE, 0, NULL),
(6, 6, 5, 3, 'small', '2026-02-01 14:00:00', '2026-02-03 14:00:00', NULL, NULL, 48.00, NULL, NULL, 36, FALSE, 12, 'Delayed executor assignment'),
(7, 7, 6, 8, 'medium', '2026-02-05 09:00:00', NULL, NULL, NULL, NULL, NULL, NULL, 336, TRUE, 0, NULL),
(8, 8, 2, 5, 'small', '2026-02-05 12:00:00', '2026-02-08 12:00:00', '2026-02-14 16:00:00', '2026-02-15 10:00:00', 72.00, 151.00, 239.00, 168, TRUE, 0, NULL),
(9, 9, 7, 6, 'medium', '2026-02-10 10:00:00', '2026-02-12 10:00:00', '2026-02-25 17:00:00', '2026-02-26 09:00:00', 48.00, 319.00, 383.00, 336, TRUE, 0, NULL),
(10, 10, 8, 7, 'medium', '2026-02-14 06:00:00', '2026-02-14 08:00:00', '2026-02-15 18:00:00', '2026-02-16 09:00:00', 2.00, 36.00, 51.00, 36, TRUE, 0, NULL),
(11, 11, 3, 2, 'small', '2026-02-15 11:00:00', '2026-02-18 11:00:00', NULL, NULL, 72.00, NULL, NULL, 48, FALSE, 24, 'Extended candidate search'),
(12, 14, 1, 10, 'small', '2026-02-20 09:00:00', '2026-02-22 09:00:00', '2026-02-24 17:00:00', '2026-02-25 10:00:00', 48.00, 77.00, 97.00, 72, TRUE, 0, NULL),
(13, 15, 11, 3, 'small', '2026-02-24 22:00:00', '2026-02-25 10:00:00', '2026-02-26 08:00:00', '2026-02-26 10:00:00', 12.00, 34.00, 36.00, 36, TRUE, 0, NULL),
(14, 17, 12, 7, 'medium', '2026-02-27 05:30:00', '2026-02-27 07:00:00', '2026-02-28 06:00:00', '2026-02-28 10:00:00', 1.50, 24.50, 28.50, 36, TRUE, 0, NULL),
(15, 18, 5, 1, 'small', '2026-02-28 10:00:00', NULL, NULL, NULL, NULL, NULL, NULL, 96, TRUE, 0, NULL);

-- Вставка автозадач для HR Specialist
INSERT INTO auto_generated_tasks (task_id, task_number, request_id, assigned_to, priority, deadline, task_type, description, checklist, status, compliance_check_passed, duplicate_check_passed, created_at) VALUES
(1, 'TASK-2026-001', 1, 5, 3, '2026-01-22 10:30:00', 'Recruitment', 'Hiring 2 sales consultants for Alexeevsky store', '["Post vacancy", "Screen resumes", "Schedule interviews", "Verify documents", "Process hiring"]', 'completed', TRUE, TRUE, '2026-01-15 10:30:00'),
(2, 'TASK-2026-002', 2, 6, 2, '2026-01-24 09:00:00', 'Employee Replacement', 'Cashier hiring to replace resigned employee', '["Post vacancy", "Candidate screening", "Interview", "Processing"]', 'completed', TRUE, TRUE, '2026-01-20 09:00:00'),
(3, 'TASK-2026-003', 3, 5, 1, '2026-01-22 16:00:00', 'Urgent Replacement', 'Urgent salesperson replacement for sick leave', '["Check available database", "Contact candidate", "Confirm shift"]', 'completed', TRUE, TRUE, '2026-01-21 16:00:00'),
(4, 'TASK-2026-004', 4, 6, 3, '2026-02-05 11:00:00', 'Temporary Staff Hiring', 'Hiring 3 storekeepers for inventory', '["Analyze needs", "Find candidates", "Processing"]', 'completed', TRUE, TRUE, '2026-01-28 11:00:00'),
(5, 'TASK-2026-005', 5, 7, 3, '2026-02-15 10:00:00', 'Recruitment', 'Senior salesperson hiring for cosmetics department', '["Post vacancy", "Resume screening", "Interviews"]', 'in_progress', TRUE, TRUE, '2026-02-01 10:00:00'),
(6, 'TASK-2026-006', 6, 5, 2, '2026-02-07 14:00:00', 'Temporary Replacement', 'Hiring 2 cashiers for vacation period', '["Check database", "Schedule coordination"]', 'in_progress', TRUE, TRUE, '2026-02-03 14:00:00'),
(7, 'TASK-2026-007', 7, 6, 4, '2026-03-15 10:00:00', 'Mass Recruitment', 'Hiring 5 salespersons for new floor', '["Market analysis", "Mass selection", "Training"]', 'new', NULL, NULL, '2026-02-05 09:00:00'),
(8, 'TASK-2026-008', 8, 6, 4, '2026-02-15 12:00:00', 'Employee Transfer', 'Coordinator for administrator transfer between stores', '["Coordinate with directors", "Process transfer"]', 'completed', TRUE, TRUE, '2026-02-08 12:00:00'),
(9, 'TASK-2026-009', 9, 7, 4, '2026-02-26 10:00:00', 'Training', 'Onboarding program for new salespersons', '["Prepare program", "Assign mentors"]', 'completed', TRUE, TRUE, '2026-02-12 10:00:00'),
(10, 'TASK-2026-010', 10, 5, 1, '2026-02-15 20:00:00', 'Urgent Recruitment', 'Urgent hiring of 2 loaders', '["Emergency calls", "Processing"]', 'completed', TRUE, TRUE, '2026-02-14 08:00:00'),
(11, 'TASK-2026-011', 11, 6, 2, '2026-02-22 11:00:00', 'Maternity Leave Replacement', 'Merchandiser hiring for maternity leave coverage', '["Find candidates", "Interviews"]', 'in_progress', TRUE, TRUE, '2026-02-18 11:00:00'),
(12, 'TASK-2026-012', 12, 5, 3, '2026-02-28 10:00:00', 'Seasonal Recruitment', 'Hiring 4 salespersons for spring season', '["Post vacancies", "Candidate screening"]', 'new', NULL, NULL, '2026-02-18 10:00:00'),
(13, 'TASK-2026-013', 13, 7, 3, '2026-02-27 14:00:00', 'Recruitment', 'Warehouse manager hiring', '["Analyze requirements", "Find candidates"]', 'in_progress', TRUE, TRUE, '2026-02-20 14:00:00'),
(14, 'TASK-2026-014', 15, 6, 2, '2026-02-26 10:00:00', 'Temporary Replacement', 'Security guard replacement for sick leave', '["Find licensed guard", "Processing"]', 'completed', TRUE, TRUE, '2026-02-25 10:00:00'),
(15, 'TASK-2026-015', 17, 5, 1, '2026-02-28 07:00:00', 'Emergency Replacement', 'Urgent replacement of 2 storekeepers', '["Emergency search", "Start work"]', 'completed', TRUE, TRUE, '2026-02-27 07:00:00');

-- Вставка уведомлений
INSERT INTO notifications (notification_id, recipient_id, notification_type, title, message, related_request_id, is_read, sent_at, priority) VALUES
(1, 8, 'Assignment Delay', 'Executor assignment time exceeded', 'Request REQ-2026-006 has been without executor assignment for over 48 hours. Intervention required.', 6, FALSE, '2026-02-05 14:00:00', 1),
(2, 8, 'SLA Violation', 'Target SLA time exceeded', 'Request REQ-2026-011 has exceeded target response time. Take action.', 11, FALSE, '2026-02-20 11:00:00', 2),
(3, 1, 'Request Status', 'Request completed', 'Your request REQ-2026-001 has been successfully completed. 2 employees hired.', 1, TRUE, '2026-01-20 15:00:00', 3),
(4, 2, 'Request Status', 'Request closed', 'Request REQ-2026-002 is closed. Candidate started work.', 2, TRUE, '2026-01-25 14:00:00', 3),
(5, 3, 'Request Status', 'Executor assigned', 'Your request REQ-2026-003 has an assigned executor. Expect results.', 3, TRUE, '2026-01-21 16:00:00', 2),
(6, 5, 'New Task', 'New task assigned', 'Task TASK-2026-005 assigned to you. Deadline: Feb 15, 2026', 5, TRUE, '2026-02-01 10:00:00', 3),
(7, 6, 'New Task', 'New task assigned', 'Task TASK-2026-006 assigned to you. Deadline: Feb 07, 2026', 6, TRUE, '2026-02-03 14:00:00', 2),
(8, 7, 'New Task', 'New task assigned', 'Task TASK-2026-007 assigned to you. Large recruitment request.', 7, TRUE, '2026-02-05 09:00:00', 4),
(9, 8, 'Information', 'Approval required', 'Request REQ-2026-007 requires approval for staff expansion.', 7, FALSE, '2026-02-06 10:00:00', 3),
(10, 1, 'Request Status', 'Request in progress', 'Your request REQ-2026-004: staff recruitment has started.', 4, TRUE, '2026-01-28 11:00:00', 3),
(11, 4, 'Request Status', 'Executor assigned', 'Request REQ-2026-005 has an assigned HR specialist. Recruitment started.', 5, TRUE, '2026-02-01 10:00:00', 3),
(12, 5, 'Reminder', 'Deadline approaching', 'Task TASK-2026-005 deadline expires in 3 days.', 5, FALSE, '2026-02-12 10:00:00', 2),
(13, 8, 'Report', 'Weekly report ready', 'Weekly request processing metrics report is available for review.', NULL, FALSE, '2026-02-19 09:00:00', 4),
(14, 1, 'Urgent', 'Emergency request', 'Urgent request REQ-2026-017 created. Immediate response required.', 17, TRUE, '2026-02-27 05:30:00', 1),
(15, 8, 'Information', 'New reduction request', 'Request REQ-2026-016 for staff reduction requires review.', 16, FALSE, '2026-02-26 11:00:00', 3);

-- Вставка журнала статусов
INSERT INTO request_status_log (log_id, request_id, status, changed_by, changed_at, comment) VALUES
(1, 1, 'new', 1, '2026-01-10 10:30:00', 'Request created'),
(2, 1, 'executor_assigned', 5, '2026-01-15 10:30:00', 'HR specialist assigned as responsible'),
(3, 1, 'in_progress', 5, '2026-01-16 09:00:00', 'Candidate search started'),
(4, 1, 'completed', 5, '2026-01-20 15:00:00', 'Candidates found and hired'),
(5, 2, 'new', 2, '2026-01-18 09:00:00', 'Request created'),
(6, 2, 'executor_assigned', 6, '2026-01-20 09:00:00', 'HR specialist assigned'),
(7, 2, 'completed', 6, '2026-01-24 12:00:00', 'Candidate found and started work'),
(8, 2, 'closed', 8, '2026-01-25 14:00:00', 'Request closed by central office manager'),
(9, 3, 'new', 3, '2026-01-21 14:30:00', 'Urgent request created'),
(10, 3, 'executor_assigned', 5, '2026-01-21 16:00:00', 'Emergency assignment'),
(11, 3, 'completed', 5, '2026-01-22 08:00:00', 'Replacement found in shortest time'),
(12, 5, 'new', 4, '2026-01-30 10:00:00', 'Request created'),
(13, 5, 'under_review', 8, '2026-01-31 10:00:00', 'Forwarded for review'),
(14, 5, 'executor_assigned', 7, '2026-02-01 10:00:00', 'Responsible assigned'),
(15, 6, 'new', 1, '2026-02-01 14:00:00', 'Request created'),
(16, 6, 'executor_assigned', 5, '2026-02-03 14:00:00', 'Assigned as executor'),
(17, 6, 'in_progress', 5, '2026-02-04 09:00:00', 'Temporary employee search started'),
(18, 17, 'completed', 5, '2026-02-28 06:00:00', 'Emergency situation resolved');

-- Вставка элементов меню UI
INSERT INTO ui_menu_items (menu_id, parent_id, menu_code, menu_name, menu_path, icon_class, display_order, role_required, is_active) VALUES
(1, NULL, 'MENU_DASHBOARD', 'Dashboard', '/dashboard', 'fa-home', 1, 'all', TRUE),
(2, NULL, 'MENU_REQUESTS', 'Requests', '/requests', 'fa-file-alt', 2, 'all', TRUE),
(3, NULL, 'MENU_HISTORY', 'Request History', '/history', 'fa-history', 3, 'store_manager', TRUE),
(4, NULL, 'MENU_NEW_REQUEST', 'Create Request', '/requests/new', 'fa-plus-circle', 4, 'store_manager', TRUE),
(5, NULL, 'MENU_METRICS', 'Metrics', '/metrics', 'fa-chart-bar', 5, 'central_office_manager', TRUE),
(6, NULL, 'MENU_SLA', 'SLA Settings', '/sla', 'fa-cog', 6, 'central_office_manager', TRUE),
(7, NULL, 'MENU_ANALYTICS', 'Analytics', '/analytics', 'fa-chart-line', 7, 'central_office_manager', TRUE),
(8, NULL, 'MENU_TASKS', 'My Tasks', '/tasks', 'fa-tasks', 8, 'hr_specialist', TRUE),
(9, NULL, 'MENU_EMPLOYEES', 'Employees', '/employees', 'fa-users', 9, 'hr_specialist', TRUE),
(10, NULL, 'MENU_JOB_DESC', 'Job Descriptions', '/job-descriptions', 'fa-book', 10, 'hr_specialist', TRUE),
(11, NULL, 'MENU_PRESETS', 'Response Presets', '/presets', 'fa-copy', 11, 'hr_specialist', TRUE),
(12, NULL, 'MENU_NOTIFICATIONS', 'Notifications', '/notifications', 'fa-bell', 12, 'all', TRUE),
(13, NULL, 'MENU_REPORTS', 'Reports', '/reports', 'fa-file-pdf', 13, 'central_office_manager', TRUE),
(14, NULL, 'MENU_SETTINGS', 'Settings', '/settings', 'fa-wrench', 14, 'all', TRUE),
(15, NULL, 'MENU_HELP', 'Help', '/help', 'fa-question-circle', 15, 'all', TRUE);

-- Вставка системных настроек
INSERT INTO system_settings (setting_id, setting_key, setting_value, setting_type, description, updated_by) VALUES
(1, 'DEFAULT_SLA_RESPONSE_HOURS', '48', 'integer', 'Стандартное время реакции SLA в часах', 8),
(2, 'MAX_HISTORY_MONTHS', '6', 'integer', 'Период хранения истории запросов (месяцы)', 8),
(3, 'NOTIFICATION_DELAY_THRESHOLD', '48', 'integer', 'Порог задержки для уведомлений (часы)', 8),
(4, 'AUTO_ASSIGN_ENABLED', 'true', 'boolean', 'Автоматическое назначение исполнителей', 8),
(5, 'ESCALATION_ENABLED', 'true', 'boolean', 'Автоматическая эскалация при задержках', 8),
(6, 'DUPLICATE_CHECK_ENABLED', 'true', 'boolean', 'Автоматическая проверка дублей сотрудников', 7),
(7, 'COMPLIANCE_CHECK_ENABLED', 'true', 'boolean', 'Автоматическая проверка соответствия должностных инструкций', 7),
(8, 'MAX_REQUESTS_PER_DAY', '50', 'integer', 'Максимальное количество запросов в день на магазин', 8),
(9, 'REPORT_GENERATION_HOUR', '09:00', 'time', 'Время автоматической генерации отчётов', 8),
(10, 'BACKUP_INTERVAL_HOURS', '24', 'integer', 'Интервал резервного копирования (часы)', 8),
(11, 'SESSION_TIMEOUT_MINUTES', '30', 'integer', 'Таймаут сессии пользователя (минуты)', 8),
(12, 'PASSWORD_MIN_LENGTH', '8', 'integer', 'Минимальная длина пароля', 8),
(13, 'LANGUAGE_DEFAULT', 'en', 'string', 'Язык интерфейса по умолчанию', 8),
(14, 'TIMEZONE_DEFAULT', 'Europe/Moscow', 'string', 'Часовой пояс по умолчанию', 8),
(15, 'CURRENCY_DEFAULT', 'RUB', 'string', 'Валюта по умолчанию', 8);

-- ============================================================
-- ВОССТАНОВЛЕНИЕ ПРОВЕРКИ ВНЕШНИХ КЛЮЧЕЙ
-- ============================================================

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- КОММЕНТАРИИ К ТАБЛИЦАМ
-- ============================================================

ALTER TABLE stores COMMENT 'Справочник магазинов';
ALTER TABLE positions COMMENT 'Справочник должностей';
ALTER TABLE employees COMMENT 'База данных сотрудников (Data Object из BPMN)';
ALTER TABLE job_descriptions COMMENT 'База должностных инструкций (Data Object из BPMN)';
ALTER TABLE request_history COMMENT 'История запросов для Store Manager (Data Object из BPMN)';
ALTER TABLE processing_metrics COMMENT 'Метрики обработки для Central Office Manager (Data Object из BPMN)';
ALTER TABLE staffing_requests COMMENT 'Запросы на персонал';
ALTER TABLE response_presets COMMENT 'Шаблоны ответов HR-специалиста (для развилки Assign Executor)';
ALTER TABLE sla_configurations COMMENT 'Конфигурации SLA по размеру запроса';
ALTER TABLE auto_generated_tasks COMMENT 'Автозадачи для HR-специалиста';
ALTER TABLE notifications COMMENT 'Уведомления о задержках и событиях';
ALTER TABLE compliance_standards COMMENT 'Стандарты соответствия компании';

-- ============================================================
-- ФИНАЛЬНЫЙ ЗАПРОС ДЛЯ ПРОВЕРКИ СВЯЗЕЙ
-- ============================================================

SELECT 
    'Stores -> Employees (manager)' AS relationship,
    COUNT(*) AS connections 
FROM stores s 
JOIN employees e ON s.store_manager_id = e.employee_id
UNION ALL
SELECT 
    'Employees -> Positions',
    COUNT(*) 
FROM employees e 
JOIN positions p ON e.position_id = p.position_id
UNION ALL
SELECT 
    'Employees -> Stores',
    COUNT(*) 
FROM employees e 
JOIN stores s ON e.store_id = s.store_id
UNION ALL
SELECT 
    'Staffing Requests -> Stores',
    COUNT(*) 
FROM staffing_requests sr 
JOIN stores s ON sr.store_id = s.store_id
UNION ALL
SELECT 
    'Staffing Requests -> Employees (requester)',
    COUNT(*) 
FROM staffing_requests sr 
JOIN employees e ON sr.requester_id = e.employee_id
UNION ALL
SELECT 
    'Request History -> Staffing Requests',
    COUNT(*) 
FROM request_history rh 
JOIN staffing_requests sr ON rh.request_id = sr.request_id
UNION ALL
SELECT 
    'Processing Metrics -> Staffing Requests',
    COUNT(*) 
FROM processing_metrics pm 
JOIN staffing_requests sr ON pm.request_id = sr.request_id
UNION ALL
SELECT 
    'Auto Tasks -> Staffing Requests',
    COUNT(*) 
FROM auto_generated_tasks at2 
JOIN staffing_requests sr ON at2.request_id = sr.request_id
UNION ALL
SELECT 
    'Response Presets -> Request Types',
    COUNT(*) 
FROM response_presets rp 
JOIN request_types rt ON rp.request_type_id = rt.type_id;