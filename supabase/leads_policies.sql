-- =============================================
-- RLS Policies for Leads Table
-- =============================================

-- Enable RLS
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- 1. Anyone can insert (public form)
-- This might already exist, but ensuring it's here
DROP POLICY IF EXISTS "Anyone can submit leads" ON leads;
CREATE POLICY "Anyone can submit leads"
  ON leads FOR INSERT
  WITH CHECK (true);

-- 2. Admins can view all leads
-- Requires the is_admin() function from schema.sql
DROP POLICY IF EXISTS "Admins can view all leads" ON leads;
CREATE POLICY "Admins can view all leads"
  ON leads FOR SELECT
  USING (is_admin());

-- 3. Admins can update all leads
DROP POLICY IF EXISTS "Admins can update all leads" ON leads;
CREATE POLICY "Admins can update all leads"
  ON leads FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- 4. Sync status constraint with frontend options
ALTER TABLE leads DROP CONSTRAINT IF EXISTS leads_status_check;
ALTER TABLE leads ADD CONSTRAINT leads_status_check CHECK (status IN ('new', 'contacted', 'converted', 'lost'));
