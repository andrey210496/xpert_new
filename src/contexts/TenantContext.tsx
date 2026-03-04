import React, { createContext, useContext } from 'react';
import type { Tenant } from '../types';
import { useAuth } from './AuthContext';

interface TenantContextType {
    tenant: Tenant | null;
    tokenBalance: number;
    tokenPercentage: number;
    isLowBalance: boolean;
    isCriticalBalance: boolean;
}

const TenantContext = createContext<TenantContextType | undefined>(undefined);

export function TenantProvider({ children }: { children: React.ReactNode }) {
    const { tenant } = useAuth();

    const tokenBalance = tenant?.token_balance || 0;
    const totalTokens = tenant?.plan_tokens_total || 1;
    const tokenPercentage = Math.round((tokenBalance / totalTokens) * 100);
    const isLowBalance = tokenPercentage <= 20;
    const isCriticalBalance = tokenPercentage <= 5;

    return (
        <TenantContext.Provider
            value={{
                tenant,
                tokenBalance,
                tokenPercentage,
                isLowBalance,
                isCriticalBalance,
            }}
        >
            {children}
        </TenantContext.Provider>
    );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useTenant() {
    const context = useContext(TenantContext);
    if (!context) {
        throw new Error('useTenant must be used within TenantProvider');
    }
    return context;
}

export default TenantContext;
