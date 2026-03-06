import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Modal, Input, Button } from '../components/ui';
import { LogIn } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

interface LoginModalProps {
    isOpen: boolean;
    onClose: () => void;
    onSwitchToSignup: () => void;
}

export function LoginModal({ isOpen, onClose, onSwitchToSignup }: LoginModalProps) {
    const { signIn } = useAuth();
    const navigate = useNavigate();
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');

        if (!email.trim() || !password.trim()) {
            setError('Preencha os campos obrigatórios.');
            return;
        }

        setIsLoading(true);
        const result = await signIn(email, password);
        setIsLoading(false);

        if (result.error) {
            setError(result.error);
        } else {
            onClose();
            if (result.profile?.profile_type === 'superadmin') {
                navigate('/superadmin');
            } else if (result.profile?.profile_type === 'admin') {
                navigate('/dashboard');
            } else if (result.profile) {
                navigate(`/chat/${result.profile.profile_type}`);
            } else {
                navigate('/');
            }
        }
    };


    return (
        <Modal isOpen={isOpen} onClose={onClose} size="sm">
            <div className="text-center mb-8 pt-4">
                <h2 className="text-2xl font-extrabold text-text-primary tracking-tight font-display mb-1.5">Entrar na conta</h2>
                <p className="text-sm text-text-secondary font-sans">Acesse a plataforma XPERT</p>
            </div>

            <form onSubmit={handleSubmit} className="flex flex-col gap-5">
                <Input
                    label="Credencial de e-mail"
                    placeholder="exemplo@xpert.ia"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    autoFocus
                />
                <div className="flex flex-col gap-1.5">
                    <Input
                        label="Chave de acesso"
                        placeholder="••••••••"
                        type="password"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                    />
                    <div className="flex justify-end">
                        <button type="button" className="text-[10px] uppercase tracking-widest font-bold text-text-tertiary hover:text-accent transition-colors cursor-pointer">
                            Esqueceu a senha?
                        </button>
                    </div>
                </div>

                {error && (
                    <div className="text-[10px] uppercase tracking-wider font-bold text-error bg-error/5 border border-error/20 rounded-md px-3 py-2 text-center">
                        {error}
                    </div>
                )}

                <Button type="submit" size="lg" isLoading={isLoading} className="mt-2 font-bold tracking-tight">
                    <LogIn size={16} className="mr-2" />
                    Confirmar Acesso
                </Button>

                <div className="text-center mt-2">
                    <button
                        type="button"
                        onClick={onSwitchToSignup}
                        className="text-xs text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
                    >
                        Não possui acesso? <span className="text-accent font-bold">Solicitar Credenciais</span>
                    </button>
                </div>
            </form>
        </Modal>
    );
}
