import { motion } from 'framer-motion';
import { Button } from '../ui';

interface HeroSectionProps {
    onCTAClick: () => void;
}

export function HeroSection({ onCTAClick }: HeroSectionProps) {
    const stats = [
        { value: '4', label: 'Especialistas' },
        { value: '24/7', label: 'Operação' },
        { value: '< 2s', label: 'Resposta' },
    ];

    return (
        <section className="relative min-h-[80vh] flex flex-col items-center justify-center px-4 dot-grid pt-20">
            {/* Horizontal Divider with Fade */}
            <div className="absolute top-0 left-0 right-0 h-px bg-gradient-to-right from-transparent via-border to-transparent" />

            <div className="relative z-10 text-center max-w-4xl mx-auto flex flex-col items-center">
                {/* Badge */}
                <motion.div
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5 }}
                    className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-accent-muted border border-accent/20 text-accent text-[11px] font-bold font-display uppercase tracking-widest mb-10"
                >
                    IA para Gestão Condominial
                </motion.div>

                {/* Headline */}
                <motion.div
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5, delay: 0.1 }}
                    className="mb-8"
                >
                    <h1 className="text-5xl md:text-6xl lg:text-8xl font-extrabold tracking-tighter leading-[0.9] flex flex-col items-center">
                        <span className="text-text-primary">Inteligência que</span>
                        <span className="text-accent">resolve de verdade.</span>
                    </h1>
                </motion.div>

                {/* Subtitle */}
                <motion.p
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5, delay: 0.2 }}
                    className="text-base md:text-lg text-text-secondary max-w-xl mx-auto mb-12 leading-relaxed font-sans font-normal"
                >
                    Agentes especializados de IA para cada perfil do seu condomínio.
                    Gestão técnica, respostas imediatas e suporte operacional em tempo real.
                </motion.p>

                {/* CTA Button */}
                <motion.div
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5, delay: 0.3 }}
                >
                    <Button
                        size="lg"
                        onClick={onCTAClick}
                        className="bg-cta hover:bg-cta-hover text-bg-primary font-bold shadow-lg shadow-cta/10 transition-all duration-150"
                    >
                        Leve o XPERT para sua Administradora
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" className="ml-2">
                            <path d="M5 12h14M12 5l7 7-7 7" />
                        </svg>
                    </Button>
                </motion.div>

                {/* Stats Table */}
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ duration: 0.8, delay: 0.5 }}
                    className="flex items-center divide-x divide-border mt-24 border-y border-border/50 py-6 px-10"
                >
                    {stats.map((stat) => (
                        <div key={stat.label} className="px-8 text-center first:pl-0 last:pr-0">
                            <div className="text-2xl font-bold text-text-primary font-mono tracking-tight">{stat.value}</div>
                            <div className="text-[10px] uppercase tracking-widest text-text-tertiary font-display font-bold mt-1.5">{stat.label}</div>
                        </div>
                    ))}
                </motion.div>
            </div>

            <div className="absolute bottom-0 left-0 right-0 h-24 bg-gradient-to-bottom from-transparent to-bg-primary" />
        </section>
    );
}
