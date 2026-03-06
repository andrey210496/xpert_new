import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../services/supabase';
import { useAuth } from '../../contexts/AuthContext';
import { Card, Badge, Button, Input } from '../ui';
import { Plus, Users, Copy, Trash2, CheckCircle2, Ticket, Loader2 } from 'lucide-react';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import type { ProfileType, Profile } from '../../types';
import { formatTokenCount } from '../../utils/tokenCalculator';

interface InviteCode {
    id: string;
    code: string;
    profile_type: ProfileType;
    max_uses: number;
    current_uses: number;
    created_at: string;
}

const profileLabels: Record<string, string> = {
    admin: 'Síndico',
    morador: 'Morador',
    zelador: 'Zelador',
    prestador: 'Prestador',
};

const profileVariant: Record<string, 'sindico' | 'morador' | 'zelador' | 'prestador'> = {
    admin: 'sindico',
    morador: 'morador',
    zelador: 'zelador',
    prestador: 'prestador',
};

export function UserManagement() {
    const { tenant } = useAuth();
    const [users, setUsers] = useState<Profile[]>([]);
    const [inviteCodes, setInviteCodes] = useState<InviteCode[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    // Invite code form state
    const [isCreatingCode, setIsCreatingCode] = useState(false);
    const [newCodeTheme, setNewCodeTheme] = useState('');
    const [newCodeType, setNewCodeType] = useState<ProfileType>('morador');
    const [newCodeUses, setNewCodeUses] = useState(10);

    const [copiedCode, setCopiedCode] = useState<string | null>(null);

    const fetchData = useCallback(async () => {
        setIsLoading(true);
        if (!tenant) return;

        // Fetch Profiles
        const { data: profilesData, error: profilesError } = await supabase
            .from('profiles')
            .select('*')
            .eq('tenant_id', tenant.id)
            .order('created_at', { ascending: false });

        if (!profilesError && profilesData) {
            setUsers(profilesData);
        }

        // Fetch Invite Codes
        const { data: invitesData, error: invitesError } = await supabase
            .from('invite_codes')
            .select('*')
            .eq('tenant_id', tenant.id)
            .order('created_at', { ascending: false });

        if (!invitesError && invitesData) {
            setInviteCodes(invitesData);
        }

        setIsLoading(false);
    }, [tenant]);

    useEffect(() => {
        if (tenant?.id) {
            // eslint-disable-next-line react-hooks/set-state-in-effect
            fetchData();
        }
    }, [tenant?.id, fetchData]);

    const toggleUserStatus = async (userId: string, currentStatus: boolean) => {
        const { error } = await supabase
            .from('profiles')
            .update({ is_active: !currentStatus })
            .eq('id', userId);

        if (!error) {
            setUsers(users.map(u => u.id === userId ? { ...u, is_active: !currentStatus } : u));
        }
    };

    const generateInviteCode = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!tenant || !newCodeTheme.trim()) return;

        const baseCode = newCodeTheme.toUpperCase().replace(/\s+/g, '-');
        const randomSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
        const finalCode = `${baseCode}-${randomSuffix}`;

        setIsCreatingCode(true);

        const { data, error } = await supabase
            .from('invite_codes')
            .insert({
                tenant_id: tenant.id,
                code: finalCode,
                profile_type: newCodeType,
                max_uses: newCodeUses
            })
            .select()
            .single();

        if (!error && data) {
            setInviteCodes([data, ...inviteCodes]);
            setNewCodeTheme('');
        }
        setIsCreatingCode(false);
    };

    const deleteInviteCode = async (id: string) => {
        const { error } = await supabase
            .from('invite_codes')
            .delete()
            .eq('id', id);

        if (!error) {
            setInviteCodes(inviteCodes.filter(c => c.id !== id));
        }
    };

    const copyToClipboard = (code: string) => {
        navigator.clipboard.writeText(code);
        setCopiedCode(code);
        setTimeout(() => setCopiedCode(null), 2000);
    };

    if (isLoading) {
        return (
            <div className="flex justify-center items-center py-20">
                <Loader2 size={32} className="animate-spin text-accent" />
            </div>
        );
    }

    return (
        <div className="space-y-8 animate-fade-in">
            {/* Header section */}
            <div className="flex justify-between items-end">
                <div>
                    <h2 className="text-2xl font-bold font-display text-text-primary mb-1">Gestão de Acesso</h2>
                    <p className="text-sm text-text-secondary">Controle de moradores, zeladores e prestadores de serviço.</p>
                </div>
            </div>

            {/* Invite Codes Generation Card */}
            <Card className="p-6 bg-bg-secondary border-border border">
                <div className="flex flex-col md:flex-row gap-8">
                    <div className="flex-1 md:max-w-sm shrink-0">
                        <div className="flex items-center gap-2 mb-4">
                            <Ticket size={20} className="text-accent" />
                            <h3 className="text-sm font-bold font-mono uppercase tracking-widest text-text-primary">Novo Convite</h3>
                        </div>
                        <p className="text-xs text-text-secondary mb-6 leading-relaxed">
                            Crie códigos de acesso compartilháveis. Quando o usuário se cadastrar com este código, será automaticamente vinculado ao seu condomínio com o perfil designado.
                        </p>

                        <form onSubmit={generateInviteCode} className="space-y-4">
                            <Input
                                label="Palavra-chave (Tema)"
                                placeholder="Ex: BLOCO-A, FESTA, etc."
                                value={newCodeTheme}
                                onChange={(e) => setNewCodeTheme(e.target.value)}
                                required
                            />
                            <div className="grid grid-cols-2 gap-4">
                                <div className="space-y-1.5">
                                    <label className="text-xs font-bold text-text-secondary uppercase tracking-tight">Perfil</label>
                                    <select
                                        className="w-full bg-bg-primary border border-border rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent"
                                        value={newCodeType}
                                        onChange={(e) => setNewCodeType(e.target.value as ProfileType)}
                                    >
                                        <option value="morador">Morador</option>
                                        <option value="zelador">Zelador</option>
                                        <option value="prestador">Prestador</option>
                                    </select>
                                </div>
                                <Input
                                    label="Limite de Usos"
                                    type="number"
                                    min={1}
                                    max={1000}
                                    value={newCodeUses.toString()}
                                    onChange={(e) => setNewCodeUses(parseInt(e.target.value) || 1)}
                                />
                            </div>
                            <Button type="submit" isLoading={isCreatingCode} className="w-full">
                                <Plus size={16} className="mr-2" /> Gerar Código
                            </Button>
                        </form>
                    </div>

                    <div className="flex-1 border-t md:border-t-0 md:border-l border-border pt-6 md:pt-0 md:pl-8">
                        <h4 className="text-xs font-bold text-text-tertiary uppercase tracking-widest mb-4">Códigos Ativos</h4>

                        {inviteCodes.length === 0 ? (
                            <div className="text-center py-10 px-4 bg-bg-primary rounded-xl border border-dashed border-border text-text-tertiary text-sm">
                                Nenhum código de convite ativo.
                            </div>
                        ) : (
                            <div className="grid grid-cols-1 gap-3 max-h-[250px] overflow-y-auto pr-2 custom-scrollbar">
                                {inviteCodes.map(code => (
                                    <div key={code.id} className="flex justify-between items-center p-3 rounded-lg bg-bg-primary border border-border group hover:border-accent/30 transition-colors">
                                        <div className="flex-1">
                                            <div className="flex items-center gap-2 mb-1">
                                                <code className="text-sm font-bold text-accent font-mono tracking-wider">{code.code}</code>
                                                <Badge variant={profileVariant[code.profile_type] || 'morador'} showDot={false}>
                                                    {profileLabels[code.profile_type]}
                                                </Badge>
                                            </div>
                                            <div className="text-[10px] text-text-tertiary font-mono">
                                                Usos: {code.current_uses}/{code.max_uses} • Criado em {format(new Date(code.created_at), "dd/MM 'às' HH:mm", { locale: ptBR })}
                                            </div>
                                        </div>
                                        <div className="flex gap-1 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                                            <button
                                                onClick={() => copyToClipboard(code.code)}
                                                className="p-1.5 text-text-tertiary hover:text-text-primary bg-bg-secondary rounded-md transition-colors"
                                                title="Copiar Código"
                                            >
                                                {copiedCode === code.code ? <CheckCircle2 size={14} className="text-success" /> : <Copy size={14} />}
                                            </button>
                                            <button
                                                onClick={() => deleteInviteCode(code.id)}
                                                className="p-1.5 text-text-tertiary hover:text-error bg-bg-secondary rounded-md transition-colors"
                                                title="Remover"
                                            >
                                                <Trash2 size={14} />
                                            </button>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </div>
            </Card>

            {/* Users Table */}
            <div>
                <div className="flex items-center gap-2 mb-4 px-1">
                    <Users size={16} className="text-text-tertiary" />
                    <h3 className="text-sm font-bold text-text-primary uppercase tracking-widest font-mono">Lista de Usuários ({users.length})</h3>
                </div>

                <div className="border border-border rounded-xl overflow-hidden bg-bg-secondary shadow-sm">
                    <div className="overflow-x-auto">
                        <table className="w-full text-left text-xs">
                            <thead>
                                <tr className="bg-bg-tertiary/50 border-b border-border">
                                    <th className="px-5 py-3.5 font-bold text-text-tertiary uppercase tracking-widest min-w-[200px]">Identidade</th>
                                    <th className="px-5 py-3.5 font-bold text-text-tertiary uppercase tracking-widest">Contato</th>
                                    <th className="px-5 py-3.5 font-bold text-text-tertiary uppercase tracking-widest">Perfil</th>
                                    <th className="px-5 py-3.5 font-bold text-text-tertiary uppercase tracking-widest">Consumo (Hoje)</th>
                                    <th className="px-5 py-3.5 font-bold text-text-tertiary uppercase tracking-widest text-right">Acesso</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-border/50">
                                {users.length === 0 ? (
                                    <tr>
                                        <td colSpan={5} className="px-6 py-8 text-center text-text-tertiary text-sm">
                                            Nenhum usuário cadastrado sob este condomínio no momento.
                                        </td>
                                    </tr>
                                ) : users.map((user) => (
                                    <tr key={user.id} className="hover:bg-bg-hover/80 transition-colors group">
                                        <td className="px-5 py-4">
                                            <div className="font-semibold text-text-primary text-sm mb-0.5">{user.full_name}</div>
                                            <div className="text-[10px] text-text-tertiary font-mono">ID: {user.id.split('-')[0]}</div>
                                        </td>
                                        <td className="px-5 py-4 font-mono text-text-secondary">{user.phone || '-'}</td>
                                        <td className="px-5 py-4">
                                            <Badge variant={profileVariant[user.profile_type] || 'morador'} showDot={true}>
                                                {profileLabels[user.profile_type] || user.profile_type}
                                            </Badge>
                                        </td>
                                        <td className="px-5 py-4 font-mono text-text-secondary">
                                            {formatTokenCount(user.daily_token_usage || 0)}
                                        </td>
                                        <td className="px-5 py-4 text-right">
                                            <div className="flex items-center justify-end gap-3">
                                                <button
                                                    onClick={() => toggleUserStatus(user.id, user.is_active)}
                                                    className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center justify-center rounded-full border-2 border-transparent transition-colors focus:outline-none ${user.is_active ? 'bg-success' : 'bg-bg-tertiary'
                                                        }`}
                                                    role="switch"
                                                    aria-checked={user.is_active}
                                                    title={user.is_active ? 'Desativar acesso' : 'Ativar acesso'}
                                                >
                                                    <span
                                                        aria-hidden="true"
                                                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${user.is_active ? 'translate-x-2' : '-translate-x-2'
                                                            }`}
                                                    />
                                                </button>
                                                <span className={`text-[10px] uppercase font-bold w-12 text-center ${user.is_active ? 'text-success' : 'text-text-tertiary'}`}>
                                                    {user.is_active ? 'Logado' : 'Bloq.'}
                                                </span>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    );
}

// Ensure the local file ends with a newline
