export function formatTokenCount(count: number): string {
    if (count >= 1_000_000) {
        return `${(count / 1_000_000).toFixed(1)}M`;
    }
    if (count >= 1_000) {
        return `${(count / 1_000).toFixed(1)}K`;
    }
    return count.toString();
}

export function estimateTokens(text: string): number {
    // Rough estimation: ~4 chars per token for Portuguese text
    return Math.ceil(text.length / 4);
}

export function calculateTokenCost(inputTokens: number, outputTokens: number): number {
    return inputTokens + outputTokens;
}
