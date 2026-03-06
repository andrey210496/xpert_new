import { useParams, useNavigate } from 'react-router-dom';
import { ChatWindow } from '../components/chat/ChatWindow';
import type { ProfileType } from '../types';

export default function Chat() {
    const { agentType } = useParams<{ agentType: string }>();
    const navigate = useNavigate();

    const validTypes: ProfileType[] = ['admin', 'morador', 'zelador', 'prestador'];
    const type = validTypes.includes(agentType as ProfileType) ? (agentType as ProfileType) : 'morador';

    return (
        <ChatWindow
            agentType={type}
            onNavigateSignup={() => navigate('/onboarding')}
            onNavigateLogin={() => navigate('/')}
        />
    );
}
