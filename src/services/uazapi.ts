import type { LeadFormData } from '../types';

export async function sendLeadNotification(lead: LeadFormData): Promise<boolean> {
    const baseUrl = import.meta.env.VITE_UAZAPI_BASE_URL;
    const token = import.meta.env.VITE_UAZAPI_INSTANCE_TOKEN;
    const superAdminPhone = import.meta.env.VITE_SUPERADMIN_WHATSAPP;

    if (!baseUrl || !token || !superAdminPhone) {
        // UAZAPI not configured — skip notification
        return false;
    }

    const now = new Date();
    const dateStr = now.toLocaleDateString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    });

    const message = `🚀 *Novo Lead XPERT!*\n\n👤 Nome: ${lead.first_name} ${lead.last_name}\n📱 Telefone: ${lead.phone}\n📧 Email: ${lead.email}\n\n📅 Data: ${dateStr}\n\n_Lead interessado em levar o XPERT para a administradora._`;

    try {
        const response = await fetch(`${baseUrl}/sendText`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`,
            },
            body: JSON.stringify({
                phone: superAdminPhone,
                message,
            }),
        });

        return response.ok;
    } catch (error) {
        console.error('[UAZAPI] Error sending notification:', error);
        return false;
    }
}
