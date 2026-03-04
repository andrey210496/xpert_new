import { Navigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import type { ProfileType } from '../types';

interface ProtectedRouteProps {
    children: React.ReactNode;
    allowedTypes?: ProfileType[];
}

function getDefaultRoute(profileType: ProfileType): string {
    switch (profileType) {
        case 'superadmin':
            return '/superadmin';
        case 'admin':
            return '/dashboard';
        default:
            return `/chat/${profileType}`;
    }
}

export function ProtectedRoute({ children, allowedTypes }: ProtectedRouteProps) {
    const { isAuthenticated, profile, isLoading } = useAuth();

    if (isLoading) {
        return (
            <div className="min-h-screen bg-bg-primary flex items-center justify-center">
                <svg className="animate-spin h-6 w-6 text-accent" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" fill="none" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
            </div>
        );
    }

    if (!isAuthenticated || !profile) {
        return <Navigate to="/" replace />;
    }

    if (allowedTypes && !allowedTypes.includes(profile.profile_type)) {
        return <Navigate to={getDefaultRoute(profile.profile_type)} replace />;
    }

    return <>{children}</>;
}
