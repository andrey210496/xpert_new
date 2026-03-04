import { motion } from 'framer-motion';
import { Building2, Home, Wrench, Hammer, ArrowRight } from 'lucide-react';
import type { ProfileType } from '../../types';
import { Card } from '../ui';

interface ProfileCardsProps {
    onSelectProfile: (type: ProfileType) => void;
}

const profiles = [
    {
        type: 'admin' as ProfileType,
        title: 'Síndico',
        description: 'Gestão técnica e inteligência administrativa para o condomínio.',
        Icon: Building2,
        colorClass: 'border-sindico',
        accentColor: '#3B82F6'
    },
    {
        type: 'morador' as ProfileType,
        title: 'Morador',
        description: 'Suporte imediato, normas e convivência para quem vive aqui.',
        Icon: Home,
        colorClass: 'border-morador',
        accentColor: '#10B981'
    },
    {
        type: 'zelador' as ProfileType,
        title: 'Zelador',
        description: 'Assitente operacional técnico para manutenção e vistorias.',
        Icon: Wrench,
        colorClass: 'border-zelador',
        accentColor: '#F59E0B'
    },
    {
        type: 'prestador' as ProfileType,
        title: 'Prestador',
        description: 'Otimização de serviços e conformidade técnica operacional.',
        Icon: Hammer,
        colorClass: 'border-prestador',
        accentColor: '#8B5CF6'
    },
];

export function ProfileCards({ onSelectProfile }: ProfileCardsProps) {
    return (
        <section className="py-24 px-4 max-w-6xl mx-auto">
            <motion.div
                initial={{ opacity: 0, y: 12 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                className="mb-12"
            >
                <h2 className="text-3xl font-extrabold text-text-primary tracking-tight font-display">
                    Escolha como utilizar
                </h2>
            </motion.div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {profiles.map((profile, index) => (
                    <motion.div
                        key={profile.type}
                        initial={{ opacity: 0, y: 16 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                        transition={{ delay: index * 0.05 }}
                        onClick={() => onSelectProfile(profile.type)}
                        className="group"
                    >
                        <Card
                            variant="default"
                            className={`h-full border-l-4 ${profile.colorClass} cursor-pointer hover:bg-bg-hover transition-all duration-150 relative flex flex-col gap-4 p-6`}
                        >
                            <profile.Icon
                                size={20}
                                style={{ color: profile.accentColor }}
                                className="mb-2"
                            />

                            <div>
                                <h3 className="text-lg font-bold text-text-primary font-display leading-tight mb-2">
                                    {profile.title}
                                </h3>
                                <p className="text-sm text-text-secondary leading-relaxed font-sans">
                                    {profile.description}
                                </p>
                            </div>

                            <div className="mt-auto flex items-center gap-2 text-[11px] font-bold text-text-tertiary transition-all duration-150 group-hover:text-text-primary group-hover:translate-x-1 opacity-0 group-hover:opacity-100">
                                ACESSAR AGENTE
                                <ArrowRight size={14} />
                            </div>
                        </Card>
                    </motion.div>
                ))}
            </div>
        </section>
    );
}
