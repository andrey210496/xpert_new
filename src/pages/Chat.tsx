import { useParams, useNavigate, Navigate } from 'react-router-dom';
import { ChatWindow } from '../components/chat/ChatWindow';
import { useAuth } from '../contexts/AuthContext';
import type { ProfileType } from '../types';

export default function Chat() {
    const { agentType } = useParams<{ agentType: string }>();
    const navigate = useNavigate();
    const { profile, isAuthenticated } = useAuth();

    const validTypes: ProfileType[] = ['admin', 'morador', 'zelador', 'prestador'];
    const type = validTypes.includes(agentType as ProfileType) ? (agentType as ProfileType) : 'morador';

    // Authenticated users can only access their own profile type's chat
    if (isAuthenticated && profile && profile.profile_type !== type) {
        return <Navigate to={`/chat/${profile.profile_type}`} replace />;
    }

    return (
        <ChatWindow
            agentType={type}
            onNavigateSignup={() => navigate('/onboarding')}
            onNavigateLogin={() => navigate('/')}
        />
    );
}
