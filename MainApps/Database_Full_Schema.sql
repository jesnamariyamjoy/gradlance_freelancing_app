-- Gradlance Platform Database Schema & Storage Setup
-- Comprehensive Schema mapping adjusted spellings and consolidated structure

-- 1. Country & Location
CREATE TABLE IF NOT EXISTS tbl_country (
    country_id SERIAL PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS tbl_states (
    states_id SERIAL PRIMARY KEY,
    states_name VARCHAR(100) NOT NULL,
    country_id INT REFERENCES tbl_country(country_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tbl_district (
    district_id SERIAL PRIMARY KEY,
    district_name VARCHAR(100) NOT NULL,
    states_id INT REFERENCES tbl_states(states_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tbl_places (
    place_id SERIAL PRIMARY KEY,
    place_name VARCHAR(100) NOT NULL,
    district_id INT REFERENCES tbl_district(district_id) ON DELETE CASCADE
);

-- 2. Skills & Categories
CREATE TABLE IF NOT EXISTS tbl_category (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS tbl_jobtype (
    jobtype_id SERIAL PRIMARY KEY,
    jobtype_name VARCHAR(100) NOT NULL,
    category_id INT REFERENCES tbl_category(category_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tbl_technicalskill (
    technicalskill_id SERIAL PRIMARY KEY,
    technicalskill_name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS tbl_softskill (
    softskill_id SERIAL PRIMARY KEY,
    softskill_name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS tbl_language (
    language_id SERIAL PRIMARY KEY,
    language_name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS tbl_qualifications (
    qualifications_id SERIAL PRIMARY KEY,
    qualifications_name VARCHAR(100) NOT NULL
);

-- 3. Users (Students) & Clients Check Auth schema exists
CREATE TABLE IF NOT EXISTS tbl_user (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name VARCHAR(100),
    user_email VARCHAR(100),
    user_contact VARCHAR(20),
    user_photo VARCHAR(255),
    college VARCHAR(255),
    user_status VARCHAR(20) DEFAULT 'pending',
    is_active BOOLEAN DEFAULT TRUE,
    is_premium BOOLEAN DEFAULT FALSE,
    rating DECIMAL(2,1) DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tbl_client (
    client_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    client_name VARCHAR(100),
    client_email VARCHAR(100),
    client_contact VARCHAR(20),
    client_address TEXT,
    client_logo VARCHAR(255),
    client_proof VARCHAR(255),
    client_status VARCHAR(20) DEFAULT 'pending',
    is_active BOOLEAN DEFAULT TRUE,
    is_premium BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP WITH TIME ZONE,
    rejected_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tbl_user_details (
    details_id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    bio TEXT,
    portfolio_link TEXT,
    github_link TEXT,
    linkedin_link TEXT,
    dob DATE,
    gender VARCHAR(20),
    course VARCHAR(100),
    current_year VARCHAR(20),
    expected_graduation VARCHAR(20),
    address TEXT,
    pincode VARCHAR(20),
    place INT REFERENCES tbl_places(place_id) ON DELETE SET NULL,
    college_name VARCHAR(255),
    resume_url VARCHAR(255),
    linkedin_url VARCHAR(255),
    github_url VARCHAR(255),
    portfolio_links JSONB,
    profile_completed BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- 4. Subscriptions
CREATE TABLE IF NOT EXISTS tbl_subscription_plan (
    plan_id SERIAL PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL,
    plan_description TEXT,
    plan_price DECIMAL(10,2) NOT NULL,
    plan_duration_days INT NOT NULL,
    plan_type VARCHAR(20), -- 'student' or 'client'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tbl_subscription (
    subscription_id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL, 
    plan_id INT REFERENCES tbl_subscription_plan(plan_id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'active', -- active, expired, cancelled
    end_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Work & Applications
CREATE TABLE IF NOT EXISTS tbl_work (
    work_id SERIAL PRIMARY KEY,
    client_id UUID REFERENCES tbl_client(client_id) ON DELETE CASCADE,
    work_title VARCHAR(255) NOT NULL,
    work_content TEXT,
    work_lastdate DATE,
    work_file VARCHAR(255), 
    work_status VARCHAR(20) DEFAULT 'pending', 
    jobtype_id INT REFERENCES tbl_jobtype(jobtype_id) ON DELETE SET NULL,
    budget DECIMAL(10,2),
    assigned_user_id UUID REFERENCES tbl_user(id) ON DELETE SET NULL,
    submitted_work_link TEXT, 
    payment_status BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tbl_application (
    application_id SERIAL PRIMARY KEY,
    work_id INT REFERENCES tbl_work(work_id) ON DELETE CASCADE,
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    bid_amount DECIMAL(10,2),
    proposal_text TEXT,
    application_status VARCHAR(20) DEFAULT 'pending', 
    work_progress INT DEFAULT 0, 
    payment_status VARCHAR(20) DEFAULT 'unpaid',
    rejected_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);  

CREATE TABLE IF NOT EXISTS tbl_saved_job (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    work_id INT REFERENCES tbl_work(work_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, work_id)
);

CREATE TABLE IF NOT EXISTS tbl_payment (
    payment_id SERIAL PRIMARY KEY,
    work_id INT REFERENCES tbl_work(work_id) ON DELETE CASCADE,
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    client_id UUID REFERENCES tbl_client(client_id) ON DELETE CASCADE,
    amount DECIMAL(10,2),
    payment_status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tbl_bank_details (
    bank_id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    account_holder_name VARCHAR(255),
    bank_name VARCHAR(255),
    account_number VARCHAR(50),
    ifsc_code VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Policies for bank details (Allowing all for development/testing)
CREATE POLICY "Allow all permissions for authenticated users" ON tbl_bank_details
FOR ALL TO authenticated
USING (true)
WITH CHECK (true);

-- 6. Tasks (For Progress Tracking)
CREATE TABLE IF NOT EXISTS tbl_task (
    task_id SERIAL PRIMARY KEY,
    work_id INT REFERENCES tbl_work(work_id) ON DELETE CASCADE,
    task_name VARCHAR(255) NOT NULL,
    task_description TEXT,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. Chat, Ratings, Complaints & Notifications
CREATE TABLE IF NOT EXISTS tbl_chat (
    chat_id SERIAL PRIMARY KEY,
    from_userid UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    to_userid UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    from_clientid UUID REFERENCES tbl_client(client_id) ON DELETE CASCADE,
    to_clientid UUID REFERENCES tbl_client(client_id) ON DELETE CASCADE,
    chat_content TEXT,
    chat_file_url VARCHAR(255),
    chat_file_type VARCHAR(50),
    chat_datetime TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    chat_status INT DEFAULT 0 
);

CREATE TABLE IF NOT EXISTS notifications (
    notification_id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL, 
    title VARCHAR(255),
    message TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    type VARCHAR(50), 
    target_id VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tbl_notification (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL, 
    title VARCHAR(255),
    message TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    type VARCHAR(50), 
    target_id VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tbl_rating (
    rating_id SERIAL PRIMARY KEY,
    work_id INT REFERENCES tbl_work(work_id) ON DELETE CASCADE,
    client_id UUID REFERENCES tbl_client(client_id) ON DELETE CASCADE,
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    rating_score INT NOT NULL,
    rating_content TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tbl_complaints (
    complaint_id SERIAL PRIMARY KEY,
    user_id UUID, 
    client_id UUID, 
    complaint_category VARCHAR(100),
    complaint_title VARCHAR(255),
    complaint_content TEXT,
    complaint_reply TEXT,
    complaint_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    complaint_status VARCHAR(50) DEFAULT 'Pending'
);

CREATE TABLE IF NOT EXISTS tbl_feedback (
    feedback_id SERIAL PRIMARY KEY,
    user_id UUID, 
    client_id UUID, 
    feedback_content TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. Mapping Tables (Multiple Skills per Work/User)
CREATE TABLE IF NOT EXISTS tbl_work_technicalskill (
    work_id INT REFERENCES tbl_work(work_id) ON DELETE CASCADE,
    technicalskill_id INT REFERENCES tbl_technicalskill(technicalskill_id) ON DELETE CASCADE,
    PRIMARY KEY (work_id, technicalskill_id)
);

CREATE TABLE IF NOT EXISTS tbl_work_softskill (
    work_id INT REFERENCES tbl_work(work_id) ON DELETE CASCADE,
    softskill_id INT REFERENCES tbl_softskill(softskill_id) ON DELETE CASCADE,
    PRIMARY KEY (work_id, softskill_id)
);

CREATE TABLE IF NOT EXISTS tbl_work_language (
    work_id INT REFERENCES tbl_work(work_id) ON DELETE CASCADE,
    language_id INT REFERENCES tbl_language(language_id) ON DELETE CASCADE,
    PRIMARY KEY (work_id, language_id)
);

CREATE TABLE IF NOT EXISTS tbl_user_technicalskill (
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    technicalskill_id INT REFERENCES tbl_technicalskill(technicalskill_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, technicalskill_id)
);

CREATE TABLE IF NOT EXISTS tbl_user_softskill (
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    softskill_id INT REFERENCES tbl_softskill(softskill_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, softskill_id)
);

CREATE TABLE IF NOT EXISTS tbl_user_language (
    user_id UUID REFERENCES tbl_user(id) ON DELETE CASCADE,
    language_id INT REFERENCES tbl_language(language_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, language_id)
);

-- Storage Buckets Setup (Supabase)
-- Insert buckets idempotently using ON CONFLICT DO UPDATE
INSERT INTO storage.buckets (id, name, public) 
VALUES 
('notifications', 'notifications', true), 
('resumes', 'resumes', true), 
('work_files', 'work_files', true), 
('proposals', 'proposals', true), 
('client_proofs', 'client_proofs', true),
('client_logos', 'client_logos', true),
('user_photos', 'user_photos', true),
('Chat', 'Chat', true)
ON CONFLICT (id) DO UPDATE SET public = true;

