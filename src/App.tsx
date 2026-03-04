import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import { TenantProvider } from './contexts/TenantContext';
import { ProtectedRoute } from './components/ProtectedRoute';
import Home from './pages/Home';
import Chat from './pages/Chat';
import Dashboard from './pages/Dashboard';
import SuperAdminDashboard from './pages/SuperAdminDashboard';
import Onboarding from './pages/Onboarding';
import { useNavigate } from 'react-router-dom';

function DashboardWrapper() {
  const navigate = useNavigate();
  return <Dashboard onNavigateHome={() => navigate('/')} />;
}

function SuperAdminWrapper() {
  const navigate = useNavigate();
  return <SuperAdminDashboard onNavigateHome={() => navigate('/')} />;
}

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <TenantProvider>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/chat/:agentType" element={
              <ProtectedRoute allowedTypes={['admin', 'morador', 'zelador', 'prestador', 'superadmin']}>
                <Chat />
              </ProtectedRoute>
            } />
            <Route path="/dashboard" element={
              <ProtectedRoute allowedTypes={['admin']}>
                <DashboardWrapper />
              </ProtectedRoute>
            } />
            <Route path="/superadmin" element={
              <ProtectedRoute allowedTypes={['superadmin']}>
                <SuperAdminWrapper />
              </ProtectedRoute>
            } />
            <Route path="/onboarding" element={<Onboarding />} />
          </Routes>
        </TenantProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;
