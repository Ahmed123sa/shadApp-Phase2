export interface Client {
  id: number;
  company_name: string;
  contact_person: string;
  email: string;
  phone: string;
  manager_id: number;
  status: string;
  country?: string;
  industry?: string;
  client_type: 'business' | 'individual';
  contract_value: number;
  payment_status: string;
  signature_data?: string;
  signed_at?: string;
  avatar_url?: string;
  notes?: string;
  workspace?: Workspace | null;
  subUsers: any[];
  payments: any[];
  created_at: string;
  updated_at: string;
}

export interface Contract {
  id: number;
  workspace_id: number;
  title: string;
  status: ContractStatus;
  contract_type?: string;
  value: string | null;
  start_date?: string;
  end_date?: string;
  pdf_url?: string;
  client_signed_at?: string;
  company_signed_at?: string;
  archived_at?: string;
  created_by: number;
  creator?: User;
  workspace?: Workspace;
  clauses: ContractClause[];
}

export type ContractStatus =
  | 'draft' | 'sent' | 'client_approved'
  | 'edit_requested' | 'company_approved' | 'completed' | 'archived';

export interface ContractClause {
  id: number;
  contract_id: number;
  content: string;
  type: 'fixed' | 'optional' | 'custom';
  sort_order: number;
}

export interface Payment {
  id: number;
  workspace_id: number;
  client_id: number;
  amount: string | number;
  method_type: string;
  proof_file_url?: string | string[];
  status: 'pending' | 'approved';
  notes?: string;
  reviewed_by?: number;
  reviewed_at?: string;
  contract_id?: number;
  client?: Client;
  workspace?: Workspace;
  created_at: string;
}

export interface Approval {
  id: number;
  workspace_id: number;
  title: string;
  description?: string;
  status: 'pending' | 'approved' | 'edit_requested';
  reference_no: string;
  responded_at?: string;
  signature?: string;
  requester?: User;
  requester_id?: number;
  certificate?: ApprovalCertificate;
  workspace?: Workspace;
  created_at: string;
}

export interface ApprovalCertificate {
  id: number;
  approval_id: number;
  certificate_url?: string;
  pdf_url?: string;
  generated_at: string;
}

export interface Meeting {
  id: number;
  workspace_id: number;
  title: string;
  zoom_meeting_id?: string;
  link?: string;
  passcode?: string;
  scheduled_at: string;
  duration_minutes: number;
  status: 'scheduled' | 'completed' | 'cancelled';
  notes?: string;
  recording_url?: string;
  contract_id?: number;
  approval_id?: number;
  contract?: Contract;
  approval?: Approval;
  created_by?: number;
  creator?: User;
  workspace?: Workspace;
}

export interface ChatMessage {
  id: number;
  workspace_id: number;
  sender_type: string;
  sender_id: number;
  message?: string;
  type: 'text' | 'file' | 'contract';
  file_url?: string;
  contract_id?: number;
  contract?: Contract;
  sender?: User | Client;
  user_id?: number;
  requires_action: boolean;
  created_at: string;
}

export interface FileEntry {
  id: number;
  workspace_id: number;
  document_definition_id?: number;
  file_url: string;
  name: string;
  type: string;
  size: number;
  status: 'pending' | 'approved' | 'rejected';
  rejection_reason?: string;
  reviewed_by?: number;
  reviewed_at?: string;
  document_definition?: DocumentDefinition;
  uploaded_by_type: string;
  uploaded_by_id: number;
}

export interface DocumentDefinition {
  id: number;
  workspace_id: number;
  name: string;
  description?: string;
  is_required: boolean;
  sort_order: number;
}

export interface Workspace {
  id: number;
  client_id: number;
  manager_id: number;
  status: 'active' | 'inactive';
  activated_at?: string;
  client: Client;
  manager?: User;
}

export interface User {
  id: number;
  name: string;
  email: string;
  role: 'super_admin' | 'account_manager';
  official_email?: string;
  signature_data?: string;
  signed_at?: string;
  avatar_url?: string;
}

export interface ContractClauseTemplate {
  id: number;
  content: string;
  type: 'fixed' | 'optional';
  category?: string;
  is_active: boolean;
  sort_order: number;
}
