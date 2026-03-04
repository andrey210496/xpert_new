import { Modal, Button, Badge } from '../ui';
import { Mail, Phone, Calendar, Tag, MessageSquare } from 'lucide-react';
import { supabase } from '../../services/supabase';
import { useState, useEffect, useRef } from 'react';

interface LeadData {
    id: string;
    first_name: string;
    last_name: string;
    email: string;
    phone: string;
    status: string;
    source: string;
    created_at: string;
}

interface LeadDetailsModalProps {
    isOpen: boolean;
    onClose: () => void;
    lead: LeadData | null;
    onUpdate: () => void;
}

const statusOptions = [
    { value: 'new', label: 'Novo', variant: 'sindico' },
    { value: 'contacted', label: 'Contatado', variant: 'morador' },
    { value: 'converted', label: 'Convertido', variant: 'zelador' },
    { value: 'lost', label: 'Perdido', variant: 'neutral' },
];

export function LeadDetailsModal({ isOpen, onClose, lead, onUpdate }: LeadDetailsModalProps) {
    const [currentStatus, setCurrentStatus] = useState(lead?.status ?? '');
    const requestIdRef = useRef(0);

    useEffect(() => {
        if (lead) setCurrentStatus(lead.status);
    }, [lead?.id, lead?.status]);

    if (!lead) return null;

    const handleUpdateStatus = (newStatus: string) => {
        if (newStatus === currentStatus) return;

        const previousStatus = currentStatus;
        const requestId = ++requestIdRef.current;
        setCurrentStatus(newStatus); // Atualização instantânea

        supabase
            .from('leads')
            .update({ status: newStatus })
            .eq('id', lead.id)
            .then(({ error }) => {
                // Ignora resposta se uma request mais recente já foi disparada
                if (requestId !== requestIdRef.current) return;
                if (error) {
                    setCurrentStatus(previousStatus); // Rollback
                } else {
                    onUpdate();
                }
            });
    };

    const handleWhatsApp = () => {
        const cleanPhone = lead.phone.replace(/\D/g, '');
        if (!cleanPhone) return;
        const url = new URL(`https://wa.me/55${cleanPhone}`);
        url.searchParams.set('text', `Olá ${lead.first_name}, aqui é o Administrador do XPERT. Recebi seu interesse em nossa plataforma.`);
        window.open(url.toString(), '_blank', 'noopener,noreferrer');
    };

    return (
        <Modal isOpen={isOpen} onClose={onClose} title="Detalhes do Lead">
            <div className="space-y-6">
                {/* Header Info */}
                <div className="flex flex-col gap-1">
                    <h3 className="text-xl font-bold text-text-primary">
                        {lead.first_name} {lead.last_name}
                    </h3>
                    <div className="flex items-center gap-2 text-text-tertiary text-sm">
                        <Calendar size={14} />
                        Capturado em {new Date(lead.created_at).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                    </div>
                </div>

                {/* Contact Info */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div className="p-3 bg-bg-secondary rounded-xl border border-border-subtle">
                        <div className="flex items-center gap-2 text-text-tertiary text-xs uppercase tracking-wider mb-1">
                            <Mail size={12} /> Email
                        </div>
                        <div className="text-text-primary font-medium break-all">{lead.email}</div>
                    </div>
                    <div className="p-3 bg-bg-secondary rounded-xl border border-border-subtle">
                        <div className="flex items-center gap-2 text-text-tertiary text-xs uppercase tracking-wider mb-1">
                            <Phone size={12} /> Telefone
                        </div>
                        <div className="text-text-primary font-medium">{lead.phone}</div>
                    </div>
                </div>

                {/* Status & Source */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                        <label className="flex items-center gap-2 text-text-tertiary text-xs uppercase tracking-wider mb-2">
                            <Tag size={12} /> Status Atual
                        </label>
                        <div className="flex flex-wrap gap-2">
                            {statusOptions.map((opt) => (
                                <button
                                    key={opt.value}
                                    onClick={() => handleUpdateStatus(opt.value)}
                                    className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all cursor-pointer ${currentStatus === opt.value
                                        ? 'bg-accent text-white ring-2 ring-accent/20'
                                        : 'bg-bg-tertiary text-text-secondary hover:bg-bg-secondary border border-border-subtle'
                                        }`}
                                >
                                    {opt.label}
                                </button>
                            ))}
                        </div>
                    </div>
                    <div>
                        <div className="flex items-center gap-2 text-text-tertiary text-xs uppercase tracking-wider mb-2">
                            <MessageSquare size={12} /> Origem
                        </div>
                        <Badge variant="neutral" className="uppercase text-[10px]">
                            {lead.source || 'Landing Page'}
                        </Badge>
                    </div>
                </div>

                {/* Actions */}
                <div className="pt-4 border-t border-border-subtle flex flex-col sm:flex-row gap-3">
                    <Button
                        variant="primary"
                        className="flex-1 gap-2"
                        onClick={handleWhatsApp}
                    >
                        <Phone size={18} />
                        Contatar via WhatsApp
                    </Button>
                    <Button
                        variant="secondary"
                        className="gap-2"
                        onClick={onClose}
                    >
                        Fechar
                    </Button>
                </div>
            </div>
        </Modal>
    );
}
