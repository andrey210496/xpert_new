import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { HeroSection } from '../components/landing/HeroSection';
import { ProfileCards } from '../components/landing/ProfileCards';
import { LeadForm } from '../components/landing/LeadForm';
import { LoginModal } from './Login';
import { useAuth } from '../contexts/AuthContext';
import type { ProfileType } from '../types';
import { motion } from 'framer-motion';
import { Shield, Zap, Clock, ArrowRight } from 'lucide-react';
import { Button } from '../components/ui';
import logo from '../assets/logo.png';

export default function Home() {
    const navigate = useNavigate();
    const { isAuthenticated, profile } = useAuth();
    const [showLeadForm, setShowLeadForm] = useState(false);
    const [showLogin, setShowLogin] = useState(false);

    const handleSelectProfile = (type: ProfileType) => {
        if (!isAuthenticated) {
            setShowLogin(true);
            return;
        }
        navigate(`/chat/${type}`);
    };

    const handleSignup = () => {
        setShowLogin(false);
        navigate('/onboarding');
    };

    return (
        <div className="min-h-screen bg-bg-primary font-sans text-text-primary">
            {/* Navigation */}
            <nav className="fixed top-0 left-0 right-0 z-50 border-b border-border bg-bg-primary/95 backdrop-blur-md">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <img src={logo} alt="DAUM XPERT.ia" className="h-10 w-auto object-contain" />
                    </div>
                    <div className="flex items-center gap-4">
                        {isAuthenticated ? (
                            <button
                                onClick={() => {
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
                        <Button size="sm" onClick={() => setShowLeadForm(true)}>Começar</Button>
                    </div>
                </div>
            </nav>

            {/* Hero */}
            <HeroSection onCTAClick={() => setShowLeadForm(true)} />

            {/* Profile Selection */}
            <ProfileCards onSelectProfile={handleSelectProfile} />

            {/* Features (Editorial Style) */}
            <section className="py-32 px-4 max-w-6xl mx-auto">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
                    {[
                        {
                            Icon: Zap,
                            title: 'Respostas Instantâneas',
                            desc: 'IA treinada com precisão em legislação e normas do mercado condominial.',
                            color: 'var(--color-accent)'
                        },
                        {
                            Icon: Shield,
                            title: 'Segurança por Perfil',
                            desc: 'Criptografia de ponta e isolamento de dados por condomínio e função.',
                            color: 'var(--color-morador)'
                        },
                        {
                            Icon: Clock,
                            title: 'Disponibilidade 24/7',
                            desc: 'Suporte ininterrupto para agilidade operacional e administrativa.',
                            color: 'var(--color-zelador)'
                        },
                    ].map((feature, i) => (
                        <motion.div
                            key={feature.title}
                            initial={{ opacity: 0, y: 12 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true }}
                            transition={{ delay: i * 0.1 }}
                            className="flex flex-col gap-4 border-t border-border-strong pt-8 group"
                        >
                            <feature.Icon size={24} style={{ color: feature.color }} />
                            <h3 className="text-xl font-bold tracking-tight font-display">{feature.title}</h3>
                            <p className="text-sm text-text-secondary leading-relaxed">{feature.desc}</p>
                        </motion.div>
                    ))}
                </div>
            </section>

            {/* Final CTA (Editorial Style) */}
            <section className="py-32 px-4 bg-bg-secondary border-y border-border">
                <div className="max-w-4xl mx-auto text-center flex flex-col items-center">
                    <h2 className="text-4xl md:text-5xl font-extrabold text-text-primary mb-6 tracking-tight font-display leading-[1.1]">
                        O futuro da gestão condominial<br />começa com o XPERT.
                    </h2>
                    <p className="text-text-secondary text-lg mb-10 max-w-2xl">
                        Uma plataforma pensada para administradoras que não abrem mão da excelência e agilidade técnica.
                    </p>
                    <Button
                        size="lg"
                        onClick={() => setShowLeadForm(true)}
                        className="bg-accent hover:bg-accent-hover text-white px-10 group"
                    >
                        Leve o XPERT para seu Condomínio
                        <ArrowRight size={18} className="ml-2 transition-transform group-hover:translate-x-1" />
                    </Button>
                </div>
            </section>

            {/* Footer */}
            <footer className="py-12 px-6 border-t border-border">
                <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
                    <img src={logo} alt="DAUM XPERT.ia" className="h-8 w-auto opacity-80" />
                    <p className="text-[10px] uppercase tracking-widest font-mono text-text-tertiary">
                        © 2026 DAUM XPERT.ia — Todos os direitos reservados.
                    </p>
                </div>
            </footer>

            {/* Modals */}
            <LeadForm isOpen={showLeadForm} onClose={() => setShowLeadForm(false)} />
            <LoginModal
                isOpen={showLogin}
                onClose={() => setShowLogin(false)}
                onSwitchToSignup={handleSignup}
            />
        </div>
    );
}
