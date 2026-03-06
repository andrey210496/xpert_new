import { useEffect, useRef } from 'react';

export function Ticker() {
    const trackRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const track = trackRef.current;
        if (!track) return;

        let animId: number;
        let pos = 0;

        const animate = () => {
            pos -= 0.5;
            const halfWidth = track.scrollWidth / 2;
            if (Math.abs(pos) >= halfWidth) pos = 0;
            track.style.transform = `translateX(${pos}px)`;
            animId = requestAnimationFrame(animate);
        };

        animId = requestAnimationFrame(animate);
        return () => cancelAnimationFrame(animId);
    }, []);

    return (
        <div className="shrink-0 overflow-hidden bg-bg-secondary border-b border-border py-2">
            <div ref={trackRef} className="flex whitespace-nowrap will-change-transform">
                {[...Array(4)].map((_, i) => (
                    <span key={i} className="text-xs font-medium tracking-wide px-6">
                        <span className="text-text-secondary">O movimento da </span>
                        <span className="text-accent font-bold">SEGUNDA CHAMADA</span>
                        <span className="text-text-secondary"> começou, a continuação da sua jornada do livro </span>
                        <span className="text-text-primary font-bold">PRIMEIRA CHAMADA</span>
                        <span className="text-text-tertiary"> — </span>
                    </span>
                ))}
            </div>
        </div>
    );
}
