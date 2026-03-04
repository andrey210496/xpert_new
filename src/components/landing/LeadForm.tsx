import { useState } from 'react';
import { motion } from 'framer-motion';
import { Modal, Input, Button } from '../ui';
import type { LeadFormData } from '../../types';
import { supabase } from '../../services/supabase';
import { sendLeadNotification } from '../../services/uazapi';
import { CheckCircle2, Send } from 'lucide-react';

interface LeadFormProps {
    isOpen: boolean;
    onClose: () => void;
}

export function LeadForm({ isOpen, onClose }: LeadFormProps) {
    const [formData, setFormData] = useState<LeadFormData>({
        first_name: '',
        last_name: '',
        phone: '',
        email: '',
    });
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [isSuccess, setIsSuccess] = useState(false);
    const [errors, setErrors] = useState<Partial<Record<keyof LeadFormData, string>>>({});
    const [lastSubmitTime, setLastSubmitTime] = useState(0);

    const validate = (): boolean => {
        const newErrors: typeof errors = {};
        if (!formData.first_name.trim()) newErrors.first_name = 'Nome é obrigatório';
        else if (formData.first_name.length > 100) newErrors.first_name = 'Nome muito longo';
        if (!formData.last_name.trim()) newErrors.last_name = 'Sobrenome é obrigatório';
        else if (formData.last_name.length > 100) newErrors.last_name = 'Sobrenome muito longo';
        if (!formData.phone.trim()) newErrors.phone = 'Telefone é obrigatório';
        else if (formData.phone.length > 20) newErrors.phone = 'Telefone inválido';
        if (!formData.email.trim()) newErrors.email = 'Email é obrigatório';
        else if (formData.email.length > 254) newErrors.email = 'Email muito longo';
        else if (!/^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/.test(formData.email)) newErrors.email = 'Email inválido';
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!validate()) return;

        const now = Date.now();
        if (now - lastSubmitTime < 30_000) {
            setErrors({ email: 'Aguarde 30 segundos antes de enviar novamente.' });
            return;
        }

        setIsSubmitting(true);
        setLastSubmitTime(now);
        try {
            // 1. Send WhatsApp notification
            await sendLeadNotification(formData);

            // 2. Save to Supabase leads table
            const { error: dbError } = await supabase.from('leads').insert([{
                ...formData,
                status: 'new',
                source: 'landing'
            }]);

            if (dbError) throw dbError;

            setIsSuccess(true);
        } catch (error) {
            if (import.meta.env.DEV) console.error('[Lead] Error:', error);
            setErrors({ email: 'Erro ao processar sua solicitação. Tente novamente.' });
        } finally {
            setIsSubmitting(false);
        }
    };

    const handleClose = () => {
        if (isSuccess) {
            setIsSuccess(false);
            setFormData({ first_name: '', last_name: '', phone: '', email: '' });
        }
        onClose();
    };

    return (
        <Modal isOpen={isOpen} onClose={handleClose} title={isSuccess ? undefined : 'Leve o XPERT para sua Administradora'}>
            {isSuccess ? (
                <motion.div
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="text-center py-8"
                >
                    <motion.div
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        transition={{ type: 'spring', damping: 15, delay: 0.1 }}
                    >
                        <CheckCircle2 size={64} className="text-success mx-auto mb-4" />
                    </motion.div>
                    <h3 className="text-xl font-semibold text-text-primary mb-2">
                        Recebemos seu contato!
                    </h3>
                    <p className="text-text-secondary mb-6">
                        Nossa equipe entrará em contato em breve para apresentar o XPERT para sua administradora.
                    </p>
                    <Button onClick={handleClose} variant="secondary">
                        Fechar
                    </Button>
                </motion.div>
            ) : (
                <form onSubmit={handleSubmit} className="flex flex-col gap-4">
                    <p className="text-text-secondary text-sm mb-2">
                        Preencha seus dados e nossa equipe entrará em contato para apresentar como o XPERT pode revolucionar a gestão do seu condomínio.
                    </p>
                    <div className="grid grid-cols-2 gap-4">
                        <Input
                            label="Nome"
                            placeholder="Seu nome"
                            value={formData.first_name}
                            onChange={(e) => setFormData({ ...formData, first_name: e.target.value.slice(0, 100) })}
                            error={errors.first_name}
                        />
                        <Input
                            label="Sobrenome"
                            placeholder="Seu sobrenome"
                            value={formData.last_name}
                            onChange={(e) => setFormData({ ...formData, last_name: e.target.value.slice(0, 100) })}
                            error={errors.last_name}
                        />
                    </div>
                    <Input
                        label="Telefone"
                        placeholder="(11) 99999-9999"
                        type="tel"
                        value={formData.phone}
                        onChange={(e) => setFormData({ ...formData, phone: e.target.value.slice(0, 20) })}
                        error={errors.phone}
                    />
                    <Input
                        label="Email"
                        placeholder="seu@email.com"
                        type="email"
                        value={formData.email}
                        onChange={(e) => setFormData({ ...formData, email: e.target.value.slice(0, 254) })}
                        error={errors.email}
                    />
                    <Button
                        type="submit"
                        variant="primary"
                        size="lg"
                        isLoading={isSubmitting}
                        className="mt-2"
                    >
                        <Send size={18} />
                        Enviar
                    </Button>
                </form>
            )}
        </Modal>
    );
}
