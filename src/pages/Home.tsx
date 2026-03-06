import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { HeroSection } from '../components/landing/HeroSection';
import { Ticker } from '../components/landing/Ticker';
import { ChatPreview } from '../components/landing/ChatPreview';
import { LeadForm } from '../components/landing/LeadForm';
import { LoginModal } from './Login';
import { useAuth } from '../contexts/AuthContext';
import type { ProfileType } from '../types';
import { motion } from 'framer-motion';
import { Building2, Home, Wrench, Hammer, Rocket } from 'lucide-react';
import logo from '../assets/logo.png';
import logoPrevente from '../assets/logo_prevente.png';

const AGENT_TABS = [
    { type: 'admin' as ProfileType, label: 'SÍNDICO(A)', Icon: Building2, color: '#3B82F6' },
    { type: 'morador' as ProfileType, label: 'MORADOR(A)', Icon: Home, color: '#10B981' },
    { type: 'zelador' as ProfileType, label: 'ZELADOR', Icon: Wrench, color: '#F59E0B' },
    { type: 'prestador' as ProfileType, label: 'PRESTADOR DE SERVIÇO', Icon: Hammer, color: '#8B5CF6' },
];

export default function HomePage() {
    const navigate = useNavigate();
    const { isAuthenticated, profile } = useAuth();
    const [showLeadForm, setShowLeadForm] = useState(false);
    const [showLogin, setShowLogin] = useState(false);
    const [selectedAgent, setSelectedAgent] = useState<ProfileType>('admin');

    const handleGoToChat = () => {
        navigate(`/chat/${selectedAgent}`);
    };

    const handleSignup = () => {
        setShowLogin(false);
        navigate('/onboarding');
    };

    return (
        <div className="relative h-screen overflow-hidden bg-bg-primary font-sans text-text-primary flex flex-col">
            {/* Premium Tech Background */}
            <div className="absolute inset-0 bg-radial-glow pointer-events-none z-0" />
            <div className="absolute inset-0 bg-tech-grid pointer-events-none z-0 opacity-60" />

            {/* Content Container */}
            <div className="relative z-10 flex flex-col h-full w-full overflow-hidden">
                {/* Navigation */}
                <nav className="shrink-0 border-b border-border bg-bg-primary/95 backdrop-blur-md z-50">
                    <div className="w-full mx-auto px-6 lg:px-12 h-20 py-2 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <img src={logo} alt="DAUM XPERT.ia" className="h-[56px] w-auto object-contain" />
                        </div>
                        <div className="flex items-center gap-3">
                            <a
                                href="https://gpsprevente.vercel.app/"
                                target="_blank"
                                rel="noopener noreferrer"
                                className="hidden md:flex items-center gap-2 px-4 py-2 rounded-full border border-accent/20 bg-accent/10 text-accent hover:bg-accent/20 transition-colors text-[10px] font-bold uppercase tracking-widest cursor-pointer whitespace-nowrap"
                            >
                                <Rocket size={14} />
                                POTENCIALIZE SEU PLANO / CONHEÇA O GPS
                            </a>
                            {isAuthenticated ? (
                                <button
                                    onClick={() => {
                                        if (profile?.profile_type === 'superadmin') navigate('/superadmin');
                                        else if (profile?.profile_type === 'admin') navigate('/dashboard');
                                        else if (profile) navigate(`/chat/${profile.profile_type}`);
                                        else navigate('/');
                                    }}
                                    className="text-sm font-medium text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
                                >
                                    Meu Painel
                                </button>
                            ) : (
                                <button
                                    onClick={() => setShowLogin(true)}
                                    className="text-sm font-medium text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
                                >
                                    Já tenho conta
                                </button>
                            )}
                        </div>
                    </div>
                </nav>

                {/* Ticker */}
                <Ticker />

                {/* Main content — centered vertically */}
                <main className="flex-1 flex flex-col items-center justify-center min-h-0 gap-4">
                    {/* Hero */}
                    <HeroSection />

                    {/* Agent Tabs */}
                    <div className="flex flex-wrap justify-center gap-2 px-4">
                        {AGENT_TABS.map((tab, i) => {
                            const isActive = selectedAgent === tab.type;
                            return (
                                <motion.button
                                    key={tab.type}
                                    initial={{ opacity: 0, y: 8 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    transition={{ delay: 0.1 + i * 0.05 }}
                                    onClick={() => setSelectedAgent(tab.type)}
                                    className={`
                                    flex items-center gap-2 px-4 py-2.5 rounded-lg text-xs font-bold uppercase tracking-wider
                                    border transition-all duration-150 cursor-pointer
                                    ${isActive
                                            ? 'bg-accent/10 border-accent text-accent'
                                            : 'bg-bg-tertiary border-border text-text-secondary hover:border-border-strong hover:text-text-primary'
                                        }
                                `}
                                >
                                    <tab.Icon size={14} />
                                    {tab.label}
                                </motion.button>
                            );
                        })}
                    </div>

                    {/* Chat Preview + CTA */}
                    <ChatPreview
                        selectedAgent={selectedAgent}
                        onAgentClick={handleGoToChat}
                        onCTAClick={() => setShowLeadForm(true)}
                    />
                </main>

                {/* Modals */}
                <LeadForm isOpen={showLeadForm} onClose={() => setShowLeadForm(false)} />
                <LoginModal
                    isOpen={showLogin}
                    onClose={() => setShowLogin(false)}
                    onSwitchToSignup={handleSignup}
                />

                {/* Integrated Footer Elements (Bottom are part of the body) */}
                <div className="absolute bottom-8 left-6 lg:left-12 z-50 pointer-events-none">
                    <p className="text-[10px] font-bold text-text-tertiary uppercase tracking-widest opacity-60">
                        © 2025 Prevente Engenharia Diagnóstica
                    </p>
                </div>

                <div className="absolute bottom-8 right-6 lg:right-12 z-50">
                    <img
                        src={logoPrevente}
                        alt="Prevente"
                        className="h-12 w-auto opacity-80 hover:opacity-100 transition-opacity object-contain"
                        onError={(e) => {
                            // Fallback if logo_prevente.png is missing
                            (e.target as HTMLImageElement).src = logo;
                        }}
                    />
                </div>
            </div>
        </div>
    );
}
