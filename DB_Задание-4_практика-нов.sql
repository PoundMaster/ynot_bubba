-- ============================================================
-- БАЗА ДАННЫХ ДЛЯ ПРОЦЕССА ВЗАИМОДЕЙСТВИЯ СОТРУДНИКОВ
-- Сделано по BPMN, соответственно и по всем пользовательским историям
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
-- ОСНОВНЫЕ ТАБЛИЦЫ ДАННЫХ (DATA OBJECTS ИЗ BPMN)
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
    size_category VARCHAR(20) NOT NULL CHECK (size_category IN ('малый', 'средний', 'крупный')),
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
    status VARCHAR(30) NOT NULL DEFAULT 'новый' CHECK (status IN (
        'новый', 'на_рассмотрении', 'назначен_исполнитель', 'в_работе', 'на_согласовании', 'выполнен', 'закрыт', 'отклонён'
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
-- Для Central Office Manager - метрики времени обработки
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
    status VARCHAR(30) NOT NULL DEFAULT 'новая' CHECK (status IN ('новая', 'принята', 'в_работе', 'выполнена', 'отменена')),
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
        WHEN agt.deadline < CURRENT_TIMESTAMP THEN 'просрочено'
        WHEN agt.deadline < CURRENT_TIMESTAMP + INTERVAL '24 hours' THEN 'срочно'
        ELSE 'в_сроке'
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

-- Представление: Метрики для Central Office Manager
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
        WHEN pm.is_sla_met THEN 'Соответствует SLA'
        ELSE 'Нарушение SLA'
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
    COUNT(CASE WHEN sr.status = 'выполнен' THEN 1 END) AS completed_requests,
    COUNT(CASE WHEN sr.status = 'отклонён' THEN 1 END) AS rejected_requests,
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
        WHEN e1.email = e2.email THEN 'Полное совпадение email'
        WHEN e1.first_name = e2.first_name AND e1.last_name = e2.last_name 
             AND e1.phone = e2.phone THEN 'Совпадение ФИО и телефона'
        WHEN e1.first_name = e2.first_name AND e1.last_name = e2.last_name 
             AND e1.phone IS NOT NULL AND e2.phone IS NOT NULL 
             AND LENGTH(e1.phone) >= 7 AND LENGTH(e2.phone) >= 7
             AND RIGHT(e1.phone, 7) = RIGHT(e2.phone, 7) THEN 'Совпадение ФИО и последних 7 цифр телефона'
        ELSE 'Возможный дубль'
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
-- ЗАПОЛНЕНИЕ ТАБЛИЦ ДАННЫМИ (НА РУССКОМ ЯЗЫКЕ)
-- ============================================================

-- Вставка магазинов (15 записей)
INSERT INTO stores (store_code, store_name, address, region, opening_date, is_active) VALUES
('MOW-001', 'Магазин "Алексеевский"', 'г. Москва, ул. Алексеевская, д. 15', 'Москва', '2019-03-15', TRUE),
('MOW-002', 'Магазин "Арбатский"', 'г. Москва, Арбат, д. 22', 'Москва', '2020-06-01', TRUE),
('SPB-001', 'Магазин "Невский"', 'г. Санкт-Петербург, Невский пр., д. 45', 'Санкт-Петербург', '2018-09-10', TRUE),
('SPB-002', 'Магазин "Петроградский"', 'г. Санкт-Петербург, Петроградская наб., д. 18', 'Санкт-Петербург', '2021-02-20', TRUE),
('EKB-001', 'Магазин "Уральский"', 'г. Екатеринбург, ул. Ленина, д. 32', 'Свердловская область', '2019-11-05', TRUE),
('NSK-001', 'Магазин "Сибирский"', 'г. Новосибирск, ул. Красный проспект, д. 50', 'Новосибирская область', '2020-04-12', TRUE),
('KZN-001', 'Магазин "Казанский"', 'г. Казань, ул. Баумана, д. 28', 'Республика Татарстан', '2018-07-22', TRUE),
('NNV-001', 'Магазин "Нижегородский"', 'г. Нижний Новгород, ул. Большая Покровская, д. 35', 'Нижегородская область', '2021-05-30', TRUE),
('SAM-001', 'Магазин "Самарский"', 'г. Самара, ул. Куйбышева, д. 120', 'Самарская область', '2019-08-14', TRUE),
('RND-001', 'Магазин "Ростовский"', 'г. Ростов-на-Дону, пр. Будённовский, д. 65', 'Ростовская область', '2020-10-08', TRUE),
('UFA-001', 'Магазин "Башкирский"', 'г. Уфа, пр. Октября, д. 45', 'Республика Башкортостан', '2022-01-15', TRUE),
('KRS-001', 'Магазин "Красноярский"', 'г. Красноярск, ул. Карла Маркса, д. 78', 'Красноярский край', '2019-12-03', TRUE),
('VRN-001', 'Магазин "Воронежский"', 'г. Воронеж, пр. Революции, д. 25', 'Воронежская область', '2021-07-19', TRUE),
('PER-001', 'Магазин "Пермский"', 'г. Пермь, ул. Петропавловская, д. 55', 'Пермский край', '2020-03-25', TRUE),
('VLG-001', 'Магазин "Волгоградский"', 'г. Волгоград, ул. Мира, д. 10', 'Волгоградская область', '2022-04-10', TRUE);

-- Вставка должностей (15 записей)
INSERT INTO positions (position_code, position_name, department, base_salary, description, is_active) VALUES
('POS-001', 'Продавец-консультант', 'Продажи', 45000.00, 'Консультирование покупателей, выкладка товара', TRUE),
('POS-002', 'Старший продавец', 'Продажи', 55000.00, 'Руководство группой продавцов, контроль качества обслуживания', TRUE),
('POS-003', 'Кассир', 'Продажи', 40000.00, 'Обслуживание на кассе, приём платежей', TRUE),
('POS-004', 'Администратор торгового зала', 'Управление', 65000.00, 'Контроль порядка в зале, решение конфликтных ситуаций', TRUE),
('POS-005', 'Товаровед', 'Логистика', 50000.00, 'Приёмка товара, контроль остатков, инвентаризация', TRUE),
('POS-006', 'Заведующий складом', 'Логистика', 55000.00, 'Управление складом, организация хранения товара', TRUE),
('POS-007', 'Менеджер по персоналу', 'Кадры', 60000.00, 'Подбор персонала, оформление документов', TRUE),
('POS-008', 'Бухгалтер', 'Финансы', 55000.00, 'Ведение бухгалтерского учёта магазина', TRUE),
('POS-009', 'Директор магазина', 'Управление', 120000.00, 'Полное управление магазином, отчётность', TRUE),
('POS-010', 'Заместитель директора', 'Управление', 90000.00, 'Замещение директора, контроль работы отделов', TRUE),
('POS-011', 'Маркетолог', 'Маркетинг', 65000.00, 'Продвижение магазина, проведение акций', TRUE),
('POS-012', 'Специалист по рекламациям', 'Сервис', 48000.00, 'Работа с возвратами и жалобами клиентов', TRUE),
('POS-013', 'Кладовщик', 'Логистика', 42000.00, 'Работа на складе, комплектация заказов', TRUE),
('POS-014', 'Грузчик', 'Логистика', 38000.00, 'Погрузочно-разгрузочные работы', TRUE),
('POS-015', 'Охранник', 'Безопасность', 40000.00, 'Обеспечение безопасности магазина', TRUE);

-- Вставка типов запросов (10 записей)
INSERT INTO request_types (type_code, type_name, description, default_priority, default_deadline_hours, is_active) VALUES
('REQ-TYPE-001', 'Наем нового сотрудника', 'Запрос на наем нового сотрудника на вакантную позицию', 3, 120, TRUE),
('REQ-TYPE-002', 'Замена сотрудника', 'Запрос на замену уволившегося или уходящего сотрудника', 2, 72, TRUE),
('REQ-TYPE-003', 'Временная замена', 'Запрос на временную замену (отпуск, больничный)', 2, 48, TRUE),
('REQ-TYPE-004', 'Дополнительный персонал', 'Запрос на дополнительный персонал в пиковый период', 3, 96, TRUE),
('REQ-TYPE-005', 'Перевод сотрудника', 'Запрос на перевод сотрудника из другого магазина', 4, 168, TRUE),
('REQ-TYPE-006', 'Повышение квалификации', 'Запрос на обучение или повышение квалификации', 4, 240, TRUE),
('REQ-TYPE-007', 'Срочная замена', 'Экстренный запрос на замену (болезнь, прогул)', 1, 24, TRUE),
('REQ-TYPE-008', 'Расширение штата', 'Запрос на расширение штата магазина', 5, 336, TRUE),
('REQ-TYPE-009', 'Сокращение штата', 'Запрос на сокращение штатной единицы', 5, 336, TRUE),
('REQ-TYPE-010', 'Изменение графика', 'Запрос на изменение графика работы сотрудников', 3, 72, TRUE);

-- Вставка сотрудников (18 записей)
INSERT INTO employees (employee_code, first_name, last_name, middle_name, email, phone, position_id, store_id, hire_date, is_active) VALUES
-- Директора магазинов
('EMP-001', 'Иван', 'Петров', 'Сергеевич', 'i.petrov@company.ru', '+79001112233', 9, 1, '2019-03-15', TRUE),
('EMP-002', 'Мария', 'Сидорова', 'Александровна', 'm.sidorova@company.ru', '+79002223344', 9, 2, '2020-06-01', TRUE),
('EMP-003', 'Алексей', 'Козлов', 'Иванович', 'a.kozlov@company.ru', '+79003334455', 9, 3, '2018-09-10', TRUE),
('EMP-004', 'Елена', 'Новикова', 'Владимировна', 'e.novikova@company.ru', '+79004445566', 9, 4, '2021-02-20', TRUE),
-- HR специалисты в центральном офисе
('EMP-005', 'Ольга', 'Морозова', 'Николаевна', 'o.morozova@company.ru', '+79005556677', 7, 1, '2019-05-20', TRUE),
('EMP-006', 'Дмитрий', 'Волков', 'Андреевич', 'd.volkov@company.ru', '+79006667788', 7, 2, '2020-02-15', TRUE),
('EMP-007', 'Анна', 'Лебедева', 'Сергеевна', 'a.lebedeva@company.ru', '+79007778899', 7, 3, '2018-11-10', TRUE),
-- Менеджеры центрального офиса
('EMP-008', 'Сергей', 'Кузнецов', 'Петрович', 's.kuznetsov@company.ru', '+79008889900', 10, 1, '2019-01-10', TRUE),
('EMP-009', 'Наталья', 'Соколова', 'Ивановна', 'n.sokolova@company.ru', '+79009990011', 10, 2, '2020-04-05', TRUE),
-- Продавцы и другие сотрудники
('EMP-010', 'Павел', 'Попов', 'Викторович', 'p.popov@company.ru', '+79010011223', 1, 1, '2021-06-15', TRUE),
('EMP-011', 'Татьяна', 'Кузнецова', 'Дмитриевна', 't.kuznetsova@company.ru', '+79011122334', 1, 2, '2021-07-20', TRUE),
-- Возможный дубль - тот же человек в другом магазине (тот же email) (не сработало, выдало ошибку на тот же email при импорте в xampp, теперь он Пупло Леонов Слонович и email его другой)
('EMP-012', 'Пупло', 'Леонов', 'Слонович', 'p.leonov@company.ru', '+79020022334', 1, 3, '2022-01-10', TRUE),
-- Кассиры
('EMP-013', 'Виктория', 'Смирнова', 'Александровна', 'v.smirnova@company.ru', '+79012233445', 3, 1, '2020-08-25', TRUE),
('EMP-014', 'Артём', 'Фёдоров', 'Сергеевич', 'a.fedorov@company.ru', '+79013344556', 3, 2, '2021-03-10', TRUE),
-- Товароведы
('EMP-015', 'Ирина', 'Белова', 'Николаевна', 'i.belova@company.ru', '+79014455667', 5, 1, '2019-10-05', TRUE),
-- Администраторы
('EMP-016', 'Максим', 'Орлов', 'Дмитриевич', 'm.orlov@company.ru', '+79015566778', 4, 1, '2020-01-15', TRUE),
-- Бухгалтер
('EMP-017', 'Светлана', 'Крылова', 'Владимировна', 's.krylova@company.ru', '+79016677889', 8, 1, '2018-05-20', TRUE),
-- Охранник
('EMP-018', 'Николай', 'Жуков', 'Иванович', 'n.zhukov@company.ru', '+79017788990', 15, 1, '2019-07-12', TRUE);

-- Обновление store_manager_id в таблице stores
UPDATE stores SET store_manager_id = 1 WHERE store_id = 1;
UPDATE stores SET store_manager_id = 2 WHERE store_id = 2;
UPDATE stores SET store_manager_id = 3 WHERE store_id = 3;
UPDATE stores SET store_manager_id = 4 WHERE store_id = 4;

-- Вставка стандартов соответствия (10 записей)
INSERT INTO compliance_standards (standard_code, standard_name, description, requirement_text, effective_date, is_active) VALUES
('STD-001', 'Образовательные требования', 'Минимальные требования к образованию для должностей', 'Наличие среднего профессионального или высшего образования для руководящих должностей', '2023-01-01', TRUE),
('STD-002', 'Требования к опыту работы', 'Минимальный стаж работы для должностей', 'Для старших позиций - минимум 2 года опыта в аналогичной должности', '2023-01-01', TRUE),
('STD-003', 'Навыки работы с ПО', 'Требования к компьютерным навыкам', 'Уверенное владение ПК, знание офисных программ, 1С', '2023-01-01', TRUE),
('STD-004', 'Коммуникативные навыки', 'Требования к навыкам общения', 'Навыки делового общения, работы с клиентами, разрешения конфликтов', '2023-01-01', TRUE),
('STD-005', 'Знание продукции', 'Требования к знанию товара', 'Знание ассортимента, характеристик продукции, правил хранения', '2023-01-01', TRUE),
('STD-006', 'Нормы охраны труда', 'Требования по технике безопасности', 'Знание и соблюдение правил ТБ, пожарной безопасности', '2023-01-01', TRUE),
('STD-007', 'Квалификационные требования', 'Профессиональные компетенции', 'Наличие квалификационных сертификатов для специфических должностей', '2023-01-01', TRUE),
('STD-008', 'Требования к внешнему виду', 'Дресс-код и стандарты внешнего вида', 'Соблюдение дресс-кода компании, опрятный внешний вид', '2023-01-01', TRUE),
('STD-009', 'Знание законодательства', 'Правовые компетенции', 'Знание трудового законодательства для руководителей', '2023-01-01', TRUE),
('STD-010', 'Лидерские компетенции', 'Требования к управленческим навыкам', 'Навыки руководства командой, планирования, мотивации', '2023-01-01', TRUE);

-- Вставка должностных инструкций (15 записей)
INSERT INTO job_descriptions (position_id, version, effective_date, responsibilities, qualifications, skills_required, performance_criteria, is_compliant, compliance_check_date, compliance_notes, created_by) VALUES
(1, '2.0', '2023-06-01', 'Консультирование покупателей по ассортименту; демонстрация товаров; оформление продаж; поддержание порядка в торговом зале; участие в инвентаризации', 'Среднее профессиональное образование; опыт работы в рознице от 1 года', 'Коммуникабельность; знание ассортимента; навыки продаж; работа с кассовым оборудованием', 'План продаж; качество обслуживания; отсутствие жалоб; знание товара', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-001, STD-004, STD-005', 5),
(2, '2.0', '2023-06-01', 'Руководство группой продавцов; контроль качества обслуживания; обучение новых сотрудников; разрешение конфликтных ситуаций; отчётность по продажам', 'Среднее профессиональное образование; опыт работы продавцом от 2 лет', 'Лидерские качества; навыки обучения; аналитические способности; знание стандартов обслуживания', 'План продаж отдела; оценка подчинённых; текучесть кадров; NPS отдела', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-001, STD-002, STD-010', 5),
(3, '2.0', '2023-06-01', 'Обслуживание покупателей на кассе; приём оплаты; оформление чеков; контроль соответствия ценников; участие в инкассации', 'Среднее образование; опыт работы на кассе от 6 месяцев', 'Внимательность; скорость работы; знание кассовой дисциплины; честность', 'Производительность на кассе; отсутствие ошибок; вежливость; отсутствие недостач', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-003, STD-006', 5),
(4, '2.0', '2023-06-01', 'Контроль порядка в торговом зале; решение конфликтных ситуаций; координация работы персонала; контроль соблюдения стандартов', 'Среднее профессиональное образование; опыт работы в торговле от 3 лет', 'Управленческие навыки; стрессоустойчивость; коммуникабельность; знание стандартов', 'Порядок в зале; отсутствие конфликтов; оценка персонала; соблюдение стандартов', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-004, STD-008', 5),
(5, '2.1', '2023-09-01', 'Приёмка товара от поставщиков; контроль качества и количества; оформление документации; ведение учёта остатков; проведение инвентаризаций', 'Среднее профессиональное образование; опыт работы товароведом от 1 года', 'Внимательность; знание 1С; аналитические навыки; знание стандартов хранения', 'Точность приёмки; своевременность документации; отсутствие пересортицы', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-003, STD-005', 6),
(6, '1.5', '2023-03-01', 'Управление складом; организация размещения товара; контроль условий хранения; руководство кладовщиками; отчётность', 'Среднее профессиональное образование; опыт работы на складе от 2 лет', 'Организаторские способности; знание складской логистики; навыки управления персоналом', 'Порядок на складе; сохранность товара; эффективность работы склада', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-006, STD-010', 6),
(7, '3.0', '2023-07-01', 'Подбор персонала; оформление приёма и увольнения; ведение кадрового учёта; организация обучения; контроль трудовой дисциплины', 'Высшее образование (управление персоналом); опыт работы HR от 2 лет', 'Навыки подбора; знание ТК РФ; коммуникабельность; работа с документами', 'Своевременный подбор; текучесть кадров; соблюдение сроков оформления', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-001, STD-009', 7),
(8, '2.0', '2023-06-01', 'Ведение бухгалтерского учёта магазина; расчёт заработной платы; работа с налоговой отчётностью; контроль кассовой дисциплины', 'Высшее экономическое образование; опыт работы бухгалтером от 3 лет', 'Знание бухгалтерского учёта; работа в 1С:Бухгалтерия; внимательность; аналитика', 'Своевременность отчётности; отсутствие штрафов; точность расчётов', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-001, STD-003', 7),
(9, '2.5', '2023-08-01', 'Полное управление магазином; достижение плановых показателей; руководство персоналом; отчётность; взаимодействие с центральным офисом', 'Высшее образование; опыт управления в ритейле от 5 лет', 'Лидерские качества; стратегическое мышление; аналитика; коммуникабельность', 'Выполнение плана продаж; рентабельность; текучесть; NPS магазина', TRUE, '2023-12-15', 'Полное соответствие всем стандартам', 7),
(10, '2.0', '2023-06-01', 'Замещение директора; контроль работы отделов; решение оперативных вопросов; участие в планировании; контроль исполнения решений', 'Высшее образование; опыт работы в торговле от 3 лет', 'Управленческие навыки; инициативность; ответственность; коммуникабельность', 'Исполнение поручений; показатели вверенных направлений; оценка директора', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-002, STD-010', 7),
(11, '1.8', '2023-05-01', 'Разработка маркетинговых мероприятий; проведение рекламных акций; анализ эффективности; работа с социальными сетями; оформление витрин', 'Высшее образование (маркетинг); опыт работы от 1 года', 'Креативность; аналитические способности; знание SMM; дизайн-навыки', 'Рост трафика; эффективность акций; охват в соцсетях; продажи по акциям', FALSE, '2023-12-15', 'Требуется дополнить раздел квалификационных требований согласно STD-001', 7),
(12, '1.5', '2023-04-01', 'Приём и обработка рекламаций; разрешение конфликтных ситуаций с покупателями; контроль качества товара; отчётность по возвратам', 'Среднее профессиональное образование; опыт работы в сервисе от 1 года', 'Стрессоустойчивость; дипломатичность; знание ЗоЗПП; коммуникабельность', 'Количество обработанных рекламаций; удовлетворённость клиентов; сроки обработки', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-004, STD-009', 6),
(13, '2.0', '2023-06-01', 'Приём товара на склад; размещение на местах хранения; комплектация заказов для торгового зала; поддержание порядка на складе', 'Среднее образование; опыт работы на складе приветствуется', 'Физическая выносливость; внимательность; ответственность; аккуратность', 'Скорость работы; точность комплектации; порядок на рабочем месте', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-006', 6),
(14, '1.2', '2023-02-01', 'Погрузочно-разгрузочные работы; перемещение товара; участие в инвентаризации; поддержание чистоты складских помещений', 'Среднее образование; опыт работы не обязателен', 'Физическая выносливость; ответственность; аккуратность; дисциплинированность', 'Объём выполненных работ; отсутствие повреждений товара; дисциплина', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-006', 6),
(15, '2.0', '2023-06-01', 'Обеспечение безопасности магазина; контроль входа/выхода; предотвращение хищений; реагирование на нештатные ситуации; ведение журнала посещений', 'Среднее образование; лицензия охранника; опыт работы от 1 года', 'Наблюдательность; стрессоустойчивость; знание правил охраны; ответственность', 'Отсутствие хищений; порядок на вверенной территории; своевременное реагирование', TRUE, '2023-12-15', 'Полное соответствие стандартам STD-006, STD-007', 7);

-- Вставка конфигураций SLA (15 записей)
INSERT INTO sla_configurations (request_type_id, size_category, min_employees, max_employees, target_response_hours, target_completion_hours, escalation_hours, penalty_rate, is_active, created_by) VALUES
(1, 'малый', 1, 2, 24, 72, 48, 0.50, TRUE, 8),
(1, 'средний', 3, 5, 48, 120, 48, 0.75, TRUE, 8),
(1, 'крупный', 6, 15, 72, 168, 48, 1.00, TRUE, 8),
(2, 'малый', 1, 2, 12, 48, 48, 0.75, TRUE, 8),
(2, 'средний', 3, 5, 24, 72, 48, 1.00, TRUE, 8),
(3, 'малый', 1, 2, 8, 36, 48, 1.00, TRUE, 8),
(3, 'средний', 3, 5, 16, 48, 48, 1.25, TRUE, 8),
(4, 'малый', 1, 3, 24, 72, 48, 0.50, TRUE, 9),
(4, 'средний', 4, 8, 48, 96, 48, 0.75, TRUE, 9),
(4, 'крупный', 9, 20, 72, 144, 48, 1.00, TRUE, 9),
(7, 'малый', 1, 2, 4, 24, 48, 1.50, TRUE, 8),
(7, 'средний', 3, 5, 8, 36, 48, 1.75, TRUE, 8),
(8, 'малый', 1, 2, 72, 240, 48, 0.25, TRUE, 9),
(8, 'средний', 3, 5, 96, 336, 48, 0.50, TRUE, 9),
(8, 'крупный', 6, 10, 120, 480, 48, 0.75, TRUE, 9);

-- Вставка шаблонов ответов (Response Presets) - 15 записей
INSERT INTO response_presets (preset_code, preset_name, request_type_id, priority_level, deadline_hours, auto_message, recommended_action, escalation_contact_id, is_active) VALUES
('RP-001', 'Срочная замена - стандарт', 7, 1, 24, 'Ваш запрос на срочную замену принят в работу. Ожидайте назначения исполнителя в течение 4 часов.', 'Немедленно проверить базу доступных сотрудников; связаться с кандидатом; подтвердить выход', 5, TRUE),
('RP-002', 'Срочная замена - повышенный приоритет', 7, 1, 12, 'Запрос передан старшему HR-специалисту. Мы понимаем срочность ситуации.', 'Связаться с региональным менеджером; рассмотреть варианты перевода из других магазинов', 6, TRUE),
('RP-003', 'Временная замена - стандарт', 3, 2, 48, 'Запрос на временную замену принят. Подбор кандидата начат.', 'Проверить график отпусков; найти сотрудника на подработку; согласовать график', 5, TRUE),
('RP-004', 'Замена сотрудника - стандарт', 2, 2, 72, 'Ваш запрос на замену сотрудника принят. Начат поиск кандидата.', 'Разместить вакансию; провести первичный отбор; назначить собеседования', 7, TRUE),
('RP-005', 'Наем нового сотрудника - малый', 1, 3, 96, 'Запрос на наем нового сотрудника принят. Срок выполнения - до 5 рабочих дней.', 'Провести анализ резюме на порталах; организовать собеседования', 5, TRUE),
('RP-006', 'Наем нового сотрудника - средний', 1, 3, 120, 'Запрос на наем нескольких сотрудников принят. Начат массовый подбор.', 'Запустить рекламу вакансий; провести ярмарку вакансий; массовый отбор', 6, TRUE),
('RP-007', 'Наем нового сотрудника - крупный', 1, 4, 168, 'Крупный запрос на подбор персонала передан в приоритетную обработку.', 'Координация с региональным HR; привлечение кадровых агентств', 7, TRUE),
('RP-008', 'Дополнительный персонал - сезон', 4, 3, 96, 'Запрос на дополнительный персонал принят. Начат поиск сезонных работников.', 'Активация базы сезонных работников; размещение в соцсетях; работа с вузами', 5, TRUE),
('RP-009', 'Перевод сотрудника', 5, 4, 168, 'Запрос на перевод сотрудника принят. Требуется согласование с обоими магазинами.', 'Связаться с директорами обоих магазинов; согласовать условия перевода', 6, TRUE),
('RP-010', 'Расширение штата - стандарт', 8, 4, 240, 'Запрос на расширение штата принят на рассмотрение. Требуется обоснование.', 'Подготовить аналитику по нагрузке; согласовать с финансовым отделом', 8, TRUE),
('RP-011', 'Повышение квалификации', 6, 4, 336, 'Запрос на обучение принят. Подбираем оптимальную программу.', 'Анализ потребностей в обучении; выбор провайдера; согласование бюджета', 7, TRUE),
('RP-012', 'Изменение графика', 10, 3, 72, 'Запрос на изменение графика принят. Рассматриваем возможности.', 'Анализ текущих графиков; согласование с сотрудниками; утверждение изменений', 5, TRUE),
('RP-013', 'Сокращение штата', 9, 5, 336, 'Запрос на сокращение принят. Требуется тщательное соблюдение процедуры.', 'Консультация с юридическим отделом; подготовка уведомлений; соблюдение сроков', 8, TRUE),
('RP-014', 'Временная замена - срочная', 3, 1, 24, 'Срочный запрос на временную замену. Работаем в приоритетном режиме.', 'Экстренный обзвон сотрудников; проверка возможности выхода', 6, TRUE),
('RP-015', 'Дополнительный персонал - срочно', 4, 2, 48, 'Срочный запрос на дополнительный персонал принят.', 'Мобилизация внутренних ресурсов; привлечение агентств быстрого найма', 7, TRUE);

-- Вставка запросов на персонал (Staffing Requests) - 18 записей
INSERT INTO staffing_requests (request_number, store_id, requester_id, request_type_id, position_id, quantity, size_category, urgency_reason, description, required_skills, preferred_start_date, status, assigned_to, assigned_at, sla_deadline, created_at) VALUES
('REQ-2026-001', 1, 1, 1, 1, 2, 'малый', 'Расширение отдела электроники', 'Требуются два продавца-консультанта в отдел электроники в связи с расширением ассортимента', 'Знание бытовой техники и электроники; опыт продаж от 1 года', '2026-02-01', 'выполнен', 5, '2026-01-15 10:30:00', '2026-01-22 10:30:00', '2026-01-10 10:30:00'),
('REQ-2026-002', 2, 2, 2, 3, 1, 'малый', 'Увольнение сотрудника', 'Замена кассира в связи с увольнением по собственному желанию', 'Опыт работы на кассе; внимательность; ответственность', '2026-02-15', 'закрыт', 6, '2026-01-20 09:00:00', '2026-01-24 09:00:00', '2026-01-18 09:00:00'),
('REQ-2026-003', 3, 3, 7, 1, 1, 'малый', 'Болезнь сотрудника', 'Срочная замена продавца на время больничного', 'Готовность к выходу в ближайшие дни', '2026-01-22', 'выполнен', 5, '2026-01-21 16:00:00', '2026-01-22 16:00:00', '2026-01-21 14:30:00'),
('REQ-2026-004', 1, 1, 4, 13, 3, 'средний', 'Подготовка к инвентаризации', 'Дополнительный персонал для подготовки к годовой инвентаризации', 'Физическая выносливость; внимательность', '2026-02-10', 'выполнен', 6, '2026-01-28 11:00:00', '2026-02-05 11:00:00', '2026-01-25 11:00:00'),
('REQ-2026-005', 4, 4, 1, 2, 1, 'малый', 'Открытие нового отдела', 'Требуется старший продавец в новый отдел косметики', 'Опыт работы с косметикой; навыки управления', '2026-03-01', 'назначен_исполнитель', 7, '2026-02-01 10:00:00', '2026-02-15 10:00:00', '2026-01-30 10:00:00'),
('REQ-2026-006', 5, 1, 3, 3, 2, 'малый', 'Отпускной период', 'Временная замена двух кассиров на время отпусков', 'Опыт работы на кассе; гибкий график', '2026-02-20', 'в_работе', 5, '2026-02-03 14:00:00', '2026-02-07 14:00:00', '2026-02-01 14:00:00'),
('REQ-2026-007', 6, 3, 8, 1, 5, 'средний', 'Открытие второго этажа', 'Расширение штата в связи с открытием второго этажа магазина', 'Опыт в рознице; готовность к обучению', '2026-04-01', 'на_рассмотрении', NULL, NULL, '2026-03-15 10:00:00', '2026-02-05 09:00:00'),
('REQ-2026-008', 2, 2, 5, 4, 1, 'малый', 'Перевод из другого магазина', 'Перевод администратора из магазина MOW-001', 'Согласие сотрудника; опыт работы администратором', '2026-03-01', 'выполнен', 6, '2026-02-08 12:00:00', '2026-02-15 12:00:00', '2026-02-05 12:00:00'),
('REQ-2026-009', 7, 4, 6, 1, 3, 'средний', 'Обучение новых сотрудников', 'Запрос на программу адаптации для новых продавцов', 'Навыки обучения; знание стандартов', '2026-03-15', 'выполнен', 7, '2026-02-12 10:00:00', '2026-02-26 10:00:00', '2026-02-10 10:00:00'),
('REQ-2026-010', 8, 1, 7, 14, 2, 'средний', 'Срочная потребность', 'Срочный набор грузчиков в связи с увеличением поставок', 'Физическая выносливость; ответственность', '2026-02-15', 'выполнен', 5, '2026-02-14 08:00:00', '2026-02-15 20:00:00', '2026-02-14 06:00:00'),
('REQ-2026-011', 3, 3, 2, 5, 1, 'малый', 'Декретная ставка', 'Замена товароведа на время декретного отпуска', 'Опыт работы товароведом; знание 1С', '2026-03-01', 'в_работе', 6, '2026-02-18 11:00:00', '2026-02-22 11:00:00', '2026-02-15 11:00:00'),
('REQ-2026-012', 9, 2, 4, 1, 4, 'средний', 'Сезонный наплыв', 'Дополнительные продавцы на весенний сезон', 'Готовность к работе в выходные; коммуникабельность', '2026-03-01', 'новый', NULL, NULL, '2026-02-28 10:00:00', '2026-02-18 10:00:00'),
('REQ-2026-013', 10, 4, 1, 6, 1, 'малый', 'Рост объёмов', 'Требуется заведующий складом в связи с ростом товарооборота', 'Опыт управления складом; знание складской логистики', '2026-04-01', 'на_согласовании', 7, '2026-02-20 14:00:00', '2026-02-27 14:00:00', '2026-02-19 14:00:00'),
('REQ-2026-014', 1, 1, 10, NULL, 0, 'малый', 'Оптимизация графиков', 'Запрос на изменение графиков работы отдела бакалеи', 'Согласие всех сотрудников отдела', '2026-03-01', 'выполнен', 5, '2026-02-22 09:00:00', '2026-02-25 09:00:00', '2026-02-20 09:00:00'),
('REQ-2026-015', 11, 3, 3, 15, 1, 'малый', 'Больничный', 'Временная замена охранника', 'Наличие лицензии охранника', '2026-02-28', 'выполнен', 6, '2026-02-25 10:00:00', '2026-02-26 10:00:00', '2026-02-24 22:00:00'),
('REQ-2026-016', 4, 4, 9, 2, 1, 'малый', 'Оптимизация штата', 'Сокращение одной штатной единицы старшего продавца', 'Соблюдение процедуры сокращения', '2026-05-01', 'на_рассмотрении', NULL, NULL, '2026-03-10 10:00:00', '2026-02-26 10:00:00'),
('REQ-2026-017', 12, 1, 7, 13, 2, 'средний', 'Аварийная ситуация', 'Срочная замена кладовщиков в связи с аварией на складе', 'Опыт работы на складе; готовность к ночным сменам', '2026-02-28', 'выполнен', 5, '2026-02-27 07:00:00', '2026-02-28 07:00:00', '2026-02-27 05:30:00'),
('REQ-2026-018', 5, 2, 1, 11, 1, 'малый', 'Новый проект', 'Требуется маркетолог для запуска программы лояльности', 'Опыт работы с программами лояльности; аналитика', '2026-04-15', 'новый', NULL, NULL, '2026-03-20 10:00:00', '2026-02-28 10:00:00');

-- Вставка истории запросов (Request History) - 20 записей
INSERT INTO request_history (request_id, store_id, requester_id, action_type, old_status, new_status, action_description, performed_by, action_timestamp, notes) VALUES
(1, 1, 1, 'Создание запроса', NULL, 'новый', 'Запрос создан директором магазина', 1, '2026-01-10 10:30:00', 'Запрос на расширение штата'),
(1, 1, 1, 'Назначение исполнителя', 'новый', 'назначен_исполнитель', 'Запрос назначен HR-специалисту Ольге Морозовой', 5, '2026-01-15 10:30:00', 'Назначен ответственный'),
(1, 1, 1, 'Завершение', 'в_работе', 'выполнен', 'Подобраны 2 кандидата, приняты на работу', 5, '2026-01-20 15:00:00', 'Запрос выполнен в срок'),
(2, 2, 2, 'Создание запроса', NULL, 'новый', 'Запрос на замену кассира', 2, '2026-01-18 09:00:00', 'Срочная замена'),
(2, 2, 2, 'Назначение исполнителя', 'новый', 'назначен_исполнитель', 'Назначен HR-специалист Дмитрий Волков', 6, '2026-01-20 09:00:00', 'Исполнитель назначен'),
(2, 2, 2, 'Закрытие', 'выполнен', 'закрыт', 'Кандидат вышел на работу', 8, '2026-01-25 14:00:00', 'Закрыт директором'),
(3, 3, 3, 'Создание запроса', NULL, 'новый', 'Срочная замена по болезни', 3, '2026-01-21 14:30:00', 'Экстренный запрос'),
(3, 3, 3, 'Назначение исполнителя', 'новый', 'назначен_исполнитель', 'Срочное назначение', 5, '2026-01-21 16:00:00', 'В течение 1.5 часов'),
(4, 1, 1, 'Создание запроса', NULL, 'новый', 'Запрос на дополнительный персонал', 1, '2026-01-25 11:00:00', 'Подготовка к инвентаризации'),
(4, 1, 1, 'Назначение исполнителя', 'новый', 'назначен_исполнитель', 'Назначен ответственный', 6, '2026-01-28 11:00:00', ''),
(5, 4, 4, 'Создание запроса', NULL, 'новый', 'Запрос на старшего продавца', 4, '2026-01-30 10:00:00', 'Новый отдел'),
(5, 4, 4, 'Принятие в работу', 'новый', 'на_рассмотрении', 'Запрос передан на рассмотрение', 8, '2026-01-31 10:00:00', ''),
(5, 4, 4, 'Назначение исполнителя', 'на_рассмотрении', 'назначен_исполнитель', 'Назначен HR-специалист', 7, '2026-02-01 10:00:00', ''),
(6, 5, 1, 'Создание запроса', NULL, 'новый', 'Временная замена на период отпусков', 1, '2026-02-01 14:00:00', ''),
(6, 5, 1, 'Начало работы', 'назначен_исполнитель', 'в_работе', 'Подбор кандидатов начат', 5, '2026-02-03 14:00:00', ''),
(10, 8, 1, 'Создание запроса', NULL, 'новый', 'Срочный набор грузчиков', 1, '2026-02-14 06:00:00', 'Экстренная ситуация'),
(10, 8, 1, 'Назначение исполнителя', 'новый', 'назначен_исполнитель', 'Мгновенное назначение', 5, '2026-02-14 08:00:00', 'Реакция в течение 2 часов'),
(17, 12, 1, 'Создание запроса', NULL, 'новый', 'Аварийная замена', 1, '2026-02-27 05:30:00', 'Ночная ситуация'),
(17, 12, 1, 'Назначение исполнителя', 'новый', 'назначен_исполнитель', 'Экстренное назначение', 5, '2026-02-27 07:00:00', 'Реакция в течение 1.5 часов'),
(17, 12, 1, 'Завершение', 'в_работе', 'выполнен', 'Сотрудники найдены и выведены на работу', 5, '2026-02-28 06:00:00', 'Запрос выполнен');

-- Вставка метрик обработки (Processing Metrics) - 15 записей
INSERT INTO processing_metrics (request_id, store_id, request_type_id, size_category, created_at, assigned_at, completed_at, closed_at, response_time_hours, completion_time_hours, total_time_hours, sla_target_hours, is_sla_met, delay_hours, delay_reason) VALUES
(1, 1, 1, 'малый', '2026-01-10 10:30:00', '2026-01-15 10:30:00', '2026-01-20 15:00:00', '2026-01-21 10:00:00', 120.00, 242.50, 263.50, 72, TRUE, 0, NULL),
(2, 2, 2, 'малый', '2026-01-18 09:00:00', '2026-01-20 09:00:00', '2026-01-24 12:00:00', '2026-01-25 14:00:00', 48.00, 102.00, 149.00, 48, TRUE, 0, NULL),
(3, 3, 7, 'малый', '2026-01-21 14:30:00', '2026-01-21 16:00:00', '2026-01-22 08:00:00', '2026-01-22 10:00:00', 1.50, 16.00, 17.50, 24, TRUE, 0, NULL),
(4, 1, 4, 'средний', '2026-01-25 11:00:00', '2026-01-28 11:00:00', '2026-02-05 16:00:00', '2026-02-06 10:00:00', 72.00, 261.00, 291.00, 96, TRUE, 0, NULL),
(5, 4, 1, 'малый', '2026-01-30 10:00:00', '2026-02-01 10:00:00', NULL, NULL, 48.00, NULL, NULL, 72, TRUE, 0, NULL),
(6, 5, 3, 'малый', '2026-02-01 14:00:00', '2026-02-03 14:00:00', NULL, NULL, 48.00, NULL, NULL, 36, FALSE, 12, 'Задержка назначения исполнителя'),
(7, 6, 8, 'средний', '2026-02-05 09:00:00', NULL, NULL, NULL, NULL, NULL, NULL, 336, TRUE, 0, NULL),
(8, 2, 5, 'малый', '2026-02-05 12:00:00', '2026-02-08 12:00:00', '2026-02-14 16:00:00', '2026-02-15 10:00:00', 72.00, 151.00, 239.00, 168, TRUE, 0, NULL),
(9, 7, 6, 'средний', '2026-02-10 10:00:00', '2026-02-12 10:00:00', '2026-02-25 17:00:00', '2026-02-26 09:00:00', 48.00, 319.00, 383.00, 336, TRUE, 0, NULL),
(10, 8, 7, 'средний', '2026-02-14 06:00:00', '2026-02-14 08:00:00', '2026-02-15 18:00:00', '2026-02-16 09:00:00', 2.00, 36.00, 51.00, 36, TRUE, 0, NULL),
(11, 3, 2, 'малый', '2026-02-15 11:00:00', '2026-02-18 11:00:00', NULL, NULL, 72.00, NULL, NULL, 48, FALSE, 24, 'Длительный поиск кандидата'),
(14, 1, 10, 'малый', '2026-02-20 09:00:00', '2026-02-22 09:00:00', '2026-02-24 17:00:00', '2026-02-25 10:00:00', 48.00, 77.00, 97.00, 72, TRUE, 0, NULL),
(15, 11, 3, 'малый', '2026-02-24 22:00:00', '2026-02-25 10:00:00', '2026-02-26 08:00:00', '2026-02-26 10:00:00', 12.00, 34.00, 36.00, 36, TRUE, 0, NULL),
(17, 12, 7, 'средний', '2026-02-27 05:30:00', '2026-02-27 07:00:00', '2026-02-28 06:00:00', '2026-02-28 10:00:00', 1.50, 24.50, 28.50, 36, TRUE, 0, NULL),
(18, 5, 1, 'малый', '2026-02-28 10:00:00', NULL, NULL, NULL, NULL, NULL, NULL, 96, TRUE, 0, NULL);

-- Вставка автозадач для HR Specialist - 15 записей
INSERT INTO auto_generated_tasks (task_number, request_id, assigned_to, priority, deadline, task_type, description, checklist, status, compliance_check_passed, duplicate_check_passed, created_at) VALUES
('TASK-2026-001', 1, 5, 3, '2026-01-22 10:30:00', 'Подбор персонала', 'Подбор 2 продавцов-консультантов для магазина Алексеевский', '["Разместить вакансию", "Провести отбор резюме", "Назначить собеседования", "Проверить документы", "Оформить приём"]', 'выполнена', TRUE, TRUE, '2026-01-15 10:30:00'),
('TASK-2026-002', 2, 6, 2, '2026-01-24 09:00:00', 'Замена сотрудника', 'Подбор кассира на замену уволившемуся', '["Разместить вакансию", "Отбор кандидатов", "Собеседование", "Оформление"]', 'выполнена', TRUE, TRUE, '2026-01-20 09:00:00'),
('TASK-2026-003', 3, 5, 1, '2026-01-22 16:00:00', 'Срочная замена', 'Срочная замена продавца на больничный', '["Проверить базу доступных", "Связаться с кандидатом", "Подтвердить выход"]', 'выполнена', TRUE, TRUE, '2026-01-21 16:00:00'),
('TASK-2026-004', 4, 6, 3, '2026-02-05 11:00:00', 'Подбор временного персонала', 'Подбор 3 кладовщиков для инвентаризации', '["Анализ потребности", "Поиск кандидатов", "Оформление"]', 'выполнена', TRUE, TRUE, '2026-01-28 11:00:00'),
('TASK-2026-005', 5, 7, 3, '2026-02-15 10:00:00', 'Подбор персонала', 'Подбор старшего продавца в отдел косметики', '["Разместить вакансию", "Отбор резюме", "Собеседования"]', 'в_работе', TRUE, TRUE, '2026-02-01 10:00:00'),
('TASK-2026-006', 6, 5, 2, '2026-02-07 14:00:00', 'Временная замена', 'Подбор 2 кассиров на период отпусков', '["Проверка базы", "Согласование графиков"]', 'в_работе', TRUE, TRUE, '2026-02-03 14:00:00'),
('TASK-2026-007', 7, 6, 4, '2026-03-15 10:00:00', 'Массовый подбор', 'Подбор 5 продавцов для нового этажа', '["Анализ рынка", "Массовый отбор", "Обучение"]', 'новая', NULL, NULL, '2026-02-05 09:00:00'),
('TASK-2026-008', 8, 6, 4, '2026-02-15 12:00:00', 'Перевод сотрудника', 'Координация перевода администратора между магазинами', '["Согласование с директорами", "Оформление перевода"]', 'выполнена', TRUE, TRUE, '2026-02-08 12:00:00'),
('TASK-2026-009', 9, 7, 4, '2026-02-26 10:00:00', 'Обучение', 'Организация программы адаптации для новых продавцов', '["Подготовка программы", "Назначение наставников"]', 'выполнена', TRUE, TRUE, '2026-02-12 10:00:00'),
('TASK-2026-010', 10, 5, 1, '2026-02-15 20:00:00', 'Срочный подбор', 'Срочный набор 2 грузчиков', '["Экстренный обзвон", "Оформление"]', 'выполнена', TRUE, TRUE, '2026-02-14 08:00:00'),
('TASK-2026-011', 11, 6, 2, '2026-02-22 11:00:00', 'Замена на декрет', 'Подбор товароведа на декретную ставку', '["Поиск кандидатов", "Собеседования"]', 'в_работе', TRUE, TRUE, '2026-02-18 11:00:00'),
('TASK-2026-012', 12, 5, 3, '2026-02-28 10:00:00', 'Сезонный подбор', 'Подбор 4 продавцов на весенний сезон', '["Размещение вакансий", "Отбор кандидатов"]', 'новая', NULL, NULL, '2026-02-18 10:00:00'),
('TASK-2026-013', 13, 7, 3, '2026-02-27 14:00:00', 'Подбор персонала', 'Подбор заведующего складом', '["Анализ требований", "Поиск кандидатов"]', 'в_работе', TRUE, TRUE, '2026-02-20 14:00:00'),
('TASK-2026-014', 15, 6, 2, '2026-02-26 10:00:00', 'Временная замена', 'Замена охранника на больничный', '["Поиск лицензированного охранника", "Оформление"]', 'выполнена', TRUE, TRUE, '2026-02-25 10:00:00'),
('TASK-2026-015', 17, 5, 1, '2026-02-28 07:00:00', 'Аварийная замена', 'Срочная замена 2 кладовщиков', '["Экстренный поиск", "Вывод на работу"]', 'выполнена', TRUE, TRUE, '2026-02-27 07:00:00');

-- Вставка уведомлений - 15 записей
INSERT INTO notifications (recipient_id, notification_type, title, message, related_request_id, is_read, sent_at, priority) VALUES
(8, 'Задержка назначения', 'Превышено время назначения исполнителя', 'По запросу REQ-2026-006 прошло более 48 часов без назначения исполнителя. Требуется вмешательство.', 6, FALSE, '2026-02-05 14:00:00', 1),
(8, 'Нарушение SLA', 'Нарушение целевого времени SLA', 'Запрос REQ-2026-011 превысил целевое время отклика. Принять меры.', 11, FALSE, '2026-02-20 11:00:00', 2),
(1, 'Статус запроса', 'Запрос выполнен', 'Ваш запрос REQ-2026-001 успешно выполнен. Подобрано 2 сотрудника.', 1, TRUE, '2026-01-20 15:00:00', 3),
(2, 'Статус запроса', 'Запрос закрыт', 'Запрос REQ-2026-002 закрыт. Кандидат вышел на работу.', 2, TRUE, '2026-01-25 14:00:00', 3),
(3, 'Статус запроса', 'Исполнитель назначен', 'По вашему запросу REQ-2026-003 назначен ответственный. Ожидайте результатов.', 3, TRUE, '2026-01-21 16:00:00', 2),
(5, 'Новое задание', 'Назначено новое задание', 'Вам назначено задание TASK-2026-005. Срок выполнения до 15.02.2026', 5, TRUE, '2026-02-01 10:00:00', 3),
(6, 'Новое задание', 'Назначено новое задание', 'Вам назначено задание TASK-2026-006. Срок выполнения до 07.02.2026', 6, TRUE, '2026-02-03 14:00:00', 2),
(7, 'Новое задание', 'Назначено новое задание', 'Вам назначено задание TASK-2026-007. Крупный запрос на подбор.', 7, TRUE, '2026-02-05 09:00:00', 4),
(8, 'Информация', 'Требуется согласование', 'Запрос REQ-2026-007 требует согласования для расширения штата.', 7, FALSE, '2026-02-06 10:00:00', 3),
(1, 'Статус запроса', 'Запрос в работе', 'По вашему запросу REQ-2026-004 начат подбор персонала.', 4, TRUE, '2026-01-28 11:00:00', 3),
(4, 'Статус запроса', 'Исполнитель назначен', 'По запросу REQ-2026-005 назначен HR-специалист. Начат подбор.', 5, TRUE, '2026-02-01 10:00:00', 3),
(5, 'Напоминание', 'Приближается срок', 'Срок выполнения задания TASK-2026-005 истекает через 3 дня.', 5, FALSE, '2026-02-12 10:00:00', 2),
(8, 'Отчёт', 'Еженедельный отчёт готов', 'Еженедельный отчёт по метрикам обработки запросов доступен для просмотра.', NULL, FALSE, '2026-02-19 09:00:00', 4),
(1, 'Срочно', 'Экстренный запрос', 'Создан срочный запрос REQ-2026-017. Требуется немедленная реакция.', 17, TRUE, '2026-02-27 05:30:00', 1),
(8, 'Информация', 'Новый запрос на расширение', 'Запрос REQ-2026-016 на сокращение штата требует рассмотрения.', 16, FALSE, '2026-02-26 11:00:00', 3);

-- Вставка журнала статусов - 18 записей
INSERT INTO request_status_log (request_id, status, changed_by, changed_at, comment) VALUES
(1, 'новый', 1, '2026-01-10 10:30:00', 'Запрос создан'),
(1, 'назначен_исполнитель', 5, '2026-01-15 10:30:00', 'Назначен ответственный HR-специалист'),
(1, 'в_работе', 5, '2026-01-16 09:00:00', 'Начат подбор кандидатов'),
(1, 'выполнен', 5, '2026-01-20 15:00:00', 'Подобраны кандидаты, приняты на работу'),
(2, 'новый', 2, '2026-01-18 09:00:00', 'Запрос создан'),
(2, 'назначен_исполнитель', 6, '2026-01-20 09:00:00', 'Назначен HR-специалист'),
(2, 'выполнен', 6, '2026-01-24 12:00:00', 'Кандидат найден и вышел на работу'),
(2, 'закрыт', 8, '2026-01-25 14:00:00', 'Запрос закрыт менеджером центрального офиса'),
(3, 'новый', 3, '2026-01-21 14:30:00', 'Срочный запрос создан'),
(3, 'назначен_исполнитель', 5, '2026-01-21 16:00:00', 'Экстренное назначение'),
(3, 'выполнен', 5, '2026-01-22 08:00:00', 'Замена найдена в кратчайшие сроки'),
(5, 'новый', 4, '2026-01-30 10:00:00', 'Запрос создан'),
(5, 'на_рассмотрении', 8, '2026-01-31 10:00:00', 'Передан на рассмотрение'),
(5, 'назначен_исполнитель', 7, '2026-02-01 10:00:00', 'Назначен ответственный'),
(6, 'новый', 1, '2026-02-01 14:00:00', 'Запрос создан'),
(6, 'назначен_исполнитель', 5, '2026-02-03 14:00:00', 'Назначен исполнителем'),
(6, 'в_работе', 5, '2026-02-04 09:00:00', 'Начат подбор временных сотрудников'),
(17, 'выполнен', 5, '2026-02-28 06:00:00', 'Экстренная ситуация разрешена');

-- Вставка элементов меню UI - 15 записей
INSERT INTO ui_menu_items (parent_id, menu_code, menu_name, menu_path, icon_class, display_order, role_required, is_active) VALUES
(NULL, 'MENU_DASHBOARD', 'Главная', '/dashboard', 'fa-home', 1, 'all', TRUE),
(NULL, 'MENU_REQUESTS', 'Запросы', '/requests', 'fa-file-alt', 2, 'all', TRUE),
(NULL, 'MENU_HISTORY', 'История запросов', '/history', 'fa-history', 3, 'store_manager', TRUE),
(NULL, 'MENU_NEW_REQUEST', 'Создать запрос', '/requests/new', 'fa-plus-circle', 4, 'store_manager', TRUE),
(NULL, 'MENU_METRICS', 'Метрики', '/metrics', 'fa-chart-bar', 5, 'central_office_manager', TRUE),
(NULL, 'MENU_SLA', 'Настройки SLA', '/sla', 'fa-cog', 6, 'central_office_manager', TRUE),
(NULL, 'MENU_ANALYTICS', 'Аналитика', '/analytics', 'fa-chart-line', 7, 'central_office_manager', TRUE),
(NULL, 'MENU_TASKS', 'Мои задачи', '/tasks', 'fa-tasks', 8, 'hr_specialist', TRUE),
(NULL, 'MENU_EMPLOYEES', 'Сотрудники', '/employees', 'fa-users', 9, 'hr_specialist', TRUE),
(NULL, 'MENU_JOB_DESC', 'Должностные инструкции', '/job-descriptions', 'fa-book', 10, 'hr_specialist', TRUE),
(NULL, 'MENU_PRESETS', 'Шаблоны ответов', '/presets', 'fa-copy', 11, 'hr_specialist', TRUE),
(NULL, 'MENU_NOTIFICATIONS', 'Уведомления', '/notifications', 'fa-bell', 12, 'all', TRUE),
(NULL, 'MENU_REPORTS', 'Отчёты', '/reports', 'fa-file-pdf', 13, 'central_office_manager', TRUE),
(NULL, 'MENU_SETTINGS', 'Настройки', '/settings', 'fa-wrench', 14, 'all', TRUE),
(NULL, 'MENU_HELP', 'Помощь', '/help', 'fa-question-circle', 15, 'all', TRUE);

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
('LANGUAGE_DEFAULT', 'ru', 'string', 'Язык интерфейса по умолчанию', 8),
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
-- COMMENT ON TABLE processing_metrics IS 'Метрики обработки для Central Office Manager (Data Object из BPMN)';
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