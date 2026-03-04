import { useNavigate } from 'react-router-dom';
import { OnboardingWizard } from '../components/onboarding/OnboardingWizard';
import type { Profile } from '../types';

export default function Onboarding() {
    const navigate = useNavigate();

    return (
        <OnboardingWizard
            onComplete={(profile: Profile | undefined) => {
                if (profile?.profile_type === 'superadmin') {
                    navigate('/superadmin');
                } else if (profile?.profile_type === 'admin') {
                    navigate('/dashboard');
                } else if (profile) {
                    navigate(`/chat/${profile.profile_type}`);
                } else {
                    navigate('/');
                }
            }}
            onBack={() => navigate('/')}
        />
    );
}
